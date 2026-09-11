extends Node2D
class_name MineController

const BOARD_SCRIPT = preload("res://scripts/match3/board.gd")
const BUTTON_THEME := preload("res://scripts/ui/button_theme_factory.gd")
const BOARD_WIDTH := 10
const BOARD_HEIGHT := 10
const SWAP_ANIMATION_TIME := 0.14
const MOVE_TO_EMPTY_ANIMATION_TIME := 0.16
const CLEAR_ANIMATION_TIME := 0.18
const GRAVITY_ANIMATION_TIME := 0.22
const DESCEND_ANIMATION_TIME := 0.3
const REJECTED_SWAP_ANIMATION_TIME := 0.12
const REJECTED_SWAP_PROGRESS := 0.35

const DEFAULT_CELL_SIZE := 56.0
const TOP_BAR_HEIGHT := 56.0
const TOP_GAP := 12.0
const SAFE_SIDE_PADDING := 16.0
const SAFE_BOTTOM_PADDING := 16.0
const BOARD_GAP := 24.0
const TOUCH_EDGE_HIT_SLOP_RATIO := 0.35
const TOUCH_TARGET_MIN_HEIGHT := 56.0
const TOUCH_DRAG_TARGET_COLOR := Color("f3dc8a")
const MINE_SPRITE_ROOT := "res://assets/sprites/match3"
const TILE_COLORS := {
	"dirt": Color("8f684b"),
	"stone": Color("65717a"),
	"clay": Color("b86f5c"),
	"copper": Color("c9794d"),
	"iron": Color("aeb8bd"),
	"gold": Color("e6c34f"),
	"hard_stone": Color("4a5560"),
	"rooted_stone": Color("48614c"),
}

class AnimatedTile extends RefCounted:
	var tile_id: String = ""
	var position: Vector2 = Vector2.ZERO
	var alpha: float = 1.0
	var scale: float = 1.0

@onready var depth_label: Label = $UI/HUD/SafeArea/Content/LeftPanel/DepthLabel
@onready var status_label: Label = $UI/HUD/SafeArea/Content/LeftPanel/StatusLabel
@onready var objective_label: Label = $UI/HUD/SafeArea/Content/LeftPanel/ObjectiveLabel
@onready var back_button: Button = $UI/HUD/SafeArea/Content/LeftPanel/BackButton
@onready var descend_button: Button = $UI/HUD/SafeArea/Content/LeftPanel/DescendButton
@onready var descend_progress_label: Label = $UI/HUD/SafeArea/Content/LeftPanel/DescendProgressLabel
@onready var dynamite_button: Button = $UI/HUD/SafeArea/Content/LeftPanel/DynamiteButton
@onready var top_resource_bar: Control = $UI/HUD/TopResourceBar
@onready var hud: Control = $UI/HUD
@onready var safe_area: MarginContainer = $UI/HUD/SafeArea
@onready var left_panel: VBoxContainer = $UI/HUD/SafeArea/Content/LeftPanel

var board: MineBoard
var board_origin := Vector2.ZERO
var cell_size := DEFAULT_CELL_SIZE
var selected_cell := Vector2i(-1, -1)
var touch_drag_active := false
var touch_drag_target_cell := Vector2i(-1, -1)
var is_animating := false
var animation_queue: Array = []
var animation_tiles: Array = []
var hidden_cells: Dictionary = {}
var visual_tile_ids: Array = []
var post_animation_status := ""
var dynamite_targeting := false
var tile_display_names: Dictionary = {}
var tile_textures: Dictionary = {}
var mine_background_texture: Texture2D
var board_backplate_texture: Texture2D
var board_font: Font
var definitions: Array = [
	preload("res://data/tiles/dirt.tres"),
	preload("res://data/tiles/stone.tres"),
	preload("res://data/tiles/clay.tres"),
	preload("res://data/tiles/copper.tres"),
	preload("res://data/tiles/iron.tres"),
	preload("res://data/tiles/gold.tres"),
	preload("res://data/tiles/hard_stone.tres"),
	preload("res://data/tiles/rooted_stone.tres"),
]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	BUTTON_THEME.apply_to(hud)
	board = BOARD_SCRIPT.new()
	add_child(board)
	_apply_layout()
	DisplayLayout.viewport_size_changed.connect(_on_viewport_size_changed)
	board.configure(definitions, GameState.mine_depth)
	if GameState.mine_board_state.is_empty() or not board.load_state(GameState.mine_board_state, GameState.mine_depth):
		board.create_new_board()
	GameState.check_depth_gates(GameState.mine_depth)
	board.match_resolved.connect(_on_match_resolved)
	board.depth_advanced.connect(_on_depth_advanced)
	board.board_changed.connect(_on_board_changed)
	board.animation_event.connect(_on_board_animation_event)
	_on_board_changed()
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/castle/castle.tscn"))
	descend_button.pressed.connect(_on_descend_pressed)
	dynamite_button.pressed.connect(_on_dynamite_pressed)
	_apply_touch_target_sizes()
	_cache_tile_display_names()
	_load_visual_textures()
	board_font = ThemeDB.fallback_font
	EventBus.progression_changed.connect(func(_reason): _update_hud())
	top_resource_bar.set_context("mine")
	_update_hud()
	set_process(true)
	queue_redraw()


func _on_viewport_size_changed(_viewport_size: Vector2) -> void:
	_apply_layout()
	queue_redraw()


func _apply_layout() -> void:
	var viewport_size := DisplayLayout.current_viewport_size()
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
	safe_area.offset_top = safe_top + TOP_BAR_HEIGHT + TOP_GAP
	safe_area.offset_right = -(safe_right + SAFE_SIDE_PADDING)
	safe_area.offset_bottom = -(safe_bottom + SAFE_BOTTOM_PADDING)

	var left_panel_width := clampf(viewport_size.x * 0.25, 248.0, 360.0)
	left_panel.custom_minimum_size.x = left_panel_width

	var board_area_left := safe_left + SAFE_SIDE_PADDING + left_panel_width + BOARD_GAP
	var board_area_top := safe_top + TOP_BAR_HEIGHT + TOP_GAP
	var board_area_right := viewport_size.x - safe_right - SAFE_SIDE_PADDING
	var board_area_bottom := viewport_size.y - safe_bottom - SAFE_BOTTOM_PADDING
	var available_width := maxf(BOARD_WIDTH * 24.0, board_area_right - board_area_left)
	var available_height := maxf(BOARD_HEIGHT * 24.0, board_area_bottom - board_area_top)
	var resolved_cell_size: float = floorf(minf(available_width / BOARD_WIDTH, available_height / BOARD_HEIGHT))
	cell_size = clampf(resolved_cell_size, 24.0, 72.0)
	var board_pixel_size := Vector2(BOARD_WIDTH * cell_size, BOARD_HEIGHT * cell_size)
	board_origin = Vector2(

		
		board_area_left + maxf(0.0, (available_width - board_pixel_size.x) * 0.5),
		board_area_top + maxf(0.0, (available_height - board_pixel_size.y) * 0.5)
	)

func _apply_touch_target_sizes() -> void:
	if not _touch_input_available():
		return
	var min_height := TOUCH_TARGET_MIN_HEIGHT
	back_button.custom_minimum_size.y = maxf(back_button.custom_minimum_size.y, min_height)
	descend_button.custom_minimum_size.y = maxf(descend_button.custom_minimum_size.y, min_height)
	dynamite_button.custom_minimum_size.y = maxf(dynamite_button.custom_minimum_size.y, min_height)

func _touch_input_available() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func _process(_delta: float) -> void:
	if is_animating and not animation_tiles.is_empty():
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _screen_to_cell(event.position, false)
		if _is_board_cell(cell):
			_handle_board_cell_pressed(cell)
	elif event is InputEventScreenTouch:
		if event.pressed:
			var touch_cell := _screen_to_cell(event.position, true)
			if not _is_board_cell(touch_cell):
				_reset_touch_drag_state()
				return
			if selected_cell.x >= 0 and touch_cell == selected_cell and not dynamite_targeting:
				touch_drag_active = true
				touch_drag_target_cell = Vector2i(-1, -1)
				return
			_handle_board_cell_pressed(touch_cell)
			touch_drag_active = selected_cell.x >= 0 and not dynamite_targeting
		else:
			_commit_touch_drag_if_needed()
	elif event is InputEventScreenDrag:
		if not touch_drag_active or selected_cell.x < 0 or dynamite_targeting:
			return
		var drag_cell := _screen_to_cell(event.position, true)
		var next_target := drag_cell if _is_board_cell(drag_cell) and drag_cell != selected_cell else Vector2i(-1, -1)
		if next_target != touch_drag_target_cell:
			touch_drag_target_cell = next_target
			queue_redraw()

func _handle_board_cell_pressed(cell: Vector2i) -> void:
	_reset_touch_drag_state()
	if dynamite_targeting:
		if board.use_dynamite(cell):
			dynamite_targeting = false
			_set_status("Dynamite detonated.")
		else:
			_set_status("Select a hardened stone tile for Dynamite.")
		_update_hud()
		return
	if selected_cell.x < 0:
		selected_cell = cell
		status_label.text = "Move along rows to clear the top edge (5 rows)"
	else:
		var attempted_swap_cell := selected_cell
		var target_is_empty: bool = board.tiles[cell.y][cell.x] == null
		var moved: bool = board.try_move_to_empty(selected_cell, cell) if target_is_empty else board.try_swap(selected_cell, cell)
		selected_cell = Vector2i(-1, -1)
		if moved:
			_set_status("Resolving...")
		else:
			var blocked_reason := GameState.mine_blocked_reason()
			_set_status(blocked_reason if not blocked_reason.is_empty() else "That move makes no match")
			if not target_is_empty and absi(attempted_swap_cell.x - cell.x) + absi(attempted_swap_cell.y - cell.y) == 1:
				await _play_rejected_swap_animation(attempted_swap_cell, cell)
	queue_redraw()

func _screen_to_cell(screen_position: Vector2, use_touch_slop: bool) -> Vector2i:
	var local_pos := screen_position - board_origin
	var board_size := Vector2(BOARD_WIDTH * cell_size, BOARD_HEIGHT * cell_size)
	var slop := cell_size * TOUCH_EDGE_HIT_SLOP_RATIO if use_touch_slop else 0.0
	if local_pos.x < -slop or local_pos.y < -slop or local_pos.x >= board_size.x + slop or local_pos.y >= board_size.y + slop:
		return Vector2i(-1, -1)
	var clamped_pos := Vector2(
		clampf(local_pos.x, 0.0, maxf(board_size.x - 0.001, 0.0)),
		clampf(local_pos.y, 0.0, maxf(board_size.y - 0.001, 0.0))
	)
	return Vector2i(floor(clamped_pos.x / cell_size), floor(clamped_pos.y / cell_size))

func _is_board_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT

func _commit_touch_drag_if_needed() -> void:
	if touch_drag_active and selected_cell.x >= 0 and _is_board_cell(touch_drag_target_cell):
		_handle_board_cell_pressed(touch_drag_target_cell)
	_reset_touch_drag_state()

func _reset_touch_drag_state() -> void:
	touch_drag_active = false
	if touch_drag_target_cell.x >= 0:
		touch_drag_target_cell = Vector2i(-1, -1)
		queue_redraw()
	else:
		touch_drag_target_cell = Vector2i(-1, -1)

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
	if new_depth >= 1:
		GameState.mark_first_depth_cleared()
	GameState.check_depth_gates(new_depth)
	post_animation_status = "New layer opened"
	if not is_animating:
		_set_status(post_animation_status)
	_update_hud()

func _on_board_changed() -> void:
	if board.enforce_gate_tiles():
		_sync_visual_tiles_from_board()
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
		var blocked_reason := GameState.mine_blocked_reason()
		if not blocked_reason.is_empty():
			_set_status(blocked_reason)
		else:
			_set_status("Not ready: clear top edge rows (%d/5)" % board.top_rows_clear_count())

func _on_dynamite_pressed() -> void:
	if is_animating:
		return
	dynamite_targeting = not dynamite_targeting
	if dynamite_targeting:
		_set_status("Select hardened stone to blast.")
	else:
		_set_status("Dynamite targeting cancelled.")
	_update_hud()

func _update_hud() -> void:
	depth_label.text = "Mine depth: %d" % board.depth
	var clear_rows := board.top_rows_clear_count()
	var ready := clear_rows >= 5
	descend_button.disabled = is_animating or not ready
	descend_progress_label.text = "Descend ready: %d/5 top rows clear" % clear_rows
	descend_progress_label.modulate = Color("b6e59c") if ready else Color("cfd6d2")
	objective_label.text = GameState.castle_objective_text()
	dynamite_button.text = "Use Dynamite (%d)%s" % [GameState.dynamite_count, " [Targeting]" if dynamite_targeting else ""]
	dynamite_button.disabled = is_animating or GameState.dynamite_count <= 0

func _draw() -> void:
	var viewport_size := DisplayLayout.current_viewport_size()
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	if mine_background_texture != null:
		var tex_size := mine_background_texture.get_size()
		if tex_size.y > 0.0:
			var bg_scale := viewport_size.y / tex_size.y
			var scaled_width := tex_size.x * bg_scale
			var center_x := viewport_size.x * 0.5
			# Center a tile on screen center, then repeat outward to cover the full width.
			var tile_x := fposmod(center_x - scaled_width * 0.5, scaled_width) - scaled_width
			while tile_x < viewport_size.x:
				draw_texture_rect(mine_background_texture, Rect2(Vector2(tile_x, 0.0), Vector2(scaled_width, viewport_size.y)), false)
				tile_x += scaled_width
		else:
			draw_texture_rect(mine_background_texture, viewport_rect, true)
	else:
		draw_rect(viewport_rect, Color("182329"))
	var tile_padding := _tile_padding()
	var tile_size := Vector2(cell_size - tile_padding, cell_size - tile_padding)
	var font_size := int(clampf(cell_size * 0.25, 10.0, 16.0))
	var text_offset := Vector2(cell_size * 0.14, cell_size * 0.58)
	var draw_font := board_font if board_font != null else ThemeDB.fallback_font
	var board_rect := Rect2(board_origin, Vector2(BOARD_WIDTH * cell_size, BOARD_HEIGHT * cell_size))
	if board_backplate_texture != null:
		draw_texture_rect(board_backplate_texture, board_rect, true)
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var rect := Rect2(board_origin + Vector2(x, y) * cell_size, tile_size)
			var tile_id := ""
			var cell := Vector2i(x, y)
			if not hidden_cells.has(cell):
				if is_animating and not visual_tile_ids.is_empty():
					tile_id = visual_tile_ids[y][x] if visual_tile_ids[y][x] != null else ""
				elif not board.tiles.is_empty() and board.tiles[y][x] != null:
					tile_id = board.tiles[y][x].id
			var tile_texture := _tile_texture(tile_id)
			if tile_texture != null:
				draw_texture_rect(tile_texture, rect, false)
				draw_rect(rect, Color("dce5e1", 0.25), false, 2.0)
			else:
				var color: Color = TILE_COLORS.get(tile_id, Color("39484d")) if not tile_id.is_empty() else Color("253239")
				draw_rect(rect, color, true)
				draw_rect(rect, Color("dce5e1", 0.35), false, 2.0)
			if not tile_id.is_empty() and tile_texture == null:
				draw_string(draw_font, rect.position + text_offset, _tile_display_name(tile_id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if GameState.gate_state("magic_barrier") == GameState.GATE_ACTIVE and not GameState.progression.get("barrier_trinket_activated", false):
		var barrier_y := board_origin.y + 6.0 * cell_size
		draw_line(Vector2(board_origin.x, barrier_y), Vector2(board_origin.x + BOARD_WIDTH * cell_size, barrier_y), Color("8f4bd6"), clampf(cell_size * 0.1, 3.0, 6.0))
	for animated_tile in animation_tiles:
		_draw_animated_tile(animated_tile)
	if selected_cell.x >= 0:
		var selected_rect := Rect2(board_origin + Vector2(selected_cell.x, selected_cell.y) * cell_size, tile_size)
		draw_rect(selected_rect, Color.WHITE, false, 4.0)
	if _is_board_cell(touch_drag_target_cell):
		var target_rect := Rect2(board_origin + Vector2(touch_drag_target_cell.x, touch_drag_target_cell.y) * cell_size, tile_size)
		draw_rect(target_rect, TOUCH_DRAG_TARGET_COLOR, false, 3.0)

func _run_animation_queue() -> void:
	_play_animation_queue()

func _play_animation_queue() -> void:
	is_animating = true
	selected_cell = Vector2i(-1, -1)
	_reset_touch_drag_state()
	_set_status("Animating mine...")
	_update_hud()
	while not animation_queue.is_empty():
		var event: Dictionary = animation_queue.pop_front()
		match event.get("type", ""):
			"swap":
				await _play_swap_animation(event)
			"move":
				await _play_movement_animation(event.get("moves", []), MOVE_TO_EMPTY_ANIMATION_TIME)
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
		_set_status("Move along rows to clear the top edge (5 rows)")
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
		hidden_cells[cell] = true
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
	hidden_cells[first] = true
	hidden_cells[second] = true

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

func _play_rejected_swap_animation(first: Vector2i, second: Vector2i) -> void:
	if not _is_visual_cell(first) or not _is_visual_cell(second):
		return
	is_animating = true
	_update_hud()

	var first_tile_id_value = _get_visual_tile_id(first)
	var second_tile_id_value = _get_visual_tile_id(second)
	var first_tile_id: String = first_tile_id_value if first_tile_id_value != null else ""
	var second_tile_id: String = second_tile_id_value if second_tile_id_value != null else ""

	animation_tiles.clear()
	hidden_cells.clear()
	hidden_cells[first] = true
	hidden_cells[second] = true

	var first_tile := AnimatedTile.new()
	first_tile.tile_id = first_tile_id
	var first_origin := _cell_position(first)
	first_tile.position = first_origin
	animation_tiles.append(first_tile)

	var second_tile := AnimatedTile.new()
	second_tile.tile_id = second_tile_id
	var second_origin := _cell_position(second)
	second_tile.position = second_origin
	animation_tiles.append(second_tile)

	# Nudge each tile partway toward the other cell, then snap back, to read as an aborted swap.
	var first_midpoint := first_origin.lerp(second_origin, REJECTED_SWAP_PROGRESS)
	var second_midpoint := second_origin.lerp(first_origin, REJECTED_SWAP_PROGRESS)

	# Two independent per-tile tweens (each sequential: out, then back) run concurrently.
	var first_tween := create_tween()
	first_tween.tween_property(first_tile, "position", first_midpoint, REJECTED_SWAP_ANIMATION_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	first_tween.tween_property(first_tile, "position", first_origin, REJECTED_SWAP_ANIMATION_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var second_tween := create_tween()
	second_tween.tween_property(second_tile, "position", second_midpoint, REJECTED_SWAP_ANIMATION_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	second_tween.tween_property(second_tile, "position", second_origin, REJECTED_SWAP_ANIMATION_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await first_tween.finished
	if second_tween.is_valid() and second_tween.is_running():
		await second_tween.finished

	animation_tiles.clear()
	hidden_cells.clear()
	is_animating = false
	_update_hud()
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
			hidden_cells[from_cell] = true
		if _is_visual_cell(target_cell):
			hidden_cells[target_cell] = true
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
	var tile_padding := _tile_padding()
	var base_size := Vector2(cell_size - tile_padding, cell_size - tile_padding)
	var size := base_size * animated_tile.scale
	var top_left := animated_tile.position + (base_size - size) * 0.5
	var rect := Rect2(top_left, size)
	var tile_texture := _tile_texture(animated_tile.tile_id)
	if tile_texture != null:
		draw_texture_rect(tile_texture, rect, false, Color(1.0, 1.0, 1.0, animated_tile.alpha))
		draw_rect(rect, Color("dce5e1", 0.35 * animated_tile.alpha), false, 2.0)
	else:
		var base_color: Color = TILE_COLORS.get(animated_tile.tile_id, Color("39484d"))
		var color := Color(base_color.r, base_color.g, base_color.b, animated_tile.alpha)
		draw_rect(rect, color, true)
		draw_rect(rect, Color("dce5e1", 0.35 * animated_tile.alpha), false, 2.0)
		var label_text := _tile_display_name(animated_tile.tile_id)
		var draw_font := board_font if board_font != null else ThemeDB.fallback_font
		draw_string(
			draw_font,
			top_left + Vector2(cell_size * 0.14, cell_size * 0.58),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			int(clampf(cell_size * 0.25, 10.0, 16.0)),
			Color(1, 1, 1, animated_tile.alpha)
		)

func _cell_position(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x, cell.y) * cell_size


func _tile_padding() -> float:
	return clampf(cell_size * 0.06, 2.0, 4.0)

func _cache_tile_display_names() -> void:
	tile_display_names.clear()
	for definition in definitions:
		tile_display_names[definition.id] = definition.display_name

func _tile_display_name(tile_id: String) -> String:
	return str(tile_display_names.get(tile_id, tile_id.capitalize()))

func _load_visual_textures() -> void:
	mine_background_texture = _load_texture_if_exists("%s/backgrounds/mine_cavern_background.png" % MINE_SPRITE_ROOT)
	board_backplate_texture = _load_texture_if_exists("%s/backgrounds/mine_board_backplate.png" % MINE_SPRITE_ROOT)
	tile_textures.clear()
	for definition in definitions:
		var tile_id := str(definition.id)
		var texture_path := "%s/tiles/%s_tile.png" % [MINE_SPRITE_ROOT, tile_id]
		tile_textures[tile_id] = _load_texture_if_exists(texture_path)

func _tile_texture(tile_id: String) -> Texture2D:
	if tile_id.is_empty() or not tile_textures.has(tile_id):
		return null
	return tile_textures[tile_id] as Texture2D

func _load_texture_if_exists(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

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
