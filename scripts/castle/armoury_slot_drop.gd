extends PanelContainer
class_name ArmourySlotDrop

signal item_dropped(payload: Dictionary, adventurer_instance_id: String, slot_id: String)

var adventurer_instance_id: String = ""
var slot_id: String = ""

func configure(target_adventurer_instance_id: String, target_slot_id: String) -> void:
	adventurer_instance_id = target_adventurer_instance_id
	slot_id = target_slot_id

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return str(data.get("kind", "")) == "armoury_item"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(data, adventurer_instance_id, slot_id)
