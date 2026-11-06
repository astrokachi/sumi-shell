import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Three battery-only behaviours the stock idle service doesn't cover:
//  - Unplugging always starts on power-saver. omarchy-powerprofiles-set
//    otherwise remembers the last profile picked on battery, so one manual
//    "performance" sticks to every later unplug. Overrides still work for the
//    rest of that battery session, and AC keeps its remembered choice.
//  - Boost through heavy load. Power-saver pins every core at 800 MHz, so a
//    build or a batch of renders crawls. Sustained high CPU takes a
//    performance hold (~1.3-1.4 GHz on battery here) until the load eases.
//    A hold never touches the remembered profile, and power-profiles-daemon
//    drops it the moment a profile is picked by hand.
//  - Suspend after a long idle, on battery only. Video and other idle
//    inhibitors hold it off, and so does the shell's stay-awake toggle.
Item {
  id: root

  property var shell: null

  readonly property int suspendAfterSeconds: 900
  readonly property string batteryProfile: "power-saver"
  readonly property bool onBattery: UPower.onBattery

  // Busy share of all cores, sampled every 5 s. Boost after 20 s at or above
  // 70%, release after 30 s under 35%. The release bar is low because the
  // same work reads as less busy once the clock rises.
  readonly property int sampleSeconds: 5
  readonly property real boostAbove: 0.70
  readonly property int boostAfterSamples: 4
  readonly property real releaseBelow: 0.35
  readonly property int releaseAfterSamples: 6
  readonly property real boostMinBattery: 0.20
  // After a hold is dropped from outside (a profile picked by hand), wait
  // before boosting again so the choice sticks.
  readonly property int overrideCooldownMs: 600000

  readonly property bool onPowerSaver: PowerProfiles.profile === PowerProfile.PowerSaver
  readonly property real batteryLevel: UPower.displayDevice && UPower.displayDevice.isPresent
    ? UPower.displayDevice.percentage : 1
  // Set the moment a boost starts or stops. boostProcess.running lags a stop
  // until the process exits, and the profile flips back before that.
  property bool boosting: false

  property var cpuPrev: null
  property int busySamples: 0
  property int quietSamples: 0
  property real cooldownUntil: 0

  function startBoost() {
    console.log("battery-saver boost on")
    root.busySamples = 0
    root.quietSamples = 0
    root.boosting = true
    boostProcess.running = true
  }

  function stopBoost(reason) {
    if (!root.boosting) return
    console.log("battery-saver boost off: " + reason)
    root.boosting = false
    boostProcess.running = false
  }

  function sample(busy) {
    if (boosting) {
      root.quietSamples = busy < releaseBelow ? root.quietSamples + 1 : 0
      if (root.quietSamples >= releaseAfterSamples) stopBoost("load eased")
      else if (batteryLevel < boostMinBattery) stopBoost("battery low")
      return
    }
    root.busySamples = busy >= boostAbove ? root.busySamples + 1 : 0
    if (root.busySamples >= boostAfterSamples && onPowerSaver
        && batteryLevel >= boostMinBattery && Date.now() >= root.cooldownUntil)
      startBoost()
  }

  function run(process, command) {
    if (process.running) return
    process.command = ["bash", "-lc", command]
    process.running = true
  }

  // UPower fills in after load, so onBattery starts false and flips once
  // ready; that first flip also applies the battery profile on startup.
  // Plugging in restores AC's remembered profile. The stock battery service
  // did that and this one replaces it: without it, power-saver from the last
  // unplug stayed on AC, every core held near 700 MHz.
  onOnBatteryChanged: {
    console.log("battery-saver onBattery=" + onBattery)
    root.busySamples = 0
    if (onBattery) run(profileProcess, "omarchy-powerprofiles-set battery " + batteryProfile)
    else {
      stopBoost("plugged in")
      run(profileProcess, "omarchy-powerprofiles-set ac")
    }
  }

  // power-profiles-daemon releases every hold when a profile is set by hand.
  // The hold's process keeps running regardless, so end it here.
  Connections {
    target: PowerProfiles
    function onProfileChanged() {
      if (!root.boosting || PowerProfiles.profile === PowerProfile.Performance) return
      root.cooldownUntil = Date.now() + root.overrideCooldownMs
      root.stopBoost("profile changed by hand")
    }
  }

  Timer {
    interval: root.sampleSeconds * 1000
    repeat: true
    running: root.onBattery
    onTriggered: if (!cpuProbe.running) cpuProbe.running = true
    onRunningChanged: root.cpuPrev = null
  }

  Process {
    id: cpuProbe
    command: ["head", "-1", "/proc/stat"]
    stdout: StdioCollector {
      onStreamFinished: {
        var vals = text.trim().split(/\s+/).slice(1).map(Number)
        var idle = vals[3] + (vals[4] || 0)
        var total = vals.reduce(function(a, b) { return a + b }, 0)
        var prev = root.cpuPrev
        root.cpuPrev = { total: total, idle: idle }
        if (prev && total > prev.total) root.sample(1 - (idle - prev.idle) / (total - prev.total))
      }
    }
  }

  // The hold lasts as long as this process. powerprofilesctl forwards SIGTERM
  // to its child and then releases the hold. The child also exits if
  // quickshell dies, so a killed shell can't leave the hold stuck on.
  Process {
    id: boostProcess
    command: ["bash", "-c",
      "qs=$PPID; exec powerprofilesctl launch -p performance -i sumi.battery-saver"
      + " -r 'Heavy CPU load on battery'"
      + " -- bash -c 'while kill -0 \"$0\" 2>/dev/null; do sleep 5; done' \"$qs\""]
    onRunningChanged: if (!running && root.boosting) {
      console.log("battery-saver boost ended on its own")
      root.boosting = false
    }
  }

  // Starting on AC never flips onBattery, so apply AC's profile once UPower
  // has had time to report. On battery the flip has already run by then.
  Timer {
    interval: 3000
    running: true
    onTriggered: if (!root.onBattery) root.run(profileProcess, "omarchy-powerprofiles-set ac")
  }

  IdleMonitor {
    id: idleMonitor
    // Re-arming on unplug restarts the count, so a long AC idle can't suspend
    // the moment the cable comes out.
    enabled: root.onBattery
    timeout: root.suspendAfterSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (!isIdle || !root.onBattery) return
      root.run(suspendProcess,
        "[[ -e \"$HOME/.local/state/omarchy/indicators/stay-awake\" ]] && exit 0; " +
        "omarchy-sleep-disabled && exit 0; " +
        "[[ $(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery) == 'b true' ]] || exit 0; " +
        "systemctl suspend")
    }
  }

  Process { id: profileProcess }
  Process { id: suspendProcess }
}
