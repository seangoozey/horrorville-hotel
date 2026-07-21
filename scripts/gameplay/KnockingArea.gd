# res://scripts/gameplay/KnockingArea.gd
extends Area2D

@export var knock_key: String = "knock"
@export var journalist_key: String = "knocking_where"
@export var knock_count: int = 3
@export var knock_spacing: float = 0.25
@export var set_interval: float = 15
@export var bubble_duration: float = 1.0
@export var base_offset: Vector2 = Vector2(0, -24)
@export var random_offset_min_radius: float = 20.0
@export var random_offset_radius: float = 50.0
@export var knock_anchor_path: NodePath = NodePath("DialogueAnchor")
@export var knock_audio_paths: Array[NodePath] = [
	NodePath("Knocks1Audio"),
	NodePath("Knocks2Audio"),
	NodePath("Knocks3Audio"),
]

var _in_area: bool = false
var _running: bool = false
var _set_index: int = 0
var _journalist: CharacterBase = null
var _knock_audio_players: Array[AudioStreamPlayer2D] = []
var _knock_audio_index: int = 0

func _ready() -> void:
	_cache_knock_audio_players()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	var character: CharacterBase = body as CharacterBase
	if character == null:
		return
	var id_value: Variant = character.get("character_id")
	if id_value != "journalist":
		return
	_journalist = character
	_in_area = true
	_start_knocking_loop()

func _on_body_exited(body: Node) -> void:
	var character: CharacterBase = body as CharacterBase
	if character == null:
		return
	var id_value: Variant = character.get("character_id")
	if id_value != "journalist":
		return
	_in_area = false
	if _journalist == character:
		_journalist = null

func _start_knocking_loop() -> void:
	if _running:
		return
	_running = true
	_knocking_loop()

func _knocking_loop() -> void:
	while _in_area and not GameState.get_flag("gsa_discovered"):
		await _play_knock_set()
		if not _in_area or GameState.get_flag("gsa_discovered"):
			break
		var timer: SceneTreeTimer = get_tree().create_timer(set_interval)
		await timer.timeout
	_running = false

func _play_knock_set() -> void:
	_set_index += 1
	_play_next_knock_audio()
	for i in range(knock_count):
		if not _in_area or GameState.get_flag("gsa_discovered"):
			return
		_spawn_knock()
		if i < knock_count - 1:
			var timer: SceneTreeTimer = get_tree().create_timer(knock_spacing)
			await timer.timeout
	if _set_index % 2 == 0 and _journalist:
		_journalist.say(journalist_key, 2.5, base_offset)

func _spawn_knock() -> void:
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if jitter.length_squared() > 0.0:
		jitter = jitter.normalized()
	var min_radius: float = min(random_offset_min_radius, random_offset_radius)
	var max_radius: float = max(random_offset_min_radius, random_offset_radius)
	var offset := base_offset + jitter * randf_range(min_radius, max_radius)
	DialogueManager.show_bubble(_get_knock_anchor(), knock_key, bubble_duration, offset, true, false)

func _get_knock_anchor() -> Node2D:
	var anchor: Node2D = get_node_or_null(knock_anchor_path) as Node2D
	if anchor != null:
		return anchor
	return self

func _cache_knock_audio_players() -> void:
	_knock_audio_players.clear()
	for path in knock_audio_paths:
		var player: AudioStreamPlayer2D = get_node_or_null(path) as AudioStreamPlayer2D
		if player == null:
			continue
		player.bus = &"SFX"
		_knock_audio_players.append(player)

func _play_next_knock_audio() -> void:
	if _knock_audio_players.is_empty():
		return
	var player: AudioStreamPlayer2D = _knock_audio_players[_knock_audio_index]
	_knock_audio_index = (_knock_audio_index + 1) % _knock_audio_players.size()
	if player.stream == null:
		return
	player.stop()
	player.play()
