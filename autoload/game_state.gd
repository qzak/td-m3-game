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

var smelter_queue: Array = []  # Array[Dictionary] (item_id, complete_unix)

var unlocked_day_index: int = 0
var mine_depth: int = 0

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
