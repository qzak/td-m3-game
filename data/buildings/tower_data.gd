extends Resource
class_name TowerData
## Per-level stats for the castle's last-resort Towers. Index i = level (i+1).

@export var range_min: Array[int] = [1, 1, 1, 1, 1]
@export var range_max: Array[int] = [2, 2, 3, 3, 4]
@export var damage_min: Array[int] = [2, 3, 4, 5, 6]
@export var damage_max: Array[int] = [4, 5, 6, 8, 10]
@export var attack_pool: Array[int] = [100, 100, 100, 100, 100]
@export var attack_regen: Array[int] = [35, 40, 45, 50, 60]

func stats_for_level(level: int) -> Dictionary:
	var index := clampi(level - 1, 0, range_min.size() - 1)
	return {
		"range_min": range_min[index],
		"range_max": range_max[index],
		"damage_min": damage_min[index],
		"damage_max": damage_max[index],
		"attack_pool": attack_pool[index],
		"attack_regen": attack_regen[index],
	}
