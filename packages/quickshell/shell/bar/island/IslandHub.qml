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

// The hub: profile and uptime, media, quick sliders and module chips.
// A chip is the module's own face: its click opens the module's popup in the
// island, a right click its options.
Item {
  id: root

  required property PanelWindow bar
  property var modules: ({})

  // the blocks are built while the hub shows, and while a module's popup opened from it is up:
  // the popup belongs to the tile or the chip, which must not go with the hub's fade
  property bool keep: false
  readonly property bool built: visible || keep

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
    return id === "activities" ? IslandService.activities.some(k => ["recording", "update", "backup", "timer"].includes(k)) : id === "tiles" ? tileIds.length > 0 : id === "player" ? hasPlayer : id === "night" ? !ModuleSettings.get("hub", "nightAuto", true) || BrightnessService.nightActive
         : id === "modules" ? ids.length > 0 : true;
  }
  // Material: the quick sliders next to each other share one tonal section
  readonly property var sliderIds: ["volume", "microphone", "brightness", "night", "dimming"]
  readonly property var shownBlocks: root.built ? HubBlocks.order.filter(id => HubBlocks.shown(id) && wants(id)) : []
  function inRun(id, step) {
    const next = shownBlocks[shownBlocks.indexOf(id) + step];
    return next !== undefined && sliderIds.indexOf(next) >= 0;
  }
  function blockOf(id) {
    return ({ activities: activitiesBlock, tiles: tilesBlock, week: weekBlock, player: playerBlock, volume: volumeBlock, microphone: microphoneBlock, brightness: brightnessBlock, night: nightBlock, dimming: dimmingBlock, modules: modulesBlock })[id] ?? null;
  }

  // the month is a page of the hub: the island grows to it and back
  property bool calendarOpen: false
  onVisibleChanged: if (!visible) calendarOpen = false
  implicitHeight: (calendarOpen ? calendarPage.implicitHeight : column.implicitHeight) + 2 * Theme.gapGroup

  Timer {
    interval: 30000
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

    // ---- header ----
    Item {
      width: parent.width
      height: 38
      ClippingRectangle {
        id: avatar
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 34; height: 34
        radius: Theme.radiusFor(height)
        color: Theme.pickFill
        Image {
          id: avatarImage
          anchors.fill: parent
          source: root.avatarPath ? "file://" + root.avatarPath : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(68, 68)
          visible: status === Image.Ready
        }
        KitText {
          anchors.centerIn: parent
          visible: !avatarImage.visible
          text: root.userName.slice(0, 1).toUpperCase()
          font.weight: Font.Medium
        }
      }
      Column {
        anchors { left: avatar.right; leftMargin: Theme.gapMedium; right: settingsButton.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapTight
        KitText { width: parent.width; text: root.userName; font.weight: Font.Medium; elide: Text.ElideRight }
        KitText {
          width: parent.width
          visible: root.subtitleMode !== "none"
          text: (root.subtitleMode === "both" ? root.uptime(SysmonService.uptime) + " · " : "") + Qt.formatDateTime(root.now, "d MMM")
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 1
          elide: Text.ElideRight
        }
      }

      IslandButton {
        id: settingsButton
        anchors { right: powerButton.left; rightMargin: Theme.gapSmall }
        icon: "settings"
        iconSize: 16
        onClicked: root.manager()
      }

      IslandButton {
        id: powerButton
        anchors.right: parent.right
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
        active: root.built && HubBlocks.shown(modelData) && root.wants(modelData)
        visible: active
        sourceComponent: Theme.material && root.sliderIds.indexOf(modelData) >= 0 ? sliderSection : root.blockOf(modelData)

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
    id: activitiesBlock
    HubActivities { width: parent.width }
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
        color: Theme.material ? Theme.sectionFill : Theme.controlFill
        border.width: Theme.frameWidth
        border.color: Theme.controlLine

        function clock(s) { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

        // a click on the card (not its buttons) opens the popup of what plays
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: BarLayout.openModule(IslandService.family === "radio" ? "tuner" : IslandService.family === "music" ? "music" : "media")
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
            text: IslandService.title || "Not playing"
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
            // Material: the filled primary, a shade lighter under the pointer
            color: Theme.material ? (playArea.containsMouse ? Theme.mix(Theme.primary, Theme.inkOn(Theme.primary), 0.08) : Theme.primary)
              : playArea.containsMouse ? Theme.foreground0 : Theme.foreground1

            KitIcon { anchors.centerIn: parent; name: IslandService.playing ? "pause" : "play"; size: 16; solid: true; tint: Theme.material ? Theme.inkOn(Theme.primary) : Theme.background0 }
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

  // Material: a slider block in its part of the sliders' section (the section's gaps are its own)
  Component {
    id: sliderSection
    Item {
      id: section
      readonly property string block: parent ? parent.modelData : ""
      readonly property bool first: !root.inRun(block, -1)
      readonly property bool last: !root.inRun(block, 1)
      readonly property int pad: Theme.sectionPad
      implicitHeight: inner.height + (first ? pad : 0) + (last ? pad : 0)

      Rectangle {
        width: parent.width
        // down over the column's gap to the next slider: one surface
        height: parent.height + (section.last ? 0 : column.spacing)
        topLeftRadius: section.first ? Theme.radiusCard : 0
        topRightRadius: topLeftRadius
        bottomLeftRadius: section.last ? Theme.radiusCard : 0
        bottomRightRadius: bottomLeftRadius
        color: Theme.sectionFill
      }
      Loader {
        id: inner
        x: section.pad
        y: section.first ? section.pad : 0
        width: parent.width - 2 * section.pad
        sourceComponent: root.blockOf(section.block)
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
      // the chips wrap to rows by what they hold; Hub › Fill each row stretches the chips of a row
      // to the whole width (the last row too), so the width is always full
      Item {
        id: chips
        width: parent.width
        height: extent

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
          for (let i = 0; i < root.ids.length; i++) {
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
          model: root.ids

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
            radius: Theme.material ? Theme.radiusFor(height) : Theme.radiusCard
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
