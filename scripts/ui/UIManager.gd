# res://scripts/ui/UIManager.gd
extends Node

@export var health_name_label: Label
@export var journal_screen: CanvasItem
@export var journal_label: Label
@export var journal_button: BaseButton
@export var info_label: RichTextLabel
@export var use_action: BaseButton
@export var special_action: BaseButton
@export var use_action_background: CanvasItem
@export var special_action_background: CanvasItem
@export var examine_sprite: CanvasItem
@export var repair_sprite: CanvasItem
@export var use_action_key_label: Label
@export var special_action_key_label: Label
@export var journal_action_key_label: Label
@export var swap_action_key_label: Label
@export var journalist_hud: Node2D
@export var journalist_life_bar: Sprite2D
@export var journalist_life_mask: Sprite2D
@export var journalist_hud_sprite: Sprite2D
@export var journalist_hud_mask: Sprite2D
@export var gsa_hud: Node2D
@export var gsa_life_bar: Sprite2D
@export var gsa_life_mask: Sprite2D
@export var gsa_hud_sprite: Sprite2D
@export var gsa_hud_mask: Sprite2D

@export var journalist: CharacterBase
@export var gsa: CharacterBase

const HUD_MASK_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D mask_texture : source_color;
uniform vec2 mask_inv_x = vec2(1.0, 0.0);
uniform vec2 mask_inv_y = vec2(0.0, 1.0);
uniform vec2 mask_inv_origin = vec2(0.0, 0.0);
uniform vec2 mask_tex_size = vec2(1.0, 1.0);
uniform vec2 mask_draw_origin = vec2(0.0, 0.0);
uniform bool invert_mask = false;
uniform float mask_mix = 0.0;

varying vec2 mask_world_pos;

void vertex() {
	mask_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	vec2 mask_local = vec2(
		mask_inv_x.x * mask_world_pos.x + mask_inv_y.x * mask_world_pos.y + mask_inv_origin.x,
		mask_inv_x.y * mask_world_pos.x + mask_inv_y.y * mask_world_pos.y + mask_inv_origin.y
	);
	vec2 mask_uv = (mask_local - mask_draw_origin) / mask_tex_size;
	float masked_alpha = 1.0;

	if (mask_uv.x >= 0.0 && mask_uv.x <= 1.0 && mask_uv.y >= 0.0 && mask_uv.y <= 1.0) {
		vec4 mask_sample = texture(mask_texture, mask_uv);
		float mask_value = dot(mask_sample.rgb, vec3(0.299, 0.587, 0.114));
		masked_alpha = invert_mask ? (1.0 - mask_value) : mask_value;
	}

	float keep_alpha = mix(1.0, masked_alpha, clamp(mask_mix, 0.0, 1.0));
	base_color.a *= keep_alpha;
	COLOR = base_color;
}
"""

const LIFE_BAR_SHADER_CODE := """
shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D shape_mask_texture : source_color;
uniform float use_external_mask = 0.0;
uniform sampler2D hud_mask_texture : source_color;
uniform vec2 hud_mask_inv_x = vec2(1.0, 0.0);
uniform vec2 hud_mask_inv_y = vec2(0.0, 1.0);
uniform vec2 hud_mask_inv_origin = vec2(0.0, 0.0);
uniform vec2 hud_mask_tex_size = vec2(1.0, 1.0);
uniform vec2 hud_mask_draw_origin = vec2(0.0, 0.0);
uniform bool hud_mask_invert = false;
uniform float hud_mask_mix = 0.0;

varying vec2 hud_mask_world_pos;

void vertex() {
	hud_mask_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base_sample = texture(TEXTURE, UV);
	vec4 base_color = base_sample * COLOR;
	vec4 mask_sample = texture(shape_mask_texture, UV);
	float mask_alpha = mix(base_sample.a, mask_sample.a, clamp(use_external_mask, 0.0, 1.0));
	float fill_alpha = step(UV.x, clamp(fill_ratio, 0.0, 1.0));
	vec2 hud_mask_local = vec2(
		hud_mask_inv_x.x * hud_mask_world_pos.x + hud_mask_inv_y.x * hud_mask_world_pos.y + hud_mask_inv_origin.x,
		hud_mask_inv_x.y * hud_mask_world_pos.x + hud_mask_inv_y.y * hud_mask_world_pos.y + hud_mask_inv_origin.y
	);
	vec2 hud_mask_uv = (hud_mask_local - hud_mask_draw_origin) / hud_mask_tex_size;
	float hud_mask_alpha = 1.0;
	if (hud_mask_uv.x >= 0.0 && hud_mask_uv.x <= 1.0 && hud_mask_uv.y >= 0.0 && hud_mask_uv.y <= 1.0) {
		vec4 hud_mask_sample = texture(hud_mask_texture, hud_mask_uv);
		float hud_mask_value = dot(hud_mask_sample.rgb, vec3(0.299, 0.587, 0.114));
		hud_mask_alpha = hud_mask_invert ? (1.0 - hud_mask_value) : hud_mask_value;
	}
	float combined_hud_mask_alpha = mix(1.0, hud_mask_alpha, clamp(hud_mask_mix, 0.0, 1.0));
	base_color.a *= mask_alpha * fill_alpha * combined_hud_mask_alpha;
	COLOR = base_color;
}
"""

const SPECIAL_ACTION_SHADER_CODE := """
shader_type canvas_item;

uniform float icon_alpha = 1.0;
uniform float wipe_progress : hint_range(0.0, 1.0) = 1.0;
uniform bool progress_highlight_enabled = false;

void fragment() {
	vec4 base_sample = texture(TEXTURE, UV) * COLOR;
	vec2 centered = UV - vec2(0.5, 0.5);
	float angle = atan(centered.x, -centered.y);
	float normalized_angle = fract((angle / (2.0 * PI)) + 1.0);
	float visible_sector = step(normalized_angle, clamp(wipe_progress, 0.0, 1.0));
	float radius_mask = step(length(centered), 0.7072);
	float progress_alpha = mix(icon_alpha, 1.0, visible_sector * radius_mask);
	base_sample.a *= progress_highlight_enabled ? progress_alpha : icon_alpha;
	COLOR = base_sample;
}
"""

var _info_tween: Tween = null
var _primary_hud_position: Vector2 = Vector2.ZERO
var _primary_hud_scale: Vector2 = Vector2.ONE
var _secondary_hud_position: Vector2 = Vector2.ZERO
var _secondary_hud_scale: Vector2 = Vector2.ONE
static var _shared_hud_mask_shader: Shader
var _primary_life_bar_position: Vector2 = Vector2.ZERO
var _primary_life_bar_scale: Vector2 = Vector2.ONE
var _secondary_life_bar_position: Vector2 = Vector2.ZERO
var _secondary_life_bar_scale: Vector2 = Vector2.ONE
var _primary_hud_mask_position: Vector2 = Vector2.ZERO
var _primary_hud_mask_scale: Vector2 = Vector2.ONE
var _secondary_hud_mask_position: Vector2 = Vector2.ZERO
var _secondary_hud_mask_scale: Vector2 = Vector2.ONE
static var _shared_life_bar_shader: Shader
static var _shared_special_action_shader: Shader
var _info_bottom_offset := 0.0

const ACTION_BACKGROUND_NEUTRAL_ALPHA := 192.0 / 255.0
const ACTION_BACKGROUND_HOVER_ALPHA := 212.0 / 255.0
const ACTION_BACKGROUND_PRESSED_ALPHA := 1.0

@onready var _journal_open_audio: AudioStreamPlayer = _resolve_ui_audio_player(NodePath("../UI/UIRoot/HUDRoot/JournalOpenAudio"))
@onready var _journal_close_audio: AudioStreamPlayer = _resolve_ui_audio_player(NodePath("../UI/UIRoot/HUDRoot/JournalCloseAudio"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_force_overlay_root_visible()
	if journal_screen:
		journal_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		journal_screen.visible = false
	GameState.set_journal_open(false)
	if info_label:
		info_label.bbcode_enabled = true
		info_label.fit_content = true
		info_label.modulate.a = 0.0
		_info_bottom_offset = info_label.offset_bottom
	if journal_button:
		journal_button.process_mode = Node.PROCESS_MODE_ALWAYS
		journal_button.pressed.connect(_on_journal_button_pressed)
	if use_action:
		use_action.process_mode = Node.PROCESS_MODE_ALWAYS
		use_action.pressed.connect(_on_use_action_button_pressed)
	if special_action:
		special_action.process_mode = Node.PROCESS_MODE_ALWAYS
		special_action.pressed.connect(_on_special_action_button_pressed)
	_configure_action_button_background(use_action, use_action_background)
	_configure_action_button_background(special_action, special_action_background)
	_capture_hud_slots()
	_configure_life_bar(journalist_life_bar, journalist_life_mask)
	_configure_life_bar(gsa_life_bar, gsa_life_mask)
	_configure_hud_mask(journalist_hud_sprite, journalist_hud_mask)
	_configure_hud_mask(gsa_hud_sprite, gsa_hud_mask)
	_configure_special_action_sprite(use_action_background)
	_configure_special_action_sprite(special_action_background)
	_configure_special_action_sprite(examine_sprite)
	_configure_special_action_sprite(repair_sprite)
	_refresh_gsa_hud_visibility()
	GameState.active_character_changed.connect(_refresh_health)
	GameState.active_character_changed.connect(_refresh_special_action_state)
	GameState.active_character_changed.connect(_refresh_hud_layout)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.pause_changed.connect(_on_pause_changed)
	NotesManager.note_added.connect(_on_note_added)
	InputRouter.special_action_requested.connect(_on_special_action_requested)
	InputRouter.interact_requested.connect(_on_interact_requested)
	InputRouter.open_journal_requested.connect(_on_open_journal_requested)
	InputRouter.ui_cancel_requested.connect(_on_ui_cancel_requested)
	InputRouter.input_device_family_changed.connect(_on_input_device_family_changed)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	if journalist:
		journalist.health_changed.connect(_on_health_changed)
		journalist.death_sequence_completed.connect(_on_character_death_sequence_completed)
		_bind_special_signals(journalist, "journalist")
	if gsa:
		gsa.health_changed.connect(_on_health_changed)
		gsa.death_sequence_completed.connect(_on_character_death_sequence_completed)
		_bind_special_signals(gsa, "gsa")
	_refresh_health(GameState.active_character_id)
	_refresh_special_action_state(GameState.active_character_id)
	_refresh_hud_layout(GameState.active_character_id)
	_refresh_action_key_labels()
	_refresh_journal()

func _refresh_health(active_id: String) -> void:
	_refresh_life_bars()
	if health_name_label:
		if active_id == "journalist":
			health_name_label.text = "The Journalist"
		elif active_id == "gsa":
			health_name_label.text = "Gas Station Attendant"
		else:
			health_name_label.text = ""

func _on_health_changed(_new_health: int) -> void:
	_refresh_health(GameState.active_character_id)

func _force_overlay_root_visible() -> void:
	if journal_screen == null:
		return
	var overlay_root: CanvasItem = journal_screen.get_parent() as CanvasItem
	if overlay_root != null:
		overlay_root.visible = true

func _on_character_death_sequence_completed() -> void:
	GameState.set_paused(true, GameState.PauseReason.DEATH)


func _on_flag_changed(flag: String, value: bool) -> void:
	if flag == "gsa_discovered" and value:
		_refresh_gsa_hud_visibility()
	elif flag == "wrench_passed" and value:
		_refresh_special_action_state(GameState.active_character_id)

func _on_special_action_requested() -> void:
	_flash_action_button_background(special_action, special_action_background)

func _on_interact_requested() -> void:
	_flash_action_button_background(use_action, use_action_background)

func _on_special_action_button_pressed() -> void:
	InputRouter.request_special_action()
	_mark_input_handled()

func _on_use_action_button_pressed() -> void:
	InputRouter.request_interact()
	_mark_input_handled()

func _on_open_journal_requested() -> void:
	_toggle_journal()
	_mark_input_handled()

func _on_journal_button_pressed() -> void:
	InputRouter.request_open_journal()
	_mark_input_handled()

func _on_input_device_family_changed(_family: String) -> void:
	_refresh_action_key_labels()

func _on_settings_changed(section: StringName) -> void:
	if section == &"controls":
		_refresh_action_key_labels()

func _on_ui_cancel_requested() -> void:
	if journal_screen and journal_screen.visible:
		_close_journal()
		_mark_input_handled()

func _on_pause_changed(paused: bool, _reason: int) -> void:
	if paused:
		_close_journal()
	if journal_button:
		journal_button.disabled = paused

func _bind_special_signals(character: CharacterBase, character_id: String) -> void:
	character.special_action_started.connect(func(_action_id: String, _duration: float, is_effective: bool) -> void:
		_on_special_started(character_id, is_effective)
	)
	character.special_action_progress.connect(func(_action_id: String, progress: float) -> void:
		_on_special_progress(character_id, progress)
	)
	character.special_action_completed.connect(func(_action_id: String, was_effective: bool) -> void:
		_on_special_completed(character_id, was_effective)
	)
	character.special_action_canceled.connect(func(_action_id: String) -> void:
		_on_special_canceled(character_id)
	)

func _on_special_started(character_id: String, _is_effective: bool) -> void:
	if GameState.active_character_id != character_id:
		return
	for item: CanvasItem in _get_active_special_action_wipe_items(character_id):
		_set_special_action_progress(item, 0.0)
		_set_special_action_base_alpha(item, 0.5)
		_set_special_action_progress_highlight(item, true)

func _on_special_progress(character_id: String, progress: float) -> void:
	if GameState.active_character_id != character_id:
		return
	for item: CanvasItem in _get_active_special_action_wipe_items(character_id):
		_set_special_action_progress(item, progress)

func _on_special_completed(character_id: String, _was_effective: bool) -> void:
	if GameState.active_character_id != character_id:
		return
	_refresh_special_action_state(character_id)

func _on_special_canceled(character_id: String) -> void:
	if GameState.active_character_id != character_id:
		return
	_refresh_special_action_state(character_id)
	var c := journalist if character_id == "journalist" else gsa
	if c == null:
		return
	if character_id == "journalist":
		c.say("journalist_cancel_action")
	else:
		c.say("gsa_cancel_action")

func _configure_action_button_background(button: BaseButton, background: CanvasItem) -> void:
	if background != null:
		_set_action_background_alpha(background, ACTION_BACKGROUND_NEUTRAL_ALPHA)
	if button == null or background == null:
		return
	button.mouse_entered.connect(_on_action_button_mouse_entered.bind(button, background))
	button.mouse_exited.connect(_on_action_button_mouse_exited.bind(button, background))
	button.button_down.connect(_on_action_button_down.bind(background))
	button.button_up.connect(_on_action_button_up.bind(button, background))

func _on_action_button_mouse_entered(_button: BaseButton, background: CanvasItem) -> void:
	_set_action_background_alpha(background, ACTION_BACKGROUND_HOVER_ALPHA)

func _on_action_button_mouse_exited(_button: BaseButton, background: CanvasItem) -> void:
	_set_action_background_alpha(background, ACTION_BACKGROUND_NEUTRAL_ALPHA)

func _on_action_button_down(background: CanvasItem) -> void:
	_set_action_background_alpha(background, ACTION_BACKGROUND_PRESSED_ALPHA)

func _on_action_button_up(button: BaseButton, background: CanvasItem) -> void:
	_refresh_action_button_background_alpha(button, background)

func _flash_action_button_background(button: BaseButton, background: CanvasItem) -> void:
	if background == null:
		return
	_set_action_background_alpha(background, ACTION_BACKGROUND_PRESSED_ALPHA)
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(_refresh_action_button_background_alpha.bind(button, background))

func _refresh_action_button_background_alpha(button: BaseButton, background: CanvasItem) -> void:
	if background == null:
		return
	if button != null and button.get_global_rect().has_point(button.get_global_mouse_position()):
		_set_action_background_alpha(background, ACTION_BACKGROUND_HOVER_ALPHA)
	else:
		_set_action_background_alpha(background, ACTION_BACKGROUND_NEUTRAL_ALPHA)

func _set_action_background_alpha(background: CanvasItem, alpha: float) -> void:
	if background == null:
		return
	background.modulate.a = clampf(alpha, 0.0, 1.0)

func _toggle_journal() -> void:
	if journal_screen == null:
		return
	if GameState.is_paused:
		return
	if journal_screen.visible:
		_close_journal()
		return
	_refresh_journal()
	journal_screen.visible = true
	GameState.set_journal_open(true)
	_play_ui_audio(_journal_open_audio)

func _close_journal() -> void:
	if journal_screen and journal_screen.visible:
		journal_screen.visible = false
		GameState.set_journal_open(false)
		_play_ui_audio(_journal_close_audio)

func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _on_note_added(note_id: String) -> void:
	_refresh_journal()
	_show_note_info_message(note_id)

func _refresh_journal() -> void:
	if journal_screen != null and journal_screen.has_method("set_notes"):
		journal_screen.call("set_notes", NotesManager.get_notes())
		return
	if journal_label == null:
		return
	journal_label.text = NotesManager.get_notes_text()

func _show_note_info_message(note_id: String) -> void:
	var note: Dictionary = NotesManager.get_note(note_id)
	var description: String = str(note.get("description", ""))
	var escaped_body := _escape_bbcode(description)
	var text := "[font name=res://data/res/NothingYouCouldDo-Regular.ttf][font_size=16][color=white][outline_size=1][outline_color=white]Journal Updated[/outline_color][/outline_size]"
	if escaped_body != "":
		text += "\n%s" % escaped_body
	text += "[/color][/font_size][/font]"
	_show_info_message(text)

func _show_info_message(text: String) -> void:
	if info_label == null:
		return
	info_label.text = text
	info_label.modulate.a = 0.0
	_resize_info_message_to_content()
	if _info_tween:
		_info_tween.kill()
	_info_tween = create_tween()
	_info_tween.tween_property(info_label, "modulate:a", 1.0, 0.25)
	_info_tween.tween_property(info_label, "modulate:a", 0.0, 0.25)
	_info_tween.tween_property(info_label, "modulate:a", 1.0, 0.25)
	_info_tween.tween_property(info_label, "modulate:a", 0.0, 0.25)
	_info_tween.tween_property(info_label, "modulate:a", 1.0, 0.25)
	_info_tween.tween_interval(10)
	_info_tween.tween_property(info_label, "modulate:a", 0.0, 1.0)

func _resize_info_message_to_content() -> void:
	if info_label == null:
		return
	await get_tree().process_frame
	if info_label == null:
		return
	var content_height: float = max(info_label.get_content_height(), 1.0)
	info_label.offset_bottom = _info_bottom_offset
	info_label.offset_top = _info_bottom_offset - content_height

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")

func _refresh_action_key_labels() -> void:
	_set_action_key_label(use_action_key_label, &"interact")
	_set_action_key_label(special_action_key_label, &"special_action")
	_set_action_key_label(journal_action_key_label, &"open_journal")
	_set_action_key_label(swap_action_key_label, &"switch_character")

func _set_action_key_label(label: Label, action_name: StringName) -> void:
	if label == null:
		return
	label.text = _format_action_binding(action_name)

func _format_action_binding(action_name: StringName) -> String:
	var event: InputEvent = null
	if InputRouter.get_input_device_family() == InputRouter.INPUT_DEVICE_GAMEPAD:
		event = SettingsManager.get_gamepad_binding_event(action_name)
	else:
		event = SettingsManager.get_keyboard_binding_event(action_name)
	if event == null:
		event = SettingsManager.get_keyboard_binding_event(action_name)
	if event == null:
		return ""
	return _normalize_action_key_text(_format_input_event(event))

func _normalize_action_key_text(text: String) -> String:
	if text.to_lower() == "tab":
		return "Tab"
	return text.to_upper()

func _format_input_event(event: InputEvent) -> String:
	var key_event := event as InputEventKey
	if key_event:
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		return OS.get_keycode_string(code)
	var mouse_event := event as InputEventMouseButton
	if mouse_event:
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "M1"
			MOUSE_BUTTON_RIGHT:
				return "M2"
			MOUSE_BUTTON_MIDDLE:
				return "M3"
			_:
				return "M%d" % mouse_event.button_index
	var joypad_button_event := event as InputEventJoypadButton
	if joypad_button_event:
		return _format_joypad_button(joypad_button_event.button_index)
	var joypad_motion_event := event as InputEventJoypadMotion
	if joypad_motion_event:
		return _format_joypad_motion(joypad_motion_event)
	return "Unknown"

func _format_joypad_button(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_DPAD_UP:
			return "D-Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Right"
		_:
			return "Btn %d" % button_index

func _format_joypad_motion(event: InputEventJoypadMotion) -> String:
	if event.axis == JOY_AXIS_LEFT_X:
		return "L Stick R" if event.axis_value > 0.0 else "L Stick L"
	if event.axis == JOY_AXIS_LEFT_Y:
		return "L Stick D" if event.axis_value > 0.0 else "L Stick U"
	return "Axis %d" % event.axis

func _configure_hud_mask(target_sprite: Sprite2D, mask_sprite: Sprite2D) -> void:
	if target_sprite == null or mask_sprite == null:
		return

	var mask_texture: Texture2D = mask_sprite.texture
	if mask_texture == null:
		return

	mask_sprite.visible = false
	if _shared_hud_mask_shader == null:
		_shared_hud_mask_shader = Shader.new()
		_shared_hud_mask_shader.code = HUD_MASK_SHADER_CODE

	var mask_material := ShaderMaterial.new()
	mask_material.shader = _shared_hud_mask_shader
	mask_material.set_shader_parameter("mask_texture", mask_texture)
	mask_material.set_shader_parameter("mask_tex_size", _get_mask_texture_size(mask_sprite, mask_texture))
	mask_material.set_shader_parameter("mask_draw_origin", _get_mask_draw_origin(mask_sprite, mask_texture))
	mask_material.set_shader_parameter("invert_mask", false)
	mask_material.set_shader_parameter("mask_mix", 0.0)
	target_sprite.material = mask_material
	_apply_hud_mask_to_material(mask_material, mask_sprite)

func _refresh_gsa_hud_visibility() -> void:
	var gsa_available: bool = GameState.get_flag("gsa_discovered")
	if gsa_hud != null:
		gsa_hud.visible = gsa_available
	if swap_action_key_label != null:
		swap_action_key_label.visible = gsa_available

func _refresh_hud_layout(active_id: String) -> void:
	if journalist_hud_sprite == null or gsa_hud_sprite == null:
		return

	if active_id == "gsa":
		_apply_hud_slot(gsa_hud_sprite, _primary_hud_position, _primary_hud_scale)
		_apply_hud_slot(journalist_hud_sprite, _secondary_hud_position, _secondary_hud_scale)
		_apply_life_bar_slot(gsa_life_bar, _primary_life_bar_position, _primary_life_bar_scale)
		_apply_life_bar_slot(journalist_life_bar, _secondary_life_bar_position, _secondary_life_bar_scale)
		_apply_hud_slot(gsa_hud_mask, _primary_hud_mask_position, _primary_hud_mask_scale)
		_apply_hud_slot(journalist_hud_mask, _secondary_hud_mask_position, _secondary_hud_mask_scale)
		_set_hud_mask_enabled(gsa_hud_sprite, false)
		_set_hud_mask_enabled(journalist_hud_sprite, true)
		_set_hud_mask_enabled(gsa_life_bar, false)
		_set_hud_mask_enabled(journalist_life_bar, true)
	else:
		_apply_hud_slot(journalist_hud_sprite, _primary_hud_position, _primary_hud_scale)
		_apply_hud_slot(gsa_hud_sprite, _secondary_hud_position, _secondary_hud_scale)
		_apply_life_bar_slot(journalist_life_bar, _primary_life_bar_position, _primary_life_bar_scale)
		_apply_life_bar_slot(gsa_life_bar, _secondary_life_bar_position, _secondary_life_bar_scale)
		_apply_hud_slot(journalist_hud_mask, _primary_hud_mask_position, _primary_hud_mask_scale)
		_apply_hud_slot(gsa_hud_mask, _secondary_hud_mask_position, _secondary_hud_mask_scale)
		_set_hud_mask_enabled(journalist_hud_sprite, false)
		_set_hud_mask_enabled(gsa_hud_sprite, true)
		_set_hud_mask_enabled(journalist_life_bar, false)
		_set_hud_mask_enabled(gsa_life_bar, true)
	_refresh_hud_mask_materials()

func _get_mask_texture_size(mask_sprite: Sprite2D, mask_texture: Texture2D) -> Vector2:
	if mask_sprite.region_enabled:
		return mask_sprite.region_rect.size
	return mask_texture.get_size()

func _get_mask_draw_origin(mask_sprite: Sprite2D, mask_texture: Texture2D) -> Vector2:
	var draw_origin: Vector2 = mask_sprite.offset
	var texture_size: Vector2 = _get_mask_texture_size(mask_sprite, mask_texture)
	if mask_sprite.centered:
		draw_origin -= texture_size * 0.5
	return draw_origin

func _capture_hud_slots() -> void:
	if journalist_hud_sprite != null:
		_primary_hud_position = journalist_hud_sprite.position
		_primary_hud_scale = journalist_hud_sprite.scale
	if journalist_life_bar != null:
		_primary_life_bar_position = journalist_life_bar.position
		_primary_life_bar_scale = journalist_life_bar.scale
	if journalist_hud_mask != null:
		_primary_hud_mask_position = journalist_hud_mask.position
		_primary_hud_mask_scale = journalist_hud_mask.scale
	if gsa_hud_sprite != null:
		_secondary_hud_position = gsa_hud_sprite.position
		_secondary_hud_scale = gsa_hud_sprite.scale
	if gsa_life_bar != null:
		_secondary_life_bar_position = gsa_life_bar.position
		_secondary_life_bar_scale = gsa_life_bar.scale
	if gsa_hud_mask != null:
		_secondary_hud_mask_position = gsa_hud_mask.position
		_secondary_hud_mask_scale = gsa_hud_mask.scale

func _apply_hud_slot(target_sprite: Sprite2D, slot_position: Vector2, slot_scale: Vector2) -> void:
	if target_sprite == null:
		return
	target_sprite.position = slot_position
	target_sprite.scale = slot_scale

func _configure_special_action_sprite(target_sprite: CanvasItem) -> void:
	if target_sprite == null:
		return
	if _shared_special_action_shader == null:
		_shared_special_action_shader = Shader.new()
		_shared_special_action_shader.code = SPECIAL_ACTION_SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _shared_special_action_shader
	shader_material.set_shader_parameter("icon_alpha", 1.0)
	shader_material.set_shader_parameter("wipe_progress", 1.0)
	shader_material.set_shader_parameter("progress_highlight_enabled", false)
	target_sprite.material = shader_material

func _refresh_special_action_state(active_id: String) -> void:
	if special_action != null:
		special_action.visible = true
	if use_action_background != null:
		_set_special_action_progress(use_action_background, 1.0)
		_set_special_action_base_alpha(use_action_background, 1.0)
		_set_special_action_progress_highlight(use_action_background, false)
	if special_action_background != null:
		_set_special_action_progress(special_action_background, 1.0)
		_set_special_action_base_alpha(special_action_background, 1.0)
		_set_special_action_progress_highlight(special_action_background, false)
	var show_journalist: bool = active_id == "journalist"
	if examine_sprite != null:
		examine_sprite.visible = show_journalist
		_set_special_action_progress(examine_sprite, 1.0)
		_set_special_action_base_alpha(examine_sprite, 1.0)
		_set_special_action_progress_highlight(examine_sprite, false)
	if repair_sprite != null:
		repair_sprite.visible = not show_journalist
		var repair_base_alpha: float = 1.0 if GameState.get_flag("wrench_passed") else 0.5
		_set_special_action_progress(repair_sprite, 1.0)
		_set_special_action_base_alpha(repair_sprite, repair_base_alpha)
		_set_special_action_progress_highlight(repair_sprite, false)

func _get_active_special_action_sprite(active_id: String) -> CanvasItem:
	return examine_sprite if active_id == "journalist" else repair_sprite

func _get_active_special_action_wipe_items(active_id: String) -> Array[CanvasItem]:
	var items: Array[CanvasItem] = []
	var sprite: CanvasItem = _get_active_special_action_sprite(active_id)
	if sprite != null:
		items.append(sprite)
	if special_action_background != null:
		items.append(special_action_background)
	return items

func _set_special_action_progress(target_sprite: CanvasItem, progress: float) -> void:
	if target_sprite == null:
		return
	var material_variant: Variant = target_sprite.material
	if not (material_variant is ShaderMaterial):
		return
	var shader_material: ShaderMaterial = material_variant as ShaderMaterial
	shader_material.set_shader_parameter("wipe_progress", clamp(progress, 0.0, 1.0))

func _set_special_action_base_alpha(target_sprite: CanvasItem, alpha: float) -> void:
	if target_sprite == null:
		return
	var material_variant: Variant = target_sprite.material
	if not (material_variant is ShaderMaterial):
		return
	var shader_material: ShaderMaterial = material_variant as ShaderMaterial
	shader_material.set_shader_parameter("icon_alpha", clamp(alpha, 0.0, 1.0))

func _set_special_action_progress_highlight(target_sprite: CanvasItem, enabled: bool) -> void:
	if target_sprite == null:
		return
	var material_variant: Variant = target_sprite.material
	if not (material_variant is ShaderMaterial):
		return
	var shader_material: ShaderMaterial = material_variant as ShaderMaterial
	shader_material.set_shader_parameter("progress_highlight_enabled", enabled)

func _set_hud_mask_enabled(target_sprite: Sprite2D, enabled: bool) -> void:
	if target_sprite == null:
		return
	var material_variant: Variant = target_sprite.material
	if not (material_variant is ShaderMaterial):
		return
	var shader_material: ShaderMaterial = material_variant as ShaderMaterial
	if shader_material.shader == _shared_hud_mask_shader:
		shader_material.set_shader_parameter("mask_mix", 1.0 if enabled else 0.0)
	elif shader_material.shader == _shared_life_bar_shader:
		shader_material.set_shader_parameter("hud_mask_mix", 1.0 if enabled else 0.0)

func _configure_life_bar(target_sprite: Sprite2D, mask_sprite: Sprite2D) -> void:
	if target_sprite == null:
		return
	if _shared_life_bar_shader == null:
		_shared_life_bar_shader = Shader.new()
		_shared_life_bar_shader.code = LIFE_BAR_SHADER_CODE

	if mask_sprite != null:
		mask_sprite.visible = false

	var fill_material := ShaderMaterial.new()
	fill_material.shader = _shared_life_bar_shader
	fill_material.set_shader_parameter("fill_ratio", 1.0)
	fill_material.set_shader_parameter("shape_mask_texture", _resolve_life_bar_mask_texture(target_sprite, mask_sprite))
	fill_material.set_shader_parameter("use_external_mask", 1.0 if mask_sprite != null and mask_sprite.texture != null else 0.0)
	fill_material.set_shader_parameter("hud_mask_mix", 0.0)
	target_sprite.material = fill_material
	_apply_hud_mask_to_material(fill_material, _resolve_hud_mask_for_target(target_sprite))

func _refresh_life_bars() -> void:
	_refresh_character_life_bar(journalist_life_bar, journalist)
	_refresh_character_life_bar(gsa_life_bar, gsa)

func _refresh_character_life_bar(target_sprite: Sprite2D, character: CharacterBase) -> void:
	if target_sprite == null or character == null:
		return
	var ratio: float = 0.0
	if character.max_health > 0:
		ratio = clamp(float(character.health) / float(character.max_health), 0.0, 1.0)
	_set_life_bar_ratio(target_sprite, ratio)

func _set_life_bar_ratio(target_sprite: Sprite2D, ratio: float) -> void:
	var material_variant: Variant = target_sprite.material
	if not (material_variant is ShaderMaterial):
		return
	var shader_material: ShaderMaterial = material_variant as ShaderMaterial
	shader_material.set_shader_parameter("fill_ratio", ratio)

func _resolve_life_bar_mask_texture(target_sprite: Sprite2D, mask_sprite: Sprite2D) -> Texture2D:
	if mask_sprite != null and mask_sprite.texture != null:
		return mask_sprite.texture
	return target_sprite.texture

func _apply_life_bar_slot(target_sprite: Sprite2D, slot_position: Vector2, slot_scale: Vector2) -> void:
	if target_sprite == null:
		return
	target_sprite.position = slot_position
	target_sprite.scale = slot_scale

func _refresh_hud_mask_materials() -> void:
	_refresh_hud_mask_material(journalist_hud_sprite, journalist_hud_mask)
	_refresh_hud_mask_material(journalist_life_bar, journalist_hud_mask)
	_refresh_hud_mask_material(gsa_hud_sprite, gsa_hud_mask)
	_refresh_hud_mask_material(gsa_life_bar, gsa_hud_mask)

func _refresh_hud_mask_material(target_sprite: Sprite2D, mask_sprite: Sprite2D) -> void:
	if target_sprite == null:
		return
	var material_variant: Variant = target_sprite.material
	if not (material_variant is ShaderMaterial):
		return
	_apply_hud_mask_to_material(material_variant as ShaderMaterial, mask_sprite)

func _apply_hud_mask_to_material(shader_material: ShaderMaterial, mask_sprite: Sprite2D) -> void:
	if shader_material == null or mask_sprite == null:
		return
	var mask_texture: Texture2D = mask_sprite.texture
	if mask_texture == null:
		return
	var inv: Transform2D = mask_sprite.get_global_transform().affine_inverse()
	var tex_size: Vector2 = _get_mask_texture_size(mask_sprite, mask_texture)
	var draw_origin: Vector2 = _get_mask_draw_origin(mask_sprite, mask_texture)
	if shader_material.shader == _shared_hud_mask_shader:
		shader_material.set_shader_parameter("mask_texture", mask_texture)
		shader_material.set_shader_parameter("mask_inv_x", inv.x)
		shader_material.set_shader_parameter("mask_inv_y", inv.y)
		shader_material.set_shader_parameter("mask_inv_origin", inv.origin)
		shader_material.set_shader_parameter("mask_tex_size", tex_size)
		shader_material.set_shader_parameter("mask_draw_origin", draw_origin)
	elif shader_material.shader == _shared_life_bar_shader:
		shader_material.set_shader_parameter("hud_mask_texture", mask_texture)
		shader_material.set_shader_parameter("hud_mask_inv_x", inv.x)
		shader_material.set_shader_parameter("hud_mask_inv_y", inv.y)
		shader_material.set_shader_parameter("hud_mask_inv_origin", inv.origin)
		shader_material.set_shader_parameter("hud_mask_tex_size", tex_size)
		shader_material.set_shader_parameter("hud_mask_draw_origin", draw_origin)

func _resolve_hud_mask_for_target(target_sprite: Sprite2D) -> Sprite2D:
	if target_sprite == journalist_hud_sprite or target_sprite == journalist_life_bar:
		return journalist_hud_mask
	if target_sprite == gsa_hud_sprite or target_sprite == gsa_life_bar:
		return gsa_hud_mask
	return null

func _resolve_ui_audio_player(path: NodePath) -> AudioStreamPlayer:
	var node: Node = get_node_or_null(path)
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node as AudioStreamPlayer
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = &"UI"
		player.volume_db = 0.0
		return player
	return null

func _play_ui_audio(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
