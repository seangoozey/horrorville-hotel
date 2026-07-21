# res://autoload/DialogueManager.gd
# Purpose: Load dialogue text and display queued text bubbles on characters.
extends Node

@export var dialogue_path := "res://data/dialogue.json"
@export var bubble_scene: PackedScene = preload("res://scenes/ui/TextBubble.tscn")

var default_duration := 4.0
var default_fade_in_time := 0.2
var default_fade_out_time := 1.0

var _data: Dictionary = {}
var _queue: Array[Dictionary] = []
var _active_bubble: TextBubble = null
var _active_key: String = ""
var _active_target: Node2D = null

func _ready() -> void:
	_load_dialogue()

func get_text(key: String, fallback: String = "") -> String:
	var value: Variant = _get_value(key)
	if typeof(value) == TYPE_STRING:
		return value as String
	return fallback

func reset_runtime_state() -> void:
	_queue.clear()
	if is_instance_valid(_active_bubble):
		_active_bubble.queue_free()
	_active_bubble = null
	_active_key = ""
	_active_target = null

func show_bubble(target: Node2D, key: String, duration: float = -1.0, offset: Vector2 = Vector2(0, 0), allow_duplicate: bool = false, queue_if_active: bool = true) -> void:
	if target == null:
		return
	var resolved_duration: float = default_duration if duration < 0.0 else duration
	if not allow_duplicate:
		if _active_bubble and _active_key == key and _active_target == target:
			return
		for item in _queue:
			if item.get("key", "") == key and item.get("target", null) == target:
				return
	var text: String = get_text(key, key)
	var item: Dictionary = {
		"target": target,
		"key": key,
		"text": text,
		"duration": resolved_duration,
		"offset": offset
	}
	if not queue_if_active:
		_spawn_detached_bubble(item)
		return
	if _active_bubble:
		_queue.append(item)
		return
	_spawn_bubble(item)

func retarget_bubble(key: String, target: Node2D, offset: Vector2 = Vector2.ZERO) -> void:
	if target == null:
		return
	if is_instance_valid(_active_bubble) and _active_key == key:
		_active_target = target
		_active_bubble.set_target(target, offset)
	for item: Dictionary in _queue:
		if str(item.get("key", "")) != key:
			continue
		item["target"] = target
		item["offset"] = offset

func _load_dialogue() -> void:
	if not FileAccess.file_exists(dialogue_path):
		push_error("DialogueManager: missing file %s" % dialogue_path)
		return
	var file := FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: failed to open %s" % dialogue_path)
		return
	var raw := file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueManager: invalid JSON in %s" % dialogue_path)
		return
	_data = parsed as Dictionary

func _get_value(path: String) -> Variant:
	var current: Variant = _data
	for part in path.split("."):
		if typeof(current) != TYPE_DICTIONARY:
			return null
		var dict := current as Dictionary
		if not dict.has(part):
			return null
		current = dict[part]
	return current

func _spawn_bubble(item: Dictionary) -> void:
	var target_value: Variant = item.get("target", null)
	var target_node: Node2D = target_value as Node2D
	if target_node == null:
		_try_spawn_next()
		return
	_active_target = target_node
	_active_key = str(item.get("key", ""))
	var bubble: TextBubble = _create_bubble()
	var scene: Node = get_tree().current_scene
	if scene:
		scene.add_child(bubble)
	_active_bubble = bubble
	bubble.finished.connect(_on_bubble_finished)
	var text_value: String = str(item.get("text", ""))
	var duration_value: float = float(item.get("duration", default_duration))
	var offset_value: Variant = item.get("offset", Vector2(0, -24))
	var offset_vec: Vector2 = offset_value if offset_value is Vector2 else Vector2(0, -24)
	bubble.setup(target_node, text_value, duration_value, offset_vec)

func _spawn_detached_bubble(item: Dictionary) -> void:
	var target_value: Variant = item.get("target", null)
	var target_node: Node2D = target_value as Node2D
	if target_node == null:
		return
	var bubble: TextBubble = _create_bubble()
	var scene: Node = get_tree().current_scene
	if scene:
		scene.add_child(bubble)
	else:
		add_child(bubble)
	var text_value: String = str(item.get("text", ""))
	var duration_value: float = float(item.get("duration", default_duration))
	var offset_value: Variant = item.get("offset", Vector2(0, -24))
	var offset_vec: Vector2 = offset_value if offset_value is Vector2 else Vector2(0, -24)
	bubble.setup(target_node, text_value, duration_value, offset_vec)

func _on_bubble_finished() -> void:
	_active_bubble = null
	_active_key = ""
	_active_target = null
	_try_spawn_next()

func _try_spawn_next() -> void:
	if _queue.is_empty():
		return
	var next_item: Variant = _queue.pop_front()
	if typeof(next_item) == TYPE_DICTIONARY:
		_spawn_bubble(next_item as Dictionary)

func _create_bubble() -> TextBubble:
	var bubble: TextBubble = null
	if bubble_scene != null:
		var instance: Node = bubble_scene.instantiate()
		if instance is TextBubble:
			bubble = instance as TextBubble
		if instance != null:
			if bubble == null:
				instance.queue_free()
	if bubble == null:
		bubble = TextBubble.new()
	bubble.fade_in_time = default_fade_in_time
	bubble.fade_out_time = default_fade_out_time
	return bubble
