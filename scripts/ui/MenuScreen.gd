# res://scripts/ui/MenuScreen.gd
extends Control

@export var menu_label: RichTextLabel
@export var continue_button: Button
@export var retry_button: Button
@export var option_button: Button
@export var quit_button: Button
@export var journal_screen: CanvasItem
@export var continue_label: Label
@export var retry_label: Label
@export var option_label: Label
@export var quit_label: Label
@export var continue_check_label: Label
@export var retry_check_label: Label
@export var option_check_label: Label
@export var quit_check_label: Label
@export var default_label_settings: LabelSettings
@export var selected_label_settings: LabelSettings
@export_file("*.tscn") var retry_scene_path: String = "res://scenes/levels/GasStation.tscn"

signal options_requested

@onready var _main_menu: CanvasItem = get_node_or_null("MainMenu") as CanvasItem
@onready var _options_menu: CanvasItem = get_node_or_null("OptionsMenu") as CanvasItem
@onready var _menu_header_left_label: RichTextLabel = get_node_or_null("MainMenu/MenuHeaderLeft2/MenuHeaderLeftLabel") as RichTextLabel
@onready var _menu_header_right_label: RichTextLabel = get_node_or_null("MainMenu/MenuHeaderRightLabel") as RichTextLabel
@onready var _return_button: Button = get_node_or_null("OptionsMenu/ReturnButton") as Button
@onready var _return_label: Label = get_node_or_null("OptionsMenu/ReturnButton/ReturnLabel") as Label
@onready var _death_stamp: CanvasItem = get_node_or_null("DeathStamp") as CanvasItem
@onready var _death_stamp_audio: AudioStreamPlayer = get_node_or_null("DeathStamp/DeadStampAudio") as AudioStreamPlayer
@onready var _solved_stamp: CanvasItem = get_node_or_null("SolvedStamp") as CanvasItem
@onready var _solved_stamp_audio: AudioStreamPlayer = get_node_or_null("SolvedStamp/SolvedStampAudio") as AudioStreamPlayer

var _continue_text: String = "Continue"
var _retry_text: String = "Retry"
var _option_text: String = "Options"
var _quit_text: String = "Quit"
var _return_text: String = "Return"
var _volume_controls: Array[Button] = []
var _display_mode_control: Button = null
var _display_mode_value_label: RichTextLabel = null
var _display_type_label: Label = null
var _resolution_control: Button = null
var _resolution_value_label: RichTextLabel = null
var _resolution_label: Label = null
var _preset_control: Button = null
var _preset_value_label: RichTextLabel = null
var _preset_label: Label = null
var _fps_control: Button = null
var _fps_value_label: RichTextLabel = null
var _fps_label: Label = null
var _controls_panel: Panel = null
var _controls_key_list_label: Label = null
var _controls_list_label: Label = null
var _controls_key_header_label: RichTextLabel = null
var _controls_header_label: RichTextLabel = null
var _controls_row_buttons: Array[Button] = []
var _controls_key_row_labels: Array[RichTextLabel] = []
var _controls_action_row_labels: Array[RichTextLabel] = []
var _options_controls: Array[Button] = []
var _display_resolutions: Array[Vector2i] = []
var _editing_volume_control: Button = null
var _editing_volume_original_value: float = 0.0
var _editing_display_mode_control: Button = null
var _editing_display_mode_original_fullscreen: bool = false
var _editing_display_mode_fullscreen: bool = false
var _editing_resolution_control: Button = null
var _editing_resolution_original: Vector2i = Vector2i.ZERO
var _editing_resolution_value: Vector2i = Vector2i.ZERO
var _editing_preset_control: Button = null
var _editing_preset_original: int = SettingsManager.PerformancePreset.BALANCED
var _editing_preset_value: int = SettingsManager.PerformancePreset.BALANCED
var _controls_device_family: String = "keyboard"
var _editing_controls_device_control: Button = null
var _editing_controls_device_original_family: String = "keyboard"
var _editing_controls_device_family: String = "keyboard"
var _listening_controls_control: Button = null
var _listening_controls_action: StringName = &""
var _controls_submode: String = "top"
var _dragging_volume_control: Button = null
var _drag_start_y: float = 0.0
var _drag_start_value: float = 0.0
var _input_focus_font: FontVariation = null
var _edit_flash_time: float = 0.0
var _held_edit_direction: float = 0.0
var _held_edit_repeat_timer: float = 0.0
var _options_active: bool = false
var _last_ui_joypad_motion_msec: Dictionary = {}
var _ui_enter_audio: AudioStreamPlayer = null
var _ui_change_audio: AudioStreamPlayer = null

const VOLUME_DRAG_PIXELS_PER_STEP := 4.0
const EDIT_FLASH_SPEED := 5.0
const EDIT_FLASH_MIN_ALPHA := 0.55
const EDIT_REPEAT_INITIAL_DELAY := 0.28
const EDIT_REPEAT_INTERVAL := 0.055
const UI_JOYPAD_MOTION_REPEAT_DELAY_MSEC := 220
const INPUT_FONT: FontFile = preload("res://data/res/NothingYouCouldDo-Regular.ttf")
const UI_ENTER_AUDIO_STREAM: AudioStream = preload("res://data/audio/sfx/ui_enter.wav")
const UI_CHANGE_AUDIO_STREAM: AudioStream = preload("res://data/audio/sfx/ui_change.wav")
const INPUT_FONT_COLOR := Color.BLACK
const INPUT_DISABLED_PREVIEW_COLOR := Color(0.68, 0.68, 0.68, 1.0)
const OPTION_TYPE_VOLUME := "volume"
const OPTION_TYPE_MUTE := "mute"
const OPTION_TYPE_DISPLAY_MODE := "display_mode"
const OPTION_TYPE_RESOLUTION := "resolution"
const OPTION_TYPE_PERFORMANCE_PRESET := "performance_preset"
const OPTION_TYPE_FPS := "fps"
const OPTION_TYPE_CONTROL_BINDING := "control_binding"
const OPTION_TYPE_CONTROLS_DEVICE := "controls_device"
const OPTION_TYPE_CONTROLS_RESET := "controls_reset"
const OPTION_TYPE_CONTROLS_BACK := "controls_back"
const OPTION_TYPE_CONTROLS_READONLY := "controls_readonly"
const OPTION_TYPE_CONTROLS_MOVE_GROUP := "controls_move_group"
const DISPLAY_MODE_FULLSCREEN := "fullscreen"
const DISPLAY_MODE_WINDOWED := "windowed"
const CONTROL_DEVICE_KEYBOARD := "keyboard"
const CONTROL_DEVICE_GAMEPAD := "gamepad"
const CONTROL_SUBMODE_TOP := "top"
const CONTROL_SUBMODE_MOVE := "move"
const MUTE_CHECKMARK := "✓"

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_menu_feedback_audio()
	visible = false
	if _death_stamp:
		_death_stamp.visible = false
	if _solved_stamp:
		_solved_stamp.visible = false
	_configure_volume_controls()
	_configure_display_controls()
	_configure_performance_controls()
	_configure_controls_panel()
	_configure_return_button()
	_configure_option_focus_neighbors()
	GameState.pause_changed.connect(_on_pause_changed)
	InputRouter.ui_down_requested.connect(_on_ui_down)
	InputRouter.ui_up_requested.connect(_on_ui_up)
	InputRouter.ui_accept_requested.connect(_on_ui_accept)
	InputRouter.ui_left_requested.connect(_on_ui_left)
	InputRouter.ui_right_requested.connect(_on_ui_right)
	InputRouter.ui_cancel_requested.connect(_on_ui_cancel)
	InputRouter.interact_requested.connect(_on_ui_accept)

	if continue_button:
		continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if continue_label:
			_continue_text = continue_label.text
		else:
			_continue_text = continue_button.text
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.focus_entered.connect(_refresh_focus)
		continue_button.focus_exited.connect(_refresh_focus)
	if retry_button:
		retry_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if retry_label:
			_retry_text = retry_label.text
		else:
			_retry_text = retry_button.text
		retry_button.pressed.connect(_on_retry_pressed)
		retry_button.focus_entered.connect(_refresh_focus)
		retry_button.focus_exited.connect(_refresh_focus)
	if option_button:
		option_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if option_label:
			_option_text = option_label.text
		else:
			_option_text = option_button.text
		option_button.pressed.connect(_on_options_pressed)
		option_button.focus_entered.connect(_refresh_focus)
		option_button.focus_exited.connect(_refresh_focus)
	if quit_button:
		quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
		if quit_label:
			_quit_text = quit_label.text
		else:
			_quit_text = quit_button.text
		quit_button.pressed.connect(_on_quit_pressed)
		quit_button.focus_entered.connect(_refresh_focus)
		quit_button.focus_exited.connect(_refresh_focus)
	_configure_focus_neighbors()
	_refresh_focus()

func _configure_menu_feedback_audio() -> void:
	_ui_enter_audio = AudioStreamPlayer.new()
	_ui_enter_audio.name = "UIEnterAudio"
	_ui_enter_audio.stream = UI_ENTER_AUDIO_STREAM
	_ui_enter_audio.bus = &"SFX"
	_ui_enter_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_enter_audio)

	_ui_change_audio = AudioStreamPlayer.new()
	_ui_change_audio.name = "UIChangeAudio"
	_ui_change_audio.stream = UI_CHANGE_AUDIO_STREAM
	_ui_change_audio.bus = &"SFX"
	_ui_change_audio.process_mode = Node.PROCESS_MODE_ALWAYS
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

func _process(delta: float) -> void:
	if _editing_volume_control == null and _editing_display_mode_control == null and _editing_resolution_control == null and _editing_preset_control == null and _editing_controls_device_control == null and _listening_controls_control == null:
		return
	_edit_flash_time += delta
	if _editing_volume_control != null and _held_edit_direction != 0.0:
		_held_edit_repeat_timer -= delta
		while _held_edit_repeat_timer <= 0.0:
			_adjust_volume_control(_editing_volume_control, _held_edit_direction)
			_held_edit_repeat_timer += EDIT_REPEAT_INTERVAL
	if _editing_volume_control != null:
		_refresh_volume_control_visuals()
	if _editing_display_mode_control != null:
		_refresh_display_option_visuals()
	if _editing_resolution_control != null:
		_refresh_display_option_visuals()
	if _editing_preset_control != null:
		_refresh_performance_option_visuals()
	if _editing_controls_device_control != null or _listening_controls_control != null:
		_refresh_controls_visuals()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening_controls_control:
		if _event_is_cancel_pressed(event):
			_cancel_control_binding_listen()
			_mark_input_handled()
			return
		var binding_event := _event_to_control_binding_event(event)
		if binding_event:
			_commit_control_binding_event(binding_event)
			_mark_input_handled()
			return
		if _is_any_ui_direction_motion_event(event):
			_mark_input_handled()
			return
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			_mark_input_handled()
			return

	if _editing_controls_device_control:
		if _is_ui_direction_pressed(event, "ui_left"):
			_stage_controls_device_family(CONTROL_DEVICE_KEYBOARD)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_right"):
			_stage_controls_device_family(CONTROL_DEVICE_GAMEPAD)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_up") or _is_ui_direction_pressed(event, "ui_down"):
			_mark_input_handled()
		elif _is_any_ui_direction_motion_event(event):
			_mark_input_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_commit_controls_device_edit()
			_mark_input_handled()
		elif _event_is_cancel_pressed(event):
			_cancel_controls_device_edit()
			_mark_input_handled()
		return

	if _editing_volume_control:
		if _is_ui_direction_pressed(event, "ui_up"):
			_adjust_editing_option(1.0)
			_begin_held_edit_direction(1.0)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_down"):
			_adjust_editing_option(-1.0)
			_begin_held_edit_direction(-1.0)
			_mark_input_handled()
		elif event.is_action_released("ui_up") and _held_edit_direction > 0.0:
			_clear_held_edit_direction()
			_mark_input_handled()
		elif event.is_action_released("ui_down") and _held_edit_direction < 0.0:
			_clear_held_edit_direction()
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_left") or _is_ui_direction_pressed(event, "ui_right"):
			_mark_input_handled()
		elif _is_any_ui_direction_motion_event(event):
			_mark_input_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_commit_volume_control(_editing_volume_control)
			_editing_volume_control = null
			_clear_held_edit_direction()
			_set_volume_focus_locked(false)
			_refresh_volume_control_visuals()
			_mark_input_handled()
		elif _event_is_cancel_pressed(event):
			_restore_option_control_original_value(_editing_volume_control)
			_editing_volume_control = null
			_clear_held_edit_direction()
			_set_volume_focus_locked(false)
			_refresh_volume_control_visuals()
			_mark_input_handled()
		return

	if _editing_display_mode_control:
		if _is_ui_direction_pressed(event, "ui_left"):
			_stage_display_mode_value(true)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_right"):
			_stage_display_mode_value(false)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_up") or _is_ui_direction_pressed(event, "ui_down"):
			_mark_input_handled()
		elif _is_any_ui_direction_motion_event(event):
			_mark_input_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_commit_display_mode_edit()
			_mark_input_handled()
		elif _event_is_cancel_pressed(event):
			_cancel_display_mode_edit()
			_mark_input_handled()
		return

	if _editing_resolution_control:
		if _is_ui_direction_pressed(event, "ui_left"):
			_stage_resolution_by_offset(-1)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_right"):
			_stage_resolution_by_offset(1)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_up") or _is_ui_direction_pressed(event, "ui_down"):
			_mark_input_handled()
		elif _is_any_ui_direction_motion_event(event):
			_mark_input_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_commit_resolution_edit()
			_mark_input_handled()
		elif _event_is_cancel_pressed(event):
			_cancel_resolution_edit()
			_mark_input_handled()
		return

	if _editing_preset_control:
		if _is_ui_direction_pressed(event, "ui_left"):
			_stage_performance_preset_by_offset(-1)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_right"):
			_stage_performance_preset_by_offset(1)
			_mark_input_handled()
		elif _is_ui_direction_pressed(event, "ui_up") or _is_ui_direction_pressed(event, "ui_down"):
			_mark_input_handled()
		elif _is_any_ui_direction_motion_event(event):
			_mark_input_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_commit_performance_preset_edit()
			_mark_input_handled()
		elif _event_is_cancel_pressed(event):
			_cancel_performance_preset_edit()
			_mark_input_handled()
		return

	if _handle_menu_direction_input(event):
		return

	var focused_volume_control := _get_focused_volume_control()
	if focused_volume_control and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		if _get_option_type(focused_volume_control) == OPTION_TYPE_MUTE:
			_toggle_mute_control(focused_volume_control)
			_mark_input_handled()
			return
		_editing_volume_control = focused_volume_control
		_editing_volume_original_value = _get_option_control_numeric_value(focused_volume_control)
		_play_ui_enter()
		_edit_flash_time = 0.0
		_clear_held_edit_direction()
		_set_volume_focus_locked(true)
		_refresh_volume_control_visuals()
		_mark_input_handled()
		return

	var focused_display_control := _get_focused_display_control()
	if focused_display_control and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_begin_display_mode_edit(focused_display_control)
		_mark_input_handled()
		return

	var focused_resolution_control := _get_focused_resolution_control()
	if focused_resolution_control and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_begin_resolution_edit(focused_resolution_control)
		_mark_input_handled()
		return

	var focused_performance_control := _get_focused_performance_control()
	if focused_performance_control and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		if focused_performance_control == _fps_control:
			_toggle_fps_control()
		else:
			_begin_performance_preset_edit(focused_performance_control)
		_mark_input_handled()
		return

	var focused_controls_control := _get_focused_controls_control()
	if focused_controls_control and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_activate_control_row(focused_controls_control)
		_mark_input_handled()

func _on_pause_changed(paused: bool, reason: int) -> void:
	visible = paused
	if not paused:
		_set_death_stamp_active(false)
		_set_solved_stamp_active(false)
		_set_options_active(false)
		_cancel_active_volume_edit()
		_editing_display_mode_control = null
		_editing_resolution_control = null
		_editing_preset_control = null
		_editing_controls_device_control = null
		_listening_controls_control = null
		_listening_controls_action = &""
		_set_display_mode_focus_locked(false)
		_set_resolution_focus_locked(false)
		_set_performance_preset_focus_locked(false)
		_refresh_display_option_visuals()
		_refresh_performance_option_visuals()
		_refresh_controls_visuals()
		return
	_set_death_stamp_active(reason == GameState.PauseReason.DEATH)
	_set_solved_stamp_active(reason == GameState.PauseReason.WIN)
	_set_options_active(false)
	_update_message(reason)
	if continue_button:
		continue_button.grab_focus()
	elif retry_button:
		retry_button.grab_focus()
	_refresh_focus()

func _set_death_stamp_active(active: bool) -> void:
	if _death_stamp:
		_death_stamp.visible = active
	if _death_stamp_audio == null:
		return
	if active:
		_death_stamp_audio.play()
	elif _death_stamp_audio.playing:
		_death_stamp_audio.stop()

func _set_solved_stamp_active(active: bool) -> void:
	if _solved_stamp:
		_solved_stamp.visible = active
	if _solved_stamp_audio == null:
		return
	if active:
		_solved_stamp_audio.play()
	elif _solved_stamp_audio.playing:
		_solved_stamp_audio.stop()

func _update_message(reason: int) -> void:
	_refresh_menu_header_labels()
	if menu_label:
		_set_heading_label_text(menu_label, _get_menu_title(reason))

func _get_menu_title(reason: int) -> String:
	match reason:
		GameState.PauseReason.DEATH:
			return "DEAD"
		GameState.PauseReason.WIN:
			return "SOLVED"
	return "PAUSED"

func _set_heading_label_text(label: RichTextLabel, value: String) -> void:
	if label.has_method("set_heading_text"):
		label.call("set_heading_text", value)
		return
	label.text = _format_fallback_heading(value)

func _format_fallback_heading(title: String) -> String:
	var upper_title := title.to_upper()
	if upper_title == "":
		return ""
	var first := upper_title.substr(0, 1)
	var rest := upper_title.substr(1)
	return "[font name=res://data/res/LibreBaskerville-VariableFont_wght.ttf][font_size=11][color=black][b]%s[/b][/color][/font_size][font_size=9][color=black][b]%s[/b][/color][/font_size][/font]" % [first, rest]

func _on_ui_down() -> void:
	if not visible:
		return
	var focused_volume_control := _get_focused_volume_control()
	var focused_display_control := _get_focused_display_control()
	var focused_resolution_control := _get_focused_resolution_control()
	var focused_performance_control := _get_focused_performance_control()
	if _editing_volume_control:
		_adjust_editing_option(-1.0)
		_mark_input_handled()
		return
	if _editing_display_mode_control:
		_mark_input_handled()
		return
	if _editing_resolution_control:
		_mark_input_handled()
		return
	if _editing_preset_control:
		_mark_input_handled()
		return
	if _editing_controls_device_control or _listening_controls_control:
		_mark_input_handled()
		return
	if focused_volume_control:
		_focus_options_vertical(1)
		_mark_input_handled()
		return
	if focused_display_control:
		_focus_options_vertical(1)
		_mark_input_handled()
		return
	if focused_resolution_control:
		_focus_options_vertical(1)
		_mark_input_handled()
		return
	if focused_performance_control:
		_focus_options_vertical(1)
		_mark_input_handled()
		return
	if _options_active:
		_focus_options_vertical(1)
		_mark_input_handled()
		return
	_focus_next()
	_mark_input_handled()

func _on_ui_up() -> void:
	if not visible:
		return
	var focused_volume_control := _get_focused_volume_control()
	var focused_display_control := _get_focused_display_control()
	var focused_resolution_control := _get_focused_resolution_control()
	var focused_performance_control := _get_focused_performance_control()
	if _editing_volume_control:
		_adjust_editing_option(1.0)
		_mark_input_handled()
		return
	if _editing_display_mode_control:
		_mark_input_handled()
		return
	if _editing_resolution_control:
		_mark_input_handled()
		return
	if _editing_preset_control:
		_mark_input_handled()
		return
	if _editing_controls_device_control or _listening_controls_control:
		_mark_input_handled()
		return
	if focused_volume_control:
		_focus_options_vertical(-1)
		_mark_input_handled()
		return
	if focused_display_control:
		_focus_options_vertical(-1)
		_mark_input_handled()
		return
	if focused_resolution_control:
		_focus_options_vertical(-1)
		_mark_input_handled()
		return
	if focused_performance_control:
		_focus_options_vertical(-1)
		_mark_input_handled()
		return
	if _options_active:
		_focus_options_vertical(-1)
		_mark_input_handled()
		return
	_focus_prev()
	_mark_input_handled()

func _on_ui_accept() -> void:
	if not visible:
		return
	var focused_volume_control := _get_focused_volume_control()
	var focused_display_control := _get_focused_display_control()
	var focused_resolution_control := _get_focused_resolution_control()
	var focused_performance_control := _get_focused_performance_control()
	var focused_controls_control := _get_focused_controls_control()
	if _listening_controls_control:
		_mark_input_handled()
		return
	if _editing_controls_device_control:
		_commit_controls_device_edit()
		_mark_input_handled()
		return
	if focused_volume_control:
		if _get_option_type(focused_volume_control) == OPTION_TYPE_MUTE:
			_toggle_mute_control(focused_volume_control)
			_mark_input_handled()
			return
		if _editing_volume_control == focused_volume_control:
			_commit_volume_control(focused_volume_control)
			_editing_volume_control = null
			_clear_held_edit_direction()
			_set_volume_focus_locked(false)
		else:
			_editing_volume_control = focused_volume_control
			_editing_volume_original_value = _get_option_control_numeric_value(focused_volume_control)
			_play_ui_enter()
			_edit_flash_time = 0.0
			_clear_held_edit_direction()
			_set_volume_focus_locked(true)
		_refresh_volume_control_visuals()
		_mark_input_handled()
		return
	if focused_display_control:
		if _editing_display_mode_control == focused_display_control:
			_commit_display_mode_edit()
		else:
			_begin_display_mode_edit(focused_display_control)
		_mark_input_handled()
		return
	if focused_resolution_control:
		if _editing_resolution_control == focused_resolution_control:
			_commit_resolution_edit()
		else:
			_begin_resolution_edit(focused_resolution_control)
		_mark_input_handled()
		return
	if focused_performance_control:
		if focused_performance_control == _fps_control:
			_toggle_fps_control()
		elif _editing_preset_control == focused_performance_control:
			_commit_performance_preset_edit()
		else:
			_begin_performance_preset_edit(focused_performance_control)
		_mark_input_handled()
		return
	if focused_controls_control:
		_activate_control_row(focused_controls_control)
		_mark_input_handled()
		return
	_activate_focused()
	_mark_input_handled()

func _on_ui_cancel() -> void:
	if _is_input_handled():
		return
	if _editing_volume_control:
		_restore_option_control_original_value(_editing_volume_control)
		_editing_volume_control = null
		_clear_held_edit_direction()
		_set_volume_focus_locked(false)
		_refresh_volume_control_visuals()
		_mark_input_handled()
		return
	if _editing_display_mode_control:
		_cancel_display_mode_edit()
		_mark_input_handled()
		return
	if _editing_resolution_control:
		_cancel_resolution_edit()
		_mark_input_handled()
		return
	if _editing_preset_control:
		_cancel_performance_preset_edit()
		_mark_input_handled()
		return
	if _listening_controls_control:
		_cancel_control_binding_listen()
		_mark_input_handled()
		return
	if _editing_controls_device_control:
		_cancel_controls_device_edit()
		_mark_input_handled()
		return
	if _controls_submode != CONTROL_SUBMODE_TOP:
		_set_controls_submode(CONTROL_SUBMODE_TOP)
		_mark_input_handled()
		return
	if _options_active:
		_return_to_main_menu()
		return
	if visible:
		if GameState.pause_reason == GameState.PauseReason.PAUSE:
			GameState.set_paused(false)
			_mark_input_handled()
		return
	if journal_screen and journal_screen.visible:
		return
	if not GameState.is_paused:
		GameState.set_paused(true, GameState.PauseReason.PAUSE)
		_mark_input_handled()

func _on_retry_pressed() -> void:
	DialogueManager.reset_runtime_state()
	InteractableManager.reset_runtime_state()
	NotesManager.reset_runtime_state()
	Inventory.reset_runtime_state()
	GameState.reset_runtime_state()
	if retry_scene_path == "":
		push_error("MenuScreen: retry_scene_path is not configured.")
		return
	SceneRouter.goto_scene(retry_scene_path)

func _on_continue_pressed() -> void:
	GameState.set_paused(false)

func _on_options_pressed() -> void:
	_play_ui_enter()
	_set_options_active(true)
	options_requested.emit()
	_focus_first_volume_control()

func _on_return_pressed() -> void:
	_return_to_main_menu()

func _on_ui_left() -> void:
	if not visible:
		return
	if _editing_volume_control:
		_mark_input_handled()
		return
	if _editing_display_mode_control:
		_stage_display_mode_value(true)
		_mark_input_handled()
		return
	if _editing_resolution_control:
		_stage_resolution_by_offset(-1)
		_mark_input_handled()
		return
	if _editing_preset_control:
		_stage_performance_preset_by_offset(-1)
		_mark_input_handled()
		return
	if _editing_controls_device_control:
		_stage_controls_device_family(CONTROL_DEVICE_KEYBOARD)
		_mark_input_handled()
		return
	if _options_active:
		_focus_opposite_options_section()
		_mark_input_handled()

func _on_ui_right() -> void:
	if not visible:
		return
	if _editing_volume_control:
		_mark_input_handled()
		return
	if _editing_display_mode_control:
		_stage_display_mode_value(false)
		_mark_input_handled()
		return
	if _editing_resolution_control:
		_stage_resolution_by_offset(1)
		_mark_input_handled()
		return
	if _editing_preset_control:
		_stage_performance_preset_by_offset(1)
		_mark_input_handled()
		return
	if _editing_controls_device_control:
		_stage_controls_device_family(CONTROL_DEVICE_GAMEPAD)
		_mark_input_handled()
		return
	if _options_active:
		_focus_opposite_options_section()
		_mark_input_handled()

func _handle_menu_direction_input(event: InputEvent) -> bool:
	if _is_ui_direction_pressed(event, "ui_up"):
		_on_ui_up()
		_mark_input_handled()
		return true
	if _is_ui_direction_pressed(event, "ui_down"):
		_on_ui_down()
		_mark_input_handled()
		return true
	if _is_ui_direction_pressed(event, "ui_left"):
		_on_ui_left()
		_mark_input_handled()
		return true
	if _is_ui_direction_pressed(event, "ui_right"):
		_on_ui_right()
		_mark_input_handled()
		return true
	if _is_any_ui_direction_motion_event(event):
		_mark_input_handled()
		return true
	return false

func _on_quit_pressed() -> void:
	GameState.set_paused(false)
	get_tree().quit()

func _refresh_focus() -> void:
	var continue_focused := continue_button and continue_button.has_focus()
	var retry_focused := retry_button and retry_button.has_focus()
	var option_focused := option_button and option_button.has_focus()
	var quit_focused := quit_button and quit_button.has_focus()
	if continue_label:
		continue_label.text = _continue_text
		continue_label.label_settings = selected_label_settings if continue_focused else default_label_settings
	if retry_label:
		retry_label.text = _retry_text
		retry_label.label_settings = selected_label_settings if retry_focused else default_label_settings
	if option_label:
		option_label.text = _option_text
		option_label.label_settings = selected_label_settings if option_focused else default_label_settings
	if quit_label:
		quit_label.text = _quit_text
		quit_label.label_settings = selected_label_settings if quit_focused else default_label_settings
	_refresh_return_button_visual()
	_refresh_display_option_visuals()
	_refresh_performance_option_visuals()
	_refresh_controls_visuals()
	if continue_check_label:
		continue_check_label.visible = continue_focused
	if retry_check_label:
		retry_check_label.visible = retry_focused
	if option_check_label:
		option_check_label.visible = option_focused
	if quit_check_label:
		quit_check_label.visible = quit_focused

func _set_options_active(active: bool) -> void:
	if _options_active == active:
		_refresh_menu_visibility()
		_refresh_menu_header_labels()
		return
	_options_active = active
	if not active:
		_cancel_active_volume_edit()
		_editing_display_mode_control = null
		_editing_resolution_control = null
		_editing_preset_control = null
		_set_display_mode_focus_locked(false)
		_set_resolution_focus_locked(false)
		_set_performance_preset_focus_locked(false)
		_refresh_display_option_visuals()
		_refresh_performance_option_visuals()
	_refresh_menu_visibility()
	_refresh_menu_header_labels()

func _refresh_menu_visibility() -> void:
	if _main_menu:
		_main_menu.visible = not _options_active
	if _options_menu:
		_options_menu.visible = _options_active

func _refresh_menu_header_labels() -> void:
	var header_text := "OPTIONS" if _options_active else "MENU"
	if _menu_header_left_label:
		_set_heading_label_text(_menu_header_left_label, header_text)
	if _menu_header_right_label:
		_set_heading_label_text(_menu_header_right_label, header_text)

func _return_to_main_menu() -> void:
	_play_ui_enter()
	_set_options_active(false)
	if option_button:
		option_button.grab_focus()
	_refresh_focus()
	_mark_input_handled()

func _focus_next() -> void:
	_focus_by_offset(1)

func _focus_prev() -> void:
	_focus_by_offset(-1)

func _activate_focused() -> void:
	var focused_display_control := _get_focused_display_control()
	var focused_resolution_control := _get_focused_resolution_control()
	var focused_performance_control := _get_focused_performance_control()
	if continue_button and continue_button.has_focus():
		_on_continue_pressed()
	elif retry_button and retry_button.has_focus():
		_on_retry_pressed()
	elif option_button and option_button.has_focus():
		_on_options_pressed()
	elif quit_button and quit_button.has_focus():
		_on_quit_pressed()
	elif focused_display_control:
		_begin_display_mode_edit(focused_display_control)
	elif focused_resolution_control:
		_begin_resolution_edit(focused_resolution_control)
	elif focused_performance_control == _fps_control:
		_toggle_fps_control()
	elif focused_performance_control:
		_begin_performance_preset_edit(focused_performance_control)
	elif _return_button and _return_button.has_focus():
		_on_return_pressed()

func _configure_focus_neighbors() -> void:
	var buttons := _get_menu_buttons()
	var button_count := buttons.size()
	if button_count == 0:
		return
	for index in range(button_count):
		var button := buttons[index]
		var prev_button := buttons[(index - 1 + button_count) % button_count]
		var next_button := buttons[(index + 1) % button_count]
		button.focus_neighbor_top = button.get_path_to(prev_button)
		button.focus_neighbor_bottom = button.get_path_to(next_button)

func _configure_option_focus_neighbors() -> void:
	var controls_section: Array[Button] = _get_visible_controls_section()
	var right_section: Array[Button] = _get_right_options_section()
	for index in range(controls_section.size()):
		var control: Button = controls_section[index]
		var previous: Button = controls_section[index - 1] if index > 0 else _return_button
		var next: Button = controls_section[index + 1] if index + 1 < controls_section.size() else _return_button
		_set_focus_neighbor(control, SIDE_TOP, previous)
		_set_focus_neighbor(control, SIDE_BOTTOM, next)
		var opposite: Button = _find_closest_vertical_control(control, right_section)
		_set_focus_neighbor(control, SIDE_LEFT, opposite)
		_set_focus_neighbor(control, SIDE_RIGHT, opposite)
	for index in range(right_section.size()):
		var control: Button = right_section[index]
		var previous: Button = right_section[index - 1] if index > 0 else _first_visible_control(controls_section)
		var next: Button = right_section[index + 1] if index + 1 < right_section.size() else _return_button
		_set_focus_neighbor(control, SIDE_TOP, previous)
		_set_focus_neighbor(control, SIDE_BOTTOM, next)
		var opposite: Button = _find_closest_vertical_control(control, controls_section)
		_set_focus_neighbor(control, SIDE_LEFT, opposite)
		_set_focus_neighbor(control, SIDE_RIGHT, opposite)
	if _return_button:
		var last_right: Button = right_section.back() if not right_section.is_empty() else null
		var first_controls: Button = _first_visible_control(controls_section)
		_set_focus_neighbor(_return_button, SIDE_TOP, last_right)
		_set_focus_neighbor(_return_button, SIDE_BOTTOM, first_controls)

func _focus_by_offset(offset: int) -> void:
	var buttons := _get_menu_buttons()
	if buttons.is_empty():
		return
	var focused_index := -1
	for index in range(buttons.size()):
		if buttons[index].has_focus():
			focused_index = index
			break
	if focused_index < 0:
		buttons[0].grab_focus()
		return
	var next_index := (focused_index + offset + buttons.size()) % buttons.size()
	buttons[next_index].grab_focus()

func _get_menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	if continue_button:
		buttons.append(continue_button)
	if retry_button:
		buttons.append(retry_button)
	if option_button:
		buttons.append(option_button)
	if quit_button:
		buttons.append(quit_button)
	return buttons

func _get_option_controls() -> Array[Button]:
	var controls: Array[Button] = []
	for control in _options_controls:
		if control:
			if not control.visible:
				continue
			var parent := control.get_parent() as CanvasItem
			if parent and not parent.visible:
				continue
			controls.append(control)
	return controls

func _configure_volume_controls() -> void:
	var master_control := get_node_or_null("OptionsMenu/AudioMenu/MasterVolumeControl/MasterInput") as Button
	var music_control := get_node_or_null("OptionsMenu/AudioMenu/MusicVolume/MusicInput") as Button
	var sfx_control := get_node_or_null("OptionsMenu/AudioMenu/SFXVolume/SFXInput") as Button
	var mute_control := get_node_or_null("OptionsMenu/AudioMenu/Mute/MuteInput") as Button
	_volume_controls = [master_control, music_control, sfx_control, mute_control]
	_options_controls = [master_control, music_control, sfx_control, mute_control]
	_configure_volume_control(master_control, SettingsManager.master_volume * 100.0, _on_master_volume_changed, &"Master")
	_configure_volume_control(music_control, SettingsManager.music_volume * 100.0, _on_music_volume_changed, &"Music")
	_configure_volume_control(sfx_control, SettingsManager.sfx_volume * 100.0, _on_sfx_volume_changed, &"SFX")
	_configure_mute_control(mute_control)

func _configure_display_controls() -> void:
	_display_mode_control = get_node_or_null("OptionsMenu/VideoPanel/DisplayTypeOptions/DisplayModeOption/DisplayModeInput") as Button
	_display_mode_value_label = get_node_or_null("OptionsMenu/VideoPanel/DisplayTypeOptions/DisplayModeOption/DisplayModeValue") as RichTextLabel
	_display_type_label = get_node_or_null("OptionsMenu/VideoPanel/DisplayTypeOptions/DisplayTypeLabel") as Label
	_configure_display_mode_control(_display_mode_control)
	if _display_mode_control:
		_options_controls.append(_display_mode_control)

	_resolution_control = get_node_or_null("OptionsMenu/VideoPanel/ResolutionOptions/ResolutionOption/ResolutionInput") as Button
	_resolution_value_label = get_node_or_null("OptionsMenu/VideoPanel/ResolutionOptions/ResolutionOption/ResolutionValue") as RichTextLabel
	_resolution_label = get_node_or_null("OptionsMenu/VideoPanel/ResolutionOptions/ResolutionLabel") as Label
	_display_resolutions = _build_best_resolution_options()
	_configure_resolution_control(_resolution_control)
	if _resolution_control:
		_options_controls.append(_resolution_control)
	_refresh_display_option_visuals()

func _configure_performance_controls() -> void:
	_preset_control = get_node_or_null("OptionsMenu/PerformancePanel/Preset/PresetOption/PresetButton") as Button
	_preset_value_label = get_node_or_null("OptionsMenu/PerformancePanel/Preset/PresetOption/PresetValue") as RichTextLabel
	_preset_label = get_node_or_null("OptionsMenu/PerformancePanel/Preset/PresetLabel") as Label
	_configure_performance_preset_control(_preset_control)
	if _preset_control:
		_options_controls.append(_preset_control)

	_fps_control = get_node_or_null("OptionsMenu/PerformancePanel/FPS/FPSDisplay/FPSCheckBox") as Button
	_fps_value_label = get_node_or_null("OptionsMenu/PerformancePanel/FPS/FPSDisplay/FPSLabel") as RichTextLabel
	_fps_label = get_node_or_null("OptionsMenu/PerformancePanel/FPS/FPSLabel") as Label
	_configure_fps_control(_fps_control)
	if _fps_control:
		_options_controls.append(_fps_control)
	_refresh_performance_option_visuals()

func _configure_controls_panel() -> void:
	_controls_panel = get_node_or_null("OptionsMenu/ControlsPanel") as Panel
	_controls_key_list_label = get_node_or_null("OptionsMenu/ControlsPanel/KeyListLabel") as Label
	_controls_list_label = get_node_or_null("OptionsMenu/ControlsPanel/ControlsListLabel") as Label
	_controls_key_header_label = get_node_or_null("OptionsMenu/ControlsPanel/KeyLabel") as RichTextLabel
	_controls_header_label = get_node_or_null("OptionsMenu/ControlsPanel/ControlsLabel") as RichTextLabel
	if _controls_panel == null or _controls_key_list_label == null or _controls_list_label == null:
		return
	_controls_key_list_label.visible = false
	_controls_list_label.visible = false
	if _controls_key_header_label:
		_controls_key_header_label.add_theme_font_override("normal_font", INPUT_FONT)
	if _controls_header_label:
		_controls_header_label.add_theme_font_override("normal_font", INPUT_FONT)
	var row_top: float = minf(_controls_key_list_label.position.y, _controls_list_label.position.y)
	var key_left: float = _controls_key_list_label.position.x
	var key_width: float = _controls_list_label.position.x - _controls_key_list_label.position.x - 4.0
	var action_left: float = _controls_list_label.position.x
	var action_width: float = maxf(1.0, _controls_panel.size.x - action_left - 4.0)
	var row_height := 15.0
	for index in range(8):
		var button := Button.new()
		button.name = "ControlsRow%d" % [index + 1]
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.position = Vector2(0.0, row_top + (float(index) * row_height))
		button.size = Vector2(_controls_panel.size.x, row_height)
		button.custom_minimum_size = button.size
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.gui_input.connect(_on_control_row_gui_input.bind(button))
		button.focus_entered.connect(_refresh_controls_visuals)
		button.focus_exited.connect(_refresh_controls_visuals)
		_controls_panel.add_child(button)
		_controls_row_buttons.append(button)
		_options_controls.append(button)

		var key_label := _create_controls_row_label("ControlsKeyRow%d" % [index + 1], Vector2(key_left, button.position.y), Vector2(key_width, row_height), HORIZONTAL_ALIGNMENT_CENTER)
		var action_label := _create_controls_row_label("ControlsActionRow%d" % [index + 1], Vector2(action_left, button.position.y), Vector2(action_width, row_height), HORIZONTAL_ALIGNMENT_LEFT)
		_controls_panel.add_child(key_label)
		_controls_panel.add_child(action_label)
		_controls_key_row_labels.append(key_label)
		_controls_action_row_labels.append(action_label)
	_refresh_controls_rows()

func _create_controls_row_label(label_name: String, label_position: Vector2, label_size: Vector2, alignment: HorizontalAlignment) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = label_name
	label.position = label_position
	label.size = label_size
	label.fit_content = false
	label.scroll_active = false
	label.bbcode_enabled = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", INPUT_FONT)
	label.add_theme_font_override("bold_font", _get_input_focus_font())
	label.add_theme_color_override("default_color", INPUT_FONT_COLOR)
	label.horizontal_alignment = alignment
	return label

func _refresh_controls_rows() -> void:
	var rows := _get_controls_rows()
	for index in range(_controls_row_buttons.size()):
		var button := _controls_row_buttons[index]
		var key_label := _controls_key_row_labels[index]
		var action_label := _controls_action_row_labels[index]
		if index >= rows.size():
			button.visible = false
			key_label.visible = false
			action_label.visible = false
			continue
		var row := rows[index]
		button.visible = true
		key_label.visible = true
		action_label.visible = true
		button.set_meta("option_type", String(row.get("type", OPTION_TYPE_CONTROLS_READONLY)))
		button.set_meta("control_action", row.get("action", &""))
		button.set_meta("control_label", String(row.get("label", "")))
		var focused: bool = button.has_focus()
		var listening: bool = button == _listening_controls_control
		var editing_device: bool = button == _editing_controls_device_control
		var active: bool = focused or listening or editing_device
		var alpha := 1.0
		if listening or editing_device:
			var pulse_amount: float = (sin(_edit_flash_time * EDIT_FLASH_SPEED) + 1.0) * 0.5
			alpha = lerpf(EDIT_FLASH_MIN_ALPHA, 1.0, pulse_amount)
		key_label.modulate.a = alpha
		action_label.modulate.a = alpha
		key_label.text = _format_controls_cell_text(String(row.get("key", "")), active)
		action_label.text = _format_controls_cell_text(String(row.get("label", "")), active)
		if String(row.get("type", "")) == OPTION_TYPE_CONTROLS_DEVICE:
			key_label.text = _format_controls_device_cell_text(active)
			action_label.text = _format_controls_cell_text("Input Type", active)
	_configure_option_focus_neighbors()

func _get_controls_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _controls_submode == CONTROL_SUBMODE_MOVE:
		if _controls_device_family == CONTROL_DEVICE_KEYBOARD:
			rows.append(_make_controls_binding_row(&"move_up", "Move Up"))
			rows.append(_make_controls_binding_row(&"move_down", "Move Down"))
			rows.append(_make_controls_binding_row(&"move_left", "Move Left"))
			rows.append(_make_controls_binding_row(&"move_right", "Move Right"))
		else:
			rows.append({"type": OPTION_TYPE_CONTROLS_READONLY, "action": &"", "key": "L Stick", "label": "Move"})
			rows.append(_make_controls_binding_row(&"move_up", "D-Pad Up"))
			rows.append(_make_controls_binding_row(&"move_down", "D-Pad Down"))
			rows.append(_make_controls_binding_row(&"move_left", "D-Pad Left"))
			rows.append(_make_controls_binding_row(&"move_right", "D-Pad Right"))
		rows.append({"type": OPTION_TYPE_CONTROLS_BACK, "action": &"", "key": "Back", "label": "Return"})
		return rows
	rows.append({"type": OPTION_TYPE_CONTROLS_MOVE_GROUP, "action": &"", "key": _format_move_summary(), "label": "Move"})
	rows.append(_make_controls_binding_row(&"interact", "Use \\ Interact"))
	rows.append(_make_controls_binding_row(&"special_action", "Special Action"))
	rows.append(_make_controls_binding_row(&"open_journal", "Open Journal"))
	rows.append(_make_controls_binding_row(&"switch_character", "Switch Character"))
	rows.append(_make_controls_binding_row(&"cancel", "Pause \\ Back"))
	rows.append({"type": OPTION_TYPE_CONTROLS_RESET, "action": &"", "key": "Reset", "label": "Restore Defaults"})
	rows.append({"type": OPTION_TYPE_CONTROLS_DEVICE, "action": &"", "key": "", "label": "Input Type"})
	return rows

func _make_controls_binding_row(action_name: StringName, label_text: String) -> Dictionary:
	return {
		"type": OPTION_TYPE_CONTROL_BINDING,
		"action": action_name,
		"key": _format_control_binding(action_name),
		"label": label_text,
	}

func _format_controls_cell_text(value: String, active: bool) -> String:
	var safe_value := value.replace("[", "\\[").replace("]", "\\]")
	if active:
		safe_value = "[b]%s[/b]" % safe_value
	return "[left][color=#000000]%s[/color][/left]" % safe_value

func _format_controls_device_cell_text(active: bool) -> String:
	var staged_family := _controls_device_family
	if _editing_controls_device_control != null:
		staged_family = _editing_controls_device_family
	var keyboard_text := "KBD\\MS"
	var gamepad_text := "PAD"
	if staged_family == CONTROL_DEVICE_KEYBOARD:
		keyboard_text = "[b]%s[/b]" % keyboard_text
	else:
		gamepad_text = "[b]%s[/b]" % gamepad_text
	var formatted := "%s \\ %s" % [keyboard_text, gamepad_text]
	if active:
		return "[left][color=#000000]%s[/color][/left]" % formatted
	return "[left][color=#000000]%s[/color][/left]" % formatted

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

func _format_control_binding(action_name: StringName) -> String:
	var event := _get_control_binding_event(action_name)
	if event == null:
		return "Unset"
	return _format_input_event(event)

func _get_control_binding_event(action_name: StringName) -> InputEvent:
	if _controls_device_family == CONTROL_DEVICE_KEYBOARD:
		return SettingsManager.get_keyboard_binding_event(action_name)
	if _is_move_action(action_name):
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton:
				return event
	return SettingsManager.get_gamepad_binding_event(action_name)

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

func _is_move_action(action_name: StringName) -> bool:
	return action_name == &"move_up" or action_name == &"move_down" or action_name == &"move_left" or action_name == &"move_right"


func _configure_display_mode_control(control: Button) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.custom_minimum_size = design_size
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("option_type", OPTION_TYPE_DISPLAY_MODE)
	control.gui_input.connect(_on_display_mode_control_gui_input.bind(control))
	control.focus_entered.connect(_refresh_display_option_visuals)
	control.focus_exited.connect(_refresh_display_option_visuals)
	_configure_display_mode_value_label()
	control.size = design_size

func _configure_resolution_control(control: Button) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.custom_minimum_size = design_size
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("option_type", OPTION_TYPE_RESOLUTION)
	control.gui_input.connect(_on_resolution_control_gui_input.bind(control))
	control.focus_entered.connect(_refresh_display_option_visuals)
	control.focus_exited.connect(_refresh_display_option_visuals)
	_configure_resolution_value_label()
	control.size = design_size

func _configure_performance_preset_control(control: Button) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.custom_minimum_size = design_size
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("option_type", OPTION_TYPE_PERFORMANCE_PRESET)
	control.gui_input.connect(_on_performance_preset_gui_input.bind(control))
	control.focus_entered.connect(_refresh_performance_option_visuals)
	control.focus_exited.connect(_refresh_performance_option_visuals)
	_configure_performance_value_label(_preset_value_label)
	control.size = design_size

func _configure_fps_control(control: Button) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.custom_minimum_size = design_size
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("option_type", OPTION_TYPE_FPS)
	control.gui_input.connect(_on_fps_control_gui_input.bind(control))
	control.focus_entered.connect(_refresh_performance_option_visuals)
	control.focus_exited.connect(_refresh_performance_option_visuals)
	_configure_performance_value_label(_fps_value_label)
	control.size = design_size

func _configure_return_button() -> void:
	if _return_button == null:
		return
	_return_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_return_button.focus_mode = Control.FOCUS_ALL
	_return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_return_button.flat = true
	_return_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_return_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_return_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_return_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _return_label:
		_return_text = _return_label.text
	else:
		_return_text = _return_button.text
	_return_button.pressed.connect(_on_return_pressed)
	_return_button.focus_entered.connect(_refresh_focus)
	_return_button.focus_exited.connect(_refresh_focus)
	_options_controls.append(_return_button)
	_refresh_return_button_visual()

func _configure_radio_control(control: Button, option_type: String, option_value: Variant) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	control.custom_minimum_size = design_size
	control.add_theme_font_override("font", INPUT_FONT)
	control.add_theme_color_override("font_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_hover_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_pressed_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_focus_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_disabled_color", INPUT_FONT_COLOR)
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("option_type", option_type)
	control.set_meta("option_value", option_value)
	control.set_meta("option_label", _find_option_label_for_control(control))
	control.pressed.connect(_on_radio_control_pressed.bind(control))
	control.focus_entered.connect(_refresh_display_option_visuals)
	control.focus_exited.connect(_refresh_display_option_visuals)
	control.size = design_size

func _configure_volume_control(control: Button, value: float, changed_callback: Callable, audio_bus: StringName) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	control.custom_minimum_size = design_size
	control.add_theme_font_override("font", INPUT_FONT)
	control.add_theme_color_override("font_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_hover_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_pressed_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_focus_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_disabled_color", INPUT_FONT_COLOR)
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("volume_changed_callback", changed_callback)
	control.set_meta("audio_bus", audio_bus)
	control.set_meta("option_type", OPTION_TYPE_VOLUME)
	control.set_meta("option_label", _find_option_label_for_control(control))
	control.focus_entered.connect(_refresh_volume_control_visuals)
	control.focus_exited.connect(_refresh_volume_control_visuals)
	control.gui_input.connect(_on_volume_control_gui_input.bind(control))
	_set_volume_control_value(control, value)
	_refresh_volume_control_visuals()
	control.size = design_size

func _configure_mute_control(control: Button) -> void:
	if control == null:
		return
	var design_size: Vector2 = control.size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.flat = true
	control.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	control.custom_minimum_size = design_size
	control.add_theme_font_override("font", INPUT_FONT)
	control.add_theme_color_override("font_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_hover_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_pressed_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_focus_color", INPUT_FONT_COLOR)
	control.add_theme_color_override("font_disabled_color", INPUT_FONT_COLOR)
	control.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.set_meta("option_type", OPTION_TYPE_MUTE)
	control.set_meta("volume_changed_callback", _on_mute_changed)
	control.set_meta("option_label", _find_option_label_for_control(control))
	control.focus_entered.connect(_refresh_volume_control_visuals)
	control.focus_exited.connect(_refresh_volume_control_visuals)
	control.gui_input.connect(_on_volume_control_gui_input.bind(control))
	_set_mute_control_value(control, SettingsManager.muted)
	_refresh_volume_control_visuals()
	control.size = design_size

func _on_volume_control_gui_input(event: InputEvent, control: Button) -> void:
	var button_event := event as InputEventMouseButton
	if button_event and button_event.button_index == MOUSE_BUTTON_LEFT:
		if button_event.pressed:
			_dragging_volume_control = control
			_drag_start_y = button_event.global_position.y
			_drag_start_value = _get_option_control_numeric_value(control)
			if _get_option_type(control) == OPTION_TYPE_VOLUME:
				_play_ui_enter()
			control.grab_focus()
		elif _dragging_volume_control == control:
			if _get_option_type(control) == OPTION_TYPE_MUTE:
				_toggle_mute_control(control)
			else:
				_commit_volume_control(control)
			_dragging_volume_control = null
		_mark_input_handled()
		return

	var motion_event := event as InputEventMouseMotion
	if motion_event and _dragging_volume_control == control and _get_option_type(control) == OPTION_TYPE_VOLUME:
		var delta_steps: float = roundf((_drag_start_y - motion_event.global_position.y) / VOLUME_DRAG_PIXELS_PER_STEP)
		var previous_value: float = _get_volume_control_value(control)
		_set_volume_control_value(control, _drag_start_value + delta_steps)
		if not is_equal_approx(previous_value, _get_volume_control_value(control)):
			_play_ui_change()
		_mark_input_handled()

func _on_radio_control_pressed(control: Button) -> void:
	match _get_option_type(control):
		OPTION_TYPE_RESOLUTION:
			_select_resolution_value(_get_resolution_control_value(control))
	_mark_input_handled()

func _select_display_mode_value(fullscreen: bool, play_change_audio: bool = true) -> void:
	var changed: bool = SettingsManager.fullscreen != fullscreen
	SettingsManager.set_fullscreen(fullscreen)
	if changed and play_change_audio:
		_play_ui_change()
	_refresh_display_option_visuals()

func _on_display_mode_control_gui_input(event: InputEvent, control: Button) -> void:
	var button_event := event as InputEventMouseButton
	if button_event == null or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if button_event.pressed:
		control.grab_focus()
		_mark_input_handled()
		return
	var choose_fullscreen := _is_display_mode_pointer_on_fullscreen(button_event.position)
	control.grab_focus()
	_editing_display_mode_control = null
	_set_display_mode_focus_locked(false)
	_select_display_mode_value(choose_fullscreen)
	_mark_input_handled()

func _begin_display_mode_edit(control: Button) -> void:
	_play_ui_enter()
	_editing_display_mode_control = control
	_editing_display_mode_original_fullscreen = SettingsManager.fullscreen
	_editing_display_mode_fullscreen = SettingsManager.fullscreen
	_edit_flash_time = 0.0
	_set_display_mode_focus_locked(true)
	_refresh_display_option_visuals()

func _commit_display_mode_edit() -> void:
	if _editing_display_mode_control == null:
		return
	_select_display_mode_value(_editing_display_mode_fullscreen, false)
	_editing_display_mode_control = null
	_set_display_mode_focus_locked(false)
	_refresh_display_option_visuals()

func _cancel_display_mode_edit() -> void:
	_editing_display_mode_fullscreen = _editing_display_mode_original_fullscreen
	_editing_display_mode_control = null
	_set_display_mode_focus_locked(false)
	_refresh_display_option_visuals()

func _stage_display_mode_value(fullscreen: bool) -> void:
	if _editing_display_mode_control == null:
		return
	if _editing_display_mode_fullscreen == fullscreen:
		return
	_editing_display_mode_fullscreen = fullscreen
	_play_ui_change()
	_refresh_display_option_visuals()

func _is_display_mode_pointer_on_fullscreen(local_position: Vector2) -> bool:
	if _display_mode_value_label == null:
		return local_position.x <= 0.0
	var label_rect := _display_mode_value_label.get_rect()
	var label_local_x: float = local_position.x - label_rect.position.x
	return label_local_x <= label_rect.size.x * 0.5

func _configure_display_mode_value_label() -> void:
	if _display_mode_value_label == null:
		return
	_display_mode_value_label.add_theme_font_override("normal_font", INPUT_FONT)
	_display_mode_value_label.add_theme_font_override("bold_font", _get_input_focus_font())
	_display_mode_value_label.add_theme_color_override("default_color", INPUT_FONT_COLOR)

func _configure_resolution_value_label() -> void:
	if _resolution_value_label == null:
		return
	_resolution_value_label.add_theme_font_override("normal_font", INPUT_FONT)
	_resolution_value_label.add_theme_font_override("bold_font", _get_input_focus_font())
	_resolution_value_label.add_theme_color_override("default_color", INPUT_FONT_COLOR)

func _configure_performance_value_label(value_label: RichTextLabel) -> void:
	if value_label == null:
		return
	value_label.add_theme_font_override("normal_font", INPUT_FONT)
	value_label.add_theme_font_override("bold_font", _get_input_focus_font())
	value_label.add_theme_color_override("default_color", INPUT_FONT_COLOR)

func _on_performance_preset_gui_input(event: InputEvent, control: Button) -> void:
	var button_event := event as InputEventMouseButton
	if button_event == null or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if button_event.pressed:
		control.grab_focus()
		_mark_input_handled()
		return
	var local_x: float = button_event.position.x
	var segment_width: float = maxf(control.size.x / 3.0, 1.0)
	var selected_preset: int = clampi(int(floor(local_x / segment_width)), SettingsManager.PerformancePreset.PERFORMANCE, SettingsManager.PerformancePreset.QUALITY)
	_editing_preset_control = null
	_set_performance_preset_focus_locked(false)
	_select_performance_preset(selected_preset)
	_mark_input_handled()

func _on_fps_control_gui_input(event: InputEvent, control: Button) -> void:
	var button_event := event as InputEventMouseButton
	if button_event == null or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if button_event.pressed:
		control.grab_focus()
	else:
		_toggle_fps_control()
	_mark_input_handled()

func _begin_performance_preset_edit(control: Button) -> void:
	_play_ui_enter()
	_editing_preset_control = control
	_editing_preset_original = SettingsManager.performance_preset
	_editing_preset_value = SettingsManager.performance_preset
	_edit_flash_time = 0.0
	_set_performance_preset_focus_locked(true)
	_refresh_performance_option_visuals()

func _commit_performance_preset_edit() -> void:
	if _editing_preset_control == null:
		return
	_select_performance_preset(_editing_preset_value, false)
	_editing_preset_control = null
	_set_performance_preset_focus_locked(false)
	_refresh_performance_option_visuals()

func _cancel_performance_preset_edit() -> void:
	_editing_preset_value = _editing_preset_original
	_editing_preset_control = null
	_set_performance_preset_focus_locked(false)
	_refresh_performance_option_visuals()

func _stage_performance_preset_by_offset(offset: int) -> void:
	if _editing_preset_control == null:
		return
	var preset_count: int = SettingsManager.PerformancePreset.QUALITY + 1
	_editing_preset_value = (_editing_preset_value + offset + preset_count) % preset_count
	_play_ui_change()
	_refresh_performance_option_visuals()

func _select_performance_preset(preset: int, play_change_audio: bool = true) -> void:
	var changed: bool = SettingsManager.performance_preset != preset
	SettingsManager.set_performance_preset(preset)
	if changed and play_change_audio:
		_play_ui_change()
	_refresh_performance_option_visuals()

func _toggle_fps_control() -> void:
	if SettingsManager.has_method(&"set_show_fps"):
		SettingsManager.call(&"set_show_fps", not _is_fps_setting_enabled())
		_play_ui_change()
	_refresh_performance_option_visuals()

func _select_resolution_value(resolution: Vector2i, play_change_audio: bool = true) -> void:
	if not _resolution_is_windowed_editable():
		_refresh_display_option_visuals()
		return
	if resolution == Vector2i.ZERO:
		return
	var changed: bool = SettingsManager.resolution != resolution
	SettingsManager.set_resolution(resolution)
	if changed and play_change_audio:
		_play_ui_change()
	_refresh_display_option_visuals()

func _on_resolution_control_gui_input(event: InputEvent, control: Button) -> void:
	var button_event := event as InputEventMouseButton
	if button_event == null or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if button_event.pressed:
		control.grab_focus()
		_mark_input_handled()
		return
	if not _resolution_is_windowed_editable():
		control.grab_focus()
		_mark_input_handled()
		return
	control.grab_focus()
	_editing_resolution_control = null
	_set_resolution_focus_locked(false)
	_select_resolution_value(_get_next_resolution_value(SettingsManager.resolution, 1))
	_mark_input_handled()

func _begin_resolution_edit(control: Button) -> void:
	if not _resolution_is_windowed_editable():
		_refresh_display_option_visuals()
		return
	_play_ui_enter()
	_editing_resolution_control = control
	_editing_resolution_original = SettingsManager.resolution
	_editing_resolution_value = _resolve_available_resolution(SettingsManager.resolution)
	_edit_flash_time = 0.0
	_set_resolution_focus_locked(true)
	_refresh_display_option_visuals()

func _commit_resolution_edit() -> void:
	if _editing_resolution_control == null:
		return
	_select_resolution_value(_editing_resolution_value, false)
	_editing_resolution_control = null
	_set_resolution_focus_locked(false)
	_refresh_display_option_visuals()

func _cancel_resolution_edit() -> void:
	_editing_resolution_value = _editing_resolution_original
	_editing_resolution_control = null
	_set_resolution_focus_locked(false)
	_refresh_display_option_visuals()

func _stage_resolution_by_offset(offset: int) -> void:
	if _editing_resolution_control == null:
		return
	if not _resolution_is_windowed_editable():
		_cancel_resolution_edit()
		return
	_editing_resolution_value = _get_next_resolution_value(_editing_resolution_value, offset)
	_play_ui_change()
	_refresh_display_option_visuals()

func _on_control_row_gui_input(event: InputEvent, control: Button) -> void:
	var button_event := event as InputEventMouseButton
	if button_event == null or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if button_event.pressed:
		control.grab_focus()
		_mark_input_handled()
		return
	_activate_control_row(control, true)
	_mark_input_handled()

func _activate_control_row(control: Button, mouse_direct: bool = false) -> void:
	var option_type := _get_option_type(control)
	match option_type:
		OPTION_TYPE_CONTROLS_MOVE_GROUP:
			_play_ui_enter()
			_set_controls_submode(CONTROL_SUBMODE_MOVE)
		OPTION_TYPE_CONTROL_BINDING:
			_begin_control_binding_listen(control)
		OPTION_TYPE_CONTROLS_DEVICE:
			if mouse_direct:
				_toggle_controls_device_family()
			else:
				_begin_controls_device_edit(control)
		OPTION_TYPE_CONTROLS_RESET:
			SettingsManager.reset_control_bindings()
			_play_ui_change()
			_refresh_controls_rows()
			_refresh_controls_visuals()
		OPTION_TYPE_CONTROLS_BACK:
			_play_ui_enter()
			_set_controls_submode(CONTROL_SUBMODE_TOP)
		_:
			_refresh_controls_visuals()

func _set_controls_submode(value: String) -> void:
	_controls_submode = value
	_cancel_control_binding_listen()
	_cancel_controls_device_edit()
	_refresh_controls_rows()
	if not _controls_row_buttons.is_empty():
		_controls_row_buttons[0].grab_focus()
	_refresh_controls_visuals()

func _begin_controls_device_edit(control: Button) -> void:
	_play_ui_enter()
	_editing_controls_device_control = control
	_editing_controls_device_original_family = _controls_device_family
	_editing_controls_device_family = _controls_device_family
	_edit_flash_time = 0.0
	_refresh_controls_visuals()

func _stage_controls_device_family(value: String) -> void:
	if _editing_controls_device_control == null:
		return
	if _editing_controls_device_family == value:
		return
	_editing_controls_device_family = value
	_play_ui_change()
	_refresh_controls_visuals()

func _commit_controls_device_edit() -> void:
	if _editing_controls_device_control == null:
		return
	_controls_device_family = _editing_controls_device_family
	_editing_controls_device_control = null
	_set_controls_submode(CONTROL_SUBMODE_TOP)

func _cancel_controls_device_edit() -> void:
	_editing_controls_device_family = _editing_controls_device_original_family
	_editing_controls_device_control = null
	_refresh_controls_visuals()

func _toggle_controls_device_family() -> void:
	_controls_device_family = CONTROL_DEVICE_GAMEPAD if _controls_device_family == CONTROL_DEVICE_KEYBOARD else CONTROL_DEVICE_KEYBOARD
	_play_ui_change()
	_set_controls_submode(CONTROL_SUBMODE_TOP)

func _begin_control_binding_listen(control: Button) -> void:
	var action_name := control.get_meta("control_action", &"") as StringName
	if action_name == &"":
		return
	if _controls_device_family == CONTROL_DEVICE_GAMEPAD and _is_move_action(action_name) and _controls_submode != CONTROL_SUBMODE_MOVE:
		return
	_play_ui_enter()
	_listening_controls_control = control
	_listening_controls_action = action_name
	_edit_flash_time = 0.0
	_refresh_controls_visuals()

func _cancel_control_binding_listen() -> void:
	_listening_controls_control = null
	_listening_controls_action = &""
	_refresh_controls_visuals()

func _commit_control_binding_event(event: InputEvent) -> void:
	if _listening_controls_action == &"":
		return
	if _controls_device_family == CONTROL_DEVICE_KEYBOARD:
		SettingsManager.set_keyboard_binding(_listening_controls_action, event)
	else:
		SettingsManager.set_gamepad_binding(_listening_controls_action, event)
	_play_ui_change()
	_listening_controls_control = null
	_listening_controls_action = &""
	_refresh_controls_rows()
	_refresh_controls_visuals()

func _event_to_control_binding_event(event: InputEvent) -> InputEvent:
	if _listening_controls_action == &"":
		return null
	if _controls_device_family == CONTROL_DEVICE_KEYBOARD:
		var key_event := event as InputEventKey
		if key_event and key_event.pressed and not key_event.echo:
			var stored_key_event := InputEventKey.new()
			stored_key_event.pressed = true
			stored_key_event.keycode = key_event.keycode
			stored_key_event.physical_keycode = key_event.physical_keycode
			return stored_key_event
		var mouse_event := event as InputEventMouseButton
		if mouse_event and mouse_event.pressed:
			if _is_move_action(_listening_controls_action):
				return null
			var stored_mouse_event := InputEventMouseButton.new()
			stored_mouse_event.pressed = true
			stored_mouse_event.button_index = mouse_event.button_index
			return stored_mouse_event
		return null
	var joypad_button_event := event as InputEventJoypadButton
	if joypad_button_event and joypad_button_event.pressed:
		var stored_joypad_button_event := InputEventJoypadButton.new()
		stored_joypad_button_event.pressed = true
		stored_joypad_button_event.button_index = joypad_button_event.button_index
		return stored_joypad_button_event
	return null

func _get_next_resolution_value(current_resolution: Vector2i, offset: int) -> Vector2i:
	if _display_resolutions.is_empty():
		return SettingsManager.DEFAULT_RESOLUTION
	var current_index := _display_resolutions.find(current_resolution)
	if current_index < 0:
		current_index = _display_resolutions.find(_resolve_available_resolution(current_resolution))
	if current_index < 0:
		current_index = 0
	var next_index := (current_index - offset + _display_resolutions.size()) % _display_resolutions.size()
	return _display_resolutions[next_index]

func _resolve_available_resolution(resolution: Vector2i) -> Vector2i:
	if _display_resolutions.has(resolution):
		return resolution
	if _display_resolutions.is_empty():
		return SettingsManager.DEFAULT_RESOLUTION
	return _display_resolutions[0]

func _adjust_editing_option(direction: float) -> void:
	if _editing_volume_control == null:
		return
	if _get_option_type(_editing_volume_control) == OPTION_TYPE_MUTE:
		_set_mute_control_value(_editing_volume_control, direction > 0.0)
		return
	_adjust_volume_control(_editing_volume_control, direction)

func _adjust_volume_control(control: Button, direction: float) -> void:
	var previous_value: float = _get_volume_control_value(control)
	_set_volume_control_value(control, previous_value + direction)
	if not is_equal_approx(previous_value, _get_volume_control_value(control)):
		_play_ui_change()

func _begin_held_edit_direction(direction: float) -> void:
	_held_edit_direction = direction
	_held_edit_repeat_timer = EDIT_REPEAT_INITIAL_DELAY

func _clear_held_edit_direction() -> void:
	_held_edit_direction = 0.0
	_held_edit_repeat_timer = 0.0

func _set_volume_control_value(control: Button, value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	control.set_meta("volume_value", clamped_value)
	control.text = "%d%%" % int(roundf(clamped_value))
	_preview_volume_control_value(control)
	_refresh_volume_control_visuals()

func _preview_volume_control_value(control: Button) -> void:
	if control == null:
		return
	if _get_option_type(control) != OPTION_TYPE_VOLUME:
		return
	if not control.has_meta("audio_bus"):
		return
	var audio_bus: StringName = control.get_meta("audio_bus", &"") as StringName
	if audio_bus == &"":
		return
	SettingsManager.preview_audio_bus_volume(audio_bus, _get_volume_control_value(control) / 100.0)

func _set_mute_control_value(control: Button, value: bool) -> void:
	control.set_meta("mute_value", value)
	_refresh_volume_control_visuals()

func _toggle_mute_control(control: Button) -> void:
	_set_mute_control_value(control, not _get_mute_control_value(control))
	_play_ui_change()
	_commit_volume_control(control)

func _get_volume_control_value(control: Button) -> float:
	return float(control.get_meta("volume_value", 0.0))

func _get_mute_control_value(control: Button) -> bool:
	return bool(control.get_meta("mute_value", false))

func _get_option_control_numeric_value(control: Button) -> float:
	if _get_option_type(control) == OPTION_TYPE_MUTE:
		return 1.0 if _get_mute_control_value(control) else 0.0
	return _get_volume_control_value(control)

func _restore_option_control_original_value(control: Button) -> void:
	if _get_option_type(control) == OPTION_TYPE_MUTE:
		_set_mute_control_value(control, _editing_volume_original_value >= 0.5)
		return
	_set_volume_control_value(control, _editing_volume_original_value)

func _cancel_active_volume_edit() -> void:
	if _editing_volume_control != null:
		_restore_option_control_original_value(_editing_volume_control)
		_editing_volume_control = null
	if _dragging_volume_control != null:
		if _get_option_type(_dragging_volume_control) == OPTION_TYPE_VOLUME:
			_set_volume_control_value(_dragging_volume_control, _drag_start_value)
		_dragging_volume_control = null
	_clear_held_edit_direction()
	_set_volume_focus_locked(false)
	_refresh_volume_control_visuals()

func _commit_volume_control(control: Button) -> void:
	var callback: Callable = control.get_meta("volume_changed_callback", Callable()) as Callable
	if callback.is_valid():
		if _get_option_type(control) == OPTION_TYPE_MUTE:
			callback.call(_get_mute_control_value(control))
		else:
			callback.call(_get_volume_control_value(control))

func _on_master_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value / 100.0)

func _on_music_volume_changed(value: float) -> void:
	SettingsManager.set_music_volume(value / 100.0)

func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value / 100.0)

func _on_mute_changed(value: bool) -> void:
	SettingsManager.set_muted(value)

func _get_focused_display_control() -> Button:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == null:
		return null
	if focused_control == _display_mode_control:
		return _display_mode_control
	return null

func _get_focused_resolution_control() -> Button:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == null:
		return null
	if not _resolution_is_windowed_editable():
		return null
	if focused_control == _resolution_control:
		return _resolution_control
	return null

func _resolution_is_windowed_editable() -> bool:
	return not SettingsManager.fullscreen

func _get_focused_performance_control() -> Button:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == _preset_control:
		return _preset_control
	if focused_control == _fps_control:
		return _fps_control
	return null

func _get_focused_controls_control() -> Button:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == null:
		return null
	for control in _controls_row_buttons:
		if control == null or not control.visible:
			continue
		if focused_control == control:
			return control
	return null

func _get_focused_volume_control() -> Button:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == null:
		return null
	for control in _volume_controls:
		if control == null:
			continue
		if focused_control == control:
			return control
	return null

func _focus_options_vertical(offset: int) -> void:
	var focused_control: Button = get_viewport().gui_get_focus_owner() as Button
	var controls_section: Array[Button] = _get_visible_controls_section()
	var right_section: Array[Button] = _get_right_options_section()
	var section: Array[Button] = controls_section if controls_section.has(focused_control) else right_section
	if section.has(focused_control):
		var focused_index: int = section.find(focused_control)
		var next_index: int = focused_index + offset
		if next_index >= 0 and next_index < section.size():
			section[next_index].grab_focus()
			return
		if _return_button:
			_return_button.grab_focus()
			return
	if focused_control == _return_button:
		if offset < 0 and not right_section.is_empty():
			right_section.back().grab_focus()
		elif offset > 0 and not controls_section.is_empty():
			controls_section.front().grab_focus()
		return
	_focus_first_volume_control()

func _focus_opposite_options_section() -> void:
	var focused_control: Button = get_viewport().gui_get_focus_owner() as Button
	var controls_section: Array[Button] = _get_visible_controls_section()
	var right_section: Array[Button] = _get_right_options_section()
	var target_section: Array[Button] = []
	if controls_section.has(focused_control):
		target_section = right_section
	elif right_section.has(focused_control):
		target_section = controls_section
	else:
		return
	var target: Button = _find_closest_vertical_control(focused_control, target_section)
	if target:
		target.grab_focus()

func _get_visible_controls_section() -> Array[Button]:
	var controls: Array[Button] = []
	for control in _controls_row_buttons:
		if control != null and control.visible:
			controls.append(control)
	return controls

func _get_right_options_section() -> Array[Button]:
	var controls: Array[Button] = []
	for control in _volume_controls:
		if control != null and control.visible:
			controls.append(control)
	if _display_mode_control != null and _display_mode_control.visible:
		controls.append(_display_mode_control)
	if _resolution_control != null and _resolution_control.visible:
		controls.append(_resolution_control)
	if _preset_control != null and _preset_control.visible:
		controls.append(_preset_control)
	if _fps_control != null and _fps_control.visible:
		controls.append(_fps_control)
	return controls

func _find_closest_vertical_control(source: Control, candidates: Array[Button]) -> Button:
	if source == null or candidates.is_empty():
		return null
	var source_y: float = source.get_global_rect().get_center().y
	var closest: Button = null
	var closest_distance: float = INF
	for candidate in candidates:
		if candidate == null or not candidate.visible:
			continue
		var distance: float = absf(candidate.get_global_rect().get_center().y - source_y)
		if distance < closest_distance:
			closest = candidate
			closest_distance = distance
	return closest

func _first_visible_control(controls: Array[Button]) -> Button:
	return controls.front() if not controls.is_empty() else null

func _set_focus_neighbor(control: Control, side: Side, neighbor: Control) -> void:
	if control == null:
		return
	var neighbor_path: NodePath = control.get_path_to(neighbor) if neighbor != null else NodePath("")
	match side:
		SIDE_TOP:
			control.focus_neighbor_top = neighbor_path
		SIDE_BOTTOM:
			control.focus_neighbor_bottom = neighbor_path
		SIDE_LEFT:
			control.focus_neighbor_left = neighbor_path
		SIDE_RIGHT:
			control.focus_neighbor_right = neighbor_path

func _focus_first_volume_control() -> void:
	for control in _volume_controls:
		if control:
			control.grab_focus()
			return

func _set_volume_focus_locked(locked: bool) -> void:
	var neighbor_path := NodePath(".") if locked else NodePath("")
	for control in _volume_controls:
		if control == null:
			continue
		control.focus_neighbor_top = neighbor_path
		control.focus_neighbor_bottom = neighbor_path
		control.focus_neighbor_left = neighbor_path
		control.focus_neighbor_right = neighbor_path

func _set_display_mode_focus_locked(locked: bool) -> void:
	if _display_mode_control == null:
		return
	var neighbor_path := NodePath(".") if locked else NodePath("")
	_display_mode_control.focus_neighbor_top = neighbor_path
	_display_mode_control.focus_neighbor_bottom = neighbor_path
	_display_mode_control.focus_neighbor_left = neighbor_path
	_display_mode_control.focus_neighbor_right = neighbor_path

func _set_resolution_focus_locked(locked: bool) -> void:
	if _resolution_control == null:
		return
	var neighbor_path := NodePath(".") if locked else NodePath("")
	_resolution_control.focus_neighbor_top = neighbor_path
	_resolution_control.focus_neighbor_bottom = neighbor_path
	_resolution_control.focus_neighbor_left = neighbor_path
	_resolution_control.focus_neighbor_right = neighbor_path

func _set_performance_preset_focus_locked(locked: bool) -> void:
	if _preset_control == null:
		return
	var neighbor_path := NodePath(".") if locked else NodePath("")
	_preset_control.focus_neighbor_top = neighbor_path
	_preset_control.focus_neighbor_bottom = neighbor_path
	_preset_control.focus_neighbor_left = neighbor_path
	_preset_control.focus_neighbor_right = neighbor_path

func _refresh_volume_control_visuals() -> void:
	for control in _volume_controls:
		if control == null:
			continue
		if _get_option_type(control) == OPTION_TYPE_MUTE:
			_refresh_mute_control_visual(control)
			continue
		var is_active: bool = control.has_focus() or control == _editing_volume_control
		var font: Font = _get_option_font(is_active)
		var font_color := INPUT_FONT_COLOR
		if control == _editing_volume_control:
			var pulse_amount: float = (sin(_edit_flash_time * EDIT_FLASH_SPEED) + 1.0) * 0.5
			font_color.a = lerpf(EDIT_FLASH_MIN_ALPHA, 1.0, pulse_amount)
		control.add_theme_font_override("font", font)
		control.add_theme_color_override("font_color", font_color)
		control.add_theme_color_override("font_hover_color", font_color)
		control.add_theme_color_override("font_pressed_color", font_color)
		control.add_theme_color_override("font_focus_color", font_color)
		control.add_theme_color_override("font_disabled_color", font_color)
		_refresh_option_label_visual(control)

func _refresh_mute_control_visual(control: Button) -> void:
	var is_enabled: bool = _get_mute_control_value(control)
	var is_focused: bool = control.has_focus()
	var font: Font = _get_option_font(is_enabled and is_focused)
	var font_color := INPUT_FONT_COLOR
	control.text = MUTE_CHECKMARK if is_enabled else ""
	control.add_theme_font_override("font", font)
	control.add_theme_color_override("font_color", font_color)
	control.add_theme_color_override("font_hover_color", font_color)
	control.add_theme_color_override("font_pressed_color", font_color)
	control.add_theme_color_override("font_focus_color", font_color)
	control.add_theme_color_override("font_disabled_color", font_color)
	_refresh_option_label_visual(control)

func _refresh_return_button_visual() -> void:
	if _return_label == null:
		return
	var is_focused: bool = _return_button != null and _return_button.has_focus()
	_return_label.text = _return_text
	_prepare_option_label_settings(_return_label)
	if is_focused:
		_return_label.label_settings = _return_label.get_meta("option_focus_label_settings") as LabelSettings
	else:
		_return_label.label_settings = _return_label.get_meta("option_default_label_settings") as LabelSettings

func _refresh_display_option_visuals() -> void:
	_refresh_display_mode_visual()
	_refresh_resolution_visual()

func _refresh_performance_option_visuals() -> void:
	_refresh_performance_preset_visual()
	_refresh_fps_visual()

func _refresh_controls_visuals() -> void:
	if _controls_panel == null:
		return
	_refresh_controls_rows()

func _refresh_display_mode_visual() -> void:
	if _display_mode_value_label == null and _display_type_label == null:
		return
	var shown_fullscreen := SettingsManager.fullscreen
	var is_active: bool = _editing_display_mode_control != null or (_display_mode_control != null and _display_mode_control.has_focus())
	if _editing_display_mode_control != null:
		shown_fullscreen = _editing_display_mode_fullscreen
		var pulse_amount: float = (sin(_edit_flash_time * EDIT_FLASH_SPEED) + 1.0) * 0.5
		if _display_mode_value_label != null:
			_display_mode_value_label.modulate.a = lerpf(EDIT_FLASH_MIN_ALPHA, 1.0, pulse_amount)
	elif _display_mode_value_label != null:
		_display_mode_value_label.modulate.a = 1.0
	if _display_mode_value_label != null:
		_display_mode_value_label.text = _format_display_mode_value(shown_fullscreen)
	if _display_type_label != null:
		_prepare_option_label_settings(_display_type_label)
		if is_active:
			_display_type_label.label_settings = _display_type_label.get_meta("option_focus_label_settings") as LabelSettings
		else:
			_display_type_label.label_settings = _display_type_label.get_meta("option_default_label_settings") as LabelSettings

func _format_display_mode_value(fullscreen: bool) -> String:
	var fullscreen_text := "Fullscreen"
	var windowed_text := "Windowed"
	if fullscreen:
		fullscreen_text = "[b]%s[/b]" % fullscreen_text
	else:
		windowed_text = "[b]%s[/b]" % windowed_text
	return "[left][color=#000000]%s \\ %s[/color][/left]" % [fullscreen_text, windowed_text]

func _refresh_resolution_visual() -> void:
	if _resolution_value_label == null and _resolution_label == null:
		return
	if not _resolution_is_windowed_editable() and _editing_resolution_control != null:
		_editing_resolution_value = _editing_resolution_original
		_editing_resolution_control = null
		_set_resolution_focus_locked(false)
	var shown_resolution := SettingsManager.resolution
	var is_active: bool = _editing_resolution_control != null or (_resolution_control != null and _resolution_control.has_focus())
	if _editing_resolution_control != null:
		shown_resolution = _editing_resolution_value
		var pulse_amount: float = (sin(_edit_flash_time * EDIT_FLASH_SPEED) + 1.0) * 0.5
		if _resolution_value_label != null:
			_resolution_value_label.modulate.a = lerpf(EDIT_FLASH_MIN_ALPHA, 1.0, pulse_amount)
	elif _resolution_value_label != null:
		_resolution_value_label.modulate.a = 1.0
	if _resolution_value_label != null:
		var resolution_text := "Native" if SettingsManager.fullscreen else _format_resolution(shown_resolution)
		_resolution_value_label.text = "[left][color=#000000]%s[/color][/left]" % resolution_text
	if _resolution_label != null:
		_prepare_option_label_settings(_resolution_label)
		if is_active:
			_resolution_label.label_settings = _resolution_label.get_meta("option_focus_label_settings") as LabelSettings
		else:
			_resolution_label.label_settings = _resolution_label.get_meta("option_default_label_settings") as LabelSettings

func _refresh_performance_preset_visual() -> void:
	if _preset_value_label == null and _preset_label == null:
		return
	var shown_preset: int = SettingsManager.performance_preset
	var is_active: bool = _editing_preset_control != null or (_preset_control != null and _preset_control.has_focus())
	if _editing_preset_control != null:
		shown_preset = _editing_preset_value
		var pulse_amount: float = (sin(_edit_flash_time * EDIT_FLASH_SPEED) + 1.0) * 0.5
		if _preset_value_label != null:
			_preset_value_label.modulate.a = lerpf(EDIT_FLASH_MIN_ALPHA, 1.0, pulse_amount)
	elif _preset_value_label != null:
		_preset_value_label.modulate.a = 1.0
	if _preset_value_label != null:
		_preset_value_label.text = _format_performance_preset_value(shown_preset)
	if _preset_label != null:
		_prepare_option_label_settings(_preset_label)
		_preset_label.label_settings = _preset_label.get_meta("option_focus_label_settings") as LabelSettings if is_active else _preset_label.get_meta("option_default_label_settings") as LabelSettings

func _refresh_fps_visual() -> void:
	if _fps_value_label != null:
		var checkmark: String = MUTE_CHECKMARK if _is_fps_setting_enabled() else ""
		_fps_value_label.text = "[left][color=#000000]%s[/color][/left]" % checkmark
		_fps_value_label.modulate.a = 1.0
	if _fps_label != null:
		_prepare_option_label_settings(_fps_label)
		var is_active: bool = _fps_control != null and _fps_control.has_focus()
		_fps_label.label_settings = _fps_label.get_meta("option_focus_label_settings") as LabelSettings if is_active else _fps_label.get_meta("option_default_label_settings") as LabelSettings

func _is_fps_setting_enabled() -> bool:
	for property: Dictionary in SettingsManager.get_property_list():
		if StringName(property.get("name", &"")) == &"show_fps":
			return bool(SettingsManager.get(&"show_fps"))
	return false

func _format_performance_preset_value(preset: int) -> String:
	var fast_text := "Fast"
	var balanced_text := "Balanced"
	var nice_text := "Nice"
	match preset:
		SettingsManager.PerformancePreset.PERFORMANCE:
			fast_text = "[b]%s[/b]" % fast_text
		SettingsManager.PerformancePreset.QUALITY:
			nice_text = "[b]%s[/b]" % nice_text
		_:
			balanced_text = "[b]%s[/b]" % balanced_text
	return "[left][color=#000000]%s \\ %s \\ %s[/color][/left]" % [fast_text, balanced_text, nice_text]

func _refresh_radio_control_visual(control: Button, selected: bool) -> void:
	var font: Font = _get_option_font(selected and control.has_focus())
	var font_color := INPUT_FONT_COLOR
	control.text = MUTE_CHECKMARK if selected else ""
	control.add_theme_font_override("font", font)
	control.add_theme_color_override("font_color", font_color)
	control.add_theme_color_override("font_hover_color", font_color)
	control.add_theme_color_override("font_pressed_color", font_color)
	control.add_theme_color_override("font_focus_color", font_color)
	control.add_theme_color_override("font_disabled_color", font_color)
	_refresh_option_label_visual(control)

func _get_option_type(control: Button) -> String:
	return String(control.get_meta("option_type", OPTION_TYPE_VOLUME))

func _find_option_label_for_control(control: Button) -> Label:
	var parent := control.get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		var label := child as Label
		if label:
			return label
	return null

func _refresh_option_label_visual(control: Button) -> void:
	if not control.has_meta("option_label"):
		return
	var label := control.get_meta("option_label") as Label
	if label == null:
		return
	_prepare_option_label_settings(label)
	var is_active: bool = control.has_focus() or control == _editing_volume_control
	if is_active:
		label.label_settings = label.get_meta("option_focus_label_settings") as LabelSettings
	else:
		label.label_settings = label.get_meta("option_default_label_settings") as LabelSettings

func _prepare_option_label_settings(label: Label) -> void:
	if label.has_meta("option_focus_label_settings"):
		return
	var default_settings := label.label_settings
	var option_default_settings: LabelSettings = null
	if default_settings:
		option_default_settings = default_settings.duplicate() as LabelSettings
	else:
		option_default_settings = LabelSettings.new()
	option_default_settings.font = INPUT_FONT
	option_default_settings.font_color = INPUT_FONT_COLOR
	label.set_meta("option_default_label_settings", option_default_settings)
	var focus_settings: LabelSettings = null
	if default_settings:
		focus_settings = default_settings.duplicate() as LabelSettings
	else:
		focus_settings = LabelSettings.new()
	focus_settings.font = _get_input_focus_font()
	focus_settings.font_color = INPUT_FONT_COLOR
	label.set_meta("option_focus_label_settings", focus_settings)

func _get_option_font(is_active: bool) -> Font:
	if is_active:
		return _get_input_focus_font()
	return INPUT_FONT

func _get_input_focus_font() -> FontVariation:
	if _input_focus_font == null:
		_input_focus_font = FontVariation.new()
		_input_focus_font.base_font = INPUT_FONT
		_input_focus_font.variation_embolden = 0.75
	return _input_focus_font

func _build_best_resolution_options() -> Array[Vector2i]:
	var screen_size := DisplayServer.screen_get_size()
	var candidates: Array[Vector2i] = []
	_add_resolution_candidate(candidates, screen_size, screen_size)
	_add_resolution_candidate(candidates, SettingsManager.resolution, screen_size)
	_add_resolution_candidate(candidates, DisplayServer.window_get_size(), screen_size)
	for resolution in PREFERRED_RESOLUTIONS:
		_add_resolution_candidate(candidates, resolution, screen_size)
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

func _add_resolution_candidate(candidates: Array[Vector2i], resolution: Vector2i, screen_size: Vector2i) -> void:
	if resolution.x <= 0 or resolution.y <= 0:
		return
	if resolution.x > screen_size.x or resolution.y > screen_size.y:
		return
	if candidates.has(resolution):
		return
	candidates.append(resolution)

func _format_resolution(resolution: Vector2i) -> String:
	return "%d X %d" % [resolution.x, resolution.y]

func _get_resolution_control_value(control: Button) -> Vector2i:
	var value: Variant = control.get_meta("option_value", Vector2i.ZERO)
	if value is Vector2i:
		return value
	if value is Vector2:
		var vector_value := value as Vector2
		return Vector2i(int(vector_value.x), int(vector_value.y))
	return Vector2i.ZERO

func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _is_input_handled() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.is_input_handled()

func _event_is_cancel_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel")

func _is_ui_direction_pressed(event: InputEvent, action_name: String) -> bool:
	if not event.is_action_pressed(action_name):
		return false
	if not (event is InputEventJoypadMotion):
		return true
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_last_ui_joypad_motion_msec.get(action_name, -UI_JOYPAD_MOTION_REPEAT_DELAY_MSEC))
	if now_msec - last_msec < UI_JOYPAD_MOTION_REPEAT_DELAY_MSEC:
		return false
	_last_ui_joypad_motion_msec[action_name] = now_msec
	return true

func _is_ui_direction_motion_event(event: InputEvent, action_name: String) -> bool:
	return event is InputEventJoypadMotion and event.is_action_pressed(action_name)

func _is_any_ui_direction_motion_event(event: InputEvent) -> bool:
	if _is_ui_direction_motion_event(event, "ui_up"):
		return true
	if _is_ui_direction_motion_event(event, "ui_down"):
		return true
	if _is_ui_direction_motion_event(event, "ui_left"):
		return true
	return _is_ui_direction_motion_event(event, "ui_right")
