extends Node2D

const SavegameStoreScript = preload("res://scripts/savegame_store.gd")
const SCHRITT_DAUER := 0.04

var model: GameModel
var savegame_store := SavegameStoreScript.new()
var is_moving := false
var level_complete := false
var loesung_wird_gesucht := false

@onready var view = $TileMapLayer


func _ready() -> void:
	model = GameModel.new()
	model.leveldaten_laden()
	view_signale_verbinden()
	view.levelauswahl_bauen(model.levelnamen_holen())

	if not level_starten(0, false):
		model.testlevel_erstellen()
		model.feld_faerben(model.player_x, model.player_y)
		ansicht_aktualisieren()

	view.startmenue_anzeigen()


func _exit_tree() -> void:
	if model != null:
		model.loesungssuche_beenden()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if view.ist_pause_sichtbar():
			view.pause_schliessen()
		elif not is_moving and not loesung_wird_gesucht and not view.ist_menue_offen():
			view.pause_anzeigen()
		return

	if is_moving or loesung_wird_gesucht or view.ist_menue_offen():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			level_starten(0)
		elif event.keycode == KEY_2:
			level_starten(1)
		elif event.keycode == KEY_3:
			level_starten(2)


func _process(_delta: float) -> void:
	if loesung_wird_gesucht and model.loesungssuche_ergebnis_bereit():
		loesungsergebnis_verarbeiten()

	if is_moving or loesung_wird_gesucht or level_complete or view.ist_menue_offen():
		return

	var eingabe_richtung := bewegungseingabe_holen()
	if eingabe_richtung != Vector2i.ZERO:
		spieler_bewegen(eingabe_richtung)


func bewegungseingabe_holen() -> Vector2i:
	if Input.is_action_just_pressed("ui_right"):
		return Vector2i.RIGHT
	if Input.is_action_just_pressed("ui_left"):
		return Vector2i.LEFT
	if Input.is_action_just_pressed("ui_down"):
		return Vector2i.DOWN
	if Input.is_action_just_pressed("ui_up"):
		return Vector2i.UP
	return Vector2i.ZERO


func level_starten(level_nummer: int, danach_speichern := true) -> bool:
	if not model.level_laden(level_nummer):
		return false

	model.feld_faerben(model.player_x, model.player_y)
	ansicht_aktualisieren()
	if danach_speichern:
		spiel_speichern()
	return true


func spieler_bewegen(richtung: Vector2i) -> void:
	var naechstes_feld := Vector2i(model.player_x, model.player_y) + richtung
	if model.feld_auslesen(naechstes_feld.x, naechstes_feld.y) == GameModel.WAND:
		return

	is_moving = true
	while model.feld_auslesen(naechstes_feld.x, naechstes_feld.y) != GameModel.WAND:
		model.player_x = naechstes_feld.x
		model.player_y = naechstes_feld.y
		view.spielerposition_anzeigen(model)

		await get_tree().create_timer(SCHRITT_DAUER).timeout

		if model.feld_faerben(model.player_x, model.player_y):
			view.feld_zeichnen(model, naechstes_feld)
			levelstatus_pruefen()
		naechstes_feld += richtung

	is_moving = false
	model.spielerzug_eintragen(richtung)
	spiel_speichern()
	view.loesungstext_leeren()
	view.tipp_button_aktivieren(not level_complete)


func levelstatus_pruefen() -> void:
	if level_complete or not model.ist_level_geschafft():
		return

	level_complete = true
	var geschafft_text := model.current_level_name + " geschafft!"
	var hat_naechstes_level := model.current_level_index < model.anzahl_level() - 1
	view.level_geschafft_anzeigen(geschafft_text, hat_naechstes_level)


func view_signale_verbinden() -> void:
	view.fortsetzen_gewaehlt.connect(spiel_fortsetzen)
	view.neues_spiel_gewaehlt.connect(neues_spiel_starten)
	view.levelauswahl_gewaehlt.connect(view.levelauswahl_anzeigen)
	view.beenden_gewaehlt.connect(spiel_beenden)
	view.zurueck_gewaehlt.connect(view.startmenue_anzeigen)
	view.naechstes_level_gewaehlt.connect(naechstes_level_starten)
	view.hauptmenue_gewaehlt.connect(view.startmenue_anzeigen)
	view.pause_fortsetzen_gewaehlt.connect(view.pause_schliessen)
	view.level_gewaehlt.connect(level_auswaehlen)
	view.tipp_gewaehlt.connect(loesungszug_ausfuehren)


func spiel_fortsetzen() -> void:
	view.menues_schliessen()
	if not spielstand_laden():
		level_starten(0)


func neues_spiel_starten() -> void:
	view.menues_schliessen()
	level_starten(0)


func spiel_beenden() -> void:
	get_tree().quit()


func level_auswaehlen(level_nummer: int) -> void:
	view.menues_schliessen()
	level_starten(level_nummer)


func naechstes_level_starten() -> void:
	var naechste_levelnummer := model.current_level_index + 1
	if naechste_levelnummer >= model.anzahl_level():
		view.startmenue_anzeigen()
		return
	view.menues_schliessen()
	level_starten(naechste_levelnummer)


func loesungszug_ausfuehren() -> void:
	if is_moving or loesung_wird_gesucht or level_complete or view.ist_menue_offen():
		return
	if model.loesungssuche_starten(model.loesungssuchlimit_holen()):
		loesung_wird_gesucht = true
		view.loesungssuche_anzeigen()


func loesungsergebnis_verarbeiten() -> void:
	loesung_wird_gesucht = false
	var ergebnis_text := model.loesungssuche_ergebnis_abholen()
	view.loesungsinfo_anzeigen(ergebnis_text)
	var loesungsrichtung := model.loesungsrichtung_holen()
	if loesungsrichtung == Vector2i.ZERO:
		view.tipp_button_aktivieren(true)
		return
	spieler_bewegen(loesungsrichtung)


func ansicht_aktualisieren() -> void:
	level_complete = false
	loesung_wird_gesucht = false
	view.spielansicht_aktualisieren(model)
	levelstatus_pruefen()


func spiel_speichern() -> bool:
	return savegame_store.speichern(model.speicherdaten_erstellen())


func spielstand_laden() -> bool:
	var daten: Variant = savegame_store.laden()
	if typeof(daten) != TYPE_DICTIONARY or not model.speicherdaten_laden(daten):
		return false
	ansicht_aktualisieren()
	return true
