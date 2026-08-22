extends Node2D
class_name TDGridMap
## Draws the battle grid and reports cell clicks for adventurer placement.

@export var grid_width: int = 24
@export var grid_height: int = 16
@export var cell_size: int = 32

var path_cells: Array[Vector2i] = []
var path_cell_set: Dictionary = {}  # Vector2i -> true, fast membership check
var buildable_cells: Dictionary = {}  # Vector2i -> true
var occupied_cells: Dictionary = {}  # Vector2i -> TDAdventurer
var reserved_cells: Dictionary = {}  # Vector2i -> true, fixed Tower cells; never player-buildable

var preview_active: bool = false
var preview_center: Vector2i = Vector2i.ZERO
var preview_range_min: int = 0
var preview_range_max: int = 0

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i, valid: bool)

func _ready() -> void:
	_build_path()
	queue_redraw()

## Castle doors always sit at the top-middle; the path is a gentle, axis-aligned
## zigzag from a bottom/side entry point up to that door, rather than a full snake.
func _build_path() -> void:
	var castle_cell := Vector2i(grid_width / 2, 0)
	var waypoints: Array[Vector2i] = [
		Vector2i(grid_width - 1, grid_height - 1),
		Vector2i(grid_width - 1, int(grid_height * 0.6)),
		Vector2i(int(grid_width * 0.67), int(grid_height * 0.6)),
		Vector2i(int(grid_width * 0.67), int(grid_height * 0.25)),
		Vector2i(castle_cell.x, int(grid_height * 0.25)),
		castle_cell,
	]

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

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size + cell_size / 2.0, cell.y * cell_size + cell_size / 2.0)

func world_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(local_pos.x / cell_size), int(local_pos.y / cell_size))

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
	preview_active = true
	preview_center = center
	preview_range_min = range_min
	preview_range_max = range_max
	queue_redraw()

func clear_range_preview() -> void:
	if preview_active:
		preview_active = false
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = to_local(event.position)
		var cell := world_to_cell(local_pos)
		if is_in_bounds(cell):
			cell_clicked.emit(cell)
	elif event is InputEventMouseMotion:
		var local_pos: Vector2 = to_local(event.position)
		var cell := world_to_cell(local_pos)
		if is_in_bounds(cell):
			cell_hovered.emit(cell, true)
		else:
			cell_hovered.emit(Vector2i(-1, -1), false)

func _draw() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell := Vector2i(x, y)
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			var color := Color(0.6, 0.45, 0.3) if path_cell_set.has(cell) else Color(0.85, 0.85, 0.85)
			draw_rect(rect, color, true)
			draw_rect(rect, Color(0.4, 0.4, 0.4), false)

	if not path_cells.is_empty():
		# The castle doors: mark the final path cell distinctly from the rest of the path.
		var castle_cell: Vector2i = path_cells[path_cells.size() - 1]
		var castle_rect := Rect2(castle_cell.x * cell_size, castle_cell.y * cell_size, cell_size, cell_size)
		draw_rect(castle_rect, Color(0.35, 0.2, 0.15), true)
		draw_rect(castle_rect, Color(0.9, 0.75, 0.3), false, 3.0)

	for cell: Vector2i in reserved_cells:
		var rect := Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
		draw_rect(rect, Color(0.15, 0.25, 0.45), true)
		draw_rect(rect, Color(0.4, 0.6, 0.9), false, 3.0)

	if preview_active:
		# Manhattan distance gives a diamond-shaped range instead of a square.
		for x in range(grid_width):
			for y in range(grid_height):
				var cell := Vector2i(x, y)
				var dist := absi(cell.x - preview_center.x) + absi(cell.y - preview_center.y)
				if dist >= preview_range_min and dist <= preview_range_max:
					var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
					draw_rect(rect, Color(1.0, 0.0, 0.0, 0.35), true)
					draw_rect(rect, Color(1.0, 0.0, 0.0, 0.9), false, 3.0)
		var center_rect := Rect2(preview_center.x * cell_size, preview_center.y * cell_size, cell_size, cell_size)
		draw_rect(center_rect, Color(0.2, 0.9, 0.3, 0.35), true)
