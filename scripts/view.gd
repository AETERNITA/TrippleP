# view.gd (auf dem TileMapLayer-Node)
extends TileMapLayer

# Zeichnet das gesamte Spielfeld anhand der Daten aus dem Model
func draw_field(model: GameModel):
	clear() # Löscht alte Kacheln
	
	for y in range(model.height):
		for x in range(model.width):
			var cell_type = model.get_cell(x, y)
			
			# Die Source-ID bleibt immer 0 (euer Atlas)
			var source_id = 0 
			
			# Hier wählen wir die Kachel innerhalb des Atlas aus (Spalte, Zeile)
			var atlas_coords = Vector2i(0, 0)
			
			if cell_type == model.WAND:
				atlas_coords = Vector2i(5, 0) # Erste Kachel im Atlas (z.B. Wand)
			elif cell_type == model.BODEN_LEER:
				atlas_coords = Vector2i(0, 2) # Zweite Kachel im Atlas (z.B. leerer Boden)
			elif cell_type == model.BODEN_GEFAERBT:
				atlas_coords = Vector2i(5, 4) # Dritte Kachel im Atlas (z.B. blau gefärbt)
			
			# Vector2i(x, y) ist die Position auf dem Spielfeld
			set_cell(Vector2i(x, y), source_id, atlas_coords)
