extends Control
class_name WarRoomController

signal day_start_requested(day_index: int)

@onready var day_list: VBoxContainer = $DayList
@onready var last_result_label: Label = $LastResultLabel

func _ready() -> void:
	_build_day_list()

func refresh() -> void:
	_build_day_list()

func _build_day_list() -> void:
	_refresh_last_result()
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

func _refresh_last_result() -> void:
	var result: Dictionary = GameState.last_day_result
	if result.is_empty() or not result.get("played", false):
		last_result_label.text = "Last Day Result: none yet"
		return
	var day_index: int = int(result.get("day_index", 0))
	var did_win: bool = bool(result.get("did_win", false))
	var currency_delta: int = int(result.get("currency_delta", 0))
	var reward: int = int(result.get("completion_reward", 0))
	var unlocked_after: int = int(result.get("unlocked_day_after", GameState.unlocked_day_index))
	if did_win:
		var unlock_text := " Day %d unlocked." % unlocked_after if unlocked_after > day_index else " No new day unlocked."
		last_result_label.text = "Last Day Result: Day %d cleared. Coins %s (bonus %s).%s" % [day_index, _signed_int(currency_delta), _signed_int(reward), unlock_text]
	else:
		last_result_label.text = "Last Day Result: Day %d failed (Castle HP hit 0). Coins %s." % [day_index, _signed_int(currency_delta)]

func _signed_int(value: int) -> String:
	return "+%d" % value if value >= 0 else str(value)
