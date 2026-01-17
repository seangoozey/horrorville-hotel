# res://scripts/gameplay/Inventory.gd
extends Node

signal item_changed(item_id: String, has_item: bool)

var items := {}  # item_id -> bool

func has(item_id: String) -> bool:
	return items.get(item_id, false)

func give(item_id: String) -> void:
	if items.get(item_id, false):
		return
	items[item_id] = true
	item_changed.emit(item_id, true)

func take(item_id: String) -> void:
	if not items.get(item_id, false):
		return
	items[item_id] = false
	item_changed.emit(item_id, false)
