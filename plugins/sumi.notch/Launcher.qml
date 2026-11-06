import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Icons.js" as Icons

// The launcher, as in the Sumi design: one search line, results grouped
// into Applications, Actions and Files, and a footer naming what Enter does.
// Opened by `omarchy-shell omarchy.dock apps` (super alt space, the menu's
// Apps row) or `omarchy-shell sumi.notch launcher`.
PanelWindow {
  id: launcher

  required property var host
  required property var screenModel
  property bool wanted: false
  signal dismissed()

  readonly property var ds: host.ds
  readonly property var dock: host.dock
  readonly property color ink: ds.ink
  readonly property color ink2: ds.ink2
  readonly property color ink3: ds.ink3

  property string query: ""
  property int cursor: 0
  // ctrl+K: what can be done with the selected result.
  property bool actionsOpen: false
  property var fileHits: []

  readonly property string needle: query.trim().toLowerCase()

  // ---- what can be found -----------------------------------------------------

  readonly property var actionCatalog: [
    { title: "Set Theme", sub: "Style", glyph: "palette", run: "omarchy-shell shell summon omarchy.menu '{\"menu\":\"style.theme\"}'" },
    { title: "Change Background", sub: "Style", glyph: "image", run: "omarchy-shell shell summon omarchy.menu '{\"menu\":\"style.background\"}'" },
    { title: "Take Screenshot", sub: "Capture", glyph: "camera", run: "omarchy-capture-screenshot" },
    { title: "Record Screen", sub: "Capture", glyph: "record", run: "omarchy-shell shell summon omarchy.menu '{\"menu\":\"trigger.capture.screenrecord\"}'" },
    { title: "Toggle Night Light", sub: "Display", glyph: "moon", run: "omarchy toggle nightlight" },
    { title: "Control Center", sub: "System", glyph: "sliders", run: "omarchy-shell sumi.notch controlCenter" },
    { title: "Clipboard History", sub: "System", glyph: "note", run: "omarchy-shell shell toggle omarchy.clipboard '{}'" },
    { title: "Emoji", sub: "System", glyph: "sparkle", run: "omarchy-shell shell toggle omarchy.emojis '{}'" },
    { title: "Keybindings", sub: "Learn", glyph: "keyboard", run: "\"$HOME/.local/bin/omarchy-menu-keybindings-patched\"" },
    { title: "Lock Screen", sub: "System", glyph: "lock", run: "omarchy-system-lock" },
    { title: "Restart", sub: "System", glyph: "restart", run: "omarchy-shell shell summon omarchy.menu '{\"menu\":\"system\"}'" },
    { title: "Shut Down", sub: "System", glyph: "power", run: "omarchy-shell shell summon omarchy.menu '{\"menu\":\"system\"}'" }
  ]

  // Letters of the query in order, anywhere in the text: "te" finds
  // Terminal and Text Editor, "tv" finds TradingView. Spaces are ignored
  // there, and the closer together the letters sit, the higher it ranks.
  function score(text) {
    var t = String(text || "").toLowerCase()
    var q = launcher.needle
    if (!q) return 1
    if (t.indexOf(q) === 0) return 100
    var words = t.split(/[\s._-]+/)
    for (var w = 0; w < words.length; w++) if (words[w].indexOf(q) === 0) return 80
    if (t.indexOf(q) >= 0) return 60
    var letters = q.replace(/\s+/g, "")
    var at = 0
    var first = -1
    for (var i = 0; i < letters.length; i++) {
      at = t.indexOf(letters.charAt(i), at)
      if (at < 0) return 0
      if (first < 0) first = at
      at++
    }
    return 20 + Math.round(19 * letters.length / (at - first))
  }

  // The same in-order match as a regex for fd, which only gathers
  // candidates; score() ranks them.
  function fuzzyPattern(q) {
    var out = []
    var letters = q.replace(/\s+/g, "")
    for (var i = 0; i < letters.length; i++) {
      var c = letters.charAt(i)
      out.push("\\.+*?()|[]{}^$#&-~".indexOf(c) >= 0 ? "\\" + c : c)
    }
    return out.join(".*")
  }

  // Rows as drawn: section headers and results, flattened.
  readonly property var rows: {
    var out = []
    var apps = []
    var library = launcher.dock.library
    for (var i = 0; i < library.length; i++) {
      var app = library[i]
      // Name first, then what it is ("Terminal" finds Foot), then its id.
      var s = launcher.needle
        ? Math.max(score(app.name), score(app.entry.genericName) - 5, score(app.id) - 10)
        : (launcher.dock.isPinned(app.id) ? 1 : 0)
      if (s > 0) apps.push({ kind: "App", title: app.name, sub: String(app.entry.genericName || app.entry.comment || ""), app: app, score: s })
    }
    apps.sort(function(a, b) { return b.score - a.score || a.title.localeCompare(b.title) })
    apps = apps.slice(0, launcher.needle ? 4 : 6)

    var actions = []
    for (var j = 0; j < launcher.actionCatalog.length; j++) {
      var act = launcher.actionCatalog[j]
      var t = launcher.needle ? Math.max(score(act.title), score(act.sub) - 30) : 0
      if (t > 0) actions.push({ kind: "Action", title: act.title, sub: act.sub, glyph: act.glyph, run: act.run, score: t })
    }
    actions.sort(function(a, b) { return b.score - a.score })
    actions = actions.slice(0, 3)

    // Each result carries its position: the Repeater hands delegates a copy,
    // so looking a row up in `results` by identity never finds it.
    var n = 0
    var push = function(title, list) {
      if (list.length === 0) return
      out.push({ header: true, title: title })
      for (var k = 0; k < list.length; k++) out.push(Object.assign({}, list[k], { idx: n++ }))
    }
    push(launcher.needle ? "Applications" : "In the dock", apps)
    push("Actions", actions)
    push("Files", launcher.fileHits)
    return out
  }

  readonly property var results: rows.filter(function(r) { return !r.header })
  readonly property var selected: results.length > 0 ? results[Math.max(0, Math.min(cursor, results.length - 1))] : null

  onRowsChanged: if (cursor >= results.length) cursor = Math.max(0, results.length - 1)
  onQueryChanged: {
    cursor = 0
    actionsOpen = false
    fileSearch.restart()
  }

  // ---- files, found with fd as you type -------------------------------------

  Timer {
    id: fileSearch
    interval: 140
    onTriggered: {
      if (launcher.needle.length < 2) { launcher.fileHits = []; return }
      fileProc.running = false
      fileProc.command = ["fd", "--max-depth", "4", "--max-results", "300", "--ignore-case",
        "--exclude", ".git", "--exclude", "node_modules", "--", fuzzyPattern(launcher.needle), Quickshell.env("HOME")]
      fileProc.running = true
    }
  }

  Process {
    id: fileProc
    stdout: StdioCollector {
      onStreamFinished: {
        var home = Quickshell.env("HOME")
        var hits = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var path = lines[i].trim()
          if (!path) continue
          var folder = path.slice(-1) === "/"
          var clean = folder ? path.slice(0, -1) : path
          var name = clean.split("/").pop()
          var dir = clean.slice(0, clean.length - name.length - 1).replace(home, "~")
          var s = launcher.score(name)
          if (s > 0) hits.push({ kind: folder ? "Folder" : "File", title: name, sub: dir || "~", glyph: folder ? "folder" : "note", path: clean, score: s, depth: clean.split("/").length })
        }
        // Best match first; on a tie, the one nearer home, then the shorter name.
        hits.sort(function(a, b) { return b.score - a.score || a.depth - b.depth || a.title.length - b.title.length })
        launcher.fileHits = hits.slice(0, 3)
      }
    }
  }

  // ---- doing things ------------------------------------------------------------

  function open(result) {
    if (!result) return
    dismissed()
    if (result.kind === "App") dock.launch({ key: result.app.id, entry: result.app.entry, windows: [] })
    else if (result.kind === "Action") Util.execDetached(result.run)
    else Util.execDetached("xdg-open " + Util.shellQuote(result.path))
  }

  readonly property var selectedActions: {
    var r = launcher.selected
    if (!r) return []
    if (r.kind === "App") {
      var pinned = launcher.dock.isPinned(r.app.id)
      return [
        { title: "Open", run: function() { launcher.open(r) } },
        { title: pinned ? "Remove from Dock" : "Keep in Dock", run: function() { if (pinned) launcher.dock.unpin(r.app.id); else launcher.dock.pin(r.app.id); launcher.actionsOpen = false } }
      ]
    }
    if (r.kind === "File" || r.kind === "Folder") {
      return [
        { title: "Open", run: function() { launcher.open(r) } },
        { title: "Show in Files", run: function() { launcher.dismissed(); Util.execDetached("xdg-open " + Util.shellQuote(r.kind === "Folder" ? r.path : r.path.slice(0, r.path.lastIndexOf("/")))) } },
        { title: "Copy Path", run: function() { launcher.dismissed(); Util.execDetached("printf %s " + Util.shellQuote(r.path) + " | wl-copy") } }
      ]
    }
    return [{ title: "Run", run: function() { launcher.open(r) } }]
  }
  property int actionCursor: 0

  // Text to open with (`omarchy-shell sumi.notch launcherWith <text>`).
  property string initialQuery: ""

  onWantedChanged: {
    if (!wanted) return
    query = initialQuery
    cursor = 0
    actionsOpen = false
    fileHits = []
  }

  // Mapped once and parked rather than mapped fresh on every open, which
  // cost ~150 ms (window setup, first frame, then the layer fade). While
  // closed it is empty, takes no keyboard focus and has no input region, so
  // clicks fall through. It unmaps only if its screen goes away; the next
  // open picks the focused one.
  screen: screenModel
  visible: !!screenModel && Quickshell.screens.indexOf(screenModel) >= 0
  // Parked, the surface shrinks to one pixel in the corner. Hyprland blurs a
  // blurred layer wherever what is under it changes, even a transparent one,
  // and four parked fullscreen layers halved the frame rate (30 FPS over
  // video). Opening grows it back; that is a resize, not a new surface.
  readonly property bool parked: !wanted && appear <= 0 && !appearSpring.moving
  anchors { top: true; left: true; bottom: !parked; right: !parked }
  implicitWidth: 1
  implicitHeight: 1
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "sumi-control"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  Item { id: inputCover; anchors.fill: parent }
  mask: Region { item: launcher.wanted ? inputCover : null }

  // Settles in on a gentle spring and leaves quicker with no bounce. Input
  // and focus follow `wanted` at once; only the drawing moves.
  readonly property real appear: appearSpring.value
  SumiSpring {
    id: appearSpring
    animated: Style.duration(1) > 0
    response: launcher.wanted ? launcher.ds.openResponse : launcher.ds.closeResponse
    dampingRatio: launcher.wanted ? launcher.ds.openDamping : launcher.ds.closeDamping
    target: launcher.wanted ? 1 : 0
  }

  MouseArea {
    anchors.fill: parent
    onClicked: launcher.dismissed()
  }

  // Built only while open: hundreds of app icons loading in the background
  // crashed the shell when it restarted mid-way, and cost memory unseen.
  Loader {
    anchors.fill: parent
    // Kept through the fade out, then released.
    active: launcher.wanted || launcher.appear > 0 || appearSpring.moving
    opacity: Math.max(0, Math.min(1, launcher.appear / launcher.ds.opaqueAt))
    sourceComponent: Component {
      Item {
        anchors.fill: parent
        Component.onCompleted: { search.text = launcher.query; search.forceActiveFocus() }
        // Reopened while still fading out, this Item is reused rather than
        // rebuilt: take the new query and the focus the same way.
        Connections {
          target: launcher
          function onWantedChanged() {
            if (!launcher.wanted) return
            // After the launcher's own handler has set the new query.
            Qt.callLater(function() { search.text = launcher.query; search.forceActiveFocus() })
          }
        }

      Rectangle {
        id: card
        scale: launcher.ds.settleFrom + (1 - launcher.ds.settleFrom) * launcher.appear
        width: Style.space(520)
        height: column.implicitHeight
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.15)
        radius: launcher.ds.rPanel
        color: launcher.host.panelBackground
        border.width: 1
        border.color: launcher.ds.line
        clip: true

        MouseArea { anchors.fill: parent }

        Rectangle {
          anchors.top: parent.top
          anchors.topMargin: 1
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width - 2 * parent.radius
          height: 1
          color: launcher.ds.highlight
        }

        Column {
          id: column
          width: parent.width

          // Search.
          Item {
            width: parent.width
            height: Style.space(54)

            SumiIcon {
              id: searchIcon
              x: Style.space(18)
              anchors.verticalCenter: parent.verticalCenter
              name: "search"
              size: 18
              color: launcher.ink2
            }

            TextInput {
              id: search
              anchors.left: searchIcon.right
              anchors.leftMargin: Style.space(12)
              anchors.right: escChip.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              focus: true
              clip: true
              color: launcher.ink
              selectionColor: Qt.rgba(launcher.ink.r, launcher.ink.g, launcher.ink.b, 0.25)
              font.family: launcher.ds.fontUi
              font.pixelSize: 17 + launcher.ds.textBump
              onTextEdited: launcher.query = text

              Keys.onPressed: function(event) {
                var count = launcher.actionsOpen ? launcher.selectedActions.length : launcher.results.length
                if (event.key === Qt.Key_Escape) {
                  if (launcher.actionsOpen) launcher.actionsOpen = false
                  else if (launcher.query !== "") { launcher.query = ""; search.text = "" }
                  else launcher.dismissed()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                  var step = event.key === Qt.Key_Down ? 1 : -1
                  if (count > 0) {
                    if (launcher.actionsOpen) launcher.actionCursor = (launcher.actionCursor + step + count) % count
                    else launcher.cursor = (launcher.cursor + step + count) % count
                  }
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  if (launcher.actionsOpen) {
                    var act = launcher.selectedActions[launcher.actionCursor]
                    if (act) act.run()
                  } else launcher.open(launcher.selected)
                  event.accepted = true
                } else if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                  if (launcher.selected) { launcher.actionsOpen = !launcher.actionsOpen; launcher.actionCursor = 0 }
                  event.accepted = true
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text
                textFormat: Text.PlainText
                text: "Search apps, actions and files"
                color: launcher.ink
                opacity: 0.4
                font: search.font
              }
            }

            Rectangle {
              id: escChip
              anchors.right: parent.right
              anchors.rightMargin: Style.space(18)
              anchors.verticalCenter: parent.verticalCenter
              width: escText.implicitWidth + Style.space(12)
              height: Style.space(20)
              radius: launcher.ds.rChip
              color: launcher.ds.raised2

              Text {
                id: escText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "esc"
                color: launcher.ink2
                font.family: launcher.ds.fontMono
                font.pixelSize: 11 + launcher.ds.textBump
              }
            }

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: launcher.ds.line
            }
          }

          // Results, or the selected result's actions.
          Column {
            width: parent.width
            topPadding: Style.space(6)
            bottomPadding: Style.space(8)
            leftPadding: Style.space(8)
            rightPadding: Style.space(8)

            Text {
              visible: !launcher.actionsOpen && launcher.rows.length === 0
              width: parent.width - Style.space(16)
              height: Style.space(56)
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: "Nothing matches “" + launcher.query.trim() + "”"
              elide: Text.ElideMiddle
              color: launcher.ink3
              font.family: launcher.ds.fontUi
              font.pixelSize: 13 + launcher.ds.textBump
            }

            Repeater {
              model: launcher.actionsOpen ? [] : launcher.rows

              Item {
                id: entry
                required property var modelData
                readonly property int resultIndex: modelData.header === true ? -1 : modelData.idx
                readonly property bool current: modelData.header !== true && resultIndex === launcher.cursor
                readonly property string glyph: modelData.kind === "App"
                  ? Icons.appGlyph(modelData.app.id) : (modelData.glyph || "")
                width: parent.width - Style.space(16)
                height: modelData.header === true ? Style.space(30) : Style.space(40)

                Text {
                  visible: entry.modelData.header === true
                  x: Style.space(10)
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(6)
                  textFormat: Text.PlainText
                  text: entry.modelData.title
                  color: launcher.ink3
                  font.family: launcher.ds.fontUi
                  font.pixelSize: 12 + launcher.ds.textBump
                }

                Rectangle {
                  visible: entry.modelData.header !== true
                  anchors.fill: parent
                  radius: launcher.ds.rRow
                  color: entry.current ? launcher.ds.sel : "transparent"

                  Item {
                    id: tile
                    x: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(20)
                    height: width

                    SumiIcon {
                      visible: entry.glyph !== ""
                      anchors.centerIn: parent
                      name: entry.glyph
                      size: 17
                      color: entry.current ? launcher.ink : launcher.ink2
                    }

                    Image {
                      visible: entry.glyph === "" && entry.modelData.kind === "App"
                      anchors.centerIn: parent
                      width: 18
                      height: 18
                      source: entry.modelData.kind === "App" ? entry.modelData.app.icon : ""
                      sourceSize.width: 48
                      sourceSize.height: 48
                      smooth: true
                      layer.enabled: true
                      layer.effect: MultiEffect { saturation: -1 }
                    }
                  }

                  // The name wins the row; the detail gets what is left, and a
                  // long file name keeps its extension (elided in the middle).
                  Text {
                    id: title
                    readonly property real room: parent.width - x - Style.space(12)
                    anchors.left: tile.right
                    anchors.leftMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, detail.text ? room * 0.72 : room)
                    textFormat: Text.PlainText
                    text: entry.modelData.title || ""
                    elide: entry.modelData.path ? Text.ElideMiddle : Text.ElideRight
                    color: launcher.ink
                    font.family: launcher.ds.fontUi
                    font.pixelSize: 14 + launcher.ds.textBump
                  }

                  Text {
                    id: detail
                    anchors.left: title.right
                    anchors.leftMargin: Style.space(10)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: width > Style.space(36)
                    textFormat: Text.PlainText
                    text: entry.modelData.sub || ""
                    elide: Text.ElideRight
                    color: launcher.ink3
                    font.family: launcher.ds.fontUi
                    font.pixelSize: 12 + launcher.ds.textBump
                  }

                  HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) launcher.cursor = entry.resultIndex
                  }
                  TapHandler { onTapped: launcher.open(entry.modelData) }
                }
              }
            }

            // ctrl+K: actions for the selected result.
            Repeater {
              model: launcher.actionsOpen ? launcher.selectedActions : []

              Rectangle {
                id: actionRow
                required property var modelData
                required property int index
                width: parent.width - Style.space(16)
                height: Style.space(40)
                radius: launcher.ds.rRow
                color: index === launcher.actionCursor ? launcher.ds.sel : "transparent"

                Text {
                  x: Style.space(14)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: actionRow.modelData.title
                  color: launcher.ink
                  font.family: launcher.ds.fontUi
                  font.pixelSize: 14 + launcher.ds.textBump
                }

                HoverHandler {
                  cursorShape: Qt.PointingHandCursor
                  onHoveredChanged: if (hovered) launcher.actionCursor = actionRow.index
                }
                TapHandler { onTapped: actionRow.modelData.run() }
              }
            }
          }

          // What Enter and ctrl+K do.
          Item {
            width: parent.width
            height: Style.space(40)

            Rectangle {
              width: parent.width
              height: 1
              color: launcher.ds.line
            }

            Row {
              x: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(10)
              visible: launcher.selected !== null

              SumiIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: launcher.selected && launcher.selected.kind === "App"
                  ? (Icons.appGlyph(launcher.selected.app.id) || "grid")
                  : (launcher.selected ? launcher.selected.glyph || "grid" : "grid")
                size: 15
                color: launcher.ink2
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                width: Math.min(implicitWidth, card.width * 0.45)
                text: launcher.selected ? launcher.selected.title : ""
                elide: Text.ElideMiddle
                color: launcher.ink2
                font.family: launcher.ds.fontUi
                font.pixelSize: 12 + launcher.ds.textBump
              }
            }

            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: launcher.actionsOpen ? "Run" : "Open"
                color: launcher.ink
                font.family: launcher.ds.fontUi
                font.pixelSize: 12 + launcher.ds.textBump
              }
              KeyChip { text: "↵" }
              Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: Style.space(14); color: launcher.ds.line }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Actions"
                color: launcher.ink2
                font.family: launcher.ds.fontUi
                font.pixelSize: 12 + launcher.ds.textBump
              }
              KeyChip { text: "ctrl K" }
            }
          }
        }
      }
      }
    }
  }

  component KeyChip: Rectangle {
    id: chip
    property string text: ""
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: chipText.implicitWidth + Style.space(12)
    height: Style.space(20)
    radius: launcher.ds.rChip
    color: launcher.ds.raised2

    Text {
      id: chipText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: chip.text
      color: launcher.ink2
      font.family: launcher.ds.fontMono
      font.pixelSize: 11 + launcher.ds.textBump
    }
  }
}
