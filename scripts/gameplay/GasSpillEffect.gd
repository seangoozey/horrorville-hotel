# res://scripts/gameplay/GasSpillEffect.gd
extends Area2D

@export var trigger_polygon_path: NodePath
@export var tracked_body_path: NodePath = NodePath("../../Hazard/SlimeBlob")

var _trigger_polygon: CollisionPolygon2D
var _tracked_body: SlimeBody
var _body_was_inside: bool = false
var _cached_local_polygon: PackedVector2Array = PackedVector2Array()
var _cached_global_polygon: PackedVector2Array = PackedVector2Array()
var _cached_polygon_transform: Transform2D

func _ready() -> void:
	_trigger_polygon = _resolve_trigger_polygon()
	_tracked_body = _resolve_tracked_body()
	if _trigger_polygon == null:
		push_error("%s: missing GasSpill collision polygon." % name)
		return
	if _tracked_body == null:
		push_error("%s: missing tracked body for gas spill effect." % name)
		return
	_refresh_polygon_cache(true)
	_tracked_body.set_gas_spill_trigger_polygon(_trigger_polygon)
	set_process(true)
	_update_tracked_body_state()

func _process(_delta: float) -> void:
	_update_tracked_body_state()

func _resolve_trigger_polygon() -> CollisionPolygon2D:
	if not trigger_polygon_path.is_empty():
		var explicit_node: Node = get_node_or_null(trigger_polygon_path)
		if explicit_node is CollisionPolygon2D:
			return explicit_node as CollisionPolygon2D
	for child in get_children():
		if child is CollisionPolygon2D:
			return child as CollisionPolygon2D
	return null

func _resolve_tracked_body() -> SlimeBody:
	if tracked_body_path.is_empty():
		return null
	var tracked_node: Node = get_node_or_null(tracked_body_path)
	if tracked_node is SlimeBody:
		return tracked_node as SlimeBody
	return null

func _update_tracked_body_state() -> void:
	if _trigger_polygon == null or _tracked_body == null:
		return
	var body_inside: bool = _is_point_in_trigger(_tracked_body.global_position)
	_tracked_body.set_gas_spill_surface_active(body_inside)
	_body_was_inside = body_inside

func _is_point_in_trigger(world_point: Vector2) -> bool:
	if _trigger_polygon == null:
		return false
	_refresh_polygon_cache(false)
	if _cached_global_polygon.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(world_point, _cached_global_polygon)

func _refresh_polygon_cache(force: bool) -> void:
	if _trigger_polygon == null:
		_cached_local_polygon = PackedVector2Array()
		_cached_global_polygon = PackedVector2Array()
		return
	var local_polygon: PackedVector2Array = _trigger_polygon.polygon
	var polygon_transform: Transform2D = _trigger_polygon.global_transform
	if (
		not force
		and local_polygon == _cached_local_polygon
		and polygon_transform == _cached_polygon_transform
	):
		return
	_cached_local_polygon = local_polygon.duplicate()
	_cached_polygon_transform = polygon_transform
	_cached_global_polygon.resize(local_polygon.size())
	for i in range(local_polygon.size()):
		_cached_global_polygon[i] = polygon_transform * local_polygon[i]
