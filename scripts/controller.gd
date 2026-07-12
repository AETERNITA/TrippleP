extends Node2D

const TILE_SIZE := 32
const STEP_TIME := 0.04
const SAVE_FILE_PATH := "user://savegame.json"
const SOLVER_HINT_MAX_MOVES := 40

var model: GameModel
var is_moving := false
var level_complete := false

@onready var view: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var level_complete_label: Label = $CanvasLayer/LevelCompleteLabel
@onready var start_menu: Control = $CanvasLayer/StartMenu
@onready var level_selection_menu: Control = $CanvasLayer/LevelSelectionMenu
@onready var level_finished_menu: Control = $CanvasLayer/LevelFinishedMenu
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var level_button_container: VBoxContainer = $CanvasLayer/LevelSelectionMenu/MenuPanel/LevelButtonContainer
@onready var continue_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/NewGameButton
@onready var level_selection_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/LevelSelectionButton
@onready var quit_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/QuitButton
@onready var back_button: Button = $CanvasLayer/LevelSelectionMenu/MenuPanel/BackButton
@onready var next_level_button: Button = $CanvasLayer/LevelFinishedMenu/MenuPanel/ButtonContainer/NextLevelButton
@onready var finished_main_menu_button: Button = $CanvasLayer/LevelFinishedMenu/MenuPanel/ButtonContainer/MainMenuButton
@onready var finished_title_label: Label = $CanvasLayer/LevelFinishedMenu/MenuPanel/TitleLabel
@onready var pause_continue_button: Button = $CanvasLayer/PauseMenu/MenuPanel/ButtonContainer/ContinueButton
@onready var pause_main_menu_button: Button = $CanvasLayer/PauseMenu/MenuPanel/ButtonContainer/MainMenuButton
@onready var solve_hint_button: Button = $CanvasLayer/GameHud/SolveHintButton
@onready var solver_info_label: Label = $CanvasLayer/GameHud/SolverInfoLabel
@onready var player_node: CharacterBody2D = $Player


func _ready() -> void:
	model = GameModel.new()
	model.load_levels()
	connect_menu_buttons()
	build_level_selection_menu()

	if not load_level(0, false):
		model.setup_test_level()
		model.set_cell_dyed(model.player_x, model.player_y)
		refresh_game_view()

	get_viewport().size_changed.connect(fit_game_to_screen)
	show_start_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_menu.visible:
			hide_pause_menu()
		elif not is_moving and not start_menu.visible and not level_selection_menu.visible and not level_finished_menu.visible:
			show_pause_menu()
		return

	if is_moving or is_menu_open():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			load_level(0)
		elif event.keycode == KEY_2:
			load_level(1)
		elif event.keycode == KEY_3:
			load_level(2)


func _process(_delta: float) -> void:
	if is_moving or level_complete or is_menu_open():
		return

	var input_direction := check_player_input()
	if input_direction != Vector2i.ZERO:
		move_player_in_direction(input_direction)


func check_player_input() -> Vector2i:
	if Input.is_action_just_pressed("ui_right"):
		return Vector2i.RIGHT
	if Input.is_action_just_pressed("ui_left"):
		return Vector2i.LEFT
	if Input.is_action_just_pressed("ui_down"):
		return Vector2i.DOWN
	if Input.is_action_just_pressed("ui_up"):
		return Vector2i.UP
	return Vector2i.ZERO


func load_level(level_index: int, should_save := true) -> bool:
	if not model.load_level(level_index):
		return false

	model.set_cell_dyed(model.player_x, model.player_y)
	refresh_game_view()
	if should_save:
		save_game()
	return true


func move_player_in_direction(direction: Vector2i) -> void:
	var next_position := Vector2i(model.player_x, model.player_y) + direction
	if model.get_cell(next_position.x, next_position.y) == GameModel.WALL:
		return

	is_moving = true
	while model.get_cell(next_position.x, next_position.y) != GameModel.WALL:
		model.player_x = next_position.x
		model.player_y = next_position.y
		update_player_sprite_position()

		await get_tree().create_timer(STEP_TIME).timeout

		if model.set_cell_dyed(model.player_x, model.player_y):
			view.draw_cell(model, next_position)
			update_level_complete_state()
		next_position += direction

	is_moving = false
	model.register_player_move(direction)
	save_game()
	clear_solver_info()


func update_level_complete_state() -> void:
	if level_complete or not model.is_level_complete():
		return

	level_complete = true
	var completion_text := model.current_level_name + " geschafft!"
	level_complete_label.text = completion_text
	finished_title_label.text = completion_text
	next_level_button.disabled = model.current_level_index >= model.get_level_count() - 1
	level_finished_menu.visible = true


func update_player_sprite_position() -> void:
	player_node.position = get_player_pixel_position()


func get_player_pixel_position() -> Vector2:
	var grid_position := Vector2(model.player_x, model.player_y)
	return grid_position * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)


func fit_game_to_screen() -> void:
	if model == null or model.width <= 0 or model.height <= 0:
		return

	var field_size := Vector2(model.width, model.height) * TILE_SIZE
	var viewport_size := get_viewport_rect().size
	var zoom_factor := minf(viewport_size.x / field_size.x, viewport_size.y / field_size.y)
	camera.position = field_size / 2.0
	camera.zoom = Vector2.ONE * zoom_factor


func connect_menu_buttons() -> void:
	continue_button.pressed.connect(continue_game)
	new_game_button.pressed.connect(start_new_game)
	level_selection_button.pressed.connect(show_level_selection_menu)
	quit_button.pressed.connect(quit_game)
	back_button.pressed.connect(show_start_menu)
	next_level_button.pressed.connect(load_next_level)
	finished_main_menu_button.pressed.connect(show_start_menu)
	pause_continue_button.pressed.connect(hide_pause_menu)
	pause_main_menu_button.pressed.connect(show_start_menu)
	solve_hint_button.pressed.connect(show_solution_hint)


func build_level_selection_menu() -> void:
	for level_index in range(model.get_level_count()):
		var level_button := Button.new()
		var level_data: Dictionary = model.levels[level_index]
		level_button.text = "%d. %s" % [
			level_index + 1,
			level_data.get("name", "Level %d" % (level_index + 1)),
		]
		level_button.custom_minimum_size = Vector2(260, 44)

		var selected_level_index := level_index
		level_button.pressed.connect(func() -> void: select_level(selected_level_index))
		level_button_container.add_child(level_button)


func show_start_menu() -> void:
	hide_menus()
	start_menu.visible = true


func show_level_selection_menu() -> void:
	hide_menus()
	level_selection_menu.visible = true


func show_pause_menu() -> void:
	pause_menu.visible = true


func hide_pause_menu() -> void:
	pause_menu.visible = false


func hide_menus() -> void:
	start_menu.visible = false
	level_selection_menu.visible = false
	level_finished_menu.visible = false
	pause_menu.visible = false


func is_menu_open() -> bool:
	return start_menu.visible or level_selection_menu.visible or level_finished_menu.visible or pause_menu.visible


func continue_game() -> void:
	hide_menus()
	if not load_saved_game():
		load_level(0)


func start_new_game() -> void:
	hide_menus()
	load_level(0)


func quit_game() -> void:
	get_tree().quit()


func select_level(level_index: int) -> void:
	hide_menus()
	load_level(level_index)


func load_next_level() -> void:
	var next_level_index := model.current_level_index + 1
	if next_level_index >= model.get_level_count():
		show_start_menu()
		return
	hide_menus()
	load_level(next_level_index)


func show_solution_hint() -> void:
	solver_info_label.text = model.get_next_solution_hint(SOLVER_HINT_MAX_MOVES)
	solver_info_label.visible = true


func clear_solver_info() -> void:
	solver_info_label.text = ""
	solver_info_label.visible = false


func refresh_game_view() -> void:
	level_complete = false
	level_complete_label.visible = false
	level_finished_menu.visible = false
	clear_solver_info()
	view.draw_field(model)
	update_player_sprite_position()
	fit_game_to_screen()
	update_level_complete_state()


func save_game() -> bool:
	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if save_file == null:
		return false
	save_file.store_string(JSON.stringify(model.get_save_data()))
	return true


func load_saved_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false

	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if save_file == null:
		return false

	var save_data: Variant = JSON.parse_string(save_file.get_as_text())
	if typeof(save_data) != TYPE_DICTIONARY or not model.load_save_data(save_data):
		return false

	refresh_game_view()
	return true
