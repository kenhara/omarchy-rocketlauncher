# Space Jockey — Mission detail fields (LL2)

**Date:** 2026-08-23 (America/Denver)  
**Sources:** `docs/research/spacex-data.md`, `docs/research/samples/ll2-spacex-*-one.json`, live probe `launches/?search=Crew-10&mode=detailed`.

Free tier: **15 req/h**. Keep list polls on `mode=list`; fetch **detailed only** for selected / next launch.

---

## 1. Endpoints & budget

| Call | When | Mode | Counts toward 15/h |
|------|------|------|--------------------|
| `GET /agencies/121/` | Every refresh (stats) | — | 1 |
| `GET /launches/upcoming/?lsp__id=121&limit=5&mode=list` | Every refresh | **list** | 1 |
| `GET /spacecraft/?search=Crew%20Dragon&in_space=true` | Every refresh / slower cadence | list-ish | 1 |
| `GET /launches/{id}/` **or** `…/upcoming/?…&limit=1` without `mode=list` | On panel focus, card select, or T−2h | **detailed** | **+1 only for that id** |
| `GET /api-throttle/` | Debug / 429 | — | rare |

**Stay under 15/h:** default cycle = 3 GETs @ ≥30 min → ≤6/h; add **one** detailed fetch when user opens next/selected card (cache by id + `last_updated`). Do **not** detailed-fetch every upcoming row.

Current `LaunchStore` already does the 3-call cycle; **add** `fetchLaunchDetail(id)` gated to `nextLaunch.id` / selected id.

---

## 2. Fields for spacex.com/launches-style detail

### Mission description
| UI | LL2 path (detailed) | Notes |
|----|---------------------|-------|
| Mission title | `mission.name` or parse `name` after `\|` | list has `name` only |
| Type | `mission.type` | e.g. Communications, Human Flight |
| Description | `mission.description` | paragraph for expanded card |
| Orbit | `mission.orbit.name` / `abbrev` | LEO, etc. |

### Crew (human flights only)
| UI | LL2 path | Notes |
|----|----------|-------|
| Vehicle name / serial | `rocket.spacecraft_stage[].spacecraft.name`, `.serial_number` | absent on Starlink |
| Launch crew | `rocket.spacecraft_stage[].launch_crew[]` | `{ role.role, astronaut.name, astronaut.agency.abbrev, astronaut.image.* }` |
| Onboard / landing crew | `.onboard_crew[]`, `.landing_crew[]` | same shape |
| Destination | `spacecraft_stage.destination` | when present |

**Not** on list mode. **Not** on Starlink-style launches (`spacecraft_stage` missing). Ongoing desk rows still use `/spacecraft/?in_space=true` (no per-astronaut roster without a related detailed launch).

### Pad
| UI | LL2 path |
|----|----------|
| Pad | `pad.name` |
| Location | `pad.location.name` |
| Map | `pad.map_url` |

### Landing (booster)
| UI | LL2 path | Derive |
|----|----------|--------|
| Attempt / success | `rocket.launcher_stage[].landing.attempt`, `.success` | |
| Type | `landing.type.name` / `abbrev` (ASDS, RTLS, …) | |
| Site | `landing.landing_location.name` / `abbrev` | e.g. OCISLY |
| Summary string | — | `"ASDS | Of Course I Still Love You"` or `"RTLS | LZ-1"` |
| Booster serial / flight # | `launcher.serial_number`, `launcher_flight_number`, `reused` | reflight cue |

### Rocket
| UI | LL2 path |
|----|----------|
| Short / full name | `rocket.configuration.name`, `.full_name` |
| Family / variant | `.families`, `.variant` when needed |

### Patches
| UI | LL2 path |
|----|----------|
| Mission patch | `mission_patches[].image_url` (priority sort) |
| Program patch | `program[].mission_patches` / program `image` |

Cache images under `~/.cache/space-jockey/` (optional later).

### Webcasts
| UI | LL2 path |
|----|----------|
| LIVE flag | `webcast_live` |
| Links | `vid_urls[]`: `url`, `source`, `publisher`, `type.name`, `priority`, `feature_image` |
| Prefer | `type.name == "Official Webcast"` (often X); else highest `priority` |

List mode often **omits** `vid_urls` — detailed next launch is required for reliable Watch (store already tries to preserve prior `vid_urls` when id matches).

### Extra (optional polish)
`probability`, `window_start`/`window_end`, `flightclub_url`, `info_urls[]`, `image.image_url` / `thumbnail_url`, `slug`, `url` (LL2 permalink).

---

## 3. Suggested slim detail object (cache)

```jsonc
{
  "id": "uuid",
  "mission_name": "Crew-10",
  "mission_type": "Human Flight",
  "description": "…",
  "orbit": "LEO",
  "vehicle": "Falcon 9 Block 5",
  "pad_name": "Launch Complex 39A",
  "location_name": "Kennedy Space Center, FL, USA",
  "landing_summary": "RTLS | LZ-1",
  "booster_serial": "B####",
  "booster_flight": 12,
  "patch_url": "https://…/mission_patch_….png",
  "image_url": "https://…",
  "webcast_live": false,
  "vid_urls": [ /* slim as today */ ],
  "crew": [
    { "name": "Anne McClain", "role": "Commander", "agency": "NASA", "image_url": "…" }
  ],
  "spacecraft_name": "Crew Dragon Endurance",
  "spacecraft_serial": "C210",
  "detailed_at": "ISO-8601"
}
```

---

## 4. UI note (deferred)

Full mission-detail panel UI is **not** in the theme pass. Wire `fetchLaunchDetail` + fields first; then expand `MissionCard` / a detail column. Leave `// TODO(mission-detail)` in Panel / LaunchStore until then.
