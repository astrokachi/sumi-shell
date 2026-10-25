import QtQuick
import qs.Commons

// An on/off switch: the track fills with ink when on.
Rectangle {
  id: control

  property color ink: "white"
  property color knob: "black"
  property bool checked: false
  // Shown but not changeable, for things the shell cannot run without.
  property bool locked: false
  signal toggled()

  width: Style.space(34)
  height: Style.space(20)
  radius: height / 2
  color: checked ? ink : Qt.rgba(ink.r, ink.g, ink.b, 0.18)
  opacity: locked ? 0.35 : 1
  Behavior on color { ColorAnimation { duration: 160 } }

  Rectangle {
    width: parent.height - Style.space(4)
    height: width
    radius: width / 2
    anchors.verticalCenter: parent.verticalCenter
    x: control.checked ? parent.width - width - Style.space(2) : Style.space(2)
    color: control.checked ? control.knob : "white"
    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  HoverHandler { enabled: !control.locked; cursorShape: Qt.PointingHandCursor }
  TapHandler { enabled: !control.locked; onTapped: control.toggled() }
}
