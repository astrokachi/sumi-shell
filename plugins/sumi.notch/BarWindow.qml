import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One screen's bar: the Omarchy menu, workspaces and app name on the left,
// the notch in the middle, status widgets on the right.
PanelWindow {
  id: win

  required property var modelData
  required property var host

  readonly property string screenName: modelData ? String(modelData.name || "") : ""

  screen: modelData
  anchors { top: true; left: true; right: true }
  implicitHeight: host.barSize
  margins.top: host.barHidden ? -host.barSize : 0
  exclusionMode: host.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto
  visible: !remapGuard.remapping
  color: "transparent"
  surfaceFormat.opaque: false

  // The stock bar's namespace, so Omarchy's glass blur and layer rules apply.
  WlrLayershell.namespace: "omarchy-bar"
  WlrLayershell.layer: WlrLayer.Top

  ScreenMoveRemap {
    id: remapGuard
    window: win
  }

  BarFacade {
    id: stripFacade
    host: win.host
  }

  Rectangle {
    anchors.fill: parent
    color: win.host.transparent ? "transparent" : win.host.glassy ? win.host.glassBackground : win.host.background
    Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    // A hairline along the bottom edge.
    Rectangle {
      visible: !win.host.transparent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: Qt.rgba(1, 1, 1, 0.06)
    }
  }

  // As on Omarchy's bar: a double-click on empty bar space steps the
  // background through solid, glassy and clear. Below everything else, so
  // the bar's own controls keep their clicks.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onDoubleClicked: win.host.cycleBackground()
  }

  Row {
    id: leftCluster
    anchors.left: parent.left
    anchors.leftMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: Style.space(18)

    // The Omarchy menu, with every one of its stock entries.
    Item {
      id: logo
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: glyph.implicitWidth + Style.space(6)
      implicitHeight: win.host.barSize

      // Sumi's mark: 墨, ink.
      Text {
        id: glyph
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "墨"
        font.family: win.host.ds.fontJp
        font.pixelSize: 14
        color: win.host.foreground
        opacity: logoHover.hovered ? 0.72 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
      }

      HoverHandler { id: logoHover; cursorShape: Qt.PointingHandCursor }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) win.host.run("xdg-terminal-exec")
          else win.host.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
        }
      }
    }

    Workspaces {
      anchors.verticalCenter: parent.verticalCenter
      host: win.host
      screen: win.modelData
    }

    AppName {
      anchors.verticalCenter: parent.verticalCenter
      host: win.host
      visible: win.host.showAppName && implicitWidth > 0
      // Leave the notch room to open into.
      width: Math.min(implicitWidth, Math.max(0, win.width / 2 - notch.width / 2 - x - Style.space(40)))
    }

    WidgetRow {
      anchors.verticalCenter: parent.verticalCenter
      host: win.host
      facade: stripFacade
      sections: ["left"]
      screenName: win.screenName
    }
  }

  // The middle: the layout's "center" widgets (Omarchy's clock and its
  // calendar, by default), or Sumi's plain time when that section is empty.
  // The notch (its widget wings, live activity and click/customize menu) is
  // gone; Notch.qml is left in place, just unused.
  Item {
    id: notch
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: centerRow.implicitWidth > 0 ? centerRow.implicitWidth : plainClock.implicitWidth
    implicitHeight: win.host.barSize
    width: implicitWidth
    height: implicitHeight

    WidgetRow {
      id: centerRow
      anchors.centerIn: parent
      host: win.host
      facade: stripFacade
      sections: ["center"]
      screenName: win.screenName
    }

    Clock {
      id: plainClock
      anchors.centerIn: parent
      visible: centerRow.implicitWidth === 0
      ink: win.host.foreground
      family: win.host.uiFamily
      hour12: !win.host.clock24
      showDate: win.host.showDate
    }
  }

  Row {
    id: rightCluster
    anchors.right: parent.right
    anchors.rightMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    spacing: Style.space(14)

    WidgetRow {
      anchors.verticalCenter: parent.verticalCenter
      host: win.host
      facade: stripFacade
      sections: ["right"]
      screenName: win.screenName
      fixedEdge: "end"
    }

    StatusCluster {
      anchors.verticalCenter: parent.verticalCenter
      host: win.host
      screenName: win.screenName
    }
  }

  ControlCenter {
    host: win.host
    bar: win
    screenName: win.screenName
  }

  Control {
    host: win.host
    bar: win
    anchorItem: notch
    screenName: win.screenName
  }

  PopupWindow {
    id: tooltipWindow

    visible: win.host.tooltipShown && win.host.targetBelongsToWindow(win.host.tooltipTarget, win)
    color: "transparent"
    implicitWidth: Math.ceil(bubble.implicitWidth)
    implicitHeight: Math.ceil(bubble.implicitHeight)

    anchor {
      id: tooltipAnchor
      window: win
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        var target = win.host.tooltipTarget
        if (!win.host.targetBelongsToWindow(target, win)) return
        var point = win.contentItem.mapFromItem(target, target.width / 2 - tooltipWindow.implicitWidth / 2, 0)
        tooltipAnchor.rect.x = Math.round(point.x)
        tooltipAnchor.rect.y = win.height + Style.space(6)
      }
    }

    Rectangle {
      id: bubble
      implicitWidth: tipLabel.implicitWidth + Style.space(20)
      implicitHeight: tipLabel.implicitHeight + Style.space(10)
      radius: Style.space(8)
      color: Commons.Color.tooltip.background
      border.width: 1
      border.color: Util.alpha(Commons.Color.tooltip.text, 0.12)

      Text {
        id: tipLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: win.host.tooltipText
        color: Commons.Color.tooltip.text
        font.family: win.host.uiFamily
        font.pixelSize: Style.space(12)
      }
    }
  }
}
