#!/usr/bin/env python3
"""Rocketlauncher stream helper (Normarchy-style).

Resolve a webcast URL with yt-dlp and expose a short-lived localhost redirect
that Qt Multimedia (MediaPlayer) can open inside the plugin panel.

Usage:
  python3 stream-proxy.py <url> [--port 0] [--timeout 120] [--quality best|720|480]

Stdout (one line, machine-readable):
  READY <http://127.0.0.1:PORT/stream>
  DIRECT <resolved-media-url>     # when a direct progressive/HLS URL is enough
  ERROR <message>

Dependencies (optional — Watch degrades without them):
  - python3
  - yt-dlp  (pipx / pacman / pip install yt-dlp)

Security: binds 127.0.0.1 only. Input and upstream fetches are https-only.
No remote installers. Exits after --timeout or when the client disconnects /
process is killed by the plugin.
"""
from __future__ import annotations

import argparse
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import URLError, HTTPError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, HTTPSHandler, Request, build_opener


def require_https(url: str, what: str = "url") -> str:
    """Return url if it is https://; raise RuntimeError otherwise.

    Rejects file: / javascript: / smb: / data: / http: before yt-dlp or urlopen.
    """
    u = (url or "").strip()
    low = u.lower()
    if not u or any(c in u for c in "\r\n\x00"):
        raise RuntimeError(f"refused {what}: https only")
    if (
        low.startswith("file:")
        or low.startswith("javascript:")
        or low.startswith("smb:")
        or low.startswith("data:")
    ):
        raise RuntimeError(f"refused {what}: https only")
    parsed = urlparse(u)
    if (parsed.scheme or "").lower() != "https" or not parsed.hostname:
        raise RuntimeError(f"refused {what}: https only")
    return u


class _NoOffHostAuthRedirect(HTTPRedirectHandler):
    """Prefer not following off-host; never send Authorization/Cookie cross-host."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urlparse(newurl)
        if (parsed.scheme or "").lower() != "https" or not parsed.hostname:
            return None
        orig = urlparse(req.full_url)
        orig_host = (orig.hostname or "").lower()
        new_host = (parsed.hostname or "").lower()
        newreq = super().redirect_request(req, fp, code, msg, headers, newurl)
        if newreq is None:
            return None
        # Drop credentials on any hop (defense in depth).
        for hdr in ("Authorization", "Cookie", "authorization", "cookie"):
            try:
                del newreq.headers[hdr]
            except KeyError:
                pass
        unredir = getattr(newreq, "unredirected_hdrs", None)
        if unredir:
            for hdr in list(unredir):
                if hdr.lower() in ("authorization", "cookie"):
                    del unredir[hdr]
        if orig_host != new_host:
            # Prefer not following off-host (cookie/auth leak).
            return None
        return newreq


def _https_opener():
    return build_opener(_NoOffHostAuthRedirect(), HTTPSHandler())


def format_selector(quality: str) -> str:
    """Map watchQuality schema (best|720|480) to a yt-dlp format string."""
    q = (quality or "best").strip().lower()
    if q in ("720", "720p"):
        # Prefer ≤720 progressive/HLS, then best overall
        return (
            "best[height<=720][protocol^=http][ext=mp4]/"
            "best[height<=720][protocol^=m3u8]/"
            "best[height<=720]/"
            "best[protocol^=http][ext=mp4]/best[protocol^=m3u8]/best/best"
        )
    if q in ("480", "480p"):
        return (
            "best[height<=480][protocol^=http][ext=mp4]/"
            "best[height<=480][protocol^=m3u8]/"
            "best[height<=480]/"
            "best[protocol^=http][ext=mp4]/best[protocol^=m3u8]/best/best"
        )
    # best (default)
    return "best[protocol^=http][ext=mp4]/best[protocol^=m3u8]/best/best"


def resolve(url: str, quality: str = "best") -> dict:
    """Return {url, headers} via yt-dlp, else raise RuntimeError."""
    url = require_https(url, "input")
    try:
        import yt_dlp  # type: ignore
    except ImportError as e:
        raise RuntimeError("yt-dlp not installed") from e

    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
        "format": format_selector(quality),
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    if not info:
        raise RuntimeError("yt-dlp returned no info")
    # Prefer flat url; else first format with a url
    media = info.get("url")
    headers = dict(info.get("http_headers") or {})
    if not media:
        for f in info.get("formats") or []:
            if f.get("url"):
                media = f["url"]
                headers = dict(f.get("http_headers") or headers)
                break
    if not media:
        raise RuntimeError("no playable URL extracted")
    media = require_https(str(media), "media")
    return {"url": media, "headers": headers}


class _Handler(BaseHTTPRequestHandler):
    media_url = ""
    media_headers: dict = {}

    def log_message(self, fmt, *args):  # silence
        return

    def do_GET(self):  # noqa: N802
        if self.path not in ("/stream", "/"):
            self.send_error(404)
            return
        # 302 so MediaPlayer follows to the real CDN / HLS playlist when possible.
        # For hosts that need Referer/cookies, fall through to a tiny proxy.
        need_proxy = bool(self.media_headers.get("Authorization") or self.media_headers.get("Cookie"))
        if not need_proxy and self.media_url:
            self.send_response(302)
            self.send_header("Location", self.media_url)
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        try:
            require_https(self.media_url, "media")
            req = Request(self.media_url, headers=dict(self.media_headers or {}))
            opener = _https_opener()
            with opener.open(req, timeout=30) as resp:
                data = resp.read(64 * 1024)
                ctype = resp.headers.get("Content-Type", "application/octet-stream")
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(data)
                while True:
                    chunk = resp.read(64 * 1024)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
        except (HTTPError, URLError, OSError, RuntimeError) as e:
            try:
                self.send_error(502, str(e))
            except Exception:
                pass


def main() -> int:
    ap = argparse.ArgumentParser(description="Rocketlauncher yt-dlp → localhost stream helper")
    ap.add_argument("url", help="YouTube / X / HLS / other yt-dlp URL")
    ap.add_argument("--port", type=int, default=0, help="Bind port (0 = ephemeral)")
    ap.add_argument("--timeout", type=int, default=180, help="Seconds before exit")
    ap.add_argument("--direct", action="store_true", help="Print DIRECT url only, no HTTP server")
    ap.add_argument(
        "--quality",
        default="best",
        choices=("best", "720", "480", "720p", "480p"),
        help="Max stream height preference (schema watchQuality)",
    )
    args = ap.parse_args()

    try:
        require_https(args.url, "input")
        resolved = resolve(args.url, quality=args.quality)
    except Exception as e:
        print(f"ERROR {e}", flush=True)
        return 1

    media = resolved["url"]
    headers = resolved["headers"]

    def _is_hls(u: str) -> bool:
        # Path/extension check only — avoid substring false positives in query strings.
        path = (u or "").split("?", 1)[0].split("#", 1)[0].lower()
        return path.endswith(".m3u8")

    # One path for HLS: DIRECT + return. Otherwise READY via localhost proxy only.
    if args.direct or _is_hls(media):
        print(f"DIRECT {media}", flush=True)
        return 0

    _Handler.media_url = media
    _Handler.media_headers = headers
    try:
        httpd = HTTPServer(("127.0.0.1", args.port), _Handler)
    except OSError as e:
        print(f"ERROR bind failed: {e}", flush=True)
        return 1

    port = httpd.server_address[1]
    print(f"READY http://127.0.0.1:{port}/stream", flush=True)

    def _serve():
        httpd.serve_forever(poll_interval=0.5)

    t = threading.Thread(target=_serve, daemon=True)
    t.start()
    try:
        time.sleep(max(5, args.timeout))
    except KeyboardInterrupt:
        pass
    finally:
        httpd.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
