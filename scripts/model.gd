# model.gd
class_name GameModel
extends RefCounted

# Konstanten für die Feld-Typen
const WAND = 0
const BODEN_LEER = 1
const BODEN_GEFAERBT = 2

var grid = []
var width = 0
var height = 0
var player_x: int = 1
var player_y: int = 1

func setup_test_level():
	width = 21
	height = 21
	grid = []
	
	for y in range(height):
		var row = []
		for x in range(width):
			# Rahmen außen rum wird Wand, innen ist leerer Boden
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				row.append(WAND)
			else:
				row.append(BODEN_LEER)
		grid.append(row)

# Liefert den Wert an einer bestimmten Koordinate
func get_cell(x: int, y: int) -> int:
	if x >= 0 and x < width and y >= 0 and y < height:
		return grid[y][x]
	return WAND
	
func set_cell_dyed(x: int, y: int):
	if x >= 0 and x < width and y >= 0 and y < height:
		if grid[y][x] == BODEN_LEER:
			grid[y][x] = BODEN_GEFAERBT
