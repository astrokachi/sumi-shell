import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The focused app's name, set like a menu bar title. Hovering shows the
// window's own title.
Item {
  id: root

  required property var host
  property color ink: host.foreground

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? String(toplevel.appId || "") : ""
  readonly property string title: toplevel ? String(toplevel.title || "") : ""
  readonly property string name: {
    if (!appId) return ""
    var entry = DesktopEntries.heuristicLookup(appId)
    if (entry && entry.name) return entry.name
    var tail = appId.split(".").pop().replace(/[-_]+/g, " ")
    return tail.charAt(0).toUpperCase() + tail.slice(1)
  }

  implicitWidth: label.text ? Math.min(label.implicitWidth, Style.space(240)) : 0
  implicitHeight: host.barSize
  visible: implicitWidth > 0

  Text {
    id: label
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    textFormat: Text.PlainText
    text: root.name
    elide: Text.ElideRight
    color: root.ink
    font.family: root.host.uiFamily
    font.pixelSize: Style.space(13) + root.host.ds.textBump
    font.weight: Font.DemiBold
  }

  HoverHandler {
    onHoveredChanged: {
      if (hovered && root.title && root.title !== root.name) root.host.showTooltip(root, root.title)
      else root.host.hideTooltip(root)
    }
  }
}
