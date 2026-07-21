extends Node
class_name SlimeTrailEmitter

const MAX_STAMPS_PER_MOTION_UPDATE: int = 8

var manager: SlimeTrailManager
var source_body: Node2D
var enabled: bool = true

var _previous_position: Vector2 = Vector2.ZERO
var _previous_body_position: Vector2 = Vector2.ZERO
var _last_stamped_position: Vector2 = Vector2.ZERO
var _previous_direction: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.ZERO
var _accumulated_body_distance: float = 0.0
var _has_previous_position: bool = false
var _has_previous_body_position: bool = false
var _has_last_stamped_position: bool = false

func set_source_body(body: Node2D) -> void:
	source_body = body
	if body != null:
		var deposit_position: Vector2 = _resolve_deposit_position(body.global_position, _move_direction)
		_previous_body_position = body.global_position
		_previous_position = deposit_position
		_last_stamped_position = deposit_position
		_has_previous_body_position = true
		_has_previous_position = true
		_has_last_stamped_position = true
		_accumulated_body_distance = 0.0

func begin_move(move_direction: Vector2) -> void:
	var safe_direction: Vector2 = move_direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		return
	_move_direction = safe_direction
	_previous_direction = safe_direction
	if manager != null:
		manager.begin_move_style(safe_direction)
	if source_body != null:
		var deposit_position: Vector2 = _resolve_deposit_position(source_body.global_position, safe_direction)
		_previous_body_position = source_body.global_position
		_previous_position = deposit_position
		_last_stamped_position = deposit_position
		_has_previous_body_position = true
		_has_previous_position = true
		_has_last_stamped_position = true
		_accumulated_body_distance = 0.0

func set_move_direction(move_direction: Vector2) -> void:
	var safe_direction: Vector2 = move_direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		return
	if _move_direction.length_squared() > 0.0001 and safe_direction.dot(_move_direction) >= 0.999:
		return
	_move_direction = safe_direction
	_previous_direction = safe_direction
	_accumulated_body_distance = 0.0
	if source_body == null:
		return
	var deposit_position: Vector2 = _resolve_deposit_position(source_body.global_position, safe_direction)
	_previous_body_position = source_body.global_position
	_previous_position = deposit_position
	_last_stamped_position = deposit_position
	_has_previous_body_position = true
	_has_previous_position = true
	_has_last_stamped_position = true

func record_motion(current_position: Vector2, blocked: bool) -> void:
	var sample_position: Vector2 = _resolve_deposit_position(current_position, _move_direction)
	if manager == null or not enabled:
		_previous_body_position = current_position
		_previous_position = sample_position
		_last_stamped_position = sample_position
		_has_previous_body_position = true
		_has_previous_position = true
		_has_last_stamped_position = true
		_accumulated_body_distance = 0.0
		return
	if not _has_previous_position or not _has_previous_body_position:
		_previous_body_position = current_position
		_previous_position = sample_position
		_last_stamped_position = sample_position
		_has_previous_body_position = true
		_has_previous_position = true
		_has_last_stamped_position = true
		_accumulated_body_distance = 0.0
		return
	if blocked:
		_previous_body_position = current_position
		_previous_position = sample_position
		_last_stamped_position = sample_position
		_has_previous_body_position = true
		_has_last_stamped_position = true
		_accumulated_body_distance = 0.0
		return

	var movement: Vector2 = current_position - _previous_body_position
	var distance: float = movement.length()
	if distance <= 0.001:
		_previous_body_position = current_position
		_previous_position = sample_position
		return

	var direction: Vector2 = movement / distance
	_accumulated_body_distance += distance
	if _move_direction.length_squared() <= 0.0001:
		_move_direction = direction
	if not _has_last_stamped_position:
		_last_stamped_position = _previous_position
		_has_last_stamped_position = true

	var from_position: Vector2 = _last_stamped_position
	var to_position: Vector2 = sample_position
	var spacing: float = max(manager.stamp_spacing, 1.0)
	if _accumulated_body_distance < spacing:
		_previous_body_position = current_position
		_previous_position = sample_position
		_previous_direction = direction
		return
	var requested_step_count: int = maxi(int(floor(_accumulated_body_distance / spacing)), 1)
	var step_count: int = mini(requested_step_count, MAX_STAMPS_PER_MOTION_UPDATE)
	var turn_amount: float = 0.0
	if _previous_direction.length_squared() > 0.0001:
		turn_amount = clamp(1.0 - _previous_direction.dot(direction), 0.0, 1.0)
	var stamp_speed: float = min(_accumulated_body_distance / float(requested_step_count), spacing)
	for step_index in range(1, step_count + 1):
		var weight: float = float(step_index) / float(step_count)
		var stamp_position: Vector2 = from_position.lerp(to_position, weight)
		manager.deposit_stamp(stamp_position, direction, stamp_speed, turn_amount)

	if requested_step_count > MAX_STAMPS_PER_MOTION_UPDATE:
		_last_stamped_position = sample_position
		_accumulated_body_distance = 0.0
	else:
		_last_stamped_position = sample_position
		_accumulated_body_distance = max(_accumulated_body_distance - (float(step_count) * spacing), 0.0)
	_previous_body_position = current_position
	_previous_position = sample_position
	_previous_direction = direction

func _resolve_deposit_position(fallback_position: Vector2, move_direction: Vector2) -> Vector2:
	if source_body == null:
		return fallback_position
	if not source_body.has_method("get_slime_trail_deposit_position"):
		return fallback_position
	var value: Variant = source_body.call("get_slime_trail_deposit_position", move_direction)
	if value is Vector2:
		return value as Vector2
	return fallback_position
