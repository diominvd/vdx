import QtQuick
import Quickshell
import qs.config
import qs.kit

// Notifications › App colours: rules that give an app's avatar a colour. A rule is
// a piece of the app's name and a colour from the list; the first one that fits
// wins, an app with none gets its own stable colour. Stored in the module's
// settings as `appColours` [{app, colour}].
Column {
  id: root

  readonly property var rules: ModuleSettings.get("notifications", "appColours", []) ?? []
  readonly property KitSeen known: KitSeen {}

  // every app that has notified since the shell started: the names a rule has to fit
  readonly property var heard: {
    const out = [];
    for (const n of NotificationsService.items)
      if (n.app !== "" && !out.includes(n.app)) out.push(n.app);
    return out;
  }

  // the heard apps no rule covers yet
  readonly property var appNames: Array.from(new Set(heard.concat(DesktopEntries.applications.values.map(a => a.name)))).filter(a => a !== "").sort((a, b) => a.localeCompare(b))

  readonly property var unruled: heard.filter(a => !rules.some(r => (r.app ?? "") !== "" && a.toLowerCase().includes(r.app.toLowerCase())))

  function save(list) { ModuleSettings.set("notifications", "appColours", list); }

  // a rule left without a name (the window closed while it was typed) is dropped when the page opens
  Component.onCompleted: if (rules.some(r => (r.app ?? "") === "")) save(rules.filter(r => (r.app ?? "") !== ""))
  function add(app) {
    const next = Theme.autoColourName(app);
    save(rules.concat([{ app: app, colour: app === "" ? Theme.appPalette[rules.length % Theme.appPalette.length] : next }]));
  }
  function edit(i, change) { save(rules.map((r, j) => j === i ? Object.assign({}, r, change) : r)); }
  function remove(i) { save(rules.filter((r, j) => j !== i)); }

  KitLabel { text: "APP COLOURS"; about: "Each app's avatar has its own colour; a rule picks yours" }

  // one row that unfolds, as in Live activities: the rules and the way to add one are its options
  KitReorderList {
    id: fold
    width: root.width
    keys: ["colours"]
    rowHeight: Theme.rowHeight
    bodyGap: 0

    delegate: KitFoldRow {
      id: row
      label: "Avatar colours"
      hint: root.rules.length === 0 ? "Every app gets its own colour" : root.rules.length + (root.rules.length === 1 ? " rule" : " rules") + " · give an app's avatar a colour"
      draggable: false
      hasSwitch: false
      flush: true
      sunken: true
      checked: true
      foldable: true

      Column {
        x: row.edge
        width: parent.width - row.edge - Theme.gapLoose
        spacing: Theme.settingsRowInset

      Repeater {
        model: root.rules.length

        Item {
          id: rule
          required property int index
          readonly property var rl: root.rules[index] ?? ({ app: "", colour: "blue" })

          width: parent ? parent.width : 0
          readonly property int base: Theme.rowHeight
          // the hairline between two options and the gap under it: the list's gap above is the other half
          readonly property int lead: index > 0 ? Theme.dividerThickness + Theme.settingsRowInset : 0
          // while the name is typed, the apps that fit it stand under the field as choices
          readonly property string typed: field.typing ? typer.text.trim().toLowerCase() : ""
          readonly property var ruled: root.rules.map(r => (r.app ?? "").toLowerCase())
          readonly property var suggestions: {
            if (!field.typing) return [];
            const fit = root.appNames.filter(a => !ruled.includes(a.toLowerCase()) && (typed === "" || a.toLowerCase().includes(typed)));
            // names that start with what is typed first, apps that notified before the installed ones
            const rank = a => (a.toLowerCase().startsWith(typed) ? 0 : 2) + (root.heard.includes(a) ? 0 : 1);
            return fit.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b)).slice(0, 8);
          }
          readonly property int pickRows: suggestions.length > 0 ? 1 : 0
          height: lead + base + (pickRows > 0 ? picks.height + Theme.gapSmall : 0)
          Behavior on height { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
          clip: true
          KitAppear { target: rule; seen: root.known; key: "rule" + rule.index }

          Rectangle {
            visible: rule.index > 0
            x: -row.edge
            width: parent.width + row.edge + Theme.gapLoose
            height: Theme.dividerThickness
            color: Theme.dividerColor
          }

          Item { id: line; y: rule.lead; width: parent.width; height: rule.base }

          Rectangle {
            id: sample
            anchors { left: parent.left; verticalCenter: line.verticalCenter }
            width: 28
            height: 28
            radius: Theme.radiusFor(height)
            color: Theme.mix(Theme.background0, Theme.paletteColour(rule.rl.colour), 0.22)
            KitText {
              anchors.centerIn: parent
              text: (rule.rl.app || "?").slice(0, 1).toUpperCase()
              color: Theme.paletteColour(rule.rl.colour)
              font.weight: Font.Medium
            }
          }

          // the name: the app as its notifications call it; a rule for another app is typed once, kept
          // in the field until Enter or Save (saving per letter would swap the field for text)
          Item {
            id: field
            property bool typing: rule.rl.app === ""
            anchors { left: sample.right; leftMargin: Theme.gapWide; verticalCenter: line.verticalCenter }
            width: Math.max(110, rule.width * 0.28)
            height: Theme.controlHeight

            function commit() {
              if (!typing) return;
              const name = typer.text.trim();
              if (name === "") root.remove(rule.index);
              else { typing = false; root.edit(rule.index, { app: name }); }
            }

            MouseArea {
              anchors.fill: parent
              enabled: !field.typing
              cursorShape: Qt.PointingHandCursor
              onClicked: { typer.text = rule.rl.app; field.typing = true; typer.input.forceActiveFocus(); }
            }
            KitText {
              visible: !field.typing
              anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
              text: rule.rl.app
              elide: Text.ElideRight
            }
            KitInput {
              id: typer
              visible: field.typing
              anchors.fill: parent
              placeholder: "App name"
              Component.onCompleted: if (field.typing) input.forceActiveFocus()
              completions: field.typing ? rule.suggestions : []
              passKeys: [Qt.Key_Escape]
              onAccepted: field.commit()
              onKeyPassed: key => {
                if (key === Qt.Key_Escape) { typer.text = rule.rl.app; field.commit(); }
              }
            }
          }

          KitButton {
            id: saveName
            visible: field.typing
            anchors { right: away.left; rightMargin: Theme.gapSmall; verticalCenter: line.verticalCenter }
            icon: "check"
            Accessible.name: "Save app name"
            onClicked: field.commit()
          }

          KitButton {
            id: away
            anchors { right: parent.right; verticalCenter: line.verticalCenter }
            icon: "x"
            Accessible.name: "Remove the rule"
            onClicked: root.remove(rule.index)
          }

          // the choices: a tap fills the name and keeps the rule
          Flow {
            id: picks
            visible: rule.pickRows > 0
            x: sample.width + Theme.gapWide
            y: rule.lead + rule.base
            width: parent.width - x
            spacing: Theme.gapSmall
            Repeater {
              model: rule.suggestions
              Rectangle {
                id: chip
                required property string modelData
                height: 26
                width: chipText.implicitWidth + 2 * Theme.gapMedium
                radius: Theme.radiusFor(height)
                color: chipArea.containsMouse ? Theme.controlHover : Theme.fillOn(true)
                border.width: Theme.frameWidth
                border.color: Theme.controlLine
                Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
                KitText { id: chipText; anchors.centerIn: parent; text: chip.modelData; font.pixelSize: Theme.fontSize - 1; color: Theme.foreground2 }
                MouseArea {
                  id: chipArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { typer.text = chip.modelData; field.commit(); }
                }
              }
            }
          }

          KitColourRow {
            anchors { left: field.right; leftMargin: Theme.gapWide; right: saveName.visible ? saveName.left : away.left; rightMargin: Theme.gapWide; verticalCenter: line.verticalCenter }
            always: true
            names: Theme.colourSet
            picked: rule.rl.colour
            colours: name => [Theme.paletteColour(name), Theme.paletteColour(name)]
            onChosen: value => root.edit(rule.index, { colour: value })
          }
        }
      }

      Rectangle { visible: root.rules.length > 0; x: -row.edge; width: parent.width + row.edge + Theme.gapLoose; height: Theme.dividerThickness; color: Theme.dividerColor }

      // an app that has notified (its name is exact), or another one typed by hand; with nobody
      // to pick from the list would hold one choice, so a button says it
      KitRow {
        visible: root.unruled.length === 0
        label: "Add a rule"
        hint: "Part of the name, first match wins"
        KitButton { icon: "plus"; text: "Add rule"; onClicked: root.add("") }
      }

      KitSelect {
        visible: root.unruled.length > 0
        label: "Add a rule"
        hint: "A notifying app, or one by name"
        placeholder: "Choose an app…"
        model: root.unruled.map(a => ({ label: a, value: a })).concat([{ label: "Another app…", value: "" }])
        current: "\u0000"
        onPicked: value => root.add(value)
      }
      }
    }
  }

  KitGrouper {}
}
