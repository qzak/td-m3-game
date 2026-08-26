extends Resource
class_name SpellData

@export var id: String
@export var display_name: String
@export var is_aoe: bool = false
@export var damage_multiplier: float = 1.0
@export var status_effect_profile: Resource  # optional on-hit effects for this spell
