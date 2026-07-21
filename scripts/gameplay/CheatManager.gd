# res://scripts/gameplay/CheatManager.gd
extends Node
class_name CheatManager

@export var cheats_enabled := true
@export var require_debug_build := true
@export var puzzle: Node
@export var wrench: Area2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event: InputEvent) -> void:
	if not _cheats_allowed():
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if not key_event.ctrl_pressed:
		return

	match key_event.physical_keycode:
		KEY_1:
			skip_gsa_discovered()
		KEY_2:
			skip_wrench_found()
		KEY_3:
			skip_wrench_passed()
		KEY_4:
			skip_generator_fixed()
		KEY_5:
			skip_slime_trap_plan()
		KEY_6:
			skip_slime_trap_set()
		KEY_7:
			skip_cellar_door_open()
		KEY_8:
			skip_ready_for_generator_trap()
		KEY_9:
			turn_generator_on()
		_:
			return
	get_viewport().set_input_as_handled()

func skip_gsa_discovered() -> void:
	GameState.set_flag("gsa_discovered", true)
	_print_cheat("GSA discovered")

func skip_wrench_found() -> void:
	Inventory.give("wrench")
	GameState.set_flag("wrench_found", true)
	_hide_wrench_pickup()
	_print_cheat("wrench found")

func skip_wrench_passed() -> void:
	skip_gsa_discovered()
	skip_wrench_found()
	Inventory.take("wrench")
	GameState.set_flag("wrench_passed", true)
	_print_cheat("wrench passed")

func skip_generator_fixed() -> void:
	skip_wrench_passed()
	GameState.set_flag("generator_fixed", true)
	_print_cheat("generator fixed")

func skip_slime_trap_plan() -> void:
	skip_generator_fixed()
	GameState.set_flag("interactable_cellar_detritus_examine_used", true)
	GameState.set_flag("interactable_sign_post_examine_used", true)
	GameState.set_flag("slime_trap_plan", true)
	_call_puzzle_method("_apply_wire_coil_state")
	_print_cheat("slime trap plan unlocked")

func skip_slime_trap_set() -> void:
	skip_slime_trap_plan()
	Inventory.give("Coil of Copper Wire")
	GameState.set_flag("slime_trap_set", true)
	_print_cheat("slime trap set")

func skip_cellar_door_open() -> void:
	skip_slime_trap_set()
	GameState.set_flag("gsa_freed", true)
	_call_puzzle_method("_apply_cellar_door_repair_state")
	_print_cheat("cellar door open")

func skip_ready_for_generator_trap() -> void:
	skip_cellar_door_open()
	GameState.set_power_mode(GameState.PowerMode.POWER_OFF)
	_print_cheat("ready for generator trap")

func turn_generator_on() -> void:
	skip_ready_for_generator_trap()
	var added_notes: int = NotesManager.add_all_catalog_notes()
	GameState.set_power_mode(GameState.PowerMode.GENERATOR_ON)
	_print_cheat("generator on; added %d journal entries" % added_notes)

func _cheats_allowed() -> bool:
	return cheats_enabled and (not require_debug_build or OS.is_debug_build())

func _hide_wrench_pickup() -> void:
	var wrench_node := wrench
	if wrench_node == null:
		wrench_node = _get_puzzle_property("wrench") as Area2D
	if wrench_node == null:
		return
	if puzzle != null:
		puzzle.emit_signal("update_wrench", wrench_node, false)
	elif wrench_node.has_method("_set_node_enabled_recursive"):
		wrench_node.call("_set_node_enabled_recursive", wrench_node, false)

func _call_puzzle_method(method_name: StringName) -> void:
	if puzzle != null and puzzle.has_method(method_name):
		puzzle.call(method_name)

func _get_puzzle_property(property_name: StringName) -> Variant:
	if puzzle == null:
		return null
	return puzzle.get(property_name)

func _print_cheat(label: String) -> void:
	print("Cheat: ", label)
