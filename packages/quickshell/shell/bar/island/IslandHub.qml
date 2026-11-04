import QtQuick
import Quickshell
import qs.bar
import qs.bar.island.hub
import qs.config
import qs.kit
import Quickshell.Widgets
import qs.modules.sysmon
import qs.modules.audio
import qs.modules.brightness

// The hub (Bezel: a watch face for the desktop): the time large, then its blocks — the
// Machine's rings, toggles as discs, the week, sliders, the player, modules as bare rings or chips.
// A chip is the module's own face: its click opens the module's popup in the
// island, a right click its options.
Item {
  id: root

  required property PanelWindow bar
  property var modules: ({})

  signal power()
  signal manager()                          // the gear: Shell Manager
  signal settings(string id)

  // Shell Manager › Bar › HUB (island style)
  // the hub has two sets of its own: the tiles (zone tiles) and the module chips (zone hub)
  readonly property var tileIds: BarLayout.islandIn("tiles", bar.screen?.name ?? "")
  readonly property var ids: BarLayout.islandIn("hub", bar.screen?.name ?? "")

  readonly property real preferredWidth: ModuleSettings.get("hub", "width", 400)
  // the player card is also the way into the Music popup, so it shows with nothing playing too
  readonly property bool hasPlayer: ShellSettings.hubPlayer
  readonly property string userName: ModuleSettings.get("profile", "name", "") || Quickshell.env("USER") || "User"
  readonly property string avatarPath: ModuleSettings.get("profile", "avatar", ModuleSettings.get("hub", "avatar", ""))
  readonly property string subtitleMode: ModuleSettings.get("hub", "subtitle", "both")
  function uptime(seconds) {
    if (seconds <= 0) return "Uptime —";
    const days = Math.floor(seconds / 86400), hours = Math.floor(seconds % 86400 / 3600), minutes = Math.floor(seconds % 3600 / 60);
    return "Up " + (days ? days + "d " : "") + (hours || days ? hours + "h " : "") + minutes + "m";
  }
  property date now: new Date()

  // a block is there when it has something to show
  function wants(id) {
    return id === "tiles" ? tileIds.length > 0 : id === "player" ? hasPlayer : id === "night" ? !ModuleSettings.get("hub", "nightAuto", true) || BrightnessService.nightActive
         : id === "modules" ? ids.length > 0 : true;
  }
  function blockOf(id) {
    return ({ machine: machineBlock, tiles: tilesBlock, week: weekBlock, player: playerBlock, volume: volumeBlock, microphone: microphoneBlock, brightness: brightnessBlock, night: nightBlock, dimming: dimmingBlock, modules: modulesBlock })[id] ?? null;
  }

  // the month is a page of the hub: the island grows to it and back
  property bool calendarOpen: false
  onVisibleChanged: if (!visible) calendarOpen = false
  implicitHeight: (calendarOpen ? calendarPage.implicitHeight : column.implicitHeight) + 2 * Theme.gapGroup

  // the player modules are on no bar; they live here for their popups (the player card opens
  // the one of what plays: the radio, the music, another app's media)
  Loader {
    id: musicHost
    visible: false
    sourceComponent: root.modules["music"] ?? null
  }
  Loader {
    id: mediaHost
    visible: false
    sourceComponent: root.modules["media"] ?? null
  }
  Loader {
    id: tunerHost
    visible: false
    sourceComponent: root.modules["tuner"] ?? null
  }

  // the large clock: a tick a second while the hub shows, none while it is hidden
  Timer {
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  HubCalendar {
    id: calendarPage
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.gapGroup }
    // the two pages cross-fade, each sliding a little as it comes or goes
    opacity: root.calendarOpen ? 1 : 0
    visible: opacity > 0.001
    transform: Translate { y: root.calendarOpen ? 0 : 10; Behavior on y { enabled: Motion.on; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } } }
    Behavior on opacity { enabled: Motion.on; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
    now: root.now
    onBack: root.calendarOpen = false
  }

  Column {
    id: column
    opacity: root.calendarOpen ? 0 : 1
    visible: opacity > 0.001
    transform: Translate { y: root.calendarOpen ? -10 : 0; Behavior on y { enabled: Motion.on; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } } }
    Behavior on opacity { enabled: Motion.on; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.gapGroup }
    spacing: Theme.sectionGap

    // ---- header: the time large (the pill's clock grown), the day, then you, settings, power ----
    Item {
      width: parent.width
      height: Math.max(time.implicitHeight + day.implicitHeight, 38)

      KitText {
        id: time
        anchors { left: parent.left; top: parent.top }
        // a display figure: a fixed size (design.md › Text)
        text: Qt.formatDateTime(root.now, ModuleSettings.get("clock", "twelveHour", false) ? "h:mm" : "HH:mm")
        font.pixelSize: 34
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
        font.letterSpacing: -1.4
      }
      KitText {
        id: day
        anchors { left: parent.left; top: time.bottom; right: avatar.left; rightMargin: Theme.gapMedium }
        text: (root.subtitleMode === "both" ? root.uptime(SysmonService.uptime) + " · " : "") + Qt.formatDateTime(root.now, "dddd · d MMM")
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 1
        elide: Text.ElideRight
      }

      ClippingRectangle {
        id: avatar
        anchors { right: settingsButton.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
        width: 30; height: 30
        radius: Theme.radiusFor(height)
        color: Theme.pickFill
        Accessible.name: root.userName
        Image {
          id: avatarImage
          anchors.fill: parent
          source: root.avatarPath ? "file://" + root.avatarPath : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(60, 60)
          visible: status === Image.Ready
        }
        KitText {
          anchors.centerIn: parent
          visible: !avatarImage.visible
          text: root.userName.slice(0, 1).toUpperCase()
          font.weight: Font.Medium
        }
      }

      IslandButton {
        id: settingsButton
        anchors { right: powerButton.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
        icon: "settings"
        iconSize: 16
        onClicked: root.manager()
      }

      IslandButton {
        id: powerButton
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        icon: "power"
        iconSize: 16
        onClicked: root.power()
      }
    }

    // ---- the blocks, in the order and the visibility of Bar › Hub ----
    Repeater {
      model: HubBlocks.order

      Loader {
        required property string modelData
        width: parent.width
        active: HubBlocks.shown(modelData) && root.wants(modelData)
        visible: active
        sourceComponent: root.blockOf(modelData)

        // a right click on a block: its options on the Hub page (the chips and the tiles
        // answer for themselves: their module's options)
        TapHandler {
          acceptedButtons: Qt.RightButton
          enabled: ShellSettings.barRightSettings && modelData !== "tiles" && modelData !== "modules"
          onTapped: root.settings("hub:" + modelData)
        }
      }
    }
  }

  // the calendar: the week strip (a click opens the month as a page), or the month itself
  Component {
    id: weekBlock
    Loader {
      sourceComponent: ModuleSettings.get("hub", "calendarMode", "week") === "month" ? monthInline : weekStrip
    }
  }
  Component {
    id: weekStrip
    HubWeek {
      width: parent.width
      now: root.now
      onClicked: root.calendarOpen = true
    }
  }
  Component {
    id: monthInline
    HubCalendar {
      width: parent.width
      now: root.now
      embedded: true
    }
  }

  Component {
    id: machineBlock
    HubMachine { width: parent.width; live: root.visible }
  }

  Component {
    id: tilesBlock
      HubTiles {
        width: parent.width
        ids: root.tileIds
        modules: root.modules
        onSettings: id => root.settings("hubchip:" + id)
      }
  }

  Component {
    id: playerBlock
      Rectangle {
        id: track
        readonly property bool compact: ModuleSettings.get("hub", "playerSize", "card") === "compact"
        width: parent.width
        height: compact ? 44 : 60
        visible: root.hasPlayer
        radius: Theme.radiusCard
        color: Theme.controlFill
        border.width: Theme.frameWidth
        border.color: Theme.controlLine

        function clock(s) { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

        // a click on the card (not its buttons) opens the popup of what plays
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: (IslandService.family === "radio" ? tunerHost : IslandService.family === "music" ? musicHost : mediaHost).item?.openPopup()
        }

        IslandCover {
          id: cover
          anchors { left: parent.left; leftMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
          size: track.height - 2 * Theme.gapMedium
        }

        Column {
          anchors { left: cover.right; leftMargin: Theme.gapWide; right: controls.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapTight

          KitText {
            width: parent.width
            text: IslandService.title || "Nothing playing"
            textFormat: Text.PlainText
            font.weight: Font.Bold
            elide: Text.ElideRight
          }
          KitText {
            width: parent.width
            visible: IslandService.hasMedia && !track.compact
            text: (IslandService.artist !== "" ? IslandService.artist + " · " : "") + track.clock(IslandService.position) + " / " + track.clock(IslandService.length)
            textFormat: Text.PlainText
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
          }
        }

        // back, the one filled button, forward
        Row {
          id: controls
          anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapSmall

          IslandButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !track.compact
            icon: "skip-back"
            iconSize: 14
            onClicked: IslandService.prev()
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: track.compact ? 30 : 40
            height: width
            radius: Theme.pill(height)
            color: playArea.containsMouse ? Theme.foreground0 : Theme.foreground1

            KitIcon { anchors.centerIn: parent; name: IslandService.playing ? "pause" : "play"; size: 16; solid: true; tint: Theme.background0 }
            MouseArea {
              id: playArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: IslandService.togglePlay()
            }
          }
          IslandButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !track.compact
            icon: "skip-forward"
            iconSize: 14
            onClicked: IslandService.next()
          }
        }
      }
  }

  // the quick sliders: each a block of its own
  Component {
    id: volumeBlock
    AudioVolumeRow {
      node: AudioService.sink
      accessibleName: "Output volume"
    }
  }
  Component {
    id: microphoneBlock
    AudioVolumeRow {
      node: AudioService.source
      iconOn: "mic"; iconOff: "mic-off"
      accessibleName: "Microphone volume"
    }
  }
  Component {
    id: brightnessBlock
    KitSliderRow {
      enabled: BrightnessService.available
      icon: BrightnessService.nightActive ? "moon" : "sun"
      iconTint: BrightnessService.nightActive ? Theme.orange : Theme.foreground0
      clickable: true
      onIconClicked: BrightnessService.setNight(!BrightnessService.nightActive)
      accessibleName: "Brightness"
      value: BrightnessService.brightness / 100
      text: BrightnessService.available ? BrightnessService.brightness + "%" : "—"
      onMoved: value => BrightnessService.setBrightness(value * 100)
    }
  }
  Component {
    id: nightBlock
    KitSliderRow {
      icon: "thermometer"
      iconTint: Theme.orange
      accessibleName: "Night light warmth"
      value: (BrightnessService.temperature - BrightnessService.temperatureMin) / (BrightnessService.temperatureMax - BrightnessService.temperatureMin)
      text: BrightnessService.temperature + " K"
      onMoved: value => BrightnessService.setTemperature(BrightnessService.temperatureMin + value * (BrightnessService.temperatureMax - BrightnessService.temperatureMin))
    }
  }
  Component {
    id: dimmingBlock
    KitSliderRow {
      icon: "moon"
      accessibleName: "Screen dimming"
      value: (BrightnessService.gamma - BrightnessService.gammaMin) / (100 - BrightnessService.gammaMin)
      text: BrightnessService.gamma + "%"
      onMoved: value => BrightnessService.setGamma(BrightnessService.gammaMin + value * (100 - BrightnessService.gammaMin))
    }
  }

  Component {
    id: modulesBlock
    // the Hub row's modules: those whose value has a whole as bare rings (Bezel: one value,
    // no plate; Hub › Module chips › Rings), the rest as chips under them
    Column {
      id: modulesColumn
      width: parent.width
      spacing: Theme.sectionGap

      readonly property bool rings: ModuleSettings.get("hub", "chipsRings", true)
      // "id:index" per ring, as a string: it changes when a ring comes or goes, not with a value
      readonly property string cellKey: !rings ? "" : root.ids.map(id => Complications.of(id).map((r, i) => id + ":" + i).join(",")).filter(k => k !== "").join(",")
      readonly property var cells: cellKey === "" ? [] : cellKey.split(",")
      readonly property var chipIds: root.ids.filter(id => !cells.some(c => c.startsWith(id + ":")))

      // the modules behind the rings, made once each, out of sight: a ring's click opens its popup
      property var hosts: ({})
      Repeater {
        model: modulesColumn.cells.map(c => c.split(":")[0]).filter((id, i, list) => list.indexOf(id) === i)
        Loader {
          required property string modelData
          visible: false
          sourceComponent: root.modules[modelData] ?? null
          onLoaded: modulesColumn.hosts[modelData] = item
        }
      }

      Flow {
        width: parent.width
        visible: modulesColumn.cells.length > 0
        spacing: Theme.gapMedium

        Repeater {
          model: modulesColumn.cells
          Item {
            id: cell
            required property string modelData
            readonly property string moduleId: modelData.split(":")[0]
            readonly property var spec: Complications.of(moduleId)[Number(modelData.split(":")[1])] ?? ({})
            width: Theme.ringCell
            height: Theme.ringCell + Theme.gapHair + caption.implicitHeight

            KitRing {
              anchors.horizontalCenter: parent.horizontalCenter
              size: Theme.ringCell
              kind: cell.spec.kind ?? "fill"
              value: cell.spec.value ?? 0
              text: cell.spec.text ?? ""
              icon: cell.spec.icon ?? ""
              tint: cell.spec.tint ?? Theme.foreground1
              on: cell.spec.on ?? true
              quiet: cell.spec.quiet ?? false
              steps: cell.spec.steps ?? 5
              scale: tap.pressed ? 0.96 : 1
              Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
            }
            KitText {
              id: caption
              anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
              width: parent.width + Theme.gapMedium
              horizontalAlignment: Text.AlignHCenter
              text: cell.spec.words ?? ""
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
              elide: Text.ElideRight
            }

            TapHandler {
              id: tap
              acceptedButtons: Qt.LeftButton
              cursorShape: Qt.PointingHandCursor
              onTapped: modulesColumn.hosts[cell.moduleId]?.openPopup?.()
            }
            TapHandler {
              acceptedButtons: Qt.RightButton
              enabled: ShellSettings.barRightSettings
              onTapped: root.settings("hubchip:" + cell.moduleId)
            }
          }
        }
      }

      // the chips wrap to rows by what they hold; Hub › Fill each row stretches the chips of a row
      // to the whole width (the last row too), so the width is always full
      Item {
        id: chips
        width: parent.width
        height: extent
        readonly property var ids: modulesColumn.chipIds

        readonly property bool fill: ModuleSettings.get("hub", "chipsFill", true)
        readonly property int chipHeight: 32
        property var naturals: []                  // each chip's own width, reported by the chip

        function setNatural(i, w) {
          if (naturals[i] === w) return;
          const copy = naturals.slice();
          copy[i] = w;
          naturals = copy;
        }

        // the greedy packing: a chip goes on the row while it fits, else on the next
        readonly property var places: {
          const gap = Theme.gapSmall, out = [];
          let row = [], used = 0, y = 0;
          const flush = () => {
            if (row.length === 0) return;
            const extra = chips.fill ? Math.max(0, chips.width - used) / row.length : 0;
            let x = 0;
            for (const r of row) { out[r.i] = { x: x, y: y, w: r.w + extra }; x += r.w + extra + gap; }
            y += chips.chipHeight + gap;
            row = []; used = 0;
          };
          for (let i = 0; i < chips.ids.length; i++) {
            const w = Math.min(chips.naturals[i] ?? 0, chips.width);
            if (row.length > 0 && used + gap + w > chips.width) flush();
            used += (row.length > 0 ? gap : 0) + w;
            row.push({ i: i, w: w });
          }
          flush();
          return out;
        }
        readonly property real extent: places.length > 0 ? places.reduce((m, p) => Math.max(m, p.y), 0) + chipHeight : 0

        Repeater {
          model: chips.ids

          Rectangle {
            id: chip
            required property string modelData
            required property int index

            readonly property real natural: slot.width + 2 * Theme.gapWide
            onNaturalChanged: chips.setNatural(index, natural)
            Component.onCompleted: chips.setNatural(index, natural)

            x: chips.places[index]?.x ?? 0
            y: chips.places[index]?.y ?? 0
            width: chips.places[index]?.w ?? natural
            height: chips.chipHeight
            radius: Theme.radiusCard
            color: hover.hovered ? Theme.controlHover : Theme.controlFill
            border.width: Theme.frameWidth
            border.color: hover.hovered ? Theme.controlLineHover : Theme.controlLine
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            HoverHandler { id: hover }

            Loader {
              id: slot
              anchors.centerIn: parent
              sourceComponent: root.modules[chip.modelData] ?? null
            }

            // a stretched chip is wider than its module: a click on the rest of it does what the
            // module does (`activate()`, else its popup); a click on the module itself is its own
            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: eventPoint => {
                const p = slot.mapFromItem(chip, eventPoint.position.x, eventPoint.position.y);
                if (slot.contains(p) || !slot.item) return;
                if (slot.item.activate) slot.item.activate();
                else slot.item.openPopup?.();
              }
            }

            TapHandler {
              acceptedButtons: Qt.RightButton
              enabled: ShellSettings.barRightSettings
              onTapped: root.settings("hubchip:" + chip.modelData)
            }
          }
        }
      }
    }
  }

}
