extends Node
class_name MineBoard

const TILE_SCRIPT = preload("res://data/tiles/mine_tile_data.gd")
const SOLVER_SCRIPT = preload("res://scripts/match3/match_solver.gd")
const WIDTH := 10
const HEIGHT := 10
const DESCENT_ROWS := 5

signal match_resolved(rewards: Dictionary)
signal depth_advanced(new_depth: int)
signal board_changed

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
	for y in range(HEIGHT):
		var row: Array = []
		for x in range(WIDTH):
			row.append(_new_random_tile(Vector2i(x, y)))
		tiles.append(row)
	while not solver.find_matches(tiles, WIDTH, HEIGHT).is_empty():
		for y in range(HEIGHT):
			for x in range(WIDTH):
				tiles[y][x] = _new_random_tile(Vector2i(x, y))
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
	if absi(first.x - second.x) + absi(first.y - second.y) != 1:
		return false
	var first_tile = tiles[first.y][first.x]
	var second_tile = tiles[second.y][second.x]
	if first_tile == null or second_tile == null:
		return false
	tiles[first.y][first.x] = second_tile
	tiles[second.y][second.x] = first_tile
	if solver.find_matches(tiles, WIDTH, HEIGHT).is_empty():
		tiles[first.y][first.x] = first_tile
		tiles[second.y][second.x] = second_tile
		return false
	_resolve_matches()
	return true

func try_move_to_empty(source: Vector2i, destination: Vector2i) -> bool:
	if not _is_valid_cell(source) or not _is_valid_cell(destination):
		return false
	if source.y != destination.y or source.x == destination.x:
		return false
	var tile = tiles[source.y][source.x]
	if tile == null or tiles[destination.y][destination.x] != null:
		return false
	tiles[destination.y][destination.x] = tile
	tiles[source.y][source.x] = null
	_apply_gravity()
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
		for cell in matches:
			var tile = tiles[cell.y][cell.x]
			if tile != null and not tile.reward_material_id.is_empty():
				rewards[tile.reward_material_id] = rewards.get(tile.reward_material_id, 0) + tile.reward_amount
			tiles[cell.y][cell.x] = null
		_apply_gravity()
	match_resolved.emit(rewards)
	board_changed.emit()

func _apply_gravity() -> void:
	for x in range(WIDTH):
		var write_y := HEIGHT - 1
		for y in range(HEIGHT - 1, -1, -1):
			if tiles[y][x] != null:
				tiles[write_y][x] = tiles[y][x]
				if write_y != y:
					tiles[y][x] = null
				write_y -= 1

func _top_rows_are_empty() -> bool:
	for y in range(DESCENT_ROWS):
		for x in range(WIDTH):
			if tiles[y][x] != null:
				return false
	return true

func can_descend() -> bool:
	return _top_rows_are_empty()

func descend() -> bool:
	if not can_descend():
		return false
	for y in range(HEIGHT - DESCENT_ROWS):
		for x in range(WIDTH):
			tiles[y][x] = tiles[y + DESCENT_ROWS][x]
	for y in range(HEIGHT - DESCENT_ROWS, HEIGHT):
		for x in range(WIDTH):
			tiles[y][x] = _new_random_tile(Vector2i(x, y))
	depth += 1
	depth_advanced.emit(depth)
	board_changed.emit()
	return true

func _new_random_tile(_cell: Vector2i):
	var candidates: Array = []
	for definition in tile_definitions.values():
		if definition.depth_required <= depth:
			candidates.append(definition)
	if candidates.is_empty():
		return null
	return candidates[random.randi_range(0, candidates.size() - 1)].duplicate()

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT
