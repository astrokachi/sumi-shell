import QtQuick

// The `shell` a hosted widget sees: services, summons and settings resolve
// through the facade Omarchy builds for this bar entry.
QtObject {
  id: api

  required property var host
  required property string moduleName

  // Looked up outside any binding: the shell builds the facade on first
  // request, and doing that while a binding evaluates loops it.
  property var entryShell: null

  function refreshEntryShell() {
    entryShell = host.shell && typeof host.shell.pluginShellForBarEntry === "function"
      ? host.shell.pluginShellForBarEntry("sumi.notch", moduleName) : null
  }

  onModuleNameChanged: Qt.callLater(refreshEntryShell)
  Component.onCompleted: Qt.callLater(refreshEntryShell)
  readonly property var barConfig: host.barConfig
  readonly property var shellConfig: ({ bar: host.barConfig })
  readonly property var pluginRegistry: null

  function serviceFor(id) {
    return entryShell ? entryShell.serviceFor(String(id || "")) : null
  }

  function firstPartyServiceFor(id) {
    return host.shell && typeof host.shell.firstPartyServiceFor === "function"
      ? host.shell.firstPartyServiceFor(String(id || "")) : null
  }

  function summon(id, payloadJson) { return entryShell ? entryShell.summon(id, payloadJson) : false }
  function hide(id) { return entryShell ? entryShell.hide(id) : false }
  function toggle(id, payloadJson) { return entryShell ? entryShell.toggle(id, payloadJson) : false }
  function isPluginOpen(id) { return entryShell ? entryShell.isPluginOpen(id) : false }
  function updateEntryInline(id, settings) { return entryShell ? entryShell.updateEntryInline(id, settings) : false }
  function mutateShellConfig(mutator) { return false }
  function pluginShellForBarEntry(ownerId, name) { return null }
}
