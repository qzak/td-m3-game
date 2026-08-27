extends PanelContainer
class_name UnitInfoCard

const CARD_OFFSET := Vector2(14.0, 14.0)
const CARD_MARGIN := 8.0
const DEFAULT_WIDTH := 280.0
const MAX_WIDTH := 340.0

var _title_label: Label
var _body_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(DEFAULT_WIDTH, 0.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	panel_style.border_color = Color(0.72, 0.62, 0.42, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.max_lines_visible = 6
	_body_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_body_label)

func show_card(title: String, lines: Array[String], screen_position: Vector2) -> void:
	_title_label.text = title
	_body_label.text = "\n".join(lines)
	_fit_width_to_viewport()
	visible = true
	reset_size()
	_place(screen_position)
	call_deferred("_place_deferred", screen_position)

func hide_card() -> void:
	visible = false

func _place(screen_position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var card_size := get_combined_minimum_size()
	var place_right := screen_position.x + CARD_OFFSET.x + card_size.x <= viewport_size.x - CARD_MARGIN
	var place_down := screen_position.y + CARD_OFFSET.y + card_size.y <= viewport_size.y - CARD_MARGIN
	var desired_x := screen_position.x + CARD_OFFSET.x if place_right else screen_position.x - CARD_OFFSET.x - card_size.x
	var desired_y := screen_position.y + CARD_OFFSET.y if place_down else screen_position.y - CARD_OFFSET.y - card_size.y
	position.x = clampf(desired_x, CARD_MARGIN, viewport_size.x - card_size.x - CARD_MARGIN)
	position.y = clampf(desired_y, CARD_MARGIN, viewport_size.y - card_size.y - CARD_MARGIN)

func _fit_width_to_viewport() -> void:
	var viewport_width := get_viewport_rect().size.x
	var target_width := minf(MAX_WIDTH, viewport_width - CARD_MARGIN * 2.0)
	custom_minimum_size = Vector2(maxf(260.0, target_width), 0.0)

func _place_deferred(screen_position: Vector2) -> void:
	if not visible:
		return
	reset_size()
	_place(screen_position)
