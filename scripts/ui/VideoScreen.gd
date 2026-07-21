# res://scripts/ui/VideoScreen.gd
extends Control

@export var video_player: VideoPlayback
@export_file("*.mp4") var video_file_path: String = ""
@export_file("*.tscn") var next_scene_path: String = ""
@export var autoplay := true
@export var allow_skip := true
@export var skip_actions: Array[StringName] = [&"ui_accept", &"ui_cancel"]
@export var advance_if_stream_missing := true
@export var exported_video_search_dirs: Array[String] = ["", "video"]

var _advancing := false

func _ready() -> void:
	if video_player == null:
		push_error("VideoScreen: video_player is not configured.")
		return
	if not video_player.video_ended.is_connected(_on_video_finished):
		video_player.video_ended.connect(_on_video_finished)
	if not video_player.video_loaded.is_connected(_on_video_loaded):
		video_player.video_loaded.connect(_on_video_loaded)
	video_player.enable_auto_play = false
	var resolved_video_path: String = _resolve_video_file_path(video_file_path)
	if resolved_video_path == "" or not FileAccess.file_exists(resolved_video_path):
		push_warning("VideoScreen: no playable MP4 configured for %s. Configured: %s Resolved: %s" % [name, video_file_path, resolved_video_path])
		if advance_if_stream_missing:
			_advance()
		return
	video_player.set_video_path(resolved_video_path)
	_configure_video_audio_bus()
	if next_scene_path != "":
		SceneRouter.preload_scene(next_scene_path)

func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip or _advancing:
		return
	for action: StringName in skip_actions:
		if event.is_action_pressed(action):
			_advance()
			get_viewport().set_input_as_handled()
			return

func _on_video_loaded() -> void:
	if autoplay and not _advancing:
		video_player.play()

func _on_video_finished() -> void:
	_advance()

func _resolve_video_file_path(configured_path: String) -> String:
	var clean_path: String = configured_path.strip_edges()
	if clean_path == "":
		return ""
	if clean_path.is_absolute_path():
		var absolute_path: String = _normalize_external_video_path(clean_path)
		if FileAccess.file_exists(absolute_path):
			return absolute_path
	if clean_path.begins_with("res://"):
		if FileAccess.file_exists(clean_path):
			return clean_path
		var globalized_path: String = _normalize_external_video_path(ProjectSettings.globalize_path(clean_path))
		if FileAccess.file_exists(globalized_path):
			return globalized_path
	elif not clean_path.contains("://"):
		var project_video_path: String = "res://data/video/%s" % clean_path
		if FileAccess.file_exists(project_video_path):
			return project_video_path
		var globalized_project_video_path: String = _normalize_external_video_path(ProjectSettings.globalize_path(project_video_path))
		if FileAccess.file_exists(globalized_project_video_path):
			return globalized_project_video_path
	var file_name: String = clean_path.get_file()
	var executable_dir: String = OS.get_executable_path().get_base_dir()
	for search_dir: String in exported_video_search_dirs:
		var candidate_dir: String = executable_dir
		var trimmed_search_dir: String = search_dir.strip_edges()
		if trimmed_search_dir != "":
			candidate_dir = candidate_dir.path_join(trimmed_search_dir)
		var candidate_path: String = _normalize_external_video_path(candidate_dir.path_join(file_name))
		if FileAccess.file_exists(candidate_path):
			return candidate_path
	return _normalize_external_video_path(executable_dir.path_join(file_name))

func _normalize_external_video_path(path: String) -> String:
	return path.replace("\\", "/")

func _configure_video_audio_bus() -> void:
	if video_player == null:
		return
	var player: AudioStreamPlayer = video_player.get("audio_player") as AudioStreamPlayer
	if player == null:
		return
	player.bus = &"Video"

func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	if video_player != null:
		if video_player.is_playing:
			video_player.pause()
		video_player.close()
	if next_scene_path == "":
		push_error("VideoScreen: next_scene_path is not configured.")
		return
	SceneRouter.goto_preloaded_or_scene.call_deferred(next_scene_path)
