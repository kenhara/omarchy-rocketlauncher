# SpaceX Launches — Data & UX Research (Omarchy Plugin)

Research date: **2026-08-22** (America/Denver) / 2026-08-23 UTC  
Target UX: [https://www.spacex.com/launches](https://www.spacex.com/launches)

**Recommended primary API: Launch Library 2 (The Space Devs) `https://ll.thespacedevs.com/2.3.0/`**  
SpaceX agency id: **121**

---

## 1. Official page analysis (`spacex.com/launches`)

The page is a client-rendered Angular SPA (`<app-root>`). Static HTML is a thin shell; mission tables and hero stats hydrate in JS. Scraping the site is brittle and unnecessary — use LL2 instead.

### 1.1 Sections (UX map)

| Section | What it shows | Plugin analogue |
| --- | --- | --- |
| **Hero / stats strip** | Large flip-style counters (digit wheels) for **Total launches**, **Total landings**, **Total reflights**, plus **Ongoing missions** count | Cached agency stats + local countdown/animation |
| **Ongoing missions** | Table: Mission · Time On-Orbit · Return Date And Time (e.g. Crew-12 with live T+ clock, return “October 2026”) | Crew Dragon / docked vehicles with `in_space` + `time_in_space` |
| **Upcoming launches** | Cards/table: Mission · Vehicle · Launch site · Landing site · Launch Date And Time | `launches/upcoming/?lsp__id=121` |
| **Completed missions** | Filterable archive: mission type, vehicle, launch site, return site, year; paginated (“1–10 OF 713” style) | `launches/previous/?lsp__id=121` + client filters |
| **Launch sites** | Texas (Starbase), Florida (LC-39A / SLC-40 / SLC-37), California (SLC-4E) narrative blocks | Pad/location from launch objects; optional static copy |
| **Watch / webcast** | Per-mission “watch here” / X @SpaceX livestream; often starts ~10 min before liftoff | `vid_urls` + `webcast_live` |

Observed completed-mission filters on the site:

- **Mission types:** Starship Flight Tests, Human Spaceflight, Space Station Resupply, Science, Commercial / International, Rideshare, National Security, Starlink, Direct to Cell, Starman  
- **Vehicles:** Falcon 9, Falcon Heavy, Starship, Falcon 1  
- **Launch sites:** LC-39A FL, SLC-40 FL, SLC-4E CA, Starbase TX, Omelek Island  
- **Return sites:** Droneship, Landing Zone, Mechazilla, Expended, combinations  

### 1.2 Visual language

Extracted from the launches page shell CSS (`:root` + body):

| Token | Value | Use |
| --- | --- | --- |
| Background | `#000` (`.app-background`) | Primary canvas |
| Text | `--white-100: rgba(240, 240, 250, 1)` | Primary type (slight cool white, not pure #fff) |
| Secondary text | `--white-70` … `--white-35` | Labels, muted meta |
| Surfaces / chrome | `--gray-80/60/40: rgba(37, 38, 40, …)` | Cards, dividers |
| Overlays | `--black-50`, `--black-80` | Scrims on imagery |
| Typography | **D-DIN** (woff2/woff/otf), fallback Arial/Verdana | Condensed industrial; all-caps labels common on site |
| Body base | `16px/26px`, weight 400 | Desktop; smaller on ≤961px |

**Imagery:** Full-bleed launch photography, fairing/night Starlink art, pad photos. Mission cards lean on high-contrast photo + sparse white type. Stats use **mechanical digit flippers** (good plugin flourish: QML `NumberAnimation` / flip delegates).

**Interaction cues:** Minimal chrome, uppercase section titles, tabular lists, filter chips, “WATCH” CTA near NET. Official webcasts increasingly on **X broadcasts** as well as YouTube.

**Do not scrape** SpaceX assets for redistribution without checking license; prefer LL2-hosted images (they carry license metadata) or SpaceX-branded placeholders the plugin ships itself.

---

## 2. Data sources (no scraping)

### 2.1 Launch Library 2 — **primary (live)**

| | |
| --- | --- |
| Base (prod) | `https://ll.thespacedevs.com/2.3.0/` |
| Base (dev, stale, no rate limit) | `https://lldev.thespacedevs.com/2.3.0/` |
| Docs / product | https://thespacedevs.com/llapi · https://ll.thespacedevs.com/docs/ |
| Auth | None for free tier; API key via Patreon for higher limits |
| SpaceX agency | `id=121` (`/agencies/121/`) |

#### Rate limits & CORS

- Free: **15 requests / hour / IP** (`limit_frequency_secs: 3600`).  
- Check usage: `GET /2.3.0/api-throttle/` → `{ your_request_limit, current_use, next_use_secs, … }`.  
- Sample observed 2026-08-23: `your_request_limit: 15`, `current_use` increments per call.  
- Paid: higher limits per key (see Patreon on thespacedevs.com).  
- **CORS:** Irrelevant for a desktop/QML plugin using native HTTP. Browser widgets would need a proxy; not required here.  
- **Dev API (`lldev`):** unlimited but **stale** — use only for offline UI work, never for production NET/webcasts.

#### Endpoints that map to plugin needs

| Need | Endpoint | Notes |
| --- | --- | --- |
| **Total launches / landings / success** | `GET /agencies/121/` | `total_launch_count`, `successful_launches`, `failed_launches`, `pending_launches`, `attempted_landings`, `successful_landings`, `failed_landings`, `consecutive_successful_launches`, `consecutive_successful_landings` |
| **Upcoming** | `GET /launches/upcoming/?lsp__id=121` | Also `lsp__name=SpaceX`. Modes: `list` (small), `detailed` (heavy). |
| **Past / completed** | `GET /launches/previous/?lsp__id=121` | `count` ≈ total past; site “OF N” pagination |
| **Next / countdown** | First upcoming with status Go, or sort by `net` | Fields: `net`, `window_start`, `window_end`, `net_precision`, `probability` |
| **Webcast / Watch** | On launch object: `webcast_live`, `vid_urls[]` | Prefer `type.name == "Official Webcast"` (priority often 10). Sources include `x.com`, `youtube.com`. |
| **Patch images** | `mission_patches[].image_url` (detailed mode); also `program[].mission_patches` | Hosted on `thespacedevs-prod.nyc3.digitaloceanspaces.com/media/mission_patch_images/…` |
| **Hero / card imagery** | `image.image_url`, `image.thumbnail_url`, `infographic` | License object included (often CC BY-NC 2.0 for SpaceX photos) |
| **Rocket name** | `rocket.configuration.name` / `full_name` | e.g. Falcon 9 / Falcon 9 Block 5 |
| **Launchpad** | `pad.name`, `pad.location.name`, `pad.map_url` | SLC-40, SLC-4E, LC-39A, Starbase, etc. |
| **Landing / booster** | `rocket.launcher_stage[]` in detailed mode | Serial, flight number, landing type/location when present |
| **Active / ongoing missions** | `GET /spacecraft/?search=Crew%20Dragon&in_space=true` | e.g. Crew Dragon Freedom (`in_space`, ISO-8601 `time_in_space`, `time_docked`) |
| **Go-for-launch queue** | `GET /launches/upcoming/?lsp__id=121&status=1` | Status id 1 = Go for Launch |
| **Programs (Starlink, etc.)** | `GET /programs/25/` (Starlink) | Program-level patch + imagery |

**Mode tip:** Use `mode=list` for polls (id, name, net, status, image). Fetch `mode=detailed` (default detailed variants) only for the focused mission / next launch to stay under 15 req/h.

**Observed live totals (agency 121, research fetch):**

- `total_launch_count`: **721**  
- `successful_launches`: **706** · `failed_launches`: **15**  
- `pending_launches`: **129**  
- `successful_landings`: **664** · `attempted_landings`: **692** · `failed_landings`: **29**  
- `consecutive_successful_launches`: **206**  
- Upcoming list `count`: **130** · Previous list `count`: **721**  

> SpaceX.com UI counters (landings / reflights / flip digits) may not match LL2 1:1 (definitions differ: orbital-only, Starship inclusion, reflight counting). Prefer LL2 agency fields and label them clearly, or compute reflights from `launcher` / stage flight numbers if you need a closer match.

#### Example URLs

```
https://ll.thespacedevs.com/2.3.0/api-throttle/
https://ll.thespacedevs.com/2.3.0/agencies/121/
https://ll.thespacedevs.com/2.3.0/launches/upcoming/?lsp__id=121&limit=5&mode=list
https://ll.thespacedevs.com/2.3.0/launches/previous/?lsp__id=121&limit=10&mode=list
https://ll.thespacedevs.com/2.3.0/launches/upcoming/?lsp__id=121&limit=1   # detailed next
https://ll.thespacedevs.com/2.3.0/spacecraft/?search=Crew%20Dragon&in_space=true
https://ll.thespacedevs.com/2.3.0/programs/25/
```

---

### 2.2 r/SpaceX API (`api.spacexdata.com`) — **historical only / not recommended live**

| | |
| --- | --- |
| Base | `https://api.spacexdata.com` |
| Repo | https://github.com/r-spacex/SpaceX-API (**archived**, maintenance-only since ~2024) |
| Status page | https://status.spacexdata.com/ |
| Maintainers’ advice | Migrate consumers to **Launch Library 2** ([issue #1243](https://github.com/r-spacex/SpaceX-API/issues/1243)) |

**v5 launches surface** (canonical for launches; other resources mostly v4):

- `GET /v5/launches` · `/past` · `/upcoming` · `/latest` · `/next` · `/{id}`  
- `POST /v5/launches/query` (mongoose-paginate body: `query`, `options.populate`, `limit`, `sort`)  

Useful historical fields when the host is up:

- Counts via query pagination `totalDocs`  
- `links.patch.small/large` (imgbox), `links.webcast`, `links.youtube_id`, `links.flickr`  
- `date_utc` / `date_unix`, `rocket`, `launchpad`, `cores[].landing_*`, `name`, `flight_number`, `upcoming`  

**Research probe (2026-08-23):** all `api.spacexdata.com` GETs from this environment returned **HTTP 525** (Cloudflare SSL handshake failure). Treat as **unreliable**. Even when healthy, data stops updating mid-2020s — unsuitable for upcoming NET, live webcasts, or current totals.

**CORS:** Community API historically allowed browser GET; moot for QML. No API key for reads.

---

### 2.3 Other sources (optional)

| Source | Role |
| --- | --- |
| Spaceflight News API | Related articles by LL2 launch UUID |
| Flight Club (`flightclub_url` on LL2 launches) | Trajectory / telemetry deep-link |
| Wikipedia Falcon 9 lists | Human-curated history; not an API |
| SpaceX.com mission pages | Official narrative + timeline tables; scrape-hostile |

---

## 3. Image URLs

| Kind | Where | Example pattern |
| --- | --- | --- |
| Mission patch | LL2 `mission_patches[].image_url` | `…/media/mission_patch_images/space2520x252_mission_patch_….png` |
| Launch / fairing art | LL2 `image.image_url` / `thumbnail_url` | `…/media/images/falcon2520925_image_….png` |
| Agency logo | `agencies/121` → `logo.image_url` | SpaceX logo PNG on DigitalOcean Spaces |
| Webcast thumb | `vid_urls[].feature_image` | YouTube `i.ytimg.com` or X `pbs.twimg.com` |
| Legacy SpaceX-API patches | `links.patch.small/large` | `images2.imgbox.com/…` (stale dataset) |

Cache patches locally (small PNGs). Respect LL2 license objects (many SpaceX photos **CC BY-NC 2.0** — fine for personal desktop widget, avoid commercial redistribution).

---

## 4. Mapping UX goals → API

| UX goal | Primary fields |
| --- | --- |
| **Total launches** | `agencies/121.total_launch_count` (or previous `count`) |
| **Total landings** | `successful_landings` / `attempted_landings` |
| **Total reflights** | Not a single agency field — derive from reusable launcher stages (`flight` > 1) or approximate; label carefully |
| **Active / ongoing missions** | Crew Dragon `in_space=true` (+ cargo Dragon if desired); show `time_in_space`, expected return from related expedition/launch if available |
| **Watch** | Next launch `vid_urls` where `type` is Official Webcast; surface `webcast_live` for LIVE badge |
| **Interesting graphics** | Digit flippers for stats; patch + launch image on cards; countdown ring to `net`; optional Flight Club link |
| **Countdown** | `net` (UTC) − now; honor `net_precision` (hour/day/month → fuzzy UI) |

---

## 5. Proposed local cache data model

Designed for SQLite / JSON file + QML models. Refresh strategy below.

```jsonc
{
  "meta": {
    "schema_version": 1,
    "source": "ll2",
    "fetched_at": "2026-08-23T05:30:00Z",
    "agency_id": 121,
    "throttle": { "limit": 15, "used": 3, "resets_in_secs": 3400 }
  },

  "stats": {
    "total_launches": 721,
    "successful_launches": 706,
    "failed_launches": 15,
    "pending_launches": 129,
    "attempted_landings": 692,
    "successful_landings": 664,
    "failed_landings": 29,
    "consecutive_successful_launches": 206,
    "consecutive_successful_landings": 13,
    "year_launch_count": 102,          // from latest launch agency_launch_attempt_count_year
    "reflights_approx": null             // optional computed
  },

  "next_launch": { /* LaunchRecord */ },
  "upcoming": [ /* LaunchRecord, limit 10–20 */ ],
  "recent": [ /* LaunchRecord, limit 10 */ ],
  "ongoing": [ /* OngoingMission */ ],
  "watch": [ /* WebcastLink from next + any webcast_live */ ],

  "assets": {
    // local paths after download
    "patches": { "<patch_id>": "cache/patches/7.png" },
    "images": { "<image_id>": "cache/images/1296.jpg" }
  }
}
```

### `LaunchRecord`

```jsonc
{
  "id": "uuid",
  "slug": "string",
  "name": "Falcon 9 Block 5 | Starlink Group 10-49",
  "mission_name": "Starlink Group 10-49",
  "mission_type": "Communications",
  "status_id": 1,
  "status": "Go for Launch",
  "net": "2026-08-25T05:49:00Z",
  "window_start": "...",
  "window_end": "...",
  "net_precision": "minute|hour|day|month|...",
  "probability": 70,
  "rocket_name": "Falcon 9",
  "rocket_full_name": "Falcon 9 Block 5",
  "pad_name": "Space Launch Complex 40",
  "location_name": "Cape Canaveral SFS, FL, USA",
  "landing_summary": "ASDS | A Shortfall of Gravitas",  // derived
  "image_url": "https://...",
  "thumbnail_url": "https://...",
  "patch_url": "https://...",
  "webcast_live": false,
  "vid_urls": [
    {
      "url": "https://x.com/i/broadcasts/...",
      "source": "x.com",
      "publisher": "SpaceX",
      "type": "Official Webcast",
      "priority": 10,
      "feature_image": "https://..."
    }
  ],
  "program_ids": [25],
  "ll2_url": "https://ll.thespacedevs.com/2.3.0/launches/{id}/",
  "last_updated": "..."
}
```

### `OngoingMission`

```jsonc
{
  "id": 551,
  "name": "Crew Dragon Freedom",
  "serial": "C213",
  "config": "Crew Dragon 2",
  "in_space": true,
  "time_in_space": "P563DT6H4M44S",  // parse to live timer in UI
  "time_docked": "P554DT9H57M24S",
  "image_url": "https://...",
  "return_estimate": null,            // fill from site/expedition when known
  "related_launch_id": null
}
```

### Suggested refresh budget (≤15/h free)

| Interval | Calls | Endpoints |
| --- | --- | --- |
| Every 30–60 min | 1 | `agencies/121/` → stats |
| Every 15–30 min | 1 | `launches/upcoming/?lsp__id=121&limit=10&mode=list` |
| Every 1–6 h | 1 | `launches/previous/?lsp__id=121&limit=10&mode=list` |
| On focus / T−2h | 1 | detailed single launch by id (webcasts, stages) |
| Every 6–12 h | 1 | `spacecraft/?search=Crew%20Dragon&in_space=true` |
| Rare | 1 | `api-throttle/` when 429 / debugging |

**Total ≈ 4–8 calls/hour** with room to spare. Persist ETags/`last_updated` and skip writes when unchanged. Use `lldev` only in CI/demo fixtures.

---

## 6. Plugin UX sketch (Omarchy / QML)

1. **Header:** SpaceX wordmark-style D-DIN title + LIVE pill if any `webcast_live` or Official Webcast starting soon.  
2. **Stats row:** three flip counters — Launches · Landings · (Reflights or Consecutive success).  
3. **Next mission card:** patch, name, rocket, pad, big countdown, primary **WATCH** button (open `vid_urls[0]` official).  
4. **Ongoing:** compact rows with elapsed on-orbit clock.  
5. **Upcoming list:** 5 rows; tap expands details from cache.  
6. **Theme:** `#000` bg, `rgba(240,240,250)` text, gray-80 cards, generous letter-spacing uppercase labels.

---

## 7. Samples in this repo

Directory: `docs/research/samples/`

| File | Contents |
| --- | --- |
| `ll2-api-throttle.json` | Rate-limit snapshot |
| `ll2-spacex-agency-121.json` / `-compact.json` | Agency stats (primary totals) |
| `ll2-agencies-spacex.json` | Search hit for SpaceX |
| `ll2-spacex-upcoming-list.json` | Compact upcoming list |
| `ll2-spacex-previous-list.json` | Compact previous list |
| `ll2-spacex-upcoming-one.json` | Slimmed detailed upcoming launch |
| `ll2-spacex-previous-one.json` | Slimmed detailed previous launch |
| `ll2-launches-go.json` | Go-for-launch filter sample |
| `ll2-dragon-search.json` / `ll2-dragon-in-space-correct.json` | Crew Dragon / in-space |
| `ll2-program-25-starlink.json` | Starlink program + patch |
| `ll2-falcon9-config.json` | Falcon 9 configuration variants |
| `spacex-v5-*.json` / `spacex-v4-company.json` | Stubs documenting HTTP 525 + maintenance-only status |

---

## 8. Recommendation

**Primary API: Launch Library 2 (`ll.thespacedevs.com/2.3.0`), filtered with `lsp__id=121`.**  

It is actively maintained, exposes webcasts (including official X streams), patches, pads, NET/windows, and agency-level launch/landing totals — everything the Omarchy plugin needs without scraping SpaceX.com.  

Treat **r-spacex/SpaceX-API** as legacy/historical only (currently failing open with 525 here and frozen since maintenance mode). Optionally keep its schema in mind for field naming familiarity (`webcast`, `patch`), but implement against LL2.

