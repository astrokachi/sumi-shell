import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons

// A quiet menu bar built around a notch. The strip carries the Omarchy menu,
// workspaces, the focused app and a few status widgets from `right`; the
// notch shows the time and opens sideways into the widgets placed in
// `centerBegin` (left wing) and `centerEnd` + `tray` (right wing). Widgets in
// `center` sit inside the notch at rest. A dock runs along the bottom edge.
Item {
  id: root

  // Injected by the shell (only declared properties are set).
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})

  // First-party services the control center drives (night light, Do Not
  // Disturb, stay awake). The shell is injected after the bar is built and a
  // service can start later still, so keep looking until all three answer.
  // Asking for omarchy.notifications reaches the clone standing in for it.
  property var nightlightService: null
  property var notificationsService: null
  property var idleService: null
  readonly property bool servicesResolved: !!nightlightService && !!notificationsService && !!idleService

  function resolveServices() {
    if (!shell || typeof shell.firstPartyServiceFor !== "function") return
    if (!nightlightService) nightlightService = shell.firstPartyServiceFor("omarchy.nightlight")
    if (!notificationsService) notificationsService = shell.firstPartyServiceFor("omarchy.notifications")
    if (!idleService) idleService = shell.firstPartyServiceFor("omarchy.idle")
  }

  onShellChanged: resolveServices()

  Timer {
    interval: 2000
    repeat: true
    running: !!root.shell && !root.servicesResolved
    onTriggered: root.resolveServices()
  }

  // The bar surface hosted widgets read, matching the stock bar's.
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property int barSize: Style.space(barSizeName === "small" ? 28 : barSizeName === "large" ? 36 : 32)
  // Sumi: one interface family for the bar and everything it hosts.
  readonly property var ds: sumiTokens
  readonly property string fontFamily: ds.fontUi
  readonly property string uiFamily: ds.fontUi
  readonly property color foreground: Commons.Color.bar.text
  readonly property color barForeground: foreground
  readonly property color background: Commons.Color.bar.background
  readonly property color urgent: Commons.Color.bar.active
  // Sumi glass: ink at 62% over a blur, as in the design.
  readonly property color glassBackground: Qt.rgba(background.r, background.g, background.b, Math.min(background.a, 0.62))
  property string look: "glassy"
  readonly property bool transparent: look === "none"
  readonly property bool glassy: look === "glassy"
  // The fill behind the control center, launcher and Omarchy menu, so they
  // match the bar: solid when it is solid, frosted when it is frosted. A clear
  // bar still gets frosted panels, or their text would sit on the wallpaper.
  readonly property color panelBackground: glassy || transparent ? glassBackground : background
  property bool foregroundAnimationEnabled: true
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property bool traySectionDragActive: false
  property bool traySectionPopoutOpen: false
  property var activePopout: null
  property var clickTargets: []
  property var layoutConfig: Util.normalizeLayout({})
  property string layoutKey: ""
  property bool barHidden: false
  readonly property var screenBarSizes: {
    var sizes = {}
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) sizes[screens[i].name] = barHidden ? 0 : barSize
    return sizes
  }

  // ---- appearance (bar.notch in shell.json, set from the Bar tab) ----------

  function pick(value, allowed, fallback) {
    return allowed.indexOf(value) >= 0 ? value : fallback
  }

  readonly property string barSizeName: pick(notchConfig.size, ["small", "medium", "large"], "medium")
  // notch: hanging from the top edge; island: a floating pill; flush: no
  // shape, its contents sit straight on the bar.
  readonly property string notchShape: pick(notchConfig.shape, ["notch", "island", "flush"], "notch")
  // black: like the hardware; glass: a light frosted tint with a hairline
  // edge; solid: the theme's background.
  readonly property string notchTone: pick(notchConfig.tone, ["black", "glass", "solid"], "black")
  readonly property string workspaceStyle: pick(notchConfig.workspaceStyle, ["dots", "numbers", "pills"], "dots")
  readonly property bool workspacesOccupiedOnly: notchConfig.workspacesOccupiedOnly === true
  readonly property bool showAppName: notchConfig.showAppName !== false
  readonly property bool clock24: notchConfig.clock24 === true
  readonly property bool showDate: notchConfig.showDate !== false
  readonly property string appIconStyle: pick(notchConfig.appIcons, ["line", "original"], "line")

  readonly property color notchColor: notchShape === "flush" ? "transparent"
    : notchTone === "glass" ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.11)
    : notchTone === "solid" ? Qt.rgba(background.r, background.g, background.b, 1)
    : ds.notch
  readonly property color notchEdge: notchShape !== "flush" && notchTone === "glass"
    ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16) : "transparent"
  readonly property color notchInk: notchShape === "flush" || notchTone !== "black" ? foreground : "#f5f5f7"

  // Notches are open unless folded away; this holds the folded screens.
  property var collapsedScreens: ({})
  // bar.notch in shell.json: startOpen, and the widgets switched off.
  readonly property var notchConfig: Util.isPlainObject(barConfig) && Util.isPlainObject(barConfig.notch) ? barConfig.notch : ({})
  property bool startStateApplied: false
  // Live system state for the status glyphs and the control center, and
  // the screen whose control center is open.
  readonly property var system: systemState
  property string controlCenterScreen: ""
  // A part to open with it ("wifi", "bluetooth", "sound", "battery").
  property string controlCenterPart: ""

  function toggleControlCenter(screenName) {
    var name = screenName || focusedScreenName()
    controlCenterScreen = controlCenterScreen === name ? "" : name
  }

  function closeControlCenter() {
    controlCenterScreen = ""
  }

  // The screen whose control panel is open, and the tab it opens on.
  property string customizeScreen: ""
  property string controlTab: "quick"
  readonly property var dock: dockModel
  // bar.notch.dock = false in shell.json drops the dock windows entirely. The
  // dock model stays: the launcher and app library read apps and pins from it.
  readonly property bool dockEnabled: notchConfig.dock !== false
  property var widgetHosts: []
  property string glassSyncedLook: ""

  // Tooltip state, drawn by the window that owns the target.
  property var tooltipTarget: null
  property string tooltipText: ""
  property bool tooltipShown: false
  property var pendingTooltipTarget: null
  property string pendingTooltipText: ""

  onBarConfigChanged: applyBarConfig()
  Component.onCompleted: applyBarConfig()

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : {}
    // Whether notches start open is read once, from the first real config.
    if (!startStateApplied && config.layout) {
      startStateApplied = true
      if (Util.isPlainObject(config.notch) && config.notch.startOpen === false) {
        var folded = {}
        for (var s = 0; s < Quickshell.screens.length; s++) folded[Quickshell.screens[s].name] = true
        collapsedScreens = folded
      }
    }
    look = config.background || (config.transparent === true ? "none" : "glassy")
    if (look !== glassSyncedLook) {
      glassSyncedLook = look
      Util.execDetached("omarchy-bar sync-glass")
    }
    // shell.json is re-pushed on every write, including ones that leave the
    // bar alone; rebuilding the widgets then would close their open panels.
    var next = Util.normalizeLayout(config.layout)
    var key = JSON.stringify(next)
    if (key === layoutKey) return
    layoutKey = key
    layoutConfig = next
  }

  function entries(sections) {
    var out = []
    for (var i = 0; i < sections.length; i++) {
      var list = layoutConfig[sections[i]] || []
      for (var j = 0; j < list.length; j++) out.push(list[j])
    }
    return out
  }

  // ---- expansion -----------------------------------------------------------

  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  function isExpanded(screenName) {
    return collapsedScreens[screenName] !== true
  }

  function setExpanded(screenName, value) {
    var name = screenName || focusedScreenName()
    var next = Object.assign({}, collapsedScreens)
    if (value) delete next[name]
    else next[name] = true
    collapsedScreens = next
  }

  function expand(screenName) { setExpanded(screenName, true) }
  function collapse(screenName) { setExpanded(screenName, false) }
  function toggleExpanded(screenName) {
    var name = screenName || focusedScreenName()
    setExpanded(name, !isExpanded(name))
  }

  // ---- customizing -----------------------------------------------------------

  function toggleCustomize(screenName) {
    var name = screenName || focusedScreenName()
    customizeScreen = customizeScreen === name ? "" : name
  }

  function closeCustomize() {
    customizeScreen = ""
  }

  function saveNotchLayout(layout, notch) {
    if (!shell || typeof shell.mutateShellConfig !== "function") return
    shell.mutateShellConfig(function(config) {
      if (!Util.isPlainObject(config.bar)) config.bar = {}
      config.bar.layout = layout
      config.bar.notch = notch
    })
  }

  function updateBarConfig(change) {
    if (!shell || typeof shell.mutateShellConfig !== "function") return
    shell.mutateShellConfig(function(config) {
      if (!Util.isPlainObject(config.bar)) config.bar = {}
      change(config.bar)
    })
  }

  function setNotchOption(key, value) {
    updateBarConfig(function(bar) {
      if (!Util.isPlainObject(bar.notch)) bar.notch = {}
      bar.notch[key] = value
    })
  }

  // Through Omarchy's command, which also syncs the blur behind the bar.
  function setBarBackground(value) {
    Util.execDetached("omarchy-bar background " + Util.shellQuote(value))
  }

  function setNotchStartOpen(value) {
    var notch = JSON.parse(JSON.stringify(notchConfig))
    notch.startOpen = !!value
    saveNotchLayout(JSON.parse(JSON.stringify(layoutConfig)), notch)
  }

  // ---- widget hosts ----------------------------------------------------------

  function registerWidgetHost(host) {
    if (!host || widgetHosts.indexOf(host) !== -1) return
    widgetHosts = widgetHosts.concat([host])
  }

  function unregisterWidgetHost(host) {
    widgetHosts = widgetHosts.filter(function(item) { return item !== host })
  }

  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    for (var i = 0; i < widgetHosts.length; i++) {
      var host = widgetHosts[i]
      if (host && host.activeItem && host.moduleName === id) items.push(host.activeItem)
    }
    return items
  }

  // The live instance a hotkey acts on: an open one first, then the one on
  // the focused monitor.
  function findPanelHost(pluginId) {
    var id = String(pluginId || "")
    var focused = focusedScreenName()
    var best = null
    for (var i = 0; i < widgetHosts.length; i++) {
      var host = widgetHosts[i]
      if (!host || host.moduleName !== id || !host.activeItem) continue
      var item = host.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function") continue
      if (item.opened === true) return host
      if (!best || (host.screenName === focused && best.screenName !== focused)) best = host
    }
    return best
  }

  function summonBarWidget(pluginId) {
    var host = findPanelHost(pluginId)
    if (!host) return false
    // A widget folded into the notch opens it first so its panel has a
    // visible anchor to hang from.
    if (host.inNotch && !isExpanded(host.screenName)) {
      expand(host.screenName)
      Qt.callLater(function() { if (host.activeItem) host.activeItem.open() })
      return true
    }
    host.activeItem.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var host = findPanelHost(pluginId)
    if (!host) return false
    host.activeItem.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var host = findPanelHost(pluginId)
    return !!host && host.activeItem.opened === true
  }

  function panelWidgetIdAt(region, index) {
    var list = layoutConfig[String(region || "")] || []
    var entry = list[Math.round(Number(index)) - 1]
    return entry ? String(entry.id || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    var current = null
    for (var i = 0; i < widgetHosts.length; i++) {
      if (widgetHosts[i] && widgetHosts[i].activeItem === owner) { current = widgetHosts[i]; break }
    }
    if (!current) return false
    var peers = widgetHosts.filter(function(host) {
      return host && host.screenName === current.screenName && host.inNotch === current.inNotch
        && host.activeItem && typeof host.activeItem.open === "function" && host.visible
    })
    peers.sort(function(a, b) { return a.mapToItem(null, 0, 0).x - b.mapToItem(null, 0, 0).x })
    var index = peers.indexOf(current)
    if (index < 0 || peers.length < 2) return false
    var next = peers[(index + (direction < 0 ? -1 : 1) + peers.length) % peers.length]
    next.activeItem.open()
    return true
  }

  // ---- one menu at a time ------------------------------------------------------

  // Opening any menu closes whichever one was already out: the control
  // center, the Controls panel, the launcher, a widget's popout, the dock's
  // menu and app library, and the Omarchy menu and notification panel, which
  // report themselves over IPC (menuOpened / menuClosed) from their plugins.
  signal menusClosing(var keep)
  property var externalMenus: ({})
  readonly property var externalMenuClosers: ({
    "sumi.menu": "omarchy-shell -q shell hide omarchy.menu",
    "sumi.notifications": "omarchy-shell -q notifications closePanel"
  })

  onControlCenterScreenChanged: if (controlCenterScreen !== "") closeMenusExcept("controlCenter")
  onCustomizeScreenChanged: if (customizeScreen !== "") closeMenusExcept("customize")
  onActivePopoutChanged: if (activePopout) closeMenusExcept("popout")

  function closeMenusExcept(keep) {
    if (keep !== "controlCenter") controlCenterScreen = ""
    if (keep !== "customize") customizeScreen = ""
    if (keep !== "launcher") launcherOpen = false
    if (keep !== "popout" && activePopout) {
      var popout = activePopout
      if ("close" in popout) popout.close()
      releasePopout(popout)
    }
    menusClosing(keep)
    var kept = {}
    for (var id in externalMenus) {
      if (id === keep) kept[id] = true
      else run(externalMenuClosers[id])
    }
    externalMenus = kept
  }

  function noteExternalMenu(id, opened) {
    if (!externalMenuClosers[id]) return
    var next = Object.assign({}, externalMenus)
    if (opened) next[id] = true
    else delete next[id]
    externalMenus = next
    if (opened) closeMenusExcept(id)
  }

  // ---- popouts, click targets, commands ---------------------------------------

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    clickTargets = clickTargets.concat([target])
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(item) { return item !== target })
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && !!target.QsWindow && target.QsWindow.window === window
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  function run(command) {
    if (command) Util.execDetached(command)
  }

  function cycleBackground() {
    Util.execDetached("omarchy-bar background cycle")
  }

  function barSizeFor(screenName) {
    return barHidden ? 0 : barSize
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < widgetHosts.length; i++) {
      var host = widgetHosts[i]
      if (!host) continue
      var point = host.mapToItem(null, 0, 0)
      out.push({ id: host.moduleName, screen: host.screenName, inNotch: host.inNotch,
        x: Math.round(point.x), y: Math.round(point.y),
        width: Math.round(host.width), height: Math.round(host.height), visible: host.visible,
        loaded: !!host.activeItem, itemVisible: host.activeItem ? host.activeItem.visible : null,
        hasEntry: !!host.registryEntry, hasComponent: !!(host.registryEntry && host.registryEntry.component), status: host.loaderStatus })
    }
    return out
  }

  // ---- tooltips ----------------------------------------------------------------

  function showTooltip(target, text) {
    pendingTooltipTarget = target
    pendingTooltipText = String(text || "")
    if (tooltipShown) applyTooltip()
    else tooltipTimer.restart()
  }

  function hideTooltip(target) {
    if (target && pendingTooltipTarget !== target && tooltipTarget !== target) return
    tooltipTimer.stop()
    pendingTooltipTarget = null
    tooltipShown = false
    tooltipTarget = null
    tooltipText = ""
  }

  function applyTooltip() {
    tooltipTarget = pendingTooltipTarget
    tooltipText = pendingTooltipText
    tooltipShown = tooltipTarget !== null && tooltipText !== ""
  }

  Timer {
    id: tooltipTimer
    interval: 450
    onTriggered: root.applyTooltip()
  }

  // ---- registry prime -----------------------------------------------------------

  // On this Omarchy, the first shell.json change after the shell starts
  // revokes the components behind plugin bar widgets, blanking them; one
  // plugin rescan per shell process prevents it (Shibumi's bar does the
  // same). The rescan rebuilds this bar, so a marker holding the shell's pid
  // makes sure it happens only once.
  Process {
    running: true
    command: ["bash", "-c",
      "f=\"${XDG_RUNTIME_DIR:-/tmp}/sumi-notch-primed\"; [[ $(cat \"$f\" 2>/dev/null) == \"$1\" ]] && exit 0; "
      + "printf '%s' \"$1\" > \"$f\"; sleep 1; omarchy-shell -q shell rescanPlugins",
      "prime", String(Quickshell.processId)]
  }

  // ---- hidden bar (omarchy toggle bar) -----------------------------------------

  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  ShellIpc {
    target: "omarchy.bar"
    function syncHidden(): void { barHiddenProbe.running = true }
  }

  // Answers for Omarchy's dock, which this dock replaces: the menu's Apps
  // row and any `omarchy-shell omarchy.dock apps` binding open the library.
  ShellIpc {
    target: "omarchy.dock"
    function apps(): void { root.toggleLauncher() }
    function refresh(): void { }
  }

  // ---- launcher ----------------------------------------------------------------

  property bool launcherOpen: false
  property string launcherQuery: ""
  onLauncherOpenChanged: {
    if (launcherOpen) closeMenusExcept("launcher")
    else launcherQuery = ""
  }
  property var launcherScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

  function toggleLauncher() {
    if (launcherOpen) { launcherOpen = false; return }
    var name = focusedScreenName()
    for (var i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === name) launcherScreen = Quickshell.screens[i]
    launcherOpen = true
  }

  Launcher {
    host: root
    screenModel: root.launcherScreen
    wanted: root.launcherOpen
    initialQuery: root.launcherQuery
    onDismissed: root.launcherOpen = false
  }

  // omarchy-shell sumi.notch toggle|open|close
  ShellIpc {
    target: "sumi.notch"
    function toggle(): void { root.toggleExpanded("") }
    function open(): void { root.expand("") }
    function close(): void { root.collapse("") }
    function toggleDock(): void { dockModel.held = !dockModel.held }
    function apps(): void { dockModel.libraryToggled(root.focusedScreenName()) }
    function customize(): void { root.toggleCustomize("") }
    function controlCenter(): void { root.toggleControlCenter("") }
    function controlCenterAt(part: string): void {
      root.controlCenterPart = part
      if (root.controlCenterScreen === "") root.toggleControlCenter("")
    }
    function closeControlCenter(): void { root.closeControlCenter() }
    function launcher(): void { root.toggleLauncher() }
    function launcherWith(text: string): void {
      root.launcherQuery = text
      if (!root.launcherOpen) root.toggleLauncher()
    }
    function openWidget(id: string): void { root.summonBarWidget(id) }
    function menuOpened(id: string): void { root.noteExternalMenu(id, true) }
    function menuClosed(id: string): void { root.noteExternalMenu(id, false) }
    function controlTab(tab: string): void {
      root.controlTab = tab
      if (root.customizeScreen === "") root.toggleCustomize("")
    }
    function debug(): string {
      var reg = root.barWidgetRegistry
      var meta = {}
      if (reg && reg.widgets) for (var k in reg.widgets) meta[k] = reg.widgets[k].metadata
      return JSON.stringify({ hosts: root.debugBarGeometry(), registry: reg && reg.widgets ? Object.keys(reg.widgets) : null, meta: meta,
        services: { nightlight: !!root.nightlightService, notifications: !!root.notificationsService, idle: !!root.idleService },
        menus: { controlCenter: root.controlCenterScreen, customize: root.customizeScreen, launcher: root.launcherOpen,
          popout: !!root.activePopout, external: Object.keys(root.externalMenus) } })
    }
  }

  Variants {
    model: Quickshell.screens

    BarWindow {
      host: root
    }
  }

  SumiTokens {
    id: sumiTokens
    textBump: Math.max(-4, Math.min(12, Math.round(Number(root.notchConfig.textBump) || 0)))
  }
  SystemState {
    id: systemState
    active: root.controlCenterScreen !== ""
    cities: root.worldCities
  }

  // The world clock's cities, wherever its entry is kept (on the bar or put
  // away in the tray); this screen's own zone when it has none.
  readonly property var worldCities: {
    var lists = [layoutConfig.left, layoutConfig.centerBegin, layoutConfig.center, layoutConfig.centerEnd, layoutConfig.right, layoutConfig.tray]
    for (var i = 0; i < lists.length; i++) {
      var list = lists[i] || []
      for (var j = 0; j < list.length; j++) if (/elsewhen$/.test(list[j].id) && Array.isArray(list[j].cities)) return list[j].cities
    }
    var off = Array.isArray(notchConfig.off) ? notchConfig.off : []
    for (var k = 0; k < off.length; k++) {
      var entry = off[k].entry || {}
      if (/elsewhen$/.test(entry.id) && Array.isArray(entry.cities)) return entry.cities
    }
    return []
  }

  // ---- dock ----------------------------------------------------------------

  DockModel { id: dockModel; appIconStyle: root.appIconStyle }

  Variants {
    model: root.dockEnabled ? Quickshell.screens : []

    DockWindow {
      host: root
      dock: dockModel
    }
  }
}
