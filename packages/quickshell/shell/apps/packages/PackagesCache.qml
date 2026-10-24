import QtQuick
import qs.config
import qs.kit

// The Cache tab: the cached versions and what clears them.
Column {
  id: root

  required property var page   // the Packages window
  spacing: Theme.gapGroup

  KitLabel {
    text: "LAST UPGRADE"
    value: page.ps.rollbackCount > 0 ? page.ps.rollbackCount + " PACKAGES" : ""
  }

  KitText {
    visible: page.ps.rollbackCount === 0
    width: parent.width
    color: Theme.muted
    text: "No upgrade in the log has its old version cached"
  }

  KitRow {
    visible: page.ps.rollbackCount > 0
    label: "Roll back the whole upgrade"
    hint: "From " + (page.ps.lastUpdate?.date ?? "").slice(0, 16).replace("T", " ")

    KitButton {
      width: Theme.buttonWidth
      anchors.verticalCenter: parent.verticalCenter
      icon: "rotate-ccw"
      text: "Roll back"
      disabled: page.ps.busy
      onClicked: page.ps.rollbackLast()
    }
  }

  Repeater {
    model: page.ps.lastUpdate?.packages ?? []

    KitRow {
      required property var modelData

      label: modelData.name

      KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(260, parent.width - 24))
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: modelData.from + " → " + modelData.to
        color: Theme.foreground2
      }
    }
  }

  KitText {
    visible: (page.ps.lastUpdate?.missing?.length ?? 0) > 0
    width: parent.width
    wrapMode: Text.WordWrap
    color: Theme.muted
    text: "Not cached, so not rolled back: " + (page.ps.lastUpdate?.missing ?? []).map(m => m.name).join(", ")
  }

  KitLabel {
    text: "CACHED VERSIONS"
    value: page.cacheRows.length + " · " + Format.shortSize(page.cacheSize)
  }

  KitSelect {
    width: Math.min(150, parent.width)
    boxWidth: width
    overlay: true
    anchors.right: parent.right
    model: [{ label: "Old versions", value: "old" }, { label: "All versions", value: "all" }]
    current: page.cacheView
    onPicked: value => page.cacheView = value
  }

  Repeater {
    model: page.cacheRows

    KitRow {
      required property var modelData

      readonly property bool current: modelData.version === modelData.installed

      label: modelData.name + "  " + modelData.version
      hint: (current ? "Installed" : "Old") + " · " + page.day(modelData.date)
      labelColor: current ? Theme.foreground0 : Theme.foreground2

      KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(80, Math.max(48, parent.width * 0.2))
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: Format.shortSize(modelData.size)
        color: Theme.muted
      }

      KitButton {
        width: Math.min(Theme.buttonWidth, Math.max(76, parent.width - 80 - Theme.gapMedium * 2))
        anchors.verticalCenter: parent.verticalCenter
        icon: "rotate-ccw"
        text: "Roll back"
        disabled: current || page.ps.busy
        onClicked: page.ps.rollback([modelData.file])
      }
    }
  }

  KitText {
    visible: page.cacheRows.length === 0
    width: parent.width
    color: Theme.muted
    text: page.cacheView === "old" ? "No old versions cached" : "The cache is empty"
  }
}
