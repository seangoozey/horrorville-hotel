# res://scripts/gameplay/SlimeBody.gd
extends CharacterBody2D
class_name SlimeBody

signal location_changed()
signal death_animation_completed()

const SLIME_POOL_RIPPLE_SCRIPT := preload("res://scripts/gameplay/SlimePoolRipple.gd")
const SLIME_TRAIL_MANAGER_SCRIPT := preload("res://scripts/gameplay/SlimeTrailManager.gd")
const SLIME_TRAIL_EMITTER_SCRIPT := preload("res://scripts/gameplay/SlimeTrailEmitter.gd")

@export_category("General")
# The scene-layer bucket the slime currently belongs to for layering and gameplay checks.
@export var current_location: LayerController.ViewLayer = LayerController.ViewLayer.EXTERIOR
# Optional override path to the animated slime sprite node.
@export var sprite_path: NodePath
# Optional sprite revealed after the slime's death animation completes.
@export var slime_spray_sprite_path: NodePath = NodePath("SlimeSpraySprite")
# Circle collision used by the slime. Its radius is adjusted by pursuit state.
@export var collision_shape_path: NodePath = NodePath("SlimeBlobCollision")
# Circle collision radius used outside active follow movement.
@export var default_collision_radius := 12.0
# Circle collision radius used while the slime is raised and following a target.
@export var follow_collision_radius := 16.0
# Minimum movement magnitude required before movement/facing animations should play.
@export var animation_stop_speed := 0.1
@export var slime_creep_audio_path: NodePath = NodePath("SlimeCreepAudio")
@export var slime_creep_water_audio_path: NodePath = NodePath("SlimeCreepWaterAudio")
@export var slime_hiss_audio_path: NodePath = NodePath("SlimeHissAudio")
@export var slime_death_audio_path: NodePath = NodePath("SlimeDeathAudio")

@export_category("Gas Spill Ripples")
# How long each in-pool ripple remains visible before fully fading out.
@export var gas_spill_ripple_fade_duration := 1.15
# Number of ripple pulses spawned each time the slime starts moving in the pool.
@export var gas_spill_ripple_count := 4
# Delay in seconds between successive ripple pulses in one burst.
@export var gas_spill_ripple_stagger_seconds := 0.08
# Starting size multiplier applied to each pool ripple relative to the slime frame.
@export var gas_spill_ripple_scale_multiplier := 1.6
# Controls how quickly each pool ripple expands over its lifetime.
@export var gas_spill_ripple_scale_speed := 1.0
# Overall visual strength of the pool ripple effect.
@export_range(0.0, 1.0, 0.01) var gas_spill_ripple_intensity := 0.26
# Seconds between ripple shader uniform updates; higher values reduce long-lived ripple CPU cost.
@export var gas_spill_ripple_update_interval := 0.033

@export_category("Slime Trail")
# Minimum speed required before the outside-pool residue trail should emit.
@export var slime_trail_speed_threshold := 2.0
# World-space area covered by the persistent trail field.
@export var slime_trail_canvas_world_size: Vector2 = Vector2(720.0, 720.0)
# Pixel resolution of the debug field texture. Keep modest while iterating on the CPU field.
@export var slime_trail_canvas_resolution: Vector2i = Vector2i(256, 256)
# Recenter the trail canvas when the deposit point enters this normalized edge margin.
@export_range(0.05, 0.45, 0.01) var slime_trail_recenter_margin_ratio := 0.22
# World distance between deposited trail field samples.
@export var slime_trail_stamp_spacing := 8.0
# Base width of each deposited trail field sample.
@export var slime_trail_base_width := 20.0
# Random width variation applied to deposited trail field samples.
@export_range(0.0, 1.0, 0.01) var slime_trail_width_randomness := 0.24
# Field sample stretch multiplier derived from movement speed.
@export var slime_trail_stretch_from_speed := 0.032
# Maximum length multiplier for each field sample, guarding against deposit contact-point jumps.
@export var slime_trail_max_stretch_multiplier := 1.35
# Length of each field sample along movement as a ratio of its lateral width.
@export_range(0.1, 1.5, 0.01) var slime_trail_field_footprint_length_ratio := 0.45
# Stateful lateral offset that makes field deposits asymmetrical around the movement centerline.
@export var slime_trail_lateral_jitter_enabled := true
# Maximum world-space distance the field deposit center can drift sideways from the movement centerline.
@export var slime_trail_lateral_jitter_max_offset := 12.0
# World-space amount the lateral jitter changes per field sample.
@export var slime_trail_lateral_jitter_step := 3.0
# Relative chance each field sample moves its lateral offset back toward the centerline.
@export_range(0.0, 1.0, 0.01) var slime_trail_lateral_jitter_center_chance := 0.62
# Relative chance each field sample keeps its current lateral offset.
@export_range(0.0, 1.0, 0.01) var slime_trail_lateral_jitter_hold_chance := 0.25
# Relative chance each field sample pushes farther outward on its current side.
@export_range(0.0, 1.0, 0.01) var slime_trail_lateral_jitter_outward_chance := 0.13
# Extra pooling width applied when the slime turns sharply.
@export var slime_trail_turn_pooling_multiplier := 1.5
# Maximum turn amount allowed to widen turn pooling.
@export_range(0.0, 1.0, 0.01) var slime_trail_max_turn_pooling_amount := 0.45
# Chance for detached droplets to appear beside a deposited stamp.
@export_range(0.0, 1.0, 0.01) var slime_trail_droplet_chance := 0.12
# Per-second alpha decay for deposited stamps. Zero keeps the trail persistent.
@export var slime_trail_decay_rate := 0.0
# Seconds between decay passes; higher values reduce CPU scans while preserving total decay over time.
@export var slime_trail_decay_update_interval := 0.1
# Field amount added by each sampled trail deposit.
@export var slime_trail_field_deposit_strength := 0.28
# How strongly repeated passes through an existing trail area widen the pooled field.
@export var slime_trail_field_repeat_pool_growth := 1.15
# Small shader blur radius for smoothing single-pixel field artifacts without CPU texture filtering.
@export_range(0, 2, 1) var slime_trail_field_upload_blur_radius: int = 0
# Applies active AlphaMaskArea masks to the rendered trail shader. This only
# affects display alpha; the persistent field data remains unchanged.
@export var slime_trail_alpha_mask_enabled := true
# Keeps the last trail mask active after the slime exits the trigger, so
# persistent trail residue does not pop in front of the masked object.
@export var slime_trail_alpha_mask_lingers_after_exit := true
# Seconds between field texture uploads while dirty; zero uploads every frame.
@export var slime_trail_texture_upload_interval := 0.033
# Minimum seconds between floating-canvas recenter operations.
@export var slime_trail_recenter_cooldown := 0.08
# Checked keeps the temporary field visualization above the slime; unchecked draws it beneath the slime over the outside art.
@export var slime_trail_visualization_debug := true
# Dark base color used by the cartoon oil trail shader.
@export var slime_trail_dark_oil_color: Color = Color(0.11, 0.055, 0.025, 1.0)
# Lighter streak color blended into the cartoon oil trail shader.
@export var slime_trail_light_oil_color: Color = Color(0.48, 0.28, 0.11, 1.0)
# Debug field value threshold used by SlimeTrailManager's temporary visualization shader.
@export_range(0.0, 1.0, 0.001) var slime_trail_field_debug_threshold := 0.08
# Debug visualization edge softness used by the temporary field shader.
@export_range(0.0, 1.0, 0.001) var slime_trail_field_debug_edge_softness := 0.08

@export_category("Slime Trail Deposit Offsets")
@export var slime_trail_auto_detect_deposit_offsets := false
@export_range(0.0, 1.0, 0.001) var slime_trail_deposit_alpha_threshold := 0.05
@export var slime_trail_deposit_edge_band_pixels := 3.0
# Keeps contact placement stable when visual trail width changes. The inward
# ratio is evaluated against this reference width instead of base_width.
@export var slime_trail_deposit_inward_reference_width := 30.0
@export var slime_trail_deposit_inward_short_radius_ratio := 4.0
# Source-sprite pixel offsets from SlimeSprite's origin to the trail contact point for each directional animation.
@export var slime_trail_deposit_offset_down: Vector2 = Vector2(98.0, -76.0)
@export var slime_trail_deposit_offset_up: Vector2 = Vector2(-106.0, 65.0)
@export var slime_trail_deposit_offset_left: Vector2 = Vector2(102.0, 79.0)
@export var slime_trail_deposit_offset_right: Vector2 = Vector2(-89.0, -112.0)
@export var slime_trail_deposit_offset_down_left: Vector2 = Vector2(145.0, 0.0)
@export var slime_trail_deposit_offset_down_right: Vector2 = Vector2(11.0, -141.0)
@export var slime_trail_deposit_offset_up_left: Vector2 = Vector2(7.0, 106.0)
@export var slime_trail_deposit_offset_up_right: Vector2 = Vector2(-140.0, -27.0)

@export_category("")
var _elevation_sources: Dictionary = {}
var _elevation_visual_bases: Dictionary = {}
var _elevation_offset_y := 0.0
var _engaged := false
var _transition_state := ""
var _pool_turn_state := ""
var _facing_animation_prefix := "down"
var _pending_pool_turn_prefix := ""
var _gas_spill_active: bool = false
var _gas_spill_trigger_polygon: CollisionPolygon2D
var _slime_effect_layer: Node2D
var _slime_effect_layer_pending: bool = false
var _slime_trail_manager: SlimeTrailManager
var _slime_trail_emitter: SlimeTrailEmitter
var _auto_slime_trail_deposit_offsets: Dictionary = {}
var _slime_trail_manager_configured: bool = false
var _slime_trail_mask_payloads: Dictionary = {}
var _slime_trail_lingering_mask_payload: Dictionary = {}
var _pending_gas_spill_ripple_delays: Array[float] = []
var _pending_gas_spill_ripple_direction: Vector2 = Vector2.ZERO
var _quality_performance_values: Dictionary = {}
var _slime_visual_effects_enabled := true
var _dead := false
@onready var _sprite: AnimatedSprite2D = _resolve_sprite()
@onready var _collision_shape: CollisionShape2D = _resolve_collision_shape()
@onready var _slime_spray_sprite: CanvasItem = _resolve_slime_spray_sprite()
@onready var _slime_creep_audio: AudioStreamPlayer2D = _resolve_audio_player(slime_creep_audio_path)
@onready var _slime_creep_water_audio: AudioStreamPlayer2D = _resolve_audio_player(slime_creep_water_audio_path)
@onready var _slime_hiss_audio: AudioStreamPlayer2D = _resolve_audio_player(slime_hiss_audio_path)
@onready var _slime_death_audio: AudioStreamPlayer2D = _resolve_audio_player(slime_death_audio_path)

func _ready() -> void:
	add_to_group(&"death_occluder")
	add_to_group(&"performance_slime")
	_capture_quality_performance_values()
	apply_performance_preset(SettingsManager.performance_preset)
	_ensure_slime_effect_layer()
	_cache_elevation_visuals()
	_apply_elevation_visual_offset()
	set_process(false)
	if _slime_spray_sprite != null:
		_slime_spray_sprite.visible = false
	if _sprite and not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	if _sprite:
		_sync_facing_prefix_from_current_animation()
		if slime_trail_auto_detect_deposit_offsets:
			_rebuild_auto_slime_trail_deposit_offsets()
	_refresh_collision_radius()

func _process(delta: float) -> void:
	if _pending_gas_spill_ripple_delays.is_empty():
		set_process(false)
		return
	for i in range(_pending_gas_spill_ripple_delays.size() - 1, -1, -1):
		var next_delay: float = _pending_gas_spill_ripple_delays[i] - delta
		if next_delay > 0.0:
			_pending_gas_spill_ripple_delays[i] = next_delay
			continue
		_pending_gas_spill_ripple_delays.remove_at(i)
		_spawn_gas_spill_ripple(_pending_gas_spill_ripple_direction)
	if _pending_gas_spill_ripple_delays.is_empty():
		set_process(false)

func _set_location(layer: LayerController.ViewLayer) -> void:
	if current_location == layer:
		return
	current_location = layer
	location_changed.emit()

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

func update_movement_animation(direction: Vector2) -> void:
	if _sprite == null:
		return
	if _dead:
		return
	if _pool_turn_state != "":
		return
	if _transition_state == "lowering":
		return
	if _engaged:
		return
	var stop_speed_sq: float = animation_stop_speed * animation_stop_speed
	if direction.length_squared() <= stop_speed_sq:
		_sprite.stop()
		return

	var normalized_direction: Vector2 = direction.normalized()
	_facing_animation_prefix = _dir_to_animation_prefix(normalized_direction)
	_update_slime_trail_move_direction(normalized_direction)
	var anim := _dir_to_walk_animation(normalized_direction)
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
	_refresh_collision_radius()

func prepare_move_start(direction: Vector2) -> bool:
	if _sprite == null:
		return false
	if _dead:
		return false
	if _engaged:
		return false
	if _pool_turn_state != "":
		return true
	var stop_speed_sq: float = animation_stop_speed * animation_stop_speed
	if direction.length_squared() <= stop_speed_sq:
		return false
	var next_prefix: String = _dir_to_animation_prefix(direction.normalized())
	if next_prefix == _facing_animation_prefix:
		return false
	var current_pool_animation: String = "%s_pool" % _facing_animation_prefix
	var next_pool_animation: String = "%s_pool" % next_prefix
	if not _has_animation(current_pool_animation) or not _has_animation(next_pool_animation):
		_facing_animation_prefix = next_prefix
		return false
	_pending_pool_turn_prefix = next_prefix
	_pool_turn_state = "leaving_current"
	_play_animation_from_start(current_pool_animation)
	return true

func is_pool_turn_locked() -> bool:
	return _pool_turn_state != ""

func set_engaged_direction(direction: Vector2) -> void:
	if _sprite == null:
		return
	if _dead:
		return
	_cancel_pool_turn()
	var stop_speed_sq: float = animation_stop_speed * animation_stop_speed
	if direction.length_squared() > stop_speed_sq:
		_facing_animation_prefix = _dir_to_animation_prefix(direction.normalized())
	if _engaged and _transition_state != "lowering":
		return
	_engaged = true
	_transition_state = "raising"
	_refresh_collision_radius()
	_play_audio(_slime_hiss_audio)
	_play_animation("%s_raise" % _facing_animation_prefix)

func clear_engaged_direction(direction: Vector2 = Vector2.ZERO) -> void:
	if _sprite == null:
		return
	if _dead:
		return
	_cancel_pool_turn()
	var stop_speed_sq: float = animation_stop_speed * animation_stop_speed
	if direction.length_squared() > stop_speed_sq:
		_facing_animation_prefix = _dir_to_animation_prefix(direction.normalized())
	if not _engaged and _transition_state != "raised":
		return
	_engaged = false
	_transition_state = "lowering"
	_refresh_collision_radius()
	_play_animation_backwards("%s_raise" % _facing_animation_prefix)

func is_raise_locked() -> bool:
	return _transition_state == "raising"

func update_engaged_animation(direction: Vector2) -> void:
	if _sprite == null:
		return
	if _dead:
		return
	if not _engaged:
		return
	if _transition_state == "raising" or _transition_state == "lowering":
		return
	var stop_speed_sq: float = animation_stop_speed * animation_stop_speed
	if direction.length_squared() > stop_speed_sq:
		_facing_animation_prefix = _dir_to_animation_prefix(direction.normalized())
		_update_slime_trail_move_direction(direction.normalized())
	_play_animation("%s_follow" % _facing_animation_prefix)
	_refresh_collision_radius()

func _resolve_sprite() -> AnimatedSprite2D:
	if sprite_path != NodePath(""):
		var node := get_node_or_null(sprite_path)
		if node is AnimatedSprite2D:
			return node
	var fallback := get_node_or_null("SlimeSprite")
	if fallback is AnimatedSprite2D:
		return fallback
	return null

func _resolve_collision_shape() -> CollisionShape2D:
	var node: Node = get_node_or_null(collision_shape_path)
	if node is CollisionShape2D:
		var shape_node := node as CollisionShape2D
		if shape_node.shape != null:
			shape_node.shape = shape_node.shape.duplicate() as Shape2D
		return shape_node
	return null

func _refresh_collision_radius() -> void:
	if _collision_shape == null:
		return
	var circle_shape := _collision_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	circle_shape.radius = follow_collision_radius if _uses_follow_collision_radius() else default_collision_radius

func _uses_follow_collision_radius() -> bool:
	if _dead:
		return false
	if not _engaged:
		return false
	if _transition_state == "raised":
		return true
	return _sprite != null and String(_sprite.animation).ends_with("_follow")

func _resolve_slime_spray_sprite() -> CanvasItem:
	if slime_spray_sprite_path != NodePath(""):
		return get_node_or_null(slime_spray_sprite_path) as CanvasItem
	var fallback := get_node_or_null("SlimeSpraySprite")
	return fallback as CanvasItem

func _resolve_audio_player(path: NodePath) -> AudioStreamPlayer2D:
	if path == NodePath(""):
		return null
	var node: Node = get_node_or_null(path)
	if node is AudioStreamPlayer2D:
		var player: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		player.bus = &"SFX"
		return player
	return null

func _play_audio(player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()

func play_death_animation() -> void:
	if _dead:
		return
	_dead = true
	_play_audio(_slime_death_audio)
	velocity = Vector2.ZERO
	_cancel_pool_turn()
	_engaged = false
	_transition_state = "dying"
	_refresh_collision_radius()
	_pending_gas_spill_ripple_delays.clear()
	_pending_gas_spill_ripple_direction = Vector2.ZERO
	if _slime_trail_emitter != null:
		_slime_trail_emitter.enabled = false
		_slime_trail_emitter.record_motion(global_position, true)
	if _slime_spray_sprite != null:
		_slime_spray_sprite.visible = false
	if _sprite == null:
		call_deferred("_complete_death_animation")
		return
	_sprite.visible = true
	var death_animation: String = _get_death_animation_name()
	if _has_animation(death_animation):
		_play_animation_from_start(death_animation)
	else:
		call_deferred("_complete_death_animation")

func is_dead() -> bool:
	return _dead

func _get_death_animation_name() -> String:
	if _is_facing_left_for_death():
		return "left_die"
	return "right_die"

func _is_facing_left_for_death() -> bool:
	if _facing_animation_prefix.find("left") != -1:
		return true
	if _facing_animation_prefix.find("right") != -1:
		return false
	if absf(velocity.x) > animation_stop_speed:
		return velocity.x < 0.0
	return false

func _reveal_slime_spray() -> void:
	if _slime_spray_sprite != null:
		_slime_spray_sprite.visible = true

func _complete_death_animation() -> void:
	if _transition_state == "dead":
		return
	_transition_state = "dead"
	_reveal_slime_spray()
	death_animation_completed.emit()

func _sync_facing_prefix_from_current_animation() -> void:
	if _sprite == null:
		return
	var animation_name: String = String(_sprite.animation)
	var suffixes: Array[String] = ["_walk", "_follow", "_raise", "_pool"]
	for suffix: String in suffixes:
		if animation_name.ends_with(suffix):
			var candidate_prefix: String = animation_name.substr(0, animation_name.length() - suffix.length())
			if _is_animation_prefix(candidate_prefix):
				_facing_animation_prefix = candidate_prefix
			return
	if _is_animation_prefix(animation_name):
		_facing_animation_prefix = animation_name

func _is_animation_prefix(prefix: String) -> bool:
	match prefix:
		"down", "up", "left", "right", "down_left", "down_right", "up_left", "up_right":
			return true
		_:
			return false

func _get_slime_trail_deposit_offset_for_prefix(prefix: String) -> Vector2:
	if slime_trail_auto_detect_deposit_offsets:
		var auto_offset: Variant = _auto_slime_trail_deposit_offsets.get(prefix, null)
		if auto_offset is Vector2:
			return auto_offset as Vector2
	match prefix:
		"down":
			return slime_trail_deposit_offset_down
		"up":
			return slime_trail_deposit_offset_up
		"left":
			return slime_trail_deposit_offset_left
		"right":
			return slime_trail_deposit_offset_right
		"down_left":
			return slime_trail_deposit_offset_down_left
		"down_right":
			return slime_trail_deposit_offset_down_right
		"up_left":
			return slime_trail_deposit_offset_up_left
		"up_right":
			return slime_trail_deposit_offset_up_right
		_:
			return slime_trail_deposit_offset_down

func get_slime_trail_deposit_position(move_direction: Vector2) -> Vector2:
	if _sprite == null:
		return global_position
	if move_direction.length_squared() <= 0.0001:
		return global_position
	var prefix: String = _dir_to_animation_prefix(move_direction.normalized())
	var source_pixel_offset: Vector2 = _get_slime_trail_deposit_offset_for_prefix(prefix)
	source_pixel_offset = _apply_slime_trail_inward_offset(source_pixel_offset)
	return _sprite.to_global(source_pixel_offset)

func set_slime_trail_alpha_mask(area_id: int, payload: Dictionary) -> void:
	_slime_trail_mask_payloads[area_id] = payload.duplicate()
	_slime_trail_lingering_mask_payload = payload.duplicate()
	_sync_slime_trail_alpha_mask()

func clear_slime_trail_alpha_mask(area_id: int) -> void:
	if not _slime_trail_mask_payloads.has(area_id):
		return
	_slime_trail_mask_payloads.erase(area_id)
	_sync_slime_trail_alpha_mask()

func _rebuild_auto_slime_trail_deposit_offsets() -> void:
	_auto_slime_trail_deposit_offsets.clear()
	if not slime_trail_auto_detect_deposit_offsets:
		return
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var prefixes: Array[String] = [
		"down",
		"down_right",
		"right",
		"up_right",
		"up",
		"up_left",
		"left",
		"down_left",
	]
	for prefix: String in prefixes:
		var offset: Vector2 = _analyze_slime_trail_deposit_offset(prefix)
		if offset != Vector2.INF:
			_auto_slime_trail_deposit_offsets[prefix] = offset

func _analyze_slime_trail_deposit_offset(prefix: String) -> Vector2:
	if _sprite == null or _sprite.sprite_frames == null:
		return Vector2.INF
	var animation_name: String = "%s_walk" % prefix
	if not _sprite.sprite_frames.has_animation(animation_name):
		animation_name = "%s_pool" % prefix
	if not _sprite.sprite_frames.has_animation(animation_name):
		return Vector2.INF
	if _sprite.sprite_frames.get_frame_count(animation_name) <= 0:
		return Vector2.INF
	var frame_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return Vector2.INF
	var frame_image: Image = _get_frame_image(frame_texture)
	if frame_image == null or frame_image.is_empty():
		return Vector2.INF

	var back_direction: Vector2 = _get_slime_trail_back_direction_for_prefix(prefix)
	if back_direction.length_squared() <= 0.0001:
		return Vector2.INF
	var best_projection: float = -INF
	var width: int = frame_image.get_width()
	var height: int = frame_image.get_height()
	for y in range(height):
		for x in range(width):
			if frame_image.get_pixel(x, y).a < slime_trail_deposit_alpha_threshold:
				continue
			var local_position: Vector2 = _frame_pixel_to_sprite_local(Vector2(float(x) + 0.5, float(y) + 0.5), width, height)
			best_projection = max(best_projection, local_position.dot(back_direction))
	if best_projection == -INF:
		return Vector2.INF

	var edge_sum: Vector2 = Vector2.ZERO
	var edge_count: int = 0
	var edge_band: float = max(slime_trail_deposit_edge_band_pixels, 0.0)
	for y in range(height):
		for x in range(width):
			if frame_image.get_pixel(x, y).a < slime_trail_deposit_alpha_threshold:
				continue
			var local_position: Vector2 = _frame_pixel_to_sprite_local(Vector2(float(x) + 0.5, float(y) + 0.5), width, height)
			if best_projection - local_position.dot(back_direction) > edge_band:
				continue
			edge_sum += local_position
			edge_count += 1
	if edge_count <= 0:
		return Vector2.INF

	var edge_offset: Vector2 = edge_sum / float(edge_count)
	return edge_offset

func _apply_slime_trail_inward_offset(source_pixel_offset: Vector2) -> Vector2:
	if source_pixel_offset.length_squared() <= 0.0001:
		return source_pixel_offset
	var inward_distance: float = _get_slime_trail_short_radius_source_pixels() * slime_trail_deposit_inward_short_radius_ratio
	return source_pixel_offset.move_toward(Vector2.ZERO, inward_distance)

func _get_frame_image(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		var atlas_image: Image = atlas_texture.atlas.get_image()
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region: Rect2 = atlas_texture.region
		var region_rect: Rect2i = Rect2i(
			Vector2i(int(round(region.position.x)), int(round(region.position.y))),
			Vector2i(int(round(region.size.x)), int(round(region.size.y)))
		)
		var image: Image = Image.create(region_rect.size.x, region_rect.size.y, false, Image.FORMAT_RGBA8)
		image.blit_rect(atlas_image, region_rect, Vector2i.ZERO)
		return image
	return texture.get_image()

func _frame_pixel_to_sprite_local(pixel_position: Vector2, frame_width: int, frame_height: int) -> Vector2:
	var local_position: Vector2 = pixel_position
	if _sprite != null and _sprite.centered:
		local_position -= Vector2(float(frame_width), float(frame_height)) * 0.5
	if _sprite != null:
		local_position += _sprite.offset
	return local_position

func _get_slime_trail_back_direction_for_prefix(prefix: String) -> Vector2:
	match prefix:
		"down":
			return Vector2(1.0, -1.0).normalized()
		"down_right":
			return Vector2.UP
		"right":
			return Vector2(-1.0, -1.0).normalized()
		"up_right":
			return Vector2.LEFT
		"up":
			return Vector2(-1.0, 1.0).normalized()
		"up_left":
			return Vector2.DOWN
		"left":
			return Vector2(1.0, 1.0).normalized()
		"down_left":
			return Vector2.RIGHT
		_:
			return Vector2.ZERO

func _get_slime_trail_short_radius_source_pixels() -> float:
	if _sprite == null:
		return 0.0
	var scale_x: float = _sprite.global_transform.x.length()
	var scale_y: float = _sprite.global_transform.y.length()
	var average_scale: float = max((scale_x + scale_y) * 0.5, 0.001)
	var reference_width: float = max(slime_trail_deposit_inward_reference_width, 0.0)
	var short_radius_world: float = reference_width * 0.5 * min(slime_trail_field_footprint_length_ratio, 1.0)
	return short_radius_world / average_scale

func set_gas_spill_surface_active(active: bool) -> void:
	if _gas_spill_active == active:
		return
	_gas_spill_active = active
	if not active:
		_pending_gas_spill_ripple_delays.clear()
		_pending_gas_spill_ripple_direction = Vector2.ZERO
	if _slime_trail_emitter != null:
		_slime_trail_emitter.enabled = _slime_visual_effects_enabled and not active
		_slime_trail_emitter.record_motion(global_position, true)

func set_gas_spill_trigger_polygon(trigger_polygon: CollisionPolygon2D) -> void:
	_gas_spill_trigger_polygon = trigger_polygon

func notify_move_started(direction: Vector2) -> void:
	if direction.length_squared() <= 0.0001:
		return
	if _gas_spill_active:
		_play_audio(_slime_creep_water_audio)
		_spawn_gas_spill_ripple_burst(direction.normalized())
		return
	_play_audio(_slime_creep_audio)
	if not _slime_visual_effects_enabled:
		return
	_ensure_slime_trail_system(true)
	if _slime_trail_emitter != null:
		_slime_trail_emitter.enabled = true
		_slime_trail_emitter.begin_move(direction.normalized())

func _spawn_gas_spill_ripple_burst(direction: Vector2) -> void:
	if not _slime_visual_effects_enabled or _sprite == null or _gas_spill_trigger_polygon == null:
		return
	_pending_gas_spill_ripple_delays.clear()
	_pending_gas_spill_ripple_direction = direction
	_spawn_gas_spill_ripple(direction)
	var ripple_count: int = max(gas_spill_ripple_count, 1)
	for pulse_index in range(1, ripple_count):
		_pending_gas_spill_ripple_delays.append(float(pulse_index) * gas_spill_ripple_stagger_seconds)
	if not _pending_gas_spill_ripple_delays.is_empty():
		set_process(true)

func _spawn_gas_spill_ripple(direction: Vector2 = Vector2.ZERO) -> void:
	if not _slime_visual_effects_enabled or not _gas_spill_active or _sprite == null or _gas_spill_trigger_polygon == null:
		return
	if _slime_effect_layer == null:
		_ensure_slime_effect_layer()
	if _slime_effect_layer == null:
		return
	var ripple = SLIME_POOL_RIPPLE_SCRIPT.new()
	_slime_effect_layer.add_child(ripple)
	ripple.configure_from_sprite(
		_sprite,
		_gas_spill_trigger_polygon,
		gas_spill_ripple_fade_duration,
		gas_spill_ripple_scale_multiplier,
		gas_spill_ripple_scale_speed,
		gas_spill_ripple_intensity,
		direction,
		gas_spill_ripple_update_interval
	)

func _ensure_slime_trail_system(refresh_configuration: bool = false) -> void:
	if not _slime_visual_effects_enabled:
		return
	if _slime_effect_layer == null:
		_ensure_slime_effect_layer()
	if _slime_effect_layer == null:
		return
	if _slime_trail_manager == null or not is_instance_valid(_slime_trail_manager):
		var existing_manager: Node = _slime_effect_layer.get_node_or_null("SlimeTrailManager")
		if existing_manager is SlimeTrailManager:
			_slime_trail_manager = existing_manager as SlimeTrailManager
		else:
			var manager_node: SlimeTrailManager = SLIME_TRAIL_MANAGER_SCRIPT.new() as SlimeTrailManager
			_slime_trail_manager = manager_node
			_slime_trail_manager_configured = false
			manager_node.name = "SlimeTrailManager"
			_slime_effect_layer.add_child(manager_node)
			manager_node.global_position = global_position
			manager_node.owner = _slime_effect_layer.owner
	if _slime_trail_manager != null and (refresh_configuration or not _slime_trail_manager_configured):
		_configure_slime_trail_manager()
	if _slime_trail_emitter == null or not is_instance_valid(_slime_trail_emitter):
		var existing_emitter: Node = get_node_or_null("SlimeTrailEmitter")
		if existing_emitter is SlimeTrailEmitter:
			_slime_trail_emitter = existing_emitter as SlimeTrailEmitter
		else:
			var emitter_node: SlimeTrailEmitter = SLIME_TRAIL_EMITTER_SCRIPT.new() as SlimeTrailEmitter
			_slime_trail_emitter = emitter_node
			emitter_node.name = "SlimeTrailEmitter"
			add_child(emitter_node)
			emitter_node.owner = owner
	_slime_trail_emitter.manager = _slime_trail_manager
	if _slime_trail_emitter.source_body != self:
		_slime_trail_emitter.set_source_body(self)

func _configure_slime_trail_manager() -> void:
	if _slime_trail_manager == null:
		return
	_slime_trail_manager.canvas_world_size = slime_trail_canvas_world_size
	_slime_trail_manager.canvas_resolution = slime_trail_canvas_resolution
	_slime_trail_manager.recenter_margin_ratio = slime_trail_recenter_margin_ratio
	_slime_trail_manager.stamp_spacing = slime_trail_stamp_spacing
	_slime_trail_manager.base_width = slime_trail_base_width
	_slime_trail_manager.width_randomness = slime_trail_width_randomness
	_slime_trail_manager.stretch_from_speed = slime_trail_stretch_from_speed
	_slime_trail_manager.max_stretch_multiplier = slime_trail_max_stretch_multiplier
	_slime_trail_manager.field_footprint_length_ratio = slime_trail_field_footprint_length_ratio
	_slime_trail_manager.lateral_jitter_enabled = slime_trail_lateral_jitter_enabled
	_slime_trail_manager.lateral_jitter_max_offset = slime_trail_lateral_jitter_max_offset
	_slime_trail_manager.lateral_jitter_step = slime_trail_lateral_jitter_step
	_slime_trail_manager.lateral_jitter_center_chance = slime_trail_lateral_jitter_center_chance
	_slime_trail_manager.lateral_jitter_hold_chance = slime_trail_lateral_jitter_hold_chance
	_slime_trail_manager.lateral_jitter_outward_chance = slime_trail_lateral_jitter_outward_chance
	_slime_trail_manager.turn_pooling_multiplier = slime_trail_turn_pooling_multiplier
	_slime_trail_manager.max_turn_pooling_amount = slime_trail_max_turn_pooling_amount
	_slime_trail_manager.droplet_chance = slime_trail_droplet_chance
	_slime_trail_manager.decay_rate = slime_trail_decay_rate
	_slime_trail_manager.decay_update_interval = slime_trail_decay_update_interval
	_slime_trail_manager.field_deposit_strength = slime_trail_field_deposit_strength
	_slime_trail_manager.field_repeat_pool_growth = slime_trail_field_repeat_pool_growth
	_slime_trail_manager.field_upload_blur_radius = slime_trail_field_upload_blur_radius
	_slime_trail_manager.alpha_mask_enabled = slime_trail_alpha_mask_enabled
	_slime_trail_manager.texture_upload_interval = slime_trail_texture_upload_interval
	_slime_trail_manager.recenter_cooldown = slime_trail_recenter_cooldown
	_slime_trail_manager.visualization_debug = slime_trail_visualization_debug
	_slime_trail_manager.dark_oil_color = slime_trail_dark_oil_color
	_slime_trail_manager.light_oil_color = slime_trail_light_oil_color
	_slime_trail_manager.mask_threshold = slime_trail_field_debug_threshold
	_slime_trail_manager.debug_edge_softness = slime_trail_field_debug_edge_softness
	if slime_trail_visualization_debug:
		var sprite_z_index: int = 0
		if _sprite != null:
			sprite_z_index = _sprite.z_index
		_slime_trail_manager.z_index = maxi(sprite_z_index, 10)
	else:
		_slime_trail_manager.z_index = 0
	_slime_trail_manager.refresh_configuration()
	_sync_slime_trail_alpha_mask()
	_slime_trail_manager_configured = true

func _update_slime_trail_move_direction(direction: Vector2) -> void:
	if _slime_trail_emitter == null or direction.length_squared() <= 0.0001:
		return
	_slime_trail_emitter.set_move_direction(direction)

func _sync_slime_trail_alpha_mask() -> void:
	if _slime_trail_manager == null or not is_instance_valid(_slime_trail_manager):
		return
	if not slime_trail_alpha_mask_enabled:
		_slime_trail_manager.clear_alpha_mask_payload()
		return
	if not _slime_trail_mask_payloads.is_empty():
		var mask_payloads: Array = _slime_trail_mask_payloads.values()
		var active_payload: Variant = mask_payloads[0]
		if active_payload is Dictionary:
			_slime_trail_lingering_mask_payload = (active_payload as Dictionary).duplicate()
			_slime_trail_manager.set_alpha_mask_payload(active_payload as Dictionary)
			return
	if slime_trail_alpha_mask_lingers_after_exit and not _slime_trail_lingering_mask_payload.is_empty():
		_slime_trail_manager.set_alpha_mask_payload(_slime_trail_lingering_mask_payload)
		return
	_slime_trail_manager.clear_alpha_mask_payload()

func _ensure_slime_effect_layer() -> void:
	var parent_node: Node = get_parent()
	if not (parent_node is Node2D):
		return
	var existing_layer: Node = parent_node.get_node_or_null("SlimeEffectLayer")
	if existing_layer is Node2D:
		_slime_effect_layer = existing_layer as Node2D
		parent_node.move_child(_slime_effect_layer, get_index())
		_slime_effect_layer_pending = false
		return
	if _slime_effect_layer_pending:
		return
	_slime_effect_layer_pending = true
	_call_deferred_create_slime_effect_layer(parent_node as Node2D)

func _call_deferred_create_slime_effect_layer(parent_node: Node2D) -> void:
	_create_slime_effect_layer.call_deferred(parent_node)

func _create_slime_effect_layer(parent_node: Node2D) -> void:
	if parent_node == null or not is_instance_valid(parent_node):
		_slime_effect_layer_pending = false
		return
	var existing_layer: Node = parent_node.get_node_or_null("SlimeEffectLayer")
	if existing_layer is Node2D:
		_slime_effect_layer = existing_layer as Node2D
		_slime_effect_layer_pending = false
		return
	_slime_effect_layer = Node2D.new()
	_slime_effect_layer.name = "SlimeEffectLayer"
	parent_node.add_child(_slime_effect_layer)
	parent_node.move_child(_slime_effect_layer, get_index())
	_slime_effect_layer.owner = parent_node.owner
	_slime_effect_layer_pending = false

func _dir_to_walk_animation(dir: Vector2) -> String:
	if dir.x != 0.0 and dir.y != 0.0:
		if dir.y < 0.0:
			return "up_left_walk" if dir.x < 0.0 else "up_right_walk"
		return "down_left_walk" if dir.x < 0.0 else "down_right_walk"
	if absf(dir.x) > absf(dir.y):
		return "right_walk" if dir.x > 0.0 else "left_walk"
	return "down_walk" if dir.y > 0.0 else "up_walk"

func _dir_to_animation_prefix(dir: Vector2) -> String:
	if dir.x != 0.0 and dir.y != 0.0:
		if dir.y < 0.0:
			return "up_left" if dir.x < 0.0 else "up_right"
		return "down_left" if dir.x < 0.0 else "down_right"
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"

func _play_animation(animation_name: String) -> void:
	if not _has_animation(animation_name):
		return
	if _sprite.animation == animation_name and _sprite.is_playing() and _sprite.speed_scale >= 0.0:
		return
	_sprite.play(animation_name)
	_sprite.speed_scale = 1.0

func _play_animation_from_start(animation_name: String) -> void:
	if not _has_animation(animation_name):
		return
	_sprite.play(animation_name)
	_sprite.speed_scale = 1.0
	_sprite.frame = 0
	_sprite.frame_progress = 0.0

func _play_animation_backwards(animation_name: String) -> void:
	if not _has_animation(animation_name):
		return
	_sprite.play_backwards(animation_name)

func _has_animation(animation_name: String) -> bool:
	return _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation_name)

func _cancel_pool_turn() -> void:
	_pool_turn_state = ""
	_pending_pool_turn_prefix = ""

func _on_animation_finished() -> void:
	if _sprite == null:
		return
	if _transition_state == "dying":
		_complete_death_animation()
		return
	if _pool_turn_state == "leaving_current":
		_pool_turn_state = "entering_next"
		_play_animation_backwards("%s_pool" % _pending_pool_turn_prefix)
		return
	if _pool_turn_state == "entering_next":
		_facing_animation_prefix = _pending_pool_turn_prefix
		_pending_pool_turn_prefix = ""
		_pool_turn_state = ""
		return
	if _transition_state == "raising":
		_transition_state = "raised"
		if _engaged:
			_play_animation("%s_follow" % _facing_animation_prefix)
	elif _transition_state == "lowering":
		_transition_state = ""
	_refresh_collision_radius()

func move_without_pushing(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		return
	var motion := velocity * delta
	if motion.length_squared() <= 0.0001:
		return
	if _slime_visual_effects_enabled:
		_ensure_slime_trail_system()
	var start_position: Vector2 = global_position

	var collision := move_and_collide(motion)
	if collision == null:
		_record_slime_trail_motion(global_position, false)
		return

	var collider := collision.get_collider()
	if collider is CharacterBody2D:
		velocity = Vector2.ZERO
		_record_slime_trail_motion(global_position, true)
		return

	var slide_motion := collision.get_remainder().slide(collision.get_normal())
	if slide_motion.length_squared() <= 0.0001:
		_record_slime_trail_motion(global_position, true)
		return
	var slide_collision: KinematicCollision2D = move_and_collide(slide_motion)
	if slide_collision != null and slide_collision.get_collider() is CharacterBody2D:
		velocity = Vector2.ZERO
	var actual_displacement_sq: float = global_position.distance_squared_to(start_position)
	var effectively_blocked: bool = slide_collision != null and actual_displacement_sq <= 0.0001
	_record_slime_trail_motion(global_position, effectively_blocked)

func _record_slime_trail_motion(current_position: Vector2, blocked: bool) -> void:
	if _slime_trail_emitter == null:
		return
	if not _slime_visual_effects_enabled:
		_slime_trail_emitter.enabled = false
		_slime_trail_emitter.record_motion(current_position, true)
		return
	if _gas_spill_active:
		_slime_trail_emitter.enabled = false
		_slime_trail_emitter.record_motion(current_position, true)
		return
	var trail_speed_threshold_sq: float = slime_trail_speed_threshold * slime_trail_speed_threshold
	_slime_trail_emitter.enabled = velocity.length_squared() >= trail_speed_threshold_sq
	_slime_trail_emitter.record_motion(current_position, blocked)

func _capture_quality_performance_values() -> void:
	_quality_performance_values = {
		"gas_spill_ripple_count": gas_spill_ripple_count,
		"gas_spill_ripple_update_interval": gas_spill_ripple_update_interval,
		"slime_trail_canvas_resolution": slime_trail_canvas_resolution,
		"slime_trail_decay_update_interval": slime_trail_decay_update_interval,
		"slime_trail_droplet_chance": slime_trail_droplet_chance,
		"slime_trail_field_upload_blur_radius": slime_trail_field_upload_blur_radius,
		"slime_trail_texture_upload_interval": slime_trail_texture_upload_interval,
	}

func apply_performance_preset(preset: int) -> void:
	if _quality_performance_values.is_empty():
		_capture_quality_performance_values()
	_restore_quality_performance_values()
	_slime_visual_effects_enabled = preset != SettingsManager.PerformancePreset.PERFORMANCE

	if preset == SettingsManager.PerformancePreset.BALANCED:
		gas_spill_ripple_count = mini(gas_spill_ripple_count, 2)
		gas_spill_ripple_update_interval = maxf(gas_spill_ripple_update_interval, 0.066)
		slime_trail_canvas_resolution = Vector2i(
			maxi(128, int(roundf(float(slime_trail_canvas_resolution.x) * 0.5))),
			maxi(128, int(roundf(float(slime_trail_canvas_resolution.y) * 0.5)))
		)
		slime_trail_decay_update_interval = maxf(slime_trail_decay_update_interval, 0.2)
		slime_trail_droplet_chance *= 0.5
		slime_trail_field_upload_blur_radius = 0
		slime_trail_texture_upload_interval = maxf(slime_trail_texture_upload_interval, 0.066)

	if not _slime_visual_effects_enabled:
		_disable_slime_visual_effects()
	elif is_inside_tree():
		_ensure_slime_trail_system(true)

func _restore_quality_performance_values() -> void:
	gas_spill_ripple_count = int(_quality_performance_values.get("gas_spill_ripple_count", gas_spill_ripple_count))
	gas_spill_ripple_update_interval = float(_quality_performance_values.get("gas_spill_ripple_update_interval", gas_spill_ripple_update_interval))
	slime_trail_canvas_resolution = _quality_performance_values.get("slime_trail_canvas_resolution", slime_trail_canvas_resolution) as Vector2i
	slime_trail_decay_update_interval = float(_quality_performance_values.get("slime_trail_decay_update_interval", slime_trail_decay_update_interval))
	slime_trail_droplet_chance = float(_quality_performance_values.get("slime_trail_droplet_chance", slime_trail_droplet_chance))
	slime_trail_field_upload_blur_radius = int(_quality_performance_values.get("slime_trail_field_upload_blur_radius", slime_trail_field_upload_blur_radius))
	slime_trail_texture_upload_interval = float(_quality_performance_values.get("slime_trail_texture_upload_interval", slime_trail_texture_upload_interval))

func _disable_slime_visual_effects() -> void:
	_pending_gas_spill_ripple_delays.clear()
	_pending_gas_spill_ripple_direction = Vector2.ZERO
	set_process(false)
	if _slime_effect_layer != null:
		for child: Node in _slime_effect_layer.get_children():
			if child is SlimePoolRipple or child is SlimeTrailManager:
				child.queue_free()
	_slime_trail_manager = null
	_slime_trail_manager_configured = false
	if _slime_trail_emitter != null:
		_slime_trail_emitter.queue_free()
	_slime_trail_emitter = null
