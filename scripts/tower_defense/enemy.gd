extends Node2D
class_name TDEnemy
## A single enemy instance walking the fixed path.

const HOP_DURATION: float = 0.22
const HOP_HEIGHT: float = 10.0
const ENEMY_SPRITE_ROOT := "res://assets/sprites/tower_defense/enemies"
const STATUS_COLOR_SLOW := Color(0.55, 0.78, 1.0, 1.0)
const STATUS_COLOR_BREAK := Color(1.0, 0.68, 0.52, 1.0)
const STATUS_COLOR_MIXED := Color(0.86, 0.72, 0.98, 1.0)

var data: EnemyData
var grid: TDGridMap
var path_index: int = 0
var current_health: int
var max_health: int = 1
var current_cell: Vector2i
var move_cooldown: int = 0  # >0 means this enemy is resting and won't attempt to move yet
var slow_steps_remaining: int = 0
var slow_move_period_bonus: int = 0
var armour_break_steps_remaining: int = 0
var armour_break_amount: int = 0
var dying: bool = false

@onready var body: Polygon2D = $Body
@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: WorldStatBar = $HPBar
@onready var status_label: Label = $StatusLabel

func setup(p_data: EnemyData, p_grid: TDGridMap, health_multiplier: float = 1.0) -> void:
	data = p_data
	grid = p_grid
	max_health = maxi(int(round(data.health * health_multiplier)), 1)
	current_health = max_health
	path_index = 0
	move_cooldown = 0
	slow_steps_remaining = 0
	slow_move_period_bonus = 0
	armour_break_steps_remaining = 0
	armour_break_amount = 0
	current_cell = grid.path_cells[0]
	position = grid.cell_to_world(current_cell)
	_apply_sprite()
	_update_hp_bar()
	_update_status_label()

## Where this enemy would move to this step if nothing blocks it (no state change yet).
func peek_target_cell() -> Vector2i:
	if move_cooldown > 0:
		return current_cell
	var next_index := mini(path_index + _steps_this_move(), grid.path_cells.size() - 1)
	return grid.path_cells[next_index]

## Resolves this step's movement once blocking has been decided elsewhere.
## Returns true once it reaches the castle.
func apply_move(can_move: bool) -> bool:
	if dying:
		return false
	if move_cooldown > 0:
		move_cooldown -= 1
		return false
	if not can_move:
		return false  # blocked by another enemy ahead; stays put and retries next step

	var from_position := position
	var last_index := grid.path_cells.size() - 1
	path_index = mini(path_index + _steps_this_move(), last_index)
	current_cell = grid.path_cells[path_index]
	var to_position := grid.cell_to_world(current_cell)
	_animate_hop(from_position, to_position)
	move_cooldown = _effective_move_period() - 1
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
	var mitigated := maxi(amount - _effective_armour(), 0)
	current_health = maxi(current_health - mitigated, 0)
	_update_hp_bar()
	return current_health <= 0

func apply_slow(duration_steps: int, move_period_bonus: int) -> void:
	if duration_steps <= 0 or move_period_bonus <= 0:
		return
	if duration_steps > slow_steps_remaining:
		slow_steps_remaining = duration_steps
		slow_move_period_bonus = move_period_bonus
	elif duration_steps == slow_steps_remaining:
		slow_move_period_bonus = maxi(slow_move_period_bonus, move_period_bonus)
	_update_status_label()

func apply_armour_break(duration_steps: int, amount: int) -> void:
	if duration_steps <= 0 or amount <= 0:
		return
	if duration_steps > armour_break_steps_remaining:
		armour_break_steps_remaining = duration_steps
		armour_break_amount = amount
	elif duration_steps == armour_break_steps_remaining:
		armour_break_amount = maxi(armour_break_amount, amount)
	_update_status_label()

func tick_status_effects() -> void:
	if slow_steps_remaining > 0:
		slow_steps_remaining -= 1
		if slow_steps_remaining <= 0:
			slow_steps_remaining = 0
			slow_move_period_bonus = 0
	if armour_break_steps_remaining > 0:
		armour_break_steps_remaining -= 1
		if armour_break_steps_remaining <= 0:
			armour_break_steps_remaining = 0
			armour_break_amount = 0
	_update_status_label()

func play_anti_swarm_cue(multiplier: float) -> void:
	if dying or multiplier <= 1.0:
		return
	if body:
		var pulse_target: Node2D = sprite if sprite != null and sprite.visible else body
		var pulse := create_tween()
		pulse.set_parallel(true)
		pulse.tween_property(pulse_target, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pulse.tween_property(pulse_target, "scale", Vector2(1.0, 1.0), 0.12).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_show_popup("SWARM x%.2f" % multiplier, Color(1.0, 0.9, 0.45, 0.95))

func play_death_animation() -> void:
	if dying:
		return
	dying = true
	if hp_bar:
		hp_bar.visible = false
	if status_label:
		status_label.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.25, 0.25), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "rotation_degrees", 85.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.set_ratio(float(current_health) / float(maxi(max_health, 1)))

func _update_status_label() -> void:
	if status_label == null:
		return
	var has_slow := slow_steps_remaining > 0
	var has_break := armour_break_steps_remaining > 0
	if not has_slow and not has_break:
		status_label.text = ""
		status_label.visible = false
		if body:
			body.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	status_label.visible = true
	var chunks: Array[String] = []
	if has_slow:
		chunks.append("S%d" % slow_steps_remaining)
	if has_break:
		chunks.append("B%d" % armour_break_steps_remaining)
	status_label.text = " ".join(chunks)
	if body:
		if has_slow and has_break:
			body.modulate = STATUS_COLOR_MIXED
		elif has_slow:
			body.modulate = STATUS_COLOR_SLOW
		else:
			body.modulate = STATUS_COLOR_BREAK
	if sprite:
		if has_slow and has_break:
			sprite.modulate = STATUS_COLOR_MIXED
		elif has_slow:
			sprite.modulate = STATUS_COLOR_SLOW
		else:
			sprite.modulate = STATUS_COLOR_BREAK

func _effective_move_period() -> int:
	var slow_bonus := slow_move_period_bonus if slow_steps_remaining > 0 else 0
	return maxi(data.move_period + slow_bonus, 1)

func _effective_armour() -> int:
	var break_amount := armour_break_amount if armour_break_steps_remaining > 0 else 0
	return maxi(data.armour - break_amount, 0)

func _animate_hop(from_position: Vector2, to_position: Vector2) -> void:
	if dying:
		return
	if from_position.is_equal_approx(to_position):
		position = to_position
		return
	var midpoint := ((from_position + to_position) * 0.5) + Vector2(0.0, -HOP_HEIGHT)
	var tween := create_tween()
	tween.tween_property(self, "position", midpoint, HOP_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", to_position, HOP_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if body:
		body.scale = Vector2(1.0, 1.0)
		var squash := create_tween()
		var squash_target: Node2D = sprite if sprite != null and sprite.visible else body
		squash_target.scale = Vector2(1.0, 1.0)
		squash.tween_property(squash_target, "scale", Vector2(1.1, 0.9), HOP_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		squash.tween_property(squash_target, "scale", Vector2(1.0, 1.0), HOP_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _show_popup(text: String, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.modulate = color
	popup.position = Vector2(-34, -66)
	popup.size = Vector2(68, 18)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 10)
	add_child(popup)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 10.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(popup.queue_free)

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
	var candidate := "%s/%s/%s_idle.png" % [ENEMY_SPRITE_ROOT, data.id, data.id]
	if ResourceLoader.exists(candidate):
		return load(candidate) as Texture2D
	return null
