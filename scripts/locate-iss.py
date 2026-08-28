#!/usr/bin/env python3
"""On-click ISS locate helper. Stdlib only. No shell.

Prove docked at ISS (SATCAT DOC + ORBIT_CENTER 25544) then read ISS TLE.
Failed proof with a known destination is still success: kind none or course.
Never dump raw SATCAT/TLE lists. Never interpolate an unvalidated designator.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import socket
import sys
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode

ISS_CATNR = 25544
TLE_MAX_AGE_SEC = 7200
INTDES_RE = re.compile(r"^[0-9]{4}-[0-9]{3}[A-Z]?$")
CRAFT_RE = re.compile(r"^[0-9]{1,10}$")
FLIGHTS_URL = "https://ll.thespacedevs.com/2.3.0/spacecraft_flights/?spacecraft="
SATCAT_BASE = "https://celestrak.org/satcat/records.php"
TLE_URL = "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=JSON"


def _load_fetch_json():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fetch-json.py")
    spec = importlib.util.spec_from_file_location("rocketlauncher_fetch_json", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


fj = _load_fetch_json()


class HardIO(Exception):
    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def neutralize(v, n: int = 120) -> str:
    s = str(v or "")
    s = re.sub(r"[<>]", "", s)
    s = re.sub(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]", "", s)
    return s[:n] if len(s) > n else s


def emit_ok(obj: dict) -> None:
    body = json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    sys.stdout.write(f"OK {len(body)}\n")
    sys.stdout.flush()
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def emit_err(reason: str) -> None:
    sys.stdout.write(f"ERR {reason}\n")
    sys.stdout.flush()


def _headers(user_agent: str) -> dict:
    return {
        "Accept": "application/json",
        "User-Agent": user_agent,
    }


def _get(url: str, headers: dict, cap: int, timeout: int) -> bytes:
    try:
        body = fj.fetch_https(url, headers, cap, timeout)
    except HTTPError:
        return b""
    except (URLError, socket.timeout, TimeoutError) as e:
        reason = ""
        if isinstance(e, URLError):
            reason = str(getattr(e, "reason", e) or e)
        if "https-only" in reason:
            raise HardIO("https-only") from e
        if "redirect-host" in reason:
            raise HardIO("redirect-host") from e
        if reason == "host":
            raise HardIO("host") from e
        raise HardIO("timeout") from e
    except OSError as e:
        raise HardIO("timeout") from e
    if body is None:
        raise HardIO("too-large")
    return body


def _parse_json(body: bytes):
    if not body:
        return None
    s = body.lstrip()
    if not s or s[:1] not in (b"{", b"["):
        return None
    try:
        return json.loads(body.decode("utf-8", "replace"))
    except (json.JSONDecodeError, UnicodeError, ValueError):
        return None


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")


def _none() -> dict:
    return {"kind": "none", "caption": "NO PUBLIC TRACK", "fetched_at": _now_iso()}


def _course(caption: str, path: str) -> dict:
    cap = neutralize(caption, 120)
    if path not in ("iss-rendezvous", "leo") or not cap:
        return _none()
    return {"kind": "course", "caption": cap, "path": path, "fetched_at": _now_iso()}


def _dest_text(flight: dict) -> str:
    d = flight.get("destination") if isinstance(flight, dict) else None
    if isinstance(d, dict):
        return str(d.get("name") or d.get("destination") or "")
    return str(d or "")


def _mentions_iss(text: str) -> bool:
    low = (text or "").lower()
    return "international space station" in low or re.search(r"\biss\b", low) is not None


def _mentions_leo(text: str) -> bool:
    low = (text or "").lower()
    return "low earth orbit" in low or re.search(r"\bleo\b", low) is not None


def _mentions_starlink(text: str) -> bool:
    return "starlink" in (text or "").lower()


def _launch_name(flight: dict) -> str:
    launch = flight.get("launch") if isinstance(flight, dict) else None
    if isinstance(launch, dict):
        return str(launch.get("name") or "")
    return ""


def _craft_name(flight: dict) -> str:
    sc = flight.get("spacecraft") if isinstance(flight, dict) else None
    if isinstance(sc, dict) and sc.get("name"):
        return str(sc.get("name") or "")
    return _launch_name(flight)


def _designator(flight: dict) -> str:
    launch = flight.get("launch") if isinstance(flight, dict) else None
    if not isinstance(launch, dict):
        return ""
    des = str(launch.get("launch_designator") or "")
    if INTDES_RE.match(des):
        return des
    return ""


def _is_ongoing(flight: dict) -> bool:
    if not isinstance(flight, dict):
        return False
    end = flight.get("mission_end")
    return end is None or end == ""


def _pick_flight(payload) -> dict | None:
    if isinstance(payload, dict):
        rows = payload.get("results") or []
    elif isinstance(payload, list):
        rows = payload
    else:
        rows = []
    if not isinstance(rows, list):
        return None
    for fl in rows:
        if _is_ongoing(fl):
            return fl
    return None


def _classify(flight: dict):
    """Return (course_path, caption_dest) or None if unknown / starlink."""
    dest = _dest_text(flight)
    blob = " ".join([dest, _launch_name(flight), _craft_name(flight)])
    if _mentions_iss(dest):
        name = neutralize(_craft_name(flight), 80)
        cap = f"ISS · {name}" if name else "ISS"
        return "iss-rendezvous", cap
    if _mentions_starlink(blob):
        return None
    if _mentions_leo(dest):
        name = neutralize(_craft_name(flight), 80)
        dlabel = neutralize(dest, 40) or "LEO"
        cap = f"{dlabel} · {name}" if name else dlabel
        return "leo", cap
    return None


def _as_records(payload) -> list:
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]
    if isinstance(payload, dict):
        if isinstance(payload.get("records"), list):
            return [x for x in payload["records"] if isinstance(x, dict)]
        return [payload]
    return []


def _orbit_center(rec: dict):
    oc = rec.get("ORBIT_CENTER")
    if oc is None:
        oc = rec.get("orbit_center")
    if isinstance(oc, str) and oc.strip().isdigit():
        return int(oc.strip())
    if isinstance(oc, bool):
        return None
    if isinstance(oc, int):
        return oc
    if isinstance(oc, float) and oc == int(oc):
        return int(oc)
    return oc


def _orbit_type(rec: dict) -> str:
    v = rec.get("ORBIT_TYPE")
    if v is None:
        v = rec.get("orbit_type")
    return str(v or "").strip().upper()


def _doc_on_iss(records: list) -> bool:
    for rec in records:
        if _orbit_type(rec) == "DOC" and _orbit_center(rec) == ISS_CATNR:
            return True
    return False


def _satcat(des: str, headers: dict, cap: int, timeout: int) -> list:
    # INTDES is regex-checked by caller. urlencode only that validated token.
    q1 = urlencode({"INTDES": des})
    url1 = f"{SATCAT_BASE}?{q1}"
    body = _get(url1, headers, cap, timeout)
    data = _parse_json(body)
    if data is None:
        q2 = urlencode({"INTDES": des, "FORMAT": "JSON"})
        body = _get(f"{SATCAT_BASE}?{q2}", headers, cap, timeout)
        data = _parse_json(body)
    return _as_records(data)


def _cache_path(cache_dir: str) -> str:
    return os.path.join(os.path.abspath(cache_dir), "iss-tle.json")


def _read_tle_cache(cache_dir: str, cap: int):
    path = _cache_path(cache_dir)
    try:
        raw = fj.read_file_capped(path, cap)
    except (FileNotFoundError, OSError, fj._RejectedFile):
        return None
    if raw is None:
        return None
    data = _parse_json(raw)
    if not isinstance(data, dict):
        return None
    ts = data.get("fetched_at")
    try:
        if isinstance(ts, (int, float)):
            age = datetime.now(timezone.utc).timestamp() - float(ts)
        else:
            t = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
            if t.tzinfo is None:
                t = t.replace(tzinfo=timezone.utc)
            age = datetime.now(timezone.utc).timestamp() - t.timestamp()
    except (TypeError, ValueError, OSError):
        return None
    if age < 0 or age >= TLE_MAX_AGE_SEC:
        return None
    return data.get("payload")


def _write_tle_cache(cache_dir: str, payload) -> None:
    blob = json.dumps(
        {"fetched_at": _now_iso(), "payload": payload},
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    try:
        fj.write_file_atomic(_cache_path(cache_dir), blob)
    except OSError:
        pass


def _tle_record(payload):
    if isinstance(payload, list):
        rec = payload[0] if payload else None
    elif isinstance(payload, dict):
        rec = payload
    else:
        rec = None
    return rec if isinstance(rec, dict) else None


def _num(v):
    try:
        n = float(v)
    except (TypeError, ValueError):
        return None
    if n != n or n in (float("inf"), float("-inf")):
        return None
    return n


def _from_tle(payload):
    rec = _tle_record(payload)
    if not rec:
        return None
    inc = _num(rec.get("INCLINATION") if rec.get("INCLINATION") is not None else rec.get("inclination"))
    ma = _num(rec.get("MEAN_ANOMALY") if rec.get("MEAN_ANOMALY") is not None else rec.get("mean_anomaly"))
    if inc is None or ma is None:
        return None
    if inc < 0 or inc > 180:
        return None
    if ma < 0 or ma >= 360:
        return None
    epoch = rec.get("EPOCH")
    if epoch is None:
        epoch = rec.get("epoch") or ""
    return inc, ma, neutralize(str(epoch), 64)


def _load_tle(headers: dict, cap: int, timeout: int, cache_dir: str):
    cached = _read_tle_cache(cache_dir, cap)
    if cached is not None:
        parsed = _from_tle(cached)
        if parsed:
            return parsed
    try:
        body = _get(TLE_URL, headers, cap, timeout)
    except HardIO:
        return None
    data = _parse_json(body)
    parsed = _from_tle(data)
    if parsed:
        _write_tle_cache(cache_dir, data)
    return parsed


def locate(spacecraft: str, cap: int, timeout: int, user_agent: str, cache_dir: str) -> tuple[str, dict | str]:
    if not CRAFT_RE.match(str(spacecraft or "")):
        return "err", "bad-id"
    headers = _headers(user_agent)
    try:
        body = _get(FLIGHTS_URL + str(spacecraft), headers, cap, timeout)
    except HardIO as e:
        return "err", e.reason
    payload = _parse_json(body)
    flight = _pick_flight(payload)
    if not flight:
        return "ok", _none()
    classified = _classify(flight)
    if not classified:
        return "ok", _none()
    path, caption = classified
    fallback = _course(caption, path)

    if path != "iss-rendezvous":
        return "ok", fallback

    des = _designator(flight)
    docked = False
    if des:
        try:
            records = _satcat(des, headers, cap, timeout)
            docked = _doc_on_iss(records)
        except HardIO:
            docked = False

    if not docked:
        return "ok", fallback

    tle = _load_tle(headers, cap, timeout, cache_dir)
    if not tle:
        return "ok", fallback
    inc, ma, epoch = tle
    name = neutralize(_craft_name(flight), 80)
    docked_cap = neutralize(f"ISS · {name} docked" if name else "ISS docked", 120)
    return "ok", {
        "kind": "iss-docked",
        "caption": docked_cap,
        "inclination_deg": inc,
        "mean_anomaly_deg": ma,
        "epoch": epoch,
        "fetched_at": _now_iso(),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Locate ISS-docked spacecraft (OK/ERR + LocateFix)")
    ap.add_argument("--spacecraft", required=True)
    ap.add_argument("--cap", type=int, required=True)
    ap.add_argument("--timeout", type=int, default=20)
    ap.add_argument("--user-agent", required=True)
    ap.add_argument("--cache-dir", required=True)
    a = ap.parse_args(argv)
    status, payload = locate(a.spacecraft, a.cap, a.timeout, a.user_agent, a.cache_dir)
    if status == "err":
        emit_err(str(payload))
        return 1
    emit_ok(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
