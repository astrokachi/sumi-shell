import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// The workspace tracker, in one of three styles (bar.notch.workspaceStyle):
// dots, where the one on screen stretches into a capsule; numbers; or pills,
// numbers with the one on screen filled. Ones with windows are stronger,
// empty ones faint, and empty ones can be left out altogether.
Item {
  id: root

  required property var host
  required property var screen
  property color ink: host.foreground
  readonly property string style: host.workspaceStyle

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property string monitorName: monitor ? String(monitor.name || "") : ""
  readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  // Omarchy numbers each monitor's workspaces in its own block of ten.
  readonly property int block: activeId > 0 ? Math.floor((activeId - 1) / 10) : 0

  readonly property var ids: {
    var base = block * 10
    var list = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > base && id <= base + 10 && list.indexOf(id) === -1) list.push(id)
    }
    list.sort(function(a, b) { return a - b })
    if (host.workspacesOccupiedOnly) {
      void(Hyprland.workspaces.values)
      list = list.filter(function(id) { return id === root.activeId || root.occupied(id) })
    }
    return list
  }

  function occupied(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws.id !== id) continue
      if (ws.toplevels && ws.toplevels.values) return ws.toplevels.values.length > 0
      return !!ws.lastIpcObject && ws.lastIpcObject.windows > 0
    }
    return false
  }

  function focusWorkspace(id) {
    host.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: dots.implicitWidth
  implicitHeight: host.barSize

  Row {
    id: dots
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.style === "dots" ? Style.space(6) : Style.space(2)

    Repeater {
      model: root.ids

      Item {
        id: dot
        required property int modelData
        readonly property bool active: modelData === root.activeId
        readonly property bool filled: root.occupied(modelData)
        // Its number within this monitor's block of ten.
        readonly property string label: String(((modelData - 1) % 10) + 1)
        readonly property real strength: active ? 1 : filled ? 0.7 : (hover.hovered ? 0.5 : 0.3)

        width: root.style === "dots" ? pill.width
          : root.style === "pills" ? Math.max(Style.space(20), number.implicitWidth + Style.space(8))
          : Math.max(Style.space(12), number.implicitWidth + Style.space(4))
        height: root.host.barSize

        // Dots.
        Rectangle {
          id: pill
          visible: root.style === "dots"
          anchors.verticalCenter: parent.verticalCenter
          width: dot.active ? Style.space(18) : Style.space(6)
          height: Style.space(6)
          radius: height / 2
          color: root.ink
          opacity: dot.strength

          Behavior on width { SpringAnimation { spring: 5; damping: 0.42; epsilon: 0.2 } }
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Pills: the active one filled.
        Rectangle {
          visible: root.style === "pills"
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: Style.space(20)
          radius: Style.space(6)
          color: root.ink
          opacity: dot.active ? 1 : hover.hovered ? 0.12 : 0
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Numbers, for numbers and pills.
        Text {
          id: number
          visible: root.style !== "dots"
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: dot.label
          color: root.style === "pills" && dot.active ? Qt.rgba(root.host.background.r, root.host.background.g, root.host.background.b, 1) : root.ink
          opacity: root.style === "pills" && dot.active ? 1 : dot.strength
          font.family: root.host.uiFamily
          font.pixelSize: Style.space(12) + root.host.ds.textBump
          font.weight: Font.Medium
          font.features: { "tnum": 1 }
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

        MouseArea {
          anchors.fill: parent
          anchors.leftMargin: -Style.space(3)
          anchors.rightMargin: -Style.space(3)
          onClicked: root.focusWorkspace(dot.modelData)
        }
      }
    }
  }

  // Scrolling over the dots steps through workspaces.
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property real accumulated: 0
    onWheel: function(event) {
      accumulated += event.angleDelta.y
      if (Math.abs(accumulated) < 120) return
      var step = accumulated > 0 ? -1 : 1
      accumulated = 0
      var index = root.ids.indexOf(root.activeId)
      var next = root.ids[Math.max(0, Math.min(root.ids.length - 1, index + step))]
      if (next !== undefined && next !== root.activeId) root.focusWorkspace(next)
    }
  }
}
