# Changelog

## 1.6.3

Watch close stays on the right, inset so the × is fully inside the card. The old spacer overflowed the panel clip.


## 1.6.2

Less software. Same locked grammar.

- Cut keyboard-legend footer (keys still work; README Controls table stays)
- Cut starfield/scanline + `starfieldEnabled` (mood via Phosphor rocket + wordmark)
- Soft-fetch next detail on panel open (`expand: false`); do not auto-expand Detail
- Hide next launch id from Upcoming; hide the section if the filtered slice is empty
- Cut consecutive-success caption (flips stay)
- Cut in-panel “Mission name on bar” + CLI dump; keep Countdown on bar (`barShowMissionName` stays in schema)
- Next card: vehicle-only subtitle, no badge echo (chip + job-line own LIVE/HOLD); NET meta stays
- Job-line STATE words: LIVE / SOON / HOLD / SUCCESS / FAIL; keep `next NET · T-…` / local NET / `offline · cached …` / `stale · cached …`


## 1.6.1

Local Phosphor Icons (regular, MIT) as QML Shape/Path — no remote webfont, no SVG Image.source. Ships the 1.6.0 nits.

- Bar chip + header: `rocket` idle, `rocket-launch` when `webcast_live`; accent-green only then
- Watch primary button: `play-circle`
- Next-launch labels only: `map-pin` pad, `planet` orbit, `parachute` landing (hidden unless LL2 has a landing/target)
- Job-line: offline only after a failed list refresh / `dataSource === none`; old cache is `stale · cached …`. Stale ≠ offline
- Chip: LIVE/HOLD/SOON/SUCCESS sit next to the short countdown (clock stays)
- Trajectory hidden until webcast / T-0 / result / ~T-10 (or hold-in-window)
- `formatNetLocal` is `Tue 25 Aug · 12:00` — no “your time”; zone stays on the footer
- 1.5.22 / 1.6.0 security locks unchanged


## 1.6.0

Grow the existing Rocketlauncher desk. Inspired by nocram.f1 *ideas* only — not a copy of their hero, session table, or QML.

- Adaptive job-line on the existing header subheader (next NET / T-10 / hold / webcast live / T+ / success / failure; offline · cached …)
- Local wall-clock NET; unofficial footer adds zone (`times local, $zone`)
- Bar chip short countdown + optional HOLD/LIVE/SUCCESS; LIVE tint still `webcast_live` only
- Next-launch Shape/Path trajectory (LEO/GTO/landing), discrete LL2 phase bead
- 1.5.22 security posture unchanged (neutralize, exclusive writes, HC-05, https allowlists, `--`, pinned PATH, python3 -B)


## 1.5.22

Defensive hardening. No behavior change to Watch-in-panel, HC-05 reads, `python3 -B`, KeyboardPanel, or unofficial footer.

- Watch URLs (`officialWebcast` / `openWatch` / `startStreamProxy` / HLS `watchStreamUrl` / `MediaPlayer.source`) go through `sanitizeOpenUrl` (https only; reject `file:` / `javascript:` / `smb:` / `data:`). `stream-proxy.py` rejects non-https before yt-dlp/urlopen. Localhost `http://127.0.0.1` READY URLs remain allowed for in-panel playback.
- Patch / crew / feature `Image.source`: https allowlist at model entry; refuse `data:` / `file:` / `.svg` / `.xml`.
- `fetch-json.py` pins/re-validates host after redirects (`ll.thespacedevs.com` / `api.thespacedevs.com`). Stream-proxy drops `Authorization`/`Cookie` and does not follow off-host redirects.
- Cache writes via helper: `O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW` 0600 temp in dest dir, fsync, replace. Directory `0700`. `FileView.setText` is fallback only.
- Neutralize remote text at slim/apply (strip `<>` and markdown images; collapse controls). `Text.PlainText` on MissionCard title/subtitle/meta/badge and remote lastError / bar mission name.
- Re-slim every cache/API row including ongoing, fallback crew, and details with `detailed_at`. Per-record byte cap.
- `notify-send --` before title/body. Pin `PATH=/usr/bin:/bin` on Processes.

## 1.5.21

- Refuse symlink/FIFO cache reads in fetch-json.py

## 1.5.20

- Bound HTTP / helper / cache reads
