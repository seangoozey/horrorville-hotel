# res://scripts/gameplay/MusicManager.gd
extends Node

const MIN_VOLUME_DB: float = -80.0
const TRACKS: Array[AudioStream] = [
	preload("res://data/audio/music/song1.ogg"),
	preload("res://data/audio/music/song2.ogg"),
	preload("res://data/audio/music/song3.ogg"),
	preload("res://data/audio/music/song4.ogg"),
	preload("res://data/audio/music/song5.ogg"),
	preload("res://data/audio/music/song6.ogg"),
	preload("res://data/audio/music/song7.ogg"),
]

@export var play_on_ready: bool = true
@export_range(0.0, 1.0, 0.01) var music_volume: float = 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

var _player: AudioStreamPlayer = null
var _track_bag: Array[int] = []
var _last_track_index: int = -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = &"Music"
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	_apply_volume()
	if play_on_ready:
		play_random_track()

func play_random_track() -> void:
	if TRACKS.is_empty() or _player == null:
		return
	var track_index: int = _pop_next_track_index()
	var track: AudioStream = TRACKS[track_index]
	_configure_non_looping_stream(track)
	_last_track_index = track_index
	_player.stream = track
	_player.play()

func stop_music() -> void:
	if _player != null:
		_player.stop()

func set_music_volume(value: float) -> void:
	music_volume = value

func _on_player_finished() -> void:
	play_random_track()

func _pop_next_track_index() -> int:
	if _track_bag.is_empty():
		_refill_track_bag()
	var track_index: int = _track_bag.pop_back()
	if TRACKS.size() > 1 and track_index == _last_track_index:
		if _track_bag.is_empty():
			_refill_track_bag()
		var swap_index: int = _track_bag.pop_back()
		_track_bag.push_back(track_index)
		track_index = swap_index
	return track_index

func _refill_track_bag() -> void:
	_track_bag.clear()
	for index: int in TRACKS.size():
		_track_bag.append(index)
	_track_bag.shuffle()

func _configure_non_looping_stream(track: AudioStream) -> void:
	var ogg_stream := track as AudioStreamOggVorbis
	if ogg_stream != null:
		ogg_stream.loop = false

func _apply_volume() -> void:
	if _player == null:
		return
	if music_volume <= 0.0:
		_player.volume_db = MIN_VOLUME_DB
	else:
		_player.volume_db = linear_to_db(music_volume)
