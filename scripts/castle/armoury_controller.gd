extends Control
class_name ArmouryController
## Lets the player equip crafted items onto their active roster adventurers.

@onready var capacity_label: Label = $CapacityLabel
@onready var item_list: VBoxContainer = $ItemList
@onready var adventurer_list: VBoxContainer = $AdventurerList
@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

func _ready() -> void:
	upgrade_row.building_id = "armoury"
	upgrade_row.refresh()
	_build_rows()

func refresh() -> void:
	_build_rows()
	upgrade_row.refresh()

func _build_rows() -> void:
	for child in item_list.get_children():
		child.queue_free()
	for child in adventurer_list.get_children():
		child.queue_free()

	capacity_label.text = "Items: %d / %d" % [GameState.owned_items.size(), GameState.capacity_for("armoury")]

	for entry in GameState.owned_items:
		_add_item_row(entry)

	for def_id in GameState.active_roster_ids:
		_add_adventurer_row(def_id)

func _add_item_row(entry: Dictionary) -> void:
	var def: ItemData = load("res://data/items/%s.tres" % entry["def_id"])
	if def == null:
		return

	var instance_id: String = entry["instance_id"]
	var slot_key: String = "weapon" if def.slot == ItemData.ItemSlot.WEAPON else "armour"
	var equipped_on_def_id: String = _find_equipped_holder_def_id(instance_id)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = def.display_name
	if equipped_on_def_id != "":
		label.text += " (equipped: %s)" % equipped_on_def_id
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)

	for def_id in GameState.active_roster_ids:
		var adventurer := _find_owned_adventurer(def_id)
		if adventurer.is_empty():
			continue
		if adventurer["equipped"][slot_key] == instance_id:
			continue

		var button := Button.new()
		button.text = "-> %s" % def_id
		button.pressed.connect(_on_equip_pressed.bind(adventurer["instance_id"], instance_id))
		row.add_child(button)

	item_list.add_child(row)

func _add_adventurer_row(def_id: String) -> void:
	var adventurer := _find_owned_adventurer(def_id)
	if adventurer.is_empty():
		return
	var adv_data: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
	if adv_data == null:
		return

	var weapon_instance_id: String = adventurer["equipped"]["weapon"]
	var armour_instance_id: String = adventurer["equipped"]["armour"]
	var weapon_name := _item_display_name(weapon_instance_id)
	var armour_name := _item_display_name(armour_instance_id)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s — weapon: %s, armour: %s" % [adv_data.display_name, weapon_name, armour_name]
	label.custom_minimum_size = Vector2(280, 0)
	row.add_child(label)

	var unequip_weapon_button := Button.new()
	unequip_weapon_button.text = "Unequip Weapon"
	unequip_weapon_button.disabled = weapon_instance_id == ""
	unequip_weapon_button.pressed.connect(_on_unequip_pressed.bind(adventurer["instance_id"], "weapon"))
	row.add_child(unequip_weapon_button)

	var unequip_armour_button := Button.new()
	unequip_armour_button.text = "Unequip Armour"
	unequip_armour_button.disabled = armour_instance_id == ""
	unequip_armour_button.pressed.connect(_on_unequip_pressed.bind(adventurer["instance_id"], "armour"))
	row.add_child(unequip_armour_button)

	adventurer_list.add_child(row)

func _find_owned_adventurer(def_id: String) -> Dictionary:
	for adventurer in GameState.owned_adventurers:
		if adventurer["def_id"] == def_id:
			return adventurer
	return {}

func _find_owned_item(instance_id: String) -> Dictionary:
	for entry in GameState.owned_items:
		if entry["instance_id"] == instance_id:
			return entry
	return {}

func _item_display_name(instance_id: String) -> String:
	if instance_id == "":
		return "none"
	var entry := _find_owned_item(instance_id)
	if entry.is_empty():
		return "none"
	var def: ItemData = load("res://data/items/%s.tres" % entry["def_id"])
	if def == null:
		return "none"
	return def.display_name

func _find_equipped_holder_def_id(item_instance_id: String) -> String:
	for adventurer in GameState.owned_adventurers:
		if adventurer["equipped"]["weapon"] == item_instance_id or adventurer["equipped"]["armour"] == item_instance_id:
			return adventurer["def_id"]
	return ""

func _on_equip_pressed(adventurer_instance_id: String, item_instance_id: String) -> void:
	GameState.equip_item(adventurer_instance_id, item_instance_id)
	_build_rows()

func _on_unequip_pressed(adventurer_instance_id: String, slot: String) -> void:
	GameState.unequip_item(adventurer_instance_id, slot)
	_build_rows()
