# Omatower Defense

Tower defense on real Grand Prix circuits, as a native Omarchy shell plugin.

You park Audi Quattros around a lap. The takes about Omarchy drive it — *not a
distro*, *bloatware*, *shell-script-slop*, *cachy-is-better*, *THE-NIXPILL* —
and if one completes the lap and crosses your start/finish line, you lose a
life. The cars shoot back with the effects from Omarchy's own `ttfx`
screensaver: `binarypath`, `matrix`, `laseretch`, `fireworks`, `blackhole`.

Everything is drawn in QML — no sprite sheets, no assets — and the whole game
recolours itself from your current Omarchy theme, light or dark.

![Omatower Defense at Spa-Francorchamps: Quattros parked around the lap, a laseretch beam through the pack](preview.png)

<sub>Spa-Francorchamps, wave 14, under the Ethereal theme. Every colour on screen
came from `colors.toml`.</sub>

## Install

```bash
omarchy plugin add https://github.com/perfektnacht/omatower-defense --enable
```

Or, to hack on it, symlink the checkout into your plugins directory and
enable it:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/perfektnacht.omatower-defense
omarchy plugin enable perfektnacht.omatower-defense
```

Open it with the car icon in the bar, or bind a key to:

```bash
omarchy-shell shell toggle perfektnacht.omatower-defense
```

Hiding the overlay pauses the run rather than throwing it away, so you can duck
out mid-wave and come back.

**Switching workspace hides it too.** A layer-shell overlay floats above every
workspace, so without this the game would sit on top of whatever you switched to
with nothing clickable underneath. Leaving its workspace closes the overlay and
pauses the run where it stands; the bar icon brings it back untouched.

### Without Omarchy

It also runs as a plain window on any Quickshell install:

```bash
qs -p .
```

## Removal

```bash
omarchy plugin remove perfektnacht.omatower-defense
```

That disables it and deletes the plugin directory. If you installed by hand
with the symlink above, the plugin directory is a link to your checkout, so
remove the link and leave the checkout alone:

```bash
omarchy plugin disable perfektnacht.omatower-defense
rm ~/.config/omarchy/plugins/perfektnacht.omatower-defense
```

Nothing else to clean up: the game writes no config, no save files and no state
outside its own plugin directory. It only ever *reads* your theme from
`~/.local/state/omarchy/current/theme/`.

## Controls

| Key | Action |
|-----|--------|
| `Enter` | Start the run from the circuit picker (`←`/`→` choose a circuit) |
| `1`–`7` | Pick a car, then click a parking bay to park it |
| Left click | Place, or select a parked car |
