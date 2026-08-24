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
}

var tavern_roster_ids: Array = []
var tavern_next_refresh_unix: int = 0
var tavern_reroll_count: int = 0  # resets to 0 each time a Day is played

var smelter_queue: Array = []  # Array[Dictionary] (item_id, complete_unix)

var owned_items: Array = []  # Array[Dictionary] {def_id, instance_id}

var unlocked_day_index: int = 1
var selected_day_index: int = 1
var mine_depth: int = 0
var mine_board_state: Array = []

func _ready() -> void:
	EventBus.day_started.connect(func(_idx): tavern_reroll_count = 0)
	EventBus.day_won.connect(_on_day_won)

func _on_day_won(day_index: int) -> void:
	unlocked_day_index = maxi(unlocked_day_index, day_index + 1)

func total_known_days() -> int:
	return 2

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

## Base + per-level slot count for a roster-capacity building (e.g. Quarters).
func capacity_for(building_id: String) -> int:
	return 2 + building_levels.get(building_id, 1)

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
		"equipped": {"weapon": "", "armour": ""},
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

## Number of concurrent smelting slots available, based on the Smelter's level.
func smelter_slot_capacity() -> int:
	return building_levels.get("smelter", 1)

## Consumes one raw material and queues it for smelting into its refined output.
func start_smelting(material_id: String) -> bool:
	if not SMELT_RECIPES.has(material_id):
		return false
	if smelter_queue.size() >= smelter_slot_capacity():
		return false
	if not spend_material(material_id, 1):
		return false
	var recipe: Dictionary = SMELT_RECIPES[material_id]
	smelter_queue.append({
		"material_id": material_id,
		"output_id": recipe["output"],
		"complete_unix": Time.get_unix_time_from_system() + recipe["seconds"],
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
	if owned_items.size() >= capacity_for("armoury"):
		return false
	for material_id in def.recipe_materials:
		if materials.get(material_id, 0) < def.recipe_materials[material_id]:
			return false
	for material_id in def.recipe_materials:
		spend_material(material_id, def.recipe_materials[material_id])
	owned_items.append({
		"def_id": def_id,
		"instance_id": "%s_%d" % [def_id, Time.get_ticks_usec()],
	})
	EventBus.item_crafted.emit(def_id)
	return true

## Equips an owned item instance onto an adventurer, unequipping it from anywhere else first.
func equip_item(adventurer_instance_id: String, item_instance_id: String) -> bool:
	var item_entry: Dictionary = {}
	for entry in owned_items:
		if entry["instance_id"] == item_instance_id:
			item_entry = entry
			break
	if item_entry.is_empty():
		return false
	var def: ItemData = load("res://data/items/%s.tres" % item_entry["def_id"])
	if def == null:
		return false
	var slot_key: String = "weapon" if def.slot == ItemData.ItemSlot.WEAPON else "armour"
	for adventurer in owned_adventurers:
		if adventurer["equipped"]["weapon"] == item_instance_id:
			adventurer["equipped"]["weapon"] = ""
		if adventurer["equipped"]["armour"] == item_instance_id:
			adventurer["equipped"]["armour"] = ""
	var target_adventurer: Dictionary = {}
	for adventurer in owned_adventurers:
		if adventurer["instance_id"] == adventurer_instance_id:
			target_adventurer = adventurer
			break
	if target_adventurer.is_empty():
		return false
	target_adventurer["equipped"][slot_key] = item_instance_id
	EventBus.item_equipped.emit(adventurer_instance_id, item_instance_id)
	return true

## Clears whatever item is equipped in the given slot ("weapon" or "armour") for an adventurer.
func unequip_item(adventurer_instance_id: String, slot: String) -> bool:
	if slot != "weapon" and slot != "armour":
		return false
	var target_adventurer: Dictionary = {}
	for adventurer in owned_adventurers:
		if adventurer["instance_id"] == adventurer_instance_id:
			target_adventurer = adventurer
			break
	if target_adventurer.is_empty():
		return false
	var item_instance_id: String = target_adventurer["equipped"][slot]
	if item_instance_id == "":
		return false
	target_adventurer["equipped"][slot] = ""
	EventBus.item_unequipped.emit(adventurer_instance_id, item_instance_id)
	return true
