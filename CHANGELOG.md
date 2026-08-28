# Changelog

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
