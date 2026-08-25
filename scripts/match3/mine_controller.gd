extends Node2D
class_name MineController

const BOARD_SCRIPT = preload("res://scripts/match3/board.gd")
const BOARD_WIDTH := 10
const BOARD_HEIGHT := 10
const SWAP_ANIMATION_TIME := 0.14
const CLEAR_ANIMATION_TIME := 0.18
const GRAVITY_ANIMATION_TIME := 0.22
const DESCEND_ANIMATION_TIME := 0.3

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

class AnimatedTile extends RefCounted:
	var tile_id: String = ""
	var position: Vector2 = Vector2.ZERO
	var alpha: float = 1.0
	var scale: float = 1.0

@onready var depth_label: Label = $UI/DepthLabel
@onready var status_label: Label = $UI/StatusLabel
@onready var back_button: Button = $UI/BackButton
@onready var descend_button: Button = $UI/DescendButton

var board: Node
var selected_cell := Vector2i(-1, -1)
var is_animating := false
var animation_queue: Array = []
var animation_tiles: Array = []
var hidden_cells: Dictionary = {}
var visual_tile_ids: Array = []
var post_animation_status := ""
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
	board.animation_event.connect(_on_board_animation_event)
	_on_board_changed()
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/castle/castle.tscn"))
	descend_button.pressed.connect(_on_descend_pressed)
	_update_hud()
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_animating and not animation_tiles.is_empty():
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i(floor((event.position - BOARD_ORIGIN) / CELL_SIZE))
		if cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT:
			if selected_cell.x < 0:
				selected_cell = cell
				status_label.text = "Select a tile or empty space in this row"
			else:
				var moved: bool = board.try_move_to_empty(selected_cell, cell) if board.tiles[cell.y][cell.x] == null else board.try_swap(selected_cell, cell)
				if moved:
					_set_status("Resolving...")
				else:
					_set_status("That move makes no match")
				selected_cell = Vector2i(-1, -1)
				queue_redraw()

func _on_board_animation_event(event: Dictionary) -> void:
	animation_queue.append(event)
	if not is_animating:
		_run_animation_queue()

func _on_match_resolved(rewards: Dictionary) -> void:
	for material_id in rewards:
		var amount: int = rewards[material_id]
		GameState.add_material(material_id, amount)
		EventBus.mine_match_resolved.emit(material_id, amount)
	_update_hud()

func _on_depth_advanced(new_depth: int) -> void:
	GameState.mine_depth = new_depth
	EventBus.mine_depth_changed.emit(new_depth)
	post_animation_status = "New layer opened"
	if not is_animating:
		_set_status(post_animation_status)
	_update_hud()

func _on_board_changed() -> void:
	GameState.mine_board_state = board.serialize()
	SaveManager.save_game()
	if not is_animating and animation_queue.is_empty():
		_sync_visual_tiles_from_board()
	_update_hud()
	queue_redraw()

func _on_descend_pressed() -> void:
	if is_animating:
		return
	if board.descend():
		_set_status("Descending...")
	else:
		_set_status("Clear the top five rows first")

func _update_hud() -> void:
	depth_label.text = "Mine depth: %d" % board.depth
	descend_button.disabled = is_animating or not board.can_descend()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("182329"))
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE - 3, CELL_SIZE - 3))
			var tile_id := ""
			var cell_key := _cell_key(Vector2i(x, y))
			if not hidden_cells.has(cell_key):
				if is_animating and not visual_tile_ids.is_empty():
					tile_id = visual_tile_ids[y][x] if visual_tile_ids[y][x] != null else ""
				elif not board.tiles.is_empty() and board.tiles[y][x] != null:
					tile_id = board.tiles[y][x].id
			var color: Color = TILE_COLORS.get(tile_id, Color("39484d")) if not tile_id.is_empty() else Color("253239")
			draw_rect(rect, color, true)
			draw_rect(rect, Color("dce5e1", 0.35), false, 2.0)
			if not tile_id.is_empty():
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(9, 32), _tile_display_name(tile_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for animated_tile in animation_tiles:
		_draw_animated_tile(animated_tile)
	if selected_cell.x >= 0:
		var selected_rect := Rect2(BOARD_ORIGIN + Vector2(selected_cell.x, selected_cell.y) * CELL_SIZE, Vector2(CELL_SIZE - 3, CELL_SIZE - 3))
		draw_rect(selected_rect, Color.WHITE, false, 4.0)

func _run_animation_queue() -> void:
	_play_animation_queue()

func _play_animation_queue() -> void:
	is_animating = true
	selected_cell = Vector2i(-1, -1)
	_set_status("Animating mine...")
	_update_hud()
	while not animation_queue.is_empty():
		var event: Dictionary = animation_queue.pop_front()
		match event.get("type", ""):
			"swap":
				await _play_swap_animation(event)
			"clear":
				await _play_clear_animation(event.get("cells", []))
			"gravity":
				await _play_movement_animation(event.get("moves", []), GRAVITY_ANIMATION_TIME)
			"descend":
				var descend_moves: Array = event.get("moves", [])
				descend_moves.append_array(event.get("spawns", []))
				await _play_movement_animation(descend_moves, DESCEND_ANIMATION_TIME)
	hidden_cells.clear()
	animation_tiles.clear()
	_sync_visual_tiles_from_board()
	is_animating = false
	_update_hud()
	if not post_animation_status.is_empty():
		_set_status(post_animation_status)
		post_animation_status = ""
	elif status_label.text == "Animating mine..." or status_label.text == "Resolving..." or status_label.text == "Descending...":
		_set_status("Select a tile or empty space in this row")
	queue_redraw()

func _play_clear_animation(cells: Array) -> void:
	if cells.is_empty():
		return
	animation_tiles.clear()
	hidden_cells.clear()
	var clear_cells: Array[Vector2i] = []
	var clear_tiles: Array = []
	for cell_info in cells:
		var cell: Vector2i = cell_info.get("cell", Vector2i.ZERO)
		clear_cells.append(cell)
		hidden_cells[_cell_key(cell)] = true
		var animated_tile := AnimatedTile.new()
		animated_tile.tile_id = cell_info.get("tile_id", "")
		animated_tile.position = _cell_position(cell)
		animation_tiles.append(animated_tile)
		clear_tiles.append(animated_tile)
	var tween := create_tween()
	tween.set_parallel(true)
	for animated_tile in clear_tiles:
		tween.tween_property(animated_tile, "scale", 0.2, CLEAR_ANIMATION_TIME)
		tween.tween_property(animated_tile, "alpha", 0.0, CLEAR_ANIMATION_TIME)
	await tween.finished
	for cell in clear_cells:
		_set_visual_tile_id(cell, null)
	animation_tiles.clear()
	hidden_cells.clear()
	queue_redraw()

func _play_swap_animation(event: Dictionary) -> void:
	var first: Vector2i = event.get("first", Vector2i.ZERO)
	var second: Vector2i = event.get("second", Vector2i.ZERO)
	if not _is_visual_cell(first) or not _is_visual_cell(second):
		return

	var first_tile_id: String = event.get("first_tile_id", "")
	if first_tile_id.is_empty():
		var existing_first = _get_visual_tile_id(first)
		first_tile_id = existing_first if existing_first != null else ""

	var second_tile_id: String = event.get("second_tile_id", "")
	if second_tile_id.is_empty():
		var existing_second = _get_visual_tile_id(second)
		second_tile_id = existing_second if existing_second != null else ""

	animation_tiles.clear()
	hidden_cells.clear()
	hidden_cells[_cell_key(first)] = true
	hidden_cells[_cell_key(second)] = true

	var first_tile := AnimatedTile.new()
	first_tile.tile_id = first_tile_id
	first_tile.position = _cell_position(first)
	animation_tiles.append(first_tile)

	var second_tile := AnimatedTile.new()
	second_tile.tile_id = second_tile_id
	second_tile.position = _cell_position(second)
	animation_tiles.append(second_tile)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(first_tile, "position", _cell_position(second), SWAP_ANIMATION_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(second_tile, "position", _cell_position(first), SWAP_ANIMATION_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	_set_visual_tile_id(first, second_tile_id if not second_tile_id.is_empty() else null)
	_set_visual_tile_id(second, first_tile_id if not first_tile_id.is_empty() else null)

	animation_tiles.clear()
	hidden_cells.clear()
	queue_redraw()

func _play_movement_animation(moves: Array, duration: float) -> void:
	if moves.is_empty():
		return
	animation_tiles.clear()
	hidden_cells.clear()
	var arrived_tiles: Array = []
	var tween := create_tween()
	tween.set_parallel(true)
	for move in moves:
		var from_cell: Vector2i = move.get("from", Vector2i.ZERO)
		var target_cell: Vector2i = move.get("to", Vector2i.ZERO)
		var tile_id: String = move.get("tile_id", "")
		if tile_id.is_empty() and _is_visual_cell(from_cell):
			var existing = _get_visual_tile_id(from_cell)
			tile_id = existing if existing != null else ""
		if _is_visual_cell(from_cell):
			_set_visual_tile_id(from_cell, null)
			hidden_cells[_cell_key(from_cell)] = true
		if _is_visual_cell(target_cell):
			hidden_cells[_cell_key(target_cell)] = true
		var animated_tile := AnimatedTile.new()
		animated_tile.tile_id = tile_id
		animated_tile.position = _cell_position(from_cell)
		animation_tiles.append(animated_tile)
		arrived_tiles.append({
			"cell": target_cell,
			"tile_id": tile_id,
		})
		tween.tween_property(animated_tile, "position", _cell_position(target_cell), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	for entry in arrived_tiles:
		var cell: Vector2i = entry["cell"]
		if _is_visual_cell(cell):
			_set_visual_tile_id(cell, entry["tile_id"])
	animation_tiles.clear()
	hidden_cells.clear()
	queue_redraw()

func _draw_animated_tile(animated_tile: AnimatedTile) -> void:
	var size := Vector2(CELL_SIZE - 3, CELL_SIZE - 3) * animated_tile.scale
	var top_left := animated_tile.position + (Vector2(CELL_SIZE - 3, CELL_SIZE - 3) - size) * 0.5
	var rect := Rect2(top_left, size)
	var base_color: Color = TILE_COLORS.get(animated_tile.tile_id, Color("39484d"))
	var color := Color(base_color.r, base_color.g, base_color.b, animated_tile.alpha)
	draw_rect(rect, color, true)
	draw_rect(rect, Color("dce5e1", 0.35 * animated_tile.alpha), false, 2.0)
	var label_text := _tile_display_name(animated_tile.tile_id)
	draw_string(ThemeDB.fallback_font, top_left + Vector2(9, 32), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, animated_tile.alpha))

func _cell_position(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x, cell.y) * CELL_SIZE

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _tile_display_name(tile_id: String) -> String:
	for definition in definitions:
		if definition.id == tile_id:
			return definition.display_name
	return tile_id.capitalize()

func _sync_visual_tiles_from_board() -> void:
	visual_tile_ids = board.serialize()

func _is_visual_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT

func _get_visual_tile_id(cell: Vector2i):
	if not _is_visual_cell(cell) or visual_tile_ids.is_empty():
		return null
	return visual_tile_ids[cell.y][cell.x]

func _set_visual_tile_id(cell: Vector2i, tile_id) -> void:
	if not _is_visual_cell(cell) or visual_tile_ids.is_empty():
		return
	visual_tile_ids[cell.y][cell.x] = tile_id

func _set_status(text: String) -> void:
	if is_animating and text != "Animating mine...":
		post_animation_status = text
		return
	status_label.text = text
