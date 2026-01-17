# res://scripts/gameplay/FollowCamera.gd
extends Camera2D

@export var journalist: Node2D
@export var gsa: Node2D

func _ready() -> void:
	GameState.active_character_changed.connect(_on_active_changed)
	_on_active_changed(GameState.active_character_id)

func _on_active_changed(id: String) -> void:
	var target := journalist if id == "journalist" else gsa
	if target:
		global_position = target.global_position

func _process(_delta: float) -> void:
	var target := journalist if GameState.active_character_id == "journalist" else gsa
	if target:
		global_position = target.global_position
