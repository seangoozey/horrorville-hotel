# res://scripts/gameplay/Interactable.gd
extends Area2D

@export var id: String
@export var prompt: String = "Interact"
@export var allowed_character: String = ""  # "" = anyone, "journalist" or "gsa"
@export var requires_flag: String = ""
@export var requires_item: String = ""

signal interacted(interactable_id: String)

var _bodies_in_range: Array[CharacterBody2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not can_interact():
		return
	interacted.emit(id)

func can_interact() -> bool:
	var active := _get_active_body()
	if active == null:
		return false
	if not _bodies_in_range.has(active):
		return false

	if allowed_character != "" and GameState.active_character_id != allowed_character:
		return false
	if requires_flag != "" and not GameState.get_flag(requires_flag):
		return false
	if requires_item != "" and not Inventory.has(requires_item):
		return false
	return true

func _get_active_body() -> CharacterBody2D:
	# Assumes your character nodes are named "Journalist" and "GSA"
	# If yours are named differently, change these paths accordingly.
	var root := get_tree().current_scene
	if root == null:
		return null
	if GameState.active_character_id == "journalist":
		return root.get_node_or_null("Journalist") as CharacterBody2D
	else:
		return root.get_node_or_null("GSA") as CharacterBody2D

func _on_body_entered(body: Node) -> void:
	var cb := body as CharacterBody2D
	if cb == null:
		return
	if not _bodies_in_range.has(cb):
		_bodies_in_range.append(cb)

func _on_body_exited(body: Node) -> void:
	var cb := body as CharacterBody2D
	if cb == null:
		return
	_bodies_in_range.erase(cb)
