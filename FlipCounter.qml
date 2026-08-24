import QtQuick
import qs.Commons

// Mechanical digit-flip counter for the Rocketlauncher stats strip.
// Theme-aware by default; optional accentColor for secondary chrome.
// Digits bind directly to displayText so Quattro always paints numbers
// (no setDigit / Style.font.display object pitfalls).
Item {
  id: root

  property int value: 0
  property string label: ""
  property color foreground: Color.foreground
  property color accentColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
  property string fontFamily: "monospace"
  property int digitCount: 3
  property bool animate: true

  readonly property string displayText: {
    var n = Math.max(0, Math.floor(Number(value) || 0))
    var s = String(n)
    while (s.length < digitCount)
      s = "0" + s
    return s
  }

  readonly property int digitPx: 28
  readonly property int labelPx: 10
  readonly property int cellW: 22
  readonly property int cellH: 34

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
        model: root.digitCount

        Rectangle {
          required property int index
          width: root.cellW
          height: root.cellH
          radius: 4
          color: root.accentColor

          Text {
            anchors.centerIn: parent
            text: root.displayText.charAt(index) || "0"
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
