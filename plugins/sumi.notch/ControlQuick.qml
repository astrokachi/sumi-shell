import QtQuick
import qs.Commons

// Controls: switches for things that stay on or off, then one-shot actions.
// Restart and Shut Down ask once more before they go.
Flickable {
  id: page

  required property var ctl

  contentHeight: body.implicitHeight
  boundsBehavior: Flickable.StopAtBounds
  clip: true

  Column {
    id: body
    width: page.width
    leftPadding: Style.space(14)
    rightPadding: Style.space(14)
    spacing: Style.space(14)

    readonly property real inner: width - leftPadding - rightPadding

    Grid {
      columns: 2
      spacing: Style.space(8)

      Repeater {
        model: page.ctl.toggles

        Rectangle {
          id: tile
          required property var modelData
          width: (body.inner - Style.space(8)) / 2
          height: Style.space(52)
          radius: Style.space(12)
          color: tileHover.hovered ? Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.1) : page.ctl.wash
          Behavior on color { ColorAnimation { duration: 120 } }

          Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(30)
            height: width
            radius: width / 2
            color: tile.modelData.on ? page.ctl.ink : Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.12)
            Behavior on color { ColorAnimation { duration: 160 } }

            CtlGlyph {
              anchors.centerIn: parent
              text: tile.modelData.glyph
              size: Style.space(17)
              color: tile.modelData.on ? page.ctl.knob : page.ctl.ink
            }
          }

          Column {
            anchors.left: badge.right
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: tile.modelData.label
              elide: Text.ElideRight
              color: page.ctl.ink
              font.family: page.ctl.family
              font.pixelSize: Style.space(12)
              font.weight: Font.DemiBold
            }

            Text {
              textFormat: Text.PlainText
              text: tile.modelData.on ? "On" : "Off"
              color: page.ctl.ink
              opacity: 0.55
              font.family: page.ctl.family
              font.pixelSize: Style.space(11)
            }
          }

          HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: { page.ctl.confirmId = ""; tile.modelData.run() } }
        }
      }
    }

    Grid {
      columns: 4
      spacing: Style.space(8)

      Repeater {
        model: page.ctl.actions

        Rectangle {
          id: action
          required property var modelData
          readonly property bool asking: page.ctl.confirmId === modelData.id
          width: (body.inner - 3 * Style.space(8)) / 4
          height: Style.space(64)
          radius: Style.space(12)
          color: asking ? page.ctl.ink
            : actionHover.hovered ? Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.1) : page.ctl.wash
          Behavior on color { ColorAnimation { duration: 120 } }

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(8)
            spacing: Style.space(4)

            CtlGlyph {
              anchors.horizontalCenter: parent.horizontalCenter
              text: action.modelData.glyph
              size: Style.space(20)
              color: action.asking ? page.ctl.knob : page.ctl.ink
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: action.asking ? "Confirm" : action.modelData.label
              elide: Text.ElideRight
              color: action.asking ? page.ctl.knob : page.ctl.ink
              font.family: page.ctl.family
              font.pixelSize: Style.space(11)
              font.weight: action.asking ? Font.DemiBold : Font.Medium
            }
          }

          HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: page.ctl.runAction(action.modelData) }
        }
      }
    }

    Text {
      visible: page.ctl.confirmId !== ""
      width: body.inner
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: "Click again to confirm, or anywhere else to cancel."
      color: page.ctl.ink
      opacity: 0.5
      font.family: page.ctl.family
      font.pixelSize: Style.space(11)
    }
  }

  // A click on empty space cancels a pending confirmation.
  TapHandler {
    enabled: page.ctl.confirmId !== ""
    onTapped: page.ctl.confirmId = ""
  }
}
