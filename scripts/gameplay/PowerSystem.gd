# res://scripts/gameplay/PowerSystem.gd
extends Node

@export var pumps_node: Node
@export var slime_system: Node
@export var lights_group_name := "lights"

func _ready() -> void:
	GameState.power_mode_changed.connect(_apply_power)
	_apply_power(GameState.power_mode)

func _apply_power(mode: int) -> void:
	# Pumps behavior
	if pumps_node:
		pumps_node.set("enabled", mode == GameState.PowerMode.GRID_ON)

	# Lights behavior (optional)
	for n in get_tree().get_nodes_in_group(lights_group_name):
		if n.has_method("set_powered"):
			n.set_powered(mode != GameState.PowerMode.POWER_OFF)

	# Slime behavior
	if slime_system and slime_system.has_method("on_power_mode_changed"):
		slime_system.on_power_mode_changed(mode)
