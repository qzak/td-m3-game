extends Node
## Global signal bus for decoupled cross-system communication.

signal building_upgraded(building_id: String, new_level: int)
signal adventurer_recruited(adventurer_id: String)
signal currency_changed(new_amount: int)
signal materials_changed(material_id: String, new_amount: int)

signal item_crafted(def_id: String)
signal item_equipped(adventurer_instance_id: String, item_instance_id: String)
signal item_unequipped(adventurer_instance_id: String, item_instance_id: String)
signal smelting_started(material_id: String)
signal smelting_collected(output_id: String, amount: int)

signal day_started(day_index: int)
signal day_won(day_index: int)
signal day_lost(day_index: int)
signal wave_spawned(wave_index: int)
signal castle_hp_changed(new_hp: int)

signal mine_depth_changed(new_depth: int)
signal mine_match_resolved(material_id: String, amount: int)
