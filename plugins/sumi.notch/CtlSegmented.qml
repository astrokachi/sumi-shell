import QtQuick
import qs.Commons

// A row of mutually exclusive choices, the current one raised.
Rectangle {
  id: control

  required property var options
  property string current: ""
  property color ink: "white"
  property string family: "Inter"
  signal picked(string value)

  readonly property int index: {
    for (var i = 0; i < options.length; i++) if (options[i].value === current) return i
    return -1
  }

  implicitWidth: Style.space(210)
  height: Style.space(26)
  radius: Style.space(7)
  color: Qt.rgba(ink.r, ink.g, ink.b, 0.07)

  Rectangle {
    visible: control.index >= 0
    x: Style.space(2) + control.index * (control.width - Style.space(4)) / Math.max(1, control.options.length)
    y: Style.space(2)
    width: (control.width - Style.space(4)) / Math.max(1, control.options.length)
    height: control.height - Style.space(4)
    radius: Style.space(5)
    color: Qt.rgba(control.ink.r, control.ink.g, control.ink.b, 0.16)
    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  Row {
    anchors.fill: parent
    anchors.margins: Style.space(2)

    Repeater {
      model: control.options

      Item {
        id: option
        required property var modelData
        width: parent.width / Math.max(1, control.options.length)
        height: parent.height

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: option.modelData.label
          color: control.ink
          opacity: control.current === option.modelData.value ? 1 : 0.6
          font.family: control.family
          font.pixelSize: Style.space(11)
          font.weight: control.current === option.modelData.value ? Font.DemiBold : Font.Medium
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (control.current !== option.modelData.value) control.picked(option.modelData.value) }
      }
    }
  }
}
