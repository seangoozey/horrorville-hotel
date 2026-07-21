# res://scripts/gameplay/ElevationArea.gd
extends Area2D
class_name ElevationArea

@export var y_offset := 5.0

var _trigger_polygon: CollisionPolygon2D
var _applied_body_ids: Dictionary = {}

func _ready() -> void:
	_trigger_polygon = _resolve_trigger_polygon()
	if _trigger_polygon == null:
		push_error("%s: missing CollisionPolygon2D trigger child." % name)
		return
	set_physics_process(true)
	_reconcile_anchor_points()

func _exit_tree() -> void:
	var body_ids: Array = _applied_body_ids.keys()
	for body_id_variant in body_ids:
		_clear_body_offset_by_id(int(body_id_variant))
	_applied_body_ids.clear()

func _physics_process(_delta: float) -> void:
	_reconcile_anchor_points()

func _reconcile_anchor_points() -> void:
	var inside_ids: Dictionary = {}
	var bodies: Array[CharacterBody2D] = []
	_collect_character_bodies(get_tree().current_scene, bodies)
	for body in bodies:
		var body_id: int = body.get_instance_id()
		if _is_anchor_inside_trigger(body.global_position):
			inside_ids[body_id] = true
			_apply_body_offset(body)
		elif _applied_body_ids.has(body_id):
			_clear_body_offset_by_id(body_id)

	var applied_ids: Array = _applied_body_ids.keys()
	for body_id_variant in applied_ids:
		var body_id: int = int(body_id_variant)
		if not inside_ids.has(body_id):
			_clear_body_offset_by_id(body_id)

func _collect_character_bodies(node: Node, out_bodies: Array[CharacterBody2D]) -> void:
	if node == null:
		return
	if node is CharacterBody2D:
		out_bodies.append(node as CharacterBody2D)
	for child in node.get_children():
		_collect_character_bodies(child, out_bodies)

func _apply_body_offset(body: CharacterBody2D) -> void:
	if body == null:
		return
	if body.has_method("_set_elevation_offset_source"):
		body._set_elevation_offset_source(self, y_offset)
		_applied_body_ids[body.get_instance_id()] = true

func _clear_body_offset_by_id(body_id: int) -> void:
	var body_obj: Object = instance_from_id(body_id)
	if body_obj != null and body_obj is CharacterBody2D:
		_clear_body_offset(body_obj as CharacterBody2D)
	_applied_body_ids.erase(body_id)

func _clear_body_offset(body: CharacterBody2D) -> void:
	if body == null:
		return
	if body.has_method("_clear_elevation_offset_source"):
		body._clear_elevation_offset_source(self)
	_applied_body_ids.erase(body.get_instance_id())

func _resolve_trigger_polygon() -> CollisionPolygon2D:
	for child in get_children():
		if child is CollisionPolygon2D:
			return child as CollisionPolygon2D
	return null

func _is_anchor_inside_trigger(anchor_global_position: Vector2) -> bool:
	if _trigger_polygon == null:
		return false
	var local_polygon: PackedVector2Array = _trigger_polygon.polygon
	if local_polygon.size() < 3:
		return false
	var xf: Transform2D = _trigger_polygon.get_global_transform()
	var global_polygon: PackedVector2Array = PackedVector2Array()
	global_polygon.resize(local_polygon.size())
	for i in range(local_polygon.size()):
		global_polygon[i] = xf * local_polygon[i]
	return Geometry2D.is_point_in_polygon(anchor_global_position, global_polygon)
