# res://scripts/gameplay/AmbienceAudio.gd
extends AudioStreamPlayer

@export var layer_controller_path: NodePath = NodePath("../World")
@export var active_layer: LayerController.ViewLayer = LayerController.ViewLayer.EXTERIOR

var _layer_controller: LayerController = null

func _ready() -> void:
	bus = &"SFX"
	_configure_looping_stream()
	_layer_controller = get_node_or_null(layer_controller_path) as LayerController
	if _layer_controller != null:
		_layer_controller.layer_changed.connect(_on_layer_changed)
		_on_layer_changed(_layer_controller._get_current())
		return
	_update_playback(true)

func _on_layer_changed(layer: LayerController.ViewLayer) -> void:
	_update_playback(layer == active_layer)

func _update_playback(should_play: bool) -> void:
	if stream == null:
		return
	if should_play:
		if not playing:
			play()
	elif playing:
		stop()

func _configure_looping_stream() -> void:
	if stream == null:
		return
	var ogg_stream := stream as AudioStreamOggVorbis
	if ogg_stream != null:
		ogg_stream.loop = true
