# Castle Hub — As-Built Notes

Living documentation of the Castle hub scene as it's actually implemented. Update this
alongside code changes so it stays a reliable reference. See
[docs/IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) for the overall design/roadmap.

## Files

| File | Responsibility |
|---|---|
| [scenes/castle/castle.tscn](../../scenes/castle/castle.tscn) | Hub scene: panel-switching buttons, day selection, and shared resource HUD. Currently the project's run scene. |
| [scenes/ui/resource_hud.tscn](../../scenes/ui/resource_hud.tscn) / [scripts/ui/resource_hud.gd](../../scripts/ui/resource_hud.gd) (`ResourceHUD`) | Global compact resource strip with hover/tap-expand details, shared across Castle/TD/Mine. |
| [scripts/castle/castle_controller.gd](../../scripts/castle/castle_controller.gd) (`CastleController`) | Loads the save on `_ready`, toggles between Tavern/Quarters panels, starts the TD battle scene. |
| [scenes/castle/buildings/tavern.tscn](../../scenes/castle/buildings/tavern.tscn) / [scripts/castle/tavern_controller.gd](../../scripts/castle/tavern_controller.gd) (`TavernController`) | Real-time-refreshed adventurer roster; "Sign Contract" spends currency and adds to `GameState.owned_adventurers`. |
| [scenes/castle/buildings/quarters.tscn](../../scenes/castle/buildings/quarters.tscn) / [scripts/castle/quarters_controller.gd](../../scripts/castle/quarters_controller.gd) (`QuartersController`) | Capacity-limited toggle list to choose `GameState.active_roster_ids` for the next Day. |
| [scenes/castle/buildings/smelter.tscn](../../scenes/castle/buildings/smelter.tscn) / [scripts/castle/smelter_controller.gd](../../scripts/castle/smelter_controller.gd) (`SmelterController`) | Real-time smelting queue: turns raw materials into refined materials. |
| [scenes/castle/buildings/weapon_smith.tscn](../../scenes/castle/buildings/weapon_smith.tscn) / [scripts/castle/weapon_smith_controller.gd](../../scripts/castle/weapon_smith_controller.gd) (`WeaponSmithController`) | Thin [`SmithControllerBase`](../../scripts/castle/smith_controller_base.gd) subclass; crafts weapon `ItemData`. |
| [scenes/castle/buildings/armour_smith.tscn](../../scenes/castle/buildings/armour_smith.tscn) / [scripts/castle/armour_smith_controller.gd](../../scripts/castle/armour_smith_controller.gd) (`ArmourSmithController`) | Thin `SmithControllerBase` subclass; crafts armour `ItemData`. |
| [scripts/castle/smith_controller_base.gd](../../scripts/castle/smith_controller_base.gd) (`SmithControllerBase`) | Shared craft-list UI/logic for the two Smiths, configured per-subclass via `building_id` + `recipe_ids`. |
| [scenes/castle/buildings/armoury.tscn](../../scenes/castle/buildings/armoury.tscn) / [scripts/castle/armoury_controller.gd](../../scripts/castle/armoury_controller.gd) (`ArmouryController`) | Lists owned crafted items and equips/unequips them onto active-roster adventurers. |
| [scenes/castle/buildings/towers.tscn](../../scenes/castle/buildings/towers.tscn) / [scripts/castle/towers_panel.gd](../../scripts/castle/towers_panel.gd) (`TowersPanel`) | Minimal panel — Towers has no other player-facing UI yet, just its upgrade row. |
| [scenes/castle/buildings/building_upgrade_row.tscn](../../scenes/castle/buildings/building_upgrade_row.tscn) / [scripts/castle/building_upgrade_row.gd](../../scripts/castle/building_upgrade_row.gd) (`BuildingUpgradeRow`) | Reusable component embedded in every building panel: shows current/next level and cost, spends currency+materials via `GameState.upgrade_building()`. |
| [data/buildings/*.tres](../../data/buildings/) | `BuildingData` cost resources (`max_level`, per-level currency/material costs) — one per building id, including `towers.tres` (cost-only; `towers_stats.tres`/`TowerData` still holds Towers' per-level combat stats). |
| [data/items/*.tres](../../data/items/) | `ItemData` resources for the 6 craftable weapons/armour pieces (see Weapon/Armour Smith section below). |
| [autoload/game_state.gd](../../autoload/game_state.gd) (`GameState`) | `recruit_adventurer()`, `capacity_for()`, `set_active_roster()`, `upgrade_building()`, `start_smelting()`/`collect_ready_smelting()`, `craft_item()`, `equip_item()`/`unequip_item()` — the save-data mutations the hub drives. |
| [autoload/save_manager.gd](../../autoload/save_manager.gd) (`SaveManager`) | Loads on Castle `_ready()`; autosaves on `EventBus.currency_changed` / `materials_changed` / `adventurer_recruited` / `building_upgraded` / `day_won` / `day_lost`. |

## Hub Flow

- `castle.tscn` is the project's boot scene (`run/main_scene` in `project.godot`). `CastleController._ready()`
  calls `SaveManager.load_game()` immediately, then wires up all seven building buttons (Tavern,
  Quarters, Smelter, Weapon Smith, Armour Smith, Armoury, Towers), the Enter Mine button, and the
  Day-selection list (see [docs/systems/tower_defense.md](tower_defense.md#day-selection)).
- Exactly one building panel is visible at a time — `_show_panel()` iterates `all_panels` (all seven
  panel instances) setting `visible = (p == panel)`, and calls `panel.refresh()` if the panel exposes
  that method (every panel controller does; `TowersPanel` forwards it to its embedded upgrade row).
- `_build_day_list()` builds one "Start Day N" button (for `N` from `1` to `GameState.total_known_days()`)
  in the `DayList` container, disabling/labeling `(Locked)` any day past `GameState.unlocked_day_index`.
  Pressing an unlocked one sets `GameState.selected_day_index` and changes to `td_battle.tscn`.
- On returning from a battle (`TDBattleController`'s "Return to Castle" button, shown on
  `day_won`/`day_lost`), the scene reloads `castle.tscn` fresh — `CastleController._ready()` runs
  again and reloads the save, so anything `SaveManager` persisted mid-battle carries over (including
  any newly-unlocked Day).
- Layout pass: Castle now uses a left rail for building/day controls and keeps the currently-open
  building panel offset to the right to avoid top-bar overlap.
- The shared `ResourceHUD` lives in the top-right: its compact row is always visible, and hovering
  (desktop) or tapping (mobile) expands a fuller readout including refined materials.

## Building Upgrades

- Every building (`tavern`, `quarters`, `smelter`, `weapon_smith`, `armour_smith`, `armoury`, `towers`)
  now has a cost-only `BuildingData` resource at `data/buildings/<id>.tres` (`max_level = 5`, 4-entry
  `upgrade_currency_costs`/`upgrade_material_costs` arrays — index 0 is the cost to go from level 1→2).
  Effects stay in their own resource where they already existed (Towers' per-level combat stats remain
  in `data/buildings/towers_stats.tres`/`TowerData`; `BuildingData` is purely for gating the upgrade).
- Every building panel embeds a `BuildingUpgradeRow` (`scenes/castle/buildings/building_upgrade_row.tscn`)
  showing the building's current level, next-level cost, and an "Upgrade" button. Pressing it calls
  `GameState.upgrade_building(building_id)`, which validates and spends currency/materials, bumps
  `building_levels[building_id]`, and emits `EventBus.building_upgraded` — every upgrade row listens
  for that signal (plus `currency_changed`/`materials_changed`) so all open rows refresh automatically,
  not just the one that was pressed.
- Towers has no other player-facing UI yet, so its panel (`TowersPanel`) is just a title label plus
  the shared upgrade row.

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
  `GameState.tavern_next_refresh_unix`; once past it, `GameState.refresh_tavern_roster(pool_ids)`
  draws a random subset of `pool_ids` sized to `GameState.capacity_for("tavern")` (`3` at level 1,
  out of the 4-entry `pool_ids` catalog) into `tavern_roster_ids`, and the next refresh is scheduled
  `refresh_interval_seconds` (default `21600`, i.e. 6 real hours) later.
- Each row shows `display_name` + `recruit_cost` (new `AdventurerData` field) and a button that's
  disabled and reads "Owned" if `GameState.owned_adventurers` already has an entry with that
  `def_id`, or disabled if `GameState.currency < recruit_cost`. Pressing it calls
  `GameState.recruit_adventurer(def_id)`, which spends currency and appends
  `{def_id, instance_id, level: 1, equipped: {"weapon": "", "armour": ""}}` to `owned_adventurers`.
- Because `TDBattleController`'s one-copy-per-`AdventurerData.id` placement rule still applies,
  and the Tavern currently only ever offers one contract per `def_id` (no re-signing once
  "Owned"), there's no way yet to own multiple instances of the same adventurer type.
- **Reroll:** a "Reroll" button replaces `tavern_roster_ids` on demand ahead of the natural
  refresh timer. Cost is `GameState.tavern_reroll_cost()` (`20 + 20 * tavern_reroll_count`,
  so `20 → 40 → 60 → …`), shown on the button and disabling it once currency runs out.
  `GameState.reroll_tavern()` spends the cost, draws a fresh random subset into `tavern_roster_ids`
  (via the same `capacity_for("tavern")`-sized draw as the natural refresh), and increments
  `tavern_reroll_count`; the count resets to `0` whenever `EventBus.day_started` fires (i.e. once
  a Day battle is actually played), via a listener in `GameState._ready()`. Persisted the same way
  as the rest of the Tavern state.
  - Both the natural refresh and a manual reroll now go through `GameState._random_subset()`
    (shuffle-and-slice), so with a 4-entry `pool_ids` catalog and a 3-slot display, either action
    has a real chance of changing which adventurer is missing from the roster — Reroll is no
    longer a no-op.

## Quarters

- `active_roster_ids` also starts pre-filled (`["swordsman", "archer", "mage"]`), matching the
  Quarters' starting capacity of 3 — so a fresh save is immediately playable in the TD battle
  without a mandatory trip through Quarters first. Recruiting Berserker means visiting Quarters to
  swap one of the starting three out, unless `building_levels["quarters"]` has been raised via its
  `BuildingUpgradeRow` (see [Building Upgrades](#building-upgrades) above).
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

## Smelter

- Refines raw materials (`copper`, `iron`, `gold` — the mine's rewards) into refined materials
  (`refined_copper`, `refined_iron`, `refined_gold`) on a real-time queue, mirroring the Tavern's
  timestamp-based approach rather than a per-frame timer.
- `GameState.SMELT_RECIPES` maps each raw material to its output id and real-seconds duration
  (`copper` 30s, `iron` 60s, `gold` 120s). `GameState.smelter_slot_capacity()` (`= building_levels["smelter"]`)
  caps how many jobs can be queued at once — 1 slot at level 1, growing with upgrades.
- `SmelterController` shows one "Smelt" button per raw material (disabled once out of that material
  or all slots are full) and a live queue list with a per-job countdown. A 1-second repeating
  `Timer` calls `GameState.collect_ready_smelting()` and rebuilds the rows, so completed jobs move
  their output into `GameState.materials` automatically the next time the panel is open — no manual
  "collect" click needed.
- `GameState.start_smelting(material_id)` spends 1 raw material and appends
  `{material_id, output_id, complete_unix}` to `smelter_queue`; `collect_ready_smelting()` sweeps
  every entry whose `complete_unix` has passed, adds its output material, and removes it from the
  queue, emitting `EventBus.smelting_started`/`smelting_collected` respectively.

## Weapon Smith & Armour Smith

- Both crafting buildings share [`SmithControllerBase`](../../scripts/castle/smith_controller_base.gd);
  each concrete controller is a few-line subclass that just sets `building_id` and a hardcoded
  `recipe_ids` list (mirroring `TavernController.pool_ids`) before calling `super._ready()` —
  `weapon_smith` offers `iron_sword`/`steel_blade`/`golden_edge`, `armour_smith` offers
  `leather_vest`/`chainmail`/`gilded_plate` (see `data/items/*.tres` for exact stats/recipes).
- Each recipe row shows the item's name, its non-zero stat bonuses, its material cost, and a
  "Craft" button — disabled (and the name prefixed `[Locked]`) if `building_levels[building_id]` is
  below `ItemData.required_smith_level`, or if materials are insufficient, or if the Armoury is
  already at capacity (`GameState.capacity_for("armoury")`).
- `GameState.craft_item(def_id)` re-validates all three conditions server-side, spends the recipe's
  `recipe_materials`, and appends a new `{def_id, instance_id}` to `GameState.owned_items` — crafted
  items have no currency cost, only a materials-and-smith-level gate.
- Crafted items don't equip themselves — see Armoury below.

## Armoury

- Lists every entry in `GameState.owned_items` alongside the current active roster
  (`GameState.active_roster_ids`), and is the only place items get equipped/unequipped.
- Each owned item's row shows one "→ <adventurer>" button per active-roster adventurer (skipped if
  that adventurer already has that exact item in the matching slot); pressing it calls
  `GameState.equip_item(adventurer_instance_id, item_instance_id)`.
- Each adventurer's row shows their currently-equipped weapon/armour names plus "Unequip Weapon"/
  "Unequip Armour" buttons (disabled when that slot is already empty), calling
  `GameState.unequip_item(adventurer_instance_id, slot)`.
- `owned_adventurers[i].equipped` is `{"weapon": "", "armour": ""}` (values are `owned_items[].instance_id`,
  empty string = none). `GameState.equip_item()` first clears the item from wherever else it might be
  equipped (an item can only be on one adventurer at a time), then sets the target slot — it does not
  auto-unequip whatever was previously in that slot on the target adventurer other than by being
  overwritten, so the previous item just becomes unequipped-but-still-owned, not lost.
- Same one-instance-per-`def_id` simplification as elsewhere in this codebase: equip lookups resolve
  an adventurer `def_id` to its `owned_adventurers` entry by taking the first match.
- Equipped bonuses (`damage_bonus`/`range_bonus`/`attack_pool_bonus`/`attack_regen_bonus` from
  `ItemData`) are applied in the TD battle itself, not here — see
  [docs/systems/tower_defense.md](tower_defense.md#equipment-bonuses).

## Known Limitations / Planned Next

- Tavern's catalog is only 4 types wide, so a 3-slot random draw only ever omits one adventurer at
  a time — the random-subset rotation (see [Tavern](#tavern)) will feel more meaningful once the
  catalog grows beyond 4-5 types.
- No item rarity/tier visuals yet — the Smiths only gate crafting by `required_smith_level`, and the
  Armoury only shows item names, not rarity.
- Only one weapon + one armour slot per adventurer; no accessory/trinket slot yet.
