.pragma library

// The Sumi icon set: single strokes on a 24 px grid, drawn by SumiIcon.qml.
// The same paths as the design canvas, so the shell and the mockups match.
var paths = {
  search: "M17.5 11a6.5 6.5 0 1 1-13 0a6.5 6.5 0 1 1 13 0Z M20 20l-4.2-4.2",
  wifi: "M2.5 9a14 14 0 0 1 19 0 M5.5 12.5a9.5 9.5 0 0 1 13 0 M8.6 16a5 5 0 0 1 6.8 0 M12 19.5h.01",
  battery: "M3 8.5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z M21.5 10.5v3 M6.5 10v4 M9.5 10v4 M12.5 10v4",
  batteryCase: "M3 8.5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z M21.5 10.5v3",
  bolt: "M13 3 6 13.5h5L10 21l7-10.5h-5Z",
  bluetooth: "M7 7l10 10-5 4.5V2.5L17 7 7 17",
  volume: "M4 9.5h3.5L12 5.5v13l-4.5-4H4Z M15.5 9a4.5 4.5 0 0 1 0 6 M18.5 6.5a8 8 0 0 1 0 11",
  sun: "M15.5 12a3.5 3.5 0 1 1-7 0a3.5 3.5 0 1 1 7 0Z M12 3v1.5 M12 19.5V21 M3 12h1.5 M19.5 12H21 M5.6 5.6l1.1 1.1 M17.3 17.3l1.1 1.1 M5.6 18.4l1.1-1.1 M17.3 6.7l1.1-1.1",
  moon: "M19.5 14.5A7.5 7.5 0 1 1 9.5 4.5a6 6 0 0 0 10 10Z",
  bell: "M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 1.5h-15Z M10 20.5a2 2 0 0 0 4 0",
  silent: "M6 16.5V11a6 6 0 0 1 9.4-4.9 M18 10.5v6l1.5 1.5h-12 M10 20.5a2 2 0 0 0 4 0 M4 4l16 16",
  coffee: "M5 9.5h11v5a4.5 4.5 0 0 1-4.5 4.5h-2A4.5 4.5 0 0 1 5 14.5Z M16 11h1.5a2.5 2.5 0 0 1 0 5H16 M8.5 3.5v3 M12 3.5v3",
  lock: "M5.5 11a1.5 1.5 0 0 1 1.5-1.5h10a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19Z M8.5 9.5V7a3.5 3.5 0 0 1 7 0v2.5",
  power: "M12 3v8 M7 5.8a8 8 0 1 0 10 0",
  grid: "M4.5 4.5h5v5h-5Z M14.5 4.5h5v5h-5Z M4.5 14.5h5v5h-5Z M14.5 14.5h5v5h-5Z",
  sliders: "M4 7h9 M17 7h3 M4 17h3 M11 17h9 M17 7a2 2 0 1 1-4 0a2 2 0 1 1 4 0Z M11 17a2 2 0 1 1-4 0a2 2 0 1 1 4 0Z",
  terminal: "M3.5 6.5A1.5 1.5 0 0 1 5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5Z M7.5 10l2.5 2-2.5 2 M12.5 14.5H16",
  folder: "M3.5 7A1.5 1.5 0 0 1 5 5.5h4l2 2h8A1.5 1.5 0 0 1 20.5 9v8.5A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5Z",
  globe: "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0Z M3.5 12h17 M12 3.5c2.4 2.6 3.5 5.4 3.5 8.5s-1.1 5.9-3.5 8.5c-2.4-2.6-3.5-5.4-3.5-8.5s1.1-5.9 3.5-8.5Z",
  code: "M8.5 8l-4 4 4 4 M15.5 8l4 4-4 4 M13.5 5.5l-3 13",
  music: "M9 18V6l10-2v12 M9 18a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0Z M19 16a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0Z",
  chart: "M4 19.5h16 M7 16v-4 M11 16V8 M15 16v-6 M19 16V5",
  calc: "M6 3.5h12A1.5 1.5 0 0 1 19.5 5v14a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 19V5A1.5 1.5 0 0 1 6 3.5Z M8 7.5h8v3H8Z M8.5 14h.01 M12 14h.01 M15.5 14h.01 M8.5 17.5h.01 M12 17.5h.01 M15.5 17.5h.01",
  note: "M6 4.5h12v15H6Z M9 9h6 M9 12.5h6 M9 16h3.5",
  play: "M8 5.5v13l10.5-6.5Z",
  pause: "M8.5 5.5v13 M15.5 5.5v13",
  next: "M6 6l9 6-9 6Z M18 6v12",
  prev: "M18 6l-9 6 9 6Z M6 6v12",
  cpu: "M7 7h10v10H7Z M9.5 4v3 M14.5 4v3 M9.5 17v3 M14.5 17v3 M4 9.5h3 M4 14.5h3 M17 9.5h3 M17 14.5h3",
  gauge: "M4.5 16a7.5 7.5 0 1 1 15 0 M12 16l3.5-4.5",
  palette: "M12 3.5a8.5 8.5 0 0 0 0 17c1.2 0 1.8-.8 1.5-1.8-.4-1.2.4-2.2 1.6-2.2H17a3.5 3.5 0 0 0 3.5-3.5c0-5.2-3.8-9.5-8.5-9.5Z M8 11h.01 M10.5 7.5h.01 M15 7.5h.01",
  image: "M3.5 6.5A1.5 1.5 0 0 1 5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5Z M4 16l4.5-4.5 4 4 2.5-2.5 4.5 4.5 M15.5 9h.01",
  camera: "M4 8.5A1.5 1.5 0 0 1 5.5 7h2.3l1.4-2h5.6l1.4 2h2.3A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5Z M15.25 12.75a3.25 3.25 0 1 1-6.5 0a3.25 3.25 0 1 1 6.5 0Z",
  calendar: "M4.5 7A1.5 1.5 0 0 1 6 5.5h12A1.5 1.5 0 0 1 19.5 7v11.5A1.5 1.5 0 0 1 18 20H6a1.5 1.5 0 0 1-1.5-1.5Z M4.5 10h15 M8.5 3.5v3 M15.5 3.5v3",
  book: "M4.5 5.5h5a2.5 2.5 0 0 1 2.5 2.5v11a2 2 0 0 0-2-2H4.5Z M19.5 5.5h-5A2.5 2.5 0 0 0 12 8v11a2 2 0 0 1 2-2h5.5Z",
  download: "M12 4v11 M7.5 10.5L12 15l4.5-4.5 M5 19.5h14",
  trash: "M4.5 7h15 M9.5 7V4.5h5V7 M6.5 7l1 12.5h9l1-12.5",
  info: "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0Z M12 11v5.5 M12 7.75h.01",
  sparkle: "M12 4l1.6 4.4L18 10l-4.4 1.6L12 16l-1.6-4.4L6 10l4.4-1.6Z M18.5 16.5l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6Z",
  chevron: "M10 6l6 6-6 6",
  back: "M14 6l-6 6 6 6",
  enter: "M19 5.5v5a2 2 0 0 1-2 2H6 M9.5 9l-3.5 3.5 3.5 3.5",
  plus: "M12 5v14 M5 12h14",
  minus: "M5 12h14",
  check: "M5 12.5l4.5 4.5L19 7.5",
  close: "M6 6l12 12 M18 6L6 18",
  monitor: "M3.5 5.5A1.5 1.5 0 0 1 5 4h14a1.5 1.5 0 0 1 1.5 1.5v10A1.5 1.5 0 0 1 19 17H5a1.5 1.5 0 0 1-1.5-1.5Z M9 20.5h6 M12 17v3.5",
  refresh: "M19.5 12a7.5 7.5 0 1 1-2.2-5.3 M19.5 4.5v4h-4",
  restart: "M4.5 12a7.5 7.5 0 1 0 2.2-5.3 M4.5 4.5v4h4",
  dock: "M3.5 6.5A1.5 1.5 0 0 1 5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5Z M7 15.5h10",
  extension: "M9.5 4.5h5v3a1.5 1.5 0 0 0 3 0v-.5h2v5h-.5a1.5 1.5 0 0 0 0 3h.5v5h-15v-15Z",
  widgets: "M4.5 4.5h6v6h-6Z M13.5 4.5h6v6h-6Z M4.5 13.5h6v6h-6Z M16.5 13.5v6 M13.5 16.5h6",
  drag: "M9 6h.01 M15 6h.01 M9 12h.01 M15 12h.01 M9 18h.01 M15 18h.01",
  hidden: "M3.5 12s3-6 8.5-6c1.6 0 3 .5 4.2 1.2 M20.5 12s-1 2-3 3.7 M9.9 14.1a3 3 0 0 0 4.2-4.2 M4 4l16 16",
  eco: "M5.5 18.5c0-8 5-12.5 13-13-0.5 8-5 13-13 13Z M5.5 18.5l6.5-6.5",
  balance: "M12 4v16 M7 20h10 M5 7.5h14 M5 7.5l-2.5 6a2.5 2.5 0 0 0 5 0Z M19 7.5l-2.5 6a2.5 2.5 0 0 0 5 0Z",
  speed: "M4.5 16a7.5 7.5 0 1 1 15 0 M12 16l4-5 M8 16h.01",
  user: "M15.5 8a3.5 3.5 0 1 1-7 0a3.5 3.5 0 1 1 7 0Z M5.5 20a6.5 6.5 0 0 1 13 0",
  keyboard: "M3.5 7.5A1.5 1.5 0 0 1 5 6h14a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 19 18H5a1.5 1.5 0 0 1-1.5-1.5Z M7 10h.01 M10.3 10h.01 M13.7 10h.01 M17 10h.01 M7 13h.01 M17 13h.01 M9.5 14.5h5",
  type: "M5 7V5.5h14V7 M12 5.5v13 M9.5 18.5h5",
  mic: "M9 6a3 3 0 0 1 6 0v5a3 3 0 0 1-6 0Z M6 11a6 6 0 0 0 12 0 M12 17v3.5",
  share: "M12 15V4 M8 7.5L12 3.5l4 4 M6.5 11H5.5v9h13v-9h-1",
  logout: "M14.5 4.5h3A1.5 1.5 0 0 1 19 6v12a1.5 1.5 0 0 1-1.5 1.5h-3 M10 8l-4 4 4 4 M6 12h9",
  record: "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0Z M15 12a3 3 0 1 1-6 0a3 3 0 1 1 6 0Z",
  window: "M3.5 6.5A1.5 1.5 0 0 1 5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5Z M3.5 9h17",
  shield: "M12 3.5l7 2.5v5.5c0 4.4-3 7.8-7 9-4-1.2-7-4.6-7-9V6Z",
  mute: "M4 9.5h3.5L12 5.5v13l-4.5-4H4Z M16 9.5l5 5 M21 9.5l-5 5",
  hotspot: "M13 12a1 1 0 1 1-2 0a1 1 0 1 1 2 0Z M8.5 15.5a5 5 0 0 1 0-7 M15.5 8.5a5 5 0 0 1 0 7 M5.6 18.4a9 9 0 0 1 0-12.8 M18.4 5.6a9 9 0 0 1 0 12.8",
  clipboard: "M9 4.5h6v3H9Z M9 5.5H7A1.5 1.5 0 0 0 5.5 7v12A1.5 1.5 0 0 0 7 20.5h10a1.5 1.5 0 0 0 1.5-1.5V7A1.5 1.5 0 0 0 17 5.5h-2 M9 12h6 M9 15.5h4",
  thermo: "M10 14.5V5.5a2 2 0 0 1 4 0v9a3.5 3.5 0 1 1-4 0Z M12 9.5v6",
  disk: "M4 7.5c0-1.4 3.6-2.5 8-2.5s8 1.1 8 2.5v9c0 1.4-3.6 2.5-8 2.5s-8-1.1-8-2.5Z M4 7.5c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5 M4 12c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5",
  cloud: "M7 18.5a4 4 0 0 1-.6-8 5.5 5.5 0 0 1 10.6-1.3A4.5 4.5 0 0 1 17 18.5Z",
  micOff: "M9 6a3 3 0 0 1 5.8-1.1 M15 9.5V11a3 3 0 0 1-4.7 2.5 M6 11a6 6 0 0 0 9.6 4.8 M18 11a6 6 0 0 1-.4 2.2 M12 17v3.5 M4 4l16 16"
}

// The glyph for an on-screen display, by Omarchy's icon key; "" keeps its own.
function osdGlyph(key, percent) {
  var n = String(key || "").toLowerCase()
  if (/^(volume-)?mute(d)?$/.test(n)) return "mute"
  if (n.indexOf("volume") === 0) return "volume"
  if (/^(microphone|mic)-(muted|off)$/.test(n)) return "micOff"
  if (n === "microphone" || n === "mic") return "mic"
  if (n === "keyboard" || n === "touchpad") return "keyboard"
  if (n === "brightness" || n === "display") return "sun"
  if (n === "touch" || n === "touchscreen") return "monitor"
  if (n === "reboot" || n === "restart") return "restart"
  if (n === "shutdown" || n === "power" || n === "poweroff") return "power"
  if (n === "logout" || n === "sign-out" || n === "leave") return "logout"
  if (/(media|player)-play$/.test(n)) return "play"
  if (/(media|player)-pause$/.test(n)) return "pause"
  if (/(media|player)-next$/.test(n)) return "next"
  if (/(media|player)-previous$/.test(n)) return "prev"
  if (/^(media|player)/.test(n)) return "music"
  if (n === "") return percent <= 0 ? "mute" : "volume"
  return ""
}

// The glyph for an app, by what it is; "" when the set has none.
function appGlyph(id) {
  var key = String(id || "").toLowerCase()
  var table = [
    [/nautilus|thunar|dolphin|files|nemo/, "folder"],
    [/chrom|firefox|brave|zen|browser|vivaldi|edge/, "globe"],
    [/foot|alacritty|ghostty|kitty|wezterm|terminal|konsole/, "terminal"],
    [/vscode|code|zed|cursor|neovim|nvim|sublime|antigravity|helix/, "code"],
    [/spotify|youtubemusic|music|rhythmbox|tidal/, "music"],
    [/tradingview|trading|stocks/, "chart"],
    [/calc/, "calc"],
    [/write|notes|obsidian|typora|text-?editor|gedit/, "note"],
    [/youtube|mpv|vlc|celluloid|video/, "play"],
    [/settings|control-?center/, "sliders"],
    [/calendar/, "calendar"],
    [/screenshot|camera|snap/, "camera"],
    [/book|reader|zathura|evince|pdf/, "book"],
    [/1password|keepass|bitwarden|password/, "lock"],
    [/btop|htop|monitor|system/, "cpu"],
    [/docker/, "extension"]
  ]
  for (var i = 0; i < table.length; i++) if (table[i][0].test(key)) return table[i][1]
  return ""
}

// The glyph for an Omarchy menu entry, by its id; "" keeps the entry's own.
function menuGlyph(id) {
  var key = String(id || "")
  var exact = {
    apps: "grid", learn: "book", trigger: "sparkle", style: "palette", setup: "sliders",
    install: "download", remove: "trash", update: "refresh", about: "info", system: "power",
    "system.screensaver": "monitor", "system.lock": "lock", "system.suspend": "moon",
    "system.hibernate": "moon", "system.logout": "logout", "system.reboot": "restart",
    "system.shutdown": "power",
    "trigger.appearance": "palette", "trigger.toggle": "sliders", "trigger.emoji": "sparkle",
    "trigger.clipboard-history": "note", "trigger.reminder": "bell", "trigger.capture": "camera",
    "trigger.transcode": "refresh", "trigger.share": "share", "trigger.hardware": "monitor",
    "trigger.tests": "gauge",
    "style.theme": "palette", "style.background": "image", "style.unlock": "lock",
    "style.font": "type", "style.hyprland": "window", "style.screensaver": "monitor", "style.about": "info",
    "setup.monitors": "monitor", "setup.keybindings": "keyboard", "setup.input": "keyboard",
    "setup.typing": "keyboard", "setup.language": "globe", "setup.network": "wifi",
    "setup.default": "check", "setup.plugin": "extension", "setup.security": "shield",
    "setup.config": "code", "setup.direct-boot": "power", "setup.reset": "restart"
  }
  if (exact[key]) return exact[key]
  var rules = [
    [/screenrecord/, "record"], [/screenshot|capture/, "camera"], [/\.qr$|qr/, "grid"],
    [/nightlight/, "moon"], [/notifications/, "bell"], [/idle/, "coffee"], [/screensaver/, "monitor"],
    [/dock/, "dock"], [/top-bar|indicators/, "sliders"], [/window/, "window"], [/workspace/, "grid"],
    [/animations/, "sparkle"], [/theme/, "palette"], [/background|image/, "image"], [/font/, "type"],
    [/browser/, "globe"], [/terminal/, "terminal"], [/editor/, "code"], [/agent|\.ai$/, "sparkle"],
    [/dictation|microphone/, "mic"], [/network|dns|wifi/, "wifi"], [/bluetooth/, "bluetooth"],
    [/fingerprint|fido|ssh|sudo|security/, "shield"], [/touchpad|keyboard|input|typing/, "keyboard"],
    [/display|monitor/, "monitor"], [/reminder/, "bell"], [/share/, "share"], [/speedtest/, "gauge"],
    [/package|install/, "download"], [/remove|uninstall/, "trash"], [/update/, "refresh"],
    [/development/, "code"], [/learn|docs/, "book"], [/plugin/, "extension"], [/audio|sound/, "volume"]
  ]
  for (var i = 0; i < rules.length; i++) if (rules[i][0].test(key)) return rules[i][1]
  return ""
}
