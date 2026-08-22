extends Node
## Handles persisting GameState to/from disk under user://.

const SAVE_PATH := "user://savegame.json"

func _ready() -> void:
	EventBus.currency_changed.connect(func(_v): save_game())
	EventBus.materials_changed.connect(func(_id, _v): save_game())
	EventBus.adventurer_recruited.connect(func(_id): save_game())
	EventBus.building_upgraded.connect(func(_id, _lvl): save_game())
	EventBus.day_won.connect(func(_idx): save_game())
	EventBus.day_lost.connect(func(_idx): save_game())

func save_game() -> void:
	var data := {
		"currency": GameState.currency,
		"materials": GameState.materials,
		"owned_adventurers": GameState.owned_adventurers,
		"active_roster_ids": GameState.active_roster_ids,
		"building_levels": GameState.building_levels,
		"tavern_roster_ids": GameState.tavern_roster_ids,
		"tavern_next_refresh_unix": GameState.tavern_next_refresh_unix,
		"tavern_reroll_count": GameState.tavern_reroll_count,
		"smelter_queue": GameState.smelter_queue,
		"unlocked_day_index": GameState.unlocked_day_index,
		"mine_depth": GameState.mine_depth,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	GameState.currency = parsed.get("currency", 0)
	GameState.materials = parsed.get("materials", {})
	GameState.owned_adventurers = parsed.get("owned_adventurers", [])
	GameState.active_roster_ids = parsed.get("active_roster_ids", [])
	GameState.building_levels = parsed.get("building_levels", GameState.building_levels)
	GameState.tavern_roster_ids = parsed.get("tavern_roster_ids", [])
	GameState.tavern_next_refresh_unix = parsed.get("tavern_next_refresh_unix", 0)
	GameState.tavern_reroll_count = parsed.get("tavern_reroll_count", 0)
	GameState.smelter_queue = parsed.get("smelter_queue", [])
	GameState.unlocked_day_index = parsed.get("unlocked_day_index", 0)
	GameState.mine_depth = parsed.get("mine_depth", 0)
	return true
