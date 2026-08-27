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
	EventBus.mine_match_resolved.connect(func(_id, _amount): save_game())
	EventBus.mine_depth_changed.connect(func(_depth): save_game())
	EventBus.progression_changed.connect(func(_reason): save_game())

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
		"last_day_result": GameState.last_day_result,
		"mine_depth": GameState.mine_depth,
		"mine_board_state": GameState.mine_board_state,
		"progression": GameState.progression,
		"gate_states": GameState.gate_states,
		"dynamite_count": GameState.dynamite_count,
		"shovel_unlocked": GameState.shovel_unlocked,
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
	# Keep GameState's built-in starting roster if an older save predates it (empty arrays).
	var loaded_owned: Array = parsed.get("owned_adventurers", [])
	if not loaded_owned.is_empty():
		GameState.owned_adventurers = loaded_owned
	var loaded_roster: Array = parsed.get("active_roster_ids", [])
	if not loaded_roster.is_empty():
		GameState.active_roster_ids = loaded_roster
	var loaded_building_levels: Dictionary = parsed.get("building_levels", {})
	for building_id in loaded_building_levels:
		GameState.building_levels[building_id] = loaded_building_levels[building_id]
	GameState.tavern_roster_ids = parsed.get("tavern_roster_ids", [])
	GameState.tavern_next_refresh_unix = parsed.get("tavern_next_refresh_unix", 0)
	GameState.tavern_reroll_count = parsed.get("tavern_reroll_count", 0)
	GameState.smelter_queue = parsed.get("smelter_queue", [])
	GameState.unlocked_day_index = parsed.get("unlocked_day_index", 1)
	GameState.last_day_result = parsed.get("last_day_result", {})
	GameState.mine_depth = parsed.get("mine_depth", 0)
	GameState.mine_board_state = parsed.get("mine_board_state", [])
	var loaded_progression: Dictionary = parsed.get("progression", {})
	for key in loaded_progression:
		GameState.progression[key] = loaded_progression[key]
	var loaded_gate_states: Dictionary = parsed.get("gate_states", {})
	for key in loaded_gate_states:
		GameState.gate_states[key] = loaded_gate_states[key]
	GameState.dynamite_count = parsed.get("dynamite_count", 0)
	GameState.shovel_unlocked = parsed.get("shovel_unlocked", false)
	return true
