extends Control
class_name TowersPanel
## Minimal panel for the Towers building — it has no other player-facing UI yet,
## just the shared building-upgrade row (see docs/systems/castle.md).

@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

func _ready() -> void:
	upgrade_row.building_id = "towers"
	upgrade_row.refresh()

func refresh() -> void:
	upgrade_row.refresh()
