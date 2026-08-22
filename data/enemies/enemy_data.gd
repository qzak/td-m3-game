extends Resource
class_name EnemyData
## Design-time definition of an enemy type.

@export var id: String
@export var display_name: String
@export var health: int = 10
@export var armour: int = 0
@export var move_steps_per_turn: int = 1
@export var is_boss: bool = false

@export var can_stun: bool = false
@export var stun_duration_steps: int = 1

@export var sprite: Texture2D
