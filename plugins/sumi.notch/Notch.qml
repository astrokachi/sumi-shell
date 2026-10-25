import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons

// The notch: the time, a small live activity while something plays, and two
// wings of widgets it is open with. Clicking it folds the wings away, the
// way the Dynamic Island closes, and clicking again opens them.
Item {
  id: notch

  required property var host
  required property string screenName

  readonly property bool expanded: { void(host.collapsedScreens); return host.isExpanded(screenName) }
  // Wings stay laid out while they fade so the notch shrinks after them.
  property bool wingsLaidOut: true
  readonly property real ear: Style.space(8)
  readonly property real padX: Style.space(14)
  readonly property real restWidth: Style.space(210)
  readonly property color ink: host.notchInk

  readonly property var player: {
    var values = Mpris.players.values
    for (var i = 0; i < values.length; i++)
      if (values[i].playbackState === MprisPlaybackState.Playing) return values[i]
    return null
  }
  readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing

  readonly property real targetWidth: {
    var content = row.implicitWidth + 2 * (ear + padX)
    return Math.max(restWidth, content) + (hover.hovered && !expanded ? Style.space(6) : 0)
  }

  width: targetWidth
  height: host.barSize

  Behavior on width {
    SpringAnimation { spring: 4.2; damping: 0.36; epsilon: 0.25 }
  }

  onExpandedChanged: {
    if (expanded) {
      foldTimer.stop()
      wingsLaidOut = true
    } else {
      foldTimer.restart()
    }
  }

  Timer {
    id: foldTimer
    interval: 140
    onTriggered: if (!notch.expanded) notch.wingsLaidOut = false
  }

  BarFacade {
    id: notchFacade
    host: notch.host
    ink: notch.ink
    // The surface its widgets sit on: black for a black notch, else the
    // theme's own background.
    paper: notch.host.notchTone === "black" && notch.host.notchShape !== "flush" ? notch.host.ds.notch : notch.host.background
  }

  HoverHandler { id: hover }

  // The island floats a little below the top edge as a pill.
  Rectangle {
    visible: notch.host.notchShape === "island"
    anchors.fill: parent
    anchors.topMargin: Style.space(3)
    anchors.bottomMargin: Style.space(3)
    radius: height / 2
    color: notch.host.notchColor
    border.width: 1
    border.color: notch.host.notchEdge
    scale: press.pressed ? 0.985 : 1
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  NotchShape {
    visible: notch.host.notchShape === "notch"
    anchors.fill: parent
    color: notch.host.notchColor
    ear: notch.ear
    radius: Style.space(13)
    scale: press.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  // Under the content so a click on a widget reaches the widget; anything
  // else in the notch folds or opens it; right-click customizes it.
  MouseArea {
    id: press
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) notch.host.toggleCustomize(notch.screenName)
      else if (mouse.button === Qt.MiddleButton && notch.player) notch.player.togglePlaying()
      else notch.host.toggleExpanded(notch.screenName)
    }
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: notch.ear
    anchors.rightMargin: notch.ear
    clip: true

    Row {
      id: row
      anchors.centerIn: parent
      height: parent.height
      spacing: Style.space(10)

      WidgetRow {
        id: leftWing
        anchors.verticalCenter: parent.verticalCenter
        visible: notch.wingsLaidOut
        opacity: notch.expanded ? 1 : 0
        host: notch.host
        facade: notchFacade
        sections: ["centerBegin"]
        screenName: notch.screenName
        inNotch: true
        fixedEdge: "end"
        Behavior on opacity { NumberAnimation { duration: notch.expanded ? 260 : 120; easing.type: Easing.OutCubic } }
      }

      // Album art, while something plays.

      WidgetRow {
        anchors.verticalCenter: parent.verticalCenter
        host: notch.host
        facade: notchFacade
        sections: ["center"]
        screenName: notch.screenName
        inNotch: true
        fixedEdge: "center"
      }

      Clock {
        anchors.verticalCenter: parent.verticalCenter
        ink: notch.ink
        family: notch.host.uiFamily
        hour12: !notch.host.clock24
        showDate: notch.host.showDate
      }

      // A hairline, then the soundwave while something plays.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: notch.player !== null
        width: 1
        height: Style.space(12)
        color: Qt.rgba(notch.ink.r, notch.ink.g, notch.ink.b, 0.14)
      }

      Equalizer {
        anchors.verticalCenter: parent.verticalCenter
        visible: notch.playing
        running: notch.playing
        color: notch.ink
        opacity: 0.9
      }


      WidgetRow {
        id: rightWing
        anchors.verticalCenter: parent.verticalCenter
        visible: notch.wingsLaidOut
        opacity: notch.expanded ? 1 : 0
        host: notch.host
        facade: notchFacade
        sections: ["centerEnd"]
        screenName: notch.screenName
        inNotch: true
        fixedEdge: "start"
        Behavior on opacity { NumberAnimation { duration: notch.expanded ? 260 : 120; easing.type: Easing.OutCubic } }
      }
    }
  }
}
