extends Node2D
class_name TDAdventurer
## A placed adventurer: tracks attack pool charge and range checks.

var data: AdventurerData
var cell: Vector2i
var attack_pool_current: int = 0
var stunned_steps_remaining: int = 0
var selected_spell_id: String = ""  # chosen spell for MAGIC units; "" = use the type's default

@onready var pool_label: Label = $PoolLabel

func setup(p_data: AdventurerData, p_cell: Vector2i, world_pos: Vector2, p_spell_id: String = "") -> void:
	data = p_data
	cell = p_cell
	position = world_pos
	attack_pool_current = 0
	stunned_steps_remaining = 0
	selected_spell_id = p_spell_id
	if selected_spell_id == "" and not data.spell_ids.is_empty():
		selected_spell_id = data.spell_ids[0]
	_update_label()

## Repositions the unit to a new cell without touching its charge/stun state
## (used for mid-battle repositioning during between-wave breathers).
func move_to(p_cell: Vector2i, world_pos: Vector2) -> void:
	cell = p_cell
	position = world_pos

func regen() -> void:
	attack_pool_current += data.attack_regen
	_update_label()

func consume_pool() -> void:
	attack_pool_current -= data.attack_pool
	_update_label()

func apply_stun(steps: int) -> void:
	stunned_steps_remaining = maxi(stunned_steps_remaining, steps)
	_update_label()

func tick_stun() -> void:
	stunned_steps_remaining = maxi(stunned_steps_remaining - 1, 0)
	_update_label()

func can_attack() -> bool:
	return stunned_steps_remaining <= 0 and attack_pool_current >= data.attack_pool

func is_in_range(target_cell: Vector2i) -> bool:
	# Manhattan distance gives a diamond-shaped range instead of a square.
	var dist := absi(cell.x - target_cell.x) + absi(cell.y - target_cell.y)
	return dist >= data.range_min and dist <= data.range_max

func _update_label() -> void:
	if pool_label:
		if stunned_steps_remaining > 0:
			pool_label.text = "STUNNED (%d)" % stunned_steps_remaining
		else:
			pool_label.text = "%d/%d" % [attack_pool_current, data.attack_pool]
