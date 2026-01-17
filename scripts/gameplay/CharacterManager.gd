# res://scripts/gameplay/CharacterManager.gd
extends Node

@export var journalist: CharacterBody2D
@export var gsa: CharacterBody2D

func _ready() -> void:
	GameState.active_character_changed.connect(_apply_active)
	_apply_active(GameState.active_character_id)

func _apply_active(id: String) -> void:
	var gsa_unlocked := GameState.get_flag("gsa_discovered")

	_set_control(journalist, id == "journalist")
	_set_control(gsa, id == "gsa" and gsa_unlocked)

func _set_control(c: CharacterBody2D, enabled: bool) -> void:
	if c == null:
		push_error("CharacterManager: character reference is null (check Inspector assignments).")
		return

	# Keep both visible (since you want that)
	c.visible = true

	c.set_physics_process(enabled)
	c.set_process_input(enabled)

	# Prevent drift when disabling
	if not enabled:
		c.velocity = Vector2.ZERO

	print("Setting Character:", c.name, " enabled=", enabled)
