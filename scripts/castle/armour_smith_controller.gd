extends SmithControllerBase
class_name ArmourSmithController

func _ready() -> void:
	building_id = "armour_smith"
	recipe_ids = ["leather_vest", "chainmail", "gilded_plate"]
	super._ready()
