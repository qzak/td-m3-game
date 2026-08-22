extends Node
## Holds the player's persistent save data for the current session.
## Loaded/saved via SaveManager. Systems read/write through this singleton.

var currency: int = 0
var materials: Dictionary = {}  # material_id (String) -> amount (int)

var owned_adventurers: Array = []  # Array[Dictionary] instance data (id, level, equipped items)
var active_roster_ids: Array = []  # adventurer instance ids selected in Quarters

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

var unlocked_day_index: int = 0
var mine_depth: int = 0

func _ready() -> void:
	EventBus.day_started.connect(func(_idx): tavern_reroll_count = 0)

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
		"equipped": [],
	})
	EventBus.adventurer_recruited.emit(def_id)
	return true

## Cost of the next Tavern reroll; rises each time it's used, resets when a Day is played.
func tavern_reroll_cost() -> int:
	return 20 + 20 * tavern_reroll_count

## Spends gold to replace the Tavern's roster on demand, ahead of its natural refresh timer.
func reroll_tavern(pool_ids: Array) -> bool:
	var cost := tavern_reroll_cost()
	if currency < cost:
		return false
	currency -= cost
	EventBus.currency_changed.emit(currency)
	tavern_roster_ids = pool_ids.duplicate()
	tavern_reroll_count += 1
	return true

## Replaces the active TD roster, capped to the Quarters' current capacity.
func set_active_roster(def_ids: Array) -> void:
	active_roster_ids = def_ids.slice(0, capacity_for("quarters"))
