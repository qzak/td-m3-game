extends Node2D
class_name TDEnemy
## A single enemy instance walking the fixed path.

var data: EnemyData
var grid: TDGridMap
var path_index: int = 0
var current_health: int
var current_cell: Vector2i
var move_cooldown: int = 0  # >0 means this enemy is resting and won't attempt to move yet

@onready var hp_label: Label = $HPLabel

func setup(p_data: EnemyData, p_grid: TDGridMap, health_multiplier: float = 1.0) -> void:
	data = p_data
	grid = p_grid
	current_health = int(round(data.health * health_multiplier))
	path_index = 0
	move_cooldown = 0
	current_cell = grid.path_cells[0]
	position = grid.cell_to_world(current_cell)
	_update_hp_label()

## Where this enemy would move to this step if nothing blocks it (no state change yet).
func peek_target_cell() -> Vector2i:
	if move_cooldown > 0:
		return current_cell
	var next_index := mini(path_index + _steps_this_move(), grid.path_cells.size() - 1)
	return grid.path_cells[next_index]

## Resolves this step's movement once blocking has been decided elsewhere.
## Returns true once it reaches the castle.
func apply_move(can_move: bool) -> bool:
	if move_cooldown > 0:
		move_cooldown -= 1
		return false
	if not can_move:
		return false  # blocked by another enemy ahead; stays put and retries next step

	var last_index := grid.path_cells.size() - 1
	path_index = mini(path_index + _steps_this_move(), last_index)
	current_cell = grid.path_cells[path_index]
	position = grid.cell_to_world(current_cell)
	move_cooldown = data.move_period - 1
	return path_index >= last_index

## Rolls the double-move ability, if this enemy has it, once per move step.
func _steps_this_move() -> int:
	if data.can_double_move and randf() < data.double_move_chance:
		return data.move_steps_per_turn * 2
	return data.move_steps_per_turn

## Stuns every adventurer within stun_range of this enemy's current cell.
func try_stun(adventurers: Array[TDAdventurer]) -> void:
	if not data.can_stun:
		return
	for adventurer in adventurers:
		var dist := absi(adventurer.cell.x - current_cell.x) + absi(adventurer.cell.y - current_cell.y)
		if dist <= data.stun_range:
			adventurer.apply_stun(data.stun_duration_steps)

## Returns true if this attack killed the enemy.
func take_damage(amount: int) -> bool:
	var mitigated := maxi(amount - data.armour, 0)
	current_health -= mitigated
	_update_hp_label()
	return current_health <= 0


func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(current_health)
