extends Control
class_name ResourceHUD

const COMPACT_MATERIAL_IDS: Array[String] = ["copper", "iron", "gold"]
const DETAIL_PRIORITY_IDS: Array[String] = [
	"copper",
	"iron",
	"gold",
	"refined_copper",
	"refined_iron",
	"refined_gold",
]

@onready var compact_button: Button = $Panel/Margin/VBox/CompactButton
@onready var details_panel: PanelContainer = $Panel/Margin/VBox/DetailsPanel
@onready var details_label: Label = $Panel/Margin/VBox/DetailsPanel/DetailsLabel

var details_pinned: bool = false
var hover_active: bool = false

func _ready() -> void:
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func(): _set_hover(false))
	compact_button.pressed.connect(_on_compact_pressed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.materials_changed.connect(_on_materials_changed)
	_refresh_text()
	_update_details_visibility()

func _on_compact_pressed() -> void:
	details_pinned = not details_pinned
	_update_details_visibility()

func _set_hover(active: bool) -> void:
	hover_active = active
	_update_details_visibility()

func _update_details_visibility() -> void:
	details_panel.visible = details_pinned or hover_active

func _on_currency_changed(_new_amount: int) -> void:
	_refresh_text()

func _on_materials_changed(_material_id: String, _new_amount: int) -> void:
	_refresh_text()

func _refresh_text() -> void:
	var compact_parts: Array[String] = ["Gold %d" % GameState.currency]
	for material_id in COMPACT_MATERIAL_IDS:
		compact_parts.append("%s %d" % [_short_material_name(material_id), int(GameState.materials.get(material_id, 0))])
	compact_button.text = "  ".join(compact_parts)

	var detail_lines: Array[String] = ["Resources", "Gold: %d" % GameState.currency]
	for material_id in _ordered_detail_material_ids():
		detail_lines.append("%s: %d" % [_full_material_name(material_id), int(GameState.materials.get(material_id, 0))])
	details_label.text = "\n".join(detail_lines)

func _ordered_detail_material_ids() -> Array[String]:
	var ids: Array[String] = []
	for material_id in DETAIL_PRIORITY_IDS:
		ids.append(material_id)

	var extras: Array[String] = []
	for key in GameState.materials.keys():
		var material_id := str(key)
		if not ids.has(material_id):
			extras.append(material_id)
	extras.sort()
	ids.append_array(extras)
	return ids

func _short_material_name(material_id: String) -> String:
	match material_id:
		"copper":
			return "Cu"
		"iron":
			return "Fe"
		"gold":
			return "Au"
		_:
			return _full_material_name(material_id)

func _full_material_name(material_id: String) -> String:
	var words := material_id.split("_")
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)
