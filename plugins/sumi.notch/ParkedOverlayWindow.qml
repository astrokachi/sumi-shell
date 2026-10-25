import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

// OverlayWindow's interface, but the surface is mapped once and parked rather
// than mapped fresh on every open. A fresh fullscreen surface cost ~250 ms per
// open (window setup, scale handshake, first frame, then the layer fade);
// a parked one only has to draw the next frame. While hidden it is
// transparent, takes no keyboard focus and has an empty input region, the way
// the notification surface idles, so clicks fall through to the desktop.
PanelWindow {
  id: window

  // Whether the overlay is showing. Drive this instead of visible.
  property bool shown: false
  property int shownLayer: WlrLayer.Overlay
  property int shownKeyboardFocus: WlrKeyboardFocus.Exclusive

  property var targetScreen: focusedScreen()

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  // A short fade with a slight settle in, and a quicker fade out, so opening
  // and closing don't cut. Input and focus follow `shown` at once; only the
  // drawing eases. Off with Hyprland's animations (Style.duration).
  property bool animateReveal: true
  // Where the settle grows from: the trigger for a dropdown, the middle for
  // a dialog.
  property int revealOrigin: Item.Center
  property real reveal: 0
  SumiTokens { id: motion }
  NumberAnimation {
    id: revealAnim
    target: window
    property: "reveal"
    easing.type: Easing.BezierSpline
    easing.bezierCurve: motion.easeOut
  }

  // Follow focus at open. Only a monitor change re-creates the surface; on
  // the same monitor this assignment is a no-op.
  onShownChanged: {
    if (shown) targetScreen = focusedScreen()
    revealAnim.stop()
    if (!animateReveal) {
      reveal = shown ? 1 : 0
      return
    }
    // From wherever it is, so reopening mid-close turns around smoothly.
    revealAnim.to = shown ? 1 : 0
    revealAnim.duration = Commons.Style.duration(shown ? motion.openMs : motion.closeMs)
    revealAnim.start()
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (Quickshell.screens.indexOf(window.targetScreen) < 0) {
        window.targetScreen = null
        // Let the removed output finish closing its old window before mapping
        // a replacement, rather than recreating it during Qt's teardown.
        Qt.callLater(function() {
          if (!window.targetScreen) window.targetScreen = window.focusedScreen()
        })
      }
    }
  }

  visible: !!targetScreen
  screen: targetScreen
  // Parked, the surface shrinks to one pixel in the corner. Hyprland blurs a
  // blurred layer wherever what is under it changes, even a transparent one,
  // and four parked fullscreen layers halved the frame rate (30 FPS over
  // video). Opening grows it back; that is a resize, not a new surface.
  readonly property bool parked: !shown && reveal === 0
  anchors { top: true; left: true; bottom: !parked; right: !parked }
  implicitWidth: 1
  implicitHeight: 1
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: shownLayer
  WlrLayershell.keyboardFocus: shown ? shownKeyboardFocus : WlrKeyboardFocus.None

  // The whole surface takes input while shown (a click outside the card
  // closes it); none while parked.
  Item { id: inputCover; anchors.fill: parent }
  mask: Region { item: window.shown ? inputCover : null }

  // Opacity rather than visible keeps keyboard handling live from the first
  // frame, so a search keystroke right after the shortcut is not lost.
  Binding {
    target: window.contentItem
    property: "opacity"
    value: window.reveal
  }
  Binding {
    target: window.contentItem
    property: "scale"
    value: 0.98 + 0.02 * window.reveal
  }
  Binding {
    target: window.contentItem
    property: "transformOrigin"
    value: window.revealOrigin
  }

  // Right-to-left languages read the overlay mirrored.
  Binding {
    target: window.contentItem
    property: "LayoutMirroring.enabled"
    value: Commons.I18n.rightToLeft
  }
  Binding {
    target: window.contentItem
    property: "LayoutMirroring.childrenInherit"
    value: true
  }
}
