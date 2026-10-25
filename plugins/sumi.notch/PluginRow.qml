import QtQuick
import qs.Commons

// One plugin: its name, what kind it is, and its switch.
Item {
  id: row

  required property var ctl
  required property var plugin
  property bool first: false

  height: Style.space(44)

  Rectangle {
    visible: !row.first
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: parent.right
    height: 1
    color: row.ctl.hairline
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: control.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.plugin.name
      elide: Text.ElideRight
      color: row.ctl.ink
      font.family: row.ctl.family
      font.pixelSize: Style.space(13)
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.plugin.kinds + (row.plugin.locked ? " · required" : "")
      elide: Text.ElideRight
      color: row.ctl.ink
      opacity: 0.45
      font.family: row.ctl.family
      font.pixelSize: Style.space(11)
    }
  }

  CtlSwitch {
    id: control
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    ink: row.ctl.ink
    knob: row.ctl.knob
    checked: row.plugin.enabled
    locked: row.plugin.locked
    onToggled: row.ctl.setPlugin(row.plugin, !row.plugin.enabled)
  }
}
