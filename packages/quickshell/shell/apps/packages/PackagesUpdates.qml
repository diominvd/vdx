import QtQuick
import qs.config
import qs.kit

// The Updates tab: the notice, the progress, the pick list and its filters.
Column {
  id: root

  required property var page   // the Packages window
  spacing: Theme.gapGroup

  KitText {
    visible: page.ps.aurError !== ""
    width: parent.width
    wrapMode: Text.WordWrap
    color: Theme.muted
    text: "AUR: " + page.ps.aurError
  }

  // the download, then the install: their progress, under the notice
  Column {
    visible: page.ps.stage !== ""
    width: parent.width
    spacing: Theme.gapSmall

    KitLabel {
      text: page.ps.stage === "downloading" ? "DOWNLOADING" : "INSTALLING"
      value: page.ps.stage === "downloading"
          ? Math.round(page.ps.stagePercent * 100) + "% · " + Format.shortSize(page.ps.stageDone) + " OF " + Format.shortSize(page.ps.stageBytes)
          : ""
    }

    KitBar {
      value: page.ps.stage === "downloading" ? page.ps.stagePercent : 1
      tint: Theme.green
    }
  }

  // the group's header: a box for the whole list, then its caption
  Row {
    visible: page.ps.count > 0
    width: parent.width
    spacing: Theme.gapWide

    PackageCheck {
      anchors.verticalCenter: parent.verticalCenter
      checked: page.ps.pickedUpdates.length === page.ps.count
      partial: page.ps.pickedUpdates.length > 0 && page.ps.pickedUpdates.length < page.ps.count
      onToggled: page.ps.pickAllUpdates(!checked)
    }

    KitLabel {
      width: Math.max(0, parent.width - 28)
      text: "SELECT ALL"
      value: page.ps.pickedUpdates.length + " OF " + page.ps.count + " · " + Format.shortSize(page.ps.repoPickedSize)
    }
  }

  Repeater {
    model: page.ps.pending

    PickRow {
      required property var modelData

      label: modelData.name
      hint: page.hint(modelData.desc)
      checked: page.ps.updPicked[modelData.name] === true
      onToggled: page.ps.pickUpdate(modelData.name, !checked)

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
        text: modelData.from + " → " + modelData.to
        color: Theme.foreground2
      }

      // what the repo update downloads; AUR builds have no download size
      KitText {
        anchors.verticalCenter: parent.verticalCenter
        width: page.sizeWidth
        horizontalAlignment: Text.AlignRight
        text: modelData.aur ? "—" : Format.shortSize(modelData.size)
        color: Theme.muted
      }
    }
  }

  KitText {
    visible: page.ps.count === 0 && !page.ps.checking
    width: parent.width
    color: Theme.muted
    text: "Nothing to update"
  }
}
