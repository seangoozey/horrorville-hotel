# res://scripts/gameplay/SlimePoolRipple.gd
extends Polygon2D
class_name SlimePoolRipple

const POOL_RIPPLE_SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform sampler2D source_texture : source_color;
uniform vec2 source_inv_x = vec2(1.0, 0.0);
uniform vec2 source_inv_y = vec2(0.0, 1.0);
uniform vec2 source_inv_origin = vec2(0.0, 0.0);
uniform vec2 source_tex_size = vec2(1.0, 1.0);
uniform vec2 source_draw_origin = vec2(0.0, 0.0);
uniform vec2 source_uv_origin = vec2(0.0, 0.0);
uniform vec2 source_uv_size = vec2(1.0, 1.0);
uniform vec2 ripple_origin_world = vec2(0.0, 0.0);
uniform vec2 ripple_axis = vec2(1.0, 0.0);
uniform float ripple_forward_scale = 1.0;
uniform float ripple_backward_scale = 1.0;
uniform float ripple_lateral_scale = 1.0;
uniform float ripple_alpha = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float sample_alpha(vec2 sample_world_pos) {
	vec2 source_local = vec2(
		source_inv_x.x * sample_world_pos.x + source_inv_y.x * sample_world_pos.y + source_inv_origin.x,
		source_inv_x.y * sample_world_pos.x + source_inv_y.y * sample_world_pos.y + source_inv_origin.y
	);
	vec2 source_uv = (source_local - source_draw_origin) / source_tex_size;
	if (source_uv.x < 0.0 || source_uv.x > 1.0 || source_uv.y < 0.0 || source_uv.y > 1.0) {
		return 0.0;
	}
	vec2 atlas_uv = source_uv_origin + (source_uv * source_uv_size);
	return texture(source_texture, atlas_uv).a;
}

void fragment() {
	vec2 safe_axis = normalize(max(abs(ripple_axis.x) + abs(ripple_axis.y), 0.001) * ripple_axis);
	vec2 ripple_perp = vec2(-safe_axis.y, safe_axis.x);
	vec2 world_offset = world_pos - ripple_origin_world;
	float forward_distance = dot(world_offset, safe_axis);
	float lateral_distance = dot(world_offset, ripple_perp);
	float directional_scale = forward_distance >= 0.0 ? max(ripple_forward_scale, 0.001) : max(ripple_backward_scale, 0.001);
	float lateral_scale = max(ripple_lateral_scale, 0.001);
	vec2 sample_world_pos = ripple_origin_world
		+ (safe_axis * (forward_distance / directional_scale))
		+ (ripple_perp * (lateral_distance / lateral_scale));
	float alpha_value = sample_alpha(sample_world_pos);
	float edge_mask = step(0.02, alpha_value) * (1.0 - step(0.98, alpha_value));
	float grayscale = clamp(alpha_value, 0.0, 1.0);
	float final_alpha = edge_mask * ripple_alpha;
	vec3 ripple_rgb = mix(vec3(1.0), vec3(grayscale), final_alpha);
	COLOR = vec4(ripple_rgb, 1.0);
}
"""

var _elapsed: float = 0.0
var _fade_duration: float = 1.1
var _start_forward_scale: float = 1.0
var _end_forward_scale: float = 1.85
var _start_backward_scale: float = 1.0
var _end_backward_scale: float = 1.45
var _start_lateral_scale: float = 1.0
var _end_lateral_scale: float = 1.35
var _start_alpha: float = 0.26
var _scale_speed: float = 1.0
var _shader_update_interval: float = 0.033
var _shader_update_elapsed: float = 0.0
var _ripple_material: ShaderMaterial
static var _shared_pool_ripple_shader: Shader

func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 1.0)
	set_process(true)

func configure_from_sprite(
	source_sprite: AnimatedSprite2D,
	trigger_polygon: CollisionPolygon2D,
	fade_duration: float,
	scale_multiplier: float,
	scale_speed: float = 1.0,
	intensity: float = 0.26,
	move_direction: Vector2 = Vector2.ZERO,
	update_interval: float = 0.033
) -> void:
	if source_sprite == null or source_sprite.sprite_frames == null or trigger_polygon == null:
		return
	var frame_texture: Texture2D = source_sprite.sprite_frames.get_frame_texture(source_sprite.animation, source_sprite.frame)
	if frame_texture == null:
		return
	if _shared_pool_ripple_shader == null:
		_shared_pool_ripple_shader = Shader.new()
		_shared_pool_ripple_shader.code = POOL_RIPPLE_SHADER_CODE
	if _ripple_material == null:
		_ripple_material = ShaderMaterial.new()
		_ripple_material.shader = _shared_pool_ripple_shader
	material = _ripple_material
	polygon = _build_polygon_in_parent_space(trigger_polygon)
	z_index = source_sprite.z_index
	_fade_duration = max(fade_duration, 0.01)
	_scale_speed = max(scale_speed, 0.01)
	_shader_update_interval = max(update_interval, 0.0)
	_shader_update_elapsed = 0.0
	_start_alpha = clamp(intensity, 0.0, 1.0)
	var safe_scale_multiplier: float = max(scale_multiplier, 1.0)
	_end_forward_scale = safe_scale_multiplier * 1.15
	_end_backward_scale = lerpf(1.0, safe_scale_multiplier, 0.75)
	_end_lateral_scale = lerpf(1.0, safe_scale_multiplier, 0.55)
	_elapsed = 0.0
	var safe_move_direction: Vector2 = move_direction.normalized()
	if safe_move_direction.length_squared() <= 0.0001:
		safe_move_direction = Vector2.RIGHT

	var source_texture: Texture2D = frame_texture
	var frame_texture_size: Vector2 = frame_texture.get_size()
	var source_uv_origin: Vector2 = Vector2.ZERO
	var source_uv_size: Vector2 = Vector2.ONE
	if frame_texture is AtlasTexture:
		var atlas_texture: AtlasTexture = frame_texture as AtlasTexture
		if atlas_texture.atlas != null:
			source_texture = atlas_texture.atlas
			var atlas_size: Vector2 = atlas_texture.atlas.get_size()
			frame_texture_size = atlas_texture.region.size
			if atlas_size.x > 0.0 and atlas_size.y > 0.0:
				source_uv_origin = atlas_texture.region.position / atlas_size
				source_uv_size = atlas_texture.region.size / atlas_size
	var draw_origin: Vector2 = source_sprite.offset
	if source_sprite.centered:
		draw_origin -= frame_texture_size * 0.5
	var sprite_transform_inverse: Transform2D = source_sprite.global_transform.affine_inverse()

	_ripple_material.set_shader_parameter("source_texture", source_texture)
	_ripple_material.set_shader_parameter("source_inv_x", sprite_transform_inverse.x)
	_ripple_material.set_shader_parameter("source_inv_y", sprite_transform_inverse.y)
	_ripple_material.set_shader_parameter("source_inv_origin", sprite_transform_inverse.origin)
	_ripple_material.set_shader_parameter("source_tex_size", frame_texture_size)
	_ripple_material.set_shader_parameter("source_draw_origin", draw_origin)
	_ripple_material.set_shader_parameter("source_uv_origin", source_uv_origin)
	_ripple_material.set_shader_parameter("source_uv_size", source_uv_size)
	_ripple_material.set_shader_parameter("ripple_origin_world", source_sprite.global_position)
	_ripple_material.set_shader_parameter("ripple_axis", safe_move_direction)
	_ripple_material.set_shader_parameter("ripple_forward_scale", _start_forward_scale)
	_ripple_material.set_shader_parameter("ripple_backward_scale", _start_backward_scale)
	_ripple_material.set_shader_parameter("ripple_lateral_scale", _start_lateral_scale)
	_update_ripple_material(0.0)

func _process(delta: float) -> void:
	_elapsed += delta * _scale_speed
	var progress: float = clamp(_elapsed / _fade_duration, 0.0, 1.0)
	_shader_update_elapsed += delta
	if _shader_update_interval <= 0.0 or _shader_update_elapsed >= _shader_update_interval or progress >= 1.0:
		_shader_update_elapsed = 0.0
		_update_ripple_material(progress)
	if progress >= 1.0:
		queue_free()

func _update_ripple_material(progress: float) -> void:
	if _ripple_material == null:
		return
	var expansion_progress: float = 1.0 - pow(1.0 - progress, 2.0)
	_ripple_material.set_shader_parameter("ripple_forward_scale", lerpf(_start_forward_scale, _end_forward_scale, expansion_progress))
	_ripple_material.set_shader_parameter("ripple_backward_scale", lerpf(_start_backward_scale, _end_backward_scale, expansion_progress))
	_ripple_material.set_shader_parameter("ripple_lateral_scale", lerpf(_start_lateral_scale, _end_lateral_scale, expansion_progress))
	var next_alpha: float = lerpf(_start_alpha, 0.0, progress)
	_ripple_material.set_shader_parameter("ripple_alpha", next_alpha)

func _build_polygon_in_parent_space(trigger_polygon: CollisionPolygon2D) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var local_polygon: PackedVector2Array = trigger_polygon.polygon
	if local_polygon.size() < 3:
		return result
	result.resize(local_polygon.size())
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return result
	var parent_inverse: Transform2D = parent_node.global_transform.affine_inverse()
	for i in range(local_polygon.size()):
		var global_point: Vector2 = trigger_polygon.global_transform * local_polygon[i]
		result[i] = parent_inverse * global_point
	return result
