import QtQuick
import qs.Commons

// The widgets of one or more layout sections, side by side.
Row {
  id: row

  required property var host
  required property var facade
  required property var sections
  property string screenName: ""
  property bool inNotch: false
  property string fixedEdge: "start"

  spacing: 0

  Repeater {
    model: row.host.entries(row.sections)

    WidgetHost {
      required property var modelData
      host: row.host
      facade: row.facade
      entry: modelData
      screenName: row.screenName
      inNotch: row.inNotch
      fixedEdge: row.fixedEdge
    }
  }
}
