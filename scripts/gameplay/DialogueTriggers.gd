# res://scripts/gameplay/DialogueTriggers.gd
extends Node

const GSA_DISCOVERED_DIALOGUE_KEY := "gsa_locked"
const GSA_RIGHT_TOOL_DIALOGUE_KEY := "gsa_right_tool"
const KNOCKING_DIALOGUE_ANCHOR_PATH := NodePath("World/KnockingArea/DialogueAnchor")

func _ready() -> void:
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.active_character_changed.connect(_on_active_character_changed)

func _on_flag_changed(flag: String, value: bool) -> void:
	if not value:
		return
	if flag == "gsa_discovered":
		var gsa: CharacterBase = GameState.get_character("gsa")
		if gsa:
			DialogueManager.show_bubble(_get_gsa_dialogue_anchor(), GSA_DISCOVERED_DIALOGUE_KEY)
		NotesManager.add_note_by_id("trapped_survivor")
	elif flag == "wrench_passed":
		var gsa: CharacterBase = GameState.get_character("gsa")
		if gsa:
			DialogueManager.show_bubble(_get_gsa_dialogue_anchor(), GSA_RIGHT_TOOL_DIALOGUE_KEY)

func _on_active_character_changed(_character_id: String) -> void:
	if not GameState.get_flag("gsa_discovered"):
		return
	DialogueManager.retarget_bubble(
		GSA_DISCOVERED_DIALOGUE_KEY,
		_get_gsa_dialogue_anchor()
	)
	DialogueManager.retarget_bubble(
		GSA_RIGHT_TOOL_DIALOGUE_KEY,
		_get_gsa_dialogue_anchor()
	)

func _get_gsa_dialogue_anchor() -> Node2D:
	var gsa: CharacterBase = GameState.get_character("gsa")
	if GameState.active_character_id == "gsa" and gsa != null:
		return gsa.get_dialogue_anchor()
	var scene: Node = get_tree().current_scene
	if scene != null:
		var knocking_anchor: Node2D = scene.get_node_or_null(KNOCKING_DIALOGUE_ANCHOR_PATH) as Node2D
		if knocking_anchor != null:
			return knocking_anchor
	if gsa != null:
		return gsa.get_dialogue_anchor()
	return null
