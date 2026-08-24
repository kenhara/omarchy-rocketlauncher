import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Rocketlauncher bar entry — clock / Minesweeper pattern:
// BarWidget loads nested Panel.qml via Loader. kinds: ["bar-widget"] only.
//
// If qs.Ui / qs.Commons import paths differ on a given Omarchy build, mirror
// the community BarWidget / WidgetButton / Style tokens from research §3–9.
BarWidget {
  id: root
  moduleName: "kenhara.rocketlauncher"

  // The bar identifies a panel by the widget in its slot, so open state and
  // popout hand-off must be readable from here (not only from the panel).
  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  // Theme tokens from the active bar (Minesweeper / Coin Toss contract).
  readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : "monospace"

  property int refreshIntervalSec: {
    var n = 1800
    try {
      if (root.settings && root.settings.refreshIntervalSec !== undefined)
        n = Number(root.settings.refreshIntervalSec)
      else if (typeof root.setting === "function")
        n = Number(root.setting("refreshIntervalSec", 1800))
    } catch (e) {}
    if (!isFinite(n)) n = 1800
    return Math.max(600, Math.min(86400, Math.round(n)))
  }

  property bool notifyMilestones: {
    try {
      if (root.settings && root.settings.notifyMilestones !== undefined)
        return !!root.settings.notifyMilestones
      if (typeof root.setting === "function")
        return !!root.setting("notifyMilestones", false)
    } catch (e) {}
    return false
  }

  property bool barShowMissionName: {
    try {
      if (root.settings && root.settings.barShowMissionName !== undefined)
        return !!root.settings.barShowMissionName
      if (typeof root.setting === "function")
        return !!root.setting("barShowMissionName", false)
    } catch (e) {}
    return false
  }

  property bool barShowCountdown: {
    try {
      if (root.settings && root.settings.barShowCountdown !== undefined)
        return !!root.settings.barShowCountdown
      if (typeof root.setting === "function")
        return !!root.setting("barShowCountdown", true)
    } catch (e) {}
    return true
  }

  property bool stickyWatch: {
    try {
      if (root.settings && root.settings.stickyWatch !== undefined)
        return !!root.settings.stickyWatch
      if (typeof root.setting === "function")
        return !!root.setting("stickyWatch", false)
    } catch (e) {}
    return false
  }

  property string watchQuality: {
    try {
      var q = "best"
      if (root.settings && root.settings.watchQuality !== undefined)
        q = root.settings.watchQuality
      else if (typeof root.setting === "function")
        q = root.setting("watchQuality", "best")
      return launchStore.normalizeWatchQuality(q)
    } catch (e) {}
    return "best"
  }

  property bool starfieldEnabled: {
    try {
      if (root.settings && root.settings.starfieldEnabled !== undefined)
        return !!root.settings.starfieldEnabled
      if (typeof root.setting === "function")
        return !!root.setting("starfieldEnabled", true)
    } catch (e) {}
    return true
  }

  property bool flipAnimate: {
    try {
      if (root.settings && root.settings.flipAnimate !== undefined)
        return !!root.settings.flipAnimate
      if (typeof root.setting === "function")
        return !!root.setting("flipAnimate", true)
    } catch (e) {}
    return true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Local bar actions only — bar-widget-only plugins are not summonable with
  // payloads; middle-click = onBarMiddleClick, right-click = onBarRightClick.
  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function toggleWatchPlayPause() {
    if (stickyWatchPlayer.active) {
      stickyWatchPlayer.togglePlayPause()
      return
    }
    if (panelLoader.item && typeof panelLoader.item.toggleWatchPlayPause === "function")
      panelLoader.item.toggleWatchPlayPause()
  }

  // Coverglow / Agents / clock modifiers
  function onBarMiddleClick() {
    if (launchStore.watching || launchStore.watchStickyBackground) {
      root.toggleWatchPlayPause()
      return
    }
    launchStore.refreshFromNetwork()
  }

  function onBarRightClick() {
    // Prefer in-panel Watch for next launch; open panel so chrome is visible.
    if (!root.opened)
      root.open()
    launchStore.openWatchForNextOrOriginal()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("store" in target) target.store = launchStore
    if ("watchPlayer" in target) target.watchPlayer = stickyWatchPlayer
    root.syncWatchChrome()
  }

  // H3: WatchPlayer lives here so MediaPlayer outlives KeyboardPanel.
  // When the panel is open, reparent into the panel slot; when closed with
  // stickyWatch, keep active with chrome hidden so playback continues.
  function syncWatchChrome() {
    var panel = panelLoader.item
    var slot = panel && panel.watchSlot ? panel.watchSlot : null
    if (root.opened && slot) {
      stickyWatchPlayer.parent = slot
      stickyWatchPlayer.x = 0
      stickyWatchPlayer.y = 0
      stickyWatchPlayer.width = slot.width
      stickyWatchPlayer.chromeVisible = true
    } else {
      stickyWatchPlayer.parent = root
      stickyWatchPlayer.x = 0
      stickyWatchPlayer.y = 0
      stickyWatchPlayer.width = 320
      // Sticky background: keep MediaPlayer, hide chrome.
      stickyWatchPlayer.chromeVisible = false
    }
  }

  function syncStoreSettings() {
    launchStore.applySettings({
      refreshIntervalSec: root.refreshIntervalSec,
      notifyMilestones: root.notifyMilestones,
      barShowMissionName: root.barShowMissionName,
      barShowCountdown: root.barShowCountdown,
      stickyWatch: root.stickyWatch,
      watchQuality: root.watchQuality,
      starfieldEnabled: root.starfieldEnabled,
      flipAnimate: root.flipAnimate
    })
    launchStore.panelOpen = root.opened
  }

  // Best-effort write-back into mutable settings (Compliantish / Enricherino).
  // Keeps shell.json / `omarchy bar set` durable across reload.
  function mirrorSetting(key, value) {
    if (!root.settings) return
    try {
      root.settings[key] = value
    } catch (e) {}
  }

  onBarChanged: injectPanel()
  onSettingsChanged: {
    injectPanel()
    syncStoreSettings()
  }
  onOpenedChanged: {
    launchStore.panelOpen = root.opened
    root.syncWatchChrome()
  }
  onRefreshIntervalSecChanged: syncStoreSettings()
  onNotifyMilestonesChanged: syncStoreSettings()
  onBarShowMissionNameChanged: syncStoreSettings()
  onBarShowCountdownChanged: syncStoreSettings()
  onStickyWatchChanged: syncStoreSettings()
  onWatchQualityChanged: syncStoreSettings()
  onStarfieldEnabledChanged: syncStoreSettings()
  onFlipAnimateChanged: syncStoreSettings()

  LaunchStore {
    id: launchStore
  }

  // Hoisted WatchPlayer (H3 stickyWatch) — outlives KeyboardPanel / panel hide.
  WatchPlayer {
    id: stickyWatchPlayer
    width: 320
    chromeVisible: false
    active: launchStore.watching
    streamUrl: launchStore.watchStreamUrl
    originalUrl: launchStore.watchUrl
    featureImage: launchStore.watchFeatureImage
    statusText: launchStore.watchStatus
    muted: launchStore.watchMuted
    foreground: root.foreground
    surfaceColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
    fontFamily: root.fontFamily
    onOpenOriginal: launchStore.openWatchOriginal()
    onCloseRequested: launchStore.closeWatch()
    onMuteToggled: launchStore.watchMuted = muted
  }

  Component.onCompleted: {
    syncStoreSettings()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // FA rocket (\uf135) + optional ▶ / mission / countdown — tintable; emoji is not
    text: {
      var g = launchStore.barGlyph || "\uf135"
      var label = launchStore.barLabel || ""
      return label.length ? (g + " " + label) : g
    }
    active: launchStore.barLive
    activeColor: Color.accent
    useActiveColor: true
    fontSize: Style.font.caption
    horizontalMargin: 8.5
    tooltipText: {
      var n = launchStore.nextLaunch
      var tip = "Rocketlauncher — rocket pilot"
      if (n)
        tip += " — " + (n.mission_name || n.name || "next launch")
      if (launchStore.countdownText && launchStore.countdownText.length)
        tip += " · " + launchStore.countdownText
      if (launchStore.stickyWatch && launchStore.watching)
        tip += launchStore.watchStickyBackground
          ? " · Watch playing in background (sticky)"
          : " · Watch active"
      tip += " · middle: play/pause or refresh · right: Watch"
      return tip
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) root.onBarMiddleClick()
      else if (buttonCode === Qt.RightButton) root.onBarRightClick()
    }
  }
}
