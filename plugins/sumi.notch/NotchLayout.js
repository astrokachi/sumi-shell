.pragma library

// Edits to the notch's widget layout, kept free of QML so they read as
// plain data in, data out. A layout is bar.layout; widgets switched off are
// kept in bar.notch.off with the section they came from and their settings,
// so switching one back on puts it back as it was.

var TITLES = {
  left: "Menu bar · left",
  centerBegin: "Notch · left of the clock",
  center: "Notch · beside the clock",
  centerEnd: "Notch · right of the clock",
  tray: "Notch · far right",
  right: "Menu bar · right"
}

// In the order they run along the bar, left to right.
var ORDER = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
var ALWAYS = ["left", "centerBegin", "centerEnd", "right"]
var DEFAULT_SECTION = "centerEnd"

// Drawn by the bar itself, or meaningless in it.
var HIDDEN = ["omarchy.workspaces", "omarchy.clock", "omarchy.menu", "omarchy.spacer", "omarchy.active-window"]

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

// The sections worth showing: the usual three, plus any other that holds
// something.
function sections(layout) {
  return ORDER.filter(function(key) {
    return ALWAYS.indexOf(key) >= 0 || (layout[key] || []).length > 0
  })
}

function locate(layout, id) {
  for (var i = 0; i < ORDER.length; i++) {
    var list = layout[ORDER[i]] || []
    for (var j = 0; j < list.length; j++) if (list[j].id === id) return { section: ORDER[i], index: j }
  }
  return null
}

function offEntries(notch) {
  return notch && Array.isArray(notch.off) ? notch.off.filter(function(item) {
    return item && item.entry && item.entry.id
  }) : []
}

// Everything that could be switched on: what was switched off, then every
// other widget the shell knows that is not on the bar.
function offIds(layout, notch, registryIds) {
  var ids = []
  offEntries(notch).forEach(function(item) {
    if (!locate(layout, item.entry.id) && ids.indexOf(item.entry.id) < 0) ids.push(item.entry.id)
  })
  var rest = registryIds.filter(function(id) {
    return HIDDEN.indexOf(id) < 0 && ids.indexOf(id) < 0 && !locate(layout, id)
  })
  rest.sort()
  return ids.concat(rest)
}

// -> { layout, notch }
function toggle(layout, notch, id) {
  var nextLayout = clone(layout)
  var nextNotch = clone(notch || {})
  var off = offEntries(nextNotch)
  var at = locate(nextLayout, id)
  if (at) {
    var entry = nextLayout[at.section].splice(at.index, 1)[0]
    off = off.filter(function(item) { return item.entry.id !== id })
    off.push({ section: at.section, index: at.index, entry: entry })
  } else {
    var kept = null
    off = off.filter(function(item) {
      if (item.entry.id !== id) return true
      kept = item
      return false
    })
    var section = kept && TITLES[kept.section] ? kept.section : DEFAULT_SECTION
    if (!nextLayout[section]) nextLayout[section] = []
    var list = nextLayout[section]
    var index = kept && kept.index >= 0 ? Math.min(kept.index, list.length) : list.length
    list.splice(index, 0, kept ? kept.entry : { id: id })
  }
  nextNotch.off = off
  return { layout: nextLayout, notch: nextNotch }
}

// One step left (-1) or right (+1) along the bar; past the end of a
// section it crosses into the next.
function move(layout, id, direction) {
  var next = clone(layout)
  var at = locate(next, id)
  if (!at) return next
  var order = sections(next)
  var list = next[at.section]
  var s = order.indexOf(at.section)
  if (direction < 0) {
    if (at.index > 0) {
      list.splice(at.index - 1, 0, list.splice(at.index, 1)[0])
    } else if (s > 0) {
      var up = order[s - 1]
      if (!next[up]) next[up] = []
      next[up].push(list.splice(at.index, 1)[0])
    }
  } else {
    if (at.index < list.length - 1) {
      list.splice(at.index + 1, 0, list.splice(at.index, 1)[0])
    } else if (s < order.length - 1) {
      var down = order[s + 1]
      if (!next[down]) next[down] = []
      next[down].unshift(list.splice(at.index, 1)[0])
    }
  }
  return next
}

function canMove(layout, id, direction) {
  var at = locate(layout, id)
  if (!at) return false
  var order = sections(layout)
  var s = order.indexOf(at.section)
  if (direction < 0) return at.index > 0 || s > 0
  return at.index < (layout[at.section] || []).length - 1 || s < order.length - 1
}

function displayName(metadata, id) {
  var name = metadata && metadata.displayName ? String(metadata.displayName) : String(id).split(".").pop()
  name = name.replace(/^Shibumi\s+/i, "").replace(/[-_]+/g, " ")
  return name.charAt(0).toUpperCase() + name.slice(1)
}

// Put a widget at a spot in a section, from wherever it is now: another spot
// on the bar, or switched off (keeping the settings it had). `index` counts
// the section's widgets without this one. -> { layout, notch }
function place(layout, notch, id, section, index) {
  var nextLayout = clone(layout)
  var nextNotch = clone(notch || {})
  var entry = null
  var at = locate(nextLayout, id)
  if (at) {
    entry = nextLayout[at.section].splice(at.index, 1)[0]
  } else {
    nextNotch.off = offEntries(nextNotch).filter(function(item) {
      if (item.entry.id !== id) return true
      entry = item.entry
      return false
    })
    if (!entry) entry = { id: id }
  }
  if (!nextLayout[section]) nextLayout[section] = []
  var list = nextLayout[section]
  list.splice(Math.max(0, Math.min(index, list.length)), 0, entry)
  return { layout: nextLayout, notch: nextNotch }
}
