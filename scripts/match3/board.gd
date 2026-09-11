extends Node
class_name MineBoard

const TILE_SCRIPT = preload("res://data/tiles/mine_tile_data.gd")
const SOLVER_SCRIPT = preload("res://scripts/match3/match_solver.gd")
const WIDTH := 10
const HEIGHT := 10
const DESCENT_ROWS := 5
const BARRIER_LOCK_ROW := 6

signal match_resolved(rewards: Dictionary)
signal depth_advanced(new_depth: int)
signal board_changed
signal animation_event(event: Dictionary)

var depth: int = 0
var tiles: Array = []
var tile_definitions: Dictionary = {}
var random := RandomNumberGenerator.new()
var solver = SOLVER_SCRIPT.new()

func _ready() -> void:
	random.randomize()

func configure(definitions: Array, starting_depth: int = 0) -> void:
	tile_definitions.clear()
	for definition in definitions:
		tile_definitions[definition.id] = definition
	depth = starting_depth

func create_new_board() -> void:
	tiles.clear()
	# Preallocate all rows first so spawn-safety checks can read already-placed
	# neighbors in the same row from `tiles` while the board is still filling.
	for y in range(HEIGHT):
		var row: Array = []
		row.resize(WIDTH)
		tiles.append(row)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			tiles[y][x] = _new_spawn_safe_tile(Vector2i(x, y))
	board_changed.emit()

func load_state(state: Array, saved_depth: int) -> bool:
	if state.size() != HEIGHT:
		return false
	var loaded: Array = []
	for y in range(HEIGHT):
		if not state[y] is Array or state[y].size() != WIDTH:
			return false
		var row: Array = []
		for id in state[y]:
			if id == null:
				row.append(null)
			elif not tile_definitions.has(str(id)):
				return false
			else:
				row.append(tile_definitions[str(id)].duplicate())
		loaded.append(row)
	tiles = loaded
	depth = saved_depth
	board_changed.emit()
	return true

func serialize() -> Array:
	var state: Array = []
	for row in tiles:
		var serialized_row: Array = []
		for tile in row:
			serialized_row.append(tile.id if tile != null else null)
		state.append(serialized_row)
	return state

func try_swap(first: Vector2i, second: Vector2i) -> bool:
	if not _is_valid_cell(first) or not _is_valid_cell(second):
		return false
	if _cell_blocked_by_barrier(first) or _cell_blocked_by_barrier(second):
		return false
	if absi(first.x - second.x) + absi(first.y - second.y) != 1:
		return false
	var first_tile = tiles[first.y][first.x]
	var second_tile = tiles[second.y][second.x]
	if first_tile == null or second_tile == null:
		return false
	if _is_immovable(first_tile) or _is_immovable(second_tile):
		return false
	tiles[first.y][first.x] = second_tile
	tiles[second.y][second.x] = first_tile
	if solver.find_matches(tiles, WIDTH, HEIGHT).is_empty():
		tiles[first.y][first.x] = first_tile
		tiles[second.y][second.x] = second_tile
		return false
	animation_event.emit({
		"type": "swap",
		"first": first,
		"second": second,
		"first_tile_id": first_tile.id,
		"second_tile_id": second_tile.id,
	})
	_resolve_matches()
	return true

func try_move_to_empty(source: Vector2i, destination: Vector2i) -> bool:
	if not _is_valid_cell(source) or not _is_valid_cell(destination):
		return false
	if _cell_blocked_by_barrier(source) or _cell_blocked_by_barrier(destination):
		return false
	if source.y != destination.y or source.x == destination.x:
		return false
	var tile = tiles[source.y][source.x]
	if tile == null or tiles[destination.y][destination.x] != null:
		return false
	if _is_immovable(tile):
		return false
	# Commit the horizontal move into the empty destination
	tiles[destination.y][destination.x] = tile
	tiles[source.y][source.x] = null
	# Emit a dedicated pre-gravity move animation event using the same "moves" payload convention
	var pre_move := [{
		"from": source,
		"to": destination,
		"tile_id": tile.id,
	}]
	animation_event.emit({
		"type": "move",
		"moves": pre_move,
	})
	var gravity_moves := _apply_gravity()
	if not gravity_moves.is_empty():
		animation_event.emit({
			"type": "gravity",
			"moves": gravity_moves,
		})
	if not solver.find_matches(tiles, WIDTH, HEIGHT).is_empty():
		_resolve_matches()
	else:
		board_changed.emit()
	return true

func _resolve_matches() -> void:
	var rewards: Dictionary = {}
	while true:
		var matches := solver.find_matches(tiles, WIDTH, HEIGHT)
		if matches.is_empty():
			break
		var cleared_cells: Array = []
		var cleared_any := false
		for cell in matches:
			var tile = tiles[cell.y][cell.x]
			if tile != null and _tile_locked_from_clear(tile):
				continue
			if tile != null and not tile.reward_material_id.is_empty():
				rewards[tile.reward_material_id] = rewards.get(tile.reward_material_id, 0) + tile.reward_amount
			if tile != null:
				cleared_cells.append({
					"cell": cell,
					"tile_id": tile.id,
				})
				cleared_any = true
			tiles[cell.y][cell.x] = null
		if not cleared_any:
			break
		if not cleared_cells.is_empty():
			animation_event.emit({
				"type": "clear",
				"cells": cleared_cells,
			})
		var gravity_moves := _apply_gravity()
		if not gravity_moves.is_empty():
			animation_event.emit({
				"type": "gravity",
				"moves": gravity_moves,
			})
	match_resolved.emit(rewards)
	board_changed.emit()

func _apply_gravity() -> Array:
	var moves: Array = []
	for x in range(WIDTH):
		var write_y := HEIGHT - 1
		for y in range(HEIGHT - 1, -1, -1):
			if tiles[y][x] != null:
				var tile = tiles[y][x]
				tiles[write_y][x] = tiles[y][x]
				if write_y != y:
					tiles[y][x] = null
					moves.append({
						"from": Vector2i(x, y),
						"to": Vector2i(x, write_y),
						"tile_id": tile.id,
					})
				write_y -= 1
	return moves

func _top_rows_are_empty() -> bool:
	for y in range(DESCENT_ROWS):
		for x in range(WIDTH):
			if tiles[y][x] != null:
				return false
	return true

func can_descend() -> bool:
	if GameState.gate_state("hardness_a") == GameState.GATE_ACTIVE:
		return false
	if GameState.gate_state("hardness_b") == GameState.GATE_ACTIVE:
		return false
	if GameState.gate_state("magic_barrier") == GameState.GATE_ACTIVE and not GameState.progression.get("barrier_trinket_activated", false):
		return false
	return _top_rows_are_empty()

func top_rows_clear_count() -> int:
	var clear_rows := 0
	for y in range(DESCENT_ROWS):
		var row_clear := true
		for x in range(WIDTH):
			if tiles[y][x] != null:
				row_clear = false
				break
		if row_clear:
			clear_rows += 1
	return clear_rows

func descend() -> bool:
	if not can_descend():
		return false
	var shifted_tiles: Array = []
	for y in range(HEIGHT - DESCENT_ROWS):
		for x in range(WIDTH):
			var shifted_tile = tiles[y + DESCENT_ROWS][x]
			if shifted_tile != null:
				shifted_tiles.append({
					"from": Vector2i(x, y + DESCENT_ROWS),
					"to": Vector2i(x, y),
					"tile_id": shifted_tile.id,
				})
			tiles[y][x] = tiles[y + DESCENT_ROWS][x]
	var spawned_tiles: Array = []
	for y in range(HEIGHT - DESCENT_ROWS, HEIGHT):
		for x in range(WIDTH):
			tiles[y][x] = _new_spawn_safe_tile(Vector2i(x, y))
			if tiles[y][x] != null:
				spawned_tiles.append({
					"from": Vector2i(x, y + DESCENT_ROWS),
					"to": Vector2i(x, y),
					"tile_id": tiles[y][x].id,
				})
	animation_event.emit({
		"type": "descend",
		"moves": shifted_tiles,
		"spawns": spawned_tiles,
		"rows": DESCENT_ROWS,
	})
	depth += 1
	depth_advanced.emit(depth)
	board_changed.emit()
	return true

func _spawn_candidates_for_depth() -> Array:
	var candidates: Array = []
	for definition in tile_definitions.values():
		if definition.depth_required <= depth:
			candidates.append(definition)
	return candidates

func _new_spawn_safe_tile(cell: Vector2i):
	var candidates := _spawn_candidates_for_depth()
	if candidates.is_empty():
		return null
	var start_index := random.randi_range(0, candidates.size() - 1)
	for offset in range(candidates.size()):
		var definition = candidates[(start_index + offset) % candidates.size()]
		if not _would_create_spawn_match(cell, str(definition.id)):
			return definition.duplicate()
	return candidates[start_index].duplicate()

func _would_create_spawn_match(cell: Vector2i, tile_id: String) -> bool:
	if cell.x >= 2:
		var left_one = tiles[cell.y][cell.x - 1]
		var left_two = tiles[cell.y][cell.x - 2]
		if left_one != null and left_two != null and str(left_one.id) == tile_id and str(left_two.id) == tile_id:
			return true
	if cell.y >= 2:
		var up_one = tiles[cell.y - 1][cell.x]
		var up_two = tiles[cell.y - 2][cell.x]
		if up_one != null and up_two != null and str(up_one.id) == tile_id and str(up_two.id) == tile_id:
			return true
	return false

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

func enforce_gate_tiles() -> bool:
	if tiles.is_empty():
		return false
	var changed := false
	if GameState.gate_state("hardness_a") == GameState.GATE_ACTIVE and _count_tiles_with_id("hard_stone") == 0:
		changed = _place_gate_tile("hard_stone") or changed
	if GameState.gate_state("hardness_b") == GameState.GATE_ACTIVE and not GameState.shovel_unlocked and _count_tiles_with_id("rooted_stone") == 0:
		changed = _place_gate_tile("rooted_stone") or changed
	return changed

func can_use_dynamite(cell: Vector2i) -> bool:
	if not _is_valid_cell(cell):
		return false
	var tile = tiles[cell.y][cell.x]
	return tile != null and int(tile.hardness_tier) > 0 and GameState.dynamite_count > 0

func use_dynamite(cell: Vector2i) -> bool:
	if not can_use_dynamite(cell):
		return false
	if not GameState.consume_dynamite():
		return false
	var tile = tiles[cell.y][cell.x]
	tiles[cell.y][cell.x] = null
	animation_event.emit({
		"type": "clear",
		"cells": [{"cell": cell, "tile_id": tile.id}],
	})
	var gravity_moves := _apply_gravity()
	if not gravity_moves.is_empty():
		animation_event.emit({
			"type": "gravity",
			"moves": gravity_moves,
		})
	board_changed.emit()
	return true

func _tile_locked_from_clear(tile) -> bool:
	if tile == null:
		return false
	if int(tile.hardness_tier) > 0:
		return true
	if bool(tile.immovable) and not GameState.shovel_unlocked:
		return true
	return false

func _is_immovable(tile) -> bool:
	if tile == null:
		return false
	return bool(tile.immovable) and not GameState.shovel_unlocked

func _cell_blocked_by_barrier(cell: Vector2i) -> bool:
	if GameState.gate_state("magic_barrier") != GameState.GATE_ACTIVE:
		return false
	if GameState.progression.get("barrier_trinket_activated", false):
		return false
	return cell.y >= BARRIER_LOCK_ROW

func _count_tiles_with_id(tile_id: String) -> int:
	var count := 0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile = tiles[y][x]
			if tile != null and str(tile.id) == tile_id:
				count += 1
	return count

func _place_gate_tile(tile_id: String) -> bool:
	if not tile_definitions.has(tile_id):
		return false
	var target_cell := Vector2i(-1, -1)
	for y in range(DESCENT_ROWS):
		for x in range(WIDTH):
			if tiles[y][x] != null:
				target_cell = Vector2i(x, y)
				break
		if target_cell.x >= 0:
			break
	if target_cell.x < 0:
		for y in range(HEIGHT):
			for x in range(WIDTH):
				if tiles[y][x] != null:
					target_cell = Vector2i(x, y)
					break
			if target_cell.x >= 0:
				break
	if target_cell.x < 0:
		return false
	tiles[target_cell.y][target_cell.x] = tile_definitions[tile_id].duplicate()
	return true
