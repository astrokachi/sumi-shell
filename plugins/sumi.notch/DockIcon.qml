import QtQuick
import QtQuick.Effects
import qs.Commons

// One app in the dock. It grows toward the pointer, bounces while its app
// starts, and wears a dot while the app has windows open.
Item {
  id: icon

  // The app's key; its details come from the dock so they update in place.
  required property string modelData
  required property var dock
  required property real magnification
  required property real maxMagnification
  required property color ink
  property bool showLabel: true

  readonly property var app: dock.itemsByKey[modelData] || null
  readonly property real base: dock.iconSize
  readonly property real size: base * magnification
  readonly property bool running: !!app && app.windows.length > 0
  readonly property bool launching: dock.isLaunching(modelData)
  property real lift: 0

  // Dimmed while it is being dragged somewhere else.
  property bool lifted: false

  signal contextMenuRequested(var item, Item anchor)
  signal dragStarted(point scenePoint)
  signal dragMoved(point scenePoint)
  signal dragFinished()

  width: size
  height: size

  // Rendered once at the largest size it reaches and scaled from there, so
  // growing never re-rasterizes the icon.
  // Line mode (Sumi): every app sits on the same ink tile. Apps the icon
  // set knows are drawn in its line style; the rest keep their own icon,
  // greyed, so the row still reads as one set.
  readonly property bool lineMode: dock.appIconStyle === "line"
  readonly property string lineIcon: lineMode && app ? dock.lineIconFor(app) : ""

  Rectangle {
    visible: icon.lineMode
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: icon.lift
    width: icon.size
    height: icon.size
    radius: icon.size * 0.25
    color: Qt.rgba(icon.ink.r, icon.ink.g, icon.ink.b, press.pressed ? 0.14 : 0.08)
    border.width: 1
    border.color: Qt.rgba(icon.ink.r, icon.ink.g, icon.ink.b, 0.08)
    opacity: icon.lifted ? 0.3 : 1

    SumiIcon {
      visible: icon.lineIcon !== ""
      anchors.centerIn: parent
      name: icon.lineIcon
      size: icon.size * 0.5
      color: icon.ink
    }
  }

  Image {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: icon.lift + (icon.lineMode ? icon.size * 0.21 : 0)
    width: icon.lineMode ? icon.size * 0.58 : icon.size
    height: width
    visible: !icon.lineMode || icon.lineIcon === ""
    layer.enabled: icon.lineMode
    layer.effect: MultiEffect { saturation: -1; brightness: 0.05 }
    source: icon.app ? icon.app.icon : ""
    sourceSize.width: Math.ceil(icon.base * icon.maxMagnification * 2)
    sourceSize.height: Math.ceil(icon.base * icon.maxMagnification * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    asynchronous: true
    opacity: icon.lifted ? 0.3 : press.pressed ? 0.62 : 1
    Behavior on opacity { NumberAnimation { duration: 90 } }
  }

  SequentialAnimation {
    running: icon.launching
    loops: Animation.Infinite
    alwaysRunToEnd: true
    NumberAnimation { target: icon; property: "lift"; to: icon.base * 0.42; duration: 300; easing.type: Easing.OutQuad }
    NumberAnimation { target: icon; property: "lift"; to: 0; duration: 300; easing.type: Easing.InQuad }
    PauseAnimation { duration: 120 }
  }

  // Running indicator, in the plate's bottom padding.
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom
    anchors.topMargin: Style.space(3)
    width: Style.space(4)
    height: width
    radius: width / 2
    color: icon.ink
    opacity: icon.running ? (icon.app.active ? 0.95 : 0.55) : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
  }

  // The app's name, floating above it while pointed at (the dock decides).
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: Style.space(9)
    width: label.implicitWidth + Style.space(18)
    height: label.implicitHeight + Style.space(8)
    radius: height / 2
    color: Qt.rgba(0.1, 0.1, 0.11, 0.82)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.1)
    visible: opacity > 0
    opacity: icon.showLabel ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: icon.showLabel ? 140 : 90 } }

    Text {
      id: label
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: icon.app ? icon.app.name : ""
      color: "#f5f5f7"
      font.family: "Inter"
      font.pixelSize: Style.space(12)
      font.weight: Font.Medium
    }
  }

  // Dragging rearranges the dock or takes the app out of it; only apps with
  // a desktop entry can be kept in it.
  DragHandler {
    target: null
    dragThreshold: 6
    enabled: !!icon.app && !!icon.app.entry
    grabPermissions: PointerHandler.CanTakeOverFromAnything
    onActiveChanged: {
      if (active) icon.dragStarted(centroid.scenePosition)
      else icon.dragFinished()
    }
    onCentroidChanged: if (active) icon.dragMoved(centroid.scenePosition)
  }

  MouseArea {
    id: press
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: function(mouse) {
      if (!icon.app) return
      if (mouse.button === Qt.RightButton) icon.contextMenuRequested(icon.app, icon)
      else if (mouse.button === Qt.MiddleButton) icon.dock.launch(icon.app)
      else icon.dock.activate(icon.app)
    }
  }
}
