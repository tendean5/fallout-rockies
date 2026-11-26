# HANDOFF — Fallout Rockies

> New session should pick this up as the primary brief. It's a snapshot of the
> state of the project, the decisions made, and the work still to do.

## The game

**Fallout Rockies** — an original, Colorado-specific, Fallout-*inspired*
roguelike. Not a clone (Fallout is Bethesda IP — original names; we used
names like "BOS" as placeholders that should likely be renamed before any
real release). Pixel art, low-res canvas (320×176 internal, scaled ×3),
zero dependencies, plain JavaScript in the browser — no build step.

**Format**: 1-player, browser-based, no accounts, no backend. Save lives in
`localStorage` under `fallout-rockies.save.v1` (versioned, with seed +
carry-forwards: artifact, flag, age, deaths, checkpoint). Demo goal: prove
the premise + the die-and-return loop feel right in days, not months.

## Design decisions locked in

- **Tone**: gritty with humor — Fallout 1-style wasteland, plus Colorado
  Western flavor. Never mustache-twirling.
- **Setting**: post-apocalyptic Colorado — Denver (urban grid), Summit County
  (high country), Colorado Springs (USAFA/NORAD), Golden (Coors brewery +
  mines), Boulder (science), ski towns, Platte River, Leadville/mining towns,
  Cheyenne Mountain dome, the Blucifer statue cult, Broncos stadium ruins,
  Red Rocks, Lookout Mountain, Denver Tech Center, government buildings.
- **The lore spine**: The Enclave (airport bunkers) = US government
  continuation (from Cold War-era sites: NORAD, USAFA, Cheyenne Mountain).
  The kid sees evidence someone high up is NOT who they say they are — a
  Chinese spy — and gets exiled. The secret runs the whole timeline.
- **The player**: an Enclave kid, ~6, exiled for seeing the evidence in
  childhood, adopted by the BoS (Brotherhood of Steel — renamed later),
  grows up across the game's time-jumps — 13 (becoming-man ceremony), 18
  (meet other factions, option to leave BoS), 24 (leading a faction).
- **Structure**: Hades-style die-and-return. Death returns to the last
  checkpoint; carry-forward state (artifacts, flags, age, deaths,
  checkpoint) persists. The ending is a **choice**, not a defeat — no
  correct ending.
- **Engine**: browser canvas, plain JS. Pixel art (low-res, ~320×176 playfield).
- **Architecture**: menu → childhood bunker scene (prologue) → time jump
  → overworld. The bunker scene is now a **walk-through corridor** — NOT a
  platformer (no pit, no jump, no gravity).

## Current state — rebuilt overworld (uncommitted)

- `index.html` — canvas 320×176, dark bg, scaled ×3, favicon hack
- `src/main.js` — boots the game
- `src/game.js` — Game class (loop, input, scene manager, mouse click,
  mouse hover + pointerdown events)
- `src/ui.js` — text/rect helpers
- `src/save.js` — load/write/clear (versioned JSON)
- `src/worldmap.js` — procedural world map (72×52 tiles): Denver grid
  (blocks + dirt streets), desert, forest, high country, mountain ridge
  with a snow pass at cols 46–49, Platte River across the bottom (wavy, with
  a road bridge), region names, `colorOf(t, x, y)`
- `src/scenes/title.js` — menu: New Game (clears save, starts childhood
  bunker) / Load (overworld). Keyboard nav (Up/Down + Enter/Space) + mouse
  click/hover.
- `src/scenes/bunkers.js` — childhood prologue: walkthrough corridor
  (no platformer mechanics). Tap + hold movement. Walking past the corridor
  → fade → "you fall, wake at the surface…" → save (age 13) → overworld.
- `src/scenes/overworld.js` — THE GAME: tile renderer with region-based
  tints; kid movement (tap nudge + hold, WALK=3.4 tiles/s); smooth
  camera-follow; water (Platte River) = drowning timer (1.6s → death);
  checkpoint-forward autonsave (every ~1.5s of safe walking); HUD
  (AGE + region name · deaths); death overlay → resetKid → last checkpoint;
  fade-in at scene start.
- `src/scenes/adult.js` — REMOVED (replaced by overworld)
- `.gitignore`, `README.md` (updated to match overworld), `CONCEPT.md`,
  `BUILD.md`
- `window.__game` debug handle in main.js (shallow in the automated
  browser unlike a real browser — ignore; not relied on)

## What's known / not verified

- Automated harness (this agent environment) **cannot hold keys** like a
  player would. Verified: menu loads cleanly, Enter/New Game/Load
  transitions work, the bunkers and overworld scenes render with zero
  console errors, canvas responds to key events.
- NOT verified by play: the kid's actual movement feel, tap assists,
  water drown at the Platte, checkpoint saves, actual death → reset loop.
  **Playtesting in a real browser is the first remaining task.**
- The automated harness cannot read `window.__game` (phantom global — not
  a bug in the game; the game runs fine).
- The overworld has no content/story/quests yet — just the map + movement.

## Open decisions (want user input)

1. How big the world should be / whether the overworld is the right shape
   vs. the childhood being the main thing.
2. Art direction — kid is an untextured colored rectangle; tiles are flat
   color. Real sprites still needed.
3. Region composition / story beats per zone.
4. Dialogue/story structure for the adult (factions, the secret).
5. Engine question (browser canvas vs. Godot — Godot is the strong
   migration target if the game proves fun; browser canvas for now).
6. Stale `?v=N` cache-busting in index.html — bump when code changes if
   needed (the harness caches modules aggressively).

## Known to the user, not blocking

- `window.__game` is used only as a dev handle; not needed by the game.
- `src/scenes/adult.js` is deleted — not needed anymore.
- The childhood bunker is now purely a one-time prologue, not a platformer.
- Deaths reset the kid to the last checkpoint; the save persists the
  checkpoint across sessions.

## Commands

Run: `python3 -m http.server 8000` from the repo folder → open http://localhost:8000
Commit state: see `git status --short` (repo at `/Users/tomendean/Documents/Default Project/fallout-rockies`).
Last commit was `876855c platformer mvp`; the rebuild is unstaged/uncommitted.
