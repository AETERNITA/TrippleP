class_name SavegameStore
extends RefCounted

const SPEICHERDATEI := "user://savegame.json"


func speichern(speicherdaten: Dictionary) -> bool:
	var datei := FileAccess.open(SPEICHERDATEI, FileAccess.WRITE)
	if datei == null:
		return false
	datei.store_string(JSON.stringify(speicherdaten))
	return true


func laden() -> Variant:
	if not FileAccess.file_exists(SPEICHERDATEI):
		return null

	var datei := FileAccess.open(SPEICHERDATEI, FileAccess.READ)
	if datei == null:
		return null

	var daten: Variant = JSON.parse_string(datei.get_as_text())
	if typeof(daten) != TYPE_DICTIONARY:
		return null
	return daten
