# res://scripts/gameplay/Inventory.gd
extends Node

signal item_changed(item_id: String, has_item: bool)

const PICKUP_AUDIO_STREAM: AudioStream = preload("res://data/audio/sfx/ui_pickup.wav")

var items := {}  # item_id -> bool
var _pickup_audio: AudioStreamPlayer = null

func _ready() -> void:
	_pickup_audio = AudioStreamPlayer.new()
	_pickup_audio.name = "PickupAudio"
	_pickup_audio.stream = PICKUP_AUDIO_STREAM
	_pickup_audio.bus = &"SFX"
	add_child(_pickup_audio)

func reset_runtime_state() -> void:
	items.clear()

func has(item_id: String) -> bool:
	return items.get(item_id, false)

func give(item_id: String, play_pickup_audio: bool = true) -> void:
	if items.get(item_id, false):
		return
	items[item_id] = true
	item_changed.emit(item_id, true)
	if play_pickup_audio and _pickup_audio != null:
		_pickup_audio.stop()
		_pickup_audio.play()

func take(item_id: String) -> void:
	if not items.get(item_id, false):
		return
	items[item_id] = false
	item_changed.emit(item_id, false)
