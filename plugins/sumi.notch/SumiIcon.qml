import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons

// One icon from the Sumi set, drawn as a stroke at any size. The stroke is
// in 24-grid units, so it thins with the icon the way the mockups do.
Item {
  id: root

  property string name: ""
  property real size: 16
  property color color: "white"
  property real stroke: 1.4

  implicitWidth: size
  implicitHeight: size

  Shape {
    width: 24
    height: 24
    scale: root.size / 24
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.stroke
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg { path: Icons.paths[root.name] || "" }
    }
  }
}
