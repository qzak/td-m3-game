extends Control
class_name WorkshopController

const RECIPE_IDS: Array[String] = ["dynamite", "shovel", "activate_trinket"]

@onready var objective_label: Label = $ObjectiveLabel
@onready var inventory_label: Label = $InventoryLabel
@onready var recipe_list: VBoxContainer = $RecipeList
@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

func _ready() -> void:
	upgrade_row.building_id = "workshop"
	refresh()

func refresh() -> void:
	objective_label.text = GameState.castle_objective_text()
	inventory_label.text = "Tools: Dynamite %d | Shovel %s | Trinket %s" % [
		GameState.dynamite_count,
		"Ready" if GameState.shovel_unlocked else "Locked",
		"Attuned" if GameState.progression.get("barrier_trinket_activated", false) else ("Owned" if GameState.progression.get("barrier_trinket_obtained", false) else "Missing"),
	]
	upgrade_row.refresh()
	_build_rows()

func _build_rows() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	for recipe_id in RECIPE_IDS:
		var recipe: Dictionary = GameState.WORKSHOP_RECIPES.get(recipe_id, {})
		if recipe.is_empty():
			continue
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(220, 0)
		name_label.text = str(recipe.get("display_name", recipe_id))
		row.add_child(name_label)
		var cost_label := Label.new()
		cost_label.custom_minimum_size = Vector2(220, 0)
		cost_label.text = _material_cost_text(recipe.get("materials", {}))
		row.add_child(cost_label)
		var craft_button := Button.new()
		craft_button.text = "Craft"
		craft_button.disabled = not _can_craft_recipe(recipe_id, recipe)
		craft_button.pressed.connect(_on_craft_pressed.bind(recipe_id))
		row.add_child(craft_button)
		recipe_list.add_child(row)

func _material_cost_text(costs: Dictionary) -> String:
	var chunks: Array[String] = []
	for material_id in costs:
		chunks.append("%dx %s" % [int(costs[material_id]), material_id])
	chunks.sort()
	return ", ".join(chunks)

func _can_craft_recipe(recipe_id: String, recipe: Dictionary) -> bool:
	if not GameState.progression.get("workshop_unlocked", false):
		return false
	var required_gate := str(recipe.get("requires_gate", ""))
	if not required_gate.is_empty() and GameState.gate_state(required_gate) != GameState.GATE_ACTIVE:
		return false
	if bool(recipe.get("requires_trinket", false)) and not GameState.progression.get("barrier_trinket_obtained", false):
		return false
	if recipe_id == "shovel" and GameState.shovel_unlocked:
		return false
	if recipe_id == "activate_trinket" and GameState.progression.get("barrier_trinket_activated", false):
		return false
	var costs: Dictionary = recipe.get("materials", {})
	for material_id in costs:
		if GameState.materials.get(material_id, 0) < int(costs[material_id]):
			return false
	return true

func _on_craft_pressed(recipe_id: String) -> void:
	GameState.craft_workshop_recipe(recipe_id)
	refresh()
