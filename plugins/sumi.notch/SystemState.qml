import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs.Commons

// What the bar's status glyphs and the control center show, and the
// actions behind them, in one place so the two always agree.
QtObject {
  id: state

  // Kept polling only while something on screen reads it.
  property bool active: false

  // ---- Wi-Fi (NetworkManager) ------------------------------------------------

  property bool wifiOn: true
  property string ssid: ""
  property int signal: 0
  readonly property bool wifiConnected: ssid !== ""

  property Process wifiProbe: Process {
    command: ["bash", "-c", "nmcli -t radio wifi; nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        state.wifiOn = String(lines[0] || "").trim() === "enabled"
        var active = String(lines[1] || "")
        if (active.indexOf("yes:") === 0) {
          var rest = active.substring(4)
          var colon = rest.indexOf(":")
          state.signal = parseInt(rest.substring(0, colon), 10) || 0
          state.ssid = rest.substring(colon + 1).replace(/\\:/g, ":")
        } else {
          state.ssid = ""
          state.signal = 0
        }
      }
    }
  }

  function refreshWifi() {
    if (!wifiProbe.running) wifiProbe.running = true
  }

  function setWifi(on) {
    state.wifiOn = on
    Util.execDetached("nmcli radio wifi " + (on ? "on" : "off"))
    wifiSettle.restart()
  }

  property Timer wifiSettle: Timer { interval: 1500; onTriggered: state.refreshWifi() }
  property Timer wifiPoll: Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: state.refreshWifi()
  }

  // ---- Wi-Fi networks: scan, join, leave, forget ------------------------------

  property var networks: []
  property bool scanning: false
  // The network a join is in flight for, and the last failure and its network.
  property string joining: ""
  property string joinError: ""
  property string joinErrorSsid: ""

  // nmcli -t escapes ':' inside a field as '\:'.
  function splitTerse(line) {
    var out = []
    var cur = ""
    for (var i = 0; i < line.length; i++) {
      var ch = line.charAt(i)
      if (ch === "\\" && i + 1 < line.length) { cur += line.charAt(i + 1); i++ }
      else if (ch === ":") { out.push(cur); cur = "" }
      else cur += ch
    }
    out.push(cur)
    return out
  }

  property Process scanProc: Process {
    command: ["bash", "-c",
      "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$NF==\"802-11-wireless\"{sub(/:802-11-wireless$/,\"\"); print \"K:\" $0}';"
      + " nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan yes 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        var known = {}
        var bySsid = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i]
          if (!line) continue
          if (line.indexOf("K:") === 0) { known[line.substring(2)] = true; continue }
          var f = state.splitTerse(line)
          if (f.length < 4) continue
          var ssid = f.slice(3).join(":")
          if (!ssid) continue
          var net = { ssid: ssid, inUse: f[0] === "*", signal: parseInt(f[1], 10) || 0,
            security: f[2] === "--" ? "" : f[2], secure: f[2] !== "" && f[2] !== "--" }
          var prev = bySsid[ssid]
          if (!prev || net.inUse || (!prev.inUse && net.signal > prev.signal)) bySsid[ssid] = net
        }
        var list = []
        for (var k in bySsid) { bySsid[k].known = !!known[k]; list.push(bySsid[k]) }
        list.sort(function(a, b) {
          if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
          if (a.known !== b.known) return a.known ? -1 : 1
          return b.signal - a.signal
        })
        state.networks = list
      }
    }
    onExited: state.scanning = false
  }

  function scanWifi() {
    if (scanProc.running) return
    scanning = true
    scanProc.running = true
  }

  // A secured network that isn't saved yet: the password goes in on stdin and
  // reaches nmcli through its editor, never on a command line (argv is
  // readable by anyone in /proc).
  readonly property string pskJoinScript:
    "u=$(uuidgen); IFS= read -r pw;"
    + " nmcli connection add type wifi con-name \"$1\" ssid \"$1\" connection.uuid \"$u\" wifi-sec.key-mgmt \"$2\" >/dev/null"
    + " && printf 'set wifi-sec.psk %s\\nsave\\nquit\\n' \"$pw\" | nmcli connection edit uuid \"$u\" >/dev/null"
    + " && nmcli --wait 20 connection up uuid \"$u\" >/dev/null"
    + " || { nmcli connection delete uuid \"$u\" >/dev/null 2>&1; exit 1; }"

  property Process joinProc: Process {
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      if (secret !== "") write(secret + "\n")
      secret = ""
      stdinEnabled = false
    }
    onExited: function(code) {
      var ssid = state.joining
      state.joining = ""
      stdinEnabled = true
      if (code !== 0) {
        state.joinErrorSsid = ssid
        state.joinError = "Couldn't join. Check the password and try again."
      }
      state.refreshWifi()
      state.scanWifi()
    }
  }

  function join(net, password) {
    if (!net || joinProc.running) return
    joining = net.ssid
    joinError = ""
    joinErrorSsid = ""
    if (net.known) {
      joinProc.command = ["nmcli", "--wait", "20", "connection", "up", "id", net.ssid]
    } else if (!net.secure) {
      joinProc.command = ["nmcli", "--wait", "20", "dev", "wifi", "connect", net.ssid]
    } else {
      var mgmt = /WPA3/.test(net.security) && !/WPA2|WPA1/.test(net.security) ? "sae" : "wpa-psk"
      joinProc.secret = String(password || "")
      joinProc.command = ["bash", "-c", pskJoinScript, "nmcli-join", net.ssid, mgmt]
    }
    joinProc.running = true
  }

  function leave(net) {
    Util.execDetached("nmcli connection down id " + Util.shellQuote(net.ssid))
    wifiSettle.restart()
    scanAfter.restart()
  }

  function forget(net) {
    Util.execDetached("nmcli connection delete id " + Util.shellQuote(net.ssid))
    scanAfter.restart()
  }

  property Timer scanAfter: Timer { interval: 1500; onTriggered: state.scanWifi() }

  // ---- Bluetooth ---------------------------------------------------------------

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool bluetoothOn: !!adapter && adapter.enabled
  readonly property string bluetoothDevice: {
    var devices = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < devices.length; i++) if (devices[i].connected) return String(devices[i].name || devices[i].deviceName || "")
    return ""
  }

  function setBluetooth(on) {
    if (adapter) adapter.enabled = on
  }

  readonly property var bluetoothDevices: {
    var values = Bluetooth.devices ? Bluetooth.devices.values : []
    var out = []
    for (var i = 0; i < values.length; i++) if (values[i] && (values[i].name || values[i].deviceName)) out.push(values[i])
    out.sort(function(a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.paired !== b.paired) return a.paired ? -1 : 1
      return String(a.name).localeCompare(String(b.name))
    })
    return out
  }
  readonly property bool discovering: !!adapter && adapter.discovering

  function setDiscovering(on) {
    if (adapter) adapter.discovering = on
  }

  function toggleDevice(device) {
    if (!device) return
    if (device.connected) device.disconnect()
    else if (device.paired) device.connect()
    else device.pair()
  }

  // ---- Sound -------------------------------------------------------------------

  readonly property var sink: Pipewire.defaultAudioSink
  property PwObjectTracker sinkTracker: PwObjectTracker { objects: state.sink ? [state.sink] : [] }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !!sink && !!sink.audio && sink.audio.muted

  // Output devices, and switching between them.
  readonly property var sinks: {
    var values = Pipewire.nodes ? Pipewire.nodes.values : []
    var out = []
    for (var i = 0; i < values.length; i++) {
      var n = values[i]
      if (n && n.isSink && !n.isStream && n.audio) out.push(n)
    }
    return out
  }

  function sinkName(node) {
    return node ? String(node.description || node.nickname || node.name || "Output") : ""
  }

  function setSink(node) {
    if (node) Pipewire.preferredDefaultAudioSink = node
  }

  function setVolume(fraction) {
    if (sink && sink.audio) {
      sink.audio.muted = false
      sink.audio.volume = Math.max(0, Math.min(1, fraction))
    }
  }

  // ---- Display brightness ----------------------------------------------------
  //
  // For the focused monitor. Omarchy's omarchy-brightness-display picks how:
  // the backlight for a built-in panel, DDC/CI for an external monitor, an
  // Apple display's own control. A monitor it can't dim reads as unavailable.

  property real brightness: 0.5
  property bool brightnessAvailable: true
  readonly property string brightnessMonitor: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  onBrightnessMonitorChanged: if (active) { refreshBrightness(); refreshDisplays() }

  function brightnessCommand(extra) {
    var command = ["omarchy-brightness-display", "--no-osd"]
    if (brightnessMonitor !== "") command.push("--monitor", brightnessMonitor)
    return command.concat(extra)
  }

  property Process brightnessProbe: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        var pct = parseInt(text.trim(), 10)
        state.brightnessAvailable = !isNaN(pct)
        // A drag in progress wins over a reading taken before it.
        if (!isNaN(pct) && state.pendingBrightness < 0 && !state.brightnessSetter.running)
          state.brightness = Math.max(0.01, pct / 100)
      }
    }
  }

  function refreshBrightness() {
    if (brightnessProbe.running) return
    brightnessProbe.command = brightnessCommand([])
    brightnessProbe.running = true
  }

  // The brightness keys only tell the OSD, and the backlight's sysfs file
  // raises no change events, so re-read it while the control center is open
  // to keep the slider live, as the volume one is. The probe skips a tick
  // while the last one is still running (DDC is slow) or a drag is applying.
  property Timer brightnessPoll: Timer {
    interval: 250
    repeat: true
    running: state.active && state.brightnessAvailable
    onTriggered: state.refreshBrightness()
  }

  // Applied a moment after the last change, one command at a time: DDC is
  // slow, and the script drops a call that overlaps another, so the value a
  // drag ends on is always sent once the one before it finishes.
  property real pendingBrightness: -1
  property Timer brightnessApply: Timer {
    interval: 60
    onTriggered: state.applyBrightness()
  }

  property Process brightnessSetter: Process {
    onExited: state.applyBrightness()
  }

  function applyBrightness() {
    if (pendingBrightness < 0 || brightnessSetter.running) return
    var pct = Math.max(1, Math.round(pendingBrightness * 100))
    pendingBrightness = -1
    brightnessSetter.command = brightnessCommand([pct + "%"])
    brightnessSetter.running = true
  }

  function setBrightness(fraction) {
    state.brightness = Math.max(0.01, Math.min(1, fraction))
    state.pendingBrightness = state.brightness
    if (!brightnessApply.running) brightnessApply.start()
  }

  // ---- Battery -----------------------------------------------------------------

  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isPresent
  readonly property real batteryLevel: hasBattery ? Math.max(0, Math.min(1, battery.percentage)) : 0
  // Plugged in is not the same as charging: a full battery, or one held at a
  // charge limit, sits on the charger without taking any.
  readonly property bool pluggedIn: hasBattery && !UPower.onBattery
  readonly property bool charging: pluggedIn && battery.state === UPowerDeviceState.Charging
  readonly property string batteryTime: {
    if (!hasBattery) return ""
    if (pluggedIn && !charging)
      return battery.state === UPowerDeviceState.FullyCharged || batteryLevel >= 0.995 ? "charged" : "not charging"
    var seconds = charging ? battery.timeToFull : battery.timeToEmpty
    // On battery UPower's time is 0 whenever its rate is (see the draw
    // below), so the energy left over the draw shown beside it stands in.
    var estimated = false
    if (!(seconds > 0) && !pluggedIn && powerDraw > 0) {
      seconds = (Number(battery.energy) || 0) / powerDraw * 3600
      estimated = powerDrawEstimated
    }
    if (!(seconds > 0)) return charging ? "charging" : ""
    var minutes = Math.round(seconds / 60)
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    var span = (estimated ? "≈ " : "") + (h > 0 ? h + " h " : "") + m + " m"
    return charging ? span + " to full" : span + " left"
  }

  // UPower's combined device reports no health and lags on rate (0 W for a
  // while after plugging in on this laptop), so the battery's own sysfs
  // figures fill in, as the Shibumi battery panel does. This HP's firmware
  // also fails current_now reads at times (ENODEV) while UPower says 0 W, so
  // when neither live source answers, the draw comes from how fast the stored
  // energy is moving, and failing that the last good figure is held.
  property real sysfsDraw: 0
  property real sysfsHealth: 0
  property real heldDraw: 0
  property bool heldDrawEstimated: false
  property string drawStatus: ""
  // {t: ms, q: µAh or µWh} counter readings over the last few minutes of one
  // charge state. Kept in the battery's own unit: multiplying each reading by
  // the voltage instead would let ~0.1 V of sag swamp a minute's drain.
  property var energySamples: []
  readonly property int energyWindowMs: 10 * 60 * 1000
  // The counter moves in ~6 mAh steps every ~23 s here, so two minutes keeps
  // a partly seen step under ~15% of the figure.
  readonly property int energyMinSpanMs: 2 * 60 * 1000
  readonly property real liveDraw: {
    if (!hasBattery) return 0
    var rate = Math.abs(Number(battery.changeRate) || 0)
    return rate > 0 ? rate : sysfsDraw
  }
  readonly property real powerDraw: !hasBattery ? 0 : liveDraw > 0 ? liveDraw : heldDraw
  readonly property bool powerDrawEstimated: liveDraw <= 0 && heldDraw > 0 && heldDrawEstimated

  // Watts from the oldest reading in the window to now, or 0 until the
  // window spans the minimum and the battery's counter has moved. A charge
  // counter (µAh) converts at the present voltage (µV).
  function trendDraw(samples, unit, voltage) {
    if (samples.length < 2) return 0
    var first = samples[0]
    var last = samples[samples.length - 1]
    var span = last.t - first.t
    if (span < energyMinSpanMs || last.q === first.q) return 0
    var perHour = Math.abs(last.q - first.q) / (span / 3600000)
    if (unit === "wh") return perHour / 1e6
    return voltage > 0 ? perHour * voltage / 1e12 : 0
  }

  function recordBatteryReading(status, counter, unit, voltage) {
    if (status !== drawStatus) {
      drawStatus = status
      energySamples = []
      heldDraw = 0
    }

    var now = Date.now()
    var samples = energySamples.filter(function(s) { return now - s.t <= energyWindowMs })
    if (counter > 0) samples.push({ t: now, q: counter })
    energySamples = samples

    var trend = trendDraw(samples, unit, voltage)
    if (liveDraw > 0) {
      heldDraw = liveDraw
      heldDrawEstimated = false
    } else if (trend > 0) {
      heldDraw = trend
      heldDrawEstimated = true
    }
  }
  readonly property real health: {
    if (!hasBattery) return 0
    if (battery.healthSupported && battery.healthPercentage > 0) return Number(battery.healthPercentage)
    return sysfsHealth
  }
  readonly property real capacity: hasBattery ? Number(battery.energyCapacity) || 0 : 0

  property Process batteryProbe: Process {
    command: ["bash", "-c",
      "for b in /sys/class/power_supply/*; do [ \"$(cat $b/type 2>/dev/null)\" = Battery ] || continue;"
      + " if [ -r $b/power_now ]; then w=$(cat $b/power_now); else w=$(( $(cat $b/current_now 2>/dev/null || echo 0) * $(cat $b/voltage_now 2>/dev/null || echo 0) / 1000000 )); fi;"
      + " f=$(cat $b/energy_full 2>/dev/null || cat $b/charge_full 2>/dev/null || echo 0);"
      + " d=$(cat $b/energy_full_design 2>/dev/null || cat $b/charge_full_design 2>/dev/null || echo 0);"
      + " if [ -r $b/energy_now ]; then echo \"counter $(cat $b/energy_now)\"; echo \"unit wh\";"
      + " else echo \"counter $(cat $b/charge_now 2>/dev/null || echo 0)\"; echo \"unit ah\"; fi;"
      + " echo \"volt $(cat $b/voltage_now 2>/dev/null || echo 0)\";"
      + " echo \"draw ${w#-}\"; echo \"full $f\"; echo \"design $d\";"
      + " echo \"status $(cat $b/status 2>/dev/null | tr -d ' ')\"; break; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var v = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].trim().split(" ")
          if (parts.length === 2) v[parts[0]] = parts[1]
        }
        // sysfs counts microwatts and micro-amp/watt-hours.
        var full = Number(v.full) || 0
        var design = Number(v.design) || 0
        state.sysfsDraw = (Number(v.draw) || 0) / 1e6
        state.sysfsHealth = design > 0 ? Math.min(100, full * 100 / design) : 0
        state.recordBatteryReading(v.status || "", Number(v.counter) || 0, v.unit || "ah", Number(v.volt) || 0)
      }
    }
  }

  // Fast while the control center shows the draw; a slow background sample
  // the rest of the time keeps the energy trend ready for when it opens.
  property Timer batteryPoll: Timer {
    interval: state.active ? 3000 : 30000
    repeat: true
    running: state.hasBattery
    triggeredOnStart: true
    onTriggered: if (!state.batteryProbe.running) state.batteryProbe.running = true
  }

  // ---- Power mode --------------------------------------------------------------

  property var profiles: []
  property string profile: ""

  property Process profilesProbe: Process {
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        var current = ""
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].trim().split("\t")
          if (!parts[0]) continue
          list.push(parts[0])
          if (parts[1] === "1") current = parts[0]
        }
        if (list.length === 0) return
        state.profiles = list
        state.profile = current
      }
    }
  }

  property Process profileSet: Process { onExited: state.refreshProfiles() }

  function refreshProfiles() {
    if (!profilesProbe.running) profilesProbe.running = true
  }

  function setProfile(name) {
    if (!name || name === profile || profileSet.running) return
    profile = name
    profileSet.command = ["omarchy-powerprofiles-set", UPower.onBattery ? "battery" : "ac", name]
    profileSet.running = true
  }

  // ---- Now playing -------------------------------------------------------------

  readonly property var player: {
    var values = Mpris.players.values
    for (var i = 0; i < values.length; i++) if (values[i].playbackState === MprisPlaybackState.Playing) return values[i]
    return values.length > 0 ? values[0] : null
  }
  readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing

  // ---- system: CPU, memory, temperature, storage ------------------------------

  property real cpu: 0
  property real memory: 0
  property real memoryUsedGb: 0
  property real memoryTotalGb: 0
  property real temperature: 0
  property real storage: 0
  property real storageUsedGb: 0
  property real storageTotalGb: 0
  property var cpuPrev: null

  property Process statsProbe: Process {
    command: ["bash", "-c",
      "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo;"
      + " t=0; for z in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp1_input; do [ -r \"$z\" ] && v=$(cat \"$z\" 2>/dev/null) && [ \"${v:-0}\" -gt \"$t\" ] && t=$v; done; echo \"temp $t\";"
      + " df -B1 --output=used,size / | tail -1"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].trim().split(/\s+/)
          if (f[0] === "cpu") {
            var vals = f.slice(1).map(Number)
            var idle = vals[3] + (vals[4] || 0)
            var total = vals.reduce(function(a, b) { return a + b }, 0)
            if (state.cpuPrev) {
              var dt = total - state.cpuPrev.total
              var di = idle - state.cpuPrev.idle
              if (dt > 0) state.cpu = Math.max(0, Math.min(1, 1 - di / dt))
            }
            state.cpuPrev = { total: total, idle: idle }
          } else if (f[0] === "MemTotal:") {
            state.memoryTotalGb = Number(f[1]) / 1048576
          } else if (f[0] === "MemAvailable:") {
            var avail = Number(f[1]) / 1048576
            state.memoryUsedGb = Math.max(0, state.memoryTotalGb - avail)
            if (state.memoryTotalGb > 0) state.memory = state.memoryUsedGb / state.memoryTotalGb
          } else if (f[0] === "temp") {
            state.temperature = Number(f[1]) / 1000
          } else if (f.length === 2 && /^\d+$/.test(f[0]) && /^\d+$/.test(f[1])) {
            state.storageUsedGb = Number(f[0]) / 1e9
            state.storageTotalGb = Number(f[1]) / 1e9
            state.storage = state.storageTotalGb > 0 ? state.storageUsedGb / state.storageTotalGb : 0
          }
        }
      }
    }
  }

  property Timer statsPoll: Timer {
    interval: 2000
    repeat: true
    running: state.active
    triggeredOnStart: true
    onTriggered: if (!state.statsProbe.running) state.statsProbe.running = true
  }

  // ---- clocks and weather --------------------------------------------------------

  // [{ name, zone }] from the world clock's settings; times filled in below.
  property var cities: []
  property var cityTimes: ({})

  property Process clockProbe: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        var next = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t")
          if (tab > 0) next[lines[i].substring(0, tab)] = lines[i].substring(tab + 1)
        }
        state.cityTimes = next
      }
    }
  }

  function refreshClocks() {
    if (clockProbe.running || cities.length === 0) return
    var zones = cities.map(function(c) { return Util.shellQuote(c.zone) }).join(" ")
    clockProbe.command = ["bash", "-c", "for z in " + zones + "; do printf '%s\\t%s\\n' \"$z\" \"$(TZ=$z date '+%H:%M|%a')\"; done"]
    clockProbe.running = true
  }

  property Timer clockPoll: Timer {
    interval: 30000
    repeat: true
    running: false  // clocks panel removed from the control center
    triggeredOnStart: true
    onTriggered: state.refreshClocks()
  }

  property string weatherPlace: ""
  property string weatherTemp: ""
  property string weatherSky: ""
  property string weatherFeels: ""
  property string weatherWind: ""
  property string weatherHumidity: ""
  property double weatherAt: 0

  property Process weatherProbe: Process {
    command: ["bash", "-c",
      "loc=$(omarchy-weather-location 2>/dev/null | head -1); q=$(printf %s \"$loc\" | sed 's/ /+/g');"
      + " printf 'place\\t%s\\n' \"$loc\";"
      + " curl -fsS --max-time 8 \"https://wttr.in/${q}?format=%t|%C|%f|%w|%h\" 2>/dev/null | sed 's/^/now\\t/'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t")
          if (tab < 0) continue
          var key = lines[i].substring(0, tab)
          var value = lines[i].substring(tab + 1).trim()
          if (key === "place") state.weatherPlace = value
          if (key === "now" && value.indexOf("|") > 0) {
            var f = value.split("|")
            state.weatherTemp = String(f[0] || "").replace("+", "")
            state.weatherSky = String(f[1] || "")
            state.weatherFeels = String(f[2] || "").replace("+", "")
            state.weatherWind = String(f[3] || "")
            state.weatherHumidity = String(f[4] || "")
            state.weatherAt = Date.now()
          }
        }
      }
    }
  }

  function refreshWeather() {
    // wttr.in asks for restraint: at most every fifteen minutes.
    if (weatherProbe.running || (weatherAt > 0 && Date.now() - weatherAt < 15 * 60000)) return
    weatherProbe.running = true
  }

  // ---- displays: monitors, scale, text size ----------------------------------

  property var monitors: []
  property real scale: 1
  property int textSize: 12

  // Follows Hyprland's focus live; the probe's own focused flag is only as
  // fresh as the last read.
  readonly property var focusedMonitor: {
    var name = brightnessMonitor
    return monitors.filter(function(m) { return name !== "" ? m.name === name : m.focused })[0] || null
  }
  onFocusedMonitorChanged: if (focusedMonitor) scale = focusedMonitor.scale

  // A screen plugged in or out changes the list itself.
  property Connections monitorEvents: Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^monitor(added|removed)/.test(event.name)) state.displaySettle.restart()
    }
  }

  property Process displayProbe: Process {
    command: ["bash", "-c", "hyprctl monitors all -j; echo; echo \"text $(omarchy-display-text-size 2>/dev/null | sed -n 's/^text size: \\([0-9]*\\).*/\\1/p')\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var at = text.lastIndexOf("\ntext ")
        var json = at >= 0 ? text.substring(0, at) : text
        try {
          var list = JSON.parse(json)
          state.monitors = list.map(function(m) {
            var builtIn = /^(eDP|LVDS|DSI)-/.test(m.name)
            return { name: m.name, description: String(m.description || ""), width: m.width, height: m.height,
              label: builtIn ? "Built-in" : String(m.model || m.name),
              refresh: Math.round(m.refreshRate || 0), scale: m.scale, enabled: !m.disabled, focused: !!m.focused }
          })
          for (var i = 0; i < list.length; i++) if (list[i].focused) state.scale = list[i].scale
        } catch (e) {}
        if (at >= 0) {
          var px = parseInt(text.substring(at + 6), 10)
          if (px > 0) state.textSize = px
        }
      }
    }
  }

  function refreshDisplays() {
    if (!displayProbe.running) displayProbe.running = true
  }

  property Timer displaySettle: Timer { interval: 1200; onTriggered: state.refreshDisplays() }

  function setScale(value) {
    state.scale = value
    Util.execDetached("omarchy-hyprland-monitor-scaling " + value)
    displaySettle.restart()
  }

  readonly property var textSizes: [9, 10, 11, 12, 14, 16, 20]

  function stepTextSize(step) {
    var i = textSizes.indexOf(textSize)
    if (i < 0) { i = 0; while (i < textSizes.length - 1 && textSizes[i] < textSize) i++ }
    i = Math.max(0, Math.min(textSizes.length - 1, i + step))
    textSize = textSizes[i]
    Util.execDetached("omarchy-display-text-size " + textSize)
  }

  // Never switches off the last screen that is on.
  function setMonitorEnabled(monitor, on) {
    if (!on && monitors.filter(function(m) { return m.enabled }).length <= 1) return
    var output = "\"" + String(monitor.name).replace(/[\\"]/g, "") + "\""
    var expr = on
      ? "hl.monitor({ output = " + output + ", disabled = false, mode = \"preferred\", position = \"auto\", scale = \"auto\" })"
      : "hl.monitor({ output = " + output + ", disabled = true })"
    Util.execDetached("hyprctl eval " + Util.shellQuote(expr))
    displaySettle.restart()
  }

  // ---- night light warmth ------------------------------------------------------

  property int warmth: 4000

  function setWarmth(kelvin) {
    warmth = Math.round(kelvin / 100) * 100
    warmthApply.restart()
  }

  property Timer warmthApply: Timer {
    interval: 120
    onTriggered: Util.execDetached("hyprctl hyprsunset temperature " + state.warmth)
  }

  // ---- hotspot (the evcode.hotspot plugin's helper does the work) ------------

  readonly property string hotspotHelper: Quickshell.env("HOME") + "/.config/omarchy/plugins/evcode.hotspot/bin/omarchy-hotspot"
  property bool hotspotOn: false
  property bool hotspotBusy: false
  property string hotspotSsid: ""
  property string hotspotUpstream: ""
  property int hotspotClients: 0
  property string hotspotSecurity: ""
  // The QR code's modules, one string of 0s and 1s per row.
  property var hotspotQr: []

  property Process hotspotProbe: Process {
    command: [state.hotspotHelper, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var st = JSON.parse(text)
          state.hotspotOn = st.active === true
          state.hotspotSsid = String(st.ssid || "")
          state.hotspotSecurity = String(st.security || "")
          state.hotspotClients = Number(st.clients_count) || 0
          state.hotspotUpstream = st.upstream && st.upstream.name ? String(st.upstream.name) : ""
          state.hotspotQr = st.qr && Array.isArray(st.qr.rows) ? st.qr.rows : []
        } catch (e) {}
      }
    }
  }

  property Process hotspotAction: Process {
    onExited: { state.hotspotBusy = false; state.refreshHotspot() }
  }

  function refreshHotspot() {
    if (!hotspotProbe.running) hotspotProbe.running = true
  }

  function toggleHotspot() {
    if (hotspotAction.running) return
    hotspotBusy = true
    hotspotOn = !hotspotOn
    hotspotAction.command = [hotspotHelper, "toggle"]
    hotspotAction.running = true
  }

  // ---- refresh everything a panel is about to show -------------------------

  function refreshAll() {
    refreshWifi()
    refreshBrightness()
    refreshProfiles()
    refreshDisplays()
    refreshHotspot()
  }
}
