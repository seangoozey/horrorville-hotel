extends Node2D
class_name SlimeTrailManager

const MAX_POOLED_WIDTH_MULTIPLIER := 1.5
const SATURATED_FIELD_VALUE := 0.99

const DEBUG_FIELD_SHADER_CODE := """
shader_type canvas_item;

uniform float field_threshold = 0.08;
uniform float edge_softness = 0.08;
uniform float debug_alpha = 1.0;
uniform float field_blur_radius = 0.0;
uniform vec2 canvas_world_center = vec2(0.0, 0.0);
uniform vec2 canvas_world_size = vec2(720.0, 720.0);
uniform vec4 dark_oil_color : source_color = vec4(0.11, 0.055, 0.025, 1.0);
uniform vec4 light_oil_color : source_color = vec4(0.48, 0.28, 0.11, 1.0);
uniform bool alpha_mask_enabled = false;
uniform bool alpha_mask_active = false;
uniform sampler2D alpha_mask_texture : source_color;
uniform vec2 alpha_mask_inv_x;
uniform vec2 alpha_mask_inv_y;
uniform vec2 alpha_mask_inv_origin;
uniform vec2 alpha_mask_tex_size = vec2(1.0, 1.0);
uniform vec2 alpha_mask_draw_origin = vec2(0.0, 0.0);
uniform bool alpha_mask_invert = true;
uniform int alpha_mask_source = 0;

varying vec2 trail_world_pos;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 curve = local * local * local * (local * ((local * 6.0) - 15.0) + 10.0);
	float bottom_left = hash(cell);
	float bottom_right = hash(cell + vec2(1.0, 0.0));
	float top_left = hash(cell + vec2(0.0, 1.0));
	float top_right = hash(cell + vec2(1.0, 1.0));
	float bottom = mix(bottom_left, bottom_right, curve.x);
	float top = mix(top_left, top_right, curve.x);
	return mix(bottom, top, curve.y);
}

float fbm(vec2 point) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += noise(point) * amplitude;
		point = (point * 2.07) + vec2(17.31, 9.47);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	trail_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float sample_alpha_mask_keep_alpha(vec2 sample_world_pos) {
	vec2 local = vec2(
		alpha_mask_inv_x.x * sample_world_pos.x + alpha_mask_inv_y.x * sample_world_pos.y + alpha_mask_inv_origin.x,
		alpha_mask_inv_x.y * sample_world_pos.x + alpha_mask_inv_y.y * sample_world_pos.y + alpha_mask_inv_origin.y
	);
	vec2 uv = (local - alpha_mask_draw_origin) / alpha_mask_tex_size;
	float mask_value = 0.0;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec4 mask_sample = texture(alpha_mask_texture, uv);
		if (alpha_mask_source == 1) {
			mask_value = dot(mask_sample.rgb, vec3(0.299, 0.587, 0.114));
		} else {
			mask_value = mask_sample.a;
		}
	}
	return alpha_mask_invert ? (1.0 - mask_value) : mask_value;
}

void fragment() {
	float field_value = texture(TEXTURE, UV).r;
	if (field_blur_radius >= 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float sum = texture(TEXTURE, UV).r * 4.0;
		sum += texture(TEXTURE, UV + vec2(px.x, 0.0)).r * 2.0;
		sum += texture(TEXTURE, UV + vec2(-px.x, 0.0)).r * 2.0;
		sum += texture(TEXTURE, UV + vec2(0.0, px.y)).r * 2.0;
		sum += texture(TEXTURE, UV + vec2(0.0, -px.y)).r * 2.0;
		sum += texture(TEXTURE, UV + vec2(px.x, px.y)).r;
		sum += texture(TEXTURE, UV + vec2(-px.x, px.y)).r;
		sum += texture(TEXTURE, UV + vec2(px.x, -px.y)).r;
		sum += texture(TEXTURE, UV + vec2(-px.x, -px.y)).r;
		field_value = sum / 16.0;
	}
	if (field_blur_radius >= 1.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float wide_sum = field_value * 4.0;
		wide_sum += texture(TEXTURE, UV + vec2(px.x * 2.0, 0.0)).r;
		wide_sum += texture(TEXTURE, UV + vec2(-px.x * 2.0, 0.0)).r;
		wide_sum += texture(TEXTURE, UV + vec2(0.0, px.y * 2.0)).r;
		wide_sum += texture(TEXTURE, UV + vec2(0.0, -px.y * 2.0)).r;
		field_value = wide_sum / 8.0;
	}
	if (field_value < 0.001) {
		discard;
	}
	float field_presence = step(0.001, field_value);
	float coverage = smoothstep(0.001, field_threshold + edge_softness, field_value);
	float density = smoothstep(field_threshold - edge_softness, field_threshold + edge_softness, field_value);
	float pooled_density = smoothstep(0.18, 0.9, field_value);
	vec2 world_position = canvas_world_center + ((UV - vec2(0.5, 0.5)) * canvas_world_size);
	vec2 oil_uv = world_position / 720.0;
	vec2 warped_uv = oil_uv + vec2(
		fbm((oil_uv * 7.0) + vec2(3.1, 8.7)),
		fbm((oil_uv * 7.0) + vec2(19.4, 2.6))
	) * 0.09;
	float turbulence = fbm(warped_uv * 11.0);
	float color_field = turbulence + (pooled_density * 0.12);
	float color_blend_width = max(fwidth(color_field) * 14.0, 0.025);
	float light_region = smoothstep(0.68 - color_blend_width, 0.68 + color_blend_width, color_field) * smoothstep(0.04, 0.16, field_value);
	vec3 oil_color = mix(dark_oil_color.rgb, light_oil_color.rgb, light_region);
	oil_color = mix(oil_color, dark_oil_color.rgb * 0.78, pooled_density * 0.22);
	float alpha = field_presence * coverage * mix(0.18, debug_alpha, max(density, pow(clamp(field_value, 0.0, 1.0), 0.65)));
	if (alpha_mask_enabled && alpha_mask_active) {
		alpha *= sample_alpha_mask_keep_alpha(trail_world_pos);
	}
	COLOR = vec4(oil_color, alpha);
}
"""

@export var canvas_world_size: Vector2 = Vector2(720.0, 720.0)
@export var canvas_resolution: Vector2i = Vector2i(256, 256)
@export_range(0.05, 0.45, 0.01) var recenter_margin_ratio: float = 0.22
@export var stamp_spacing: float = 8.0
@export var base_width: float = 20.0
@export_range(0.0, 1.0, 0.01) var width_randomness: float = 0.24
@export var stretch_from_speed: float = 0.032
@export var max_stretch_multiplier: float = 1.35
@export_range(0.1, 1.5, 0.01) var field_footprint_length_ratio: float = 0.45
@export var lateral_jitter_enabled: bool = true
@export var lateral_jitter_max_offset: float = 12.0
@export var lateral_jitter_step: float = 3.0
@export_range(0.0, 1.0, 0.01) var lateral_jitter_center_chance: float = 0.62
@export_range(0.0, 1.0, 0.01) var lateral_jitter_hold_chance: float = 0.25
@export_range(0.0, 1.0, 0.01) var lateral_jitter_outward_chance: float = 0.13
@export var turn_pooling_multiplier: float = 1.5
@export_range(0.0, 1.0, 0.01) var max_turn_pooling_amount: float = 0.45
@export_range(0.0, 1.0, 0.01) var droplet_chance: float = 0.12
@export var decay_rate: float = 0.0
@export var decay_update_interval: float = 0.1
@export var field_deposit_strength: float = 0.28
@export var field_repeat_pool_growth: float = 1.15
@export_range(0, 2, 1) var field_upload_blur_radius: int = 0
@export var alpha_mask_enabled: bool = true
@export var texture_upload_interval: float = 0.033
@export var recenter_cooldown: float = 0.08
@export var visualization_debug: bool = true
@export var dark_oil_color: Color = Color(0.11, 0.055, 0.025, 1.0)
@export var light_oil_color: Color = Color(0.48, 0.28, 0.11, 1.0)
@export_range(0.0, 1.0, 0.001) var mask_threshold: float = 0.08
@export_range(0.0, 1.0, 0.001) var debug_edge_softness: float = 0.08
@export_range(0.0, 1.0, 0.01) var debug_alpha: float = 1.0

var _display_sprite: Sprite2D
var _field_image: Image
var _field_texture: ImageTexture
var _debug_material: ShaderMaterial
var _field_values: PackedFloat32Array = PackedFloat32Array()
var _recenter_values_buffer: PackedFloat32Array = PackedFloat32Array()
var _active_field_indices: Array[int] = []
var _active_field_lookup: PackedByteArray = PackedByteArray()
var _recenter_lookup_buffer: PackedByteArray = PackedByteArray()
var _recenter_indices_buffer: Array[int] = []
var _recenter_image_buffer: Image
var _field_dirty: bool = false
var _dirty_min: Vector2i = Vector2i.ZERO
var _dirty_max: Vector2i = Vector2i.ZERO
var _active_move_width_multiplier: float = 1.0
var _width_variation_phase: float = 0.0
var _lateral_jitter_offset: float = 0.0
var _previous_stamp_direction: Vector2 = Vector2.DOWN
var _cached_resolution: Vector2i = Vector2i.ZERO
var _decay_elapsed: float = 0.0
var _texture_upload_elapsed: float = 0.0
var _recenter_cooldown_remaining: float = 0.0
var _alpha_mask_payload: Dictionary = {}

func _ready() -> void:
	_ensure_field()
	_ensure_display_sprite()
	_begin_new_move_style(Vector2.DOWN)
	_update_processing_state()

func refresh_configuration() -> void:
	_ensure_field()
	_ensure_display_sprite()
	_sync_display_configuration()
	_sync_debug_material()
	_update_processing_state()

func _process(delta: float) -> void:
	_recenter_cooldown_remaining = max(_recenter_cooldown_remaining - delta, 0.0)
	if decay_rate > 0.0:
		_decay_elapsed += delta
		var safe_decay_interval: float = max(decay_update_interval, 0.0)
		if safe_decay_interval <= 0.0 or _decay_elapsed >= safe_decay_interval:
			_decay_field(_decay_elapsed)
			_decay_elapsed = 0.0
	if _field_dirty:
		_texture_upload_elapsed += delta
		var safe_upload_interval: float = max(texture_upload_interval, 0.0)
		if safe_upload_interval <= 0.0 or _texture_upload_elapsed >= safe_upload_interval:
			_upload_field_debug_texture()
	_update_processing_state()

func begin_move_style(move_direction: Vector2) -> void:
	_begin_new_move_style(move_direction)

func set_alpha_mask_payload(payload: Dictionary) -> void:
	_alpha_mask_payload = payload.duplicate()
	_sync_debug_material()

func clear_alpha_mask_payload() -> void:
	if _alpha_mask_payload.is_empty():
		return
	_alpha_mask_payload.clear()
	_sync_debug_material()

func deposit_stamp(world_position: Vector2, move_direction: Vector2, speed: float, turn_amount: float) -> void:
	set_process(true)
	_ensure_field()
	_recenter_if_needed(world_position)
	var canvas_position: Vector2 = world_to_canvas(world_position)
	if not _is_inside_canvas(canvas_position):
		return
	var safe_direction: Vector2 = move_direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		safe_direction = Vector2.RIGHT
	var lateral_axis: Vector2 = Vector2(-safe_direction.y, safe_direction.x)
	var jittered_canvas_position: Vector2 = canvas_position + (lateral_axis * _world_to_canvas_distance(_next_lateral_jitter_offset()))

	var width_value: float = base_width * _next_width_multiplier(speed, turn_amount)
	var local_field_value: float = _sample_field(jittered_canvas_position)
	if local_field_value >= SATURATED_FIELD_VALUE:
		_previous_stamp_direction = safe_direction
		_update_processing_state()
		return
	var repeat_pool_multiplier: float = 1.0 + (local_field_value * field_repeat_pool_growth)
	var safe_turn_amount: float = min(max(turn_amount, 0.0), max_turn_pooling_amount)
	var turn_pool_multiplier: float = 1.0 + (safe_turn_amount * turn_pooling_multiplier)
	var maximum_pooled_width: float = max(base_width, 1.0) * MAX_POOLED_WIDTH_MULTIPLIER
	var pooled_width: float = min(
		width_value * repeat_pool_multiplier * turn_pool_multiplier,
		maximum_pooled_width
	)
	var stretch_value: float = min(1.0 + max(speed, 0.0) * stretch_from_speed, max(max_stretch_multiplier, 1.0))
	_paint_oriented_field(jittered_canvas_position, safe_direction, pooled_width, stretch_value, field_deposit_strength)

	if safe_turn_amount > 0.18:
		var turn_side: float = signf(_cross_scalar(_previous_stamp_direction, safe_direction))
		if is_zero_approx(turn_side):
			turn_side = 1.0
		var perpendicular: Vector2 = Vector2(-safe_direction.y, safe_direction.x) * turn_side
		var pooled_offset: Vector2 = perpendicular * _world_to_canvas_distance(width_value) * (0.22 + safe_turn_amount * 0.45)
		_paint_oriented_field(
			jittered_canvas_position + pooled_offset,
			safe_direction.rotated(randf_range(-0.3, 0.3)),
			min(pooled_width * (1.0 + safe_turn_amount * 0.65), maximum_pooled_width),
			1.0,
			field_deposit_strength * 0.85
		)

	if randf() <= droplet_chance:
		var droplet_offset: Vector2 = (
			(-safe_direction * _world_to_canvas_distance(width_value * randf_range(0.1, 0.6)))
			+ (Vector2(-safe_direction.y, safe_direction.x) * _world_to_canvas_distance(width_value * randf_range(-0.7, 0.7)))
		)
		_paint_oriented_field(
			jittered_canvas_position + droplet_offset,
			safe_direction.rotated(randf_range(-PI, PI)),
			width_value * randf_range(0.28, 0.48),
			1.0,
			field_deposit_strength * 0.65
		)
	_previous_stamp_direction = safe_direction
	_update_processing_state()

func world_to_canvas(world_position: Vector2) -> Vector2:
	var local_world: Vector2 = to_local(world_position)
	var safe_world_size: Vector2 = _get_safe_canvas_world_size()
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var uv: Vector2 = Vector2(
		(local_world.x / safe_world_size.x) + 0.5,
		(local_world.y / safe_world_size.y) + 0.5
	)
	return Vector2(
		uv.x * float(safe_resolution.x),
		uv.y * float(safe_resolution.y)
	)

func _ensure_field() -> void:
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	if _field_image != null and _cached_resolution == safe_resolution:
		return
	_cached_resolution = safe_resolution
	_field_values = PackedFloat32Array()
	_field_values.resize(safe_resolution.x * safe_resolution.y)
	_recenter_values_buffer = PackedFloat32Array()
	_recenter_values_buffer.resize(safe_resolution.x * safe_resolution.y)
	_active_field_indices.clear()
	_active_field_lookup = PackedByteArray()
	_active_field_lookup.resize(safe_resolution.x * safe_resolution.y)
	_recenter_lookup_buffer = PackedByteArray()
	_recenter_lookup_buffer.resize(safe_resolution.x * safe_resolution.y)
	_recenter_indices_buffer.clear()
	_field_image = Image.create(safe_resolution.x, safe_resolution.y, false, Image.FORMAT_RGBA8)
	_field_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_recenter_image_buffer = Image.create(safe_resolution.x, safe_resolution.y, false, Image.FORMAT_RGBA8)
	_recenter_image_buffer.fill(Color(0.0, 0.0, 0.0, 0.0))
	_field_texture = ImageTexture.create_from_image(_field_image)
	_field_dirty = false

func _recenter_if_needed(world_position: Vector2) -> void:
	if _recenter_cooldown_remaining > 0.0:
		return
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var canvas_position: Vector2 = world_to_canvas(world_position)
	var margin_x: float = float(safe_resolution.x) * clamp(recenter_margin_ratio, 0.05, 0.45)
	var margin_y: float = float(safe_resolution.y) * clamp(recenter_margin_ratio, 0.05, 0.45)
	if (
		canvas_position.x >= margin_x
		and canvas_position.y >= margin_y
		and canvas_position.x <= float(safe_resolution.x) - margin_x
		and canvas_position.y <= float(safe_resolution.y) - margin_y
	):
		return
	_recenter_field(world_position)

func _recenter_field(new_center: Vector2) -> void:
	_ensure_field()
	if global_position.distance_squared_to(new_center) <= 0.0001:
		return
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var safe_world_size: Vector2 = _get_safe_canvas_world_size()
	var pixel_world_size: Vector2 = Vector2(
		safe_world_size.x / float(safe_resolution.x),
		safe_world_size.y / float(safe_resolution.y)
	)
	var center_delta: Vector2 = new_center - global_position
	var pixel_offset: Vector2i = Vector2i(
		int(round(center_delta.x / pixel_world_size.x)),
		int(round(center_delta.y / pixel_world_size.y))
	)
	if pixel_offset == Vector2i.ZERO:
		return
	var snapped_center: Vector2 = global_position + Vector2(
		float(pixel_offset.x) * pixel_world_size.x,
		float(pixel_offset.y) * pixel_world_size.y
	)
	_clear_recenter_buffers()

	for index: int in _active_field_indices:
		var value: float = _field_values[index]
		if value <= 0.0:
			continue
		var old_y: int = floori(float(index) / float(safe_resolution.x))
		var old_x: int = index - (old_y * safe_resolution.x)
		var new_x: int = old_x - pixel_offset.x
		var new_y: int = old_y - pixel_offset.y
		if new_x < 0 or new_y < 0 or new_x >= safe_resolution.x or new_y >= safe_resolution.y:
			continue
		var new_index: int = new_y * safe_resolution.x + new_x
		if value <= _recenter_values_buffer[new_index]:
			continue
		_recenter_values_buffer[new_index] = value
		_recenter_image_buffer.set_pixel(new_x, new_y, Color(value, value, value, value))
		if _recenter_lookup_buffer[new_index] == 0:
			_recenter_lookup_buffer[new_index] = 1
			_recenter_indices_buffer.append(new_index)

	global_position = snapped_center
	var old_values: PackedFloat32Array = _field_values
	_field_values = _recenter_values_buffer
	_recenter_values_buffer = old_values
	var old_lookup: PackedByteArray = _active_field_lookup
	_active_field_lookup = _recenter_lookup_buffer
	_recenter_lookup_buffer = old_lookup
	var old_indices: Array[int] = _active_field_indices
	_active_field_indices = _recenter_indices_buffer
	_recenter_indices_buffer = old_indices
	var old_image: Image = _field_image
	_field_image = _recenter_image_buffer
	_recenter_image_buffer = old_image
	if _field_texture == null:
		_field_texture = ImageTexture.create_from_image(_field_image)
	else:
		_field_texture.update(_field_image)
	_field_dirty = false
	_texture_upload_elapsed = 0.0
	_recenter_cooldown_remaining = max(recenter_cooldown, 0.0)
	_sync_display_configuration()
	_sync_debug_material()

func _clear_recenter_buffers() -> void:
	for index: int in _recenter_indices_buffer:
		_recenter_values_buffer[index] = 0.0
		_recenter_lookup_buffer[index] = 0
	_recenter_indices_buffer.clear()
	_recenter_image_buffer.fill(Color(0.0, 0.0, 0.0, 0.0))

func _ensure_display_sprite() -> void:
	if _display_sprite == null or not is_instance_valid(_display_sprite):
		_display_sprite = Sprite2D.new()
		_display_sprite.name = "TrailFieldDebugDisplay"
		_display_sprite.centered = true
		_display_sprite.top_level = true
		add_child(_display_sprite)
	_sync_display_configuration()
	_sync_debug_material()

func _sync_display_configuration() -> void:
	if _display_sprite == null:
		return
	_display_sprite.texture = _field_texture
	_display_sprite.top_level = visualization_debug
	_display_sprite.global_position = global_position
	_display_sprite.show_behind_parent = false
	_display_sprite.z_as_relative = not visualization_debug
	_display_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var safe_world_size: Vector2 = _get_safe_canvas_world_size()
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	_display_sprite.scale = Vector2(
		safe_world_size.x / float(safe_resolution.x),
		safe_world_size.y / float(safe_resolution.y)
	)
	if visualization_debug:
		_display_sprite.z_index = maxi(z_index, 10)
	else:
		_display_sprite.z_index = 0

func _sync_debug_material() -> void:
	if _display_sprite == null:
		return
	if _debug_material == null:
		var debug_shader := Shader.new()
		debug_shader.code = DEBUG_FIELD_SHADER_CODE
		_debug_material = ShaderMaterial.new()
		_debug_material.shader = debug_shader
	_display_sprite.material = _debug_material
	_debug_material.set_shader_parameter("field_threshold", mask_threshold)
	_debug_material.set_shader_parameter("edge_softness", debug_edge_softness)
	_debug_material.set_shader_parameter("debug_alpha", debug_alpha)
	_debug_material.set_shader_parameter("field_blur_radius", float(clampi(field_upload_blur_radius, 0, 2)))
	_debug_material.set_shader_parameter("alpha_mask_enabled", alpha_mask_enabled)
	_debug_material.set_shader_parameter("alpha_mask_active", alpha_mask_enabled and not _alpha_mask_payload.is_empty())
	if alpha_mask_enabled and not _alpha_mask_payload.is_empty():
		_debug_material.set_shader_parameter("alpha_mask_texture", _alpha_mask_payload.get("texture", null))
		_debug_material.set_shader_parameter("alpha_mask_inv_x", _alpha_mask_payload.get("inv_x", Vector2.ZERO))
		_debug_material.set_shader_parameter("alpha_mask_inv_y", _alpha_mask_payload.get("inv_y", Vector2.ZERO))
		_debug_material.set_shader_parameter("alpha_mask_inv_origin", _alpha_mask_payload.get("inv_origin", Vector2.ZERO))
		_debug_material.set_shader_parameter("alpha_mask_tex_size", _alpha_mask_payload.get("tex_size", Vector2.ONE))
		_debug_material.set_shader_parameter("alpha_mask_draw_origin", _alpha_mask_payload.get("draw_origin", Vector2.ZERO))
		_debug_material.set_shader_parameter("alpha_mask_invert", _alpha_mask_payload.get("invert_mask", true))
		_debug_material.set_shader_parameter("alpha_mask_source", _alpha_mask_payload.get("mask_source", 0))
	_debug_material.set_shader_parameter("canvas_world_center", global_position)
	_debug_material.set_shader_parameter("canvas_world_size", _get_safe_canvas_world_size())
	_debug_material.set_shader_parameter("dark_oil_color", dark_oil_color)
	_debug_material.set_shader_parameter("light_oil_color", light_oil_color)

func _paint_oriented_field(canvas_position: Vector2, direction: Vector2, world_width: float, stretch_value: float, strength: float) -> void:
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var safe_direction: Vector2 = direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		safe_direction = Vector2.RIGHT
	var lateral_axis: Vector2 = Vector2(-safe_direction.y, safe_direction.x)
	var half_width_px: float = max(_world_to_canvas_distance(world_width) * 0.5, 1.0)
	var spacing_coverage_px: float = _world_to_canvas_distance(stamp_spacing) * 0.75
	var half_length_px: float = max(half_width_px * field_footprint_length_ratio * max(stretch_value, 1.0), spacing_coverage_px, 1.0)
	var bounds_radius: int = int(ceil(max(half_width_px, half_length_px))) + 2
	var min_x: int = clampi(int(floor(canvas_position.x)) - bounds_radius, 0, safe_resolution.x - 1)
	var max_x: int = clampi(int(ceil(canvas_position.x)) + bounds_radius, 0, safe_resolution.x - 1)
	var min_y: int = clampi(int(floor(canvas_position.y)) - bounds_radius, 0, safe_resolution.y - 1)
	var max_y: int = clampi(int(ceil(canvas_position.y)) + bounds_radius, 0, safe_resolution.y - 1)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sample_point: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var offset: Vector2 = sample_point - canvas_position
			var along: float = offset.dot(safe_direction) / half_length_px
			var lateral: float = offset.dot(lateral_axis) / half_width_px
			var ellipse_distance: float = (along * along) + (lateral * lateral)
			if ellipse_distance > 1.0:
				continue
			var falloff: float = pow(1.0 - ellipse_distance, 1.35)
			var index: int = y * safe_resolution.x + x
			var previous_value: float = _field_values[index]
			var next_value: float = clamp(previous_value + (strength * falloff), 0.0, 1.0)
			if is_equal_approx(next_value, previous_value):
				continue
			_field_values[index] = next_value
			if previous_value <= 0.0 and next_value > 0.0 and _active_field_lookup[index] == 0:
				_active_field_lookup[index] = 1
				_active_field_indices.append(index)
			_mark_dirty_pixel(x, y)

func _sample_field(canvas_position: Vector2) -> float:
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var x: int = clampi(int(round(canvas_position.x)), 0, safe_resolution.x - 1)
	var y: int = clampi(int(round(canvas_position.y)), 0, safe_resolution.y - 1)
	return _field_values[y * safe_resolution.x + x]

func _decay_field(delta: float) -> void:
	var decay_amount: float = decay_rate * delta
	if decay_amount <= 0.0:
		return
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var surviving_indices: Array[int] = []
	surviving_indices.resize(_active_field_indices.size())
	var survivor_count: int = 0
	for index: int in _active_field_indices:
		var value: float = _field_values[index]
		if value <= 0.0:
			_active_field_lookup[index] = 0
			continue
		var next_value: float = max(value - decay_amount, 0.0)
		if not is_equal_approx(next_value, value):
			_field_values[index] = next_value
			var y: int = floori(float(index) / float(safe_resolution.x))
			var x: int = index - (y * safe_resolution.x)
			_mark_dirty_pixel(x, y)
		if next_value <= 0.0:
			_active_field_lookup[index] = 0
			continue
		surviving_indices[survivor_count] = index
		survivor_count += 1
	surviving_indices.resize(survivor_count)
	_active_field_indices = surviving_indices

func _upload_field_debug_texture() -> void:
	if _field_image == null or _field_texture == null:
		return
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var min_x: int = clampi(_dirty_min.x, 0, safe_resolution.x - 1)
	var min_y: int = clampi(_dirty_min.y, 0, safe_resolution.y - 1)
	var max_x: int = clampi(_dirty_max.x, 0, safe_resolution.x - 1)
	var max_y: int = clampi(_dirty_max.y, 0, safe_resolution.y - 1)
	_write_field_image_rect(min_x, min_y, max_x, max_y)
	_field_texture.update(_field_image)
	_field_dirty = false
	_texture_upload_elapsed = 0.0
	_update_processing_state()

func _update_processing_state() -> void:
	var needs_decay: bool = decay_rate > 0.0 and not _active_field_indices.is_empty()
	set_process(needs_decay or _field_dirty or _recenter_cooldown_remaining > 0.0)

func _write_field_image_rect(min_x: int, min_y: int, max_x: int, max_y: int) -> void:
	if _field_image == null:
		return
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var value: float = _field_values[y * safe_resolution.x + x]
			_field_image.set_pixel(x, y, Color(value, value, value, value))

func _mark_dirty_pixel(x: int, y: int) -> void:
	var pixel: Vector2i = Vector2i(x, y)
	if not _field_dirty:
		_dirty_min = pixel
		_dirty_max = pixel
		_field_dirty = true
		return
	_dirty_min.x = mini(_dirty_min.x, pixel.x)
	_dirty_min.y = mini(_dirty_min.y, pixel.y)
	_dirty_max.x = maxi(_dirty_max.x, pixel.x)
	_dirty_max.y = maxi(_dirty_max.y, pixel.y)

func _begin_new_move_style(move_direction: Vector2) -> void:
	var safe_direction: Vector2 = move_direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		safe_direction = Vector2.DOWN
	_active_move_width_multiplier = randf_range(1.0 - width_randomness, 1.0 + width_randomness)
	_width_variation_phase = randf_range(-PI, PI)
	_lateral_jitter_offset = 0.0
	_previous_stamp_direction = safe_direction

func _next_width_multiplier(speed: float, turn_amount: float) -> float:
	var random_range: float = clamp(width_randomness, 0.0, 1.0)
	_width_variation_phase += 0.18 + min(max(speed, 0.0) * 0.015, 0.18) + (turn_amount * 0.12)
	var wave_a: float = sin(_width_variation_phase)
	var wave_b: float = sin((_width_variation_phase * 0.47) + 1.7)
	var coherent_variation: float = (wave_a * 0.7) + (wave_b * 0.3)
	var multiplier: float = _active_move_width_multiplier * (1.0 + (coherent_variation * random_range))
	return max(multiplier, 0.15)

func _next_lateral_jitter_offset() -> float:
	if not lateral_jitter_enabled:
		_lateral_jitter_offset = 0.0
		return 0.0
	var max_offset: float = max(lateral_jitter_max_offset, 0.0)
	var step: float = max(lateral_jitter_step, 0.0)
	if max_offset <= 0.0 or step <= 0.0:
		_lateral_jitter_offset = 0.0
		return 0.0
	var center_chance: float = max(lateral_jitter_center_chance, 0.0)
	var hold_chance: float = max(lateral_jitter_hold_chance, 0.0)
	var outward_chance: float = max(lateral_jitter_outward_chance, 0.0)
	var total_chance: float = center_chance + hold_chance + outward_chance
	if total_chance <= 0.0:
		return _lateral_jitter_offset

	var roll: float = randf() * total_chance
	if roll < center_chance:
		_lateral_jitter_offset = move_toward(_lateral_jitter_offset, 0.0, step)
	elif roll < center_chance + hold_chance:
		pass
	else:
		var side: float = signf(_lateral_jitter_offset)
		if is_zero_approx(side):
			side = -1.0 if randf() < 0.5 else 1.0
		_lateral_jitter_offset = clamp(_lateral_jitter_offset + (side * step), -max_offset, max_offset)
	return _lateral_jitter_offset

func _is_inside_canvas(canvas_position: Vector2) -> bool:
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	return canvas_position.x >= 0.0 and canvas_position.y >= 0.0 and canvas_position.x <= float(safe_resolution.x) and canvas_position.y <= float(safe_resolution.y)

func _cross_scalar(a: Vector2, b: Vector2) -> float:
	return (a.x * b.y) - (a.y * b.x)

func _world_to_canvas_distance(world_distance: float) -> float:
	var safe_world_size: Vector2 = _get_safe_canvas_world_size()
	var safe_resolution: Vector2i = _get_safe_canvas_resolution()
	var pixels_per_world_x: float = float(safe_resolution.x) / safe_world_size.x
	var pixels_per_world_y: float = float(safe_resolution.y) / safe_world_size.y
	return world_distance * ((pixels_per_world_x + pixels_per_world_y) * 0.5)

func _get_safe_canvas_resolution() -> Vector2i:
	return Vector2i(
		maxi(canvas_resolution.x, 64),
		maxi(canvas_resolution.y, 64)
	)

func _get_safe_canvas_world_size() -> Vector2:
	return Vector2(
		max(canvas_world_size.x, 128.0),
		max(canvas_world_size.y, 128.0)
	)
