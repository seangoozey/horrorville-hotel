# res://autoload/NotesManager.gd
# Purpose: Load notes catalog and track collected notes with cached journal text.
extends Node

signal note_added(note_id: String)

@export var notes_path: String = "res://data/notes.json"

var _notes: Dictionary = {}
var _order: Array[String] = []
var _catalog: Dictionary = {}
var _cached_text: String = "No notes yet."

func _ready() -> void:
	_load_notes_catalog()

func add_note(note_id: String, title: String, description: String) -> bool:
	if _notes.has(note_id):
		return false
	_notes[note_id] = {
		"title": title,
		"description": description
	}
	_order.append(note_id)
	_rebuild_cache()
	note_added.emit(note_id)
	return true

func add_note_by_id(note_id: String) -> bool:
	if _notes.has(note_id):
		return false
	var entry: Variant = _catalog.get(note_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var data := entry as Dictionary
	var title: String = str(data.get("title", ""))
	var description: String = str(data.get("description", ""))
	return add_note(note_id, title, description)

func add_all_catalog_notes() -> int:
	var added_count := 0
	for note_id_variant in _catalog.keys():
		var note_id: String = str(note_id_variant)
		if add_note_by_id(note_id):
			added_count += 1
	return added_count

func get_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note_id in _order:
		var entry: Variant = _notes.get(note_id, null)
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry as Dictionary)
	return result

func get_note(note_id: String) -> Dictionary:
	var entry: Variant = _notes.get(note_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return entry as Dictionary

func get_notes_text() -> String:
	return _cached_text

func reset_runtime_state() -> void:
	_notes.clear()
	_order.clear()
	_rebuild_cache()

func _load_notes_catalog() -> void:
	if not FileAccess.file_exists(notes_path):
		push_error("NotesManager: missing file %s" % notes_path)
		return
	var file := FileAccess.open(notes_path, FileAccess.READ)
	if file == null:
		push_error("NotesManager: failed to open %s" % notes_path)
		return
	var raw := file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("NotesManager: invalid JSON in %s" % notes_path)
		return
	_catalog = parsed as Dictionary

func _rebuild_cache() -> void:
	if _order.is_empty():
		_cached_text = "No notes yet."
		return
	var parts: Array[String] = []
	for note_id in _order:
		var entry: Variant = _notes.get(note_id, null)
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var note := entry as Dictionary
		var title: String = str(note.get("title", ""))
		var desc: String = str(note.get("description", ""))
		if title != "":
			parts.append(title)
		if desc != "":
			parts.append(desc)
		parts.append("")
	_cached_text = "\n".join(parts).strip_edges()
