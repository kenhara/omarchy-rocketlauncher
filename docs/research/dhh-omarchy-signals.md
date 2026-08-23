# DHH / Omarchy signals for Space Jockey

**Purpose:** Concrete things DHH (and close Quattro framing) has said about Omarchy, plugins, and the “malleable computer” — mapped to competition plugin strategy for `harris.space-jockey`.  
**Refresh:** Sun 23 Aug 2026 (America/Denver)  
**Competition:** Mon 24 Aug 2026, 09:00 CEST · Core Team vote · “best ideas and execution”  
**Note:** X/Twitter API was not used; quotes come from omarchy.org/news, GitHub releases/manual, hey.com essays, Rails World 2025 transcript coverage, Digg syndication of launch tweets, and secondary Linux coverage.

---

## 1. Direct quotes / paraphrases (with sources)

### Fun, aesthetics, “computers should be fun”

| # | Quote / paraphrase | Source |
|---|--------------------|--------|
| 1 | **“Computers should be fun. They should be cool. They should look a little bit like a hacker movie.”** Preceded by: “What if computers were fun again?” | Rails World 2025 Opening Keynote transcript ([RubyEvents.org](https://www.rubyevents.org/talks/opening-keynote-rails-world-2025)); Omarchy demoed live in the keynote. |
| 2 | **“Are they a little nerdy? Yes, that's the fun! That's the point! That's the productivity!”** (on TUIs / LazyGit) | [Omacom Doctrine](https://learn.omacom.io/3/omacom/81/doctrine) |
| 3 | **“Omarchy embraces hard corners, 80s retro colors, and monospace fonts… confident in its own aesthetic.”** Not Liquid Glass / Windows taskbar cosplay. | Doctrine (same) |
| 4 | **“Aesthetics matter… The pursuit of beauty is a core human yearning.”** Beauty as aid to a “beautiful, cohesive, and productive system,” not decoration over function. Aim: **“tastefully cohesive and casually cool.”** | Doctrine |
| 5 | **“Technology is simply more fun when you're optimistic about the idea that tomorrow's tools could be better.”** | Doctrine |
| 6 | Manual framing: beautiful system → motivation → productivity; **“Omarchy isn't just for pRoDUcTiVItY, it's also for having fun”** (gaming chapter energy). | [Omarchy Manual](https://learn.omacom.io/2/the-omarchy-manual) |

### Malleable computer / agent-built OS

| # | Quote / paraphrase | Source |
|---|--------------------|--------|
| 7 | **“Open source promised that users would be free to change whatever code they were running. The reality… hardly any of them ever did — it was simply too hard. Now, with AI, it suddenly isn't.”** | [The malleable computer](https://world.hey.com/dhh/the-malleable-computer-7c187a9b) (15 Apr 2026) |
| 8 | Excitement peaks when AI can change **“your system's menu bars, your window manager, your notification system, your everything”** — and **“you can only do this on Linux.”** | Same essay |
| 9 | **“I've already seen this a lot in the Omarchy world: users who aren't super technical making the system their own with the help of AI and being utterly delighted.”** | Same essay |
| 10 | Foundation launch: **“It's time to dream big. Omarchy Quattro has given people a chance to experience what the malleable computer of the future looks like, and they like it (a lot!).”** Moral obligation to broaden that future. | [Omacom Foundation launches with $8 million](https://omarchy.org/news/2026/08/omacom-foundation-launches-with-8-million) (DHH byline on omarchy.org/news) |
| 11 | Digg syndication of launch tweets: DHH — **“Omarchy Quattro is out!! This is one of the greatest software releases in my professional career. I hope you enjoy using it just as much as I did building it.”** | [Digg: DHH Releases Omarchy Quattro](https://digg.com/tech/lwpvnwp5) |
| 12 | Same Digg thread (Tobi Lütke / related posts): **malleable OS for the agentic age**; **“Just ask your agent to build your idea, and shortly after your operating system is enhanced. Magical traction on this concept with Quattro.”** | Digg syndication of X posts around Quattro launch |
| 13 | Core Team charter: build for people **“excited about the age of agents, the malleable computer, and beautiful, modern, opinionated computing.”** HANCORE stewarding **plugin ecosystem**. | [The Omarchy Core Team](https://omarchy.org/news/2026/09/the-omarchy-core-team) |
| 14 | Origin energy: Arch+Hyprland so atomized you can **“change EVERYTHING!”**; Hyprland tiling is **“one of the most intoxicating ways of using a computer”**; bottle the setup so others don’t need **10–20 hours**. | [Omarchy: Bottling that inspiration before it spoils](https://world.hey.com/dhh/omarchy-bottling-that-inspiration-before-it-spoils-cd75e26b) (2 Jun 2025) |

### Quattro shell, plugins, first-party bar widgets (DHH-authored release text)

| # | Quote / paraphrase | Source |
|---|--------------------|--------|
| 15 | Quattro = biggest release: bar/launcher/menus/notifications/OSDs/panels/lock/polkit in **one Quickshell process with a plugin architecture**. | [v4.0.0 release notes](https://github.com/basecamp/omarchy/releases/tag/v4.0.0) authored by **@dhh** |
| 16 | **Bar plugin system:** third-party widgets (and whole bars) via `omarchy plugin add <git>` · managed from **Setup > Plugins** — by @ryanrhughes and **@dhh**. | Same |
| 17 | Headline: **“Add plugin system and full ecosystem”** → [omarchyplugins.com](https://omarchyplugins.com/). | Same |
| 18 | First-party exemplars called out in the same release DHH shipped: **model-usage / Agents bar widget** (Claude Code / Codex / Fireworks stats) · **Google Meet picture-in-picture widget** · Tailscale/Dropbox service panels · weather forecast panel · event-driven (not polled) shell. | Same + [AI manual](https://omarchy.org/manual/ai/) |
| 19 | Agents panel UX pattern (official): bar icon appears when usage exists; **left-click = dense panel**, **right-click = launch default agent**; pace / plan / token breakdown; stays out of the way until useful. | Manual AI · Agents plugin README (quattro) |
| 20 | Meet PiP: a **tiny always-useful bar affordance** for a real-world activity (calls), not a settings clone — community pattern to mirror for “live” contexts (webcasts). | Release notes (credited @ryanrhughes; shipped in DHH’s Quattro narrative) |

### Plugin competition & marketplace

| # | Quote / paraphrase | Source |
|---|--------------------|--------|
| 21 | **“The Omarchy Plugin Marketplace is already home to over 500 plugins and growing very fast.”** | [The first plugin competition](https://omarchy.org/news/2026/08/the-first-plugin-competition/) |
| 22 | **“We have a million ideas for how we can improve this setup, including with automated agent-powered security reviews, but let’s not have perfect be the enemy of good and fun for now!”** | Same |
| 23 | Competition funded with **“the four grand that I received from yapping endlessly about Omarchy on X”**; winners by **Omarchy Core Team** vote; prizes $2500 / $1000 / $500; deadline Mon 24 Aug 2026 09:00 CEST. | Same |
| 24 | Closing line: **“Have fun and may the best ideas and execution win!”** | Same |
| 25 | Agent-built plugins are already culturally normal (e.g. marketplace buddy plugins credit agent teams) — matches malleable-computer thesis. | Community examples + Digg “ask your agent” framing |

### Dead-simple apps & delight over chrome

| # | Quote / paraphrase | Source |
|---|--------------------|--------|
| 26 | Quattro ships **Omawrite / Omacut / Omacalc** as **“dead-simple”** defaults — blink-open, stay out of the way, free software. | v4.0.0 feature presentation (DHH) |
| 27 | Not mass-market appliance Linux: for **developers, designers, the technically-inclined**; **unapologetically Linux**. | Doctrine |

---

## 2. What these imply for a competition plugin

Core Team judges are steeped in the above. Implied scoring axes:

1. **Delight in ≤10 seconds** — “computers should be fun” / “best ideas and execution.” A one-sentence pitch that feels like a hacker-movie prop beats a settings utility.
2. **Native shell citizen** — Quattro’s whole point is plugins *inside* `omarchy-shell`, not bolted Electron/SPA. Correct `bar-widget` lifecycle, theme tokens, IPC.
3. **Tiny bar → rich popout** — Clock, Agents, Meet PiP, Weather: compact glyph/text on the bar; depth in a panel. Agents: dense data without bar clutter.
4. **Malleable / agent-friendly packaging** — clear README, schema knobs (no QML edit required), `omarchy plugin add` install, validate-clean — so an agent (or non-expert) can install/tweak safely. Perfect security is coming later; still avoid scary baseline flags.
5. **Opinionated aesthetic, not Mac/Win cosplay** — monospace, hard corners, theme-cohesive; SpaceX mood via typography/motion, not a private “Liquid Glass” skin that fights Omarchy themes.
6. **Live / real-world activity** — Meet PiP and Agents usage prove DHH ships widgets for *things you do while computing* (calls, agent spend). A launch countdown + Watch sits in that family.
7. **Ship fun now** — “don’t let perfect be the enemy of good and fun”; polish execution, don’t wait for a mega-suite.

**What judges are unlikely to reward:** full `kind: bar` replacements, CRT overlays that tax GPU for vibe alone, affiliation-claiming brand skins, fake stats, or plugins that fight the shell (second Quickshell, package-manager hooks, auto-editing Hypr binds).

---

## 3. Concrete Space Jockey improvements mapped to signals

**Baseline product (already shipped):** bar countdown · flip-digit stats · mission detail · crew avatars · Watch (yt-dlp + Qt Multimedia) · LL2 data · unofficial disclaimer · README install/IPC · schema knobs (`refreshIntervalSec`, `notifyMilestones`, `barShowMissionName`, `stickyWatch`) · Fun category · MIT · `harris.space-jockey` (was `harris.launch-desk`).

| Signal | Already done | Still worth doing (pre-deadline) |
|--------|--------------|----------------------------------|
| **Fun / hacker-movie aesthetic** (#1–6) | Flip digits, starfield/scanline, countdown drama, Watch webcast | Finish **theme-token chrome** (drop hardcoded SpaceX greys → `Color` / `bar.foreground` / `Style.cornerRadius`); keep mood via letter-spacing / uppercase / low-alpha motion |
| **Tiny bar → rich panel** (#18–20 Agents / Meet / Clock) | Rocket + NET countdown on bar; panel with flips + cards + Watch | Optional **bar mission name**; **right/middle-click** shortcuts (refresh / Watch); bar glyph when sticky Watch playing |
| **Dense-but-scannable stats** (#18–19 Agents) | Flip counters for launches / landings / pending | Pace-like narrative optional later; don’t clutter bar — Agents stays out of the way until useful |
| **Live activity widget** (#20 Meet PiP) | Watch for webcast | **Sticky Watch** true-path; **keyboard** Space/M/O; optional idle-inhibit while playing |
| **Malleable / schema / agent-tweakable** (#7–9, #12) | Multi-key `barWidget.schema` | Document schema in README; `summon '{"watch":true}'` payload; optional Hypr bind *snippet* (never auto-write) |
| **Ship fun, not perfect security theater** (#22) | No sudo install; LL2 + cache | `omarchy plugin validate`; avoid `omarchy pkg add`; honest deps; aim marketplace baseline `passed` |
| **Dead-simple delight** (#26) | One panel, one pitch | **Hero `preview.png`** on real Omarchy desktop (bar + flips + mission); README controls table |
| **Honest / unapologetic Linux** (#3, #27) | Unofficial disclaimer; LL2 honesty (no fake reflights) | Keep — Core Team will notice affiliation cosplay |
| **Competition closing vibe** (#24) | Pitch: “Space Jockey on your Omarchy bar…” | Demo script: open → flips → expand → Space Watch → Esc → optional T−10 toast |

### Priority stack (aligned with DHH signals, not just peer plugins)

1. Theme-native chrome → “tastefully cohesive” / not fighting Quattro themes  
2. Watch keys + sticky Watch + bar modifiers → Meet-PiP-class “live” widget  
3. Preview + README controls/IPC → execution judges can *see* in 10s  
4. Validate / baseline-clean → agent-powered review culture coming; don’t be the scary listing  
5. Notify milestones (schema already present) → Agents/Coin-Toss-style opt-in toasts  

**Skip relative to DHH signals:** CRT suite, full bar replacement, Electron/SPA, fake SpaceX branding, overbuilt Discover/download managers.

---

## 4. Source index

| Resource | URL |
|----------|-----|
| Plugin competition | https://omarchy.org/news/2026/08/the-first-plugin-competition/ |
| Foundation / malleable future | https://omarchy.org/news/2026/08/omacom-foundation-launches-with-8-million |
| Core Team | https://omarchy.org/news/2026/09/the-omarchy-core-team |
| Quattro release (DHH) | https://github.com/basecamp/omarchy/releases/tag/v4.0.0 |
| Malleable computer essay | https://world.hey.com/dhh/the-malleable-computer-7c187a9b |
| Bottling inspiration | https://world.hey.com/dhh/omarchy-bottling-that-inspiration-before-it-spoils-cd75e26b |
| Omacom Doctrine | https://learn.omacom.io/3/omacom/81/doctrine |
| AI / Agents manual | https://omarchy.org/manual/ai/ |
| Digg Quattro tweet roundup | https://digg.com/tech/lwpvnwp5 |
| Rails World 2025 keynote (“computers should be fun”) | https://www.rubyevents.org/talks/opening-keynote-rails-world-2025 |
| Linuxiac Quattro coverage | https://linuxiac.com/arch-based-omarchy-4-0-quattro-is-here-with-its-biggest-desktop-overhaul-yet/ |
| Related internal briefs | `docs/research/space-jockey-next-ideas.md`, `docs/research/omarchy-plugins.md`, `DESIGN.md` |

---

*X.com was not opened; primary sources above are sufficient for competition framing.*
