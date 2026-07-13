extends Node2D

const KACHEL_GROESSE := 32
const SCHRITT_DAUER := 0.04
const SPEICHERDATEI := "user://savegame.json"
const MAX_LOESUNGSZUEGE := 40
const BOSS_LEVEL_NAME := "BOSS LEVEL"
const BOSS_LEVEL_TIPP_TEXT := "Das ist das BOSS LEVEL - keine Tipps"

var model: GameModel
var is_moving := false
var level_complete := false

@onready var view: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var level_complete_label: Label = $CanvasLayer/LevelCompleteLabel
@onready var start_menu: Control = $CanvasLayer/StartMenu
@onready var level_selection_menu: Control = $CanvasLayer/LevelSelectionMenu
@onready var level_finished_menu: Control = $CanvasLayer/LevelFinishedMenu
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var level_button_container: VBoxContainer = $CanvasLayer/LevelSelectionMenu/MenuPanel/LevelScrollContainer/LevelButtonContainer
@onready var continue_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/NewGameButton
@onready var level_selection_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/LevelSelectionButton
@onready var quit_button: Button = $CanvasLayer/StartMenu/MenuPanel/ButtonContainer/QuitButton
@onready var back_button: Button = $CanvasLayer/LevelSelectionMenu/MenuPanel/BackButton
@onready var next_level_button: Button = $CanvasLayer/LevelFinishedMenu/MenuPanel/ButtonContainer/NextLevelButton
@onready var finished_main_menu_button: Button = $CanvasLayer/LevelFinishedMenu/MenuPanel/ButtonContainer/MainMenuButton
@onready var finished_title_label: Label = $CanvasLayer/LevelFinishedMenu/MenuPanel/TitleLabel
@onready var pause_continue_button: Button = $CanvasLayer/PauseMenu/MenuPanel/ButtonContainer/ContinueButton
@onready var pause_main_menu_button: Button = $CanvasLayer/PauseMenu/MenuPanel/ButtonContainer/MainMenuButton
@onready var solve_hint_button: Button = $CanvasLayer/GameHud/SolveHintButton
@onready var solver_info_label: Label = $CanvasLayer/GameHud/SolverInfoLabel
@onready var player_node: CharacterBody2D = $Player


func _ready() -> void:
	model = GameModel.new()
	model.leveldaten_laden()
	menue_knoepfe_verbinden()
	levelauswahl_bauen()

	if not level_starten(0, false):
		model.testlevel_erstellen()
		model.feld_faerben(model.player_x, model.player_y)
		ansicht_aktualisieren()

	get_viewport().size_changed.connect(kamera_anpassen)
	startmenue_anzeigen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_menu.visible:
			pause_schliessen()
		elif not is_moving and not start_menu.visible and not level_selection_menu.visible and not level_finished_menu.visible:
			pause_anzeigen()
		return

	if is_moving or ist_menue_offen():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Praktisch zum schnellen Testen der ersten drei Level.
		if event.keycode == KEY_1:
			level_starten(0)
		elif event.keycode == KEY_2:
			level_starten(1)
		elif event.keycode == KEY_3:
			level_starten(2)


func _process(_delta: float) -> void:
	if is_moving or level_complete or ist_menue_offen():
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
		spielerposition_anzeigen()

		await get_tree().create_timer(SCHRITT_DAUER).timeout

		if model.feld_faerben(model.player_x, model.player_y):
			view.feld_zeichnen(model, naechstes_feld)
			levelstatus_pruefen()
		naechstes_feld += richtung

	is_moving = false
	model.spielerzug_eintragen(richtung)
	spiel_speichern()
	loesungstext_leeren()


func levelstatus_pruefen() -> void:
	if level_complete or not model.ist_level_geschafft():
		return

	level_complete = true
	var geschafft_text := model.current_level_name + " geschafft!"
	level_complete_label.text = geschafft_text
	finished_title_label.text = geschafft_text
	next_level_button.disabled = model.current_level_index >= model.anzahl_level() - 1
	level_finished_menu.visible = true


func spielerposition_anzeigen() -> void:
	player_node.position = spieler_pixelposition()


func spieler_pixelposition() -> Vector2:
	var raster_position := Vector2(model.player_x, model.player_y)
	return raster_position * KACHEL_GROESSE + Vector2.ONE * (KACHEL_GROESSE / 2.0)


func kamera_anpassen() -> void:
	if model == null or model.width <= 0 or model.height <= 0:
		return

	var feldgroesse := Vector2(model.width, model.height) * KACHEL_GROESSE
	var fenstergroesse := get_viewport_rect().size
	var zoom := minf(fenstergroesse.x / feldgroesse.x, fenstergroesse.y / feldgroesse.y)
	camera.position = feldgroesse / 2.0
	camera.zoom = Vector2.ONE * zoom


func menue_knoepfe_verbinden() -> void:
	continue_button.pressed.connect(spiel_fortsetzen)
	new_game_button.pressed.connect(neues_spiel_starten)
	level_selection_button.pressed.connect(levelauswahl_anzeigen)
	quit_button.pressed.connect(spiel_beenden)
	back_button.pressed.connect(startmenue_anzeigen)
	next_level_button.pressed.connect(naechstes_level_starten)
	finished_main_menu_button.pressed.connect(startmenue_anzeigen)
	pause_continue_button.pressed.connect(pause_schliessen)
	pause_main_menu_button.pressed.connect(startmenue_anzeigen)
	solve_hint_button.pressed.connect(loesungszug_ausfuehren)


func levelauswahl_bauen() -> void:
	for level_nummer in range(model.anzahl_level()):
		var level_button := Button.new()
		var level_daten: Dictionary = model.levels[level_nummer]
		level_button.text = str(
			level_daten.get("name", "Level %d" % (level_nummer + 1))
		)
		level_button.custom_minimum_size = Vector2(260, 44)

		var ausgewaehltes_level := level_nummer
		level_button.pressed.connect(func() -> void: level_auswaehlen(ausgewaehltes_level))
		level_button_container.add_child(level_button)


func startmenue_anzeigen() -> void:
	menues_schliessen()
	start_menu.visible = true


func levelauswahl_anzeigen() -> void:
	menues_schliessen()
	level_selection_menu.visible = true


func pause_anzeigen() -> void:
	pause_menu.visible = true


func pause_schliessen() -> void:
	pause_menu.visible = false


func menues_schliessen() -> void:
	start_menu.visible = false
	level_selection_menu.visible = false
	level_finished_menu.visible = false
	pause_menu.visible = false


func ist_menue_offen() -> bool:
	return start_menu.visible or level_selection_menu.visible or level_finished_menu.visible or pause_menu.visible


func spiel_fortsetzen() -> void:
	menues_schliessen()
	if not spielstand_laden():
		level_starten(0)


func neues_spiel_starten() -> void:
	menues_schliessen()
	level_starten(0)


func spiel_beenden() -> void:
	get_tree().quit()


func level_auswaehlen(level_nummer: int) -> void:
	menues_schliessen()
	level_starten(level_nummer)


func naechstes_level_starten() -> void:
	var naechste_levelnummer := model.current_level_index + 1
	if naechste_levelnummer >= model.anzahl_level():
		startmenue_anzeigen()
		return
	menues_schliessen()
	level_starten(naechste_levelnummer)


func loesungszug_ausfuehren() -> void:
	if is_moving or level_complete or ist_menue_offen():
		return
	if model.current_level_name == BOSS_LEVEL_NAME:
		solver_info_label.text = BOSS_LEVEL_TIPP_TEXT
		solver_info_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		solver_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		solver_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		solver_info_label.add_theme_color_override("font_color", Color.RED)
		solver_info_label.add_theme_color_override("font_outline_color", Color.BLACK)
		solver_info_label.add_theme_font_size_override("font_size", 72)
		solver_info_label.add_theme_constant_override("outline_size", 8)
		solver_info_label.visible = true
		return

	model.naechsten_loesungszug_suchen(MAX_LOESUNGSZUEGE)
	var loesungsrichtung := model.loesungsrichtung_holen()
	loesungstext_leeren()

	if loesungsrichtung == Vector2i.ZERO:
		return

	solve_hint_button.disabled = true
	await spieler_bewegen(loesungsrichtung)
	solve_hint_button.disabled = level_complete


func loesungstext_leeren() -> void:
	solver_info_label.text = ""
	solver_info_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	solver_info_label.offset_left = 16.0
	solver_info_label.offset_top = 118.0
	solver_info_label.offset_right = 360.0
	solver_info_label.offset_bottom = 168.0
	solver_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	solver_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	solver_info_label.remove_theme_color_override("font_color")
	solver_info_label.remove_theme_color_override("font_outline_color")
	solver_info_label.add_theme_font_size_override("font_size", 18)
	solver_info_label.remove_theme_constant_override("outline_size")
	solver_info_label.visible = false


func ansicht_aktualisieren() -> void:
	level_complete = false
	level_complete_label.visible = false
	level_finished_menu.visible = false
	solve_hint_button.disabled = false
	loesungstext_leeren()
	view.spielfeld_zeichnen(model)
	spielerposition_anzeigen()
	kamera_anpassen()
	levelstatus_pruefen()


func spiel_speichern() -> bool:
	var datei := FileAccess.open(SPEICHERDATEI, FileAccess.WRITE)
	if datei == null:
		return false
	datei.store_string(JSON.stringify(model.speicherdaten_erstellen()))
	return true


func spielstand_laden() -> bool:
	if not FileAccess.file_exists(SPEICHERDATEI):
		return false

	var datei := FileAccess.open(SPEICHERDATEI, FileAccess.READ)
	if datei == null:
		return false

	var daten: Variant = JSON.parse_string(datei.get_as_text())
	if typeof(daten) != TYPE_DICTIONARY or not model.speicherdaten_laden(daten):
		return false

	ansicht_aktualisieren()
	return true
