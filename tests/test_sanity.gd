extends GutTest


func test_level_ist_fertig_wenn_alle_felder_gefaerbt_sind() -> void:
	var model := GameModel.new()
	model.width = 3
	model.height = 3
	model.grid = [
		[model.WAND, model.WAND, model.WAND],
		[model.WAND, model.BODEN_GEFAERBT, model.WAND],
		[model.WAND, model.WAND, model.WAND],
	]

	assert_true(model.ist_level_geschafft(), "Ein Level ohne leeren Boden ist geschafft.")


func test_speicherdaten_stellen_den_spielstand_wieder_her() -> void:
	var model := GameModel.new()
	model.current_level_index = 2
	model.current_level_name = "Testlevel"
	model.width = 3
	model.height = 3
	model.player_x = 1
	model.player_y = 1
	model.grid = [
		[model.WAND, model.WAND, model.WAND],
		[model.WAND, model.BODEN_GEFAERBT, model.WAND],
		[model.WAND, model.WAND, model.WAND],
	]

	var geladenes_model := GameModel.new()
	var erfolgreich_geladen := geladenes_model.speicherdaten_laden(model.speicherdaten_erstellen())

	assert_true(erfolgreich_geladen, "Gespeicherte Spieldaten sollen wieder geladen werden können.")
	assert_eq(geladenes_model.current_level_index, 2)
	assert_eq(geladenes_model.current_level_name, "Testlevel")
	assert_eq(geladenes_model.player_x, 1)
	assert_eq(geladenes_model.grid[1][1], model.BODEN_GEFAERBT)


func test_alle_level_sind_innerhalb_des_limits_loesbar() -> void:
	var model := GameModel.new()

	for level_nummer in range(model.anzahl_level()):
		assert_true(model.level_laden(level_nummer), "Das Level soll geladen werden können.")
		model.feld_faerben(model.player_x, model.player_y)
		assert_true(
			model.ist_rekursiv_loesbar(model.loesungssuchlimit_holen()),
			model.current_level_name + " soll innerhalb des berechneten Zuglimits lösbar sein."
		)
