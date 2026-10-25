import QtQuick
import QtQuick.Shapes

// The notch silhouette: a body hanging from the top edge whose top corners
// flare out into the edge (the "ears") and whose bottom corners are round.
Shape {
  id: root

  property color color: "#000000"
  property real ear: 8
  property real radius: 12

  readonly property real r: Math.min(radius, height / 2, (width - 2 * ear) / 2)

  preferredRendererType: Shape.CurveRenderer
  antialiasing: true

  ShapePath {
    strokeWidth: -1
    fillColor: root.color
    startX: 0
    startY: 0

    PathArc {
      x: root.ear; y: root.ear
      radiusX: root.ear; radiusY: root.ear
      direction: PathArc.Clockwise
    }
    PathLine { x: root.ear; y: root.height - root.r }
    PathArc {
      x: root.ear + root.r; y: root.height
      radiusX: root.r; radiusY: root.r
      direction: PathArc.Counterclockwise
    }
    PathLine { x: root.width - root.ear - root.r; y: root.height }
    PathArc {
      x: root.width - root.ear; y: root.height - root.r
      radiusX: root.r; radiusY: root.r
      direction: PathArc.Counterclockwise
    }
    PathLine { x: root.width - root.ear; y: root.ear }
    PathArc {
      x: root.width; y: 0
      radiusX: root.ear; radiusY: root.ear
      direction: PathArc.Clockwise
    }
    PathLine { x: 0; y: 0 }
  }
}
