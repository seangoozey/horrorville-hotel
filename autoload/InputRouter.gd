# res://autoload/InputRouter.gd
# Purpose: Convert input actions into global signals for gameplay and UI systems.
extends Node

signal interact_requested
signal special_action_requested
signal switch_character_requested
signal open_journal_requested
signal ui_cancel_requested
signal ui_accept_requested
signal ui_up_requested
signal ui_down_requested
signal ui_left_requested
signal ui_right_requested
signal input_device_family_changed(family: String)

const UI_JOYPAD_MOTION_REPEAT_DELAY_MSEC := 220
const INPUT_DEVICE_KEYBOARD := "keyboard"
const INPUT_DEVICE_GAMEPAD := "gamepad"

var _last_ui_joypad_motion_msec: Dictionary = {}
var _input_device_family := INPUT_DEVICE_KEYBOARD

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func request_interact() -> void:
	if _should_block_gameplay_action():
		_mark_input_handled()
		return
	interact_requested.emit()

func request_special_action() -> void:
	if _should_block_gameplay_action():
		_mark_input_handled()
		return
	if _should_block_special_action():
		_mark_input_handled()
		return
	special_action_requested.emit()

func request_switch_character() -> void:
	if _should_block_gameplay_action():
		_mark_input_handled()
		return
	switch_character_requested.emit()

func request_open_journal() -> void:
	if _should_block_gameplay_action():
		_mark_input_handled()
		return
	open_journal_requested.emit()

func get_input_device_family() -> String:
	return _input_device_family

func _unhandled_input(event: InputEvent) -> void:
	_update_input_device_family(event)
	if event.is_action_pressed("interact"):
		request_interact()
	elif event.is_action_pressed("special_action"):
		request_special_action()
	elif event.is_action_pressed("switch_character"):
		request_switch_character()
	elif event.is_action_pressed("open_journal"):
		request_open_journal()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		ui_cancel_requested.emit()
	elif event.is_action_pressed("ui_accept"):
		ui_accept_requested.emit()
	elif _is_ui_direction_pressed(event, "ui_up"):
		ui_up_requested.emit()
	elif _is_ui_direction_pressed(event, "ui_down"):
		ui_down_requested.emit()
	elif _is_ui_direction_pressed(event, "ui_left"):
		ui_left_requested.emit()
	elif _is_ui_direction_pressed(event, "ui_right"):
		ui_right_requested.emit()

func _update_input_device_family(event: InputEvent) -> void:
	var next_family := ""
	if event is InputEventJoypadButton and event.is_pressed():
		next_family = INPUT_DEVICE_GAMEPAD
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.5:
		next_family = INPUT_DEVICE_GAMEPAD
	elif event is InputEventKey and event.is_pressed():
		next_family = INPUT_DEVICE_KEYBOARD
	elif event is InputEventMouseButton and event.is_pressed():
		next_family = INPUT_DEVICE_KEYBOARD
	if next_family == "" or next_family == _input_device_family:
		return
	_input_device_family = next_family
	input_device_family_changed.emit(_input_device_family)

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

func _should_block_gameplay_action() -> bool:
	var character := GameState.get_active_character()
	if character == null:
		return false
	return character.is_special_action_active()

func _should_block_special_action() -> bool:
	if GameState.active_character_id != "gsa":
		return false
	var character := GameState.get_active_character()
	if character == null:
		return false
	if character.special_action_id != "fix":
		return false
	if GameState.get_flag("wrench_passed"):
		return false
	if character.is_special_action_active():
		return true
	character.say("gsa_missing_wrench")
	return true

func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()
