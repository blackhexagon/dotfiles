import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "DayModel.js" as Day

// Bar face of the calendar pomodoro. The engine lives in Service.qml; this
// widget is one per monitor and only renders it.
//
//   during a block      tomato + time left, accent  (title in the tooltip)
//   between blocks      tomato + next start
//   after the last one  tomato only, dimmed
//   sync error          warning mark
//
// Left click opens today's list of pomodoros.
BarWidget {
  id: root
  moduleName: "u2b22.pomodoro"

  readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("u2b22.pomodoro") : null
  readonly property string calendarSetting: String(setting("calendar", "Work") || "Work")

  readonly property string status: svc ? svc.status : "loading"
  readonly property real now: svc ? svc.now : Date.now()
  readonly property var current: svc ? svc.current : null
  readonly property var upcoming: svc ? svc.upcoming : null
  readonly property var events: svc ? svc.events : []

  readonly property color accent: Color.accent
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string tomato: "🍅"
  readonly property string warningMark: "󰀦"

  readonly property string barText: {
    if (status === "error") return warningMark
    if (current) return tomato + "  " + Day.countdown(current.endMs - now)
    if (status === "ok" && upcoming) return tomato + "  " + Day.clockTime(upcoming.startMs)
    return tomato
  }

  readonly property string tooltip: {
    if (!svc || status === "loading") return "Pomodoro · syncing " + calendarSetting + "…"
    if (status === "error") return svc.errorMessage
    if (current) return current.title
    if (upcoming) return "Next at " + Day.clockTime(upcoming.startMs) + " · " + upcoming.title
    return "No more pomodoros today"
  }

  property bool popupOpen: false

  // Shape contract the shell expects from a bar widget with a panel.
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }
  onPopupOpenChanged: if (popupOpen && svc) svc.requestSync()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? (root.current ? root.tomato : root.barText.split("  ")[0]) : root.barText
    foreground: root.current ? root.accent : (root.bar ? root.bar.barForeground : Color.foreground)
    dimmed: root.status === "loading" || (root.status === "ok" && !root.current && !root.upcoming)
    useActiveColor: false
    tooltipText: root.tooltip
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Item {
        width: parent.width
        height: headerLabel.implicitHeight

        Text {
          id: headerLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: (root.svc ? root.svc.calendarName : root.calendarSetting).toUpperCase() + " · TODAY"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 2
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.svc && root.svc.syncing ? "syncing…"
            : root.svc && root.svc.fetchedAt > 0 && root.status === "ok"
              ? "synced " + Day.clockTime(root.svc.fetchedAt) : ""
          color: Util.alpha(root.fg, 0.45)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      PanelSeparator { width: parent.width; foreground: root.fg }

      // ---- error / setup
      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.status === "error"

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: root.svc && root.svc.connecting
            ? "Waiting for Google sign-in in your browser…"
            : root.warningMark + "  " + (root.svc ? root.svc.errorMessage : "")
          color: root.svc && root.svc.connecting ? root.fg : Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          visible: !!root.svc && root.svc.errorKind === "config"
          text: "Fix ~/.config/omarchy/u2b22-pomodoro/oauth.json, or delete it to use the shared Google client, then retry."
          color: Util.alpha(root.fg, 0.6)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Row {
          spacing: Style.space(6)

          Button {
            visible: !!root.svc && root.svc.errorKind === "connect"
            iconText: "󰌆"
            text: "Connect Google"
            foreground: root.fg
            accent: root.accent
            bordered: true
            enabled: !!root.svc && !root.svc.connecting
            opacity: enabled ? 1 : 0.4
            onClicked: root.svc.connectGoogle()
          }
          Button {
            iconText: "󰑐"
            text: "Retry"
            foreground: root.fg
            accent: root.accent
            bordered: true
            enabled: !!root.svc && !root.svc.syncing && !root.svc.connecting
            opacity: enabled ? 1 : 0.4
            onClicked: root.svc.requestSync()
          }
        }
      }

      Text {
        width: parent.width
        visible: root.status === "loading"
        text: "Syncing…"
        color: Util.alpha(root.fg, 0.6)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }

      Text {
        width: parent.width
        visible: root.status === "ok" && root.events.length === 0
        text: "No pomodoros today"
        color: Util.alpha(root.fg, 0.6)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }

      // ---- today's pomodoros
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.status === "ok"

        Repeater {
          model: root.events

          Item {
            required property var modelData
            readonly property string phase: Day.rowState(modelData, root.now, root.current)
            readonly property bool isCurrent: phase === "current"
            width: parent.width
            height: Math.max(timeLabel.implicitHeight, titleLabel.implicitHeight)
            opacity: phase === "done" ? 0.45 : 1

            Text {
              id: timeLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: Day.clockTime(modelData.startMs) + "–" + Day.clockTime(modelData.endMs)
              color: parent.isCurrent ? root.accent : root.fg
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: parent.isCurrent
            }

            Text {
              id: titleLabel
              anchors.left: timeLabel.right
              anchors.leftMargin: Style.space(10)
              anchors.right: leftLabel.left
              anchors.rightMargin: leftLabel.visible ? Style.space(8) : 0
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: modelData.title
              color: parent.isCurrent ? root.accent : root.fg
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: parent.isCurrent
            }

            Text {
              id: leftLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: parent.isCurrent
              width: visible ? implicitWidth : 0
              text: Day.countdown(modelData.endMs - root.now)
              color: root.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }
        }
      }
    }
  }
}
