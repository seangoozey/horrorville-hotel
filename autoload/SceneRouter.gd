# res://autoload/SceneRouter.gd
# Purpose: Route scene changes by path.
extends Node

const VICTORY_OUTRO_DELAY_SECONDS := 3.0
const PRELOAD_POLL_INTERVAL_SECONDS := 0.05

var _preload_requests: Dictionary = {}

func goto_scene(path: String) -> void:
	if path == "":
		push_error("SceneRouter: scene path is empty.")
		return

	var packed_scene: PackedScene = _take_preloaded_scene(path)
	if packed_scene != null:
		_change_scene_to_packed(path, packed_scene)
		return
	_change_scene_to_file(path)

func preload_scene(path: String) -> void:
	if path == "":
		return
	if _preload_requests.has(path):
		return
	var error: Error = ResourceLoader.load_threaded_request(path)
	if error != OK and error != ERR_BUSY:
		push_warning("SceneRouter: failed to start threaded preload for %s. Error: %s" % [path, error])
		return
	_preload_requests[path] = true

func goto_preloaded_or_scene(path: String) -> void:
	if path == "":
		push_error("SceneRouter: scene path is empty.")
		return
	var packed_scene: PackedScene = await wait_for_preloaded_scene(path)
	if packed_scene != null:
		_change_scene_to_packed(path, packed_scene)
		return
	_change_scene_to_file(path)

func wait_for_preloaded_scene(path: String) -> PackedScene:
	if path == "":
		return null
	preload_scene(path)
	while _preload_requests.has(path):
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_preload_requests.erase(path)
				var resource: Resource = ResourceLoader.load_threaded_get(path)
				return resource as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_preload_requests.erase(path)
				push_warning("SceneRouter: threaded preload failed for %s. Status: %s" % [path, status])
				return null
		await get_tree().create_timer(PRELOAD_POLL_INTERVAL_SECONDS).timeout
	var cached_resource: Resource = ResourceLoader.load(path)
	return cached_resource as PackedScene

func _take_preloaded_scene(path: String) -> PackedScene:
	if not _preload_requests.has(path):
		return null
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	_preload_requests.erase(path)
	var resource: Resource = ResourceLoader.load_threaded_get(path)
	return resource as PackedScene

func _change_scene_to_file(path: String) -> void:
	if GameState.is_paused:
		GameState.set_paused(false)
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneRouter: failed to change scene to %s. Error: %s" % [path, error])
		return

func _change_scene_to_packed(path: String, packed_scene: PackedScene) -> void:
	if GameState.is_paused:
		GameState.set_paused(false)
	var error: Error = get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("SceneRouter: failed to change to preloaded scene %s. Error: %s" % [path, error])
		return

func complete_victory_with_outro(outro_scene_path: String) -> void:
	if outro_scene_path == "":
		await get_tree().create_timer(VICTORY_OUTRO_DELAY_SECONDS).timeout
		GameState.set_paused(true, GameState.PauseReason.WIN)
		return
	preload_scene(outro_scene_path)
	var delay_timer: SceneTreeTimer = get_tree().create_timer(VICTORY_OUTRO_DELAY_SECONDS)
	var packed_scene: PackedScene = await wait_for_preloaded_scene(outro_scene_path)
	await delay_timer.timeout
	if packed_scene != null:
		_change_scene_to_packed(outro_scene_path, packed_scene)
		return
	_change_scene_to_file(outro_scene_path)
