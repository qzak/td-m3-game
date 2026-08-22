extends Resource
class_name DayData
## A full "Day" challenge: ordered waves and difficulty scaling.

@export var day_index: int = 0
@export var waves: Array[WaveData] = []
@export var difficulty_scalar: float = 1.0
