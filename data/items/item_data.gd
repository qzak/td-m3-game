extends Resource
class_name ItemData
## Design-time definition of a weapon or armour piece.

enum ItemSlot { WEAPON, ARMOUR }

@export var id: String
@export var display_name: String
@export var slot: ItemSlot = ItemSlot.WEAPON
@export var rarity: int = 1
@export var required_smith_level: int = 1

@export var damage_bonus: int = 0
@export var range_bonus: int = 0
@export var attack_pool_bonus: int = 0
@export var attack_regen_bonus: int = 0

@export var recipe_materials: Dictionary = {}  # material_id (String) -> amount (int)
