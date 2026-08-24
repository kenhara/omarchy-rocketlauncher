# Rocketlauncher — next ideas from Omarchy Quattro plugins

**Purpose:** Prioritized “steal / skip” list for `kenhara.rocketlauncher` before marketplace submit.  
**Refresh date:** Sun 23 Aug 2026 (America/Denver)  
**Deadline context:** Competition Mon 24 Aug 2026, 09:00 CEST (~01:00 MDT) — ship buffer matters.  
**Baseline research:** `docs/research/omarchy-plugins.md` (22 Aug) — this doc refreshes official + marketplace standouts and maps gaps onto **current** Rocketlauncher (v1.2.0).

**Already shipped (do not redo):** bar countdown · flip stats · mission detail · crew avatars · Watch (yt-dlp + Qt Multimedia) · LL2 data · theme-token *intent* · unofficial disclaimer · README install/IPC/remove · single schema knob `refreshIntervalSec`.

---

## 1. Official / first-party plugins — UX patterns that matter

Source: `basecamp/omarchy` `shell/plugins/README.md` + `docs/omarchy-shell.md` (quattro), refreshed 23 Aug 2026.

| Plugin | id | kinds | Pattern to steal for Rocketlauncher |
|--------|-----|-------|----------------------------------|
| **Clock** | `omarchy.clock` | `bar-widget` | Tiny bar text → nested calendar panel; format via bar settings; **archetype Rocketlauncher already follows**. |
| **Agents** | `omarchy.agents` | `bar-widget` | Data-rich panel + **deep `schema`/`defaults`** (refresh, sync paths, enums). Meters + “pace” narrative — polish for stats panels. |
| **Media** | `omarchy.media` | `service` + `bar-widget` | System MPRIS transport lives in the shell; custom players should **play nice** (pause when shell media pauses / don’t fight Coverglow). |
| **Notifications** | `omarchy.notifications` | `service` | Owns `org.freedesktop.Notifications`. Third-party alerts = **`notify-send`** (Coin Toss pattern); DND-aware; use sparingly. |
| **OSD** | `omarchy.osd` | `panel` | Volume/brightness flash — **not** for mission alerts; use notifications instead. |
| **Reminders** | `omarchy.reminders` | `overlay` | Timed user flows — overkill for T−10; toast is enough. |
| **Emojis / Clipboard / Image picker** | overlays | `overlay` + often `keepLoaded` | Fullscreen on demand; **irrelevant** unless Rocketlauncher ever grows a patch/image browser. |
| **Menu** | `omarchy.menu` | `menu` + `bar-widget` | Summon via IPC; JSONC extensions — don’t compete. |
| **Audio / Network / Power / Bluetooth / Weather / Monitor / Tailscale** | bar-widgets | nested panels | Compact bar glyph + focused popout; section-aware placement. |
| **Battery / Idle / Night light / Lock / Polkit** | services | headless | Session lifecycle — only relevant if Watch should inhibit idle (nice-to-have later). |
| **Bar** | `omarchy.bar` | `bar` | Full replacement — **skip** (Lacuna-scale). |

**IPC contract worth documenting (already partially in README):**

```sh
omarchy-shell shell toggle kenhara.rocketlauncher
omarchy-shell shell summon kenhara.rocketlauncher '{}'
omarchy-shell shell hide kenhara.rocketlauncher
# Future: summon with payload e.g. '{"watch":true}' or '{"launchId":"..."}'
```

**Style contract:** `Color` / `Style.space` / `Style.font.*` / `Style.cornerRadius` / `bar.foreground` — Agents + Clock winners; theme-audit still flags hardcoded SpaceX greys in Panel/MissionCard/FlipCounter.

---

## 2. Marketplace standouts — features Rocketlauncher lacks

| Plugin | What they do well | Gap vs Rocketlauncher today |
|--------|-------------------|---------------------------|
| **Agents** (`omarchy.agents`) | Rich schema (refresh, syncMode enum, paths); dense but scannable panel | Only one schema key (`refreshIntervalSec`). Need more power-user knobs without QML edits. |
| **Coverglow** | Album-tint chrome; **middle-click play/pause**, right-click layout; scroll next/prev; keyboard map; section-aware popup; suggested Hypr bind in README | No middle/right-click bar actions; no Watch keyboard map beyond Escape; popup is anchor-based OK. |
| **Coin Toss** | Witty copy; **right-click = instant action**; schema (`notify`, linger, history); `/dev/urandom` honesty; keybind snippet; history persistence | No right-click shortcut (e.g. refresh / open Watch); no optional `notify`; bar could linger “LIVE” / “T−10” state. |
| **Normarchy** | Sticky panel while video plays; **Esc hides, audio continues**; Space/M/O/S shortcuts; middle-click stop; tokenized 127.0.0.1 proxy; optional Hypr bind; strong disclaimer | Rocketlauncher **pauses + stops proxy on panel hide** — opposite sticky model. Buttons exist; **no key bindings** for Space/Mute/Open. |
| **omaStream** | Overlay + service + bar; quality menu; audio-only; Esc leaves fullscreen then closes; **closing overlay keeps playback for bar control**; middle/right/wheel on bar | Overbuilt for a rocketlauncher. Steal: quality enum, sticky playback option, bar transport clicks — not Discover/download. |
| **Phosphor** | CRT ambience; bar toggle; dedicated IPC (`phosphor toggle`); honest perf cost callouts | Do **not** add CRT overlay. Steal: right-click toggle, named IPC, “costs GPU” honesty for Watch. |
| **Lacuna** (suite / CRT overlay) | Production schema for ambience; full `bar` replacement; connected shell | **Skip** suite / `kind: bar`. Schema richness is the only lesson. |
| **Bongo Cat** | Workspace filter; drag lock; rich schema; multi-button bar; keyboard in panel | Workspace awareness **low value** for a status widget. Skip input/Polkit. Steal: schema completeness + click modifiers. |
| **Game of Life** | Theme-synced LED; schema cols/rows/speed/trail; pause when `!opened` | Motion already pauses when closed/watching. Steal: more visual knobs (`starfield`, `flipAnimate`). |
| **Breakout / Flappy** | Dual kind panel+bar; **IPC summon with payload**; keyboard table in README; theme colours marketing line | Stay `bar-widget` only. Steal: README controls table + `summon '{"watch":true}'` docs. |
| **Games generally** | Delight + theme | Skip game loops; Rocketlauncher’s “game” is countdown + Watch. |

---

## 3. Prioritized incorporate list

### A. Must-have before submit

Concrete work that raises Core Team “native + delightful” score without scope blow-up. Aim to finish **hours before** listing review.

| # | Item | Concrete implementation | Why (source pattern) |
|---|------|-------------------------|----------------------|
| 1 | **Theme-native chrome** | Finish theme-audit: replace hardcoded `#19191c` / `#f0f0fa` / badge hex with `Color` + `bar.foreground` alpha fills; radii via `Style.cornerRadius`. Keep SpaceX mood as **letter-spacing / uppercase / low-alpha starfield**, not a private palette. | Flappy / Minesweeper / Coin Toss / Agents — “your theme’s colours.” |
| 2 | **Watch keyboard shortcuts** | In `PanelKeyCatcher` / focused panel: `Space` play/pause · `M` mute · `O` open original · (optional) `S` stop Watch. Document in README table. | Normarchy, Coverglow, omaStream, Breakout. |
| 3 | **Richer `barWidget.schema`** | Add at least: `notifyMilestones` (bool, default false) · `barShowMissionName` (bool) · `stickyWatch` (bool, default false) · `watchMaxHeight` (int, optional). Wire to `LaunchStore` / settings inject. | Agents, Game of Life, Coin Toss, Coverglow. |
| 4 | **T−10 / T−0 toast (opt-in)** | When `notifyMilestones` and countdown crosses 600s / 0: `notify-send -a "Rocketlauncher" -u normal "T−10: <mission>"` (and once at liftoff window). Debounce per launch id in cache. Off by default. | Coin Toss `notify`; `omarchy.notifications` via FreeDesktop. |
| 5 | **Preview quality** | Replace thin 1200×800 SVG-ish card (~41 KB) with a **real Omarchy desktop screenshot**: bar rocket+countdown visible, panel open showing flip digits + one mission card (+ Watch poster if possible). Prefer ~1600–2560 wide webp/png; marketplace auto-generates cards. | Lacuna hero shots; Phosphor/Normarchy/omaStream marketplace first impression. |
| 6 | **README controls + IPC + optional bind** | Add Controls table (click / keys / middle-click if added). Document summon/hide/toggle. Optional Hypr snippet `o.bind` / `hl.bind` for toggle — **do not** write user’s bindings file. Expand disclaimer already present. | Breakout, Normarchy, Coverglow, Coin Toss. |
| 7 | **Validate + baseline-clean** | `omarchy plugin validate`; no `omarchy pkg add` in README (omaStream tripped `package-manager`); keep deps as `pacman`/`pipx` optional; no sudo scripts. | Marketplace SECURITY baseline; competition tip: aim `passed`. |

### B. Nice-to-have (post-list or if time remains)

| # | Item | Concrete | Why / caveat |
|---|------|----------|--------------|
| 8 | **Sticky Watch (`stickyWatch`)** | When true: Esc / click-away **hides panel but keeps MediaPlayer + proxy** (Normarchy); bar shows ▶ / muted glyph; middle-click bar stops. When false (current): pause+teardown on hide. | Normarchy / omaStream — big UX win for live webcasts; needs careful lifecycle + proxy GC. |
| 9 | **Bar click modifiers** | Left = toggle panel; **middle** = play/pause Watch if active else refresh; **right** = open Watch / open original. | Coverglow, Coin Toss, Bongo, omaStream. |
| 10 | **MPRIS pause cooperation** | Expose Watch via MPRIS (or pause MediaPlayer when `omarchy.media` / Coverglow issues Pause on “Rocketlauncher” player). At minimum: pause Watch when another MPRIS player starts (optional schema). | Coverglow + `omarchy.media`. Harder than notify; skip if sticky Watch unfinished. |
| 11 | **Watch quality schema** | `watchHeight`: `best` \| `720` \| `480` → yt-dlp format args in `stream-proxy.py`. | omaStream QualityMenu; yt-dlp queue plugins. |
| 12 | **Summon payloads** | `summon '{"watch":true}'` starts Watch for next launch; `{"launchId":"…"}` expands that card. Register docs like Breakout `{"level":3}`. | Breakout IPC craft. |
| 13 | **Idle inhibit while Watching** | Call Hyprland / shell idle inhibit only while `stickyWatch` playing — release on stop. | Lock/idle first-party services; prevents blank mid-stream. |
| 14 | **Visual schema knobs** | `starfieldEnabled`, `flipAnimate` — Game of Life trail/speed style. | Polish only. |
| 15 | **Section-aware panel edge** | If shell supports it like Coverglow `edgeGap`, respect left/center/right. | Coverglow — verify KeyboardPanel already anchors correctly first. |

### C. Skip (with why)

| Idea | Why skip |
|------|----------|
| Full **Phosphor / Lacuna CRT** overlay | Wrong product; GPU tax; competes with ambience plugins; Rocketlauncher already has faint scanline. |
| **`kind: "bar"`** / Lacuna-style shell suite | Competition winners cluster on bar-widget+panel; full bar is a product line. |
| **Bongo** workspace filter / Polkit input | Irrelevant + review-required capabilities. |
| **Game loops** (Breakout/Flappy/GoL mechanics) | Dilutes Rocketlauncher pitch; theme/keyboard/README lessons already extracted. |
| **omaStream Discover / download manager** | Scope bomb; pulls ffmpeg/jq/`package-manager` findings; Watch already Normarchy-sized. |
| **QtWebEngine** YouTube/X embed | Not a safe Quattro assumption; community players use yt-dlp. |
| **Fake SpaceX “reflights” counter** | DESIGN.md honesty rule; LL2 lacks that agency field. |
| **Auto-editing Hyprland bindings / shell.json** | Normarchy/Coin Toss explicitly refuse; users paste snippets. |
| **Second Quickshell / Electron SPA** | Forbidden / anti-pattern. |
| Claiming SpaceX affiliation / shipping logos | Disclaimer already correct — keep. |

---

## 4. Suggested pre-submit sequence (timeboxed)

1. **Theme tokens** (must #1) — visual “native” gate.  
2. **Watch keys + README controls** (must #2, #6).  
3. **Schema: notify + sticky flag + bar mission name** (must #3–4); implement notify; sticky can land as wired default-false stub if short on time.  
4. **Hero `preview.png`** (must #5) on a themed Omarchy desktop.  
5. **Validate / lint / security README pass** (must #7).  
6. If >2 h left: sticky Watch true-path + middle-click (#8–9).  
7. Submit marketplace issue with buffer; freeze HEAD used for verification.

---

## 5. One-line pitch check (keep)

> Rocketlauncher on your Omarchy bar — flip-digit Falcon & Starship stats, countdown, mission detail, Watch.

After must-haves, the demo script for judges: open panel → flips → expand mission → Space plays Watch → Esc → (optional) toast at T−10 with notify on.

---

## 6. Source links (refreshed)

| Resource | URL |
|----------|-----|
| Official plugins list | https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md |
| omarchy-shell docs | https://github.com/basecamp/omarchy/blob/quattro/docs/omarchy-shell.md |
| Manual: shell plugins | https://omarchy.org/manual/shell-plugins/ |
| Normarchy | https://github.com/ctl0v0/normarchy |
| omaStream | https://github.com/yaredow/omastream |
| Coverglow | https://github.com/Adityavijayvargiya01/coverglow |
| Coin Toss | https://github.com/alkevintan/omarchy-cointoss |
| Phosphor | https://github.com/ejuro/phosphor-crt-overlay |
| Lacuna | https://github.com/OldJobobo/lacuna-shell |
| Bongo Cat | https://github.com/HANCORE-linux/omarchy-bongocat |
| Breakout | https://github.com/acrogenesis/omarchy-breakout |
| Agents manifest (builtin) | `docs/research/examples/manifest-builtin-agents.json` |

---

*End of next-ideas brief.*
