import QtQuick
import Quickshell
import qs.Commons as Commons

// "Thu 23 Oct  9:41 PM": the date quiet, the time in full ink.
Row {
  id: root

  property color ink: "#f5f5f7"
  property string family: "Inter"
  property bool hour12: true
  property bool showDate: true

  readonly property var locale: Qt.locale(Commons.I18n.formatLocale)

  spacing: Commons.Style.space(7)

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    visible: root.showDate
    text: clock.date.toLocaleDateString(root.locale, "ddd d MMM")
    color: root.ink
    opacity: 0.62
    font.family: root.family
    font.pixelSize: Commons.Style.space(13)
    font.weight: Font.Medium
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: clock.date.toLocaleTimeString(root.locale, root.hour12 ? "h:mm AP" : "HH:mm")
    color: root.ink
    font.family: root.family
    font.pixelSize: Commons.Style.space(13)
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
  }
}
