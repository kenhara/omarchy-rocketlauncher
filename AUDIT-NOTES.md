# Rocketlauncher audit notes (v1.6.2)

## 1.6.2 — less software

Eight cuts: keyboard-legend footer, starfield/scanline + starfieldEnabled, no auto-expand Detail,
next id filtered from Upcoming, consecutive-success caption, in-panel mission-name + CLI dump,
next-card countdown/badge echo, job-line STATE words (LIVE/SOON/HOLD/SUCCESS/FAIL).
HC-05 / AutoText / no XHR / 1.5.22 locks unchanged.

## 1.6.1 — Phosphor icons + 1.6.0 nits

Local Shape/Path glyphs only (rocket, rocket-launch, play-circle, map-pin, planet, parachute).
No remote webfont, no SVG Image.source, no FA on chip/header. Next-launch labels only.
Job-line: offline only after failed list refresh / dataSource none; stale cache is stale ≠ offline.
Chip keeps short countdown next to LIVE/HOLD/SOON/SUCCESS. Trajectory hidden until bead moves.
formatNetLocal drops “your time”. HC-06–HC-11 from 1.5.22 and 1.6.0 desk unchanged.


## 1.6.0 — inspired, not copied

Next-launch board grows existing grammar (cards / Watch / flips / job-line).
Inspired by nocram.f1 *ideas* only — their QML and Monza/session/live-mode chrome were not adopted.
L3 (UTC NET) is superseded: cards and footer use local wall-clock; panel/tooltip countdown stays T-HH:MM:SS.
HC-06–HC-11 from 1.5.22 are unchanged.


Mapping of plugin audit IDs after the 1.5.0 fix pass.

## Fixed in this release

| ID | Summary | Where |
|----|---------|--------|
| **B2** | Default font fallback is concrete `"monospace"`; primary font still comes from `bar.fontFamily` / `contentFontFamily`. Never rely on `Style.font.family` as primary. | `BarWidget.qml`, `Panel.qml`, `FlipCounter.qml`, `MissionCard.qml`, `MissionDetail.qml`, `WatchPlayer.qml` |
| **H1** | Panel content `Column` wrapped in `Flickable` (`clip: true`). `fittedContentHeight` caps the viewport; `contentHeight` = `column.implicitHeight`. | `Panel.qml` |
| **H2** | Right-click Watch race: list mode often omits `vid_urls`. `openWatch` sets `pendingWatchAfterDetail` and fetches detail; starts Watch when `vid_urls` arrive. Eager soft-fetch of next detail after `commitNetworkFetch` when next id changes / lacks vids. | `LaunchStore.qml` |
| **H3** | `WatchPlayer` hoisted to `BarWidget` so MediaPlayer outlives `KeyboardPanel`. Reparented into panel `watchSlot` while open; `chromeVisible: false` for sticky background. README softened to best-effort pending live shell verify. | `BarWidget.qml`, `Panel.qml`, `WatchPlayer.qml`, `README.md` |
| **M1** | `upcoming[]` no longer includes Success/past (Starlink Group 15-20 stays in `past[]` only). Sample NETs pushed forward for demo freshness. | `data/sample-cache.json` |
| **M2** | HLS takes one path: `DIRECT` + return. Non-HLS uses `READY` via proxy only. HLS detection is path/extension `.m3u8` (not substring). | `scripts/stream-proxy.py`, `LaunchStore.isHlsUrl` |
| **M3** | `detailLoading` guarded before mutating selection; busy fetches queue `pendingDetailId`. `detailLoadingId` drives the spinner. | `LaunchStore.qml`, `Panel.qml` |
| **M4** | README: removed rename-in-progress WIP / duplicate install; one clean install for `kenhara/omarchy-rocketlauncher`. | `README.md` |
| **M5** | README hero: `![Rocketlauncher](preview.png)` near top. | `README.md` |
| **L1** | `openUrlExternal`: if `Qt.openUrlExternally` returns `false`, fall back to `xdg-open`. | `LaunchStore.qml` |
| **L2** | Single owner for `pauseWatchOnHide`: `LaunchStore.onPanelOpenChanged` only (Panel no longer calls it). | `LaunchStore.qml`, `Panel.qml` |
| **L3** | `formatNetShort` is UTC (comment + `UTC` suffix in UI / fuzzy NET countdown). | `LaunchStore.qml`, `Panel.qml` |
| **L4** | Comment that 4-digit `FlipCounter` is intentional odometer look. | `Panel.qml`, `FlipCounter.qml` |
| **HC1** | Bounded HTTP/cache reads via `scripts/fetch-json.py` (1 MiB/response, 2 MiB cache); row/field caps after parse; FileView cache writes-only. | `LaunchStore.qml`, `scripts/fetch-json.py` |
| **HC-05** | `--file` refuses symlink/FIFO/non-regular via O_NOFOLLOW + S_ISREG; ERR not-regular. | `scripts/fetch-json.py` |
| **HC-06** | Watch / MediaPlayer / stream-proxy https-only (`sanitizeOpenUrl`; reject file:/javascript:/smb:/data:). | `LaunchStore.qml`, `WatchPlayer.qml`, `scripts/stream-proxy.py` |
| **HC-07** | Image.source https allowlist; refuse data:/file:/.svg/.xml at slim + QML. | `LaunchStore.qml`, `MissionDetail.qml`, `WatchPlayer.qml` |
| **HC-08** | fetch-json pin/re-validate host after redirects; stream-proxy drop auth cookies off-host. | `scripts/fetch-json.py`, `scripts/stream-proxy.py` |
| **HC-09** | Cache write: O_EXCL\|O_NOFOLLOW 0600 temp, fsync, replace; dir 0700. FileView fallback only. | `scripts/fetch-json.py`, `LaunchStore.qml` |
| **HC-10** | AutoText neutralize at slim/apply; PlainText on MissionCard + lastError. Re-slim all rows + per-record byte cap. | `LaunchStore.qml`, `MissionCard.qml`, `Panel.qml` |
| **HC-11** | notify-send `--` before title/body; PATH=/usr/bin:/bin on Processes. | `LaunchStore.qml` |

## Remaining — live Omarchy / UTM VM

| ID | Summary | Owner |
|----|---------|--------|
| **B1** | Live `qs.Ui` validate on Omarchy (import paths / Style tokens). | User UTM VM |
| **H3 live-verify** | Confirm stickyWatch background playback + bar ▶ glyph on a real Omarchy shell (hoist is implemented; runtime behavior needs live Multimedia / panel host). | User UTM VM |

## Version

- **1.5.0** — stickyWatch hoist is a behavioral change (from 1.4.2).
- **1.5.20** — defensive I/O bounds (helper + cache + row/field caps).
- **1.5.21** — refuse symlink/FIFO cache reads (HC-05).
- **1.5.22** — Watch/image URL allowlists, redirect pinning, atomic cache writes, AutoText neutralize (HC-06–HC-11).
- **1.6.0** — next-launch board (job-line, local NET, short chip, trajectory). Inspired, not copied.
- **1.6.1** — Phosphor Icons (local Shape/Path). Unofficial; MIT credit.
- **1.6.2** — less software (eight cuts). 1.5.22 locks kept.

