# Fallout Rockies

Fallout-*inspired* Colorado wasteland overworld — Godot 4. An original game,
not a clone of any Bethesda IP.

Current state: the core loop is in place — title menu → childhood bunker
prologue → top-down overworld with kid movement, Platte River drowning,
checkpoints, death → reset-to-checkpoint, and a versioned save file.

The JS/canvas prototype (superseded) lives in `archive/js-canvas/`.

## Controls

- **Arrow keys / WASD** — move (tap for one nudge, hold to walk)
- **Enter / Space** — confirm menu selection
- **Escape** — back to title
- **Mouse** — hover/click the menu buttons

## Run it

Open `fallout-rockies/` in Godot 4 — either run it from the editor (F5) or from the terminal:

```sh
~/Applications/Godot.app/Contents/MacOS/Godot --path "."
```


The title screen starts a new game through the bunker prologue; the bunker
auto-saves the kid (age 13) and drops them into the overworld at the
airport. Deaths reset to the last safe checkpoint with carry-forward state
(age, artifact, deaths) intact; the save lives in `user://fallout_rockies.save.json`.

## Smoke test (automated)

With Godot 4 available (e.g. `~/Applications/Godot.app`):

```sh
godot --headless --path . -- --smoke
```

Walks the full flow headlessly — title → bunkers → overworld → movement +
checkpoint save → water drowning death → reset — and prints a PASS/FAIL
summary. Exit code = number of failures (0 = pass).

## Layout

- `project.godot` — engine config (320×176 logical viewport, canvas_items stretch)
- `scenes/Main.tscn` — root scene (holder + scene swap)
- `scripts/game.gd` — autoload: carry state, scene switching, smoke mode
- `scripts/save.gd` — versioned JSON save in `user://`
- `scripts/world_map.gd` — procedural map (72×52), regions, palette
- `scripts/main.gd` · `scripts/title.gd` · `scripts/bunkers.gd` · `scripts/overworld.gd` · `scripts/kid.gd`
- `archive/js-canvas/` — the old browser version (reference only)
