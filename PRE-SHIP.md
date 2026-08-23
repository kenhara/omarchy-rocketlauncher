# Space Jockey — pre-ship checklist (v1.5.2)

## PRE-SHIP note — discoverability (1.5.2)

Patch bump for marketplace discoverability before UTM smoke: `barWidget.category` **Fun → Widgets**; generous `keywords` + `barWidget.aliases` (SpaceX/NASA/Falcon/LL2/webcast…); README Discoverability (honest: keywords may help search; aliases for discovery docs). No QML/logic change.


Applied Omarchy Quattro pre-ship checklist to `harris.space-jockey` on 2026-08-23.

## Grep / must-fix results

| # | Check | Result |
|---|--------|--------|
| 1 | No `Style.font.size(` | Clean (named `Style.font.*` only) |
| 2 | `Style.font.family` not primary | Clean — `bar.fontFamily` / `"monospace"` |
| 3 | `Quickshell.clipboardText` | N/A (no clipboard path) |
| 4 | Clipboard bash `bash -c` + wl-copy→xclip→xsel | N/A |
| 5 | No `env KEY=` argv secrets | Clean |
| 6 | No `/workspace/` in README/DESIGN | Clean |
| 7 | LICENSE second Software unquoted | **Fixed** |
| 8 | README hero `preview.png`; Install+Remove; no WIP | Already OK |
| 9 | FileView.setText — no mkdir+`Qt.callLater` race | **Fixed** (dropped `ensureCacheDir`) |
| 10 | Dead `dataChanged` (0 consumers) | **Deleted** signal + emitters |
| 11 | `openUrlExternally` bool + honest toasts | **Fixed** (https allow-list; Opened / Refused / Open failed) |
| 12 | Remote Text → `textFormat: PlainText` | **Fixed** in `MissionDetail.qml` |
| 13 | Hover on buttons; Flickable tall panel | **Hover added**; Flickable kept |
| 14 | Version sync manifest/README/DESIGN/preview/UA | **1.5.2** |
| 15 | Integer schema min/max/step | Already OK |
| 16 | Drop invented `handleSummonPayload` | **Dropped**; local `onBarMiddleClick` / `onBarRightClick` |
| 17 | Witty pitch ≤15 words; Controls L/R/M; baseline-clean | **Pitch synced**; Controls OK; no curl\|sh |

## Space-Jockey-specific kept

- Panel `Flickable` scroll (H1)
- Async Watch after detail / `pendingWatchAfterDetail` (H2)
- Sticky WatchPlayer hoist on BarWidget (H3)
- Sample-cache correctness (upcoming vs past, fresh NETs)
- Stream-proxy one path for HLS vs READY

## Files touched

- `LICENSE`, `manifest.json`, `README.md`, `DESIGN.md`
- `LaunchStore.qml`, `BarWidget.qml`, `Panel.qml`
- `MissionDetail.qml`, `MissionCard.qml`, `WatchPlayer.qml`
- `docs/preview/index.html`
- `PRE-SHIP.md` (this file)

## Version

**1.5.2** (discoverability: Widgets category + keywords/aliases). Prior **1.5.1** was pre-ship doc/code hardening after 1.5.0 audit.
