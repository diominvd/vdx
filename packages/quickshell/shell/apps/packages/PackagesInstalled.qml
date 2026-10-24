import QtQuick
import qs.config
import qs.kit

// The Installed tab: the search, the filters and the pick list.
Column {
  id: root

  required property var page   // the Packages window
  spacing: Theme.gapGroup

  // Search and filters share a line when possible; Flow wraps them on narrow
  // windows instead of squeezing the search field to zero or clipping controls.
  Flow {
    width: parent.width
    spacing: Theme.gapMedium

    KitInput {
      id: field
      width: Math.max(160, parent.width - filterBox.width - sortBox.width - parent.spacing * 2)
      placeholder: "Search by name, description or program…"
      onTextChanged: page.query = text.trim().toLowerCase()
    }

    KitSelect {
      id: filterBox
      width: Math.min(150, Math.max(72, (parent.width - 96) / 2))
      boxWidth: width
      overlay: true
      model: [{ label: "All types", value: "all" }, { label: "Apps", value: "apps" },
              { label: "Pacman", value: "repo" }, { label: "AUR", value: "aur" }]
      current: page.filter
      onPicked: value => page.filter = value
    }

    KitSelect {
      id: sortBox
      width: Math.min(150, Math.max(72, (parent.width - 96) / 2))
      boxWidth: width
      overlay: true
      model: [{ label: "By name", value: "name" }, { label: "By size", value: "size" }, { label: "By date", value: "date" }]
      current: page.sortBy
      onPicked: value => page.sortBy = value
    }
  }

  Row {
    visible: page.shown.length > 0
    width: parent.width
    spacing: Theme.gapWide

    PackageCheck {
      anchors.verticalCenter: parent.verticalCenter
      accessibleName: qsTr("Select all shown packages")
      checked: page.shown.length > 0 && page.shownPicked === page.shown.length
      partial: page.shownPicked > 0 && page.shownPicked < page.shown.length
      onToggled: page.ps.pickMany(page.shown.map(p => p.name), !checked)
    }

    KitLabel {
      width: Math.max(0, parent.width - 28)
      text: "SELECT ALL SHOWN"
      value: page.shownPicked + " PICKED"
    }
  }

  Repeater {
    model: page.shown

    PickRow {
      required property var modelData

      label: modelData.name
      hint: page.hint(modelData.desc)
      checked: page.ps.picked[modelData.name] === true
      onToggled: page.ps.pick(modelData.name, !checked)

      KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: page.sourceWidth
        text: page.source(modelData)
        color: modelData.aur ? Theme.foreground2 : Theme.muted
      }

      KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: page.versionWidth
        elide: Text.ElideLeft
        text: modelData.version
        color: Theme.foreground2
      }

      KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: page.sizeWidth
        horizontalAlignment: Text.AlignRight
        text: page.sortBy === "date" ? page.day(modelData.date) : Format.shortSize(modelData.size)
        color: Theme.foreground2
      }
    }
  }

  KitText {
    visible: page.shown.length === 0
    width: parent.width
    color: Theme.muted
    text: "Nothing matches"
  }
}
