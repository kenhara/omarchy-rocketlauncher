import QtQuick
import qs.Commons

// Expandable mission detail — description, pad, landing, patch, crew.
// Theme-native (Color / Style). Hides empty crew for Starlink-style launches.
Item {
  id: root

  property var detail: null
  property color foreground: Color.foreground
  property color surfaceColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
  property string fontFamily: "monospace"
  property bool expanded: true

  readonly property bool hasDetail: !!(detail && (detail.description || detail.pad_name || detail.landing_summary))
  readonly property var crewList: (detail && detail.crew) ? detail.crew : []
  readonly property bool hasCrew: crewList && crewList.length > 0
  readonly property string preferredPatchUrl: {
    if (!detail) return ""
    if (detail.patch_url) return detail.patch_url
    if (detail.image_url) return detail.image_url
    return ""
  }

  property bool patchFailed: false
  property string patchSource: ""

  onPreferredPatchUrlChanged: {
    patchFailed = false
    patchSource = preferredPatchUrl
  }
  onDetailChanged: {
    patchFailed = false
    patchSource = preferredPatchUrl
  }

  readonly property bool showPatch: patchSource.length > 0 && !patchFailed

  visible: hasDetail && expanded
  implicitWidth: Style.space(320)
  implicitHeight: visible ? col.implicitHeight : 0

  function crewLink(member) {
    if (!member) return ""
    if (member.wiki_url) return member.wiki_url
    if (member.url) return member.url
    return ""
  }

  Column {
    id: col
    width: parent.width
    spacing: Style.space(10)

    // Patch + type / orbit row
    Row {
      width: parent.width
      spacing: Style.space(10)
      visible: root.showPatch || (root.detail && (root.detail.mission_type || root.detail.orbit))

      Rectangle {
        id: patchRect
        visible: root.showPatch
        width: Style.space(48)
        height: Style.space(48)
        radius: Math.max(4, Style.cornerRadius - 2)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        clip: true

        Image {
          id: patchImage
          anchors.fill: parent
          anchors.margins: 4
          source: root.patchSource
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          cache: true
          visible: status === Image.Ready
          onStatusChanged: {
            if (status === Image.Error) {
              // Prefer patch_url; if that fails, try image_url once; then hide.
              if (root.detail && root.patchSource === root.detail.patch_url && root.detail.image_url
                  && root.detail.image_url !== root.patchSource) {
                root.patchSource = root.detail.image_url
                return
              }
              root.patchFailed = true
              root.patchSource = ""
            }
          }
        }
      }

      Column {
        width: parent.width - (root.showPatch ? Style.space(48) + parent.spacing : 0)
        spacing: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          width: parent.width
          visible: !!(root.detail && root.detail.mission_type)
          text: root.detail ? (root.detail.mission_type || "") : ""
          color: root.foreground
          opacity: 0.7
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        Text {
          width: parent.width
          visible: !!(root.detail && (root.detail.orbit || root.detail.spacecraft_name))
          text: {
            if (!root.detail) return ""
            var bits = []
            if (root.detail.orbit) bits.push(root.detail.orbit)
            if (root.detail.spacecraft_name) {
              var sc = root.detail.spacecraft_name
              if (root.detail.spacecraft_serial)
                sc += " · " + root.detail.spacecraft_serial
              bits.push(sc)
            }
            return bits.join("  ·  ")
          }
          color: root.foreground
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    Text {
      width: parent.width
      visible: !!(root.detail && root.detail.description)
      text: root.detail ? (root.detail.description || "") : ""
      wrapMode: Text.WordWrap
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      lineHeight: 1.25
    }

    // Pad / landing / rocket facts
    Column {
      width: parent.width
      spacing: Style.space(4)

      Text {
        width: parent.width
        visible: !!(root.detail && root.detail.pad_name)
        text: {
          if (!root.detail) return ""
          var t = "Pad  " + (root.detail.pad_name || "")
          if (root.detail.location_name)
            t += "  ·  " + root.detail.location_name
          return t
        }
        wrapMode: Text.WordWrap
        color: root.foreground
        opacity: 0.5
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        visible: !!(root.detail && root.detail.landing_summary)
        text: {
          if (!root.detail) return ""
          var t = "Landing  " + (root.detail.landing_summary || "")
          if (root.detail.booster_serial) {
            t += "  ·  " + root.detail.booster_serial
            if (root.detail.booster_flight)
              t += " (flight " + root.detail.booster_flight + ")"
          }
          return t
        }
        wrapMode: Text.WordWrap
        color: root.foreground
        opacity: 0.5
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        visible: !!(root.detail && root.detail.vehicle)
        text: "Vehicle  " + (root.detail ? (root.detail.vehicle || "") : "")
        color: root.foreground
        opacity: 0.5
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    // Crew — horizontal avatar row (circular) + name + role; hidden when empty
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.hasCrew

      Text {
        text: "CREW"
        color: root.foreground
        opacity: 0.55
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 2
      }

      Flow {
        width: parent.width
        spacing: Style.space(10)

        Repeater {
          model: root.crewList

          Column {
            required property var modelData
            width: Style.space(72)
            spacing: Style.space(4)

            readonly property string linkUrl: root.crewLink(modelData)

            Rectangle {
              width: Style.space(40)
              height: Style.space(40)
              radius: width / 2
              anchors.horizontalCenter: parent.horizontalCenter
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
              clip: true

              Image {
                id: crewAvatar
                anchors.fill: parent
                source: (modelData && modelData.image_url) ? modelData.image_url : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
                onStatusChanged: {
                  // On error, leave visible=false so initial-letter fallback shows.
                  if (status === Image.Error)
                    source = ""
                }
              }

              Text {
                anchors.centerIn: parent
                visible: crewAvatar.status !== Image.Ready
                text: {
                  var n = (modelData && modelData.name) ? modelData.name : "?"
                  return n.charAt(0)
                }
                color: root.foreground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: (modelData && modelData.name) ? modelData.name : ""
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: {
                if (!modelData) return ""
                var bits = []
                if (modelData.role) bits.push(modelData.role)
                if (modelData.agency) bits.push(modelData.agency)
                return bits.join(" · ")
              }
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              enabled: parent.linkUrl.length > 0
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (parent.linkUrl.length)
                  Qt.openUrlExternally(parent.linkUrl)
              }
            }
          }
        }
      }
    }
  }
}
