class_name GameView
extends TileMapLayer

signal fortsetzen_gewaehlt
signal neues_spiel_gewaehlt
signal levelauswahl_gewaehlt
signal beenden_gewaehlt
signal zurueck_gewaehlt
signal naechstes_level_gewaehlt
signal hauptmenue_gewaehlt
signal pause_fortsetzen_gewaehlt
signal level_gewaehlt(level_nummer: int)
signal tipp_gewaehlt

const KACHEL_GROESSE := 32
const BODEN_SOURCE_ID := 1
const GEFAERBTER_BODEN_SOURCE_ID := 2
const WAND_SOURCE_ID := 3
const WAND_TILE := Vector2i.ZERO
const BODEN_TILE := Vector2i.ZERO
const GEFAERBTER_BODEN_TILE := Vector2i.ZERO

var _angezeigtes_model: GameModel = null

@onready var camera: Camera2D = $"../Camera2D"
@onready var player_node: CharacterBody2D = $"../Player"
@onready var level_complete_label: Label = $"../CanvasLayer/LevelCompleteLabel"
@onready var start_menu: Control = $"../CanvasLayer/StartMenu"
@onready var level_selection_menu: Control = $"../CanvasLayer/LevelSelectionMenu"
@onready var level_finished_menu: Control = $"../CanvasLayer/LevelFinishedMenu"
@onready var pause_menu: Control = $"../CanvasLayer/PauseMenu"
@onready var level_button_container: VBoxContainer = $"../CanvasLayer/LevelSelectionMenu/MenuPanel/LevelScrollContainer/LevelButtonContainer"
@onready var continue_button: Button = $"../CanvasLayer/StartMenu/MenuPanel/ButtonContainer/ContinueButton"
@onready var new_game_button: Button = $"../CanvasLayer/StartMenu/MenuPanel/ButtonContainer/NewGameButton"
@onready var level_selection_button: Button = $"../CanvasLayer/StartMenu/MenuPanel/ButtonContainer/LevelSelectionButton"
@onready var quit_button: Button = $"../CanvasLayer/StartMenu/MenuPanel/ButtonContainer/QuitButton"
@onready var back_button: Button = $"../CanvasLayer/LevelSelectionMenu/MenuPanel/BackButton"
@onready var next_level_button: Button = $"../CanvasLayer/LevelFinishedMenu/MenuPanel/ButtonContainer/NextLevelButton"
@onready var finished_main_menu_button: Button = $"../CanvasLayer/LevelFinishedMenu/MenuPanel/ButtonContainer/MainMenuButton"
@onready var finished_title_label: Label = $"../CanvasLayer/LevelFinishedMenu/MenuPanel/TitleLabel"
@onready var pause_continue_button: Button = $"../CanvasLayer/PauseMenu/MenuPanel/ButtonContainer/ContinueButton"
@onready var pause_main_menu_button: Button = $"../CanvasLayer/PauseMenu/MenuPanel/ButtonContainer/MainMenuButton"
@onready var solve_hint_button: Button = $"../CanvasLayer/GameHud/SolveHintButton"
@onready var solver_info_label: Label = $"../CanvasLayer/GameHud/SolverInfoLabel"


func _ready() -> void:
	continue_button.pressed.connect(fortsetzen_gewaehlt.emit)
	new_game_button.pressed.connect(neues_spiel_gewaehlt.emit)
	level_selection_button.pressed.connect(levelauswahl_gewaehlt.emit)
	quit_button.pressed.connect(beenden_gewaehlt.emit)
	back_button.pressed.connect(zurueck_gewaehlt.emit)
	next_level_button.pressed.connect(naechstes_level_gewaehlt.emit)
	finished_main_menu_button.pressed.connect(hauptmenue_gewaehlt.emit)
	pause_continue_button.pressed.connect(pause_fortsetzen_gewaehlt.emit)
	pause_main_menu_button.pressed.connect(hauptmenue_gewaehlt.emit)
	solve_hint_button.pressed.connect(tipp_gewaehlt.emit)
	get_viewport().size_changed.connect(_kamera_anpassen)


func levelauswahl_bauen(levelnamen: Array[String]) -> void:
	for level_nummer in range(levelnamen.size()):
		var level_button := Button.new()
		level_button.text = levelnamen[level_nummer]
		level_button.custom_minimum_size = Vector2(260, 44)
		var ausgewaehltes_level := level_nummer
		level_button.pressed.connect(
			func() -> void: level_gewaehlt.emit(ausgewaehltes_level)
		)
		level_button_container.add_child(level_button)


func spielansicht_aktualisieren(model: GameModel) -> void:
	_angezeigtes_model = model
	level_complete_label.visible = false
	level_finished_menu.visible = false
	solve_hint_button.disabled = false
	loesungstext_leeren()
	spielfeld_zeichnen(model)
	spielerposition_anzeigen(model)
	_kamera_anpassen()


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


func spielerposition_anzeigen(model: GameModel) -> void:
	var raster_position := Vector2(model.player_x, model.player_y)
	player_node.position = raster_position * KACHEL_GROESSE + Vector2.ONE * (KACHEL_GROESSE / 2.0)


func level_geschafft_anzeigen(geschafft_text: String, hat_naechstes_level: bool) -> void:
	level_complete_label.text = geschafft_text
	finished_title_label.text = geschafft_text
	next_level_button.disabled = not hat_naechstes_level
	level_finished_menu.visible = true


func loesungssuche_anzeigen() -> void:
	solve_hint_button.disabled = true
	solver_info_label.text = "Lösung wird im Hintergrund gesucht ..."
	solver_info_label.visible = true


func loesungsinfo_anzeigen(text: String) -> void:
	solver_info_label.text = text
	solver_info_label.visible = true


func loesungstext_leeren() -> void:
	solver_info_label.text = ""
	solver_info_label.visible = false


func tipp_button_aktivieren(aktiv: bool) -> void:
	solve_hint_button.disabled = not aktiv


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


func ist_pause_sichtbar() -> bool:
	return pause_menu.visible


func ist_menue_offen() -> bool:
	return start_menu.visible or level_selection_menu.visible or level_finished_menu.visible or pause_menu.visible


func _kamera_anpassen() -> void:
	if _angezeigtes_model == null or _angezeigtes_model.width <= 0 or _angezeigtes_model.height <= 0:
		return
	var feldgroesse := Vector2(_angezeigtes_model.width, _angezeigtes_model.height) * KACHEL_GROESSE
	var fenstergroesse := get_viewport_rect().size
	var zoom := minf(fenstergroesse.x / feldgroesse.x, fenstergroesse.y / feldgroesse.y)
	camera.position = feldgroesse / 2.0
	camera.zoom = Vector2.ONE * zoom
