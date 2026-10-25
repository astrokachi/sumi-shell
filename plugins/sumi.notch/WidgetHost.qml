import QtQuick
import qs.Commons

// One bar widget, built from the shell's registry by id.
Item {
  id: slot

  required property var host
  required property var facade
  required property var entry
  property string screenName: ""
  property bool inNotch: false
  property string fixedEdge: "start"

  readonly property string moduleName: entry ? Util.canonicalWidgetId(String(entry.id || "")) : ""
  readonly property var moduleSettings: {
    var copy = {}
    if (!entry) return copy
    for (var key in entry) if (key !== "id") copy[key] = entry[key]
    return copy
  }
  readonly property var registryEntry: {
    var registry = host.barWidgetRegistry
    if (!registry || !registry.widgets) return null
    void(registry.revision)
    return registry.widgets[moduleName] || null
  }
  readonly property Item activeItem: loader.item
  readonly property int loaderStatus: loader.status

  // Each widget gets its own bar object, so its shell resolves its services.
  WidgetShell {
    id: widgetShell
    host: slot.host
    moduleName: slot.moduleName
  }

  BarFacade {
    id: ownFacade
    host: slot.host
    ink: slot.facade.ink
    paper: slot.facade.paper
    shell: widgetShell
  }

  // Never hide the slot itself: an item's `visible` includes its parents',
  // so a hidden slot would read its widget as hidden and stay at zero width.
  implicitWidth: loader.item && loader.item.visible ? Math.ceil(loader.item.implicitWidth) : 0
  implicitHeight: host.barSize
  width: implicitWidth
  height: implicitHeight

  Loader {
    id: loader
    anchors.verticalCenter: parent.verticalCenter
    width: item ? Math.ceil(item.implicitWidth) : 0
    height: slot.height
    sourceComponent: slot.registryEntry ? slot.registryEntry.component : null
    onLoaded: slot.inject()
    onStatusChanged: if (status === Loader.Error) console.warn("sumi.notch: widget " + slot.moduleName + " failed to load")
  }

  function inject() {
    var target = loader.item
    if (!target) return
    if ("fixedEdge" in target) target.fixedEdge = fixedEdge
    if ("bar" in target) target.bar = ownFacade
    if ("moduleName" in target) target.moduleName = moduleName
    if ("settings" in target) target.settings = moduleSettings
  }

  onModuleSettingsChanged: inject()
  onFacadeChanged: inject()

  Component.onCompleted: host.registerWidgetHost(slot)
  Component.onDestruction: host.unregisterWidgetHost(slot)
}
