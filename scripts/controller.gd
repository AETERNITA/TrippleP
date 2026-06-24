extends Node2D
var model: GameModel
@onready var view: TileMapLayer = $TileMapLayer
@export var player_node: CharacterBody2D # Zieht hier das Player-Node im Inspektor rein

#Kachelgröße in Pixeln
const TILE_SIZE: int = 32

func _ready():
	model = GameModel.new()
	model.setup_test_level()
	view.draw_field(model)
# Startposition des Spielers visuell setzen
	player_node.position = Vector2(230,0)
	update_player_sprite_position()
	
func _process(_delta):
	var direction = Vector2i.ZERO
	if Input.is_action_just_pressed("ui_right"):
		direction = Vector2i(1, 0)
	elif Input.is_action_just_pressed("ui_left"):
		direction = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("ui_down"):
		direction = Vector2i(0, 1)
	elif Input.is_action_just_pressed("ui_up"):
		direction = Vector2i(0, -1)
	if direction != Vector2i.ZERO:
		move_player_in_direction(direction)
		
func move_player_in_direction(dir: Vector2i):
	var next_x = model.player_x + dir.x
	var next_y = model.player_y + dir.y
	
	# Schleife: Bewege logisch im Model weiter, bis eine Wand kommt
	# while model.get_cell(next_x, next_y) != model.WAND:
	print("Hifle")
	model.player_x = next_x
	model.player_y = next_y
# Aktuelles Feld im Model als gefärbt markieren
	model.set_cell_dyed(model.player_x, model.player_y)
	next_x = model.player_x + dir.x
	next_y = model.player_y + dir.y
# Nach dem Zug: Aktualisiere die TileMap und die visuelle Position des Spielers
	view.draw_field(model)
	update_player_sprite_position()

# Rechnet die Grid-Koordinaten (z.B. 1,1) in Pixel (z.B. 64,64) um
func update_player_sprite_position():
	if player_node:
		@warning_ignore("integer_division")
		var pixel_x = model.player_x * TILE_SIZE + (TILE_SIZE / 2)
		@warning_ignore("integer_division")
		var pixel_y = model.player_y * TILE_SIZE + (TILE_SIZE / 2)
		player_node.position = Vector2(pixel_x, pixel_y)
