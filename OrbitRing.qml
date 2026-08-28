import QtQuick
import QtQuick.Shapes
import qs.Commons

// Live docked-ISS ring. Only mounted when LocateFix.kind === "iss-docked".
// Local Shape/Path — no Image.source, no SVG, no remote. Bead is mean anomaly, not a costume.
Item {
  id: root

  property real inclinationDeg: 0
  property real meanAnomalyDeg: 0
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
  readonly property real ry: rx * 0.42
  readonly property real tiltRad: inclinationDeg * Math.PI / 180
  readonly property real maRad: meanAnomalyDeg * Math.PI / 180
  readonly property real beadX: {
    var lx = rx * Math.cos(maRad)
    var ly = ry * Math.sin(maRad)
    return cx + lx * Math.cos(tiltRad) - ly * Math.sin(tiltRad)
  }
  readonly property real beadY: {
    var lx = rx * Math.cos(maRad)
    var ly = ry * Math.sin(maRad)
    return cy + lx * Math.sin(tiltRad) + ly * Math.cos(tiltRad)
  }

  Item {
    id: ringBox
    width: parent.width
    height: root.ringH

    Rectangle {
      width: 12
      height: 12
      radius: 6
      x: root.cx - 6
      y: root.cy - 6
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
    }

    Shape {
      anchors.fill: parent
      transform: Rotation {
        origin.x: root.cx
        origin.y: root.cy
        angle: root.inclinationDeg
      }
      ShapePath {
        strokeWidth: 1.5
        strokeColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
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

    Rectangle {
      width: 7
      height: 7
      radius: 3.5
      x: root.beadX - width / 2
      y: root.beadY - height / 2
      color: root.foreground
      opacity: 0.88
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
