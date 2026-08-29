# AGENTS.md

This file helps coding agents get productive quickly in this repository.

## Project Snapshot

- Engine: Godot 4.x (GDScript).
- Game pillars: Castle hub, Tower Defense battle, Match-3 mine.
- Data-first approach: gameplay content is mostly defined in `.tres` resources under `data/`.

## Visual Direction (Important)

- Target style: pixel-art fantasy adventure world with a cozy, readable, handcrafted look.
- Palette direction: warm, natural, slightly muted colors similar to the feel of Stardew Valley (earthy greens, browns, soft blues, warm highlights).
- Asset generation rule: prefer grounded medieval-adventure motifs (wood, stone, cloth, iron, lantern light, farmland/forest accents) over sci-fi or high-saturation neon styles.
- UI generation rule: keep pixel-friendly shapes and spacing, avoid ultra-modern glossy UI language, and favor legibility at small resolutions.
- Consistency rule: when proposing new visuals, describe how they match existing palette and tone before suggesting alternatives.

## Story & Theming (Important)

- See [docs/LORE.md](docs/LORE.md) for the full story bible and enemy naming conventions.
- All enemies are dragons (whelps up through ancient wyrms) — never introduce goblins, orcs,
  undead, or other monster families. New enemy content must fit the dragon power-curve naming
  scheme documented there.

## Start Here (Reading Order)

1. `docs/IMPLEMENTATION_PLAN.md` for the pending implementation backlog.
2. `docs/LORE.md` for the story premise and enemy theming/naming rules.
3. `docs/systems/tower_defense.md` for the TD loop, pathing, spawning, and day/wave flow.
4. `docs/systems/match3.md` for board rules, descent mechanic, and reward logic.
5. `docs/systems/castle.md` for building panels, progression, and scene flow.

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

## Implementation Plan Hygiene (Required)

- Treat `docs/IMPLEMENTATION_PLAN.md` as a **pending-features-only** backlog.
- When implementing a backlog item, remove that item from `docs/IMPLEMENTATION_PLAN.md` in the same change.
- Do not keep completion history in `docs/IMPLEMENTATION_PLAN.md`; put shipped/as-built behavior in the relevant file under `docs/systems/`.
- Keep remaining backlog entries itemized and actionable so future agents can execute them directly.

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

## Delegation Template (For Orchestrator Agents)

Use this prompt format when delegating implementation slices to subagents.

```text
Task: <one concrete outcome>

Context to read first:
- AGENTS.md
- docs/IMPLEMENTATION_PLAN.md
- docs/systems/<relevant-system>.md

Scope boundaries:
- In scope: <explicit files/systems>
- Out of scope: <what must not be touched>
- Save compatibility: <required/not required>

Implementation requirements:
- Keep edits minimal and localized.
- Prefer data-driven updates in data/*.tres when possible.
- Keep EventBus signals/public method contracts stable unless all callers are updated.

Deliverables:
- Code changes implementing <feature/fix>.
- Docs update in docs/systems/<file>.md if behavior changed.
- Short summary of gameplay impact.

Validation required:
1) Run:
  godot --headless --path "D:\td-m3-game" --check-only --quit
2) Smoke-test relevant flow:
  - Castle / TD / Match-3 (pick what applies)
3) Report exact checks performed and result.

Output format:
1) Assumptions made.
2) Files changed.
3) Risks/regressions to watch.
4) Validation results.
```

Recommended usage:

- Use one template per sub-task, not one giant prompt.
- Keep each delegated task to one system unless cross-system coupling is required.
- For high-risk changes (save schema, battle loop timing, progression economy), prefer stronger reasoning models.