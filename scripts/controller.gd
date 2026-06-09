# controller.gd
extends Node2D

var model: GameModel
@onready var view: TileMapLayer = $TileMapLayer # Pfad zu eurer View anpassen

func _ready():
	# 1. Model erstellen und Level generieren
	model = GameModel.new()
	model.setup_test_level()
	
	# 2. View anweisen, das Spielfeld zu zeichnen
	view.draw_field(model)
