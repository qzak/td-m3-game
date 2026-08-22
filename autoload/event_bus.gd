extends Node
## Global signal bus for decoupled cross-system communication.

signal building_upgraded(building_id: String, new_level: int)
signal adventurer_recruited(adventurer_id: String)
signal currency_changed(new_amount: int)
signal materials_changed(material_id: String, new_amount: int)

signal day_started(day_index: int)
signal day_won(day_index: int)
signal day_lost(day_index: int)
signal wave_spawned(wave_index: int)
signal castle_hp_changed(new_hp: int)

signal mine_depth_changed(new_depth: int)
signal mine_match_resolved(material_id: String, amount: int)
