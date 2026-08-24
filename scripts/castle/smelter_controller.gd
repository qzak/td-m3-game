extends Control
class_name SmelterController
## Lets the player smelt raw materials into refined materials on a queued timer.

const RAW_MATERIALS: Array[String] = ["copper", "iron", "gold"]

@onready var material_list: VBoxContainer = $MaterialList
@onready var queue_list: VBoxContainer = $QueueList
@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

func _ready() -> void:
	upgrade_row.building_id = "smelter"
	upgrade_row.refresh()

	_build_rows()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_on_tick)
	add_child(timer)

func refresh() -> void:
	_build_rows()
	upgrade_row.refresh()

func _on_tick() -> void:
	GameState.collect_ready_smelting()
	_build_rows()

func _build_rows() -> void:
	for child in material_list.get_children():
		child.queue_free()
	for child in queue_list.get_children():
		child.queue_free()

	for material_id in RAW_MATERIALS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s: %d owned" % [material_id, GameState.materials.get(material_id, 0)]
		label.custom_minimum_size = Vector2(220, 0)
		row.add_child(label)

		var button := Button.new()
		button.text = "Smelt"
		button.disabled = GameState.materials.get(material_id, 0) < 1 or GameState.smelter_queue.size() >= GameState.smelter_slot_capacity()
		button.pressed.connect(_on_smelt_pressed.bind(material_id))
		row.add_child(button)

		material_list.add_child(row)

	var slots_label := Label.new()
	slots_label.text = "Slots: %d / %d" % [GameState.smelter_queue.size(), GameState.smelter_slot_capacity()]
	queue_list.add_child(slots_label)

	for entry in GameState.smelter_queue:
		var row := HBoxContainer.new()
		var label := Label.new()
		var seconds_left: int = max(0, int(entry["complete_unix"] - Time.get_unix_time_from_system()))
		label.text = "%s -> %s: %ds left" % [entry["material_id"], entry["output_id"], seconds_left]
		row.add_child(label)
		queue_list.add_child(row)

func _on_smelt_pressed(material_id: String) -> void:
	GameState.start_smelting(material_id)
	_build_rows()
