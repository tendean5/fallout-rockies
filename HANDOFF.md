# HANDOFF — Fallout Rockies (Godot 4)

> Jump-off document. The browser/JS build is archived in `archive/js-canvas/`.

## The game

**Fallout Rockies** — an original, Colorado-specific, Fallout-*inspired*
roguelike. Not a clone (Fallout is Bethesda IP — original names; "BoS" is a
placeholder that should be renamed before real release).
**Format**: 1-player, Godot 4, original art style (placeholder pixel art
drawn procedurally — replaces `archive/js-canvas/` prototype).

**Structure**: Hades-style die-and-return. Death returns to the last
checkpoint; carry-forward state (artifact, flag, age, deaths) persists.
The ending is a *choice*, not a defeat condition (not built yet).

**Engine**: Godot 4.7.2 (GDScript). Top-down overworld, like Fallout 1/2.

## Current state — Godot rebuild (PASS)

- `project.godot` — viewport 320×176 logical, `canvas_items` stretch, no antialias; autoloads `Game` (`scripts/game.gd`); main scene `scenes/Main.tscn`.
- `scenes/Main.tscn` — root Node2D, creates holder node, starts title scene.
- `scripts/game.gd` — autoload: carry state, checkpoint, scene switching (`scene_change_to`), save, smoke mode.
- `scripts/save.gd` — versioned JSON save `user://fallout_rockies.save.json` (v1).
- `scripts/world_map.gd` — procedural 72×52 map (same layout as the JS port): Denver grid, airport zone (SW), high country (E), desert (W), peaks (N-E w/ snow pass), dense forest (N-W), Platte River across the bottom w/ road bridge. Region names + palette.
- `scripts/title.gd` — menu: NEW GAME (clears save → bunker prologue) / LOAD (overworld). Keyboard nav + mouse hover/click.
- `scripts/bunkers.gd` — prologue walkthrough corridor (no platformer mechanics): kid walks right; surface fade → save (age 13) → overworld.
- `scripts/overworld.gd` — THE GAME: camera-follow top-down renderer, kid movement (tap assist + hold, 3.4 tiles/s), collisions, water drowning (1.6s → death), checkpoint autonsave (≈1.5s safe walking), HUD (AGE + region + DEATHS), death overlay → reset kid to checkpoint.
- `scripts/kid.gd` / `kid_state.gd` — kid sprite drawing + typed kid state object.
- The old browser prototype is archived in `archive/js-canvas/` (reference only).

## Verified

- `godot --headless -- --smoke`: PASS — title → bunkers → save → overworld → walk/checkpoint (x=7) → drown → death → reset (deaths=1), 0 failures, exit 0.
- Rendering verified via `--shot <path>` (captures a frame 0.6s in and prints a color histogram): title shows dark bg + gold text + button fills; overworld shows dirt/water tiles + gold kid + HUD bar. Both were frozen after frame 1 until the `queue_redraw()` fix (scenes call it every physics frame now).

## Known / not verified

- **Playtesting in a real window (display) is the remaining task** — the shot harness is headless (Metal), not interactive play.
- Art is placeholder (flat-color tiles + drawn rect kid, like the old canvas build). Real pixel-art sprites still needed.
- Not yet built: quests/story/factions, combat, dialogue, audio.

## Open decisions

1. Exporter/run workflow — how to get the game in front of a player (Godot binary vs export).
2. Art direction — kid/tiles pixel art.
3. Region composition / story beats.
4. Save schema migration path (v1 is bare: version, age, checkpoint, carry, savedAt).

## Commands

- Run: `~/Applications/Godot.app/Contents/MacOS/Godot --path .` (Godot 4.7.2 installed in ~/Applications)
- Headless smoke: `godot --headless --path . -- --smoke`
- Visual capture: `godot --path . -- --shot /tmp/shot.png --start=overworld` (debug flag; captures a frame 0.6s in, prints a color histogram, quits)
- Export: not set up yet.
