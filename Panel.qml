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
  property bool ongoingSectionExpanded: true
  property bool upcomingSectionExpanded: true

  onOpenedChanged: {
    if (root.opened && liveStore && liveStore.nextLaunch && liveStore.nextLaunch.id) {
      // Soft-fetch detail for next launch when the panel opens (cached after first hit).
      liveStore.fetchLaunchDetail(liveStore.nextLaunch.id)
      liveStore.detailExpanded = true
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

      // Subtle starfield — paused when panel closed
      Canvas {
        id: starfield
        anchors.fill: parent
        opacity: root.opened && !root.isWatching && (!liveStore || liveStore.starfieldEnabled) ? 0.35 : 0
        property var stars: []
        property real t: 0

        function rebuild() {
          var list = []
          var w = Math.max(1, width)
          var h = Math.max(1, height)
          for (var i = 0; i < 48; i++) {
            list.push({
              x: Math.random() * w,
              y: Math.random() * h,
              r: 0.6 + Math.random() * 1.4,
              a: 0.15 + Math.random() * 0.55,
              s: 0.2 + Math.random() * 0.8
            })
          }
          stars = list
          requestPaint()
        }

        onWidthChanged: rebuild()
        onHeightChanged: rebuild()
        Component.onCompleted: rebuild()

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          for (var i = 0; i < stars.length; i++) {
            var s = stars[i]
            var twinkle = 0.65 + 0.35 * Math.sin(t * s.s + i)
            ctx.globalAlpha = s.a * twinkle
            ctx.fillStyle = Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 1)
            ctx.beginPath()
            ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2)
            ctx.fill()
          }
          // Faint scanline
          ctx.globalAlpha = 0.04
          ctx.fillStyle = Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 1)
          for (var y = 0; y < height; y += 3)
            ctx.fillRect(0, y, width, 1)
        }

        Timer {
          interval: 80
          running: root.opened && !root.isWatching && (!liveStore || liveStore.starfieldEnabled)
          repeat: true
          onTriggered: {
            starfield.t += 0.08
            starfield.requestPaint()
          }
        }
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

          Text {
            text: "ROCKETLAUNCHER"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            font.letterSpacing: 3
          }

          Text {
            text: {
              var src = liveStore ? liveStore.dataSource : "—"
              var upd = liveStore ? liveStore.lastUpdatedText : "never"
              var load = (liveStore && liveStore.loading) ? " · refreshing…" : ""
              return "updated " + upd + " · " + src + load
            }
            color: root.contentForeground
            opacity: 0.45
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
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
            label: "Total launches"
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

        Text {
          width: parent.width
          text: {
            var c = liveStore ? liveStore.statConsecutiveSuccessfulLaunches : 0
            return "Consecutive successful launches: " + c
              + "  ·  LL2 agency totals (not reflight counters)"
          }
          wrapMode: Text.WordWrap
          color: root.contentForeground
          opacity: 0.4
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
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
              var cd = liveStore.countdownText || ""
              return (n.vehicle || "") + (cd ? "  ·  " + cd : "")
            }
            meta: {
              var n = liveStore ? liveStore.nextLaunch : null
              if (!n || !n.net) return ""
              return "NET " + n.net.replace("T", " ").replace(/\.\d+Z$/, " UTC")
            }
            badgeText: badgeFor(liveStore ? liveStore.nextLaunch : null).text
            badgeKind: badgeFor(liveStore ? liveStore.nextLaunch : null).kind
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

            MissionCard {
              required property var modelData
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
            }
          }
        }

        // 5. Upcoming list
        Column {
          width: parent.width
          spacing: Style.space(8)

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
              if (!root.upcomingSectionExpanded || !liveStore || !liveStore.upcoming)
                return []
              return liveStore.upcoming.slice(0, 5)
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
                  return "NET " + liveStore.formatNetShort(modelData.net) + " UTC"
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
                  return liveStore.formatNetShort(modelData.net) + " UTC"
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

        Text {
          width: parent.width
          text: "Launch data: The Space Devs (LL2) · Unofficial"
          wrapMode: Text.WordWrap
          color: root.contentForeground
          opacity: 0.32
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          width: parent.width
          text: {
            var sticky = liveStore && liveStore.stickyWatch
            var base = "Esc closes · Space play/pause · W watch · D detail · M mute · O open original · S stop Watch"
            if (sticky)
              base += " · stickyWatch: Esc keeps playback (best-effort; verify on live Omarchy)"
            else
              base += " · Watch embeds when yt-dlp resolves (YouTube/HLS); X → Open original"
            return base
          }
          wrapMode: Text.WordWrap
          color: root.contentForeground
          opacity: 0.28
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
        } // Column
      } // Flickable
    }
  }
}
