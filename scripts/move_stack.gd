class_name MoveStack
extends RefCounted

var _items: Array[String] = []


func push(move: String) -> void:
	_items.append(move)


func pop() -> Variant:
	return null if _items.is_empty() else _items.pop_back()


func is_empty() -> bool:
	return _items.is_empty()


func size() -> int:
	return _items.size()
