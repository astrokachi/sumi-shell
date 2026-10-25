import QtQuick

// A spring in Apple's terms, for motion that should feel physical:
//  - `response`: how quickly it gets there, in seconds (not a duration; a
//    spring has none, it settles when it settles).
//  - `dampingRatio`: 1 arrives without overshoot; lower overshoots a little
//    and settles back, which reads as springy. Keep it at 0.75 or above.
//
// It always moves on from wherever it is at whatever speed it has, so changing
// `target` mid-flight (opening again while it closes) turns around smoothly
// instead of jumping back or starting over. It only draws frames while moving.
//
// Bind to `value`; drive it by setting `target`. It starts at its first target
// rather than springing there from 0, and `animated: false` makes every change
// a jump (for reduced motion).
Item {
  id: spring
  visible: false

  property real target: 0
  property real value: 0
  property real velocity: 0
  property real response: 0.35
  property real dampingRatio: 1
  property bool animated: true
  readonly property bool moving: frames.running

  // Jump to `to` and rest there. Only for springs driven by setting
  // `target` from code: on one whose `target` is bound, assigning it would
  // break the binding.
  function snap(to) {
    frames.stop()
    velocity = 0
    value = to
    if (target !== to) target = to
  }

  onTargetChanged: {
    if (!animated) {
      // Jump without touching `target`, so a bound target stays bound.
      frames.stop()
      velocity = 0
      value = target
      return
    }
    if (value !== target || velocity !== 0) frames.running = true
  }

  Component.onCompleted: {
    value = target
    velocity = 0
  }

  FrameAnimation {
    id: frames
    onTriggered: {
      // A long frame (the shell busy, a surface just mapped) shouldn't throw
      // the spring off; integrate in small fixed steps either way.
      var dt = Math.min(Math.max(frameTime, 0), 1 / 30)
      var omega = 2 * Math.PI / Math.max(spring.response, 0.01)
      var stiffness = omega * omega
      var damping = 2 * spring.dampingRatio * omega
      var steps = Math.max(1, Math.ceil(dt * 240))
      var h = dt / steps
      var x = spring.value - spring.target
      var v = spring.velocity
      for (var i = 0; i < steps; i++) {
        v += (-stiffness * x - damping * v) * h
        x += v * h
      }
      // At rest once the remaining motion is under a fraction of a pixel (or
      // of an opacity step) at this scale.
      var scale = Math.max(1, Math.abs(spring.target))
      if (Math.abs(x) < 0.0005 * scale && Math.abs(v) < 0.01 * scale) {
        stop()
        spring.velocity = 0
        spring.value = spring.target
        return
      }
      spring.velocity = v
      spring.value = spring.target + x
    }
  }
}
