extends RefCounted
class_name MineMatchSolver

func find_matches(board: Array, width: int, height: int) -> Array[Vector2i]:
	var matched: Dictionary = {}
	for y in range(height):
		var run_start := 0
		for x in range(width + 1):
			var same_as_previous: bool = x < width and board[y][x] != null and x > run_start and board[y][x - 1] != null and board[y][x].id == board[y][x - 1].id
			if same_as_previous:
				continue
			if x - run_start >= 3 and board[y][run_start] != null:
				for run_x in range(run_start, x):
					matched[Vector2i(run_x, y)] = true
			run_start = x

	for x in range(width):
		var run_start := 0
		for y in range(height + 1):
			var same_as_previous: bool = y < height and board[y][x] != null and y > run_start and board[y - 1][x] != null and board[y][x].id == board[y - 1][x].id
			if same_as_previous:
				continue
			if y - run_start >= 3 and board[run_start][x] != null:
				for run_y in range(run_start, y):
					matched[Vector2i(x, run_y)] = true
			run_start = y

	var result: Array[Vector2i] = []
	for cell: Vector2i in matched:
		result.append(cell)
	return result
