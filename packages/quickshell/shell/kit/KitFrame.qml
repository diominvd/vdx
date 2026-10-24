import QtQuick
import qs.config

// Popup body: flat dark surface, a thin light frame, sharp corners, a padded
// column. Round corners: Theme.radiusSurface. A bar popup opened inside the
// island (`inIsland`, set by the Island) takes the island as its surface and
// frame and draws neither. Children stack vertically and take
// `width: parent.width`. A window showing the same content sets
// `framed: false` and its own `padding`.
Rectangle {
  id: root

  default property alias content: column.data
  property int padding: Theme.popupPadding
  property bool framed: true
  // a window whose first item is a KitHeader: its top sits this much higher
  property int headerInset: 0
  // the same for a window whose last item is text: its line box ends below the ink
  property int bottomInset: 0
  property bool inIsland: false
  // a menu: as wide as its content, not at least Theme.popupWidth (the island's
  // popup width follows this too). The content sets implicitWidth itself.
  property bool fitWidth: false

  implicitWidth: Theme.popupWidth
  implicitHeight: column.implicitHeight + 2 * padding - headerInset - bottomInset
  radius: framed ? Theme.radiusSurface : 0
  color: inIsland ? "transparent" : Theme.background0
  border.width: framed && !inIsland ? Theme.windowFrameWidth : 0
  border.color: Theme.popupFrame

  KitColumn {
    id: column
    x: root.padding
    y: root.padding - root.headerInset
    // Keep the content column valid if the popup is temporarily narrower than its padding.
    width: Math.max(0, root.width - 2 * root.padding)
    spacing: Theme.gapGroup
  }
}
