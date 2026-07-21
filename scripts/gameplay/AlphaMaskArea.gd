# res://scripts/gameplay/AlphaMaskArea.gd
extends Area2D
class_name AlphaMaskArea

enum MaskSource { ALPHA, GRAYSCALE }
const MAX_STACKED_MASKS := 4

@export var mask_sprite_path: NodePath
@export var trigger_polygon_path: NodePath
# Use full physics-body overlap for the slime instead of its origin point.
# Keep this off for regular environmental masks; the wire trap needs it because
# its character-tuned trigger does not line up with the slime's larger body.
@export var use_body_overlap_for_slime: bool = false
# If true, mask value hides character pixels. If false, mask value reveals them.
@export var invert_mask: bool = true
@export var mask_source: MaskSource = MaskSource.ALPHA

var _mask_sprite: Sprite2D
var _trigger_polygon: CollisionPolygon2D
var _mask_shader: Shader
static var _shared_mask_shader: Shader
static var _visual_mask_states: Dictionary = {}
var _applied_by_body_id: Dictionary = {}
var _applied_body_refs_by_id: Dictionary = {}
var _original_material_meta_key: String
var _last_mask_transform: Transform2D
var _last_mask_texture_rid: RID
var _last_mask_draw_origin: Vector2 = Vector2.ZERO
var _last_mask_tex_size: Vector2 = Vector2.ONE
var _last_invert_mask: bool = false
var _last_mask_source: int = -1
var _mask_enabled := true
var _maskable_bodies: Array[Node2D] = []
var _cached_trigger_local_polygon: PackedVector2Array = PackedVector2Array()
var _cached_trigger_global_polygon: PackedVector2Array = PackedVector2Array()
var _cached_trigger_transform: Transform2D

func _ready() -> void:
	_mask_sprite = _resolve_mask_sprite()
	_trigger_polygon = _resolve_trigger_polygon()
	if _mask_sprite == null:
		push_error("%s: missing Sprite2D mask child." % name)
		return
	if _trigger_polygon == null:
		push_error("%s: missing CollisionPolygon2D trigger child." % name)
		return

	_mask_sprite.visible = false
	if _shared_mask_shader == null:
		_shared_mask_shader = Shader.new()
		_shared_mask_shader.code = _shader_code()
	_mask_shader = _shared_mask_shader
	_original_material_meta_key = "_alpha_mask_area_original_material_%d" % get_instance_id()

	_cache_maskable_bodies()
	_refresh_trigger_polygon_cache(true)
	set_process(true)
	set_physics_process(true)
	_refresh_mask_uniforms_if_needed(true)
	_reconcile_anchor_points()

func _exit_tree() -> void:
	var body_ids: Array = _applied_by_body_id.keys()
	for body_id in body_ids:
		_remove_area_from_body(int(body_id))
	_applied_by_body_id.clear()
	_applied_body_refs_by_id.clear()

func _process(_delta: float) -> void:
	if not _mask_enabled:
		return
	_refresh_mask_uniforms_if_needed(false)

func _physics_process(_delta: float) -> void:
	if not _mask_enabled:
		return
	_reconcile_anchor_points()

func set_mask_enabled(enabled: bool) -> void:
	if _mask_enabled == enabled:
		return
	_mask_enabled = enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	set_process(enabled)
	set_physics_process(enabled)
	if enabled:
		_refresh_mask_uniforms_if_needed(true)
		_reconcile_anchor_points()
		return
	var body_ids: Array = _applied_by_body_id.keys()
	for body_id in body_ids:
		_remove_area_from_body(int(body_id))

func _reconcile_anchor_points() -> void:
	var inside_ids: Dictionary = {}
	for body in _maskable_bodies:
		if not is_instance_valid(body):
			continue
		var body_id: int = body.get_instance_id()
		if _is_body_inside_trigger(body):
			inside_ids[body_id] = true
			_apply_mask_to_body(body)
		elif _applied_by_body_id.has(body_id):
			_remove_area_from_body(body_id)

	if _applied_by_body_id.is_empty():
		return

	var applied_ids: Array = _applied_by_body_id.keys()
	for body_id_variant in applied_ids:
		var body_id: int = int(body_id_variant)
		if not inside_ids.has(body_id):
			_remove_area_from_body(body_id)

func _cache_maskable_bodies() -> void:
	_maskable_bodies.clear()
	_collect_maskable_bodies(get_tree().current_scene)

func _collect_maskable_bodies(node: Node) -> void:
	if node == null:
		return
	if node is CharacterBase or node is SlimeBody:
		_maskable_bodies.append(node as Node2D)
	for child in node.get_children():
		_collect_maskable_bodies(child)

func _is_body_inside_trigger(body: Node2D) -> bool:
	if use_body_overlap_for_slime and body is SlimeBody and body is PhysicsBody2D:
		return overlaps_body(body as PhysicsBody2D)
	return _is_anchor_inside_trigger(body.global_position)

func _is_anchor_inside_trigger(anchor_global_position: Vector2) -> bool:
	if _trigger_polygon == null:
		return false
	_refresh_trigger_polygon_cache(false)
	if _cached_trigger_global_polygon.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(anchor_global_position, _cached_trigger_global_polygon)

func _refresh_trigger_polygon_cache(force: bool) -> void:
	if _trigger_polygon == null:
		_cached_trigger_local_polygon = PackedVector2Array()
		_cached_trigger_global_polygon = PackedVector2Array()
		return
	var local_polygon: PackedVector2Array = _trigger_polygon.polygon
	var polygon_transform: Transform2D = _trigger_polygon.global_transform
	if (
		not force
		and local_polygon == _cached_trigger_local_polygon
		and polygon_transform == _cached_trigger_transform
	):
		return
	_cached_trigger_local_polygon = local_polygon.duplicate()
	_cached_trigger_transform = polygon_transform
	_cached_trigger_global_polygon.resize(local_polygon.size())
	for i in range(local_polygon.size()):
		_cached_trigger_global_polygon[i] = polygon_transform * local_polygon[i]

func _apply_mask_to_body(body: Node) -> void:
	var body_id: int = body.get_instance_id()
	if _applied_by_body_id.has(body_id):
		return

	var visuals: Array[CanvasItem] = []

	_collect_visual_items(body, visuals)
	if visuals.is_empty():
		return

	for visual in visuals:
		_add_area_to_visual(visual)

	_applied_by_body_id[body_id] = visuals
	_applied_body_refs_by_id[body_id] = body
	_apply_trail_mask_to_body(body)

func _remove_area_from_body(body_id: int) -> void:
	if not _applied_by_body_id.has(body_id):
		return
	var body_variant: Variant = _applied_body_refs_by_id.get(body_id, null)
	if body_variant is SlimeBody:
		(body_variant as SlimeBody).clear_slime_trail_alpha_mask(get_instance_id())
	var visuals: Array = _applied_by_body_id[body_id]
	for visual_variant in visuals:
		if visual_variant is CanvasItem:
			_remove_area_from_visual(visual_variant as CanvasItem)
	_applied_by_body_id.erase(body_id)
	_applied_body_refs_by_id.erase(body_id)

func _add_area_to_visual(visual: CanvasItem) -> void:
	var visual_id: int = visual.get_instance_id()
	var area_id: int = get_instance_id()
	var payload = _build_area_payload()
	if payload.is_empty():
		return

	if not _visual_mask_states.has(visual_id):
		_initialize_visual_mask_state(visual, visual_id, _original_material_meta_key)

	var state: Dictionary = _visual_mask_states[visual_id]
	var areas: Dictionary = state.get("areas", {})
	areas[area_id] = payload
	state["areas"] = areas
	_visual_mask_states[visual_id] = state
	_update_visual_mask_material(state)

func _initialize_visual_mask_state(visual: CanvasItem, visual_id: int, meta_key: String) -> void:
	var base_material: Material = visual.material
	var original_material: Variant = base_material
	var mask_material: Material = base_material

	if not _is_our_mask_material(base_material):
		mask_material = ShaderMaterial.new()
		_configure_mask_material(mask_material)
		visual.set_meta(_original_material_meta_key, base_material)
		visual.material = mask_material
	elif visual.has_meta(_original_material_meta_key):
		original_material = visual.get_meta(_original_material_meta_key)
	else:
		original_material = null

	var state: Dictionary = {
		"visual": visual,
		"meta_key": meta_key,
		"original": original_material,
		"material": mask_material,
		"areas": {},
	}
	_visual_mask_states[visual_id] = state


func _remove_area_from_visual(visual: CanvasItem) -> void:
	var visual_id: int = visual.get_instance_id()
	if not _visual_mask_states.has(visual_id):
		return
	var state: Dictionary = _visual_mask_states[visual_id]
	var areas: Dictionary = state.get("areas", {})
	var area_id: int = get_instance_id()
	if not areas.has(area_id):
		return
	areas.erase(area_id)
	state["areas"] = areas
	_visual_mask_states[visual_id] = state

	if areas.is_empty():
		_restore_visual_material(visual, state)
		_visual_mask_states.erase(visual_id)
	else:
		_update_visual_mask_material(state)

func _refresh_area_mask_for_visual(visual: CanvasItem) -> void:
	var visual_id: int = visual.get_instance_id()
	if not _visual_mask_states.has(visual_id):
		return
	var state: Dictionary = _visual_mask_states[visual_id]
	var areas: Dictionary = state.get("areas", {})
	var area_id: int = get_instance_id()
	if not areas.has(area_id):
		return
	var payload: Dictionary = _build_area_payload()
	if payload.is_empty():
		return
	areas[area_id] = payload
	state["areas"] = areas
	_visual_mask_states[visual_id] = state
	_update_visual_mask_material(state)

func _restore_visual_material(visual: CanvasItem, state: Dictionary) -> void:
	var meta_key: String = state.get("meta_key", "")
	var original_material: Variant = state.get("original", null)
	if meta_key != "" and visual.has_meta(meta_key):
		var original_meta: Variant = visual.get_meta(meta_key)
		visual.material = original_meta as Material
		visual.remove_meta(meta_key)
	elif original_material != null:
		visual.material = original_material as Material
	elif _is_our_mask_material(visual.material):
		visual.material = null

func _build_area_payload() -> Dictionary:
	if _mask_sprite == null:
		return {}
	var texture: Texture2D = _mask_sprite.texture
	if texture == null:
		return {}

	var inv: Transform2D = _mask_sprite.get_global_transform().affine_inverse()
	var tex_size: Vector2 = _get_mask_texture_size(texture)
	var draw_origin: Vector2 = _get_mask_draw_origin(tex_size)

	return {
		"texture": texture,
		"inv_x": inv.x,
		"inv_y": inv.y,
		"inv_origin": inv.origin,
		"tex_size": tex_size,
		"draw_origin": draw_origin,
		"invert_mask": invert_mask,
		"mask_source": int(mask_source),
	}

func _update_visual_mask_material(state: Dictionary) -> void:
	var mask_material_variant: Variant = state.get("material", null)
	if not (mask_material_variant is ShaderMaterial):
		return
	var mask_material: ShaderMaterial = mask_material_variant
	var areas: Dictionary = state.get("areas", {})
	var ordered_payloads: Array = areas.values()
	var area_count: int = ordered_payloads.size()
	if area_count > MAX_STACKED_MASKS:
		push_warning("AlphaMaskArea: maximum overlap slots (%d) reached; dropping extra masks." % MAX_STACKED_MASKS)
		area_count = MAX_STACKED_MASKS

	for slot in range(MAX_STACKED_MASKS):
		var param_suffix: String = str(slot)
		if slot < area_count:
			var payload: Dictionary = ordered_payloads[slot]
			mask_material.set_shader_parameter("mask_active_%s" % param_suffix, true)
			mask_material.set_shader_parameter("mask_texture_%s" % param_suffix, payload.get("texture", null))
			mask_material.set_shader_parameter("mask_inv_x_%s" % param_suffix, payload.get("inv_x", Vector2.ZERO))
			mask_material.set_shader_parameter("mask_inv_y_%s" % param_suffix, payload.get("inv_y", Vector2.ZERO))
			mask_material.set_shader_parameter("mask_inv_origin_%s" % param_suffix, payload.get("inv_origin", Vector2.ZERO))
			mask_material.set_shader_parameter("mask_tex_size_%s" % param_suffix, payload.get("tex_size", Vector2.ONE))
			mask_material.set_shader_parameter("mask_draw_origin_%s" % param_suffix, payload.get("draw_origin", Vector2.ZERO))
			mask_material.set_shader_parameter("mask_invert_%s" % param_suffix, payload.get("invert_mask", true))
			mask_material.set_shader_parameter("mask_source_%s" % param_suffix, payload.get("mask_source", 0))
		else:
			mask_material.set_shader_parameter("mask_active_%s" % param_suffix, false)

func _is_our_mask_material(candidate_material: Material) -> bool:
	if not (candidate_material is ShaderMaterial):
		return false
	var shader_material: ShaderMaterial = candidate_material as ShaderMaterial
	return shader_material.shader == _mask_shader

func _configure_mask_material(mask_material: ShaderMaterial) -> void:
	mask_material.shader = _mask_shader

func _collect_visual_items(node: Node, out_items: Array[CanvasItem]) -> void:
	if node is CanvasItem and _is_visual_canvas_item(node):
		out_items.append(node as CanvasItem)
	for child in node.get_children():
		_collect_visual_items(child, out_items)

func _is_visual_canvas_item(node: Node) -> bool:
	if node == _mask_sprite or node == _trigger_polygon:
		return false
	if node is CollisionShape2D or node is CollisionPolygon2D:
		return false
	if node is CollisionObject2D:
		return false
	return true

func _refresh_mask_uniforms_if_needed(force: bool) -> void:
	if _mask_sprite == null:
		return
	var texture: Texture2D = _mask_sprite.texture
	if texture == null:
		return

	var mask_transform: Transform2D = _mask_sprite.get_global_transform()
	var texture_rid: RID = texture.get_rid()
	var tex_size: Vector2 = _get_mask_texture_size(texture)
	var draw_origin: Vector2 = _get_mask_draw_origin(tex_size)

	var changed: bool = force
	changed = changed or _last_mask_transform != mask_transform
	changed = changed or _last_mask_texture_rid != texture_rid
	changed = changed or _last_mask_tex_size != tex_size
	changed = changed or _last_mask_draw_origin != draw_origin
	changed = changed or _last_invert_mask != invert_mask
	changed = changed or _last_mask_source != int(mask_source)
	if not changed:
		return

	_last_mask_transform = mask_transform
	_last_mask_texture_rid = texture_rid
	_last_mask_tex_size = tex_size
	_last_mask_draw_origin = draw_origin
	_last_invert_mask = invert_mask
	_last_mask_source = int(mask_source)

	if _applied_by_body_id.is_empty():
		return

	var body_ids: Array = _applied_by_body_id.keys()
	for body_id in body_ids:
		var body_variant: Variant = _applied_body_refs_by_id.get(int(body_id), null)
		if body_variant is SlimeBody:
			_apply_trail_mask_to_body(body_variant as SlimeBody)
		var visuals: Array = _applied_by_body_id[body_id]
		for visual_variant in visuals:
			if visual_variant is CanvasItem:
				_refresh_area_mask_for_visual(visual_variant as CanvasItem)

func _apply_trail_mask_to_body(body: Node) -> void:
	if not (body is SlimeBody):
		return
	var payload: Dictionary = _build_area_payload()
	if payload.is_empty():
		return
	(body as SlimeBody).set_slime_trail_alpha_mask(get_instance_id(), payload)

func _get_mask_texture_size(texture: Texture2D) -> Vector2:
	if _mask_sprite.region_enabled:
		return _mask_sprite.region_rect.size
	return texture.get_size()

func _get_mask_draw_origin(texture_size: Vector2) -> Vector2:
	var draw_origin: Vector2 = _mask_sprite.offset
	if _mask_sprite.centered:
		draw_origin -= texture_size * 0.5
	return draw_origin

func _resolve_mask_sprite() -> Sprite2D:
	if not mask_sprite_path.is_empty():
		var node: Node = get_node_or_null(mask_sprite_path)
		if node is Sprite2D:
			return node as Sprite2D
	for child in get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

func _resolve_trigger_polygon() -> CollisionPolygon2D:
	if not trigger_polygon_path.is_empty():
		var node: Node = get_node_or_null(trigger_polygon_path)
		if node is CollisionPolygon2D:
			return node as CollisionPolygon2D
	for child in get_children():
		if child is CollisionPolygon2D:
			return child as CollisionPolygon2D
	return null

func _shader_code() -> String:
	var code: String = """
shader_type canvas_item;

"""

	for i in range(MAX_STACKED_MASKS):
		code += """
uniform bool mask_active_%d;
uniform sampler2D mask_texture_%d : source_color;
uniform vec2 mask_inv_x_%d;
uniform vec2 mask_inv_y_%d;
uniform vec2 mask_inv_origin_%d;
uniform vec2 mask_tex_size_%d = vec2(1.0, 1.0);
uniform vec2 mask_draw_origin_%d = vec2(0.0, 0.0);
uniform bool mask_invert_%d = true;
uniform int mask_source_%d = 0; // 0 = alpha, 1 = grayscale
""" % [i, i, i, i, i, i, i, i, i]

	code += """

	varying vec2 mask_world_pos;

	void vertex() {
		mask_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	}

float sample_mask_keep_alpha(
	vec2 sample_world_pos,
	sampler2D mask_texture,
	bool invert_mask,
	int mask_source,
	vec2 inv_x,
	vec2 inv_y,
	vec2 inv_origin,
	vec2 mask_tex_size,
	vec2 mask_draw_origin
) {
	vec2 local = vec2(
		inv_x.x * sample_world_pos.x + inv_y.x * sample_world_pos.y + inv_origin.x,
		inv_x.y * sample_world_pos.x + inv_y.y * sample_world_pos.y + inv_origin.y
	);

	vec2 uv = (local - mask_draw_origin) / mask_tex_size;
	float mask_value = 0.0;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec4 mask_sample = texture(mask_texture, uv);
		if (mask_source == 1) {
			mask_value = dot(mask_sample.rgb, vec3(0.299, 0.587, 0.114));
		} else {
			mask_value = mask_sample.a;
		}
	}

	return invert_mask ? (1.0 - mask_value) : mask_value;
}

void fragment() {
	float keep_alpha = 1.0;
"""

	for i in range(MAX_STACKED_MASKS):
		code += """
	if (mask_active_%d) {
		keep_alpha *= sample_mask_keep_alpha(
				mask_world_pos,
				mask_texture_%d,
			mask_invert_%d,
			mask_source_%d,
			mask_inv_x_%d,
			mask_inv_y_%d,
			mask_inv_origin_%d,
			mask_tex_size_%d,
			mask_draw_origin_%d
		);
	}
""" % [i, i, i, i, i, i, i, i, i]

	code += """
	COLOR.a *= keep_alpha;
}
"""

	return code
