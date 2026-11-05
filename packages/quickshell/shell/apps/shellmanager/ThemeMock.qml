import QtQuick
import Quickshell.Widgets
import qs.config

// A theme as a small desktop: a window with a sidebar, text and chips, drawn in
// the theme's own colours over its picture when wallpapers are pictures. Laid
// out for 170 px wide and scaled to any width.
ClippingRectangle {
  id: root

  required property string name

  readonly property var c: ThemeService.colors[name] ?? ({})
  readonly property real k: width / 170

  function col(role) { return c[role] ?? Theme[role]; }

  // a card's share of the radius, not its height's: a small card stays a card, not a pill
  radius: Math.round(Theme.radiusCard * 0.6)
  color: col("background1")

  // the theme's own picture (Appearance › Wallpaper › Image)
  Image {
    anchors.fill: parent
    readonly property string rel: ShellSettings.wallpaperMode === "image" ? WallpaperService.imageFor(root.name) : ""
    visible: rel !== "" && status === Image.Ready
    source: rel !== "" ? "file://" + WallpaperService.pathOf(rel) : ""
    sourceSize.width: 340
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  Rectangle {
    id: win
    x: parent.width * 0.12
    y: parent.height * 0.16
    width: parent.width
    height: parent.height
    radius: Math.round(Theme.radiusCard * 0.4)
    color: root.col("background0")
    border.width: Theme.hairline
    border.color: root.col("background3")

    Row {
      x: 8 * root.k; y: 7 * root.k
      spacing: 3 * root.k
      Repeater {
        model: ["red", "yellow", "green"]
        Rectangle { required property string modelData; width: 5 * root.k; height: width; radius: Theme.pill(height); color: root.col(modelData) }
      }
    }

    Rectangle {
      x: 1; y: 18 * root.k
      width: win.width * 0.24
      height: win.height
      color: root.col("background1")

      Column {
        x: 8 * root.k; y: 8 * root.k
        spacing: 6 * root.k
        Rectangle { width: 22 * root.k; height: 3 * root.k; radius: Theme.pill(height); color: root.col("foreground0") }
        Rectangle { width: 16 * root.k; height: 3 * root.k; radius: Theme.pill(height); color: root.col("gray") }
        Rectangle { width: 19 * root.k; height: 3 * root.k; radius: Theme.pill(height); color: root.col("gray") }
      }
    }

    Column {
      x: win.width * 0.24 + 10 * root.k; y: 26 * root.k
      spacing: 8 * root.k
      Rectangle { width: 32 * root.k; height: 3 * root.k; radius: Theme.pill(height); color: root.col("foreground2") }
      Row {
        spacing: 5 * root.k
        Repeater {
          model: ["blue", "green", "purple"]
          Rectangle {
            required property string modelData
            width: 24 * root.k; height: 16 * root.k
            radius: Theme.radiusFor(height)
            color: root.col("background2")
            Rectangle { anchors.centerIn: parent; width: 9 * root.k; height: 3 * root.k; radius: Theme.pill(height); color: root.col(parent.modelData) }
          }
        }
      }
      Rectangle { width: 42 * root.k; height: 3 * root.k; radius: Theme.pill(height); color: root.col("background3") }
    }
  }
}
