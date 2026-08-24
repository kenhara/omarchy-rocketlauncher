import QtQuick
import Quickshell
import Quickshell.Io

// Launch Library 2 client + cache for Rocketlauncher.
// Pure QML + Qt network (XMLHttpRequest). No elevated privilege.
//
// Refresh budget: default 30–60 min (schema knob, min 600s). Free tier is
// 15 req/hour — we use mode=list and at most 3 GETs per refresh cycle.
Item {
  id: store

  // Injected / configurable
  property int refreshIntervalSec: 1800
  property bool panelOpen: false
  // Schema knobs (injected from BarWidget / settings)
  property bool notifyMilestones: false
  property bool barShowMissionName: false
  property bool stickyWatch: false
  property string watchQuality: "best"   // best | 720 | 480 → stream-proxy.py
  property bool starfieldEnabled: true
  property bool flipAnimate: true

  readonly property string apiBase: "https://ll.thespacedevs.com/2.3.0"
  readonly property int agencyId: 121
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/rocketlauncher"
  readonly property string cachePath: cacheDir + "/cache.json"
  readonly property string pluginDir: String(Qt.resolvedUrl("."))
    .replace(/^file:\/\//, "")
    .replace(/\/$/, "")
  readonly property string samplePath: pluginDir + "/data/sample-cache.json"

  readonly property string pluginVersion: "1.5.8"
  readonly property string userAgent: "Rocketlauncher/" + pluginVersion + " (Omarchy unofficial; kenhara.rocketlauncher)"


  property var stats: ({
    total_launches: 0,
    successful_landings: 0,
    pending_launches: 0,
    consecutive_successful_launches: 0
  })
  // Flat ints for FlipCounter bindings (nested var fields don't always notify)
  property int statTotalLaunches: 0
  property int statSuccessfulLandings: 0
  property int statPendingLaunches: 0
  property int statConsecutiveSuccessfulLaunches: 0
  property var nextLaunch: null
  property var upcoming: []
  property var past: []
  property bool pastLoaded: false
  property bool pastLoading: false
  property var ongoing: []
  property string fetchedAt: ""
  property string dataSource: "none"   // sample | disk | network
  property bool loading: false
  property string lastError: ""
  property double nowMs: Date.now()

  // Mission detail cache (id → slim detail). Only fetched for next/selected.
  property var launchDetails: ({})
  property string selectedLaunchId: ""
  property bool detailLoading: false
  property string detailLoadingId: ""
  property string pendingDetailId: ""
  property bool pendingDetailExpand: true
  property bool detailExpanded: false
  // H2: right-click Watch before list-mode detail has vid_urls.
  property bool pendingWatchAfterDetail: false
  property string pendingWatchLaunchId: ""

  // In-panel Watch (Normarchy: yt-dlp → localhost → Qt Multimedia)
  property bool watching: false
  property string watchUrl: ""
  property string watchStreamUrl: ""
  property string watchFeatureImage: ""
  property string watchStatus: "idle"   // idle | resolving | playing | fallback | error
  property bool watchMuted: false
  property int watchProxyPid: 0
  // Set when panel hides mid-Watch (stickyWatch false) — player paused / proxy stopped; no auto-resume.
  property bool watchPausedByHide: false
  // stickyWatch true: panel closed but MediaPlayer + proxy still running.
  property bool watchStickyBackground: false
  // Debounce notify-send per launch id: { id: { t10: true, t0: true } }
  property var notifiedMilestones: ({})
  property int prevCountdownSec: 999999999

  readonly property string countdownText: formatCountdown(nextLaunch)
  readonly property string lastUpdatedText: formatUpdated(fetchedAt)
  // Inline binding so QML tracks stickyWatch / watching / mission / countdown.
  readonly property string barLabel: {
    var cd = store.countdownText.length ? store.countdownText : "NET —"
    var parts = []
    if (store.stickyWatch && store.watching)
      parts.push("▶")
    if (store.barShowMissionName && store.nextLaunch) {
      var mn = String(store.nextLaunch.mission_name || store.nextLaunch.name || "")
      if (mn.length > 18)
        mn = mn.substring(0, 16) + "…"
      if (mn.length)
        parts.push(mn)
    }
    parts.push(cd)
    return parts.join(" ")
  }


  onPanelOpenChanged: {
    if (!store.panelOpen)
      store.pauseWatchOnHide()
    else if (store.watchStickyBackground)
      store.watchStickyBackground = false
  }

  function settingRefresh(sec) {
    var n = Number(sec)
    if (!isFinite(n)) n = 1800
    store.refreshIntervalSec = Math.max(600, Math.min(86400, Math.round(n)))
    refreshTimer.interval = store.refreshIntervalSec * 1000
  }

  function applySettings(opts) {
    opts = opts || {}
    if (opts.refreshIntervalSec !== undefined)
      store.settingRefresh(opts.refreshIntervalSec)
    if (opts.notifyMilestones !== undefined)
      store.notifyMilestones = !!opts.notifyMilestones
    if (opts.barShowMissionName !== undefined)
      store.barShowMissionName = !!opts.barShowMissionName
    if (opts.stickyWatch !== undefined)
      store.stickyWatch = !!opts.stickyWatch
    if (opts.watchQuality !== undefined)
      store.watchQuality = store.normalizeWatchQuality(opts.watchQuality)
    if (opts.starfieldEnabled !== undefined)
      store.starfieldEnabled = !!opts.starfieldEnabled
    if (opts.flipAnimate !== undefined)
      store.flipAnimate = !!opts.flipAnimate
    store.syncIdleInhibit()
  }

  function normalizeWatchQuality(q) {
    var s = String(q || "best").toLowerCase().replace(/p$/, "")
    if (s === "720" || s === "480") return s
    return "best"
  }


  function parseName(name) {
    name = String(name || "")
    var idx = name.indexOf("|")
    if (idx < 0) return { vehicle: name, mission: name }
    return {
      vehicle: name.substring(0, idx).trim(),
      mission: name.substring(idx + 1).trim()
    }
  }

  function slimLaunch(item) {
    if (!item) return null
    var status = item.status || {}
    var img = item.image || {}
    var netP = item.net_precision || {}
    var parts = parseName(item.name)
    var vids = []
    var rawVids = item.vid_urls || []
    for (var i = 0; i < rawVids.length; i++) {
      var v = rawVids[i] || {}
      var t = v.type
      var tname = (t && typeof t === "object") ? (t.name || "") : String(t || "")
      vids.push({
        url: v.url || "",
        source: v.source || "",
        publisher: v.publisher || "",
        type: tname,
        priority: v.priority || 0,
        feature_image: v.feature_image || ""
      })
    }
    return {
      id: item.id || "",
      name: item.name || "",
      mission_name: item.mission_name || parts.mission,
      vehicle: item.vehicle || parts.vehicle,
      status_id: status.id !== undefined ? status.id : (item.status_id || 0),
      status: status.name || item.status || "",
      status_abbrev: status.abbrev || item.status_abbrev || "",
      net: item.net || "",
      window_start: item.window_start || "",
      window_end: item.window_end || "",
      net_precision: (typeof netP === "object" ? (netP.name || "") : String(netP || "")),
      image_url: img.image_url || item.image_url || "",
      thumbnail_url: img.thumbnail_url || item.thumbnail_url || "",
      webcast_live: !!(item.webcast_live),
      vid_urls: vids
    }
  }

  function slimOngoing(item) {
    if (!item) return null
    var cfg = item.spacecraft_config || {}
    var img = item.image || {}
    var st = item.status || {}
    return {
      id: item.id || 0,
      name: item.name || "",
      serial: item.serial_number || item.serial || "",
      config: cfg.name || item.config || "",
      in_space: !!(item.in_space),
      time_in_space: item.time_in_space || "",
      time_docked: item.time_docked || "",
      image_url: img.image_url || item.image_url || "",
      status: st.name || item.status || ""
    }
  }

  function detailFor(id) {
    if (!id) return null
    var d = store.launchDetails[id]
    return d || null
  }

  function selectedDetail() {
    var id = store.selectedLaunchId || (store.nextLaunch ? store.nextLaunch.id : "")
    return store.detailFor(id)
  }

  function featureImageFor(launch) {
    if (!launch) return ""
    var vids = launch.vid_urls || []
    for (var i = 0; i < vids.length; i++) {
      if (vids[i] && vids[i].feature_image)
        return vids[i].feature_image
    }
    return launch.image_url || launch.thumbnail_url || ""
  }

  function slimCrewMember(c) {
    if (!c) return null
    // Already-slim sample / cache rows
    if (!c.astronaut && (c.name || c.wiki_url || c.image_url)) {
      return {
        name: c.name || "",
        role: c.role || "",
        agency: c.agency || "",
        image_url: c.image_url || "",
        wiki_url: c.wiki_url || "",
        url: c.url || ""
      }
    }
    var a = c.astronaut || {}
    var role = c.role || {}
    var img = a.image || {}
    var ag = a.agency || {}
    var roleName = (typeof role === "object") ? (role.role || "") : String(role || "")
    // Prefer Wikipedia, else LL2 astronaut page
    var wiki = a.wiki || a.wiki_url || c.wiki_url || ""
    var astrUrl = a.url || c.url || ""
    return {
      name: a.name || "",
      role: roleName,
      agency: ag.abbrev || ag.name || "",
      image_url: img.image_url || img.thumbnail_url || "",
      wiki_url: wiki,
      url: astrUrl
    }
  }

  function slimDetail(item) {
    if (!item) return null
    var mission = item.mission || {}
    var orbit = mission.orbit || {}
    var pad = item.pad || {}
    var loc = pad.location || {}
    var rocket = item.rocket || {}
    var cfg = rocket.configuration || {}
    var parts = parseName(item.name)
    var stages = rocket.spacecraft_stage || []
    var stage = stages.length ? stages[0] : null
    var sc = stage ? (stage.spacecraft || {}) : {}
    var crew = []
    if (stage) {
      var rawCrew = []
      var lc = stage.launch_crew || []
      var oc = stage.onboard_crew || []
      // Prefer launch_crew; fall back to onboard_crew; merge uniquely by name.
      var seen = ({})
      var src = lc.length ? lc : oc
      if (lc.length && oc.length) {
        src = lc.slice()
        for (var oi = 0; oi < oc.length; oi++) src.push(oc[oi])
      }
      for (var i = 0; i < src.length; i++) {
        var m = slimCrewMember(src[i])
        if (!m || !m.name) continue
        if (seen[m.name]) continue
        seen[m.name] = true
        crew.push(m)
      }
    }
    var landingSummary = ""
    var boosterSerial = ""
    var boosterFlight = 0
    var lstages = rocket.launcher_stage || []
    if (lstages.length) {
      var ls = lstages[0] || {}
      var land = ls.landing || {}
      var lt = land.type || {}
      var ll = land.landing_location || {}
      var launcher = ls.launcher || {}
      var bits = []
      var tname = lt.abbrev || lt.name || ""
      var lname = ll.name || ll.abbrev || ""
      if (tname) bits.push(tname)
      if (lname) bits.push(lname)
      landingSummary = bits.join(" | ")
      boosterSerial = launcher.serial_number || ""
      boosterFlight = Number(ls.launcher_flight_number) || 0
    }
    var patches = item.mission_patches || []
    var patchUrl = ""
    if (patches.length) {
      var bestP = patches[0]
      var bestPri = Number(bestP.priority) || 0
      for (var p = 1; p < patches.length; p++) {
        var pri = Number(patches[p].priority) || 0
        if (pri >= bestPri) { bestPri = pri; bestP = patches[p] }
      }
      patchUrl = bestP.image_url || ""
    }
    var img = item.image || {}
    var base = slimLaunch(item) || {}
    return {
      id: item.id || base.id || "",
      name: item.name || base.name || "",
      mission_name: mission.name || base.mission_name || parts.mission,
      mission_type: mission.type || item.mission_type || "",
      description: mission.description || item.description || "",
      orbit: orbit.abbrev || orbit.name || item.orbit || "",
      vehicle: cfg.full_name || cfg.name || base.vehicle || parts.vehicle,
      pad_name: pad.name || item.pad_name || "",
      location_name: loc.name || item.location_name || "",
      landing_summary: landingSummary || item.landing_summary || "",
      booster_serial: boosterSerial || item.booster_serial || "",
      booster_flight: boosterFlight || item.booster_flight || 0,
      patch_url: patchUrl || item.patch_url || "",
      image_url: img.image_url || base.image_url || "",
      thumbnail_url: img.thumbnail_url || base.thumbnail_url || "",
      webcast_live: !!(item.webcast_live),
      vid_urls: base.vid_urls || [],
      crew: crew.length ? crew : (item.crew || []),
      spacecraft_name: sc.name || item.spacecraft_name || "",
      spacecraft_serial: sc.serial_number || item.spacecraft_serial || "",
      status_id: base.status_id,
      status: base.status,
      status_abbrev: base.status_abbrev,
      net: base.net,
      window_start: base.window_start,
      window_end: base.window_end,
      net_precision: base.net_precision,
      detailed_at: item.detailed_at || (new Date()).toISOString()
    }
  }

  function rememberDetail(detail) {
    if (!detail || !detail.id) return
    var cache = {}
    var keys = Object.keys(store.launchDetails || {})
    for (var i = 0; i < keys.length; i++)
      cache[keys[i]] = store.launchDetails[keys[i]]
    cache[detail.id] = detail
    store.launchDetails = cache
  }

  function mergeDetailOntoLaunch(launch, detail) {
    if (!launch || !detail) return launch
    var out = {}
    var k
    for (k in launch) out[k] = launch[k]
    var fields = [
      "mission_type", "description", "orbit", "pad_name", "location_name",
      "landing_summary", "booster_serial", "booster_flight", "patch_url",
      "crew", "spacecraft_name", "spacecraft_serial", "detailed_at", "vehicle"
    ]
    for (var i = 0; i < fields.length; i++) {
      var f = fields[i]
      if (detail[f] !== undefined && detail[f] !== null && detail[f] !== "")
        out[f] = detail[f]
    }
    if (detail.crew && detail.crew.length)
      out.crew = detail.crew
    if (detail.vid_urls && detail.vid_urls.length)
      out.vid_urls = detail.vid_urls
    if (detail.image_url)
      out.image_url = detail.image_url
    return out
  }

  function pickNext(list) {
    var now = Date.now()
    var i, L, netMs
    // Prefer Go / TBD / Hold with a future (or near) NET
    for (i = 0; i < list.length; i++) {
      L = list[i]
      if (!L) continue
      if (L.status_id === 1 || L.status_id === 2 || L.status_abbrev === "Go" || L.status_abbrev === "TBD") {
        netMs = Date.parse(L.net || "")
        if (!isFinite(netMs) || netMs + 3600000 >= now)
          return L
      }
    }
    for (i = 0; i < list.length; i++) {
      L = list[i]
      if (!L) continue
      netMs = Date.parse(L.net || "")
      if (isFinite(netMs) && netMs >= now - 600000)
        return L
    }
    return list.length ? list[0] : null
  }

  function applyPayload(obj, source) {
    if (!obj || typeof obj !== "object") return false
    var s = obj.stats || {}
    store.stats = {
      total_launches: Number(s.total_launches) || 0,
      successful_launches: Number(s.successful_launches) || 0,
      failed_launches: Number(s.failed_launches) || 0,
      pending_launches: Number(s.pending_launches) || 0,
      attempted_landings: Number(s.attempted_landings) || 0,
      successful_landings: Number(s.successful_landings) || 0,
      failed_landings: Number(s.failed_landings) || 0,
      consecutive_successful_launches: Number(s.consecutive_successful_launches) || 0,
      consecutive_successful_landings: Number(s.consecutive_successful_landings) || 0
    }
    store.statTotalLaunches = store.stats.total_launches
    store.statSuccessfulLandings = store.stats.successful_landings
    store.statPendingLaunches = store.stats.pending_launches
    store.statConsecutiveSuccessfulLaunches = store.stats.consecutive_successful_launches
    var up = []
    var rawUp = obj.upcoming || []
    for (var i = 0; i < rawUp.length; i++)
      up.push(slimLaunch(rawUp[i]))
    store.upcoming = up
    var past = []
    var rawPast = obj.past || obj.previous || []
    for (var pi = 0; pi < rawPast.length; pi++)
      past.push(slimLaunch(rawPast[pi]))
    if (past.length) {
      store.past = past
      store.pastLoaded = true
    }
    var next = slimLaunch(obj.next_launch) || pickNext(up)
    // Ingest bundled / cached detail map
    if (obj.details && typeof obj.details === "object") {
      var dkeys = Object.keys(obj.details)
      for (var di = 0; di < dkeys.length; di++) {
        var rawD = obj.details[dkeys[di]]
        var sd = rawD && rawD.detailed_at && (rawD.description !== undefined || rawD.pad_name !== undefined)
          ? rawD
          : slimDetail(rawD)
        if (sd) rememberDetail(sd)
      }
    }
    // next_launch may already carry slim detail fields (sample)
    if (obj.next_launch && (obj.next_launch.detailed_at || obj.next_launch.description || obj.next_launch.pad_name)) {
      var nd = slimDetail(obj.next_launch)
      if (!nd && obj.next_launch.id) {
        nd = obj.next_launch
      }
      if (nd) {
        if (!nd.detailed_at) nd.detailed_at = (new Date()).toISOString()
        rememberDetail(nd)
      }
    }
    if (next && next.id && store.launchDetails[next.id])
      next = mergeDetailOntoLaunch(next, store.launchDetails[next.id])
    store.nextLaunch = next
    var on = []
    var rawOn = obj.ongoing || []
    for (var j = 0; j < rawOn.length; j++)
      on.push(slimOngoing(rawOn[j]))
    store.ongoing = on
    store.fetchedAt = (obj.meta && obj.meta.fetched_at) ? obj.meta.fetched_at : (new Date()).toISOString()
    store.dataSource = source || "unknown"
    store.lastError = ""
    if (obj.notified_milestones && typeof obj.notified_milestones === "object")
      store.notifiedMilestones = obj.notified_milestones
    return true
  }

  function buildCacheObject() {
    return {
      meta: {
        schema_version: 1,
        source: "ll2",
        fetched_at: store.fetchedAt || (new Date()).toISOString(),
        agency_id: store.agencyId,
        bundled_sample: false
      },
      stats: store.stats,
      next_launch: store.nextLaunch,
      upcoming: store.upcoming,
      past: store.past,
      ongoing: store.ongoing,
      details: store.launchDetails,
      notified_milestones: store.notifiedMilestones || ({})
    }
  }

  function officialWebcast(launch) {
    if (!launch) return ""
    var vids = launch.vid_urls || []
    var best = ""
    var bestPri = -1
    for (var i = 0; i < vids.length; i++) {
      var v = vids[i] || {}
      var t = String(v.type || "")
      var pri = Number(v.priority) || 0
      if (t.indexOf("Official") >= 0 && v.url)
        return v.url
      if (v.url && pri >= bestPri) {
        bestPri = pri
        best = v.url
      }
    }
    return best
  }

  function isYoutubeUrl(url) {
    var u = String(url || "").toLowerCase()
    return u.indexOf("youtube.com") >= 0 || u.indexOf("youtu.be") >= 0
  }

  function isXBroadcastUrl(url) {
    var u = String(url || "").toLowerCase()
    return u.indexOf("x.com/") >= 0 || u.indexOf("twitter.com/") >= 0
  }

  function isHlsUrl(url) {
    // Path/extension .m3u8 only (not substring match on query).
    var u = String(url || "").split("?")[0].split("#")[0].toLowerCase()
    return u.length >= 5 && u.substring(u.length - 5) === ".m3u8"
  }

  function sanitizeOpenUrl(url) {
    var u = String(url || "").trim()
    if (!u.length) return ""
    // Remote / webcast / wiki links — https only (no javascript:/file: surprises).
    if (u.toLowerCase().indexOf("https://") !== 0) return ""
    return u
  }

  function openUrlExternal(url) {
    var u = store.sanitizeOpenUrl(url)
    if (!u.length) {
      store.notifySend("Rocketlauncher", String(url || "").trim().length ? "Refused — https only" : "No URL")
      return false
    }
    try {
      var ok = Qt.openUrlExternally(u)
      if (ok !== false) {
        store.notifySend("Rocketlauncher", "Opened")
        return true
      }
    } catch (e) {}
    openUrlProc.command = ["xdg-open", u]
    openUrlProc.running = true
    return true
  }

  function pauseWatchOnHide() {
    // stickyWatch: Esc/hide keeps MediaPlayer + stream-proxy; bar can show ▶.
    if (store.stickyWatch && (store.watching || store.watchStreamUrl.length > 0 || store.watchStatus === "resolving")) {
      store.watchStickyBackground = true
      store.watchPausedByHide = false
      store.syncIdleInhibit()
      return
    }
    // Default: pause MediaPlayer (clear stream) and stop proxy.
    // Do not auto-resume when the panel reopens — user must press Watch / Play.
    store.watchStickyBackground = false
    store.watchPausedByHide = store.watching || store.watchStreamUrl.length > 0
    stopStreamProxy()
    store.watchStreamUrl = ""
    if (store.watching || store.watchStatus !== "idle") {
      store.watching = false
      store.watchStatus = "idle"
      store.watchUrl = ""
      store.watchFeatureImage = ""
    }
    store.syncIdleInhibit()
  }

  function closeWatch() {
    store.watching = false
    store.watchStatus = "idle"
    store.watchStreamUrl = ""
    store.watchUrl = ""
    store.watchFeatureImage = ""
    store.watchPausedByHide = false
    store.watchStickyBackground = false
    stopStreamProxy()
    store.syncIdleInhibit()
  }

  // Optional: systemd-inhibit --what=idle while stickyWatch is actively playing.
  // No privilege; hypridle honors it unless ignore_systemd_inhibit=true. No hyprctl dispatcher.
  function syncIdleInhibit() {
    var want = !!(store.stickyWatch && store.watching
      && (store.watchStatus === "playing" || store.watchStatus === "resolving"
          || store.watchStickyBackground))
    try {
      if (want) {
        if (!idleInhibit.running) {
          idleInhibit.command = [
            "systemd-inhibit",
            "--what=idle",
            "--who=Rocketlauncher",
            "--why=Watch playing (stickyWatch)",
            "--mode=block",
            "sleep", "infinity"
          ]
          idleInhibit.running = true
        }
      } else if (idleInhibit.running) {
        idleInhibit.running = false
      }
    } catch (e) {}
  }

  function toggleWatchMute() {
    store.watchMuted = !store.watchMuted
  }

  function notifySend(title, body) {
    try {
      notifyProc.command = [
        "notify-send",
        "-a", "Rocketlauncher",
        "-u", "normal",
        String(title || "Rocketlauncher"),
        String(body || "")
      ]
      notifyProc.running = true
    } catch (e) {}
  }

  function markNotified(id, key) {
    id = String(id || "")
    if (!id) return
    var map = store.notifiedMilestones || ({})
    var row = map[id] || ({})
    row[key] = true
    map[id] = row
    // Reassign for QML change tracking
    store.notifiedMilestones = map
    persistToDisk()
  }

  function wasNotified(id, key) {
    var map = store.notifiedMilestones || ({})
    var row = map[String(id || "")] || ({})
    return !!row[key]
  }

  function tickMilestones() {
    if (!store.notifyMilestones) {
      // Still track prev so enabling mid-countdown does not spam immediately
      var L0 = store.nextLaunch
      if (L0 && L0.net) {
        var n0 = Date.parse(L0.net)
        if (isFinite(n0))
          store.prevCountdownSec = Math.floor((n0 - store.nowMs) / 1000)
      }
      return
    }
    var L = store.nextLaunch
    if (!L || !L.id || !L.net) return
    var netMs = Date.parse(L.net)
    if (!isFinite(netMs)) return
    var delta = Math.floor((netMs - store.nowMs) / 1000)
    var prev = store.prevCountdownSec
    var mission = L.mission_name || L.name || "Launch"
    // Cross T−10 (600s): was above 10 min, now at/under 10 min but still pre-liftoff
    if (prev > 600 && delta <= 600 && delta > 0 && !store.wasNotified(L.id, "t10")) {
      store.markNotified(L.id, "t10")
      store.notifySend("T−10: " + mission, "Rocketlauncher · NET in about 10 minutes")
    }
    // Cross T−0: was positive, now ≤ 0 (liftoff window)
    if (prev > 0 && delta <= 0 && delta > -3600 && !store.wasNotified(L.id, "t0")) {
      store.markNotified(L.id, "t0")
      store.notifySend("T−0: " + mission, "Rocketlauncher · liftoff window")
    }
    store.prevCountdownSec = delta
  }

  function stopStreamProxy() {
    resolveTimer.stop()
    if (streamProxy.running)
      streamProxy.running = false
    store.watchProxyPid = 0
  }

  function startStreamProxy(url) {
    stopStreamProxy()
    store.watchStatus = "resolving"
    store.watchStreamUrl = ""
    var script = store.pluginDir + "/scripts/stream-proxy.py"
    var q = store.normalizeWatchQuality(store.watchQuality)
    streamProxy.command = ["python3", script, url, "--timeout", "180", "--quality", q]
    streamProxyStdout = ""
    streamProxy.running = true
    resolveTimer.restart()
    store.syncIdleInhibit()
  }

  property string streamProxyStdout: ""

  function onStreamProxyLine(line) {
    line = String(line || "").trim()
    if (!line) return
    if (line.indexOf("READY ") === 0) {
      resolveTimer.stop()
      store.watchStreamUrl = line.substring(6).trim()
      store.watchStatus = "playing"
      store.watching = true
      store.syncIdleInhibit()
      return
    }
    if (line.indexOf("DIRECT ") === 0) {
      resolveTimer.stop()
      store.watchStreamUrl = line.substring(7).trim()
      store.watchStatus = "playing"
      store.watching = true
      store.syncIdleInhibit()
      return
    }
    if (line.indexOf("ERROR ") === 0) {
      resolveTimer.stop()
      // Honest degrade — especially for X broadcasts
      store.watchStreamUrl = ""
      store.watchStatus = "fallback"
      store.watching = true
      return
    }
  }

  function openWatch(launch) {
    var L = launch || store.nextLaunch
    if (!L) return false
    var url = officialWebcast(L)
    // H2: list mode often omits vid_urls — fetch detail, then start Watch.
    if (!url) {
      if (L.id) {
        store.pendingWatchAfterDetail = true
        store.pendingWatchLaunchId = String(L.id)
        store.watching = true
        store.watchStatus = "resolving"
        store.watchFeatureImage = featureImageFor(L)
        store.fetchLaunchDetail(L.id, { expand: store.panelOpen })
        return true
      }
      return false
    }

    store.pendingWatchAfterDetail = false
    store.pendingWatchLaunchId = ""
    store.watchPausedByHide = false
    store.watchUrl = url
    store.watchFeatureImage = featureImageFor(L)
    store.watching = true
    store.watchMuted = false

    // Prefer in-panel player for YouTube / HLS / yt-dlp-capable URLs.
    // X broadcasts: try yt-dlp, then degrade to feature_image + Open original.
    // Never claim X always works.
    if (isHlsUrl(url)) {
      store.watchStreamUrl = url
      store.watchStatus = "playing"
      store.syncIdleInhibit()
      return true
    }
    if (isYoutubeUrl(url) || isXBroadcastUrl(url)) {
      startStreamProxy(url)
      return true
    }
    // Other hosts — attempt yt-dlp once; if that fails, external open.
    startStreamProxy(url)
    return true
  }

  function openWatchOriginal() {
    var url = store.watchUrl
    if (!url && store.nextLaunch)
      url = store.officialWebcast(store.nextLaunch)
    return openUrlExternal(url)
  }

  // Right-click bar: start in-panel Watch; if no webcast URL yet, openWatch
  // queues a detail fetch (H2) and starts Watch when vid_urls arrive.
  function openWatchForNextOrOriginal() {
    var L = store.nextLaunch
    if (!L) return false
    var url = store.officialWebcast(L)
    if (!url && store.watchUrl)
      return store.openUrlExternal(store.watchUrl)
    return store.openWatch(L)
  }

  property string trackedLaunchId: ""

  onNextLaunchChanged: {
    var id = store.nextLaunch && store.nextLaunch.id ? String(store.nextLaunch.id) : ""
    if (id !== store.trackedLaunchId) {
      store.trackedLaunchId = id
      // New mission id → allow fresh T−10 / T−0 toasts; reset edge tracker.
      store.prevCountdownSec = 999999999
    }
  }

  function ensureNextDetail() {
    var n = store.nextLaunch
    if (!n || !n.id) return false
    store.detailExpanded = true
    return fetchLaunchDetail(n.id, { expand: true })
  }

  function applyDetailToLists(id, detail) {
    if (store.nextLaunch && store.nextLaunch.id === id)
      store.nextLaunch = mergeDetailOntoLaunch(store.nextLaunch, detail)
    var up = []
    for (var i = 0; i < store.upcoming.length; i++) {
      var row = store.upcoming[i]
      if (row && row.id === id)
        up.push(mergeDetailOntoLaunch(row, detail))
      else
        up.push(row)
    }
    store.upcoming = up
    var pastRows = []
    for (var pi = 0; pi < store.past.length; pi++) {
      var prow = store.past[pi]
      if (prow && prow.id === id)
        pastRows.push(mergeDetailOntoLaunch(prow, detail))
      else
        pastRows.push(prow)
    }
    store.past = pastRows
  }

  function maybeStartPendingWatch(id) {
    if (!store.pendingWatchAfterDetail) return
    if (String(store.pendingWatchLaunchId) !== String(id)) return
    store.pendingWatchAfterDetail = false
    store.pendingWatchLaunchId = ""
    var L = null
    if (store.nextLaunch && store.nextLaunch.id === id)
      L = store.nextLaunch
    else {
      for (var i = 0; i < store.upcoming.length; i++) {
        if (store.upcoming[i] && store.upcoming[i].id === id) {
          L = store.upcoming[i]
          break
        }
      }
    }
    if (!L)
      L = store.detailFor(id)
    if (L && officialWebcast(L))
      store.openWatch(L)
    else {
      store.watchStatus = "fallback"
      store.watching = true
    }
  }

  function drainPendingDetail() {
    var pid = store.pendingDetailId
    if (!pid) return
    var expand = store.pendingDetailExpand
    store.pendingDetailId = ""
    store.fetchLaunchDetail(pid, { expand: expand })
  }

  // opts.expand (default true): update selectedLaunchId / detailExpanded for UI.
  // Quiet eager fetches pass { expand: false }.
  function fetchLaunchDetail(id, opts) {
    id = String(id || "")
    if (!id) return false
    opts = opts || {}
    var expand = opts.expand !== false

    var cached = store.launchDetails[id]
    if (cached && cached.detailed_at && (cached.description || cached.pad_name || cached.landing_summary || (cached.crew && cached.crew.length) || (cached.vid_urls && cached.vid_urls.length))) {
      if (expand) {
        store.selectedLaunchId = id
        store.detailExpanded = true
      }
      store.applyDetailToLists(id, cached)
        store.maybeStartPendingWatch(id)
      return true
    }

    // M3: guard detailLoading BEFORE mutating selection; queue if busy.
    if (store.detailLoading) {
      store.pendingDetailId = id
      store.pendingDetailExpand = expand
      if (expand) {
        store.selectedLaunchId = id
        store.detailExpanded = true
      }
      return false
    }

    if (expand) {
      store.selectedLaunchId = id
      store.detailExpanded = true
    }
    store.detailLoading = true
    store.detailLoadingId = id
    // One detailed GET per id — free tier ≤15/h; list polls stay on mode=list.
    httpGet(store.apiBase + "/launches/" + id + "/", function(ok, body) {
      store.detailLoading = false
      store.detailLoadingId = ""
      if (!ok) {
        store.lastError = "detail fetch failed"
        // Offline / rate-limit: keep any partial fields already on the launch
            store.maybeStartPendingWatch(id)
        store.drainPendingDetail()
        return
      }
      try {
        var raw = JSON.parse(body)
        var detail = slimDetail(raw)
        if (!detail) {
          store.lastError = "detail parse empty"
          store.drainPendingDetail()
          return
        }
        rememberDetail(detail)
        store.applyDetailToLists(id, detail)
            persistToDisk()
        store.maybeStartPendingWatch(id)
      } catch (e) {
        store.lastError = "detail parse failed"
      }
      store.drainPendingDetail()
    })
    return true
  }

  function formatCountdown(launch) {
    if (!launch || !launch.net) return ""
    var netMs = Date.parse(launch.net)
    if (!isFinite(netMs)) return ""
    var precision = String(launch.net_precision || "").toLowerCase()
    // Fuzzy NET when precision is coarse
    if (precision.indexOf("day") >= 0 || precision.indexOf("month") >= 0 || precision.indexOf("year") >= 0)
      return "NET " + formatNetShort(launch.net) + " UTC"
    var delta = Math.floor((netMs - store.nowMs) / 1000)
    if (delta < -3600) return "NET " + formatNetShort(launch.net) + " UTC"
    if (delta < 0) return "T+" + formatHMS(-delta)
    return "T-" + formatHMS(delta)
  }

  function formatHMS(totalSec) {
    var s = Math.max(0, Math.floor(totalSec))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var sec = s % 60
    function pad(n) { return (n < 10 ? "0" : "") + n }
    if (h > 99) return pad(h) + ":" + pad(m)
    return pad(h) + ":" + pad(m) + ":" + pad(sec)
  }

  // NET calendar day in UTC (callers may append " UTC"; countdown uses this for fuzzy NET).
  function formatNetShort(iso) {
    var d = new Date(iso)
    if (isNaN(d.getTime())) return "—"
    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    return months[d.getUTCMonth()] + " " + d.getUTCDate()
  }

  function formatUpdated(iso) {
    if (!iso) return "never"
    var d = new Date(iso)
    if (isNaN(d.getTime())) return iso
    return d.toISOString().replace("T", " ").replace(/\.\d+Z$/, " UTC")
  }

  function formatIsoDuration(isoDur) {
    // P563DT6H4M44S → "563d 6h"
    var s = String(isoDur || "")
    var m = s.match(/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/)
    if (!m) return s || "—"
    var days = Number(m[1] || 0)
    var hours = Number(m[2] || 0)
    if (days > 0) return days + "d " + hours + "h"
    var mins = Number(m[3] || 0)
    if (hours > 0) return hours + "h " + mins + "m"
    return mins + "m"
  }

  function statusBadge(launch) {
    if (!launch) return { text: "—", kind: "muted" }
    var a = String(launch.status_abbrev || "")
    var n = String(launch.status || "")
    if (launch.webcast_live) return { text: "LIVE", kind: "live" }
    if (a === "Go" || launch.status_id === 1) return { text: "Go", kind: "go" }
    if (a === "TBD" || launch.status_id === 2) return { text: "TBD", kind: "tbd" }
    if (a === "Success" || launch.status_id === 3) return { text: "OK", kind: "ok" }
    if (a) return { text: a, kind: "muted" }
    return { text: n ? n.split(" ")[0] : "—", kind: "muted" }
  }

  // --- IO helpers ----------------------------------------------------------

  function loadSampleText(text) {
    try {
      var obj = JSON.parse(text || "{}")
      return applyPayload(obj, "sample")
    } catch (e) {
      store.lastError = "sample parse failed"
      return false
    }
  }

  function loadDiskText(text) {
    try {
      var obj = JSON.parse(text || "{}")
      return applyPayload(obj, "disk")
    } catch (e) {
      return false
    }
  }

  function persistToDisk() {
    // FileView.setText mkpath — no mkdir Process + Qt.callLater race.
    var body = JSON.stringify(buildCacheObject(), null, 2) + "\n"
    try {
      cacheFile.setText(body)
    } catch (e) {
      // Disk may be unwritable — stay on sample / memory.
    }
  }

  function bootstrap() {
    // Prefer disk cache if present; else bundled sample; then network refresh.
    cacheFile.reload()
  }

  function onCacheLoaded(text) {
    if (text && text.length > 2 && loadDiskText(text)) {
      maybeRefreshNetwork()
      return
    }
    sampleFile.reload()
  }

  function onSampleLoaded(text) {
    loadSampleText(text || "")
    maybeRefreshNetwork()
  }

  function maybeRefreshNetwork() {
    // Always schedule; fetch immediately if we only have sample or stale disk.
    var ageMs = 0
    if (store.fetchedAt) {
      var t = Date.parse(store.fetchedAt)
      if (isFinite(t)) ageMs = Date.now() - t
    }
    var stale = !store.fetchedAt || ageMs > store.refreshIntervalSec * 1000
    if (stale || store.dataSource === "sample")
      refreshFromNetwork()
  }

  // Sequential fetch: agency → upcoming list → dragon in_space (≤3 calls)
  property int fetchStep: 0
  property var fetchAgency: null
  property var fetchUpcoming: null
  property var fetchDragon: null

  // Lazy-load previous launches on first Past Missions expand (saves free-tier quota).
  function ensurePastLaunches() {
    if (store.pastLoaded || store.pastLoading) return false
    // Bundled / disk sample already applied → mark loaded without a network hit.
    if (store.past && store.past.length > 0) {
      store.pastLoaded = true
        return true
    }
    store.pastLoading = true
    httpGet(store.apiBase + "/launches/previous/?lsp__id=" + store.agencyId + "&limit=5&mode=list", function(ok, body) {
      store.pastLoading = false
      if (!ok) {
        store.lastError = "past fetch failed"
            return
      }
      try {
        var raw = JSON.parse(body)
        var rows = raw.results || []
        var past = []
        for (var i = 0; i < rows.length; i++)
          past.push(slimLaunch(rows[i]))
        store.past = past
        store.pastLoaded = true
            persistToDisk()
      } catch (e) {
        store.lastError = "past parse failed"
          }
    })
    return true
  }

  function refreshFromNetwork() {
    if (store.loading) return
    store.loading = true
    store.lastError = ""
    store.fetchStep = 0
    store.fetchAgency = null
    store.fetchUpcoming = null
    store.fetchDragon = null
    httpGet(store.apiBase + "/agencies/" + store.agencyId + "/", function(ok, body) {
      if (!ok) {
        store.loading = false
        store.lastError = "agency fetch failed"
        return
      }
      try { store.fetchAgency = JSON.parse(body) } catch (e) {
        store.loading = false
        store.lastError = "agency parse failed"
        return
      }
      httpGet(store.apiBase + "/launches/upcoming/?lsp__id=" + store.agencyId + "&limit=5&mode=list", function(ok2, body2) {
        if (!ok2) {
          store.loading = false
          store.lastError = "upcoming fetch failed"
          return
        }
        try { store.fetchUpcoming = JSON.parse(body2) } catch (e2) {
          store.loading = false
          store.lastError = "upcoming parse failed"
          return
        }
        httpGet(store.apiBase + "/spacecraft/?search=Crew%20Dragon&in_space=true", function(ok3, body3) {
          store.loading = false
          if (ok3) {
            try { store.fetchDragon = JSON.parse(body3) } catch (e3) { store.fetchDragon = { results: [] } }
          } else {
            store.fetchDragon = { results: store.ongoing }
          }
          commitNetworkFetch()
        })
      })
    })
  }

  function commitNetworkFetch() {
    var a = store.fetchAgency || {}
    var upRaw = (store.fetchUpcoming && store.fetchUpcoming.results) ? store.fetchUpcoming.results : []
    var up = []
    for (var i = 0; i < upRaw.length; i++)
      up.push(slimLaunch(upRaw[i]))
    // Preserve webcast URLs from previous next launch when list mode omits them
    var prev = store.nextLaunch
    var next = pickNext(up)
    if (next && prev && next.id === prev.id && (!next.vid_urls || !next.vid_urls.length) && prev.vid_urls)
      next.vid_urls = prev.vid_urls
    var onRaw = (store.fetchDragon && store.fetchDragon.results) ? store.fetchDragon.results : []
    var on = []
    for (var j = 0; j < onRaw.length; j++)
      on.push(slimOngoing(onRaw[j]))
    var payload = {
      meta: {
        schema_version: 1,
        source: "ll2",
        fetched_at: (new Date()).toISOString(),
        agency_id: store.agencyId,
        bundled_sample: false
      },
      stats: {
        total_launches: a.total_launch_count || 0,
        successful_launches: a.successful_launches || 0,
        failed_launches: a.failed_launches || 0,
        pending_launches: a.pending_launches || 0,
        attempted_landings: a.attempted_landings || 0,
        successful_landings: a.successful_landings || 0,
        failed_landings: a.failed_landings || 0,
        consecutive_successful_launches: a.consecutive_successful_launches || 0,
        consecutive_successful_landings: a.consecutive_successful_landings || 0
      },
      next_launch: next,
      upcoming: up,
      ongoing: on
    }
    var prevId = store.nextLaunch && store.nextLaunch.id ? String(store.nextLaunch.id) : ""
    applyPayload(payload, "network")
    persistToDisk()
    // H2: eager soft-fetch next detail when id changes so Watch has vid_urls.
    var newId = store.nextLaunch && store.nextLaunch.id ? String(store.nextLaunch.id) : ""
    if (newId && newId !== prevId)
      store.fetchLaunchDetail(newId, { expand: false })
    else if (newId && (!store.nextLaunch.vid_urls || !store.nextLaunch.vid_urls.length)
             && !store.launchDetails[newId])
      store.fetchLaunchDetail(newId, { expand: false })
  }

  function httpGet(url, cb) {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      var ok = xhr.status >= 200 && xhr.status < 300
      cb(ok, xhr.responseText || "")
    }
    try {
      xhr.open("GET", url)
      xhr.setRequestHeader("Accept", "application/json")
      xhr.setRequestHeader("User-Agent", store.userAgent)
      xhr.send()
    } catch (e) {
      cb(false, "")
    }
  }

  Component.onCompleted: {
    store.nowMs = Date.now()
    bootstrap()
  }

  Timer {
    id: clockTimer
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      store.nowMs = Date.now()
      store.tickMilestones()
    }
  }

  Timer {
    id: refreshTimer
    interval: Math.max(600, store.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: store.refreshFromNetwork()
  }

  FileView {
    id: cacheFile
    path: store.cachePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: store.onCacheLoaded(text())
    onLoadFailed: sampleFile.reload()
  }

  FileView {
    id: sampleFile
    path: store.samplePath
    watchChanges: false
    printErrors: false
    onLoaded: store.onSampleLoaded(text())
    onLoadFailed: {
      store.lastError = "no sample cache"
      store.dataSource = "none"
    }
  }

  Process {
    id: openUrlProc
    running: false
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0)
        store.notifySend("Rocketlauncher", "Opened")
      else
        store.notifySend("Rocketlauncher", "Open failed")
    }
  }

  Process {
    id: notifyProc
    running: false
  }

  Process {
    id: idleInhibit
    running: false
  }

  Timer {
    id: resolveTimer
    interval: 25000
    repeat: false
    onTriggered: {
      if (store.watching && store.watchStatus === "resolving") {
        store.watchStatus = "fallback"
        store.watchStreamUrl = ""
      }
    }
  }

  Process {
    id: streamProxy
    running: false
    stdout: SplitParser {
      onRead: function(line) { store.onStreamProxyLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) {
        // yt-dlp may chatter on stderr; ignore unless still resolving with no READY
        var s = String(line || "")
        if (s.indexOf("ERROR") === 0)
          store.onStreamProxyLine(s)
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (store.watching && store.watchStatus === "resolving")
        store.watchStatus = "fallback"
    }
  }
}
