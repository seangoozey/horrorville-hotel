# res://scripts/gameplay/FlickerLight.gd
extends Sprite2D

# If true, start with the light-off overlay visible.
@export var start_visible: bool = true
@export_range(0.0, 1.0, 0.01) var off_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01) var on_alpha: float = 0.0
# Time range (seconds) to keep the light-off overlay visible.
@export var min_light_off_time: float = 0.35
@export var max_light_off_time: float = 2.1
# Time range (seconds) to keep the light-on state visible (overlay hidden).
@export var min_light_on_time: float = 0.03
@export var max_light_on_time: float = 0.14
# Chance to do a rapid burst of toggles after an off interval.
@export_range(0.0, 1.0, 0.01) var burst_chance: float = 0.45
# Number of toggles inside one burst.
@export var burst_toggles_min: int = 2
@export var burst_toggles_max: int = 6
# Per-toggle delay range (seconds) during a burst.
@export var burst_toggle_min: float = 0.02
@export var burst_toggle_max: float = 0.09
@export var layer_controller_path: NodePath = NodePath("../..")
@export var effect_layer: LayerController.ViewLayer = LayerController.ViewLayer.INTERIOR
@export var flicker_on_audio_path: NodePath = NodePath("LightFlickerOnAudio")
@export var flicker_off_audio_path: NodePath = NodePath("LightFlickerOffAudio")

# RNG instance for flicker timing and burst behavior.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Loop guard to stop async flicker work when node exits.
var _running: bool = true
var _flicker_enabled: bool = false
var _layer_active: bool = true
var _layer_controller: LayerController = null
@onready var _flicker_on_audio: AudioStreamPlayer2D = _resolve_audio_player(flicker_on_audio_path)
@onready var _flicker_off_audio: AudioStreamPlayer2D = _resolve_audio_player(flicker_off_audio_path)

func _ready() -> void:
	_rng.randomize()
	_layer_controller = get_node_or_null(layer_controller_path) as LayerController
	if _layer_controller != null:
		_layer_controller.layer_changed.connect(_on_layer_changed)
		_on_layer_changed(_layer_controller._get_current())
	GameState.power_mode_changed.connect(_on_power_mode_changed)
	_on_power_mode_changed(GameState.power_mode)
	_flicker_loop()

func _exit_tree() -> void:
	_running = false

func _flicker_loop() -> void:
	while _running and is_inside_tree():
		if not _flicker_enabled:
			_set_light_off_visible(false)
			await get_tree().create_timer(0.1).timeout
			continue
		if visible:
			await _wait_random(min_light_off_time, max_light_off_time)
			if not _running:
				return
			if _rng.randf() < burst_chance:
				await _run_burst()
			else:
				_set_light_off_visible(false)
		else:
			await _wait_random(min_light_on_time, max_light_on_time)
			if not _running:
				return
			_set_light_off_visible(true)

func _run_burst() -> void:
	var burst_toggles: int = _rng.randi_range(burst_toggles_min, burst_toggles_max)
	for _i: int in range(burst_toggles):
		_set_light_off_visible(not visible)
		await _wait_random(burst_toggle_min, burst_toggle_max)
		if not _running:
			return
	if not visible:
		_set_light_off_visible(true)

func _wait_random(min_time: float, max_time: float) -> void:
	var duration: float = maxf(0.001, _rng.randf_range(min_time, max_time))
	await get_tree().create_timer(duration).timeout

func _set_light_off_visible(light_off_visible: bool) -> void:
	var changed: bool = visible != light_off_visible
	visible = light_off_visible
	var target_alpha: float = off_alpha if light_off_visible else on_alpha
	modulate = Color(modulate.r, modulate.g, modulate.b, clampf(target_alpha, 0.0, 1.0))
	if changed and _flicker_enabled:
		if light_off_visible:
			_play_audio(_flicker_off_audio)
		else:
			_play_audio(_flicker_on_audio)

func _on_power_mode_changed(mode: int) -> void:
	_flicker_enabled = mode == GameState.PowerMode.GRID_ON and _layer_active
	if _flicker_enabled:
		_set_light_off_visible(start_visible)
	else:
		_set_light_off_visible(false)

func _on_layer_changed(active_layer: LayerController.ViewLayer) -> void:
	_layer_active = active_layer == effect_layer
	_on_power_mode_changed(GameState.power_mode)

func _resolve_audio_player(path: NodePath) -> AudioStreamPlayer2D:
	if path == NodePath(""):
		return null
	var node: Node = get_node_or_null(path)
	if node is AudioStreamPlayer2D:
		var player: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		player.bus = &"SFX"
		return player
	return null

func _play_audio(player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
