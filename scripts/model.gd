class_name GameModel
extends RefCounted

const WAND := 0
const BODEN_LEER := 1
const BODEN_GEFAERBT := 2

const LEVEL_DATEI := "res://data/levels.json"
const SUCHRICHTUNGEN: Array[Vector2i] = [
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


func leveldaten_laden() -> bool:
	if not levels.is_empty():
		return true
	if not FileAccess.file_exists(LEVEL_DATEI):
		return false

	var datei := FileAccess.open(LEVEL_DATEI, FileAccess.READ)
	if datei == null:
		return false

	var json_daten: Variant = JSON.parse_string(datei.get_as_text())
	if typeof(json_daten) != TYPE_DICTIONARY:
		return false

	var geladene_level: Variant = json_daten.get("levels")
	if typeof(geladene_level) != TYPE_ARRAY or geladene_level.is_empty():
		return false

	levels = geladene_level
	return true


func anzahl_level() -> int:
	if leveldaten_laden():
		return levels.size()
	return 0


func level_laden(level_nummer: int) -> bool:
	if not leveldaten_laden() or level_nummer < 0 or level_nummer >= levels.size():
		return false

	var level_daten: Variant = levels[level_nummer]
	if typeof(level_daten) != TYPE_DICTIONARY:
		return false

	var zeilen: Variant = level_daten.get("rows")
	if typeof(zeilen) != TYPE_ARRAY or zeilen.is_empty():
		return false

	var neue_breite := str(zeilen[0]).length()
	if neue_breite == 0:
		return false

	var neues_raster: Array = []
	var startfeld := Vector2i(-1, -1)
	for y in range(zeilen.size()):
		var zeile := str(zeilen[y])
		if zeile.length() != neue_breite:
			return false

		var reihe: Array[int] = []
		for x in range(neue_breite):
			var zeichen := zeile.substr(x, 1)
			match zeichen:
				"#":
					reihe.append(WAND)
				".", "P":
					reihe.append(BODEN_LEER)
					if zeichen == "P":
						if startfeld.x >= 0:
							return false
						startfeld = Vector2i(x, y)
				_:
					return false
		neues_raster.append(reihe)

	if startfeld.x < 0:
		return false

	current_level_index = level_nummer
	current_level_name = str(level_daten.get("name", "Level %d" % (level_nummer + 1)))
	width = neue_breite
	height = zeilen.size()
	grid = neues_raster
	player_x = startfeld.x
	player_y = startfeld.y
	loesung_zuruecksetzen()
	return true


func testlevel_erstellen() -> void:
	current_level_index = 0
	current_level_name = "Testlevel"
	width = 21
	height = 21
	player_x = 1
	player_y = 1
	grid = []

	for y in range(height):
		var reihe: Array[int] = []
		for x in range(width):
			var ist_rand := x == 0 or x == width - 1 or y == 0 or y == height - 1
			if ist_rand:
				reihe.append(WAND)
			else:
				reihe.append(BODEN_LEER)
		grid.append(reihe)

	loesung_zuruecksetzen()


func feld_auslesen(x: int, y: int) -> int:
	if _ist_im_spielfeld(x, y):
		return int(grid[y][x])
	return WAND


func feld_faerben(x: int, y: int) -> bool:
	if not _ist_im_spielfeld(x, y) or int(grid[y][x]) != BODEN_LEER:
		return false
	grid[y][x] = BODEN_GEFAERBT
	return true


func leere_felder_zaehlen() -> int:
	var anzahl_leer := 0
	for reihe in grid:
		for feld in reihe:
			if int(feld) == BODEN_LEER:
				anzahl_leer += 1
	return anzahl_leer


func ist_level_geschafft() -> bool:
	return not grid.is_empty() and leere_felder_zaehlen() == 0


func speicherdaten_erstellen() -> Dictionary:
	return {
		"level_index": current_level_index,
		"level_name": current_level_name,
		"width": width,
		"height": height,
		"player_x": player_x,
		"player_y": player_y,
		"grid": grid,
	}


func speicherdaten_laden(speicherdaten: Dictionary) -> bool:
	var gespeicherte_breite := int(speicherdaten.get("width", 0))
	var gespeicherte_hoehe := int(speicherdaten.get("height", 0))
	var gespeichertes_x := int(speicherdaten.get("player_x", -1))
	var gespeichertes_y := int(speicherdaten.get("player_y", -1))
	var gespeichertes_raster: Variant = speicherdaten.get("grid")

	if not _ist_raster_gueltig(gespeichertes_raster, gespeicherte_breite, gespeicherte_hoehe):
		return false
	if gespeichertes_x < 0 or gespeichertes_x >= gespeicherte_breite:
		return false
	if gespeichertes_y < 0 or gespeichertes_y >= gespeicherte_hoehe:
		return false
	if int(gespeichertes_raster[gespeichertes_y][gespeichertes_x]) == WAND:
		return false

	current_level_index = int(speicherdaten.get("level_index", 0))
	current_level_name = str(speicherdaten.get("level_name", "Level %d" % (current_level_index + 1)))
	width = gespeicherte_breite
	height = gespeicherte_hoehe
	player_x = gespeichertes_x
	player_y = gespeichertes_y
	grid = gespeichertes_raster.duplicate(true)
	loesung_zuruecksetzen()
	return true


func ist_rekursiv_loesbar(maximale_zuege: int = 20) -> bool:
	loesung_zuruecksetzen()
	if grid.is_empty() or maximale_zuege <= 0:
		return false

	var test_raster := grid.duplicate(true)
	var start_position := Vector2i(player_x, player_y)
	_feld_im_raster_faerben(test_raster, start_position)
	var besuchte_zustaende := {}

	# Erst kurze Lösungen ausprobieren, danach immer einen Zug mehr erlauben.
	for zuglimit in range(1, maximale_zuege + 1):
		var loesungszuege := MoveStack.new()
		if _loesung_rekursiv_suchen(
			start_position,
			test_raster,
			zuglimit,
			besuchte_zustaende,
			loesungszuege
		):
			last_solution_moves = loesungszuege
			solution_state_key = _zustandsschluessel_bauen(start_position, test_raster)
			return true

	return false


func naechsten_loesungszug_suchen(maximale_zuege: int = 20) -> String:
	if ist_level_geschafft():
		return "Level ist bereits geschafft."

	var aktueller_zustand := _zustandsschluessel_bauen(Vector2i(player_x, player_y), grid)
	if pending_solution_move != null and solution_state_key == aktueller_zustand:
		return "Nächster Zug: " + str(pending_solution_move)

	if last_solution_moves.ist_leer() or solution_state_key != aktueller_zustand:
		if not ist_rekursiv_loesbar(maximale_zuege):
			return "Keine Lösung in %d Zügen gefunden." % maximale_zuege

	pending_solution_move = last_solution_moves.zug_nehmen()
	if pending_solution_move == null:
		return "Level ist bereits geschafft."
	return "Nächster Zug: " + str(pending_solution_move)


func loesungsrichtung_holen() -> Vector2i:
	if pending_solution_move == null:
		return Vector2i.ZERO
	return _text_als_richtung(str(pending_solution_move))


func spielerzug_eintragen(richtung: Vector2i) -> void:
	if pending_solution_move == _richtung_als_text(richtung):
		pending_solution_move = null
		solution_state_key = _zustandsschluessel_bauen(Vector2i(player_x, player_y), grid)
	else:
		loesung_zuruecksetzen()


func loesung_zuruecksetzen() -> void:
	last_solution_moves = MoveStack.new()
	pending_solution_move = null
	solution_state_key = ""


func _loesung_rekursiv_suchen(
	spieler_position: Vector2i,
	raster: Array,
	uebrige_zuege: int,
	besuchte_zustaende: Dictionary,
	loesungszuege: MoveStack
) -> bool:
	if _ist_raster_fertig(raster):
		return true
	if uebrige_zuege <= 0:
		return false

	var zustand := _zustandsschluessel_bauen(spieler_position, raster)
	if int(besuchte_zustaende.get(zustand, -1)) >= uebrige_zuege:
		return false
	besuchte_zustaende[zustand] = uebrige_zuege

	for richtung in SUCHRICHTUNGEN:
		if _feld_im_raster_auslesen(raster, spieler_position + richtung) == WAND:
			continue

		var neues_raster := raster.duplicate(true)
		var neue_position := _rutschen_und_faerben(spieler_position, richtung, neues_raster)
		if _loesung_rekursiv_suchen(
			neue_position,
			neues_raster,
			uebrige_zuege - 1,
			besuchte_zustaende,
			loesungszuege
		):
			# Beim Zurückgehen aus der Rekursion landen die Züge auf dem Stapel.
			loesungszuege.zug_ablegen(_richtung_als_text(richtung))
			return true

	return false


func _rutschen_und_faerben(
	start_position: Vector2i,
	richtung: Vector2i,
	raster: Array
) -> Vector2i:
	var aktuelle_position := start_position
	var naechste_position := aktuelle_position + richtung
	while _feld_im_raster_auslesen(raster, naechste_position) != WAND:
		aktuelle_position = naechste_position
		_feld_im_raster_faerben(raster, aktuelle_position)
		naechste_position += richtung
	return aktuelle_position


func _feld_im_raster_auslesen(raster: Array, feld_position: Vector2i) -> int:
	if _ist_im_spielfeld(feld_position.x, feld_position.y):
		return int(raster[feld_position.y][feld_position.x])
	return WAND


func _feld_im_raster_faerben(raster: Array, feld_position: Vector2i) -> void:
	if _ist_im_spielfeld(feld_position.x, feld_position.y) and int(raster[feld_position.y][feld_position.x]) == BODEN_LEER:
		raster[feld_position.y][feld_position.x] = BODEN_GEFAERBT


func _ist_raster_fertig(raster: Array) -> bool:
	for reihe in raster:
		for feld in reihe:
			if int(feld) == BODEN_LEER:
				return false
	return true


func _zustandsschluessel_bauen(spieler_position: Vector2i, raster: Array) -> String:
	var felder := PackedStringArray()
	felder.resize(width * height)
	var index := 0
	for reihe in raster:
		for feld in reihe:
			felder[index] = str(int(feld))
			index += 1
	return "%d,%d:%s" % [spieler_position.x, spieler_position.y, "".join(felder)]


func _richtung_als_text(richtung: Vector2i) -> String:
	if richtung == Vector2i.RIGHT:
		return "rechts"
	if richtung == Vector2i.LEFT:
		return "links"
	if richtung == Vector2i.DOWN:
		return "unten"
	if richtung == Vector2i.UP:
		return "oben"
	return ""


func _text_als_richtung(richtung_text: String) -> Vector2i:
	match richtung_text:
		"rechts":
			return Vector2i.RIGHT
		"links":
			return Vector2i.LEFT
		"unten":
			return Vector2i.DOWN
		"oben":
			return Vector2i.UP
	return Vector2i.ZERO


func _ist_im_spielfeld(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func _ist_raster_gueltig(raster: Variant, erwartete_breite: int, erwartete_hoehe: int) -> bool:
	if erwartete_breite <= 0 or erwartete_hoehe <= 0 or typeof(raster) != TYPE_ARRAY:
		return false
	if raster.size() != erwartete_hoehe:
		return false

	for reihe in raster:
		if typeof(reihe) != TYPE_ARRAY or reihe.size() != erwartete_breite:
			return false
		for wert in reihe:
			if typeof(wert) != TYPE_INT and typeof(wert) != TYPE_FLOAT:
				return false
			var feld := int(wert)
			if feld != WAND and feld != BODEN_LEER and feld != BODEN_GEFAERBT:
				return false
	return true
