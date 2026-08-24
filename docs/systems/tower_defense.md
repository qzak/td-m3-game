# Tower Defense — As-Built Notes

Living documentation of the TD battle scene as it's actually implemented. Update this
alongside code changes so it stays a reliable reference. See
[docs/IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) for the overall design/roadmap.

## Files

| File | Responsibility |
|---|---|
| [scenes/tower_defense/td_battle.tscn](../../scenes/tower_defense/td_battle.tscn) | Main battle scene: grid, units root, HUD, step timer. Currently the project's run scene. |
| [scripts/tower_defense/battle_controller.gd](../../scripts/tower_defense/battle_controller.gd) (`TDBattleController`) | Owns the move/attack step loop, spawning, targeting, win/lose, placement mode, HUD wiring. |
| [scripts/tower_defense/grid_map.gd](../../scripts/tower_defense/grid_map.gd) (`TDGridMap`) | Draws the grid + path, hit-tests mouse clicks/hover into cells, draws the range-preview overlay. |
| [scripts/tower_defense/adventurer.gd](../../scripts/tower_defense/adventurer.gd) (`TDAdventurer`) | Per-placed-unit state: attack pool charge/regen, range check. |
| [scripts/tower_defense/enemy.gd](../../scripts/tower_defense/enemy.gd) (`TDEnemy`) | Per-enemy state: health/armour, path following, move-speed cooldown. |
| [scenes/tower_defense/adventurer_unit.tscn](../../scenes/tower_defense/adventurer_unit.tscn) / [enemy_unit.tscn](../../scenes/tower_defense/enemy_unit.tscn) | Placeholder visuals (colored square + stat label) — no art yet. |
| [data/adventurers/*.tres](../../data/adventurers/) | `AdventurerData` resource instances (see roster below). |
| [data/enemies/goblin.tres](../../data/enemies/goblin.tres), [large_goblin.tres](../../data/enemies/large_goblin.tres) | Enemy types (see roster below). |
| [data/waves/day_1.tres](../../data/waves/day_1.tres) + `day1_wave*.tres` | `DayData`/`WaveData` resources defining the current Day's wave sequence (see below). |

## Grid & Path

- 24x16 grid, 32px cells, `TDGridMap` positioned at `(80, 80)` in the scene.
- The castle doors always sit at the top-middle cell (`Vector2i(grid_width / 2, 0)`). The enemy
  path is a gentle, single-tile-wide zigzag from a bottom/side entry point up to those doors —
  built in `TDGridMap._build_path()` as a handful of axis-aligned waypoints (currently: bottom-right
  corner → up → left → up → left → up to the door), walked segment by segment into the ordered
  `path_cells` array. `path_cell_set` is kept alongside for O(1) membership checks (drawing,
  buildability). The castle-door cell is drawn with a distinct dark/gold marker.
- All non-path cells are buildable; `occupied_cells` (keyed by `Vector2i`) tracks which ones
  already have an adventurer.
- **Important gotcha:** the `HUD` `Control` covers the whole viewport, so its `mouse_filter`
  must stay `IGNORE` (`2`) or it silently swallows clicks/hover meant for the grid. Buttons
  underneath keep their own `STOP` filter and still work normally.

## Battle Loop

`TDBattleController` runs a single repeating `Timer` (`step_interval`, default `0.5s`) that
alternates:

- **Move step** (`_move_step`): resolves enemy movement first via `_resolve_enemy_movement()`
  (so a freshly spawned enemy doesn't jump on its own spawn step), deals 1 castle-HP damage per
  enemy that reaches the door, processes the wave spawn queue (`_process_spawn_queue`), then
  adds `attack_regen` to every placed adventurer's attack pool.
- **Attack step** (`_attack_step`): each adventurer whose pool is `>= attack_pool` picks the
  valid in-range enemy furthest along the path (closest to the castle) and attacks, looping so
  a large regen can trigger multiple attacks in one step. Damage is
  `randi_range(damage_min, damage_max) - enemy.armour` (floored at 0).

Win condition: no enemies left alive and no wave left to call. Loss condition: castle HP
hits 0. Both stop the timer and set `battle_over`.

The timer isn't running continuously for the whole Day, though — see below.

## Enemy Movement & Blocking

- Only one enemy may occupy a given path cell at a time. `_resolve_enemy_movement()` sorts all
  alive enemies by `path_index` descending (closest to the castle first) and resolves them in
  that order: each enemy calls `peek_target_cell()` to see where it would move, and is blocked
  (`TDEnemy.apply_move(false)`) if another enemy already claimed that cell earlier in this same
  step. Blocked enemies simply stay put and try again next move step — this is what lets a slow
  or stationary enemy jam up everyone behind it on the single-tile-wide path.
- **Move speed** is controlled by two `EnemyData` fields: `move_steps_per_turn` (cells covered
  in one move, for fast enemies) and `move_period` (how many move-steps between moves, for slow
  enemies — `2` means it only moves on every other move step). `TDEnemy.move_cooldown` tracks
  this: `apply_move()` ticks it down and skips movement entirely while it's `> 0`, regardless of
  blocking.

## Enemy Roster (current)

| Name | id | Health | Armour | Move Speed |
|---|---|---|---|---|
| Goblin | `goblin` | 25 | 0 | 1 cell every move step |
| Large Goblin | `large_goblin` | 60 | 2 | 1 cell every **other** move step, and blocks the path behind it |

## Day / Wave Structure

- `TDBattleController.day_data` (a `DayData` resource) replaces the old hardcoded single-wave
  fields. `DayData` holds `day_index`, an ordered `waves: Array[WaveData]`, and a
  `difficulty_scalar` applied as an enemy health multiplier (`TDEnemy.setup(data, grid,
  health_multiplier)`).
- Each `WaveData` is just `enemy_data: EnemyData` + `count` + `spawn_delay_steps` — no id/string
  lookup, it references the `EnemyData` resource directly (same pattern as adventurers).
- **Waves are player-triggered, one at a time, via a single button that changes meaning
  depending on state** (`start_button` / `_update_start_button_label()`):
  - **No wave currently spawning** (`wave_active == false`): button reads `Call Wave N` — a
    direct action. Pressing it calls `_begin_wave()`, which starts that wave's enemies spawning
    immediately (and, on the very first press, locks adventurer placement and fires
    `EventBus.day_started`).
  - **A wave is actively spawning** (`wave_active == true`): button becomes a toggle, reading
    `Auto-Call Next Wave` / `Cancel Auto-Call`. It flips `auto_call_next` and does *not* start
    anything immediately — waves never overlap. Once the active wave finishes spawning
    (`_process_spawn_queue()`), if `auto_call_next` was left on, `_begin_wave()` runs
    immediately for the next wave; otherwise the button reverts to `Call Wave N` and waits for
    a manual press.
- **The step timer pauses whenever the field is clear and no wave is actively spawning**
  (`_check_end_conditions()`): `step_timer.stop()` and the result label prompts the player to
  call the next wave. This is deliberate — it stops adventurers from passively racking up
  attack points between waves. `_begin_wave()` resumes the timer (and resets `is_move_phase` to
  `true` so the next tick is a clean move step) if it was stopped.
- [data/waves/day_1.tres](../../data/waves/day_1.tres) is the current sample: goblins in
  waves 1-3 (5 @ 2-step spacing, 8 @ 2-step, 10 @ 1-step), then a 4th wave of 3 Large Goblins
  (4-step spacing) to demonstrate the path-blocking behavior. `difficulty_scalar = 1.0`.
- The HUD's `WaveLabel` shows `Day X — Wave Y/Z — Enemies left to spawn: N`, driven by
  `current_wave_index` and `total_enemies_remaining_to_spawn`.
- `EventBus.day_started/day_won/day_lost` now emit `day_data.day_index` instead of a hardcoded 0.
- [data/waves/day_2.tres](../../data/waves/day_2.tres) is a harder second Day (`difficulty_scalar =
  1.3`, `completion_reward = 250`): goblins, then Goblin Riders, then Goblin Shamans, then Large
  Goblins, then a fast 8-strong Goblin Rider finale wave (1-step spacing).

## Day Selection

- The Castle no longer hardcodes "Start Day 1" — `CastleController._build_day_list()` builds one
  "Start Day N" button per day from `1` to `GameState.total_known_days()` (currently `2`), disabling
  and appending `" (Locked)"` to any day beyond `GameState.unlocked_day_index`.
- Pressing an unlocked day button sets `GameState.selected_day_index = N` then changes to
  `td_battle.tscn`. `TDBattleController._ready()` checks `GameState.selected_day_index` before
  summing up wave counts: if it's `> 0` and `res://data/waves/day_%d.tres` loads successfully, that
  resource replaces the scene's exported `day_data`; otherwise the exported `day_data` (still
  Day 1 in the `.tscn`) is used as-is, which keeps `td_battle.tscn` directly runnable/testable
  without going through the Castle.
- `GameState.unlocked_day_index` starts at `1` (Day 1 always available) and is bumped to
  `day_index + 1` whenever `EventBus.day_won` fires, via a listener registered in
  `GameState._ready()` — so clearing Day 1 unlocks Day 2, etc. There's no Day-replay restriction;
  clearing a Day again just re-fires the same unlock logic (`maxi`, so it never regresses).
- `GameState.total_known_days()` is currently a hardcoded `2` — it'll need to become dynamic (e.g.
  scanning `data/waves/day_*.tres`) once more Days are authored.

## Placement & Range Preview

- Before the first wave is called, clicking one of the dynamically-built **Place X** buttons (one
  per adventurer in `GameState.active_roster_ids`, chosen in the Castle's Quarters — see
  [docs/systems/castle.md](castle.md)) sets `selected_adventurer_data` and updates the
  `SelectedLabel` HUD text.
- While a unit type is selected, moving the mouse over the grid emits `TDGridMap.cell_hovered`,
  which the controller uses to call `grid.set_range_preview(cell, range_min, range_max)`. The
  grid highlights every cell within Manhattan distance `[range_min, range_max]` of the
  hovered cell with a translucent red overlay and a bold red outline, and tints the hovered
  cell itself green — this is the "what would this unit be able to hit from here" preview.
- Clicking a buildable cell instantiates `adventurer_unit.tscn`, calls `setup()`, and marks the
  cell occupied. Each adventurer represents a unique recruited individual, so only one copy of
  a given adventurer (`AdventurerData.id`) can be placed at a time — `TDBattleController` tracks
  `placed_adventurer_ids` and disables that unit's placement button once it's on the field.
  There's still no overall roster/slot cap yet (that comes with the Castle's Quarters system).

## Adventurer Roster (current)

| Name | id | Type | Range | Damage | Attack Pool / Regen | Recruit Cost |
|---|---|---|---|---|---|---|
| The Swordsman | `swordsman` | Physical melee | 1–1 | 3–6 | 100 / 40 | 100 (starting) |
| The Archer | `archer` | Physical ranged | 1–4 | 2–4 | 80 / 45 | 100 (starting) |
| The Mage | `mage` | Magic | 4–5 | 4–8 | 120 / 30 | 100 (starting) |
| The Berserker | `berserker` | Physical melee | 1–1 | 8–14 | 140 / 20 | 250 (Tavern) |

Range is Manhattan distance (`|dx| + |dy|`, diamond-shaped) from the adventurer's cell to the
enemy's current path cell — melee units can only hit true neighbors, the mage is long-range-only
and can't hit anything adjacent to it. The Berserker hits hardest but has the slowest charge
(lowest `attack_regen`) of any adventurer. See [docs/systems/castle.md](castle.md) for how the
roster is recruited (Tavern) and selected (Quarters) before a battle.

## Mage Spellcasting

- `AdventurerData.spell_ids` (only meaningful for `type == MAGIC`) references `SpellData` resources
  at `res://data/adventurers/spells/<id>.tres` (`SpellData`: `id`, `display_name`, `is_aoe: bool`,
  `damage_multiplier: float`). The Mage's only spell today is `fireball` (`is_aoe = true`,
  `damage_multiplier = 0.6`).
- In `_attack_step()`, a magic adventurer with a non-empty `spell_ids` whose first spell has
  `is_aoe = true` hits **every** enemy `_find_targets_in_range()` finds in one go instead of
  picking a single target via `_find_target()` — each hit rolls `damage_min..damage_max` normally
  and then multiplies by `damage_multiplier` (lower than 1.0 to offset hitting multiple enemies at
  once). The attack pool is still only consumed once per attack tick, same as a single-target hit.
  Kills are collected during the AOE sweep and removed/bountied/freed afterward (not mid-iteration)
  to avoid mutating the `enemies` array while scanning it.
- Non-magic adventurers, and any magic adventurer without an AOE spell configured, are completely
  unaffected — they keep using the original single-target `_find_target()` path. Towers also use
  the single-target path (they have no `spell_ids`).
- Only one spell per adventurer is supported today (`spell_ids[0]`) — there's no spell-selection UI
  or spell-switching mid-battle yet.

## Equipment Bonuses

- Items crafted at the Weapon/Armour Smith and equipped via the Armoury (see
  [docs/systems/castle.md](castle.md#armoury)) apply their stat bonuses the moment a battle's
  placement buttons are built, not when they're equipped — `TDBattleController._build_placement_buttons()`
  looks up each roster `def_id`'s `GameState.owned_adventurers` entry, resolves its
  `equipped.weapon`/`equipped.armour` instance ids through `GameState.owned_items` to their
  `ItemData` defs, sums `damage_bonus`/`range_bonus`/`attack_pool_bonus`/`attack_regen_bonus`
  across whichever are equipped, and applies them to a `def.duplicate()` copy of the base
  `AdventurerData` (`damage_min`/`damage_max` both get `damage_bonus`, `range_max` gets
  `range_bonus` — `range_min` is untouched, so bonuses only extend reach rather than shrink it —
  and `attack_pool`/`attack_regen` get their respective bonuses). That boosted copy, not the raw
  `.tres` data, is what actually gets placed on the grid.
- Re-equipping/unequipping items mid-Castle-visit is picked up the next time `_build_placement_buttons()`
  runs (i.e. the next time `td_battle.tscn` loads) — there's no need to re-place a unit for the
  Castle-side change to take effect, since placement buttons are only ever built once per battle.
- `_spawn_towers()`'s manually-constructed `AdventurerData.new()` for the Towers is unrelated to
  this — Towers have no equipment slots.

## Gold Economy

- `EnemyData.bounty` (default `5`, tuned up for tougher types — Large Goblin `12`, Goblin
  Shaman/Rider `10`) is awarded via `GameState.add_currency()` the instant an enemy dies in
  `_attack_step()`. Enemies that reach the castle door instead (no kill) grant nothing.
- `DayData.completion_reward` (`150` on `day_1.tres`) is awarded once, on a full Day clear, right
  before `EventBus.day_won` fires.
- The HUD's `GoldLabel` mirrors `GameState.currency` and updates every `_update_hud()` call so
  gold gained from kills/clears is visible mid-battle, not just back in the Castle.
- `GameState.currency` starts at `100` for a new save — enough to recruit the cheaper adventurers
  outright, but a full Day clear (or several kills) is needed to afford the Berserker (`250`).

## Known Limitations / Next Up

- Mage only has one hardcoded AOE spell (Fireball) with no selection UI or alternate spells yet —
  see [Mage Spellcasting](#mage-spellcasting).
- No new placements allowed between waves once the day has started (only before the first
  wave) — might be worth revisiting since real breathing room exists between waves now.
- Only Days 1–2 exist and `GameState.total_known_days()` is hardcoded — no dynamic Day discovery,
  and no further difficulty curve beyond Day 2 yet.

