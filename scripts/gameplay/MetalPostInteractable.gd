# res://scripts/gameplay/MetalPostInteractable.gd
extends NoteInteractable
class_name MetalPostInteractable

@export var electrocution_polygon: CollisionPolygon2D
@export var shock_damage := 2
@export var journalist_shock_dialogue_id := "journalist_metal_post_shock"
@export var gsa_shock_dialogue_id := "gsa_metal_post_shock"

var _electrocuted_bodies := {}

func _ready() -> void:
	super._ready()
	if electrocution_polygon == null:
		electrocution_polygon = get_node_or_null("MetalPostElectrocution") as CollisionPolygon2D
	GameState.power_mode_changed.connect(_update_electrocution_state)
	GameState.flag_changed.connect(_on_flag_changed)
	_update_electrocution_state(GameState.power_mode)

func _process(_delta: float) -> void:
	if electrocution_polygon == null or electrocution_polygon.disabled:
		_electrocuted_bodies.clear()
		return
	for body in _bodies_in_range:
		var character := body as CharacterBase
		if character == null:
			continue
		var inside := _is_point_in_collision_polygon(character.global_position, electrocution_polygon)
		if inside and not _electrocuted_bodies.get(character, false):
			_electrocuted_bodies[character] = true
			_apply_shock(character)
		elif not inside and _electrocuted_bodies.get(character, false):
			_electrocuted_bodies.erase(character)

func _on_flag_changed(flag: String, _value: bool) -> void:
	if flag == "slime_trap_set":
		_update_electrocution_state(GameState.power_mode)

func _update_electrocution_state(_mode: int) -> void:
	if electrocution_polygon == null:
		return
	var enabled := GameState.power_mode == GameState.PowerMode.GENERATOR_ON \
		and GameState.get_flag("slime_trap_set")
	electrocution_polygon.disabled = not enabled
	if not enabled:
		_electrocuted_bodies.clear()

func _apply_shock(character: CharacterBase) -> void:
	character.take_damage(shock_damage)
	_trigger_damage_shake(shock_damage)
	if character.character_id == "journalist":
		character.say(journalist_shock_dialogue_id)
	else:
		character.say(gsa_shock_dialogue_id)

func _trigger_damage_shake(amount: int) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var camera := root.get_node_or_null("Camera2D")
	if camera and camera.has_method("trigger_damage_shake"):
		camera.trigger_damage_shake(amount)

func _is_point_in_collision_polygon(point: Vector2, poly_node: CollisionPolygon2D) -> bool:
	var local_poly := poly_node.polygon
	if local_poly.size() < 3:
		return false
	var global_poly := PackedVector2Array()
	global_poly.resize(local_poly.size())
	for i in local_poly.size():
		global_poly[i] = poly_node.global_transform * local_poly[i]
	return Geometry2D.is_point_in_polygon(point, global_poly)
