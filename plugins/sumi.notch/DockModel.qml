import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Icons.js" as Icons

// What the dock shows: pinned apps in their order, then apps that are open
// but not pinned. Pins live in shell.json under `dock.pinned`, managed with
// `omarchy dock pin|unpin`; this only reads them.
QtObject {
  id: model

  property var dockConfig: ({})
  readonly property var pinnedIds: {
    var source = Array.isArray(dockConfig.pinned) ? dockConfig.pinned : []
    var ids = []
    for (var i = 0; i < source.length; i++) {
      var id = normalizeId(source[i])
      if (id && ids.indexOf(id) === -1) ids.push(id)
    }
    return ids
  }
  readonly property bool autohide: dockConfig.autohide !== false
  // "line": apps drawn from the Sumi icon set on ink tiles; "original":
  // their own icons. Set from the bar's appearance settings.
  property string appIconStyle: "line"
  readonly property int iconSize: {
    var size = Number(dockConfig.iconSize)
    return size >= 28 && size <= 72 ? Math.round(size) : 46
  }

  // Held open from the keyboard (`omarchy-shell sumi.notch toggleDock`).
  property bool held: false
  // Asks the dock on a screen to open or close its app library.
  signal libraryToggled(string screenName)

  // Apps launched from the dock bounce until a window of theirs shows up.
  property var launching: ({})

  readonly property var items: {
    void(DesktopEntries.applications.values.length)
    var byKey = {}
    var order = []

    function add(key, entry, pinned) {
      if (byKey[key]) return byKey[key]
      var item = { key: key, entry: entry, pinned: pinned, windows: [], active: false,
        name: entry && entry.name ? String(entry.name) : prettyName(key),
        icon: iconFor(entry, key) }
      byKey[key] = item
      order.push(item)
      return item
    }

    for (var i = 0; i < pinnedIds.length; i++) {
      var entry = DesktopEntries.byId(pinnedIds[i])
      if (entry) add(entry.id || pinnedIds[i], entry, true)
    }

    var toplevels = Hyprland.toplevels.values
    for (var j = 0; j < toplevels.length; j++) {
      var toplevel = toplevels[j].wayland
      if (!toplevel || !toplevel.appId || toplevel.parent) continue
      var workspace = toplevels[j].workspace
      // Scratchpads and other special workspaces stay out of the dock.
      if (workspace && workspace.id < 1) continue
      var found = DesktopEntries.heuristicLookup(toplevel.appId)
      var key = found && found.id ? found.id : String(toplevel.appId)
      var item = byKey[key] || add(key, found, false)
      item.windows.push({ address: String(toplevels[j].address || ""), toplevel: toplevel,
        workspaceId: workspace ? workspace.id : -1 })
      if (toplevel.activated) item.active = true
    }
    return order
  }

  readonly property var itemsByKey: {
    var byKey = {}
    for (var i = 0; i < items.length; i++) byKey[items[i].key] = items[i]
    return byKey
  }

  // Plain key lists for the views: unchanged keys keep their delegates.
  readonly property var pinnedKeys: items.filter(function(item) { return item.pinned }).map(function(item) { return item.key })
  readonly property var openKeys: items.filter(function(item) { return !item.pinned }).map(function(item) { return item.key })

  // The Sumi glyph for an app, by what it is; "" when the set has none.
  function lineIconFor(item) {
    return Icons.appGlyph(item.entry && item.entry.id ? item.entry.id : item.key)
  }

  function normalizeId(value) {
    var id = String(value || "").trim()
    return id.slice(-8) === ".desktop" ? id.slice(0, -8) : id
  }

  function prettyName(key) {
    var tail = String(key).split(".").pop().replace(/[-_]+/g, " ")
    return tail.charAt(0).toUpperCase() + tail.slice(1)
  }

  function iconFor(entry, key) {
    var name = entry && entry.icon ? String(entry.icon) : String(key)
    if (name.charAt(0) === "/") return "file://" + name
    var path = Quickshell.iconPath(name, true)
    if (!path) path = Quickshell.iconPath(String(key).toLowerCase(), true)
    return path || Quickshell.iconPath("application-x-executable", true)
  }

  // ---- actions -------------------------------------------------------------

  function launch(item) {
    if (!item || !item.entry) return
    var id = String(item.entry.id || item.key)
    if (item.entry.runInTerminal) {
      var words = (item.entry.command || []).filter(function(word) { return !/^%[a-zA-Z]$/.test(String(word)) })
      Util.execDetached("omarchy-launch-tui " + words.map(function(word) { return Util.shellQuote(word) }).join(" "))
    } else {
      Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(id + ".desktop"))
    }
    var next = Object.assign({}, launching)
    next[item.key] = { at: Date.now(), windows: item.windows.length }
    launching = next
  }

  function isLaunching(key) {
    return launching[key] !== undefined
  }

  // Clicking an open app brings it forward; clicking it again while it is in
  // front steps through its windows.
  function activate(item) {
    if (!item) return
    if (item.windows.length === 0) {
      launch(item)
      return
    }
    var index = -1
    for (var i = 0; i < item.windows.length; i++) if (item.windows[i].toplevel.activated) index = i
    if (index >= 0) {
      if (item.windows.length < 2) return
      index = (index + 1) % item.windows.length
    } else {
      var monitor = Hyprland.focusedMonitor
      var current = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
      index = 0
      for (var k = 0; k < item.windows.length; k++) if (item.windows[k].workspaceId === current) { index = k; break }
    }
    focusWindow(item.windows[index])
  }

  function focusWindow(window) {
    var address = window.address
    if (!address) {
      window.toplevel.activate()
      return
    }
    if (address.indexOf("0x") !== 0) address = "0x" + address
    var target = "window = \"address:" + address + "\""
    Util.execDetached("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ " + target + " })")
      + " && hyprctl dispatch " + Util.shellQuote("hl.dsp.window.alter_zorder({ mode = \"top\", " + target + " })"))
  }

  function quit(item) {
    if (!item) return
    var windows = item.windows.slice()
    for (var i = 0; i < windows.length; i++) windows[i].toplevel.close()
  }

  function setPinned(item, pinned) {
    if (!item || !item.entry) return
    var id = String(item.entry.id || item.key)
    if (pinned) pin(id)
    else unpin(id)
  }

  function isPinned(id) {
    return pinnedIds.indexOf(normalizeId(id)) >= 0
  }

  function pin(id, index) {
    var key = normalizeId(id)
    var ids = pinnedIds.filter(function(other) { return other !== key })
    ids.splice(index === undefined ? ids.length : Math.max(0, Math.min(index, ids.length)), 0, key)
    setPinnedOrder(ids)
  }

  function unpin(id) {
    var key = normalizeId(id)
    setPinnedOrder(pinnedIds.filter(function(other) { return other !== key }))
  }

  // Shows the new pins at once, then saves them; the file watch confirms.
  function setPinnedOrder(ids) {
    if (JSON.stringify(ids) === JSON.stringify(pinnedIds)) return
    var previous = pinnedIds
    dockConfig = Object.assign({}, dockConfig, { pinned: ids })
    // `pinned` with no ids prints the list rather than clearing it.
    if (ids.length === 0) {
      Util.execDetached(previous.map(function(id) { return "omarchy-dock unpin " + Util.shellQuote(id) }).join("; "))
      return
    }
    Util.execDetached("omarchy-dock pinned " + ids.map(function(id) { return Util.shellQuote(id) }).join(" "))
  }

  // Every app worth offering, by name.
  readonly property var library: {
    var values = DesktopEntries.applications.values
    var out = []
    var seen = {}
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay || !entry.id || seen[entry.id]) continue
      seen[entry.id] = true
      out.push({ id: String(entry.id), name: String(entry.name || entry.id), icon: iconFor(entry, entry.id), entry: entry })
    }
    out.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return out
  }

  // ---- plumbing ------------------------------------------------------------

  property Timer launchSweep: Timer {
    interval: 400
    repeat: true
    running: Object.keys(model.launching).length > 0
    onTriggered: {
      var next = {}
      var changed = false
      var now = Date.now()
      for (var key in model.launching) {
        var launch = model.launching[key]
        var count = 0
        for (var i = 0; i < model.items.length; i++) if (model.items[i].key === key) count = model.items[i].windows.length
        if (count > launch.windows || now - launch.at > 8000) changed = true
        else next[key] = launch
      }
      if (changed) model.launching = next
    }
  }

  property FileView configFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        model.dockConfig = parsed && typeof parsed.dock === "object" && parsed.dock ? parsed.dock : {}
      } catch (error) {
        // Mid-write; the next change event brings the whole file.
      }
    }
  }
}
