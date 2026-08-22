extends Node2D
class_name TDEnemy
## A single enemy instance walking the fixed path.

var data: EnemyData
var grid: TDGridMap
var path_index: int = 0
var current_health: int
var current_cell: Vector2i

@onready var hp_label: Label = $HPLabel

func setup(p_data: EnemyData, p_grid: TDGridMap, health_multiplier: float = 1.0) -> void:
	data = p_data
	grid = p_grid
	current_health = int(round(data.health * health_multiplier))
	path_index = 0
	current_cell = grid.path_cells[0]
	position = grid.cell_to_world(current_cell)
	_update_hp_label()

## Advances along the path; returns true once it reaches the castle.
func advance() -> bool:
	path_index += data.move_steps_per_turn
	var last_index := grid.path_cells.size() - 1
	if path_index >= last_index:
		current_cell = grid.path_cells[last_index]
		position = grid.cell_to_world(current_cell)
		return true
	current_cell = grid.path_cells[path_index]
	position = grid.cell_to_world(current_cell)
	return false

## Returns true if this attack killed the enemy.
func take_damage(amount: int) -> bool:
	var mitigated := maxi(amount - data.armour, 0)
	current_health -= mitigated
	_update_hp_label()
	return current_health <= 0

func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(current_health)
