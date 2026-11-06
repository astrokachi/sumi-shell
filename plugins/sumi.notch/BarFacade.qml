import QtQuick

// The bar object a hosted widget sees. Everything forwards to the bar, except
// the ink: widgets folded into the notch draw on black whatever the theme.
QtObject {
  id: api

  required property var host
  property color ink: host.foreground
  property color paper: host.background

  readonly property color foreground: ink
  readonly property color barForeground: ink
  // Opaque: widgets build their panels on it, and a see-through tint
  // (a glass notch, a clear bar) would leave them unreadable.
  readonly property color background: Qt.rgba(paper.r, paper.g, paper.b, 1)
  // Hosted widgets paint their glyphs in `urgent`; keep them monochrome.
  property color urgent: ink
  property string fontFamily: host.fontFamily
  readonly property string position: host.position
  readonly property bool vertical: false
  readonly property int barSize: host.barSize
  readonly property bool transparent: host.transparent
  readonly property bool foregroundAnimationEnabled: host.foregroundAnimationEnabled
  readonly property bool centerSectionRevealHeld: false
  readonly property bool centerHoverRevealSuppressed: host.centerHoverRevealSuppressed
  readonly property bool traySectionDragActive: false
  readonly property bool traySectionPopoutOpen: false
  readonly property var activePopout: host.activePopout
  readonly property var clickTargets: host.clickTargets
  readonly property var layoutConfig: host.layoutConfig
  property var shell: host.shell
  // Visual tokens a hosted widget may read; this bar sets none.
  property var visualTokens: null
  readonly property var manifest: host.manifest
  readonly property var barConfig: host.barConfig

  function run(command) { host.run(command) }
  function showTooltip(target, text) { host.showTooltip(target, text) }
  function hideTooltip(target) { host.hideTooltip(target) }
  function requestPopout(owner) { host.requestPopout(owner) }
  function releasePopout(owner) { host.releasePopout(owner) }
  function registerClickTarget(target) { host.registerClickTarget(target) }
  function unregisterClickTarget(target) { host.unregisterClickTarget(target) }
  function switchPanelFrom(owner, direction) { return host.switchPanelFrom(owner, direction) }
  function moduleWidgets(id) { return host.moduleWidgets(id) }
  function targetBelongsToWindow(target, window) { return host.targetBelongsToWindow(target, window) }
  function setCenterHoverRevealSuppressed(value) { host.setCenterHoverRevealSuppressed(value) }
  function cycleBackground() { host.cycleBackground() }
}
