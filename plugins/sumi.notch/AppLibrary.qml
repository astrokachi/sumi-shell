import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Every installed app, opened from the dock's Apps button, the menu's Apps
// row or `omarchy-shell omarchy.dock apps`. Click an app to open it; its
// badge keeps it in the dock or takes it out. Typing searches.
//
// A layer of its own rather than a popup: a popup that grabs input is only
// allowed straight after a click on its parent, so one opened from a
// command or another surface would be closed the moment it appeared.
PanelWindow {
  id: library

  required property var dock
  required property var dockWindow
  property bool wanted: false
  signal dismissed()

  readonly property color ink: Commons.Color.popups.text
  readonly property color paper: Commons.Color.popups.background
  readonly property int columns: 6
  property string query: ""

  readonly property var apps: {
    var needle = query.trim().toLowerCase()
    if (!needle) return dock.library
    return dock.library.filter(function(app) {
      return app.name.toLowerCase().indexOf(needle) >= 0 || app.id.toLowerCase().indexOf(needle) >= 0
    })
  }

  onWantedChanged: if (wanted) query = ""

  screen: dockWindow.screen
  visible: wanted
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "omarchy-dock-apps"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // A click anywhere outside the card closes it.
  MouseArea {
    anchors.fill: parent
    onClicked: library.dismissed()
  }

  // Built only while open: hundreds of app icons loading in the background
  // crashed the shell when it restarted mid-way, and cost memory unseen.
  Loader {
    anchors.fill: parent
    active: library.wanted
    sourceComponent: Component {
      Item {
        anchors.fill: parent
        Component.onCompleted: { search.forceActiveFocus() }

      Rectangle {
        id: card
        width: Style.space(560)
        height: Style.space(460)
        x: Math.round((parent.width - width) / 2)
        // Just above the dock's resting shelf.
        y: Math.round(parent.height - library.dockWindow.height + library.dockWindow.plateTop
          - library.dockWindow.headroom - height - Style.space(10))
        radius: Style.space(16)
        color: library.paper
        border.width: 1
        border.color: Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.12)
        clip: true

        // Swallow clicks on the card itself.
        MouseArea { anchors.fill: parent }

        Rectangle {
          id: searchBox
          anchors.top: parent.top
          anchors.topMargin: Style.space(14)
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(260)
          height: Style.space(30)
          radius: Style.space(9)
          color: Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.07)

          CtlGlyph {
            id: searchGlyph
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            size: Style.space(16)
            color: library.ink
            opacity: 0.5
          }

          TextInput {
            id: search
            anchors.left: searchGlyph.right
            anchors.leftMargin: Style.space(6)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            clip: true
            color: library.ink
            selectionColor: Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.25)
            font.family: "Inter"
            font.pixelSize: Style.space(13)
            onTextEdited: library.query = text
            Keys.onEscapePressed: {
              if (library.query !== "") { library.query = ""; search.text = "" }
              else library.dismissed()
            }
            // Enter opens the first match.
            Keys.onReturnPressed: if (library.apps.length > 0) library.open(library.apps[0])

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: !search.text
              textFormat: Text.PlainText
              text: "Search apps"
              color: library.ink
              opacity: 0.4
              font: search.font
            }
          }
        }

        GridView {
          id: grid
          anchors.top: searchBox.bottom
          anchors.topMargin: Style.space(12)
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(10)
          anchors.horizontalCenter: parent.horizontalCenter
          width: cellWidth * library.columns
          cellWidth: Math.floor((card.width - Style.space(24)) / library.columns)
          cellHeight: Style.space(96)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: library.apps

          delegate: Item {
            id: tile
            required property var modelData
            readonly property bool pinned: library.dock.isPinned(modelData.id)
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
              anchors.fill: parent
              anchors.margins: Style.space(3)
              radius: Style.space(12)
              color: tileHover.hovered ? Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.07) : "transparent"
            }

            // Line mode: the same ink tiles as the dock. Apps the icon set
            // knows get its glyph; the rest keep their icon, greyed.
            readonly property bool lineMode: library.dock.appIconStyle === "line"
            readonly property string glyph: lineMode ? library.dock.lineIconFor({ key: modelData.id, entry: modelData.entry }) : ""

            Rectangle {
              id: icon
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              anchors.topMargin: Style.space(10)
              width: Style.space(48)
              height: width
              radius: width * 0.25
              color: tile.lineMode ? Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.08) : "transparent"
              border.width: tile.lineMode ? 1 : 0
              border.color: Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.08)

              SumiIcon {
                visible: tile.glyph !== ""
                anchors.centerIn: parent
                name: tile.glyph
                size: parent.width * 0.5
                color: library.ink
              }
            }

            Image {
              anchors.centerIn: icon
              visible: tile.glyph === ""
              width: tile.lineMode ? icon.width * 0.58 : icon.width
              height: width
              layer.enabled: tile.lineMode
              layer.effect: MultiEffect { saturation: -1; brightness: 0.05 }
              source: tile.modelData.icon
              sourceSize.width: 96
              sourceSize.height: 96
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              asynchronous: true
            }

            Text {
              anchors.top: icon.bottom
              anchors.topMargin: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - Style.space(10)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: tile.modelData.name
              elide: Text.ElideRight
              color: library.ink
              font.family: "Inter"
              font.pixelSize: Style.space(11)
            }

            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: library.open(tile.modelData) }

            // Keep in Dock / Remove from Dock. Always shown for pinned apps,
            // on hover for the rest.
            Rectangle {
              anchors.right: icon.right
              anchors.rightMargin: -Style.space(7)
              anchors.top: icon.top
              anchors.topMargin: -Style.space(5)
              width: Style.space(20)
              height: width
              radius: width / 2
              visible: tile.pinned || tileHover.hovered
              color: tile.pinned ? library.ink : Qt.rgba(library.paper.r, library.paper.g, library.paper.b, 0.95)
              border.width: 1
              border.color: Qt.rgba(library.ink.r, library.ink.g, library.ink.b, 0.3)

              CtlGlyph {
                anchors.centerIn: parent
                text: tile.pinned ? (badgeHover.hovered ? "remove" : "check") : "add"
                size: Style.space(14)
                color: tile.pinned ? library.paper : library.ink
              }

              HoverHandler { id: badgeHover; cursorShape: Qt.PointingHandCursor }
              TapHandler {
                onTapped: {
                  if (tile.pinned) library.dock.unpin(tile.modelData.id)
                  else library.dock.pin(tile.modelData.id)
                }
              }
            }
          }

          WheelHandler {
            onWheel: function(event) {
              var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
              grid.contentY = Math.max(0, Math.min(Math.max(0, grid.contentHeight - grid.height), grid.contentY - delta))
            }
          }
        }

        Text {
          anchors.centerIn: grid
          visible: library.apps.length === 0
          textFormat: Text.PlainText
          text: "No apps match “" + library.query.trim() + "”"
          color: library.ink
          opacity: 0.45
          font.family: "Inter"
          font.pixelSize: Style.space(12)
        }
      }
      }
    }
  }

  function open(app) {
    dismissed()
    dock.launch({ key: app.id, entry: app.entry, windows: [] })
  }
}
