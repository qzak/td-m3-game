extends Node2D
class_name TDBattleController
## Vertical-slice battle loop: alternates move/attack steps on a timer.

const ENEMY_SCENE := preload("res://scenes/tower_defense/enemy_unit.tscn")
const ADVENTURER_SCENE := preload("res://scenes/tower_defense/adventurer_unit.tscn")

@export var step_interval: float = 0.5
@export var day_data: DayData
@export var starting_castle_hp: int = 10

@export var swordsman_data: AdventurerData
@export var archer_data: AdventurerData
@export var mage_data: AdventurerData

@onready var grid: TDGridMap = $GridMap
@onready var units_root: Node2D = $UnitsRoot
@onready var step_timer: Timer = $StepTimer
@onready var castle_hp_label: Label = $UI/HUD/CastleHPLabel
@onready var wave_label: Label = $UI/HUD/WaveLabel
@onready var result_label: Label = $UI/HUD/ResultLabel
@onready var selected_label: Label = $UI/HUD/SelectedLabel
@onready var start_button: Button = $UI/HUD/Controls/StartBattleButton
@onready var place_warrior_button: Button = $UI/HUD/Controls/PlaceSwordsmanButton
@onready var place_archer_button: Button = $UI/HUD/Controls/PlaceArcherButton
@onready var place_mage_button: Button = $UI/HUD/Controls/PlaceMageButton

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

func _ready() -> void:
	castle_hp = starting_castle_hp
	for wave in day_data.waves:
		total_enemies_remaining_to_spawn += wave.count

	adventurer_buttons = {
		swordsman_data.id: place_warrior_button,
		archer_data.id: place_archer_button,
		mage_data.id: place_mage_button,
	}

	grid.cell_clicked.connect(_on_grid_cell_clicked)
	grid.cell_hovered.connect(_on_grid_cell_hovered)
	step_timer.wait_time = step_interval
	step_timer.timeout.connect(_on_step_timer_timeout)

	place_warrior_button.pressed.connect(func(): _select_adventurer(swordsman_data))
	place_archer_button.pressed.connect(func(): _select_adventurer(archer_data))
	place_mage_button.pressed.connect(func(): _select_adventurer(mage_data))
	start_button.pressed.connect(_on_start_button_pressed)

	_update_start_button_label()
	_update_hud()

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
		place_warrior_button.disabled = true
		place_archer_button.disabled = true
		place_mage_button.disabled = true
		grid.clear_range_preview()
		EventBus.day_started.emit(day_data.day_index)

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
	# Each recruited adventurer is a unique individual, so only one copy can be on the field.
	if placed_adventurer_ids.has(data.id):
		return
	selected_adventurer_data = data
	selected_label.text = 'Selected: %s (click a grid tile to place)' % data.display_name

func _on_grid_cell_hovered(cell: Vector2i, valid: bool) -> void:
	if battle_started or selected_adventurer_data == null or not valid:
		grid.clear_range_preview()
		return
	grid.set_range_preview(cell, selected_adventurer_data.range_min, selected_adventurer_data.range_max)

func _on_grid_cell_clicked(cell: Vector2i) -> void:
	if battle_started or selected_adventurer_data == null:
		return
	if not grid.is_buildable(cell):
		return
	var adventurer: TDAdventurer = ADVENTURER_SCENE.instantiate()
	units_root.add_child(adventurer)
	adventurer.setup(selected_adventurer_data, cell, grid.cell_to_world(cell))
	grid.occupied_cells[cell] = adventurer
	adventurers.append(adventurer)

	placed_adventurer_ids[selected_adventurer_data.id] = true
	if adventurer_buttons.has(selected_adventurer_data.id):
		adventurer_buttons[selected_adventurer_data.id].disabled = true
	selected_adventurer_data = null
	selected_label.text = "Selected: none"
	grid.clear_range_preview()

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
	for enemy in enemies.duplicate():
		if enemy.advance():
			castle_hp = maxi(castle_hp - 1, 0)
			enemies.erase(enemy)
			enemy.queue_free()
			EventBus.castle_hp_changed.emit(castle_hp)

	_process_spawn_queue()

	for adventurer in adventurers:
		adventurer.regen()

	_update_hud()
	_check_end_conditions()

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
		while adventurer.can_attack():
			var target := _find_target(adventurer)
			if target == null:
				break
			adventurer.consume_pool()
			var dmg := randi_range(adventurer.data.damage_min, adventurer.data.damage_max)
			if target.take_damage(dmg):
				enemies.erase(target)
				target.queue_free()
	_check_end_conditions()

## Targets the valid enemy furthest along the path (closest to the castle).
func _find_target(adventurer: TDAdventurer) -> TDEnemy:
	var best: TDEnemy = null
	for enemy in enemies:
		if adventurer.is_in_range(enemy.current_cell):
			if best == null or enemy.path_index > best.path_index:
				best = enemy
	return best

func _spawn_enemy(enemy_data: EnemyData) -> void:
	var enemy: TDEnemy = ENEMY_SCENE.instantiate()
	units_root.add_child(enemy)
	enemy.setup(enemy_data, grid, day_data.difficulty_scalar)
	enemies.append(enemy)

func _check_end_conditions() -> void:
	if battle_over:
		return
	if castle_hp <= 0:
		battle_over = true
		step_timer.stop()
		result_label.text = "Day Failed"
		EventBus.day_lost.emit(day_data.day_index)
		return

	if wave_active or not enemies.is_empty():
		return  # still spawning or enemies still alive on the field

	if current_wave_index >= day_data.waves.size():
		battle_over = true
		step_timer.stop()
		result_label.text = "Day Cleared!"
		EventBus.day_won.emit(day_data.day_index)
	else:
		# Field is clear and nothing is spawning — pause so adventurers stop gaining
		# attack points until the player calls the next wave.
		step_timer.stop()
		result_label.text = "Wave cleared — call the next wave when ready"

func _update_hud() -> void:
	castle_hp_label.text = "Castle HP: %d" % castle_hp
	var wave_display := mini(current_wave_index + 1, day_data.waves.size())
	wave_label.text = "Day %d — Wave %d/%d — Enemies left to spawn: %d" % [
		day_data.day_index, wave_display, day_data.waves.size(), total_enemies_remaining_to_spawn
	]
