extends Control
class_name WarRoomController

signal day_start_requested(day_index: int)

@onready var day_list: VBoxContainer = $DayList

func _ready() -> void:
	_build_day_list()

func refresh() -> void:
	_build_day_list()

func _build_day_list() -> void:
	for child in day_list.get_children():
		child.queue_free()
	for day_index in range(1, GameState.total_known_days() + 1):
		var button := Button.new()
		var locked: bool = day_index > GameState.unlocked_day_index
		button.text = "Start Day %d" % day_index if not locked else "Start Day %d (Locked)" % day_index
		button.disabled = locked
		button.pressed.connect(_on_start_day_pressed.bind(day_index))
		day_list.add_child(button)

func _on_start_day_pressed(day_index: int) -> void:
	day_start_requested.emit(day_index)
