import QtQuick

// Busy mark: a braille spinner, like a CLI progress indicator.
KitText {
  id: root

  readonly property string frames: "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  property int frame: 0

  text: frames[frame]

  Timer {
    interval: 80
    repeat: true
    running: root.visible
    onTriggered: root.frame = (root.frame + 1) % root.frames.length
  }
}
