import QtQuick
import QtQuick.Shapes
import qs.Commons

// Next-launch-only trajectory stroke. Local QML Shape/Path — no Image.source,
// no remote SVG, no fake telemetry. Bead snaps to LL2 phase only.
Item {
  id: root

  property string kind: "leo"       // leo | gto | landing
  property string phase: "net"      // net | webcast | t0 | success | failure
  property color foreground: Color.foreground

  implicitWidth: Style.space(320)
  implicitHeight: 36
  height: implicitHeight
  clip: true

  readonly property real pad: 10
  readonly property real x0: pad
  readonly property real y0: height - 10
  readonly property real x3: Math.max(pad + 8, width - pad)
  readonly property real y3: {
    if (kind === "landing") return height - 10
    if (kind === "gto") return height * 0.52
    return height * 0.34
  }
  readonly property real x1: {
    if (kind === "gto") return width * 0.28
    if (kind === "landing") return width * 0.30
    return width * 0.26
  }
  readonly property real y1: {
    if (kind === "gto") return 3
    if (kind === "landing") return 4
    return height * 0.14
  }
  readonly property real x2: {
    if (kind === "gto") return width * 0.68
    if (kind === "landing") return width * 0.62
    return width * 0.64
  }
  readonly property real y2: {
    if (kind === "gto") return height * 0.08
    if (kind === "landing") return 6
    return height * 0.12
  }
  readonly property real beadT: {
    if (phase === "success") return 0.96
    if (phase === "failure") return 0.50
    if (phase === "t0") return 0.62
    if (phase === "webcast") return 0.34
    return 0.10
  }

  function bez(t, a, b, c, d) {
    var u = 1 - t
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
  }

  readonly property real beadX: bez(beadT, x0, x1, x2, x3)
  readonly property real beadY: bez(beadT, y0, y1, y2, y3)

  Shape {
    anchors.fill: parent
    ShapePath {
      strokeWidth: 1.5
      strokeColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: root.x0
      startY: root.y0
      PathCubic {
        x: root.x3
        y: root.y3
        control1X: root.x1
        control1Y: root.y1
        control2X: root.x2
        control2Y: root.y2
      }
    }
  }

  Rectangle {
    width: 4
    height: 4
    radius: 2
    x: root.x0 - 2
    y: root.y0 - 2
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
  }

  Rectangle {
    width: 4
    height: 4
    radius: 2
    x: root.x3 - 2
    y: root.y3 - 2
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
  }

  Rectangle {
    width: root.phase === "failure" ? 8 : 7
    height: width
    radius: root.phase === "failure" ? 2 : width / 2
    x: root.beadX - width / 2
    y: root.beadY - height / 2
    color: root.foreground
    opacity: 0.88
  }
}
