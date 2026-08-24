import QtQuick
import qs.Commons

// Mechanical digit-flip counter for the Rocketlauncher stats strip.
// Theme-aware by default; optional accentColor for secondary chrome.
// Digits rebuilt into digitChars so Repeater/modelData always paints
// (avoids charAt binding stalls that left wells stuck at 0000).
Item {
  id: root

  property int value: 0
  property string label: ""
  property color foreground: Color.foreground
  property color accentColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
  property string fontFamily: "monospace"
  property int digitCount: 3
  property bool animate: true

  property var digitChars: []

  readonly property int digitPx: 28
  readonly property int labelPx: 10
  readonly property int cellW: 22
  readonly property int cellH: 34

  function rebuildDigits() {
    var n = Math.max(0, Math.floor(Number(root.value) || 0))
    var s = String(n)
    while (s.length < root.digitCount)
      s = "0" + s
    if (s.length > root.digitCount)
      s = s.substring(s.length - root.digitCount)
    var chars = []
    for (var i = 0; i < s.length; i++)
      chars.push(s.charAt(i))
    root.digitChars = chars
  }

  onValueChanged: root.rebuildDigits()
  onDigitCountChanged: root.rebuildDigits()
  Component.onCompleted: root.rebuildDigits()

  implicitWidth: Math.max(column.implicitWidth, 72)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    spacing: 6

    Text {
      text: root.label
      color: root.foreground
      opacity: 0.5
      font.family: root.fontFamily
      font.pixelSize: root.labelPx
      font.letterSpacing: 1.5
      font.capitalization: Font.AllUppercase
    }

    Row {
      spacing: 3

      Repeater {
        model: root.digitChars

        Rectangle {
          width: root.cellW
          height: root.cellH
          radius: 4
          color: root.accentColor

          Text {
            anchors.centerIn: parent
            text: modelData
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.digitPx
            font.bold: true
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: root.foreground
            opacity: 0.12
          }
        }
      }
    }
  }
}
