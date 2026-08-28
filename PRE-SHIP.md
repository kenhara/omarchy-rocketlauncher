# Rocketlauncher — pre-ship checklist (v1.7.0)

## PRE-SHIP note — robustness (1.7.0)

Fetch watchdog, initial-host allowlist, UUID launch ids, cache write fail-closed,
Watch resolve timeout kills proxy. No CI. 1.5.22 locks kept.

## PRE-SHIP note — less software (1.6.2)

Eight cuts only. No new hero, no new settings, no Phosphor on other plugins, no marketplace Verify.
1.5.22 / HC-05 / AutoText / no XHR kept. Job-line STATE words match the chip.

## PRE-SHIP note — Phosphor icons + 1.6.0 nits (1.6.1)

Harris-approved set only: rocket / rocket-launch (bar + header), play-circle (Watch),
map-pin / planet / parachute (next-launch labels; parachute hidden without LL2 landing).
Bundled Phosphor regular paths in PhosphorIcon.qml (MIT). No Image.source SVG, no remote
webfont, no FA rocket on chip/header. Do not grow the chip. Unofficial still.

Nits: job-line offline only after a failed list fetch (stale ≠ offline);
chip keeps short countdown next to LIVE/HOLD/SOON/SUCCESS; trajectory hidden
until T-10 / hold-in-window / webcast / T-0 / result; NET drops “your time”.
1.5.22 / 1.6.0 security posture kept.



## PRE-SHIP note — next-launch board (1.6.0)

Inspired by nocram.f1 *ideas* only — not a copy of their product shape or QML.
Grows the existing desk: adaptive job-line, local NET, width-stable bar chip,
next-launch Shape/Path trajectory. No Monza hero, no weekend session table,
no live-mode toggle, no F1 keyboard-legend footer, no remote SVGs.
1.5.22 security posture kept. notifyMilestones stays opt-in.


## PRE-SHIP note — discoverability (1.5.3)

Patch bump for marketplace discoverability before UTM smoke: `barWidget.category` **Fun → Widgets**; generous `keywords` + `barWidget.aliases` (SpaceX/NASA/Falcon/LL2/webcast…); README Discoverability (honest: keywords may help search; aliases for discovery docs). No QML/logic change.


Applied Omarchy Quattro pre-ship checklist to `kenhara.rocketlauncher` on 2026-08-23.

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
| 14 | Version sync manifest/README/DESIGN/preview/UA | **1.5.3** |
| 15 | Integer schema min/max/step | Already OK |
| 16 | Drop invented `handleSummonPayload` | **Dropped**; local `onBarMiddleClick` / `onBarRightClick` |
| 17 | Witty pitch ≤15 words; Controls L/R/M; baseline-clean | **Pitch synced**; Controls OK; no curl\|sh |

## Rocketlauncher-specific kept

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

**1.5.3** (discoverability: Widgets category + keywords/aliases). Prior **1.5.1** was pre-ship doc/code hardening after 1.5.0 audit.
