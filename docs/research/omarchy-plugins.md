# Omarchy Plugin Research Brief

**Purpose:** Competition entry research for a fun/visual Omarchy Quattro plugin  
**Deadline:** Monday 24 Aug 2026, 09:00 CEST  
**Judging:** Omarchy Core Team vote · prizes $2500 / $1000 / $500 · announce by Fri 28 Aug 2026  
**Eligibility:** Any plugin listed on the marketplace before the deadline (including already-listed)  
**Sources:** omarchyplugins.com develop/publish, marketplace repo `HANCORE-linux/omarchy-plugin-marketplace`, official `basecamp/omarchy` Quattro docs, competition news, registry snapshot (~989 sources / 500+ previewed plugins)  
**Research date:** Sat 22 Aug 2026 (America/Denver)

---

## 1. Competition context (what “wins”)

From [The first plugin competition](https://omarchy.org/news/2026/08/the-first-plugin-competition):

- Marketplace already has **500+ plugins**; creativity is exploding post-Quattro.
- Rules emphasize **ideas and execution**, not a formal rubric.
- Core Team will vote a podium — so standout demos that are immediately delightful, polished, and on-brand for Omarchy matter more than obscure utility.

**Implied judging axes (inferred from marketplace patterns + DHH framing):**

1. **Delight / originality** — memorable one-sentence pitch
2. **Visual polish** — theme-aware, animation, preview screenshot that pops
3. **Native Quattro fit** — correct kinds, Style/Color tokens, bar ↔ panel lifecycle
4. **Safe & clean packaging** — README install/remove, MIT (or clear license), no scary baseline findings
5. **Useful desktop integration** — lives on the bar, summons cleanly, doesn’t fight the shell

---

## 2. Architecture overview (Quattro / Quickshell)

Omarchy 4.0 “Quattro” replaced Waybar/Walker/Mako/etc. with **one long-running Quickshell process** (`omarchy-shell`). Almost everything visible is a **plugin**:

| Location | Contents |
|----------|----------|
| `$OMARCHY_PATH/shell/plugins/` | First-party / built-in |
| `~/.config/omarchy/plugins/<id>/` | Third-party / clones |

**Critical runtime facts:**

- Plugins share the shell process and run **unsandboxed** with the user’s permissions.
- Never spawn a second Quickshell process for a plugin.
- Distribution unit = **public GitHub repo** with root `manifest.json`.
- Install = `omarchy plugin add <git-url>` (clones, validates, does **not** run hooks/sudo).
- Hot reload on save under `~/.config/omarchy/plugins/`.
- IPC via `omarchy-shell shell <method> …` (`summon`, `hide`, `toggle`, `rescanPlugins`, …).

---

## 3. Plugin kinds — when to use each

| Kind | `entryPoints` key | Typical file | Use when |
|------|-------------------|--------------|----------|
| **`bar-widget`** | `barWidget` | `BarWidget.qml` | Always-visible bar item; primary discoverability surface. Most community plugins. |
| **`panel`** | `panel` | `Panel.qml` | Floating / anchored popout (calendar, game board, settings). Can also be nested *inside* a bar-widget via Loader (clock pattern) without declaring `panel` kind. |
| **`overlay`** | `overlay` | `Overlay.qml` | Fullscreen experience (emoji picker, CRT effect, tower-defense canvas, image picker). |
| **`menu`** | `menu` | `Menu.qml` | Summoned menu surface (Omarchy menu style). |
| **`service`** | `service` | `Service.qml` | Headless singleton: input listeners, ambient effects, media backends, lock overlays. Pair with bar-widget for controls. |
| **`bar`** | `bar` | `Bar.qml` | Full bar replacement (rare; e.g. Lacuna suite). Only one active. |

**Combo patterns that work well for fun/visual entries:**

1. **`bar-widget` only** — bar button opens nested `Panel.qml` via Loader (official clock / Minesweeper / Game of Life / Coin Toss). Simplest; matches develop tutorial.
2. **`bar-widget` + `panel`** — explicit panel kind + bar launcher (Breakout, Flappy Pipes). Good for games summonable by IPC *and* bar click.
3. **`bar-widget` + `overlay`** — fullscreen game/ambience with bar toggle (Omatower Defense).
4. **`service` + `bar-widget`** — persistent visual (Phosphor CRT, Bongo Cat) controlled from the bar.
5. **`service` only** — pure ambient / lock interaction (Omasmash). Harder to discover; usually pair with bar UI.

**`keepLoaded: true`:** use for overlays/services that must survive between summons (CRT ambience, input-reactive pets, lock overlays).

**Nested panel rule (important):** If `BarWidget.qml` loads `Panel.qml` internally, keep `kinds: ["bar-widget"]` only — do **not** also declare a `panel` kind unless you intentionally expose a standalone panel entry point.

---

## 4. Manifest schema (correct fields)

### Required (marketplace + `omarchy plugin validate`)

| Field | Notes |
|-------|--------|
| `schemaVersion` | Must be `1` |
| `id` | Unique, namespaced, **not** `omarchy.*`. Prefer `io.github.user.name`. Permanent; retired IDs stay blocked. |
| `name` | Human-readable title |
| `version` | Semver-ish; marketplace displays ≤64 chars |
| `author` | Shown in marketplace |
| `description` | Short marketplace blurb |
| `kinds` | Array of kinds above |
| `entryPoints` | Map kind → safe relative QML path; file must exist; kind/key must agree |

### Strongly recommended for listing

| Field | Notes |
|-------|--------|
| `license` | e.g. `"MIT"` + root `LICENSE` file |
| `barWidget` block | When kind includes `bar-widget` |

### `barWidget` block

```json
"barWidget": {
  "displayName": "…",
  "description": "…",
  "category": "Fun",
  "allowMultiple": false,
  "defaultSection": "right",
  "aliases": ["optional", "search", "terms"],
  "defaults": { },
  "schema": [ ]
}
```

- `defaultSection`: `left` | `center` | `right` (default `center` if omitted)
- `allowMultiple`: usually `false`; `true` for spacers/indicators
- `schema` / `defaults`: optional inline settings (Bongo Cat, Coverglow, Game of Life excel here)

### Other useful top-level keys

- `keepLoaded`, `activation` (`on-demand` / `persistent`)
- `keywords`, `homepage`, `repository`
- Dev-only: `omarchy.clonedFrom` while cloning a built-in — **remove before publish**

### Canonical bar-widget template

See `examples/manifest-template-bar-widget.json` and `examples/manifest-template-overlay.json`.

Publish-guide minimal overlay example:

```json
{
  "schemaVersion": 1,
  "id": "yourname.plugin",
  "name": "Plugin name",
  "version": "1.0.0",
  "author": "Your name",
  "description": "What the plugin does.",
  "kinds": ["overlay"],
  "entryPoints": { "overlay": "Plugin.qml" }
}
```

### Validation checklist

```bash
omarchy plugin clone omarchy.clock --edit   # or start from scratch
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR"/*.qml
omarchy-shell shell rescanPlugins
omarchy plugin list --json | jq --arg id "$PLUGIN_ID" '.[] | select(.id == $id)'
omarchy-shell shell summon "$PLUGIN_ID" '{}'
omarchy-shell shell hide "$PLUGIN_ID"
```

Validate rejects: missing fields, kind/entrypoint mismatch, missing files, `omarchy.*` third-party IDs, **symlinks** in the folder.

---

## 5. Clone → develop → publish workflow

1. **Clone a matching built-in** (`omarchy plugin clone omarchy.clock --edit`) when building bar+panel.
2. Keep temporary clone ID while iterating; auto-reload on save.
3. Implement QML using `qs.Ui` / `qs.Commons` (`BarWidget`, `WidgetButton`, `Panel`, `KeyboardPanel`, `PanelKeyCatcher`, `Style`, theme colors).
4. Forward panel lifecycle from bar entry: `opened`, `open()`, `close()`, `toggle()`, `closeForPopoutSwitch()`, inject `bar` / `anchorItem` / `hostWidget`.
5. Validate + qmllint.
6. Replace ID with permanent namespaced ID; remove `omarchy.clonedFrom`.
7. Public GitHub repo root: `manifest.json`, QML, `README.md`, `LICENSE`, optional `preview.png|jpg|webp|avif`.
8. Submit via marketplace issue form (or CLI format in `SUBMISSION.md`).
9. Automated validation + Automated Security Baseline on **exact commit**; maintainer `approved-and-verified` before listing.

Install/remove users expect:

```sh
omarchy plugin add https://github.com/you/repo.git --enable
omarchy bar move your.id --section right   # if bar-widget
omarchy plugin remove your.id
```

---

## 6. Marketplace landscape (what’s popular)

**Registry snapshot (~989 sources):**

| Category | Approx. count |
|----------|---------------|
| Widgets | 346 |
| Productivity | 190 |
| System | 125 |
| Developer Tools | 79 |
| Appearance | 76 |
| Hardware | 76 |
| Desktop | 72 |
| Other | 27 |

**Dominant tags:** `bar`, `quickshell`, then `system`, `hyprland`, `media`, `ai`, `launcher`, `workspaces`.

**Security baseline outcomes (listed sources with scans):** ~542 `passed`, ~370 `review-required`, ~6 `needs-fixes`. Common review capabilities: `package-manager`, `installer`, `privilege`, `service-management`, `remote-build`.

**Engagement metrics on site:** detail views, command copies, hearts — marketplace interactions, **not** installs/security signals. Sort options include recently added, starred, viewed, copied, hearts, verified.

**Success patterns observed:**

- Tiny bar affordance + rich popout (Agents Usage, Coverglow, Coin Toss)
- Theme-synced visuals (games that “use your theme’s colours”)
- Dual entry (bar + panel/overlay) for discoverability + IPC summon
- Settings schema so power users can tune without editing QML
- Clear one-line description + preview asset
- Fun category that still feels “desktop native,” not a random Electron game

---

## 7. Standout plugins (study these)

### Visual / ambient polish

1. **Phosphor (CRT overlay)** — `io.github.ejuro.phosphor`  
   - Repo: https://github.com/ejuro/phosphor-crt-overlay  
   - Kinds: `service` + `bar-widget`  
   - Why it stands out: full-desktop CRT (scanlines, phosphor mask, bloom, bezel) independent of theme; bar control; baseline `passed`. Peak “wow in 5 seconds.”  
   - Manifest: `examples/manifest-phosphor.json`

2. **Lacuna CRT Overlay** (suite piece) — `lacuna.crt-overlay`  
   - Repo: https://github.com/OldJobobo/lacuna-omarchy-plugins  
   - Kind: `overlay` + `keepLoaded` + rich `schema`  
   - Why: production-grade ambience controls (intensity, bloom pulse, distortion, vignette). Shows how far overlays can go as *desktop atmosphere*.  
   - Manifest: `examples/manifest-lacuna-crt.json`

3. **Coverglow** — `io.github.adityavijayvargiya01.coverglow`  
   - Repo: https://github.com/Adityavijayvargiya01/coverglow  
   - Kind: `bar-widget`  
   - Why: album-art-driven chrome/colors; vertical/horizontal layouts; excellent “useful + beautiful” media integration.  
   - Manifest: `examples/manifest-coverglow.json`

### Character / animation

4. **Bongo Cat** — `hancore.bongocat`  
   - Repo: https://github.com/HANCORE-linux/omarchy-bongocat  
   - Kinds: `bar-widget` + `service`, `keepLoaded`  
   - Why: keyboard-reactive pet, drag positioning, workspace awareness, rich settings schema. Fun mascot energy with real polish. Note: baseline often `review-required` (input/session capabilities) — document what you touch.  
   - Manifest: `examples/manifest-bongocat.json`

### Games with theme-native UI

5. **Game of Life** — `io.github.guillechuma.gameoflife`  
   - Repo: https://github.com/guillechuma/gameoflife  
   - Kind: `bar-widget`  
   - Why: retro LED matrix, theme-synced, tunable cols/rows/speed/trail via schema. Compact visual loop that belongs on a status bar.  
   - Manifest: `examples/manifest-gameoflife.json`

6. **Omarchy Breakout** — `acrogenesis.breakout`  
   - Repo: https://github.com/acrogenesis/omarchy-breakout  
   - Kinds: `panel` + `bar-widget`  
   - Why: multi-level campaign, explicit IPC summon documented in description, dual kind pattern for games.  
   - Manifest: `examples/manifest-breakout.json`

7. **Flappy Pipes** — `eduardodallecort.flappy-pipes`  
   - Repo: https://github.com/eduardodallecort/omarchy-flappy-pipes  
   - Kinds: `panel` + `bar-widget`  
   - Why: “original physics, your theme’s colours” — the winning marketing line for fun plugins.  
   - Manifest: `examples/manifest-flappy-pipes.json`

8. **Minesweeper / Tetris (terminal theme-aware)**  
   - https://github.com/acobrerosf/omarchy-minesweeper (`terminal.minesweeper`)  
   - https://github.com/Ycaro-Oleg/omarchy-my-tetris (`terminal.tetris`)  
   - Why: classic games that *follow Omarchy theme*; bar-widget + panel Loader pattern aligned with develop docs.

9. **Omatower Defense** — `perfektnacht.omatower-defense`  
   - Repo: https://github.com/perfektnacht/omatower-defense  
   - Kinds: `overlay` + `bar-widget`, `keepLoaded`  
   - Why: ambitious fullscreen game with Omarchy in-jokes; shows overlay-as-canvas. High execution bar.  
   - Manifest: `examples/manifest-omatower-defense.json`

10. **Coin Toss** — `com.aktivesolutions.cointoss`  
    - Repo: https://github.com/alkevintan/omarchy-cointoss  
    - Kind: `bar-widget`  
    - Why: tiny scope, delightful animation, `/dev/urandom` honesty, history so you can’t re-roll — witty copy + craft.  
    - Manifest: `examples/manifest-cointoss.json`

### Reference built-ins (architecture gold)

- **Agents** `omarchy.agents` — bar-widget with deep panel + schema (develop.html cites this alongside clock). `examples/manifest-builtin-agents.json`
- **Emojis / Clipboard** — `overlay` + `keepLoaded` pattern. `examples/manifest-builtin-emojis.json`, `manifest-builtin-clipboard.json`

---

## 8. Visual patterns that “win”

| Pattern | Why it works | Examples |
|---------|--------------|----------|
| **Theme tokens everywhere** | Feels native, not a bolted-on skin | Flappy, Minesweeper, Game of Life, Coverglow |
| **Bar glyph → rich surface** | Low daily cost, high delight on click | Clock tutorial, Agents, Coin Toss |
| **Subtle continuous motion** | Desktop feels alive without being noisy | CRT scanlines, LED trails, Coverglow |
| **Reactive to real desktop events** | Integration > gimmick | Bongo Cat (keys), Coverglow (MPRIS), Phosphor (session) |
| **Fullscreen only when summoned** | Respects tiling workflow | Overlay games, emoji picker |
| **Schema knobs** | Judges/power users can personalize | Bongo, Lacuna CRT, Game of Life |
| **Strong preview.png** | Marketplace card is first impression | Auto-optimized card/detail webp |
| **Witty one-liner description** | Core Team reads hundreds — stickiness | Omasmash, Coin Toss, Flappy |

**Prefer for a fun competition entry:**

- **Primary:** `bar-widget` (+ nested panel) *or* `overlay`+`bar-widget`
- **Secondary:** optional `service` if you need persistent animation/input
- Avoid replacing the whole `bar` unless the entire product is a shell suite (Lacuna-scale)

---

## 9. Concrete best practices for a competition-winning fun/visual plugin

1. **One unforgettable idea** — pitch in ≤15 words; demo in ≤10 seconds of video/GIF.
2. **Clone the right archetype** — clock for bar+panel; emojis/clipboard for overlay; agents for data-rich panel.
3. **Use Omarchy Style/Color** — `Style.space()`, `Style.font.*`, `root.barForeground`, theme singletons; never hardcode a foreign palette as the only look.
4. **Animation with restraint** — 60fps-friendly QML/`ShaderEffect` where needed; pause when hidden; respect reduced-motion if feasible.
5. **Correct lifecycle** — Escape closes; `summon`/`hide`/`toggle` work; reopening after close works (forward `opened`/`open`/`close`).
6. **Namespaced permanent ID** before submit — search marketplace first.
7. **README with Install / Usage / Configure / Remove** — copy develop tutorial shape; list every process, network, and path you touch.
8. **MIT + LICENSE** — match community norm; keep DHH copyright line only if deriving Omarchy samples appropriately.
9. **preview.webp/png** — clear hero shot of the visual effect in a real Omarchy desktop.
10. **Pass Automated Security Baseline** — no curl|sh, no unpinned remote builds, no passwordless sudo; avoid packaging installers unless necessary.
11. **Category/tags for listing** — Fun games → often `Widgets` or `Other` + tags `bar`, `quickshell` (and `hyprland`/`media` if relevant). Marketplace categories are fixed: Appearance, Desktop, Developer Tools, Hardware, Productivity, System, Widgets, Other.
12. **Ship before Mon 09:00 CEST** — listing needs validation + maintainer approval; submit early (hours of buffer).
13. **Don’t fight Quattro** — no second Quickshell; no overwriting user config without consent; clean `omarchy plugin remove`.

---

## 10. Security & marketplace requirements

### Unsandboxed caveat (repeat everywhere)

> Plugins execute as unsandboxed third-party code inside `omarchy-shell` with the user’s full permissions. Marketplace listing ≠ security audit.

### Listing requirements (`publish.html` + `SUBMISSION.md` + `SECURITY.md`)

- Public GitHub repository  
- Valid root `manifest.json`  
- README with **install and removal**  
- License + documented external dependencies  
- Safe install/removal (no silent config overwrite)  
- Optional root preview (≤50 MB / 40 MP); marketplace generates card/detail images  
- Unique ID outside `omarchy.*`  
- Exact-commit Automated Security Baseline + maintainer `approved-and-verified`

### Baseline findings to avoid

- `curl-pipe-shell`  
- Unpinned `cargo install --git` / remote git execution  
- Dangerous passwordless sudoers  
- Privileged process control from shared `/tmp` PID files  

### Capabilities that force maintainer review (OK if justified & documented)

`installer`, `package-manager`, `privilege`, `remote-build`, `bundled-executable-binary`, `service-management`, `sudoers-modification`

**Competition tip:** Aim for baseline **`passed`** with empty capabilities. Fun visual plugins rarely need privilege — prefer pure QML + Quickshell APIs.

---

## 11. Pitfalls to avoid

| Pitfall | Consequence |
|---------|-------------|
| Using `omarchy.*` ID as third party | Validation/reject |
| Declaring both nested panel *and* `panel` kind incorrectly | Double registration / load bugs |
| Not forwarding panel open/close from bar widget | Opens once, never again |
| Symlinks in plugin folder | `omarchy plugin validate` fails |
| Leaving `omarchy.clonedFrom` in published manifest | Wrong disable/remove behavior |
| Hardcoded colors only | Looks alien across themes |
| Heavy always-on overlay without toggle/`keepLoaded` discipline | Perf / annoyance |
| Curl\|bash installers, sudo, bundled binaries | Security review delay or block |
| Missing README remove steps | Submission checklist fail |
| Submitting at the last minute | May miss maintainer approval before deadline |
| Spawning another Quickshell | Explicitly forbidden in develop docs |
| Editing `$OMARCHY_PATH` instead of cloning | Overwritten on update |
| Reusing a retired plugin ID | Permanently unavailable |
| Treating marketplace “verified” as safety cert | Users still must read source; HEAD installs aren’t verification-bound |

---

## 12. Recommended architecture for *this* competition entry

Given the SpaceX-themed project path and deadline:

**Suggested shape:** `bar-widget` + nested details panel **or** `overlay` + `bar-widget`, theme-aware motion/graphics, zero privilege, MIT, strong preview.

**Why:** Matches the densest cluster of successful fun plugins, validates easily, demos well for Core Team voting, and avoids security-review lag.

**Day plan (before Mon 09:00 CEST):**

1. Finalize concept + ID + preview mock  
2. Scaffold from clock clone or overlay builtin  
3. Polish animation + theme integration  
4. Validate, README, LICENSE, preview  
5. Submit marketplace issue **≥12–24h before deadline**  
6. Keep HEAD stable after listed commit / follow update rules if needed  

---

## 13. Key links

| Resource | URL |
|----------|-----|
| Marketplace | https://omarchyplugins.com/ |
| Develop guide | https://omarchyplugins.com/develop.html |
| Publish guide | https://omarchyplugins.com/publish.html |
| Marketplace repo | https://github.com/HANCORE-linux/omarchy-plugin-marketplace |
| Competition news | https://omarchy.org/news/2026/08/the-first-plugin-competition |
| Manual: shell plugins | https://omarchy.org/manual/shell-plugins/ |
| Official docs (Quattro) | https://github.com/basecamp/omarchy/blob/quattro/docs/omarchy-shell.md |
| Official plugins list | https://github.com/basecamp/omarchy/blob/quattro/shell/plugins/README.md |
| Submission guide | https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/main/SUBMISSION.md |
| Security policy | https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/main/SECURITY.md |

---

## 14. Examples directory index

Saved under `docs/research/examples/`:

- `registry.json` — marketplace registry snapshot  
- `manifest-template-*.json` — starter templates  
- `manifest-*.json` — real standout + builtin manifests  
- `readme-*.md` — excerpts from polished plugins  
- `official-*.md`, `marketplace-*.md` — upstream docs mirrors  

---

*End of brief.*
