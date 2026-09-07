extends PanelContainer
class_name ArmouryDragItem

const ITEM_ICON_ROOT := "res://assets/sprites/items"

signal item_hovered(payload: Dictionary, location: Vector2)
signal item_unhovered()
signal item_tapped(payload: Dictionary, location: Vector2)

var drag_payload: Dictionary = {}
var display_text: String = ""

func configure(payload: Dictionary, text: String) -> void:
	drag_payload = payload
	display_text = text
	_rebuild()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): item_hovered.emit(drag_payload, get_global_mouse_position()))
	mouse_exited.connect(func(): item_unhovered.emit())
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.texture = _build_texture_for_payload(drag_payload)
	add_child(icon)

func _get_drag_data(at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	var payload := drag_payload.duplicate(true)
	if payload.get("source_kind", "") == "grid":
		var cell_size := maxi(1, int(payload.get("cell_size", 1)))
		payload["grab_offset"] = Vector2i(
			maxi(0, int(floor(at_position.x / float(cell_size)))),
			maxi(0, int(floor(at_position.y / float(cell_size))))
		)
	var drag_preview := Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := PanelContainer.new()
	var source_size := size
	if source_size.x <= 0 or source_size.y <= 0:
		source_size = get_combined_minimum_size()
	var preview_size := source_size
	var payload_preview_size = payload.get("drag_preview_size", null)
	if typeof(payload_preview_size) == TYPE_VECTOR2 and payload_preview_size.x > 0 and payload_preview_size.y > 0:
		preview_size = payload_preview_size
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.position = -preview_size * 0.5
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.texture = _build_texture_for_payload(payload)
	preview.add_child(icon)
	drag_preview.add_child(preview)
	drag_preview.tree_exiting.connect(func():
		if is_instance_valid(self):
			visible = true
	)
	set_drag_preview(drag_preview)
	visible = false
	return payload

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		item_tapped.emit(drag_payload, global_position + event.position)

func _build_icon_texture(icon_kind: String) -> Texture2D:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var stroke := Color(0.12, 0.10, 0.08, 1.0)
	var fill := Color(0.78, 0.70, 0.56, 1.0)
	match icon_kind:
		"weapon":
			_fill_rect(image, Rect2i(4, 10, 15, 4), fill)
			_fill_rect(image, Rect2i(2, 11, 2, 2), fill)
			_fill_rect(image, Rect2i(5, 8, 2, 8), stroke)
			_fill_rect(image, Rect2i(18, 10, 3, 4), stroke)
		"armour":
			_fill_rect(image, Rect2i(6, 5, 12, 14), fill)
			_fill_rect(image, Rect2i(3, 7, 4, 5), fill)
			_fill_rect(image, Rect2i(17, 7, 4, 5), fill)
			_fill_rect(image, Rect2i(10, 5, 4, 3), Color(0, 0, 0, 0))
			_fill_rect(image, Rect2i(6, 12, 2, 7), stroke)
			_fill_rect(image, Rect2i(16, 12, 2, 7), stroke)
		_:
			_fill_rect(image, Rect2i(7, 7, 10, 10), fill)
			_fill_rect(image, Rect2i(5, 11, 14, 2), stroke)
			_fill_rect(image, Rect2i(11, 5, 2, 14), stroke)
	return ImageTexture.create_from_image(image)

func _build_texture_for_payload(payload: Dictionary) -> Texture2D:
	var icon_id := str(payload.get("icon_id", "")).strip_edges()
	var icon_kind := str(payload.get("icon_kind", "item"))
	if icon_id != "":
		var folder := "weapons" if icon_kind == "weapon" else "armour"
		var candidate := "%s/%s/%s_icon.png" % [ITEM_ICON_ROOT, folder, icon_id]
		if ResourceLoader.exists(candidate):
			return load(candidate) as Texture2D
	return _build_icon_texture(icon_kind)

func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)
