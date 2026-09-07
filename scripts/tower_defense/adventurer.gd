extends Node2D
class_name TDAdventurer
## A placed adventurer: tracks attack pool charge and range checks.

const PROJECTILE_MIN_DURATION: float = 0.08
const PROJECTILE_SPEED: float = 480.0
const ADVENTURER_SPRITE_ROOT := "res://assets/sprites/tower_defense/adventurers"

var data: AdventurerData
var cell: Vector2i
var attack_pool_current: int = 0
var stunned_steps_remaining: int = 0
var selected_spell_id: String = ""  # chosen spell for MAGIC units; "" = use the type's default
var current_health: int = 1

@onready var body: Polygon2D = $Body
@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: WorldStatBar = $HPBar
@onready var action_meter: AdventurerActionMeter = $ActionMeter

func setup(p_data: AdventurerData, p_cell: Vector2i, world_pos: Vector2, p_spell_id: String = "") -> void:
	data = p_data
	cell = p_cell
	position = world_pos
	attack_pool_current = 0
	stunned_steps_remaining = 0
	current_health = maxi(data.max_health, 1)
	selected_spell_id = p_spell_id
	if selected_spell_id == "" and not data.spell_ids.is_empty():
		selected_spell_id = data.spell_ids[0]
	_apply_sprite()
	_update_overlay()

## Repositions the unit to a new cell without touching its charge/stun state
## (used for mid-battle repositioning during between-wave breathers).
func move_to(p_cell: Vector2i, world_pos: Vector2) -> void:
	cell = p_cell
	position = world_pos

func regen() -> void:
	attack_pool_current = mini(attack_pool_current + data.attack_regen, _max_stored_actions())
	_update_overlay()

func consume_pool() -> void:
	attack_pool_current = maxi(attack_pool_current - data.attack_pool, 0)
	_update_overlay()

func apply_stun(steps: int) -> void:
	stunned_steps_remaining = maxi(stunned_steps_remaining, steps)
	_update_overlay()

func tick_stun() -> void:
	stunned_steps_remaining = maxi(stunned_steps_remaining - 1, 0)
	_update_overlay()

func can_attack() -> bool:
	return stunned_steps_remaining <= 0 and data.attack_pool > 0 and attack_pool_current >= data.attack_pool

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
	projectile.polygon = PackedVector2Array([
		Vector2(-4, -2),
		Vector2(4, 0),
		Vector2(-4, 2),
	])
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
		var squash_target: Node2D = sprite if sprite != null and sprite.visible else body
		var body_tween := create_tween()
		body_tween.tween_property(squash_target, "scale", Vector2(1.12, 0.88), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		body_tween.tween_property(squash_target, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _spawn_impact(target_position: Vector2, color: Color) -> void:
	var host := get_parent()
	if host == null:
		return
	var impact := Polygon2D.new()
	impact.color = color
	impact.polygon = PackedVector2Array([
		Vector2(0, -7),
		Vector2(7, 0),
		Vector2(0, 7),
		Vector2(-7, 0),
	])
	impact.position = target_position
	host.add_child(impact)
	var impact_tween := create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(impact, "scale", Vector2(2.0, 2.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_LINEAR)
	impact_tween.finished.connect(impact.queue_free)

func _max_stored_actions() -> int:
	var action_cost := maxi(data.attack_pool, 1)
	var multiplier := maxi(data.action_storage_multiplier, 1)
	return action_cost * multiplier

func _update_overlay() -> void:
	if hp_bar:
		hp_bar.set_ratio(float(current_health) / float(maxi(data.max_health, 1)))
	if action_meter == null:
		return
	var action_cost := maxi(data.attack_pool, 1)
	var capacity := maxi(data.action_storage_multiplier, 1)
	var full_actions := mini(attack_pool_current / action_cost, capacity)
	var partial_fill := 0.0
	if full_actions < capacity:
		partial_fill = float(attack_pool_current % action_cost) / float(action_cost)
	action_meter.set_capacity(capacity)
	action_meter.set_state(full_actions, partial_fill, stunned_steps_remaining > 0)

func _apply_sprite() -> void:
	if sprite == null or body == null or data == null:
		return
	var texture := _resolve_sprite_texture()
	if texture == null:
		sprite.visible = false
		body.visible = true
		return
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = true
	body.visible = false

func _resolve_sprite_texture() -> Texture2D:
	if data.sprite != null:
		return data.sprite
	var sprite_id := data.id
	if sprite_id.begins_with("tower_"):
		sprite_id = "tower"
	var candidate := "%s/%s/%s_idle.png" % [ADVENTURER_SPRITE_ROOT, sprite_id, sprite_id]
	if ResourceLoader.exists(candidate):
		return load(candidate) as Texture2D
	return null
