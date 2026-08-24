#!/usr/bin/env python3
"""Rocketlauncher bounded JSON fetch helper.

Hard-cap HTTP and on-disk cache reads so LaunchStore never JSON.parse-s an
unbounded body. Stdlib only. No shell.

Usage:
  fetch-json.py --url <URL> --cap <BYTES> --timeout <SECS> [--header 'K: V' ...]
  fetch-json.py --file <PATH> --cap <BYTES>

Stdout (machine-readable):
  OK <nbytes>\n<body>      # body is <= cap bytes
  ERR <reason>             # timeout | http-<code> | too-large | not-found | not-regular | io
"""
from __future__ import annotations

import argparse
import errno
import os
import socket
import stat
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


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


def main() -> int:
    ap = argparse.ArgumentParser(description="Bounded JSON fetch (OK/ERR + body)")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--url")
    src.add_argument("--file")
    ap.add_argument("--cap", type=int, required=True)
    ap.add_argument("--timeout", type=int, default=20)
    ap.add_argument("--header", action="append", default=[])
    a = ap.parse_args()

    try:
        if a.file:
            body = read_file_capped(a.file, a.cap)
        else:
            headers = {}
            for h in a.header:
                k, _, v = h.partition(":")
                headers[k.strip()] = v.strip()
            req = Request(a.url, headers=headers, method="GET")
            with urlopen(req, timeout=a.timeout) as resp:
                body = read_capped(resp, a.cap)
    except _RejectedFile:
        print("ERR not-regular")
        return 7
    except FileNotFoundError:
        print("ERR not-found")
        return 2
    except HTTPError as e:
        print(f"ERR http-{e.code}")
        return 3
    except (URLError, socket.timeout, TimeoutError):
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
