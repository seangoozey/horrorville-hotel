# res://scripts/gameplay/GeneratorInteractable.gd
extends Interactable
class_name GeneratorInteractable

@export var generator_sprite_path: NodePath = NodePath("../../Genny/GennySprite")
@export var generator_dark_position := Vector2(1552.27, -1475.18)
@export var generator_lit_position := Vector2(1555.0, -1477.0)
@export_range(0.1, 10.0, 0.1) var generator_start_ramp_seconds := 1.0
@export_range(0.0, 1.0, 0.01) var generator_running_alpha_min := 0.6
@export_range(0.0, 1.0, 0.01) var generator_running_alpha_max := 1.0
@export_range(0.1, 5.0, 0.1) var generator_alpha_wander_min_seconds := 0.8
@export_range(0.1, 5.0, 0.1) var generator_alpha_wander_max_seconds := 1.8
@export var layer_controller_path: NodePath = NodePath("../../..")
@export var generator_effect_layer: LayerController.ViewLayer = LayerController.ViewLayer.CELLAR
@export var generator_start_fail_audio_path: NodePath = NodePath("GennyStartFailAudio")
@export var generator_start_audio_path: NodePath = NodePath("GennyStartAudio")
@export var generator_stop_audio_path: NodePath = NodePath("GennyStopAudio")
@export var generator_run_audio_path: NodePath = NodePath("GennyRunAudio")

var _generator_sprite: Sprite2D
var _layer_controller: LayerController
var _generator_start_fail_audio: AudioStreamPlayer2D
var _generator_start_audio: AudioStreamPlayer2D
var _generator_stop_audio: AudioStreamPlayer2D
var _generator_run_audio: AudioStreamPlayer2D
var _alpha_tween: Tween
var _rng := RandomNumberGenerator.new()
var _alpha_wander_time_left := 0.0
var _starting_generator := false
var _trip_fuse_after_start := false
var _alpha_wander_target_high := false
var _generator_effect_active := true
var _generator_start_audio_pending_run := false
var _generator_run_audio_active := false

func _ready() -> void:
	super._ready()
	_rng.randomize()
	_generator_sprite = get_node_or_null(generator_sprite_path) as Sprite2D
	_layer_controller = get_node_or_null(layer_controller_path) as LayerController
	_generator_start_fail_audio = _resolve_generator_audio_player(generator_start_fail_audio_path)
	_generator_start_audio = _resolve_generator_audio_player(generator_start_audio_path)
	_generator_stop_audio = _resolve_generator_audio_player(generator_stop_audio_path)
	_generator_run_audio = _resolve_generator_audio_player(generator_run_audio_path)
	_configure_looping_wav(_generator_run_audio)
	if _generator_start_audio != null and not _generator_start_audio.finished.is_connected(_on_generator_start_audio_finished):
		_generator_start_audio.finished.connect(_on_generator_start_audio_finished)
	if _layer_controller != null:
		_layer_controller.layer_changed.connect(_on_layer_changed)
		_on_layer_changed(_layer_controller._get_current())
	interacted.connect(_on_interacted)
	special_interacted.connect(_on_special_interacted)
	GameState.power_mode_changed.connect(_on_power_mode_changed)
	GameState.flag_changed.connect(_on_flag_changed)
	_apply_permanent_disabled_state()
	_apply_generator_visual_state(GameState.power_mode, true)

func _process(delta: float) -> void:
	if _starting_generator or _generator_sprite == null:
		return
	if GameState.power_mode != GameState.PowerMode.GENERATOR_ON:
		return
	if _generator_effect_active:
		_alpha_wander_time_left -= delta
		if _alpha_wander_time_left <= 0.0:
			_start_running_alpha_wander()

func _on_interacted(_interactable_id: String) -> void:
	if GameState.get_flag("generator_permanently_disabled"):
		return
	if not GameState.get_flag("generator_fixed"):
		var active := GameState.get_active_character()
		if active == null:
			return
		if GameState.active_character_id == "journalist":
			active.say("journalist_generator_use")
		else:
			active.say("gsa_generator_broken")
		return
	if _starting_generator:
		return
	if GameState.power_mode == GameState.PowerMode.GENERATOR_ON:
		GameState.set_power_mode(GameState.PowerMode.POWER_OFF)
	else:
		_start_generator(GameState.power_mode == GameState.PowerMode.GRID_ON)

func _on_special_interacted(_interactable_id: String, action_id: String, character: CharacterBase) -> void:
	if character == null:
		return
	if GameState.get_flag("generator_permanently_disabled"):
		return
	if action_id == "examine":
		var added_generator := NotesManager.add_note_by_id("derelict_generator")
		if added_generator:
			character.say("journalist_generator_examine")
		return
	if action_id == "fix":
		if GameState.get_flag("generator_fixed"):
			return
		GameState.set_flag("generator_fixed", true)
		character.say("gsa_generator_fixed")

func _start_generator(trip_fuse_after_start: bool) -> void:
	if GameState.get_flag("generator_permanently_disabled"):
		return
	_starting_generator = true
	_trip_fuse_after_start = trip_fuse_after_start
	_generator_start_audio_pending_run = false
	_stop_generator_run_audio(false)
	if _alpha_tween != null:
		_alpha_tween.kill()
	if trip_fuse_after_start:
		_play_generator_audio(_generator_start_fail_audio)
	else:
		_play_generator_start_audio()
	if _generator_sprite == null:
		_finish_generator_start()
		return
	_generator_sprite.position = generator_lit_position if trip_fuse_after_start else generator_dark_position
	_generator_sprite.visible = true
	var modulate_color := _generator_sprite.modulate
	modulate_color.a = 0.0
	_generator_sprite.modulate = modulate_color
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(_generator_sprite, "modulate:a", 1.0, generator_start_ramp_seconds)
	_alpha_tween.finished.connect(_finish_generator_start)

func _finish_generator_start() -> void:
	_starting_generator = false
	if _trip_fuse_after_start:
		var gsa := GameState.get_character("gsa")
		if gsa != null:
			gsa.say("gsa_blew_fuses")
		GameState.set_power_mode(GameState.PowerMode.POWER_OFF)
	else:
		GameState.set_power_mode(GameState.PowerMode.GENERATOR_ON)
		GameState.set_flag("pumps_disabled", true)
		if _generator_sprite != null:
			_generator_sprite.position = generator_dark_position
		if _generator_effect_active:
			_start_running_alpha_wander()
	_trip_fuse_after_start = false

func _on_power_mode_changed(mode: int) -> void:
	if _starting_generator:
		return
	_apply_generator_visual_state(mode, false)

func _on_flag_changed(flag: String, _value: bool) -> void:
	if flag != "generator_permanently_disabled":
		return
	_apply_permanent_disabled_state()

func _apply_permanent_disabled_state() -> void:
	if not GameState.get_flag("generator_permanently_disabled"):
		return
	permanently_disabled = true
	_starting_generator = false
	_trip_fuse_after_start = false
	_generator_start_audio_pending_run = false
	_stop_generator_run_audio(true)
	_stop_running_alpha_wander()
	if GameState.power_mode != GameState.PowerMode.POWER_OFF:
		GameState.set_power_mode(GameState.PowerMode.POWER_OFF)
	_apply_generator_visual_state(GameState.PowerMode.POWER_OFF, true)

func _apply_generator_visual_state(mode: int, instant: bool) -> void:
	if _generator_sprite == null:
		return
	if mode == GameState.PowerMode.GENERATOR_ON:
		_generator_sprite.position = generator_dark_position
		_generator_sprite.visible = true
		_try_start_generator_run_audio()
		if instant:
			var running_color := _generator_sprite.modulate
			running_color.a = generator_running_alpha_max
			_generator_sprite.modulate = running_color
		if _generator_effect_active:
			_start_running_alpha_wander()
		else:
			_stop_running_alpha_wander()
	else:
		_generator_start_audio_pending_run = false
		if _generator_start_audio != null and _generator_start_audio.playing:
			_generator_start_audio.stop()
		_stop_generator_run_audio(true)
		_stop_running_alpha_wander()
		_generator_sprite.position = generator_dark_position
		var off_color := _generator_sprite.modulate
		off_color.a = 0.0
		_generator_sprite.modulate = off_color
		_generator_sprite.visible = false

func _start_running_alpha_wander() -> void:
	if _generator_sprite == null or not _generator_effect_active:
		return
	if _alpha_tween != null:
		_alpha_tween.kill()
	var min_alpha: float = min(generator_running_alpha_min, generator_running_alpha_max)
	var max_alpha: float = max(generator_running_alpha_min, generator_running_alpha_max)
	var alpha_range := max_alpha - min_alpha
	var target_alpha := max_alpha
	if alpha_range > 0.0:
		_alpha_wander_target_high = not _alpha_wander_target_high
		if _alpha_wander_target_high:
			target_alpha = _rng.randf_range(max_alpha - alpha_range * 0.25, max_alpha)
		else:
			target_alpha = _rng.randf_range(min_alpha, min_alpha + alpha_range * 0.25)
	var min_seconds: float = min(generator_alpha_wander_min_seconds, generator_alpha_wander_max_seconds)
	var max_seconds: float = max(generator_alpha_wander_min_seconds, generator_alpha_wander_max_seconds)
	var duration := _rng.randf_range(min_seconds, max_seconds)
	_alpha_wander_time_left = duration
	_alpha_tween = create_tween()
	_alpha_tween.set_trans(Tween.TRANS_SINE)
	_alpha_tween.set_ease(Tween.EASE_IN_OUT)
	_alpha_tween.tween_property(_generator_sprite, "modulate:a", target_alpha, duration)

func _stop_running_alpha_wander() -> void:
	if _alpha_tween != null:
		_alpha_tween.kill()
	_alpha_wander_time_left = 0.0

func _on_layer_changed(active_layer: LayerController.ViewLayer) -> void:
	var next_generator_active := active_layer == generator_effect_layer
	if _generator_effect_active == next_generator_active:
		return
	_generator_effect_active = next_generator_active
	if GameState.power_mode != GameState.PowerMode.GENERATOR_ON or _starting_generator:
		return
	if _generator_effect_active:
		_start_running_alpha_wander()
	else:
		_stop_running_alpha_wander()

func _resolve_generator_audio_player(path: NodePath) -> AudioStreamPlayer2D:
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

func _play_generator_start_audio() -> void:
	if _generator_start_audio == null or _generator_start_audio.stream == null:
		_start_generator_run_audio()
		return
	_generator_start_audio_pending_run = true
	_play_generator_audio(_generator_start_audio)

func _on_generator_start_audio_finished() -> void:
	if not _generator_start_audio_pending_run:
		return
	_generator_start_audio_pending_run = false
	if _trip_fuse_after_start:
		return
	if _starting_generator or GameState.power_mode == GameState.PowerMode.GENERATOR_ON:
		_start_generator_run_audio()

func _try_start_generator_run_audio() -> void:
	if GameState.power_mode != GameState.PowerMode.GENERATOR_ON:
		return
	if _generator_start_audio_pending_run:
		if _generator_start_audio != null and _generator_start_audio.playing:
			return
		_generator_start_audio_pending_run = false
	_start_generator_run_audio()

func _start_generator_run_audio() -> void:
	if _generator_run_audio == null or _generator_run_audio.stream == null:
		_generator_run_audio_active = false
		return
	if _generator_run_audio.playing:
		_generator_run_audio_active = true
		return
	_generator_run_audio_active = true
	_generator_run_audio.play()

func _stop_generator_run_audio(play_stop: bool) -> void:
	var was_running: bool = _generator_run_audio_active or (_generator_run_audio != null and _generator_run_audio.playing)
	_generator_run_audio_active = false
	if _generator_run_audio != null and _generator_run_audio.playing:
		_generator_run_audio.stop()
	if play_stop and was_running:
		_play_generator_audio(_generator_stop_audio)

func _play_generator_audio(player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
