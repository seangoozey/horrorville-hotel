# res://scripts/gameplay/CharacterAudio.gd
extends Node
class_name CharacterAudio

const DAMAGE_AUDIO_NAMES: Array[StringName] = [
	&"Damage1Audio",
	&"Damage2Audio",
	&"Damage3Audio",
	&"Damage4Audio",
]

@export var walk_audio_path: NodePath = NodePath("../WalkAudio")
@export var debug_enabled := false

@onready var _walk_audio: AudioStreamPlayer = _resolve_audio_player(walk_audio_path)

var _walking := false

func _ready() -> void:
	_configure_looping_wav(_walk_audio, "WalkAudio")
	if _walk_audio != null:
		_walking = _walk_audio.playing
	var character: CharacterBase = get_parent() as CharacterBase
	if character != null:
		character.damaged.connect(_on_character_damaged)

func set_walking(is_walking: bool, reason: String = "") -> void:
	if _walk_audio == null:
		_debug("walk request ignored: missing WalkAudio is_walking=%s reason=%s" % [is_walking, reason])
		return
	if _walking == is_walking:
		return
	_walking = is_walking
	if is_walking:
		_debug("walk play reason=%s before_playing=%s position=%.3f" % [reason, _walk_audio.playing, _walk_audio.get_playback_position()])
		_walk_audio.play()
		_debug("walk play issued after_playing=%s position=%.3f" % [_walk_audio.playing, _walk_audio.get_playback_position()])
	else:
		_debug("walk stop reason=%s before_playing=%s position=%.3f" % [reason, _walk_audio.playing, _walk_audio.get_playback_position()])
		if _walk_audio.playing:
			_walk_audio.stop()
		_debug("walk stop issued after_playing=%s position=%.3f" % [_walk_audio.playing, _walk_audio.get_playback_position()])

func stop_all(reason: String = "") -> void:
	set_walking(false, reason)

func play_sound(player_name: StringName, restart: bool = true, play_while_paused: bool = false) -> void:
	var player: AudioStreamPlayer = _resolve_sibling_audio_player(player_name)
	if player == null:
		_debug("sound request ignored: missing %s" % [player_name])
		return
	_validate_audio_bus(player, str(player_name))
	if play_while_paused:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	if restart or not player.playing:
		player.play()

func stop_sound(player_name: StringName) -> void:
	var player: AudioStreamPlayer = _resolve_sibling_audio_player(player_name)
	if player != null and player.playing:
		player.stop()

func play_random_damage_sound() -> void:
	var available_players: Array[AudioStreamPlayer] = []
	for player_name: StringName in DAMAGE_AUDIO_NAMES:
		var player: AudioStreamPlayer = _resolve_sibling_audio_player(player_name)
		if player != null and player.stream != null:
			available_players.append(player)
	if available_players.is_empty():
		_debug("damage sound request ignored: no Damage*Audio streams configured")
		return

	for player: AudioStreamPlayer in available_players:
		if player.playing:
			player.stop()
	var selected_index: int = randi_range(0, available_players.size() - 1)
	var selected_player: AudioStreamPlayer = available_players[selected_index]
	_validate_audio_bus(selected_player, selected_player.name)
	selected_player.play()

func _on_character_damaged(_amount: int) -> void:
	play_random_damage_sound()

func _resolve_audio_player(path: NodePath) -> AudioStreamPlayer:
	if path == NodePath(""):
		return null
	var node: Node = get_node_or_null(path)
	if node is AudioStreamPlayer:
		return node as AudioStreamPlayer
	return null

func _resolve_sibling_audio_player(player_name: StringName) -> AudioStreamPlayer:
	if String(player_name) == "":
		return null
	var child_player: AudioStreamPlayer = _resolve_audio_player(NodePath(String(player_name)))
	if child_player != null:
		return child_player
	return _resolve_audio_player(NodePath("../%s" % [player_name]))

func _configure_looping_wav(player: AudioStreamPlayer, label: String) -> void:
	if player == null or player.stream == null:
		push_warning("%s has no %s stream configured." % [owner.name if owner != null else name, label])
		_debug("configure failed: missing %s or stream" % [label])
		return
	_validate_audio_bus(player, label)
	var wav_stream := player.stream as AudioStreamWAV
	if wav_stream == null:
		_debug("configure: %s stream is %s, not AudioStreamWAV" % [label, player.stream.get_class()])
		return
	var total_frames: int = int(max(wav_stream.get_length() * wav_stream.mix_rate, 0.0))
	wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav_stream.loop_begin = 0
	wav_stream.loop_end = total_frames
	_debug("configured %s stream=%s bus=%s playing=%s loop_begin=%s loop_end=%s length=%.3f mix_rate=%s" % [label, player.stream.resource_path, player.bus, player.playing, wav_stream.loop_begin, wav_stream.loop_end, wav_stream.get_length(), wav_stream.mix_rate])

func _validate_audio_bus(player: AudioStreamPlayer, label: String) -> void:
	if AudioServer.get_bus_index(player.bus) != -1:
		return
	push_warning("%s %s bus '%s' was not found; falling back to Master." % [owner.name if owner != null else name, label, player.bus])
	player.bus = &"Master"

func _debug(message: String) -> void:
	if not debug_enabled:
		return
	print("[CharacterAudio:%s:%d] %s" % [owner.name if owner != null else name, Time.get_ticks_msec(), message])
