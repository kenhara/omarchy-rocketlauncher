import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Nested details panel for Rocketlauncher (loaded by BarWidget — not a separate kind).
Panel {
  id: root
  moduleName: "kenhara.rocketlauncher"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var store: null
  // H3: BarWidget-owned WatchPlayer; reparented into watchSlot while panel is open.
  property var watchPlayer: null
  property alias watchSlot: watchSlotItem

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : "monospace"
  // Theme-first surfaces (Coverglow / Coin Toss pattern). Brand accents = subtle alpha only.
  readonly property color themeBackground: {
    try {
      if (typeof Color !== "undefined" && Color.popups && Color.popups.background)
        return Color.popups.background
      if (typeof Color !== "undefined" && Color.background)
        return Color.background
    } catch (e) {}
    return Qt.rgba(0.1, 0.1, 0.12, 1)
  }
  readonly property color surfaceColor: Qt.rgba(
    contentForeground.r, contentForeground.g, contentForeground.b, 0.06)
  readonly property color digitWell: Qt.rgba(
    contentForeground.r, contentForeground.g, contentForeground.b, 0.12)
  readonly property color dimForeground: Qt.darker(contentForeground, 1.45)
  readonly property color fainterForeground: Qt.darker(contentForeground, 1.7)

  readonly property var liveStore: store
  property bool pastSectionExpanded: false
  property bool ongoingSectionExpanded: false
  property bool upcomingSectionExpanded: false

  function upcomingWithoutNext() {
    if (!liveStore || !liveStore.upcoming) return []
    var nid = liveStore.nextLaunch ? String(liveStore.nextLaunch.id || "") : ""
    var src = liveStore.upcoming
    var out = []
    for (var i = 0; i < src.length; i++) {
      if (src[i] && String(src[i].id) !== nid)
        out.push(src[i])
    }
    return out
  }

  onOpenedChanged: {
    if (root.opened && liveStore && liveStore.nextLaunch && liveStore.nextLaunch.id) {
      // Soft-fetch detail for next launch when the panel opens (cached after first hit).
      liveStore.fetchLaunchDetail(liveStore.nextLaunch.id, { expand: false })
    }
    // L2: pauseWatchOnHide is owned by LaunchStore.onPanelOpenChanged (via BarWidget).
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function watchNext() {
    if (!liveStore) return
    liveStore.openWatch(liveStore.nextLaunch)
  }

  function toggleWatchPlayPause() {
    if (root.isWatching && root.watchPlayer && root.watchPlayer.active) {
      root.watchPlayer.togglePlayPause()
      return
    }
    if (liveStore)
      liveStore.openWatch(liveStore.nextLaunch)
  }

  function watchTargetLaunch() {
    if (!liveStore) return null
    var sid = liveStore.selectedLaunchId
    if (sid) {
      if (liveStore.nextLaunch && String(liveStore.nextLaunch.id) === String(sid))
        return liveStore.nextLaunch
      if (typeof liveStore.launchRowById === "function") {
        var row = liveStore.launchRowById(sid)
        if (row) return row
      }
      var d = liveStore.detailFor(sid)
      if (d) return d
    }
    return liveStore.nextLaunch
  }

  function handleWatchKeys(event) {
    if (!event) return false
    var key = event.key
    var text = String(event.text || "").toLowerCase()
    // Space — play/pause (or start Watch for next launch)
    if (key === Qt.Key_Space) {
      if (root.isWatching && root.watchPlayer && root.watchPlayer.active) {
        root.watchPlayer.togglePlayPause()
      } else if (liveStore) {
        liveStore.openWatch(liveStore.nextLaunch)
      }
      event.accepted = true
      return true
    }
    // W — Watch for next (or selected) if not already watching
    if (key === Qt.Key_W || text === "w") {
      if (liveStore && !liveStore.watching)
        liveStore.openWatch(root.watchTargetLaunch())
      event.accepted = true
      return true
    }
    // D — toggle Detail for selected, else next
    if (key === Qt.Key_D || text === "d") {
      if (liveStore) {
        var sid = liveStore.selectedLaunchId
        if (!sid) {
          root.requestNextDetail()
        } else if (liveStore.nextLaunch && String(liveStore.nextLaunch.id) === String(sid)) {
          if (liveStore.detailExpanded)
            liveStore.detailExpanded = false
          else
            root.requestNextDetail()
        } else {
          root.requestLaunchDetail(sid)
        }
      }
      event.accepted = true
      return true
    }
    // M — mute / unmute
    if (key === Qt.Key_M || text === "m") {
      if (liveStore) liveStore.toggleWatchMute()
      event.accepted = true
      return true
    }
    // O — open original webcast URL
    if (key === Qt.Key_O || text === "o") {
      if (liveStore) {
        if (!liveStore.watchUrl && liveStore.nextLaunch)
          liveStore.openWatch(liveStore.nextLaunch)
        liveStore.openWatchOriginal()
      }
      event.accepted = true
      return true
    }
    // S — stop Watch (optional; always tears down even when sticky)
    if (key === Qt.Key_S || text === "s") {
      if (liveStore) liveStore.closeWatch()
      event.accepted = true
      return true
    }
    return false
  }

  function badgeFor(launch) {
    if (!liveStore || !launch) return { text: "", kind: "muted" }
    return liveStore.statusBadge(launch)
  }

  function nextDetail() {
    if (!liveStore || !liveStore.nextLaunch) return null
    var id = liveStore.nextLaunch.id
    return liveStore.detailFor(id) || liveStore.nextLaunch
  }

  function nextFact(field) {
    var d = root.nextDetail()
    if (d && d[field]) return String(d[field])
    var n = liveStore ? liveStore.nextLaunch : null
    if (n && n[field]) return String(n[field])
    return ""
  }

  readonly property string nextPadLabel: root.nextFact("pad_name")
  readonly property string nextOrbitLabel: root.nextFact("orbit")
  readonly property string nextLandingLabel: root.nextFact("landing_summary")

  function requestNextDetail() {
    if (!liveStore) return
    liveStore.ensureNextDetail()
  }

  function requestLaunchDetail(id) {
    if (!liveStore || !id) return
    if (liveStore.selectedLaunchId === id && liveStore.detailExpanded) {
      liveStore.detailExpanded = false
      return
    }
    // Always expand; fetchLaunchDetail seeds a stub if the API fails.
    liveStore.fetchLaunchDetail(id, { expand: true })
  }

  function openExternalLink(url) {
    if (liveStore) return liveStore.openUrlExternal(url)
    return false
  }

  function detailForId(id) {
    if (!liveStore || !id) return null
    return liveStore.detailFor(id)
  }

  readonly property bool isWatching: !!(liveStore && liveStore.watching)
  readonly property int panelBaseHeight: Style.space(520)
  readonly property int panelWatchHeight: Style.space(720)

  function persistSetting(key, value) {
    if (!liveStore) return
    var opts = ({})
    opts[key] = value
    liveStore.applySettings(opts)
    // Mirror into bar settings so shell.json / `omarchy bar set` stay durable.
    if (hostWidget && typeof hostWidget.mirrorSetting === "function")
      hostWidget.mirrorSetting(key, value)
    else if (hostWidget && hostWidget.settings) {
      try { hostWidget.settings[key] = value } catch (e) {}
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    // H1: fittedContentHeight caps the viewport; Flickable scrolls tall column content.
    contentHeight: panel.fittedContentHeight(
      root.isWatching ? root.panelWatchHeight : root.panelBaseHeight
    )
    popoutSwitching: root.popoutSwitching
    popoutSwitchClosing: root.popoutSwitchClosing

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Keys.onPressed: function(event) {
        root.handleWatchKeys(event)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: column.implicitHeight
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(14)

        // 1. Header
        Column {
          width: parent.width
          spacing: Style.space(4)

          Row {
            spacing: Style.space(8)
            PhosphorIcon {
              name: (liveStore && liveStore.barLive) ? "rocket-launch" : "rocket"
              color: (liveStore && liveStore.barLive) ? Color.accent : root.contentForeground
              width: Style.font.body
              height: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "ROCKETLAUNCHER"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              font.letterSpacing: 3
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            text: {
              if (!liveStore) return "next NET"
              var line = liveStore.jobLine || "next NET"
              if (liveStore.loading && String(line).indexOf("offline") !== 0)
                line += " · refreshing…"
              return line
            }
            textFormat: Text.PlainText
            color: root.contentForeground
            opacity: 0.45
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            width: parent.width
          }
        }

        // 2. Hero flip-digit row
        Row {
          width: parent.width
          spacing: Style.space(12)

          // L4: 4-digit FlipCounter is intentional (odometer look), not a bug.
          FlipCounter {
            width: (parent.width - parent.spacing * 2) / 3
            value: liveStore ? liveStore.statTotalLaunches : 0
            label: "Launches"
            digitCount: 4
            foreground: root.contentForeground
            accentColor: root.digitWell
            fontFamily: root.contentFontFamily
            animate: root.opened && (!liveStore || liveStore.flipAnimate)
          }

          FlipCounter {
            width: (parent.width - parent.spacing * 2) / 3
            value: liveStore ? liveStore.statSuccessfulLandings : 0
            label: "Landings"
            digitCount: 4
            foreground: root.contentForeground
            accentColor: root.digitWell
            fontFamily: root.contentFontFamily
            animate: root.opened && (!liveStore || liveStore.flipAnimate)
          }

          FlipCounter {
            width: (parent.width - parent.spacing * 2) / 3
            value: liveStore ? liveStore.statPendingLaunches : 0
            label: "Pending"
            digitCount: 4
            foreground: root.contentForeground
            accentColor: root.digitWell
            fontFamily: root.contentFontFamily
            animate: root.opened && (!liveStore || liveStore.flipAnimate)
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        // 3. Next launch card + expandable detail + in-panel Watch
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "NEXT LAUNCH"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          MissionCard {
            width: parent.width
            compact: false
            interactive: false
            foreground: root.contentForeground
            surfaceColor: root.surfaceColor
            fontFamily: root.contentFontFamily
            title: {
              var n = liveStore ? liveStore.nextLaunch : null
              return n ? (n.mission_name || n.name || "—") : "No upcoming launch"
            }
            subtitle: {
              var n = liveStore ? liveStore.nextLaunch : null
              if (!n) return ""
              return n.vehicle || ""
            }
            meta: {
              var n = liveStore ? liveStore.nextLaunch : null
              if (!n || !n.net) return ""
              return "NET " + liveStore.formatNetLocal(n.net)
            }
            badgeText: ""
            badgeKind: "muted"
            showWatch: {
              var n = liveStore ? liveStore.nextLaunch : null
              return !!(n && liveStore.officialWebcast(n))
            }
            showDetail: !!(liveStore && liveStore.nextLaunch)
            detailOpen: !!(liveStore && liveStore.detailExpanded && liveStore.nextLaunch
              && liveStore.selectedLaunchId === liveStore.nextLaunch.id)
            onWatchClicked: root.watchNext()
            onDetailClicked: {
              if (!liveStore) return
              if (liveStore.detailExpanded) {
                liveStore.detailExpanded = false
              } else {
                root.requestNextDetail()
              }
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(12)
            visible: root.nextPadLabel.length > 0
              || root.nextOrbitLabel.length > 0
              || root.nextLandingLabel.length > 0

            Row {
              spacing: 4
              visible: root.nextPadLabel.length > 0
              PhosphorIcon {
                name: "map-pin"
                color: root.contentForeground
                width: Style.font.caption
                height: Style.font.caption
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.nextPadLabel
                textFormat: Text.PlainText
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Style.space(168))
                color: root.contentForeground
                opacity: 0.5
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              spacing: 4
              visible: root.nextOrbitLabel.length > 0
              PhosphorIcon {
                name: "planet"
                color: root.contentForeground
                width: Style.font.caption
                height: Style.font.caption
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.nextOrbitLabel
                textFormat: Text.PlainText
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Style.space(96))
                color: root.contentForeground
                opacity: 0.5
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              spacing: 4
              visible: root.nextLandingLabel.length > 0
              PhosphorIcon {
                name: "parachute"
                color: root.contentForeground
                width: Style.font.caption
                height: Style.font.caption
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.nextLandingLabel
                textFormat: Text.PlainText
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Style.space(168))
                color: root.contentForeground
                opacity: 0.5
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          TrajectoryStroke {
            width: parent.width
            visible: {
              if (!liveStore || !liveStore.nextLaunch) return false
              var _n = liveStore.nowMs
              return liveStore.trajectoryVisible(liveStore.nextLaunch)
            }
            kind: liveStore ? liveStore.trajectoryKind(liveStore.nextLaunch) : "leo"
            phase: {
              if (!liveStore) return "net"
              var _n = liveStore.nowMs
              return liveStore.trajectoryPhase(liveStore.nextLaunch)
            }
            foreground: root.contentForeground
          }

          Text {
            width: parent.width
            visible: {
              if (!liveStore || !liveStore.detailLoading) return false
              var lid = liveStore.detailLoadingId || liveStore.selectedLaunchId
              var nid = liveStore.nextLaunch ? liveStore.nextLaunch.id : ""
              return lid === nid || lid === liveStore.selectedLaunchId
            }
            text: "Loading mission detail…"
            color: root.contentForeground
            opacity: 0.45
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            visible: {
              if (!liveStore || !liveStore.lastError || liveStore.detailLoading) return false
              if (!liveStore.detailExpanded || !liveStore.nextLaunch) return false
              return liveStore.selectedLaunchId === liveStore.nextLaunch.id
            }
            text: liveStore ? liveStore.lastError : ""
            textFormat: Text.PlainText
            color: Color.urgent
            opacity: 0.75
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          MissionDetail {
            width: parent.width
            detail: root.nextDetail()
            expanded: !!(liveStore && liveStore.detailExpanded && liveStore.nextLaunch
              && liveStore.selectedLaunchId === liveStore.nextLaunch.id)
            foreground: root.contentForeground
            surfaceColor: root.surfaceColor
            fontFamily: root.contentFontFamily
            onOpenLink: function(url) { root.openExternalLink(url) }
          }

          // H3: slot for BarWidget-hoisted WatchPlayer (reparented while panel open).
          Item {
            id: watchSlotItem
            width: parent.width
            height: {
              if (!root.watchPlayer || !root.watchPlayer.active || !root.watchPlayer.chromeVisible)
                return 0
              return root.watchPlayer.implicitHeight
            }
            visible: height > 0
            onWidthChanged: {
              if (root.watchPlayer && root.watchPlayer.parent === watchSlotItem)
                root.watchPlayer.width = width
            }
          }
        }

        // 4. Ongoing missions
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: liveStore && liveStore.ongoing && liveStore.ongoing.length > 0

          Item {
            width: parent.width
            height: Math.max(ongoingHdr.implicitHeight, ongoingToggle.height)

            PanelSectionHeader {
              id: ongoingHdr
              anchors.left: parent.left
              anchors.right: ongoingToggle.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "ONGOING MISSIONS"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Rectangle {
              id: ongoingToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(88)
              height: Style.space(28)
              radius: Math.max(3, Style.cornerRadius - 3)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b,
                ongoingToggleMa.containsMouse ? 0.12 : 0.06)
              border.width: 1
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b,
                ongoingToggleMa.containsMouse ? 0.5 : 0.35)

              Text {
                anchors.centerIn: parent
                text: root.ongoingSectionExpanded ? "COLLAPSE" : "EXPAND"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }

              MouseArea {
                id: ongoingToggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.ongoingSectionExpanded = !root.ongoingSectionExpanded
              }
            }
          }

          Repeater {
            model: root.ongoingSectionExpanded && liveStore ? liveStore.ongoing : []

            Column {
              required property var modelData
              width: parent.width
              spacing: Style.space(6)

              readonly property string craftId: String(modelData && modelData.id != null ? modelData.id : "")
              readonly property var locateMap: liveStore ? liveStore.locateById : ({})
              readonly property var locateOpenMap: liveStore ? liveStore.locateOpenById : ({})
              readonly property var locateFix: {
                var _m = locateMap
                return liveStore ? liveStore.locateFixFor(craftId) : null
              }
              readonly property bool locateIsOpen: {
                var _o = locateOpenMap
                return !!(locateOpenMap && locateOpenMap[craftId])
              }

              MissionCard {
                width: parent.width
                compact: true
                interactive: false
                foreground: root.contentForeground
                surfaceColor: root.surfaceColor
                fontFamily: root.contentFontFamily
                title: modelData.name || "Crew Dragon"
                subtitle: (modelData.config || "Crew Dragon")
                  + (modelData.serial ? " · " + modelData.serial : "")
                meta: {
                  var tis = liveStore ? liveStore.formatIsoDuration(modelData.time_in_space) : modelData.time_in_space
                  return "Time in space: " + tis
                }
                badgeText: modelData.in_space ? "IN SPACE" : ""
                badgeKind: "ok"
                showWatch: false
                showDetail: false
                showLocate: true
                locateOpen: parent.locateIsOpen
                locateBusy: !!(parent.locateFix && parent.locateFix.kind === "checking")
                locateKind: parent.locateFix && parent.locateFix.kind ? parent.locateFix.kind : ""
                onLocateClicked: {
                  if (liveStore)
                    liveStore.requestLocate(modelData.id)
                }
              }

              OrbitRing {
                width: parent.width
                visible: parent.locateIsOpen && parent.locateFix && parent.locateFix.kind === "iss-docked"
                inclinationDeg: parent.locateFix && parent.locateFix.inclination_deg != null ? parent.locateFix.inclination_deg : 0
                meanAnomalyDeg: parent.locateFix && parent.locateFix.mean_anomaly_deg != null ? parent.locateFix.mean_anomaly_deg : 0
                caption: parent.locateFix && parent.locateFix.caption ? parent.locateFix.caption : ""
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              CourseStroke {
                width: parent.width
                visible: parent.locateIsOpen && parent.locateFix && parent.locateFix.kind === "course"
                path: parent.locateFix && parent.locateFix.path ? parent.locateFix.path : "leo"
                caption: parent.locateFix && parent.locateFix.caption ? parent.locateFix.caption : ""
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              Text {
                width: parent.width
                visible: parent.locateIsOpen && parent.locateFix && parent.locateFix.kind === "none"
                text: parent.locateFix && parent.locateFix.caption ? parent.locateFix.caption : "NO PUBLIC TRACK"
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                color: root.contentForeground
                opacity: 0.5
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
                wrapMode: Text.WordWrap
              }
            }
          }
        }

        // 5. Upcoming list
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.upcomingWithoutNext().length > 0

          Item {
            width: parent.width
            height: Math.max(upcomingHdr.implicitHeight, upcomingToggle.height)

            PanelSectionHeader {
              id: upcomingHdr
              anchors.left: parent.left
              anchors.right: upcomingToggle.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "UPCOMING"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Rectangle {
              id: upcomingToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(88)
              height: Style.space(28)
              radius: Math.max(3, Style.cornerRadius - 3)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b,
                upcomingToggleMa.containsMouse ? 0.12 : 0.06)
              border.width: 1
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b,
                upcomingToggleMa.containsMouse ? 0.5 : 0.35)

              Text {
                anchors.centerIn: parent
                text: root.upcomingSectionExpanded ? "COLLAPSE" : "EXPAND"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }

              MouseArea {
                id: upcomingToggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.upcomingSectionExpanded = !root.upcomingSectionExpanded
              }
            }
          }

          Repeater {
            model: {
              if (!root.upcomingSectionExpanded)
                return []
              return root.upcomingWithoutNext().slice(0, 5)
            }

            Column {
              required property var modelData
              width: parent.width
              spacing: Style.space(6)

              MissionCard {
                width: parent.width
                compact: true
                interactive: false
                foreground: root.contentForeground
                surfaceColor: root.surfaceColor
                fontFamily: root.contentFontFamily
                title: modelData.mission_name || modelData.name || "—"
                subtitle: modelData.vehicle || ""
                meta: {
                  if (!modelData.net) return ""
                  if (!liveStore) return modelData.net
                  return "NET " + liveStore.formatNetLocal(modelData.net)
                }
                badgeText: badgeFor(modelData).text
                badgeKind: badgeFor(modelData).kind
                showWatch: !!(liveStore && liveStore.officialWebcast(modelData))
                showDetail: true
                detailOpen: !!(liveStore && liveStore.selectedLaunchId === modelData.id
                  && liveStore.detailExpanded)
                onWatchClicked: {
                  if (liveStore)
                    liveStore.openWatch(modelData)
                }
                onDetailClicked: root.requestLaunchDetail(modelData.id)
              }

              Text {
                width: parent.width
                visible: !!(liveStore && liveStore.detailLoading
                  && String(liveStore.selectedLaunchId) === String(modelData.id)
                  && (String(liveStore.detailLoadingId || liveStore.selectedLaunchId)
                      === String(modelData.id)))
                text: "Loading mission detail…"
                color: root.contentForeground
                opacity: 0.45
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                width: parent.width
                visible: !!(liveStore && liveStore.lastError
                  && liveStore.detailExpanded
                  && String(liveStore.selectedLaunchId) === String(modelData.id)
                  && !liveStore.detailLoading)
                text: liveStore ? liveStore.lastError : ""
                textFormat: Text.PlainText
                color: Color.urgent
                opacity: 0.75
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              MissionDetail {
                width: parent.width
                detail: {
                  if (!liveStore || liveStore.selectedLaunchId !== modelData.id)
                    return null
                  // Next launch detail lives under NEXT LAUNCH — avoid a duplicate empty card.
                  if (liveStore.nextLaunch && liveStore.nextLaunch.id === modelData.id)
                    return null
                  return liveStore.detailFor(modelData.id) || modelData
                }
                expanded: !!(liveStore && liveStore.detailExpanded
                  && liveStore.selectedLaunchId === modelData.id
                  && (!liveStore.nextLaunch || liveStore.nextLaunch.id !== modelData.id))
                foreground: root.contentForeground
                surfaceColor: root.surfaceColor
                fontFamily: root.contentFontFamily
                onOpenLink: function(url) { root.openExternalLink(url) }
              }
            }
          }
        }

        // 6. Past missions (lazy-loaded on first expand)
        Column {
          width: parent.width
          spacing: Style.space(8)

          Item {
            width: parent.width
            height: Math.max(pastHdr.implicitHeight, pastToggle.height)

            PanelSectionHeader {
              id: pastHdr
              anchors.left: parent.left
              anchors.right: pastToggle.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "PAST MISSIONS"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Rectangle {
              id: pastToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(88)
              height: Style.space(28)
              radius: Math.max(3, Style.cornerRadius - 3)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b,
                pastToggleMa.containsMouse ? 0.12 : 0.06)
              border.width: 1
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b,
                pastToggleMa.containsMouse ? 0.5 : 0.35)

              Text {
                anchors.centerIn: parent
                text: root.pastSectionExpanded ? "COLLAPSE" : "EXPAND"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }

              MouseArea {
                id: pastToggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.pastSectionExpanded = !root.pastSectionExpanded
                  if (root.pastSectionExpanded && liveStore)
                    liveStore.ensurePastLaunches()
                }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.pastSectionExpanded && !!(liveStore && liveStore.pastLoading)
            text: "Loading past missions…"
            color: root.contentForeground
            opacity: 0.45
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            visible: root.pastSectionExpanded && !!(liveStore && liveStore.pastLoaded
              && (!liveStore.past || liveStore.past.length === 0) && !liveStore.pastLoading)
            text: "No past missions cached"
            color: root.contentForeground
            opacity: 0.4
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: {
              if (!root.pastSectionExpanded || !liveStore || !liveStore.past) return []
              return liveStore.past.slice(0, 5)
            }

            Column {
              required property var modelData
              width: parent.width
              spacing: Style.space(6)

              MissionCard {
                width: parent.width
                compact: true
                interactive: false
                foreground: root.contentForeground
                surfaceColor: root.surfaceColor
                fontFamily: root.contentFontFamily
                title: modelData.mission_name || modelData.name || "—"
                subtitle: modelData.vehicle || ""
                meta: {
                  if (!modelData.net) return ""
                  if (!liveStore) return modelData.net
                  return "NET " + liveStore.formatNetLocal(modelData.net)
                }
                badgeText: badgeFor(modelData).text
                badgeKind: badgeFor(modelData).kind
                showWatch: false
                showDetail: true
                detailOpen: !!(liveStore && liveStore.selectedLaunchId === modelData.id
                  && liveStore.detailExpanded)
                onDetailClicked: root.requestLaunchDetail(modelData.id)
              }

              MissionDetail {
                width: parent.width
                detail: {
                  if (!liveStore || liveStore.selectedLaunchId !== modelData.id)
                    return null
                  return liveStore.detailFor(modelData.id) || modelData
                }
                expanded: !!(liveStore && liveStore.detailExpanded
                  && liveStore.selectedLaunchId === modelData.id)
                foreground: root.contentForeground
                surfaceColor: root.surfaceColor
                fontFamily: root.contentFontFamily
            onOpenLink: function(url) { root.openExternalLink(url) }
              }
            }
          }
        }

        // Bar display — in-panel (Omarchy has no widget-settings GUI)
        Column {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "Bar"
            color: root.contentForeground
            opacity: 0.55
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          // Countdown on bar
          Row {
            width: parent.width
            spacing: Style.space(10)

            Column {
              width: parent.width - countdownToggleWell.width - Style.space(10)
              spacing: 2
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: parent.width
                text: "Countdown on bar"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: (liveStore && liveStore.barShowCountdown)
                  ? "On — NET countdown in the bar chip"
                  : "Off — rocket only (countdown stays in panel + tooltip)"
                color: root.contentForeground
                opacity: 0.4
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Rectangle {
              id: countdownToggleWell
              width: Style.space(46)
              height: Style.space(24)
              radius: height / 2
              anchors.verticalCenter: parent.verticalCenter
              color: (liveStore && liveStore.barShowCountdown)
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
              border.width: 1
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)

              Rectangle {
                width: Style.space(18)
                height: Style.space(18)
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: (liveStore && liveStore.barShowCountdown)
                  ? parent.width - width - Style.space(3)
                  : Style.space(3)
                color: root.contentForeground

                Behavior on x {
                  NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!liveStore) return
                  root.persistSetting("barShowCountdown", !liveStore.barShowCountdown)
                }
              }
            }
          }

        }

        Text {
          width: parent.width
          text: {
            var zone = liveStore && typeof liveStore.localTimeZone === "function"
              ? liveStore.localTimeZone()
              : (liveStore ? (liveStore.localZoneName || "") : "")
            var t = "Unofficial · Launch Library 2"
            if (zone)
              t += " · times local, " + zone
            return t
          }
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: root.contentForeground
          opacity: 0.32
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }

        } // Column
      } // Flickable
    }
  }
}
