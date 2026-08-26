extends Control
class_name TopResourceBar

const ENTRY_DEFS: Array[Dictionary] = [
	{"id": "currency", "label": "Gold", "swatch": Color("d7b34d"), "contexts": ["castle", "mine", "smith", "battle"]},
	{"id": "copper", "label": "Copper", "swatch": Color("c9794d"), "contexts": ["castle", "mine", "battle"]},
	{"id": "iron", "label": "Iron", "swatch": Color("aeb8bd"), "contexts": ["castle", "mine", "battle"]},
	{"id": "gold", "label": "Gold Ore", "swatch": Color("e6c34f"), "contexts": ["castle", "mine", "battle"]},
	{"id": "refined_copper", "label": "Ref. Copper", "swatch": Color("a65f3b"), "contexts": ["castle", "smith"]},
	{"id": "refined_iron", "label": "Ref. Iron", "swatch": Color("8e999f"), "contexts": ["castle", "smith"]},
	{"id": "refined_gold", "label": "Ref. Gold", "swatch": Color("c8a63d"), "contexts": ["castle", "smith"]},
]

@onready var chips: HBoxContainer = $Panel/Margin/Chips

var _context := "castle"
var _chip_rows: Dictionary = {}

func _ready() -> void:
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.materials_changed.connect(_on_materials_changed)
	_build_chips()
	_refresh_all()

func set_context(value: String) -> void:
	_context = value
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

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.color = def["swatch"]
		row.add_child(swatch)

		var label := Label.new()
		label.text = "%s: 0" % def["label"]
		label.add_theme_font_size_override("font_size", 16)
		row.add_child(label)

		chips.add_child(row)
		_chip_rows[def["id"]] = {"row": row, "label": label}

func _refresh_all() -> void:
	for def in ENTRY_DEFS:
		_refresh_chip_value(def["id"])
	_refresh_visibility()

func _refresh_chip_value(entry_id: String) -> void:
	if not _chip_rows.has(entry_id):
		return
	var chip_entry: Dictionary = _chip_rows[entry_id]
	var label: Label = chip_entry["label"]
	var display_name := _label_for(entry_id)
	var value := GameState.currency if entry_id == "currency" else int(GameState.materials.get(entry_id, 0))
	label.text = "%s: %d" % [display_name, value]

func _refresh_visibility() -> void:
	for def in ENTRY_DEFS:
		var entry_id: String = def["id"]
		if not _chip_rows.has(entry_id):
			continue
		var row: HBoxContainer = _chip_rows[entry_id]["row"]
		row.visible = _is_visible_in_context(def)

func _is_visible_in_context(def: Dictionary) -> bool:
	var contexts: Array = def.get("contexts", [])
	for context_name in contexts:
		if str(context_name) == _context:
			return true
	return false

func _label_for(entry_id: String) -> String:
	for def in ENTRY_DEFS:
		if def["id"] == entry_id:
			return def["label"]
	return entry_id.capitalize()
