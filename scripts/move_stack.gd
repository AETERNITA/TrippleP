class_name MoveStack
extends RefCounted


# Ein eigenes verkettetes Stack-Element. Dadurch haengt die Datenstruktur
# nicht mehr von den Stack-Operationen eines Arrays ab.
class StackElement extends RefCounted:
	var zug: Vector2i
	var darunter: StackElement

	func _init(neuer_zug: Vector2i, vorheriges_element: StackElement) -> void:
		zug = neuer_zug
		darunter = vorheriges_element


var _oberstes_element: StackElement = null
var _anzahl_elemente := 0


func zug_ablegen(zug: Vector2i) -> void:
	_oberstes_element = StackElement.new(zug, _oberstes_element)
	_anzahl_elemente += 1


func zug_nehmen() -> Variant:
	if _oberstes_element == null:
		return null

	var zug := _oberstes_element.zug
	_oberstes_element = _oberstes_element.darunter
	_anzahl_elemente -= 1
	return zug


func obersten_zug_ansehen() -> Variant:
	if _oberstes_element == null:
		return null
	return _oberstes_element.zug


func ist_leer() -> bool:
	return _oberstes_element == null


func anzahl() -> int:
	return _anzahl_elemente


func leeren() -> void:
	_oberstes_element = null
	_anzahl_elemente = 0
