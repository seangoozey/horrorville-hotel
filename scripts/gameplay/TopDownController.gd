# res://scripts/gameplay/TopDownController.gd
extends CharacterBody2D

@export var speed := 160.0
@export var character_id: String = ""  # set to "journalist" or "gsa" in Inspector

func _physics_process(_delta: float) -> void:
	# If not the active character, do nothing
	if character_id != "" and GameState.active_character_id != character_id:
		velocity = Vector2.ZERO
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed
	move_and_slide()
