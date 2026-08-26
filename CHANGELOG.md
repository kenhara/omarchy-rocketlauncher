# Changelog

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
