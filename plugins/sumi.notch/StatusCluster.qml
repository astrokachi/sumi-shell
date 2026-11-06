import QtQuick
import qs.Commons

// The bar's status glyphs, as in the Sumi design: Bluetooth, Wi-Fi and
// sound (faint when off), the battery with its percentage, and the button
// that opens the control center. Any of them opens it.
Row {
  id: cluster

  required property var host
  required property string screenName
  readonly property var sys: host.system
  readonly property color ink: host.foreground
  readonly property color faint: Qt.rgba(ink.r, ink.g, ink.b, 0.4)
  readonly property bool centerOpen: host.controlCenterScreen === screenName

  spacing: Style.space(14)
  height: host.barSize

  SumiIcon {
    anchors.verticalCenter: parent.verticalCenter
    name: "bluetooth"
    size: 15
    color: cluster.sys.bluetoothOn ? cluster.ink : cluster.faint
  }

  SumiIcon {
    anchors.verticalCenter: parent.verticalCenter
    name: "wifi"
    size: 15
    color: cluster.sys.wifiConnected ? cluster.ink : cluster.faint
  }

  SumiIcon {
    anchors.verticalCenter: parent.verticalCenter
    name: cluster.sys.muted ? "mute" : "volume"
    size: 15
    color: cluster.sys.muted ? cluster.faint : cluster.ink
  }

  Row {
    visible: cluster.sys.hasBattery
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    BatteryGlyph {
      anchors.verticalCenter: parent.verticalCenter
      size: 16
      sys: cluster.sys
      color: cluster.ink
      lowColor: cluster.host.ds.signal
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: Math.round(cluster.sys.batteryLevel * 100) + "%"
      color: cluster.ink
      font.family: cluster.host.ds.fontUi
      font.pixelSize: 13 + cluster.host.ds.textBump
      font.features: { "tnum": 1 }
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(26)
    height: Style.space(22)
    radius: cluster.host.ds.rChip
    color: Qt.rgba(cluster.ink.r, cluster.ink.g, cluster.ink.b, cluster.centerOpen || buttonHover.hovered ? 0.14 : 0.09)
    Behavior on color { ColorAnimation { duration: 120 } }

    SumiIcon {
      anchors.centerIn: parent
      name: "sliders"
      size: 15
      color: cluster.ink
    }

    HoverHandler { id: buttonHover }
  }

  // The whole cluster is one target.
  TapHandler {
    onTapped: cluster.host.toggleControlCenter(cluster.screenName)
  }
  HoverHandler { cursorShape: Qt.PointingHandCursor }
}
