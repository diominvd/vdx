import QtQuick
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
    bodyGap: Theme.settingsRowInset

    delegate: KitFoldRow {
      id: row
      label: "Avatar colours"
      hint: root.rules.length === 0 ? "Every app gets its own colour" : root.rules.length + (root.rules.length === 1 ? " rule" : " rules") + " · give an app's avatar a colour"
      draggable: false
      hasSwitch: false
      flush: true
      checked: true
      foldable: true

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
          height: lead + base
          KitAppear { target: rule; seen: root.known; key: "rule" + rule.index }

          Rectangle {
            visible: rule.index > 0
            width: parent.width
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
          // in the field until Enter or leaving it (a rule saved per letter would swap the field for text)
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
              onAccepted: field.commit()
              input.onActiveFocusChanged: if (!input.activeFocus) field.commit()
            }
          }

          KitButton {
            id: away
            anchors { right: parent.right; verticalCenter: line.verticalCenter }
            icon: "x"
            Accessible.name: "Remove the rule"
            onClicked: root.remove(rule.index)
          }

          KitColourRow {
            anchors { left: field.right; leftMargin: Theme.gapWide; right: away.left; rightMargin: Theme.gapWide; verticalCenter: line.verticalCenter }
            always: true
            names: Theme.colourSet
            picked: rule.rl.colour
            colours: name => [Theme.paletteColour(name), Theme.paletteColour(name)]
            onChosen: value => root.edit(rule.index, { colour: value })
          }
        }
      }

      Rectangle { visible: root.rules.length > 0; width: parent.width; height: Theme.dividerThickness; color: Theme.dividerColor }

      // an app that has notified (its name is exact), or another one typed by hand; with nobody
      // to pick from the list would hold one choice, so a button says it
      KitRow {
        visible: root.unruled.length === 0
        label: "Add a rule"
        hint: "Part of the name; first match wins"
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

  KitGrouper {}
}
