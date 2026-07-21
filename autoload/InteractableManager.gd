# res://autoload/InteractableManager.gd
# Purpose: Handle special-action fallback when no interactable can respond, including no-action dialogue.
extends Node

var _pending_no_action: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputRouter.special_action_requested.connect(_on_special_action_requested)

func reset_runtime_state() -> void:
	_pending_no_action.clear()

func _on_special_action_requested() -> void:
	if _has_special_interactable_in_range():
		return
	var character := GameState.get_active_character()
	if character == null:
		return
	if _pending_no_action.get(character.character_id, false):
		return
	if character.is_special_action_active() or character.special_action_id == "":
		return
	_pending_no_action[character.character_id] = true
	_connect_special_action_signals(character)
	character.start_special_action(false)

func _on_special_action_completed(_action_id: String, was_effective: bool, character: CharacterBase) -> void:
	if character == null:
		return
	if not _pending_no_action.get(character.character_id, false):
		return
	_disconnect_special_action_canceled(character)
	_pending_no_action.erase(character.character_id)
	if was_effective:
		return
	if character.character_id == "journalist":
		character.say("journalist_no_action")
	else:
		character.say("gsa_no_action")

func _on_special_action_canceled(_action_id: String, character: CharacterBase) -> void:
	if character == null:
		return
	_disconnect_special_action_completed(character)
	_pending_no_action.erase(character.character_id)

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

func _has_special_interactable_in_range() -> bool:
	var nodes := get_tree().get_nodes_in_group("interactables")
	for node in nodes:
		var interactable := node as Interactable
		if interactable == null:
			continue
		if not interactable.is_active_in_range():
			continue
		if interactable.can_handle_special_action():
			return true
	return false
