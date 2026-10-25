import QtQuick
import qs.Commons

// Plugins: the services, panels and overlays that run in the shell, yours
// first. Bar widgets live under Layout. Essentials show as Required.
Flickable {
  id: page

  required property var ctl

  contentHeight: body.implicitHeight
  boundsBehavior: Flickable.StopAtBounds
  clip: true

  readonly property var groups: [
    { title: "Your plugins", items: ctl.plugins.filter(function(plugin) { return !plugin.firstParty }) },
    { title: "Omarchy", items: ctl.plugins.filter(function(plugin) { return plugin.firstParty }) }
  ]

  Column {
    id: body
    width: page.width
    leftPadding: Style.space(14)
    rightPadding: Style.space(14)
    bottomPadding: Style.space(8)
    spacing: Style.space(12)

    Text {
      visible: page.ctl.plugins.length === 0
      width: body.width - body.leftPadding - body.rightPadding
      horizontalAlignment: Text.AlignHCenter
      topPadding: Style.space(20)
      textFormat: Text.PlainText
      text: "Loading plugins…"
      color: page.ctl.ink
      opacity: 0.4
      font.family: page.ctl.family
      font.pixelSize: Style.space(12)
    }

    Repeater {
      model: page.groups

      Column {
        id: group
        required property var modelData
        width: body.width - body.leftPadding - body.rightPadding
        spacing: Style.space(6)
        visible: modelData.items.length > 0

        Text {
          textFormat: Text.PlainText
          text: group.modelData.title
          color: page.ctl.ink
          opacity: 0.5
          font.family: page.ctl.family
          font.pixelSize: Style.space(11)
          font.weight: Font.DemiBold
        }

        Rectangle {
          width: parent.width
          height: rows.implicitHeight
          radius: Style.space(10)
          color: page.ctl.wash

          Column {
            id: rows
            width: parent.width

            Repeater {
              model: group.modelData.items

              PluginRow {
                required property var modelData
                required property int index
                ctl: page.ctl
                plugin: modelData
                first: index === 0
                width: rows.width
              }
            }
          }
        }
      }
    }
  }
}
