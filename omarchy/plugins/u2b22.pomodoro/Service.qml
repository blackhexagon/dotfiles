import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "DayModel.js" as Day

// Calendar-driven pomodoro engine. One instance per shell; the bar widget
// (one per monitor) only reads this state.
//
// The pomodoros are today's timed events on one Google calendar. The bundled
// pomodoro_sync.py fetches them; nothing is cached, so a failed sync is an
// error state rather than a stale day. When a block ends and the next one
// starts exactly 5 or 15 minutes later, a full-screen break screen (ported
// from techywilbur.pomodoro) covers every monitor until the next block.
//
// IPC: omarchy-shell u2b22-pomodoro <status|sync|previewBreak|hideBreak>
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir).replace(/^file:\/\//, "").replace(/\/$/, "") : ""
  readonly property string helperPath: sourceDir ? sourceDir + "/pomodoro_sync.py" : ""

  // The calendar is a setting on the widget's bar entry in shell.json.
  readonly property var barEntry: Day.findEntry(shell ? shell.barConfig : null, "u2b22.pomodoro")
  readonly property string calendarName: barEntry && barEntry.calendar ? String(barEntry.calendar) : "Work"
  // Typing this phrase is the only way to leave a break early.
  readonly property string skipPhrase: barEntry && barEntry.skipPhrase
    ? String(barEntry.skipPhrase) : "jsemtakovejcurakzepotrebujupokracovatvpraci"

  // ---- sync state
  property string status: "loading"   // loading | ok | error
  property string errorKind: ""       // config | connect | calendar | network | secret
  property string errorMessage: ""
  property var events: []
  property real dayEnd: 0
  property real fetchedAt: 0
  property bool syncQueued: false
  property bool syncExited: false
  property bool syncRead: false
  property string syncOutput: ""
  readonly property bool syncing: syncProcess.running
  readonly property bool connecting: connectProcess.running

  // ---- day state, recomputed every tick
  property real now: Date.now()
  readonly property var current: Day.current(events, now)
  readonly property var upcoming: Day.next(events, now)
  readonly property var gap: Day.breakGap(events, now)
  readonly property string currentId: current ? current.id : ""
  property string lastCurrentId: ""

  // ---- break screen
  property string dismissedGapKey: ""
  // A one-minute stand-in break for checking how descriptions look.
  property var previewGap: null
  readonly property var shownGap: previewGap && now < previewGap.endMs ? previewGap : gap
  readonly property bool overlayVisible: shownGap !== null && shownGap.key !== dismissedGapKey
  readonly property real gapProgress: shownGap
    ? Math.min(1, Math.max(0, (now - shownGap.startMs) / (shownGap.endMs - shownGap.startMs))) : 0

  function previewBreak() {
    var t = Date.now()
    var finished = Day.lastEnded(events, t) || (events.length ? events[0] : null)
    var following = upcoming || (events.length ? events[events.length - 1] : null)
    previewGap = {
      key: "preview@" + t,
      kind: "short",
      startMs: t,
      endMs: t + 60000,
      previous: finished || { title: "Previous block", description: "" },
      next: following || { title: "Next block", startMs: t + 60000 }
    }
  }

  // ---- skip phrase. Case and spaces are ignored.
  property string typedPhrase: ""
  readonly property bool typedOnTrack: Day.phraseKey(skipPhrase).indexOf(Day.phraseKey(typedPhrase)) === 0

  function typeKey(event) {
    if (event.key === Qt.Key_Escape) typedPhrase = ""
    else if (event.key === Qt.Key_Backspace) typedPhrase = typedPhrase.slice(0, -1)
    else if (event.text && event.text.length === 1 && event.text >= " " && typedPhrase.length < 200) {
      typedPhrase += event.text
      if (Day.phraseKey(typedPhrase) === Day.phraseKey(skipPhrase)) skipBreak()
    }
  }

  function skipBreak() {
    if (shownGap) dismissedGapKey = shownGap.key
    previewGap = null
    typedPhrase = ""
  }

  // Only a preview can be hidden without the phrase; a real break cannot.
  function hideBreak() {
    if (previewGap) skipBreak()
  }

  onOverlayVisibleChanged: typedPhrase = ""

  function requestSync() {
    if (!helperPath) return
    if (syncProcess.running || (syncExited !== syncRead)) { syncQueued = true; return }
    syncExited = false
    syncRead = false
    syncOutput = ""
    syncProcess.command = ["/usr/bin/python3", helperPath, "sync", "--calendar", calendarName]
    syncProcess.running = true
  }

  // A run is finished only when the process has exited and its stdout has
  // been read; the two signals can arrive in either order.
  function finishSync() {
    if (!syncExited || !syncRead) return
    applySync(parseResult(syncOutput), syncStderr.text)
    if (syncQueued) {
      syncQueued = false
      Qt.callLater(requestSync)
    }
  }

  function connectGoogle() {
    if (!helperPath || connectProcess.running) return
    connectProcess.running = true
  }

  function parseResult(raw) {
    try {
      var value = JSON.parse(String(raw || ""))
      return value && typeof value === "object" ? value : null
    } catch (e) {
      return null
    }
  }

  function cleanMessage(value, fallback) {
    var text = String(value || "").replace(/\s+/g, " ").trim()
    if (!text) text = fallback
    return text.length > 240 ? text.substring(0, 237) + "…" : text
  }

  function fail(kind, message) {
    // Status first, so clearing the events below is not read as a block ending.
    status = "error"
    errorKind = kind || "network"
    errorMessage = cleanMessage(message, "Calendar sync failed")
    events = []
    dayEnd = 0
  }

  function applySync(parsed, stderrText) {
    if (!parsed) {
      fail("network", stderrText)
      return
    }
    if (parsed.ok !== true) {
      fail(parsed.kind, parsed.error)
      return
    }
    status = "ok"
    errorKind = ""
    errorMessage = ""
    events = Day.parseEvents(parsed.events)
    dayEnd = Number(parsed.dayEnd) || 0
    fetchedAt = Number(parsed.fetchedAt) || Date.now()
  }

  function statusJson() {
    return JSON.stringify({
      status: status, errorKind: errorKind, error: errorMessage,
      calendar: calendarName, fetchedAt: fetchedAt, events: events.length,
      current: current ? { title: current.title, left: Day.countdown(current.endMs - now) } : null,
      next: upcoming ? { title: upcoming.title, at: Day.clockTime(upcoming.startMs) } : null,
      breakScreen: overlayVisible
    })
  }

  onCalendarNameChanged: requestSync()

  // A block ending is the moment to refresh: the next decision (break screen
  // or not) should use the freshest calendar.
  onCurrentIdChanged: {
    var ended = lastCurrentId !== "" && status === "ok"
    lastCurrentId = currentId
    if (ended) requestSync()
  }

  Process {
    id: syncProcess
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.syncOutput = text
        root.syncRead = true
        root.finishSync()
      }
    }
    stderr: StdioCollector { id: syncStderr; waitForEnd: true }
    onExited: {
      root.syncExited = true
      root.finishSync()
    }
  }

  Process {
    id: connectProcess
    running: false
    command: ["/usr/bin/python3", root.helperPath, "connect"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseResult(text)
        if (parsed && parsed.ok === true) root.requestSync()
        else root.fail(parsed ? parsed.kind : "connect", parsed ? parsed.error : connectStderr.text)
      }
    }
    stderr: StdioCollector { id: connectStderr; waitForEnd: true }
  }

  // The shell hands over its bar config just after creating the service; let
  // that settle so the first sync uses the configured calendar.
  Timer {
    interval: 1000
    running: true
    onTriggered: root.requestSync()
  }

  Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.requestSync()
  }

  // One tick a second drives the countdown. A jump of more than a minute
  // means suspend; crossing midnight means a new day. Both resync.
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      var t = Date.now()
      var jumped = t - root.now > 60000
      root.now = t
      if (jumped || (root.dayEnd > 0 && t >= root.dayEnd)) root.requestSync()
    }
  }

  IpcHandler {
    target: "u2b22-pomodoro"
    function status(): string { return root.statusJson() }
    function sync(): string { root.requestSync(); return "ok" }
    function previewBreak(): string { root.previewBreak(); return "ok" }
    function hideBreak(): string { root.hideBreak(); return "ok" }
  }

  // ------------------------------------------------------------------ break screen

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: root.overlayVisible
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "u2b22-pomodoro"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      exclusionMode: ExclusionMode.Ignore

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.93)
      }

      BreakScreen {
        anchors.fill: parent
        controller: root
        // Keep the handler on the controls' ancestor so typing still reaches
        // the skip phrase after clicking an exercise's scrollbar.
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          root.typeKey(event)
          event.accepted = true
        }
        opacity: win.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
      }
    }
  }
}
