# res://scripts/gameplay/LayerController.gd
extends Node

class_name LayerController
enum ViewLayer { EXTERIOR, INTERIOR, CELLAR }

signal layer_changed(layer: ViewLayer)

@export var exterior_layer: Node2D
@export var slime_body: CharacterBody2D
@export var slime_collision_layer := 1

var current: int = ViewLayer.EXTERIOR

func _ready() -> void:
	_update_slime_collision_mask()

func _get_current() -> ViewLayer:
	return current as ViewLayer
	
func set_layer(layer: int) -> void:
	current = layer
	layer_changed.emit(current as ViewLayer)

func _update_slime_collision_mask() -> void:
	if slime_body == null:
		return
	slime_body.collision_mask = _layer_mask(slime_collision_layer)

func _layer_mask(layer_index: int) -> int:
	return 1 << int(layer_index - 1)
