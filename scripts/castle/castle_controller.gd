extends Node2D
class_name CastleController
## Hub scene: load the save, and switch between Tavern/Quarters panels or start a Day.

@onready var currency_label: Label = $UI/HUD/CurrencyLabel
@onready var tavern_panel: TavernController = $UI/HUD/TavernPanel
@onready var quarters_panel: QuartersController = $UI/HUD/QuartersPanel
@onready var tavern_button: Button = $UI/HUD/Controls/TavernButton
@onready var quarters_button: Button = $UI/HUD/Controls/QuartersButton
@onready var start_day_button: Button = $UI/HUD/Controls/StartDayButton

func _ready() -> void:
	SaveManager.load_game()

	tavern_button.pressed.connect(func(): _show_panel(tavern_panel))
	quarters_button.pressed.connect(func(): _show_panel(quarters_panel))
	start_day_button.pressed.connect(_on_start_day_pressed)
	EventBus.currency_changed.connect(_on_currency_changed)

	_show_panel(null)
	_update_currency_label()

func _show_panel(panel: Control) -> void:
	tavern_panel.visible = panel == tavern_panel
	quarters_panel.visible = panel == quarters_panel
	if panel == tavern_panel:
		tavern_panel.refresh()
	elif panel == quarters_panel:
		quarters_panel.refresh()

func _on_start_day_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tower_defense/td_battle.tscn")

func _on_currency_changed(_new_amount: int) -> void:
	_update_currency_label()

func _update_currency_label() -> void:
	currency_label.text = "Gold: %d" % GameState.currency
