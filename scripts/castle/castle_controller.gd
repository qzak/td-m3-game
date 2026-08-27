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
@onready var war_room_panel: Control = $UI/HUD/WarRoomPanel
@onready var workshop_panel: Control = $UI/HUD/WorkshopPanel
@onready var tavern_button: Button = $UI/HUD/Controls/TavernButton
@onready var quarters_button: Button = $UI/HUD/Controls/QuartersButton
@onready var smelter_button: Button = $UI/HUD/Controls/SmelterButton
@onready var weapon_smith_button: Button = $UI/HUD/Controls/WeaponSmithButton
@onready var armour_smith_button: Button = $UI/HUD/Controls/ArmourSmithButton
@onready var armoury_button: Button = $UI/HUD/Controls/ArmouryButton
@onready var towers_button: Button = $UI/HUD/Controls/TowersButton
@onready var war_room_button: Button = $UI/HUD/Controls/WarRoomButton
@onready var workshop_button: Button = $UI/HUD/Controls/WorkshopButton
@onready var mine_button: Button = $UI/HUD/Controls/MineButton
@onready var controls: GridContainer = $UI/HUD/Controls
@onready var close_panel_button: Button = $UI/HUD/ClosePanelButton
@onready var top_resource_bar: Control = $UI/HUD/TopResourceBar
@onready var objective_label: Label = $UI/HUD/ObjectiveLabel

var all_panels: Array[Control] = []

func _ready() -> void:
	SaveManager.load_game()
	top_resource_bar.set_context("castle")

	all_panels = [tavern_panel, quarters_panel, smelter_panel, weapon_smith_panel, armour_smith_panel, armoury_panel, towers_panel, war_room_panel, workshop_panel]

	tavern_button.pressed.connect(func(): _show_panel(tavern_panel))
	quarters_button.pressed.connect(func(): _show_panel(quarters_panel))
	smelter_button.pressed.connect(func(): _show_panel(smelter_panel))
	weapon_smith_button.pressed.connect(func(): _show_panel(weapon_smith_panel))
	armour_smith_button.pressed.connect(func(): _show_panel(armour_smith_panel))
	armoury_button.pressed.connect(func(): _show_panel(armoury_panel))
	towers_button.pressed.connect(func(): _show_panel(towers_panel))
	war_room_button.pressed.connect(func(): _show_panel(war_room_panel))
	workshop_button.pressed.connect(func(): _show_panel(workshop_panel))
	mine_button.pressed.connect(_on_mine_pressed)
	close_panel_button.pressed.connect(func(): _show_panel(null))
	war_room_panel.day_start_requested.connect(_on_start_day_pressed)
	EventBus.progression_changed.connect(func(_reason): _refresh_progression_ui())

	_show_panel(null)
	_refresh_progression_ui()

## Shows exactly one building panel (or none, if panel is null) and refreshes it so its
## contents rebuild against current GameState whenever it's opened.
func _show_panel(panel: Control) -> void:
	for p in all_panels:
		p.visible = p == panel
	var focus_mode := panel != null
	controls.visible = not focus_mode
	close_panel_button.visible = focus_mode
	if panel == weapon_smith_panel or panel == armour_smith_panel or panel == smelter_panel:
		top_resource_bar.set_context("smith")
	else:
		top_resource_bar.set_context("castle")
	if panel != null and panel.has_method("refresh"):
		panel.refresh()

func _on_start_day_pressed(day_index: int) -> void:
	if not GameState.can_start_day(day_index):
		_refresh_progression_ui()
		return
	GameState.selected_day_index = day_index
	get_tree().change_scene_to_file("res://scenes/tower_defense/td_battle.tscn")

func _on_mine_pressed() -> void:
	if not GameState.can_enter_mine():
		_refresh_progression_ui()
		return
	GameState.mark_mine_intro_seen()
	get_tree().change_scene_to_file("res://scenes/match3/mine.tscn")

func _refresh_progression_ui() -> void:
	objective_label.text = GameState.castle_objective_text()
	var workshop_open := bool(GameState.progression.get("workshop_unlocked", false))
	workshop_button.disabled = not workshop_open
	if workshop_open:
		workshop_button.text = "Workshop"
	else:
		workshop_button.text = "Workshop (Locked)"
	if GameState.can_enter_mine():
		mine_button.text = "Enter Mine"
		mine_button.disabled = false
	else:
		mine_button.text = "Enter Mine (Win Day 1)"
		mine_button.disabled = true
