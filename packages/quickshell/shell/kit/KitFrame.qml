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
  // a menu: as wide as its content, not at least Theme.modulePopupWidth (the island's
  // popup width follows this too). The content sets implicitWidth itself.
  property bool fitWidth: false

  // on a fractional scale (1.2) a 1 px frame and an odd size fall between device pixels
  // and the stroke looks bent: the frame and the size are whole device pixels
  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1

  implicitWidth: Math.ceil(Theme.modulePopupWidth * dpr) / dpr
  implicitHeight: Math.ceil((column.implicitHeight + 2 * padding - headerInset - bottomInset) * dpr) / dpr
  radius: framed ? Theme.radiusSurface : 0
  color: inIsland ? Theme.clear : Theme.background0
  border.width: framed && !inIsland ? Math.max(1, Math.round(Theme.windowFrameWidth * dpr)) / dpr : 0
  border.color: Theme.popupFrame

  KitColumn {
    id: column
    x: root.padding
    y: root.padding - root.headerInset
    width: root.width - 2 * root.padding
    spacing: Theme.sectionGap
  }
}
