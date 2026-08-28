extends Control
class_name LibraryController

@onready var status_label: Label = $StatusLabel
@onready var upgrade_row: BuildingUpgradeRow = $UpgradeRow

func _ready() -> void:
	upgrade_row.building_id = "library"
	refresh()

func refresh() -> void:
	status_label.text = "Bestiary records are not available yet. Encounter tracking and entry details will be added in a later update."
	upgrade_row.refresh()
