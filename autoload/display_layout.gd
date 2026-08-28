extends Node

const DESIGN_VIEWPORT_SIZE := Vector2i(1280, 720)

signal viewport_size_changed(viewport_size: Vector2)

var _viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	var root := get_tree().root
	if root != null and not root.size_changed.is_connected(_on_root_size_changed):
		root.size_changed.connect(_on_root_size_changed)
	_on_root_size_changed()


func design_viewport_size() -> Vector2i:
	return DESIGN_VIEWPORT_SIZE


func current_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(DESIGN_VIEWPORT_SIZE)
	return viewport.get_visible_rect().size


func extra_viewport_height() -> float:
	return maxf(0.0, current_viewport_size().y - float(DESIGN_VIEWPORT_SIZE.y))


func safe_area_rect() -> Rect2:
	var viewport_size := current_viewport_size()
	var fallback := Rect2(Vector2.ZERO, viewport_size)
	var safe_area := Rect2(DisplayServer.get_display_safe_area())
	if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0:
		return fallback

	var window_position := Vector2(DisplayServer.window_get_position())
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		var local_position := safe_area.position - window_position
		if local_position.x <= window_size.x and local_position.y <= window_size.y and local_position.x + safe_area.size.x >= 0.0 and local_position.y + safe_area.size.y >= 0.0:
			var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
			safe_area.position = local_position * scale
			safe_area.size *= scale

	safe_area.position.x = clampf(safe_area.position.x, 0.0, viewport_size.x)
	safe_area.position.y = clampf(safe_area.position.y, 0.0, viewport_size.y)
	var safe_end_x := clampf(safe_area.end.x, safe_area.position.x, viewport_size.x)
	var safe_end_y := clampf(safe_area.end.y, safe_area.position.y, viewport_size.y)
	safe_area.size = Vector2(safe_end_x - safe_area.position.x, safe_end_y - safe_area.position.y)
	if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0:
		return fallback
	return safe_area


func safe_area_margins() -> Dictionary:
	var viewport_size := current_viewport_size()
	var safe := safe_area_rect()
	return {
		"left": safe.position.x,
		"top": safe.position.y,
		"right": maxf(0.0, viewport_size.x - safe.end.x),
		"bottom": maxf(0.0, viewport_size.y - safe.end.y),
	}


func _on_root_size_changed() -> void:
	var current_size := current_viewport_size()
	if current_size.is_equal_approx(_viewport_size):
		return
	_viewport_size = current_size
	viewport_size_changed.emit(_viewport_size)
