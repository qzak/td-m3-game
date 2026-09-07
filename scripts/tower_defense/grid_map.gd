extends Node2D
class_name TDGridMap
## Draws the battle grid and reports cell clicks for adventurer placement.

@export var grid_width: int = 24
@export var grid_height: int = 16
@export var cell_size: float = 32.0
@export var default_path_waypoints: Array[Vector2i] = [
	Vector2i(23, 15),
	Vector2i(23, 9),
	Vector2i(16, 9),
	Vector2i(16, 4),
	Vector2i(12, 4),
	Vector2i(12, 0),
]

var path_cells: Array[Vector2i] = []
var path_cell_set: Dictionary = {}  # Vector2i -> true, fast membership check
var buildable_cells: Dictionary = {}  # Vector2i -> true
var occupied_cells: Dictionary = {}  # Vector2i -> TDAdventurer
var reserved_cells: Dictionary = {}  # Vector2i -> true, fixed Tower cells; never player-buildable
var active_path_waypoints: Array[Vector2i] = []

var preview_active: bool = false
var preview_center: Vector2i = Vector2i.ZERO
var preview_range_min: int = 0
var preview_range_max: int = 0
var preview_cells: Array[Vector2i] = []

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i, valid: bool)
const TOUCH_EDGE_HIT_SLOP_RATIO := 0.35
const PATH_COLOR := Color(0.6, 0.45, 0.3)
const BUILDABLE_COLOR := Color(0.85, 0.85, 0.85)
const GRID_LINE_COLOR := Color(0.4, 0.4, 0.4)
const PREVIEW_FILL_COLOR := Color(1.0, 0.0, 0.0, 0.35)
const PREVIEW_OUTLINE_COLOR := Color(1.0, 0.0, 0.0, 0.9)
const PREVIEW_CENTER_COLOR := Color(0.2, 0.9, 0.3, 0.35)
const TD_BACKGROUND_SPRITE_ROOT := "res://assets/sprites/tower_defense/backgrounds"
const TD_GRID_SPRITE_ROOT := "res://assets/sprites/tower_defense/grid"

var battlefield_ground_texture: Texture2D
var path_cell_texture: Texture2D
var buildable_cell_texture: Texture2D
var castle_gate_texture: Texture2D
var preview_fill_texture: Texture2D
var preview_outline_texture: Texture2D
var preview_center_texture: Texture2D

func _ready() -> void:
	_load_visual_textures()
	_build_path()
	queue_redraw()

func set_path_waypoints(waypoints: Array[Vector2i]) -> void:
	active_path_waypoints = waypoints.duplicate()
	_build_path()
	queue_redraw()

func _build_path() -> void:
	var waypoints: Array[Vector2i] = _resolve_path_waypoints()

	path_cells.clear()
	path_cells.append(waypoints[0])
	for i in range(waypoints.size() - 1):
		var from: Vector2i = waypoints[i]
		var to: Vector2i = waypoints[i + 1]
		var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var current := from
		while current != to:
			current += step
			path_cells.append(current)

	path_cell_set.clear()
	for cell in path_cells:
		path_cell_set[cell] = true

	buildable_cells.clear()
	for x in range(grid_width):
		for y in range(grid_height):
			var cell := Vector2i(x, y)
			if not path_cell_set.has(cell):
				buildable_cells[cell] = true

func _resolve_path_waypoints() -> Array[Vector2i]:
	var legacy_waypoints := _legacy_default_waypoints()
	if _is_valid_waypoint_path(default_path_waypoints):
		legacy_waypoints = default_path_waypoints.duplicate()
	if _is_valid_waypoint_path(active_path_waypoints):
		return active_path_waypoints.duplicate()
	return legacy_waypoints

func _is_valid_waypoint_path(waypoints: Array[Vector2i]) -> bool:
	if waypoints.size() < 2:
		return false

	var castle_cell := Vector2i(grid_width / 2, 0)
	if waypoints[waypoints.size() - 1] != castle_cell:
		return false

	for i in range(waypoints.size()):
		if not is_in_bounds(waypoints[i]):
			return false
		if i == 0:
			continue
		var prev: Vector2i = waypoints[i - 1]
		var current: Vector2i = waypoints[i]
		if prev == current:
			return false
		if prev.x != current.x and prev.y != current.y:
			return false

	return true

func _legacy_default_waypoints() -> Array[Vector2i]:
	var castle_cell := Vector2i(grid_width / 2, 0)
	return [
		Vector2i(grid_width - 1, grid_height - 1),
		Vector2i(grid_width - 1, int(grid_height * 0.6)),
		Vector2i(int(grid_width * 0.67), int(grid_height * 0.6)),
		Vector2i(int(grid_width * 0.67), int(grid_height * 0.25)),
		Vector2i(castle_cell.x, int(grid_height * 0.25)),
		castle_cell,
	]

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size + cell_size / 2.0, cell.y * cell_size + cell_size / 2.0)


func world_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(local_pos.x / cell_size)), int(floor(local_pos.y / cell_size)))


func grid_pixel_size() -> Vector2:
	return Vector2(grid_width * cell_size, grid_height * cell_size)


func set_cell_size(new_cell_size: float) -> void:
	var clamped := maxf(12.0, new_cell_size)
	if is_equal_approx(clamped, cell_size):
		return
	cell_size = clamped
	queue_redraw()

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func is_buildable(cell: Vector2i) -> bool:
	return buildable_cells.has(cell) and not occupied_cells.has(cell) and not reserved_cells.has(cell)

## Marks a cell as permanently off-limits to player placement (used by fixed Towers).
func reserve_cell(cell: Vector2i) -> void:
	reserved_cells[cell] = true
	queue_redraw()

## Shows which path cells an adventurer with the given range could hit from `center`.
func set_range_preview(center: Vector2i, range_min: int, range_max: int) -> void:
	if preview_active and preview_center == center and preview_range_min == range_min and preview_range_max == range_max:
		return
	preview_active = true
	preview_center = center
	preview_range_min = range_min
	preview_range_max = range_max
	_rebuild_preview_cells()
	queue_redraw()

func clear_range_preview() -> void:
	if preview_active:
		preview_active = false
		preview_cells.clear()
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_emit_click_for_screen_position(event.position, false)
	elif event is InputEventMouseMotion:
		_emit_hover_for_screen_position(event.position, false)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_emit_click_for_screen_position(event.position, true)
			_emit_hover_for_screen_position(event.position, true)
		else:
			cell_hovered.emit(Vector2i(-1, -1), false)
	elif event is InputEventScreenDrag:
		_emit_hover_for_screen_position(event.position, true)

func _emit_click_for_screen_position(screen_position: Vector2, use_touch_slop: bool) -> void:
	var cell := _cell_from_screen_position(screen_position, use_touch_slop)
	if is_in_bounds(cell):
		cell_clicked.emit(cell)

func _emit_hover_for_screen_position(screen_position: Vector2, use_touch_slop: bool) -> void:
	var cell := _cell_from_screen_position(screen_position, use_touch_slop)
	if is_in_bounds(cell):
		cell_hovered.emit(cell, true)
	else:
		cell_hovered.emit(Vector2i(-1, -1), false)

func _cell_from_screen_position(screen_position: Vector2, use_touch_slop: bool) -> Vector2i:
	var local_pos := to_local(screen_position)
	var grid_size := grid_pixel_size()
	var slop := cell_size * TOUCH_EDGE_HIT_SLOP_RATIO if use_touch_slop else 0.0
	if local_pos.x < -slop or local_pos.y < -slop or local_pos.x >= grid_size.x + slop or local_pos.y >= grid_size.y + slop:
		return Vector2i(-1, -1)
	var clamped_pos := Vector2(
		clampf(local_pos.x, 0.0, maxf(grid_size.x - 0.001, 0.0)),
		clampf(local_pos.y, 0.0, maxf(grid_size.y - 0.001, 0.0))
	)
	return world_to_cell(clamped_pos)

func _draw() -> void:
	var grid_size := grid_pixel_size()
	if battlefield_ground_texture != null:
		draw_texture_rect(battlefield_ground_texture, Rect2(Vector2.ZERO, grid_size), true)
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			if path_cell_set.has(cell):
				if path_cell_texture != null:
					draw_texture_rect(path_cell_texture, rect, false)
				else:
					draw_rect(rect, PATH_COLOR, true)
			else:
				if buildable_cell_texture != null:
					draw_texture_rect(buildable_cell_texture, rect, false)
				else:
					draw_rect(rect, BUILDABLE_COLOR, true)

	for x in range(grid_width + 1):
		var x_pos := x * cell_size
		draw_line(Vector2(x_pos, 0.0), Vector2(x_pos, grid_size.y), GRID_LINE_COLOR, 1.0)
	for y in range(grid_height + 1):
		var y_pos := y * cell_size
		draw_line(Vector2(0.0, y_pos), Vector2(grid_size.x, y_pos), GRID_LINE_COLOR, 1.0)

	if not path_cells.is_empty():
		# The castle doors: mark the final path cell distinctly from the rest of the path.
		var castle_cell: Vector2i = path_cells[path_cells.size() - 1]
		var castle_rect := Rect2(castle_cell.x * cell_size, castle_cell.y * cell_size, cell_size, cell_size)
		if castle_gate_texture != null:
			draw_texture_rect(castle_gate_texture, castle_rect, false)
		else:
			draw_rect(castle_rect, Color(0.35, 0.2, 0.15), true)
			draw_rect(castle_rect, Color(0.9, 0.75, 0.3), false, 3.0)

	for cell: Vector2i in reserved_cells:
		var rect := Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
		draw_rect(rect, Color(0.15, 0.25, 0.45), true)
		draw_rect(rect, Color(0.4, 0.6, 0.9), false, 3.0)

	if preview_active:
		for cell in preview_cells:
			var rect := Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
			if preview_fill_texture != null:
				draw_texture_rect(preview_fill_texture, rect, false)
			else:
				draw_rect(rect, PREVIEW_FILL_COLOR, true)
			if preview_outline_texture != null:
				draw_texture_rect(preview_outline_texture, rect, false)
			else:
				draw_rect(rect, PREVIEW_OUTLINE_COLOR, false, 3.0)
		var center_rect := Rect2(preview_center.x * cell_size, preview_center.y * cell_size, cell_size, cell_size)
		if preview_center_texture != null:
			draw_texture_rect(preview_center_texture, center_rect, false)
		else:
			draw_rect(center_rect, PREVIEW_CENTER_COLOR, true)

func _rebuild_preview_cells() -> void:
	preview_cells.clear()
	if not preview_active:
		return
	var max_range := maxi(preview_range_min, preview_range_max)
	for dx in range(-max_range, max_range + 1):
		var abs_dx := absi(dx)
		var dy_limit := max_range - abs_dx
		for dy in range(-dy_limit, dy_limit + 1):
			var distance := abs_dx + absi(dy)
			if distance < preview_range_min or distance > preview_range_max:
				continue
			var cell := Vector2i(preview_center.x + dx, preview_center.y + dy)
			if is_in_bounds(cell):
				preview_cells.append(cell)

func _load_visual_textures() -> void:
	battlefield_ground_texture = _load_texture_if_exists("%s/battlefield_ground.png" % TD_BACKGROUND_SPRITE_ROOT)
	path_cell_texture = _load_texture_if_exists("%s/path_cell_tile.png" % TD_GRID_SPRITE_ROOT)
	buildable_cell_texture = _load_texture_if_exists("%s/buildable_cell_tile.png" % TD_GRID_SPRITE_ROOT)
	castle_gate_texture = _load_texture_if_exists("%s/castle_gate_marker.png" % TD_BACKGROUND_SPRITE_ROOT)
	preview_fill_texture = _load_texture_if_exists("%s/range_preview_fill.png" % TD_GRID_SPRITE_ROOT)
	preview_outline_texture = _load_texture_if_exists("%s/range_preview_outline.png" % TD_GRID_SPRITE_ROOT)
	preview_center_texture = _load_texture_if_exists("%s/range_preview_center.png" % TD_GRID_SPRITE_ROOT)

func _load_texture_if_exists(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
