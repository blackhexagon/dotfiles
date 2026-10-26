import QtQuick
import QtQuick.Window
import Quickshell
import "Plugin" as Plugin
import "Plugin/DayModel.js" as Day

// Render the real visual component, without Google, the service or a desktop.
Window {
  id: test
  visible: true
  width: cases[caseIndex].w
  height: cases[caseIndex].h

  readonly property string exercise: "Pomalu protáhni záda a pravidelně dýchej. ".repeat(18)
  readonly property string description: "GoodDay #123\n\nPauza – cviky:\n"
    + ["1. První cvik: " + exercise, "2. Druhý cvik: " + exercise, "3. Třetí cvik: " + exercise].join("\n")
  readonly property var cases: [
    { w: 1572, h: 1440, text: "", count: 0 },
    { w: 1572, h: 1440, text: description, count: 3, snapshot: "original-size" },
    { w: 3440, h: 1440, text: description, count: 3, snapshot: "ultrawide" },
    { w: 1920, h: 1080, text: description, count: 3 },
    { w: 1366, h: 768, text: description, count: 3 },
    { w: 1280, h: 720, text: description, count: 3, snapshot: "720p" },
    { w: 1024, h: 600, text: description, count: 3 },
    { w: 800, h: 600, text: description, count: 3 },
    { w: 600, h: 800, text: description, count: 3 },
    { w: 640, h: 360, text: description, count: 3, snapshot: "small" },
    { w: 800, h: 450, text: description, count: 3 },
    { w: 320, h: 240, text: description, count: 3 },
    { w: 1280, h: 720, text: exercise.repeat(60), count: 1 },
    { w: 1280, h: 720, text: exercise.repeat(20) + "\n" + description, count: 3 },
    { w: 1280, h: 720, text: Array.from({length: 40}, function(_, i) { return (i + 1) + ". " + exercise }).join("\n"), count: 40 },
    { w: 640, h: 360, text: description, count: 3, longLabels: true },
    { w: 320, h: 240, text: description, count: 3, longLabels: true }
  ]
  property int caseIndex: 0
  property var failures: []

  QtObject {
    id: fixture
    property real now: 0
    property real gapProgress: 0.5
    property string skipPhrase: test.cases[test.caseIndex].longLabels ? "verylongphrase".repeat(15) : "jsemtakovejcurakzepotrebujupokracovatvpraci"
    property string typedPhrase: test.cases[test.caseIndex].longLabels ? "x".repeat(200) : ""
    property bool typedOnTrack: !test.cases[test.caseIndex].longLabels
    property var events: Array.from({length: 30}, function() { return { endMs: -1 } })
    property var shownGap: ({ kind: "short", endMs: 300000,
      previous: { description: test.cases[test.caseIndex].text },
      next: { title: test.cases[test.caseIndex].longLabels ? "Dlouhý název dalšího pomodora ".repeat(20) : "🍅 7/11 Další pomodoro" } })
  }

  Plugin.BreakScreen {
    id: screen
    anchors.fill: parent
    controller: fixture
  }

  function find(item, name) {
    if (item.objectName === name) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = find(item.children[i], name)
      if (found) return found
    }
    return null
  }

  function rect(item) {
    var point = item.mapToItem(screen, 0, 0)
    return { x: point.x, y: point.y, w: item.width, h: item.height }
  }

  function check() {
    var label = width + "x" + height + " case " + caseIndex
    for (var name of ["breakDial", "phraseInput", "breakFooter", "breakInstructions"]) {
      var item = find(screen, name)
      if (!item || !item.visible) {
        failures.push(label + ": " + name + " missing or hidden")
        continue
      }
      var r = rect(item)
      if (r.x < -0.5 || r.y < -0.5 || r.x + r.w > width + 0.5 || r.y + r.h > height + 0.5 || r.w <= 0 || r.h < 0)
        failures.push(label + ": " + name + " outside screen: " + JSON.stringify(r))
    }
    var dial = rect(find(screen, "breakDial"))
    var instructions = rect(find(screen, "breakInstructions"))
    var footer = rect(find(screen, "breakFooter"))
    if (dial.y + dial.h > instructions.y + 0.5 || instructions.y + instructions.h > footer.y + 0.5)
      failures.push(label + ": instructions overlap the dial or footer")

    var list = find(screen, "exerciseColumns")
    if (list.count !== cases[caseIndex].count)
      failures.push(label + ": expected " + cases[caseIndex].count + " exercise columns, got " + list.count)
    if (list.count > list.visibleColumns && list.contentWidth <= list.width)
      failures.push(label + ": extra exercise columns are not reachable by scrolling")

    // The long-description case must leave both controls exactly where they
    // were with an empty description at the same resolution.
    if (caseIndex === 0) baseline = { dial: dial, input: rect(find(screen, "phraseInput")) }
    if (caseIndex === 1 && JSON.stringify(baseline) !== JSON.stringify({ dial: dial, input: rect(find(screen, "phraseInput")) }))
      failures.push(label + ": description length moved the dial or input")
  }

  property var baseline: null

  function nextCase() {
    if (caseIndex + 1 < cases.length) {
      caseIndex += 1
      settle.restart()
    } else {
      console.log("LAYOUT_RESULT " + JSON.stringify({ cases: cases.length, failures: failures }))
      Qt.quit()
    }
  }

  Timer {
    id: settle
    interval: 120
    running: true
    onTriggered: {
      test.check()
      var directory = Quickshell.env("POMO_LAYOUT_SNAPSHOT_DIR")
      var name = test.cases[test.caseIndex].snapshot
      if (directory && name) {
        screen.grabToImage(function(result) {
          if (!result.saveToFile(directory + "/" + name + ".png")) test.failures.push("Could not save " + name)
          test.nextCase()
        })
      } else test.nextCase()
    }
  }
}
