extends RefCounted
class_name ButtonThemeFactory

const FRAME_PATH := "res://assets/sprites/ui/buttons/button_frame.png"
const CORNER_PATH := "res://assets/sprites/ui/buttons/button_frame_corner.png"
const GAME_FONT_PATH := "res://assets/fonts/PixelifySans.ttf"
const BASE_FILL_COLOR := Color("bd5f31")
const CORNER_PROTRUSION := 2

static var _theme_cache: Theme
static var _font_cache: Font

static func get_theme() -> Theme:
	if _theme_cache == null:
		_theme_cache = _build_theme()
	return _theme_cache

static func apply_to(control: Control) -> void:
	control.theme = get_theme()
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func game_font() -> Font:
	if _font_cache == null:
		_font_cache = load(GAME_FONT_PATH) as Font
	return _font_cache if _font_cache != null else ThemeDB.fallback_font

static func _build_theme() -> Theme:
	var frame := _load_image(FRAME_PATH)
	var corner := _load_image(CORNER_PATH)
	if frame == null or corner == null:
		var fallback_theme := Theme.new()
		_apply_font(fallback_theme)
		return fallback_theme

	var corner_w := corner.get_width()
	var corner_h := corner.get_height()

	var normal_style := _make_button_style(frame, corner, BASE_FILL_COLOR)
	var hover_style := _make_button_style(frame, corner, _lighten(BASE_FILL_COLOR, 0.12))
	var pressed_style := _make_button_style(frame, corner, _darken(BASE_FILL_COLOR, 0.16))
	var disabled_style := _make_button_style(frame, corner, _disabled_fill(BASE_FILL_COLOR))

	var theme := Theme.new()
	_apply_font(theme)
	for type_name in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, normal_style.duplicate())
		theme.set_stylebox("hover", type_name, hover_style.duplicate())
		theme.set_stylebox("pressed", type_name, pressed_style.duplicate())
		theme.set_stylebox("disabled", type_name, disabled_style.duplicate())
		theme.set_stylebox("focus", type_name, hover_style.duplicate())
		theme.set_color("font_color", type_name, Color("fff3e8"))
		theme.set_color("font_hover_color", type_name, Color("fffaf5"))
		theme.set_color("font_pressed_color", type_name, Color("f5e2cf"))
		theme.set_color("font_focus_color", type_name, Color("fffaf5"))
		theme.set_color("font_disabled_color", type_name, Color("dbc1af"))

	theme.set_stylebox("panel", "PopupMenu", normal_style.duplicate())
	theme.set_color("font_color", "PopupMenu", Color("fff3e8"))
	theme.set_color("font_hover_color", "PopupMenu", Color("fffaf5"))
	theme.set_color("font_disabled_color", "PopupMenu", Color("dbc1af"))
	return theme

static func _apply_font(theme: Theme) -> void:
	var font := game_font()
	for type_name in ["Button", "OptionButton", "Label", "Panel", "PopupMenu", "RichTextLabel"]:
		theme.set_font("font", type_name, font)

static func _make_button_style(frame: Image, corner: Image, fill_color: Color) -> StyleBoxTexture:
	var frame_w := frame.get_width()
	var frame_h := frame.get_height()
	var corner_w := corner.get_width()
	var corner_h := corner.get_height()
	var protrusion := CORNER_PROTRUSION
	var core_width := corner_w * 2 + frame_w
	var core_height := corner_h * 2 + frame_h
	var width := core_width + (protrusion * 2)
	var height := core_height + (protrusion * 2)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var core_left := protrusion
	var core_top := protrusion
	var core_right := core_left + core_width
	var core_bottom := core_top + core_height
	image.fill_rect(Rect2i(core_left, core_top, core_width, core_height), fill_color)

	var edge_x_inset := maxi(0, corner_w - protrusion)
	var edge_y_inset := maxi(0, corner_h - protrusion)
	var edge_start_x := core_left + edge_x_inset
	var edge_end_x := core_right - edge_x_inset
	var edge_start_y := core_top + edge_y_inset
	var edge_end_y := core_bottom - edge_y_inset

	var top_clip := Rect2i(edge_start_x, core_top, maxi(0, edge_end_x - edge_start_x), frame_h)
	var bottom_clip := Rect2i(edge_start_x, core_bottom - frame_h, maxi(0, edge_end_x - edge_start_x), frame_h)
	var left_clip := Rect2i(core_left, edge_start_y, frame_h, maxi(0, edge_end_y - edge_start_y))
	var right_clip := Rect2i(core_right - frame_h, edge_start_y, frame_h, maxi(0, edge_end_y - edge_start_y))

	for x in range(edge_start_x, edge_end_x, frame_w):
		_blit_with_clip(image, frame, Vector2i(x, core_top), 0, false, false, top_clip)
		_blit_with_clip(image, frame, Vector2i(x, core_bottom - frame_h), 0, false, true, bottom_clip)

	for y in range(edge_start_y, edge_end_y, frame_w):
		_blit_with_clip(image, frame, Vector2i(core_left, y), 3, false, false, left_clip)
		_blit_with_clip(image, frame, Vector2i(core_right - frame_h, y), 1, false, false, right_clip)

	var full_clip := Rect2i(0, 0, width, height)
	# Source corner art is authored as top-left.
	_blit_with_clip(image, corner, Vector2i(core_left - protrusion, core_top - protrusion), 0, false, false, full_clip)
	_blit_with_clip(image, corner, Vector2i(core_right - corner_w + protrusion, core_top - protrusion), 0, true, false, full_clip)
	_blit_with_clip(image, corner, Vector2i(core_left - protrusion, core_bottom - corner_h + protrusion), 0, false, true, full_clip)
	_blit_with_clip(image, corner, Vector2i(core_right - corner_w + protrusion, core_bottom - corner_h + protrusion), 0, true, true, full_clip)

	var texture := ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = float(corner_w + protrusion)
	style.texture_margin_top = float(corner_h + protrusion)
	style.texture_margin_right = float(corner_w + protrusion)
	style.texture_margin_bottom = float(corner_h + protrusion)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.expand_margin_left = float(protrusion)
	style.expand_margin_top = float(protrusion)
	style.expand_margin_right = float(protrusion)
	style.expand_margin_bottom = float(protrusion)
	style.draw_center = true
	style.set_content_margin(SIDE_LEFT, float(corner_w + 2))
	style.set_content_margin(SIDE_TOP, float(corner_h - 1))
	style.set_content_margin(SIDE_RIGHT, float(corner_w + 2))
	style.set_content_margin(SIDE_BOTTOM, float(corner_h - 1))
	return style

static func _load_image(path: String) -> Image:
	# Source .png files are not shipped in exports; only the imported texture is.
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image = image.duplicate()
	if image.is_compressed() and image.decompress() != OK:
		return null
	return image

static func _blit_with_clip(
	dst: Image,
	src: Image,
	dst_pos: Vector2i,
	rotation_quarters: int,
	flip_h: bool,
	flip_v: bool,
	clip: Rect2i
) -> void:
	var q := posmod(rotation_quarters, 4)
	var src_w := src.get_width()
	var src_h := src.get_height()
	for sy in src_h:
		for sx in src_w:
			var tx := src_w - 1 - sx if flip_h else sx
			var ty := src_h - 1 - sy if flip_v else sy
			var ox := 0
			var oy := 0
			match q:
				0:
					ox = tx
					oy = ty
				1:
					ox = src_h - 1 - ty
					oy = tx
				2:
					ox = src_w - 1 - tx
					oy = src_h - 1 - ty
				_:
					ox = ty
					oy = src_w - 1 - tx
			var dx := dst_pos.x + ox
			var dy := dst_pos.y + oy
			if dx < clip.position.x or dy < clip.position.y:
				continue
			if dx >= clip.position.x + clip.size.x or dy >= clip.position.y + clip.size.y:
				continue
			if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
				continue
			var color := src.get_pixel(sx, sy)
			if color.a <= 0.0:
				continue
			dst.set_pixel(dx, dy, color)

static func _lighten(color: Color, amount: float) -> Color:
	return Color(
		lerpf(color.r, 1.0, amount),
		lerpf(color.g, 1.0, amount),
		lerpf(color.b, 1.0, amount),
		color.a
	)

static func _darken(color: Color, amount: float) -> Color:
	return Color(
		color.r * (1.0 - amount),
		color.g * (1.0 - amount),
		color.b * (1.0 - amount),
		color.a
	)

static func _disabled_fill(color: Color) -> Color:
	var gray := (color.r + color.g + color.b) / 3.0
	return Color(
		lerpf(color.r, gray, 0.45),
		lerpf(color.g, gray, 0.45),
		lerpf(color.b, gray, 0.45),
		color.a
	)
