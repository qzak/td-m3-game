extends Node2D
class_name CastleController
## Hub scene: load the save, and switch between Tavern/Quarters panels or start a Day.

@onready var tavern_panel: TavernController = $UI/HUD/TavernPanel
@onready var quarters_panel: QuartersController = $UI/HUD/QuartersPanel
@onready var smelter_panel: SmelterController = $UI/HUD/SmelterPanel
@onready var weapon_smith_panel: WeaponSmithController = $UI/HUD/WeaponSmithPanel
@onready var armour_smith_panel: ArmourSmithController = $UI/HUD/ArmourSmithPanel
@onready var armoury_panel: ArmouryController = $UI/HUD/ArmouryPanel
@onready var towers_panel: TowersPanel = $UI/HUD/TowersPanel
@onready var tavern_button: Button = $UI/HUD/Controls/TavernButton
@onready var quarters_button: Button = $UI/HUD/Controls/QuartersButton
@onready var smelter_button: Button = $UI/HUD/Controls/SmelterButton
@onready var weapon_smith_button: Button = $UI/HUD/Controls/WeaponSmithButton
@onready var armour_smith_button: Button = $UI/HUD/Controls/ArmourSmithButton
@onready var armoury_button: Button = $UI/HUD/Controls/ArmouryButton
@onready var towers_button: Button = $UI/HUD/Controls/TowersButton
@onready var mine_button: Button = $UI/HUD/Controls/MineButton
@onready var day_list: VBoxContainer = $UI/HUD/DayList

var all_panels: Array[Control] = []

func _ready() -> void:
	SaveManager.load_game()

	all_panels = [tavern_panel, quarters_panel, smelter_panel, weapon_smith_panel, armour_smith_panel, armoury_panel, towers_panel]

	tavern_button.pressed.connect(func(): _show_panel(tavern_panel))
	quarters_button.pressed.connect(func(): _show_panel(quarters_panel))
	smelter_button.pressed.connect(func(): _show_panel(smelter_panel))
	weapon_smith_button.pressed.connect(func(): _show_panel(weapon_smith_panel))
	armour_smith_button.pressed.connect(func(): _show_panel(armour_smith_panel))
	armoury_button.pressed.connect(func(): _show_panel(armoury_panel))
	towers_button.pressed.connect(func(): _show_panel(towers_panel))
	mine_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/match3/mine.tscn"))

	_show_panel(null)
	_build_day_list()

## Shows exactly one building panel (or none, if panel is null) and refreshes it so its
## contents rebuild against current GameState whenever it's opened.
func _show_panel(panel: Control) -> void:
	for p in all_panels:
		p.visible = p == panel
	if panel != null and panel.has_method("refresh"):
		panel.refresh()

## Builds the list of "Start Day N" buttons, locking any days beyond what's been unlocked.
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
	GameState.selected_day_index = day_index
	get_tree().change_scene_to_file("res://scenes/tower_defense/td_battle.tscn")
