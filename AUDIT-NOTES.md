# Rocketlauncher audit notes (v1.5.0)

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

## Remaining — live Omarchy / UTM VM

| ID | Summary | Owner |
|----|---------|--------|
| **B1** | Live `qs.Ui` validate on Omarchy (import paths / Style tokens). | User UTM VM |
| **H3 live-verify** | Confirm stickyWatch background playback + bar ▶ glyph on a real Omarchy shell (hoist is implemented; runtime behavior needs live Multimedia / panel host). | User UTM VM |

## Version

- **1.5.0** — stickyWatch hoist is a behavioral change (from 1.4.2).
- **1.5.20** — defensive I/O bounds (helper + cache + row/field caps).
- **1.5.21** — refuse symlink/FIFO cache reads (HC-05).
