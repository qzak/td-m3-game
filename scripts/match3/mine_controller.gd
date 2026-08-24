extends Node2D
class_name MineController

const BOARD_SCRIPT = preload("res://scripts/match3/board.gd")
const BOARD_WIDTH := 10
const BOARD_HEIGHT := 10

const BOARD_ORIGIN := Vector2(360, 54)
const CELL_SIZE := 56.0
const TILE_COLORS := {
	"dirt": Color("8f684b"),
	"stone": Color("65717a"),
	"clay": Color("b86f5c"),
	"copper": Color("c9794d"),
	"iron": Color("aeb8bd"),
	"gold": Color("e6c34f"),
}

@onready var depth_label: Label = $UI/DepthLabel
@onready var materials_label: Label = $UI/MaterialsLabel
@onready var status_label: Label = $UI/StatusLabel
@onready var back_button: Button = $UI/BackButton
@onready var descend_button: Button = $UI/DescendButton

var board: Node
var selected_cell := Vector2i(-1, -1)
var definitions: Array = [
	preload("res://data/tiles/dirt.tres"),
	preload("res://data/tiles/stone.tres"),
	preload("res://data/tiles/clay.tres"),
	preload("res://data/tiles/copper.tres"),
	preload("res://data/tiles/iron.tres"),
	preload("res://data/tiles/gold.tres"),
]

func _ready() -> void:
	board = BOARD_SCRIPT.new()
	add_child(board)
	board.configure(definitions, GameState.mine_depth)
	if GameState.mine_board_state.is_empty() or not board.load_state(GameState.mine_board_state, GameState.mine_depth):
		board.create_new_board()
	board.match_resolved.connect(_on_match_resolved)
	board.depth_advanced.connect(_on_depth_advanced)
	board.board_changed.connect(_on_board_changed)
	_on_board_changed()
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/castle/castle.tscn"))
	descend_button.pressed.connect(_on_descend_pressed)
	_update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i(floor((event.position - BOARD_ORIGIN) / CELL_SIZE))
		if cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT:
			if selected_cell.x < 0:
				selected_cell = cell
				status_label.text = "Select a tile or empty space in this row"
			else:
				var moved: bool = board.try_move_to_empty(selected_cell, cell) if board.tiles[cell.y][cell.x] == null else board.try_swap(selected_cell, cell)
				if moved:
					status_label.text = "Match resolved"
				else:
					status_label.text = "That move makes no match"
				selected_cell = Vector2i(-1, -1)
				queue_redraw()

func _on_match_resolved(rewards: Dictionary) -> void:
	for material_id in rewards:
		var amount: int = rewards[material_id]
		GameState.add_material(material_id, amount)
		EventBus.mine_match_resolved.emit(material_id, amount)
	_update_hud()

func _on_depth_advanced(new_depth: int) -> void:
	GameState.mine_depth = new_depth
	EventBus.mine_depth_changed.emit(new_depth)
	status_label.text = "New layer opened"
	_update_hud()

func _on_board_changed() -> void:
	GameState.mine_board_state = board.serialize()
	SaveManager.save_game()
	_update_hud()
	queue_redraw()

func _on_descend_pressed() -> void:
	if board.descend():
		status_label.text = "Descended to a new layer"
	else:
		status_label.text = "Clear the top five rows first"

func _update_hud() -> void:
	depth_label.text = "Mine depth: %d" % board.depth
	var material_text := "Materials:"
	for material_id in ["copper", "iron", "gold"]:
		material_text += "  %s %d" % [material_id.capitalize(), GameState.materials.get(material_id, 0)]
	materials_label.text = material_text
	descend_button.disabled = not board.can_descend()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("182329"))
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE - 3, CELL_SIZE - 3))
			var tile = board.tiles[y][x] if not board.tiles.is_empty() else null
			var color: Color = TILE_COLORS.get(tile.id, Color("39484d")) if tile != null else Color("253239")
			draw_rect(rect, color, true)
			draw_rect(rect, Color("dce5e1", 0.35), false, 2.0)
			if tile != null:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(9, 32), tile.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if selected_cell.x >= 0:
		var selected_rect := Rect2(BOARD_ORIGIN + Vector2(selected_cell.x, selected_cell.y) * CELL_SIZE, Vector2(CELL_SIZE - 3, CELL_SIZE - 3))
		draw_rect(selected_rect, Color.WHITE, false, 4.0)
