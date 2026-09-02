extends Control
class_name BuildingUpgradeRow

@export var building_id: String = ""

@onready var name_level_label: Label = $Row/Labels/NameLevelLabel
@onready var cost_label: Label = $Row/Labels/CostLabel
@onready var effect_label: Label = $Row/Labels/EffectLabel
@onready var upgrade_button: Button = $Row/UpgradeButton

func _ready() -> void:
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.materials_changed.connect(_on_materials_changed)
	_refresh()

func refresh() -> void:
	_refresh()

func _refresh() -> void:
	if building_id == "":
		_show_missing_building_state()
		return

	var def := load("res://data/buildings/%s.tres" % building_id) as BuildingData
	if def == null:
		_show_missing_building_state()
		return

	var level: int = GameState.building_levels.get(building_id, 1)
	name_level_label.text = "%s — Level %d/%d" % [def.display_name, level, def.max_level]
	_set_effect_text(def, level)

	if level >= def.max_level:
		cost_label.text = "Max level"
		upgrade_button.disabled = true
		upgrade_button.visible = true
		return

	var idx: int = level - 1
	if idx < 0 or idx >= def.upgrade_currency_costs.size() or idx >= def.upgrade_material_costs.size():
		cost_label.text = "Max level"
		upgrade_button.disabled = true
		upgrade_button.visible = true
		return

	var currency_cost: int = def.upgrade_currency_costs[idx]
	var material_costs: Dictionary = def.upgrade_material_costs[idx]
	var cost_text := "Upgrade: %d gold" % currency_cost
	if not material_costs.is_empty():
		var material_parts: Array[String] = []
		var material_ids: Array = material_costs.keys()
		material_ids.sort()
		for material_id in material_ids:
			var amount := int(material_costs[material_id])
			if amount <= 0:
				continue
			material_parts.append("%d %s" % [amount, material_id])
		if not material_parts.is_empty():
			cost_text += ", %s" % ", ".join(material_parts)
	cost_label.text = cost_text
	upgrade_button.text = "Upgrade"
	upgrade_button.disabled = not _can_afford(currency_cost, material_costs)
	upgrade_button.visible = true

func _show_missing_building_state() -> void:
	name_level_label.text = "(no building configured)"
	cost_label.text = "—"
	effect_label.text = "Now/Next: —"
	upgrade_button.disabled = true
	upgrade_button.visible = false

func _set_effect_text(def: BuildingData, level: int) -> void:
	var current_text := _effect_for_level(def, level)
	if level >= def.max_level:
		effect_label.text = "Now: %s (max)" % current_text
		return
	var next_text := _effect_for_level(def, level + 1)
	effect_label.text = "Now/Next: %s -> %s" % [current_text, next_text]

func _effect_for_level(def: BuildingData, level: int) -> String:
	match building_id:
		"tavern":
			var cap := _int_for_level(def.capacity_by_level, level, 2 + level)
			var refresh_seconds := _int_for_level(def.tavern_refresh_seconds_by_level, level, 21600)
			return "Contracts %d, refresh %s" % [cap, _duration_text(refresh_seconds)]
		"quarters":
			return "Active slots %d" % _int_for_level(def.capacity_by_level, level, 2 + level)
		"smelter":
			var slots := _int_for_level(def.capacity_by_level, level, level)
			var multiplier := _float_for_level(def.smelter_time_multiplier_by_level, level, 1.0)
			return "Queue %d, smelt time x%.1f" % [slots, multiplier]
		"armoury":
			var grid_dimension := _int_for_level(def.capacity_by_level, level, 5 + ((level - 1) * 2))
			return "Grid %dx%d" % [grid_dimension, grid_dimension]
		"weapon_smith", "armour_smith":
			return "Unlocks recipes up to Lv%d" % level
		"workshop":
			return "Tool queue slots %d" % _int_for_level(def.capacity_by_level, level, 1)
		"towers":
			var tower_data: TowerData = load("res://data/buildings/towers_stats.tres")
			if tower_data == null:
				return "Tower stats unavailable"
			var stats := tower_data.stats_for_level(level)
			return "DMG %d-%d, RNG %d-%d, Regen %d" % [
				int(stats["damage_min"]),
				int(stats["damage_max"]),
				int(stats["range_min"]),
				int(stats["range_max"]),
				int(stats["attack_regen"]),
			]
		_:
			if not def.capacity_by_level.is_empty():
				return "Cap %d" % _int_for_level(def.capacity_by_level, level, 2 + level)
	return "No effect data"

func _int_for_level(values: Array[int], level: int, fallback: int) -> int:
	var index := level - 1
	if index >= 0 and index < values.size():
		return values[index]
	return fallback

func _float_for_level(values: Array[float], level: int, fallback: float) -> float:
	var index := level - 1
	if index >= 0 and index < values.size():
		return values[index]
	return fallback

func _duration_text(total_seconds: int) -> String:
	if total_seconds % 3600 == 0:
		return "%dh" % int(total_seconds / 3600)
	if total_seconds % 60 == 0:
		return "%dm" % int(total_seconds / 60)
	return "%ds" % total_seconds

func _can_afford(currency_cost: int, material_costs: Dictionary) -> bool:
	if GameState.currency < currency_cost:
		return false
	for material_id in material_costs:
		if GameState.materials.get(material_id, 0) < material_costs[material_id]:
			return false
	return true

func _on_upgrade_pressed() -> void:
	GameState.upgrade_building(building_id)
	_refresh()

func _on_building_upgraded(_building_id: String, _new_level: int) -> void:
	_refresh()

func _on_currency_changed(_new_amount: int) -> void:
	_refresh()

func _on_materials_changed(_material_id: String, _new_amount: int) -> void:
	_refresh()
