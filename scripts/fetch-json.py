#!/usr/bin/env python3
"""Rocketlauncher bounded JSON fetch helper.

Hard-cap HTTP and on-disk cache reads so LaunchStore never JSON.parse-s an
unbounded body. Atomic cache writes (O_EXCL|O_NOFOLLOW). Stdlib only. No shell.

Usage:
  fetch-json.py --url <URL> --cap <BYTES> --timeout <SECS> [--header 'K: V' ...]
  fetch-json.py --file <PATH> --cap <BYTES>
  fetch-json.py --write <PATH> --cap <BYTES> [--nbytes N]

Stdout (machine-readable):
  OK <nbytes>\n<body>      # body is <= cap bytes
  ERR <reason>             # timeout | http-<code> | too-large | not-found |
                           # not-regular | io | https-only | redirect-host | host
"""
from __future__ import annotations

import argparse
import errno
import os
import secrets
import socket
import stat
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import (
    HTTPRedirectHandler,
    HTTPSHandler,
    Request,
    build_opener,
)

# Initial GET host must be one of these. Redirects pin to the request host;
# ll. ↔ api. on The Space Devs may swap.
_ALLOWED_HOSTS = frozenset({
    "ll.thespacedevs.com",
    "api.thespacedevs.com",
    "celestrak.org",
})
_LL2_HOSTS = frozenset({"ll.thespacedevs.com", "api.thespacedevs.com"})


def emit_ok(body: bytes) -> None:
    sys.stdout.write(f"OK {len(body)}\n")
    sys.stdout.flush()
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def read_capped(reader, cap: int):
    data = reader.read(cap + 1)
    if len(data) > cap:
        return None
    return data


class _RejectedFile(Exception):
    """Cache path is not a plain regular file (symlink, FIFO, device, dir…)."""


class _HostPinRedirect(HTTPRedirectHandler):
    """Re-validate https + host after each redirect hop."""

    def __init__(self, pinned_host: str) -> None:
        super().__init__()
        self.pinned_host = (pinned_host or "").lower()

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urlparse(newurl)
        scheme = (parsed.scheme or "").lower()
        host = (parsed.hostname or "").lower()
        if scheme != "https" or not _host_allowed(host, self.pinned_host):
            raise URLError("redirect-host")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _host_allowed(host: str, pinned: str) -> bool:
    h = (host or "").lower()
    p = (pinned or "").lower()
    if not h or not p:
        return False
    if h == p:
        return True
    # ll. ↔ api. on The Space Devs is the same API; nowhere else.
    return h in _LL2_HOSTS and p in _LL2_HOSTS


def read_file_capped(path: str, cap: int):
    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
    except OSError as e:
        if e.errno in (errno.ELOOP, errno.EMLINK):
            raise _RejectedFile(path) from e
        raise
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise _RejectedFile(path)
        os.set_blocking(fd, True)
        f = os.fdopen(fd, "rb")
    except BaseException:
        os.close(fd)
        raise
    with f:
        return read_capped(f, cap)


def _ensure_dir_0700(dest_dir: str) -> None:
    try:
        os.mkdir(dest_dir, 0o700)
    except FileExistsError:
        pass
    st = os.lstat(dest_dir)
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
        raise OSError("dest dir not a directory")
    os.chmod(dest_dir, 0o700)


def write_file_atomic(path: str, data: bytes) -> None:
    """O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW 0600 temp in dest dir, fsync, replace.

    Does not follow a symlink at *path*: os.replace swaps the name (the
    symlink inode is replaced; the symlink target is left untouched).
    """
    path = os.path.abspath(path)
    dest_dir = os.path.dirname(path) or "."
    _ensure_dir_0700(dest_dir)

    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    fd = -1
    tmp = ""
    last_err: OSError | None = None
    for _ in range(12):
        tmp = os.path.join(
            dest_dir,
            f".{os.path.basename(path)}.{os.getpid()}.{secrets.token_hex(8)}.tmp",
        )
        try:
            fd = os.open(tmp, flags, 0o600)
            break
        except OSError as e:
            last_err = e
            if e.errno in (errno.EEXIST, errno.ELOOP):
                continue
            raise
    else:
        raise last_err or OSError("tmp create failed")

    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            raise OSError("tmp not regular")
        try:
            os.fchmod(fd, 0o600)
        except OSError:
            pass
        view = memoryview(data)
        written = 0
        while written < len(data):
            n = os.write(fd, view[written:])
            if n <= 0:
                raise OSError("short write")
            written += n
        os.fsync(fd)
        # Refuse to rename if the tmp *name* was swapped under us.
        st_path = os.lstat(tmp)
        if (
            stat.S_ISLNK(st_path.st_mode)
            or not stat.S_ISREG(st_path.st_mode)
            or st_path.st_ino != st.st_ino
            or st_path.st_dev != st.st_dev
        ):
            raise OSError("tmp replaced")
    except BaseException:
        try:
            os.close(fd)
        except OSError:
            pass
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    os.close(fd)
    os.replace(tmp, path)


def fetch_https(url: str, headers: dict, cap: int, timeout: int):
    parsed = urlparse(url)
    if (parsed.scheme or "").lower() != "https":
        raise URLError("https-only")
    host = (parsed.hostname or "").lower()
    if not host:
        raise URLError("https-only")
    if host not in _ALLOWED_HOSTS:
        raise URLError("host")
    opener = build_opener(_HostPinRedirect(host), HTTPSHandler())
    req = Request(url, headers=headers, method="GET")
    with opener.open(req, timeout=timeout) as resp:
        final = urlparse(resp.geturl())
        if (final.scheme or "").lower() != "https" or not _host_allowed(
            final.hostname or "", host
        ):
            raise URLError("redirect-host")
        return read_capped(resp, cap)


def _read_stdin(cap: int, nbytes: int | None) -> bytes | None:
    if nbytes is not None and nbytes >= 0:
        if nbytes > cap:
            # Drain nothing; caller treats too-large.
            leftover = sys.stdin.buffer.read(cap + 1)
            if leftover is not None and len(leftover) > cap:
                return None
            return None
        chunks: list[bytes] = []
        left = nbytes
        while left > 0:
            buf = sys.stdin.buffer.read(left)
            if not buf:
                break
            chunks.append(buf)
            left -= len(buf)
        data = b"".join(chunks)
        if len(data) > cap:
            return None
        return data
    return read_capped(sys.stdin.buffer, cap)


def main() -> int:
    ap = argparse.ArgumentParser(description="Bounded JSON fetch (OK/ERR + body)")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--url")
    src.add_argument("--file")
    src.add_argument("--write")
    ap.add_argument("--cap", type=int, required=True)
    ap.add_argument("--timeout", type=int, default=20)
    ap.add_argument("--header", action="append", default=[])
    ap.add_argument(
        "--nbytes",
        type=int,
        default=None,
        help="When --write: read exactly N bytes from stdin (no EOF wait)",
    )
    a = ap.parse_args()

    try:
        if a.file:
            body = read_file_capped(a.file, a.cap)
        elif a.write:
            data = _read_stdin(a.cap, a.nbytes)
            if data is None:
                print("ERR too-large")
                return 6
            if a.nbytes is not None and a.nbytes >= 0 and len(data) != a.nbytes:
                print("ERR io")
                return 5
            write_file_atomic(a.write, data)
            print(f"OK {len(data)}")
            return 0
        else:
            headers = {}
            for h in a.header:
                k, _, v = h.partition(":")
                headers[k.strip()] = v.strip()
            body = fetch_https(a.url, headers, a.cap, a.timeout)
    except _RejectedFile:
        print("ERR not-regular")
        return 7
    except FileNotFoundError:
        print("ERR not-found")
        return 2
    except HTTPError as e:
        print(f"ERR http-{e.code}")
        return 3
    except (URLError, socket.timeout, TimeoutError) as e:
        reason = ""
        if isinstance(e, URLError):
            reason = str(getattr(e, "reason", e) or e)
        if "https-only" in reason:
            print("ERR https-only")
            return 9
        if "redirect-host" in reason:
            print("ERR redirect-host")
            return 8
        if reason == "host":
            print("ERR host")
            return 10
        print("ERR timeout")
        return 4
    except OSError:
        print("ERR io")
        return 5
    if body is None:
        print("ERR too-large")
        return 6
    emit_ok(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
