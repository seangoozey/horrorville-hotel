# res://scripts/gameplay/LayerTrigger.gd
extends Area2D

@export var target_layer: LayerController.ViewLayer
@export var layer_controller_path: NodePath
@export var destination_path: NodePath

@onready var controller := get_node_or_null(layer_controller_path)
@onready var destination := get_node_or_null(destination_path) as Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if destination == null:
		return
	if not _is_supported_body(body):
		return
	_apply_location(body, target_layer)
	if body is CharacterBase:
		if controller:
			controller.call_deferred("set_layer", target_layer)
	_teleport_body(body, destination)

func _is_supported_body(body: Node) -> bool:
	return body is CharacterBase

func _apply_location(body: Node, layer: LayerController.ViewLayer) -> void:
	var character := body as CharacterBase
	if character != null:
		character._set_location(layer)

func _teleport_body(body: Node, to_node: Node2D) -> void:
	if to_node == null:
		return
	var dest := to_node.global_position
	if body is CharacterBody2D:
		var character_body := body as CharacterBody2D
		character_body.global_position = dest
		character_body.velocity = Vector2.ZERO
	elif body is Node2D:
		(body as Node2D).global_position = dest
