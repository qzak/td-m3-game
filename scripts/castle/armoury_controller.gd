extends Control
class_name ArmouryController
## Inventory-grid armoury that supports drag/drop equip and unequip.

const SLOT_DROP_SCRIPT := preload("res://scripts/castle/armoury_slot_drop.gd")
const DRAG_ITEM_SCRIPT := preload("res://scripts/castle/armoury_drag_item.gd")

@onready var capacity_label: Label = $CapacityLabel
@onready var inventory_grid: Control = $ContentRow/InventoryColumn/InventoryGrid
@onready var adventurer_list: VBoxContainer = $ContentRow/RightColumn/AdventurerList
@onready var selected_adventurer_label: Label = $ContentRow/RightColumn/SelectedAdventurerLabel
@onready var slot_list: VBoxContainer = $ContentRow/RightColumn/SlotList
@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

var selected_adventurer_instance_id: String = ""
var item_tooltip: PanelContainer

func _ready() -> void:
	upgrade_row.building_id = "armoury"
	inventory_grid.item_dropped.connect(_on_inventory_grid_drop)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	_create_item_tooltip()
	refresh()

func refresh() -> void:
	_apply_grid_dimensions()
	upgrade_row.refresh()
	_build_rows()

func _apply_grid_dimensions() -> void:
	var grid_size := GameState.armoury_grid_size()
	inventory_grid.set("columns", grid_size.x)
	inventory_grid.set("rows", grid_size.y)
	inventory_grid.custom_minimum_size = Vector2(grid_size.x * int(inventory_grid.get("cell_size")), grid_size.y * int(inventory_grid.get("cell_size")))
	inventory_grid.queue_redraw()

func _build_rows() -> void:
	_hide_item_tooltip()
	for child in adventurer_list.get_children():
		child.queue_free()
	for child in slot_list.get_children():
		child.queue_free()
	for child in inventory_grid.get_children():
		child.queue_free()

	var stored_count := 0
	for entry in GameState.owned_items:
		if _entry_storage_cell(entry).x >= 0:
			stored_count += 1
	var grid_size := GameState.armoury_grid_size()
	capacity_label.text = "Stored: %d | Equipped/held: %d | Grid: %dx%d" % [
		stored_count,
		GameState.owned_items.size() - stored_count,
		grid_size.x,
		grid_size.y,
	]

	var active_adventurers: Array = _active_adventurer_entries()
	if active_adventurers.is_empty():
		selected_adventurer_instance_id = ""
		selected_adventurer_label.text = "No active adventurers"
	else:
		if selected_adventurer_instance_id == "":
			selected_adventurer_instance_id = str(active_adventurers[0].get("instance_id", ""))
		var still_exists := false
		for adventurer in active_adventurers:
			if str(adventurer.get("instance_id", "")) == selected_adventurer_instance_id:
				still_exists = true
				break
		if not still_exists:
			selected_adventurer_instance_id = str(active_adventurers[0].get("instance_id", ""))

	for adventurer in active_adventurers:
		_add_adventurer_button(adventurer)

	if selected_adventurer_instance_id != "":
		_build_slot_list(selected_adventurer_instance_id)

	_build_inventory_items()

func _active_adventurer_entries() -> Array:
	var result: Array = []
	for def_id in GameState.active_roster_ids:
		var adventurer := _find_owned_adventurer(def_id)
		if not adventurer.is_empty():
			result.append(adventurer)
	return result

func _add_adventurer_button(adventurer: Dictionary) -> void:
	var def_id := str(adventurer.get("def_id", ""))
	var adv_data: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
	if adv_data == null:
		return
	var instance_id := str(adventurer.get("instance_id", ""))
	var button := Button.new()
	button.text = adv_data.display_name
	if instance_id == selected_adventurer_instance_id:
		button.text = "> %s" % button.text
	button.pressed.connect(func():
		selected_adventurer_instance_id = instance_id
		_build_rows()
	)
	adventurer_list.add_child(button)

func _build_slot_list(adventurer_instance_id: String) -> void:
	var adventurer := _find_owned_adventurer_by_instance(adventurer_instance_id)
	if adventurer.is_empty():
		selected_adventurer_label.text = "Select an adventurer"
		return
	var def_id := str(adventurer.get("def_id", ""))
	var adv_data: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
	selected_adventurer_label.text = "Slots: %s" % (adv_data.display_name if adv_data != null else def_id)
	var equipped: Dictionary = adventurer.get("equipped", {})
	var slot_ids: Array[String] = GameState.equipment_slot_ids_for_adventurer(def_id)
	for slot_id in slot_ids:
		var slot_drop = SLOT_DROP_SCRIPT.new()
		slot_drop.configure(adventurer_instance_id, slot_id)
		slot_drop.custom_minimum_size = Vector2(240, 74)
		slot_drop.item_dropped.connect(_on_slot_item_dropped)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_drop.add_child(vbox)

		var slot_title := Label.new()
		slot_title.text = slot_id.capitalize()
		vbox.add_child(slot_title)

		var equipped_instance_id := str(equipped.get(slot_id, ""))
		if equipped_instance_id == "":
			var empty_label := Label.new()
			empty_label.text = "(empty)"
			vbox.add_child(empty_label)
		else:
			var def := _item_def_from_instance(equipped_instance_id)
			var item_name := def.display_name if def != null else equipped_instance_id
			var footprint := Vector2i.ONE
			var icon_kind := "item"
			if def != null:
				footprint = Vector2i(maxi(1, def.footprint.x), maxi(1, def.footprint.y))
				icon_kind = def.get_effective_slot_id()
			var cell_size := int(inventory_grid.get("cell_size"))
			var visual_size := Vector2(footprint.x * cell_size - 2, footprint.y * cell_size - 2)
			var drag_item = DRAG_ITEM_SCRIPT.new()
			drag_item.custom_minimum_size = visual_size
			drag_item.size = visual_size
			drag_item.configure({
				"kind": "armoury_item",
				"item_instance_id": equipped_instance_id,
				"icon_id": def.id if def != null else "",
				"source_kind": "slot",
				"source_adventurer_instance_id": adventurer_instance_id,
				"source_slot_id": slot_id,
				"footprint": footprint,
				"icon_kind": icon_kind,
				"drag_preview_size": visual_size,
			}, item_name)
			_connect_item_interactions(drag_item)
			vbox.add_child(drag_item)

		slot_list.add_child(slot_drop)

func _build_inventory_items() -> void:
	var cell_size := int(inventory_grid.get("cell_size"))
	for entry in GameState.owned_items:
		var cell := _entry_storage_cell(entry)
		if cell.x < 0 or cell.y < 0:
			continue
		var def := _item_def_from_entry(entry)
		if def == null:
			continue
		var footprint := Vector2i(maxi(1, def.footprint.x), maxi(1, def.footprint.y))
		var icon_kind := def.get_effective_slot_id()
		var item_node = DRAG_ITEM_SCRIPT.new()
		item_node.position = Vector2(cell.x * cell_size + 1, cell.y * cell_size + 1)
		var visual_size := Vector2(footprint.x * cell_size - 2, footprint.y * cell_size - 2)
		item_node.custom_minimum_size = visual_size
		item_node.size = item_node.custom_minimum_size
		item_node.configure({
			"kind": "armoury_item",
			"item_instance_id": str(entry.get("instance_id", "")),
			"icon_id": def.id,
			"source_kind": "grid",
			"source_cell": cell,
			"cell_size": cell_size,
			"footprint": footprint,
			"icon_kind": icon_kind,
			"drag_preview_size": visual_size,
		}, def.display_name)
		_connect_item_interactions(item_node)
		inventory_grid.add_child(item_node)

func _on_inventory_grid_drop(payload: Dictionary, cell: Vector2i) -> void:
	var item_instance_id := str(payload.get("item_instance_id", ""))
	if item_instance_id == "":
		return
	var target_cell := cell
	var grab_offset = payload.get("grab_offset", null)
	if typeof(grab_offset) == TYPE_VECTOR2I:
		target_cell -= grab_offset
	if GameState.place_item_in_storage(item_instance_id, target_cell):
		_build_rows()

func _on_slot_item_dropped(payload: Dictionary, adventurer_instance_id: String, slot_id: String) -> void:
	var item_instance_id := str(payload.get("item_instance_id", ""))
	if item_instance_id == "":
		return
	if GameState.equip_item_to_slot(adventurer_instance_id, item_instance_id, slot_id):
		selected_adventurer_instance_id = adventurer_instance_id
		_build_rows()

func _connect_item_interactions(item_node: Node) -> void:
	if item_node.has_signal("item_hovered"):
		item_node.connect("item_hovered", Callable(self, "_on_item_hovered"))
	if item_node.has_signal("item_unhovered"):
		item_node.connect("item_unhovered", Callable(self, "_on_item_unhovered"))
	if item_node.has_signal("item_tapped"):
		item_node.connect("item_tapped", Callable(self, "_on_item_tapped"))

func _on_item_hovered(payload: Dictionary, location: Vector2) -> void:
	_show_item_tooltip(str(payload.get("item_instance_id", "")), location)

func _on_item_unhovered() -> void:
	_hide_item_tooltip()

func _on_item_tapped(payload: Dictionary, location: Vector2) -> void:
	_show_item_tooltip(str(payload.get("item_instance_id", "")), location)

func _create_item_tooltip() -> void:
	item_tooltip = PanelContainer.new()
	item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_tooltip.z_index = 100
	var label := Label.new()
	label.custom_minimum_size = Vector2(240, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_tooltip.add_child(label)
	add_child(item_tooltip)
	item_tooltip.hide()

func _show_item_tooltip(item_instance_id: String, location: Vector2) -> void:
	var item_def := _item_def_from_instance(item_instance_id)
	if item_def == null:
		_hide_item_tooltip()
		return
	var label := item_tooltip.get_child(0) as Label
	label.text = _item_detail_text(item_def)
	item_tooltip.size = item_tooltip.get_combined_minimum_size()
	var viewport_size := get_viewport_rect().size
	item_tooltip.global_position = Vector2(
		clampf(location.x + 16.0, 0.0, maxf(0.0, viewport_size.x - item_tooltip.size.x)),
		clampf(location.y + 16.0, 0.0, maxf(0.0, viewport_size.y - item_tooltip.size.y))
	)
	item_tooltip.show()

func _hide_item_tooltip() -> void:
	if item_tooltip != null:
		item_tooltip.hide()

func _item_detail_text(item_def: ItemData) -> String:
	var stat_parts: Array[String] = []
	if item_def.damage_bonus != 0:
		stat_parts.append("+%d damage" % item_def.damage_bonus)
	if item_def.range_bonus != 0:
		stat_parts.append("+%d range" % item_def.range_bonus)
	if item_def.attack_pool_bonus != 0:
		stat_parts.append("+%d attack pool" % item_def.attack_pool_bonus)
	if item_def.attack_regen_bonus != 0:
		stat_parts.append("+%d attack regen" % item_def.attack_regen_bonus)
	if stat_parts.is_empty():
		stat_parts.append("No stat bonuses")
	return "%s\nSlot: %s\nSize: %dx%d\n%s" % [
		item_def.display_name,
		item_def.get_effective_slot_id(),
		maxi(1, item_def.footprint.x),
		maxi(1, item_def.footprint.y),
		", ".join(stat_parts),
	]

func _on_building_upgraded(building_id: String, _new_level: int) -> void:
	if building_id != "armoury":
		return
	GameState.refit_armoury_storage()
	_apply_grid_dimensions()
	_build_rows()

func _find_owned_adventurer(def_id: String) -> Dictionary:
	for adventurer in GameState.owned_adventurers:
		if str(adventurer.get("def_id", "")) == def_id:
			return adventurer
	return {}

func _find_owned_adventurer_by_instance(instance_id: String) -> Dictionary:
	for adventurer in GameState.owned_adventurers:
		if str(adventurer.get("instance_id", "")) == instance_id:
			return adventurer
	return {}

func _item_def_from_entry(entry: Dictionary) -> ItemData:
	return load("res://data/items/%s.tres" % str(entry.get("def_id", ""))) as ItemData

func _item_def_from_instance(item_instance_id: String) -> ItemData:
	for entry in GameState.owned_items:
		if str(entry.get("instance_id", "")) == item_instance_id:
			return _item_def_from_entry(entry)
	return null

func _entry_storage_cell(entry: Dictionary) -> Vector2i:
	var stored = entry.get("storage_cell", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return Vector2i(-1, -1)
	return Vector2i(int(stored.get("x", -1)), int(stored.get("y", -1)))
