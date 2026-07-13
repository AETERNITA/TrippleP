extends TileMapLayer

const FLOOR_SOURCE_ID := 1
const DYED_FLOOR_SOURCE_ID := 2
const WALL_SOURCE_ID := 3
const WALL_TILE := Vector2i.ZERO
const EMPTY_FLOOR_TILE := Vector2i.ZERO
const DYED_FLOOR_TILE := Vector2i.ZERO


func draw_field(model: GameModel) -> void:
	clear()
	for y in range(model.height):
		for x in range(model.width):
			draw_cell(model, Vector2i(x, y))


func draw_cell(model: GameModel, cell_position: Vector2i) -> void:
	var source_id := FLOOR_SOURCE_ID
	var atlas_coordinates := EMPTY_FLOOR_TILE
	match model.get_cell(cell_position.x, cell_position.y):
		GameModel.WALL:
			source_id = WALL_SOURCE_ID
			atlas_coordinates = WALL_TILE
		GameModel.DYED_FLOOR:
			source_id = DYED_FLOOR_SOURCE_ID
			atlas_coordinates = DYED_FLOOR_TILE
	set_cell(cell_position, source_id, atlas_coordinates)
