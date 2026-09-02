extends Resource
class_name AdventurerData
## Design-time definition of an adventurer type. Instance data (level, equipment) lives in GameState.

enum AdventurerType { PHYSICAL_MELEE, PHYSICAL_RANGED, MAGIC }

@export var id: String
@export var display_name: String
@export var rarity: int = 1
@export var type: AdventurerType = AdventurerType.PHYSICAL_MELEE

# Per-adventurer equipment slot definitions (string ids). Defaults keep backward-compatibility
# with a simple "weapon" / "armour" pair.
@export var equipment_slots: Array[String] = ["weapon", "armour"]

@export var damage_min: int = 1
@export var damage_max: int = 3
@export var range_min: int = 1
@export var range_max: int = 1
@export var max_health: int = 100

@export var attack_pool: int = 100
@export var attack_regen: int = 25
@export var action_storage_multiplier: int = 4

@export var recruit_cost: int = 100

@export var spell_ids: Array[String] = []  # only used when type == MAGIC
@export var status_effect_profile: Resource  # optional baseline on-hit effects for this unit's attacks
@export var sprite: Texture2D
