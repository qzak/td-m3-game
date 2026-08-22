extends Resource
class_name EnemyData
## Design-time definition of an enemy type.

@export var id: String
@export var display_name: String
@export var health: int = 10
@export var armour: int = 0
@export var move_steps_per_turn: int = 1
@export var move_period: int = 1  ## moves once every this many move-steps; 2 = half speed
@export var is_boss: bool = false

@export var can_stun: bool = false
@export var stun_duration_steps: int = 1
@export var stun_range: int = 1  ## Manhattan distance at which this enemy stuns adventurers

@export var can_double_move: bool = false
@export var double_move_chance: float = 0.5  ## chance per move step to move double distance

@export var sprite: Texture2D
