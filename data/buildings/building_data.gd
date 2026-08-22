extends Resource
class_name BuildingData
## Per-level costs and effects for a single castle building.

@export var id: String
@export var display_name: String
@export var max_level: int = 5
@export var upgrade_material_costs: Array[Dictionary] = []  # index = level -> {material_id: amount}
@export var upgrade_currency_costs: Array[int] = []  # index = level -> currency cost
