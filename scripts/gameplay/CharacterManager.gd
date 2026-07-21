# res://scripts/gameplay/CharacterManager.gd
extends Node

@export var journalist: CharacterBase
@export var gsa: CharacterBase
@export var slime_blob: CharacterBody2D
@export var layer_controller_path: NodePath

@onready var controller := get_node(layer_controller_path)

func _ready() -> void:
	GameState.active_character_changed.connect(_apply_active)
	if gsa:
		gsa._set_location(LayerController.ViewLayer.CELLAR)
		gsa.location_changed.connect(_update_character_collisions)
	if journalist:
		journalist.location_changed.connect(_update_character_collisions)
	if slime_blob != null and slime_blob.has_signal("location_changed"):
		slime_blob.location_changed.connect(_update_character_collisions)
	_apply_active(GameState.active_character_id)
	_update_character_collisions()
	_start_intro_dialogue()

func _apply_active(id: String) -> void:
	var gsa_unlocked := GameState.get_flag("gsa_discovered")

	_set_control(journalist, id == "journalist")
	_set_control(gsa, id == "gsa" and gsa_unlocked)
	if GameState.active_character_id=="journalist":
		controller.set_layer(journalist.current_location)
	else:
		controller.set_layer(gsa.current_location)

func _set_control(c: CharacterBase, enabled: bool) -> void:
	if c == null:
		push_error("CharacterManager: character reference is null (check Inspector assignments).")
		return

	c.set_physics_process(enabled)
	c.set_process_input(enabled)

	# Prevent drift when disabling
	if not enabled:
		c.velocity = Vector2.ZERO

func _update_character_collisions() -> void:
	_set_collision_pair_enabled(journalist, gsa, _share_location(journalist, gsa))
	_set_collision_pair_enabled(journalist, slime_blob, _share_location(journalist, slime_blob))
	_set_collision_pair_enabled(gsa, slime_blob, _share_location(gsa, slime_blob))

func _set_collision_pair_enabled(a: PhysicsBody2D, b: PhysicsBody2D, enabled: bool) -> void:
	if a == null or b == null:
		return
	if enabled:
		a.remove_collision_exception_with(b)
		b.remove_collision_exception_with(a)
	else:
		a.add_collision_exception_with(b)
		b.add_collision_exception_with(a)

func _share_location(a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var a_location: Variant = a.get("current_location")
	var b_location: Variant = b.get("current_location")
	return a_location == b_location

func _start_intro_dialogue() -> void:
	if journalist == null:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		journalist.say("journalist_intro")
	)

func _get_active_character() -> CharacterBase:
	return journalist if GameState.active_character_id == "journalist" else gsa
