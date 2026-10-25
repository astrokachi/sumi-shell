import QtQuick
import qs.Commons

// Four bars that dance while something plays.
Row {
  id: root

  property bool running: false
  property color color: "white"

  spacing: Style.space(2)
  height: Style.space(14)

  Repeater {
    model: 4

    Rectangle {
      id: bar
      required property int index
      property real level: 0.3

      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(3)
      height: Math.max(width, root.height * level)
      radius: width / 2
      color: root.color

      Behavior on level { NumberAnimation { duration: 260; easing.type: Easing.InOutSine } }

      Timer {
        interval: 240 + bar.index * 37
        repeat: true
        running: root.running && root.visible
        onTriggered: bar.level = 0.25 + Math.random() * 0.75
        onRunningChanged: if (!running) bar.level = 0.3
      }
    }
  }
}
