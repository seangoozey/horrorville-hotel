# res://scripts/gameplay/PowerSystem.gd
extends Node

@export var pumps_node: Node
@export var slime_system: Node
@export var outside_sprite: Sprite2D
@export var interior_sprite: Sprite2D
@export var cellar_sprite: Sprite2D
@export var cellar_door_open_sprite: Sprite2D
@export var cellar_dark_door_open_sprite: Sprite2D
@export var outside_texture_grid_on: Texture2D
@export var outside_texture_dark: Texture2D
@export var interior_texture_grid_on: Texture2D
@export var interior_texture_dark: Texture2D
@export var cellar_texture_grid_on: Texture2D
@export var cellar_texture_dark: Texture2D
@export var lights_group_name := "lights"
@export var pumps_running_audio_path: NodePath = NodePath("../World/Pumps/PumpsRunningAudio")
@export var power_grid_on_audio_path: NodePath = NodePath("../World/Cellar/Interactables/Breakers/PowerGridOnAudio")
@export var power_grid_off_audio_path: NodePath = NodePath("../World/Cellar/Interactables/Breakers/PowerGridOffAudio")

@onready var _pumps_running_audio: AudioStreamPlayer2D = _resolve_audio_player(pumps_running_audio_path)
@onready var _power_grid_on_audio: AudioStreamPlayer2D = _resolve_audio_player(power_grid_on_audio_path)
@onready var _power_grid_off_audio: AudioStreamPlayer2D = _resolve_audio_player(power_grid_off_audio_path)

var _has_applied_power := false
var _last_power_mode: int = GameState.PowerMode.GRID_ON

func _ready() -> void:
	_configure_looping_wav(_pumps_running_audio)
	GameState.power_mode_changed.connect(_apply_power)
	GameState.flag_changed.connect(_on_flag_changed)
	_apply_power(GameState.power_mode)

func _apply_power(mode: int) -> void:
	if _has_applied_power:
		_play_power_grid_transition_audio(_last_power_mode, mode)

	# Pumps behavior
	if pumps_node:
		pumps_node.set("enabled", mode == GameState.PowerMode.GRID_ON)
	_update_pumps_audio(mode == GameState.PowerMode.GRID_ON)

	# Lights behavior (optional)
	for n in get_tree().get_nodes_in_group(lights_group_name):
		if n.has_method("set_powered"):
			n.set_powered(mode != GameState.PowerMode.POWER_OFF)

	# Slime behavior
	if slime_system and slime_system.has_method("on_power_mode_changed"):
		slime_system.on_power_mode_changed(mode)

	var grid_on := mode == GameState.PowerMode.GRID_ON
	if outside_sprite:
		outside_sprite.texture = outside_texture_grid_on if grid_on else outside_texture_dark
	if interior_sprite:
		interior_sprite.texture = interior_texture_grid_on if grid_on else interior_texture_dark
	if cellar_sprite:
		cellar_sprite.texture = cellar_texture_grid_on if grid_on else cellar_texture_dark
	_apply_cellar_door_open_art(mode)
	_last_power_mode = mode
	_has_applied_power = true

func _on_flag_changed(flag: String, _value: bool) -> void:
	if flag != "gsa_freed":
		return
	_apply_cellar_door_open_art(GameState.power_mode)

func _apply_cellar_door_open_art(mode: int) -> void:
	var door_open := GameState.get_flag("gsa_freed")
	var grid_on := mode == GameState.PowerMode.GRID_ON
	if cellar_door_open_sprite:
		cellar_door_open_sprite.visible = door_open and grid_on
	if cellar_dark_door_open_sprite:
		cellar_dark_door_open_sprite.visible = door_open and not grid_on

func _resolve_audio_player(path: NodePath) -> AudioStreamPlayer2D:
	if path == NodePath(""):
		return null
	var node: Node = get_node_or_null(path)
	if node is AudioStreamPlayer2D:
		var player: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		player.bus = &"SFX"
		return player
	return null

func _configure_looping_wav(player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	var wav_stream := player.stream as AudioStreamWAV
	if wav_stream == null:
		return
	var total_frames: int = int(max(wav_stream.get_length() * wav_stream.mix_rate, 0.0))
	wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav_stream.loop_begin = 0
	wav_stream.loop_end = total_frames

func _update_pumps_audio(enabled: bool) -> void:
	if _pumps_running_audio == null or _pumps_running_audio.stream == null:
		return
	if enabled:
		if not _pumps_running_audio.playing:
			_pumps_running_audio.play()
	elif _pumps_running_audio.playing:
		_pumps_running_audio.stop()

func _play_power_grid_transition_audio(previous_mode: int, new_mode: int) -> void:
	if previous_mode == new_mode:
		return
	if new_mode == GameState.PowerMode.GRID_ON:
		_play_audio(_power_grid_on_audio)
	elif previous_mode == GameState.PowerMode.GRID_ON:
		_play_audio(_power_grid_off_audio)

func _play_audio(player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
