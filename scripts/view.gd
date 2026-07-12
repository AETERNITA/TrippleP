extends TileMapLayer

const SOURCE_ID := 0
const WALL_TILE := Vector2i(5, 0)
const EMPTY_FLOOR_TILE := Vector2i(0, 2)
const DYED_FLOOR_TILE := Vector2i(4, 3)


func draw_field(model: GameModel) -> void:
	clear()
	for y in range(model.height):
		for x in range(model.width):
			draw_cell(model, Vector2i(x, y))


func draw_cell(model: GameModel, cell_position: Vector2i) -> void:
	var atlas_coordinates := EMPTY_FLOOR_TILE
	match model.get_cell(cell_position.x, cell_position.y):
		GameModel.WALL:
			atlas_coordinates = WALL_TILE
		GameModel.DYED_FLOOR:
			atlas_coordinates = DYED_FLOOR_TILE
	set_cell(cell_position, SOURCE_ID, atlas_coordinates)
