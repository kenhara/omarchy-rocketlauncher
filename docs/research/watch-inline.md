# Launch Desk — In-plugin Watch feasibility

**Date:** 2026-08-23 (America/Denver)  
**Goal:** Play Official Webcast (YouTube / X broadcasts / HLS) *inside* the plugin panel instead of `Qt.openUrlExternally`.

---

## 1. What Launch Desk does today

`LaunchStore.openWatch()` prefers `Qt.openUrlExternally(url)` with `xdg-open` fallback. Official URLs from LL2 are often:

- `https://x.com/i/broadcasts/…` (SpaceX Official Webcast, priority 10)
- `https://www.youtube.com/watch?v=…` (unofficial / re-streams)

Opening the system browser is reliable but leaves the desktop.

---

## 2. Platform facts (Omarchy Quattro / Quickshell)

| Tech | Availability in community plugins | Fit for webcast |
|------|-----------------------------------|-----------------|
| **Qt Multimedia** (`MediaPlayer` + `VideoOutput`) | Proven: Normarchy, omaStream | Plays local / progressive / many HLS URLs *if* a direct media URL is obtained |
| **yt-dlp + local proxy → Qt Multimedia** | Normarchy (`python3` helper → `127.0.0.1` tokenized HTTP → `MediaPlayer`) | Best path for YouTube |
| **mpv / mpv-mpris via Process** | Radio Atlas, Audiobookshelf (mpv daemon + socket) | Excellent for audio/HLS; video usually floats as a separate Hyprland window (hyprctl float) — “on desktop” but not inside QML |
| **QtWebEngine / WebView** | **Not used** by audited Omarchy plugins; not documented as a shell-bundled module for third-party plugins | Embedding youtube.com / x.com pages would need WebEngine in the Quickshell build — **not a safe assumption** |
| **Coverglow** | MPRIS art + theme tint — no video decode | Pattern for *chrome*, not playback |

Official Omarchy docs emphasize MPRIS / media *control*, not shipping Chromium inside plugins. Marketplace video players that work (Normarchy, omaStream) all go **Qt Multimedia ± yt-dlp**, not WebView.

---

## 3. Community patterns (ranked evidence)

1. **Normarchy** (`ctl0v0/normarchy`) — native panel video: `import QtMultimedia`, `MediaPlayer` + `VideoOutput`, Python + `yt-dlp` stream proxy on localhost. Esc hides panel while playback can continue. Globe opens original YouTube when native fails.
2. **omaStream** (marketplace) — YouTube/Twitch/X/SoundCloud via yt-dlp + Qt 6 Multimedia + ffmpeg; in-shell overlay player.
3. **Radio Atlas / Audiobookshelf** — `mpv` (+ mpris). Great for audio; video tends to be an external mpv window managed with `hyprctl`.
4. **Coverglow** — theme-native media *UI* over MPRIS; no embed.

---

## 4. Constraints specific to SpaceX Watch

- **X broadcasts** (`x.com/i/broadcasts/…`) are harder than YouTube: yt-dlp support varies; DRM / login walls possible; often no stable progressive URL.
- **YouTube** live/VOD: Normarchy-style yt-dlp → localhost → `MediaPlayer` is proven on Omarchy.
- **HLS** (`.m3u8`): often playable by Qt Multimedia / mpv when the URL is direct.
- **Panel size:** KeyboardPanel ~360×520 is small for a livestream; Normarchy still embeds — acceptable for “picture-in-panel,” or expand panel when watching.
- **Dependencies:** declaring `yt-dlp`, `python3`, `curl`, Qt Multimedia matches other Fun plugins; avoid bundling binaries.
- **Security baseline:** helper must stay local (127.0.0.1), no curl|sh installers, document network destinations (YouTube/X/LL2 only).

---

## 5. Ranked options

### 1) Best native approach (recommended when Watch is implemented)

**In-panel Qt Multimedia player + yt-dlp stream helper (Normarchy pattern).**

- Resolve Official Webcast URL → if YouTube (or yt-dlp-supported), spawn short-lived localhost proxy → `MediaPlayer.source = http://127.0.0.1:…`.
- Render `VideoOutput` inside an expanded section of `Panel.qml` / a sticky panel (Normarchy’s sticky keyboard panel pattern).
- Controls: Space play/pause, M mute, Esc hide panel (optionally keep audio), button “Open original” fallback.
- For **X-only** official links: try yt-dlp; on failure show thumbnail (`vid_urls[].feature_image`) + “Open broadcast” that uses external URL — honest degrade.

**Pros:** Truly inside the plugin; matches winning marketplace media plugins; theme-native chrome.  
**Cons:** Extra deps; X support flaky; live latency / format breakage.

### 2) Fallback — desktop-local, not browser

**Detachable mpv (PiP) via `bar.run` / Process**, float with `hyprctl` (Audiobookshelf mini-player pattern).

- Still “on the Omarchy desktop,” not Chrome.
- Wire MPRIS so `omarchy.media` can pause.
- Keep panel as launcher + status (“Playing webcast…”).

**Pros:** Robust for HLS/YouTube via mpv+yt-dlp; less QML video risk.  
**Cons:** Not visually *inside* the panel; window-rule friction.

### 3) Not possible / not allowed as primary

**Embedded QtWebEngine WebView of youtube.com / x.com.**

- No evidence Omarchy plugins can rely on WebEngine being linked into `omarchy-shell`.
- Heavy, sandbox-awkward, fights “no second browser” goal while still being a browser engine.
- Treat as **out of scope** unless Omarchy ships a documented WebView API later.

**Also reject as primary:** keep-only `Qt.openUrlExternally` once inline path exists — remain as last-resort fallback only.

---

## 6. Recommendation for Launch Desk (this milestone)

- **Do not** implement full embed in the theme pass.
- **Next implementation step:** Option **1** for YouTube-capable official/unofficial URLs; Option **2** optional setting (“Watch in mpv window”); keep external open as tertiary fallback especially for X broadcasts.
- Leave QML TODOs pointing here; current Watch button may stay external until helper lands.

**One-line verdict:** In-plugin Watch is **feasible** via Qt Multimedia + yt-dlp (proven by Normarchy/omaStream); WebView is **not** a realistic Quattro path; mpv PiP is the solid desktop fallback when stream extract fails.
