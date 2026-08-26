extends Resource
class_name StatusEffectProfile

@export var id: String
@export var display_name: String

@export_group("Slow")
@export var slow_duration_steps: int = 0
@export var slow_move_period_bonus: int = 0

@export_group("Armour Break")
@export var armour_break_duration_steps: int = 0
@export var armour_break_amount: int = 0

@export_group("Anti-Swarm")
@export var anti_swarm_radius: int = 1
@export var anti_swarm_min_enemies: int = 0
@export var anti_swarm_damage_multiplier: float = 1.0
