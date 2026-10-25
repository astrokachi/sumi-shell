import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons

// One screen's dock: a glass shelf along the bottom edge whose icons swell
// toward the pointer. It stays out while the workspace is empty and tucks
// away under windows, coming back when the pointer touches the bottom edge.
PanelWindow {
  id: win

  required property var modelData
  required property var host
  required property var dock

  readonly property real base: dock.iconSize
  readonly property real maxMagnification: 1.5
  readonly property real spacing: Style.space(5)
  readonly property real padX: Style.space(7)
  readonly property real padTop: Style.space(7)
  readonly property real padBottom: Style.space(11)
  readonly property real gap: Style.space(6)
  readonly property real separatorWidth: Style.space(17)
  readonly property real headroom: base * (maxMagnification - 1)
  readonly property real labelSpace: Style.space(40)
  readonly property real plateHeight: base + padTop + padBottom

  readonly property var pinnedKeys: dock.pinnedKeys
  readonly property var openKeys: dock.openKeys
  readonly property int count: pinnedKeys.length + openKeys.length
  readonly property bool hasSeparator: pinnedKeys.length > 0 && openKeys.length > 0
  // Apps, then the Apps button after a separator of its own.
  readonly property real restWidth: 2 * padX + (count + 1) * base
    + count * spacing + (hasSeparator ? separatorWidth : 0) + separatorWidth

  readonly property color ink: Commons.Color.bar.text
  readonly property color paper: Commons.Color.bar.background

  // ---- when it shows -------------------------------------------------------

  readonly property var monitor: Hyprland.monitorFor(modelData)
  readonly property var workspace: monitor ? monitor.activeWorkspace : null
  readonly property bool workspaceEmpty: !workspace || !workspace.toplevels || workspace.toplevels.values.length === 0
  readonly property bool fullscreen: !!workspace && !!workspace.lastIpcObject && workspace.lastIpcObject.hasfullscreen === true
  property bool revealed: false
  property var menuItem: null
  property bool libraryOpen: false
  // Something that needs the dock to stay put: a menu, the app library, a drag.
  readonly property bool busy: menuItem !== null || libraryOpen || dragKey !== ""
  readonly property bool shown: !fullscreen
    && (!dock.autohide || workspaceEmpty || revealed || dock.held || busy)

  // Touching the bottom edge reveals it; it goes away a moment after the
  // pointer leaves. One hover area does both jobs and always reaches the
  // edge, so revealing never moves the pointer out of it.
  Connections {
    target: hover
    function onContainsMouseChanged() { if (hover.containsMouse) win.revealed = true }
  }

  Timer {
    interval: 600
    running: win.revealed && !hover.containsMouse && !win.busy
    onTriggered: win.revealed = false
  }

  // ---- magnification -------------------------------------------------------

  property real pointerX: -1
  // The app under the pointer, for its name label.
  property string hoveredKey: ""

  function trackPointer(x, y) {
    pointerX = x
    var inShelf = shelf.mapFromItem(null, x, y)
    // Icons sit on the shelf's bottom edge at different heights; probing
    // along that edge finds whichever one is in this column.
    var child = inShelf.y >= -labelSpace ? shelf.childAt(inShelf.x, shelf.height - 2) : null
    hoveredKey = child === appsButton ? "@apps" : child && "app" in child ? String(child.modelData) : ""
  }
  // Eases magnification in and out as the pointer arrives and leaves; while
  // it moves, icons follow it directly with no animation to lag behind.
  property real strength: hover.containsMouse && shown && !busy ? 1 : 0
  Behavior on strength { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  function restCenter(slot) {
    var x = (width - restWidth) / 2 + padX + slot * (base + spacing) + base / 2
    if (hasSeparator && slot >= pinnedKeys.length) x += separatorWidth
    if (slot >= count) x += separatorWidth
    return x
  }

  // ---- dragging -------------------------------------------------------------

  // The app being dragged and where the pointer is, in window coordinates.
  property string dragKey: ""
  property point dragPoint: Qt.point(0, 0)
  readonly property real plateTop: height - gap - plateHeight
  // Held well above the shelf, letting go takes the app out of the dock.
  readonly property bool removing: dragKey !== "" && dragPoint.y < plateTop - Style.space(30)
  readonly property var dropOthers: pinnedKeys.filter(function(key) { return key !== win.dragKey })
  readonly property int dropIndex: {
    var index = 0
    for (var i = 0; i < dropOthers.length; i++)
      if (restCenter(pinnedKeys.indexOf(dropOthers[i])) < dragPoint.x) index = i + 1
    return index
  }
  readonly property real dropMarkX: {
    if (dropOthers.length === 0) return (width - restWidth) / 2 + padX - spacing / 2
    if (dropIndex < dropOthers.length) return restCenter(pinnedKeys.indexOf(dropOthers[dropIndex])) - base / 2 - spacing / 2
    return restCenter(pinnedKeys.indexOf(dropOthers[dropOthers.length - 1])) + base / 2 + spacing / 2
  }

  function startDrag(key, scenePoint) {
    closeMenu()
    hoveredKey = ""
    dragKey = key
    dragPoint = scenePoint
  }

  function finishDrag() {
    var key = dragKey
    var item = dock.itemsByKey[key]
    var removed = removing
    dragKey = ""
    if (!item || !item.entry) return
    if (removed) {
      if (item.pinned) dock.unpin(item.entry.id)
      return
    }
    // Let go beside the dock: nothing changes.
    var left = (width - restWidth) / 2
    if (dragPoint.x < left - base || dragPoint.x > left + restWidth + base) return
    dock.pin(item.entry.id, dropIndex)
  }

  function magnificationAt(slot) {
    if (strength <= 0 || pointerX < 0) return 1
    var distance = pointerX - restCenter(slot)
    var sigma = base * 1.15
    return 1 + (maxMagnification - 1) * strength * Math.exp(-(distance * distance) / (2 * sigma * sigma))
  }

  // ---- surface -------------------------------------------------------------

  screen: modelData
  anchors { bottom: true; left: true; right: true }
  implicitHeight: Math.ceil(labelSpace + headroom + plateHeight + gap)
  color: "transparent"
  surfaceFormat.opaque: false
  // Never reserve space from this window: setting exclusiveZone at all
  // switches it to reserving, autohide or not. The reserver below does it
  // when the dock stays put.
  exclusionMode: ExclusionMode.Ignore

  // Shares the stock dock's namespace so its blur layer rule applies.
  WlrLayershell.namespace: "omarchy-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // Shown, the whole hover area takes the pointer; hidden, only its bottom
  // strip does. Neither moves with the slide animation or the magnification.
  mask: Region {
    item: win.shown ? hitArea : edgeStrip
  }

  Item {
    id: hitArea
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: win.restWidth + 2 * win.base
    height: win.plateHeight + win.gap + win.headroom

    Item {
      id: edgeStrip
      anchors.bottom: parent.bottom
      width: parent.width
      height: 3
    }

  }

  Item {
    id: stage
    anchors.fill: parent

    transform: Translate {
      y: win.shown ? 0 : win.plateHeight + win.gap + win.headroom + 4
      Behavior on y {
        NumberAnimation {
          duration: win.shown ? 280 : 200
          easing.type: win.shown ? Easing.OutCubic : Easing.InCubic
        }
      }
    }

    Rectangle {
      id: plate
      anchors.bottom: parent.bottom
      anchors.bottomMargin: win.gap
      anchors.horizontalCenter: parent.horizontalCenter
      width: shelf.width + 2 * win.padX
      height: win.plateHeight
      // Sumi glass: ink-dark, blurred behind by the dock's layer rule.
      radius: win.host.ds.rDock
      color: Qt.rgba(win.paper.r, win.paper.g, win.paper.b, 0.66)
      border.width: 1
      border.color: win.host.ds.line

      // A hairline of light along the top edge, like glass catching it.
      Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * parent.radius
        height: 1
        color: win.host.ds.highlight
      }
    }

    Row {
      id: shelf
      anchors.bottom: plate.bottom
      anchors.bottomMargin: win.padBottom
      anchors.horizontalCenter: plate.horizontalCenter
      height: win.base * win.maxMagnification
      spacing: win.spacing

      // Keyed by app, so a focus or window change updates icons in place
      // instead of rebuilding them under the pointer.
      Repeater {
        model: ScriptModel { values: win.pinnedKeys }

        DockIcon {
          required property int index
          anchors.bottom: parent.bottom
          dock: win.dock
          ink: win.ink
          maxMagnification: win.maxMagnification
          magnification: win.magnificationAt(index)
          showLabel: !win.busy && win.hoveredKey === modelData
          lifted: win.dragKey === modelData
          onContextMenuRequested: function(item, anchor) { win.openMenu(item, anchor) }
          onDragStarted: function(point) { win.startDrag(modelData, point) }
          onDragMoved: function(point) { win.dragPoint = point }
          onDragFinished: win.finishDrag()
        }
      }

      Item {
        visible: win.hasSeparator
        anchors.bottom: parent.bottom
        width: win.separatorWidth - win.spacing
        height: win.base

        Rectangle {
          anchors.centerIn: parent
          width: 1
          height: parent.height * 0.78
          color: win.ink
          opacity: 0.22
        }
      }

      Repeater {
        model: ScriptModel { values: win.openKeys }

        DockIcon {
          required property int index
          anchors.bottom: parent.bottom
          dock: win.dock
          ink: win.ink
          maxMagnification: win.maxMagnification
          magnification: win.magnificationAt(win.pinnedKeys.length + index)
          showLabel: !win.busy && win.hoveredKey === modelData
          lifted: win.dragKey === modelData
          onContextMenuRequested: function(item, anchor) { win.openMenu(item, anchor) }
          onDragStarted: function(point) { win.startDrag(modelData, point) }
          onDragMoved: function(point) { win.dragPoint = point }
          onDragFinished: win.finishDrag()
        }
      }

      Item {
        anchors.bottom: parent.bottom
        width: win.separatorWidth - win.spacing
        height: win.base

        Rectangle {
          anchors.centerIn: parent
          width: 1
          height: parent.height * 0.78
          color: win.ink
          opacity: 0.22
        }
      }

      // Every app, for opening one or keeping it in the dock.
      Item {
        id: appsButton
        readonly property real size: win.base * win.magnificationAt(win.count)
        anchors.bottom: parent.bottom
        width: size
        height: size

        Rectangle {
          anchors.fill: parent
          anchors.margins: parent.width * 0.06
          radius: width * 0.24
          color: Qt.rgba(win.ink.r, win.ink.g, win.ink.b, appsPress.pressed ? 0.24 : 0.14)
          border.width: 1
          border.color: Qt.rgba(win.ink.r, win.ink.g, win.ink.b, 0.16)

          CtlGlyph {
            anchors.centerIn: parent
            text: "apps"
            size: parent.width * 0.52
            color: win.ink
          }
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.top
          anchors.bottomMargin: Style.space(9)
          width: appsLabel.implicitWidth + Style.space(18)
          height: appsLabel.implicitHeight + Style.space(8)
          radius: height / 2
          color: Qt.rgba(0.1, 0.1, 0.11, 0.82)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.1)
          opacity: win.hoveredKey === "@apps" && !win.busy ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 120 } }

          Text {
            id: appsLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "Apps"
            color: "#f5f5f7"
            font.family: "Inter"
            font.pixelSize: Style.space(12)
            font.weight: Font.Medium
          }
        }

        MouseArea {
          id: appsPress
          anchors.fill: parent
          onClicked: { win.closeMenu(); win.libraryOpen = !win.libraryOpen }
        }
      }
    }

    // Where a dragged app will land among the pinned ones.
    Rectangle {
      visible: win.dragKey !== "" && !win.removing
      x: win.dropMarkX - 1
      y: win.plateTop + win.padTop - Style.space(2)
      width: 2
      height: win.base + Style.space(4)
      radius: 1
      color: win.ink
    }

    // The dragged app, under the pointer.
    Item {
      visible: win.dragKey !== ""
      x: win.dragPoint.x - width / 2
      y: Math.max(0, Math.min(win.height - height, win.dragPoint.y - height / 2))
      width: win.base
      height: win.base

      Image {
        anchors.fill: parent
        source: win.dragKey && win.dock.itemsByKey[win.dragKey] ? win.dock.itemsByKey[win.dragKey].icon : ""
        sourceSize.width: 128
        sourceSize.height: 128
        smooth: true
        mipmap: true
        opacity: win.removing ? 0.45 : 0.9
        scale: win.removing ? 0.8 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      }

      // Shows that letting go here takes it out.
      Rectangle {
        visible: win.removing
        anchors.top: parent.top
        anchors.right: parent.right
        width: Style.space(18)
        height: width
        radius: width / 2
        color: win.ink

        CtlGlyph {
          anchors.centerIn: parent
          text: "remove"
          size: Style.space(13)
          color: win.paper
        }
      }
    }
  }

  Connections {
    target: win.dock
    function onLibraryToggled(screenName) {
      if (screenName === String(win.modelData ? win.modelData.name : "")) win.libraryOpen = !win.libraryOpen
    }
  }

  AppLibrary {
    dock: win.dock
    dockWindow: win
    wanted: win.libraryOpen
    onDismissed: win.libraryOpen = false
  }

  // Tracks the pointer over the dock. Laid over the icons but taking no
  // buttons, so clicks still reach them.
  MouseArea {
    id: hover
    anchors.fill: hitArea
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onPositionChanged: function(mouse) { win.trackPointer(hitArea.x + mouse.x, hitArea.y + mouse.y) }
    onContainsMouseChanged: if (!containsMouse) { win.pointerX = -1; win.hoveredKey = "" }
  }

  // With autohide off, windows keep clear of the dock like on macOS.
  LazyLoader {
    active: !win.dock.autohide

    PanelWindow {
      screen: win.modelData
      anchors { bottom: true; left: true; right: true }
      implicitHeight: 1
      exclusiveZone: Math.ceil(win.plateHeight + win.gap)
      color: "transparent"
      mask: Region {}
      WlrLayershell.namespace: "sumi-dock-reserve"
      WlrLayershell.layer: WlrLayer.Bottom
    }
  }

  // ---- context menu --------------------------------------------------------

  property Item menuAnchor: null

  function openMenu(item, anchor) {
    menuAnchor = anchor
    menuItem = item
  }

  function closeMenu() {
    menuItem = null
    menuAnchor = null
  }

  readonly property var menuActions: {
    var item = menuItem
    if (!item) return []
    var list = []
    if (item.entry) list.push({ label: item.windows.length > 0 ? "New Window" : "Open", run: function() { win.dock.launch(item) } })
    if (item.entry) list.push({ label: item.pinned ? "Remove from Dock" : "Keep in Dock", run: function() { win.dock.setPinned(item, !item.pinned) } })
    if (item.windows.length > 0) list.push({ label: "Quit", run: function() { win.dock.quit(item) } })
    return list
  }

  Timer {
    interval: 900
    running: win.menuItem !== null && !menuHover.hovered && !hover.containsMouse && win.dragKey === ""
    onTriggered: win.closeMenu()
  }

  PopupWindow {
    id: menuWindow

    visible: win.menuItem !== null && win.menuAnchor !== null
    color: "transparent"
    implicitWidth: Math.ceil(menuPlate.width)
    implicitHeight: Math.ceil(menuPlate.height)

    anchor {
      id: menuPopupAnchor
      window: win
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        var target = win.menuAnchor
        if (!target) return
        var point = win.contentItem.mapFromItem(target, target.width / 2, 0)
        menuPopupAnchor.rect.x = Math.round(point.x - menuWindow.implicitWidth / 2)
        menuPopupAnchor.rect.y = Math.round(point.y - menuWindow.implicitHeight - Style.space(10))
      }
    }

    Rectangle {
      id: menuPlate
      width: Math.max(Style.space(160), menuColumn.implicitWidth + Style.space(10))
      height: menuColumn.implicitHeight + Style.space(10)
      radius: Style.space(10)
      color: Commons.Color.menu.background
      border.width: 1
      border.color: Qt.rgba(win.ink.r, win.ink.g, win.ink.b, 0.12)

      HoverHandler { id: menuHover }

      Column {
        id: menuColumn
        anchors.centerIn: parent
        width: parent.width - Style.space(10)

        Text {
          width: parent.width
          leftPadding: Style.space(10)
          topPadding: Style.space(4)
          bottomPadding: Style.space(4)
          textFormat: Text.PlainText
          text: win.menuItem ? win.menuItem.name : ""
          elide: Text.ElideRight
          color: Commons.Color.menu.text
          opacity: 0.5
          font.family: win.host.uiFamily
          font.pixelSize: Style.space(12)
          font.weight: Font.DemiBold
        }

        Repeater {
          model: win.menuActions

          Rectangle {
            id: action
            required property var modelData
            width: menuColumn.width
            height: Style.space(26)
            radius: Style.space(6)
            color: actionHover.hovered ? Qt.rgba(win.ink.r, win.ink.g, win.ink.b, 0.1) : "transparent"

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              textFormat: Text.PlainText
              text: action.modelData.label
              color: Commons.Color.menu.text
              font.family: win.host.uiFamily
              font.pixelSize: Style.space(13)
            }

            HoverHandler { id: actionHover }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                var run = action.modelData.run
                win.closeMenu()
                run()
              }
            }
          }
        }
      }
    }
  }
}
