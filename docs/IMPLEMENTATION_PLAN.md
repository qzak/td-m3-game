# TD + Match-3 + RPG — Implementation Plan

Based on the attached design doc. Target engine: Godot 4.6 (Mobile renderer, already configured).

> As each system gets built, its actual (as-built) behavior is documented under
> [docs/systems/](systems/) — check there for up-to-date implementation details rather than
> just this plan. Currently: [docs/systems/tower_defense.md](systems/tower_defense.md),
> [docs/systems/castle.md](systems/castle.md).

## 1. High-Level Architecture

Three loosely-coupled "modes" share persistent player data:

```
┌────────────┐     ┌────────────────┐     ┌───────────────┐
│  Castle     │◄───►│  Meta/Save Data │◄──►│  Match-3 Mine  │
│  (hub UI)   │     │  (Resources)    │    │  (mini-game)   │
└─────┬──────┘     └────────────────┘     └───────────────┘
      │
      ▼
┌────────────┐
│ Tower       │
│ Defense     │
│ (Day battle)│
└────────────┘
```

- **Castle** — hub scene with building UIs (Tavern, Smelter, Armour Smith, Weapon Smith, Armoury, Quarters, Towers).
- **Tower Defense** — grid-based battle scene, played per "Day".
- **Match-3 Mine** — resource-gathering mini-game, descending 10x10 board.
- All three read/write a shared `GameState` autoload backed by `Resource`-based save data (adventurers, inventory, currency, building levels).

## 2. Project Folder Structure

```
res://
  autoload/
    event_bus.gd          # global signals (decoupled cross-system messaging)
    game_state.gd          # player save data, currency, roster, building levels
    save_manager.gd        # load/save to user:// as .tres or JSON
  data/                     # Resource *definitions* (design-time data, not save data)
    adventurers/
      adventurer_data.gd    # Resource: base stats, type, rarity
      *.tres                # individual adventurer definitions
    enemies/
      enemy_data.gd
      *.tres
    items/
      item_data.gd          # weapons/armour definitions
      *.tres
    buildings/
      building_data.gd      # upgrade costs/effects per level
    waves/
      wave_data.gd          # per-day enemy spawn schedule
  scenes/
    main_menu/
    castle/
      castle.tscn
      buildings/
        tavern.tscn
        smelter.tscn
        armour_smith.tscn
        weapon_smith.tscn
        armoury.tscn
        quarters.tscn
        towers.tscn
    tower_defense/
      td_battle.tscn
      grid/
      adventurer_unit.tscn
      enemy_unit.tscn
      projectile.tscn
    match3/
      mine.tscn
      tile.tscn
  scripts/
    tower_defense/
      battle_controller.gd  # move/attack step loop
      grid_map.gd
      adventurer.gd
      enemy.gd
      path_follow.gd
    match3/
      board.gd
      tile.gd
      match_solver.gd
    castle/
      building_base.gd
      tavern_controller.gd
      quarters_controller.gd
    ui/
  resources/                # save files live in user://, not res://
  assets/
    sprites/ audio/ fonts/
```

## 3. Core Data Model (Resources)

Use custom `Resource` classes for all data-driven content so designers can add adventurers/enemies/items as `.tres` files without code changes.

- `AdventurerData`: id, display name, rarity, type (physical_melee, physical_ranged, magic), base damage range, range, attack pool, attack regen, spell list (if magic), sprite.
- `EnemyData`: id, health, armour, move speed (steps per move-phase), abilities (stun, double-move), sprite, is_boss.
- `ItemData` (weapon/armour): stat modifiers, rarity, required smith level.
- `BuildingData`: per-level costs, effects (capacity, speed, unlock rarity).
- `WaveData` / `DayData`: ordered list of (enemy_id, count, spawn_delay) per Day, difficulty scalar.

Save data (`GameState`, persisted via `SaveManager`):
- Currency + raw/refined materials inventory
- Owned adventurers (instance data: level/XP if any, equipped items)
- Building levels
- Current tavern roster + refresh timer
- Unlocked Days / best clear record
- Mine progress (depth reached, current board state if mid-run)

## 4. Tower Defense System

- **Grid**: `TileMap` or custom `GridMap2D` with enemy path defined per Day (array of path cells or a `Path2D`/`Curve2D`).
- **Turn loop**: `BattleController` runs a repeating timer (default 500ms) alternating `_move_step()` and `_attack_step()`:
  - Move step: enemies advance N cells (per their move-speed stat); adventurers gain `attack_regen` into `attack_pool`.
  - Attack step: adventurers whose `attack_pool >= threshold` pick a target in range and fire (pool wraps/subtracts; handle "double attack" if regen > pool per the doc).
- **Placement**: player drags adventurers from Quarters roster onto valid grid cells before battle starts (no mid-battle repositioning initially — can add later).
- **Enemies**: spawned per `WaveData`, follow path, apply abilities each step (stun adjacent adventurer = skip their next attack step; double-move = move 2 cells that step).
- **Towers**: fixed defensive structures near the castle gate, auto-attack, act as last line of defense (no adventurer needed).
- **Win/loss**: Day cleared when all waves defeated; loss when castle HP hits 0 (enemies reaching the end reduce castle HP).

## 5. Match-3 Mine System

- 10x10 board using a `Board` (Array of Array) of `TileData` (resource-type gem).
- Standard match-3 detection (match_solver.gd): match-3+ horizontal/vertical, cascade resolution.
- the board should have randomly scattered pieces, with a few different types of "garbage" pieces that need to be matched in order to "get to the good stuff". Have dirt, stone and clay as three different garbage pieces.
- **Descend mechanic**: After a match is made, do not drop new pieces from the top. Still resolve any gravity, but instead allow the player to keep finding matches until they have cleared pieces in the entire top half of the board i.e. top 5 rows. Once the top half has been fully cleared of pieces, the player "descends" down the mine. This would be indicated by 5 new rows being pushed up from the bottom, shifting existing pieces up to the top of the board. One such event increments the "depth" by one.
- valuable pieces should appear once certain depth has been reached. As an example, copper should sporadically appear at depth level zero. Once player has reached depth level 5, iron could start appearing, and once they reach depth level 15, gold starts appearing.
- Rewards: matched valuable pieces award raw materials/currency directly into `GameState`; no fail state, purely a resource-gain loop (could add move limit or timer later for pacing).

## 6. Castle Hub System

Each building is a scene with a shared `BuildingBase` (level, upgrade cost lookup from `BuildingData`, upgrade() function that spends materials and emits `EventBus.building_upgraded`).

- **Tavern**: roster of N `AdventurerData` refreshed every X hours (real-time timestamp stored in save data); "sign contract" spends currency, adds to owned adventurer list.
- **Smelter**: only building with a real-time queue (smelting slots with completion timestamps), refines raw → refined materials.
- **Armour/Weapon Smith**: craft `ItemData` from refined materials + recipes gated by smith level.
- **Armoury**: inventory capacity cap for crafted items.
- **Quarters**: select active adventurer roster for next Day (capacity = level-based slot count).
- **Towers**: upgrade last-resort defense stats used directly in TD battle.

## 7. Suggested Build Order (Milestones)

1. **Foundations** — autoloads (`EventBus`, `GameState`, `SaveManager`), base `Resource` classes, project settings/input map.
2. **TD Core Loop (vertical slice)** — one hardcoded grid/path, place 1-2 adventurer types, move/attack step loop, one enemy type, win/lose condition. Playable without castle or mine.
3. **Adventurer & Enemy Data-Driven Content** — convert hardcoded units to `.tres` data, add several adventurer/enemy types and abilities (stun, double-move, ranged/melee), add Towers.
4. **Castle Hub Minimal** — Quarters (select roster) + Tavern (sign contracts) wired to `GameState`, enough to feed adventurers into TD.
5. **Match-3 Mine** — board, matching, descend mechanic, material rewards feeding into `GameState`.
6. **Remaining Buildings** — Smelter (timed queue), Armour/Weapon Smith (crafting), Armoury (capacity), building upgrade UI generalized via `BuildingData`.
7. **Day/Wave Content & Progression** — multiple Days with `WaveData`, difficulty scaling, replay support.
8. **Polish** — save/load robustness, mobile UI/touch input, audio/VFX, balancing pass.

## 8. Next Immediate Steps

1. Scaffold folder structure above.
2. Add `EventBus` and `GameState` autoloads.
3. Define `AdventurerData`, `EnemyData` resource scripts.
4. Build the milestone-2 TD vertical slice in a single test scene.
