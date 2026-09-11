# Match-3 Mine - As-Built Notes

The mine is a 10x10 resource-gathering board. It is entered from the Castle's `Enter Mine`
button and returns through `Return to Castle`.

- Player-facing Mine action buttons inherit the shared button skin from
  [scripts/ui/button_theme_factory.gd](../../scripts/ui/button_theme_factory.gd), using the
  frame/corner UI art and `#bd5f31` interior fill
  with hover/pressed/disabled tint variants. Border strips are tiled around the perimeter and
  nearest filtering is used to retain crisp pixel visuals.

Project display uses canonical cross-platform stretch settings
(`window/stretch/mode="canvas_items"` + `window/stretch/aspect="expand"`), with runtime layout now
adapting to safe-area insets and viewport size.
- Mine HUD labels/actions now live in a safe-area-aware container rail instead of fixed pixel
  offsets.
- Board origin/cell size are now computed from the live viewport, and the mine background draw uses
  a viewport-relative rect instead of a fixed `1280x720` rectangle.
- Draw-path perf pass (mobile-oriented): `MineController` now caches tile display-name lookups and
  reuses `Vector2i` keys for hidden-cell checks during animation, reducing per-frame allocations in
  its `_draw()` loop without changing board visuals/logic.
- First-time mine board generation now uses a single-pass fill that avoids immediate horizontal/vertical
  3-in-a-row during placement, replacing full-board reroll loops that could stall first entry.

## Files

| File | Responsibility |
|---|---|
| `scripts/match3/board.gd` (`MineBoard`) | Owns the tile array, legal swaps, match resolution, gravity, descent, depth gates, and serialization. |
| `scripts/match3/match_solver.gd` (`MineMatchSolver`) | Finds horizontal and vertical runs of three or more, including boards with empty cells. |
| `scripts/match3/mine_controller.gd` (`MineController`) | Draws the board, handles mouse/touch board input (tap + drag target preview), applies rewards to `GameState`, and updates the HUD. |
| `scenes/ui/top_resource_bar.tscn` / `scripts/ui/top_resource_bar.gd` (`TopResourceBar`) | Shared full-width resource strip with placeholder icon swatches, context filtering, and live `EventBus` updates. |
| `data/tiles/*.tres` | Data-driven tile definitions, including progression blockers (`hard_stone`, `rooted_stone`). |
| `autoload/save_manager.gd` | Persists `mine_depth` and the serialized current board in `user://savegame.json`. |

## Rules

- A swap must be adjacent and produce at least one match; otherwise it is reverted.
- A non-empty tile may move any horizontal distance into an empty cell on its left or right in
  the same row. The move remains in place whether or not it produces a match; matches resolve
  automatically when present. Gravity runs immediately after the move so pieces do not float.
- Matched tiles are removed, remaining tiles fall down, and cascades resolve automatically.
- Empty spaces are not refilled from the top.
- Once all five top rows are empty, the `Descend` button becomes available. A persistent HUD line
  now shows readiness progress (`Descend ready: X/5 top rows clear`) so players can see how close
  they are before it unlocks. Pressing `Descend` shifts the lower five rows to the top and
  generates five new rows at the bottom using spawn-safe placement (no immediate horizontal/vertical
  3+ runs at the placement cell). This increases depth by one and emits
  `EventBus.mine_depth_changed`; descent is never automatic.
- Copper is available at depth 0, iron at depth 5, and gold at depth 15. Matching a valuable tile
  adds its material directly through `GameState.add_material()` and emits
  `EventBus.mine_match_resolved`.
- Garbage tiles are dirt, stone, and clay. They have no material reward and primarily clear space.
- Gate-aware blocker rules:
  - **Hardness Gate A** (`hard_stone`): active from the first cleared depth layer; `hard_stone` tiles always survive normal match clears (never removed by matching three) and must be removed with Dynamite.
  - **Hardness Gate B** (`rooted_stone`): arms once the mine reaches depth 5 (`GameState.HARDNESS_B_DEPTH`); cannot be moved by normal swap/move rules until Shovel is crafted.
  - **Magic Barrier Gate**: arms once the mine reaches depth 15 (`GameState.MAGIC_BARRIER_DEPTH`); matching/moving below the barrier row is blocked until the trinket is attuned.
  - Gates no longer chain instantly off each other's resolution — `GameState.check_depth_gates(depth)` arms each gate independently by depth, so resolving an earlier gate (e.g. blasting hard_stone) does not immediately spawn the next gate's blocker tile on the same layer.
- Descend is additionally progression-gated by active unresolved mine gates via `GameState.gate_state(...)`.

## Animation & Input Locking

- `MineBoard` emits ordered animation events and `MineController` plays them as a queue:
  - adjacent swaps: **swap → clear → gravity** (plus cascades),
  - move-to-empty actions: **move → gravity → clear** (when matches are created), then cascades.
- **Swap** animation: a legal adjacent swap is animated first (`0.14s`) before any clear/gravity
  pass runs; rejected swaps still revert immediately with no committed swap animation.
- **Move-to-empty** animation: accepted horizontal empty-space moves animate as a dedicated pre-gravity
  slide (`0.16s`) before gravity and any resulting clear/cascade.
- **Clear** animation: matched tiles shrink and fade (`0.18s`) before the next step.
- **Gravity** animation: moved tiles slide to their compacted row (`0.22s`), with destination cells
  hidden until tweens complete to avoid double-draw artifacts.
- **Descend** animation: shifted rows and newly spawned bottom rows animate together as one move pass
  (`0.30s`), then depth/status text updates.
- While any animation is running, board input is hard-gated (`_unhandled_input` early return),
  `Descend` is disabled, active selection is cleared, and status is pinned to `Animating mine...`.
  Deferred status text (for example `New layer opened`) is shown after the queue finishes.
- Touch parity:
  - `InputEventScreenTouch` now mirrors click behavior for select/move/swap and Dynamite targeting.
  - `InputEventScreenDrag` can preview a second target cell after selecting a source tile, then
    releasing commits that move/swap as the touch equivalent of a second click.
  - Touch hit-testing allows a small edge slop around the board bounds to make border-cell taps
    easier.
- Touch ergonomics: Mine action buttons (`Return to Castle`, `Descend`, `Use Dynamite`) enforce a
  larger minimum height on touch-capable devices.
- Mine-specific HUD now focuses on depth/status/actions; shared resource counts moved to the
  full-width `TopResourceBar` at the top of the scene.
- In mine context, `TopResourceBar` prioritizes ore scanning order (`Gold Ore`, `Iron`, `Copper`,
  then `Coins`) so gathering targets stay front-loaded.
- Idle/help status copy now repeatedly calls out the goal ("clear the top edge") to make descent
  requirements obvious without trial-and-error.
- Mine HUD now also includes:
  - a gate/objective line (shared Castle objective source),
  - a Dynamite action button with targeting mode,
  - explicit blocked-reason status messaging from progression state.
