import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons as Commons
import "DayModel.js" as Day

// A bounded viewport, not a content-sized column. Only the exercise area
// scrolls: neither a long description nor long typed text can move the dial
// or the skip input off-screen. Kept separate from the service for UI tests.
Item {
  id: view
  required property var controller

  readonly property real uiScale: Math.min(1, width / 960, height / 800)
  readonly property int inset: Math.round(24 * uiScale)
  readonly property int gutter: Math.max(4, Math.round(14 * uiScale))
  readonly property int bodySize: Math.max(12, Math.round(22 * uiScale))
  readonly property int smallSize: Math.max(10, Math.round(14 * uiScale))
  readonly property int inputSize: Math.max(11, Math.round(16 * uiScale))
  readonly property int ringSize: Math.round(Math.min(width * 0.65, height * 0.28, 420))
  readonly property int ringStroke: Math.max(3, Math.round(ringSize * 0.02))
  readonly property var description: Day.descriptionSections(controller.shownGap && controller.shownGap.previous
    ? controller.shownGap.previous.description : "")
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: Commons.Style.font.family

  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: view.inset
    spacing: view.gutter

    Text {
      Layout.fillWidth: true
      visible: view.height >= 320
      horizontalAlignment: Text.AlignHCenter
      text: view.controller.shownGap && view.controller.shownGap.kind === "long" ? "LONG BREAK" : "SHORT BREAK"
      color: view.accent
      font.family: view.fontFamily
      font.pixelSize: Math.max(12, Math.round(28 * view.uiScale))
      font.letterSpacing: Math.round(6 * view.uiScale)
      font.bold: true
    }

    Item {
      objectName: "breakDial"
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: view.ringSize
      Layout.preferredHeight: view.ringSize
      Layout.minimumHeight: view.ringSize
      Layout.maximumHeight: view.ringSize

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeColor: Commons.Util.alpha(view.fg, 0.12)
          strokeWidth: view.ringStroke
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: view.ringSize / 2; centerY: view.ringSize / 2
            radiusX: view.ringSize / 2 - view.ringStroke; radiusY: radiusX
            startAngle: -90; sweepAngle: 360
          }
        }

        ShapePath {
          strokeColor: view.accent
          strokeWidth: view.ringStroke
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: view.ringSize / 2; centerY: view.ringSize / 2
            radiusX: view.ringSize / 2 - view.ringStroke; radiusY: radiusX
            startAngle: -90
            sweepAngle: Math.max(0.01, 360 * (1 - view.controller.gapProgress))
            Behavior on sweepAngle { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: view.controller.shownGap ? Day.countdown(view.controller.shownGap.endMs - view.controller.now) : ""
        color: view.fg
        font.family: view.fontFamily
        font.pixelSize: Math.round(view.ringSize * 0.24)
        font.bold: true
      }
    }

    // All variable-length instructions live in this remaining space. Each
    // numbered item (or bullet) becomes its own horizontally arranged card.
    Item {
      id: instructions
      objectName: "breakInstructions"
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      clip: true

      ScrollView {
        id: introScroll
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? Math.min(intro.implicitHeight, instructions.height * 0.22) : 0
        visible: view.description.intro !== ""
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Text {
          id: intro
          width: introScroll.availableWidth
          text: view.description.intro
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          color: Commons.Util.alpha(view.fg, 0.65)
          font.family: view.fontFamily
          font.pixelSize: view.smallSize
        }
      }

      ListView {
        id: exercises
        objectName: "exerciseColumns"
        anchors.top: introScroll.bottom
        anchors.topMargin: introScroll.visible ? view.gutter : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        orientation: ListView.Horizontal
        spacing: view.gutter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: view.description.exercises
        readonly property int visibleColumns: Math.max(1, Math.min(count,
          Math.floor(width / Math.max(240, 420 * view.uiScale))))
        readonly property real columnWidth: Math.max(1, (width - (visibleColumns - 1) * spacing) / visibleColumns)
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Rectangle {
          required property string modelData
          objectName: "exerciseCard"
          width: exercises.columnWidth
          height: Math.max(0, exercises.height - (exercises.contentWidth > exercises.width ? view.gutter : 0))
          radius: Math.round(8 * view.uiScale)
          color: Commons.Util.alpha(view.fg, 0.04)
          border.width: 1
          border.color: Commons.Util.alpha(view.fg, 0.12)

          ScrollView {
            id: exerciseScroll
            anchors.fill: parent
            anchors.margins: view.gutter
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Text {
              width: exerciseScroll.availableWidth
              text: modelData
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              color: Commons.Util.alpha(view.fg, 0.9)
              font.family: view.fontFamily
              font.pixelSize: view.bodySize
              lineHeight: 1.15
            }
          }
        }
      }
    }

    ColumnLayout {
      objectName: "breakFooter"
      Layout.fillWidth: true
      spacing: Math.max(2, Math.round(7 * view.uiScale))

      Row {
        Layout.alignment: Qt.AlignHCenter
        visible: view.controller.events.length > 0
        readonly property real dotSize: Math.min(12 * view.uiScale,
          (view.width - 2 * view.inset) / (view.controller.events.length * 1.6))
        spacing: dotSize * 0.6
        Repeater {
          model: view.controller.events
          Rectangle {
            required property var modelData
            width: parent.dotSize
            height: width
            radius: width / 2
            color: modelData.endMs <= view.controller.now ? view.accent : Commons.Util.alpha(view.fg, 0.14)
          }
        }
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: view.controller.shownGap ? "NEXT AT " + Day.clockTime(view.controller.shownGap.endMs) : ""
        color: Commons.Util.alpha(view.fg, 0.55)
        font.family: view.fontFamily
        font.pixelSize: view.smallSize
        font.letterSpacing: Math.round(3 * view.uiScale)
        font.bold: true
      }

      Text {
        objectName: "nextPomodoroTitle"
        Layout.fillWidth: true
        Layout.maximumHeight: font.pixelSize * 2.5
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: view.controller.shownGap ? view.controller.shownGap.next.title : ""
        color: view.fg
        font.family: view.fontFamily
        font.pixelSize: Math.max(14, Math.round(38 * view.uiScale))
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "To skip the break, type:"
        color: Commons.Util.alpha(view.fg, 0.4)
        font.family: view.fontFamily
        font.pixelSize: view.smallSize
      }

      Text {
        Layout.fillWidth: true
        Layout.preferredHeight: font.pixelSize * 2.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        text: view.controller.skipPhrase
        wrapMode: Text.WrapAnywhere
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        color: Commons.Util.alpha(view.fg, 0.55)
        font.family: view.fontFamily
        font.pixelSize: view.inputSize
      }

      Rectangle {
        objectName: "phraseInput"
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: 820
        Layout.preferredHeight: Math.max(28, view.inputSize * 2 + view.gutter)
        Layout.minimumHeight: Layout.preferredHeight
        radius: Math.round(4 * view.uiScale)
        color: "transparent"
        border.width: 1
        border.color: view.controller.typedPhrase === "" ? Commons.Util.alpha(view.fg, 0.2)
          : view.controller.typedOnTrack ? view.accent : Commons.Color.urgent

        Text {
          anchors.fill: parent
          anchors.margins: Math.max(4, view.gutter / 2)
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideLeft
          textFormat: Text.PlainText
          text: view.controller.typedPhrase !== "" ? view.controller.typedPhrase : " "
          color: view.controller.typedOnTrack ? view.accent : Commons.Color.urgent
          font.family: view.fontFamily
          font.pixelSize: view.inputSize
        }
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Backspace deletes · Esc clears"
        color: Commons.Util.alpha(view.fg, 0.3)
        font.family: view.fontFamily
        font.pixelSize: view.smallSize
      }
    }
  }
}
