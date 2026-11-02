import QtQuick
import qs.config

// A dot per choice, in the model's order (left to right; Theme.colourSet is the
// starting set, the theme's colour first): `colours(name)` gives its
// [from, to] gradient (one colour twice), the picked one carries a ring; the user's
// own colours (`customs`) follow the choices.  `exclude` leaves names out.
// `add` is a choice that is empty until something is saved in it: while
// `addEmpty`, its dot is hollow with a plus (choose it to type one).
Row {
  id: root

  property var model: []
  property var exclude: []
  property string picked: ""
  property var colours: name => [Theme.frame, Theme.frame]
  property string add: ""
  property bool addEmpty: false
  property var customs: ShellSettings.shareColours ? ShellSettings.customColours : []   // the user's own colours (#rrggbb), after a divider
  property bool disabled: false               // dimmed, and no click (a choice made elsewhere)

  signal chosen(string name)

  spacing: Theme.gapMedium
  opacity: disabled ? 0.4 : 1

  Repeater {
    model: root.model.filter(name => root.exclude.indexOf(name) < 0).concat(root.customs)

    Rectangle {
      id: swatch
      required property string modelData
      readonly property bool hollow: modelData === root.add && root.addEmpty
      readonly property bool picked: root.picked === modelData
      readonly property var pair: hollow ? [Theme.clear, Theme.clear] : modelData.startsWith("#") ? [modelData, modelData] : root.colours(modelData)

      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      radius: Theme.pill(height)
      border.width: picked ? Theme.ring : hollow ? Theme.hairline : 0
      border.color: picked ? Theme.selectedText : Theme.gray
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: swatch.pair[0] }
        GradientStop { position: 1; color: swatch.pair[1] }
      }

      KitIcon {
        anchors.centerIn: parent
        visible: swatch.hollow
        name: "plus"
        tint: Theme.foreground2
        size: Theme.iconSmall
      }

      MouseArea {
        anchors.fill: parent
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen(swatch.modelData)
      }
    }
  }
}
