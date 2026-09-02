extends Node
## Holds the player's persistent save data for the current session.
## Loaded/saved via SaveManager. Systems read/write through this singleton.

var currency: int = 100
var materials: Dictionary = {}  # material_id (String) -> amount (int)

## Every player starts owning the three founding adventurers already (no need to recruit them).
var owned_adventurers: Array = [
	{"def_id": "swordsman", "instance_id": "swordsman_start", "level": 1, "equipped": {"weapon": "", "armour": ""}},
	{"def_id": "archer", "instance_id": "archer_start", "level": 1, "equipped": {"weapon": "", "armour": ""}},
	{"def_id": "mage", "instance_id": "mage_start", "level": 1, "equipped": {"weapon": "", "armour": ""}},
]
var active_roster_ids: Array = ["swordsman", "archer", "mage"]  # pre-filled, matches starting capacity

var building_levels: Dictionary = {
	"tavern": 1,
	"smelter": 1,
	"armour_smith": 1,
	"weapon_smith": 1,
	"armoury": 1,
	"quarters": 1,
	"towers": 1,
	"workshop": 1,
	"library": 1,
}

var tavern_roster_ids: Array = []
var tavern_next_refresh_unix: int = 0
var tavern_reroll_count: int = 0  # resets to 0 each time a Day is played

var smelter_queue: Array = []  # Array[Dictionary] (item_id, complete_unix)

var owned_items: Array = []  # Array[Dictionary] {def_id, instance_id, storage_cell?}

var unlocked_day_index: int = 1
var selected_day_index: int = 1
var last_day_result: Dictionary = {}
var mine_depth: int = 0
var mine_board_state: Array = []
var progression: Dictionary = {
	"day1_cleared": false,
	"mine_intro_seen": false,
	"first_depth_cleared": false,
	"workshop_unlocked": false,
	"barrier_trinket_obtained": false,
	"barrier_trinket_activated": false,
}
var gate_states: Dictionary = {
	"hardness_a": "introduced",
	"hardness_b": "introduced",
	"magic_barrier": "introduced",
}
var dynamite_count: int = 0
var shovel_unlocked: bool = false
var _total_known_days_cache: int = -1  # -1 = not yet computed

const GATE_INTRODUCED := "introduced"
const GATE_ACTIVE := "active"
const GATE_RESOLVED := "resolved"
const HARDNESS_B_DEPTH := 5
const MAGIC_BARRIER_DEPTH := 15
const LEGACY_DEFAULT_EQUIPMENT_SLOTS: Array[String] = ["weapon", "armour"]
const ARMOURY_GRID_BASE_SIZE := 5
const ARMOURY_GRID_SIZE_STEP := 2
const WORKSHOP_RECIPES := {
	"dynamite": {
		"display_name": "Dynamite",
		"materials": {"volatile_core": 1, "copper": 3},
		"requires_gate": "hardness_a",
	},
	"shovel": {
		"display_name": "Forge Shovel",
		"materials": {"iron": 4, "refined_iron": 2},
		"requires_gate": "hardness_b",
	},
	"activate_trinket": {
		"display_name": "Attune Wardbreaker Trinket",
		"materials": {"refined_gold": 2},
		"requires_gate": "magic_barrier",
		"requires_trinket": true,
	},
}

func _ready() -> void:
	normalize_armoury_state()
	EventBus.day_started.connect(func(_idx): tavern_reroll_count = 0)
	EventBus.day_won.connect(_on_day_won)

func _on_day_won(day_index: int) -> void:
	unlocked_day_index = maxi(unlocked_day_index, day_index + 1)
	if day_index == 1 and not progression.get("day1_cleared", false):
		progression["day1_cleared"] = true
		_emit_progression_changed("day1-cleared")

func record_day_result(day_index: int, did_win: bool, currency_delta: int, completion_reward: int, castle_hp_end: int, unlocked_day_after: int) -> void:
	last_day_result = {
		"played": true,
		"day_index": day_index,
		"did_win": did_win,
		"currency_delta": currency_delta,
		"completion_reward": completion_reward,
		"castle_hp_end": castle_hp_end,
		"unlocked_day_after": unlocked_day_after,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
	}

func can_enter_mine() -> bool:
	return bool(progression.get("day1_cleared", false))

func can_start_day(day_index: int) -> bool:
	if day_index > unlocked_day_index:
		return false
	if day_index <= 1:
		return true
	return bool(progression.get("first_depth_cleared", false))

func mark_mine_intro_seen() -> void:
	if progression.get("mine_intro_seen", false):
		return
	progression["mine_intro_seen"] = true
	_emit_progression_changed("mine-intro-seen")

func mark_first_depth_cleared() -> void:
	if progression.get("first_depth_cleared", false):
		return
	progression["first_depth_cleared"] = true
	progression["workshop_unlocked"] = true
	if gate_state("hardness_a") != GATE_RESOLVED:
		set_gate_state("hardness_a", GATE_ACTIVE)
	_emit_progression_changed("first-depth-cleared")

func gate_state(gate_id: String) -> String:
	return str(gate_states.get(gate_id, GATE_INTRODUCED))

func set_gate_state(gate_id: String, new_state: String) -> void:
	if not gate_states.has(gate_id):
		return
	if new_state != GATE_INTRODUCED and new_state != GATE_ACTIVE and new_state != GATE_RESOLVED:
		return
	if gate_states[gate_id] == new_state:
		return
	gate_states[gate_id] = new_state
	_emit_progression_changed("gate-state-%s-%s" % [gate_id, new_state])

## Arms hardness_b/magic_barrier once the mine reaches their trigger depth, instead of instantly
## chaining off the previous gate's resolution.
func check_depth_gates(current_depth: int) -> void:
	if current_depth >= HARDNESS_B_DEPTH and gate_state("hardness_b") == GATE_INTRODUCED:
		set_gate_state("hardness_b", GATE_ACTIVE)
	if current_depth >= MAGIC_BARRIER_DEPTH and gate_state("magic_barrier") == GATE_INTRODUCED:
		set_gate_state("magic_barrier", GATE_ACTIVE)

func consume_dynamite() -> bool:
	if dynamite_count <= 0:
		return false
	dynamite_count -= 1
	if gate_state("hardness_a") == GATE_ACTIVE:
		set_gate_state("hardness_a", GATE_RESOLVED)
	_emit_progression_changed("dynamite-used")
	return true

func craft_workshop_recipe(recipe_id: String) -> bool:
	var recipe: Dictionary = WORKSHOP_RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return false
	if not progression.get("workshop_unlocked", false):
		return false
	var required_gate := str(recipe.get("requires_gate", ""))
	if not required_gate.is_empty() and gate_state(required_gate) != GATE_ACTIVE:
		return false
	if bool(recipe.get("requires_trinket", false)) and not progression.get("barrier_trinket_obtained", false):
		return false
	var material_costs: Dictionary = recipe.get("materials", {})
	for material_id in material_costs:
		if materials.get(material_id, 0) < int(material_costs[material_id]):
			return false
	for material_id in material_costs:
		spend_material(material_id, int(material_costs[material_id]))
	match recipe_id:
		"dynamite":
			dynamite_count += 1
		"shovel":
			shovel_unlocked = true
			set_gate_state("hardness_b", GATE_RESOLVED)
		"activate_trinket":
			progression["barrier_trinket_activated"] = true
			set_gate_state("magic_barrier", GATE_RESOLVED)
		_:
			return false
	_emit_progression_changed("crafted-%s" % recipe_id)
	return true

func grant_barrier_trinket() -> void:
	if progression.get("barrier_trinket_obtained", false):
		return
	progression["barrier_trinket_obtained"] = true
	_emit_progression_changed("trinket-obtained")

func castle_objective_text() -> String:
	if not progression.get("day1_cleared", false):
		return "Objective: Win Day 1 in the War Room."
	if not progression.get("first_depth_cleared", false):
		return "Objective: Enter the Mine and clear the first depth layer."
	if gate_state("hardness_a") == GATE_ACTIVE:
		if dynamite_count > 0:
			return "Objective: Use Dynamite in the Mine to blast hardened stone."
		return "Objective: Defeat Young Drakes for Volatile Core, then craft Dynamite in Workshop."
	if gate_state("hardness_b") == GATE_ACTIVE:
		if shovel_unlocked:
			return "Objective: Return to the Mine and clear immovable strata with your Shovel."
		return "Objective: Craft a Shovel in Workshop to clear immovable mine pieces."
	if gate_state("magic_barrier") == GATE_ACTIVE:
		if not progression.get("barrier_trinket_obtained", false):
			return "Objective: Defeat the Day 3 Elder Wyrm boss for the Wardbreaker Trinket."
		if not progression.get("barrier_trinket_activated", false):
			return "Objective: Attune the Wardbreaker Trinket in Workshop to dispel the barrier."
	return "Objective: Push deeper into the mine and strengthen your roster."

func mine_blocked_reason() -> String:
	if gate_state("hardness_a") == GATE_ACTIVE and dynamite_count <= 0:
		return "Hardened stone blocks progress. Craft Dynamite in Workshop."
	if gate_state("hardness_b") == GATE_ACTIVE and not shovel_unlocked:
		return "Immovable strata blocks progress. Craft a Shovel in Workshop."
	if gate_state("magic_barrier") == GATE_ACTIVE and not progression.get("barrier_trinket_activated", false):
		return "A magic barrier seals deeper strata. Obtain and attune the Wardbreaker Trinket."
	return ""

func _emit_progression_changed(reason: String) -> void:
	EventBus.progression_changed.emit(reason)

func total_known_days() -> int:
	# Return cached value if already computed
	if _total_known_days_cache >= 0:
		return _total_known_days_cache
	
	# Scan res://data/waves/ for day_<n>.tres files
	var dir: DirAccess = DirAccess.open("res://data/waves")
	if dir == null:
		_total_known_days_cache = 1
		return 1
	
	# Use a regex to match day_<number>.tres pattern exactly
	var regex := RegEx.new()
	regex.compile("^day_([0-9]+)\\.tres(\\.remap)?$")
	
	var found_days: Dictionary = {}  # n -> true
	var files: PackedStringArray = dir.get_files()
	
	for file_name: String in files:
		var result: RegExMatch = regex.search(file_name)
		if result:
			var n_str: String = result.get_string(1)
			var n: int = int(n_str)
			found_days[n] = true
	
	# Find highest contiguous n starting at 1
	var max_contiguous: int = 0
	for i in range(1, 1000):  # reasonable upper limit
		if found_days.has(i):
			max_contiguous = i
		else:
			break  # stop at first gap
	
	# Fall back to 1 if none found
	if max_contiguous == 0:
		max_contiguous = 1
	
	_total_known_days_cache = max_contiguous
	return _total_known_days_cache

func add_currency(amount: int) -> void:
	currency += amount
	EventBus.currency_changed.emit(currency)

func add_material(material_id: String, amount: int) -> void:
	materials[material_id] = materials.get(material_id, 0) + amount
	EventBus.materials_changed.emit(material_id, materials[material_id])

func spend_material(material_id: String, amount: int) -> bool:
	if materials.get(material_id, 0) < amount:
		return false
	materials[material_id] -= amount
	EventBus.materials_changed.emit(material_id, materials[material_id])
	return true

func _building_def(building_id: String) -> BuildingData:
	return load("res://data/buildings/%s.tres" % building_id) as BuildingData

func _level_index(building_id: String) -> int:
	return maxi(0, building_levels.get(building_id, 1) - 1)

func _value_for_level(values: Array, idx: int, fallback: Variant) -> Variant:
	if idx >= 0 and idx < values.size():
		return values[idx]
	return fallback

## Returns a building capacity/slot cap, preferring per-level values from BuildingData when present.
func capacity_for(building_id: String) -> int:
	var fallback_capacity: int = 2 + building_levels.get(building_id, 1)
	if building_id == "smelter":
		fallback_capacity = building_levels.get(building_id, 1)
	var def := _building_def(building_id)
	if def == null:
		return fallback_capacity
	return int(_value_for_level(def.capacity_by_level, _level_index(building_id), fallback_capacity))

func armoury_grid_size() -> Vector2i:
	var level := maxi(1, int(building_levels.get("armoury", 1)))
	var dimension := ARMOURY_GRID_BASE_SIZE + ARMOURY_GRID_SIZE_STEP * (level - 1)
	return Vector2i(dimension, dimension)

func has_armoury_storage_space_for(def_id: String) -> bool:
	var item_def: ItemData = load("res://data/items/%s.tres" % def_id)
	if item_def == null:
		return false
	var free_cell := _find_first_free_storage_cell_for_footprint(_item_footprint(item_def))
	return free_cell.x >= 0 and free_cell.y >= 0

func equipment_slot_ids_for_adventurer(def_id: String) -> Array[String]:
	var def: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
	if def == null:
		return LEGACY_DEFAULT_EQUIPMENT_SLOTS.duplicate()
	var slot_ids: Array[String] = []
	for raw_slot in def.equipment_slots:
		var slot_id := str(raw_slot).strip_edges()
		if slot_id == "" or slot_ids.has(slot_id):
			continue
		slot_ids.append(slot_id)
	if slot_ids.is_empty():
		return LEGACY_DEFAULT_EQUIPMENT_SLOTS.duplicate()
	return slot_ids

func normalize_armoury_state() -> void:
	for adventurer in owned_adventurers:
		var slot_ids: Array[String] = equipment_slot_ids_for_adventurer(str(adventurer.get("def_id", "")))
		var legacy_equipped: Dictionary = adventurer.get("equipped", {})
		var normalized_equipped: Dictionary = {}
		for slot_id in slot_ids:
			normalized_equipped[slot_id] = str(legacy_equipped.get(slot_id, ""))
		adventurer["equipped"] = normalized_equipped

	var equipped_item_ids: Dictionary = {}
	for adventurer in owned_adventurers:
		var equipped: Dictionary = adventurer.get("equipped", {})
		for slot_id in equipped:
			var item_instance_id := str(equipped[slot_id])
			if item_instance_id != "":
				equipped_item_ids[item_instance_id] = true

	for entry in owned_items:
		var instance_id := str(entry.get("instance_id", ""))
		if instance_id == "" or equipped_item_ids.get(instance_id, false):
			entry.erase("storage_cell")
			continue
		var cell := _find_first_free_storage_cell(instance_id)
		if cell.x < 0:
			entry.erase("storage_cell")
			continue
		_set_storage_cell(entry, cell)

func refit_armoury_storage() -> void:
	var equipped_item_ids: Dictionary = {}
	for adventurer in owned_adventurers:
		var equipped: Dictionary = adventurer.get("equipped", {})
		for slot_id in equipped:
			var item_instance_id := str(equipped[slot_id])
			if item_instance_id != "":
				equipped_item_ids[item_instance_id] = true

	for entry in owned_items:
		var instance_id := str(entry.get("instance_id", ""))
		if instance_id == "":
			continue
		if equipped_item_ids.get(instance_id, false):
			entry.erase("storage_cell")
			continue
		var current_cell := _storage_cell_for_entry(entry)
		if current_cell.x >= 0 and can_place_item_in_storage(instance_id, current_cell):
			continue
		entry.erase("storage_cell")
		var new_cell := _find_first_free_storage_cell(instance_id)
		if new_cell.x >= 0:
			_set_storage_cell(entry, new_cell)

func _empty_equipped_map_for_def(def_id: String) -> Dictionary:
	var equipped: Dictionary = {}
	for slot_id in equipment_slot_ids_for_adventurer(def_id):
		equipped[slot_id] = ""
	return equipped

func _item_slot_id(item_def: ItemData) -> String:
	if item_def == null:
		return ""
	return item_def.get_effective_slot_id()

func _item_footprint(item_def: ItemData) -> Vector2i:
	if item_def == null:
		return Vector2i(1, 1)
	return Vector2i(maxi(1, item_def.footprint.x), maxi(1, item_def.footprint.y))

func _storage_cell_for_entry(entry: Dictionary) -> Vector2i:
	var stored = entry.get("storage_cell", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return Vector2i(-1, -1)
	var x := int(stored.get("x", -1))
	var y := int(stored.get("y", -1))
	return Vector2i(x, y)

func _set_storage_cell(entry: Dictionary, cell: Vector2i) -> void:
	entry["storage_cell"] = {"x": cell.x, "y": cell.y}

func _entry_for_item_instance(item_instance_id: String) -> Dictionary:
	for entry in owned_items:
		if str(entry.get("instance_id", "")) == item_instance_id:
			return entry
	return {}

func _item_def_for_entry(entry: Dictionary) -> ItemData:
	return load("res://data/items/%s.tres" % str(entry.get("def_id", ""))) as ItemData

func _item_def_for_instance(item_instance_id: String) -> ItemData:
	var entry := _entry_for_item_instance(item_instance_id)
	if entry.is_empty():
		return null
	return _item_def_for_entry(entry)

func _find_item_holder(item_instance_id: String) -> Dictionary:
	for adventurer in owned_adventurers:
		var equipped: Dictionary = adventurer.get("equipped", {})
		for slot_id in equipped:
			if str(equipped[slot_id]) == item_instance_id:
				return {
					"adventurer_instance_id": str(adventurer.get("instance_id", "")),
					"slot_id": str(slot_id),
				}
	return {}

func _rect_inside_grid(cell: Vector2i, footprint: Vector2i) -> bool:
	var grid_size := armoury_grid_size()
	if cell.x < 0 or cell.y < 0:
		return false
	return cell.x + footprint.x <= grid_size.x and cell.y + footprint.y <= grid_size.y

func _rectangles_overlap(a_cell: Vector2i, a_size: Vector2i, b_cell: Vector2i, b_size: Vector2i) -> bool:
	var a_right := a_cell.x + a_size.x
	var a_bottom := a_cell.y + a_size.y
	var b_right := b_cell.x + b_size.x
	var b_bottom := b_cell.y + b_size.y
	return a_cell.x < b_right and a_right > b_cell.x and a_cell.y < b_bottom and a_bottom > b_cell.y

func can_place_item_in_storage(item_instance_id: String, cell: Vector2i) -> bool:
	var entry := _entry_for_item_instance(item_instance_id)
	if entry.is_empty():
		return false
	var item_def := _item_def_for_entry(entry)
	if item_def == null:
		return false
	var footprint := _item_footprint(item_def)
	return _can_place_footprint_at_cell(footprint, cell, item_instance_id)

func _find_first_free_storage_cell(item_instance_id: String) -> Vector2i:
	var entry := _entry_for_item_instance(item_instance_id)
	if entry.is_empty():
		return Vector2i(-1, -1)
	var item_def := _item_def_for_entry(entry)
	if item_def == null:
		return Vector2i(-1, -1)
	return _find_first_free_storage_cell_for_footprint(_item_footprint(item_def), item_instance_id)

func _find_first_free_storage_cell_for_footprint(footprint: Vector2i, ignored_item_instance_id: String = "") -> Vector2i:
	var grid_size := armoury_grid_size()
	for y in range(0, grid_size.y):
		for x in range(0, grid_size.x):
			var probe := Vector2i(x, y)
			if _can_place_footprint_at_cell(footprint, probe, ignored_item_instance_id):
				return probe
	return Vector2i(-1, -1)

func _can_place_footprint_at_cell(footprint: Vector2i, cell: Vector2i, ignored_item_instance_id: String = "") -> bool:
	if not _rect_inside_grid(cell, footprint):
		return false
	for other in owned_items:
		var other_instance_id := str(other.get("instance_id", ""))
		if other_instance_id == ignored_item_instance_id:
			continue
		var other_cell := _storage_cell_for_entry(other)
		if other_cell.x < 0:
			continue
		var other_def := _item_def_for_entry(other)
		if other_def == null:
			continue
		if _rectangles_overlap(cell, footprint, other_cell, _item_footprint(other_def)):
			return false
	return true

func tavern_refresh_interval_seconds() -> int:
	var fallback_interval: int = 21600
	var def := _building_def("tavern")
	if def == null:
		return fallback_interval
	return int(_value_for_level(def.tavern_refresh_seconds_by_level, _level_index("tavern"), fallback_interval))

## Spends currency and adds a new owned instance of the given AdventurerData id.
func recruit_adventurer(def_id: String) -> bool:
	var def: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
	if def == null or currency < def.recruit_cost:
		return false
	currency -= def.recruit_cost
	EventBus.currency_changed.emit(currency)
	owned_adventurers.append({
		"def_id": def_id,
		"instance_id": "%s_%d" % [def_id, Time.get_ticks_usec()],
		"level": 1,
		"equipped": _empty_equipped_map_for_def(def_id),
	})
	EventBus.adventurer_recruited.emit(def_id)
	return true

## Cost of the next Tavern reroll; rises each time it's used, resets when a Day is played.
func tavern_reroll_cost() -> int:
	return 20 + 20 * tavern_reroll_count

## Returns a shuffled random subset of pool_ids, capped to `size` entries.
func _random_subset(pool_ids: Array, size: int) -> Array:
	var duplicate: Array = pool_ids.duplicate()
	duplicate.shuffle()
	return duplicate.slice(0, mini(size, duplicate.size()))

## Spends gold to replace the Tavern's roster on demand, ahead of its natural refresh timer.
func reroll_tavern(pool_ids: Array) -> bool:
	var cost := tavern_reroll_cost()
	if currency < cost:
		return false
	currency -= cost
	EventBus.currency_changed.emit(currency)
	tavern_roster_ids = _random_subset(pool_ids, capacity_for("tavern"))
	tavern_reroll_count += 1
	return true

## Replaces the Tavern's roster with a fresh random subset, used by the natural refresh path.
func refresh_tavern_roster(pool_ids: Array) -> void:
	tavern_roster_ids = _random_subset(pool_ids, capacity_for("tavern"))

## Replaces the active TD roster, capped to the Quarters' current capacity.
func set_active_roster(def_ids: Array) -> void:
	active_roster_ids = def_ids.slice(0, capacity_for("quarters"))

## Spends currency and materials to raise a building's level by one.
func upgrade_building(building_id: String) -> bool:
	var def: BuildingData = load("res://data/buildings/%s.tres" % building_id)
	if def == null:
		return false
	var level: int = building_levels.get(building_id, 1)
	if level >= def.max_level:
		return false
	var idx: int = level - 1
	if idx < 0 or idx >= def.upgrade_currency_costs.size() or idx >= def.upgrade_material_costs.size():
		return false
	var currency_cost: int = def.upgrade_currency_costs[idx]
	var material_costs: Dictionary = def.upgrade_material_costs[idx]
	if currency < currency_cost:
		return false
	for material_id in material_costs:
		if materials.get(material_id, 0) < material_costs[material_id]:
			return false
	currency -= currency_cost
	EventBus.currency_changed.emit(currency)
	for material_id in material_costs:
		materials[material_id] -= material_costs[material_id]
		EventBus.materials_changed.emit(material_id, materials[material_id])
	building_levels[building_id] = level + 1
	EventBus.building_upgraded.emit(building_id, level + 1)
	return true

const SMELT_RECIPES := {
	"copper": {"output": "refined_copper", "seconds": 30},
	"iron": {"output": "refined_iron", "seconds": 60},
	"gold": {"output": "refined_gold", "seconds": 120},
}

## Number of concurrent smelting slots available, driven by Smelter BuildingData capacity vector.
func smelter_slot_capacity() -> int:
	return capacity_for("smelter")

func smelter_time_multiplier() -> float:
	var fallback_multiplier: float = 1.0
	var def := _building_def("smelter")
	if def == null:
		return fallback_multiplier
	return float(_value_for_level(def.smelter_time_multiplier_by_level, _level_index("smelter"), fallback_multiplier))

## Consumes one raw material and queues it for smelting into its refined output.
func start_smelting(material_id: String) -> bool:
	if not SMELT_RECIPES.has(material_id):
		return false
	if smelter_queue.size() >= smelter_slot_capacity():
		return false
	if not spend_material(material_id, 1):
		return false
	var recipe: Dictionary = SMELT_RECIPES[material_id]
	var duration_seconds: int = maxi(1, int(round(float(recipe["seconds"]) * smelter_time_multiplier())))
	smelter_queue.append({
		"material_id": material_id,
		"output_id": recipe["output"],
		"complete_unix": Time.get_unix_time_from_system() + duration_seconds,
	})
	EventBus.smelting_started.emit(material_id)
	return true

## Collects every finished smelting job, adding its output material to inventory.
func collect_ready_smelting() -> int:
	var now: float = Time.get_unix_time_from_system()
	var remaining: Array = []
	var collected: int = 0
	for entry in smelter_queue:
		if entry["complete_unix"] <= now:
			add_material(entry["output_id"], 1)
			EventBus.smelting_collected.emit(entry["output_id"], 1)
			collected += 1
		else:
			remaining.append(entry)
	smelter_queue = remaining
	return collected

## Spends materials to craft a new owned equipment instance of the given ItemData id.
func craft_item(def_id: String) -> bool:
	var def: ItemData = load("res://data/items/%s.tres" % def_id)
	if def == null:
		return false
	var smith_id: String = "weapon_smith" if def.slot == ItemData.ItemSlot.WEAPON else "armour_smith"
	if building_levels.get(smith_id, 1) < def.required_smith_level:
		return false
	var first_cell := _find_first_free_storage_cell_for_footprint(_item_footprint(def))
	if first_cell.x < 0:
		return false
	var next_instance_id := "%s_%d" % [def_id, Time.get_ticks_usec()]
	for material_id in def.recipe_materials:
		if materials.get(material_id, 0) < def.recipe_materials[material_id]:
			return false
	for material_id in def.recipe_materials:
		spend_material(material_id, def.recipe_materials[material_id])
	var crafted_entry := {
		"def_id": def_id,
		"instance_id": next_instance_id,
	}
	_set_storage_cell(crafted_entry, first_cell)
	owned_items.append(crafted_entry)
	EventBus.item_crafted.emit(def_id)
	return true

func place_item_in_storage(item_instance_id: String, cell: Vector2i) -> bool:
	var item_entry := _entry_for_item_instance(item_instance_id)
	if item_entry.is_empty():
		return false
	var old_cell := _storage_cell_for_entry(item_entry)
	item_entry.erase("storage_cell")
	if not can_place_item_in_storage(item_instance_id, cell):
		if old_cell.x >= 0:
			_set_storage_cell(item_entry, old_cell)
		return false
	var holder := _find_item_holder(item_instance_id)
	if not holder.is_empty():
		var holder_adventurer_id := str(holder.get("adventurer_instance_id", ""))
		var holder_slot_id := str(holder.get("slot_id", ""))
		for adventurer in owned_adventurers:
			if str(adventurer.get("instance_id", "")) == holder_adventurer_id:
				var equipped: Dictionary = adventurer.get("equipped", {})
				equipped[holder_slot_id] = ""
				adventurer["equipped"] = equipped
				EventBus.item_unequipped.emit(holder_adventurer_id, item_instance_id)
				break
	_set_storage_cell(item_entry, cell)
	return true

## Equips an owned item instance onto an adventurer slot, unequipping it from anywhere else first.
func equip_item_to_slot(adventurer_instance_id: String, item_instance_id: String, slot_id: String) -> bool:
	var item_entry := _entry_for_item_instance(item_instance_id)
	if item_entry.is_empty():
		return false
	var item_def := _item_def_for_entry(item_entry)
	if item_def == null:
		return false
	if _item_slot_id(item_def) != slot_id:
		return false

	var target_adventurer: Dictionary = {}
	for adventurer in owned_adventurers:
		if str(adventurer.get("instance_id", "")) == adventurer_instance_id:
			target_adventurer = adventurer
			break
	if target_adventurer.is_empty():
		return false

	var allowed_slots := equipment_slot_ids_for_adventurer(str(target_adventurer.get("def_id", "")))
	if not allowed_slots.has(slot_id):
		return false
	var target_equipped: Dictionary = target_adventurer.get("equipped", {})
	if not target_equipped.has(slot_id):
		target_equipped[slot_id] = ""

	var incoming_storage_cell := _storage_cell_for_entry(item_entry)
	var incoming_was_in_storage := incoming_storage_cell.x >= 0 and incoming_storage_cell.y >= 0
	if incoming_was_in_storage:
		item_entry.erase("storage_cell")

	var displaced_item_id := str(target_equipped.get(slot_id, ""))
	if displaced_item_id != "" and displaced_item_id != item_instance_id:
		var displaced_cell := _find_first_free_storage_cell(displaced_item_id)
		if displaced_cell.x < 0:
			if incoming_was_in_storage:
				_set_storage_cell(item_entry, incoming_storage_cell)
			return false
		var displaced_entry := _entry_for_item_instance(displaced_item_id)
		if displaced_entry.is_empty():
			if incoming_was_in_storage:
				_set_storage_cell(item_entry, incoming_storage_cell)
			return false
		_set_storage_cell(displaced_entry, displaced_cell)
		EventBus.item_unequipped.emit(adventurer_instance_id, displaced_item_id)

	var previous_holder := _find_item_holder(item_instance_id)
	if not previous_holder.is_empty():
		var previous_adventurer_id := str(previous_holder.get("adventurer_instance_id", ""))
		var previous_slot_id := str(previous_holder.get("slot_id", ""))
		for adventurer in owned_adventurers:
			if str(adventurer.get("instance_id", "")) != previous_adventurer_id:
				continue
			var equipped: Dictionary = adventurer.get("equipped", {})
			equipped[previous_slot_id] = ""
			adventurer["equipped"] = equipped
			break

	item_entry.erase("storage_cell")
	target_equipped[slot_id] = item_instance_id
	target_adventurer["equipped"] = target_equipped
	EventBus.item_equipped.emit(adventurer_instance_id, item_instance_id)
	return true

## Equips an owned item instance using its default slot id.
func equip_item(adventurer_instance_id: String, item_instance_id: String) -> bool:
	var item_def := _item_def_for_instance(item_instance_id)
	if item_def == null:
		return false
	return equip_item_to_slot(adventurer_instance_id, item_instance_id, _item_slot_id(item_def))

func unequip_item_to_storage_cell(adventurer_instance_id: String, slot: String, cell: Vector2i) -> bool:
	var target_adventurer: Dictionary = {}
	for adventurer in owned_adventurers:
		if str(adventurer.get("instance_id", "")) == adventurer_instance_id:
			target_adventurer = adventurer
			break
	if target_adventurer.is_empty():
		return false
	var equipped: Dictionary = target_adventurer.get("equipped", {})
	if not equipped.has(slot):
		return false
	var item_instance_id := str(equipped.get(slot, ""))
	if item_instance_id == "":
		return false
	if not can_place_item_in_storage(item_instance_id, cell):
		return false
	equipped[slot] = ""
	target_adventurer["equipped"] = equipped
	var item_entry := _entry_for_item_instance(item_instance_id)
	if item_entry.is_empty():
		return false
	_set_storage_cell(item_entry, cell)
	EventBus.item_unequipped.emit(adventurer_instance_id, item_instance_id)
	return true

## Clears whatever item is equipped in the given slot and places it in first available storage cell.
func unequip_item(adventurer_instance_id: String, slot: String) -> bool:
	var target_adventurer: Dictionary = {}
	for adventurer in owned_adventurers:
		if str(adventurer.get("instance_id", "")) == adventurer_instance_id:
			target_adventurer = adventurer
			break
	if target_adventurer.is_empty():
		return false
	var equipped: Dictionary = target_adventurer.get("equipped", {})
	if not equipped.has(slot):
		return false
	var item_instance_id := str(equipped.get(slot, ""))
	if item_instance_id == "":
		return false
	var first_cell := _find_first_free_storage_cell(item_instance_id)
	if first_cell.x < 0:
		return false
	equipped[slot] = ""
	target_adventurer["equipped"] = equipped
	var item_entry := _entry_for_item_instance(item_instance_id)
	if item_entry.is_empty():
		return false
	_set_storage_cell(item_entry, first_cell)
	EventBus.item_unequipped.emit(adventurer_instance_id, item_instance_id)
	return true
