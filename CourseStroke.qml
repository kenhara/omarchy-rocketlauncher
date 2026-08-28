import QtQuick
import QtQuick.Shapes
import qs.Commons

// Static planned course. No bead — not a live locate. path is iss-rendezvous | leo.
Item {
  id: root

  property string path: "leo"   // iss-rendezvous | leo
  property string caption: ""
  property color foreground: Color.foreground
  property string fontFamily: "monospace"

  implicitWidth: Style.space(320)
  implicitHeight: 88
  height: implicitHeight
  clip: true

  readonly property real ringH: 64
  readonly property real cx: width / 2
  readonly property real cy: ringH / 2
  readonly property real rx: Math.min(36, width * 0.22)
  // ISS plane is ~51.6°; static course uses that published lean, not a live TLE.
  readonly property real tiltDeg: path === "iss-rendezvous" ? 51.6 : 0
  readonly property real ry: path === "iss-rendezvous" ? rx * 0.42 : rx * 0.78

  Item {
    id: ringBox
    width: parent.width
    height: root.ringH

    Rectangle {
      width: 10
      height: 10
      radius: 5
      x: root.cx - 5
      y: root.cy - 5
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.32)
    }

    Shape {
      anchors.fill: parent
      transform: Rotation {
        origin.x: root.cx
        origin.y: root.cy
        angle: root.tiltDeg
      }
      ShapePath {
        strokeWidth: 1.25
        strokeColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.38)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: root.cx + root.rx
        startY: root.cy
        PathAngleArc {
          centerX: root.cx
          centerY: root.cy
          radiusX: root.rx
          radiusY: root.ry
          startAngle: 0
          sweepAngle: 360
        }
      }
    }
  }

  Text {
    anchors.top: ringBox.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    horizontalAlignment: Text.AlignHCenter
    text: root.caption
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    opacity: 0.5
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    font.capitalization: Font.AllUppercase
  }
}
