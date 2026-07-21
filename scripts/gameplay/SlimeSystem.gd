# res://scripts/gameplay/SlimeSystem.gd
extends Node2D

signal active_damage_proximity(in_range: bool)
signal active_damage_taken(amount: int)

enum MotionState { CREEP_WAIT, CREEP_MOVE, FOLLOW, CHASE }

@export var slime_blob: SlimeBody
@export var pump_anchor: Node2D
@export var journalist: Node2D
@export var gsa: Node2D
@export var metal_post_electrocution: CollisionPolygon2D
@export var slime_area_wander: Area2D
@export var trap_target: Marker2D
@export var trap_zone_collision: CollisionPolygon2D
@export_file("*.tscn") var outro_video_scene_path: String = "res://scenes/ui/OutroVideo.tscn"

@export var speed := 22.0
@export var wander_move_speed := 15.0
@export var follow_move_speed := 18.0
@export var lure_radius := 1300.0
@export var wander_radius := 100.0
@export var creep_move_duration_min := 0.8
@export var creep_move_duration_max := 1.25
@export var creep_wait_duration_min := 0.35
@export var creep_wait_duration_max := 0.9
@export var damage_per_second := 1.0
@export var damage_range_grid_on := 240.0
@export var damage_range_power_off := 150.0
@export var movement_stop_distance := 2.0
@export var trap_target_kill_distance := 8.0
@export var isometric_axis_angle_degrees := 40.9
@export var pursuit_direction_switch_margin := 0.12
@export var stuck_detection_duration := 0.3
@export var stuck_minimum_displacement := 2.0
@export_range(0.05, 1.0, 0.05) var stuck_minimum_progress_ratio := 0.8
@export_range(0.0, 2.0, 0.05) var stuck_lateral_drift_penalty := 0.75
@export var stuck_test_distance := 120.0
@export_range(0.0, 1.0, 0.05) var stuck_minimum_clear_fraction := 0.65
@export var stuck_waypoint_distance := 100.0
@export var stuck_waypoint_arrival_distance := 8.0
@export var stuck_waypoint_timeout := 6.0

var _mode: int = GameState.PowerMode.GRID_ON
var _damage_timers: Dictionary = {}
var _damage_in_range: Dictionary = {}
var _active_in_range: bool = false
var _motion_state: MotionState = MotionState.CREEP_WAIT
var _state_time_remaining: float = 0.0
var _creep_anchor_point: Vector2 = Vector2.ZERO
var _creep_input_direction: Vector2 = Vector2.ZERO
var _pursuit_target: Node2D = null
var _pursuit_input_direction: Vector2 = Vector2.ZERO
var _pending_move_start_direction: Vector2 = Vector2.ZERO
var _isometric_axis_x: float = 1.0
var _isometric_axis_y: float = 1.0
var _cached_wander_polys: Array[PackedVector2Array] = []
var _cached_metal_post_poly: PackedVector2Array = PackedVector2Array()
var _cached_trap_zone_poly: PackedVector2Array = PackedVector2Array()
var _slime_death_started := false
var _character_death_started := false
var _stuck_sample_position: Vector2 = Vector2.ZERO
var _stuck_sample_direction: Vector2 = Vector2.ZERO
var _stuck_elapsed: float = 0.0
var _stuck_expected_distance: float = 0.0
var _detour_waypoint: Vector2 = Vector2.ZERO
var _detour_waypoint_active: bool = false
var _detour_waypoint_elapsed: float = 0.0

func _ready() -> void:
	_refresh_isometric_axes()
	_cache_static_polygons()
	GameState.power_mode_changed.connect(_on_power_mode_changed)
	_connect_character_death_signal(journalist)
	_connect_character_death_signal(gsa)
	_on_power_mode_changed(GameState.power_mode)
	if slime_blob:
		slime_blob.visible = true
		_creep_anchor_point = _get_default_creep_anchor()
		_stuck_sample_position = slime_blob.global_position
	_enter_creep_wait(_get_default_creep_anchor())

func _physics_process(delta: float) -> void:
	if GameState.get_flag("slime_dead"):
		if slime_blob:
			slime_blob.velocity = Vector2.ZERO
		_set_active_in_range(false)
		return
	if _character_death_started:
		if slime_blob:
			slime_blob.velocity = Vector2.ZERO
		_set_active_in_range(false)
		return

	_apply_slime_damage(delta)
	if slime_blob == null:
		_check_metal_post_electrocution()
		return

	if _should_attract_to_trap_target():
		_update_trap_target_motion()
	else:
		var pursuit_target: Node2D = _resolve_pursuit_target()
		if pursuit_target != null:
			var pursuit_state: MotionState = _resolve_pursuit_state()
			_update_pursuit_motion(pursuit_state, pursuit_target)
		else:
			_update_creep_motion(delta)

	slime_blob.move_without_pushing(delta)
	_update_stuck_recovery(delta)
	_check_metal_post_electrocution()

func _connect_character_death_signal(character_node: Node2D) -> void:
	var character: CharacterBase = character_node as CharacterBase
	if character == null:
		return
	if not character.died.is_connected(_on_character_died):
		character.died.connect(_on_character_died)

func _on_character_died() -> void:
	if _character_death_started:
		return
	_character_death_started = true
	_set_active_in_range(false)
	_damage_timers.clear()
	_damage_in_range.clear()
	_motion_state = MotionState.CREEP_WAIT
	_pursuit_target = null
	_creep_input_direction = Vector2.ZERO
	_pursuit_input_direction = Vector2.ZERO
	_pending_move_start_direction = Vector2.ZERO
	if slime_blob != null:
		slime_blob.velocity = Vector2.ZERO
		slime_blob.clear_engaged_direction()

func _update_pursuit_motion(pursuit_state: MotionState, pursuit_target: Node2D) -> void:
	if slime_blob == null or pursuit_target == null:
		return

	var entering_new_pursuit: bool = _motion_state != pursuit_state or _pursuit_target != pursuit_target
	if entering_new_pursuit:
		_enter_pursuit_state(pursuit_state, pursuit_target)

	var face_direction: Vector2 = pursuit_target.global_position - slime_blob.global_position
	slime_blob.set_engaged_direction(face_direction)
	if slime_blob.is_raise_locked():
		slime_blob.velocity = Vector2.ZERO
		return

	var desired_input_direction: Vector2 = _choose_pursuit_input_direction(face_direction)
	if _detour_waypoint_active:
		desired_input_direction = _get_detour_waypoint_direction()
	var movement_stop_distance_sq: float = movement_stop_distance * movement_stop_distance
	if desired_input_direction == Vector2.ZERO or face_direction.length_squared() <= movement_stop_distance_sq:
		_pursuit_input_direction = Vector2.ZERO
		slime_blob.velocity = Vector2.ZERO
		slime_blob.update_engaged_animation(Vector2.ZERO)
		return

	var move_speed: float = follow_move_speed if pursuit_state == MotionState.FOLLOW else speed
	slime_blob.velocity = _map_input_to_isometric(desired_input_direction) * move_speed
	slime_blob.update_engaged_animation(desired_input_direction)
	_emit_pending_move_start_if_needed(desired_input_direction)

func _update_trap_target_motion() -> void:
	if slime_blob == null or trap_target == null:
		return
	var entering_trap_pull: bool = _motion_state != MotionState.CHASE or _pursuit_target != trap_target
	if entering_trap_pull:
		_enter_pursuit_state(MotionState.CHASE, trap_target)

	var target_direction: Vector2 = trap_target.global_position - slime_blob.global_position
	var kill_distance_sq: float = trap_target_kill_distance * trap_target_kill_distance
	if target_direction.length_squared() <= kill_distance_sq:
		slime_blob.global_position = trap_target.global_position
		_kill_slime_from_trap()
		return

	slime_blob.set_engaged_direction(target_direction)
	if slime_blob.is_raise_locked():
		slime_blob.velocity = Vector2.ZERO
		return

	var desired_input_direction: Vector2 = _choose_pursuit_input_direction(target_direction)
	if _detour_waypoint_active:
		desired_input_direction = _get_detour_waypoint_direction()
	if desired_input_direction == Vector2.ZERO:
		slime_blob.velocity = Vector2.ZERO
		slime_blob.update_engaged_animation(Vector2.ZERO)
		return

	slime_blob.velocity = _map_input_to_isometric(desired_input_direction) * speed
	slime_blob.update_engaged_animation(desired_input_direction)
	_emit_pending_move_start_if_needed(desired_input_direction)

func _update_creep_motion(delta: float) -> void:
	if slime_blob == null:
		return
	if _is_pursuit_state(_motion_state):
		_exit_pursuit_state()

	var creep_anchor: Vector2 = _get_default_creep_anchor()
	if _motion_state != MotionState.CREEP_WAIT and _motion_state != MotionState.CREEP_MOVE:
		_enter_creep_wait(creep_anchor)

	if _motion_state == MotionState.CREEP_WAIT:
		_creep_anchor_point = creep_anchor
		_state_time_remaining = max(_state_time_remaining - delta, 0.0)
		slime_blob.velocity = Vector2.ZERO
		slime_blob.update_movement_animation(Vector2.ZERO)
		if _state_time_remaining <= 0.0:
			_start_creep_move()
		return

	if _creep_input_direction == Vector2.ZERO:
		_enter_creep_wait(creep_anchor)
		return
	if slime_blob.prepare_move_start(_creep_input_direction):
		slime_blob.velocity = Vector2.ZERO
		return
	_state_time_remaining = max(_state_time_remaining - delta, 0.0)
	slime_blob.velocity = _map_input_to_isometric(_creep_input_direction) * wander_move_speed
	slime_blob.update_movement_animation(_creep_input_direction)
	_emit_pending_move_start_if_needed(_creep_input_direction)
	if _state_time_remaining <= 0.0:
		_enter_creep_wait(creep_anchor)

func _enter_pursuit_state(pursuit_state: MotionState, pursuit_target: Node2D) -> void:
	_motion_state = pursuit_state
	_pursuit_target = pursuit_target
	_state_time_remaining = 0.0
	_creep_input_direction = Vector2.ZERO
	_pursuit_input_direction = Vector2.ZERO
	_reset_stuck_tracking()
	if slime_blob != null and pursuit_target != null:
		var notify_direction: Vector2 = pursuit_target.global_position - slime_blob.global_position
		if notify_direction.length_squared() > 0.0001:
			_pending_move_start_direction = notify_direction.normalized()

func _exit_pursuit_state() -> void:
	if slime_blob != null:
		slime_blob.clear_engaged_direction(_creep_input_direction)
		slime_blob.velocity = Vector2.ZERO
		slime_blob.update_movement_animation(Vector2.ZERO)
	_pursuit_target = null
	_creep_input_direction = Vector2.ZERO
	_pursuit_input_direction = Vector2.ZERO
	_pending_move_start_direction = Vector2.ZERO
	_enter_creep_wait(_get_default_creep_anchor())

func _enter_creep_wait(anchor_point: Vector2) -> void:
	_motion_state = MotionState.CREEP_WAIT
	_creep_anchor_point = anchor_point
	_creep_input_direction = Vector2.ZERO
	_pursuit_input_direction = Vector2.ZERO
	_pending_move_start_direction = Vector2.ZERO
	_reset_stuck_tracking()
	_state_time_remaining = randf_range(creep_wait_duration_min, creep_wait_duration_max)
	if slime_blob != null:
		slime_blob.velocity = Vector2.ZERO
		slime_blob.update_movement_animation(Vector2.ZERO)

func _start_creep_move() -> void:
	if slime_blob == null:
		return
	var next_direction: Vector2 = _choose_creep_direction(_creep_anchor_point)
	if next_direction == Vector2.ZERO:
		_enter_creep_wait(_creep_anchor_point)
		return
	_motion_state = MotionState.CREEP_MOVE
	_creep_input_direction = next_direction
	_pending_move_start_direction = next_direction
	_state_time_remaining = randf_range(creep_move_duration_min, creep_move_duration_max)
	_reset_stuck_tracking()

func _update_stuck_recovery(delta: float) -> void:
	if slime_blob == null:
		return
	if slime_blob.velocity.length_squared() <= 0.0001 or slime_blob.is_raise_locked() or slime_blob.is_pool_turn_locked():
		_reset_stuck_sample()
		return
	if _detour_waypoint_active:
		_detour_waypoint_elapsed += delta
		var arrival_distance_sq: float = stuck_waypoint_arrival_distance * stuck_waypoint_arrival_distance
		if (
			slime_blob.global_position.distance_squared_to(_detour_waypoint) <= arrival_distance_sq
			or _detour_waypoint_elapsed >= max(stuck_waypoint_timeout, 0.1)
		):
			_clear_detour_waypoint()
			_reset_stuck_sample()
			return
	var requested_direction: Vector2 = slime_blob.velocity.normalized()
	if _stuck_sample_direction.length_squared() <= 0.0001:
		_stuck_sample_direction = requested_direction
	elif requested_direction.dot(_stuck_sample_direction) < 0.92:
		_reset_stuck_sample()
		_stuck_sample_direction = requested_direction
	_stuck_elapsed += delta
	_stuck_expected_distance += slime_blob.velocity.length() * delta
	if _stuck_elapsed < max(stuck_detection_duration, 0.05):
		return
	var displacement: Vector2 = slime_blob.global_position - _stuck_sample_position
	var forward_progress: float = displacement.dot(_stuck_sample_direction)
	var lateral_direction: Vector2 = Vector2(-_stuck_sample_direction.y, _stuck_sample_direction.x)
	var lateral_drift: float = absf(displacement.dot(lateral_direction))
	var effective_progress: float = forward_progress - (lateral_drift * max(stuck_lateral_drift_penalty, 0.0))
	var required_progress: float = max(
		stuck_minimum_displacement,
		_stuck_expected_distance * clamp(stuck_minimum_progress_ratio, 0.05, 1.0)
	)
	if effective_progress >= required_progress:
		_reset_stuck_sample()
		return
	if _motion_state == MotionState.CREEP_MOVE:
		_enter_creep_wait(_get_default_creep_anchor())
		return
	if _is_pursuit_state(_motion_state):
		var detour: Vector2 = _choose_unstuck_detour()
		if detour != Vector2.ZERO:
			_set_detour_waypoint(detour)
			_pending_move_start_direction = Vector2.ZERO
			slime_blob.notify_move_started(detour)
			_reset_stuck_sample()
			return
		_exit_pursuit_state()

func _set_detour_waypoint(input_direction: Vector2) -> void:
	if slime_blob == null:
		return
	var safe_direction: Vector2 = input_direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		return
	var clearance_fraction: float = _get_unblocked_motion_fraction(safe_direction)
	var waypoint_distance: float = min(
		max(stuck_waypoint_distance, 1.0),
		max(stuck_test_distance, 1.0) * clearance_fraction * 0.9
	)
	_detour_waypoint = slime_blob.global_position + (_map_input_to_isometric(safe_direction) * waypoint_distance)
	_detour_waypoint_active = true
	_detour_waypoint_elapsed = 0.0

func _get_detour_waypoint_direction() -> Vector2:
	if slime_blob == null or not _detour_waypoint_active:
		return Vector2.ZERO
	return _quantize_input_direction(_detour_waypoint - slime_blob.global_position)

func _clear_detour_waypoint() -> void:
	_detour_waypoint_active = false
	_detour_waypoint = Vector2.ZERO
	_detour_waypoint_elapsed = 0.0

func _choose_unstuck_detour() -> Vector2:
	if slime_blob == null:
		return Vector2.ZERO
	var current_direction: Vector2 = _quantize_input_direction(slime_blob.velocity)
	if current_direction == Vector2.ZERO:
		current_direction = _pursuit_input_direction
	if current_direction == Vector2.ZERO:
		return Vector2.ZERO
	var direction_ring: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2(1.0, 1.0).normalized(),
		Vector2.DOWN,
		Vector2(-1.0, 1.0).normalized(),
		Vector2.LEFT,
		Vector2(-1.0, -1.0).normalized(),
		Vector2.UP,
		Vector2(1.0, -1.0).normalized(),
	]
	var target_input_direction: Vector2 = current_direction
	if _pursuit_target != null:
		target_input_direction = _map_world_to_isometric_input(_pursuit_target.global_position - slime_blob.global_position)
	var current_index: int = _find_closest_direction_index(current_direction, direction_ring)
	var offsets: Array[int] = [1, -1, 2, -2, 3, -3, 4]
	var best_candidate: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for offset: int in offsets:
		var candidate_index: int = posmod(current_index + offset, direction_ring.size())
		var candidate: Vector2 = direction_ring[candidate_index]
		var clearance_fraction: float = _get_unblocked_motion_fraction(candidate)
		if clearance_fraction < stuck_minimum_clear_fraction:
			continue
		var target_progress: float = candidate.dot(target_input_direction)
		var turn_separation: float = 1.0 - candidate.dot(current_direction)
		var score: float = (clearance_fraction * 2.0) + (target_progress * 0.7) + (turn_separation * 0.2)
		if score > best_score:
			best_score = score
			best_candidate = candidate
	return best_candidate

func _get_unblocked_motion_fraction(input_direction: Vector2) -> float:
	if slime_blob == null:
		return 0.0
	var world_motion: Vector2 = _map_input_to_isometric(input_direction) * max(stuck_test_distance, 1.0)
	if not slime_blob.test_move(slime_blob.global_transform, world_motion):
		return 1.0
	var low: float = 0.0
	var high: float = 1.0
	for _iteration in range(7):
		var midpoint: float = (low + high) * 0.5
		if slime_blob.test_move(slime_blob.global_transform, world_motion * midpoint):
			high = midpoint
		else:
			low = midpoint
	return low

func _find_closest_direction_index(direction: Vector2, directions: Array[Vector2]) -> int:
	var best_index: int = 0
	var best_dot: float = -INF
	for index in range(directions.size()):
		var score: float = direction.dot(directions[index])
		if score > best_dot:
			best_dot = score
			best_index = index
	return best_index

func _reset_stuck_tracking() -> void:
	_clear_detour_waypoint()
	_reset_stuck_sample()

func _reset_stuck_sample() -> void:
	_stuck_elapsed = 0.0
	_stuck_expected_distance = 0.0
	_stuck_sample_direction = Vector2.ZERO
	if slime_blob != null:
		_stuck_sample_position = slime_blob.global_position

func _emit_pending_move_start_if_needed(direction: Vector2) -> void:
	if slime_blob == null:
		return
	if _pending_move_start_direction.length_squared() <= 0.0001:
		return
	if direction.length_squared() <= 0.0001:
		return
	slime_blob.notify_move_started(direction.normalized())
	_pending_move_start_direction = Vector2.ZERO

func _choose_creep_direction(anchor_point: Vector2) -> Vector2:
	if slime_blob == null:
		return Vector2.ZERO
	var candidate_target: Vector2 = anchor_point + _random_wander_offset()
	candidate_target = _constrain_to_wander_area(candidate_target)
	var desired_direction: Vector2 = _quantize_input_direction(candidate_target - slime_blob.global_position)
	if desired_direction != Vector2.ZERO:
		return desired_direction

	var fallback_directions: Array[Vector2] = [
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, 1.0).normalized(),
	]
	fallback_directions.shuffle()
	for candidate: Vector2 in fallback_directions:
		if candidate.length_squared() > 0.0:
			return candidate
	return Vector2.ZERO

func _resolve_pursuit_target() -> Node2D:
	if _mode == GameState.PowerMode.GRID_ON:
		return _get_follow_target()
	if _mode == GameState.PowerMode.POWER_OFF or _mode == GameState.PowerMode.GENERATOR_ON:
		return _get_chase_target()
	return null

func _resolve_pursuit_state() -> MotionState:
	if _mode == GameState.PowerMode.GRID_ON:
		return MotionState.FOLLOW
	return MotionState.CHASE

func _get_default_creep_anchor() -> Vector2:
	if _mode == GameState.PowerMode.GRID_ON and pump_anchor != null:
		return pump_anchor.global_position
	if slime_blob != null:
		return slime_blob.global_position
	if pump_anchor != null:
		return pump_anchor.global_position
	return global_position

func _is_pursuit_state(state: MotionState) -> bool:
	return state == MotionState.FOLLOW or state == MotionState.CHASE

func _apply_slime_damage(delta: float) -> void:
	if slime_blob == null:
		_set_active_in_range(false)
		return

	var damage_range: float = 0.0
	if _mode == GameState.PowerMode.GRID_ON:
		damage_range = damage_range_grid_on
	elif _mode == GameState.PowerMode.POWER_OFF:
		damage_range = damage_range_power_off
	else:
		_set_active_in_range(false)
		return

	var active: Node2D = _get_active_character()
	var damage_range_sq: float = damage_range * damage_range
	var slime_position: Vector2 = slime_blob.global_position
	if active and _is_exterior_character(active):
		var in_range: bool = active.global_position.distance_squared_to(slime_position) <= damage_range_sq
		_set_active_in_range(in_range)
	else:
		_set_active_in_range(false)

	_apply_damage_to(journalist, delta, damage_range_sq)
	_apply_damage_to(gsa, delta, damage_range_sq)

func _apply_damage_to(target: Node2D, delta: float, damage_range_sq: float) -> void:
	if target == null:
		return
	if not _is_exterior_character(target):
		_damage_timers[target] = 0.0
		_damage_in_range[target] = false
		return
	var in_range: bool = target.global_position.distance_squared_to(slime_blob.global_position) <= damage_range_sq
	if not in_range:
		_damage_timers[target] = 0.0
		_damage_in_range[target] = false
		return

	if not _damage_in_range.get(target, false):
		_damage_in_range[target] = true
		_say_slime_area_dialogue(target)

	_damage_timers[target] = float(_damage_timers.get(target, 0.0)) + delta * damage_per_second
	if _damage_timers[target] >= 1.0:
		var ticks: int = int(_damage_timers[target])
		_damage_timers[target] -= float(ticks)
		if target is CharacterBase:
			(target as CharacterBase).take_damage(ticks)
			if target == _get_active_character():
				active_damage_taken.emit(ticks)

func _set_active_in_range(in_range: bool) -> void:
	if _active_in_range == in_range:
		return
	_active_in_range = in_range
	active_damage_proximity.emit(_active_in_range)

func _say_slime_area_dialogue(target: Node2D) -> void:
	var character := target as CharacterBase
	if character == null:
		return
	var id_value: Variant = character.get("character_id")
	if id_value == "journalist":
		character.say("journalist_slime_area")
	elif id_value == "gsa":
		character.say("gsa_slime_area")

func _on_power_mode_changed(m: int) -> void:
	_mode = m
	if not _is_pursuit_state(_motion_state):
		_creep_anchor_point = _get_default_creep_anchor()

func _check_metal_post_electrocution() -> void:
	if slime_blob == null or metal_post_electrocution == null:
		return
	if metal_post_electrocution.disabled:
		return
	if _should_attract_to_trap_target():
		return
	if _cached_metal_post_poly.size() >= 3:
		if Geometry2D.is_point_in_polygon(slime_blob.global_position, _cached_metal_post_poly):
			_kill_slime_from_trap()
		return
	if _is_point_in_collision_polygon(slime_blob.global_position, metal_post_electrocution):
		_kill_slime_from_trap()

func _kill_slime_from_trap() -> void:
	if _slime_death_started:
		return
	_slime_death_started = true
	_set_active_in_range(false)
	_damage_timers.clear()
	_damage_in_range.clear()
	_motion_state = MotionState.CREEP_WAIT
	_pursuit_target = null
	_creep_input_direction = Vector2.ZERO
	_pursuit_input_direction = Vector2.ZERO
	_pending_move_start_direction = Vector2.ZERO
	_reset_stuck_tracking()
	if slime_blob != null:
		slime_blob.velocity = Vector2.ZERO
		slime_blob.play_death_animation()
	GameState.set_flag("generator_permanently_disabled", true)
	GameState.lock_power_off()
	GameState.set_flag("slime_dead", true)
	if slime_blob != null:
		await slime_blob.death_animation_completed
	SceneRouter.complete_victory_with_outro(outro_video_scene_path)

func _is_point_in_collision_polygon(point: Vector2, poly_node: CollisionPolygon2D) -> bool:
	var local_poly: PackedVector2Array = poly_node.polygon
	if local_poly.size() < 3:
		return false
	var global_poly: PackedVector2Array = PackedVector2Array()
	global_poly.resize(local_poly.size())
	for i in range(local_poly.size()):
		global_poly[i] = poly_node.global_transform * local_poly[i]
	return Geometry2D.is_point_in_polygon(point, global_poly)

func _should_attract_to_trap_target() -> bool:
	if slime_blob == null or trap_target == null:
		return false
	if not _is_trap_active():
		return false
	if _cached_trap_zone_poly.size() >= 3:
		return Geometry2D.is_point_in_polygon(slime_blob.global_position, _cached_trap_zone_poly)
	if trap_zone_collision == null:
		return false
	return _is_point_in_collision_polygon(slime_blob.global_position, trap_zone_collision)

func _is_trap_active() -> bool:
	return GameState.power_mode == GameState.PowerMode.GENERATOR_ON and GameState.get_flag("slime_trap_set")

func _get_active_character() -> Node2D:
	return journalist if GameState.active_character_id == "journalist" else gsa

func _get_follow_target() -> Node2D:
	if slime_blob == null:
		return null
	var best_target: Node2D = null
	var best_dist_sq: float = INF
	var slime_position: Vector2 = slime_blob.global_position
	var max_dist_sq: float = damage_range_grid_on * damage_range_grid_on
	best_target = _get_nearest_candidate(journalist, slime_position, max_dist_sq, best_target, best_dist_sq)
	if best_target != null:
		best_dist_sq = best_target.global_position.distance_squared_to(slime_position)
	best_target = _get_nearest_candidate(gsa, slime_position, max_dist_sq, best_target, best_dist_sq)
	return best_target

func _get_chase_target() -> CharacterBase:
	if slime_blob == null:
		return null
	var j := journalist as CharacterBase
	var g := gsa as CharacterBase
	var best: CharacterBase = null
	var best_dist: float = INF
	var slime_position: Vector2 = slime_blob.global_position
	var max_dist_sq: float = lure_radius * lure_radius
	if j and _is_exterior_character(j):
		var j_dist_sq: float = j.global_position.distance_squared_to(slime_position)
		if j_dist_sq <= max_dist_sq:
			best = j
			best_dist = j_dist_sq
	if g and _is_exterior_character(g):
		var g_dist_sq: float = g.global_position.distance_squared_to(slime_position)
		if g_dist_sq <= max_dist_sq and g_dist_sq < best_dist:
			best = g
	return best

func _get_nearest_candidate(candidate: Node2D, origin: Vector2, max_dist_sq: float, current_best: Node2D, current_best_dist_sq: float) -> Node2D:
	if candidate == null:
		return current_best
	if not _is_exterior_character(candidate):
		return current_best
	var dist_sq: float = candidate.global_position.distance_squared_to(origin)
	if dist_sq > max_dist_sq or dist_sq >= current_best_dist_sq:
		return current_best
	return candidate

func _is_exterior_character(candidate: Node2D) -> bool:
	var character := candidate as CharacterBase
	if character == null:
		return false
	return character.current_location == LayerController.ViewLayer.EXTERIOR

func _random_wander_offset() -> Vector2:
	var random_direction: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if random_direction.length_squared() == 0.0:
		return Vector2.ZERO
	return random_direction.normalized() * randf_range(0.0, wander_radius)

func _quantize_input_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() == 0.0:
		return Vector2.ZERO

	var input_dir: Vector2 = _map_world_to_isometric_input(direction)
	var quantized_input: Vector2 = Vector2(
		signf(input_dir.x) if absf(input_dir.x) >= 0.35 else 0.0,
		signf(input_dir.y) if absf(input_dir.y) >= 0.35 else 0.0
	)
	if quantized_input == Vector2.ZERO:
		if absf(input_dir.x) > absf(input_dir.y):
			quantized_input.x = signf(input_dir.x)
		else:
			quantized_input.y = signf(input_dir.y)
	return quantized_input.normalized()

func _choose_pursuit_input_direction(direction: Vector2) -> Vector2:
	var candidate_direction: Vector2 = _quantize_input_direction(direction)
	if candidate_direction == Vector2.ZERO:
		_pursuit_input_direction = Vector2.ZERO
		return Vector2.ZERO
	if _pursuit_input_direction == Vector2.ZERO or candidate_direction == _pursuit_input_direction:
		_pursuit_input_direction = candidate_direction
		return _pursuit_input_direction

	var input_direction: Vector2 = _map_world_to_isometric_input(direction)
	if input_direction == Vector2.ZERO:
		_pursuit_input_direction = candidate_direction
		return _pursuit_input_direction

	var current_score: float = input_direction.dot(_pursuit_input_direction)
	var candidate_score: float = input_direction.dot(candidate_direction)
	if candidate_score >= current_score + pursuit_direction_switch_margin:
		_pursuit_input_direction = candidate_direction
	return _pursuit_input_direction

func _map_input_to_isometric(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var mapped: Vector2 = Vector2(
		_isometric_axis_x * (dir.x - dir.y),
		_isometric_axis_y * (dir.x + dir.y)
	)
	return mapped.normalized() * dir.length()

func _map_world_to_isometric_input(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	if is_zero_approx(_isometric_axis_x) or is_zero_approx(_isometric_axis_y):
		return dir.normalized()
	var u: float = dir.x / _isometric_axis_x
	var v: float = dir.y / _isometric_axis_y
	var input_dir: Vector2 = Vector2((u + v) * 0.5, (v - u) * 0.5)
	return input_dir.normalized()

func _constrain_to_wander_area(pos: Vector2) -> Vector2:
	if slime_area_wander == null:
		return pos
	var wander_polys: Array[PackedVector2Array] = _cached_wander_polys
	if wander_polys.is_empty():
		wander_polys = _get_area_polygons(slime_area_wander)
	if wander_polys.is_empty():
		return pos
	for poly: PackedVector2Array in wander_polys:
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(pos, poly):
			return pos
	return _closest_point_on_polygons(pos, wander_polys)

func _get_area_polygons(area: Area2D) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = []
	for child in area.get_children():
		if child is CollisionPolygon2D:
			var local_poly: PackedVector2Array = (child as CollisionPolygon2D).polygon
			if local_poly.size() < 3:
				continue
			var global_poly: PackedVector2Array = PackedVector2Array()
			global_poly.resize(local_poly.size())
			for i in range(local_poly.size()):
				global_poly[i] = (child as CollisionPolygon2D).global_transform * local_poly[i]
			polys.append(global_poly)
	return polys

func _closest_point_on_polygon(pos: Vector2, poly: PackedVector2Array) -> Vector2:
	var closest: Vector2 = poly[0]
	var min_dist: float = pos.distance_squared_to(closest)
	var count: int = poly.size()
	for i in range(count):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var candidate: Vector2 = _closest_point_on_segment(pos, a, b)
		var dist_sq: float = pos.distance_squared_to(candidate)
		if dist_sq < min_dist:
			min_dist = dist_sq
			closest = candidate
	return closest

func _closest_point_on_polygons(pos: Vector2, polys: Array[PackedVector2Array]) -> Vector2:
	var closest: Vector2 = pos
	var min_dist: float = INF
	for poly: PackedVector2Array in polys:
		if poly.size() < 2:
			continue
		var candidate: Vector2 = _closest_point_on_polygon(pos, poly)
		var dist_sq: float = pos.distance_squared_to(candidate)
		if dist_sq < min_dist:
			min_dist = dist_sq
			closest = candidate
	return closest

func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq == 0.0:
		return a
	var t: float = clamp((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return a + ab * t

func _refresh_isometric_axes() -> void:
	var angle: float = deg_to_rad(isometric_axis_angle_degrees)
	_isometric_axis_x = cos(angle)
	_isometric_axis_y = sin(angle)

func _cache_static_polygons() -> void:
	_cached_wander_polys.clear()
	if slime_area_wander != null:
		_cached_wander_polys = _get_area_polygons(slime_area_wander)
	_cached_metal_post_poly = PackedVector2Array()
	if metal_post_electrocution != null:
		var local_poly: PackedVector2Array = metal_post_electrocution.polygon
		if local_poly.size() >= 3:
			_cached_metal_post_poly.resize(local_poly.size())
			for i in range(local_poly.size()):
				_cached_metal_post_poly[i] = metal_post_electrocution.global_transform * local_poly[i]
	_cached_trap_zone_poly = PackedVector2Array()
	if trap_zone_collision != null:
		var local_trap_zone_poly: PackedVector2Array = trap_zone_collision.polygon
		if local_trap_zone_poly.size() >= 3:
			_cached_trap_zone_poly.resize(local_trap_zone_poly.size())
			for i in range(local_trap_zone_poly.size()):
				_cached_trap_zone_poly[i] = trap_zone_collision.global_transform * local_trap_zone_poly[i]
