extends Resource
class_name WaveData
## A single wave within a Day: which enemy, how many, spacing.

@export var enemy_data: EnemyData
@export var count: int = 5
@export var spawn_delay_steps: int = 2
