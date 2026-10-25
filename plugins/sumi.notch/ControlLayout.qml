import QtQuick
import qs.Commons
import "NotchLayout.js" as NotchLayout

// Layout: the bar's widgets as chips, group by group in the order they run
// along the bar. Drag a chip to rearrange it, within a group or into
// another; drag it into the tray at the bottom to switch it off, or drag
// one from the tray onto the bar to switch it on.
Item {
  id: page

  required property var ctl
  // What the page would take without scrolling, for the panel to size to.
  readonly property real contentHeight: flick.contentHeight + hint.height

  readonly property var groups: NotchLayout.sections(ctl.layout).map(function(key) {
    return { key: key, title: NotchLayout.TITLES[key], ids: (ctl.layout[key] || []).map(function(entry) { return entry.id }) }
  })

  // ---- dragging ---------------------------------------------------------------

  // The chip being dragged, where the pointer is (in page coordinates), and
  // where it would land: a section key, or "off" for the tray.
  property string dragId: ""
  property point dragPoint: Qt.point(0, 0)
  property string dropKey: ""
  property int dropIndex: -1
  // Where to draw the insertion mark, in page coordinates.
  property rect dropMark: Qt.rect(0, 0, 0, 0)

  // Drop areas register here: { key, box, flow }.
  property var targets: []

  function registerTarget(target) { targets = targets.concat([target]) }
  function unregisterTarget(box) { targets = targets.filter(function(target) { return target.box !== box }) }

  function chipsIn(flow) {
    var out = []
    for (var i = 0; i < flow.children.length; i++) {
      var child = flow.children[i]
      if (child && "widgetId" in child && child.widgetId !== dragId && child.visible) out.push(child)
    }
    return out
  }

  // Works out the drop spot under the pointer, and the mark that shows it.
  function track(scenePoint) {
    dragPoint = page.mapFromItem(null, scenePoint.x, scenePoint.y)
    dropKey = ""
    dropIndex = -1
    for (var t = 0; t < targets.length; t++) {
      var target = targets[t]
      var inBox = target.box.mapFromItem(null, scenePoint.x, scenePoint.y)
      // A little slack above and below, so the gap between groups counts.
      if (inBox.x < 0 || inBox.x > target.box.width || inBox.y < -Style.space(8) || inBox.y > target.box.height + Style.space(8)) continue
      dropKey = target.key
      if (target.key === "off") return

      var flow = target.flow
      var p = flow.mapFromItem(null, scenePoint.x, scenePoint.y)
      var chips = chipsIn(flow)
      var index = 0
      for (var c = 0; c < chips.length; c++) {
        var chip = chips[c]
        var above = chip.y + chip.height < p.y
        var sameRow = p.y >= chip.y - Style.space(3) && p.y <= chip.y + chip.height + Style.space(3)
        if (above || (sameRow && chip.x + chip.width / 2 < p.x)) index = c + 1
      }
      dropIndex = index

      var mark
      if (chips.length === 0) mark = flow.mapToItem(page, 0, 0)
      else if (index < chips.length) mark = chips[index].mapToItem(page, -Style.space(4), 0)
      else mark = chips[chips.length - 1].mapToItem(page, chips[chips.length - 1].width + Style.space(2), 0)
      dropMark = Qt.rect(mark.x, mark.y, 2, Style.space(26))
      return
    }
  }

  function drop() {
    var id = dragId
    var key = dropKey
    var index = dropIndex
    dragId = ""
    dropKey = ""
    if (!id || !key) return
    if (key === "off") {
      if (ctl.widgetOn(id)) ctl.toggleWidget(id)
      return
    }
    ctl.placeWidget(id, key, index)
  }

  // Scrolls while a chip is held near the top or bottom edge.
  Timer {
    interval: 16
    repeat: true
    running: page.dragId !== ""
    onTriggered: {
      var edge = Style.space(36)
      var y = page.dragPoint.y - flick.y
      var step = 0
      if (y < edge) step = -Math.ceil((edge - y) / 4)
      else if (y > flick.height - edge) step = Math.ceil((y - flick.height + edge) / 4)
      if (step === 0) return
      flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + step))
    }
  }

  // ---- content ----------------------------------------------------------------

  Flickable {
    id: flick
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: hint.top
    contentHeight: body.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    // Dragging belongs to the chips; the wheel scrolls.
    interactive: false
    clip: true

    WheelHandler {
      onWheel: function(event) {
        var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - delta))
      }
    }

    Column {
      id: body
      width: parent.width
      leftPadding: Style.space(14)
      rightPadding: Style.space(14)
      bottomPadding: Style.space(8)
      spacing: Style.space(12)

      readonly property real inner: width - leftPadding - rightPadding

      Repeater {
        model: page.groups

        Column {
          id: group
          required property var modelData
          width: body.inner
          spacing: Style.space(6)

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
            id: box
            width: parent.width
            height: Math.max(chips.implicitHeight + Style.space(12), Style.space(38))
            radius: Style.space(10)
            color: page.dropKey === group.modelData.key ? Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.11) : page.ctl.wash
            border.width: page.dropKey === group.modelData.key ? 1 : 0
            border.color: Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.25)
            Behavior on color { ColorAnimation { duration: 100 } }

            Component.onCompleted: page.registerTarget({ key: group.modelData.key, box: box, flow: chips })
            Component.onDestruction: page.unregisterTarget(box)

            Text {
              anchors.centerIn: parent
              visible: group.modelData.ids.length === 0
              textFormat: Text.PlainText
              text: "Empty · drop a widget here"
              color: page.ctl.ink
              opacity: 0.35
              font.family: page.ctl.family
              font.pixelSize: Style.space(11)
            }

            Flow {
              id: chips
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(6)

              Repeater {
                model: group.modelData.ids

                Chip {
                  required property string modelData
                  widgetId: modelData
                }
              }
            }
          }
        }
      }

      // Everything that is not on the bar; also where chips go to switch off.
      Column {
        width: body.inner
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: "Not on the bar"
          color: page.ctl.ink
          opacity: 0.5
          font.family: page.ctl.family
          font.pixelSize: Style.space(11)
          font.weight: Font.DemiBold
        }

        Rectangle {
          id: tray
          width: parent.width
          height: Math.max(offChips.implicitHeight + Style.space(12), Style.space(38))
          radius: Style.space(10)
          color: page.dropKey === "off" ? Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.11) : "transparent"
          border.width: 1
          border.color: Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, page.dropKey === "off" ? 0.3 : 0.12)

          Component.onCompleted: page.registerTarget({ key: "off", box: tray, flow: offChips })
          Component.onDestruction: page.unregisterTarget(tray)

          Text {
            anchors.centerIn: parent
            visible: page.ctl.offIds.length === 0
            textFormat: Text.PlainText
            text: "Drop a widget here to take it off the bar"
            color: page.ctl.ink
            opacity: 0.35
            font.family: page.ctl.family
            font.pixelSize: Style.space(11)
          }

          Flow {
            id: offChips
            anchors.fill: parent
            anchors.margins: Style.space(6)
            spacing: Style.space(6)

            Repeater {
              model: page.ctl.offIds

              Chip {
                required property string modelData
                widgetId: modelData
                off: true
              }
            }
          }
        }
      }
    }
  }

  Text {
    id: hint
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    height: Style.space(22)
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: "Drag to rearrange · drag down to take off the bar"
    color: page.ctl.ink
    opacity: 0.4
    font.family: page.ctl.family
    font.pixelSize: Style.space(11)
  }

  // Where the dragged chip will land.
  Rectangle {
    visible: page.dragId !== "" && page.dropKey !== "" && page.dropKey !== "off"
    x: page.dropMark.x
    y: page.dropMark.y
    width: 2
    height: page.dropMark.height
    radius: 1
    color: page.ctl.ink
  }

  // The chip under the pointer while dragging.
  Rectangle {
    visible: page.dragId !== ""
    x: page.dragPoint.x - width / 2
    y: page.dragPoint.y - height / 2
    width: ghostLabel.implicitWidth + Style.space(20)
    height: Style.space(28)
    radius: height / 2
    color: page.ctl.ink
    scale: 1.04

    Text {
      id: ghostLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: page.dragId ? page.ctl.nameFor(page.dragId) : ""
      color: page.ctl.knob
      font.family: page.ctl.family
      font.pixelSize: Style.space(12)
      font.weight: Font.DemiBold
    }
  }

  component Chip: Rectangle {
    id: chip
    property string widgetId: ""
    property bool off: false
    readonly property bool lifted: page.dragId === widgetId

    width: chipRow.implicitWidth + Style.space(18)
    height: Style.space(26)
    radius: height / 2
    opacity: lifted ? 0.25 : 1
    color: chipHover.hovered && page.dragId === "" ? Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.16)
      : Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, off ? 0 : 0.08)
    border.width: off ? 1 : 0
    border.color: Qt.rgba(page.ctl.ink.r, page.ctl.ink.g, page.ctl.ink.b, 0.2)
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: Style.space(3)

      CtlGlyph {
        anchors.verticalCenter: parent.verticalCenter
        text: chip.off ? "add" : "drag_indicator"
        size: Style.space(14)
        color: page.ctl.ink
        opacity: chip.off ? 0.8 : 0.4
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: page.ctl.nameFor(chip.widgetId)
        color: page.ctl.ink
        opacity: chip.off ? 0.7 : 1
        font.family: page.ctl.family
        font.pixelSize: Style.space(12)
        font.weight: Font.Medium
      }
    }

    HoverHandler { id: chipHover; cursorShape: page.dragId !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor }

    DragHandler {
      target: null
      dragThreshold: 3
      grabPermissions: PointerHandler.CanTakeOverFromAnything
      onActiveChanged: {
        if (active) {
          page.dragId = chip.widgetId
          page.track(centroid.scenePosition)
        } else if (page.dragId === chip.widgetId) {
          page.drop()
        }
      }
      onCentroidChanged: if (active) page.track(centroid.scenePosition)
    }

    // A click on a chip in the tray puts it back on the bar.
    TapHandler {
      enabled: chip.off
      onTapped: page.ctl.toggleWidget(chip.widgetId)
    }
  }
}
