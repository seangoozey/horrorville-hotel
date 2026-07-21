# res://scripts/gameplay/Interactable.gd
extends Area2D
class_name Interactable

@export var id: String
@export var prompt: String = "Interact"
@export var allowed_character: String = ""  # "" = anyone, "journalist" or "gsa"
@export var standard_allowed_character: String = ""  # Optional override for E-interact
@export var requires_flag: String = ""
@export var requires_special_flag: String = ""
@export var requires_item: String = ""
@export var requires_special_item: String = ""
@export var requires_special_action_id: String = ""
@export var special_action_ids: Array[String] = []
@export var allow_standard_interact: bool = false
@export var disable_on_special_action: bool = false
@export var emit_interact_on_special_action: bool = true

var permanently_disabled: bool = false

signal interacted(interactable_id: String)
signal special_interacted(interactable_id: String, action_id: String, character: CharacterBase)

var _bodies_in_range: Array[CharacterBody2D] = []
var _pending_special: bool = false
var _pending_character: CharacterBase = null
var _pending_action_id: String = ""
var _pending_fail_reason: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	InputRouter.interact_requested.connect(_on_interact_requested)
	InputRouter.special_action_requested.connect(_on_special_action_requested)
	add_to_group("interactables")

func _on_interact_requested() -> void:
	if not can_interact():
		return
	interacted.emit(id)

func _on_special_action_requested() -> void:
	if can_special_interact():
		_start_special_action(true, "")
		return
	if _can_fail_special_interact():
		_start_special_action(false, _get_special_action_fail_reason())

func is_active_in_range() -> bool:
	if permanently_disabled:
		return false
	var active := _get_active_body()
	if active == null:
		return false
	return _bodies_in_range.has(active)

func get_prompt_text() -> String:
	if can_interact():
		return "%s (E)" % prompt
	return ""

func can_interact() -> bool:
	if permanently_disabled:
		return false
	if (requires_special_action_id != "" or not special_action_ids.is_empty()) and not allow_standard_interact:
		return false
	var active := _get_active_body()
	if active == null:
		return false
	if not _bodies_in_range.has(active):
		return false

	var standard_allowed := standard_allowed_character if standard_allowed_character != "" else allowed_character
	if standard_allowed != "" and GameState.active_character_id != standard_allowed:
		return false
	if requires_flag != "" and not GameState.get_flag(requires_flag):
		return false
	if requires_item != "" and not Inventory.has(requires_item):
		return false
	return true

func can_special_interact() -> bool:
	if permanently_disabled:
		return false
	var active := _get_active_body()
	if active == null:
		return false
	if not _bodies_in_range.has(active):
		return false
	var character: CharacterBase = active as CharacterBase
	if character == null:
		return false
	if not special_action_ids.is_empty():
		if not special_action_ids.has(character.special_action_id):
			return false
	elif character.special_action_id != requires_special_action_id:
		return false
	if allowed_character != "" and GameState.active_character_id != allowed_character:
		return false
	if requires_flag != "" and not GameState.get_flag(requires_flag):
		return false
	if requires_special_flag != "" and not GameState.get_flag(requires_special_flag):
		return false
	if requires_item != "" and not Inventory.has(requires_item):
		return false
	if requires_special_item != "" and not Inventory.has(requires_special_item):
		return false
	return true

func can_handle_special_action() -> bool:
	return can_special_interact() or _can_fail_special_interact()

func _get_active_body() -> CharacterBody2D:
	return GameState.get_active_character() as CharacterBody2D

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
	if _pending_character == cb:
		var character: CharacterBase = cb as CharacterBase
		if character != null:
			_disconnect_special_action_completed(character)
			_disconnect_special_action_canceled(character)
		_clear_pending_special()

func _start_special_action(is_effective: bool, fail_reason: String) -> void:
	if _pending_special:
		return
	var active := _get_active_body()
	var character: CharacterBase = active as CharacterBase
	if character == null:
		return
	if character.is_special_action_active() or character.special_action_id == "":
		return
	var action_id := character.special_action_id
	var already_used: bool = _is_special_action_used(action_id)
	if already_used:
		is_effective = false
		fail_reason = "repeat_action"
	_pending_special = true
	_pending_character = character
	_pending_action_id = action_id
	_pending_fail_reason = fail_reason
	_connect_special_action_signals(character)
	character.start_special_action(is_effective)

func _on_special_action_completed(action_id: String, was_effective: bool, character: CharacterBase) -> void:
	if not _pending_special:
		return
	if character != null:
		_disconnect_special_action_canceled(character)
	_pending_special = false
	if character == null:
		_clear_pending_special()
		return
	if not _bodies_in_range.has(character):
		_clear_pending_special()
		return
	var fail_reason := _pending_fail_reason
	_pending_fail_reason = ""
	if not was_effective:
		_handle_special_action_failed(action_id, character, fail_reason)
		_clear_pending_special()
		return
	if not special_action_ids.is_empty():
		if not special_action_ids.has(action_id):
			_clear_pending_special()
			return
	elif action_id != requires_special_action_id:
		_clear_pending_special()
		return
	_mark_special_action_used(action_id)
	special_interacted.emit(id, action_id, character)
	if emit_interact_on_special_action:
		interacted.emit(id)
	if disable_on_special_action:
		# Any successful special action (examine/fix) permanently disables this interactable.
		_set_node_collisions_enabled_recursive(self, false)
	_clear_pending_special()

func _on_special_action_canceled(_action_id: String, character: CharacterBase) -> void:
	if character != null:
		_disconnect_special_action_completed(character)
	if _pending_character == character:
		_clear_pending_special()

func _clear_pending_special() -> void:
	_pending_special = false
	_pending_character = null
	_pending_action_id = ""
	_pending_fail_reason = ""

func _connect_special_action_signals(character: CharacterBase) -> void:
	var completed_callable := _get_completed_callable(character)
	var canceled_callable := _get_canceled_callable(character)
	if not character.special_action_completed.is_connected(completed_callable):
		character.special_action_completed.connect(completed_callable, CONNECT_ONE_SHOT)
	if not character.special_action_canceled.is_connected(canceled_callable):
		character.special_action_canceled.connect(canceled_callable, CONNECT_ONE_SHOT)

func _disconnect_special_action_completed(character: CharacterBase) -> void:
	var completed_callable := _get_completed_callable(character)
	if character.special_action_completed.is_connected(completed_callable):
		character.special_action_completed.disconnect(completed_callable)

func _disconnect_special_action_canceled(character: CharacterBase) -> void:
	var canceled_callable := _get_canceled_callable(character)
	if character.special_action_canceled.is_connected(canceled_callable):
		character.special_action_canceled.disconnect(canceled_callable)

func _get_completed_callable(character: CharacterBase) -> Callable:
	return _on_special_action_completed.bind(character)

func _get_canceled_callable(character: CharacterBase) -> Callable:
	return _on_special_action_canceled.bind(character)

func _handle_special_action_failed(_action_id: String, character: CharacterBase, fail_reason: String) -> void:
	if character == null:
		return
	var line_id := ""
	if fail_reason == "repeat_action":
		match character.character_id:
			"journalist":
				line_id = "journalist_repeat_action"
			"gsa":
				line_id = "gsa_repeat_action"
	elif fail_reason == "repair_examine_only":
		if character.character_id == "gsa":
			line_id = "gsa_repair_examine_only"
	else:
		match character.character_id:
			"journalist":
				line_id = "journalist_no_action"
			"gsa":
				line_id = "gsa_no_action"
	if line_id != "":
		character.say(line_id)

func _get_special_action_fail_reason() -> String:
	var active := _get_active_body()
	var character: CharacterBase = active as CharacterBase
	if character != null and character.character_id == "gsa" and character.special_action_id == "fix" and _is_examine_only_special_area():
		return "repair_examine_only"
	return "no_action"

func _is_examine_only_special_area() -> bool:
	if not special_action_ids.is_empty():
		return special_action_ids.has("examine") and not special_action_ids.has("fix")
	return requires_special_action_id == "examine"

func _can_fail_special_interact() -> bool:
	if permanently_disabled:
		return false
	var active := _get_active_body()
	if active == null:
		return false
	if not _bodies_in_range.has(active):
		return false
	var character: CharacterBase = active as CharacterBase
	if character == null:
		return false
	if character.is_special_action_active():
		return false
	if requires_special_action_id == "" and special_action_ids.is_empty():
		return false
	if allowed_character != "" and GameState.active_character_id != allowed_character:
		return true
	if requires_flag != "" and not GameState.get_flag(requires_flag):
		return true
	if requires_special_flag != "" and not GameState.get_flag(requires_special_flag):
		return true
	if requires_item != "" and not Inventory.has(requires_item):
		return true
	if requires_special_item != "" and not Inventory.has(requires_special_item):
		return true
	if not special_action_ids.is_empty():
		return not special_action_ids.has(character.special_action_id)
	return character.special_action_id != requires_special_action_id

func _is_special_action_used(action_id: String) -> bool:
	if id == "" or action_id == "":
		return false
	return GameState.get_flag(_get_special_action_flag(action_id))

func _mark_special_action_used(action_id: String) -> void:
	if id == "" or action_id == "":
		return
	GameState.set_flag(_get_special_action_flag(action_id), true)

func _get_special_action_flag(action_id: String) -> String:
	return "interactable_%s_%s_used" % [id, action_id]

func _set_node_enabled_recursive(n: Node, enabled: bool) -> void:
	permanently_disabled = true
	n.set_meta("layer_lock_disabled", true)
	n.visible = false
	
	if n is Area2D:
		var a := n as Area2D
		a.set_deferred("monitoring", enabled)
		a.set_deferred("monitorable", enabled)

	# If you later use StaticBody2D/CollisionObject2D with 'disabled'
	if n is CollisionObject2D:
		var c := n as CollisionObject2D
		c.set_deferred("disabled", not enabled)
	
		# Actual collision shapes (THIS is what you’re missing)
	if n is CollisionShape2D:
		var cs := n as CollisionShape2D
		cs.set_deferred("disabled", not enabled)

	if n is CollisionPolygon2D:
		var cp := n as CollisionPolygon2D
		cp.set_deferred("disabled", not enabled)

	for child in n.get_children():
		_set_node_enabled_recursive(child, enabled)

func _set_node_collisions_enabled_recursive(n: Node, enabled: bool) -> void:
	permanently_disabled = true
	n.set_meta("layer_lock_disabled", true)

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
		_set_node_collisions_enabled_recursive(child, enabled)
