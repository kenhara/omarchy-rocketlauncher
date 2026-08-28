#!/usr/bin/env python3
"""Fixture-based checks for locate-iss.py. No network required for pass.

Live SATCAT (documented; Crew-12 confirmed from CelesTrak STATIONS CSV):
  https://celestrak.org/satcat/records.php?INTDES=2026-031
  default JSON; FORMAT=JSON retry. 2026-031A CREW DRAGON 12 ORBIT_TYPE=DOC ORBIT_CENTER=25544.
GP JSON: https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=JSON
  fields INCLINATION, MEAN_ANOMALY, EPOCH (host celestrak.org).
"""
from __future__ import annotations

import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
from urllib.error import URLError

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "locate-iss.py")
UA = "Rocketlauncher/1.6.5 prove"


def load_mod():
    spec = importlib.util.spec_from_file_location("locate_iss_under_test", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def flights(dest, designator, name="Crew Dragon Freedom", launch_name="Falcon 9 Block 5 | Crew-12", mission_end=None):
    return {
        "count": 1,
        "results": [
            {
                "id": 1,
                "destination": dest,
                "mission_end": mission_end,
                "spacecraft": {"id": 551, "name": name},
                "launch": {"launch_designator": designator, "name": launch_name},
            }
        ],
    }


def sat_doc():
    return [
        {
            "OBJECT_NAME": "CREW DRAGON 12",
            "OBJECT_ID": "2026-031A",
            "NORAD_CAT_ID": 67796,
            "OBJECT_TYPE": "PAY",
            "ORBIT_CENTER": 25544,
            "ORBIT_TYPE": "DOC",
        }
    ]


def sat_orb():
    return [
        {
            "OBJECT_NAME": "CREW DRAGON 12",
            "OBJECT_ID": "2026-031A",
            "OBJECT_TYPE": "PAY",
            "ORBIT_CENTER": "EA",
            "ORBIT_TYPE": "ORB",
        }
    ]


def sat_missing_center():
    return [
        {
            "OBJECT_NAME": "CREW DRAGON 12",
            "OBJECT_TYPE": "PAY",
            "ORBIT_TYPE": "DOC",
        }
    ]


def sat_starlink_pay():
    rows = []
    for i in range(12):
        rows.append(
            {
                "OBJECT_NAME": f"STARLINK-{1000 + i}",
                "OBJECT_ID": f"2020-025{'ABCDEFGHJKLMN'[i]}",
                "OBJECT_TYPE": "PAY",
                "ORBIT_CENTER": "EA",
                "ORBIT_TYPE": "ORB",
            }
        )
    return rows


def tle_ok():
    return [
        {
            "OBJECT_NAME": "ISS (ZARYA)",
            "OBJECT_ID": "1998-067A",
            "NORAD_CAT_ID": "25544",
            "EPOCH": "2026-08-28T09:12:00",
            "INCLINATION": "51.64",
            "MEAN_ANOMALY": "123.4",
        }
    ]


class FakeNet:
    def __init__(self) -> None:
        self.urls: list[str] = []
        self.uas: list[str] = []
        self.flights_body = None
        self.satcat_body = None
        self.tle_body = None
        self.satcat_html_first = False
        self.tle_timeout = False
        self.flights_timeout = False

    def fetch_https(self, url, headers, cap, timeout):
        self.urls.append(url)
        self.uas.append((headers or {}).get("User-Agent", ""))
        if "spacecraft_flights" in url:
            if self.flights_timeout:
                raise URLError("timeout")
            return self.flights_body
        if "records.php" in url or "satcat" in url:
            if self.satcat_html_first and "FORMAT=" not in url:
                return b"<html><body>SATCAT</body></html>"
            return self.satcat_body
        if "gp.php" in url or "CATNR=25544" in url:
            if self.tle_timeout:
                raise URLError("timeout")
            return self.tle_body
        raise URLError("https-only")


def dumps(obj) -> bytes:
    return json.dumps(obj).encode("utf-8")


def run_locate(mod, net, cache_dir, spacecraft="551"):
    mod.fj.fetch_https = net.fetch_https
    return mod.locate(spacecraft, 1048576, 20, UA, cache_dir)


def check(ok: bool, msg: str) -> None:
    print(f"assert ok, '{msg}'")
    assert ok, msg


def fresh() -> str:
    return tempfile.mkdtemp(prefix="locate-iss-prove-")


def is_none_fix(payload) -> bool:
    return (
        isinstance(payload, dict)
        and payload.get("kind") == "none"
        and payload.get("caption") == "NO PUBLIC TRACK"
        and payload.get("kind") != "iss-docked"
    )


def main() -> int:
    mod = load_mod()
    tmp = fresh()

    # 1. DOC satcat + valid TLE + ISS destination → iss-docked
    net = FakeNet()
    net.flights_body = dumps(flights("International Space Station", "2026-031"))
    net.satcat_body = dumps(sat_doc())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    ok = (
        st == "ok"
        and payload.get("kind") == "iss-docked"
        and payload.get("caption") == "ISS · Crew Dragon Freedom docked"
        and abs(float(payload.get("inclination_deg")) - 51.64) < 0.001
        and abs(float(payload.get("mean_anomaly_deg")) - 123.4) < 0.001
        and payload.get("epoch") == "2026-08-28T09:12:00"
        and isinstance(payload.get("fetched_at"), str)
        and payload.get("fetched_at")
    )
    check(ok, "DOC satcat becomes iss-docked")
    check(all(UA == u for u in net.uas) and len(net.uas) >= 3, "User-Agent passed to every GET")
    check(all("celestrak.com" not in u for u in net.urls), "TLE host is celestrak.org not .com")
    check(any("INTDES=2026-031" in u and "satcat" in u for u in net.urls), "SATCAT queried with validated INTDES")

    # 2. SATCAT ORB / missing center + ISS dest → course, not iss-docked
    net = FakeNet()
    net.flights_body = dumps(flights("International Space Station", "2026-031"))
    net.satcat_body = dumps(sat_orb())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    ok = st == "ok" and payload.get("kind") == "course" and payload.get("path") == "iss-rendezvous"
    check(ok, "SATCAT ORB becomes course not iss-docked")
    check("docked" not in str(payload.get("caption", "")).lower() or payload.get("kind") != "iss-docked", "ORB is not a live docked fix")

    net = FakeNet()
    net.flights_body = dumps(flights("ISS", "2026-031"))
    net.satcat_body = dumps(sat_missing_center())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    ok = st == "ok" and payload.get("kind") == "course" and payload.get("path") == "iss-rendezvous"
    check(ok, "SATCAT missing center becomes course not iss-docked")

    # 3. Starlink-like many PAY → none (do not draw Starlink as one path)
    net = FakeNet()
    net.flights_body = dumps(
        flights("Low Earth Orbit", "2020-025", name="Starlink", launch_name="Falcon 9 | Starlink Group 10-49")
    )
    net.satcat_body = dumps(sat_starlink_pay())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    ok = st == "ok" and is_none_fix(payload)
    check(ok, "Starlink-like many PAY becomes none")

    # 4. bad spacecraft id → ERR bad-id
    proc = subprocess.run(
        [
            sys.executable,
            "-B",
            SCRIPT,
            "--spacecraft",
            "nope",
            "--cap",
            "1024",
            "--timeout",
            "5",
            "--user-agent",
            UA,
            "--cache-dir",
            tmp,
        ],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PATH": "/usr/bin:/bin"},
    )
    check(proc.stdout.strip() == "ERR bad-id", "bad spacecraft id")
    st, payload = run_locate(mod, FakeNet(), tmp, spacecraft="12ab")
    check(st == "err" and payload == "bad-id", "non-digit spacecraft is bad-id")
    st, payload = run_locate(mod, FakeNet(), tmp, spacecraft="12345678901")
    check(st == "err" and payload == "bad-id", "overlong spacecraft is bad-id")

    # 5. poison designators never interpolated
    for poison in ("../x", "2026-031A;rm"):
        net = FakeNet()
        net.flights_body = dumps(flights("International Space Station", poison))
        net.satcat_body = dumps(sat_doc())
        net.tle_body = dumps(tle_ok())
        st, payload = run_locate(mod, net, tmp)
        joined = " ".join(net.urls)
        check(poison not in joined, f"poison designator {poison!r} never interpolated raw")
        check("../" not in joined and ";rm" not in joined, "path/meta characters stay out of SATCAT URL")
        ok = st == "ok" and payload.get("kind") in ("course", "none") and payload.get("kind") != "iss-docked"
        check(ok, f"poison designator {poison!r} is none/bad not iss-docked")

    # 6. unknown destination → none
    net = FakeNet()
    net.flights_body = dumps(flights("Mars transfer", "2026-031"))
    net.satcat_body = dumps(sat_doc())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    check(st == "ok" and is_none_fix(payload), "unknown destination becomes none")
    check(payload.get("caption") == "NO PUBLIC TRACK" and payload.get("kind") != "iss-docked", "none caption is NO PUBLIC TRACK")
    check(not any("satcat" in u or "gp.php" in u for u in net.urls), "unknown dest does not fetch SATCAT/TLE")

    # 7. ISS destination without DOC → course, not iss-docked
    net = FakeNet()
    net.flights_body = dumps(flights("International Space Station", "2026-031"))
    net.satcat_body = dumps(sat_starlink_pay())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    ok = (
        st == "ok"
        and payload.get("kind") == "course"
        and payload.get("path") == "iss-rendezvous"
        and "ISS" in payload.get("caption", "")
        and "docked" not in payload.get("caption", "").lower()
    )
    check(ok, "ISS destination without DOC becomes course")

    # DOC but TLE missing → course (no fake bead). Fresh cache so a prior TLE write cannot leak.
    net = FakeNet()
    net.flights_body = dumps(flights("International Space Station", "2026-031"))
    net.satcat_body = dumps(sat_doc())
    net.tle_timeout = True
    st, payload = run_locate(mod, net, fresh())
    check(st == "ok" and payload.get("kind") == "course" and payload.get("kind") != "iss-docked", "DOC without TLE becomes course")

    # HTML SATCAT first hop then JSON
    net = FakeNet()
    net.flights_body = dumps(flights("International Space Station", "2026-031"))
    net.satcat_body = dumps(sat_doc())
    net.tle_body = dumps(tle_ok())
    net.satcat_html_first = True
    st, payload = run_locate(mod, net, tmp)
    check(st == "ok" and payload.get("kind") == "iss-docked", "HTML SATCAT retries FORMAT=JSON")
    check(any("FORMAT=JSON" in u for u in net.urls), "FORMAT=JSON retry used")

    # LEO dest (not Starlink, not ISS) → course leo
    net = FakeNet()
    net.flights_body = dumps(flights("Low Earth Orbit", "2026-099", name="CRS Dragon", launch_name="Falcon 9 | CRS-32"))
    net.satcat_body = dumps(sat_orb())
    net.tle_body = dumps(tle_ok())
    st, payload = run_locate(mod, net, tmp)
    ok = st == "ok" and payload.get("kind") == "course" and payload.get("path") == "leo"
    check(ok, "known LEO destination becomes course leo")
    check(not any("satcat" in u or "gp.php" in u for u in net.urls), "LEO course does not hit ISS TLE")

    live = os.environ.get("LOCATE_LIVE") == "1"
    if live:
        env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PATH": "/usr/bin:/bin"}
        live_dir = tempfile.mkdtemp(prefix="locate-iss-live-")
        proc = subprocess.run(
            [
                sys.executable,
                "-B",
                SCRIPT,
                "--spacecraft",
                "551",
                "--cap",
                "1048576",
                "--timeout",
                "20",
                "--user-agent",
                "Rocketlauncher/1.6.5 (Omarchy unofficial; kenhara.rocketlauncher)",
                "--cache-dir",
                live_dir,
            ],
            capture_output=True,
            text=False,
            env=env,
        )
        out = proc.stdout or b""
        line = out.split(b"\n", 1)[0].decode("utf-8", "replace")
        kind = "?"
        if out.startswith(b"OK "):
            nl = out.find(b"\n")
            body = out[nl + 1 :] if nl >= 0 else b""
            try:
                kind = json.loads(body.decode("utf-8")).get("kind", "?")
            except Exception:
                kind = "parse-fail"
        elif out.startswith(b"ERR "):
            kind = line
        print(f"live kind {kind}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
