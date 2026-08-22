extends Control
class_name QuartersController
## Lets the player pick which owned adventurers are active for the next TD battle.

@onready var roster_list: VBoxContainer = $RosterList
@onready var capacity_label: Label = $CapacityLabel

func _ready() -> void:
	_build_rows()

func refresh() -> void:
	_build_rows()

func _build_rows() -> void:
	for child in roster_list.get_children():
		child.queue_free()

	var capacity := GameState.capacity_for("quarters")
	capacity_label.text = "Active roster: %d / %d" % [GameState.active_roster_ids.size(), capacity]

	for entry in GameState.owned_adventurers:
		var def_id: String = entry.get("def_id")
		var def: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
		if def == null:
			continue

		var row := HBoxContainer.new()
		var checkbox := CheckBox.new()
		checkbox.text = def.display_name
		checkbox.button_pressed = GameState.active_roster_ids.has(def_id)
		checkbox.toggled.connect(_on_toggled.bind(def_id))
		row.add_child(checkbox)
		roster_list.add_child(row)

func _on_toggled(pressed: bool, def_id: String) -> void:
	var capacity := GameState.capacity_for("quarters")
	var roster: Array = GameState.active_roster_ids.duplicate()
	if pressed:
		if roster.size() >= capacity:
			_build_rows()  # revert the checkbox, capacity is full
			return
		if not roster.has(def_id):
			roster.append(def_id)
	else:
		roster.erase(def_id)

	GameState.set_active_roster(roster)
	_build_rows()
