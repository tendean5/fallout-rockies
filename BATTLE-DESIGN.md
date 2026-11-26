# Battle System — Gen-3 Pokémon Grammar, Fallout-Flavored (Design First)

> Planning doc, not code. Companion to CONCEPT.md / BUILD.md / HANDOFF.md.
> **Scope:** the turn-based battle layer for *Fallout Rockies* — an original
> Colorado-wasteland world. Visual grammar inspired by Generation 3
> (GBA, 2D sprites, text-box UI); mechanics inspired by Fallout
> (solo hero accumulates weapons). **No Nintendo / Bethesda names,
> sprites, formulas, or lore.**

---

## 1. What this is — and what it is not

**What:** a GBA-style turn-based battle layer the overworld drops into
(wild encounters, scripted NPC/boss encounters). Gen-3 *grammar and palette*,
Fallout *combat style*: the kid fights **alone** with weapons he picks up,
not a party of creature comrades.

**Not:**
- Not a *Pokémon* game. Every creature, move, type, number, and text line
  is original. The target is the aesthetic grammar, not the IP.
- Not 3D, not real-time. Generation 3 was 2D sprites on a box — same here.
- Not replacing the overworld. Battles are **one event type**, inside a run.
  The Hades-style die-and-return loop is untouched.
- Not replacing the overworld with a party builder. Companions (human or
  creature) may be added **later**; the design leaves the seam.

**Non-goals (explicitly):** multiplayer, 3D, off-grid battle stages,
deck-builder mechanics, combat as the core hook.

---

## 2. The feel we are targeting (locked)

```
┌────────────────────────────┬───────────────┐
│  Enemy sprite (top)        │  Enemy panel:  │
│  (per-zone backdrop)       │  name, level,  │
│                            │  HP bar, badge │
│  Kid sprite (bottom)       │                │
├────────────────────────────┴───────────────┤
│  Text log (left)    │ Attack/Items/Hold/Run│
│  "Rustjaw attacks!" │             (right)  │
│  >                  │                       │
└───────────────────────────────────────────┘
```

- 320×176 logical viewport, crisp nearest-neighbor, same pipeline as the
  overworld (`canvas_items` stretch, no antialias).
- **Per-zone backdrop palettes** (locked): Denver (rust/orange dusk),
  high-country (cold blues/snow), Platte River (teal), forest (dark green).
  Each palette feeds the battle backdrop + the ground line where the kid
  stands.
- **Text:** 2-line log + blinking `▼` cursor, 1-2 line history.
- **Feedback:** damage number popup over the target; KO fade; status
  lines in the log. **Fallout-1-feel pacing** (locked): turns resolve fast —
  no long menus, no long cinematics; text line, one action beat, next turn.
- **Audio seams:** attack hit, damage pop, heal, KO — hooks leaved; M1 ships
  silent.

*Theme:* original palette — rust, dust, cold blue; hard outlines; small
type, not pastel.

---

## 3. Core data model (locked)

### The hero (the kid) — solo combatant
```gd
# illustrative only
kid = {
  "level": 1,
  "max_hp": 40, "current_hp": 40,
  "exp": 0,
  "weapons": ["rust_pistol"],     // owned + equipped
  "active_weapon": "rust_pistol",
  "items": {"stim": 3, "medkit": 1},
}
```
- No party in M1. The `kid` dict is the **root combatant**.
- **Companions are M4+.** Roster seam: `battle.combatants` is a list; M1
  ships `[kid]` only. Future companions append to this array and get their
  own stats/sprites — the scene doesn't need a structural rework.
- Stats: HP, level, exp, weapon list, items. (Hit/shot skill: simplified —
  a single `weapon accuracy` number instead of Fallout's skill tree; the
  doc records the seam, the mechanic ships in M2.)

### Weapons (Fallout-style, original)
```gd
weapons.rust_pistol: {power: 8, accuracy: 0.85, type: "rust", name: "Rust Pistol"}
weapons.dust_axe:    {power: 11, accuracy: 0.75, type: "dust", name: "Dust Axe"}
weapons.smoke_rifle: {power: 10, accuracy: 0.80, type: "smoke", name: "Smoke Rifle"}
# TODO: more weapons to add as the kid explores — Rust, Smoke, Spore, Dust, Leech, Wind
```
- The kid carries **2–3 weapons per level bracket** as he explores, plus
  items (stims/medkits). Original-names, one type each.

### Items (Fallout-style, original)
```gd
items.stim:   {name: "Stimpack",  heal: 20}
items.medkit: {name: "Medkit",   heal: 40}
```
- No ammo in M1 (ranged weapons without ammo state to tune).

### Wild enemies (locked: use doc's suggestions)
```gd
creatures.rustjaw:   {name: "Rustjaw",   types: ["rust"],  weak: "smoke", resist: "wind",
                       max_hp: 28, power: 7, accuracy: 0.80, spd: 10, wild_weight: 3}
creatures.silt_pup:   {name: "Silt Pup", types: ["dust"],  weak: "rust",  resist: "dust",
                       max_hp: 34, power: 8, accuracy: 0.72, spd: 12, wild_weight: 3}
creatures.smoke_wasp: {name: "Smoke Wasp", types: ["smoke"], weak: "dust",  resist: "smoke",
                       max_hp: 20, power: 9, accuracy: 0.74, spd: 16, wild_weight: 2}
```
- Each enemy has: types, weakness, resist, max_hp, power, accuracy, spd,
  wild_weight. One attack per turn (M1 – per-enemy special move later).
- ("weak: X" = attacked by X does 1.5×; "resist: Y" = attacked by Y does 0.5×.
  Generator: simple 2-axis original chart.)

### Types (original set)
| type | flavor | kid weapon | enemy weakness |
|---|---|---|---|
| rust | frozen metal | Pistol | Silt Pup |
| dust | grime/sand | Axe | Rustjaw |
| smoke | fire/steam | Rifle | Smoke Wasp |
| spore | fungus (later) | — | — |
| leech | creeping bite (later) | — | — |
| wind | hard to track (later) | — | — |

---

## 4. Combat logic (original, gen-3 grammar)

### Damage formula (original, simplified)
```
hit = accuracy roll (0..1) < weapon.accuracy
if not hit: miss (log line, no damage)
base = weapon.power × level_factor
level_factor = 0.7 + 0.3 * (kid.level / enemy.level)
type_mult = type_chart(weapon.type, enemy)   // 1.5 weak, 0.5 resist, 1.0 otherwise
crit = 8% chance, x1.5
damage = floor(base × type_mult × crit_mult)
```
- **No copying Nintendo math.** Grammar: accuracy roll + stab-ish
  type_mult + crit + level factor. Constants to be tuned in M2.

### Status effects (original, small set)
| Condition | Effect |
|---|---|
| Poison (applied by Silt Pup) | 1/8 max HP per turn at end of turn, 3 turns, then fades |
| Sleep | kid *or* enemy skips next turn |
| Blinding | kid's next weapon misses (original: smoke_wasp) |
- Enemies don't gain status effects in M1 except Poison.

### Turn order (original, gen-3 grammar)
- Actor with higher SPD goes first. (kid's SPD from a base + level — M1 uses
  the kid's own SPD from weapon, not a separate stat.)
- Tie → random coin-flip, logged.
- If both actors act on a turn, both act.

### Run / escape (original)
- `Run` action: succeeds if escape roll passes (same accuracy-gate idea as
  attack, but with a lower threshold and always better vs. weaker enemies).
- Never forced — Run fails if roll fails; kid uses a turn.

### EXP / level (original)
- Killing/surviving a fight grants EXP (`base 10 + enemy.level × 2`, flat).
- Level cap: none in M1; formula raises max_hp and power slightly.
- Kid stats are **not** copied from creature rules — the kid is the only
  permanent combatant.

---

## 5. Battle scene & flow (locked)

```
INTRO ──▶ CHOOSE ──▶ RESOLVE ──▶ POST ──▶ CHOOSE (next turn) ──▶ ...
  ▲                          │                
  │                          ▼                
  │                        KO? ──▶ LOST → death → checkpoint reset
  │                          │       or RETURN → resume overworld
  └──── (wild fade-in)
```

- **INTRO**: fanfare text + enemy sprite fades in (~0.4s).
- **CHOOSE**: 4-command menu on right
  (`Attack`, `Items`, `Hold`, `Run`), keyboard + mouse.
- **RESOLVE**: sprite lunge / damage number popup / log line; then a
  0.5s beat (tunable, M1: fast), then next turn.
- **Post-turn**: status ticks (kid poison); check KO → end of battle.
- **LOST / RETURN**: 0.5s transition into the overworld, carrying the kid
  state forward. **(Locked: party wipe = kid death = existing checkpoint
  reset — not a new death rule.)**

### Behaviors
- Keyboard: `↑↓` navigate, `Enter/Space` confirm, `Escape` run/close.
- Mouse: hover/click like the title screen.

---

## 6. Overworld integration (locked)

- **Triggers (original)**: wild encounters on tile-scripted zones — river
  edges and dense forest, using the region data already in
  `world_map.gd`. Trigger attempts once per tile-enter (cooldown 0.75s
  after a successful fight, no same-tile loops). Every encounter is
  **scripted** in M1 (`battle_event_id`), no RNG-circle in v1.
- **Smoke tests**: `--smoke` extended — force a wild encounter → run one
  full turn headlessly → assert the battle ran and returned to overworld.
- **Save (v2)**: see §7.
- **Resume**: fight ends → return to the tile the kid was heading into.
- **Re-trigger cooldown**: 0.75s after a successful fight before the
  next wild encounter is eligible.

---

## 7. Save schema (v2)

```json
{
  "version": 2,
  "checkpoint": {"x": 6, "y": 38},
  "age": 13,
  "carry": {"flag": null, "artifact": "locket", "deaths": 0},
  "kid": {
    "level": 1,
    "max_hp": 40,
    "current_hp": 40,
    "exp": 0,
    "weapons": ["rust_pistol"],
    "active_weapon": "rust_pistol",
    "items": {"stim": 3, "medkit": 1}
  }
}
```

- **Migration (locked)**: auto-migrate on load — v1 saves with no `kid`
  block get the starting kid injected on first load; existing checkpoint,
  age, carry are untouched.

---

## 8. Milestones

- **M1 — battle shell (shell + data model + smoke test)** — state machine,
  kid data, 3 wild enemies, backdrops (4 zone palettes), text log, 4-command
  menu, one full turn in `--smoke`. **Ship.**
- **M2 — combat logic** — damage formula, type chart, status effects, KO
  handling, EXP/leveling, save v2 round-trip.
- **M3 — overworld integration** — real encounters on tiles, resume
  overworld, real smoke-test coverage of a full fight.

---

## 9. Decisions locked (this doc supersedes the earlier open questions)

| # | Decision |
|---|---|
| 1 | Creature set: **Rustjaw, Silt Pup, Smoke Wasp** (original names + shapes) |
| 2 | **Kid is alone**; weapons accumulate; companions (human or creature) **later** |
| 3 | **Per-zone backdrop palettes** (Denver / high-country / river / forest) in M1 |
| 4 | **Auto-migrate** v1 saves — inject starting kid, keep checkpoint/age/carry |
| 5 | **Fallout-1-feel pacing**: quick turns, no long menus, no cinematics |
| 6 | **Party wipe = kid death = existing checkpoint reset** — no new death rule |

---

_End of design doc. No code in M1 until sign-off._
