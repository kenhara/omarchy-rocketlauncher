# Rocketlauncher

![Rocketlauncher](preview.png)

See the next space launch without leaving Omarchy.

Flip-digit Falcon and Starship stats, a local-time countdown (HOLD / LIVE / SOON),
ongoing crew, past missions, and Watch in the panel. A native bar-widget, not a
browser tab.

Named for Heinlein’s rocket-pilot vibe. Unofficial; not SpaceX-branded.

**ID:** `kenhara.rocketlauncher`  
**Author:** Harris Kenny  
**License:** MIT  
**Version:** 1.7.1

1.7.0: fetch watchdog, host allowlist, launch-id and cache fail-closed, Watch resolve timeout. Prior releases: [CHANGELOG.md](CHANGELOG.md).

**Repo:** https://github.com/kenhara/omarchy-rocketlauncher

## Unofficial disclaimer


**Rocketlauncher is unofficial.** It is **not** affiliated with, endorsed by, or
sponsored by Space Exploration Technologies Corp. (“SpaceX”) or any related
entity. This plugin does **not** ship SpaceX logos, wordmarks, or brand assets.
Mission/vehicle names and trademarks mentioned in launch data belong to their
respective owners. Launch schedules and imagery metadata come from
[Launch Library 2](https://ll.thespacedevs.com/docs/) (The Space Devs); the
plugin links to LL2-hosted images and does not redistribute those binaries.

## Discoverability

Marketplace card: **Widgets** · tags `bar, media, quickshell`.

Search words include **space**, Falcon, Starship, SpaceX, NASA, webcast. Display
name stays **Rocketlauncher** (brand-free).

## Install

### From GitHub

```sh
omarchy plugin add https://github.com/kenhara/omarchy-rocketlauncher.git --enable
omarchy bar move kenhara.rocketlauncher --section right
```

### Local copy

The **git repo root is the plugin** (`manifest.json` at root). On an Omarchy
machine:

```sh
mkdir -p ~/.config/omarchy/plugins
cp -a . ~/.config/omarchy/plugins/kenhara.rocketlauncher

omarchy plugin validate ~/.config/omarchy/plugins/kenhara.rocketlauncher
omarchy-shell shell rescanPlugins
omarchy bar move kenhara.rocketlauncher --section right
```

Hot reload applies on save under `~/.config/omarchy/plugins/`.

### Optional dependencies (in-panel Watch)

Watch embeds when possible via **Qt Multimedia** + a small localhost helper:

| Dep | Why |
|-----|-----|
| `python3` | Runs `scripts/stream-proxy.py` |
| `yt-dlp` | Resolves YouTube / (sometimes) X / other webcast URLs to a playable stream |

```sh
# Arch / Omarchy examples
sudo pacman -S python yt-dlp
# or: python3 -m pip install --user yt-dlp
```

`yt-dlp` must be importable by system `python3` (pacman / `pip --user`). A pipx-only install is not seen by the helper.

Without these, **WATCH** still works: the panel shows a thumbnail fallback and
**Open original** (or the store opens the URL externally). The plugin never
bundles binaries and never runs remote installers.

## Usage

- **Left-click** the bar rocket + short countdown (`14h 06m` / `06:22`; tooltip keeps `T-HH:MM:SS`) to
  open/close the panel. Opening fetches **mission detail** for the next launch
  (cached by id after the first hit). **Middle-click** play/pauses Watch when
  active, otherwise refreshes data. **Right-click** starts Watch for the next
  launch.
- **Past Missions** — expand the section in the panel to load the last few
  SpaceX launches (`/launches/previous/`, lazy on first expand to save free-tier
  quota). Tap a card for the same on-demand mission detail as Next / Upcoming.
  Offline sample cache ships a few past rows from research fixtures.
- **Ongoing missions** — expand the section; **LOCATE** (on click) proves a docked ISS fix or shows a static course / `NO PUBLIC TRACK`. Not on the refresh cycle.
- Crew avatars with a Wikipedia / LL2 astronaut URL are clickable (opens in the
  browser). Pointer cursor only appears on actionable controls.
- Tap the next-launch card to expand/collapse detail (description, pad,
  landing, patch, crew when present). Starlink-style flights omit the empty
  crew section.
- **WATCH** prefers an in-panel player (YouTube / HLS when `yt-dlp` can
  resolve). Official webcasts are often **X broadcasts** — those try
  `yt-dlp` first, then degrade to the webcast `feature_image` + **Open
  original**. We never claim X always embeds.
- Flip counters animate when totals change.

### Controls

| Input | Action |
|-------|--------|
| Left-click bar | Toggle panel |
| Middle-click bar | If Watch is active: play/pause; else refresh launch data |
| Right-click bar | Open Watch for next launch (panel opens; falls back toward Open original when no webcast) |
| Escape | Close panel (see `stickyWatch` below) |
| Space | Play / pause Watch (or start Watch for next launch) |
| `M` | Mute / unmute |
| `O` | Open original webcast URL |
| `S` | Stop Watch (tears down player + proxy even when sticky) |
| WATCH button | Start in-panel Watch |
| PLAY / PAUSE / MUTE / OPEN ORIGINAL | Same as keys, on the Watch chrome |
| Tap next-launch card | Expand / collapse mission detail |
| Tap upcoming / past card | Expand / collapse mission detail for that id |
| Past Missions header | Expand section (lazy-loads previous launches once) |
| Crew avatar (when linked) | Open Wikipedia / LL2 astronaut page |

### stickyWatch (Meet-style PiP)

Schema default is **`false`** (pause-on-hide). When **`true`**, Watch aims to
**stay up while you work, like Meet PiP** — Esc / click-away hides the panel
but MediaPlayer + `stream-proxy.py` keep running from a **BarWidget-hoisted**
player (outlives the keyboard panel). Treat sticky playback as
**best-effort** until verified on a live Omarchy shell / UTM VM.

- **`stickyWatch: false` (default):** Esc / hide **pauses** Watch, clears the
  stream URL, and **stops** `stream-proxy.py`. Reopening does **not**
  auto-resume — press **WATCH** / **PLAY** (or Space) again.
- **`stickyWatch: true`:** Esc / hide **keeps** MediaPlayer + the localhost
  proxy running in the background. The bar can show a **▶** glyph while Watch
  is active. Press **S** or the Watch **×** control to fully stop. Optional
  `systemd-inhibit --what=idle` runs while sticky Watch is playing (no
  privilege; skipped quietly if `systemd-inhibit` is missing). There is no
  safe `hyprctl` idle-inhibit dispatcher, so we do not call one.

### IPC

```sh
omarchy-shell shell toggle kenhara.rocketlauncher
omarchy-shell shell hide kenhara.rocketlauncher
```

Rocketlauncher is **`bar-widget` only** — use left / middle / right clicks on the
bar (and the keys above) rather than inventing summon payloads. Middle-click
play/pauses Watch when active, otherwise refreshes launch data; right-click
starts Watch for the next launch.

### Optional Hyprland bind

Paste into your own Hypr config if you want a key — **Rocketlauncher does not
edit** `~/.config/hypr/` or `shell.json` for you:

```ini
# hyprland.conf / binds.conf (example only)
bind = SUPER, L, exec, omarchy-shell shell toggle kenhara.rocketlauncher
```

## Configure

Omarchy has **no widget-settings GUI**. Prefer the in-panel toggles; CLI / `shell.json` are secondary.

### 1) In-panel Bar (preferred)

Open Rocketlauncher → scroll to the **Bar** section near the footer:

- **Countdown on bar** — On/Off (default On). When Off, the bar chip is just the rocket (optional mission name still respects `barShowMissionName` via CLI); countdown stays in the panel and tooltip.

Edits update the live store and mirror into bar settings so they survive reload.

### 2) CLI (`omarchy bar set`)

```sh
omarchy bar set kenhara.rocketlauncher barShowCountdown false
omarchy bar set kenhara.rocketlauncher barShowMissionName true
```

### 3) `~/.config/omarchy/shell.json` / schema

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `refreshIntervalSec` | integer | `1800` | Poll interval in seconds. **Minimum 600** so the free Launch Library 2 tier (15 req/hour) is never hammered. |
| `notifyMilestones` | bool | `false` | Opt-in `notify-send` once per launch id at **T−10** and **T−0** (debounced in `~/.cache/rocketlauncher/cache.json`). |
| `barShowMissionName` | bool | `false` | Prefix the bar countdown with a short mission name (CLI / `shell.json`; no in-panel switch). |
| `barShowCountdown` | bool | `true` | Show NET countdown on the bar chip. Prefer the in-panel **Countdown on bar** toggle. When off, chip is just the rocket (mission name still respects `barShowMissionName`); countdown stays in panel + tooltip. |
| `stickyWatch` | bool | `false` | Keep Watch playing when the panel hides — Meet-style PiP (see above). |
| `watchQuality` | enum | `best` | `best`, `720`, or `480` — passed to `scripts/stream-proxy.py` as yt-dlp height preference. |
| `flipAnimate` | bool | `true` | Animate flip-digit counters when totals change. |

## Remove

```sh
omarchy plugin remove kenhara.rocketlauncher
```

Optional cache cleanup:

```sh
rm -rf ~/.cache/rocketlauncher
```

## Data & network

**Primary API:** [Launch Library 2](https://ll.thespacedevs.com/docs/) (The Space Devs)  
Base: `https://ll.thespacedevs.com/2.3.0/` · Falcon / Starship launches via LSP agency id **121**

### Refresh cycle (default every 30 minutes, never faster than every 10)

Up to **three** list GETs on the regular refresh cycle:

1. `GET /agencies/121/` — totals (launches, landings, pending, consecutive successes)
2. `GET /launches/upcoming/?lsp__id=121&limit=5&mode=list` — upcoming list (compact)
3. `GET /spacecraft/?search=Crew%20Dragon&in_space=true` — ongoing Crew Dragon

On-click **LOCATE** (not on this cycle): LL2 spacecraft_flights + CelesTrak SATCAT/TLE.

### Past missions (lazy)

On **first expand** of the Past Missions section (not on every refresh):

4. `GET /launches/previous/?lsp__id=121&limit=5&mode=list` — recent past launches

Bundled `data/sample-cache.json` includes offline past rows from
`docs/research/samples/ll2-spacex-previous-*.json`.

### Mission detail (on demand)

When you open the panel or expand the next / upcoming / past card:

5. `GET /launches/{id}/` — **one detailed fetch per id**, then cached in
   `~/.cache/rocketlauncher/cache.json` and in-memory `launchDetails`.

Do **not** detailed-fetch every upcoming/past row. Stay under the free tier
(**15 req/hour**).

**Cache path:** `~/.cache/rocketlauncher/cache.json`  
Offline fixtures: `data/sample-cache.json`, plus
`data/sample-detail-crew.json` / `data/sample-detail-starlink.json` for UI demos.

Labels are honest LL2 agency fields:

- **LAUNCHES** → `total_launch_count`
- **Landings** → `successful_landings`
- **Pending** → `pending_launches`

No API key is used (free tier). No scrapers, no sudo, no second Quickshell
process. Pure QML + Qt network (+ optional local `yt-dlp` helper for Watch).

## Privacy and safety

- Network: `ll.thespacedevs.com` for launch data (https, host pinned after redirects); on-click LOCATE also hits `celestrak.org` (SATCAT + ISS TLE). When Watch is used,
  `yt-dlp` contacts the webcast host (YouTube / X / etc.) over **https only** and the helper
  binds **127.0.0.1 only**. Webcast / image URLs that are not https are dropped.
- Disk: read/write `~/.cache/rocketlauncher/cache.json` (atomic helper write; reads refuse symlink/FIFO); read bundled samples.
- Opens user-selected **https** webcast URLs in the default browser as a fallback.
- Optional `notify-send` toasts when `notifyMilestones` is enabled (FreeDesktop Notifications; `--` before title/body).
- Optional `systemd-inhibit --what=idle` while `stickyWatch` Watch is playing (user-session inhibit only; not used when sticky is off).
- Zero privilege beyond normal desktop user permissions inside `omarchy-shell`.

## License

MIT — see `LICENSE`. Copyright (c) 2026 Harris Kenny.

Icons from [Phosphor Icons](https://phosphoricons.com/) (regular weight) by
Helena Zhang and Tobias Fried, MIT. Paths are bundled in `PhosphorIcon.qml` and
painted with QML Shape/Path — no remote webfont, no `Image.source` of SVG.

Launch data © The Space Devs / Launch Library 2 contributors. Imagery URLs in
samples may carry CC BY-NC or NASA terms — this plugin does not redistribute
those binaries; it only links or references metadata. No SpaceX logos or
wordmarks are shipped. Unofficial; not affiliated with SpaceX or NASA.
