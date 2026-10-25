import QtQuick
import qs.config
import qs.kit

// Themes, as in a terminal's theme picker: the themes listed on the left (a
// small desktop in its colours, name, its seven colours, a check on the active one), a large preview of the picked
// one on the right — code, a prompt, controls and its palette, drawn in its own
// colours. A search over the list; ↑ / ↓ (or a click) previews, Enter or Apply switches the desktop to
// it, Esc goes back to the active one. Fills the window: the panes scroll.
Row {
  id: root

  // the window's fixed header shows these
  readonly property string icon: "palette"
  readonly property string title: "Themes"
  readonly property string subtitle: (ThemeService.current || "—").toUpperCase() + " · " + ThemeService.bases.length + " THEMES · " + (ThemeService.light ? "LIGHT" : "DARK")
  readonly property var jumps: []

  // the theme in the preview; Apply makes it the active one
  property string selected: ThemeService.current
  readonly property bool changed: selected !== ThemeService.current
  // the preview's own mode (only the preview: the desktop and Apply keep the active one's)
  property bool previewLight: ThemeService.light
  readonly property string previewed: ThemeService.variant(selected, previewLight)
  readonly property var c: ThemeService.colors[previewed] ?? ({})
  readonly property var accents: ["red", "orange", "yellow", "green", "aqua", "blue", "purple"]

  function col(role) { return c[role] ?? Theme[role]; }
  function colOf(name, role) { return ThemeService.colors[name]?.[role] ?? Theme[role]; }
  function isLight(name) {
    const bg = ThemeService.colors[name]?.background0;
    return bg !== undefined && Theme.luminance(bg) > 0.4;
  }
  // "Dark · warm": its background's lightness and cast (warm, cool, green, rose or neutral)
  function character(name) {
    const bg = Qt.color(colOf(name, "background1"));
    const h = bg.hsvHue, sat = bg.hsvSaturation;
    const cast = h < 0 || sat < 0.12 ? "neutral" : h < 0.2 ? "warm" : h < 0.45 ? "green" : h < 0.8 ? "cool" : "rose";
    return (isLight(name) ? "Light" : "Dark") + " · " + cast;
  }
  property string query: ""
  // the themes in the active mode (a light one's twin when Light), found by name
  readonly property var shown: ThemeService.inMode.filter(n => ThemeService.baseOf(n).includes(query.trim().toLowerCase()))

  function step(d) {
    const list = shown, i = list.indexOf(selected);
    selected = list[Math.max(0, Math.min(list.length - 1, i + d))] ?? selected;
    themeList.positionViewAtIndex(list.indexOf(selected), ListView.Contain);
  }
  function apply() { if (changed && !ThemeService.busy) ThemeService.apply(selected); }

  spacing: Theme.gapGroup

  // shown: the keys go to the list, the preview starts at the active theme
  onVisibleChanged: if (visible) { selected = ThemeService.current; previewLight = ThemeService.light; search.input.forceActiveFocus(); }

  // ---- the search and the list ----
  Column {
    id: side
    width: 270
    height: parent.height - Theme.windowPadding
    spacing: Theme.gapMedium

    KitInput {
      id: search
      width: parent.width
      placeholder: "Search…"
      text: root.query
      onTextEdited: {
        root.query = text;
        if (root.shown.length > 0 && !root.shown.includes(root.selected)) root.selected = root.shown[0];
      }
      Keys.onUpPressed: root.step(-1)
      Keys.onDownPressed: root.step(1)
      Keys.onReturnPressed: root.apply()
      Keys.onEnterPressed: root.apply()
      Keys.onEscapePressed: event => {
        if (root.query !== "") { root.query = ""; search.text = ""; }
        else if (root.changed) root.selected = ThemeService.current;
        else event.accepted = false;
      }
    }

    Rectangle {
      id: listBox
      width: parent.width
      height: parent.height - search.height - parent.spacing
      radius: Theme.radiusCard
      color: Theme.background1
      border.width: Theme.frameWidth
      border.color: Theme.background2

      ListView {
        id: themeList
        anchors { fill: parent; margins: Theme.gapSmall }
        clip: true
        spacing: Theme.gapTight
        boundsBehavior: Flickable.StopAtBounds
        model: root.shown

        delegate: Rectangle {
          id: item
          required property string modelData
          readonly property bool picked: modelData === root.selected
          readonly property bool active: modelData === ThemeService.current

          width: themeList.width
          height: 56
          radius: Theme.radiusControl
          color: picked ? Theme.background3 : area.containsMouse ? Theme.background2 : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          // the card: a small desktop in its colours
          ThemeMock {
            id: thumb
            anchors { left: parent.left; leftMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
            width: 72
            height: 44
            name: item.modelData
          }

          Column {
            id: info
            anchors { left: thumb.right; leftMargin: Theme.gapLoose; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapHair

            KitText {
              width: parent.width
              elide: Text.ElideRight
              text: ThemeService.baseOf(item.modelData)
              color: item.picked || item.active ? Theme.foreground0 : Theme.foreground2
              font.weight: item.picked ? Font.ExtraBold : Font.DemiBold
            }

            // what sets it apart: light or dark, and the cast of its greys
            KitText {
              width: parent.width
              elide: Text.ElideRight
              text: root.character(item.modelData)
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }
          }

          Item {
            id: mark
            anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
            width: 16
            height: 16
            KitSpinner { anchors.centerIn: parent; visible: ThemeService.applying === item.modelData }
            KitIcon {
              anchors.centerIn: parent
              visible: item.active && ThemeService.applying !== item.modelData
              name: "check"
              tint: Theme.green
              size: Theme.iconSmall
            }
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.selected = item.modelData; search.input.forceActiveFocus(); }
            onDoubleClicked: root.apply()
          }
        }
      }

      KitText {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.gapWide
        visible: root.shown.length === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Theme.muted
        text: root.query.trim() === ""
          ? "No themes available in this appearance."
          : "No themes found. Try another name or clear the search."
      }
    }

  }

  // ---- the preview ----
  Column {
    width: parent.width - side.width - parent.spacing
    height: side.height
    spacing: Theme.gapWide

    // its name, and Apply while it is not the active one
    Item {
      width: parent.width
      height: Theme.controlHeight

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight
        KitText { text: ThemeService.baseOf(root.selected); font.weight: Font.ExtraBold; font.pixelSize: Theme.fontSize + 2 }
        KitText {
          text: (root.isLight(root.previewed) ? "Light" : "Dark")
                + (root.changed ? " · enter applies, esc back" : " · in use")
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }
      }

      Row {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapSmall

      // the preview in the theme's dark or light twin
      KitSegments {
        accessibleName: "Theme preview appearance"
        width: 150
        model: [{ label: "Dark", value: false }, { label: "Light", value: true }]
        current: root.previewLight
        onPicked: value => root.previewLight = value
      }

      KitButton {
        visible: root.changed
        icon: "check"
        text: "Apply"
        busy: ThemeService.busy
        onClicked: root.apply()
      }
      }
    }

    // the theme drawn in its own colours
    Rectangle {
      id: well
      width: parent.width
      height: parent.height - y
      radius: Theme.radiusCard
      color: root.col("background0")
      border.width: Theme.hairline
      border.color: root.col("background2")
      clip: true
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal } }

      Column {
        anchors { fill: parent; margins: Theme.gapGroup }
        spacing: Theme.gapGroup

        // code, highlighted: [text, role] spans per line
        Column {
          spacing: Theme.gapHair
          Repeater {
            model: [
              [["# switch the desktop to a theme", "gray"]],
              [["def ", "red"], ["apply", "green"], ["(", "foreground1"], ["name", "blue"], [": ", "foreground1"], ["str", "yellow"], [") -> ", "foreground1"], ["bool", "yellow"], [":", "foreground1"]],
              [["    colours ", "foreground1"], ["= ", "orange"], ["load", "aqua"], ["(", "foreground1"], ["f\"themes/{name}\"", "green"], [")", "foreground1"]],
              [["    if ", "red"], ["len", "aqua"], ["(colours) ", "foreground1"], ["< ", "orange"], ["18", "purple"], [":", "foreground1"]],
              [["        return ", "red"], ["False", "purple"]],
              [["    return ", "red"], ["write", "aqua"], ["(colours, ", "foreground1"], ["\"~/.config\"", "green"], [")", "foreground1"]]
            ]
            Row {
              required property var modelData
              Repeater {
                model: parent.modelData
                Text {
                  required property var modelData
                  text: modelData[0]
                  color: root.col(modelData[1])
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize
                }
              }
            }
          }
        }

        // a prompt
        Rectangle {
          width: parent.width
          height: 1
          color: root.col("background2")
        }

        Row {
          Repeater {
            model: [["~/.dotfiles", "blue"], [" main", "purple"], [" ❯ ", "green"], ["git status ", "foreground0"], ["-sb", "gray"]]
            Text {
              required property var modelData
              text: modelData[0]
              color: root.col(modelData[1])
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.weight: modelData[1] === "green" ? Font.Bold : Font.Normal
            }
          }
        }

        Row {
          spacing: Theme.gapWide
          Repeater {
            model: [["M", "yellow", "install.py"], ["A", "green", "ThemesPage.qml"], ["D", "red", "Display.qml"]]
            Row {
              required property var modelData
              spacing: Theme.gapSmall
              Text { text: parent.modelData[0]; color: root.col(parent.modelData[1]); font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.weight: Font.Bold }
              Text { text: parent.modelData[2]; color: root.col("foreground2"); font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
            }
          }
        }

        // controls: a raised card with buttons, a picked chip, a switch
        Rectangle {
          width: parent.width
          height: 44
          radius: Theme.radiusCard
          color: root.col("background1")

          Row {
            anchors { left: parent.left; leftMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapMedium

            Repeater {
              model: [["Button", "background2", "foreground0"], ["Picked", "background3", "foreground0"], ["Error", "background2", "red"]]
              Rectangle {
                required property var modelData
                width: chipText.implicitWidth + 20
                height: 24
                radius: Theme.radiusFor(height)
                color: root.col(modelData[1])
                Text {
                  id: chipText
                  anchors.centerIn: parent
                  text: parent.modelData[0]
                  color: root.col(parent.modelData[2])
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize - 1
                  font.weight: Font.DemiBold
                }
              }
            }
          }

          Rectangle {
            anchors { right: parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
            width: 34
            height: 18
            radius: Theme.pill(height)
            color: root.col("foreground0")
            Rectangle {
              anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
              width: 12
              height: 12
              radius: Theme.pill(height)
              color: root.col("background0")
            }
          }
        }

        // the palette, named
        Row {
          width: parent.width
          spacing: Theme.gapSmall

          Repeater {
            model: root.accents
            Column {
              required property string modelData
              width: (well.width - 2 * Theme.gapGroup - 6 * Theme.gapSmall) / 7
              spacing: Theme.gapHair
              Rectangle {
                width: parent.width
                height: 22
                radius: Theme.pill(height)
                color: root.col(parent.modelData)
              }
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: parent.modelData
                color: root.col("foreground2")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
              }
            }
          }
        }

        // the tones, background to text, as the colours above
        Row {
          width: parent.width
          spacing: Theme.gapSmall

          Repeater {
            model: [["background0", "bg 0"], ["background1", "bg 1"], ["background2", "bg 2"], ["background3", "bg 3"],
                    ["gray", "gray"], ["foreground2", "fg 2"], ["foreground0", "fg 0"]]
            Column {
              required property var modelData
              width: (well.width - 2 * Theme.gapGroup - 6 * Theme.gapSmall) / 7
              spacing: Theme.gapHair
              Rectangle {
                width: parent.width
                height: 22
                radius: Theme.pill(height)
                color: root.col(parent.modelData[0])
                border.width: Theme.hairline
                border.color: root.col("background2")
              }
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: parent.modelData[1]
                color: root.col("foreground2")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
              }
            }
          }
        }
      }
    }

    KitText {
      visible: ThemeService.error !== ""
      width: parent.width
      text: ThemeService.error
      color: Theme.red
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }
  }
}
