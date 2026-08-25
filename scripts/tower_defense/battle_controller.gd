extends Node2D
class_name TDBattleController
## Vertical-slice battle loop: alternates move/attack steps on a timer.

const ENEMY_SCENE := preload("res://scenes/tower_defense/enemy_unit.tscn")
const ADVENTURER_SCENE := preload("res://scenes/tower_defense/adventurer_unit.tscn")

@export var step_interval: float = 0.5
@export var day_data: DayData
@export var starting_castle_hp: int = 10
@export var tower_data: TowerData

## Fallback roster used when GameState has no active roster yet (e.g. testing this scene directly).
@export var fallback_roster_ids: Array[String] = ["swordsman", "archer", "mage"]

@onready var grid: TDGridMap = $GridMap
@onready var units_root: Node2D = $UnitsRoot
@onready var step_timer: Timer = $StepTimer
@onready var castle_hp_label: Label = $UI/HUD/CastleHPLabel
@onready var wave_label: Label = $UI/HUD/WaveLabel
@onready var gold_label: Label = $UI/HUD/GoldLabel
@onready var result_label: Label = $UI/HUD/ResultLabel
@onready var selected_label: Label = $UI/HUD/SelectedLabel
@onready var start_button: Button = $UI/HUD/Controls/StartBattleButton
@onready var return_button: Button = $UI/HUD/Controls/ReturnToCastleButton
@onready var placement_buttons_container: HBoxContainer = $UI/HUD/Controls/PlacementButtonsContainer

var enemies: Array[TDEnemy] = []
var adventurers: Array[TDAdventurer] = []

var current_wave_index: int = 0
var current_wave_spawned_count: int = 0
var steps_until_next_spawn: int = 0
var total_enemies_remaining_to_spawn: int = 0
var wave_active: bool = false  # true while current_wave_index's enemies are actively spawning
var auto_call_next: bool = false  # if set, the next wave starts the instant this one finishes spawning
var castle_hp: int = 0
var is_move_phase: bool = true
var battle_started: bool = false
var battle_over: bool = false

var selected_adventurer_data: AdventurerData = null
var placed_adventurer_ids: Dictionary = {}  # AdventurerData.id -> true, one copy of each allowed
var adventurer_buttons: Dictionary = {}  # AdventurerData.id -> Button
var spell_pickers: Dictionary = {}  # AdventurerData.id -> OptionButton (magic units with >=2 spells)
var selected_spell_for: Dictionary = {}  # AdventurerData.id -> chosen spell id

## Placement/repositioning is only allowed before the first wave and during between-wave breathers.
var placement_open: bool = true
## The already-placed unit currently being repositioned (picked up), or null.
var picked_up_adventurer: TDAdventurer = null
var picked_up_origin_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	castle_hp = starting_castle_hp

	if GameState.selected_day_index > 0:
		var loaded_day: DayData = load("res://data/waves/day_%d.tres" % GameState.selected_day_index)
		if loaded_day != null:
			day_data = loaded_day

	for wave in day_data.waves:
		total_enemies_remaining_to_spawn += wave.count

	_build_placement_buttons()

	grid.cell_clicked.connect(_on_grid_cell_clicked)
	grid.cell_hovered.connect(_on_grid_cell_hovered)
	step_timer.wait_time = step_interval
	step_timer.timeout.connect(_on_step_timer_timeout)

	start_button.pressed.connect(_on_start_button_pressed)
	return_button.visible = false
	return_button.pressed.connect(_on_return_button_pressed)

	_spawn_towers()

	_update_start_button_label()
	_update_hud()

## Builds one placement button per adventurer in the active roster (falls back to a default
## trio when no roster has been chosen yet, e.g. running this scene directly for testing).
func _build_placement_buttons() -> void:
	var roster_ids: Array = GameState.active_roster_ids
	if roster_ids.is_empty():
		roster_ids = fallback_roster_ids

	for def_id in roster_ids:
		var def: AdventurerData = load("res://data/adventurers/%s.tres" % def_id)
		if def == null:
			continue

		var owned_entry: Dictionary = {}
		for entry in GameState.owned_adventurers:
			if entry["def_id"] == def_id:
				owned_entry = entry
				break

		var damage_bonus: int = 0
		var range_bonus: int = 0
		var attack_pool_bonus: int = 0
		var attack_regen_bonus: int = 0
		if not owned_entry.is_empty():
			var equipped: Dictionary = owned_entry["equipped"]
			for item_instance_id in [equipped.get("weapon", ""), equipped.get("armour", "")]:
				if item_instance_id == "":
					continue
				var item_entry: Dictionary = {}
				for candidate in GameState.owned_items:
					if candidate["instance_id"] == item_instance_id:
						item_entry = candidate
						break
				if item_entry.is_empty():
					continue
				var item_data: ItemData = load("res://data/items/%s.tres" % item_entry["def_id"])
				if item_data == null:
					continue
				damage_bonus += item_data.damage_bonus
				range_bonus += item_data.range_bonus
				attack_pool_bonus += item_data.attack_pool_bonus
				attack_regen_bonus += item_data.attack_regen_bonus

		var boosted: AdventurerData = def.duplicate()
		boosted.damage_min += damage_bonus
		boosted.damage_max += damage_bonus
		boosted.range_max += range_bonus
		boosted.attack_pool += attack_pool_bonus
		boosted.attack_regen += attack_regen_bonus

		var button := Button.new()
		button.text = "Place %s" % boosted.display_name
		button.pressed.connect(_select_adventurer.bind(boosted))
		placement_buttons_container.add_child(button)
		adventurer_buttons[boosted.id] = button

		_build_spell_picker(boosted)

## For a magic adventurer with two or more spells, adds an OptionButton next to its Place button
## so the player can choose which spell it will fight with before deploying it. The choice is
## stored in selected_spell_for (def id -> spell id) and passed into the unit's setup() on placement.
func _build_spell_picker(def: AdventurerData) -> void:
	if def.type != AdventurerData.AdventurerType.MAGIC or def.spell_ids.size() < 2:
		return
	var picker := OptionButton.new()
	for i in def.spell_ids.size():
		var spell_id: String = def.spell_ids[i]
		var spell: SpellData = load("res://data/adventurers/spells/%s.tres" % spell_id)
		var label: String = spell.display_name if spell != null else spell_id
		picker.add_item(label, i)
	picker.select(0)
	selected_spell_for[def.id] = def.spell_ids[0]
	picker.item_selected.connect(func(index: int): selected_spell_for[def.id] = def.spell_ids[index])
	placement_buttons_container.add_child(picker)
	spell_pickers[def.id] = picker

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/castle/castle.tscn")

## While a wave is actively spawning, toggles "auto-call the next wave" for when it finishes.
## Otherwise (no wave currently spawning), immediately starts the next wave.
func _on_start_button_pressed() -> void:
	if current_wave_index >= day_data.waves.size():
		return

	if wave_active:
		auto_call_next = not auto_call_next
		_update_start_button_label()
		return

	_begin_wave()

func _begin_wave() -> void:
	if not battle_started:
		battle_started = true
		EventBus.day_started.emit(day_data.day_index)
	_close_placement()

	wave_active = true
	auto_call_next = false
	current_wave_spawned_count = 0
	steps_until_next_spawn = 0
	if step_timer.is_stopped():
		is_move_phase = true
		result_label.text = ""
		step_timer.start()

	_update_start_button_label()

func _update_start_button_label() -> void:
	if current_wave_index >= day_data.waves.size():
		start_button.text = "All Waves Called"
		start_button.disabled = true
	elif wave_active:
		start_button.text = "Cancel Auto-Call" if auto_call_next else "Auto-Call Next Wave"
		start_button.disabled = false
	else:
		start_button.text = "Call Wave %d" % (current_wave_index + 1)
		start_button.disabled = false

func _select_adventurer(data: AdventurerData) -> void:
	if not placement_open:
		return
	# Each recruited adventurer is a unique individual, so only one copy can be on the field.
	if placed_adventurer_ids.has(data.id):
		return
	# Picking a reserve to deploy cancels any in-progress reposition.
	_cancel_pickup()
	selected_adventurer_data = data
	selected_label.text = 'Selected: %s (click a grid tile to place)' % data.display_name

func _on_grid_cell_hovered(cell: Vector2i, valid: bool) -> void:
	if not placement_open or not valid:
		grid.clear_range_preview()
		return
	var active := selected_adventurer_data
	if active == null and picked_up_adventurer != null:
		active = picked_up_adventurer.data
	if active == null:
		grid.clear_range_preview()
		return
	grid.set_range_preview(cell, active.range_min, active.range_max)

func _on_grid_cell_clicked(cell: Vector2i) -> void:
	if not placement_open:
		return

	# Placing a fresh reserve unit selected via a Place button.
	if selected_adventurer_data != null:
		if not grid.is_buildable(cell):
			return
		var adventurer: TDAdventurer = ADVENTURER_SCENE.instantiate()
		units_root.add_child(adventurer)
		var chosen_spell: String = selected_spell_for.get(selected_adventurer_data.id, "")
		adventurer.setup(selected_adventurer_data, cell, grid.cell_to_world(cell), chosen_spell)
		grid.occupied_cells[cell] = adventurer
		adventurers.append(adventurer)

		placed_adventurer_ids[selected_adventurer_data.id] = true
		if adventurer_buttons.has(selected_adventurer_data.id):
			adventurer_buttons[selected_adventurer_data.id].disabled = true
		if spell_pickers.has(selected_adventurer_data.id):
			spell_pickers[selected_adventurer_data.id].disabled = true
		selected_adventurer_data = null
		selected_label.text = "Selected: none"
		grid.clear_range_preview()
		return

	# Dropping a picked-up unit onto a buildable cell (clicking its origin cancels the move).
	if picked_up_adventurer != null:
		if not grid.is_buildable(cell):
			return
		picked_up_adventurer.move_to(cell, grid.cell_to_world(cell))
		grid.occupied_cells[cell] = picked_up_adventurer
		picked_up_adventurer = null
		selected_label.text = "Selected: none"
		grid.clear_range_preview()
		return

	# Nothing selected: clicking a player-placed unit picks it up for repositioning.
	# Towers live in reserved_cells (not occupied_cells), so they're never pickable.
	if grid.occupied_cells.has(cell):
		var unit: TDAdventurer = grid.occupied_cells[cell]
		grid.occupied_cells.erase(cell)
		picked_up_adventurer = unit
		picked_up_origin_cell = cell
		selected_label.text = "Moving %s (click a tile to move, or its own tile to cancel)" % unit.data.display_name
		grid.set_range_preview(cell, unit.data.range_min, unit.data.range_max)

## Opens the placement window (before the first wave, and during between-wave breathers),
## re-enabling Place buttons for any roster members not already on the field.
func _open_placement() -> void:
	placement_open = true
	for def_id: String in adventurer_buttons:
		adventurer_buttons[def_id].disabled = placed_adventurer_ids.has(def_id)
	for def_id: String in spell_pickers:
		spell_pickers[def_id].disabled = placed_adventurer_ids.has(def_id)

## Closes the placement window when a wave begins: returns any in-progress reposition to its
## origin, clears the selection/preview, and disables all Place buttons.
func _close_placement() -> void:
	_cancel_pickup()
	placement_open = false
	selected_adventurer_data = null
	selected_label.text = "Selected: none"
	grid.clear_range_preview()
	for button in placement_buttons_container.get_children():
		button.disabled = true

## Returns a picked-up unit to the cell it came from (used on cancel / when a wave starts).
func _cancel_pickup() -> void:
	if picked_up_adventurer == null:
		return
	picked_up_adventurer.move_to(picked_up_origin_cell, grid.cell_to_world(picked_up_origin_cell))
	grid.occupied_cells[picked_up_origin_cell] = picked_up_adventurer
	picked_up_adventurer = null

func _on_step_timer_timeout() -> void:
	if battle_over:
		return
	if is_move_phase:
		_move_step()
	else:
		_attack_step()
	is_move_phase = not is_move_phase

func _move_step() -> void:
	# Move existing enemies first so a freshly spawned enemy stays on the spawn tile this step.
	_resolve_enemy_movement()

	_process_spawn_queue()

	for adventurer in adventurers:
		adventurer.tick_stun()
		adventurer.regen()

	# Stuns apply after movement so a freshly stunned adventurer skips the upcoming attack step.
	for enemy in enemies:
		enemy.try_stun(adventurers)

	_update_hud()
	_check_end_conditions()

## Moves enemies front-to-back (closest to the castle first) so a slower enemy (or one that's
## resting between moves) blocks anyone behind it from advancing into its tile.
func _resolve_enemy_movement() -> void:
	var ordered: Array[TDEnemy] = enemies.duplicate()
	ordered.sort_custom(func(a: TDEnemy, b: TDEnemy) -> bool: return a.path_index > b.path_index)

	var claimed_cells: Dictionary = {}  # Vector2i -> true, tiles already resolved this step
	for enemy: TDEnemy in ordered:
		var target_cell: Vector2i = enemy.peek_target_cell()
		var blocked := target_cell != enemy.current_cell and claimed_cells.has(target_cell)
		if enemy.apply_move(not blocked):
			castle_hp = maxi(castle_hp - 1, 0)
			enemies.erase(enemy)
			enemy.queue_free()
			EventBus.castle_hp_changed.emit(castle_hp)
			continue
		claimed_cells[enemy.current_cell] = true

## Advances through day_data.waves in order, spawning one enemy at a time per wave's spacing.
## Only spawns while wave_active; once a wave finishes spawning, either auto-continues into
## the next wave (if auto_call_next was toggled on) or waits for a manual call.
func _process_spawn_queue() -> void:
	if not wave_active:
		return
	if steps_until_next_spawn > 0:
		steps_until_next_spawn -= 1
		return

	var wave: WaveData = day_data.waves[current_wave_index]
	_spawn_enemy(wave.enemy_data)
	current_wave_spawned_count += 1
	total_enemies_remaining_to_spawn -= 1
	EventBus.wave_spawned.emit(current_wave_index)

	if current_wave_spawned_count < wave.count:
		steps_until_next_spawn = wave.spawn_delay_steps
		return

	wave_active = false
	current_wave_index += 1
	current_wave_spawned_count = 0
	if auto_call_next and current_wave_index < day_data.waves.size():
		_begin_wave()
	else:
		auto_call_next = false
		_update_start_button_label()

func _attack_step() -> void:
	for adventurer in adventurers:
		var spell: SpellData = _resolve_spell(adventurer)
		var damage_multiplier: float = spell.damage_multiplier if spell != null else 1.0

		if spell != null and spell.is_aoe:
			while adventurer.can_attack():
				var targets := _find_targets_in_range(adventurer)
				if targets.is_empty():
					break
				adventurer.consume_pool()
				var kills: Array[TDEnemy] = []
				for target in targets.duplicate():
					_play_attack_visual(adventurer, target)
					var dmg := int(randi_range(adventurer.data.damage_min, adventurer.data.damage_max) * damage_multiplier)
					if target.take_damage(dmg):
						kills.append(target)
				for kill in kills:
					enemies.erase(kill)
					GameState.add_currency(kill.data.bounty)
					kill.play_death_animation()
		else:
			while adventurer.can_attack():
				var target := _find_target(adventurer)
				if target == null:
					break
				adventurer.consume_pool()
				_play_attack_visual(adventurer, target)
				var dmg := int(randi_range(adventurer.data.damage_min, adventurer.data.damage_max) * damage_multiplier)
				if target.take_damage(dmg):
					enemies.erase(target)
					GameState.add_currency(target.data.bounty)
					target.play_death_animation()
	_check_end_conditions()

func _play_attack_visual(adventurer: TDAdventurer, target: TDEnemy) -> void:
	match adventurer.data.type:
		AdventurerData.AdventurerType.PHYSICAL_MELEE:
			adventurer.play_melee_attack(target.position)
		_:
			adventurer.play_ranged_attack(target.position)

## Resolves the spell a magic adventurer is currently fighting with (its selected spell, falling
## back to the type's first spell). Returns null for non-magic units or those with no spells.
func _resolve_spell(adventurer: TDAdventurer) -> SpellData:
	if adventurer.data.type != AdventurerData.AdventurerType.MAGIC:
		return null
	var spell_id: String = adventurer.selected_spell_id
	if spell_id == "":
		if adventurer.data.spell_ids.is_empty():
			return null
		spell_id = adventurer.data.spell_ids[0]
	return load("res://data/adventurers/spells/%s.tres" % spell_id)

## Targets the valid enemy furthest along the path (closest to the castle).
func _find_target(adventurer: TDAdventurer) -> TDEnemy:
	var best: TDEnemy = null
	for enemy in enemies:
		if adventurer.is_in_range(enemy.current_cell):
			if best == null or enemy.path_index > best.path_index:
				best = enemy
	return best

## Collects every enemy currently in range of the adventurer, for AOE spellcasting.
func _find_targets_in_range(adventurer: TDAdventurer) -> Array[TDEnemy]:
	var targets: Array[TDEnemy] = []
	for enemy in enemies:
		if adventurer.is_in_range(enemy.current_cell):
			targets.append(enemy)
	return targets

func _spawn_enemy(enemy_data: EnemyData) -> void:
	var enemy: TDEnemy = ENEMY_SCENE.instantiate()
	units_root.add_child(enemy)
	enemy.setup(enemy_data, grid, day_data.difficulty_scalar)
	enemies.append(enemy)

## Fixed last-resort defenders flanking the castle door; never placed/removed by the player.
func _spawn_towers() -> void:
	if tower_data == null:
		return
	var door_cell: Vector2i = grid.path_cells[grid.path_cells.size() - 1]
	var level: int = GameState.building_levels.get("towers", 1)
	var stats := tower_data.stats_for_level(level)
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0)]:
		var cell := door_cell + offset
		if not grid.is_in_bounds(cell) or grid.path_cell_set.has(cell):
			continue
		grid.reserve_cell(cell)
		var tower_stats := AdventurerData.new()
		tower_stats.id = "tower_%d_%d" % [cell.x, cell.y]
		tower_stats.display_name = "Tower"
		tower_stats.range_min = stats["range_min"]
		tower_stats.range_max = stats["range_max"]
		tower_stats.damage_min = stats["damage_min"]
		tower_stats.damage_max = stats["damage_max"]
		tower_stats.attack_pool = stats["attack_pool"]
		tower_stats.attack_regen = stats["attack_regen"]

		var tower: TDAdventurer = ADVENTURER_SCENE.instantiate()
		units_root.add_child(tower)
		tower.setup(tower_stats, cell, grid.cell_to_world(cell))
		adventurers.append(tower)

func _check_end_conditions() -> void:
	if battle_over:
		return
	if castle_hp <= 0:
		battle_over = true
		step_timer.stop()
		result_label.text = "Day Failed"
		return_button.visible = true
		EventBus.day_lost.emit(day_data.day_index)
		return

	if wave_active or not enemies.is_empty():
		return  # still spawning or enemies still alive on the field

	if current_wave_index >= day_data.waves.size():
		battle_over = true
		step_timer.stop()
		result_label.text = "Day Cleared!"
		return_button.visible = true
		GameState.add_currency(day_data.completion_reward)
		EventBus.day_won.emit(day_data.day_index)
	else:
		# Field is clear and nothing is spawning — pause so adventurers stop gaining
		# attack points until the player calls the next wave, and re-open placement so the
		# player can deploy reserves or reposition units during the breather.
		step_timer.stop()
		_open_placement()
		result_label.text = "Wave cleared — place/move units, then call the next wave when ready"

func _update_hud() -> void:
	castle_hp_label.text = "Castle HP: %d" % castle_hp
	gold_label.text = "Gold: %d" % GameState.currency
	var wave_display := mini(current_wave_index + 1, day_data.waves.size())
	wave_label.text = "Day %d — Wave %d/%d — Enemies left to spawn: %d" % [
		day_data.day_index, wave_display, day_data.waves.size(), total_enemies_remaining_to_spawn
	]
