extends Node2D

var model: GameModel
var elapsed_time: float
var is_moving: bool = false

@onready var view: TileMapLayer = $TileMapLayer
@export var player_node: CharacterBody2D # Zieht hier das Player-Node im Inspektor rein

const TILE_SIZE: int = 32
const STEP_TIME: float = 0.04

func _ready():
	model = GameModel.new()
	if not model.load_level(0):
		model.setup_test_level()
	model.set_cell_dyed(model.player_x, model.player_y)
	view.draw_field(model)
	update_player_sprite_position()

func _unhandled_input(event):
	if is_moving:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			load_level(0)
		elif event.keycode == KEY_2:
			load_level(1)
		elif event.keycode == KEY_3:
			load_level(2)

func _process(_delta):
	if is_moving:
		return
	
	var input_direction = check_player_input()
	if input_direction != Vector2i.ZERO:
		move_player_in_direction(input_direction)

func check_player_input() -> Vector2i:
	if Input.is_action_just_pressed("ui_right"):
		return Vector2i(1, 0)
	elif Input.is_action_just_pressed("ui_left"):
		return Vector2i(-1, 0)
	elif Input.is_action_just_pressed("ui_down"):
		return Vector2i(0, 1)
	elif Input.is_action_just_pressed("ui_up"):
		return Vector2i(0, -1)
	return Vector2i.ZERO

func load_level(level_index: int):
	if model.load_level(level_index):
		model.set_cell_dyed(model.player_x, model.player_y)
		view.draw_field(model)
		update_player_sprite_position()

func move_player_in_direction(dir: Vector2i):
	is_moving = true
	
	var next_x = model.player_x + dir.x
	var next_y = model.player_y + dir.y
	
	while model.get_cell(next_x, next_y) != model.WAND:
		model.player_x = next_x
		model.player_y = next_y
		update_player_sprite_position()
		
		await get_tree().create_timer(STEP_TIME).timeout
		
		model.set_cell_dyed(model.player_x, model.player_y)
		view.draw_field(model)
		
		next_x = model.player_x + dir.x
		next_y = model.player_y + dir.y
	
	is_moving = false

func update_player_sprite_position():
	if player_node:
		player_node.position = get_player_pixel_position()

func get_player_pixel_position() -> Vector2:
	@warning_ignore("integer_division")
	var pixel_x = model.player_x * TILE_SIZE + (TILE_SIZE / 2)
	@warning_ignore("integer_division")
	var pixel_y = model.player_y * TILE_SIZE + (TILE_SIZE / 2)
	return Vector2(pixel_x, pixel_y)
