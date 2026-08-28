#!/usr/bin/env python3
"""Local prove for fetch-json.py. No real internet."""
from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
from urllib.error import URLError
from urllib.request import Request

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "fetch-json.py")
ENV = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PATH": "/usr/bin:/bin"}

PASSES = 0


def load_mod():
    spec = importlib.util.spec_from_file_location("rocketlauncher_fetch_json_prove", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def check(ok: bool, msg: str) -> None:
    global PASSES
    print(f"assert ok, '{msg}'")
    assert ok, msg
    PASSES += 1


def run_helper(args, stdin=None):
    return subprocess.run(
        [sys.executable, "-B", SCRIPT, *args],
        capture_output=True,
        text=True,
        env=ENV,
        input=stdin,
    )


def first_line(proc) -> str:
    out = proc.stdout or ""
    return out.split("\n", 1)[0].strip()


def main() -> int:
    mod = load_mod()
    tmp = tempfile.mkdtemp(prefix="prove-fetch-json-")

    # oversize body → ERR too-large
    fat = os.path.join(tmp, "fat.json")
    with open(fat, "wb") as f:
        f.write(b"{" + (b"x" * 64) + b"}")
    proc = run_helper(["--file", fat, "--cap", "16"])
    check(first_line(proc) == "ERR too-large", "oversize body is ERR too-large")

    # symlink cache read → ERR not-regular
    real = os.path.join(tmp, "real.json")
    link = os.path.join(tmp, "link.json")
    with open(real, "w", encoding="utf-8") as f:
        f.write("{}")
    os.symlink(real, link)
    proc = run_helper(["--file", link, "--cap", "1024"])
    check(first_line(proc) == "ERR not-regular", "symlink cache read is ERR not-regular")

    # FIFO cache read → ERR not-regular
    fifo = os.path.join(tmp, "fifo.json")
    os.mkfifo(fifo)
    rdwr = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
    try:
        proc = run_helper(["--file", fifo, "--cap", "1024"])
    finally:
        os.close(rdwr)
    check(first_line(proc) == "ERR not-regular", "FIFO cache read is ERR not-regular")

    # initial host not in allowlist → ERR host (no connect)
    proc = run_helper(["--url", "https://not-allowed.invalid/", "--cap", "1024", "--timeout", "2"])
    check(first_line(proc) == "ERR host", "initial host not in allowlist is ERR host")
    try:
        mod.fetch_https("https://example.com/", {}, 1024, 2)
        raised = False
    except URLError as e:
        raised = str(getattr(e, "reason", e) or e) == "host"
    check(raised, "fetch_https rejects non-allowlisted host before open")

    # redirect off-host → ERR redirect-host
    handler = mod._HostPinRedirect("ll.thespacedevs.com")
    req = Request("https://ll.thespacedevs.com/2.3.0/")
    try:
        handler.redirect_request(
            req, None, 302, "Found", {}, "https://not-allowed.invalid/x"
        )
        off = False
    except URLError as e:
        off = "redirect-host" in str(getattr(e, "reason", e) or e)
    check(off, "redirect off-host is ERR redirect-host")

    try:
        handler.redirect_request(
            req, None, 302, "Found", {}, "https://api.thespacedevs.com/2.3.0/"
        )
        pair = True
    except URLError:
        pair = False
    check(pair, "LL2 pair redirect stays allowed")

    cel = mod._HostPinRedirect("celestrak.org")
    try:
        cel.redirect_request(
            Request("https://celestrak.org/satcat/records.php"),
            None,
            302,
            "Found",
            {},
            "https://ll.thespacedevs.com/x",
        )
        cel_pin = False
    except URLError as e:
        cel_pin = "redirect-host" in str(getattr(e, "reason", e) or e)
    check(cel_pin, "celestrak redirect off-host is ERR redirect-host")

    print(f"pass {PASSES}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
