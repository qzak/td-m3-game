extends Resource
class_name ItemData
## Design-time definition of a weapon or armour piece.

# Backwards-compatible enum for existing systems. Prefer using `slot_id` for
# extensible compatibility checks between items and adventurer equipment slots.
enum ItemSlot { WEAPON, ARMOUR }

@export var id: String
@export var display_name: String
# Legacy enum kept for compatibility with existing code paths
@export var slot: ItemSlot = ItemSlot.WEAPON
# New string-based slot id for extensible slot checks (e.g. "weapon", "main_hand", "robe")
@export var slot_id: String = ""

# Inventory footprint (width, height) in item grid cells. Default 1x1 for backward safety.
@export var footprint: Vector2i = Vector2i(1, 1)

@export var rarity: int = 1
@export var required_smith_level: int = 1

@export var damage_bonus: int = 0
@export var range_bonus: int = 0
@export var attack_pool_bonus: int = 0
@export var attack_regen_bonus: int = 0

@export var recipe_materials: Dictionary = {}  # material_id (String) -> amount (int)

# Helper: return the effective slot id, preferring slot_id when set, falling back to the legacy enum.
func get_effective_slot_id() -> String:
	if slot_id != "":
		return slot_id
	match slot:
		ItemSlot.WEAPON:
			return "weapon"
		ItemSlot.ARMOUR:
			return "armour"
		_:
			return "unknown"
