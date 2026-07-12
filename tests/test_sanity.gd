extends GutTest


func test_empty_grid_is_not_complete() -> void:
	var model := GameModel.new()

	assert_false(model.is_level_complete(), "Ein leeres Raster ist kein abgeschlossenes Level.")


func test_level_is_not_complete_while_empty_floor_exists() -> void:
	var model := GameModel.new()
	model.width = 3
	model.height = 3
	model.grid = [
		[model.WALL, model.WALL, model.WALL],
		[model.WALL, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL],
	]

	assert_false(model.is_level_complete(), "Ein Level mit leerem Boden ist noch nicht geschafft.")


func test_level_is_complete_when_all_floor_is_dyed() -> void:
	var model := GameModel.new()
	model.width = 3
	model.height = 3
	model.grid = [
		[model.WALL, model.WALL, model.WALL],
		[model.WALL, model.DYED_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL],
	]

	assert_true(model.is_level_complete(), "Ein Level ohne leeren Boden ist geschafft.")


func test_save_data_can_restore_current_game_state() -> void:
	var model := GameModel.new()
	model.current_level_index = 2
	model.current_level_name = "Testlevel"
	model.width = 3
	model.height = 3
	model.player_x = 1
	model.player_y = 1
	model.grid = [
		[model.WALL, model.WALL, model.WALL],
		[model.WALL, model.DYED_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL],
	]

	var restored_model := GameModel.new()
	var loaded_successfully := restored_model.load_save_data(model.get_save_data())

	assert_true(loaded_successfully, "Gespeicherte Spieldaten sollen wieder geladen werden können.")
	assert_eq(restored_model.current_level_index, 2)
	assert_eq(restored_model.current_level_name, "Testlevel")
	assert_eq(restored_model.player_x, 1)
	assert_eq(restored_model.grid[1][1], model.DYED_FLOOR)


func test_invalid_save_data_is_rejected() -> void:
	var model := GameModel.new()
	var invalid_save := {
		"width": 3,
		"height": 3,
		"player_x": 1,
		"player_y": 1,
		"grid": [[0, 0, 0], [0, 2], [0, 0, 0]],
	}

	assert_false(model.load_save_data(invalid_save), "Ein unvollständiges Raster darf nicht geladen werden.")


func test_move_stack_uses_last_in_first_out_order() -> void:
	var move_stack := MoveStack.new()
	move_stack.push("rechts")
	move_stack.push("unten")

	assert_eq(move_stack.pop(), "unten")
	assert_eq(move_stack.pop(), "rechts")
	assert_true(move_stack.is_empty())


func test_recursive_solver_finds_simple_solution() -> void:
	var model := GameModel.new()
	model.width = 4
	model.height = 3
	model.player_x = 1
	model.player_y = 1
	model.grid = [
		[model.WALL, model.WALL, model.WALL, model.WALL],
		[model.WALL, model.DYED_FLOOR, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL, model.WALL],
	]

	assert_true(model.can_current_level_be_solved_recursively(1), "Ein Feld rechts soll in einem Zug lösbar sein.")
	assert_eq(model.last_solution_moves.pop(), "rechts")


func test_solution_hint_uses_recursive_solver_result() -> void:
	var model := GameModel.new()
	model.width = 4
	model.height = 3
	model.player_x = 1
	model.player_y = 1
	model.grid = [
		[model.WALL, model.WALL, model.WALL, model.WALL],
		[model.WALL, model.DYED_FLOOR, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL, model.WALL],
	]

	assert_eq(model.get_next_solution_hint(1), "Nächster Zug: rechts")


func test_recursive_solver_rejects_blocked_level() -> void:
	var model := GameModel.new()
	model.width = 5
	model.height = 3
	model.player_x = 1
	model.player_y = 1
	model.grid = [
		[model.WALL, model.WALL, model.WALL, model.WALL, model.WALL],
		[model.WALL, model.DYED_FLOOR, model.WALL, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL, model.WALL, model.WALL],
	]

	assert_false(model.can_current_level_be_solved_recursively(3), "Ein abgetrenntes Feld darf nicht als lösbar gelten.")


func test_recursive_solver_finds_shortest_solution_with_iterative_depth() -> void:
	var model := GameModel.new()
	model.width = 5
	model.height = 5
	model.player_x = 2
	model.player_y = 2
	model.grid = [
		[model.WALL, model.WALL, model.WALL, model.WALL, model.WALL],
		[model.WALL, model.EMPTY_FLOOR, model.EMPTY_FLOOR, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.EMPTY_FLOOR, model.DYED_FLOOR, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.EMPTY_FLOOR, model.EMPTY_FLOOR, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL, model.WALL, model.WALL],
	]

	assert_false(model.can_current_level_be_solved_recursively(4), "Das Feld ist nicht in vier Zügen lösbar.")
	assert_true(model.can_current_level_be_solved_recursively(40), "Das Feld soll innerhalb des Limits lösbar sein.")
	assert_eq(model.last_solution_moves.size(), 5, "Die iterative Suche soll den kürzesten Weg mit fünf Zügen finden.")


func test_solution_hint_keeps_stack_until_player_moves() -> void:
	var model := GameModel.new()
	model.width = 4
	model.height = 3
	model.player_x = 1
	model.player_y = 1
	model.grid = [
		[model.WALL, model.WALL, model.WALL, model.WALL],
		[model.WALL, model.DYED_FLOOR, model.EMPTY_FLOOR, model.WALL],
		[model.WALL, model.WALL, model.WALL, model.WALL],
	]

	assert_eq(model.get_next_solution_hint(1), "Nächster Zug: rechts")
	assert_eq(model.get_next_solution_hint(1), "Nächster Zug: rechts", "Ohne Spielerzug soll derselbe Tipp angezeigt werden.")


func test_all_levels_are_solvable_within_move_limit() -> void:
	var model := GameModel.new()

	for level_index in range(model.get_level_count()):
		assert_true(model.load_level(level_index), "Das Level soll geladen werden können.")
		model.set_cell_dyed(model.player_x, model.player_y)
		assert_true(
			model.can_current_level_be_solved_recursively(40),
			model.current_level_name + " soll innerhalb von 40 Zügen lösbar sein."
		)
