extends Node2D
class_name WorldStatBar

@export var bar_size: Vector2 = Vector2(34.0, 6.0)
@export var corner_radius: int = 2
@export var fill_color: Color = Color(0.28, 0.86, 0.38, 1.0)
@export var empty_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.9)
@export var border_width: float = 1.0

var _ratio: float = 1.0

func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(-bar_size.x * 0.5, -bar_size.y * 0.5), bar_size)
	_draw_rounded(rect, empty_color)
	if _ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * _ratio, rect.size.y))
		_draw_rounded(fill_rect, fill_color)
	if border_width > 0.0:
		draw_rect(rect, border_color, false, border_width)

func _draw_rounded(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(corner_radius)
	draw_style_box(style, rect)
