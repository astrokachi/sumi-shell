import QtQuick
import qs.Commons

// Bar: how the bar, the notch, the workspace tracker and the clock look.
// Every change applies at once and can be undone from the toast.
Flickable {
  id: page

  required property var ctl
  readonly property var host: ctl.host

  contentHeight: body.implicitHeight
  boundsBehavior: Flickable.StopAtBounds
  clip: true

  function choose(label, apply, revert) {
    apply()
    ctl.notify(label, revert)
  }

  function option(key, value, previous, label) {
    choose(label, function() { page.host.setNotchOption(key, value) },
      function() { page.host.setNotchOption(key, previous) })
  }

  Column {
    id: body
    width: page.width
    leftPadding: Style.space(14)
    rightPadding: Style.space(14)
    bottomPadding: Style.space(8)
    spacing: Style.space(12)

    readonly property real inner: width - leftPadding - rightPadding

    Group {
      title: "Bar"

      ChoiceRow {
        label: "Background"
        options: [{ value: "glassy", label: "Frosted" }, { value: "opaque", label: "Solid" }, { value: "none", label: "Clear" }]
        current: page.host.look
        onPicked: function(value) {
          var previous = page.host.look
          page.choose("Bar background changed", function() { page.host.setBarBackground(value) },
            function() { page.host.setBarBackground(previous) })
        }
      }

      ChoiceRow {
        label: "Size"
        options: [{ value: "small", label: "Small" }, { value: "medium", label: "Medium" }, { value: "large", label: "Large" }]
        current: page.host.barSizeName
        onPicked: function(value) { page.option("size", value, page.host.barSizeName, "Bar size changed") }
      }

      ChoiceRow {
        label: "Dock icons"
        options: [{ value: "line", label: "Line" }, { value: "original", label: "Original" }]
        current: page.host.appIconStyle
        onPicked: function(value) { page.option("appIcons", value, page.host.appIconStyle, "Dock icons changed") }
      }

      SwitchRow {
        label: "Show the focused app's name"
        checked: page.host.showAppName
        onToggled: page.option("showAppName", !page.host.showAppName, page.host.showAppName, "App name " + (page.host.showAppName ? "hidden" : "shown"))
      }
    }

    Group {
      title: "Notch"

      ChoiceRow {
        label: "Shape"
        options: [{ value: "notch", label: "Notch" }, { value: "island", label: "Island" }, { value: "flush", label: "Flush" }]
        current: page.host.notchShape
        onPicked: function(value) { page.option("shape", value, page.host.notchShape, "Notch shape changed") }
      }

      ChoiceRow {
        label: "Color"
        enabled: page.host.notchShape !== "flush"
        options: [{ value: "black", label: "Black" }, { value: "glass", label: "Glass" }, { value: "solid", label: "Solid" }]
        current: page.host.notchTone
        onPicked: function(value) { page.option("tone", value, page.host.notchTone, "Notch color changed") }
      }

      SwitchRow {
        label: "Open at startup"
        checked: page.host.notchConfig.startOpen !== false
        onToggled: {
          var was = page.host.notchConfig.startOpen !== false
          page.choose("Notch " + (was ? "starts folded" : "starts open"),
            function() { page.host.setNotchStartOpen(!was) }, function() { page.host.setNotchStartOpen(was) })
        }
      }
    }

    Group {
      title: "Workspaces"

      ChoiceRow {
        label: "Style"
        options: [{ value: "dots", label: "Dots" }, { value: "numbers", label: "Numbers" }, { value: "pills", label: "Pills" }]
        current: page.host.workspaceStyle
        onPicked: function(value) { page.option("workspaceStyle", value, page.host.workspaceStyle, "Workspace style changed") }
      }

      SwitchRow {
        label: "Only show workspaces in use"
        checked: page.host.workspacesOccupiedOnly
        onToggled: page.option("workspacesOccupiedOnly", !page.host.workspacesOccupiedOnly, page.host.workspacesOccupiedOnly, "Workspaces changed")
      }
    }

    Group {
      title: "Clock"

      SwitchRow {
        label: "24-hour time"
        checked: page.host.clock24
        onToggled: page.option("clock24", !page.host.clock24, page.host.clock24, "Clock changed")
      }

      SwitchRow {
        label: "Show the date"
        checked: page.host.showDate
        onToggled: page.option("showDate", !page.host.showDate, page.host.showDate, "Clock changed")
      }
    }
  }

  component Group: Column {
    id: group
    property string title: ""
    default property alias rows: list.data

    width: body.inner
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: group.title
      color: page.ctl.ink
      opacity: 0.5
      font.family: page.ctl.family
      font.pixelSize: Style.space(11)
      font.weight: Font.DemiBold
    }

    Rectangle {
      width: parent.width
      height: list.implicitHeight
      radius: Style.space(10)
      color: page.ctl.wash

      Column {
        id: list
        width: parent.width
      }
    }
  }

  component ChoiceRow: Item {
    id: row
    property string label: ""
    property var options: []
    property string current: ""
    signal picked(string value)

    width: body.inner
    height: Style.space(42)
    opacity: enabled ? 1 : 0.35

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: row.label
      color: page.ctl.ink
      font.family: page.ctl.family
      font.pixelSize: Style.space(13)
    }

    CtlSegmented {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(216)
      ink: page.ctl.ink
      family: page.ctl.family
      options: row.options
      current: row.current
      enabled: row.enabled
      onPicked: function(value) { row.picked(value) }
    }
  }

  component SwitchRow: Item {
    id: row
    property string label: ""
    property bool checked: false
    signal toggled()

    width: body.inner
    height: Style.space(40)

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.right: parent.right
      height: 1
      color: page.ctl.hairline
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: row.label
      color: page.ctl.ink
      font.family: page.ctl.family
      font.pixelSize: Style.space(13)
    }

    CtlSwitch {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      ink: page.ctl.ink
      knob: page.ctl.knob
      checked: row.checked
      onToggled: row.toggled()
    }
  }
}
