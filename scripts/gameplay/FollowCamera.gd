# res://scripts/gameplay/FollowCamera.gd
extends Camera2D

@export var journalist: Node2D
@export var gsa: Node2D
@export var slime_system_path: NodePath
@export var exterior_bounds_path: NodePath
@export var interior_bounds_path: NodePath
@export var cellar_bounds_path: NodePath
@export var light_shake_strength := 1.5
@export var light_shake_speed := 10.0
@export var damage_jerk_strength := 6.0
@export var damage_jerk_decay := 20.0

@onready var _slime_system: Node = get_node_or_null(slime_system_path)
@onready var _exterior_bounds: CanvasItem = get_node_or_null(exterior_bounds_path) as CanvasItem
@onready var _interior_bounds: CanvasItem = get_node_or_null(interior_bounds_path) as CanvasItem
@onready var _cellar_bounds: CanvasItem = get_node_or_null(cellar_bounds_path) as CanvasItem

var _in_damage_range := false
var _shake_time := 0.0
var _damage_jerk := 0.0

func _ready() -> void:
	GameState.active_character_changed.connect(_on_active_changed)
	_on_active_changed(GameState.active_character_id)
	if _slime_system:
		_slime_system.active_damage_proximity.connect(_on_active_damage_proximity)
		_slime_system.active_damage_taken.connect(_on_active_damage_taken)

func _on_active_changed(id: String) -> void:
	var target := journalist if id == "journalist" else gsa
	if target:
		global_position = _resolve_camera_position(target, Vector2.ZERO)

func _process(_delta: float) -> void:
	var target := journalist if GameState.active_character_id == "journalist" else gsa

	var shake_offset := Vector2.ZERO
	if _in_damage_range:
		_shake_time += _delta * light_shake_speed
		shake_offset += Vector2(cos(_shake_time), sin(_shake_time)) * light_shake_strength
	else:
		_shake_time = 0.0

	if _damage_jerk > 0.0:
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if jitter.length_squared() > 0.0:
			jitter = jitter.normalized()
		shake_offset += jitter * _damage_jerk
		_damage_jerk = max(_damage_jerk - damage_jerk_decay * _delta, 0.0)

	if target:
		global_position = _resolve_camera_position(target, shake_offset)
	offset = Vector2.ZERO

func _on_active_damage_proximity(in_range: bool) -> void:
	_in_damage_range = in_range

func _on_active_damage_taken(amount: int) -> void:
	_damage_jerk = max(_damage_jerk, damage_jerk_strength * float(amount))

func trigger_damage_shake(amount: int) -> void:
	_damage_jerk = max(_damage_jerk, damage_jerk_strength * float(amount))

func _resolve_camera_position(target: Node2D, shake_offset: Vector2) -> Vector2:
	if target == null:
		return global_position
	var location: Variant = target.get("current_location")
	var bounds_rect := _bounds_for_location(location)
	if bounds_rect == null:
		return target.global_position + shake_offset
	var rect := _global_rect_from_canvas_item(bounds_rect)
	if rect == Rect2():
		return target.global_position + shake_offset

	var desired := target.global_position + shake_offset
	var safe_zoom := Vector2(
		zoom.x if abs(zoom.x) > 0.0001 else 1.0,
		zoom.y if abs(zoom.y) > 0.0001 else 1.0
	)
	var half_view := (get_viewport_rect().size * 0.5) / safe_zoom
	var min_x := rect.position.x + half_view.x
	var max_x := rect.position.x + rect.size.x - half_view.x
	var min_y := rect.position.y + half_view.y
	var max_y := rect.position.y + rect.size.y - half_view.y

	if min_x > max_x:
		desired.x = rect.position.x + rect.size.x * 0.5
	else:
		desired.x = clamp(desired.x, min_x, max_x)

	if min_y > max_y:
		desired.y = rect.position.y + rect.size.y * 0.5
	else:
		desired.y = clamp(desired.y, min_y, max_y)

	return desired

func _bounds_for_location(location: Variant) -> CanvasItem:
	if location == LayerController.ViewLayer.INTERIOR:
		return _interior_bounds
	if location == LayerController.ViewLayer.CELLAR:
		return _cellar_bounds
	return _exterior_bounds

func _global_rect_from_canvas_item(item: CanvasItem) -> Rect2:
	if item is ColorRect:
		return (item as ColorRect).get_global_rect()
	if item is Sprite2D:
		var sprite := item as Sprite2D
		if sprite.texture == null:
			return Rect2()
		var local_rect := sprite.get_rect()
		var p0 := sprite.to_global(local_rect.position)
		var p1 := sprite.to_global(local_rect.position + Vector2(local_rect.size.x, 0.0))
		var p2 := sprite.to_global(local_rect.position + Vector2(0.0, local_rect.size.y))
		var p3 := sprite.to_global(local_rect.position + local_rect.size)
		var min_x := minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
		var min_y := minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
		var max_x := maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
		var max_y := maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
		return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return Rect2()
