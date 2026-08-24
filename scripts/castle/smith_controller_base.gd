extends Control
class_name SmithControllerBase
## Shared base for the Weapon Smith and Armour Smith building controllers.
## Lists a fixed set of craftable ItemData recipes and lets the player spend
## materials (via GameState.craft_item) to add new owned equipment instances.
##
## Configuration contract for subclasses:
## A subclass script should set `building_id` and `recipe_ids` before this
## base's `_ready()` runs its `_build_rows()` — either by overriding the
## `@export` defaults directly in the subclass script (e.g.
## `@export var building_id: String = "weapon_smith"` and
## `@export var recipe_ids: Array[String] = ["iron_sword", "steel_blade", "golden_edge"]`)
## or by assigning them in the subclass's own `_ready()` before calling
## `super._ready()`. Either approach works since both are plain exported
## fields read by `_build_rows()`.
##
## Scene contract: any scene using this base (or a subclass of it) must have
## a `VBoxContainer` named `RecipeList` as a direct child of the root Control,
## matching the `@onready var recipe_list` lookup below.

@export var building_id: String = ""
@export var recipe_ids: Array[String] = []

@onready var recipe_list: VBoxContainer = $RecipeList

func _ready() -> void:
	_build_rows()

## Public refresh hook, mirrors TavernController.refresh() — lets a parent
## Castle panel rebuild the recipe list when this panel becomes visible.
func refresh() -> void:
	_build_rows()

## Clears and rebuilds one row per recipe id, each showing the item's stats,
## its material cost, and a Craft button gated on smith level/capacity/materials.
func _build_rows() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	for def_id in recipe_ids:
		var def: ItemData = load("res://data/items/%s.tres" % def_id)
		if def == null:
			continue

		var row := HBoxContainer.new()

		var locked: bool = GameState.building_levels.get(building_id, 1) < def.required_smith_level
		var name_label := Label.new()
		var name_text := def.display_name
		var bonus_summary := _bonus_summary(def)
		if not bonus_summary.is_empty():
			name_text += " (%s)" % bonus_summary
		if locked:
			name_text = "[Locked] " + name_text
		name_label.text = name_text
		name_label.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_label)

		var cost_label := Label.new()
		cost_label.text = _recipe_cost_text(def)
		cost_label.custom_minimum_size = Vector2(160, 0)
		row.add_child(cost_label)

		var button := Button.new()
		button.text = "Craft"
		button.disabled = locked or _inventory_full() or not _has_materials(def)
		button.pressed.connect(_on_craft_pressed.bind(def_id))
		row.add_child(button)

		recipe_list.add_child(row)

## Builds a short ", "-joined summary of this recipe's non-zero stat bonuses.
func _bonus_summary(def: ItemData) -> String:
	var parts: Array[String] = []
	if def.damage_bonus != 0:
		parts.append("+%d dmg" % def.damage_bonus)
	if def.range_bonus != 0:
		parts.append("+%d range" % def.range_bonus)
	if def.attack_pool_bonus != 0:
		parts.append("+%d pool" % def.attack_pool_bonus)
	if def.attack_regen_bonus != 0:
		parts.append("+%d regen" % def.attack_regen_bonus)
	return ", ".join(parts)

## Builds a ", "-joined "3x refined_copper" style summary of a recipe's material cost.
func _recipe_cost_text(def: ItemData) -> String:
	var parts: Array[String] = []
	for material_id in def.recipe_materials:
		parts.append("%dx %s" % [def.recipe_materials[material_id], material_id])
	return ", ".join(parts)

## True when the Armoury is already at its owned-items capacity.
func _inventory_full() -> bool:
	return GameState.owned_items.size() >= GameState.capacity_for("armoury")

## True when GameState.materials can cover every material this recipe requires.
func _has_materials(def: ItemData) -> bool:
	for material_id in def.recipe_materials:
		if GameState.materials.get(material_id, 0) < def.recipe_materials[material_id]:
			return false
	return true

func _on_craft_pressed(def_id: String) -> void:
	GameState.craft_item(def_id)
	_build_rows()
