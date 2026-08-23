import QtQuick
import qs.Commons

// Mechanical digit-flip counter for the Space Jockey stats strip.
// Theme-aware by default; optional accentColor for secondary chrome.
Item {
  id: root

  property int value: 0
  property string label: ""
  property color foreground: Color.foreground
  // Digit well: foreground alpha (theme-native); Panel may override.
  property color accentColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
  property string fontFamily: Style.font.family
  property int digitCount: 3
  property bool animate: true

  readonly property string displayText: padValue(value, digitCount)

  implicitWidth: Math.max(column.implicitWidth, StyleSafe.space(72))
  implicitHeight: column.implicitHeight

  // Graceful Style fallback when qs.Commons tokens differ / unavailable.
  QtObject {
    id: StyleSafe
    function space(n) {
      try { if (typeof Style !== "undefined" && Style.space) return Style.space(n) } catch (e) {}
      return n
    }
    function fontSize(kind) {
      try {
        if (typeof Style !== "undefined" && Style.font) {
          if (kind === "caption" && Style.font.caption) return Style.font.caption
          if (kind === "title" && Style.font.title) return Style.font.title
          if (kind === "display" && Style.font.display) return Style.font.display
          if (Style.font.body) return Style.font.body
        }
      } catch (e) {}
      return kind === "title" || kind === "display" ? 28 : (kind === "caption" ? 10 : 14)
    }
    function cornerRadius() {
      try {
        if (typeof Style !== "undefined" && Style.cornerRadius !== undefined)
          return Style.cornerRadius
      } catch (e) {}
      return 6
    }
  }

  function padValue(v, width) {
    var n = Math.max(0, Math.floor(Number(v) || 0))
    var s = String(n)
    while (s.length < width) s = "0" + s
    return s
  }

  onValueChanged: {
    if (!animate) {
      digitRow.instantSet(displayText)
      return
    }
    digitRow.flipTo(displayText)
  }

  Column {
    id: column
    spacing: StyleSafe.space(6)

    Text {
      text: root.label
      color: root.foreground
      opacity: 0.5
      font.family: root.fontFamily
      font.pixelSize: StyleSafe.fontSize("caption")
      font.letterSpacing: 1.5
      font.capitalization: Font.AllUppercase
    }

    Row {
      id: digitRow
      spacing: StyleSafe.space(3)

      property string current: root.displayText

      function instantSet(text) {
        current = text
        for (var i = 0; i < repeater.count; i++) {
          var item = repeater.itemAt(i)
          if (item) item.setDigit(text.charAt(i), false)
        }
      }

      function flipTo(text) {
        current = text
        for (var i = 0; i < repeater.count; i++) {
          var item = repeater.itemAt(i)
          if (item) item.setDigit(text.charAt(i), true)
        }
      }

      Repeater {
        id: repeater
        model: root.digitCount

        Rectangle {
          id: digitCell
          required property int index
          width: StyleSafe.space(22)
          height: StyleSafe.space(34)
          radius: Math.max(2, StyleSafe.cornerRadius() - 4)
          color: root.accentColor
          clip: true

          property string digit: "0"

          function setDigit(ch, doAnim) {
            var next = ch || "0"
            if (next === digit) return
            if (!doAnim) {
              digit = next
              flipY = 0
              return
            }
            outgoingText.text = digit
            digit = next
            flipAnim.restart()
          }

          property real flipY: 0

          Text {
            id: outgoingText
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6 + digitCell.flipY
            opacity: Math.max(0, 1 - Math.abs(digitCell.flipY) / 20)
            text: digitCell.digit
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: StyleSafe.fontSize("display")
            font.bold: true
            visible: false
          }

          Text {
            id: incomingText
            anchors.centerIn: parent
            text: digitCell.digit
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: StyleSafe.fontSize("display")
            font.bold: true
            opacity: 1 - Math.min(1, Math.abs(digitCell.flipY) / 28)
            scale: 1 - Math.min(0.15, Math.abs(digitCell.flipY) / 120)
          }

          // Scanline accent across the digit cell
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: root.foreground
            opacity: 0.12
          }

          SequentialAnimation {
            id: flipAnim
            NumberAnimation {
              target: digitCell
              property: "flipY"
              from: -16
              to: 0
              duration: 220
              easing.type: Easing.OutCubic
            }
          }

          Component.onCompleted: digit = root.displayText.charAt(index) || "0"
        }
      }
    }
  }

  Component.onCompleted: digitRow.instantSet(displayText)
}
