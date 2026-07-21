# res://autoload/SettingsManager.gd
# Purpose: Persist and apply audio, display, frame-cap performance presets, and keyboard/gamepad binding overrides.
extends Node

signal settings_changed(section: StringName)

enum PerformancePreset { PERFORMANCE, BALANCED, QUALITY }

const CONFIG_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"
const DISPLAY_SECTION := "display"
const PERFORMANCE_SECTION := "performance"
const CONTROLS_SECTION := "controls"
const BINDING_FAMILY_KEYBOARD := "keyboard"
const BINDING_FAMILY_GAMEPAD := "gamepad"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_MUTED := false
const MASTER_VOLUME_CEILING_DB := -3.0
const MUSIC_VOLUME_CEILING_DB := -6.0
const SFX_VOLUME_CEILING_DB := -3.0
const VIDEO_VOLUME_CEILING_DB := 3.0
const DEFAULT_FULLSCREEN := false
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_PERFORMANCE_PRESET := PerformancePreset.QUALITY
const DEFAULT_SHOW_FPS := false
const CONTROL_BINDING_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"interact",
	&"special_action",
	&"open_journal",
	&"switch_character",
	&"cancel",
]

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var muted: bool = DEFAULT_MUTED
var fullscreen: bool = DEFAULT_FULLSCREEN
var resolution: Vector2i = DEFAULT_RESOLUTION
var performance_preset: int = DEFAULT_PERFORMANCE_PRESET
var show_fps: bool = DEFAULT_SHOW_FPS
var keyboard_bindings: Dictionary = {}
var gamepad_bindings: Dictionary = {}
var _default_control_events: Dictionary = {}

func _ready() -> void:
	_capture_default_control_events()
	load_settings()
	apply_all_settings()

func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.keycode
	var physical_key: Key = key_event.physical_keycode
	if key != KEY_ENTER and key != KEY_KP_ENTER and physical_key != KEY_ENTER and physical_key != KEY_KP_ENTER:
		return
	if not key_event.alt_pressed:
		return
	set_fullscreen(not fullscreen)
	get_viewport().set_input_as_handled()

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		_capture_current_display_defaults()
		return

	master_volume = float(config.get_value(AUDIO_SECTION, "master_volume", DEFAULT_MASTER_VOLUME))
	music_volume = float(config.get_value(AUDIO_SECTION, "music_volume", DEFAULT_MUSIC_VOLUME))
	sfx_volume = float(config.get_value(AUDIO_SECTION, "sfx_volume", DEFAULT_SFX_VOLUME))
	muted = bool(config.get_value(AUDIO_SECTION, "muted", DEFAULT_MUTED))
	fullscreen = bool(config.get_value(DISPLAY_SECTION, "fullscreen", DEFAULT_FULLSCREEN))
	var loaded_resolution: Variant = config.get_value(DISPLAY_SECTION, "resolution", DEFAULT_RESOLUTION)
	resolution = _variant_to_resolution(loaded_resolution)
	performance_preset = int(config.get_value(PERFORMANCE_SECTION, "preset", DEFAULT_PERFORMANCE_PRESET))
	show_fps = bool(config.get_value(PERFORMANCE_SECTION, "show_fps", DEFAULT_SHOW_FPS))
	keyboard_bindings = config.get_value(CONTROLS_SECTION, "keyboard_bindings", {}) as Dictionary
	gamepad_bindings = config.get_value(CONTROLS_SECTION, "gamepad_bindings", {}) as Dictionary

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(AUDIO_SECTION, "master_volume", master_volume)
	config.set_value(AUDIO_SECTION, "music_volume", music_volume)
	config.set_value(AUDIO_SECTION, "sfx_volume", sfx_volume)
	config.set_value(AUDIO_SECTION, "muted", muted)
	config.set_value(DISPLAY_SECTION, "fullscreen", fullscreen)
	config.set_value(DISPLAY_SECTION, "resolution", resolution)
	config.set_value(PERFORMANCE_SECTION, "preset", performance_preset)
	config.set_value(PERFORMANCE_SECTION, "show_fps", show_fps)
	config.set_value(CONTROLS_SECTION, "keyboard_bindings", keyboard_bindings)
	config.set_value(CONTROLS_SECTION, "gamepad_bindings", gamepad_bindings)
	config.save(CONFIG_PATH)

func apply_all_settings() -> void:
	apply_audio_settings()
	apply_display_settings()
	apply_performance_settings()
	apply_control_settings()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()
	settings_changed.emit(&"audio")

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()
	settings_changed.emit(&"audio")

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio_settings()
	save_settings()
	settings_changed.emit(&"audio")

func set_muted(value: bool) -> void:
	muted = value
	apply_audio_settings()
	save_settings()
	settings_changed.emit(&"audio")

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display_settings()
	save_settings()
	settings_changed.emit(&"display")

func set_resolution(value: Vector2i) -> void:
	resolution = value
	if resolution.x <= 0 or resolution.y <= 0:
		resolution = DEFAULT_RESOLUTION
	apply_display_settings()
	save_settings()
	settings_changed.emit(&"display")

func set_performance_preset(value: int) -> void:
	performance_preset = clampi(value, PerformancePreset.PERFORMANCE, PerformancePreset.QUALITY)
	apply_performance_settings()
	save_settings()
	settings_changed.emit(&"performance")

func set_show_fps(value: bool) -> void:
	show_fps = value
	save_settings()
	settings_changed.emit(&"performance")

func set_keyboard_binding(action_name: StringName, event: InputEvent) -> void:
	if not CONTROL_BINDING_ACTIONS.has(action_name):
		return
	if not _is_keyboard_binding_event(event):
		return
	keyboard_bindings[String(action_name)] = _input_event_to_dictionary(event)
	_apply_binding_event(action_name, BINDING_FAMILY_KEYBOARD, event)
	save_settings()
	settings_changed.emit(&"controls")

func set_gamepad_binding(action_name: StringName, event: InputEvent) -> void:
	if not CONTROL_BINDING_ACTIONS.has(action_name):
		return
	if not _is_gamepad_binding_event(event):
		return
	gamepad_bindings[String(action_name)] = _input_event_to_dictionary(event)
	_apply_binding_event(action_name, BINDING_FAMILY_GAMEPAD, event)
	save_settings()
	settings_changed.emit(&"controls")

func reset_control_bindings() -> void:
	keyboard_bindings.clear()
	gamepad_bindings.clear()
	_restore_default_control_events()
	save_settings()
	settings_changed.emit(&"controls")

func get_keyboard_binding_event(action_name: StringName) -> InputEvent:
	return _get_binding_event(action_name, BINDING_FAMILY_KEYBOARD)

func get_gamepad_binding_event(action_name: StringName) -> InputEvent:
	return _get_binding_event(action_name, BINDING_FAMILY_GAMEPAD)

func apply_audio_settings() -> void:
	_set_bus_volume(&"Master", master_volume, MASTER_VOLUME_CEILING_DB)
	_set_bus_volume(&"Music", music_volume, MUSIC_VOLUME_CEILING_DB)
	_set_bus_volume(&"SFX", sfx_volume, SFX_VOLUME_CEILING_DB)
	_set_bus_volume(&"Video", 1.0, VIDEO_VOLUME_CEILING_DB)
	var master_bus_index := AudioServer.get_bus_index(&"Master")
	if master_bus_index >= 0:
		AudioServer.set_bus_mute(master_bus_index, muted)

func preview_audio_bus_volume(bus_name: StringName, value: float) -> void:
	match bus_name:
		&"Master":
			_set_bus_volume(bus_name, value, MASTER_VOLUME_CEILING_DB)
		&"Music":
			_set_bus_volume(bus_name, value, MUSIC_VOLUME_CEILING_DB)
		&"SFX":
			_set_bus_volume(bus_name, value, SFX_VOLUME_CEILING_DB)
		&"Video":
			_set_bus_volume(bus_name, value, VIDEO_VOLUME_CEILING_DB)

func apply_display_settings() -> void:
	if not _can_apply_window_display_settings():
		return
	var safe_resolution: Vector2i = _get_safe_window_resolution()
	_apply_default_content_scale()
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_apply_default_content_scale.call_deferred()
		return
	_apply_windowed_resolution(safe_resolution)
	_apply_windowed_resolution.call_deferred(safe_resolution)

func apply_performance_settings() -> void:
	match performance_preset:
		PerformancePreset.PERFORMANCE:
			Engine.max_fps = 60
		PerformancePreset.QUALITY:
			Engine.max_fps = 0
		_:
			Engine.max_fps = 120
	get_tree().call_group(&"performance_slime", &"apply_performance_preset", performance_preset)

func apply_control_settings() -> void:
	_restore_default_control_events()
	for action_key in keyboard_bindings.keys():
		var action_name := StringName(String(action_key))
		if not CONTROL_BINDING_ACTIONS.has(action_name):
			continue
		var event := _dictionary_to_input_event(keyboard_bindings[action_key])
		if event:
			_apply_binding_event(action_name, BINDING_FAMILY_KEYBOARD, event)
	for action_key in gamepad_bindings.keys():
		var action_name := StringName(String(action_key))
		if not CONTROL_BINDING_ACTIONS.has(action_name):
			continue
		var event := _dictionary_to_input_event(gamepad_bindings[action_key])
		if event:
			_apply_binding_event(action_name, BINDING_FAMILY_GAMEPAD, event)

func _set_bus_volume(bus_name: StringName, value: float, ceiling_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var linear_volume := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume) + ceiling_db)

func _capture_current_display_defaults() -> void:
	resolution = DisplayServer.window_get_size()
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	fullscreen = current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _capture_default_control_events() -> void:
	_default_control_events.clear()
	for action_name in CONTROL_BINDING_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		var event_copies: Array[InputEvent] = []
		for event in InputMap.action_get_events(action_name):
			event_copies.append(event.duplicate() as InputEvent)
		_default_control_events[action_name] = event_copies

func _restore_default_control_events() -> void:
	for action_name in CONTROL_BINDING_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		var default_events: Array[InputEvent] = _default_control_events.get(action_name, []) as Array[InputEvent]
		for event in default_events:
			InputMap.action_add_event(action_name, event.duplicate() as InputEvent)

func _get_binding_event(action_name: StringName, family: String) -> InputEvent:
	var binding_store := keyboard_bindings if family == BINDING_FAMILY_KEYBOARD else gamepad_bindings
	var action_key := String(action_name)
	if binding_store.has(action_key):
		var stored_event := _dictionary_to_input_event(binding_store[action_key])
		if stored_event:
			return stored_event
	if not InputMap.has_action(action_name):
		return null
	for event in InputMap.action_get_events(action_name):
		if family == BINDING_FAMILY_KEYBOARD and _is_keyboard_binding_event(event):
			return event
		if family == BINDING_FAMILY_GAMEPAD and _is_gamepad_binding_event(event):
			return event
	return null

func _apply_binding_event(action_name: StringName, family: String, event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		return
	var existing_events: Array[InputEvent] = []
	for existing_event in InputMap.action_get_events(action_name):
		existing_events.append(existing_event)
	for existing_event in existing_events:
		if _should_remove_binding_event(existing_event, family, event):
			InputMap.action_erase_event(action_name, existing_event)
	InputMap.action_add_event(action_name, event.duplicate() as InputEvent)

func _should_remove_binding_event(existing_event: InputEvent, family: String, replacement_event: InputEvent) -> bool:
	if family == BINDING_FAMILY_KEYBOARD:
		return _is_keyboard_binding_event(existing_event)
	if replacement_event is InputEventJoypadButton:
		return existing_event is InputEventJoypadButton
	if replacement_event is InputEventJoypadMotion:
		return existing_event is InputEventJoypadMotion
	return _is_gamepad_binding_event(existing_event)

func _is_keyboard_binding_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton

func _is_gamepad_binding_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func _input_event_to_dictionary(event: InputEvent) -> Dictionary:
	var key_event := event as InputEventKey
	if key_event:
		return {
			"type": "key",
			"keycode": key_event.keycode,
			"physical_keycode": key_event.physical_keycode,
		}
	var mouse_event := event as InputEventMouseButton
	if mouse_event:
		return {
			"type": "mouse_button",
			"button_index": mouse_event.button_index,
		}
	var joypad_button_event := event as InputEventJoypadButton
	if joypad_button_event:
		return {
			"type": "joypad_button",
			"button_index": joypad_button_event.button_index,
		}
	var joypad_motion_event := event as InputEventJoypadMotion
	if joypad_motion_event:
		return {
			"type": "joypad_motion",
			"axis": joypad_motion_event.axis,
			"axis_value": joypad_motion_event.axis_value,
		}
	return {}

func _dictionary_to_input_event(value: Variant) -> InputEvent:
	var data := value as Dictionary
	if data == null:
		return null
	var event_type := String(data.get("type", ""))
	match event_type:
		"key":
			var key_event := InputEventKey.new()
			key_event.pressed = true
			key_event.keycode = int(data.get("keycode", 0)) as Key
			key_event.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			return key_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.pressed = true
			mouse_event.button_index = int(data.get("button_index", MOUSE_BUTTON_LEFT)) as MouseButton
			return mouse_event
		"joypad_button":
			var joypad_button_event := InputEventJoypadButton.new()
			joypad_button_event.pressed = true
			joypad_button_event.button_index = int(data.get("button_index", JOY_BUTTON_A)) as JoyButton
			return joypad_button_event
		"joypad_motion":
			var joypad_motion_event := InputEventJoypadMotion.new()
			joypad_motion_event.axis = int(data.get("axis", JOY_AXIS_LEFT_X)) as JoyAxis
			joypad_motion_event.axis_value = float(data.get("axis_value", 1.0))
			return joypad_motion_event
	return null

func _can_apply_window_display_settings() -> bool:
	# The editor's embedded game window cannot be resized or fullscreened.
	return not OS.has_feature("editor")

func _get_safe_window_resolution() -> Vector2i:
	var safe_resolution: Vector2i = resolution
	if safe_resolution.x <= 0 or safe_resolution.y <= 0:
		safe_resolution = DEFAULT_RESOLUTION
	var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	if screen_size.x > 0 and screen_size.y > 0:
		safe_resolution.x = mini(safe_resolution.x, screen_size.x)
		safe_resolution.y = mini(safe_resolution.y, screen_size.y)
	return safe_resolution

func _apply_default_content_scale() -> void:
	if _can_apply_window_display_settings() == false:
		return
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	root_window.content_scale_factor = 1.0

func _apply_windowed_resolution(safe_resolution: Vector2i) -> void:
	if _can_apply_window_display_settings() == false:
		return
	if safe_resolution.x <= 0 or safe_resolution.y <= 0:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(safe_resolution)
	_center_window_on_current_screen()

func _center_window_on_current_screen() -> void:
	if _can_apply_window_display_settings() == false:
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_position: Vector2i = DisplayServer.screen_get_position(screen_index)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_index)
	var window_size: Vector2i = DisplayServer.window_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return
	var centered_position: Vector2i = screen_position + ((screen_size - window_size) / 2)
	DisplayServer.window_set_position(centered_position)

func _variant_to_resolution(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		var vector_value := value as Vector2
		return Vector2i(int(vector_value.x), int(vector_value.y))
	return DEFAULT_RESOLUTION
