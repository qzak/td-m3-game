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

## Visual Direction (Important)

- Target style: pixel-art fantasy adventure world with a cozy, readable, handcrafted look.
- Palette direction: warm, natural, slightly muted colors similar to Stardew Valley (earthy greens, browns, soft blues, warm highlights).
- For generated assets/UI ideas, favor medieval-adventure materials and motifs (wood, stone, cloth, iron, lantern light, village/farm/forest tones).
- Avoid styles that clash with the target (neon sci-fi, hyper-glossy UI, overly realistic rendering).
- Keep UI and icon suggestions pixel-friendly and legible at small resolutions.

## Story & Theming (Important)

- All enemies are dragons, from small whelps early on to ancient wyrm bosses later. Never
  introduce other monster families (goblins, orcs, undead, etc.).
- See `docs/LORE.md` for the story premise and enemy naming conventions before adding new enemy content.

## Read First

1. `AGENTS.md`
2. `docs/IMPLEMENTATION_PLAN.md`
3. `docs/LORE.md`
4. `docs/systems/tower_defense.md`
5. `docs/systems/match3.md`
6. `docs/systems/castle.md`

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