# res://scripts/gameplay/ExposedWiresInteractable.gd
extends NoteInteractable
class_name ExposedWiresInteractable

@export var shock_damage := 2
@export var required_item_id := "Coil of Copper Wire"
@export var missing_item_dialogue_id := "gsa_missing_wire_coil"
@export var sparks_path: NodePath = NodePath("../Sparks")
@export var wire_trap_sprite_path: NodePath = NodePath("../Trap/WireTrapSprite")
@export var wire_trap_glow_sprite_path: NodePath = NodePath("../Trap/WireTrapGlowSprite")
@export var wire_trap_mask_path: NodePath = NodePath("../Trap/Mask")
@export var wire_trap_wall_collision_path: NodePath = NodePath("../Trap/WireTrapWall/WireTrapWallCollision")
@export var wire_trap_electrocution_polygon_path: NodePath = NodePath("../Trap/MetalPostElectrocution")
@export var wire_trap_zap_follow_path: NodePath = NodePath("../Trap/WireTrapZapPath/ZapFollow")
@export var wire_trap_zap_path: NodePath = NodePath("../Trap/WireTrapZapPath/ZapFollow/WireTrapZap")
@export var low_sparks_audio_path: NodePath = NodePath("../Trap/LowSparksAudio")
@export var high_sparks_audio_path: NodePath = NodePath("../Trap/HighSparksAudio")
@export var layer_controller_path: NodePath = NodePath("../..")
@export var effect_layer: LayerController.ViewLayer = LayerController.ViewLayer.EXTERIOR
@export_range(0.0, 1.0, 0.01) var thrum_alpha_min := 0.35
@export_range(0.0, 1.0, 0.01) var thrum_alpha_max := 0.85
@export_range(0.1, 5.0, 0.1) var thrum_min_seconds := 0.5
@export_range(0.1, 5.0, 0.1) var thrum_max_seconds := 1.1
@export_range(0.1, 20.0, 0.1) var light_sparks_min_seconds := 3.0
@export_range(0.1, 20.0, 0.1) var light_sparks_max_seconds := 4.0
@export_range(0.1, 30.0, 0.1) var heavy_sparks_min_seconds := 10.0
@export_range(0.1, 30.0, 0.1) var heavy_sparks_max_seconds := 12.0
@export var wire_trap_zap_animation: StringName = &"Zap 1"
@export_range(0.05, 2.0, 0.01) var wire_trap_zap_seconds := 0.33
@export_range(0.0, 300.0, 1.0) var wire_trap_pushback_distance := 80.0

var _wire_trap_sprite: CanvasItem = null
var _wire_trap_glow_sprite: CanvasItem = null
var _wire_trap_mask: Node = null
var _wire_trap_wall_collision: CollisionPolygon2D = null
var _wire_trap_electrocution_polygon: CollisionPolygon2D = null
var _wire_trap_zap_follow: PathFollow2D = null
var _wire_trap_zap: AnimatedSprite2D = null
var _low_sparks_audio: AudioStreamPlayer2D = null
var _high_sparks_audio: AudioStreamPlayer2D = null
var _sparks: AnimatedSprite2D = null
var _layer_controller: LayerController = null
var _rng := RandomNumberGenerator.new()
var _sparks_thrum_tween: Tween = null
var _trap_glow_thrum_tween: Tween = null
var _trap_zap_tween: Tween = null
var _light_sparks_time_left := 0.0
var _heavy_sparks_time_left := 0.0
var _sparks_thrum_target_high := false
var _trap_glow_thrum_target_high := false
var _effect_layer_active := true
var _trap_electrocuted_bodies: Dictionary = {}
var _trap_previous_character_positions: Dictionary = {}

func _ready() -> void:
	super._ready()
	_rng.randomize()
	_sparks = get_node_or_null(sparks_path) as AnimatedSprite2D
	_wire_trap_sprite = get_node_or_null(wire_trap_sprite_path) as CanvasItem
	_wire_trap_glow_sprite = get_node_or_null(wire_trap_glow_sprite_path) as CanvasItem
	_wire_trap_mask = get_node_or_null(wire_trap_mask_path)
	_wire_trap_wall_collision = get_node_or_null(wire_trap_wall_collision_path) as CollisionPolygon2D
	_wire_trap_electrocution_polygon = get_node_or_null(wire_trap_electrocution_polygon_path) as CollisionPolygon2D
	_wire_trap_zap_follow = get_node_or_null(wire_trap_zap_follow_path) as PathFollow2D
	_wire_trap_zap = get_node_or_null(wire_trap_zap_path) as AnimatedSprite2D
	_low_sparks_audio = _resolve_audio_player(low_sparks_audio_path)
	_high_sparks_audio = _resolve_audio_player(high_sparks_audio_path)
	_layer_controller = get_node_or_null(layer_controller_path) as LayerController
	if _layer_controller == null:
		_layer_controller = get_parent() as LayerController
	if _layer_controller != null:
		_layer_controller.layer_changed.connect(_on_layer_changed)
		_on_layer_changed(_layer_controller._get_current())
	if _sparks != null and not _sparks.animation_finished.is_connected(_on_sparks_animation_finished):
		_sparks.animation_finished.connect(_on_sparks_animation_finished)
	if _wire_trap_zap != null and not _wire_trap_zap.animation_finished.is_connected(_on_wire_trap_zap_animation_finished):
		_wire_trap_zap.animation_finished.connect(_on_wire_trap_zap_animation_finished)
	_reset_wire_trap_zap()
	_update_wire_trap_visibility()
	GameState.power_mode_changed.connect(_on_power_mode_changed)
	GameState.flag_changed.connect(_on_flag_changed)
	_update_effect_state()

func _process(delta: float) -> void:
	if not _should_run_exposed_wire_effects():
		_trap_electrocuted_bodies.clear()
		_trap_previous_character_positions.clear()
		_update_wire_trap_electrocution_state()
		return
	_update_sparks(delta)
	_update_wire_trap_electrocution()

func _on_interact_requested() -> void:
	if _try_generator_shock():
		return
	super._on_interact_requested()

func _on_special_action_requested() -> void:
	if _try_generator_shock():
		return
	if _should_block_fix_missing_item():
		return
	super._on_special_action_requested()

func _on_special_interacted(_interactable_id: String, action_id: String, character: CharacterBase) -> void:
	if action_id == "fix":
		_try_fix_wires(character)
		return
	if action_id == "examine":
		if character and character.character_id == "journalist":
			_try_add_note(character)

func _try_generator_shock() -> bool:
	if GameState.power_mode != GameState.PowerMode.GENERATOR_ON:
		return false
	if not is_active_in_range():
		return false
	var character := GameState.get_active_character()
	if character == null:
		return true
	character.take_damage(shock_damage)
	_trigger_damage_shake(shock_damage)
	if character.character_id == "journalist":
		character.say("journalist_high_voltage")
	else:
		character.say("gsa_high_voltage")
	return true

func _should_block_fix_missing_item() -> bool:
	if not is_active_in_range():
		return false
	var character := GameState.get_active_character()
	if character == null:
		return true
	if character.special_action_id != "fix":
		return false
	if Inventory.has(required_item_id):
		return false
	character.say(missing_item_dialogue_id)
	return true

func _try_fix_wires(character: CharacterBase) -> void:
	if character == null:
		return
	if not Inventory.has(required_item_id):
		character.say(missing_item_dialogue_id)
		return
	GameState.set_flag("slime_trap_set", true)
	_update_wire_trap_visibility()

func _on_flag_changed(flag: String, _value: bool) -> void:
	if flag == "slime_trap_set":
		_update_wire_trap_visibility()
		_update_effect_state()

func _on_power_mode_changed(_mode: int) -> void:
	_update_effect_state()

func _update_wire_trap_visibility() -> void:
	var trap_set := GameState.get_flag("slime_trap_set")
	if _wire_trap_sprite != null:
		_wire_trap_sprite.visible = trap_set
	if _wire_trap_mask != null and _wire_trap_mask.has_method("set_mask_enabled"):
		_wire_trap_mask.set_mask_enabled(trap_set)
	if _wire_trap_wall_collision != null:
		_wire_trap_wall_collision.disabled = true

func _on_layer_changed(active_layer: LayerController.ViewLayer) -> void:
	_effect_layer_active = active_layer == effect_layer
	_update_effect_state()

func _update_effect_state() -> void:
	if _should_run_exposed_wire_effects():
		set_process(true)
		_start_sparks()
	else:
		_stop_sparks()
	if _should_run_wire_trap_effects():
		set_process(true)
		_start_trap_glow_thrum()
	else:
		_stop_trap_glow()
		_reset_wire_trap_zap()
		_trap_electrocuted_bodies.clear()
		_trap_previous_character_positions.clear()
	_update_wire_trap_electrocution_state()
	if not _should_run_exposed_wire_effects() and not _should_run_wire_trap_effects():
		set_process(false)

func _should_run_exposed_wire_effects() -> bool:
	return _effect_layer_active and GameState.power_mode == GameState.PowerMode.GENERATOR_ON

func _should_run_wire_trap_effects() -> bool:
	return _should_run_exposed_wire_effects() and GameState.get_flag("slime_trap_set")

func _should_enable_wire_trap_electrocution() -> bool:
	return GameState.power_mode == GameState.PowerMode.GENERATOR_ON and GameState.get_flag("slime_trap_set")

func _update_wire_trap_electrocution_state() -> void:
	if _wire_trap_electrocution_polygon == null:
		return
	_wire_trap_electrocution_polygon.disabled = not _should_enable_wire_trap_electrocution()
	if _wire_trap_electrocution_polygon.disabled:
		_trap_electrocuted_bodies.clear()
		_trap_previous_character_positions.clear()

func _update_sparks(delta: float) -> void:
	if _sparks == null or not _sparks.visible:
		return
	if _sparks.is_playing():
		return
	_light_sparks_time_left -= delta
	_heavy_sparks_time_left -= delta
	if _heavy_sparks_time_left <= 0.0:
		_play_sparks_animation(&"HeavySparks")
		_schedule_heavy_sparks()
		_schedule_light_sparks()
	elif _light_sparks_time_left <= 0.0:
		_play_sparks_animation(&"LightSparks")
		_schedule_light_sparks()

func _start_sparks() -> void:
	if _sparks == null:
		return
	_sparks.visible = true
	if _light_sparks_time_left <= 0.0:
		_schedule_light_sparks()
	if _heavy_sparks_time_left <= 0.0:
		_schedule_heavy_sparks()
	_start_sparks_thrum()

func _stop_sparks() -> void:
	if _sparks == null:
		return
	if _sparks_thrum_tween != null:
		_sparks_thrum_tween.kill()
	_sparks.stop()
	_sparks.visible = false
	var sparks_color := _sparks.modulate
	sparks_color.a = 0.0
	_sparks.modulate = sparks_color
	_light_sparks_time_left = 0.0
	_heavy_sparks_time_left = 0.0

func _start_sparks_thrum() -> void:
	if _sparks == null or not _should_run_exposed_wire_effects():
		return
	if _sparks.is_playing():
		return
	if _sparks_thrum_tween != null:
		_sparks_thrum_tween.kill()
	_sparks.animation = &"LightSparks"
	_sparks.frame = 0
	_sparks.stop()
	_sparks_thrum_tween = _create_thrum_tween(_sparks, _sparks_thrum_target_high)
	_sparks_thrum_target_high = not _sparks_thrum_target_high
	_sparks_thrum_tween.finished.connect(_start_sparks_thrum)

func _play_sparks_animation(animation_name: StringName) -> void:
	if _sparks == null or _sparks.sprite_frames == null:
		return
	if not _sparks.sprite_frames.has_animation(animation_name):
		return
	if _sparks_thrum_tween != null:
		_sparks_thrum_tween.kill()
	var sparks_color := _sparks.modulate
	sparks_color.a = 1.0
	_sparks.modulate = sparks_color
	_sparks.play(animation_name)
	if animation_name == &"HeavySparks":
		_play_audio(_high_sparks_audio)
	else:
		_play_audio(_low_sparks_audio)
	if _should_run_wire_trap_effects():
		_play_wire_trap_zap()

func _on_sparks_animation_finished() -> void:
	if not _should_run_exposed_wire_effects():
		_stop_sparks()
		return
	_start_sparks_thrum()

func _start_trap_glow_thrum() -> void:
	if _wire_trap_glow_sprite == null or not _should_run_wire_trap_effects():
		return
	_wire_trap_glow_sprite.visible = true
	if _trap_glow_thrum_tween != null:
		return
	_trap_glow_thrum_tween = _create_thrum_tween(_wire_trap_glow_sprite, _trap_glow_thrum_target_high)
	_trap_glow_thrum_target_high = not _trap_glow_thrum_target_high
	_trap_glow_thrum_tween.finished.connect(_on_trap_glow_thrum_finished)

func _on_trap_glow_thrum_finished() -> void:
	_trap_glow_thrum_tween = null
	_start_trap_glow_thrum()

func _stop_trap_glow() -> void:
	if _trap_glow_thrum_tween != null:
		_trap_glow_thrum_tween.kill()
		_trap_glow_thrum_tween = null
	if _wire_trap_glow_sprite == null:
		return
	_wire_trap_glow_sprite.visible = false
	var glow_color := _wire_trap_glow_sprite.modulate
	glow_color.a = 0.0
	_wire_trap_glow_sprite.modulate = glow_color

func _create_thrum_tween(target: CanvasItem, target_high: bool) -> Tween:
	var min_alpha: float = min(thrum_alpha_min, thrum_alpha_max)
	var max_alpha: float = max(thrum_alpha_min, thrum_alpha_max)
	var alpha_range: float = max_alpha - min_alpha
	var target_alpha := max_alpha
	if alpha_range > 0.0:
		if target_high:
			target_alpha = _rng.randf_range(max_alpha - alpha_range * 0.2, max_alpha)
		else:
			target_alpha = _rng.randf_range(min_alpha, min_alpha + alpha_range * 0.2)
	var min_seconds: float = min(thrum_min_seconds, thrum_max_seconds)
	var max_seconds: float = max(thrum_min_seconds, thrum_max_seconds)
	var duration: float = _rng.randf_range(min_seconds, max_seconds)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "modulate:a", target_alpha, duration)
	return tween

func _play_wire_trap_zap() -> void:
	if _wire_trap_zap_follow == null or _wire_trap_zap == null:
		return
	_reset_wire_trap_zap()
	_wire_trap_zap_follow.progress_ratio = 0.0
	_wire_trap_zap.visible = true
	_wire_trap_zap.animation = _get_wire_trap_zap_animation()
	_wire_trap_zap.frame = 0
	_wire_trap_zap.frame_progress = 0.0
	_wire_trap_zap.play()
	_trap_zap_tween = create_tween()
	_trap_zap_tween.tween_property(_wire_trap_zap_follow, "progress_ratio", 1.0, wire_trap_zap_seconds)
	_trap_zap_tween.finished.connect(_on_wire_trap_zap_tween_finished)

func _on_wire_trap_zap_tween_finished() -> void:
	_trap_zap_tween = null
	_reset_wire_trap_zap()

func _on_wire_trap_zap_animation_finished() -> void:
	if _trap_zap_tween == null:
		_reset_wire_trap_zap()

func _reset_wire_trap_zap() -> void:
	if _trap_zap_tween != null:
		_trap_zap_tween.kill()
		_trap_zap_tween = null
	if _wire_trap_zap_follow != null:
		_wire_trap_zap_follow.progress_ratio = 0.0
	if _wire_trap_zap != null:
		_wire_trap_zap.stop()
		_wire_trap_zap.visible = false

func _get_wire_trap_zap_animation() -> StringName:
	if _wire_trap_zap != null and _wire_trap_zap.sprite_frames != null:
		if _wire_trap_zap.sprite_frames.has_animation(wire_trap_zap_animation):
			return wire_trap_zap_animation
		if _wire_trap_zap.sprite_frames.has_animation(&"default"):
			return &"default"
	return wire_trap_zap_animation

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

func _schedule_light_sparks() -> void:
	var min_seconds: float = min(light_sparks_min_seconds, light_sparks_max_seconds)
	var max_seconds: float = max(light_sparks_min_seconds, light_sparks_max_seconds)
	_light_sparks_time_left = _rng.randf_range(min_seconds, max_seconds)

func _schedule_heavy_sparks() -> void:
	var min_seconds: float = min(heavy_sparks_min_seconds, heavy_sparks_max_seconds)
	var max_seconds: float = max(heavy_sparks_min_seconds, heavy_sparks_max_seconds)
	_heavy_sparks_time_left = _rng.randf_range(min_seconds, max_seconds)

func _update_wire_trap_electrocution() -> void:
	_update_wire_trap_electrocution_state()
	if _wire_trap_electrocution_polygon == null or not _should_enable_wire_trap_electrocution():
		_trap_electrocuted_bodies.clear()
		_trap_previous_character_positions.clear()
		return
	_update_character_wire_trap_electrocution(GameState.get_character("journalist"))
	_update_character_wire_trap_electrocution(GameState.get_character("gsa"))

func _update_character_wire_trap_electrocution(character: CharacterBase) -> void:
	if character == null:
		return
	var character_key: int = character.get_instance_id()
	if character.current_location != LayerController.ViewLayer.EXTERIOR:
		_trap_electrocuted_bodies.erase(character)
		_trap_previous_character_positions.erase(character_key)
		return
	var current_position := character.global_position
	var previous_position: Vector2 = _trap_previous_character_positions.get(character_key, current_position)
	var approach_vector := current_position - previous_position
	var inside := _is_point_in_collision_polygon(current_position, _wire_trap_electrocution_polygon)
	if inside and not _trap_electrocuted_bodies.get(character, false):
		_trap_electrocuted_bodies[character] = true
		character.take_damage(shock_damage)
		_push_character_back_from_wire_trap(character, approach_vector)
		_trigger_damage_shake(shock_damage)
		if character.character_id == "journalist":
			character.say("journalist_high_voltage")
		else:
			character.say("gsa_high_voltage")
	elif not inside and _trap_electrocuted_bodies.get(character, false):
		_trap_electrocuted_bodies.erase(character)
	_trap_previous_character_positions[character_key] = character.global_position

func _push_character_back_from_wire_trap(character: CharacterBase, approach_vector: Vector2) -> void:
	if character == null:
		return
	if wire_trap_pushback_distance <= 0.0:
		return
	var push_direction := -approach_vector.normalized()
	if push_direction == Vector2.ZERO:
		push_direction = -character.velocity.normalized()
	if push_direction == Vector2.ZERO:
		push_direction = Vector2.UP
	character.velocity = Vector2.ZERO
	character.global_position += push_direction * wire_trap_pushback_distance

func _trigger_damage_shake(amount: int) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var camera := root.get_node_or_null("Camera2D")
	if camera and camera.has_method("trigger_damage_shake"):
		camera.trigger_damage_shake(amount)

func _is_point_in_collision_polygon(point: Vector2, poly_node: CollisionPolygon2D) -> bool:
	var local_poly := poly_node.polygon
	if local_poly.size() < 3:
		return false
	var global_poly := PackedVector2Array()
	global_poly.resize(local_poly.size())
	for i in local_poly.size():
		global_poly[i] = poly_node.global_transform * local_poly[i]
	return Geometry2D.is_point_in_polygon(point, global_poly)
