class_name SolutionSearch
extends RefCounted

const WAND := 0
const BODEN_LEER := 1
const BODEN_GEFAERBT := 2
const REKURSIVE_SUCHFELD_GRENZE := 150
const SUCHRICHTUNGEN: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]


func suchen(
	raster: Array,
	spieler_position: Vector2i,
	breite: int,
	hoehe: int,
	maximale_zuege: int
) -> Dictionary:
	var arbeitsraster := raster.duplicate(true)
	_feld_faerben(arbeitsraster, spieler_position, breite, hoehe)

	var loesungsstapel := MoveStack.new()
	var begehbare_felder := _begehbare_felder_zaehlen(arbeitsraster)
	var erfolgreich := _grosses_level_planen(
		spieler_position,
		arbeitsraster,
		breite,
		hoehe,
		maximale_zuege,
		loesungsstapel
	)
	# Auf grossen Rastern darf ein fehlgeschlagener Plan nicht in die
	# exponentielle Tiefensuche fallen. So bleibt auch ein beliebiger
	# Boss-Zwischenstand garantiert begrenzt.
	if not erfolgreich and begehbare_felder <= REKURSIVE_SUCHFELD_GRENZE:
		loesungsstapel.leeren()
		erfolgreich = _iterativ_vertieft_suchen(
			spieler_position,
			arbeitsraster,
			breite,
			hoehe,
			maximale_zuege,
			loesungsstapel
		)

	var zuege: Array[Vector2i] = []
	while not loesungsstapel.ist_leer():
		zuege.append(loesungsstapel.zug_nehmen())

	return {
		"erfolgreich": erfolgreich,
		"zuege": zuege,
	}


func _iterativ_vertieft_suchen(
	spieler_position: Vector2i,
	raster: Array,
	breite: int,
	hoehe: int,
	maximale_zuege: int,
	ergebnis: MoveStack
) -> bool:
	for zuglimit in range(1, maximale_zuege + 1):
		var besuchte_zustaende := {}
		var loesungszuege := MoveStack.new()
		if _loesung_rekursiv_suchen(
			spieler_position,
			raster,
			breite,
			hoehe,
			zuglimit,
			besuchte_zustaende,
			loesungszuege
		):
			var hilfsstapel := MoveStack.new()
			while not loesungszuege.ist_leer():
				hilfsstapel.zug_ablegen(loesungszuege.zug_nehmen())
			while not hilfsstapel.ist_leer():
				ergebnis.zug_ablegen(hilfsstapel.zug_nehmen())
			return true
	return false


# REKURSION: Tiefensuche mit iterativer Vertiefung und Memoisierung.
# Diese Funktion laeuft ausschliesslich im Such-Thread. Raster, Zustandsmenge
# und Stack gehoeren nur diesem Thread und bilden deshalb keinen kritischen Abschnitt.
func _loesung_rekursiv_suchen(
	spieler_position: Vector2i,
	raster: Array,
	breite: int,
	hoehe: int,
	uebrige_zuege: int,
	besuchte_zustaende: Dictionary,
	loesungszuege: MoveStack
) -> bool:
	if _ist_raster_fertig(raster):
		return true
	if uebrige_zuege <= 0:
		return false

	var zustand := _zustandsschluessel_bauen(spieler_position, raster, breite, hoehe)
	if int(besuchte_zustaende.get(zustand, -1)) >= uebrige_zuege:
		return false
	besuchte_zustaende[zustand] = uebrige_zuege

	var moegliche_zuege: Array[Dictionary] = []
	for richtung in SUCHRICHTUNGEN:
		if _feld_auslesen(raster, spieler_position + richtung, breite, hoehe) == WAND:
			continue
		var neues_raster := raster.duplicate(true)
		var vorher_leer := _leere_felder_zaehlen(neues_raster)
		var neue_position := _rutschen_und_faerben(
			spieler_position,
			richtung,
			neues_raster,
			breite,
			hoehe
		)
		moegliche_zuege.append({
			"richtung": richtung,
			"position": neue_position,
			"raster": neues_raster,
			"gewinn": vorher_leer - _leere_felder_zaehlen(neues_raster),
		})

	moegliche_zuege.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["gewinn"]) > int(b["gewinn"])
	)

	for zug in moegliche_zuege:
		if _loesung_rekursiv_suchen(
			zug["position"],
			zug["raster"],
			breite,
			hoehe,
			uebrige_zuege - 1,
			besuchte_zustaende,
			loesungszuege
		):
			loesungszuege.zug_ablegen(zug["richtung"])
			return true

	return false


func _grosses_level_planen(
	start_position: Vector2i,
	raster: Array,
	breite: int,
	hoehe: int,
	maximale_zuege: int,
	ergebnis: MoveStack
) -> bool:
	var transitionen := _transitionen_vorberechnen(raster, breite, hoehe)
	var gefaerbte_felder := {}
	var begehbare_felder := 0
	for y in range(hoehe):
		for x in range(breite):
			if int(raster[y][x]) == WAND:
				continue
			begehbare_felder += 1
			if int(raster[y][x]) == BODEN_GEFAERBT:
				gefaerbte_felder[Vector2i(x, y)] = true

	var aktuelle_position := start_position
	var weg: Array[Vector2i] = []
	while gefaerbte_felder.size() < begehbare_felder and weg.size() < maximale_zuege:
		var teilweg := _besten_naechsten_teilweg_finden(
			aktuelle_position,
			transitionen,
			gefaerbte_felder
		)
		if teilweg.is_empty():
			return false

		for transition in teilweg:
			weg.append(transition["richtung"])
			aktuelle_position = transition["position"]
			for feld_position in transition["felder"]:
				gefaerbte_felder[feld_position] = true
			if weg.size() > maximale_zuege:
				return false

	if gefaerbte_felder.size() < begehbare_felder:
		return false

	for index in range(weg.size() - 1, -1, -1):
		ergebnis.zug_ablegen(weg[index])
	return true


func _besten_naechsten_teilweg_finden(
	start_position: Vector2i,
	transitionen: Dictionary,
	gefaerbte_felder: Dictionary
) -> Array[Dictionary]:
	var warteschlange: Array[Vector2i] = [start_position]
	var naechster_index := 0
	var vorgaenger := {start_position: null}
	var entfernung := {start_position: 0}
	var beste_startposition := Vector2i.ZERO
	var beste_transition: Dictionary = {}
	var bester_wert := -1.0
	var bester_gewinn := -1

	while naechster_index < warteschlange.size():
		var position := warteschlange[naechster_index]
		naechster_index += 1
		var distanz := int(entfernung[position])

		for transition in transitionen.get(position, []):
			var gewinn := 0
			for feld_position in transition["felder"]:
				if not gefaerbte_felder.has(feld_position):
					gewinn += 1

			if gewinn > 0:
				var wert := float(gewinn) / float(distanz + 1)
				if wert > bester_wert or (is_equal_approx(wert, bester_wert) and gewinn > bester_gewinn):
					bester_wert = wert
					bester_gewinn = gewinn
					beste_startposition = position
					beste_transition = transition

			var ziel: Vector2i = transition["position"]
			if not vorgaenger.has(ziel):
				vorgaenger[ziel] = {
					"von": position,
					"transition": transition,
				}
				entfernung[ziel] = distanz + 1
				warteschlange.append(ziel)

	if beste_transition.is_empty():
		return []

	var rueckweg: Array[Dictionary] = []
	var rueckweg_position := beste_startposition
	while rueckweg_position != start_position:
		var schritt: Dictionary = vorgaenger[rueckweg_position]
		rueckweg.append(schritt["transition"])
		rueckweg_position = schritt["von"]

	# Der rekonstruierte Rueckweg liegt rueckwaerts vor.
	var teilweg: Array[Dictionary] = []
	for index in range(rueckweg.size() - 1, -1, -1):
		teilweg.append(rueckweg[index])
	teilweg.append(beste_transition)
	return teilweg
func _transitionen_vorberechnen(raster: Array, breite: int, hoehe: int) -> Dictionary:
	var transitionen := {}
	for y in range(hoehe):
		for x in range(breite):
			if int(raster[y][x]) == WAND:
				continue
			var position := Vector2i(x, y)
			var zuege: Array[Dictionary] = []
			for richtung in SUCHRICHTUNGEN:
				if _feld_auslesen(raster, position + richtung, breite, hoehe) == WAND:
					continue
				var felder: Array[Vector2i] = []
				var ziel := position
				var naechstes_feld := ziel + richtung
				while _feld_auslesen(raster, naechstes_feld, breite, hoehe) != WAND:
					ziel = naechstes_feld
					felder.append(ziel)
					naechstes_feld += richtung
				zuege.append({
					"richtung": richtung,
					"position": ziel,
					"felder": felder,
				})
			transitionen[position] = zuege
	return transitionen


func _rutschen_und_faerben(
	start_position: Vector2i,
	richtung: Vector2i,
	raster: Array,
	breite: int,
	hoehe: int
) -> Vector2i:
	var aktuelle_position := start_position
	var naechste_position := aktuelle_position + richtung
	while _feld_auslesen(raster, naechste_position, breite, hoehe) != WAND:
		aktuelle_position = naechste_position
		_feld_faerben(raster, aktuelle_position, breite, hoehe)
		naechste_position += richtung
	return aktuelle_position


func _feld_auslesen(
	raster: Array,
	feld_position: Vector2i,
	breite: int,
	hoehe: int
) -> int:
	if _ist_im_spielfeld(feld_position, breite, hoehe):
		return int(raster[feld_position.y][feld_position.x])
	return WAND


func _feld_faerben(
	raster: Array,
	feld_position: Vector2i,
	breite: int,
	hoehe: int
) -> void:
	if _ist_im_spielfeld(feld_position, breite, hoehe) and int(raster[feld_position.y][feld_position.x]) == BODEN_LEER:
		raster[feld_position.y][feld_position.x] = BODEN_GEFAERBT


func _ist_raster_fertig(raster: Array) -> bool:
	return _leere_felder_zaehlen(raster) == 0


func _leere_felder_zaehlen(raster: Array) -> int:
	var anzahl := 0
	for reihe in raster:
		for feld in reihe:
			if int(feld) == BODEN_LEER:
				anzahl += 1
	return anzahl


func _begehbare_felder_zaehlen(raster: Array) -> int:
	var anzahl := 0
	for reihe in raster:
		for feld in reihe:
			if int(feld) != WAND:
				anzahl += 1
	return anzahl


func _zustandsschluessel_bauen(
	spieler_position: Vector2i,
	raster: Array,
	breite: int,
	hoehe: int
) -> String:
	var felder := PackedStringArray()
	felder.resize(breite * hoehe)
	var index := 0
	for reihe in raster:
		for feld in reihe:
			felder[index] = str(int(feld))
			index += 1
	return "%d,%d:%s" % [spieler_position.x, spieler_position.y, "".join(felder)]


func _ist_im_spielfeld(position: Vector2i, breite: int, hoehe: int) -> bool:
	return position.x >= 0 and position.x < breite and position.y >= 0 and position.y < hoehe
