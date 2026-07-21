# res://scripts/gameplay/NoteInteractable.gd
extends Interactable
class_name NoteInteractable

@export var note_id: String = ""
@export var dialogue_id: String = ""
@export var trigger_on_interact: bool = false

func _ready() -> void:
	super._ready()
	if trigger_on_interact:
		interacted.connect(_on_interacted)
	special_interacted.connect(_on_special_interacted)

func _on_interacted(_interactable_id: String) -> void:
	_try_add_note(GameState.get_active_character())

func _on_special_interacted(_interactable_id: String, _action_id: String, character: CharacterBase) -> void:
	_try_add_note(character)

func _try_add_note(character: CharacterBase) -> void:
	if note_id == "":
		return
	var added := NotesManager.add_note_by_id(note_id)
	if not added:
		return
	if dialogue_id == "":
		return
	var speaker := character if character != null else GameState.get_active_character()
	if speaker:
		speaker.say(dialogue_id)
