class_name MoveStack
extends RefCounted

var _items: Array[String] = []


func zug_ablegen(zug: String) -> void:
	_items.append(zug)


func zug_nehmen() -> Variant:
	if _items.is_empty():
		return null
	return _items.pop_back()


func ist_leer() -> bool:
	return _items.is_empty()


func anzahl() -> int:
	return _items.size()
