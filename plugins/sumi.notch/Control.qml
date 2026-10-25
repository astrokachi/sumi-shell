import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "NotchLayout.js" as NotchLayout

// The notch's control panel, opened by right-clicking the notch: quick
// toggles and actions, where each widget sits on the bar, how the bar looks,
// and which plugins run. Search reaches all three; every change can be undone for a moment.
//
// A layer of its own rather than a popup: a popup that grabs input is only
// allowed straight after a click on the bar, so one opened by a keybinding
// or command would be closed the moment it appeared.
PanelWindow {
  id: ctl

  required property var host
  required property var bar
  required property Item anchorItem
  required property string screenName

  readonly property color ink: Commons.Color.popups.text
  readonly property color paper: Commons.Color.popups.background
  readonly property color knob: paper
  readonly property string family: host.uiFamily
  readonly property color wash: Qt.rgba(ink.r, ink.g, ink.b, 0.06)
  readonly property color hairline: Qt.rgba(ink.r, ink.g, ink.b, 0.08)

  readonly property var tabs: [{ id: "quick", label: "Controls" }, { id: "layout", label: "Layout" },
    { id: "bar", label: "Bar" }, { id: "plugins", label: "Plugins" }]
  property string tab: "quick"
  property string query: ""
  readonly property string needle: query.trim().toLowerCase()

  // ---- opening and closing --------------------------------------------------

  readonly property bool wanted: host.customizeScreen === screenName
  onWantedChanged: {
    if (!wanted) return
    tab = host.controlTab
    query = ""
    confirmId = ""
    selectedId = ""
    refreshPlugins()
  }

  readonly property int cardWidth: Style.space(400)
  // The card fits the page it shows, and scrolls only once the page is
  // taller than the screen leaves room for.
  readonly property int maxCardHeight: height - host.barSize - Style.space(40)
  readonly property int cardHeight: {
    var page = pageLoader.item
    if (!page) return maxCardHeight
    var natural = head.height + Math.ceil(page.contentHeight) + toast.height + Style.space(4)
    return Math.max(Style.space(140), Math.min(maxCardHeight, natural))
  }

  screen: bar.screen
  visible: wanted
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "sumi-control"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // A click anywhere outside the card closes it.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: ctl.host.closeCustomize()
  }

  // ---- widgets ----------------------------------------------------------------

  readonly property var layout: host.layoutConfig
  readonly property var notch: host.notchConfig
  readonly property var registryIds: {
    var registry = host.barWidgetRegistry
    if (!registry || !registry.widgets) return []
    void(registry.revision)
    return Object.keys(registry.widgets)
  }
  // Shibumi widgets only draw through Shibumi's own runtime service, so
  // without it they would sit on the bar blank: offer them only while it runs.
  readonly property bool shibumiRunning: !!(host.shell && host.shell.serviceFor
    && host.shell.serviceFor("hancore.shibumi.state"))
  readonly property var offIds: NotchLayout.offIds(layout, notch, registryIds).filter(function(id) {
    return shibumiRunning || String(id).indexOf("hancore.shibumi.") !== 0
  })
  property string selectedId: ""

  function nameFor(id) {
    var registry = host.barWidgetRegistry
    var entry = registry && registry.widgets ? registry.widgets[id] : null
    return NotchLayout.displayName(entry ? entry.metadata : null, id)
  }

  function widgetOn(id) {
    return NotchLayout.locate(layout, id) !== null
  }

  function toggleWidget(id) {
    var before = { layout: layout, notch: notch }
    var wasOn = widgetOn(id)
    var next = NotchLayout.toggle(layout, notch, id)
    host.saveNotchLayout(next.layout, next.notch)
    if (wasOn && selectedId === id) selectedId = ""
    notify(nameFor(id) + (wasOn ? " turned off" : " turned on"), function() {
      host.saveNotchLayout(before.layout, before.notch)
    })
  }

  function placeWidget(id, section, index) {
    var before = { layout: layout, notch: notch }
    var at = NotchLayout.locate(layout, id)
    if (at && at.section === section) {
      // Dropped back where it was: nothing to save.
      var others = (layout[section] || []).filter(function(entry) { return entry.id !== id })
      if (index === at.index && others.length === (layout[section] || []).length - 1) return
    }
    var next = NotchLayout.place(layout, notch, id, section, index)
    host.saveNotchLayout(next.layout, next.notch)
    notify(nameFor(id) + (at ? " moved" : " added"), function() {
      host.saveNotchLayout(before.layout, before.notch)
    })
  }

  function moveWidget(id, direction) {
    if (!NotchLayout.canMove(layout, id, direction)) return
    var before = layout
    host.saveNotchLayout(NotchLayout.move(layout, id, direction), notch)
    notify(nameFor(id) + " moved", function() { host.saveNotchLayout(before, ctl.notch) })
  }

  // ---- quick controls -----------------------------------------------------------

  property var nightlight: null
  property var idle: null
  property var notifications: null
  property string confirmId: ""

  Component.onCompleted: {
    var shell = host.shell
    if (!shell || typeof shell.firstPartyServiceFor !== "function") return
    nightlight = shell.firstPartyServiceFor("omarchy.nightlight")
    idle = shell.firstPartyServiceFor("omarchy.idle")
    notifications = shell.firstPartyServiceFor("omarchy.notifications")
  }


  readonly property var toggles: [
    { id: "nightlight", label: "Night Light", glyph: "nightlight",
      on: !!nightlight && nightlight.enabled,
      run: function() {
        if (ctl.nightlight) ctl.nightlight.setNightlight(!ctl.nightlight.enabled)
        else Util.execDetached("omarchy toggle nightlight")
      } },
    { id: "dnd", label: "Do Not Disturb", glyph: "do_not_disturb_on",
      on: !!notifications && notifications.doNotDisturb,
      run: function() {
        if (ctl.notifications) ctl.notifications.setDoNotDisturb(!ctl.notifications.doNotDisturb)
        else Util.execDetached("omarchy toggle notification silencing")
      } },
    { id: "awake", label: "Stay Awake", glyph: "coffee",
      on: !!idle && idle.stayAwake,
      run: function() {
        if (ctl.idle) ctl.idle.setIdleEnabled(ctl.idle.stayAwake)
        else Util.execDetached("omarchy toggle idle")
      } },
    { id: "dock", label: "Hide Dock", glyph: "dock_to_bottom",
      on: !!host.dock && host.dock.autohide,
      run: function() { Util.execDetached("omarchy-dock autohide toggle") } }
  ]

  readonly property var actions: [
    { id: "theme", label: "Theme", glyph: "palette",
      command: "omarchy-shell -q shell summon omarchy.image-picker '{\"source\":\"themes\"}'" },
    { id: "background", label: "Background", glyph: "wallpaper",
      command: "b=$(omarchy-theme-bg-switcher); [[ -n $b ]] && omarchy-theme-bg-set \"$b\"" },
    { id: "screensaver", label: "Screensaver", glyph: "airwave", command: "omarchy-launch-screensaver force" },
    { id: "lock", label: "Lock", glyph: "lock", command: "omarchy-system-lock" },
    { id: "reload", label: "Reload Shell", glyph: "refresh", command: "omarchy restart shell" },
    { id: "reboot", label: "Restart", glyph: "restart_alt", command: "omarchy system reboot", confirm: true },
    { id: "shutdown", label: "Shut Down", glyph: "power_settings_new", command: "omarchy system shutdown", confirm: true }
  ]

  function runAction(action) {
    if (action.confirm && confirmId !== action.id) {
      confirmId = action.id
      return
    }
    confirmId = ""
    host.closeCustomize()
    Util.execDetached(action.command)
  }

  // ---- plugins ----------------------------------------------------------------

  // Plugins whose switch would take something essential away.
  readonly property var protectedPlugins: ["sumi.lock", "sumi.notch", "sumi.image-picker",
    "sumi.menu", "sumi.notifications", "sumi.osd",
    "omarchy.notifications", "omarchy.polkit", "omarchy.idle", "omarchy.menu", "omarchy.background", "omarchy.osd"]
  // Replaced by this shell; switching them on would run two of a thing.
  readonly property var replacedPlugins: ["astrokachi.dock", "omarchy.dock", "omarchy.lock", "omarchy.menu", "omarchy.notifications", "omarchy.osd", "omarchy.image-picker"]
  property var plugins: []

  function refreshPlugins() {
    if (!pluginList.running) pluginList.running = true
  }

  Process {
    id: pluginList
    command: ["omarchy-shell", "shell", "listPlugins"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = []
        try { parsed = JSON.parse(text) } catch (error) { return }
        if (!Array.isArray(parsed)) return
        ctl.plugins = parsed.filter(function(plugin) {
          var kinds = Array.isArray(plugin.kinds) ? plugin.kinds : []
          return kinds.indexOf("bar-widget") < 0 && kinds.indexOf("bar") < 0
            && ctl.replacedPlugins.indexOf(plugin.id) < 0
        }).map(function(plugin) {
          return { id: String(plugin.id), name: String(plugin.name || plugin.id),
            kinds: (plugin.kinds || []).join(" · "), enabled: plugin.enabled === true,
            firstParty: plugin.firstParty === true,
            locked: plugin.canDisable === false || ctl.protectedPlugins.indexOf(plugin.id) >= 0 }
        })
      }
    }
  }

  Timer {
    id: pluginSettle
    interval: 900
    onTriggered: ctl.refreshPlugins()
  }

  function setPlugin(plugin, on) {
    if (plugin.locked) return
    Util.execDetached("omarchy plugin " + (on ? "enable " : "disable ") + Util.shellQuote(plugin.id))
    // Show the change at once; the listing catches up after the shell does.
    ctl.plugins = ctl.plugins.map(function(item) {
      if (item.id !== plugin.id) return item
      var copy = Object.assign({}, item)
      copy.enabled = on
      return copy
    })
    pluginSettle.restart()
    notify(plugin.name + (on ? " turned on" : " turned off"), function() {
      ctl.setPluginQuietly(plugin.id, !on)
    })
  }

  function setPluginQuietly(id, on) {
    Util.execDetached("omarchy plugin " + (on ? "enable " : "disable ") + Util.shellQuote(id))
    pluginSettle.restart()
  }

  // ---- undo -------------------------------------------------------------------

  property string toastText: ""
  property var undoAction: null

  function notify(text, undo) {
    toastText = text
    undoAction = undo || null
    toastTimer.restart()
  }

  function undo() {
    var action = undoAction
    undoAction = null
    toastText = ""
    toastTimer.stop()
    if (action) action()
  }

  Timer {
    id: toastTimer
    interval: 6000
    onTriggered: { ctl.toastText = ""; ctl.undoAction = null }
  }

  // ---- surface ----------------------------------------------------------------

  Rectangle {
    id: surface
    // Hangs under the notch, at the middle of the bar.
    width: ctl.cardWidth
    height: ctl.cardHeight
    Behavior on height { enabled: ctl.visible; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    // mapToItem() alone tracks only the notch's width: also re-read it when
    // the notch moves (the bar window sizing up after startup) or the panel
    // opens, and keep the card on screen.
    x: {
      ctl.wanted; ctl.width; ctl.anchorItem.x
      var center = ctl.anchorItem.mapToItem(null, ctl.anchorItem.width / 2, 0).x
      return Math.max(Style.space(8), Math.min(ctl.width - width - Style.space(8), Math.round(center - width / 2)))
    }
    y: ctl.host.barSize + Style.space(6)
    radius: Style.space(14)
    color: ctl.paper
    border.width: 1
    border.color: Qt.rgba(ctl.ink.r, ctl.ink.g, ctl.ink.b, 0.12)
    clip: true

    // Clicks on the card's own background stay on the card.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

    focus: true
    Keys.onEscapePressed: {
      if (ctl.query !== "") ctl.query = ""
      else if (ctl.selectedId !== "") ctl.selectedId = ""
      else ctl.host.closeCustomize()
    }

    Column {
      id: head
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      padding: Style.space(14)
      spacing: Style.space(12)

      // Search.
      Rectangle {
        width: head.width - 2 * head.padding
        height: Style.space(32)
        radius: Style.space(9)
        color: ctl.wash
        border.width: 1
        border.color: search.activeFocus ? Qt.rgba(ctl.ink.r, ctl.ink.g, ctl.ink.b, 0.22) : "transparent"

        CtlGlyph {
          id: searchGlyph
          anchors.left: parent.left
          anchors.leftMargin: Style.space(9)
          anchors.verticalCenter: parent.verticalCenter
          text: "search"
          size: Style.space(17)
          color: ctl.ink
          opacity: 0.5
        }

        TextInput {
          id: search
          anchors.left: searchGlyph.right
          anchors.leftMargin: Style.space(7)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          onTextEdited: ctl.query = text
          color: ctl.ink
          selectionColor: Qt.rgba(ctl.ink.r, ctl.ink.g, ctl.ink.b, 0.25)
          font.family: ctl.family
          font.pixelSize: Style.space(13)
          clip: true
          focus: true
          Keys.onEscapePressed: function(event) { event.accepted = false }

          // Follows the query when it is cleared from elsewhere.
          Connections {
            target: ctl
            function onQueryChanged() { if (search.text !== ctl.query) search.text = ctl.query }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !search.text
            textFormat: Text.PlainText
            text: "Search controls, widgets and plugins"
            color: ctl.ink
            opacity: 0.4
            font: search.font
          }
        }
      }

      // Tabs, as a segmented control; hidden while searching.
      Rectangle {
        visible: ctl.needle === ""
        width: head.width - 2 * head.padding
        height: Style.space(28)
        radius: Style.space(8)
        color: ctl.wash

        Rectangle {
          readonly property int index: Math.max(0, ctl.tabs.map(function(tab) { return tab.id }).indexOf(ctl.tab))
          x: Style.space(2) + index * (parent.width - Style.space(4)) / ctl.tabs.length
          y: Style.space(2)
          width: (parent.width - Style.space(4)) / ctl.tabs.length
          height: parent.height - Style.space(4)
          radius: Style.space(6)
          color: Qt.rgba(ctl.ink.r, ctl.ink.g, ctl.ink.b, 0.14)
          Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(2)

          Repeater {
            model: ctl.tabs

            Item {
              id: tabItem
              required property var modelData
              width: parent.width / ctl.tabs.length
              height: parent.height

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: tabItem.modelData.label
                color: ctl.ink
                opacity: ctl.tab === tabItem.modelData.id ? 1 : 0.6
                font.family: ctl.family
                font.pixelSize: Style.space(12)
                font.weight: ctl.tab === tabItem.modelData.id ? Font.DemiBold : Font.Medium
              }

              TapHandler { onTapped: { ctl.tab = tabItem.modelData.id; ctl.host.controlTab = ctl.tab; ctl.confirmId = "" } }
              HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
          }
        }
      }
    }

    Loader {
      id: pageLoader
      anchors.top: head.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: toast.top
      anchors.bottomMargin: Style.space(4)
      sourceComponent: ctl.needle !== "" ? searchPage : ctl.tab === "layout" ? layoutPage : ctl.tab === "plugins" ? pluginsPage : ctl.tab === "bar" ? barPage : quickPage
    }

    // Pages name the panel `ctl` too, so it is handed over by another name.
    readonly property var panel: ctl
    Component { id: quickPage; ControlQuick { ctl: surface.panel } }
    Component { id: layoutPage; ControlLayout { ctl: surface.panel } }
    Component { id: pluginsPage; ControlPlugins { ctl: surface.panel } }
    Component { id: barPage; ControlBar { ctl: surface.panel } }
    Component { id: searchPage; ControlSearch { ctl: surface.panel } }

    // What just changed, with a way back.
    Item {
      id: toast
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: ctl.toastText !== "" ? Style.space(40) : Style.space(10)
      clip: true
      Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: ctl.hairline
        visible: ctl.toastText !== ""
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(16)
        anchors.right: undoLabel.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: ctl.toastText
        elide: Text.ElideRight
        color: ctl.ink
        opacity: 0.75
        font.family: ctl.family
        font.pixelSize: Style.space(12)
      }

      Text {
        id: undoLabel
        anchors.right: parent.right
        anchors.rightMargin: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        visible: ctl.undoAction !== null
        textFormat: Text.PlainText
        text: "Undo"
        color: ctl.ink
        font.family: ctl.family
        font.pixelSize: Style.space(12)
        font.weight: Font.DemiBold

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: ctl.undo() }
      }
    }
  }
}
