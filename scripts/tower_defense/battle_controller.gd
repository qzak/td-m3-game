extends Node2D
class_name TDBattleController
## Vertical-slice battle loop: alternates move/attack steps on a timer.

const ENEMY_SCENE := preload("res://scenes/tower_defense/enemy_unit.tscn")
const ADVENTURER_SCENE := preload("res://scenes/tower_defense/adventurer_unit.tscn")

@export var step_interval: float = 0.5
@export var enemy_data: EnemyData
@export var enemy_count: int = 6
@export var spawn_interval_steps: int = 2
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

var enemies_remaining_to_spawn: int = 0
var steps_until_next_spawn: int = 0
var castle_hp: int = 0
var is_move_phase: bool = true
var battle_started: bool = false
var battle_over: bool = false

var selected_adventurer_data: AdventurerData = null
var placed_adventurer_ids: Dictionary = {}  # AdventurerData.id -> true, one copy of each allowed
var adventurer_buttons: Dictionary = {}  # AdventurerData.id -> Button

func _ready() -> void:
	castle_hp = starting_castle_hp
	enemies_remaining_to_spawn = enemy_count

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
	start_button.pressed.connect(_start_battle)

	_update_hud()

func _start_battle() -> void:
	if battle_started:
		return
	battle_started = true
	start_button.disabled = true
	place_warrior_button.disabled = true
	place_archer_button.disabled = true
	place_mage_button.disabled = true
	grid.clear_range_preview()
	EventBus.day_started.emit(0)
	step_timer.start()

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

	if enemies_remaining_to_spawn > 0:
		if steps_until_next_spawn <= 0:
			_spawn_enemy()
			enemies_remaining_to_spawn -= 1
			steps_until_next_spawn = spawn_interval_steps
		else:
			steps_until_next_spawn -= 1

	for adventurer in adventurers:
		adventurer.regen()

	_update_hud()
	_check_end_conditions()

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

func _spawn_enemy() -> void:
	var enemy: TDEnemy = ENEMY_SCENE.instantiate()
	units_root.add_child(enemy)
	enemy.setup(enemy_data, grid)
	enemies.append(enemy)
	EventBus.wave_spawned.emit(0)

func _check_end_conditions() -> void:
	if battle_over:
		return
	if castle_hp <= 0:
		battle_over = true
		step_timer.stop()
		result_label.text = "Day Failed"
		EventBus.day_lost.emit(0)
		return
	if battle_started and enemies_remaining_to_spawn <= 0 and enemies.is_empty():
		battle_over = true
		step_timer.stop()
		result_label.text = "Day Cleared!"
		EventBus.day_won.emit(0)

func _update_hud() -> void:
	castle_hp_label.text = "Castle HP: %d" % castle_hp
	wave_label.text = "Enemies left to spawn: %d" % enemies_remaining_to_spawn
