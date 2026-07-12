class_name GameModel
extends RefCounted

const WALL := 0
const EMPTY_FLOOR := 1
const DYED_FLOOR := 2

const LEVEL_FILE_PATH := "res://data/levels.json"
const SOLVER_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]

var grid: Array = []
var width := 0
var height := 0
var player_x := 1
var player_y := 1
var levels: Array = []
var current_level_index := 0
var current_level_name := ""
var last_solution_moves := MoveStack.new()
var pending_solution_move: Variant = null
var solution_state_key := ""


func load_levels() -> bool:
	if not levels.is_empty():
		return true
	if not FileAccess.file_exists(LEVEL_FILE_PATH):
		return false

	var level_file := FileAccess.open(LEVEL_FILE_PATH, FileAccess.READ)
	if level_file == null:
		return false

	var parsed_data: Variant = JSON.parse_string(level_file.get_as_text())
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return false

	var loaded_levels: Variant = parsed_data.get("levels")
	if typeof(loaded_levels) != TYPE_ARRAY or loaded_levels.is_empty():
		return false

	levels = loaded_levels
	return true


func get_level_count() -> int:
	return levels.size() if load_levels() else 0


func load_level(level_index: int) -> bool:
	if not load_levels() or level_index < 0 or level_index >= levels.size():
		return false

	var level_data: Variant = levels[level_index]
	if typeof(level_data) != TYPE_DICTIONARY:
		return false

	var rows: Variant = level_data.get("rows")
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return false

	var new_width := str(rows[0]).length()
	if new_width == 0:
		return false

	var new_grid: Array = []
	var spawn_position := Vector2i(-1, -1)
	for y in range(rows.size()):
		var row_text := str(rows[y])
		if row_text.length() != new_width:
			return false

		var row: Array[int] = []
		for x in range(new_width):
			var tile := row_text.substr(x, 1)
			match tile:
				"#":
					row.append(WALL)
				".", "P":
					row.append(EMPTY_FLOOR)
					if tile == "P":
						if spawn_position.x >= 0:
							return false
						spawn_position = Vector2i(x, y)
				_:
					return false
		new_grid.append(row)

	if spawn_position.x < 0:
		return false

	current_level_index = level_index
	current_level_name = str(level_data.get("name", "Level %d" % (level_index + 1)))
	width = new_width
	height = rows.size()
	grid = new_grid
	player_x = spawn_position.x
	player_y = spawn_position.y
	invalidate_solution()
	return true


func setup_test_level() -> void:
	current_level_index = 0
	current_level_name = "Testlevel"
	width = 21
	height = 21
	player_x = 1
	player_y = 1
	grid = []

	for y in range(height):
		var row: Array[int] = []
		for x in range(width):
			var is_border := x == 0 or x == width - 1 or y == 0 or y == height - 1
			row.append(WALL if is_border else EMPTY_FLOOR)
		grid.append(row)

	invalidate_solution()


func get_cell(x: int, y: int) -> int:
	return int(grid[y][x]) if _is_inside(x, y) else WALL


func set_cell_dyed(x: int, y: int) -> bool:
	if not _is_inside(x, y) or int(grid[y][x]) != EMPTY_FLOOR:
		return false
	grid[y][x] = DYED_FLOOR
	return true


func get_empty_floor_count() -> int:
	var empty_floor_count := 0
	for row in grid:
		for cell in row:
			if int(cell) == EMPTY_FLOOR:
				empty_floor_count += 1
	return empty_floor_count


func is_level_complete() -> bool:
	return not grid.is_empty() and get_empty_floor_count() == 0


func get_save_data() -> Dictionary:
	return {
		"level_index": current_level_index,
		"level_name": current_level_name,
		"width": width,
		"height": height,
		"player_x": player_x,
		"player_y": player_y,
		"grid": grid,
	}


func load_save_data(save_data: Dictionary) -> bool:
	var saved_width := int(save_data.get("width", 0))
	var saved_height := int(save_data.get("height", 0))
	var saved_player_x := int(save_data.get("player_x", -1))
	var saved_player_y := int(save_data.get("player_y", -1))
	var saved_grid: Variant = save_data.get("grid")

	if not _is_valid_grid(saved_grid, saved_width, saved_height):
		return false
	if saved_player_x < 0 or saved_player_x >= saved_width:
		return false
	if saved_player_y < 0 or saved_player_y >= saved_height:
		return false
	if int(saved_grid[saved_player_y][saved_player_x]) == WALL:
		return false

	current_level_index = int(save_data.get("level_index", 0))
	current_level_name = str(save_data.get("level_name", "Level %d" % (current_level_index + 1)))
	width = saved_width
	height = saved_height
	player_x = saved_player_x
	player_y = saved_player_y
	grid = saved_grid.duplicate(true)
	invalidate_solution()
	return true


func can_current_level_be_solved_recursively(max_moves: int = 20) -> bool:
	invalidate_solution()
	if grid.is_empty() or max_moves <= 0:
		return false

	var test_grid := grid.duplicate(true)
	var start_position := Vector2i(player_x, player_y)
	_set_cell_dyed_in_grid(test_grid, start_position)
	var visited_states := {}

	for depth_limit in range(1, max_moves + 1):
		var solution_moves := MoveStack.new()
		if _search_solution_recursive(
			start_position,
			test_grid,
			depth_limit,
			visited_states,
			solution_moves
		):
			last_solution_moves = solution_moves
			solution_state_key = _build_solver_state_key(start_position, test_grid)
			return true

	return false


func get_next_solution_hint(max_moves: int = 20) -> String:
	if is_level_complete():
		return "Level ist bereits geschafft."

	var current_state_key := _build_solver_state_key(Vector2i(player_x, player_y), grid)
	if pending_solution_move != null and solution_state_key == current_state_key:
		return "Nächster Zug: " + str(pending_solution_move)

	if last_solution_moves.is_empty() or solution_state_key != current_state_key:
		if not can_current_level_be_solved_recursively(max_moves):
			return "Keine Lösung in %d Zügen gefunden." % max_moves

	pending_solution_move = last_solution_moves.pop()
	if pending_solution_move == null:
		return "Level ist bereits geschafft."
	return "Nächster Zug: " + str(pending_solution_move)


func register_player_move(direction: Vector2i) -> void:
	if pending_solution_move == _direction_to_text(direction):
		pending_solution_move = null
		solution_state_key = _build_solver_state_key(Vector2i(player_x, player_y), grid)
	else:
		invalidate_solution()


func invalidate_solution() -> void:
	last_solution_moves = MoveStack.new()
	pending_solution_move = null
	solution_state_key = ""


func _search_solution_recursive(
	position: Vector2i,
	current_grid: Array,
	moves_left: int,
	visited_states: Dictionary,
	solution_moves: MoveStack
) -> bool:
	if _is_grid_complete(current_grid):
		return true
	if moves_left <= 0:
		return false

	var state_key := _build_solver_state_key(position, current_grid)
	if int(visited_states.get(state_key, -1)) >= moves_left:
		return false
	visited_states[state_key] = moves_left

	for direction in SOLVER_DIRECTIONS:
		if _get_cell_in_grid(current_grid, position + direction) == WALL:
			continue

		var next_grid := current_grid.duplicate(true)
		var next_position := _slide_and_dye_in_grid(position, direction, next_grid)
		if _search_solution_recursive(
			next_position,
			next_grid,
			moves_left - 1,
			visited_states,
			solution_moves
		):
			solution_moves.push(_direction_to_text(direction))
			return true

	return false


func _slide_and_dye_in_grid(
	start_position: Vector2i,
	direction: Vector2i,
	target_grid: Array
) -> Vector2i:
	var current_position := start_position
	var next_position := current_position + direction
	while _get_cell_in_grid(target_grid, next_position) != WALL:
		current_position = next_position
		_set_cell_dyed_in_grid(target_grid, current_position)
		next_position += direction
	return current_position


func _get_cell_in_grid(target_grid: Array, position: Vector2i) -> int:
	if _is_inside(position.x, position.y):
		return int(target_grid[position.y][position.x])
	return WALL


func _set_cell_dyed_in_grid(target_grid: Array, position: Vector2i) -> void:
	if _is_inside(position.x, position.y) and int(target_grid[position.y][position.x]) == EMPTY_FLOOR:
		target_grid[position.y][position.x] = DYED_FLOOR


func _is_grid_complete(target_grid: Array) -> bool:
	for row in target_grid:
		for cell in row:
			if int(cell) == EMPTY_FLOOR:
				return false
	return true


func _build_solver_state_key(position: Vector2i, target_grid: Array) -> String:
	var cells := PackedStringArray()
	cells.resize(width * height)
	var index := 0
	for row in target_grid:
		for cell in row:
			cells[index] = str(int(cell))
			index += 1
	return "%d,%d:%s" % [position.x, position.y, "".join(cells)]


func _direction_to_text(direction: Vector2i) -> String:
	if direction == Vector2i.RIGHT:
		return "rechts"
	if direction == Vector2i.LEFT:
		return "links"
	if direction == Vector2i.DOWN:
		return "unten"
	if direction == Vector2i.UP:
		return "oben"
	return ""


func _is_inside(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func _is_valid_grid(candidate: Variant, expected_width: int, expected_height: int) -> bool:
	if expected_width <= 0 or expected_height <= 0 or typeof(candidate) != TYPE_ARRAY:
		return false
	if candidate.size() != expected_height:
		return false

	for row in candidate:
		if typeof(row) != TYPE_ARRAY or row.size() != expected_width:
			return false
		for value in row:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return false
			var cell := int(value)
			if cell != WALL and cell != EMPTY_FLOOR and cell != DYED_FLOOR:
				return false
	return true
