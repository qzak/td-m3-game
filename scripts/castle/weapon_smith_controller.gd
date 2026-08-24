extends SmithControllerBase
class_name WeaponSmithController

func _ready() -> void:
	building_id = "weapon_smith"
	recipe_ids = ["iron_sword", "steel_blade", "golden_edge"]
	super._ready()
