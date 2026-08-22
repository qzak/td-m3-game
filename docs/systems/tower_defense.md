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
| [scripts/tower_defense/enemy.gd](../../scripts/tower_defense/enemy.gd) (`TDEnemy`) | Per-enemy state: health/armour, path following. |
| [scenes/tower_defense/adventurer_unit.tscn](../../scenes/tower_defense/adventurer_unit.tscn) / [enemy_unit.tscn](../../scenes/tower_defense/enemy_unit.tscn) | Placeholder visuals (colored square + stat label) — no art yet. |
| [data/adventurers/*.tres](../../data/adventurers/) | `AdventurerData` resource instances (see roster below). |
| [data/enemies/goblin.tres](../../data/enemies/goblin.tres) | Only enemy type so far. |

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

- **Move step** (`_move_step`): spawns the next enemy if its spawn delay has elapsed, advances
  every alive enemy along the path (`TDEnemy.advance()`), deals 1 castle-HP damage per enemy
  that reaches the end, then adds `attack_regen` to every placed adventurer's attack pool.
- **Attack step** (`_attack_step`): each adventurer whose pool is `>= attack_pool` picks the
  valid in-range enemy furthest along the path (closest to the castle) and attacks, looping so
  a large regen can trigger multiple attacks in one step. Damage is
  `randi_range(damage_min, damage_max) - enemy.armour` (floored at 0).

Win condition: no enemies left alive and none left to spawn. Loss condition: castle HP hits 0.
Both stop the timer and set `battle_over`.

## Placement & Range Preview

- Before `Start Battle` is pressed, clicking **Place Swordsman / Place Archer / Mage** sets
  `selected_adventurer_data` and updates the `SelectedLabel` HUD text.
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

| Name | id | Type | Range | Damage | Attack Pool / Regen |
|---|---|---|---|---|---|
| The Swordsman | `swordsman` | Physical melee | 1–1 | 3–6 | 100 / 40 |
| The Archer | `archer` | Physical ranged | 1–4 | 2–4 | 80 / 45 |
| The Mage | `mage` | Magic | 4–5 | 4–8 | 120 / 30 |

Range is Manhattan distance (`|dx| + |dy|`, diamond-shaped) from the adventurer's cell to the
enemy's current path cell — melee units can only hit true neighbors, the mage is long-range-only
and can't hit anything adjacent to it.

## Known Limitations / Next Up

- Single hardcoded wave (`enemy_count` goblins on a fixed spawn interval) — not yet using the
  scaffolded `WaveData`/`DayData` resources.
- No enemy abilities yet (stun, double-move) even though `EnemyData` has the fields.
- No Towers (last-resort defense) yet.
- Mage doesn't cast selectable spells yet — currently attacks identically to other types, just
  with different stats.
- No adventurer placement limit tied to the Castle's Quarters.
