.pragma library

// Pure logic for the calendar-driven pomodoro. Events are
// { id, title, description, startMs, endMs } in epoch milliseconds, sorted by
// start.

var BREAK_MINUTES = [5, 15]

// This plugin's entry in the bar layout, from the shell's bar config snapshot.
function findEntry(barConfig, id) {
  var layout = barConfig && barConfig.layout
  if (!layout) return null
  for (var section in layout) {
    var list = layout[section]
    if (!Array.isArray(list)) continue
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) return list[i]
    }
  }
  return null
}

// Comparison form of the skip phrase: case and whitespace do not matter.
function phraseKey(text) {
  return String(text || "").toLowerCase().replace(/\s+/g, "")
}

// Numbered exercises take precedence over bullets so nested bullet points
// remain part of their exercise. Prose without a list stays in one column.
function descriptionSections(description) {
  var text = String(description || "").replace(/\r\n?/g, "\n").trim()
  if (!text) return { intro: "", exercises: [] }
  var numbered = /^\s*\d+[.)]\s+/m.test(text)
  var marker = numbered ? /^\s*\d+[.)]\s+/ : /^\s*[•*\-]\s+/
  var lines = text.split("\n")
  var intro = []
  var exercises = []
  var current = null
  for (var i = 0; i < lines.length; i++) {
    if (marker.test(lines[i])) {
      if (current) exercises.push(current.join("\n").trim())
      current = [lines[i].trim()]
    } else if (current) {
      current.push(lines[i])
    } else {
      intro.push(lines[i])
    }
  }
  if (!current) return { intro: "", exercises: [text] }
  exercises.push(current.join("\n").trim())
  return { intro: intro.join("\n").trim(), exercises: exercises }
}

function pad(n) {
  return (n < 10 ? "0" : "") + n
}

// "24:12" under an hour, "1:05:03" from an hour up.
function countdown(ms) {
  var total = Math.max(0, Math.ceil(ms / 1000))
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  var s = total % 60
  return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s)
}

function clockTime(ms) {
  var d = new Date(ms)
  return pad(d.getHours()) + ":" + pad(d.getMinutes())
}

function parseEvents(list) {
  if (!Array.isArray(list)) return []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (!e) continue
    var start = Number(e.startMs)
    var end = Number(e.endMs)
    if (!isFinite(start) || !isFinite(end) || end <= start) continue
    out.push({
      id: String(e.id || i),
      title: String(e.title || "(untitled)"),
      description: String(e.description || ""),
      startMs: start,
      endMs: end
    })
  }
  out.sort(function(a, b) { return a.startMs - b.startMs || a.endMs - b.endMs })
  return out
}

// The block in progress. When blocks overlap, the latest start wins.
function current(events, now) {
  var found = null
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    if (e.startMs <= now && now < e.endMs && (!found || e.startMs >= found.startMs)) found = e
  }
  return found
}

function next(events, now) {
  for (var i = 0; i < events.length; i++) {
    if (events[i].startMs > now) return events[i]
  }
  return null
}

function lastEnded(events, now) {
  var found = null
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    if (e.endMs <= now && (!found || e.endMs > found.endMs)) found = e
  }
  return found
}

// The break between a finished block and the next one, when it is exactly
// 5 or 15 minutes long. Null otherwise, including before the first block.
function breakGap(events, now) {
  if (current(events, now)) return null
  var before = lastEnded(events, now)
  var after = next(events, now)
  if (!before || !after) return null
  var minutes = Math.round((after.startMs - before.endMs) / 60000)
  if (BREAK_MINUTES.indexOf(minutes) === -1) return null
  return {
    key: before.id + ">" + after.id + "@" + after.startMs,
    kind: minutes === 15 ? "long" : "short",
    startMs: before.endMs,
    endMs: after.startMs,
    previous: before,
    next: after
  }
}

function rowState(event, now, currentEvent) {
  if (currentEvent && event.id === currentEvent.id) return "current"
  if (event.endMs <= now) return "done"
  if (event.startMs <= now) return "running"
  return "later"
}
