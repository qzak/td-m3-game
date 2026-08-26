extends Control
class_name QuartersController
## Lets the player pick which owned adventurers are active for the next TD battle.

@onready var active_list: VBoxContainer = $ActiveList
@onready var available_list: VBoxContainer = $AvailableList
@onready var capacity_label: Label = $CapacityLabel
@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

func _ready() -> void:
	upgrade_row.building_id = "quarters"
	upgrade_row.refresh()
	EventBus.building_upgraded.connect(_on_building_upgraded)
	_build_rows()

func refresh() -> void:
	_build_rows()
	upgrade_row.refresh()

func _build_rows() -> void:
	for child in active_list.get_children():
		child.queue_free()
	for child in available_list.get_children():
		child.queue_free()

	var capacity := GameState.capacity_for("quarters")
	capacity_label.text = "Active roster: %d / %d" % [GameState.active_roster_ids.size(), capacity]

	for entry in GameState.owned_adventurers:
		var def_id: String = entry.get("def_id")
		var def: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
		if def == null:
			continue

		var is_active := GameState.active_roster_ids.has(def_id)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = def.display_name
		label.custom_minimum_size = Vector2(160, 0)
		row.add_child(label)

		var button := Button.new()
		if is_active:
			button.text = "Remove"
			button.pressed.connect(_on_remove_pressed.bind(def_id))
		else:
			button.text = "Add"
			button.disabled = GameState.active_roster_ids.size() >= capacity
			button.pressed.connect(_on_add_pressed.bind(def_id))
		row.add_child(button)

		if is_active:
			active_list.add_child(row)
		else:
			available_list.add_child(row)

func _on_add_pressed(def_id: String) -> void:
	var capacity := GameState.capacity_for("quarters")
	var roster: Array = GameState.active_roster_ids.duplicate()
	if roster.size() >= capacity or roster.has(def_id):
		_build_rows()
		return
	roster.append(def_id)
	GameState.set_active_roster(roster)
	_build_rows()

func _on_remove_pressed(def_id: String) -> void:
	var roster: Array = GameState.active_roster_ids.duplicate()
	roster.erase(def_id)
	GameState.set_active_roster(roster)
	_build_rows()

func _on_building_upgraded(building_id: String, _new_level: int) -> void:
	if building_id != "quarters":
		return
	_build_rows()
