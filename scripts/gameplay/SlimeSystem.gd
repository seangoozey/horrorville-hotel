# res://scripts/gameplay/SlimeSystem.gd
extends Node2D

@export var slime_blob: ColorRect
@export var pump_anchor: Node2D
@export var kill_point: Node2D
@export var journalist: Node2D
@export var gsa: Node2D

@export var speed := 55.0
@export var lure_radius := 130.0

var _mode: int = GameState.PowerMode.GRID_ON

func _ready() -> void:
	GameState.power_mode_changed.connect(_on_power_mode_changed)
	_on_power_mode_changed(GameState.power_mode)

func _process(delta: float) -> void:
	if GameState.get_flag("slime_dead"):
		if slime_blob:
			slime_blob.visible = false
		return

	var target_pos := pump_anchor.global_position

	if _mode == GameState.PowerMode.GRID_ON:
		target_pos = pump_anchor.global_position

	elif _mode == GameState.PowerMode.POWER_OFF:
		var active := _get_active_character()
		if active and active.global_position.distance_to(slime_blob.global_position) <= lure_radius:
			target_pos = active.global_position
		else:
			# idle drift back toward pumps slowly
			target_pos = pump_anchor.global_position

	elif _mode == GameState.PowerMode.GENERATOR_ON:
		target_pos = kill_point.global_position
		if slime_blob.global_position.distance_to(target_pos) < 8.0:
			GameState.set_flag("slime_dead", true)
			return

	slime_blob.global_position = slime_blob.global_position.move_toward(target_pos, speed * delta)

func _on_power_mode_changed(m: int) -> void:
	_mode = m
	if slime_blob:
		slime_blob.visible = true

func _get_active_character() -> Node2D:
	return journalist if GameState.active_character_id == "journalist" else gsa
