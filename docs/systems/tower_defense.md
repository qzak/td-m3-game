# Tower Defense — As-Built Notes

Living documentation of the TD battle scene as it's actually implemented. Update this
alongside code changes so it stays a reliable reference. See
[docs/IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) for the overall design/roadmap.

## Files

| File | Responsibility |
|---|---|
| [scenes/tower_defense/td_battle.tscn](../../scenes/tower_defense/td_battle.tscn) | Main battle scene: grid, units root, HUD, step timer. Currently the project's run scene. |
| [scripts/tower_defense/battle_controller.gd](../../scripts/tower_defense/battle_controller.gd) (`TDBattleController`) | Owns the move/attack step loop, spawning, targeting, win/lose, placement mode, HUD wiring. |
| [scripts/tower_defense/grid_map.gd](../../scripts/tower_defense/grid_map.gd) (`TDGridMap`) | Draws the grid + path, hit-tests mouse/touch input into cells (tap + drag hover), and draws the range-preview overlay. |
| [scripts/tower_defense/adventurer.gd](../../scripts/tower_defense/adventurer.gd) (`TDAdventurer`) | Per-placed-unit state: attack pool charge/regen, range check. |
| [scripts/tower_defense/enemy.gd](../../scripts/tower_defense/enemy.gd) (`TDEnemy`) | Per-enemy state: health/armour, path following, move-speed cooldown. |
| [data/tower_defense/status_effect_profile.gd](../../data/tower_defense/status_effect_profile.gd) + [data/tower_defense/status_profiles/*.tres](../../data/tower_defense/status_profiles/) | Data-driven on-hit status effect profile used by adventurers/spells (slow, armour break, anti-swarm). |
| [scenes/tower_defense/adventurer_unit.tscn](../../scenes/tower_defense/adventurer_unit.tscn) / [enemy_unit.tscn](../../scenes/tower_defense/enemy_unit.tscn) | Placeholder visuals (colored square + compact combat bars + status label) — no final art yet. |
| [scripts/ui/world_stat_bar.gd](../../scripts/ui/world_stat_bar.gd) + [scripts/ui/adventurer_action_meter.gd](../../scripts/ui/adventurer_action_meter.gd) + [scripts/ui/unit_info_card.gd](../../scripts/ui/unit_info_card.gd) | Reusable world-overlay bars and hover/tap unit info card used by TD combat units. |
| [scenes/ui/top_resource_bar.tscn](../../scenes/ui/top_resource_bar.tscn) / [scripts/ui/top_resource_bar.gd](../../scripts/ui/top_resource_bar.gd) (`TopResourceBar`) | Shared full-width resource strip with placeholder icon swatches, context filtering, and live `EventBus` updates. |
| [data/adventurers/*.tres](../../data/adventurers/) + [data/adventurers/spells/*.tres](../../data/adventurers/spells/) | `AdventurerData` and `SpellData` resource instances (see rosters below). |
| [data/enemies/*.tres](../../data/enemies/) | Enemy types (see roster below). |
| [data/waves/day_1.tres](../../data/waves/day_1.tres) + `day*_wave*.tres` | `DayData`/`WaveData` resources defining each day's wave sequence (see below). |

## Grid & Path

- 24x16 grid with runtime-sized cells; `TDBattleController` now computes `TDGridMap` cell size and
  origin from the current viewport + safe-area insets, then keeps `UnitsRoot` aligned to that same
  origin.
- The castle doors always sit at the top-middle cell (`Vector2i(grid_width / 2, 0)`).
- Enemy routes are now day-specific: `DayData.path_waypoints` (stored in `data/waves/day_1.tres`
  through `day_5.tres`) defines each day's hardcoded, axis-aligned waypoint chain. `TDGridMap`
  expands those waypoints into ordered `path_cells`; `path_cell_set` is kept alongside for O(1)
  membership checks (drawing/buildability). Missing or invalid waypoint data falls back to the
  legacy default route.
- The castle-door cell is drawn with a distinct dark/gold marker.
- `TDGridMap`'s draw pass now avoids per-cell outline overdraw by drawing shared grid lines once,
  and range preview now caches only the in-range cells instead of scanning the full grid every hover
  update. Visual behavior is unchanged; this trims mobile draw/GPU work during placement preview.
- All non-path cells are buildable; `occupied_cells` (keyed by `Vector2i`) tracks which ones
  already have an adventurer.
- **Important gotcha:** the `HUD` `Control` covers the whole viewport, so its `mouse_filter`
  must stay `IGNORE` (`2`) or it silently swallows clicks/hover/touch-drag meant for the grid. Buttons
  underneath keep their own `STOP` filter and still work normally.
- Resource display is now split by signal:
  - shared `TopResourceBar` in battle context carries tactical chips (`Wave`, `Upcoming`, `Drops`)
    plus compact economy chips (`Volatile Core`, `Coins`),
  - TD HUD keeps only battle-state/interaction context (`Castle HP`, wave state, selection, results).
- TD HUD labels are now container-driven (`SafeArea/Layout/StatusColumn`) and safe-area-aware
  instead of fixed offsets; they stay anchored under the shared top bar across viewport sizes.
- Project display now uses canonical cross-platform stretch settings
  (`window/stretch/mode="canvas_items"` + `window/stretch/aspect="expand"`), so TD keeps its authored
  1280x720 composition while taller displays gain extra vertical space.

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
  `randi_range(damage_min, damage_max) * spell_multiplier * anti_swarm_multiplier`, then reduced by
  enemy effective armour in `TDEnemy.take_damage()` (floored at 0).
  Attack visuals fire per hit (melee swing or ranged projectile/impact), and kills are removed
  from simulation immediately before their death tween finishes on-screen. Kill rewards now include:
  bounty gold, optional enemy material drops (`EnemyData.drop_material_id` + `drop_amount`), and
  progression rewards (Day 3 Elder Wyrm grants the barrier trinket when that gate is active).

Win condition: no enemies left alive and no wave left to call. Loss condition: castle HP
hits 0. Both stop the timer and set `battle_over`.

The timer isn't running continuously for the whole Day, though — see below.

Players can change simulation pacing with HUD speed controls (`1x`, `2x`, `3x`). This only changes
the TD battle step timer cadence (`StepTimer.wait_time`) and does not affect Castle or Mine scenes.

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
- Enemy traversal uses a short hop presentation (`HOP_DURATION = 0.22`, `HOP_HEIGHT = 10`):
  movement tweens through an elevated midpoint while the body briefly squash-stretches, but
  path/blocking logic still resolves from discrete path cells.
- `TDEnemy` now also tracks temporary status state (slow + armour break). Durations tick once per
  move step (after movement resolution), so attack-applied effects influence upcoming movement and
  later hits without changing targeting order.

## Enemy Roster (current)

| Name | id | Health | Armour | Move Speed |
|---|---|---|---|---|
| Whelp | `whelp` | 25 | 0 | 1 cell every move step |
| Wyrmling | `wyrmling` | 20 | 0 | 1 cell every move step (plus occasional double-move burst) |
| Hatchling Mystic | `hatchling_mystic` | 17 | 1 | 1 cell every move step (stuns nearby adventurers) |
| Drake Warlock | `drake_warlock` | 30 | 2 | 1 cell every **other** move step (longer-range stun support) |
| Young Drake | `young_drake` | 60 | 3 | 1 cell every **other** move step, blocks the path behind it, and drops Volatile Core |
| War Drake | `war_drake` | 85 | 5 | 1 cell every **other** move step, heavy-armour blocker |
| Elder Wyrm | `elder_wyrm` | 180 | 7 | 1 cell every **other** move step, Day 3 boss gate target |

## Day / Wave Structure

- `TDBattleController.day_data` (a `DayData` resource) replaces the old hardcoded single-wave
  fields. `DayData` holds `day_index`, an ordered `waves: Array[WaveData]`, `path_waypoints`, and a
  `difficulty_scalar` applied as an enemy health multiplier (`TDEnemy.setup(data, grid,
  health_multiplier)`).
- Each `WaveData` is just `enemy_data: EnemyData` + `count` + `spawn_delay_steps` — no id/string
  lookup, it references the `EnemyData` resource directly (same pattern as adventurers).
- **Waves are player-triggered, one at a time, with split controls for clarity**:
  - `Call Wave N` (primary button) always means "start the next wave now" and is disabled while
    a wave is already spawning.
  - `Auto-Call: ON/OFF` (secondary toggle) arms/disarms automatic calling of the next wave once
    the current one finishes spawning.
  - This removes the old single-button mode-switch ambiguity while keeping the same pacing logic
    (`auto_call_next` still controls automatic chaining, waves never overlap).
- **The step timer pauses whenever the field is clear and no wave is actively spawning**
  (`_check_end_conditions()`): `step_timer.stop()` and the result label prompts the player to
  call the next wave. This is deliberate — it stops adventurers from passively racking up
  attack points between waves. `_begin_wave()` resumes the timer (and resets `is_move_phase` to
  `true` so the next tick is a clean move step) if it was stopped.
- [data/waves/day_1.tres](../../data/waves/day_1.tres) is the current sample: whelps in
  waves 1-3 (5 @ 2-step spacing, 8 @ 2-step, 10 @ 1-step), then a 4th wave of 3 Young Drakes
  (4-step spacing) to demonstrate the path-blocking behavior. `difficulty_scalar = 1.0`.
- Tactical preview now lives in top-bar battle chips:
  - `Wave` chip: `Day X • Wave Y/Z • Spawn N`
  - `Upcoming` chip: grouped enemy type/count summary from remaining wave data, including partially
    spawned current-wave remainder.
  - `Drops` chip: projected remaining drops (`drop_material_id`/`drop_amount`) with projected
    coin bounty (`+Nc`) from remaining kills.
  - `WaveStateLabel` remains on the side HUD for explicit phase/state (`Prep`, `Spawning wave N`,
    `Breather`, `Final wave cleared`).
- `EventBus.day_started/day_won/day_lost` now emit `day_data.day_index` instead of a hardcoded 0.
- [data/waves/day_2.tres](../../data/waves/day_2.tres) is a harder second Day (`difficulty_scalar =
  1.3`, `completion_reward = 200`): whelps, then Wyrmlings, then Drake Warlocks, then Young
  Drakes, then a fast 8-strong Wyrmling finale wave (1-step spacing).
- [data/waves/day_3.tres](../../data/waves/day_3.tres) is a third Day (`difficulty_scalar = 1.6`,
  `completion_reward = 210`) with six waves on a rising curve:
  Wyrmlings → Young Drakes → War Drakes → a tight 10-strong Wyrmling swarm
  (1-step spacing) → Hatchling Mystics → more Mystics.
- [data/waves/day_4.tres](../../data/waves/day_4.tres) pushes pacing further (`difficulty_scalar = 1.9`,
  `completion_reward = 280`) with seven waves that alternate tempo and control pressure:
  Whelps → Wyrmlings → Drake Warlocks → Young Drakes (slower breather) → a fast
  Hatchling Mystic surge → heavier Wyrmling swarm → War Drake finale.
- [data/waves/day_5.tres](../../data/waves/day_5.tres) is the current peak (`difficulty_scalar = 2.25`,
  `completion_reward = 360`) with eight waves escalating through Wyrmlings/Drake Warlocks/Young Drakes,
  then sustained Mystic/War Drake pressure into a dense Wyrmling spike and a heavy War Drake
  close.

## Day Selection

- The Castle no longer hardcodes "Start Day 1" — `CastleController._build_day_list()` builds one
  "Start Day N" button per day from `1` to `GameState.total_known_days()`, disabling
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
- `GameState.total_known_days()` is now **dynamic**: it scans `res://data/waves/` for files matching
  `day_<n>.tres` (via a `RegEx`, tolerant of a trailing `.remap` in exported builds) and returns the
  highest *contiguous* `n` starting at `1` (stopping at the first gap; falls back to `1` if none are
  found). The result is cached in `_total_known_days_cache` so the disk scan only happens once.
  Authoring a new `day_<n>.tres` (with its waves) is therefore all it takes to add a Day — no code
  change. Currently Days 1–5 exist, so it returns `5`.

## Placement, Reinforcement & Range Preview

- Placement/repositioning is gated by a `placement_open` flag (replacing the old
  `battle_started`-only gate). It is open **before the first wave** and re-opens during every
  **between-wave breather** (`_check_end_conditions()`'s "Wave cleared" branch, when the field is
  clear, no wave is spawning, and more waves remain). It is closed while a wave is spawning, while
  enemies are on the field, and once the Day ends. `_begin_wave()` calls `_close_placement()` (which
  disables all placement controls, clears any selection/preview, and returns an in-progress
  reposition to its origin); the breather branch calls `_open_placement()` (which re-enables the
  Place buttons/spell pickers only for roster members **not already placed**).
- Before/between waves, clicking one of the dynamically-built **Place X** buttons (one per
  adventurer in `GameState.active_roster_ids`, chosen in the Castle's Quarters — see
  [docs/systems/castle.md](castle.md)) sets `selected_adventurer_data` and updates the
  `SelectedLabel` HUD text.
- While a unit type is selected, moving the pointer over the grid emits `TDGridMap.cell_hovered`
  (`InputEventMouseMotion` on desktop, `InputEventScreenDrag` for touch), which the controller
  uses to call `grid.set_range_preview(cell, range_min, range_max)`. The grid highlights every
  cell within Manhattan distance `[range_min, range_max]` of the hovered cell with a translucent
  red overlay and a bold red outline, and tints the hovered cell itself green — this is the
  "what would this unit be able to hit from here" preview.
- Clicking a buildable cell instantiates `adventurer_unit.tscn`, calls `setup()`, and marks the
  cell occupied. Each adventurer represents a unique recruited individual, so only one copy of
  a given adventurer (`AdventurerData.id`) can be placed at a time — `TDBattleController` tracks
  `placed_adventurer_ids` and disables that unit's placement button once it's on the field.
- **Reinforcements:** because the window re-opens between waves, a reserve roster member that
  wasn't deployed earlier can be placed during any breather — the Place buttons for un-placed units
  are re-enabled by `_open_placement()`.
- **Repositioning:** while `placement_open` and nothing is selected for placement, clicking an
  occupied cell that holds one of the player's placed adventurers "picks it up" —
  `grid.occupied_cells` frees that cell, the unit becomes `picked_up_adventurer`, and the range
  preview follows the cursor. The next click on a buildable cell drops it there via
  `TDAdventurer.move_to()` (which preserves attack-pool/stun charge — it is not a fresh `setup()`);
  clicking the unit's own origin cell drops it back unchanged (a natural cancel). Towers live in
  `reserved_cells` (never `occupied_cells`), so they are never pickable, and repositioning is free.

## Adventurer Roster (current)

| Name | id | Type | Range | Damage | Attack Pool / Regen | Recruit Cost |
|---|---|---|---|---|---|---|
| The Swordsman | `swordsman` | Physical melee | 1–1 | 3–6 | 100 / 40 | 100 (starting) |
| The Archer | `archer` | Physical ranged | 1–4 | 2–4 | 80 / 45 | 100 (starting) |
| The Mage | `mage` | Magic | 4–5 | 4–8 | 120 / 30 | 100 (starting) |
| The Berserker | `berserker` | Physical melee | 1–1 | 8–14 | 140 / 20 | 250 (Tavern) |
| The Pikeman | `pikeman` | Physical melee | 1–2 | 5–9 | 110 / 35 | 180 (Tavern) |
| The Druid | `druid` | Magic | 3–5 | 3–6 | 110 / 35 | 220 (Tavern) |

Range is Manhattan distance (`|dx| + |dy|`, diamond-shaped) from the adventurer's cell to the
enemy's current path cell — melee units can only hit true neighbors unless they have an extended
`range_max` (like Pikeman), while mage/druid are long-range-only and can't hit adjacent targets.
The Berserker still has the slowest charge (lowest `attack_regen`) among recruitables. See
[docs/systems/castle.md](castle.md) for how the roster is recruited (Tavern) and selected
(Quarters) before a battle.

## Combat Unit UI (bars + info cards)

- Floating combat numbers were replaced by compact bars:
  - **Enemies:** red rounded HP bar only (no numeric fallback).
  - **Adventurers:** top HP bar + two-part action readiness display.
- Adventurer action readiness now has:
  1. a bottom fill bar for progress toward the next full action,
  2. pip rows above it for stored full actions (empty/full states shown together).
- Action storage is capped per adventurer by data:
  - `max_stored_actions = attack_pool * action_storage_multiplier`
  - `action_storage_multiplier` lives in `AdventurerData` and each `data/adventurers/*.tres`
    resource (Berserker currently set to `10`).
- Hover/tap inspection:
  - Desktop hover over an adventurer opens an info card near cursor and shows that unit's range.
  - Click/tap pins an adventurer or enemy card; click/tap empty space closes it.
  - Tap/click pick radii are now larger for touch than mouse, so tap-to-pin reliably substitutes
    for hover on mobile/touch devices.
  - Placement/reposition controls keep priority: cards are disabled while placement is open.
 - Touch ergonomics: battle control buttons (`Call Wave`, `Auto-Call`, speed controls, `Return to Castle`,
   placement buttons, and spell pickers) enforce a larger minimum height on touch-capable devices.

## Combat Animation Details

- **Melee (`PHYSICAL_MELEE`)**: attacker performs a quick rotation jab plus a small body squash,
  then spawns a short orange impact flash at the target.
- **Ranged (including MAGIC and towers)**: a yellow projectile polygon travels attacker→target,
  then spawns a gold impact flash on contact.
- **Enemy death lifecycle**: `play_death_animation()` hides the HP label, runs a squash/tilt/fade
  tween (~0.2s), then `queue_free`s. The enemy is already removed from the `enemies` array when
  this starts, so it no longer blocks movement or receives targeting.

## Magic Spellcasting

- `AdventurerData.spell_ids` (only meaningful for `type == MAGIC`) references `SpellData` resources
  at `res://data/adventurers/spells/<id>.tres` (`SpellData`: `id`, `display_name`, `is_aoe: bool`,
  `damage_multiplier: float`).
  - Mage spells: `fireball` (`is_aoe = true`, `damage_multiplier = 0.6`) and `arcane_bolt`
    (`is_aoe = false`, `damage_multiplier = 1.6`).
  - Druid spells: `thorn_nova` (`is_aoe = true`, `damage_multiplier = 0.8`) and `frost_sigil`
    (`is_aoe = false`, `damage_multiplier = 1.3`).
- **Spell selection UI:** for any roster entry that is `MAGIC`-type with two or more spells,
  `_build_placement_buttons()` calls `_build_spell_picker()`, which adds an `OptionButton` next to
  that unit's Place button listing each spell's `display_name`. The choice is stored in
  `selected_spell_for` (def id → spell id, defaulting to the first spell) and passed into the unit's
  `setup(..., chosen_spell)` when it's placed; the picker is disabled once the unit is deployed and
  re-enabled between waves only while the unit is still un-placed. The spell is chosen
  pre-placement — there's no mid-battle spell-switching on an already-placed unit.
- Each placed `TDAdventurer` stores its `selected_spell_id` (falling back to `spell_ids[0]` when
  none was passed). In `_attack_step()`, `_resolve_spell()` loads that unit's selected spell (or
  `null` for non-magic units / units with no spells), and its `damage_multiplier` is now applied in
  **both** attack paths:
  - **AOE spell** (`is_aoe = true`): the adventurer hits **every** enemy `_find_targets_in_range()`
    finds in one go — each hit rolls `damage_min..damage_max` and multiplies by the spell's
    multiplier. Kills are collected during the sweep and removed/bountied/freed afterward (not
    mid-iteration) to avoid mutating the `enemies` array while scanning it.
  - **Single-target spell** (or a non-magic unit, where the multiplier is `1.0`): the adventurer
    picks one target via `_find_target()` and its damage is multiplied by the resolved multiplier
    (so `arcane_bolt` deals `1.6×`, while a plain physical attacker is unchanged at `1.0×`).
  The attack pool is still only consumed once per attack tick in either path.
- Towers use the single-target path (they have no `spell_ids`, so `_resolve_spell()` returns `null`
  and the multiplier is `1.0`).

## Status Effects Foundation

- `StatusEffectProfile` is a new data resource (`data/tower_defense/status_effect_profile.gd`) with
  three independent knobs:
  - **Slow:** `slow_duration_steps`, `slow_move_period_bonus` (temporarily increases effective
    `move_period`, so enemies act less often).
  - **Armour Break:** `armour_break_duration_steps`, `armour_break_amount` (temporarily reduces
    effective armour used by `TDEnemy.take_damage()`).
  - **Anti-Swarm:** `anti_swarm_radius`, `anti_swarm_min_enemies`, `anti_swarm_damage_multiplier`
    (bonus damage when the target is inside a local cluster).
- Profiles are optional and data-driven on both `AdventurerData` and `SpellData`:
  - `AdventurerData.status_effect_profile` applies to that unit's attacks by default.
  - `SpellData.status_effect_profile` adds spell-specific effects for magic attacks.
  - During hit resolution, controller collects both profiles (if present), rolls damage, applies
    anti-swarm multipliers, then applies slow/armour-break on surviving targets.
- Current status-content wiring (broader tactical spread):
  - **Adventurer baselines:** Archer uses `archer_slow`, Berserker uses `berserker_armour_break`,
    and Pikeman uses `pikeman_anti_swarm`.
  - **Spell overlays:** Arcane Bolt uses `arcane_armour_break`; Fireball uses
    `fireball_anti_swarm`; Frost Sigil uses `frost_sigil_slow`; Thorn Nova uses
    `thorn_nova_anti_swarm` (cluster threshold tuned down to 3 nearby enemies).
  - **Enemy tuning to exercise statuses:** shaman/hexer/large/brute armour values were nudged up
    (with a slight brute/shaman HP trim) so slow, armour-break, and anti-swarm each have clearer
    target archetypes across Day 1–3 waves.
- **In-combat readability (lightweight pass):**
  - `enemy_unit.tscn` now includes a compact `StatusLabel` above HP that only appears while
    effects are active.
  - Slow and armour-break durations are shown as short codes with step expiry timing:
    `S#` (slow steps left), `B#` (armour-break steps left), e.g. `S2 B1`.
  - Enemy body tint shifts while effects are active (cool tint for slow, warm tint for break,
    mixed tint for both) and returns to normal when effects expire.
  - When anti-swarm bonus damage actually triggers (`multiplier > 1.0`), the hit target shows
    a short `SWARM xN.NN` floating cue plus a brief body pulse; no persistent icon is added.

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

- `EnemyData.bounty` (default `5`, tuned up for tougher types — Wyrmling `10`,
  Hatchling Mystic `8`, Young Drake `10`, Drake Warlock `12`, War Drake `16`) is awarded via
  `GameState.add_currency()` the instant an enemy dies in
  `_attack_step()`. Enemies that reach the castle door instead (no kill) grant nothing.
- `DayData.completion_reward` (`130` on `day_1.tres`) is awarded once, on a full Day clear, right
  before `EventBus.day_won` fires.
- End-of-day result copy is now explicit:
  - win: bonus coins + whether a new day unlocked,
  - loss: failure reason (`Castle HP reached 0`).
- `GameState.last_day_result` stores a compact day recap (win/loss, coin delta, completion bonus,
  unlock result) so Castle/War Room can show the most recent outcome.
- The shared `TopResourceBar` still mirrors live `EventBus` updates; battle context combines those
  economy values with tactical wave/upcoming/drop chips so high-signal combat context stays at the top.
- `GameState.currency` starts at `100` for a new save — enough to recruit the cheaper adventurers
  outright, but a full Day clear (or several kills) is needed to afford the Berserker (`250`).

## Known Limitations / Next Up

- Magic-unit spells are chosen pre-placement via the TD spell picker — there's still no way to switch
  an *already-placed* unit's spell mid-battle (see [Magic Spellcasting](#magic-spellcasting)).
- Reinforcement and repositioning are now allowed during between-wave breathers (see
  [Placement, Reinforcement & Range Preview](#placement-reinforcement--range-preview)), but not
  while a wave is actively spawning or enemies are on the field.
- Status readability remains lightweight (short text + tint + trigger popups); there is still no
  full dedicated status-icon inspector yet.
- Days 1–5 exist and `GameState.total_known_days()` now discovers them dynamically — further
  Day authoring remains data-only.
