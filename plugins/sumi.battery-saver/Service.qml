import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Two battery-only behaviours the stock idle service doesn't cover:
//  - Unplugging always starts on power-saver. omarchy-powerprofiles-set
//    otherwise remembers the last profile picked on battery, so one manual
//    "performance" sticks to every later unplug. Overrides still work for the
//    rest of that battery session, and AC keeps its remembered choice.
//  - Suspend after a long idle, on battery only. Video and other idle
//    inhibitors hold it off, and so does the shell's stay-awake toggle.
Item {
  id: root

  property var shell: null

  readonly property int suspendAfterSeconds: 900
  readonly property string batteryProfile: "power-saver"
  readonly property bool onBattery: UPower.onBattery

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
    if (onBattery) run(profileProcess, "omarchy-powerprofiles-set battery " + batteryProfile)
    else run(profileProcess, "omarchy-powerprofiles-set ac")
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
