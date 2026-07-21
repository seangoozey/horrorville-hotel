# res://autoload/GameState.gd
# Purpose: Store global game state (flags, power mode, active character, pause) and emit change signals.
extends Node

enum PowerMode { GRID_ON, POWER_OFF, GENERATOR_ON }
enum PauseReason { NONE, DEATH, PAUSE, WIN }

signal power_mode_changed(new_mode: int)
signal active_character_changed(character_id: String)
signal flag_changed(flag: String, value: bool)
signal pause_changed(paused: bool, reason: int)
signal journal_open_changed(is_open: bool)

var power_mode: int = PowerMode.GRID_ON
var active_character_id: String = "journalist"
var is_paused := false
var pause_reason: int = PauseReason.NONE
var is_journal_open := false

func get_character(id: String) -> CharacterBase:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	if id == "journalist":
		var journalist: CharacterBase = root.get_node_or_null("Characters/Journalist") as CharacterBase
		return journalist if journalist != null else root.get_node_or_null("Journalist") as CharacterBase
	if id == "gsa":
		var gsa: CharacterBase = root.get_node_or_null("Characters/GSA") as CharacterBase
		return gsa if gsa != null else root.get_node_or_null("GSA") as CharacterBase
	return null

func get_active_character() -> CharacterBase:
	return get_character(active_character_id)

# simple global flags for puzzle progression
const DEFAULT_FLAGS: Dictionary = {
	"gsa_discovered": false,
	"wrench_found": false,
	"wrench_clean": false,
	"wrench_passed": false,
	"gsa_freed": false,
	"pumps_disabled": false,
	"slime_dead": false,
	"power_permanently_off": false,
	"generator_permanently_disabled": false,
	"slime_trap_plan": false,
	"slime_trap_set": false
}

var flags: Dictionary = DEFAULT_FLAGS.duplicate()

func reset_runtime_state() -> void:
	set_journal_open(false)
	set_paused(false)
	set_active_character("journalist")
	for flag_variant: Variant in DEFAULT_FLAGS.keys():
		var flag: String = str(flag_variant)
		set_flag(flag, bool(DEFAULT_FLAGS[flag]))
	for flag_variant: Variant in flags.keys():
		var flag: String = str(flag_variant)
		if not DEFAULT_FLAGS.has(flag):
			flags.erase(flag)
	set_power_mode(PowerMode.GRID_ON)

func set_power_mode(new_mode: int) -> void:
	if get_flag("power_permanently_off") and new_mode != PowerMode.POWER_OFF:
		new_mode = PowerMode.POWER_OFF
	if power_mode == new_mode:
		return
	power_mode = new_mode
	power_mode_changed.emit(power_mode)

func lock_power_off() -> void:
	set_flag("power_permanently_off", true)
	set_power_mode(PowerMode.POWER_OFF)

func set_active_character(id: String) -> void:
	if active_character_id == id:
		return
	active_character_id = id
	active_character_changed.emit(active_character_id)

func set_flag(flag: String, value: bool) -> void:
	if not flags.has(flag):
		flags[flag] = value
		flag_changed.emit(flag, value)
		return
	if flags[flag] == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)

func get_flag(flag: String) -> bool:
	return flags.get(flag, false)

func set_paused(paused: bool, reason: int = PauseReason.PAUSE) -> void:
	if is_paused == paused and pause_reason == reason:
		return
	is_paused = paused
	pause_reason = reason if paused else PauseReason.NONE
	get_tree().paused = is_paused
	pause_changed.emit(is_paused, pause_reason)

func set_journal_open(is_open: bool) -> void:
	if is_journal_open == is_open:
		return
	is_journal_open = is_open
	journal_open_changed.emit(is_journal_open)
