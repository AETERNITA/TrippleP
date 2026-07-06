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
var levels = []
var current_level_index: int = 0
var current_level_name: String = ""

const LEVEL_FILE_PATH = "res://data/levels.json"

func load_levels() -> bool:
	if not levels.is_empty():
		return true
	
	if not FileAccess.file_exists(LEVEL_FILE_PATH):
		return false
	
	var level_file = FileAccess.open(LEVEL_FILE_PATH, FileAccess.READ)
	var parsed_data = JSON.parse_string(level_file.get_as_text())
	
	if typeof(parsed_data) != TYPE_DICTIONARY or not parsed_data.has("levels"):
		return false
	
	levels = parsed_data["levels"]
	return not levels.is_empty()

func get_level_count() -> int:
	if load_levels():
		return levels.size()
	return 0

func load_level(level_index: int) -> bool:
	if not load_levels():
		return false
	
	if level_index < 0 or level_index >= levels.size():
		return false
	
	var level_data = levels[level_index]
	var rows = level_data["rows"]
	
	current_level_index = level_index
	current_level_name = level_data.get("name", "Level " + str(level_index + 1))
	height = rows.size()
	width = rows[0].length()
	grid = []
	
	for y in range(height):
		var row = []
		var row_text: String = rows[y]
		
		for x in range(width):
			var tile = row_text.substr(x, 1)
			
			if tile == "#":
				row.append(WAND)
			else:
				row.append(BODEN_LEER)
			
			if tile == "P":
				player_x = x
				player_y = y
		
		grid.append(row)
	
	return true

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
