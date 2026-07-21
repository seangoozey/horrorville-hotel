# res://scripts/ui/TextBubble.gd
class_name TextBubble
extends Node2D

signal finished

@export var panel: PanelContainer
@export var label: Label
@export var max_width := 200.0
@export var fade_in_time := 0.2
@export var fade_out_time := 1.0

var _target: Node2D = null
var _offset: Vector2 = Vector2.ZERO
var _duration: float = 2.5
var _elapsed: float = 0.0
var _pending_text: String = ""
var _done: bool = false

func _ready() -> void:
	if label == null:
		label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		add_child(label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_END
	if label.label_settings == null:
		var settings: LabelSettings = load("res://data/res/StaticLabelWhite.tres") as LabelSettings
		if settings:
			label.label_settings = settings
	if _pending_text != "":
		label.text = _pending_text
	call_deferred("_update_bubble_layout")
	modulate.a = 0.0

func setup(target: Node2D, text: String, duration: float, offset: Vector2) -> void:
	_target = target
	_offset = offset
	_duration = duration
	_pending_text = text
	if label:
		label.text = text
		call_deferred("_update_bubble_layout")

func set_target(target: Node2D, offset: Vector2 = Vector2.ZERO) -> void:
	_target = target
	_offset = offset

func _process(delta: float) -> void:
	if _target:
		var desired := _target.global_position + _offset
		global_position = _clamp_to_camera_view(desired)
	_elapsed += delta
	_update_fade()
	if not _done and _duration > 0.0 and _elapsed >= _duration:
		_done = true
		finished.emit()
		queue_free()

func _update_fade() -> void:
	var alpha: float = 1.0
	if fade_in_time > 0.0 and _elapsed < fade_in_time:
		alpha = _elapsed / fade_in_time
	elif _duration > 0.0 and fade_out_time > 0.0 and _elapsed > _duration - fade_out_time:
		alpha = max(0.0, (_duration - _elapsed) / fade_out_time)
	modulate.a = clamp(alpha, 0.0, 1.0)

func _update_bubble_layout() -> void:
	if panel == null:
		if label != null:
			label.position.y = -label.size.y
		return
	if label != null:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size = Vector2.ZERO
		label.reset_size()
		var natural_width: float = label.get_combined_minimum_size().x
		var target_width: float = natural_width
		if max_width > 0.0:
			target_width = minf(natural_width, max_width)
		if natural_width > target_width:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = target_width
			label.size.x = target_width
	panel.reset_size()
	call_deferred("_finalize_bubble_layout")

func _finalize_bubble_layout() -> void:
	if panel == null:
		return
	panel.reset_size()
	panel.position = Vector2(0.0, -panel.size.y)

func _clamp_to_camera_view(desired: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return desired
	var camera := vp.get_camera_2d()
	if camera == null:
		return desired

	var safe_zoom := Vector2(
		camera.zoom.x if abs(camera.zoom.x) > 0.0001 else 1.0,
		camera.zoom.y if abs(camera.zoom.y) > 0.0001 else 1.0
	)
	var half_view := (vp.get_visible_rect().size * 0.5) / safe_zoom
	var center := camera.get_screen_center_position()
	var view_rect := Rect2(center - half_view, half_view * 2.0)

	var bubble_width: float = 0.0
	var bubble_height: float = 0.0
	if panel:
		bubble_width = panel.size.x
		bubble_height = panel.size.y
	elif label:
		bubble_width = maxf(label.size.x, label.custom_minimum_size.x)
		bubble_height = label.size.y

	var clamped := desired
	var min_x := view_rect.position.x
	var max_x := view_rect.position.x + view_rect.size.x - bubble_width
	var min_y := view_rect.position.y + bubble_height
	var max_y := view_rect.position.y + view_rect.size.y

	if min_x > max_x:
		clamped.x = view_rect.position.x + view_rect.size.x * 0.5 - bubble_width * 0.5
	else:
		clamped.x = clamp(clamped.x, min_x, max_x)

	if min_y > max_y:
		clamped.y = view_rect.position.y + view_rect.size.y * 0.5
	else:
		clamped.y = clamp(clamped.y, min_y, max_y)

	return clamped
