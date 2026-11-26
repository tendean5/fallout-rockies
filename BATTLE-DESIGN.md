# Battle System — Gen-3 Pokémon-Style (Design First)

> Planning doc, not code. Companion to CONCEPT.md / BUILD.md / HANDOFF.md.
> **Scope:** the turn-based battle layer for *Fallout Rockies* — an original
> Colorado-wasteland world, not a *Pokémon* clone. Everything visual,
> mechanical, and textual here is an **original** re-imagining of the
> generation-3 (GBA) style: 16-bit-era sprite look, boxy text UI, turn-based
> combat. No Nintendo names, sprites, type formulas, or lore.

---

## 1. What this is — and what it is not

**What:** a GBA-era turn-based battle layer that the overworld drops into
(wild encounters, scripted NPC/boss encounters), with a 16-bit-style UI shell
that reads as "generation 3" at a glance — but with an original wasteland
theme.

**Not:**
- Not a *Pokémon* game. Creatures, moves, types, numbers, and text are all
  original. The target aesthetic, not the IP, is what we're replicating.
- Not a 3D battle. Generation 3 was 2D sprites on a box. Everything here is
  2D, crisp, at 320×176 logical pixels.
- Not replacing the overworld. Battles are **one event type**, not the game.
  The Hades-style die-and-return loop is untouched; battles happen inside a
  run and resume the run.
- Not a re-architecture. We keep `Main.tscn` + `Game` autoload +
  `scene_change_to()` scene-swap pattern.

**Non-goals (explicitly):** multiplayer, 3D, real-time mechanics, a full
"deck builder", custom-tile battle backgrounds beyond a small fixed set,
streaming/multi-map battle stages beyond simple tile-backed backdrops.

---

## 2. The feel we are targeting

- **Resolution:** 320×176 logical viewport (existing), nearest-neighbor,
  crisp pixels — same as the overworld.
- **Layout (generation-3 grammar, original palette):**
  ```
  ┌────────────────────────────┬───────────────┐
  │  Enemy sprite (top)        │  Enemy panel:  │
  │                            │  name, level,  │
  │  Party sprite (bottom)     │  HP bar,       │
  │                            │  type badge    │
  ├────────────────────────────┴───────────────┤
  │  Text log (left)  │ Move menu (right)      │
  │  "..."            │ Attack  Items          │
  │  >                 │ Defend  Run            │
  └───────────────────────────────────────────┘
  ```
  Close enough to the GBA grammar that it reads as "generation 3" on a
  glance, but sized to our 320×176 canvas and re-themed for the wasteland.
- **Text:** chunky line-based log, blinking `▼` cursor, 2 lines of history.
- **Feedback:** damage numbers pop over the target sprite; KO flashes and
  a fade; status ticks in the log.
- **Audio cue hooks:** one-hit blip, KO hit, heal, text-cursor tick (audio
  can come later; the design leaves seams).

*Theme decision:* re-title the generation-3 grammar over a cold, dusty
palette — high contrast, hard outlines, small type, not pastel.

---

## 3. Core data model (original)

Keep it typed and data-driven like the rest of the codebase (typed objects
+ static draw helpers), but plain-dict instances so saves round-trip.

### Species / creature
```gd
# illustrative only, not code
{
  "id": "rust_walrus",          // stable id (save key)
  "name": "Rustjaw",            // original name
  "types": ["rust"],             // 1-2 types, see §4
  "base_hp": 34, "base_atk": 28, "base_def": 22,
  "base_res": 24, "base_spd": 18,
  "wild_weight": 20,             // encounter odds (§7)
  "learn": ["rust_slam", "bite"],// move ids
  "sprite": "res://assets/sprites/creatures/rustjaw.png",
}
```
- **Party:** up to 6 slots (generation-3 grammar). Each slot:
  `{species_id, level, current_hp, status, moves:[ids], exp}`.
- **Level scaling:** simple curve; gen-3 "small numbers, big feel" energy
  without copying any stat curve. Formula sketched below — numbers to be
  tuned in M2.
- **Evolve / level-ups:** deferred to post-M2; the doc leaves the seam
  (`species_id` is just a key — an evolved form is a new `species_id` + a
  re-spec rule).

### Moves
```gd
{
  "id": "rust_slam",
  "name": "Rust Slam",
  "type": "rust",            // must match one of the type set
  "power": 40,
  "accuracy": 0.9,
  "effect": "none",          // damage | "poison" | "status:paralysis" | "heal_self"
  "effect_chance": 0.0,
  "priority": 0              // gen-3 grammar: priority moves exist
}
```
- Original type set (wasteland-flavored, original names — not Pokémon
  types): e.g. **Rust**, **Smoke**, **Spore**, **Dust**, **Leech**,
  **Wind**. Effectiveness chart is symmetric and original.

---

## 4. Combat logic (original formula, gen-3 grammar)

Aim: fast, transparent, legible. Show the numbers.

### Damage formula (original)
```
base  = power * (ATK/DEF) * stab * type_mult * level_factor
stab  = 1.5 if attacker's move type == attacker's own (1st, original rule)
type_mult: chart-driven, see §3
level_factor = 0.6 + 0.4 * (attacker_level / target_level)  // tuned in M2
crit: 8% chance, x1.5 — flat original
```
- No copying exact Nintendo math. Numbers are tunable; the doc commits to
  the **grammar** (stab, type mult, crit, level factor), not the constants.

### Status effects (original)
| Condition | Effect | Duration / rules |
|---|---|---|
| Poison | 1/8 max HP per turn (brand new, pick original severity) | ticks at end of turn, log line |
| Paralysis | 25% chance skip turn | turn skipped, 2-chance text |
| Sleep | next turn asleep (skip) | needs waking hit or switch |
| Burning | HP drain each turn (original) | max 2 turns then fades |

- KO handling: `current_hp <= 0` → slot removed from live party; the only
  recovery paths are **switch** or **heal** (both available in the menu);
  if every party slot is KO → battle lost (see §6).

### Turn order
- Sort by **priority** (move) then **SPD** (attacker's creature); tie →
  random coin-flip, logged as such.
- A move with priority > 0 acts first within its turn (gen-3 grammar).
- If both creatures act on a turn: both act; the loser takes damage first
  if the normal order puts them first — gen-3's "classic" grammar.

### Run / escape
- `Run` = a single action, succeeds when **speed check** passes
  (`SPD_wild / SPD_enemy` threshold vs. a tuned random gate), never fails
  inside the first turn if `enemy.level < attacker.level` (floor rule).
- **Refuse / switch**: failure simply burns the action.

### EXP / growth
- Kill / survive grants EXP (`base_exp * enemy_level / 2`, original).
- Level-up raises stats (original curve) and may unlock the next move.
- Party levels persist through saves (see §8).

---

## 5. Battle scene & flow (the state machine)

Battle scene replaces the current holder scene the same way `loading` does
(`scene_change_to("battle")`), and hands the result back.

```
INTRO ──▶ TURNING
   ▲            ▼
  │        CHOOSE_ACTION  ──┬──▶ ATTACK / ITEM / DEFEND / SWITCH / RUN
  │            ▲            │
  │            │            ▼
  └────────── STATUS ◀── RESOLVE_ACTION
            ▲                 │
            ├── pending ☑?    ▼
            │             POST_TURN
            │               (KO sweep, status ticks)
            │                 │
            └── (no KO) ◀────┴──▶ TURNING (next turn)

If party KO  →  LOST  → resume overworld with death-overlay path
If wild enemy KO / run →  RETURN → resume overworld with carry preserved
```

- **INTRO**: fanfare text in the log box, enemy sprite fades in.
- **CHOOSE_ACTION**: menu appears on the right; keyboard `↑ ↓ Enter` +
  mouse hover/click (same grammar as the title screen).
- **RESOLVE**: action queued, animation beats (sprite lunge/flash/damage
  number popup), log lines, then the next turn starts after a short
  settle (0.6s, tunable).
- **LOST / RETURN**: a 0.5s transition into the overworld, carrying the
  party state forward.

---

## 6. Overworld integration

- **Triggers (original)**: `wild` encounters fire by tile-scripted zones —
  water/river edges and dense-forest zones, matching the existing
  `overworld.gd` region/zone ideas. Trigger attempts once per tile enter
  (cooldown 0.75s after a successful fight — no same-tile loops).
  Fully scripted (quest/boss) encounters pass a `battle_event_id`.
- **Smoke tests**: extend `--smoke` to force a wild encounter → run one
  full turn in a headless battle → assert the battle ran and returned
  to the overworld (the existing `smoke_stage` pattern).
- **Save payload (v2):**
  - `party` (list, 0..6 slots of typed dicts)
  - `party_exp`, `party_status` (dict per slot)
  - keep `checkpoint`, `age`, `carry` intact. v1 save still loads;
    migration: if no `party`, initialize the kid's starting party.
- **Death rule (original):** party wipe = local combat loss → the run
  returns as the *normal die-and-return* — the kid dies, the carry-forward
  is preserved, **nothing new** is introduced. (Battles don't add a new
  death rule, but they share the existing overlay.)
- **Resume:** a successful fight returns to the tile the kid was heading
  into (not a different one), with a 0.75s no-retrigger cooldown.

---

## 7. Encounters & species (initial slice)

- **Wild encounters**: 3 original creatures to start —
  1. `rustjaw` (Rust) — weak, fast, low move count; the "classic" opener
  2. `silt_pup` (Dust) — the dog-like local creature; normal
  3. `smoke_wasp` (Smoke) — the sting; fast, low HP, high priority moves
- **Battle backdrop**: simple `dust` ground + a background color per
  zone (denver-grid / high-country / river); the enemy sprite is drawn
  against a flat backdrop that reads as "an overworld tile-battle".
- **Boss encounters**: not in M1–M3; deferred. The hook (`battle_event_id`)
  is already in the design so we can wire them later.

---

## 8. Visual / art direction

**Pallete & type:** original wasteland palette — rust oranges, cold blues,
hard outlines. Pixel-art sprites drawn in the same `assets/sprites/`
pipeline as the kid (PNG preload + mirrors).

- **Creature sprites**: procedural-drawn placeholders in M1
  (same `pixel_art.draw_map` approach, 8×8–12×12 grids, original
  shapes) so the battle scene ships before real art is ready.
- **Text**: same fallback font + `draw_string` as the overworld. A crisp
  UI chrome (thin border, hard corners) around the log + menu boxes.

## 9. Sound / motion seams (not built yet)

SBIUD of the existing autoload `Audio` (already wired to SFX). Leave
seams for: fanfare cue, attack hit, damage pop, heal, KO — but M1 ships
silent to keep scope tight.

---

## 10. Milestones

- **M1 — battle shell + data model** — state machine skeleton, 3 species,
  camera/backdrop, log box + menu layout, one wild encounter forced by
  smoke test. Ship via a smoke-test pass.
- **M2 — combat logic** — damage formula, type chart, status ticks, turn
  order, damage numbers. Party state + EXP/level-up. Save v2 round-trip.
- **M3 — overworld integration** — real encounters on tiles, resume,
  smoke test covers a fight, playtest.

---

## 11. Open questions to resolve before M1

1. **Creature names & shapes** — original suggestions vs. your own list.
2. **Starting party** — should the kid start with a guaranteed creature,
   or pick from 2–3 at the airport?
3. **Battle backdrop art** — placeheld colors per zone, or one shared
   backdrop in M1?
4. **Save migration** — v1 → v2 migration: auto-migrate on load, or show
   the kid a fresh party?
5. **Battle speed** — 1 action per 0.75s, 1.0s, or tap-driven?
6. **What "LOST" means** — party wipe = head-death? Resolve to existing
   checkpoint-reset, or to a revive-at-town?

---

_End of design doc. No code in M1 until you sign off on this._
