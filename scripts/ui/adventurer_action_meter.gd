extends Node2D
class_name AdventurerActionMeter

@export var fill_size: Vector2 = Vector2(34.0, 5.0)
@export var pips_per_row: int = 5
@export var pip_size: Vector2 = Vector2(6.0, 5.0)
@export var pip_gap: float = 2.0
@export var row_gap: float = 2.0
@export var fill_color: Color = Color(0.35, 0.62, 1.0, 1.0)
@export var fill_stunned_color: Color = Color(0.62, 0.62, 0.62, 1.0)
@export var fill_empty_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var pip_full_color: Color = Color(1.0, 0.84, 0.3, 1.0)
@export var pip_empty_color: Color = Color(0.22, 0.22, 0.22, 0.95)
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.9)

var _pip_capacity: int = 1
var _full_pips: int = 0
var _partial_fill: float = 0.0
var _stunned: bool = false

func set_capacity(value: int) -> void:
	_pip_capacity = maxi(value, 1)
	queue_redraw()

func set_state(full_pips: int, partial_fill: float, stunned: bool) -> void:
	_full_pips = clampi(full_pips, 0, _pip_capacity)
	_partial_fill = clampf(partial_fill, 0.0, 1.0)
	_stunned = stunned
	queue_redraw()

func _draw() -> void:
	_draw_pips()
	_draw_fill_bar()

func _draw_pips() -> void:
	var cols := maxi(pips_per_row, 1)
	var rows := int(ceil(float(_pip_capacity) / float(cols)))
	var row_width := (float(cols) * pip_size.x) + (float(cols - 1) * pip_gap)
	var top_y := -fill_size.y - 3.0 - (float(rows) * pip_size.y + float(rows - 1) * row_gap)
	for index in range(_pip_capacity):
		var row := index / cols
		var col := index % cols
		var x := -row_width * 0.5 + col * (pip_size.x + pip_gap)
		var y := top_y + row * (pip_size.y + row_gap)
		var rect := Rect2(Vector2(x, y), pip_size)
		var color := pip_full_color if index < _full_pips else pip_empty_color
		_draw_rounded(rect, color, 1)

func _draw_fill_bar() -> void:
	var rect := Rect2(Vector2(-fill_size.x * 0.5, 0.0), fill_size)
	_draw_rounded(rect, fill_empty_color, 2)
	if _partial_fill > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * _partial_fill, rect.size.y))
		_draw_rounded(fill_rect, fill_stunned_color if _stunned else fill_color, 2)
	draw_rect(rect, border_color, false, 1.0)

func _draw_rounded(rect: Rect2, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
