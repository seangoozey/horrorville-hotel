# res://scripts/gameplay/TopDownController.gd
extends CharacterBase

@export var character_id: String = ""  # set to "journalist" or "gsa" in Inspector
@export var special_action_cancel_grace := 0.12
@export var sprite_path: NodePath
@export var character_audio_path: NodePath = NodePath("CharacterAudio")
@export var facing: Facing = Facing.DOWN
@export var isometric_axis_angle_degrees := 40.9
@export var movement_speed_scale := 0.7
@export var movement_cardinal_snap_ratio := 0.65
@export var corpse_perimeter_path: NodePath = NodePath("CorpsePerimeter")
@export var corpse_slime_clearance := 18.0
@export var corpse_slime_push_step := 12.0

enum Facing { DOWN, UP, LEFT, RIGHT }

@onready var _sprite: AnimatedSprite2D = _resolve_sprite()
@onready var _character_audio: CharacterAudio = _resolve_character_audio()
@onready var _corpse_perimeter: Polygon2D = get_node_or_null(corpse_perimeter_path) as Polygon2D

var _cancel_grace_timer := 0.0
var _is_dead := false
var _special_audio_playback_id: int = 0
var _corpse_expansion_active := false
var _corpse_perimeter_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	super._ready()
	if _corpse_perimeter != null:
		_corpse_perimeter_base_scale = _corpse_perimeter.scale
		_corpse_perimeter.visible = false
	special_action_started.connect(_on_special_action_started)
	died.connect(_on_died)
	GameState.active_character_changed.connect(_on_active_character_changed)

func _physics_process(_delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		_set_walking_audio(false, "dead")
		_update_corpse_expansion()
		return
	# If not the active character, do nothing
	if character_id != "" and GameState.active_character_id != character_id:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		_set_walking_audio(false, "inactive_character")
		return
	if GameState.is_journal_open:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		_set_walking_audio(false, "journal_open")
		return

	var dir := _get_movement_input()
	var movement_dir := _map_input_to_isometric(dir)
	if is_special_action_active():
		_cancel_grace_timer = max(_cancel_grace_timer - _delta, 0.0)
		velocity = Vector2.ZERO
		_update_special_action_animation()
		_set_walking_audio(false, "special_action_active")
		return
	velocity = movement_dir * speed * movement_speed_scale
	_update_animation(dir)
	_set_walking_audio(dir != Vector2.ZERO, "movement_input")
	move_without_pushing(_delta)

func _get_movement_input() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var abs_x: float = absf(dir.x)
	var abs_y: float = absf(dir.y)
	var stronger_axis: float = maxf(abs_x, abs_y)
	var weaker_axis: float = minf(abs_x, abs_y)
	if stronger_axis > 0.0 and weaker_axis / stronger_axis <= movement_cardinal_snap_ratio:
		if abs_x > abs_y:
			dir.y = 0.0
		else:
			dir.x = 0.0
	return dir.normalized() if dir.length() > 1.0 else dir

func _on_special_action_started(_action_id: String, _duration: float, is_effective: bool) -> void:
	_cancel_grace_timer = special_action_cancel_grace
	if _character_audio == null:
		return
	_special_audio_playback_id += 1
	var playback_id: int = _special_audio_playback_id
	_character_audio.play_sound(&"SpecialActionAudio")
	if is_effective:
		return
	var failed_audio_timer: SceneTreeTimer = get_tree().create_timer(1.0)
	await failed_audio_timer.timeout
	if playback_id == _special_audio_playback_id:
		_character_audio.stop_sound(&"SpecialActionAudio")

func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	if is_special_action_active():
		cancel_special_action()
	_set_walking_audio(false, "death")
	if _character_audio != null:
		_character_audio.play_sound(&"DeathAudio", true, true)
	if _sprite != null:
		_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		var death_animation: String = _facing_to_death_animation(facing)
		if _has_animation(death_animation):
			_begin_corpse_expansion()
			_sprite.play(death_animation)
			await _sprite.animation_finished
			_finish_corpse_expansion()
		else:
			push_warning("%s is missing death animation '%s'." % [name, death_animation])
	var menu_delay: SceneTreeTimer = get_tree().create_timer(2.0)
	await menu_delay.timeout
	complete_death_sequence()

func _begin_corpse_expansion() -> void:
	if _corpse_perimeter == null:
		return
	_corpse_perimeter.rotation_degrees = _facing_to_corpse_rotation(facing)
	_corpse_perimeter.scale = Vector2.ZERO
	_corpse_expansion_active = true

func _finish_corpse_expansion() -> void:
	if _corpse_perimeter == null:
		return
	_corpse_perimeter.scale = _corpse_perimeter_base_scale
	_corpse_expansion_active = false
	_separate_slime_from_corpse()

func _update_corpse_expansion() -> void:
	if not _corpse_expansion_active or _corpse_perimeter == null or _sprite == null:
		return
	var frame_count: int = _sprite.sprite_frames.get_frame_count(_sprite.animation)
	var progress: float = 1.0
	if frame_count > 1:
		progress = clamp((float(_sprite.frame) + _sprite.frame_progress) / float(frame_count - 1), 0.0, 1.0)
	_corpse_perimeter.scale = _corpse_perimeter_base_scale * progress
	_separate_slime_from_corpse()

func _separate_slime_from_corpse() -> void:
	if _corpse_perimeter == null or _corpse_perimeter.polygon.size() < 3:
		return
	var slime: SlimeBody = get_tree().get_first_node_in_group(&"death_occluder") as SlimeBody
	if slime == null or slime.is_dead():
		return
	var global_polygon: PackedVector2Array = _get_corpse_global_polygon()
	if global_polygon.size() < 3:
		return
	var slime_position: Vector2 = slime.global_position
	var closest_point: Vector2 = _closest_point_on_polygon(slime_position, global_polygon)
	var center: Vector2 = _get_polygon_center(global_polygon)
	var separation_direction: Vector2 = slime_position - center
	if separation_direction.length_squared() <= 0.0001:
		separation_direction = closest_point - center
	if separation_direction.length_squared() <= 0.0001:
		separation_direction = Vector2.DOWN
	separation_direction = separation_direction.normalized()
	var inside: bool = Geometry2D.is_point_in_polygon(slime_position, global_polygon)
	var boundary_distance: float = slime_position.distance_to(closest_point)
	if not inside and boundary_distance >= corpse_slime_clearance:
		return
	var required_distance: float = boundary_distance + corpse_slime_clearance if inside else corpse_slime_clearance - boundary_distance
	var push_distance: float = min(max(required_distance, 0.0), max(corpse_slime_push_step, 0.0))
	var push_motion: Vector2 = separation_direction * push_distance
	if push_motion.length_squared() <= 0.0001:
		return
	var safe_fraction: float = 1.0
	if slime.test_move(slime.global_transform, push_motion):
		safe_fraction = _find_safe_slime_push_fraction(slime, push_motion)
	if safe_fraction > 0.0:
		slime.global_position += push_motion * safe_fraction

func _find_safe_slime_push_fraction(slime: SlimeBody, motion: Vector2) -> float:
	var low: float = 0.0
	var high: float = 1.0
	for _iteration in range(6):
		var midpoint: float = (low + high) * 0.5
		if slime.test_move(slime.global_transform, motion * midpoint):
			high = midpoint
		else:
			low = midpoint
	return low

func _get_corpse_global_polygon() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if _corpse_perimeter == null:
		return result
	result.resize(_corpse_perimeter.polygon.size())
	for index in range(_corpse_perimeter.polygon.size()):
		result[index] = _corpse_perimeter.global_transform * _corpse_perimeter.polygon[index]
	return result

func _get_polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(maxi(polygon.size(), 1))

func _closest_point_on_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var closest: Vector2 = polygon[0]
	var closest_distance_sq: float = point.distance_squared_to(closest)
	for index in range(polygon.size()):
		var segment_start: Vector2 = polygon[index]
		var segment_end: Vector2 = polygon[(index + 1) % polygon.size()]
		var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		var distance_sq: float = point.distance_squared_to(candidate)
		if distance_sq < closest_distance_sq:
			closest = candidate
			closest_distance_sq = distance_sq
	return closest

func _facing_to_corpse_rotation(value: Facing) -> float:
	match value:
		Facing.LEFT:
			return 84.0
		Facing.UP:
			return 180.0
		Facing.RIGHT:
			return 262.0
		_:
			return 0.0

func cancel_special_action() -> void:
	if not is_special_action_active():
		return
	super.cancel_special_action()
	_special_audio_playback_id += 1
	if _character_audio != null:
		_character_audio.stop_sound(&"SpecialActionAudio")

func _map_input_to_isometric(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var angle := deg_to_rad(isometric_axis_angle_degrees)
	var axis_x := cos(angle)
	var axis_y := sin(angle)
	var mapped := Vector2(
		axis_x * (dir.x - dir.y),
		axis_y * (dir.x + dir.y)
	)
	return mapped.normalized() * dir.length()

func _resolve_sprite() -> AnimatedSprite2D:
	if sprite_path != NodePath(""):
		var node := get_node_or_null(sprite_path)
		if node is AnimatedSprite2D:
			return node
	var fallback := get_node_or_null("AnimatedSprite2D")
	if fallback is AnimatedSprite2D:
		return fallback
	return null

func _resolve_character_audio() -> CharacterAudio:
	if character_audio_path != NodePath(""):
		var node := get_node_or_null(character_audio_path)
		if node is CharacterAudio:
			return node as CharacterAudio
	var fallback := get_node_or_null("CharacterAudio")
	if fallback is CharacterAudio:
		return fallback as CharacterAudio
	return null

func _on_active_character_changed(active_id: String) -> void:
	if character_id != "" and active_id != character_id:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		_set_walking_audio(false, "active_character_changed")

func _set_walking_audio(is_walking: bool, reason: String) -> void:
	if _character_audio == null:
		return
	_character_audio.set_walking(is_walking, reason)

func _update_animation(dir: Vector2) -> void:
	if _sprite == null:
		return
	if dir == Vector2.ZERO:
		var idle_anim := _facing_to_idle_animation(facing)
		if _sprite.animation != idle_anim or not _sprite.is_playing():
			_sprite.play(idle_anim)
		return
	var anim := _dir_to_walk_animation(dir)
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)

func _resolve_facing(dir: Vector2) -> Facing:
	if abs(dir.x) > abs(dir.y):
		facing = Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
	else:
		facing = Facing.DOWN if dir.y > 0.0 else Facing.UP
	return facing

func _facing_to_animation(value: Facing) -> String:
	match value:
		Facing.UP:
			return "up_walk"
		Facing.LEFT:
			return "left_walk"
		Facing.RIGHT:
			return "right_walk"
		_:
			return "down_walk"

func _facing_to_idle_animation(value: Facing) -> String:
	match value:
		Facing.UP:
			return "up_idle"
		Facing.LEFT:
			return "left_idle"
		Facing.RIGHT:
			return "right_idle"
		_:
			return "down_idle"

func _facing_to_examine_animation(value: Facing) -> String:
	match value:
		Facing.UP:
			return "up_examine"
		Facing.LEFT:
			return "left_examine"
		Facing.RIGHT:
			return "right_examine"
		_:
			return "down_examine"

func _facing_to_repair_animation(value: Facing) -> String:
	match value:
		Facing.UP:
			return "up_repair"
		Facing.LEFT:
			return "left_repair"
		Facing.RIGHT:
			return "right_repair"
		_:
			return "down_repair"

func _facing_to_death_animation(value: Facing) -> String:
	match value:
		Facing.UP:
			return "up_death"
		Facing.LEFT:
			return "left_death"
		Facing.RIGHT:
			return "right_death"
		_:
			return "down_death"

func _update_special_action_animation() -> void:
	if _sprite == null:
		return
	var anim := _get_special_action_animation()
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)

func _get_special_action_animation() -> String:
	var preferred_anim := ""
	match special_action_id:
		"fix":
			preferred_anim = _facing_to_repair_animation(facing)
		"examine":
			preferred_anim = _facing_to_examine_animation(facing)
		_:
			preferred_anim = _facing_to_idle_animation(facing)
	if _has_animation(preferred_anim):
		return preferred_anim
	var down_action_anim := ""
	match special_action_id:
		"fix":
			down_action_anim = "down_repair"
		"examine":
			down_action_anim = "down_examine"
	if down_action_anim != "" and _has_animation(down_action_anim):
		return down_action_anim
	return _facing_to_idle_animation(facing)

func _has_animation(anim: String) -> bool:
	return _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim)

func _dir_to_walk_animation(dir: Vector2) -> String:
	_resolve_facing(dir)
	if dir.x != 0.0 and dir.y != 0.0:
		if dir.y < 0.0:
			return "up_left_walk" if dir.x < 0.0 else "up_right_walk"
		return "down_left_walk" if dir.x < 0.0 else "down_right_walk"
	return _facing_to_animation(facing)
