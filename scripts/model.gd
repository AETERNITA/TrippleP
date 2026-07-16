class_name GameModel
extends RefCounted

const SolutionSearchScript = preload("res://scripts/solution_search.gd")
const WAND := 0
const BODEN_LEER := 1
const BODEN_GEFAERBT := 2

const LEVEL_DATEI := "res://data/levels.json"
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
var _such_thread: Thread = null


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


func levelnamen_holen() -> Array[String]:
	var namen: Array[String] = []
	if not leveldaten_laden():
		return namen
	for level_nummer in range(levels.size()):
		var level_daten: Dictionary = levels[level_nummer]
		namen.append(str(level_daten.get("name", "Level %d" % (level_nummer + 1))))
	return namen


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
	if not loesungssuche_starten(maximale_zuege):
		return false
	var ergebnis: Variant = _such_thread.wait_to_finish()
	_such_thread = null
	return _suchergebnis_uebernehmen(ergebnis)


func loesungssuchlimit_holen() -> int:
	# Das Limit richtet sich nach der gesamten Levelgroesse und schrumpft nicht
	# bei verstreuten Restfeldern in einem weit fortgeschrittenen Boss-Level.
	var begehbare_felder := width * height - _waende_zaehlen()
	return maxi(40, begehbare_felder + 40)


func loesungssuche_starten(maximale_zuege: int = 20) -> bool:
	if _such_thread != null or grid.is_empty() or maximale_zuege <= 0:
		return false

	last_solution_moves.leeren()
	pending_solution_move = null
	solution_state_key = ""
	var raster_kopie := grid.duplicate(true)
	var start_position := Vector2i(player_x, player_y)
	_such_thread = Thread.new()
	var fehler := _such_thread.start(
		_loesung_im_thread.bind(
			raster_kopie,
			start_position,
			width,
			height,
			maximale_zuege
		)
	)
	if fehler != OK:
		_such_thread = null
		return false
	return true


func loesungssuche_ergebnis_bereit() -> bool:
	return _such_thread != null and not _such_thread.is_alive()


func loesungssuche_ergebnis_abholen() -> String:
	if _such_thread == null:
		return "Keine Lösungssuche aktiv."
	if _such_thread.is_alive():
		return "Lösung wird noch gesucht."

	var ergebnis: Variant = _such_thread.wait_to_finish()
	_such_thread = null
	if not _suchergebnis_uebernehmen(ergebnis):
		return "Keine Lösung innerhalb des Zuglimits gefunden."

	pending_solution_move = last_solution_moves.zug_nehmen()
	if pending_solution_move == null:
		return "Level ist bereits geschafft."
	return "Nächster Zug: " + _richtung_als_text(pending_solution_move)


func loesungssuche_beenden() -> void:
	if _such_thread == null:
		return
	_such_thread.wait_to_finish()
	_such_thread = null


func _loesung_im_thread(
	raster: Array,
	start_position: Vector2i,
	breite: int,
	hoehe: int,
	maximale_zuege: int
) -> Dictionary:
	# Der Worker besitzt eine tiefe Rasterkopie. Er teilt keine veraenderlichen
	# Daten mit Model, Controller oder View; deshalb ist kein Mutex erforderlich.
	var suche := SolutionSearchScript.new()
	return suche.suchen(raster, start_position, breite, hoehe, maximale_zuege)


func _suchergebnis_uebernehmen(ergebnis: Variant) -> bool:
	if typeof(ergebnis) != TYPE_DICTIONARY or not bool(ergebnis.get("erfolgreich", false)):
		return false
	var zuege: Variant = ergebnis.get("zuege")
	if typeof(zuege) != TYPE_ARRAY:
		return false
	last_solution_moves = MoveStack.new()
	for index in range(zuege.size() - 1, -1, -1):
		if typeof(zuege[index]) != TYPE_VECTOR2I:
			return false
		last_solution_moves.zug_ablegen(zuege[index])
	pending_solution_move = null
	solution_state_key = _zustandsschluessel_bauen(Vector2i(player_x, player_y), grid)
	return true


func naechsten_loesungszug_suchen(maximale_zuege: int = 20) -> String:
	if ist_level_geschafft():
		return "Level ist bereits geschafft."

	var aktueller_zustand := _zustandsschluessel_bauen(Vector2i(player_x, player_y), grid)
	if pending_solution_move != null and solution_state_key == aktueller_zustand:
		return "Nächster Zug: " + _richtung_als_text(pending_solution_move)

	if last_solution_moves.ist_leer() or solution_state_key != aktueller_zustand:
		if not ist_rekursiv_loesbar(maximale_zuege):
			return "Keine Lösung in %d Zügen gefunden." % maximale_zuege

	pending_solution_move = last_solution_moves.zug_nehmen()
	if pending_solution_move == null:
		return "Level ist bereits geschafft."
	return "Nächster Zug: " + _richtung_als_text(pending_solution_move)


func loesungsrichtung_holen() -> Vector2i:
	if pending_solution_move == null:
		return Vector2i.ZERO
	return pending_solution_move


func spielerzug_eintragen(richtung: Vector2i) -> void:
	if pending_solution_move == richtung:
		pending_solution_move = null
		solution_state_key = _zustandsschluessel_bauen(Vector2i(player_x, player_y), grid)
	else:
		loesung_zuruecksetzen()


func loesung_zuruecksetzen() -> void:
	loesungssuche_beenden()
	last_solution_moves = MoveStack.new()
	pending_solution_move = null
	solution_state_key = ""

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


func _ist_im_spielfeld(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func _waende_zaehlen() -> int:
	var anzahl := 0
	for reihe in grid:
		for feld in reihe:
			if int(feld) == WAND:
				anzahl += 1
	return anzahl


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
