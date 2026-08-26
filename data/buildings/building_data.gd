extends Resource
class_name BuildingData
## Per-level costs and effects for a single castle building.

@export var id: String
@export var display_name: String
@export var max_level: int = 5
@export var upgrade_material_costs: Array[Dictionary] = []  # index = level -> {material_id: amount}
@export var upgrade_currency_costs: Array[int] = []  # index = level -> currency cost
@export var capacity_by_level: Array[int] = []  # index = level-1 -> capacity/slots cap
@export var tavern_refresh_seconds_by_level: Array[int] = []  # index = level-1 -> natural refresh timer
@export var smelter_time_multiplier_by_level: Array[float] = []  # index = level-1 -> recipe duration multiplier
