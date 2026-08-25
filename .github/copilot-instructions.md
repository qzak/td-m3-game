# Copilot Instructions

Use this repo context when answering or editing code.

## Stack and Structure

- Godot 4.x, GDScript.
- Core systems:
  - Castle hub: `scripts/castle/`, `scenes/castle/`
  - Tower defense: `scripts/tower_defense/`, `scenes/tower_defense/`
  - Match-3 mine: `scripts/match3/`, `scenes/match3/`
- Shared state/autoloads: `autoload/game_state.gd`, `autoload/save_manager.gd`, `autoload/event_bus.gd`.
- Data-driven gameplay content lives in `data/**/*.tres`.

## Read First

1. `AGENTS.md`
2. `docs/IMPLEMENTATION_PLAN.md`
3. `docs/systems/tower_defense.md`
4. `docs/systems/match3.md`
5. `docs/systems/castle.md`

## Working Rules

- Keep edits minimal and targeted; avoid unrelated refactors.
- Prefer data changes in `data/*.tres` over hardcoded script constants.
- Preserve save/data compatibility unless explicitly requested.
- If behavior changes, update the matching doc in `docs/systems/`.

## Godot 4.x Gotchas

- Never use custom `class_name TileData` (collides with engine type).
- Avoid nested typed arrays like `Array[Array[SomeType]]`.
- `match` default branch is `_:`.
- `Array.remove(idx)` is not available; use `remove_at(idx)` or pop helpers.

## Validation

Run script validation after edits:

```powershell
godot --headless --path "D:\td-m3-game" --check-only --quit
```

For gameplay logic edits, sanity-check the touched flow in editor:

- Castle panel flow + day selection.
- TD placement/waves/win-loss return.
- Match-3 swaps/cascades/descend/depth-gated tiles.