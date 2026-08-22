# Castle Hub — As-Built Notes

Living documentation of the Castle hub scene as it's actually implemented. Update this
alongside code changes so it stays a reliable reference. See
[docs/IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) for the overall design/roadmap.

## Files

| File | Responsibility |
|---|---|
| [scenes/castle/castle.tscn](../../scenes/castle/castle.tscn) | Hub scene: currency label, panel-switching buttons, Start Day button. Currently the project's run scene. |
| [scripts/castle/castle_controller.gd](../../scripts/castle/castle_controller.gd) (`CastleController`) | Loads the save on `_ready`, toggles between Tavern/Quarters panels, starts the TD battle scene. |
| [scenes/castle/buildings/tavern.tscn](../../scenes/castle/buildings/tavern.tscn) / [scripts/castle/tavern_controller.gd](../../scripts/castle/tavern_controller.gd) (`TavernController`) | Real-time-refreshed adventurer roster; "Sign Contract" spends currency and adds to `GameState.owned_adventurers`. |
| [scenes/castle/buildings/quarters.tscn](../../scenes/castle/buildings/quarters.tscn) / [scripts/castle/quarters_controller.gd](../../scripts/castle/quarters_controller.gd) (`QuartersController`) | Capacity-limited toggle list to choose `GameState.active_roster_ids` for the next Day. |
| [autoload/game_state.gd](../../autoload/game_state.gd) (`GameState`) | `recruit_adventurer()`, `capacity_for()`, `set_active_roster()` — the save-data mutations the hub drives. |
| [autoload/save_manager.gd](../../autoload/save_manager.gd) (`SaveManager`) | Loads on Castle `_ready()`; autosaves on `EventBus.currency_changed` / `materials_changed` / `adventurer_recruited` / `building_upgraded` / `day_won` / `day_lost`. |

## Hub Flow

- `castle.tscn` is the project's boot scene (`run/main_scene` in `project.godot`). `CastleController._ready()`
  calls `SaveManager.load_game()` immediately, then wires up the Tavern/Quarters/Start Day buttons.
- Only one of the two building panels (`TavernPanel`, `QuartersPanel`) is visible at a time —
  `_show_panel()` toggles `visible` and calls the panel's `refresh()` so its list is rebuilt
  against current `GameState` whenever it's opened.
- "Start Day 1" changes scene straight to `td_battle.tscn` (hardcoded — no Day-selection UI yet,
  since only one `DayData` currently exists).
- On returning from a battle (`TDBattleController`'s "Return to Castle" button, shown on
  `day_won`/`day_lost`), the scene reloads `castle.tscn` fresh — `CastleController._ready()` runs
  again and reloads the save, so anything `SaveManager` persisted mid-battle carries over.

## Tavern

- `GameState.currency` starts at `100` for a new save. Gold beyond that comes from TD battles —
  see [docs/systems/tower_defense.md](tower_defense.md#gold-economy) for enemy bounties and the
  Day completion reward.
- `GameState.owned_adventurers` starts pre-populated with the three founding adventurers
  (Swordsman, Archer, Mage) — the player never needs to recruit them. `TavernController.pool_ids`
  (currently `["swordsman", "archer", "mage", "berserker"]`) is the full catalog offered in the
  Tavern; the three starting types just show up already "Owned", so **Berserker is the only
  adventurer that actually needs recruiting today**.
- `_refresh_if_needed()` compares `Time.get_unix_time_from_system()` against
  `GameState.tavern_next_refresh_unix`; once past it, `GameState.tavern_roster_ids` is reset to the
  full pool and the next refresh is scheduled `refresh_interval_seconds` (default `21600`, i.e. 6
  real hours) later.
- Each row shows `display_name` + `recruit_cost` (new `AdventurerData` field) and a button that's
  disabled and reads "Owned" if `GameState.owned_adventurers` already has an entry with that
  `def_id`, or disabled if `GameState.currency < recruit_cost`. Pressing it calls
  `GameState.recruit_adventurer(def_id)`, which spends currency and appends
  `{def_id, instance_id, level: 1, equipped: []}` to `owned_adventurers`.
- Because `TDBattleController`'s one-copy-per-`AdventurerData.id` placement rule still applies,
  and the Tavern currently only ever offers one contract per `def_id` (no re-signing once
  "Owned"), there's no way yet to own multiple instances of the same adventurer type.
- **Reroll:** a "Reroll" button replaces `tavern_roster_ids` on demand ahead of the natural
  refresh timer. Cost is `GameState.tavern_reroll_cost()` (`20 + 20 * tavern_reroll_count`,
  so `20 → 40 → 60 → …`), shown on the button and disabling it once currency runs out.
  `GameState.reroll_tavern()` spends the cost, replaces `tavern_roster_ids`, and increments
  `tavern_reroll_count`; the count resets to `0` whenever `EventBus.day_started` fires (i.e. once
  a Day battle is actually played), via a listener in `GameState._ready()`. Persisted the same way
  as the rest of the Tavern state.
  - Note: `tavern_roster_ids` is always a full copy of `pool_ids` (no random subset selection
    yet), so today a reroll is a no-op — it becomes meaningful once the Tavern draws a random
    subset from a catalog larger than what it displays at once.

## Quarters

- `active_roster_ids` also starts pre-filled (`["swordsman", "archer", "mage"]`), matching the
  Quarters' starting capacity of 3 — so a fresh save is immediately playable in the TD battle
  without a mandatory trip through Quarters first. Recruiting Berserker means visiting Quarters to
  swap one of the starting three out, since capacity doesn't grow until `building_levels["quarters"]`
  is upgraded (no upgrade UI yet).
- `QuartersController` splits owned adventurers into two `VBoxContainer` lists side by side —
  `ActiveList` (currently in `active_roster_ids`, each row with a "Remove" button) and
  `AvailableList` (owned but not active, each row with an "Add" button, disabled once capacity is
  full). Adding/removing calls `GameState.set_active_roster()` and rebuilds both lists.
- `GameState.recruit_adventurer()` never caps `owned_adventurers` — Quarters slots for adventurers
  you own are effectively unlimited. `GameState.capacity_for("quarters")` (`2 + building_levels["quarters"]`,
  so `3` at level 1) only caps `active_roster_ids`, the subset taken into the next Day.
- `active_roster_ids` feeds directly into `TDBattleController._build_placement_buttons()`, which
  builds one "Place X" button per active roster id by loading `res://data/adventurers/<id>.tres`
  — this is the actual Castle → TD bridge. If the roster is empty (e.g. running `td_battle.tscn`
  directly without going through the Castle), `fallback_roster_ids` (`swordsman`/`archer`/`mage`)
  is used instead so the battle scene stays testable standalone.
- `SaveManager.load_game()` only overwrites `owned_adventurers`/`active_roster_ids` with the saved
  values if they're non-empty — this keeps `GameState`'s built-in starting roster intact when
  loading an older save file that predates it (which would otherwise persist as empty arrays).

## Known Limitations / Planned Next

- No Smelter, Armour/Weapon Smith, or Armoury yet — only Tavern and Quarters are built.
- No building-upgrade UI yet — `building_levels` can only change by direct code/save edits; the
  Towers' level (used by `TDBattleController._spawn_towers()`) is read from this dictionary but
  nothing in the Castle UI currently lets the player raise it.
- Tavern's catalog (4 types) is now larger than the 3-slot roster it displays, but
  `TavernController.pool_ids` still shows the whole catalog every refresh rather than a random
  subset — "rotate a random subset" behavior can be added once there are enough adventurer types
  for it to matter more.
