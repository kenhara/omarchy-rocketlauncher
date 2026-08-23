# Omarchy Breakout

A full Breakout campaign for the Omarchy desktop: 25 handcrafted levels, deterministic arcade physics, power-ups, combos, persistent high scores, and a collection of affectionate 37signals and Omarchy easter eggs.

The game is a native Omarchy Quattro plugin. It uses QML Canvas, Qt Multimedia, and dependency-free JavaScript, follows the active Omarchy color theme live, and does not open a browser or install a game engine. Brick debris, impact sparks, tiny hit-freezes, subtle screen shake, squash-and-stretch balls, and combo-pitched audio give every hit tactile arcade feedback.

## Install

```bash
omarchy plugin add https://github.com/acrogenesis/omarchy-breakout.git --enable
```

For local development, replace the URL with the path to this git checkout. Launch it from the bar's grid button or with:

```bash
omarchy-shell shell toggle acrogenesis.breakout '{}'
```

Start a fresh run directly on any campaign level from 1 through 25:

```bash
omarchy-shell shell summon acrogenesis.breakout '{"level":3}'
```

When the panel is already loaded, `omarchy-shell breakout startLevel 3` can also restart it directly.

## Requirements and removal

Omarchy Breakout requires Omarchy Quattro and its built-in Omarchy Shell. It has no external runtime dependencies, makes no network requests, requires no elevated privileges, and does not overwrite user configuration.

Remove it with:

```bash
omarchy plugin remove acrogenesis.breakout --yes
```

Removal deletes the plugin checkout and disables its bar entry. High scores and the sound preference under `~/.local/state/omarchy-breakout/` are intentionally retained as user data and can be deleted separately if desired.

## Controls

| Key | Action |
|---|---|
| `Left` / `A` | Move left (`Left` aims a held sticky ball) |
| `Right` / `D` | Move right (`Right` aims a held sticky ball) |
| `Space` | Launch or release a sticky ball |
| `Enter` | Start or restart a campaign |
| `P` | Pause |
| `F10` or click `SOUND` | Toggle sound |
| `Esc` | Close (the game pauses safely) |

Catch falling capsules for a wider paddle, a slower ball, an extra life, three-ball multiball, a brick-piercing fireball, a sticky paddle with aimed relaunch, a one-save bottom shield, or a magnet that pulls other capsules toward the paddle.

The campaign now starts briskly and keeps tightening: launch speed rises from 560 on level 1 to 1,040 on the secret finale, the ball accelerates as each board empties, and the paddle gets progressively narrower. Levels 6, 12, 18, and 24 end in compact three-phase bosses with distinct chassis: a horned creeper, a twin-drum reloader, a maze block, and a monolith. Level 25 is a secret empty arena against a large Apple-logo boss; a few capsules rain in during the fight. Each design stays intact throughout its fight while it patrols, predicts approaching ball paths, and dodges. Machine bosses keep a living LED visor. The apple is the 1977 rainbow logo: stripes flash when it fires or takes a hit, the leaf tilts as it watches, and the bite glows like a mouth. No screen on the fruit. The first boss fires one slow aimed orb at a time; later bosses add simultaneous volleys. Touching an orb costs a life. Each later boss takes more hits, and every defeat ends in a flash, expanding shockwaves, sparks, and flying armor.

## Campaign

The 25 stages run from **The Boot** through **One More Thing**, with stops at Arch BTW, Tokyo Night, Basecamp Hill, Signal 37, Campfire, HEY, Writebook, Rails, Hotwire, Turbo, Stimulus, Kamal, Solid Cable, ONCE, REWORK, Shape Up, One Person Framework, and a secret apple arena. Reinforced bricks take two hits; steel bricks redirect the ball but do not need to be cleared. Every sixth board adds a named boss encounter beneath its symbolic brick scene.

Some bricks and key sequences say more than the manual does. Try the initials of Omarchy's creator, or type the name of the place where 37signals keeps its work.

High scores persist in `~/.local/state/omarchy-breakout/highscores.json` (or `$XDG_STATE_HOME/omarchy-breakout/highscores.json`).

## Development and tests

```bash
qs -p /path/to/omarchy-breakout
qs ipc -p /path/to/omarchy-breakout call breakout startLevel 6
omarchy plugin validate .
node tests/test_engine.js
node tests/test_audio.js
node tests/test_effects.js
node tests/test_campaign.js
bash tests/live-test.sh
```

Closing the window hides it but leaves the development process running. Reopen a specific level with `qs ipc -p /path/to/omarchy-breakout call breakout startLevel 6` instead of launching a second `qs -p`. `summon '{"level":6}'` also works once the process is up. Use `qs ipc --newest` only if a duplicate instance was started.

The live test launches the real QML panel in the current Wayland session, focuses it defensively, injects keyboard input, plays the paddle against the moving ball, checks live IPC state and framerate, captures screenshots, and restores the previous window focus.

## Credits
