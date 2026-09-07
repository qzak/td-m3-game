extends Control
class_name TopResourceBar

const ENTRY_DEFS: Array[Dictionary] = [
	{"id": "battle_wave", "label": "Wave", "swatch": Color("7ea7ff"), "contexts": ["battle"]},
	{"id": "battle_upcoming", "label": "Upcoming", "swatch": Color("c58fff"), "contexts": ["battle"]},
	{"id": "battle_drops", "label": "Drops", "swatch": Color("72be7f"), "contexts": ["battle"]},
	{"id": "currency", "label": "Coins", "swatch": Color("d7b34d"), "contexts": ["castle", "mine", "smith", "battle"]},
	{"id": "copper", "label": "Copper", "swatch": Color("c9794d"), "contexts": ["castle", "mine", "smith"]},
	{"id": "iron", "label": "Iron", "swatch": Color("aeb8bd"), "contexts": ["castle", "mine", "smith"]},
	{"id": "gold", "label": "Gold Ore", "swatch": Color("e6c34f"), "contexts": ["castle", "mine", "smith"]},
	{"id": "volatile_core", "label": "Volatile Core", "swatch": Color("c85a52"), "contexts": ["castle", "battle", "smith"]},
	{"id": "refined_copper", "label": "Ref. Copper", "swatch": Color("a65f3b"), "contexts": ["castle", "smith"]},
	{"id": "refined_iron", "label": "Ref. Iron", "swatch": Color("8e999f"), "contexts": ["castle", "smith"]},
	{"id": "refined_gold", "label": "Ref. Gold", "swatch": Color("c8a63d"), "contexts": ["castle", "smith"]},
]

const CONTEXT_TITLES := {
	"castle": "Castle",
	"battle": "Battle",
	"mine": "Mine",
	"smith": "Smithy",
}

const CONTEXT_ORDER := {
	"castle": ["currency", "volatile_core", "refined_iron", "refined_copper", "refined_gold", "iron", "copper", "gold"],
	"battle": ["battle_wave", "battle_upcoming", "battle_drops", "volatile_core", "currency"],
	"mine": ["gold", "iron", "copper", "currency"],
	"smith": ["refined_iron", "refined_copper", "refined_gold", "volatile_core", "currency", "iron", "copper", "gold"],
}
const ICON_ROOT := "res://assets/sprites/ui/resource_icons"
const BATTLE_ICON_ROOT := "res://assets/sprites/ui/battle_icons"

@onready var context_label: Label = $Panel/Margin/ContentRow/ContextLabel
@onready var chips: HBoxContainer = $Panel/Margin/ContentRow/Chips

var _context := "castle"
var _chip_rows: Dictionary = {}
var _battle_wave_summary: String = "Day 1 • Wave 1/1 • Spawn 0"
var _battle_upcoming_summary: String = "Upcoming none"
var _battle_drop_summary: String = "Drops none"

func _ready() -> void:
	_set_mouse_passthrough(self)
	resized.connect(_on_resized)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.materials_changed.connect(_on_materials_changed)
	_build_chips()
	_refresh_all()

func set_context(value: String) -> void:
	_context = value
	_refresh_visibility()

func set_battle_summaries(wave_summary: String, upcoming_summary: String, drop_summary: String) -> void:
	_battle_wave_summary = wave_summary
	_battle_upcoming_summary = upcoming_summary
	_battle_drop_summary = drop_summary
	_refresh_chip_value("battle_wave")
	_refresh_chip_value("battle_upcoming")
	_refresh_chip_value("battle_drops")
	_refresh_visibility()

func _on_currency_changed(_new_amount: int) -> void:
	_refresh_chip_value("currency")

func _on_materials_changed(material_id: String, _new_amount: int) -> void:
	_refresh_chip_value(material_id)

func _build_chips() -> void:
	for child in chips.get_children():
		child.queue_free()
	_chip_rows.clear()

	for def in ENTRY_DEFS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(14, 14)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _resolve_icon_texture(def)
		row.add_child(icon)

		var label := Label.new()
		label.text = "%s: 0" % def["label"]
		label.add_theme_font_size_override("font_size", 16)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		chips.add_child(row)
		_chip_rows[def["id"]] = {"row": row, "label": label, "icon": icon}

func _on_resized() -> void:
	_refresh_visibility()

func _refresh_all() -> void:
	for def in ENTRY_DEFS:
		_refresh_chip_value(def["id"])
	_refresh_visibility()

func _refresh_chip_value(entry_id: String) -> void:
	if not _chip_rows.has(entry_id):
		return
	var chip_entry: Dictionary = _chip_rows[entry_id]
	var label: Label = chip_entry["label"]
	match entry_id:
		"battle_wave":
			label.text = _battle_wave_summary
		"battle_upcoming":
			label.text = _battle_upcoming_summary
		"battle_drops":
			label.text = _battle_drop_summary
		_:
			var display_name := _label_for(entry_id)
			var value := GameState.currency if entry_id == "currency" else int(GameState.materials.get(entry_id, 0))
			label.text = "%s: %d" % [display_name, value]

func _refresh_visibility() -> void:
	context_label.text = str(CONTEXT_TITLES.get(_context, _context.capitalize()))
	var ordered_ids := _ordered_ids_for_context()
	var fitted_ids: Array = []
	var used_width := 0.0
	var available_width := chips.size.x
	if available_width <= 0.0:
		available_width = size.x - context_label.get_combined_minimum_size().x - 24.0
	var chip_gap := float(chips.get_theme_constant("separation"))
	for entry_id in ordered_ids:
		var row: HBoxContainer = _chip_rows[entry_id]["row"]
		var row_width := row.get_combined_minimum_size().x
		var extra_gap := chip_gap if not fitted_ids.is_empty() else 0.0
		var must_keep := fitted_ids.is_empty()
		if must_keep or used_width + extra_gap + row_width <= available_width:
			fitted_ids.append(entry_id)
			used_width += extra_gap + row_width
	var visible_index := 0
	var primary_id: String = str(fitted_ids[0]) if not fitted_ids.is_empty() else ""
	for def in ENTRY_DEFS:
		var entry_id: String = def["id"]
		if not _chip_rows.has(entry_id):
			continue
		var row: HBoxContainer = _chip_rows[entry_id]["row"]
		var visible := fitted_ids.has(entry_id)
		row.visible = visible
		if visible:
			chips.move_child(row, visible_index)
			visible_index += 1
	_apply_primary_style(primary_id)

func _ordered_ids_for_context() -> Array:
	var preferred: Array = CONTEXT_ORDER.get(_context, [])
	var ordered: Array = []
	for entry_id in preferred:
		if _chip_rows.has(entry_id):
			var def := _def_for(entry_id)
			if not def.is_empty() and _is_visible_in_context(def):
				ordered.append(entry_id)
	for def in ENTRY_DEFS:
		var entry_id: String = def["id"]
		if ordered.has(entry_id):
			continue
		if _is_visible_in_context(def):
			ordered.append(entry_id)
	return ordered

func _apply_primary_style(primary_id: String) -> void:
	for entry_id in _chip_rows:
		var chip_entry: Dictionary = _chip_rows[entry_id]
		var row: HBoxContainer = chip_entry["row"]
		var label: Label = chip_entry["label"]
		var icon: TextureRect = chip_entry["icon"]
		var is_primary: bool = entry_id == primary_id and row.visible
		label.add_theme_font_size_override("font_size", 18 if is_primary else 16)
		label.add_theme_color_override("font_color", Color("ffffff") if is_primary else Color("d7dcd8"))
		icon.custom_minimum_size = Vector2(18, 18) if is_primary else Vector2(14, 14)
		row.modulate = Color("ffffff") if is_primary else Color("e6ece8")

func _is_visible_in_context(def: Dictionary) -> bool:
	var contexts: Array = def.get("contexts", [])
	for context_name in contexts:
		if str(context_name) == _context:
			return true
	return false

func _label_for(entry_id: String) -> String:
	var def := _def_for(entry_id)
	if not def.is_empty():
		return def["label"]
	return entry_id.capitalize()

func _def_for(entry_id: String) -> Dictionary:
	for def in ENTRY_DEFS:
		if def["id"] == entry_id:
			return def
	return {}

func _set_mouse_passthrough(root: Control) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		if child is Control:
			_set_mouse_passthrough(child)

func _resolve_icon_texture(def: Dictionary) -> Texture2D:
	var entry_id := str(def.get("id", ""))
	var explicit_file := _icon_filename_for(entry_id)
	if explicit_file != "":
		var path := "%s/%s" % [BATTLE_ICON_ROOT if entry_id.begins_with("battle_") else ICON_ROOT, explicit_file]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	var swatch: Color = def.get("swatch", Color.WHITE)
	return _solid_icon_texture(swatch)

func _icon_filename_for(entry_id: String) -> String:
	match entry_id:
		"battle_wave":
			return "wave_icon.png"
		"battle_upcoming":
			return "upcoming_icon.png"
		"battle_drops":
			return "drops_icon.png"
		"currency":
			return "coins_icon.png"
		"copper":
			return "copper_icon.png"
		"iron":
			return "iron_icon.png"
		"gold":
			return "gold_ore_icon.png"
		"volatile_core":
			return "volatile_core_icon.png"
		"refined_copper":
			return "refined_copper_icon.png"
		"refined_iron":
			return "refined_iron_icon.png"
		"refined_gold":
			return "refined_gold_icon.png"
		_:
			return ""

func _solid_icon_texture(color: Color) -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
