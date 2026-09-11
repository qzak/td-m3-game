# Castle Hub — As-Built Notes

Living documentation of the Castle hub scene as it's actually implemented. Update this
alongside code changes so it stays a reliable reference. See
[docs/IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) for the overall design/roadmap.

- Player-facing Castle buttons now use the shared button skin from
  [scripts/ui/button_theme_factory.gd](../../scripts/ui/button_theme_factory.gd), which applies the
  frame/corner UI art, repo-local Pixelify Sans font, and `#bd5f31` interior fill through the Castle
  HUD theme. Frame borders use tiled repetition (not stretch), corner gems protrude slightly past the
  button bounds, and the HUD forces nearest filtering to preserve crisp pixel edges.

## Files

| File | Responsibility |
|---|---|
| [scenes/castle/castle.tscn](../../scenes/castle/castle.tscn) | Hub scene with focus-mode building entry, War Room day selection, and shared top resource bar. Currently the project's run scene. |
| [scenes/ui/top_resource_bar.tscn](../../scenes/ui/top_resource_bar.tscn) / [scripts/ui/top_resource_bar.gd](../../scripts/ui/top_resource_bar.gd) (`TopResourceBar`) | Shared full-width resource strip with placeholder icon swatches, context filtering, and live `EventBus` updates. |
| [scripts/castle/castle_controller.gd](../../scripts/castle/castle_controller.gd) (`CastleController`) | Loads the save on `_ready`, controls focus-mode panel flow, and starts TD days from the War Room. |
| [scenes/castle/buildings/tavern.tscn](../../scenes/castle/buildings/tavern.tscn) / [scripts/castle/tavern_controller.gd](../../scripts/castle/tavern_controller.gd) (`TavernController`) | Real-time-refreshed adventurer roster; "Sign Contract" spends currency and adds to `GameState.owned_adventurers`. |
| [scenes/castle/buildings/quarters.tscn](../../scenes/castle/buildings/quarters.tscn) / [scripts/castle/quarters_controller.gd](../../scripts/castle/quarters_controller.gd) (`QuartersController`) | Capacity-limited toggle list to choose `GameState.active_roster_ids` for the next Day. |
| [scenes/castle/buildings/smelter.tscn](../../scenes/castle/buildings/smelter.tscn) / [scripts/castle/smelter_controller.gd](../../scripts/castle/smelter_controller.gd) (`SmelterController`) | Real-time smelting queue: turns raw materials into refined materials. |
| [scenes/castle/buildings/weapon_smith.tscn](../../scenes/castle/buildings/weapon_smith.tscn) / [scripts/castle/weapon_smith_controller.gd](../../scripts/castle/weapon_smith_controller.gd) (`WeaponSmithController`) | Thin [`SmithControllerBase`](../../scripts/castle/smith_controller_base.gd) subclass; crafts weapon `ItemData`. |
| [scenes/castle/buildings/armour_smith.tscn](../../scenes/castle/buildings/armour_smith.tscn) / [scripts/castle/armour_smith_controller.gd](../../scripts/castle/armour_smith_controller.gd) (`ArmourSmithController`) | Thin `SmithControllerBase` subclass; crafts armour `ItemData`. |
| [scripts/castle/smith_controller_base.gd](../../scripts/castle/smith_controller_base.gd) (`SmithControllerBase`) | Shared craft-list UI/logic for the two Smiths, configured per-subclass via `building_id` + `recipe_ids`. |
| [scenes/castle/buildings/armoury.tscn](../../scenes/castle/buildings/armoury.tscn) / [scripts/castle/armoury_controller.gd](../../scripts/castle/armoury_controller.gd) (`ArmouryController`) | Lists owned crafted items and equips/unequips them onto active-roster adventurers. |
| [scenes/castle/buildings/towers.tscn](../../scenes/castle/buildings/towers.tscn) / [scripts/castle/towers_panel.gd](../../scripts/castle/towers_panel.gd) (`TowersPanel`) | Minimal panel — Towers has no other player-facing UI yet, just its upgrade row. |
| [scenes/castle/buildings/war_room.tscn](../../scenes/castle/buildings/war_room.tscn) / [scripts/castle/war_room_controller.gd](../../scripts/castle/war_room_controller.gd) (`WarRoomController`) | Dedicated day-selection panel; emits day-start requests, preserves unlock/lock behavior, and surfaces the most recent day result summary. |
| [scenes/castle/buildings/workshop.tscn](../../scenes/castle/buildings/workshop.tscn) / [scripts/castle/workshop_controller.gd](../../scripts/castle/workshop_controller.gd) (`WorkshopController`) | Progression-tool crafting panel (Dynamite, Shovel, Trinket attunement) tied to active mine gates and workshop unlock state. |
| [scenes/castle/buildings/library.tscn](../../scenes/castle/buildings/library.tscn) / [scripts/castle/library_controller.gd](../../scripts/castle/library_controller.gd) (`LibraryController`) | Placeholder panel scaffold for future bestiary work; currently shows empty-state messaging plus the shared building upgrade row. |
| [scenes/castle/buildings/building_upgrade_row.tscn](../../scenes/castle/buildings/building_upgrade_row.tscn) / [scripts/castle/building_upgrade_row.gd](../../scripts/castle/building_upgrade_row.gd) (`BuildingUpgradeRow`) | Reusable component embedded in every building panel: shows current/next level and cost, spends currency+materials via `GameState.upgrade_building()`. |
| [data/buildings/*.tres](../../data/buildings/) | `BuildingData` resources (`max_level`, per-level currency/material costs, optional per-level capacity/timer/speed vectors) — one per building id, including `towers.tres` (combat stats still live in `towers_stats.tres`/`TowerData`). |
| [data/items/*.tres](../../data/items/) | `ItemData` resources for the 6 craftable weapons/armour pieces (see Weapon/Armour Smith section below). |
| [autoload/game_state.gd](../../autoload/game_state.gd) (`GameState`) | `recruit_adventurer()`, `capacity_for()`, `set_active_roster()`, `upgrade_building()`, `start_smelting()`/`collect_ready_smelting()`, `craft_item()`, `equip_item()`/`unequip_item()` — the save-data mutations the hub drives. |
| [autoload/save_manager.gd](../../autoload/save_manager.gd) (`SaveManager`) | Loads on Castle `_ready()`; autosaves on core `EventBus` state-change signals, and on mobile lifecycle pause it force-saves then pauses the tree until resume. |

## Hub Flow

- `castle.tscn` is the project's boot scene (`run/main_scene` in `project.godot`). `CastleController._ready()`
  calls `SaveManager.load_game()` immediately, then wires up all building buttons (Tavern, Quarters,
  Smelter, Weapon Smith, Armour Smith, Armoury, Towers, War Room, Workshop, Library) plus Enter Mine.
- Exactly one building panel is visible at a time — `_show_panel()` iterates `all_panels`, sets
  `visible = (p == panel)`, and calls `panel.refresh()` when available.
- Entering any building now enables **focus mode**: the main building button grid hides, a dedicated
  `Back` button appears, and the chosen panel becomes the primary view. Pressing `Back` returns to
  the root building list.
- Day selection moved out of the root Castle screen into the **War Room** panel. War Room builds one
  "Start Day N" button (`1..GameState.total_known_days()`), marks unavailable days as `(Locked)` based on
  `GameState.can_start_day()`, and emits the selected day back to Castle to start
  `td_battle.tscn`.
- War Room now also shows a compact **Last Day Result** line (win/loss, coin delta, unlock result)
  using metadata stored in `GameState.last_day_result`.
- Castle now surfaces a persistent **Objective** line driven by `GameState.castle_objective_text()`
  so progression blockers and next steps are always visible in the hub and War Room.
- The Mine entry is progression-gated: it remains disabled until Day 1 is cleared.
- Workshop unlocks when the first mine depth is cleared and then drives all gate-tool crafting loops.
- On returning from a battle (`TDBattleController`'s "Return to Castle" button, shown on
  `day_won`/`day_lost`), the scene reloads `castle.tscn` fresh — `CastleController._ready()` runs
  again and reloads the save, so anything `SaveManager` persisted mid-battle carries over (including
  any newly-unlocked Day).
- Mobile lifecycle handling now lives in `SaveManager`: on app background/suspend notifications it
  writes `user://savegame.json` immediately and pauses `SceneTree`; on resume it restores play only
  if that pause was applied by lifecycle handling.
- Responsive layout pass: Castle HUD now routes through a safe-area `MarginContainer`; the top bar
  is inset by safe-area margins and the main content sits below it with side/bottom padding.
- Building navigation now lives in a container-driven left rail (`Sidebar`), while all building
  panels fill a responsive right-side `PanelHost` instead of fixed pixel offsets.
- Project display now uses canonical cross-platform stretch settings
  (`window/stretch/mode="canvas_items"` + `window/stretch/aspect="expand"`), preserving the
  authored 1280x720 layout baseline while allowing extra vertical room on taller viewports.
- Project GUI defaults use [assets/fonts/PixelifySans.ttf](../../assets/fonts/PixelifySans.ttf) as the
  committed pixel-friendly UI font, with antialiasing, hinting, and subpixel positioning disabled for
  crisper rasterization. The font is licensed under SIL OFL; keep
  [assets/fonts/PixelifySans.OFL.txt](../../assets/fonts/PixelifySans.OFL.txt) with it if replacing or
  redistributing the asset.
- Project export presets are now committed in `export_presets.cfg` for:
  - **Windows Desktop** (`build/windows/td-m3-game.exe`)
  - **Linux/X11** (`build/linux/td-m3-game.x86_64`)
  - **Android** (`build/android/td-m3-game.apk`) with placeholder custom-template + keystore fields
  - **iOS** (`build/ios`) with placeholder team/profile signing fields
  - **Web** (`build/web/index.html`) for browser exports.
- `project.godot` keeps `renderer/rendering_method="mobile"` for native targets and sets
  `renderer/rendering_method.web="gl_compatibility"` for browser export. This project is
  currently 2D/UI-heavy, so the web Compatibility renderer should remain the browser target unless
  Godot gains Web support for Mobile/Forward+ renderers.
- `.github/workflows/godot-web-build.yml` builds the **Web** preset with `barichello/godot-ci:4.7.2`
  on every push to `main`, uploads the generated browser bundle as a workflow artifact, and deploys
  `build/web` to the `gh-pages` branch for GitHub Pages hosting. The workflow installs Linux fontconfig
  support before running Godot, uses Bash for strict shell handling, copies export templates from the
  godot-ci image when available, downloads the official Godot export templates if the single-thread Web
  templates are missing, prints the committed **Web** preset for log clarity, then runs
  `godot --headless --import --quit` so fresh CI checkouts generate `.godot/imported/*` resources before
  exporting the committed `Web` preset.
- The shared `TopResourceBar` spans the top edge of the screen. Castle uses the `castle` context by
  default and switches to the `smith` context when Smelter/Weapon Smith/Armour Smith are focused to
  prioritize refined-material visibility. The bar now shows a scene context tag and emphasizes
  context-primary chips for faster scanning.

## Building Upgrades

- Every building (`tavern`, `quarters`, `smelter`, `weapon_smith`, `armour_smith`, `armoury`, `towers`, `workshop`, `library`)
  has a `BuildingData` resource at `data/buildings/<id>.tres` (`max_level = 5`, 4-entry
  `upgrade_currency_costs`/`upgrade_material_costs` arrays — index 0 is the cost to go from level 1→2).
  `BuildingData` can also carry effect vectors consumed by Castle systems:
  `capacity_by_level`, `tavern_refresh_seconds_by_level`, and
  `smelter_time_multiplier_by_level`. Towers' combat stats still remain in
  `data/buildings/towers_stats.tres`/`TowerData`.
- Differentiation pass: Tavern now emphasizes roster breadth/refresh cadence, Quarters prioritizes active
  roster slots, Armoury focuses on item-storage growth, Smelter scales both queue slots and processing
  speed, while Smiths and Towers have steeper late upgrade costs.
- Every building panel embeds a `BuildingUpgradeRow` (`scenes/castle/buildings/building_upgrade_row.tscn`)
  showing the building's current level, next-level cost, and a concise **Now/Next** effect line
  (`Now/Next: <current> -> <next>`, or `Now: <current> (max)` at max level). Pressing "Upgrade" calls
  `GameState.upgrade_building(building_id)`, which validates and spends currency/materials, bumps
  `building_levels[building_id]`, and emits `EventBus.building_upgraded` — every upgrade row listens
  for that signal (plus `currency_changed`/`materials_changed`) so all open rows refresh automatically,
  not just the one that was pressed.
- Building-panel subtitle copy is intentionally progression-forward and role-specific (what each building
  does now, plus what its upgrades improve/unlock next) so players can scan identity and upgrade value
  before opening detailed lists.
- Effect line mappings are data-driven where available: Tavern/Quarters/Smelter/Armoury show capacity
  (and Tavern refresh cadence / Smelter time multiplier), Smiths show craft-tier level gating, and
  Towers show `towers_stats.tres` combat stat progression.
- Towers has no other player-facing UI yet, so its panel (`TowersPanel`) is just a title label plus
  the shared upgrade row.
- Library currently has no bestiary data binding yet; its panel intentionally remains a scaffold with
  explicit "coming soon" messaging while still participating in normal Castle panel routing and upgrade
  row refresh behavior.

## Tavern

- `GameState.currency` starts at `100` for a new save. Gold beyond that comes from TD battles —
  see [docs/systems/tower_defense.md](tower_defense.md#gold-economy) for enemy bounties and the
  Day completion reward.
- `GameState.owned_adventurers` starts pre-populated with the three founding adventurers
  (Swordsman, Archer, Mage) — the player never needs to recruit them. `TavernController.pool_ids`
  (currently `["swordsman", "archer", "mage", "berserker", "pikeman", "druid"]`) is the full
  catalog offered in the Tavern; the three starting types just show up already "Owned", while
  Berserker/Pikeman/Druid are recruitable contracts.
- `_refresh_if_needed()` compares `Time.get_unix_time_from_system()` against
  `GameState.tavern_next_refresh_unix`; once past it, `GameState.refresh_tavern_roster(pool_ids)`
  draws a random subset of `pool_ids` sized to `GameState.capacity_for("tavern")` (`3` at level 1,
  out of the 6-entry `pool_ids` catalog) into `tavern_roster_ids`, and the next refresh is scheduled
  by `GameState.tavern_refresh_interval_seconds()`, read from Tavern `BuildingData`
  (`21600 -> 18000 -> 14400 -> 10800 -> 7200`, i.e. 6h down to 2h by level 5).
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
    (shuffle-and-slice), so with a 6-entry `pool_ids` catalog and a 3-slot display, rerolls and
    refreshes produce a broader spread of possible contract combinations.

## Quarters

- `active_roster_ids` also starts pre-filled (`["swordsman", "archer", "mage"]`), matching the
  Quarters' starting capacity of 3 — so a fresh save is immediately playable in the TD battle
  without a mandatory trip through Quarters first. Recruiting Berserker/Pikeman/Druid means visiting Quarters to
  swap one of the starting three out, unless `building_levels["quarters"]` has been raised via its
  `BuildingUpgradeRow` (see [Building Upgrades](#building-upgrades) above).
- `QuartersController` splits owned adventurers into two `VBoxContainer` lists side by side —
  `ActiveList` (currently in `active_roster_ids`, each row with a "Remove" button) and
  `AvailableList` (owned but not active, each row with an "Add" button, disabled once capacity is
  full). Adding/removing calls `GameState.set_active_roster()` and rebuilds both lists.
- `GameState.recruit_adventurer()` never caps `owned_adventurers` — Quarters slots for adventurers
  you own are effectively unlimited. `GameState.capacity_for("quarters")` now reads Quarters
  `capacity_by_level` (`3, 4, 5, 6, 8`) and only caps `active_roster_ids`, the subset taken into the
  next Day.
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
  (`copper` 30s, `iron` 60s, `gold` 120s). `GameState.smelter_slot_capacity()` now reads
  Smelter `capacity_by_level` (`1, 2, 3, 4, 6`), and queued durations are multiplied by
  `smelter_time_multiplier_by_level` (`1.0, 0.9, 0.8, 0.7, 0.6`) at queue time.
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
- Armoury now renders a level-scaled square storage grid and a selected-adventurer slot panel:
  - Armoury Level 1 starts at `5 x 5`.
  - Each Armoury upgrade increases both dimensions by `+2` (`7x7`, `9x9`, `11x11`, `13x13`).
  - While the Armoury panel is open, upgrading the building updates the visible grid size immediately.
  - Storage items are shown at their persisted grid cells.
  - Equipped items are removed from storage and shown only in slot cards.
  - Drag from storage item -> slot card to equip.
  - Drag from equipped item -> storage grid to unequip to a chosen cell.
  - Dragging over storage highlights the item's full footprint green for a valid target or red for
    an invalid one, accounting for the cell grabbed from a stored item.
- Hovering an item (or tapping it on touch devices) shows a detail tooltip beside the cursor or
  touch point with slot, footprint, and bonus stats; it hides when the hover ends.
- During a drag, the source item is hidden and its drag preview represents the picked-up item;
  source visibility is restored after a drop or cancelled drag.
- Item size and compatibility are data-driven:
  - `ItemData.footprint` controls grid width/height in cells.
  - Current content standardization: armour recipes use `2x2`; weapon recipes scale by expected size
    (e.g. `3x1`, `4x1`, `4x2` across the current weapon tier set).
  - `ItemData.slot_id` (with legacy enum fallback) controls which slot the item can be dropped onto.
  - `AdventurerData.equipment_slots` defines each adventurer's available slot IDs.
- `owned_adventurers[i].equipped` is now a slot-id dictionary (key = slot id, value = `owned_items[].instance_id`
  or empty string). `GameState.equip_item_to_slot()` enforces slot compatibility, guarantees one item
  is equipped in at most one slot globally, and if it replaces an existing equipped item it attempts
  to return that displaced item to the first free storage position.
- Save migration keeps older `{"weapon": "", "armour": ""}` entries compatible by normalizing equipped maps
  against the current `AdventurerData.equipment_slots` shape on load.
- Same one-instance-per-`def_id` simplification as elsewhere in this codebase: equip lookups resolve
  an adventurer `def_id` to its `owned_adventurers` entry by taking the first match.
- Equipped bonuses (`damage_bonus`/`range_bonus`/`attack_pool_bonus`/`attack_regen_bonus` from
  `ItemData`) are applied in the TD battle itself, not here — see
  [docs/systems/tower_defense.md](tower_defense.md#equipment-bonuses).

## Known Limitations / Planned Next

- Tavern's catalog now has 6 types, but it still shows only 3 contracts at tavern level 1; upgrading
  the Tavern increases simultaneous visible contracts and makes targeted recruiting easier.
- No item rarity/tier visuals yet — the Smiths only gate crafting by `required_smith_level`, and the
  Armoury uses simple type icons (weapon/armour silhouettes) without rarity framing.
- UI layout for the armoury grid is functional-first and does not yet have icon art, rarity frames, or
  advanced drag preview polish.
