# Rocketlauncher — Theme & Native Patterns Audit

**Date:** 2026-08-23 (America/Denver)  
**Sources:** all QML at repo root; community raw QML from Coin Toss, Minesweeper, Game of Life, Coverglow; `docs/research/omarchy-plugins.md`; `docs/research/examples/official-omarchy-shell.md`.

---

## 1. Hardcoded colors / fonts that fight the system theme

| Location | Value | Problem |
|----------|-------|---------|
| `Panel.qml` `surfaceColor` | `Qt.rgba(0.098, 0.098, 0.110, 0.92)` | Fixed near-black card; washes out / looks alien on light or tinted themes |
| `Panel.qml` `digitWell` | `Qt.rgba(0.145, 0.149, 0.157, 1)` | Fixed gray digit wells; ignore `Color` / bar palette |
| `Panel.qml` starfield Canvas | `fillStyle = "#f0f0fa"` (stars + scanlines) | SpaceX.com white; ignores `bar.foreground` / `Color.foreground` |
| `MissionCard.qml` defaults | `foreground: "#f0f0fa"`, `surfaceColor: "#19191c"` | Defaults assume dark SpaceX skin when props omitted |
| `MissionCard.qml` `badgeColor()` | `#1a3d2a`, `#4a1a1a`, `#3a3420`, `#1a2a3d` | Fixed dark semantic wells — invisible or muddy on light themes |
| `MissionCard.qml` `badgeFg()` | `#7dffa0`, `#ff8a8a`, `#ffd27a`, `#8ac4ff` | Fixed neon badge text — clash with theme accent |
| `MissionCard.qml` radii | `8`, `3`, `4` | Bypass `Style.cornerRadius` |
| `FlipCounter.qml` defaults | `foreground: "#f0f0fa"`, `accentColor: "#252628"` | Same dark-only assumption |
| `FlipCounter.qml` digit cell | `radius: 3` | Should follow `Style.cornerRadius` (scaled) |
| Fonts | Mostly OK via `bar.fontFamily` / `Style.font.*` | Fallback `"sans-serif"` in FlipCounter/MissionCard is fine as last resort; prefer `Style.font.family` |

**Already theme-correct (keep):**

- `BarWidget.qml`: `root.bar.foreground`, `root.bar.fontFamily`, `Color.foreground` / `Style.font.family` fallbacks; `WidgetButton` with `bar:` injected.
- `Panel.qml` text / headers / separators: `contentForeground`, `contentFontFamily`, `Style.space()`, `Style.font.*`, opacity tokens (`0.35`–`0.55`).
- Lifecycle forwarding on `BarWidget` (`opened`, `open`/`close`/`toggle`/`closeForPopoutSwitch`, Loader inject).

---

## 2. How winners use Style / Color / bar tokens

### Official shell (`official-omarchy-shell.md`)

- **`Color`:** `foreground`, `background`, `accent`, `urgent` + surface roles (`Color.popups.*`, `Color.bar.*`, …).
- **`Style`:** `Style.space(px)`, `Style.font.*`, `Style.cornerRadius`, `Style.bar.*`.
- **Bar module:** `bar.foreground` / `background` / `urgent` / `fontFamily` / `position` / `vertical` / `barSize`.

### Coin Toss (`alkevintan/omarchy-cointoss` — Panel-as-entry)

```qml
readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
readonly property color dim: Qt.darker(root.foreground, 1.45)
readonly property color fainter: Qt.darker(root.foreground, 1.7)
// fills: Qt.rgba(foreground.r,g,b, 0.04–0.08)
// accents: Color.accent for verdict highlight
// UI chrome: Style.space, Style.font.*, PanelSectionHeader, Button, PanelSeparator
```

### Minesweeper (`acobrerosf/omarchy-minesweeper` — bar-widget + nested Panel)

```qml
readonly property color contentForeground: bar ? bar.foreground : Color.foreground
readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
// Buttons / headers take foreground + fontFamily; no foreign palette
// BarIconButton + Style.bar.iconSlot
```

### Game of Life (`guillechuma/gameoflife`)

```qml
readonly property color bgColor: (root.bar && root.bar.barBackground)
  ? root.bar.barBackground : Color.background
// All canvas / button fills from barForeground + bgColor + Qt.rgba(..., alpha)
// Timers: running: root.playing && root.opened  (pause when closed)
```

### Coverglow (`Adityavijayvargiya01/coverglow`)

- Base surfaces: `Color.popups.background`, `Color.accent`.
- **Secondary** art tint from album art, blended *into* theme (`artFill` alpha 0.18) — never replaces theme as the only palette.
- `Style.space`, `Style.font.*`, `Style.cornerRadius`, `Border.flat`.

**Pattern to copy:** theme tokens lead; brand/art accents are secondary alpha overlays; dimming via `Qt.darker(foreground, …)` or `opacity` on `contentForeground`; pause motion when `!opened`.

---

## 3. Lifecycle / Panel / BarWidget contract gaps

| Contract piece | Minesweeper / Game of Life | Rocketlauncher | Gap? |
|----------------|----------------------------|-------------|------|
| `kinds: ["bar-widget"]` only + nested Panel via Loader | Yes | Yes | OK |
| Forward `opened` / `popoutSwitchClosing` from Loader | Yes | Yes | OK |
| `open` / `close` / `toggle` / `closeForPopoutSwitch` | Yes | Yes | OK |
| `injectPanel`: `bar`, `settings`, `anchorItem`, `hostWidget` | Yes | Yes + `store` | OK (extra store inject is fine) |
| Nested `Panel { manageIpc: false }` | Yes | Yes | OK |
| `barIdentity: hostWidget \|\| root` + `switchPanelFrom` | Yes | Yes | OK |
| `KeyboardPanel` + `PanelKeyCatcher` Escape / Tab | Yes | Yes | OK |
| `popoutSwitching` / `popoutSwitchClosing` wired into KeyboardPanel | Minesweeper yes | Yes | OK |
| Pause expensive work when closed | GoL timer gated; Coin Toss tick on `opened` | Starfield timer gated; countdown clock always on | Minor: 1 Hz clock is cheap — OK |
| Prefer `BarIconButton` + `Style.bar.*Slot` for icon-only | Minesweeper | Uses `WidgetButton` (text countdown) | OK — text needs WidgetButton |
| Coin Toss uses **Panel as bar entry** (no nested Loader) | N/A | Rocketlauncher correctly uses clock/minesweeper nested pattern | No change |

**No critical lifecycle bugs found.** Main gap vs winners is **visual theming**, not open/close wiring.

---

## 4. Exact code changes for theme-native Rocketlauncher

1. **`Panel.qml`**
   - Replace fixed `surfaceColor` / `digitWell` with theme-derived:
     - `surfaceColor`: `Qt.rgba(Color.background.r,g,b, 0.55)` or blend `Color.popups.background` with foreground @ ~0.06 fill.
     - `digitWell`: `Qt.rgba(contentForeground.r,g,b, 0.12)`.
   - Add `dim` / `fainter` via `Qt.darker(contentForeground, …)` for captions if desired.
   - Starfield: paint with `contentForeground` (or rgba of it), not `#f0f0fa`.
   - Keep SpaceX “feel” only as subtle letter-spacing / uppercase / optional low-alpha starfield — not a private palette.
   - Leave `// TODO(watch-inline): …` and `// TODO(mission-detail): …` comments (no full UI yet).

2. **`MissionCard.qml`**
   - `import qs.Commons`; default `foreground` → `Color.foreground`, `surfaceColor` → translucent `Color.background` / foreground alpha fill.
   - Badge wells/text: tint from `Color.accent` (go/ok), `Color.urgent` (live), `Qt.darker(foreground,…)` (tbd/muted) with alpha fills — not fixed hex.
   - Radii: `Math.max(2, Style.cornerRadius - N)` / `Style.cornerRadius`.
   - WATCH control: keep inverted `foreground` fill; label color `Color.background` (or parent surface), not hardcoded SpaceX black.

3. **`FlipCounter.qml`**
   - Defaults: `foreground` → `Color.foreground`; `accentColor` → `Qt.rgba(foreground…, 0.12)` when Color available.
   - Digit radius from `Style.cornerRadius`.

4. **`BarWidget.qml`**
   - Already good; optional: expose `barForeground` alias for child consistency. No structural change.

5. **`LaunchStore.qml`**
   - No theme work; add TODO for detailed-launch fetch + inline watch (see other research docs).

6. **Do not** ship a hardcoded `#000` / `#f0f0fa` “SpaceX mode” as the only look (research UX sketch §6 was a moodboard, not a Quattro contract).

---

## 5. Applied status

Theme fixes listed in §4 items 1–3 are applied in-tree in this pass. Watch embed and full mission-detail UI remain deferred (TODOs in QML + `watch-inline.md` / `mission-detail-fields.md`).
