extends Node2D
class_name CastleController
## Hub scene: load the save, and switch between Tavern/Quarters panels or start a Day.

const CASTLE_BUTTON_ICON_ROOT := "res://assets/sprites/castle/buildings/buttons"
const BUTTON_THEME := preload("res://scripts/ui/button_theme_factory.gd")

@onready var tavern_panel: TavernController = $UI/HUD/SafeArea/MainColumns/PanelHost/TavernPanel
@onready var quarters_panel: QuartersController = $UI/HUD/SafeArea/MainColumns/PanelHost/QuartersPanel
@onready var smelter_panel: SmelterController = $UI/HUD/SafeArea/MainColumns/PanelHost/SmelterPanel
@onready var weapon_smith_panel: WeaponSmithController = $UI/HUD/SafeArea/MainColumns/PanelHost/WeaponSmithPanel
@onready var armour_smith_panel: ArmourSmithController = $UI/HUD/SafeArea/MainColumns/PanelHost/ArmourSmithPanel
@onready var armoury_panel: ArmouryController = $UI/HUD/SafeArea/MainColumns/PanelHost/ArmouryPanel
@onready var towers_panel: TowersPanel = $UI/HUD/SafeArea/MainColumns/PanelHost/TowersPanel
@onready var war_room_panel: Control = $UI/HUD/SafeArea/MainColumns/PanelHost/WarRoomPanel
@onready var workshop_panel: Control = $UI/HUD/SafeArea/MainColumns/PanelHost/WorkshopPanel
@onready var library_panel: Control = $UI/HUD/SafeArea/MainColumns/PanelHost/LibraryPanel
@onready var tavern_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/TavernButton
@onready var quarters_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/QuartersButton
@onready var smelter_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/SmelterButton
@onready var weapon_smith_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/WeaponSmithButton
@onready var armour_smith_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/ArmourSmithButton
@onready var armoury_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/ArmouryButton
@onready var towers_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/TowersButton
@onready var war_room_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/WarRoomButton
@onready var workshop_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/WorkshopButton
@onready var library_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/LibraryButton
@onready var mine_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls/MineButton
@onready var controls: GridContainer = $UI/HUD/SafeArea/MainColumns/Sidebar/Controls
@onready var close_panel_button: Button = $UI/HUD/SafeArea/MainColumns/Sidebar/ClosePanelButton
@onready var top_resource_bar: Control = $UI/HUD/TopResourceBar
@onready var objective_label: Label = $UI/HUD/SafeArea/MainColumns/Sidebar/ObjectiveLabel
@onready var safe_area: MarginContainer = $UI/HUD/SafeArea
@onready var side_bar: VBoxContainer = $UI/HUD/SafeArea/MainColumns/Sidebar
@onready var hud: Control = $UI/HUD

var all_panels: Array[Control] = []
const TOP_BAR_HEIGHT := 56.0
const CONTENT_GAP := 12.0
const SAFE_SIDE_PADDING := 16.0
const SAFE_BOTTOM_PADDING := 16.0

func _ready() -> void:
	SaveManager.load_game()
	BUTTON_THEME.apply_to(hud)
	top_resource_bar.set_context("castle")
	_apply_safe_area_layout()
	DisplayLayout.viewport_size_changed.connect(_on_viewport_size_changed)

	all_panels = [tavern_panel, quarters_panel, smelter_panel, weapon_smith_panel, armour_smith_panel, armoury_panel, towers_panel, war_room_panel, workshop_panel, library_panel]

	tavern_button.pressed.connect(func(): _show_panel(tavern_panel))
	quarters_button.pressed.connect(func(): _show_panel(quarters_panel))
	smelter_button.pressed.connect(func(): _show_panel(smelter_panel))
	weapon_smith_button.pressed.connect(func(): _show_panel(weapon_smith_panel))
	armour_smith_button.pressed.connect(func(): _show_panel(armour_smith_panel))
	armoury_button.pressed.connect(func(): _show_panel(armoury_panel))
	towers_button.pressed.connect(func(): _show_panel(towers_panel))
	war_room_button.pressed.connect(func(): _show_panel(war_room_panel))
	workshop_button.pressed.connect(func(): _show_panel(workshop_panel))
	library_button.pressed.connect(func(): _show_panel(library_panel))
	mine_button.pressed.connect(_on_mine_pressed)
	close_panel_button.pressed.connect(func(): _show_panel(null))
	war_room_panel.day_start_requested.connect(_on_start_day_pressed)
	EventBus.progression_changed.connect(func(_reason): _refresh_progression_ui())
	_apply_button_icons()

	_show_panel(null)
	_refresh_progression_ui()


func _on_viewport_size_changed(_viewport_size: Vector2) -> void:
	_apply_safe_area_layout()


func _apply_safe_area_layout() -> void:
	var margins: Dictionary = DisplayLayout.safe_area_margins()
	var safe_left: float = float(margins.get("left", 0.0))
	var safe_top: float = float(margins.get("top", 0.0))
	var safe_right: float = float(margins.get("right", 0.0))
	var safe_bottom: float = float(margins.get("bottom", 0.0))

	top_resource_bar.offset_left = safe_left
	top_resource_bar.offset_top = safe_top
	top_resource_bar.offset_right = -safe_right
	top_resource_bar.offset_bottom = safe_top + TOP_BAR_HEIGHT

	safe_area.offset_left = safe_left + SAFE_SIDE_PADDING
	safe_area.offset_top = safe_top + TOP_BAR_HEIGHT + CONTENT_GAP
	safe_area.offset_right = -(safe_right + SAFE_SIDE_PADDING)
	safe_area.offset_bottom = -(safe_bottom + SAFE_BOTTOM_PADDING)
	var viewport_width := DisplayLayout.current_viewport_size().x
	side_bar.custom_minimum_size.x = clampf(viewport_width * 0.23, 220.0, 320.0)

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
	library_button.text = "Library"
	library_button.disabled = false
	if GameState.can_enter_mine():
		mine_button.text = "Enter Mine"
		mine_button.disabled = false
	else:
		mine_button.text = "Enter Mine (Win Day 1)"
		mine_button.disabled = true

func _apply_button_icons() -> void:
	_set_button_icon_if_exists(tavern_button, "tavern_button_icon.png")
	_set_button_icon_if_exists(quarters_button, "quarters_button_icon.png")
	_set_button_icon_if_exists(smelter_button, "smelter_button_icon.png")
	_set_button_icon_if_exists(weapon_smith_button, "weapon_smith_button_icon.png")
	_set_button_icon_if_exists(armour_smith_button, "armour_smith_button_icon.png")
	_set_button_icon_if_exists(armoury_button, "armoury_button_icon.png")
	_set_button_icon_if_exists(towers_button, "towers_button_icon.png")
	_set_button_icon_if_exists(war_room_button, "war_room_button_icon.png")
	_set_button_icon_if_exists(workshop_button, "workshop_button_icon.png")
	_set_button_icon_if_exists(library_button, "library_button_icon.png")
	_set_button_icon_if_exists(mine_button, "mine_button_icon.png")
	_set_button_icon_if_exists(close_panel_button, "back_button_icon.png")

func _set_button_icon_if_exists(button: Button, file_name: String) -> void:
	var path := "%s/%s" % [CASTLE_BUTTON_ICON_ROOT, file_name]
	if not ResourceLoader.exists(path):
		return
	button.icon = load(path) as Texture2D
