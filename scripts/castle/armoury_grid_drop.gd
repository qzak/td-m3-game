extends Control
class_name ArmouryGridDrop

signal item_dropped(payload: Dictionary, cell: Vector2i)

@export var columns: int = 20
@export var rows: int = 20
@export var cell_size: int = 20

var preview_cell := Vector2i(-1, -1)
var preview_footprint := Vector2i.ONE
var preview_is_valid := false

func _ready() -> void:
	custom_minimum_size = Vector2(columns * cell_size, rows * cell_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		_clear_drop_preview()
		return false
	if str(data.get("kind", "")) != "armoury_item":
		_clear_drop_preview()
		return false
	var target_cell := _target_cell_from_local(at_position, data)
	var is_valid := GameState.can_place_item_in_storage(
		str(data.get("item_instance_id", "")),
		target_cell)
	_set_drop_preview(target_cell, _footprint_from_data(data), is_valid)
	return is_valid

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var cell := _cell_from_local(at_position)
	_clear_drop_preview()
	item_dropped.emit(data, cell)

func _draw() -> void:
	var total_size := Vector2(columns * cell_size, rows * cell_size)
	draw_rect(Rect2(Vector2.ZERO, total_size), Color(0.11, 0.10, 0.09, 0.95), true)
	if preview_cell.x >= 0 or preview_cell.y >= 0:
		var highlight_color := Color(0.22, 0.75, 0.30, 0.52) if preview_is_valid else Color(0.88, 0.22, 0.18, 0.58)
		for y in range(preview_footprint.y):
			for x in range(preview_footprint.x):
				var cell := preview_cell + Vector2i(x, y)
				if cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows:
					draw_rect(Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size), highlight_color, true)
	for x in range(columns + 1):
		var px := float(x * cell_size)
		draw_line(Vector2(px, 0), Vector2(px, total_size.y), Color(0.30, 0.26, 0.21), 1.0)
	for y in range(rows + 1):
		var py := float(y * cell_size)
		draw_line(Vector2(0, py), Vector2(total_size.x, py), Color(0.30, 0.26, 0.21), 1.0)

func _cell_from_local(local_position: Vector2) -> Vector2i:
	var x := int(floor(local_position.x / float(cell_size)))
	var y := int(floor(local_position.y / float(cell_size)))
	return Vector2i(x, y)

func _target_cell_from_local(local_position: Vector2, data: Dictionary) -> Vector2i:
	var target_cell := _cell_from_local(local_position)
	var grab_offset = data.get("grab_offset", null)
	if typeof(grab_offset) == TYPE_VECTOR2I:
		target_cell -= grab_offset
	return target_cell

func _footprint_from_data(data: Dictionary) -> Vector2i:
	var footprint = data.get("footprint", Vector2i.ONE)
	if typeof(footprint) != TYPE_VECTOR2I:
		return Vector2i.ONE
	return Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))

func _set_drop_preview(cell: Vector2i, footprint: Vector2i, is_valid: bool) -> void:
	if preview_cell == cell and preview_footprint == footprint and preview_is_valid == is_valid:
		return
	preview_cell = cell
	preview_footprint = footprint
	preview_is_valid = is_valid
	queue_redraw()

func _clear_drop_preview() -> void:
	_set_drop_preview(Vector2i(-1, -1), Vector2i.ONE, false)

func _process(_delta: float) -> void:
	if not get_viewport().gui_is_dragging():
		_clear_drop_preview()
