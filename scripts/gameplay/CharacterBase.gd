# res://scripts/gameplay/CharacterBase.gd
extends CharacterBody2D
class_name CharacterBase

signal location_changed()
signal health_changed(new_health: int)
signal damaged(amount: int)
signal died()
signal death_sequence_completed()
signal special_action_started(action_id: String, duration: float, is_effective: bool)
signal special_action_progress(action_id: String, progress: float)
signal special_action_completed(action_id: String, was_effective: bool)
signal special_action_canceled(action_id: String)

@export var speed := 350.0
@export var current_location: LayerController.ViewLayer = LayerController.ViewLayer.EXTERIOR
@export var max_health := 5
@export var health := 5
@export var special_action_id: String = ""
@export var special_action_label: String = ""
@export var special_action_duration: float = 3.0
@export var special_action_fail_duration: float = 1.0
@export var dialogue_anchor_path: NodePath = NodePath("DialogueAnchor")

var _special_action_active: bool = false
var _special_action_elapsed: float = 0.0
var _special_action_effective: bool = false
var _elevation_sources: Dictionary = {}
var _elevation_visual_bases: Dictionary = {}
var _elevation_offset_y := 0.0

func _ready() -> void:
	health = int(clamp(health, 0, max_health))
	_cache_elevation_visuals()
	_apply_elevation_visual_offset()

func _process(delta: float) -> void:
	if not _special_action_active:
		return
	_special_action_elapsed += delta
	var progress: float = 0.0
	var total: float = special_action_duration if _special_action_effective else special_action_fail_duration
	if total > 0.0:
		progress = clamp(_special_action_elapsed / total, 0.0, 1.0)
	special_action_progress.emit(special_action_id, progress)
	if _special_action_elapsed >= total:
		_special_action_active = false
		special_action_completed.emit(special_action_id, _special_action_effective)

func _set_location(layer: LayerController.ViewLayer) -> void:
	if current_location == layer:
		return
	current_location = layer
	location_changed.emit()

func _take_damage(damage: int) -> void:
	take_damage(damage)

func take_damage(damage: int) -> void:
	if damage <= 0:
		return
	var previous_health: int = health
	set_health(health - damage)
	var applied_damage: int = previous_health - health
	if applied_damage > 0 and health > 0:
		damaged.emit(applied_damage)

func set_health(value: int) -> void:
	var clamped: int = int(clamp(value, 0, max_health))
	if clamped == health:
		return
	var was_alive := health > 0
	health = clamped
	health_changed.emit(health)
	if was_alive and health == 0:
		died.emit()

func complete_death_sequence() -> void:
	death_sequence_completed.emit()

func say(text_id: String, duration: float = -1.0, offset: Vector2 = Vector2(0, 0)) -> void:
	DialogueManager.show_bubble(get_dialogue_anchor(), text_id, duration, offset)

func get_dialogue_anchor() -> Node2D:
	var anchor: Node2D = get_node_or_null(dialogue_anchor_path) as Node2D
	if anchor != null:
		return anchor
	return self

func start_special_action(is_effective: bool = false) -> void:
	if _special_action_active or special_action_id == "":
		return
	_special_action_active = true
	_special_action_elapsed = 0.0
	_special_action_effective = is_effective
	var duration: float = special_action_duration if is_effective else special_action_fail_duration
	special_action_started.emit(special_action_id, duration, is_effective)

func is_special_action_active() -> bool:
	return _special_action_active

func cancel_special_action() -> void:
	if not _special_action_active:
		return
	_special_action_active = false
	special_action_canceled.emit(special_action_id)

func _set_elevation_offset_source(source: Object, offset_y: float) -> void:
	if source == null:
		return
	_elevation_sources[source.get_instance_id()] = max(offset_y, 0.0)
	_refresh_elevation_offset()

func _clear_elevation_offset_source(source: Object) -> void:
	if source == null:
		return
	_elevation_sources.erase(source.get_instance_id())
	_refresh_elevation_offset()

func _refresh_elevation_offset() -> void:
	var next_offset := 0.0
	for value in _elevation_sources.values():
		next_offset += float(value)
	if is_equal_approx(next_offset, _elevation_offset_y):
		return
	_elevation_offset_y = next_offset
	_apply_elevation_visual_offset()

func _cache_elevation_visuals() -> void:
	_elevation_visual_bases.clear()
	for child in get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is CollisionPolygon2D:
			continue
		if child is Node2D:
			_elevation_visual_bases[child] = (child as Node2D).position
		elif child is Control:
			_elevation_visual_bases[child] = (child as Control).position

func _apply_elevation_visual_offset() -> void:
	for child in _elevation_visual_bases.keys():
		if not is_instance_valid(child):
			continue
		var base_position: Variant = _elevation_visual_bases[child]
		if not (base_position is Vector2):
			continue
		var adjusted := base_position as Vector2
		adjusted.y -= _elevation_offset_y
		if child is Node2D:
			(child as Node2D).position = adjusted
		elif child is Control:
			(child as Control).position = adjusted

func move_without_pushing(delta: float) -> void:
	var motion := velocity * delta
	if motion.length_squared() <= 0.0001:
		return

	var collision := move_and_collide(motion)
	if collision == null:
		return

	var slide_motion := collision.get_remainder().slide(collision.get_normal())
	if slide_motion.length_squared() <= 0.0001:
		return
	move_and_collide(slide_motion)
