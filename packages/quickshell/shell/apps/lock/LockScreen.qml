import QtQuick
import QtQuick.Effects
import Quickshell
import qs.apps.shellmanager
import qs.config
import qs.kit

// What a locked screen shows (Lock.qml puts it on every monitor): the time,
// the date, the user, a password field with the keyboard layout beside it
// (a click switches it) and the power buttons; a wrong password says so in
// red. The background is the theme's, the wallpaper or the blurred desktop;
// the cursor hides after a few still seconds. With Motion.lock it comes in
// (the background fades, the rest rises) and the field shakes on a wrong
// password. Not `main`: a dark monitor —
// its hidden field still takes the keys and shares the text with the shown
// one. Options: ModuleSettings "lock".
Rectangle {
  id: root

  required property var lock                 // Lock.qml: user, busy, error, layout, typed, snapshot(), tryUnlock(), nextLayout(), power()
  property string screenName: ""
  property bool main: true                   // shows the clock, the field and the buttons

  function opt(key, fallback) { return ModuleSettings.get("lock", key, fallback); }

  readonly property string background: opt("background", "solid")   // solid | wallpaper | blur
  readonly property bool hideCursor: opt("hideCursor", true)

  // the wallpaper as Wallpaper.qml sets it: the theme's picture, else its
  // colour; blurred: the desktop as it was just before locking
  readonly property string image: background === "blur" ? lock.snapshot(screenName)
    : ShellSettings.wallpaperMode === "image" && WallpaperService.imageFor(ThemeService.current) !== ""
      ? "file://" + WallpaperService.pathOf(WallpaperService.imageFor(ThemeService.current)) : ""

  color: background === "solid" || !main ? Theme.background0
       : ShellSettings.wallpaperMode === "custom" ? ShellSettings.wallpaperColor : Theme.background1

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ---- coming in ----
  // the screen is locked from the first frame (the colour); only what is on
  // it fades and rises
  property real intro: Motion.lock ? 0 : 1
  NumberAnimation on intro { running: Motion.lock; from: 0; to: 1; duration: Motion.ms(520); easing.type: Motion.easing }

  // ---- background ----
  Image {
    id: wallpaper
    anchors.fill: parent
    visible: root.main && root.background !== "solid" && root.image !== "" && status === Image.Ready
    source: root.main && root.background !== "solid" ? root.image : ""
    fillMode: Image.PreserveAspectCrop
    opacity: root.intro
    cache: false                         // the snapshot is a new picture under the same name
    layer.enabled: root.background === "blur"
    layer.effect: MultiEffect { blurEnabled: true; blur: root.opt("blur", 60) / 100; blurMax: 64 }
  }

  Rectangle {
    anchors.fill: parent
    visible: root.main && root.background !== "solid"
    opacity: root.intro
    color: Theme.scrim
  }

  // ---- centre ----
  Column {
    anchors.centerIn: parent
    opacity: (root.main ? 1 : 0) * root.intro   // not hidden: the field must take keys
    transform: Translate { y: 24 * (1 - root.intro) }
    width: 360
    spacing: Theme.gapGroup

    KitText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(clock.date, root.opt("clock", "24h") === "12h" ? "h:mm AP" : "HH:mm")
      font.pixelSize: 72
      font.weight: Font.ExtraBold
    }

    KitText {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.opt("date", true)
      text: Qt.formatDate(clock.date, "dddd, d MMMM").toUpperCase()
      color: Theme.muted
      font.letterSpacing: 1
    }

    Item { width: 1; height: 24 }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.opt("user", true)
      spacing: Theme.gapMedium

      KitIcon { anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 16; tint: Theme.foreground2 }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: root.lock.user }
    }

    // the field keeps the centre; the layout stands out to its right
    Item {
      id: fieldBox
      width: parent.width
      height: field.height
      transform: Translate { id: shake }

      // a wrong password: a short shake from side to side
      SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -10; duration: Motion.ms(50); easing.type: Motion.easing }
        NumberAnimation { target: shake; property: "x"; to: 8; duration: Motion.ms(70) }
        NumberAnimation { target: shake; property: "x"; to: -5; duration: Motion.ms(60) }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: Motion.ms(60); easing.type: Motion.easing }
      }

      Connections {
        target: root.lock
        function onErrorChanged() { if (root.lock.error !== "" && Motion.lock) shakeAnim.restart(); }
      }

      KitInput {
        id: field
        width: parent.width
        accessibleName: "Unlock password"
        echoMode: TextInput.Password
        placeholder: "Password"
        enabled: !root.lock.busy
        onTextChanged: if (root.lock.typed !== text) root.lock.typed = text
        onAccepted: { root.lock.tryUnlock(text); root.lock.typed = ""; }
        Component.onCompleted: input.forceActiveFocus()

        Connections {
          target: root.lock
          function onTypedChanged() { if (field.text !== root.lock.typed) field.text = root.lock.typed; }
        }
      }

      // the layout the password is typed in, as the bar's Language shows it
      KitButton {
        id: layoutButton
        x: parent.width + 6
        visible: root.main && root.opt("layout", true) && root.lock.layout !== ""
        implicitHeight: field.height
        implicitWidth: 48
        text: Format.layout(root.lock.layout) || root.lock.layout.slice(0, 2).toUpperCase()
        onClicked: { root.lock.nextLayout(); field.input.forceActiveFocus(); }
      }
    }

    KitText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.lock.busy ? "Checking…" : root.lock.error !== "" ? root.lock.error : "Enter to unlock"
      color: root.lock.error !== "" && !root.lock.busy ? Theme.red : Theme.muted
      font.pixelSize: Theme.fontSize - 1
    }
  }

  // ---- power ----
  // a button asks once: the second click within 3 s does it
  property string armed: ""

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

  Column {
    id: powerRow

    readonly property bool hovered: suspend.hovered || reboot.hovered || shutdown.hovered

    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
    visible: root.main && root.opt("power", true)
    opacity: root.intro
    spacing: Theme.gapLoose

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Theme.gapSmall

      KitButton {
        id: suspend
        icon: "moon"; text: "Suspend"
        selected: root.armed === "suspend"
        onClicked: root.press("suspend")
      }
      KitButton {
        id: reboot
        icon: "refresh"; text: root.armed === "reboot" ? "Sure?" : "Reboot"
        selected: root.armed === "reboot"
        onClicked: root.press("reboot")
      }
      KitButton {
        id: shutdown
        icon: "power"; text: root.armed === "poweroff" ? "Sure?" : "Shut down"
        selected: root.armed === "poweroff"
        onClicked: root.press("poweroff")
      }
    }
  }

  function press(action) {
    field.input.forceActiveFocus();
    if (armed === action) { armed = ""; disarm.stop(); lock.power(action); return; }
    armed = action;
    disarm.restart();
  }

  // ---- cursor ----
  // hidden after a few still seconds (not over a button), back on a move.
  // One area over everything that takes no clicks: its shape switches in
  // place, so the pointer goes at once, not on the next move.
  property bool pointerShown: !hideCursor

  onHideCursorChanged: pointerShown = !hideCursor

  Timer {
    id: idle
    interval: root.opt("cursorDelay", 3) * 1000
    running: root.hideCursor
    onTriggered: if (root.hideCursor && !powerRow.hovered) root.pointerShown = false
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    cursorShape: root.pointerShown ? Qt.ArrowCursor : Qt.BlankCursor
    onPositionChanged: if (root.hideCursor) { root.pointerShown = true; idle.restart(); }
  }
}
