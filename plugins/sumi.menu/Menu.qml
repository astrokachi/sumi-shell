import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import QtQuick.Effects
import "MenuModel.js" as MenuModel
// Sumi: the shared icon set and its glyph maps live with the notch.
import "../sumi.notch" as Sumi
import "../sumi.notch/Icons.js" as Icons

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Plugin lifecycle hooks. The host calls open(payloadJson) after
  // `omarchy-shell shell summon omarchy.menu ...` and close() when hidden.
  property string pendingInitialMenu: "root"

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    if (payload.fontFamily) root.fontFamily = payload.fontFamily

    if (payload.mode === "select" || payload.mode === "input") {
      root.openDmenu(payload)
    } else {
      root.openRoute(payload.initialMenu || payload.menu || "root")
    }
  }

  function close() {
    root.cancel()
  }

  function refresh() {
    defaultMenuFile.reload()
    suiteMenuFile.reload()
    userMenuFile.reload()
    languageFile.reload()
    menuCatalogFile.reload()
    return "ok"
  }

  function ping() { return "ok" }

  // A shell restart drops every open picker request unanswered, and the stock
  // omarchy-menu-select / omarchy-menu-images callers then poll for a done
  // file forever (the image one every 10 ms, ~6% CPU each). Anything of theirs
  // older than this shell can never be answered, so stop it at startup.
  Component.onCompleted: Quickshell.execDetached(["bash", "-c",
    "shell=$(pgrep -xn quickshell) || exit 0; age=$(ps -o etimes= -p \"$shell\") || exit 0; "
    + "for p in $(pgrep -f '/bin/omarchy-menu-(select|images)( |$)'); do "
    + "a=$(ps -o etimes= -p \"$p\") && (( a > age )) && kill \"$p\"; done"])

  property string fontFamily: Style.font.menuFamily
  // JSONC menu definitions. The shell parses both at startup and merges
  // the user file on top of the defaults, so the keybind → IPC → visible
  // path doesn't have to shell out to bash + jq on every open.
  property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  // Display language for the shipped rows. The code lives in
  // ~/.config/omarchy/language (omarchy-language owns it); a missing file
  // means English. The catalog at default/i18n/<code>/menu.json is applied
  // to the default items before the user extension merges on top, so a
  // user's own rows and retitles always win.
  property string language: "en"
  property var menuCatalog: ({})
  readonly property string languagePath: Quickshell.env("OMARCHY_LANGUAGE_FILE") || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy/language")
  property var defaultMenuItems: []
  property var userMenuItems: []
  // Sumi's own rows and retitles, shipped with this plugin (sumi-menu.jsonc).
  // They sit between Omarchy's defaults and the user's extension file, so
  // the user's own entries still win.
  property var suiteMenuItems: []
  // Whether each file has answered once, loaded or (the user's) missing. At
  // startup both arrive separately, and evaluating guards for the first alone
  // would run the whole batch twice; an open before then evaluates anyway.
  property bool defaultMenuSettled: false
  property bool userMenuSettled: false
  property bool opened: false
  property string mode: "menu"
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property bool dmenuMultiple: false
  property var dmenuSelected: []
  // What the last confirmed change applied; a failed change returns the checks here.
  property var dmenuSaved: []
  property string dmenuChangeKey: ""
  property var dmenuOnChange: []
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  property bool requestActive: false
  property bool rowsLoaded: false
  property string activeMenu: "root"
  property string filterText: ""
  // Resets of filterText reach the search line; its edits come back through setFilter.
  onFilterTextChanged: if (filterInput.text !== filterText) filterInput.text = filterText
  property int selectedIndex: 0
  property bool cursorActive: false
  property int requestSerial: 0
  property int applySerial: 0
  property var items: ({})
  property var itemOrder: []
  property var navStack: []
  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0

  // Shared application engine (entries, hidden filters, icons, launch,
  // removal), owned by the shell and also used by the standalone launcher.
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
  property bool deleteConfirmOpen: false
  property var deleteTarget: null
  onOpenedChanged: {
    if (!opened) { deleteConfirmOpen = false; deleteTarget = null }
    // The notch keeps one menu out at a time; tell it this one came or went.
    Util.execDetached("omarchy-shell -q sumi.notch " + (opened ? "menuOpened" : "menuClosed") + " sumi.menu")
  }
  // Bound to the central [menu] section in shell.toml via Commons.Color.qml.
  // Each color already includes its alpha companion (composed in the
  // singleton), so consumers can drop them straight into a Rectangle.
  // The background instead follows the bar, as the control center and
  // launcher do: the bar's colour, frosted unless the bar is solid.
  readonly property string barLook: root.shell && root.shell.barConfig
    && root.shell.barConfig.background ? root.shell.barConfig.background : "glassy"
  readonly property color barBackground: Commons.Color.bar.background
  property color background: barLook === "opaque" ? barBackground
    : Qt.rgba(barBackground.r, barBackground.g, barBackground.b, Math.min(barBackground.a, 0.62))
  property color foreground: Commons.Color.menu.text
  // Sumi: a hairline edge, a 14 px card with 8 px rows inside it, 36 px
  // rows and 14 px labels. The edge is the Control Center's ink hairline
  // whatever the theme's [menu] border says; some themes set it bright.
  property color border: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.09)
  property var borderSpec: Border.flat(border, 1)
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  property color selectedBorder: Commons.Color.menu.selectedBorder
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", selectedBorder, 0)
  readonly property real rowReservedBorderLeft: Border.left(selectedBorderSpec)
  readonly property real rowReservedBorderRight: Border.right(selectedBorderSpec)
  readonly property int cornerRadius: 14
  readonly property int rowRadius: 8
  readonly property color ink2: Util.alpha(foreground, 0.64)
  // A dropdown under the bar's mark that cascades its submenus to the
  // right, as in the Sumi design. Prompts from scripts (dmenu) stay a
  // centred dialog.
  readonly property bool dropdown: !root.dmenuActive
  property int contentMargin: root.dropdown ? Style.space(6) : Style.space(8)
  // The search line only appears once you type.
  property int headerHeight: root.dropdown ? (root.filterText ? Style.space(40) : 0) : Style.space(44)
  property int contentSpacing: root.dropdown ? (root.filterText ? Style.space(6) : 0) : Style.space(6)
  property int baseRowHeight: root.dropdown ? Style.space(34) : Style.space(36)
  // Drill-in: inside a submenu the card is headed by a back row.
  property int backRowHeight: root.dropdown && !root.dmenuActive && !root.filterText && root.activeMenu !== "root" ? root.baseRowHeight : 0
  // Every level of the drill-in uses the same card width, so going in and out
  // never moves the card's edges. Wider menus (fonts, screen recording) still
  // get their extra room.
  function drillWidthFor(menuId) { return Math.max(Style.space(272), root.cardWidthFor(menuId)) }
  property int detailRowHeight: Style.space(48)
  readonly property int sepHeight: Style.space(11)
  readonly property string monoFamily: "JetBrainsMono Nerd Font"
  readonly property color ink3: Util.alpha(foreground, 0.56)
  readonly property int cascadeGap: Style.space(6)
  // The root card opens where the Apps launcher does: centred, 15% down the
  // screen. Submenus still cascade out to its right.
  readonly property int dropLeft: Math.max(Style.space(10), Math.round((panel.width - root.cardWidthFor("root")) / 2))
  readonly property int dropTop: Math.max(Style.space(40), Math.round(panel.height * 0.15))

  // ---- Sumi: groups, key hints and values -------------------------------

  // Hairlines between groups, per menu.
  readonly property var groupMaps: ({
    root: { apps: 1, learn: 1, trigger: 1, style: 1, setup: 1, install: 2, remove: 2, update: 2, about: 3, system: 3 },
    system: { "system.screensaver": 1, "system.lock": 1, "system.suspend": 2, "system.hibernate": 2,
      "system.logout": 3, "system.reboot": 3, "system.shutdown": 3 },
    trigger: { "trigger.appearance": 1, "trigger.toggle": 1, "trigger.capture": 2, "trigger.clipboard-history": 2,
      "trigger.emoji": 2, "trigger.share": 2, "trigger.transcode": 2, "trigger.reminder": 3, "trigger.hardware": 3, "trigger.tests": 3 }
  })

  function groupOf(id) {
    var entry = root.item(id)
    var map = entry ? root.groupMaps[entry.parent] : null
    return map && map[id] !== undefined ? String(map[id]) : ""
  }

  // A hairline above this row when it starts a new group.
  function sepAbove(index) {
    if (!root.dropdown || root.filterText || index <= 0 || index >= displayModel.count) return false
    var here = root.groupOf(displayModel.get(index).itemId)
    return here !== "" && here !== root.groupOf(displayModel.get(index - 1).itemId)
  }

  function sepAboveIn(rows, index) {
    if (index <= 0) return false
    var here = root.groupOf(rows[index].itemId)
    return here !== "" && here !== root.groupOf(rows[index - 1].itemId)
  }

  // The keys that open an entry directly, from Omarchy's own bindings.
  readonly property var keyHints: ({
    apps: "super alt ␣", system: "super esc", "system.lock": "super ctrl L",
    "trigger.capture": "super ctrl C", "trigger.capture.screenshot": "super shift S",
    "trigger.toggle": "super ctrl O", "trigger.hardware": "super ctrl H", "trigger.share": "super ctrl S",
    "trigger.emoji": "super ctrl E", "trigger.clipboard-history": "super ctrl V",
    "trigger.reminder.set": "super ctrl R",
    "style.theme": "super shift ctrl ␣", "style.background": "super ctrl ␣",
    "learn.keybindings": "super K"
  })

  // Live answers shown beside rows (current theme, toggle states, ...),
  // read each time the menu opens.
  property var valueMap: ({})

  function valueFor(id, label) {
    var v = root.valueMap
    if (id === "style.theme") return v.theme || ""
    if (id === "style.background") return v.background || ""
    if (id === "style.font") return v.font || ""
    if (id === "style.font.cjk") return v.cjk ? v.cjk.toUpperCase() : ""
    if (id === "about") return v.version ? "Omarchy " + v.version.split("-")[0] : ""
    if (v[id] !== undefined) return v[id]
    return ""
  }

  Process {
    id: valuesProc
    property string collected: ""
    command: ["nice", "-n", "19", "bash", "-c",
      "printf 'theme\\t%s\\n' \"$(omarchy theme current 2>/dev/null)\"; "
      + "printf 'background\\t%s\\n' \"$(omarchy theme bg current 2>/dev/null | head -c 60)\"; "
      + "printf 'font\\t%s\\n' \"$(omarchy font current 2>/dev/null)\"; "
      + "printf 'cjk\\t%s\\n' \"$(omarchy font cjk 2>/dev/null)\"; "
      + "printf 'version\\t%s\\n' \"$(omarchy version 2>/dev/null)\"; "
      + "printf 'trigger.toggle.nightlight\\t%s\\n' \"$(omarchy toggle nightlight --status 2>/dev/null | jq -r 'if .enabled then \"On\" else \"Off\" end')\"; "
      + "printf 'trigger.toggle.idle-lock\\t%s\\n' \"$(omarchy toggle idle status 2>/dev/null | jq -r 'if .enabled then \"On\" else \"Off\" end')\"; "
      + "printf 'trigger.toggle.notifications\\t%s\\n' \"$( [ \"$(omarchy-shell notifications isDnd 2>/dev/null)\" = on ] && echo On || echo Off)\"; "
      + "printf 'trigger.toggle.screensaver\\t%s\\n' \"$( [ -f \"$HOME/.local/state/omarchy/toggles/screensaver-off\" ] && echo Off || echo On)\""]
    stdout: SplitParser { onRead: function(line) { valuesProc.collected += line + "\n" } }
    onExited: {
      var next = {}
      var lines = valuesProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t")
        if (tab > 0) next[lines[i].substring(0, tab)] = lines[i].substring(tab + 1).trim()
      }
      if (next.font) next.font = next.font.replace(/ Nerd Font( Mono| Propo)?$/, "").replace(/^JetBrainsMono$/, "JetBrains Mono")
      // An unchanged answer would still re-run every binding that reads it.
      if (JSON.stringify(next) !== JSON.stringify(root.valueMap)) root.valueMap = next
      valuesProc.collected = ""
    }
  }

  function refreshValues() {
    if (!valuesProc.running) valuesProc.running = true
  }

  // ---- Sumi: the cascade ---------------------------------------------------

  // The menus on screen, outermost first: the ones navigated through, then
  // the active one.
  readonly property var cascadePath: root.navStack.concat([root.activeMenu])

  // A menu's rows as it shows them unfiltered.
  function rowsFor(menuId, _serial, _guards) {
    var rows = []
    for (var j = 0; j < root.itemOrder.length; j++) {
      var child = root.item(root.itemOrder[j])
      if (!child || child.parent !== menuId) continue
      if (!root.isVisible(child)) continue
      rows.push(root.displayRow(child, child.description, child.order))
    }
    if (menuId === "apps") rows.sort(function(a, b) { return String(a.label).toLowerCase().localeCompare(String(b.label).toLowerCase()) })
    return rows
  }

  function cardWidthFor(menuId) {
    if (menuId === "root") return Style.space(252)
    if (menuId === "trigger.capture.screenrecord" || menuId === "style.font" || menuId === "style.font.cjk") return Style.space(320)
    return Style.space(272)
  }

  // Height of a card's rows up to (not including) row `index`.
  function rowsOffset(rows, index) {
    var y = 0
    for (var i = 0; i < index && i < rows.length; i++) {
      if (root.sepAboveIn(rows, i)) y += root.sepHeight
      y += root.baseRowHeight
    }
    if (root.sepAboveIn(rows, index)) y += root.sepHeight
    return y
  }

  // Where each level's card sits: [{ x, y, width }], outermost first.
  // Drill-in: every level opens in the same place as the root card (centred,
  // where the Apps launcher opens), so the menu never grows sideways or runs
  // off screen however deep it goes. Only the last entry is drawn.
  readonly property var cascadeGeometry: {
    void(root.layoutSerial)
    var out = []
    var path = root.cascadePath
    var margin = Style.space(10)
    for (var i = 0; i < path.length; i++) {
      var width = root.drillWidthFor(path[i])
      var x = Math.max(margin, Math.round((panel.width - width) / 2))
      out.push({ x: x, y: root.dropTop, width: width })
    }
    return out
  }

  // Opening a row in a menu further out: close what lay beyond it first.
  function activateInCascade(level, row) {
    var path = root.cascadePath
    root.navStack = path.slice(0, level)
    root.activeMenu = path[level]
    if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, true)
    } else if (row.kind === "app") {
      applySerial = requestSerial
      opened = false
      if (root.appLibrary) root.appLibrary.launch(row.appId, row.label)
    } else {
      root.applySelected(row.itemId, row.action)
    }
  }
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: root.dropdown ? 0 : Style.space(2)
  property int dividerHeight: Style.space(17)
  property bool searchDivider: false
  property int layoutSerial: 0
  property int cardWidth: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : ((root.activeMenu === "trigger.capture.screenrecord" || root.activeMenu === "style.font" || root.activeMenu === "style.font.cjk") ? Style.space(520) : Style.space(320)), panel.width - Style.gapsOut * 2)
  property int visibleRowsHeight: root.dmenuActive ? dmenuRowListHeight(layoutSerial, displayModel.count, filterText) : rowListHeight(layoutSerial, displayModel.count, filterText, searchDivider)
  property int cardHeight: root.dmenuActive
    ? Math.min(contentMargin * 2 + headerHeight + (mode === "input" ? 0 : contentSpacing + visibleRowsHeight), panel.height - Style.gapsOut * 2)
    : Math.min(contentMargin * 2 + headerHeight + backRowHeight + contentSpacing + visibleRowsHeight, panel.height - Style.gapsOut * 2)

  function finishRequest(selection) {
    if (!root.requestActive || !root.doneFile) {
      root.opened = false
      return
    }

    var activeSelectionFile = root.selectionFile
    var activeDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""

    if (selection === null || selection === undefined) {
      resultProc.command = ["bash", "-c", ": > " + Util.shellQuote(activeDoneFile)]
    } else {
      resultProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(selection) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    }
    resultProc.running = true
  }

  function runAction(action) {
    var command = String(action || "")
    if (!command) return

    var summon = MenuModel.summonAction(command)
    if (summon && root.shell && root.shell.summon(summon.id, summon.payload)) return

    Util.execDetached(command)
  }

  // Menu rows only surface their detail while a search is narrowing them;
  // dmenu rows carry caller-supplied subtext that must always be visible.
  function rowHeightForDetail(detail) {
    return (root.filterText || root.dmenuActive) && detail ? root.detailRowHeight : root.baseRowHeight
  }

  // Height the card can devote to rows before running off the screen — or
  // past the frozen top edge once a search has pinned the card in place.
  // Uses panel.cardTop rather than effectiveCardTop: the centered top is
  // derived from the card height, which this value feeds.
  function availableRowsHeight() {
    if (root.dropdown) {
      var geo = root.cascadeGeometry
      var cardY = geo.length ? geo[geo.length - 1].y : root.dropTop
      return Math.max(root.baseRowHeight * 3, panel.height - Math.min(cardY, panel.height * 0.4) - Style.space(24) - root.contentMargin * 2 - root.headerHeight - root.backRowHeight - root.contentSpacing)
    }
    var top = panel.cardTop >= 0 ? panel.cardTop : Style.gapsOut
    var available = panel.height - top - Style.gapsOut - root.contentMargin * 2 - root.headerHeight - root.contentSpacing
    // The starting menu sets the ceiling along with the offset: drilling into
    // a longer submenu scrolls behind the fold instead of growing the card.
    if (panel.maxRowsHeight >= 0) available = Math.min(available, panel.maxRowsHeight)
    // A card that swallows the whole screen reads as a page, not a menu.
    return Math.min(available, Math.round(panel.height * 0.7))
  }

  // When every row fits, the list gets its full height. When they don't,
  // the card must end mid-row: a clipped row is what tells the eye there is
  // more below the fold, so never come out even on a row boundary.
  function foldedListHeight(totals, available) {
    var count = totals.length
    if (count === 0) return root.baseRowHeight
    if (totals[count - 1] <= available) return totals[count - 1]

    var peek = root.rowPeek
    var full = 0
    while (full < count && totals[full] <= available) full++
    while (full > 1 && totals[full - 1] + root.rowSpacing + peek > available) full--
    if (full < 1) return Math.max(available, root.baseRowHeight)

    return totals[full - 1] + root.rowSpacing + peek
  }

  function rowListHeight(_serial, _count, _filter, _divider) {
    if (displayModel.count === 0) return root.baseRowHeight

    var totals = []
    var total = 0
    var previousSection = ""

    // Read the plain rows rebuildDisplay appended, not displayModel.get(),
    // which builds a wrapper per call; this runs several times a keystroke
    // over every result.
    var rows = root.shownRows
    var count = Math.min(displayModel.count, rows.length)
    for (var i = 0; i < count; i++) {
      var row = rows[i]
      if (i > 0) total += root.rowSpacing
      if (row.section === "drilldown" && previousSection !== "drilldown") total += root.dividerHeight
      if (root.dropdown && !root.filterText && root.sepAboveIn(rows, i)) total += root.sepHeight
      total += root.rowHeightForDetail(row.detail)
      previousSection = row.section
      totals.push(total)
    }

    return foldedListHeight(totals, availableRowsHeight())
  }

  function dmenuRowListHeight(_serial, _count, _filter) {
    if (root.mode === "input") return 0
    if (displayModel.count === 0) return root.baseRowHeight

    var available = availableRowsHeight()
    if (root.dmenuMaxHeight > 0) available = Math.min(available, Style.space(root.dmenuMaxHeight))

    var totals = []
    var total = 0
    var rows = root.shownRows
    var count = Math.min(displayModel.count, rows.length)
    for (var i = 0; i < count; i++) {
      if (i > 0) total += root.rowSpacing
      total += root.rowHeightForDetail(rows[i].detail)
      totals.push(total)
    }

    return foldedListHeight(totals, available)
  }

  function item(id) {
    return root.items[id] || null
  }

  // ------------------------------------------------------------------
  // JSONC → normalized item array. Mirrors the bash bin's jq pipeline so
  // the on-disk authoring format stays untouched.
  // ------------------------------------------------------------------

  function stripJsonc(raw) {
    return MenuModel.stripJsonc(raw)
  }

  function normalizeAliases(value) {
    return MenuModel.normalizeAliases(value)
  }

  function normalizeItem(id, raw) {
    return MenuModel.normalizeItem(id, raw)
  }

  function parseMenuJsonc(raw) {
    return MenuModel.parseMenuJsonc(raw)
  }

  function parseCatalog(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  function setLanguage(raw) {
    var code = String(raw || "").trim()
    if (!/^[a-z]{2,3}(-[A-Za-z]{2})?$/.test(code)) code = "en"
    if (root.language === code) return
    root.language = code
    menuCatalogFile.reload()
  }

  // Merge defaults + user extension. Later entries override earlier ones
  // on a per-key basis (so the user can tweak label/icon/action without
  // re-declaring the whole row).
  // Catalog-only rebuilds pass skipGuards: retitling rows cannot change any
  // when/checked answer, so re-running the guard batch would be pure waste.
  function rebuildItemsFromSources(skipGuards) {
    var translatedDefaults = MenuModel.applyTranslations(root.defaultMenuItems, root.menuCatalog)
    // The root row is injected by the merge (it has no JSONC entry), so its
    // "Go" label comes from the catalog's root entry; the merge only uses
    // it for the injected row, never over a user-supplied heading.
    var rootCatalog = root.menuCatalog.root
    var mergedMenu = MenuModel.mergeMenuSources(translatedDefaults, root.suiteMenuItems.concat(root.userMenuItems), rootCatalog && rootCatalog.label)
    root.providerRevision += 1
    root.providersLoaded = ({})
    root.providerQueue = []
    root.items = mergedMenu.items
    root.itemOrder = mergedMenu.itemOrder
    root.rowsLoaded = true
    if (!skipGuards && root.defaultMenuSettled && root.userMenuSettled) root.evaluateGuards()
    if (root.opened) {
      root.rebuildDisplay()
      if (!root.dmenuActive) {
        if (root.filterText.trim()) root.loadProvidersForSearch()
        else root.loadProviderForMenu(root.activeMenu)
      }
    }
  }

  // Each known provider is a tiny bash one-liner that enumerates a list and
  // emits one tab-delimited row per item: `label\tvalue\tcurrent`. The shell
  // turns those into menu items children of `menuId`. A `volatile` provider
  // re-runs every time its submenu is entered, so a font installed since the
  // shell started shows up without restarting it.
  readonly property var providers: ({
    "fonts": {
      script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      volatile: true,
      actionFor: function(value) { return "omarchy-font-set " + Util.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "\udb81\udc0b",
      // Profile names are powerprofilesctl ids; only the label is translated,
      // and the id stays searchable through searchTerms.
      labelFor: function(value) {
        if (value === "power-saver") return Commons.I18n.t("menu.powerProfilePowerSaver")
        if (value === "balanced") return Commons.I18n.t("menu.powerProfileBalanced")
        if (value === "performance") return Commons.I18n.t("menu.powerProfilePerformance")
        return value
      },
      actionFor: function(value) { return "omarchy-powerprofiles-set autodetect " + Util.shellQuote(value) }
    },
    // Rows carry a fourth field (the English name) so searching "danish"
    // finds the row labeled with its native name; mergeProviderRows turns
    // it into an alias.
    "languages": {
      script: "current=$(omarchy-language 2>/dev/null); omarchy-language list 2>/dev/null | while IFS=$'\\t' read -r name code english; do [[ -z $code ]] && continue; printf '%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$code\" \"$current\" \"$english\"; done",
      icon: "\uf1ab",
      volatile: true,
      actionFor: function(value) { return "omarchy-language " + Util.shellQuote(value) }
    }
  })

  function slugify(value) {
    return MenuModel.slugify(value)
  }

  // The apps provider is QML-native: rows come from the shared AppLibrary
  // (DesktopEntries) instead of a bash enumeration, so they carry image
  // icons, launch feedback, and uninstall support like the launcher.
  function mergeAppRows() {
    if (!root.appLibrary) return

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || ""),
        appId: appId,
        label: root.appLibrary.entryName(entry),
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        searchTerms: [],
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(root.items, root.itemOrder, appRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    if (entry.provider === "apps") {
      root.providersLoaded[id] = true
      root.mergeAppRows()
      return
    }
    var spec = root.providers[entry.provider]
    if (!spec) return

    root.providersLoaded[id] = true
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.revision = root.providerRevision
    providerProc.collected = ""
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function mergeProviderRows(rows, menuId, providerKey) {
    var spec = root.providers[providerKey]
    if (!spec) return
    var lines = String(rows || "").split("\n")
    var providerRows = []
    var takenIds = ({})
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      var rawLabel = parts[0] || ""
      var label = spec.labelFor ? spec.labelFor(rawLabel) : rawLabel
      var value = parts[1] || parts[0] || ""
      var current = parts[2] || ""
      if (!label) continue
      // Distinct values can slugify alike — Fira Code and Fira-Code both give
      // fira-code — and a repeated id is dropped, which would silently lose a
      // row from the list. Nudge it until it is the row's own.
      var rowId = menuId + "." + root.slugify(value)
      while (takenIds[rowId]) rowId += "-"
      takenIds[rowId] = true

      providerRows.push({
        id: rowId,
        parent: menuId,
        kind: "action",
        icon: (value === current) ? "✓" : (spec.icon || ""),
        label: label,
        title: "",
        target: "",
        description: "",
        action: spec.actionFor(value),
        provider: "",
        aliases: [],
        searchTerms: (parts[3] ? [parts[3]] : []).concat(label !== rawLabel ? [rawLabel] : []),
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, providerRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startNextProvider() {
    if (providerProc.running) return

    while (root.providerQueue.length > 0) {
      var id = root.providerQueue.shift()
      var entry = root.item(id)
      if (!entry || !entry.provider || root.providersLoaded[id]) continue

      root.startProviderForMenu(id)
      return
    }
  }

  // Entering a submenu is the one moment a volatile list is worth paying for
  // again: it may have been reshaped by the last pick from it. Search doesn't
  // invalidate, or every keystroke would restart the same enumeration.
  function invalidateVolatileProvider(id) {
    var entry = root.item(id)
    var spec = entry && entry.provider ? root.providers[entry.provider] : null
    if (spec && spec.volatile) root.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return

    // Native providers don't touch providerProc, so they never need to queue.
    if (entry.provider === "apps") {
      root.startProviderForMenu(id)
      return
    }

    if (providerProc.running) {
      if (root.providerQueue.indexOf(id) < 0) root.providerQueue = root.providerQueue.concat([id])
      return
    }

    root.startProviderForMenu(id)
  }

  function loadProvidersForSearch() {
    var active = root.item(root.activeMenu) ? root.activeMenu : "root"

    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || !entry.provider || root.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !root.isDescendantOf(entry.id, active)) continue

      root.loadProviderForMenu(entry.id)
    }
  }

  function depthFor(id) {
    return MenuModel.depthFor(root.items, id)
  }

  function pathFor(id) {
    return MenuModel.pathFor(root.items, id)
  }

  function parentPathFor(id) {
    return MenuModel.parentPathFor(root.items, id)
  }

  function isDescendantOf(id, ancestorId) {
    return MenuModel.isDescendantOf(root.items, id, ancestorId)
  }

  function childCount(id) {
    return MenuModel.childCount(root.items, root.itemOrder, id)
  }

  // Guarded items are hidden when their `when:` evaluates false. Static
  // submenus are also hidden when none of their descendants are visible;
  // provider-backed menus stay visible because their rows load on demand.
  function isVisible(entry) {
    return MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry)
  }

  // Label with the ✓ marker baked in when `checked:` or `disabled:` evaluated
  // truthy.
  function labelFor(entry) {
    return MenuModel.labelFor(entry, root.checkedResults, root.disabledResults)
  }

  function searchableToken(value) {
    return MenuModel.searchableToken(value)
  }

  function leafIdFor(id) {
    return MenuModel.leafIdFor(id)
  }

  function nameSearchText(entry) {
    return MenuModel.nameSearchText(entry)
  }

  function termInSearchWords(term, text) {
    return MenuModel.termInSearchWords(term, text)
  }

  function descriptionTextMatches(query, text) {
    return MenuModel.descriptionTextMatches(query, text)
  }

  // Rows whose `disabled:` evaluated truthy stay listed but dimmed, and the
  // cursor steps over them.
  function isDisabled(entry) {
    return MenuModel.isDisabled(root.disabledResults, entry)
  }

  // A disabled row earns its place in the submenu it belongs to, where the
  // list around it is the point. Search is a list of what you can do, so it
  // leaves them out.
  // Text first: visibility walks the menu tree for every submenu, and most
  // entries fail the text long before that is worth paying for.
  function matchesQuery(entry, query) {
    if (!MenuModel.matchesQuery(entry, query, true, root.searchTextsFor(entry))) return false
    return root.isVisible(entry) && !root.isDisabled(entry)
  }

  function searchScore(entry, query) {
    return MenuModel.searchScore(root.items, entry, query, root.searchTextsFor(entry))
  }

  function displayRow(entry, detail, score, section, childCounts) {
    return MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, root.disabledResults, entry, detail, score, section, childCounts)
  }

  // Each entry's search text and every menu's child count, built on first use
  // and dropped whenever the rows themselves change. Rebuilding both on every
  // keystroke was most of what typing cost. Only the search path in
  // rebuildDisplay reads it -- never a binding -- so filling it can't loop.
  property var searchCache: null
  onItemsChanged: searchCache = null
  onItemOrderChanged: searchCache = null

  function searchRows() {
    if (!root.searchCache) root.searchCache = { texts: ({}), childCounts: MenuModel.childCounts(root.items, root.itemOrder) }
    return root.searchCache
  }

  function searchTextsFor(entry) {
    var texts = root.searchRows().texts
    var found = texts[entry.id]
    if (!found) {
      found = MenuModel.searchTexts(entry)
      texts[entry.id] = found
    }
    return found
  }

  function rowSelectable(index) {
    if (index < 0 || index >= displayModel.count) return false
    return !displayModel.get(index).disabled
  }

  // First selectable row at or past `from`, continuing in the direction of
  // travel and wrapping. -1 when every row is disabled, which leaves the menu
  // with no cursor at all rather than one parked on a row Enter won't run.
  function nextSelectable(from, direction) {
    var count = displayModel.count
    if (count === 0) return -1

    var step = direction < 0 ? -1 : 1
    var index = ((from % count) + count) % count
    for (var i = 0; i < count; i++) {
      if (root.rowSelectable(index)) return index
      index = (index + step + count) % count
    }

    return -1
  }

  // Park the cursor on a selectable row after the rows underneath it changed.
  // A menu with nothing selectable in it -- every app in it already installed
  // -- shows no cursor at all, and grows one the moment a row can take it.
  function settleCursor() {
    var target = root.nextSelectable(root.selectedIndex, 1)
    root.selectedIndex = target >= 0 ? target : 0
    root.cursorActive = target >= 0
  }

  function rebuildDmenuDisplay() {
    root.shownRows = []
    displayModel.clear()
    root.searchDivider = false

    if (root.mode === "input") {
      layoutSerial += 1
      return
    }

    // Collected and appended once, as in rebuildDisplay: a picker like the
    // keybindings list hands over ~240 options, ~4 ms each appended singly.
    var rows = []
    if (root.dmenuMultiple && root.dmenuOnChange.length === 0) {
      rows.push({
        itemId: "dmenu.apply", disabled: false, kind: "dmenu", icon: "", iconFont: "",
        appIcon: "", appId: "", label: Commons.I18n.t("common.apply"), target: "",
        detail: Commons.I18n.tn("menu.selectedCount", root.dmenuSelected.length).arg(Commons.I18n.formatNumber(root.dmenuSelected.length)), path: "", childCount: 0,
        action: "", provider: "", score: -1, section: ""
      })
    }
    var query = root.filterText.trim().toLowerCase()
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      // An option is "<label>", "<glyph>\t<label>", or
      // "<glyph>\t<label>\t<subtext>". The glyph never comes back with the
      // selection; the subtext renders under the label, filters alongside it,
      // and returns with the selection as a stable key for same-named rows.
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (query && label.toLowerCase().indexOf(query) < 0
          && detail.toLowerCase().indexOf(query) < 0) continue
      rows.push({
        itemId: "dmenu." + i,
        disabled: false,
        kind: "dmenu",
        icon: root.dmenuMultiple ? (root.dmenuSelected.indexOf(MenuModel.dmenuValue(root.dmenuOptions[i])) !== -1 ? "✓" : "○") : icon,
        iconFont: "",
        appIcon: "",
        appId: "",
        label: label,
        target: "",
        detail: detail,
        path: "",
        childCount: 0,
        action: "",
        provider: "",
        score: i,
        section: ""
      })
    }

    root.shownRows = rows
    if (rows.length > 0) displayModel.append(rows)
    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  function updateDmenuChecks() {
    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (row.itemId === "dmenu.apply") {
        displayModel.setProperty(i, "detail", Commons.I18n.tn("menu.selectedCount", root.dmenuSelected.length).arg(Commons.I18n.formatNumber(root.dmenuSelected.length)))
      } else if (row.kind === "dmenu") {
        var value = MenuModel.dmenuValue(root.dmenuOptions[Number(row.itemId.substring(6))])
        displayModel.setProperty(i, "icon", root.dmenuSelected.indexOf(value) !== -1 ? "✓" : "○")
      }
    }
  }

  function rebuildDisplay() {
    if (root.dmenuActive) {
      root.rebuildDmenuDisplay()
      return
    }

    root.shownRows = []
    displayModel.clear()

    if (!root.rowsLoaded) return

    var active = root.item(root.activeMenu) ? root.activeMenu : "root"
    root.activeMenu = active
    var rows = []
    var query = root.filterText.trim()
    root.searchDivider = false

    if (query) {
      var currentRows = []
      var drilldownRows = []

      for (var i = 0; i < root.itemOrder.length; i++) {
        var entry = root.item(root.itemOrder[i])
        if (!entry || entry.id === "root") continue
        if (!root.isDescendantOf(entry.id, active)) continue
        if (!root.matchesQuery(entry, query)) continue

        var detail = root.parentPathFor(entry.id)
        var row = root.displayRow(entry, detail, root.searchScore(entry, query), "", root.searchRows().childCounts)
        if (entry.parent === active) currentRows.push(row)
        else drilldownRows.push(row)
      }

      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }

      currentRows.sort(searchSort)
      drilldownRows.sort(searchSort)
      rows = currentRows.concat(drilldownRows)
      // One letter matches most of the menu; laying out 200+ rows was most of
      // what the first keystroke cost. Show the best few until the second.
      if (query.length < 2 && rows.length > root.firstLetterLimit) rows = rows.slice(0, root.firstLetterLimit)
      var shownCurrent = Math.min(currentRows.length, rows.length)
      root.searchDivider = shownCurrent > 0 && rows.length > shownCurrent
      if (root.searchDivider) {
        for (var d = shownCurrent; d < rows.length; d++) rows[d].section = "drilldown"
      }
    } else {
      for (var j = 0; j < root.itemOrder.length; j++) {
        var child = root.item(root.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!root.isVisible(child)) continue
        rows.push(root.displayRow(child, child.description, child.order))
      }

      // DesktopEntries can reorder its values when an application starts.
      // Keep the Apps menu alphabetical independently of provider refreshes.
      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          var aId = String(a.itemId || "")
          var bId = String(b.itemId || "")
          if (aId < bId) return -1
          if (aId > bId) return 1
          return 0
        })
      }
    }

    // One append for the whole list: per-row appends re-ran every binding on
    // the row count for each row, ~4 ms a row, past a second for one letter.
    // Set before the append, whose count change re-runs rowListHeight.
    root.shownRows = rows
    if (rows.length > 0) displayModel.append(rows)
    layoutSerial += 1

    root.settleCursor()

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  // Contain alone parks the cursor row flush with the viewport edge, hiding
  // the neighbor entirely and losing the fold affordance. Keep the next
  // hidden row peeking past the cursor in the direction of travel.
  function revealCursor() {
    if (displayModel.count === 0) return
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)

    var item = resultList.itemAtIndex(root.selectedIndex)
    if (!item) return

    var reach = root.rowPeek + root.rowSpacing
    if (root.selectedIndex < displayModel.count - 1) {
      var maxY = Math.max(resultList.originY, resultList.originY + resultList.contentHeight - resultList.height)
      var overhang = item.y + item.height + reach - (resultList.contentY + resultList.height)
      if (overhang > 0) resultList.contentY = Math.min(resultList.contentY + overhang, maxY)
    }
    if (root.selectedIndex > 0) {
      var underhang = resultList.contentY - (item.y - reach)
      if (underhang > 0) resultList.contentY = Math.max(resultList.contentY - underhang, resultList.originY)
    }
  }

  function select(delta) {
    if (displayModel.count === 0) return

    root.disarmPointer()
    var from = cursorActive ? selectedIndex + delta : (delta < 0 ? displayModel.count - 1 : 0)
    var target = root.nextSelectable(from, delta)
    if (target < 0) return

    cursorActive = true
    selectedIndex = target
    revealCursor()
  }

  function setFilter(nextFilter) {
    if (openRefresh.running) openRefresh.restart()
    panel.freezeCardTop()
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = root.mode !== "input"
    root.disarmPointer()
    if (!root.dmenuActive && root.filterText.trim()) root.loadProvidersForSearch()
    root.rebuildDisplay()
  }

  function setActiveMenu(id, pushHistory, fromPointer) {
    panel.freezeCardTop()
    if (!root.item(id)) id = "root"
    if (pushHistory && id !== root.activeMenu) root.navStack = root.navStack.concat([root.activeMenu])
    root.activeMenu = id
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    if (fromPointer) pointerGate.allowInitialSample()
    else root.disarmPointer()
    root.rebuildDisplay()
    root.invalidateVolatileProvider(id)
    root.loadProviderForMenu(id)
  }

  function goBack() {
    if (root.activeMenu === "root") return false

    if (root.navStack.length > 0) {
      var previous = root.navStack[root.navStack.length - 1]
      root.navStack = root.navStack.slice(0, root.navStack.length - 1)
      root.setActiveMenu(previous, false)
      return true
    }

    var active = root.item(root.activeMenu)
    root.setActiveMenu((active && active.parent) ? active.parent : "root", false)
    return true
  }

  function activateIndex(index, fromPointer) {
    if (root.deleteConfirmOpen) return
    if (root.dmenuActive) {
      if (root.mode === "input") {
        root.applyDmenuSelection(root.filterText)
        return
      }
      if (index < 0 || index >= displayModel.count) return
      var picked = displayModel.get(index)
      if (root.dmenuMultiple) {
        if (picked.itemId === "dmenu.apply") {
          root.applyDmenuSelection(JSON.stringify(MenuModel.dmenuSelections(root.dmenuOptions, root.dmenuSelected)))
        } else {
          var value = MenuModel.dmenuValue(root.dmenuOptions[Number(picked.itemId.substring(6))])
          var selected = MenuModel.toggleDmenuSelection(selectionProc.requestedSelection(), value)
          if (root.dmenuOnChange.length > 0) {
            selectionProc.enqueue(selected)
          } else {
            root.dmenuSelected = selected
            root.updateDmenuChecks()
          }
        }
      } else {
        root.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      }
      return
    }

    if (!root.rowSelectable(index)) return

    var row = displayModel.get(index)
    if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, fromPointer)
    } else if (row.kind === "app") {
      var appId = row.appId
      var label = row.label
      applySerial = requestSerial
      opened = false
      if (root.appLibrary) root.appLibrary.launch(appId, label)
    } else {
      root.applySelected(row.itemId, row.action)
    }
  }

  function requestDeleteSelected() {
    if (!root.cursorActive || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return
    var row = displayModel.get(root.selectedIndex)
    if (!row || row.kind !== "app") return
    root.deleteTarget = { appId: row.appId, label: row.label }
    deleteConfirm.selectedIndex = 1
    root.deleteConfirmOpen = true
  }

  function cancelDelete() {
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    deleteConfirm.selectedIndex = 1
    root.disarmPointer()
    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  function confirmDelete() {
    var target = root.deleteTarget
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    if (!target) return
    root.cancel()
    if (root.appLibrary) root.appLibrary.remove(target.appId, target.label)
  }

  function applyDmenuSelection(value) {
    applySerial = requestSerial
    opened = false
    root.finishRequest(value)
  }

  function applySelected(id, action) {
    if (!id) { cancel(); return }

    applySerial = requestSerial
    opened = false
    root.runAction(action)
  }

  // Closing leaves the filter as it was, so the menu fades out showing what
  // it showed; openExistingMenu and openDmenu clear it for the next open.
  function cancel() {
    if (root.dmenuActive) root.finishRequest(null)
    opened = false
  }

  // A picker request this open replaces would otherwise never be answered,
  // and its omarchy-menu-select caller polls for a done file forever.
  // Answer it as cancelled. Detached, since resultProc may be mid-answer.
  function releaseRequest() {
    if (!root.requestActive || !root.doneFile) return
    Quickshell.execDetached(["touch", root.doneFile])
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""
  }

  function openExistingMenu(initialMenu) {
    root.releaseRequest()
    requestSerial += 1
    mode = "menu"
    requestActive = false
    selectionFile = ""
    doneFile = ""
    activeMenu = root.item(initialMenu) ? initialMenu : "root"
    navStack = []
    // A dropdown opened straight at a submenu shows the way to it, outermost
    // menu first, so the cascade always starts under the bar's mark.
    if (root.dropdown && activeMenu !== "root") {
      var chain = []
      var at = root.item(activeMenu)
      while (at && at.parent && root.item(at.parent)) {
        chain.unshift(at.parent)
        at = root.item(at.parent)
      }
      navStack = chain
    }
    filterText = ""
    selectedIndex = 0
    cursorActive = true
    root.disarmPointer()
    opened = true
    rebuildDisplay()
    invalidateVolatileProvider(activeMenu)
    loadProviderForMenu(activeMenu)
    // Values, guards and icons refresh once the menu is on screen; it opens
    // with the last answers, which is all it ever had before they landed.
    openRefresh.restart()

    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  // Building the guard script and starting its bash took 30-40 ms, and the
  // values and icon scans fork too. Run them once typing pauses: while they
  // ran, the first keystrokes after opening stalled for 100-400 ms.
  Timer {
    id: openRefresh
    interval: 600
    onTriggered: {
      if (!root.opened) return
      root.refreshValues()
      root.evaluateGuards()
      // The shell may start before first-install packages have finished placing
      // their icons. Refresh here even when the desktop entry list did not change.
      if (root.appLibrary) root.appLibrary.refreshIcons()
    }
  }

  function openDmenu(payload) {
    root.releaseRequest()
    requestSerial += 1
    mode = payload.mode === "input" ? "input" : "select"
    dmenuPrompt = String(payload.prompt || (mode === "input" ? Commons.I18n.t("menu.inputPrompt") : Commons.I18n.t("menu.selectPrompt")))
    dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    dmenuMultiple = mode === "select" && payload.multiple === true
    dmenuOnChange = dmenuMultiple && Array.isArray(payload.onChange)
      && payload.onChange.every(function(arg) { return typeof arg === "string" }) ? payload.onChange : []
    dmenuChangeKey = String(payload.changeKey || JSON.stringify(dmenuOnChange))
    dmenuSelected = MenuModel.dmenuSelections(dmenuOptions, Array.isArray(payload.selected) ? payload.selected : [], dmenuOnChange.length > 0)
    dmenuSaved = dmenuSelected
    if (dmenuOnChange.length > 0)
      dmenuSelected = MenuModel.dmenuSelections(dmenuOptions, selectionProc.requestedSelection(), true)
    selectionFile = String(payload.selectionFile || "")
    doneFile = String(payload.doneFile || "")
    requestActive = !!doneFile
    dmenuWidth = Math.max(1, Number(payload.width || 300))
    dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    activeMenu = "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = mode !== "input"
    root.disarmPointer()
    opened = true
    rebuildDisplay()

    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }
  ListModel { id: displayModel }
  readonly property int firstLetterLimit: 40
  // The same rows as plain objects, for code that walks all of them.
  property var shownRows: []

  // ----------------------------------------------------------- route surface
  //
  // The menu is opened through the standard plugin lifecycle:
  // `omarchy-shell shell summon omarchy.menu '{"menu":"system"}'`.
  // Callers may pass a real id (`system`, `setup.power`) or an alias declared
  // in JSONC (`power`, `reminder-set`). Unknown strings fall through to the
  // id-as-route behavior so misspellings still attempt to open the literal id.
  function resolveRoute(input) {
    return MenuModel.resolveRoute(root.items, root.itemOrder, input)
  }

  function openRoute(initialMenu) {
    var id = root.resolveRoute(initialMenu)
    var entry = root.items[id]
    // If the resolved id is an action (i.e. the user invoked an alias for
    // a leaf, e.g. `omarchy menu summon screenrecord-stop`), run it directly
    // instead of opening an action with no children.
    if (entry && entry.kind === "action" && entry.action) {
      root.cancel()
      root.runAction(entry.action)
      return "ok"
    }
    // If it's a link (a redirect to another menu), follow the link.
    if (entry && entry.kind === "link" && entry.target) id = entry.target
    root.pendingInitialMenu = id
    root.openExistingMenu(id)
    return "ok"
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    if (!root.rowSelectable(index)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    property string collected: ""
    property int revision: 0
    stdout: SplitParser {
      onRead: function(data) { providerProc.collected += data + "\n" }
    }
    onExited: {
      if (providerProc.revision === root.providerRevision) {
        root.mergeProviderRows(providerProc.collected, providerProc.menuId, providerProc.providerKey)
        if (root.filterText.trim()) root.loadProvidersForSearch()
      }
      root.startNextProvider()
    }
  }

  Process {
    id: selectionProc
    property int serial: 0
    property string changeKey: ""
    property var selected: []
    property var queue: []
    property string collected: ""

    function requestedSelection() {
      for (var i = queue.length - 1; i >= 0; i--) {
        if (queue[i].key === root.dmenuChangeKey) return queue[i].selected
      }
      if (running && changeKey === root.dmenuChangeKey) return selected
      return root.dmenuSelected
    }

    function enqueue(values) {
      var selected = MenuModel.dmenuSelections(root.dmenuOptions, values, true)
      queue = queue.concat([{
        serial: root.requestSerial, key: root.dmenuChangeKey, selected: selected,
        command: root.dmenuOnChange.concat([JSON.stringify(selected)])
      }])
      if (!running) startNext()
    }

    function startNext() {
      if (queue.length === 0) return
      var change = queue[0]
      queue = queue.slice(1)
      serial = change.serial
      changeKey = change.key
      selected = change.selected
      collected = ""
      command = change.command
      running = true
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: selectionProc.collected = text
    }
    onExited: function(exitCode) {
      if (changeKey === root.dmenuChangeKey && root.dmenuActive && root.dmenuOnChange.length > 0) {
        if (exitCode === 0) {
          var applied = selected
          if (collected.trim()) {
            try { applied = JSON.parse(collected) } catch (error) { applied = root.dmenuSelected }
          }
          if (Array.isArray(applied))
            root.dmenuSelected = MenuModel.dmenuSelections(root.dmenuOptions, applied, true)
          root.dmenuSaved = root.dmenuSelected
        } else {
          root.dmenuSelected = root.dmenuSaved
        }
        root.updateDmenuChecks()
      }
      startNext()
    }
  }

  Process {
    id: resultProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }

  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/omarchy/extensions/omarchy-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
    path: root.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.defaultMenuItems = root.parseMenuJsonc(text()); root.defaultMenuSettled = true; root.rebuildItemsFromSources() }
    // A user file that loaded first held its evaluation for this one.
    onLoadFailed: { root.defaultMenuSettled = true; if (root.userMenuSettled) root.evaluateGuards() }
    onFileChanged: reload()
  }

  FileView {
    id: suiteMenuFile
    path: root.manifest && root.manifest.__sourceDir ? root.manifest.__sourceDir + "/sumi-menu.jsonc" : ""
    watchChanges: true
    printErrors: false
    onLoaded: { root.suiteMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onLoadFailed: { root.suiteMenuItems = []; root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  FileView {
    id: userMenuFile
    path: root.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.userMenuItems = root.parseMenuJsonc(text()); root.userMenuSettled = true; root.rebuildItemsFromSources() }
    onLoadFailed: { root.userMenuItems = []; root.userMenuSettled = true; root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  // The language choice and its catalog are watched the same way, so
  // picking a language under Setup retitles the menu with no shell restart.
  FileView {
    id: languageFile
    path: root.languagePath
    watchChanges: true
    printErrors: false
    onLoaded: root.setLanguage(text())
    onLoadFailed: root.setLanguage("")
    onFileChanged: reload()
  }

  FileView {
    id: menuCatalogFile
    path: root.omarchyPath + "/default/i18n/" + root.language + "/menu.json"
    watchChanges: true
    printErrors: false
    onLoaded: { root.menuCatalog = root.parseCatalog(text()); root.rebuildItemsFromSources(true) }
    onLoadFailed: { root.menuCatalog = ({}); root.rebuildItemsFromSources(true) }
    onFileChanged: reload()
  }

  // ---------------------------------------------------------------- guards
  //
  // `when:` (visibility) and `checked:` (✓ marker) are bash expressions the
  // shell wasn't allowed to evaluate before the perf rewrite. Now the shell
  // batches them into one bash subprocess per (re)load so the open path
  // never has to wait on them.

  property var whenResults: ({})       // id → true|false (allow visibility)
  property var checkedResults: ({})    // id → true|false (show ✓)
  property var disabledResults: ({})   // id → true|false (dim, skip cursor)
  property bool guardsPending: false

  function evaluateGuards() {
    // Process ignores a command change while it is running, and `collected`
    // belongs to the run in flight, so a second evaluation cannot overwrite
    // the first: it would throw away the lines already read and never start.
    // The surviving tail then lands as the whole answer, and every id lost
    // with it goes back to showing, since a `when:` only hides on an explicit
    // false. Wait for the run in flight and evaluate once it lands instead.
    if (guardProc.running) {
      root.guardsPending = true
      return
    }
    root.guardsPending = false

    var script = MenuModel.guardScript(root.items)
    if (!script) {
      root.whenResults = ({})
      root.checkedResults = ({})
      root.disabledResults = ({})
      return
    }
    guardProc.collected = ""
    guardProc.command = ["nice", "-n", "19", "bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { guardProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      // A batch that was killed rather than finished has only told us about
      // the rows it reached, and a row whose `when:` went unanswered shows.
      // Keep the last complete set rather than let a half-read one through.
      // A signal leaves the exit code at 0, so the status is what tells us.
      if (exitCode !== 0 || exitStatus !== 0) {
        if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
        return
      }

      var nextWhen = ({})
      var nextChecked = ({})
      var nextDisabled = ({})
      var lines = guardProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var colon = line.lastIndexOf(":")
        if (colon < 0) continue
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) continue
        var id = rest.substring(0, tagAt)
        var tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
        else if (tag === "d") nextDisabled[id] = value
      }
      // Usually nothing changed since the last run. Swapping in equal answers
      // still rebuilt the menu, which stalled typing when it landed mid-word.
      var changed = false
      if (JSON.stringify(nextWhen) !== JSON.stringify(root.whenResults)) { root.whenResults = nextWhen; changed = true }
      if (JSON.stringify(nextChecked) !== JSON.stringify(root.checkedResults)) { root.checkedResults = nextChecked; changed = true }
      if (JSON.stringify(nextDisabled) !== JSON.stringify(root.disabledResults)) { root.disabledResults = nextDisabled; changed = true }
      if (changed && root.opened) root.rebuildDisplay()
      // Run the evaluation that had to stand aside. Deferred by a turn so the
      // process is settled before its command is set again.
      if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
    }
  }
  Sumi.ParkedOverlayWindow {
    id: panel
    // The dropdown settles in from the bar's mark; a picker dialog from its middle.
    revealOrigin: root.dropdown ? Item.Top : Item.Center
    shown: root.opened && root.rowsLoaded
    WlrLayershell.namespace: "omarchy-menu"

    // The card opens centered exactly as always. The first search keystroke
    // or submenu move freezes the top line where it currently sits — from
    // then on the card grows and shrinks downward instead of re-centering
    // on every resize, which made the menu jump around. The rows height is
    // frozen at the same moment, so the starting menu also caps how tall the
    // card may grow from there. Closing or changing screens unfreezes both.
    property int cardTop: -1
    property int maxRowsHeight: -1
    readonly property int centeredTop: Math.max(Style.gapsOut, Math.round((height - root.cardHeight) / 2))
    readonly property int effectiveCardTop: cardTop >= 0 ? cardTop : centeredTop
    function freezeCardTop() {
      if (shown && cardTop < 0) {
        cardTop = effectiveCardTop
        maxRowsHeight = root.visibleRowsHeight
      }
    }
    // Released at the next open rather than at close, so a dialog fading out
    // doesn't jump back to centre.
    onShownChanged: if (shown) { cardTop = -1; maxRowsHeight = -1 }
    onTargetScreenChanged: { cardTop = -1; maxRowsHeight = -1 }

    // A dropdown leaves the desktop as it is; a dialog dims it.
    Rectangle {
      anchors.fill: parent
      color: root.dropdown ? "transparent" : root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    // Drill-in: the menus navigated through are not drawn; the back row in
    // the card leads back to them. (Was: they stayed open to the left.)
    Repeater {
      model: 0

      BorderSurface {
        id: ancestor
        required property int index
        readonly property string menuId: root.cascadePath[index] || "root"
        readonly property string nextId: root.cascadePath[index + 1] || ""
        readonly property var geo: root.cascadeGeometry[index] || ({ x: 0, y: 0, width: 0 })
        readonly property var rows: root.rowsFor(menuId, root.providerRevision, root.checkedResults)
        x: geo.x
        y: geo.y
        width: geo.width
        height: ancestorColumn.implicitHeight + root.contentMargin * 2
        radius: root.cornerRadius
        color: root.background
        borderSpec: root.borderSpec
        padding: root.contentMargin

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: ancestorColumn
          x: root.contentMargin
          y: root.contentMargin
          width: parent.width - root.contentMargin * 2

          Repeater {
            model: ancestor.rows

            Item {
              id: arow
              required property var modelData
              required property int index
              readonly property bool sep: root.sepAboveIn(ancestor.rows, index)
              readonly property bool held: modelData.target === ancestor.nextId || modelData.itemId === ancestor.nextId
              readonly property bool checked: String(modelData.label).slice(-2) === " ✓"
              readonly property string glyph: modelData.kind === "app" ? Icons.appGlyph(modelData.appId) : Icons.menuGlyph(modelData.itemId)
              readonly property string value: arow.checked ? "" : root.valueFor(modelData.itemId, modelData.label)
              width: ancestorColumn.width
              height: root.baseRowHeight + (sep ? root.sepHeight : 0)

              Rectangle {
                visible: arow.sep
                x: Style.space(10)
                width: parent.width - Style.space(20)
                y: Math.round(root.sepHeight / 2)
                height: 1
                color: Util.alpha(root.foreground, 0.09)
              }

              Rectangle {
                y: arow.sep ? root.sepHeight : 0
                width: parent.width
                height: root.baseRowHeight
                radius: root.rowRadius
                color: arow.held || ahover.hovered ? root.selectedBackground : "transparent"

                Sumi.SumiIcon {
                  id: aicon
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  visible: arow.glyph !== ""
                  name: arow.glyph
                  size: 16
                  color: arow.held ? root.selectedText : root.ink2
                }
                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  visible: arow.glyph === "" && arow.modelData.icon !== ""
                  width: 16
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.PlainText
                  text: arow.modelData.icon
                  color: root.ink2
                  font.family: arow.modelData.iconFont || root.monoFamily
                  font.pixelSize: Style.font.icon
                }
                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(37)
                  anchors.right: atrail.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: arow.checked ? String(arow.modelData.label).slice(0, -2) : arow.modelData.label
                  elide: Text.ElideRight
                  color: arow.held ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: 13
                }
                Row {
                  id: atrail
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: arow.value
                    width: Math.min(implicitWidth, Style.space(118))
                    elide: Text.ElideRight
                    color: root.ink3
                    font.family: root.fontFamily
                    font.pixelSize: 12
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: arow.value === "" ? (root.keyHints[arow.modelData.itemId] || "") : ""
                    color: root.ink3
                    font.family: root.monoFamily
                    font.pixelSize: 11
                  }
                  Sumi.SumiIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: arow.checked
                    name: "check"
                    size: 14
                    color: root.ink2
                  }
                  Sumi.SumiIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: arow.modelData.kind === "menu" || arow.modelData.kind === "link"
                    name: "chevron"
                    size: 13
                    color: arow.held ? root.selectedText : root.foreground
                    opacity: 0.45
                  }
                }

                HoverHandler { id: ahover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (!arow.modelData.disabled) root.activateInCascade(ancestor.index, arow.modelData) }
              }
            }
          }
        }
      }
    }

    BorderSurface {
      id: card
      readonly property var geo: root.cascadeGeometry[root.cascadeGeometry.length - 1] || ({ x: 0, y: 0, width: root.cardWidth })
      width: root.dropdown ? geo.width : root.cardWidth
      height: root.dropdown
        ? Math.min(root.cardHeight, panel.height - Style.space(12) - y)
        : Math.min(root.cardHeight, panel.height - Style.gapsOut - panel.effectiveCardTop)
      radius: root.cornerRadius
      x: root.dropdown ? geo.x : Math.round((parent.width - width) / 2)
      // A submenu that would run off the bottom rises to fit.
      y: root.dropdown ? Math.max(Style.space(8), Math.min(geo.y, panel.height - Style.space(12) - root.cardHeight)) : panel.effectiveCardTop
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.deleteConfirmOpen ? 20 : 0

        // Focus is on filterInput, which forwards every key here first.
        Keys.onPressed: function(event) {
          if (root.deleteConfirmOpen) {
            // Swallow the rest too, or it would type into the search line behind the dialog.
            deleteConfirm.handleKey(event)
            event.accepted = true
            return
          }

          if (event.key === Qt.Key_Delete) {
            root.requestDeleteSelected()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.cancel()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if ((event.key === Qt.Key_Backspace || Util.readingKey(event) === Qt.Key_Left) && !root.filterText) {
            root.goBack()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || Util.readingKey(event) === Qt.Key_Right) {
            if (root.dmenuActive) {
              if (root.mode === "input") root.applyDmenuSelection(root.filterText)
              else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
            } else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else root.settleCursor()
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: deleteConfirm

          anchors.fill: parent
          opened: root.deleteConfirmOpen
          z: 10
          message: Commons.I18n.t("common.uninstallConfirm").arg((root.deleteTarget && root.deleteTarget.label) || "")
          confirmText: Commons.I18n.t("common.uninstall")
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelDelete()
          onConfirmed: root.confirmDelete()
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"
          clip: true

          Sumi.SumiIcon {
            id: searchGlyph
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 17
            color: root.ink2
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -Math.round(root.contentSpacing / 2)
            height: 1
            color: Util.alpha(root.foreground, 0.09)
          }

          FilterInput {
            id: filterInput
            anchors.left: searchGlyph.right
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: keyCatcher
            // Input-method commits bypass key handling, so the dialog has to refuse them here.
            readOnly: root.deleteConfirmOpen
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 16
            onTextChanged: if (text !== root.filterText) root.setFilter(text)
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: filterInput
            verticalAlignment: Text.AlignVCenter
            visible: !root.filterText && !filterInput.preeditText
            text: root.dmenuActive ? (root.dmenuPrompt + "…") : ((root.item(root.activeMenu) ? (root.item(root.activeMenu).title || root.item(root.activeMenu).label) : "Go") + "…")
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: 16
            elide: Text.ElideRight
          }

        }

        // Drill-in back row: "‹ Development". Click (or Left / Backspace) goes up a level.
        Rectangle {
          id: backRow
          width: parent.width
          height: root.backRowHeight
          visible: root.backRowHeight > 0
          radius: root.cornerRadius
          color: backHover.hovered ? root.selectedBackground : "transparent"

          Sumi.SumiIcon {
            id: backGlyph
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron"
            rotation: 180
            size: 13
            color: backHover.hovered ? root.selectedText : root.foreground
            opacity: 0.6
          }

          Text {
            anchors.left: backGlyph.right
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            // The row's own name; a submenu's title is often its section's (all of Remove's say "Remove").
            text: { var it = root.item(root.activeMenu); return it ? (it.label || it.title) : "" }
            color: backHover.hovered ? root.selectedText : root.foreground
            font.family: root.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Util.alpha(root.foreground, 0.09)
          }

          HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.goBack() }
        }

        Item {
          width: parent.width
          height: root.visibleRowsHeight

          ListView {
            id: resultList
            anchors.fill: parent
            model: displayModel
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              target: null
              onWheel: function(event) {
                var delta = event.pixelDelta.y || event.angleDelta.y / 120 * root.rowHeightForDetail("") * 3
                var bottom = resultList.originY + Math.max(0, resultList.contentHeight - resultList.height)
                resultList.contentY = Math.max(resultList.originY, Math.min(bottom, resultList.contentY - delta))
                event.accepted = true
              }
            }

            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
              required property string section

              width: ListView.view.width
              height: section === "drilldown" ? root.dividerHeight : 0
              visible: section === "drilldown"

              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(4)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Util.alpha(root.foreground, 0.09)
              }
            }

            delegate: BorderSurface {
              id: row
              required property int index
              required property string itemId
              required property string kind
              required property string icon
              required property string iconFont
              required property string appIcon
              required property string appId
              required property string label
              required property string target
              required property string detail
              required property string path
              required property string action
              required property int childCount
              required property bool disabled

              readonly property bool hasCursor: root.cursorActive && row.index === root.selectedIndex
              readonly property bool isApp: row.kind === "app"
              // The Sumi glyph for this row; apps and entries the set has no
              // glyph for keep their own icon.
              readonly property string sumiGlyph: row.isApp ? Icons.appGlyph(row.appId) : Icons.menuGlyph(row.itemId)
              readonly property bool hasIcon: row.icon.length > 0 || row.isApp || row.sumiGlyph !== ""
              // Sumi: a hairline above a new group, the ✓ moved out of the
              // label into the trailing column, and a value or key hint.
              readonly property bool sep: root.sepAbove(row.index)
              readonly property int sepOffset: row.sep ? root.sepHeight : 0
              readonly property bool checkedRow: row.label.slice(-2) === " ✓"
              readonly property string cleanLabel: row.checkedRow ? row.label.slice(0, -2) : row.label
              readonly property string valueText: row.checkedRow ? "" : root.valueFor(row.itemId, row.label)
              // A value or a key hint, never both, as in the design.
              readonly property string keyText: root.dropdown && !root.filterText && row.valueText === "" ? (root.keyHints[row.itemId] || "") : ""

              width: ListView.view.width
              height: root.rowHeightForDetail(row.detail) + row.sepOffset
              // Faded: the row is here to say the software is already
              // installed, not to be picked.
              opacity: row.disabled ? 0.4 : 1
              radius: root.rowRadius
              color: "transparent"
              borderSpec: Border.none()

              Rectangle {
                visible: row.sep
                x: Style.space(10)
                width: parent.width - Style.space(20)
                y: Math.round(root.sepHeight / 2)
                height: 1
                color: Util.alpha(root.foreground, 0.09)
              }

              Rectangle {
                y: row.sepOffset
                width: parent.width
                height: parent.height - row.sepOffset
                radius: root.rowRadius
                color: row.hasCursor ? root.selectedBackground : "transparent"
              }

              Rectangle {
                visible: false
                width: Style.space(4)
                height: parent.height - Style.space(18)
                radius: Math.min(root.cornerRadius, Style.space(4))
                color: root.selectedBackground
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: iconText
                textFormat: Text.PlainText
                visible: row.hasIcon && !row.isApp && row.sumiGlyph === ""
                text: row.icon
                color: row.hasCursor ? root.selectedText : root.ink2
                font.family: row.iconFont.length > 0 ? row.iconFont : root.fontFamily
                font.pixelSize: Style.font.icon
                width: Style.space(30)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
              }

              Sumi.SumiIcon {
                visible: row.sumiGlyph !== ""
                anchors.centerIn: iconText
                name: row.sumiGlyph
                size: 16
                color: row.hasCursor ? root.selectedText : root.ink2
              }

              Image {
                id: appIconImage
                visible: row.isApp && row.sumiGlyph === ""
                width: Style.font.iconLarge
                height: Style.font.iconLarge
                fillMode: Image.PreserveAspectFit
                // Decode at physical pixels — a logical-size decode leaves
                // PNG icons upscaled and blurry on HiDPI displays.
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: row.isApp && root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : ""
                asynchronous: true
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8) + (Style.space(30) - width) / 2
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
              }

              Column {
                id: contentColumn
                anchors.left: row.hasIcon ? iconText.right : parent.left
                anchors.leftMargin: row.hasIcon ? Style.space(4) : root.rowReservedBorderLeft + Style.space(14)
                anchors.right: trail.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: row.sepOffset / 2
                spacing: Style.space(3)

                Text {
                  id: labelText
                  textFormat: Text.PlainText
                  width: parent.width
                  text: row.cleanLabel
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.dropdown ? 13 : 14
                  font.weight: Font.Normal
                  elide: Text.ElideRight
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  // A parent path's separator points along the reading direction.
                  text: Commons.I18n.rightToLeft && row.kind !== "dmenu" ? row.detail.replace(/ › /g, " ‹ ") : row.detail
                  visible: (root.filterText || row.kind === "dmenu") && row.detail.length > 0
                  color: root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              Row {
                id: trail
                width: implicitWidth
                anchors.right: parent.right
                anchors.rightMargin: root.rowReservedBorderRight + Style.space(8)
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  visible: text !== ""
                  text: row.valueText
                  width: Math.min(implicitWidth, Style.space(118))
                  elide: Text.ElideRight
                  color: root.ink3
                  font.family: root.fontFamily
                  font.pixelSize: 12
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  visible: text !== ""
                  text: row.keyText
                  color: root.ink3
                  font.family: root.monoFamily
                  font.pixelSize: 11
                  anchors.verticalCenter: parent.verticalCenter
                }

                Sumi.SumiIcon {
                  visible: row.checkedRow
                  name: "check"
                  size: 14
                  color: row.hasCursor ? root.selectedText : root.ink2
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  visible: false
                  text: row.childCount
                  color: root.foreground
                  opacity: 0.45
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Sumi.SumiIcon {
                  visible: row.kind === "menu" || row.kind === "link"
                  name: Commons.I18n.rightToLeft ? "back" : "chevron"
                  size: 13
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: row.kind === "menu" || row.kind === "link" ? 0.45 : 0
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                onEntered: root.selectFromPointer(row.index, row, {
                  x: mouseArea.mouseX,
                  y: mouseArea.mouseY
                })
                onPositionChanged: function(mouse) {
                  root.selectFromPointer(row.index, row, mouse)
                }
                onClicked: {
                  if (row.disabled) return
                  root.cursorActive = true
                  root.selectedIndex = row.index
                  root.activateIndex(row.index, true)
                }
              }
            }
          }

          // Scroll scrims. The clipped row already marks the fold at rest;
          // these keep both edges honest once the list has been scrolled,
          // when content hides above the card top as well as below. Strength
          // tracks the distance still hidden past each edge rather than
          // animating on a clock, so a programmatic jump — wrapping from the
          // last row back to the first — lands with the fade already applied.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.contentY - resultList.originY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: root.background }
              GradientStop { position: 1; color: Util.alpha(root.background, 0) }
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.originY + resultList.contentHeight - resultList.height - resultList.contentY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: Util.alpha(root.background, 0) }
              GradientStop { position: 1; color: root.background }
            }
          }

          // Nothing to show: one quiet line in the space of a row.
          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            visible: displayModel.count === 0 && root.mode !== "input"
            textFormat: Text.PlainText
            text: root.filterText ? Commons.I18n.t("common.noMatchesFor").arg(root.filterText) : Commons.I18n.t("menu.nothingHere")
            elide: Text.ElideRight
            color: root.ink2
            font.family: root.fontFamily
            font.pixelSize: 13
          }
        }

        Item {
          width: parent.width
          height: 0
        }
      }
    }
  }
}
