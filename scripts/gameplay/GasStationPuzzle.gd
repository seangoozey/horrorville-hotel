# res://scripts/gameplay/GasStationPuzzle.gd
extends Node

signal update_wrench(n: Node, enabled: bool)


@export var wrench: Area2D
@export var window: Area2D
@export var breakers: Area2D
@export var door_latch: Area2D
@export var door_wall_collision: CollisionPolygon2D
@export var open_door_wall_collision: Node
@export var door_mask: Area2D
@export var door_open_mask: Area2D
@export var wire_coil: Area2D

# require slime blob distance > threshold
@export var slime_blob: CharacterBody2D
@export var wrench_safe_distance := 50.0

func _ready() -> void:
	# connect interactables
	(wrench as Area2D).interacted.connect(_on_interacted)
	(window as Area2D).interacted.connect(_on_interacted)
	(breakers as Area2D).interacted.connect(_on_interacted)
	(door_latch as Area2D).interacted.connect(_on_interacted)

	InputRouter.switch_character_requested.connect(_on_switch_character_requested)
	GameState.flag_changed.connect(_on_flag_changed)
	_apply_wire_coil_state()
	call_deferred("_apply_cellar_door_repair_state")
	_update_slime_trap_plan()

func _on_switch_character_requested() -> void:
	# Gate switching until GSA is discovered
	if not GameState.get_flag("gsa_discovered"):
		return

	if GameState.active_character_id == "journalist":
		GameState.set_active_character("gsa")
	else:
		GameState.set_active_character("journalist")

func _on_interacted(id: String) -> void:
	match id:
		"window":
			# Discover GSA
			if not GameState.get_flag("gsa_discovered"):
				GameState.set_flag("gsa_discovered", true)
			# window is also where you pass the wrench later
			if Inventory.has("wrench") and not GameState.get_flag("wrench_passed"):
				# Require the slime to be "contained" (grid on) OR power off - you decide.
				# For now: allow anytime after wrench is acquired.
				Inventory.take("wrench")
				GameState.set_flag("wrench_passed", true)

		"breakers":
			if GameState.get_flag("power_permanently_off"):
				return
			# GSA only (set allowed_character on interactable)
			# Toggle between GRID_ON and POWER_OFF; generator mode is separate.
			if GameState.power_mode == GameState.PowerMode.GRID_ON:
				GameState.set_power_mode(GameState.PowerMode.POWER_OFF)
			elif GameState.power_mode == GameState.PowerMode.POWER_OFF:
				GameState.set_power_mode(GameState.PowerMode.GRID_ON)
			elif GameState.power_mode == GameState.PowerMode.GENERATOR_ON:
				# If generator is running, breakers still represent "grid" state.
				# For MVP: disallow toggling while generator on.
				return

		"wrench":
			# Journalist only (set allowed_character on interactable)
			if slime_blob and slime_blob.global_position.distance_to(wrench.global_position) < wrench_safe_distance:
				return

			# The wrench is only safe to pick up if power is off (so slime can be lured away).
			if GameState.power_mode != GameState.PowerMode.POWER_OFF:
				# can't pick up while contained/active
				return
			if GameState.get_flag("wrench_found"):
				return
			Inventory.give("wrench")
			GameState.set_flag("wrench_found", true)
			update_wrench.emit(wrench,false)

		"door_latch":
			# GSA only; requires wrench_passed
			# If the journalist reaches the latch first, they discover the GSA.
			if not GameState.get_flag("gsa_discovered"):
				GameState.set_flag("gsa_discovered", true)
			if not GameState.get_flag("wrench_passed"):
				return
			if GameState.get_flag("gsa_freed"):
				return
			GameState.set_flag("gsa_freed", true)
			_apply_cellar_door_repair_state()

func _on_flag_changed(flag: String, value: bool) -> void:
	if not value:
		return
	if flag == "generator_fixed" \
			or flag == "interactable_cellar_detritus_examine_used" \
			or flag == "interactable_sign_post_examine_used":
		_update_slime_trap_plan()
	elif flag == "slime_trap_plan":
		_apply_wire_coil_state()

func _update_slime_trap_plan() -> void:
	if GameState.get_flag("slime_trap_plan"):
		return
	if GameState.get_flag("generator_fixed") \
			and GameState.get_flag("interactable_cellar_detritus_examine_used") \
			and GameState.get_flag("interactable_sign_post_examine_used"):
		GameState.set_flag("slime_trap_plan", true)

func _apply_wire_coil_state() -> void:
	if wire_coil == null:
		return
	var enabled := GameState.get_flag("slime_trap_plan")
	_set_node_lock_recursive(wire_coil, not enabled)
	wire_coil.visible = enabled
	_set_node_enabled_recursive(wire_coil, enabled)

func _apply_cellar_door_repair_state() -> void:
	var door_open := GameState.get_flag("gsa_freed")
	if door_wall_collision != null:
		_set_node_enabled_recursive(door_wall_collision, not door_open)
	var open_wall := _get_open_door_wall_collision()
	if open_wall != null:
		_set_node_enabled_recursive(open_wall, door_open)
	if door_mask != null:
		_set_node_enabled_recursive(door_mask, not door_open)
	if door_open_mask != null:
		_set_node_enabled_recursive(door_open_mask, door_open)

func _get_open_door_wall_collision() -> Node:
	if open_door_wall_collision != null:
		return open_door_wall_collision
	var root := owner if owner != null else get_tree().current_scene
	if root == null:
		return null
	return root.find_child("OpenDoorWallCollision", true, false)

func _set_node_lock_recursive(n: Node, locked: bool) -> void:
	n.set_meta("layer_lock_disabled", locked)
	for child in n.get_children():
		_set_node_lock_recursive(child, locked)

func _set_node_enabled_recursive(n: Node, enabled: bool) -> void:
	if n.has_method("set_mask_enabled"):
		n.call("set_mask_enabled", enabled)
	if n is Area2D:
		var a := n as Area2D
		a.set_deferred("monitoring", enabled)
		a.set_deferred("monitorable", enabled)
	if n is CollisionObject2D:
		var c := n as CollisionObject2D
		c.set_deferred("disabled", not enabled)
	if n is CollisionShape2D:
		var cs := n as CollisionShape2D
		cs.set_deferred("disabled", not enabled)
	if n is CollisionPolygon2D:
		var cp := n as CollisionPolygon2D
		cp.set_deferred("disabled", not enabled)
	for child in n.get_children():
		_set_node_enabled_recursive(child, enabled)
