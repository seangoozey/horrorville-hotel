# res://autoload/GameState.gd
extends Node

enum PowerMode { GRID_ON, POWER_OFF, GENERATOR_ON }

signal power_mode_changed(new_mode: int)
signal active_character_changed(character_id: String)
signal flag_changed(flag: String, value: bool)

var power_mode: int = PowerMode.GRID_ON
var active_character_id: String = "journalist"

# simple global flags for puzzle progression
var flags := {
	"gsa_discovered": false,
	"wrench_found": false,
	"wrench_clean": false,
	"wrench_passed": false,
	"gsa_freed": false,
	"pumps_disabled": false,
	"slime_dead": false
}

func set_power_mode(new_mode: int) -> void:
	if power_mode == new_mode:
		return
	power_mode = new_mode
	power_mode_changed.emit(power_mode)

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
