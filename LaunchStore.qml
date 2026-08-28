import QtQuick
import Quickshell
import Quickshell.Io

// Launch Library 2 client + cache for Rocketlauncher.
// Network + cache reads go through scripts/fetch-json.py (hard byte cap).
// Cache writes go through fetch-json.py --write (O_EXCL|O_NOFOLLOW); FileView is fallback only.
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
  property bool barShowCountdown: true
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

  readonly property string pluginVersion: "1.6.0"
  readonly property string userAgent: "Rocketlauncher/" + pluginVersion + " (Omarchy unofficial; kenhara.rocketlauncher)"

  readonly property int netByteCap: 1048576   // 1 MiB per LL2 response
  readonly property int netTimeoutSec: 20
  readonly property int cacheByteCap: 2097152  // 2 MiB
  readonly property int maxListRows: 25
  readonly property int maxDetails:  60
  readonly property int maxVids:     12
  readonly property int maxCrew:     16
  readonly property int maxStr:      4000
  readonly property int maxShortStr: 512
  readonly property int maxRecordBytes: 49152  // 48 KiB per slimmed row
  readonly property var helperEnv: ({
    "PYTHONDONTWRITEBYTECODE": "1",
    "PATH": "/usr/bin:/bin"
  })

  function clampStr(v, n) {
    var s = String(v == null ? "" : v)
    return s.length > n ? s.substring(0, n) : s
  }

  // Strip markup / controls at slim/apply so AutoText cannot revive them.
  function neutralizeText(v) {
    var s = String(v == null ? "" : v)
    s = s.replace(/!\[[^\]]*\]\([^)]*\)/g, "")
    s = s.replace(/[<>]/g, "")
    s = s.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
    return s
  }

  function autoText(v, n) {
    return store.clampStr(store.neutralizeText(v), n)
  }

  function sanitizeOpenUrl(url, allowLoopback) {
    var u = String(url || "").trim()
    if (!u.length) return ""
    if (/[\x00-\x1F\x7F]/.test(u)) return ""
    var lower = u.toLowerCase()
    if (lower.indexOf("file:") === 0 || lower.indexOf("javascript:") === 0
        || lower.indexOf("smb:") === 0 || lower.indexOf("data:") === 0)
      return ""
    if (lower.indexOf("https://") === 0)
      return u
    // Localhost proxy from stream-proxy.py (READY line) — http://127.0.0.1 only.
    if (allowLoopback && /^http:\/\/127\.0\.0\.1(?::[0-9]+)?(?:\/\S*)?$/i.test(u))
      return u
    return ""
  }

  function sanitizeImageUrl(url) {
    var u = store.sanitizeOpenUrl(url)
    if (!u.length) return ""
    var path = u.toLowerCase().split("?")[0].split("#")[0]
    if (path.length >= 4) {
      var ext4 = path.substring(path.length - 4)
      if (ext4 === ".svg" || ext4 === ".xml")
        return ""
    }
    if (path.length >= 5 && path.substring(path.length - 5) === ".svgz")
      return ""
    return u
  }

  function recordByteLen(obj) {
    try {
      return JSON.stringify(obj).length
    } catch (e) {
      return store.maxRecordBytes + 1
    }
  }

  function fitRecord(obj) {
    if (!obj) return null
    if (store.recordByteLen(obj) <= store.maxRecordBytes)
      return obj
    if (obj.vid_urls && obj.vid_urls.length)
      obj.vid_urls = obj.vid_urls.slice(0, 2)
    if (obj.description)
      obj.description = store.clampStr(obj.description, 400)
    if (obj.crew && obj.crew.length)
      obj.crew = obj.crew.slice(0, 4)
    if (store.recordByteLen(obj) <= store.maxRecordBytes)
      return obj
    return null
  }

  function utf8Len(s) {
    s = String(s || "")
    var n = 0
    for (var i = 0; i < s.length; i++) {
      var c = s.charCodeAt(i)
      if (c < 128) n += 1
      else if (c < 2048) n += 2
      else if (c >= 0xD800 && c <= 0xDBFF) {
        n += 4
        i++
      } else n += 3
    }
    return n
  }


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

  readonly property string countdownText: { var _n = nowMs; return formatCountdown(nextLaunch) }
  readonly property string lastUpdatedText: { var _n = nowMs; return formatUpdated(fetchedAt) }
  readonly property string localZoneName: localTimeZone()
  readonly property string jobLine: {
    var _n = nowMs
    var _s = dataSource
    var _f = fetchedAt
    var _l = loading
    return formatJobLine()
  }
  readonly property string barChipCountdown: { var _n = nowMs; return formatCountdownShort(nextLaunch) }
  readonly property string barChipWord: { var _n = nowMs; return formatBarChipWord(nextLaunch) }
  // FA rocket (\uf135) — tintable via Text.color; color emoji 🚀 is not.
  readonly property string barGlyph: "\uf135"
  // LIVE chip tint: webcast_live only (not stickyWatch ▶). HOLD/SOON never tint.
  readonly property bool barLive: !!(store.nextLaunch && store.nextLaunch.webcast_live)
  // Chip: rocket + optional word/short countdown. Panel/tooltip keep T-HH:MM:SS.
  readonly property string barLabel: {
    var parts = []
    if (store.stickyWatch && store.watching)
      parts.push("▶")
    if (store.barShowMissionName && store.nextLaunch) {
      var mn = store.autoText(store.nextLaunch.mission_name || store.nextLaunch.name || "", 18)
      if (mn.length > 18)
        mn = mn.substring(0, 16) + "…"
      if (mn.length)
        parts.push(mn)
    }
    if (store.barShowCountdown) {
      var word = store.barChipWord
      if (word.length)
        parts.push(word)
      else
        parts.push(store.barChipCountdown.length ? store.barChipCountdown : "NET —")
    }
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
    if (opts.barShowCountdown !== undefined)
      store.barShowCountdown = !!opts.barShowCountdown
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
    var vlim = Math.min(rawVids.length, store.maxVids)
    for (var i = 0; i < vlim; i++) {
      var v = rawVids[i] || {}
      var vu = store.sanitizeOpenUrl(v.url || "")
      if (!vu) continue
      var t = v.type
      var tname = (t && typeof t === "object") ? (t.name || "") : String(t || "")
      vids.push({
        url: store.autoText(vu, store.maxShortStr),
        source: store.autoText(v.source || "", store.maxShortStr),
        publisher: store.autoText(v.publisher || "", store.maxShortStr),
        type: store.autoText(tname, store.maxShortStr),
        priority: v.priority || 0,
        feature_image: store.sanitizeImageUrl(v.feature_image || "")
      })
    }
    return store.fitRecord({
      id: store.autoText(item.id || "", store.maxShortStr),
      name: store.autoText(item.name || "", store.maxShortStr),
      mission_name: store.autoText(item.mission_name || parts.mission, store.maxShortStr),
      vehicle: store.autoText(item.vehicle || parts.vehicle, store.maxShortStr),
      status_id: status.id !== undefined ? status.id : (item.status_id || 0),
      status: store.autoText(status.name || item.status || "", store.maxShortStr),
      status_abbrev: store.autoText(status.abbrev || item.status_abbrev || "", store.maxShortStr),
      net: store.autoText(item.net || "", store.maxShortStr),
      window_start: store.autoText(item.window_start || "", store.maxShortStr),
      window_end: store.autoText(item.window_end || "", store.maxShortStr),
      net_precision: store.autoText((typeof netP === "object" ? (netP.name || "") : String(netP || "")), store.maxShortStr),
      image_url: store.sanitizeImageUrl(img.image_url || item.image_url || ""),
      thumbnail_url: store.sanitizeImageUrl(img.thumbnail_url || item.thumbnail_url || ""),
      webcast_live: !!(item.webcast_live),
      vid_urls: vids,
      orbit: store.autoText(store.orbitAbbrev(item), store.maxShortStr),
      mission_type: store.autoText(store.missionTypeOf(item), store.maxShortStr),
      landing_summary: store.autoText(item.landing_summary || "", store.maxShortStr)
    })
  }

  function orbitAbbrev(item) {
    if (!item) return ""
    if (typeof item.orbit === "string") return item.orbit
    if (item.orbit && typeof item.orbit === "object")
      return item.orbit.abbrev || item.orbit.name || ""
    var mission = item.mission || {}
    var o = mission.orbit || {}
    if (typeof o === "string") return o
    return o.abbrev || o.name || ""
  }

  function missionTypeOf(item) {
    if (!item) return ""
    if (item.mission_type) return item.mission_type
    var mission = item.mission || {}
    return mission.type || ""
  }

  function slimOngoing(item) {
    if (!item) return null
    var cfg = item.spacecraft_config || {}
    var img = item.image || {}
    var st = item.status || {}
    return store.fitRecord({
      id: item.id || 0,
      name: store.autoText(item.name || "", store.maxShortStr),
      serial: store.autoText(item.serial_number || item.serial || "", store.maxShortStr),
      config: store.autoText(cfg.name || item.config || "", store.maxShortStr),
      in_space: !!(item.in_space),
      time_in_space: store.autoText(item.time_in_space || "", store.maxShortStr),
      time_docked: store.autoText(item.time_docked || "", store.maxShortStr),
      image_url: store.sanitizeImageUrl(img.image_url || item.image_url || ""),
      status: store.autoText(st.name || item.status || "", store.maxShortStr)
    })
  }

  function detailFor(id) {
    if (!id) return null
    var d = store.launchDetails[id]
    return d || null
  }

  // Resolve a list-mode launch row by id (next / upcoming / past) for stubs.
  function launchRowById(id) {
    id = String(id || "")
    if (!id) return null
    if (store.nextLaunch && String(store.nextLaunch.id) === id)
      return store.nextLaunch
    var i
    for (i = 0; i < store.upcoming.length; i++) {
      if (store.upcoming[i] && String(store.upcoming[i].id) === id)
        return store.upcoming[i]
    }
    for (i = 0; i < store.past.length; i++) {
      if (store.past[i] && String(store.past[i].id) === id)
        return store.past[i]
    }
    return null
  }

  // Merge a list-mode row into launchDetails so MissionDetail has something to show.
  function rememberStubFromRow(id) {
    id = String(id || "")
    if (!id) return null
    if (store.launchDetails[id]) return store.launchDetails[id]
    var row = store.launchRowById(id)
    if (!row) return null
    var stub = slimDetail(row)
    if (!stub) return null
    rememberDetail(stub)
    return stub
  }

  function selectedDetail() {
    var id = store.selectedLaunchId || (store.nextLaunch ? store.nextLaunch.id : "")
    return store.detailFor(id)
  }

  function featureImageFor(launch) {
    if (!launch) return ""
    var vids = launch.vid_urls || []
    for (var i = 0; i < vids.length; i++) {
      if (vids[i] && vids[i].feature_image) {
        var fi = store.sanitizeImageUrl(vids[i].feature_image)
        if (fi) return fi
      }
    }
    return store.sanitizeImageUrl(launch.image_url || launch.thumbnail_url || "")
  }

  function slimCrewMember(c) {
    if (!c) return null
    // Already-slim sample / cache rows
    if (!c.astronaut && (c.name || c.wiki_url || c.image_url)) {
      return store.fitRecord({
        name: store.autoText(c.name || "", store.maxShortStr),
        role: store.autoText(c.role || "", store.maxShortStr),
        agency: store.autoText(c.agency || "", store.maxShortStr),
        image_url: store.sanitizeImageUrl(c.image_url || ""),
        wiki_url: store.sanitizeOpenUrl(c.wiki_url || ""),
        url: store.sanitizeOpenUrl(c.url || "")
      })
    }
    var a = c.astronaut || {}
    var role = c.role || {}
    var img = a.image || {}
    var ag = a.agency || {}
    var roleName = (typeof role === "object") ? (role.role || "") : String(role || "")
    // Prefer Wikipedia, else LL2 astronaut page
    var wiki = a.wiki || a.wiki_url || c.wiki_url || ""
    var astrUrl = a.url || c.url || ""
    return store.fitRecord({
      name: store.autoText(a.name || "", store.maxShortStr),
      role: store.autoText(roleName, store.maxShortStr),
      agency: store.autoText(ag.abbrev || ag.name || "", store.maxShortStr),
      image_url: store.sanitizeImageUrl(img.image_url || img.thumbnail_url || ""),
      wiki_url: store.sanitizeOpenUrl(wiki),
      url: store.sanitizeOpenUrl(astrUrl)
    })
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
        if (crew.length >= store.maxCrew) break
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
      patchUrl = store.sanitizeImageUrl(bestP.image_url || "")
    }
    var img = item.image || {}
    var base = slimLaunch(item) || {}
    var fallbackCrew = item.crew || []
    if (!crew.length && fallbackCrew.length) {
      var seenFb = ({})
      var fblim = Math.min(fallbackCrew.length, store.maxCrew)
      for (var fi = 0; fi < fblim; fi++) {
        var fm = slimCrewMember(fallbackCrew[fi])
        if (!fm || !fm.name) continue
        if (seenFb[fm.name]) continue
        seenFb[fm.name] = true
        crew.push(fm)
      }
    }
    return store.fitRecord({
      id: store.autoText(item.id || base.id || "", store.maxShortStr),
      name: store.autoText(item.name || base.name || "", store.maxShortStr),
      mission_name: store.autoText(mission.name || base.mission_name || parts.mission, store.maxShortStr),
      mission_type: store.autoText(mission.type || item.mission_type || "", store.maxShortStr),
      description: store.autoText(mission.description || item.description || "", store.maxStr),
      orbit: store.autoText(orbit.abbrev || orbit.name || item.orbit || "", store.maxShortStr),
      vehicle: store.autoText(cfg.full_name || cfg.name || base.vehicle || parts.vehicle, store.maxShortStr),
      pad_name: store.autoText(pad.name || item.pad_name || "", store.maxShortStr),
      location_name: store.autoText(loc.name || item.location_name || "", store.maxShortStr),
      landing_summary: store.autoText(landingSummary || item.landing_summary || "", store.maxShortStr),
      booster_serial: store.autoText(boosterSerial || item.booster_serial || "", store.maxShortStr),
      booster_flight: boosterFlight || item.booster_flight || 0,
      patch_url: store.sanitizeImageUrl(patchUrl || item.patch_url || ""),
      image_url: store.sanitizeImageUrl(img.image_url || base.image_url || ""),
      thumbnail_url: store.sanitizeImageUrl(img.thumbnail_url || base.thumbnail_url || ""),
      webcast_live: !!(item.webcast_live),
      vid_urls: base.vid_urls || [],
      crew: crew,
      spacecraft_name: store.autoText(sc.name || item.spacecraft_name || "", store.maxShortStr),
      spacecraft_serial: store.autoText(sc.serial_number || item.spacecraft_serial || "", store.maxShortStr),
      status_id: base.status_id,
      status: base.status,
      status_abbrev: base.status_abbrev,
      net: base.net,
      window_start: base.window_start,
      window_end: base.window_end,
      net_precision: base.net_precision,
      detailed_at: store.autoText(item.detailed_at || (new Date()).toISOString(), store.maxShortStr)
    })
  }

  function rememberDetail(detail) {
    if (!detail || !detail.id) return
    var cache = {}
    var keys = Object.keys(store.launchDetails || {})
    for (var i = 0; i < keys.length; i++)
      cache[keys[i]] = store.launchDetails[keys[i]]
    cache[detail.id] = detail
    var ckeys = Object.keys(cache)
    while (ckeys.length > store.maxDetails) {
      var drop = ""
      var oldest = ""
      for (var j = 0; j < ckeys.length; j++) {
        if (String(ckeys[j]) === String(detail.id)) continue
        var at = ""
        if (cache[ckeys[j]] && cache[ckeys[j]].detailed_at)
          at = String(cache[ckeys[j]].detailed_at)
        if (drop === "" || at < oldest) {
          drop = ckeys[j]
          oldest = at
        }
      }
      if (!drop)
        break
      delete cache[drop]
      ckeys = Object.keys(cache)
    }
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

  function pickStat(s, primary, aliases) {
    s = s || {}
    if (s[primary] !== undefined && s[primary] !== null && s[primary] !== "")
      return Number(s[primary]) || 0
    var list = aliases || []
    for (var i = 0; i < list.length; i++) {
      var k = list[i]
      if (s[k] !== undefined && s[k] !== null && s[k] !== "")
        return Number(s[k]) || 0
    }
    return Number(s[primary]) || 0
  }

  function applyPayload(obj, source) {
    if (!obj || typeof obj !== "object") return false
    var s = obj.stats || {}
    store.stats = {
      total_launches: store.pickStat(s, "total_launches", ["total_launch_count"]),
      successful_launches: store.pickStat(s, "successful_launches", ["successful_launch_count"]),
      failed_launches: store.pickStat(s, "failed_launches", ["failed_launch_count"]),
      pending_launches: store.pickStat(s, "pending_launches", ["pending_launch_count"]),
      attempted_landings: store.pickStat(s, "attempted_landings", ["attempted_landing_count"]),
      successful_landings: store.pickStat(s, "successful_landings", ["successful_landing_count"]),
      failed_landings: store.pickStat(s, "failed_landings", ["failed_landing_count"]),
      consecutive_successful_launches: store.pickStat(s, "consecutive_successful_launches", ["consecutive_successful_launch_count"]),
      consecutive_successful_landings: store.pickStat(s, "consecutive_successful_landings", ["consecutive_successful_landing_count"])
    }
    store.statTotalLaunches = store.stats.total_launches
    store.statSuccessfulLandings = store.stats.successful_landings
    store.statPendingLaunches = store.stats.pending_launches
    store.statConsecutiveSuccessfulLaunches = store.stats.consecutive_successful_launches
    var up = []
    var rawUp = (obj.upcoming || []).slice(0, store.maxListRows)
    for (var i = 0; i < rawUp.length; i++) {
      var sl = slimLaunch(rawUp[i])
      if (sl) up.push(sl)
    }
    store.upcoming = up
    var past = []
    var rawPast = (obj.past || obj.previous || []).slice(0, store.maxListRows)
    for (var pi = 0; pi < rawPast.length; pi++) {
      var spl = slimLaunch(rawPast[pi])
      if (spl) past.push(spl)
    }
    if (past.length) {
      store.past = past
      store.pastLoaded = true
    }
    var next = slimLaunch(obj.next_launch) || pickNext(up)
    // Ingest bundled / cached detail map
    if (obj.details && typeof obj.details === "object") {
      var dkeys = Object.keys(obj.details)
      var dlim = Math.min(dkeys.length, store.maxDetails)
      for (var di = 0; di < dlim; di++) {
        var rawD = obj.details[dkeys[di]]
        var sd = slimDetail(rawD)
        if (sd) rememberDetail(sd)
      }
    }
    // next_launch may already carry slim detail fields (sample)
    if (obj.next_launch && (obj.next_launch.detailed_at || obj.next_launch.description || obj.next_launch.pad_name)) {
      var nd = slimDetail(obj.next_launch)
      if (nd) {
        if (!nd.detailed_at) nd.detailed_at = (new Date()).toISOString()
        rememberDetail(nd)
      }
    }
    if (next && next.id && store.launchDetails[next.id])
      next = mergeDetailOntoLaunch(next, store.launchDetails[next.id])
    store.nextLaunch = next
    var on = []
    var rawOn = (obj.ongoing || []).slice(0, store.maxListRows)
    for (var j = 0; j < rawOn.length; j++) {
      var so = slimOngoing(rawOn[j])
      if (so) on.push(so)
    }
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
      var vu = store.sanitizeOpenUrl(v.url || "")
      if (!vu) continue
      var t = String(v.type || "")
      var pri = Number(v.priority) || 0
      if (t.indexOf("Official") >= 0)
        return vu
      if (pri >= bestPri) {
        bestPri = pri
        best = vu
      }
    }
    return store.sanitizeOpenUrl(best)
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
    openUrlProc.environment = store.helperEnv
    openUrlProc.command = ["xdg-open", "--", u]
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
          idleInhibit.environment = store.helperEnv
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
      notifyProc.environment = store.helperEnv
      notifyProc.command = [
        "notify-send",
        "-a", "Rocketlauncher",
        "-u", "normal",
        "--",
        store.autoText(title || "Rocketlauncher", store.maxShortStr),
        store.autoText(body || "", store.maxShortStr)
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
    var mission = store.autoText(L.mission_name || L.name || "Launch", 80)
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
    var safe = store.sanitizeOpenUrl(url)
    if (!safe) {
      store.watchStatus = "fallback"
      store.watching = true
      return
    }
    var script = store.pluginDir + "/scripts/stream-proxy.py"
    var q = store.normalizeWatchQuality(store.watchQuality)
    streamProxy.command = ["python3", "-B", script, safe, "--timeout", "180", "--quality", q]
    streamProxy.environment = store.helperEnv
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
      var ready = store.sanitizeOpenUrl(line.substring(6).trim(), true)
      if (!ready) {
        store.watchStreamUrl = ""
        store.watchStatus = "fallback"
        store.watching = true
        return
      }
      store.watchStreamUrl = ready
      store.watchStatus = "playing"
      store.watching = true
      store.syncIdleInhibit()
      return
    }
    if (line.indexOf("DIRECT ") === 0) {
      resolveTimer.stop()
      var direct = store.sanitizeOpenUrl(line.substring(7).trim())
      if (!direct) {
        store.watchStreamUrl = ""
        store.watchStatus = "fallback"
        store.watching = true
        return
      }
      store.watchStreamUrl = direct
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
    var url = store.sanitizeOpenUrl(officialWebcast(L))
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
      var hls = store.sanitizeOpenUrl(url)
      if (!hls) {
        store.watchStreamUrl = ""
        store.watchStatus = "fallback"
        return true
      }
      store.watchStreamUrl = hls
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
        store.lastError = ""
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
      store.lastError = ""
    }
    store.detailLoading = true
    store.detailLoadingId = id
    // One detailed GET per id — free tier ≤15/h; list polls stay on mode=list.
    httpGet(store.apiBase + "/launches/" + id + "/", function(ok, body) {
      store.detailLoading = false
      store.detailLoadingId = ""
      if (!ok) {
        store.lastError = "detail fetch failed"
        // Keep expand open and seed a stub so MissionDetail can render list fields.
        if (expand) {
          store.selectedLaunchId = id
          store.detailExpanded = true
        }
        store.rememberStubFromRow(id)
        store.maybeStartPendingWatch(id)
        store.drainPendingDetail()
        return
      }
      try {
        var raw = JSON.parse(body)
        var detail = slimDetail(raw)
        if (!detail) {
          store.lastError = "detail parse empty"
          if (expand) {
            store.selectedLaunchId = id
            store.detailExpanded = true
          }
          store.rememberStubFromRow(id)
          store.maybeStartPendingWatch(id)
          store.drainPendingDetail()
          return
        }
        rememberDetail(detail)
        store.applyDetailToLists(id, detail)
        store.lastError = ""
        persistToDisk()
        store.maybeStartPendingWatch(id)
      } catch (e) {
        store.lastError = "detail parse failed"
        if (expand) {
          store.selectedLaunchId = id
          store.detailExpanded = true
        }
        store.rememberStubFromRow(id)
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
    // Fuzzy NET when precision is coarse — local wall clock, not UTC.
    if (precision.indexOf("day") >= 0 || precision.indexOf("month") >= 0 || precision.indexOf("year") >= 0)
      return "NET " + formatNetLocalDay(launch.net)
    var delta = Math.floor((netMs - store.nowMs) / 1000)
    if (delta < -3600) return "NET " + formatNetLocalDay(launch.net)
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

  function pad2(n) {
    n = Math.floor(Number(n) || 0)
    return (n < 10 ? "0" : "") + n
  }

  function localTimeZone() {
    try {
      if (typeof Intl !== "undefined" && Intl.DateTimeFormat) {
        var tz = Intl.DateTimeFormat().resolvedOptions().timeZone
        if (tz && String(tz).length)
          return String(tz)
      }
    } catch (e) {}
    var off = -new Date().getTimezoneOffset()
    var sign = off >= 0 ? "+" : "-"
    var abs = Math.abs(off)
    var h = Math.floor(abs / 60)
    var m = abs % 60
    return "UTC" + sign + store.pad2(h) + (m ? ":" + store.pad2(m) : "")
  }

  // Local wall-clock NET: "Tue 25 Aug · 12:00 your time"
  function formatNetLocal(iso) {
    var d = new Date(iso)
    if (isNaN(d.getTime())) return "—"
    return store.formatNetLocalDay(iso) + " · " + store.pad2(d.getHours()) + ":" + store.pad2(d.getMinutes()) + " your time"
  }

  function formatNetLocalDay(iso) {
    var d = new Date(iso)
    if (isNaN(d.getTime())) return "—"
    var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
  }

  // Kept for any leftover callers; local day, not UTC.
  function formatNetShort(iso) {
    return store.formatNetLocalDay(iso)
  }

  function formatUpdated(iso) {
    if (!iso) return "never"
    return store.formatRelativeAge(iso)
  }

  function formatRelativeAge(iso) {
    if (!iso) return "unknown"
    var t = Date.parse(iso)
    if (!isFinite(t)) return "unknown"
    var sec = Math.max(0, Math.floor((store.nowMs - t) / 1000))
    if (sec < 45) return "just now"
    var min = Math.floor(sec / 60)
    if (min < 60) return min + "m ago"
    var h = Math.floor(min / 60)
    if (h < 48) return h + "h ago"
    var d = Math.floor(h / 24)
    return d + "d ago"
  }

  function cacheAgeMs() {
    if (!store.fetchedAt) return Number.POSITIVE_INFINITY
    var t = Date.parse(store.fetchedAt)
    if (!isFinite(t)) return Number.POSITIVE_INFINITY
    return Math.max(0, store.nowMs - t)
  }

  function isCacheStale() {
    var age = store.cacheAgeMs()
    if (!isFinite(age)) return true
    return age > store.refreshIntervalSec * 1000
  }

  // Chip-only short countdown (width-stable): 12d / 2d 14h / 14h 06m / 06:22
  function formatCountdownShort(launch) {
    if (!launch || !launch.net) return ""
    var netMs = Date.parse(launch.net)
    if (!isFinite(netMs)) return ""
    var delta = Math.floor((netMs - store.nowMs) / 1000)
    var sign = ""
    var s = delta
    if (delta < 0) {
      sign = "+"
      s = -delta
    }
    s = Math.max(0, Math.floor(s))
    var days = Math.floor(s / 86400)
    var hours = Math.floor((s % 86400) / 3600)
    var mins = Math.floor((s % 3600) / 60)
    var secs = s % 60
    if (days >= 10)
      return sign + days + "d"
    if (days >= 1)
      return sign + days + "d " + hours + "h"
    if (hours >= 1)
      return sign + hours + "h " + store.pad2(mins) + "m"
    return sign + store.pad2(mins) + ":" + store.pad2(secs)
  }

  function formatBarChipWord(launch) {
    if (!launch) return ""
    if (launch.webcast_live) return "LIVE"
    var phase = store.launchPhase(launch)
    if (phase === "hold") return "HOLD"
    if (phase === "success") return "SUCCESS"
    if (phase === "failure") return "FAIL"
    if (phase === "t10") return "SOON"
    return ""
  }

  // Discrete LL2 job phase for the existing header subheader (not a second header).
  function launchPhase(launch) {
    if (!launch) return "net"
    var a = String(launch.status_abbrev || "")
    var id = Number(launch.status_id) || 0
    var st = String(launch.status || "").toLowerCase()
    if (a === "Failure" || id === 4 || id === 7 || a === "Partial Failure"
        || st.indexOf("fail") === 0)
      return "failure"
    if (a === "Success" || id === 3)
      return "success"
    if (launch.webcast_live)
      return "live"
    if (a === "Hold" || id === 5 || st.indexOf("hold") >= 0)
      return "hold"
    if (id === 6 || a === "In Flight")
      return "tplus"
    var netMs = Date.parse(launch.net || "")
    if (isFinite(netMs)) {
      var delta = Math.floor((netMs - store.nowMs) / 1000)
      if (delta <= 0)
        return "tplus"
      if (delta <= 600)
        return "t10"
    }
    return "net"
  }

  function formatJobLine() {
    if (!store.loading && (store.dataSource === "none" || store.isCacheStale())) {
      var age = store.fetchedAt ? store.formatRelativeAge(store.fetchedAt) : "unknown"
      return "offline · cached " + age
    }
    var L = store.nextLaunch
    if (!L)
      return "next NET · none scheduled"
    var phase = store.launchPhase(L)
    if (phase === "failure") return "failure"
    if (phase === "success") return "success"
    if (phase === "live") return "webcast live"
    if (phase === "hold") return "hold"
    if (phase === "tplus") {
      var plus = store.countdownText
      return plus.length ? plus : "T+"
    }
    if (phase === "t10") return "T-10"
    var cd = store.countdownText
    if (cd.indexOf("T-") === 0)
      return "next NET · " + cd
    if (L.net)
      return "next NET · " + store.formatNetLocal(L.net)
    return "next NET"
  }

  function trajectoryKind(launch) {
    if (!launch) return "leo"
    var o = String(launch.orbit || "").toLowerCase()
    if (o.indexOf("gto") >= 0 || o.indexOf("geo") >= 0 || o.indexOf("gso") >= 0
        || o.indexOf("heo") >= 0)
      return "gto"
    if (o.indexOf("sub") >= 0 || o.indexOf("ballistic") >= 0)
      return "landing"
    if (o.indexOf("leo") >= 0 || o.indexOf("sso") >= 0 || o.indexOf("meo") >= 0
        || o.indexOf("po") === 0)
      return "leo"
    var land = String(launch.landing_summary || "").toLowerCase()
    if (land.length)
      return "landing"
    return "leo"
  }

  function trajectoryPhase(launch) {
    var p = store.launchPhase(launch)
    if (p === "failure") return "failure"
    if (p === "success") return "success"
    if (p === "live") return "webcast"
    if (p === "tplus") return "t0"
    return "net"
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
    // Primary: fetch-json.py --write (O_EXCL|O_NOFOLLOW 0600 temp, fsync, replace).
    // FileView.setText remains writes-only fallback if the helper cannot start.
    var body = JSON.stringify(buildCacheObject(), null, 2) + "\n"
    store.runAtomicWrite(store.cachePath, body)
  }

  function runAtomicWrite(path, body) {
    var proc = writeProcComp.createObject(store)
    if (!proc) {
      try { cacheFile.setText(body) } catch (e) {}
      return
    }
    proc.writeBody = body
    proc.command = [
      "python3", "-B", store.pluginDir + "/scripts/fetch-json.py",
      "--write", path,
      "--cap", String(store.cacheByteCap),
      "--nbytes", String(store.utf8Len(body))
    ]
    proc.environment = store.helperEnv
    proc.running = true
  }

  function bootstrap() {
    // Prefer disk cache if present (bounded read); else bundled sample; then network.
    store.runCappedFetch([
      "--file", store.cachePath,
      "--cap", String(store.cacheByteCap)
    ], function(ok, body) {
      if (ok)
        store.onCacheLoaded(body)
      else
        sampleFile.reload()
    })
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
        var rows = (raw.results || []).slice(0, store.maxListRows)
        var past = []
        for (var i = 0; i < rows.length; i++) {
          var pl = slimLaunch(rows[i])
          if (pl) past.push(pl)
        }
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
    upRaw = upRaw.slice(0, store.maxListRows)
    var up = []
    for (var i = 0; i < upRaw.length; i++) {
      var ul = slimLaunch(upRaw[i])
      if (ul) up.push(ul)
    }
    // Preserve webcast URLs from previous next launch when list mode omits them
    var prev = store.nextLaunch
    var next = pickNext(up)
    if (next && prev && next.id === prev.id && (!next.vid_urls || !next.vid_urls.length) && prev.vid_urls)
      next.vid_urls = prev.vid_urls
    var onRaw = (store.fetchDragon && store.fetchDragon.results) ? store.fetchDragon.results : []
    onRaw = onRaw.slice(0, store.maxListRows)
    var on = []
    for (var j = 0; j < onRaw.length; j++) {
      var ol = slimOngoing(onRaw[j])
      if (ol) on.push(ol)
    }
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

  // Per-call Process+StdioCollector so fetchLaunchDetail can overlap
  // refreshFromNetwork / ensurePastLaunches without clobbering stdout.
  function deliverFetch(raw, cb) {
    var t = String(raw || "")
    if (t.indexOf("OK ") === 0) {
      var nl = t.indexOf("\n")
      var body = nl >= 0 ? t.substring(nl + 1) : ""
      if (cb) cb(true, body)
      return
    }
    var reason = "fetch failed"
    if (t.indexOf("ERR ") === 0) {
      var end = t.indexOf("\n")
      reason = (end >= 0 ? t.substring(4, end) : t.substring(4)).trim() || reason
    }
    store.lastError = store.autoText(reason, store.maxShortStr)
    if (cb) cb(false, "")
  }

  function runCappedFetch(args, cb) {
    var proc = fetchProcComp.createObject(store)
    if (!proc) {
      store.lastError = "fetch spawn failed"
      if (cb) cb(false, "")
      return
    }
    proc.doneCb = cb
    proc.command = ["python3", "-B", store.pluginDir + "/scripts/fetch-json.py"].concat(args)
    proc.environment = store.helperEnv
    proc.running = true
  }

  function httpGet(url, cb) {
    store.runCappedFetch([
      "--url", url,
      "--cap", String(store.netByteCap),
      "--timeout", String(store.netTimeoutSec),
      "--header", "Accept: application/json",
      "--header", "User-Agent: " + store.userAgent
    ], cb)
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
    preload: false
    // Writes-only fallback. Primary cache write is fetch-json.py --write.
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
    environment: store.helperEnv
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
    environment: store.helperEnv
  }

  Process {
    id: idleInhibit
    running: false
    environment: store.helperEnv
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

  Component {
    id: fetchProcComp
    Process {
      id: fp
      property var doneCb: null
      property bool delivered: false
      running: false
      environment: store.helperEnv
      stdout: StdioCollector {
        id: capOut
        waitForEnd: true
        onStreamFinished: fp.completeFetch(capOut.text)
      }
      onExited: function(exitCode, exitStatus) {
        Qt.callLater(function() {
          if (!fp.delivered) {
            var t = ""
            try { t = capOut.text } catch (e) {}
            fp.completeFetch(t)
          }
          fp.destroy()
        })
      }
      function completeFetch(raw) {
        if (fp.delivered)
          return
        fp.delivered = true
        var cb = fp.doneCb
        fp.doneCb = null
        store.deliverFetch(raw, cb)
      }
    }
  }

  Component {
    id: writeProcComp
    Process {
      id: wp
      property string writeBody: ""
      running: false
      stdinEnabled: true
      environment: store.helperEnv
      stdout: StdioCollector {
        id: writeOut
        waitForEnd: true
      }
      onStarted: {
        try {
          wp.write(wp.writeBody)
        } catch (e) {}
        // Close stdin so the helper sees EOF even if --nbytes is off.
        wp.stdinEnabled = false
      }
      onExited: function(exitCode, exitStatus) {
        if (exitCode !== 0) {
          try { cacheFile.setText(wp.writeBody) } catch (e) {}
        }
        Qt.callLater(function() { wp.destroy() })
      }
    }
  }

  Process {
    id: streamProxy
    running: false
    environment: store.helperEnv
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
