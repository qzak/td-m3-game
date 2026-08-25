# AGENTS.md

This file helps coding agents get productive quickly in this repository.

## Project Snapshot

- Engine: Godot 4.x (GDScript).
- Game pillars: Castle hub, Tower Defense battle, Match-3 mine.
- Data-first approach: gameplay content is mostly defined in `.tres` resources under `data/`.

## Start Here (Reading Order)

1. `docs/IMPLEMENTATION_PLAN.md` for the overall architecture and milestone status.
2. `docs/systems/tower_defense.md` for the TD loop, pathing, spawning, and day/wave flow.
3. `docs/systems/match3.md` for board rules, descent mechanic, and reward logic.
4. `docs/systems/castle.md` for building panels, progression, and scene flow.

## Code Map

- `autoload/`
  - `game_state.gd`: central player/save state mutations.
  - `save_manager.gd`: save/load and autosave wiring.
  - `event_bus.gd`: global signals between systems.
- `scripts/castle/`: hub controllers and building panel logic.
- `scripts/tower_defense/`: battle loop, grid/path, unit behaviors.
- `scripts/match3/`: board state, move rules, matching, and rendering controller.
- `data/`: Resource definitions and gameplay content (`adventurers`, `enemies`, `items`, `tiles`, `waves`, `buildings`).
- `scenes/`: Godot scenes for castle, TD battle, match-3 mine, and building panels.

## How To Validate Changes

Use headless script validation after edits:

```powershell
godot --headless --path "D:\td-m3-game" --check-only --quit
```

If a scene/system behavior was changed, also run that flow in editor when possible:

- Castle scene flow: panel switching, day selection, enter battle/mine.
- TD flow: pre-placement, wave progression, between-wave behavior, win/loss return.
- Match-3 flow: legal moves, cascade, descend availability, depth-gated tiles.

## Known Godot 4.x Gotchas (Important)

- Do not name custom `class_name` as `TileData`; that collides with Godot's built-in `TileData`.
- Nested typed arrays like `Array[Array[SomeType]]` are not supported; keep outer array untyped.
- `match` default case is `_:` (not `else:`).
- `Array.remove(idx)` is removed in Godot 4; use `remove_at(idx)` or pop helpers.

## Editing Rules For Agents

- Keep changes minimal and localized; avoid unrelated refactors.
- Preserve current save/data compatibility unless the task explicitly changes it.
- Prefer extending data-driven content in `data/*.tres` over hardcoding gameplay values.
- Keep public signal names and event flow stable unless all callers are updated.
- When changing cross-system behavior, update the corresponding doc in `docs/systems/`.

## Common Task Entry Points

- Add new enemy/adventurer/item content: `data/` resources first, then only minimal script support.
- Adjust TD pacing/balance: `scripts/tower_defense/battle_controller.gd` and day/wave resources in `data/waves/`.
- Adjust mine progression/rewards: `scripts/match3/board.gd` plus `data/tiles/` resources.
- Adjust building economy/progression: `data/buildings/` and relevant `scripts/castle/*_controller.gd`.

## Done Criteria For Code Changes

- Scripts parse successfully via headless check.
- No obvious regressions in touched gameplay loop.
- Related system docs updated when behavior changes.
- Changes remain consistent with data-driven architecture.