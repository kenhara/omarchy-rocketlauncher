import QtQuick
import qs.Commons

// Compact mission / upcoming / ongoing row used by Rocketlauncher Panel.
// Theme-native: Color / Style tokens lead; badge hues tint accent/urgent.
Item {
  id: root

  property string title: ""
  property string subtitle: ""
  property string meta: ""
  property string badgeText: ""
  property string badgeKind: "muted"   // go | tbd | live | ok | muted
  property color foreground: Color.foreground
  property color surfaceColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
  property string fontFamily: "monospace"
  property bool showWatch: false
  property bool showDetail: false
  property bool detailOpen: false
  property bool compact: false
  // Only true when parent wires an action (detail expand, etc.)
  property bool interactive: false

  signal watchClicked()
  signal detailClicked()
  signal clicked()

  implicitWidth: Style.space(320)
  // Stacked Watch/Detail: height is max(text column, button column) + padding.
  implicitHeight: {
    var pad = Style.space(compact ? 16 : 20)
    var textH = textColumn.implicitHeight
    var btnH = btnColumn.visible ? btnColumn.implicitHeight : 0
    return Math.max(textH, btnH) + pad
  }

  readonly property real cardRadius: Math.max(4, Style.cornerRadius)
  readonly property int actionBtnCount: (showWatch ? 1 : 0) + (showDetail ? 1 : 0)
  // Stacked buttons share one column width (single button width).
  readonly property real actionBtnsWidth: actionBtnCount > 0 ? Style.space(72) : 0

  function badgeColor() {
    // Alpha wells from theme accent/urgent — readable on light and dark themes.
    if (badgeKind === "go")
      return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
    if (badgeKind === "live")
      return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.28)
    if (badgeKind === "tbd")
      return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
    if (badgeKind === "ok")
      return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)
  }

  function badgeFg() {
    if (badgeKind === "go" || badgeKind === "ok")
      return Color.accent
    if (badgeKind === "live")
      return Color.urgent
    if (badgeKind === "tbd")
      return Qt.lighter(foreground, 1.15)
    return foreground
  }

  Rectangle {
    anchors.fill: parent
    radius: root.cardRadius
    color: root.surfaceColor
    border.width: 1
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
      (root.interactive && cardMa.containsMouse) ? 0.16 : 0.08)

    MouseArea {
      id: cardMa
      anchors.fill: parent
      enabled: root.interactive
      hoverEnabled: root.interactive
      cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.clicked()
      z: 0
    }

    Row {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(10)
      z: 1

      Column {
        id: textColumn
        width: parent.width - (root.actionBtnCount > 0 ? root.actionBtnsWidth + parent.spacing : 0)
        spacing: Style.space(4)

        Row {
          spacing: Style.space(8)
          width: parent.width

          Text {
            id: titleText
            width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + parent.spacing : 0))
            text: root.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Rectangle {
            id: badge
            visible: root.badgeText.length > 0
            width: badgeLabel.implicitWidth + 12
            height: badgeLabel.implicitHeight + 6
            radius: Math.max(2, Style.cornerRadius - 4)
            color: root.badgeColor()
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: badgeLabel
              anchors.centerIn: parent
              text: root.badgeText
              textFormat: Text.PlainText
              color: root.badgeFg()
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        Text {
          width: parent.width
          visible: root.subtitle.length > 0
          text: root.subtitle
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: root.foreground
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          width: parent.width
          visible: root.meta.length > 0
          text: root.meta
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: root.foreground
          opacity: 0.4
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // Primary Watch + secondary Detail stacked vertically on the right
      Column {
        id: btnColumn
        visible: root.actionBtnCount > 0
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          id: watchBtn
          visible: root.showWatch
          width: Style.space(72)
          height: Style.space(28)
          radius: Math.max(3, Style.cornerRadius - 3)
          color: watchMa.containsMouse ? Qt.lighter(root.foreground, 1.12) : root.foreground
          Accessible.name: "Watch"
          Accessible.role: Accessible.Button

          Text {
            anchors.centerIn: parent
            text: "WATCH"
            color: Color.background
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          MouseArea {
            id: watchMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.watchClicked()
          }
        }

        Rectangle {
          id: detailBtn
          visible: root.showDetail
          width: Style.space(72)
          height: Style.space(28)
          radius: Math.max(3, Style.cornerRadius - 3)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
            detailMa.containsMouse ? 0.12 : 0.06)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
            detailMa.containsMouse ? 0.5 : 0.35)
          Accessible.name: root.detailOpen ? "Close detail" : "Detail"
          Accessible.role: Accessible.Button

          Text {
            anchors.centerIn: parent
            text: root.detailOpen ? "CLOSE" : "DETAIL"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          MouseArea {
            id: detailMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailClicked()
          }
        }
      }
    }
  }
}
