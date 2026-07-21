# res://scripts/gameplay/PumpsArea.gd
extends NoteInteractable

@export var dialogue_key: String = "journalist_pumps"
@export var target_character_id: String = "journalist"
@export var bubble_offset: Vector2 = Vector2(0, -24)
@export var bubble_duration: float = 2.5

var _triggered: bool = false

func _ready() -> void:
	super._ready()
	body_entered.connect(_on_pumps_body_entered)

func _on_pumps_body_entered(body: Node) -> void:
	if _triggered:
		return
	var character: CharacterBase = body as CharacterBase
	if character == null:
		return
	var id_value: Variant = character.get("character_id")
	if id_value != target_character_id:
		return
	_triggered = true
	character.say(dialogue_key, bubble_duration, bubble_offset)
