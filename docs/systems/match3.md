# Match-3 Mine - As-Built Notes

The mine is a 10x10 resource-gathering board. It is entered from the Castle's `Enter Mine`
button and returns through `Return to Castle`.

## Files

| File | Responsibility |
|---|---|
| `scripts/match3/board.gd` (`MineBoard`) | Owns the tile array, legal swaps, match resolution, gravity, descent, depth gates, and serialization. |
| `scripts/match3/match_solver.gd` (`MineMatchSolver`) | Finds horizontal and vertical runs of three or more, including boards with empty cells. |
| `scripts/match3/mine_controller.gd` (`MineController`) | Draws the board, handles click-to-swap input, applies rewards to `GameState`, and updates the HUD. |
| `data/tiles/*.tres` | Data-driven dirt, stone, clay, copper, iron, and gold tile definitions. |
| `autoload/save_manager.gd` | Persists `mine_depth` and the serialized current board in `user://savegame.json`. |

## Rules

- A swap must be adjacent and produce at least one match; otherwise it is reverted.
- A non-empty tile may move any horizontal distance into an empty cell on its left or right in
  the same row. The move remains in place whether or not it produces a match; matches resolve
  automatically when present. Gravity runs immediately after the move so pieces do not float.
- Matched tiles are removed, remaining tiles fall down, and cascades resolve automatically.
- Empty spaces are not refilled from the top.
- Once all five top rows are empty, the `Descend` button becomes available. Pressing it shifts the
  lower five rows to the top and generates five new rows at the bottom. This increases depth by
  one and emits `EventBus.mine_depth_changed`; descent is never automatic.
- Copper is available at depth 0, iron at depth 5, and gold at depth 15. Matching a valuable tile
  adds its material directly through `GameState.add_material()` and emits
  `EventBus.mine_match_resolved`.
- Garbage tiles are dirt, stone, and clay. They have no material reward and primarily clear space.
