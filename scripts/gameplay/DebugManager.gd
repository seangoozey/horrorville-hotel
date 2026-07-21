@tool
extends Node

const DEFAULT_GENERATOR_DARK_POSITION := Vector2(1552.27, -1475.18)
const DEFAULT_GENERATOR_LIT_POSITION := Vector2(1555.0, -1477.0)
const FPS_SAMPLE_WINDOW_SECONDS := 1.0

@export var debug_label: Label
@export var fps_display_label: Label
@export var show_debug := true

var _fps_sample_elapsed := 0.0
var _fps_sample_frames := 0
var _fps_sample_worst_frame_ms := 0.0

@export var power_system: Node:
	set(value):
		power_system = value
		_apply_debug_state()

@export var generator_sprite: Sprite2D:
	set(value):
		generator_sprite = value
		_apply_generator_state()

@export var door_wall_collision: CollisionPolygon2D:
	set(value):
		door_wall_collision = value
		_apply_cellar_door_state()

@export var open_door_wall_collision: Node:
	set(value):
		open_door_wall_collision = value
		_apply_cellar_door_state()

@export var door_mask: Area2D:
	set(value):
		door_mask = value
		_apply_cellar_door_state()

@export var door_open_mask: Area2D:
	set(value):
		door_open_mask = value
		_apply_cellar_door_state()

@export var power_on := true:
	set(value):
		power_on = value
		_apply_power_art()
		_apply_cellar_door_state()

@export var generator_on := false:
	set(value):
		generator_on = value
		_apply_power_art()
		_apply_generator_state()
		_apply_cellar_door_state()

@export var cellar_door_open := false:
	set(value):
		cellar_door_open = value
		_apply_cellar_door_state()

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_debug_state()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.active_character_changed.connect(_refresh_debug_label)
	GameState.power_mode_changed.connect(_refresh_debug_label)
	GameState.flag_changed.connect(_on_flag_changed)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	_refresh_debug_label()
	_refresh_fps_display(true)

func _process(delta: float) -> void:
	if fps_display_label == null or not _is_fps_display_enabled():
		return
	_fps_sample_elapsed += delta
	_fps_sample_frames += 1
	_fps_sample_worst_frame_ms = maxf(_fps_sample_worst_frame_ms, delta * 1000.0)
	if _fps_sample_elapsed >= FPS_SAMPLE_WINDOW_SECONDS:
		_refresh_fps_display()

func set_debug(text: String) -> void:
	if debug_label:
		debug_label.text = text

func _refresh_debug_label(_value: Variant = null) -> void:
	if debug_label == null:
		return
	if not show_debug:
		debug_label.text = ""
		return

	debug_label.text = "Char: %s | Power: %s | flags: %s" % [
		GameState.active_character_id,
		_power_name(GameState.power_mode),
		str(GameState.flags)
	]

func _on_flag_changed(_flag: String, _value: bool) -> void:
	_refresh_debug_label()

func _on_settings_changed(section: StringName) -> void:
	if section == &"performance":
		_refresh_fps_display(true)

func _refresh_fps_display(force: bool = false) -> void:
	if fps_display_label == null:
		return
	var fps_enabled: bool = _is_fps_display_enabled()
	fps_display_label.visible = fps_enabled
	if not fps_enabled:
		_reset_fps_sample()
		return
	if _fps_sample_frames == 0:
		if force:
			fps_display_label.text = "FPS: -- | Avg: -- ms | Worst: -- ms"
		return
	if not force and _fps_sample_elapsed < FPS_SAMPLE_WINDOW_SECONDS:
		return
	var measured_fps: float = float(_fps_sample_frames) / _fps_sample_elapsed
	var average_frame_ms: float = (_fps_sample_elapsed * 1000.0) / float(_fps_sample_frames)
	fps_display_label.text = "FPS: %.0f | Avg: %.1f ms | Worst: %.1f ms" % [
		measured_fps,
		average_frame_ms,
		_fps_sample_worst_frame_ms,
	]
	_reset_fps_sample()

func _reset_fps_sample() -> void:
	_fps_sample_elapsed = 0.0
	_fps_sample_frames = 0
	_fps_sample_worst_frame_ms = 0.0

func _is_fps_display_enabled() -> bool:
	for property: Dictionary in SettingsManager.get_property_list():
		if StringName(property.get("name", &"")) == &"show_fps":
			return bool(SettingsManager.get(&"show_fps"))
	return false

func _power_name(mode: int) -> String:
	match mode:
		GameState.PowerMode.GRID_ON:
			return "GRID_ON"
		GameState.PowerMode.POWER_OFF:
			return "POWER_OFF"
		GameState.PowerMode.GENERATOR_ON:
			return "GENERATOR_ON"
	return "?"

func _apply_debug_state() -> void:
	if not Engine.is_editor_hint():
		return
	_apply_power_art()
	_apply_generator_state()
	_apply_cellar_door_state()

func _apply_power_art() -> void:
	if not Engine.is_editor_hint() or power_system == null:
		return

	var outside_sprite := power_system.get("outside_sprite") as Sprite2D
	var interior_sprite := power_system.get("interior_sprite") as Sprite2D
	var cellar_sprite := power_system.get("cellar_sprite") as Sprite2D
	var outside_texture := _get_power_texture("outside_texture_grid_on", "outside_texture_dark")
	var interior_texture := _get_power_texture("interior_texture_grid_on", "interior_texture_dark")
	var cellar_texture := _get_power_texture("cellar_texture_grid_on", "cellar_texture_dark")

	_set_sprite_texture(outside_sprite, outside_texture)
	_set_sprite_texture(interior_sprite, interior_texture)
	_set_sprite_texture(cellar_sprite, cellar_texture)

func _apply_generator_state() -> void:
	if not Engine.is_editor_hint():
		return
	if generator_sprite == null:
		return
	generator_sprite.visible = generator_on
	var target_position := DEFAULT_GENERATOR_DARK_POSITION
	if generator_on and power_on:
		target_position = DEFAULT_GENERATOR_LIT_POSITION
	generator_sprite.position = target_position
	var modulate_color := generator_sprite.modulate
	modulate_color.a = 1.0 if generator_on else 0.0
	generator_sprite.modulate = modulate_color

func _apply_cellar_door_state() -> void:
	if not Engine.is_editor_hint():
		return
	if power_system == null:
		return
	var cellar_door_open_sprite := power_system.get("cellar_door_open_sprite") as Sprite2D
	var cellar_dark_door_open_sprite := power_system.get("cellar_dark_door_open_sprite") as Sprite2D
	if cellar_door_open_sprite:
		cellar_door_open_sprite.visible = cellar_door_open and _is_grid_power_on()
	if cellar_dark_door_open_sprite:
		cellar_dark_door_open_sprite.visible = cellar_door_open and not _is_grid_power_on()
	_set_node_enabled_recursive(door_wall_collision, not cellar_door_open)
	_set_node_enabled_recursive(_get_open_door_wall_collision(), cellar_door_open)
	_set_node_enabled_recursive(door_mask, not cellar_door_open)
	_set_node_enabled_recursive(door_open_mask, cellar_door_open)

func _get_power_texture(on_property: String, off_property: String) -> Texture2D:
	var property_name := on_property if _is_grid_power_on() else off_property
	return power_system.get(property_name) as Texture2D

func _is_grid_power_on() -> bool:
	return power_on

func _get_open_door_wall_collision() -> Node:
	if open_door_wall_collision != null:
		return open_door_wall_collision
	var root := owner if owner != null else get_tree().current_scene
	if root == null:
		return null
	return root.find_child("OpenDoorWallCollision", true, false)

func _set_sprite_texture(sprite: Sprite2D, texture: Texture2D) -> void:
	if sprite == null or texture == null:
		return
	sprite.texture = texture

func _set_node_enabled_recursive(n: Node, enabled: bool) -> void:
	if n == null:
		return
	if n is Area2D:
		var area := n as Area2D
		area.set_deferred("monitoring", enabled)
		area.set_deferred("monitorable", enabled)
	if n is CollisionObject2D:
		var collision_object := n as CollisionObject2D
		collision_object.set_deferred("disabled", not enabled)
	if n is CollisionShape2D:
		var collision_shape := n as CollisionShape2D
		collision_shape.set_deferred("disabled", not enabled)
	if n is CollisionPolygon2D:
		var collision_polygon := n as CollisionPolygon2D
		collision_polygon.set_deferred("disabled", not enabled)
	for child in n.get_children():
		_set_node_enabled_recursive(child, enabled)
