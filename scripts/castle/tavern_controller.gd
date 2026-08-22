extends Control
class_name TavernController
## Recruits new adventurers into GameState.owned_adventurers on a real-time refresh timer.

@export var pool_ids: Array[String] = ["swordsman", "archer", "mage"]
@export var refresh_interval_seconds: int = 21600  # 6 real hours

@onready var roster_list: VBoxContainer = $RosterList

func _ready() -> void:
	_refresh_if_needed()
	_build_rows()

func refresh() -> void:
	_refresh_if_needed()
	_build_rows()

func _refresh_if_needed() -> void:
	var now := Time.get_unix_time_from_system()
	if now >= GameState.tavern_next_refresh_unix:
		GameState.tavern_roster_ids = pool_ids.duplicate()
		GameState.tavern_next_refresh_unix = now + refresh_interval_seconds

func _build_rows() -> void:
	for child in roster_list.get_children():
		child.queue_free()

	for def_id in GameState.tavern_roster_ids:
		var def: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
		if def == null:
			continue

		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s — %d gold" % [def.display_name, def.recruit_cost]
		label.custom_minimum_size = Vector2(220, 0)
		row.add_child(label)

		var button := Button.new()
		var already_owned := _is_owned(def_id)
		button.text = "Owned" if already_owned else "Sign Contract"
		button.disabled = already_owned or GameState.currency < def.recruit_cost
		button.pressed.connect(_on_sign_pressed.bind(def_id))
		row.add_child(button)

		roster_list.add_child(row)

func _is_owned(def_id: String) -> bool:
	for entry in GameState.owned_adventurers:
		if entry.get("def_id") == def_id:
			return true
	return false

func _on_sign_pressed(def_id: String) -> void:
	if GameState.recruit_adventurer(def_id):
		_build_rows()
