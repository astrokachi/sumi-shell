import QtQuick
import qs.Commons as Commons

// The Sumi design system as one object: type, ink, surfaces, shape and
// motion for every surface the shell draws. Colours derive from the active
// Omarchy theme (the Sumi theme supplies the palette), so a theme change
// still carries through.
QtObject {
  id: ds

  // Type: one family for every interface surface, a Japanese companion,
  // and the system monospace for figures and keys.
  readonly property string fontUi: "Inter"
  readonly property string fontJp: "Zen Kaku Gothic New"
  readonly property string fontMono: "JetBrainsMono Nerd Font"

  // Ink, from strongest to quietest. Secondary inks are the primary at
  // lower opacity so they sit on any surface.
  readonly property color ink: Commons.Color.foreground
  readonly property color ink2: Qt.rgba(ink.r, ink.g, ink.b, 0.64)
  readonly property color ink3: Qt.rgba(ink.r, ink.g, ink.b, 0.56)
  readonly property color paper: Commons.Color.background
  // Shu red: alerts, recording, errors. Never decoration.
  readonly property color signal: Commons.Color.bar.active

  // Surfaces: a panel is ink-dark and nearly opaque; tiles and rows inside
  // it are lifted with a wash of ink rather than a new colour.
  readonly property color panel: Qt.rgba(paper.r, paper.g, paper.b, 0.96)
  readonly property color raised: Qt.rgba(ink.r, ink.g, ink.b, 0.05)
  readonly property color raised2: Qt.rgba(ink.r, ink.g, ink.b, 0.09)
  readonly property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.09)
  readonly property color highlight: Qt.rgba(1, 1, 1, 0.06)
  readonly property color sel: Qt.rgba(ink.r, ink.g, ink.b, 0.08)
  readonly property color on: ink
  readonly property color onInk: paper
  readonly property color notch: "#0A0A0A"

  // Shape: concentric radii, inner = outer minus padding.
  readonly property real rPanel: 14
  readonly property real rTile: 12
  readonly property real rRow: 8
  readonly property real rChip: 6
  readonly property real rDock: 20
  readonly property real rApp: 11

  readonly property real iconStroke: 1.4

  // Motion: still and unbouncing.
  readonly property int openMs: 160
  readonly property int closeMs: 120
  // A strong ease-out for things arriving or leaving: quick at the start,
  // where the eye is, then settling. For Easing.BezierSpline.
  readonly property var easeOut: [0.23, 1, 0.32, 1, 1, 1]
}
