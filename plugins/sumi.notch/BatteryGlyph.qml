import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons

// The battery in the Sumi line style: the case, filled to the charge level,
// with a solid bolt over it while on the charger. The fill turns to the
// signal colour when running low on battery.
Item {
  id: root

  required property var sys
  property real size: 16
  property color color: "white"
  property color lowColor: color

  readonly property real unit: size / 24
  readonly property bool low: sys.batteryLevel < 0.15 && !sys.pluggedIn
  readonly property color ink: low ? lowColor : color

  implicitWidth: size
  implicitHeight: size

  SumiIcon {
    anchors.fill: parent
    name: "batteryCase"
    size: root.size
    color: root.ink
  }

  // The charge, inside the case (x 5–17, y 8.5–15.5 on the 24 grid). Faint
  // under the bolt so the bolt stays legible at bar size.
  Rectangle {
    x: 5 * root.unit
    y: 8.5 * root.unit
    width: Math.max(root.unit, 12 * root.unit * root.sys.batteryLevel)
    height: 7 * root.unit
    radius: root.unit
    color: root.ink
    opacity: root.sys.pluggedIn ? 0.35 : 0.9
    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
  }

  // The bolt, centred on the case and a little taller than it.
  Shape {
    visible: root.sys.pluggedIn
    width: 24
    height: 24
    scale: root.unit * 0.7
    transformOrigin: Item.Center
    x: 11 * root.unit - 12
    y: 12 * root.unit - 12
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
      fillColor: root.ink
      strokeColor: root.ink
      strokeWidth: 1
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths.bolt }
    }
  }
}
