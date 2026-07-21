# res://scripts/ui/TitleScreen.gd
extends Control

@export_file("*.tscn") var intro_video_scene_path: String = "res://scenes/ui/IntroVideo.tscn"
@export var play_button: Button
@export var options_button: Button
@export var exit_button: Button
@export var initial_focus: Control
@export var options_panel: PanelContainer
@export var options_title: Label
@export var options_list: VBoxContainer
@export var play_on_accept_when_unfocused := true

const INPUT_FONT: FontFile = preload("res://data/res/NothingYouCouldDo-Regular.ttf")
const UI_ENTER_AUDIO_STREAM: AudioStream = preload("res://data/audio/sfx/ui_enter.wav")
const UI_CHANGE_AUDIO_STREAM: AudioStream = preload("res://data/audio/sfx/ui_change.wav")
const OPTION_COLOR := Color.BLACK
const PANEL_COLOR := Color(0.93, 0.88, 0.76, 0.94)
const ROW_NORMAL_COLOR := Color(1.0, 0.96, 0.84, 0.9)
const ROW_FOCUS_COLOR := Color(0.9843137, 0.7921569, 0.5176471, 0.8235294)
const DEFAULT_OPTION_ROW_WIDTH := 540.0
const OPTION_LABEL_COLUMN_CHARS := 18
const VOLUME_STEP := 5
const HELD_ADJUST_INITIAL_DELAY := 0.28
const HELD_ADJUST_REPEAT_INTERVAL := 0.08
const MUTE_CHECKMARK := "✓"
const CONTROL_DEVICE_KEYBOARD := "keyboard"
const CONTROL_DEVICE_GAMEPAD := "gamepad"
const CONTROL_SUBMODE_TOP := "top"
const CONTROL_SUBMODE_MOVE := "move"

const PREFERRED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(3840, 2160),
	Vector2i(3440, 1440),
	Vector2i(3200, 1800),
	Vector2i(2880, 1620),
	Vector2i(2560, 1440),
	Vector2i(2560, 1080),
	Vector2i(2048, 1152),
	Vector2i(1920, 1200),
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1440, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(1024, 768),
]

var _main_buttons: Array[Button] = []
var _options_panel: PanelContainer = null
var _options_title: Label = null
var _options_list: VBoxContainer = null
var _options_scroll: ScrollContainer = null
var _options_panel_skin: TitleOptionsPanel = null
var _option_buttons: Array[Button] = []
var _option_rows: Array[Dictionary] = []
var _display_resolutions: Array[Vector2i] = []
var _options_active := false
var _controls_device_family := CONTROL_DEVICE_KEYBOARD
var _controls_submode := CONTROL_SUBMODE_TOP
var _listening_button: Button = null
var _listening_action: StringName = &""
var _ui_enter_audio: AudioStreamPlayer = null
var _ui_change_audio: AudioStreamPlayer = null
var _held_adjust_direction := 0
var _held_adjust_timer := 0.0

func _ready() -> void:
	_configure_menu_feedback_audio()
	_configure_main_buttons()
	_configure_options_panel()
	_display_resolutions = _build_best_resolution_options()
	SettingsManager.settings_changed.connect(_on_settings_changed)
	var focus_target: Control = initial_focus if initial_focus != null else play_button
	if focus_target != null:
		focus_target.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _options_active:
		_handle_options_input(event)
		return
	if event.is_action_pressed("ui_accept") and play_on_accept_when_unfocused:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null:
			_on_play_pressed()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _options_active or _listening_button != null or _held_adjust_direction == 0:
		return
	_held_adjust_timer -= delta
	while _held_adjust_timer <= 0.0:
		if not _adjust_focused_option(_held_adjust_direction):
			_clear_held_adjust()
			return
		_held_adjust_timer += HELD_ADJUST_REPEAT_INTERVAL

func _configure_main_buttons() -> void:
	_main_buttons.clear()
	if play_button != null:
		_main_buttons.append(play_button)
		if not play_button.pressed.is_connected(_on_play_pressed):
			play_button.pressed.connect(_on_play_pressed)
	if options_button != null:
		_main_buttons.append(options_button)
		if not options_button.pressed.is_connected(_on_options_pressed):
			options_button.pressed.connect(_on_options_pressed)
	if exit_button != null:
		_main_buttons.append(exit_button)
		if not exit_button.pressed.is_connected(_on_exit_pressed):
			exit_button.pressed.connect(_on_exit_pressed)
	for index in range(_main_buttons.size()):
		var button: Button = _main_buttons[index]
		button.focus_neighbor_top = button.get_path_to(_main_buttons[posmod(index - 1, _main_buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(_main_buttons[posmod(index + 1, _main_buttons.size())])

func _configure_menu_feedback_audio() -> void:
	_ui_enter_audio = AudioStreamPlayer.new()
	_ui_enter_audio.name = "TitleUIEnterAudio"
	_ui_enter_audio.stream = UI_ENTER_AUDIO_STREAM
	_ui_enter_audio.bus = &"SFX"
	add_child(_ui_enter_audio)
	_ui_change_audio = AudioStreamPlayer.new()
	_ui_change_audio.name = "TitleUIChangeAudio"
	_ui_change_audio.stream = UI_CHANGE_AUDIO_STREAM
	_ui_change_audio.bus = &"SFX"
	add_child(_ui_change_audio)

func _play_ui_enter() -> void:
	if _ui_enter_audio == null:
		return
	_ui_enter_audio.stop()
	_ui_enter_audio.play()

func _play_ui_change() -> void:
	if _ui_change_audio == null:
		return
	_ui_change_audio.stop()
	_ui_change_audio.play()

func _configure_options_panel() -> void:
	_options_panel = options_panel
	_options_title = options_title
	_options_list = options_list
	_options_scroll = _options_list.get_parent() as ScrollContainer if _options_list != null else null
	_options_panel_skin = _options_panel as TitleOptionsPanel
	if _options_panel != null and _options_title != null and _options_list != null:
		_options_panel.visible = false
		_options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		_apply_options_panel_skin()
		return
	_build_fallback_options_panel()

func _build_fallback_options_panel() -> void:
	_options_panel = TitleOptionsPanel.new()
	_options_panel_skin = _options_panel as TitleOptionsPanel
	_options_panel.name = "TitleOptionsPanel"
	_options_panel.visible = false
	_options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_options_panel.set_anchors_preset(Control.PRESET_CENTER)
	_options_panel.custom_minimum_size = Vector2(620, 580)
	_options_panel.offset_left = -310.0
	_options_panel.offset_top = -290.0
	_options_panel.offset_right = 310.0
	_options_panel.offset_bottom = 290.0
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color.BLACK
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	_options_panel.add_theme_stylebox_override("panel", style)
	add_child(_options_panel)

	var root := VBoxContainer.new()
	root.name = "OptionsRoot"
	root.add_theme_constant_override("separation", 12)
	_options_panel.add_child(root)

	_options_title = Label.new()
	_options_title.text = "OPTIONS"
	_options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options_title.add_theme_font_override("font", INPUT_FONT)
	_options_title.add_theme_font_size_override("font_size", 28)
	_options_title.add_theme_color_override("font_color", OPTION_COLOR)
	root.add_child(_options_title)

	var scroll := ScrollContainer.new()
	scroll.name = "OptionsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_options_scroll = scroll

	_options_list = VBoxContainer.new()
	_options_list.name = "OptionsList"
	_options_list.add_theme_constant_override("separation", 6)
	_options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_options_list)
	_apply_options_panel_skin()

func _apply_options_panel_skin() -> void:
	if _options_panel_skin == null:
		return
	_options_panel_skin.apply_panel_style()
	if _options_list != null:
		_options_panel_skin.apply_options_list_style(_options_list)
	if _options_scroll != null:
		_options_panel_skin.apply_scroll_style(_options_scroll)

func _set_options_active(active: bool) -> void:
	_options_active = active
	_clear_held_adjust()
	if _options_panel != null:
		_options_panel.visible = active
	for button: Button in _main_buttons:
		button.visible = not active
		button.focus_mode = Control.FOCUS_NONE if active else Control.FOCUS_ALL
	if active:
		_controls_submode = CONTROL_SUBMODE_TOP
		_listening_button = null
		_listening_action = &""
		_rebuild_options_rows()
		_focus_first_option()
	else:
		if options_button != null:
			options_button.grab_focus()

func _rebuild_options_rows() -> void:
	_clear_held_adjust()
	_apply_options_panel_skin()
	for child in _options_list.get_children():
		child.queue_free()
	_option_buttons.clear()
	_option_rows = _get_options_rows()
	if _options_title != null:
		_options_title.text = "MOVE CONTROLS" if _controls_submode == CONTROL_SUBMODE_MOVE else "OPTIONS"
	for row_index in range(_option_rows.size()):
		var row: Dictionary = _option_rows[row_index]
		if String(row.get("type", "")) == "header":
			_options_list.add_child(_make_section_header(String(row.get("label", ""))))
			continue
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(_get_option_row_width(), 34)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", INPUT_FONT)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", OPTION_COLOR)
		button.add_theme_color_override("font_focus_color", OPTION_COLOR)
		button.add_theme_color_override("font_hover_color", OPTION_COLOR)
		button.add_theme_stylebox_override("normal", _make_option_row_style(false))
		button.add_theme_stylebox_override("hover", _make_option_row_style(true))
		button.add_theme_stylebox_override("focus", _make_option_row_style(true))
		button.add_theme_stylebox_override("pressed", _make_option_row_style(true))
		button.set_meta("row_index", row_index)
		button.pressed.connect(_activate_option_button.bind(button))
		button.focus_entered.connect(_on_option_button_focus_entered.bind(button))
		button.focus_exited.connect(_refresh_option_button_text)
		_options_list.add_child(button)
		_option_buttons.append(button)
	if _options_scroll != null:
		_options_scroll.scroll_vertical = 0
	_refresh_option_button_text()
	_configure_option_neighbors()

func _make_section_header(label: String) -> Label:
	var header := Label.new()
	header.focus_mode = Control.FOCUS_NONE
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size = Vector2(_get_option_row_width(), 16 if label.is_empty() else 28)
	header.text = label.to_upper()
	header.add_theme_font_override("font", INPUT_FONT)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", OPTION_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return header

func _get_option_row_width() -> float:
	if _options_panel_skin != null:
		return _options_panel_skin.option_row_width
	return DEFAULT_OPTION_ROW_WIDTH

func _make_option_row_style(selected: bool) -> StyleBoxFlat:
	if _options_panel_skin != null:
		return _options_panel_skin.make_option_row_style(selected)
	var color := ROW_FOCUS_COLOR if selected else ROW_NORMAL_COLOR
	return _make_row_style(color)

func _make_row_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0, 0, 0, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _configure_option_neighbors() -> void:
	for index in range(_option_buttons.size()):
		var button: Button = _option_buttons[index]
		button.focus_neighbor_top = button.get_path_to(_option_buttons[posmod(index - 1, _option_buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(_option_buttons[posmod(index + 1, _option_buttons.size())])

func _focus_first_option() -> void:
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()

func _on_option_button_focus_entered(button: Button) -> void:
	_refresh_option_button_text()
	_scroll_option_into_view.call_deferred(button)

func _scroll_option_into_view(button: Control) -> void:
	if _options_scroll == null or button == null or not is_instance_valid(button):
		return
	if not _option_buttons.is_empty() and button == _option_buttons[0]:
		_options_scroll.scroll_vertical = 0
		return
	var visible_top := float(_options_scroll.scroll_vertical)
	var visible_bottom := visible_top + _options_scroll.size.y
	var button_top := button.position.y
	var button_bottom := button_top + button.size.y
	if button_top < visible_top:
		_options_scroll.scroll_vertical = int(button_top)
	elif button_bottom > visible_bottom:
		_options_scroll.scroll_vertical = int(button_bottom - _options_scroll.size.y)

func _refresh_option_button_text() -> void:
	for button: Button in _option_buttons:
		var row: Dictionary = _get_button_row(button)
		var prefix := "> " if button.has_focus() else "  "
		button.text = prefix + _format_option_row(row)

func _get_options_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _controls_submode == CONTROL_SUBMODE_MOVE:
		rows.append({"type": "header", "label": "Controls"})
		if _controls_device_family == CONTROL_DEVICE_KEYBOARD:
			rows.append(_binding_row(&"move_up", "Move Up"))
			rows.append(_binding_row(&"move_down", "Move Down"))
			rows.append(_binding_row(&"move_left", "Move Left"))
			rows.append(_binding_row(&"move_right", "Move Right"))
		else:
			rows.append({"type": "readonly", "label": "Move", "value": "L Stick"})
			rows.append(_binding_row(&"move_up", "D-Pad Up"))
			rows.append(_binding_row(&"move_down", "D-Pad Down"))
			rows.append(_binding_row(&"move_left", "D-Pad Left"))
			rows.append(_binding_row(&"move_right", "D-Pad Right"))
		rows.append({"type": "back", "label": "Return"})
		return rows
	rows.append({"type": "header", "label": "Audio"})
	rows.append({"type": "volume", "label": "Master Volume", "key": "master"})
	rows.append({"type": "volume", "label": "Music Volume", "key": "music"})
	rows.append({"type": "volume", "label": "SFX Volume", "key": "sfx"})
	rows.append({"type": "mute", "label": "Mute"})
	rows.append({"type": "header", "label": "Video"})
	rows.append({"type": "display", "label": "Display"})
	rows.append({"type": "resolution", "label": "Resolution"})
	rows.append({"type": "performance", "label": "Performance"})
	rows.append({"type": "fps", "label": "Show FPS"})
	rows.append({"type": "header", "label": "Controls"})
	rows.append({"type": "device", "label": "Input Type"})
	rows.append({"type": "move_group", "label": "Move"})
	rows.append(_binding_row(&"interact", "Use \\ Interact"))
	rows.append(_binding_row(&"special_action", "Special Action"))
	rows.append(_binding_row(&"open_journal", "Open Journal"))
	rows.append(_binding_row(&"switch_character", "Switch Character"))
	rows.append(_binding_row(&"cancel", "Pause \\ Back"))
	rows.append({"type": "header", "label": ""})
	rows.append({"type": "reset", "label": "Restore Defaults"})
	rows.append({"type": "return", "label": "Return"})
	return rows

func _binding_row(action_name: StringName, label: String) -> Dictionary:
	return {"type": "binding", "label": label, "action": action_name}

func _format_option_row(row: Dictionary) -> String:
	var row_type := String(row.get("type", ""))
	var label := String(row.get("label", ""))
	if _listening_button != null and _get_button_row(_listening_button) == row:
		return _format_option_value_row(label, "Press a key\\button...")
	match row_type:
		"volume":
			return _format_option_value_row(label, "%3d" % _get_volume_percent(String(row.get("key", ""))))
		"mute":
			return _format_option_value_row(label, "[%s]" % [MUTE_CHECKMARK if SettingsManager.muted else " "])
		"display":
			return _format_option_value_row(label, "Fullscreen" if SettingsManager.fullscreen else "Windowed")
		"resolution":
			if SettingsManager.fullscreen:
				return _format_option_value_row(label, "Native")
			return _format_option_value_row(label, _format_resolution(SettingsManager.resolution))
		"performance":
			return _format_option_value_row(label, _format_performance(SettingsManager.performance_preset))
		"fps":
			return _format_option_value_row(label, "[%s]" % [MUTE_CHECKMARK if SettingsManager.show_fps else " "])
		"device":
			return _format_option_value_row(label, "Keyboard\\Mouse" if _controls_device_family == CONTROL_DEVICE_KEYBOARD else "Gamepad")
		"move_group":
			return _format_option_value_row(label, _format_move_summary())
		"binding":
			return _format_option_value_row(label, _format_control_binding(row.get("action", &"") as StringName))
		"readonly":
			return _format_option_value_row(label, String(row.get("value", "")))
	return label

func _format_option_value_row(label: String, value: String) -> String:
	var format_string := "%-" + str(OPTION_LABEL_COLUMN_CHARS) + "s : %s"
	return format_string % [label, value]

func _handle_options_input(event: InputEvent) -> void:
	if _listening_button != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
			_clear_held_adjust()
			_listening_button = null
			_listening_action = &""
			_play_ui_enter()
			_refresh_option_button_text()
			get_viewport().set_input_as_handled()
			return
		var binding_event: InputEvent = _event_to_control_binding_event(event)
		if binding_event != null:
			_commit_control_binding(binding_event)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		_clear_held_adjust()
		if _controls_submode != CONTROL_SUBMODE_TOP:
			_controls_submode = CONTROL_SUBMODE_TOP
			_play_ui_enter()
			_rebuild_options_rows()
			_focus_first_option()
		else:
			_play_ui_enter()
			_set_options_active(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_begin_held_adjust(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_begin_held_adjust(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_left") and _held_adjust_direction < 0:
		_clear_held_adjust()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_right") and _held_adjust_direction > 0:
		_clear_held_adjust()
		get_viewport().set_input_as_handled()

func _activate_option_button(button: Button) -> void:
	_clear_held_adjust()
	var row: Dictionary = _get_button_row(button)
	match String(row.get("type", "")):
		"display":
			SettingsManager.set_fullscreen(not SettingsManager.fullscreen)
			_play_ui_enter()
		"mute":
			SettingsManager.set_muted(not SettingsManager.muted)
			_play_ui_enter()
		"fps":
			SettingsManager.set_show_fps(not SettingsManager.show_fps)
			_play_ui_enter()
		"move_group":
			_controls_submode = CONTROL_SUBMODE_MOVE
			_play_ui_enter()
			_rebuild_options_rows()
			_focus_first_option()
			return
		"binding":
			_listening_button = button
			_listening_action = row.get("action", &"") as StringName
			_play_ui_enter()
		"device":
			_toggle_controls_device()
			_play_ui_enter()
		"reset":
			SettingsManager.reset_control_bindings()
			_play_ui_enter()
		"back":
			_controls_submode = CONTROL_SUBMODE_TOP
			_play_ui_enter()
			_rebuild_options_rows()
			_focus_first_option()
			return
		"return":
			_play_ui_enter()
			_set_options_active(false)
			return
		_:
			_adjust_focused_option(1)
	_refresh_option_button_text()

func _begin_held_adjust(direction: int) -> void:
	if not _adjust_focused_option(direction):
		_clear_held_adjust()
		return
	if _focused_option_supports_held_adjust():
		_held_adjust_direction = direction
		_held_adjust_timer = HELD_ADJUST_INITIAL_DELAY
	else:
		_clear_held_adjust()

func _clear_held_adjust() -> void:
	_held_adjust_direction = 0
	_held_adjust_timer = 0.0

func _focused_option_supports_held_adjust() -> bool:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or not _option_buttons.has(focused):
		return false
	var row_type := String(_get_button_row(focused).get("type", ""))
	if row_type == "resolution" and SettingsManager.fullscreen:
		return false
	return row_type == "volume" or row_type == "resolution" or row_type == "performance"

func _adjust_focused_option(direction: int) -> bool:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or not _option_buttons.has(focused):
		return false
	var row: Dictionary = _get_button_row(focused)
	var changed := false
	match String(row.get("type", "")):
		"volume":
			changed = _adjust_volume(String(row.get("key", "")), direction * VOLUME_STEP)
		"display":
			SettingsManager.set_fullscreen(direction > 0)
			changed = true
		"resolution":
			if SettingsManager.fullscreen:
				return false
			SettingsManager.set_resolution(_get_next_resolution_value(SettingsManager.resolution, -direction))
			changed = true
		"performance":
			var preset_count: int = SettingsManager.PerformancePreset.QUALITY + 1
			SettingsManager.set_performance_preset((SettingsManager.performance_preset + direction + preset_count) % preset_count)
			changed = true
		"device":
			_toggle_controls_device()
			changed = true
		"mute":
			SettingsManager.set_muted(not SettingsManager.muted)
			changed = true
		"fps":
			SettingsManager.set_show_fps(not SettingsManager.show_fps)
			changed = true
	if changed:
		_play_ui_change()
		_refresh_option_button_text()
	return changed

func _get_button_row(button: Button) -> Dictionary:
	var index: int = int(button.get_meta("row_index", -1))
	if index < 0 or index >= _option_rows.size():
		return {}
	return _option_rows[index]

func _adjust_volume(key: String, delta: int) -> bool:
	var value: int = _get_volume_percent(key)
	var next_value: int = clampi(value + delta, 0, 100)
	if next_value == value:
		return false
	var normalized: float = float(next_value) / 100.0
	match key:
		"master":
			SettingsManager.set_master_volume(normalized)
		"music":
			SettingsManager.set_music_volume(normalized)
		"sfx":
			SettingsManager.set_sfx_volume(normalized)
	return true

func _get_volume_percent(key: String) -> int:
	match key:
		"master":
			return int(round(SettingsManager.master_volume * 100.0))
		"music":
			return int(round(SettingsManager.music_volume * 100.0))
		"sfx":
			return int(round(SettingsManager.sfx_volume * 100.0))
	return 0

func _toggle_controls_device() -> void:
	_controls_device_family = CONTROL_DEVICE_GAMEPAD if _controls_device_family == CONTROL_DEVICE_KEYBOARD else CONTROL_DEVICE_KEYBOARD
	_rebuild_options_rows()

func _event_to_control_binding_event(event: InputEvent) -> InputEvent:
	if not event.is_pressed():
		return null
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo or key_event.alt_pressed:
			return null
		return key_event.duplicate() as InputEvent
	if event is InputEventMouseButton:
		return event.duplicate() as InputEvent
	if event is InputEventJoypadButton:
		return event.duplicate() as InputEvent
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) < 0.75:
			return null
		return motion_event.duplicate() as InputEvent
	return null

func _commit_control_binding(event: InputEvent) -> void:
	if _listening_action == &"":
		return
	if _controls_device_family == CONTROL_DEVICE_KEYBOARD:
		SettingsManager.set_keyboard_binding(_listening_action, event)
	else:
		SettingsManager.set_gamepad_binding(_listening_action, event)
	_listening_button = null
	_listening_action = &""
	_play_ui_change()
	_refresh_option_button_text()

func _format_control_binding(action_name: StringName) -> String:
	var event: InputEvent = SettingsManager.get_keyboard_binding_event(action_name) if _controls_device_family == CONTROL_DEVICE_KEYBOARD else SettingsManager.get_gamepad_binding_event(action_name)
	if event == null:
		return "Unset"
	return _format_input_event(event)

func _format_input_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "M1"
			MOUSE_BUTTON_RIGHT:
				return "M2"
			MOUSE_BUTTON_MIDDLE:
				return "M3"
			_:
				return "M%d" % mouse_event.button_index
	if event is InputEventJoypadButton:
		return _format_joypad_button((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		return _format_joypad_motion(event as InputEventJoypadMotion)
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

func _format_move_summary() -> String:
	if _controls_device_family == CONTROL_DEVICE_GAMEPAD:
		return "L Stick \\ D-Pad"
	var up_text := _format_control_binding(&"move_up")
	var left_text := _format_control_binding(&"move_left")
	var down_text := _format_control_binding(&"move_down")
	var right_text := _format_control_binding(&"move_right")
	if up_text == "W" and left_text == "A" and down_text == "S" and right_text == "D":
		return "WASD"
	return "%s\\%s\\%s\\%s" % [up_text, left_text, down_text, right_text]

func _format_performance(preset: int) -> String:
	match preset:
		SettingsManager.PerformancePreset.PERFORMANCE:
			return "Fast"
		SettingsManager.PerformancePreset.QUALITY:
			return "Nice"
	return "Balanced"

func _format_resolution(value: Vector2i) -> String:
	return "%d X %d" % [value.x, value.y]

func _get_next_resolution_value(current_resolution: Vector2i, offset: int) -> Vector2i:
	if _display_resolutions.is_empty():
		return SettingsManager.DEFAULT_RESOLUTION
	var current_index := _display_resolutions.find(current_resolution)
	if current_index < 0:
		current_index = 0
	var next_index := (current_index + offset + _display_resolutions.size()) % _display_resolutions.size()
	return _display_resolutions[next_index]

func _build_best_resolution_options() -> Array[Vector2i]:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var candidates: Array[Vector2i] = []
	_add_resolution_candidate(candidates, screen_size, screen_size)
	_add_resolution_candidate(candidates, SettingsManager.resolution, screen_size)
	_add_resolution_candidate(candidates, DisplayServer.window_get_size(), screen_size)
	for resolution_option: Vector2i in PREFERRED_RESOLUTIONS:
		_add_resolution_candidate(candidates, resolution_option, screen_size)
	candidates.sort_custom(_compare_resolution_descending)
	if candidates.is_empty():
		candidates.append(SettingsManager.DEFAULT_RESOLUTION)
	return candidates

func _compare_resolution_descending(a: Vector2i, b: Vector2i) -> bool:
	var area_a: int = a.x * a.y
	var area_b: int = b.x * b.y
	if area_a == area_b:
		return a.x > b.x
	return area_a > area_b

func _add_resolution_candidate(candidates: Array[Vector2i], value: Vector2i, screen_size: Vector2i) -> void:
	if value.x <= 0 or value.y <= 0:
		return
	if value.x > screen_size.x or value.y > screen_size.y:
		return
	if candidates.has(value):
		return
	candidates.append(value)

func _on_settings_changed(section: StringName) -> void:
	if section == &"display":
		_display_resolutions = _build_best_resolution_options()
	if _options_active:
		_refresh_option_button_text()

func _on_play_pressed() -> void:
	_reset_runtime_systems()
	if intro_video_scene_path == "":
		push_error("TitleScreen: intro_video_scene_path is not configured.")
		return
	SceneRouter.goto_scene(intro_video_scene_path)

func _on_options_pressed() -> void:
	_play_ui_enter()
	_set_options_active(true)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _reset_runtime_systems() -> void:
	DialogueManager.reset_runtime_state()
	InteractableManager.reset_runtime_state()
	NotesManager.reset_runtime_state()
	Inventory.reset_runtime_state()
	GameState.reset_runtime_state()
