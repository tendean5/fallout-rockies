# Fallout Rockies — Build Plan

> Planning doc, not code. This is the "how we build" companion to CONCEPT.md.

## Stack (recommendation)

- **HTML5 + Canvas + JavaScript** (plain JS to start; TypeScript optional later).
  No engine, no install, no dependencies. Both of you can open the game locally
  and it works immediately — right now and on any browser.
- One page, one `<canvas>`, a fixed timestep game loop, tile rendering.
- **Browser-local persistence**, later migrations possible if the game proves
  worth the commitment.

### Why browser
- Zero install friction for a 1-player, no-account game.
- Both of you can play the same build (you can split testing: one runs the game,
  one reviews) with no shared-world server.
- Roguelike design maps cleanly: **the world is regenerated each run**, only
  carry-forward state persists (artifacts, what you know, faction attitudes).

## Save system

- localStorage, versioned (`{version, runSeed, carryForwards: {...}}`).
- On death: regenerate the world from the seed, restore the carry-forwards.
- Never store the world — only the kid, what they carry, and what they learned.
- If we migrate later (engine change, server saves), this schema, not the world,
  is the only thing to port.

## The bones (what we build first)

A thin spine to prove the loop, not the full engine:

1. **Tilemap + camera** — render a tile world, scroll to the kid.
2. **Player movement + physics** — arrow keys/WASD, simple sprite, walking and
   falling, one way to move between zones.
3. **Death/return loop** — die, carry forward, come back.
4. **HUD placeholder** — a tiny ribbon: the kid, a couple artifacts, faction
   badges.
5. **One art pipeline** — sprites, tiles, a color palette.
6. **One faction/zone placeholder** — the first real zone with one story beat.

What we deliberately do **not** build yet: combat, inventory systems, AI,
audio, dialog trees, branching runtime, saves migration, real art. Each comes
in wired to a story need, not speculative.

## The wire-in slice (first playable)

The exile scene, end to end:

- The kid falls out of the Enclave / slips into the wastes.
- One screen, one zone (start: the airport exterior or the border).
- The death/return loop fires — you die, you return, carrying the kid's first
  artifact.
- One real story beat: a line of dialogue, a note, a sign — the tone, not the
  plot.

Goal: prove the premise plays, in days, not months.

## Phasing

- **M1 — bones + slice** — the loop works and the exile scene is playable.
- **M2 — first real zone + story beats** — one fully-set zone, one faction with
  a real voice.
- **M3 — faction skeleton + map spine** — 3–4 zones connected, factions with
  visible distinctions, the ending pressure — the question of the choice.

## Art direction (recommendation, not decided)

Pixel art — the natural fit for a roguelike, and Colorado reads: dusk palette,
dark blues and oranges. Painted/illustration style is the alternative and would
shift what "sprites" means — this is a real fork, not a detail. Also to lock:
canvas resolution (probably ~960x540 with pixel-scaled 2-3x).

## Open decisions to lock before code

- Plain JS vs TypeScript
- Art direction: pixel vs painted
- Canvas resolution and world scale
- Exact checkpoint cadence for the death/return loop
- What "carry forward" means: artifacts only, or artifacts + run/death count
