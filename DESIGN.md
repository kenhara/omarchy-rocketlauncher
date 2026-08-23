# Launch Desk — design rationale

## Why this shape wins on Omarchy

Marketplace standouts (Coin Toss, Game of Life, Coverglow, Agents, Minesweeper)
share a pattern: **tiny bar affordance → rich popout**, theme tokens first,
correct Quattro lifecycle, witty one-liner, MIT, baseline-friendly.

Launch Desk follows that cluster exactly:

| Winner pattern | How Launch Desk uses it |
|----------------|-------------------------|
| `bar-widget` only + nested `Panel.qml` via Loader (clock / Minesweeper / Game of Life) | No separate `panel` kind — avoids double registration |
| Forward `opened` / `open` / `close` / `toggle` / `closeForPopoutSwitch` + inject `bar` / `anchorItem` / `hostWidget` | Matches community BarWidget contracts so popout switching works |
| Theme-aware `Style` / bar foreground | Primary chrome from Omarchy; SpaceX dark greys / cool white as **secondary** accents |
| Schema knobs | `refreshIntervalSec` (min 600) so power users tune without editing QML |
| Subtle motion, pause when hidden | Digit flips + starfield/scanline only while open |
| Zero privilege | Pure QML + `XMLHttpRequest` + optional `xdg-open` — aim for security baseline `passed` |
| Strong pitch | “SpaceX launch desk on your Omarchy bar — flip-digit stats, countdown, ongoing missions, Watch.” |

## Product choices

- **Not Electron.** A launches SPA would fight Quattro; this lives in the shell.
- **LL2 over scraping SpaceX.com** — stable API, webcasts, agency totals; free tier respected with aggressive cache + `mode=list`.
- **Honest stats.** SpaceX.com “reflights” ≠ a single LL2 agency field. We show **Total launches / Landings / Pending** plus consecutive successes as meta — no invented reflight counter.
- **Offline-first sample** so judges see a full desk without burning API quota.

## Architecture sketch

```
BarWidget.qml  ──Loader──►  Panel.qml
      │                        │
      └── LaunchStore ─────────┘
             │
             ├─ ~/.cache/launch-desk/cache.json
             └─ data/sample-cache.json (bundled)
```

## Competition fit

Delight in ≤10 seconds: open the panel, see flip digits, next NET, Watch.
Native Omarchy feel, not a bolted-on website. The git repo root **is** the
plugin (`manifest.json` at root) so `omarchy plugin add <git-url>` works for
the marketplace. Suggested remote: `omarchy-launch-desk`.
