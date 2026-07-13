extends TileMapLayer

const BODEN_SOURCE_ID := 1
const GEFAERBTER_BODEN_SOURCE_ID := 2
const WAND_SOURCE_ID := 3
const WAND_TILE := Vector2i.ZERO
const BODEN_TILE := Vector2i.ZERO
const GEFAERBTER_BODEN_TILE := Vector2i.ZERO

# Diese Nummern gehören zu den drei Quellen im TileSet.

func spielfeld_zeichnen(model: GameModel) -> void:
	clear()
	for y in range(model.height):
		for x in range(model.width):
			feld_zeichnen(model, Vector2i(x, y))


func feld_zeichnen(model: GameModel, feld_position: Vector2i) -> void:
	var source_id := BODEN_SOURCE_ID
	var atlas_coordinates := BODEN_TILE
	match model.feld_auslesen(feld_position.x, feld_position.y):
		GameModel.WAND:
			source_id = WAND_SOURCE_ID
			atlas_coordinates = WAND_TILE
		GameModel.BODEN_GEFAERBT:
			source_id = GEFAERBTER_BODEN_SOURCE_ID
			atlas_coordinates = GEFAERBTER_BODEN_TILE
	set_cell(feld_position, source_id, atlas_coordinates)
