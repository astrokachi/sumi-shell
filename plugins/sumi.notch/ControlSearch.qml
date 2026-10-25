import QtQuick
import qs.Commons
import "NotchLayout.js" as NotchLayout

// Search results across controls, widgets and plugins, each usable in place.
Flickable {
  id: page

  required property var ctl

  contentHeight: body.implicitHeight
  boundsBehavior: Flickable.StopAtBounds
  clip: true

  function matches(text) {
    return String(text || "").toLowerCase().indexOf(ctl.needle) >= 0
  }

  readonly property var controls: ctl.toggles.concat(ctl.actions).filter(function(item) {
    return page.matches(item.label) || page.matches(item.id)
  })
  readonly property var widgets: ctl.registryIds.filter(function(id) {
    return NotchLayout.HIDDEN.indexOf(id) < 0 && (page.matches(ctl.nameFor(id)) || page.matches(id))
  }).sort(function(a, b) { return ctl.nameFor(a).localeCompare(ctl.nameFor(b)) })
  readonly property var pluginHits: ctl.plugins.filter(function(plugin) {
    return page.matches(plugin.name) || page.matches(plugin.id)
  })

  Column {
    id: body
    width: page.width
    leftPadding: Style.space(14)
    rightPadding: Style.space(14)
    bottomPadding: Style.space(8)
    spacing: Style.space(12)

    readonly property real inner: width - leftPadding - rightPadding

    Text {
      visible: page.controls.length + page.widgets.length + page.pluginHits.length === 0
      width: body.inner
      horizontalAlignment: Text.AlignHCenter
      topPadding: Style.space(24)
      textFormat: Text.PlainText
      text: "Nothing matches “" + page.ctl.query.trim() + "”"
      color: page.ctl.ink
      opacity: 0.45
      font.family: page.ctl.family
      font.pixelSize: Style.space(12)
    }

    // Controls.
    Section {
      title: "Controls"
      count: page.controls.length

      Repeater {
        model: page.controls

        ResultRow {
          required property var modelData
          required property int index
          first: index === 0
          glyph: modelData.glyph
          label: page.ctl.confirmId === modelData.id ? "Click again to confirm" : modelData.label
          detail: modelData.on === undefined ? "" : (modelData.on ? "On" : "Off")
          onActivated: {
            if (modelData.run) modelData.run()
            else page.ctl.runAction(modelData)
          }
        }
      }
    }

    // Widgets.
    Section {
      title: "Widgets"
      count: page.widgets.length

      Repeater {
        model: page.widgets

        ResultRow {
          required property string modelData
          required property int index
          first: index === 0
          glyph: "widgets"
          label: page.ctl.nameFor(modelData)
          detail: {
            var at = NotchLayout.locate(page.ctl.layout, modelData)
            return at ? NotchLayout.TITLES[at.section] : "Not on the bar"
          }
          switchable: true
          checked: page.ctl.widgetOn(modelData)
          onActivated: page.ctl.toggleWidget(modelData)
        }
      }
    }

    // Plugins.
    Section {
      title: "Plugins"
      count: page.pluginHits.length

      Repeater {
        model: page.pluginHits

        ResultRow {
          required property var modelData
          required property int index
          first: index === 0
          glyph: "extension"
          label: modelData.name
          detail: modelData.kinds + (modelData.locked ? " · required" : "")
          switchable: true
          locked: modelData.locked
          checked: modelData.enabled
          onActivated: page.ctl.setPlugin(modelData, !modelData.enabled)
        }
      }
    }
  }

  component Section: Column {
    id: section
    property string title: ""
    property int count: 0
    default property alias rows: list.data

    width: body.inner
    spacing: Style.space(6)
    visible: count > 0

    Text {
      textFormat: Text.PlainText
      text: section.title
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

  component ResultRow: Item {
    id: result
    property bool first: false
    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool switchable: false
    property bool checked: false
    property bool locked: false
    signal activated()

    width: body.inner
    height: Style.space(42)

    Rectangle {
      visible: !result.first
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.leftMargin: Style.space(40)
      anchors.right: parent.right
      height: 1
      color: page.ctl.hairline
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Style.space(8)
      color: resultHover.hovered && !result.switchable ? Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.08) : "transparent"
    }

    CtlGlyph {
      id: icon
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: result.glyph
      size: Style.space(18)
      color: page.ctl.ink
      opacity: 0.8
    }

    Column {
      anchors.left: icon.right
      anchors.leftMargin: Style.space(10)
      anchors.right: toggle.visible ? toggle.left : parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: result.label
        elide: Text.ElideRight
        color: page.ctl.ink
        font.family: page.ctl.family
        font.pixelSize: Style.space(13)
      }

      Text {
        visible: result.detail !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: result.detail
        elide: Text.ElideRight
        color: page.ctl.ink
        opacity: 0.45
        font.family: page.ctl.family
        font.pixelSize: Style.space(11)
      }
    }

    CtlSwitch {
      id: toggle
      visible: result.switchable
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      ink: page.ctl.ink
      knob: page.ctl.knob
      checked: result.checked
      locked: result.locked
      onToggled: result.activated()
    }

    HoverHandler { id: resultHover; enabled: !result.switchable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: !result.switchable; onTapped: result.activated() }
  }
}
