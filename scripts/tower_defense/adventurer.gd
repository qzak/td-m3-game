extends Node2D
class_name TDAdventurer
## A placed adventurer: tracks attack pool charge and range checks.

const PROJECTILE_MIN_DURATION: float = 0.08
const PROJECTILE_SPEED: float = 480.0

var data: AdventurerData
var cell: Vector2i
var attack_pool_current: int = 0
var stunned_steps_remaining: int = 0
var selected_spell_id: String = ""  # chosen spell for MAGIC units; "" = use the type's default

@onready var body: Polygon2D = $Body
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

func play_ranged_attack(target_position: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var projectile := Polygon2D.new()
	projectile.color = Color(1.0, 0.9, 0.2, 1.0)
	projectile.polygon = PackedVector2Array(-4, -2, 4, 0, -4, 2)
	projectile.position = position
	projectile.rotation = (target_position - position).angle()
	host.add_child(projectile)

	var travel_time := maxf(PROJECTILE_MIN_DURATION, position.distance_to(target_position) / PROJECTILE_SPEED)
	var projectile_tween := create_tween()
	projectile_tween.tween_property(projectile, "position", target_position, travel_time).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	projectile_tween.finished.connect(func() -> void:
		projectile.queue_free()
		_spawn_impact(target_position, Color(1.0, 0.85, 0.35, 0.95))
	)

func play_melee_attack(target_position: Vector2) -> void:
	var direction := signf(target_position.x - position.x)
	if is_zero_approx(direction):
		direction = 1.0
	var swing_tween := create_tween()
	swing_tween.tween_property(self, "rotation", 0.3 * direction, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_spawn_impact(target_position, Color(1.0, 0.45, 0.25, 0.95))
	if body:
		var body_tween := create_tween()
		body_tween.tween_property(body, "scale", Vector2(1.12, 0.88), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		body_tween.tween_property(body, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _spawn_impact(target_position: Vector2, color: Color) -> void:
	var host := get_parent()
	if host == null:
		return
	var impact := Polygon2D.new()
	impact.color = color
	impact.polygon = PackedVector2Array(0, -7, 7, 0, 0, 7, -7, 0)
	impact.position = target_position
	host.add_child(impact)
	var impact_tween := create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(impact, "scale", Vector2(2.0, 2.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_LINEAR)
	impact_tween.finished.connect(impact.queue_free)

func _update_label() -> void:
	if pool_label:
		if stunned_steps_remaining > 0:
			pool_label.text = "STUNNED (%d)" % stunned_steps_remaining
		else:
			pool_label.text = "%d/%d" % [attack_pool_current, data.attack_pool]
