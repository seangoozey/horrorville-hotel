# res://autoload/SceneRouter.gd
extends Node

var current_scene: Node = null

func goto_scene(path: String) -> void:
	var packed := load(path)
	if packed == null:
		push_error("Scene not found: %s" % path)
		return

	if current_scene != null:
		current_scene.queue_free()

	current_scene = packed.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
