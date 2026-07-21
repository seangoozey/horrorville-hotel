# res://scripts/gameplay/ZOrderManager.gd
extends Node
class_name ZOrderManager

@export var journalist_path: NodePath = NodePath("../Characters/Journalist")
@export var gsa_path: NodePath = NodePath("../Characters/GSA")
@export var managed_sprite_paths: Array[NodePath] = [NodePath("../World/Outside/SignSprite")]
@export var z_above_offset := 1
@export var z_below_offset := -1

func _process(_delta: float) -> void:
	var active := _get_active_character()
	if active == null:
		return
	var anchor := active.global_position
	var character_z := active.z_index
	for path in managed_sprite_paths:
		var sprite := get_node_or_null(path) as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var bounds := _global_rect_from_sprite(sprite)
		var target_z := character_z + z_above_offset if bounds.has_point(anchor) else character_z + z_below_offset
		if sprite.z_index != target_z:
			sprite.z_index = target_z

func _get_active_character() -> CharacterBody2D:
	var journalist := get_node_or_null(journalist_path) as CharacterBody2D
	var gsa := get_node_or_null(gsa_path) as CharacterBody2D
	return journalist if GameState.active_character_id == "journalist" else gsa

func _global_rect_from_sprite(sprite: Sprite2D) -> Rect2:
	var local_rect := sprite.get_rect()
	var p0 := sprite.to_global(local_rect.position)
	var p1 := sprite.to_global(local_rect.position + Vector2(local_rect.size.x, 0.0))
	var p2 := sprite.to_global(local_rect.position + Vector2(0.0, local_rect.size.y))
	var p3 := sprite.to_global(local_rect.position + local_rect.size)
	var min_x := minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var min_y := minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_x := maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var max_y := maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
