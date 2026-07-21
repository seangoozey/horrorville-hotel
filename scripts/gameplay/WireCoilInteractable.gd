# res://scripts/gameplay/WireCoilInteractable.gd
extends Interactable
class_name WireCoilInteractable

@export var item_id: String = "Coil of Copper Wire"
@export var note_id: String = "wire_coil"
@export var wire_coil_sprite_path: NodePath = NodePath("WireCoilSprite")
@export_range(0.0, 1.0, 0.01) var pulse_value_min := 0.7
@export_range(0.0, 1.0, 0.01) var pulse_value_max := 0.9
@export_range(0.1, 10.0, 0.1) var pulse_half_cycle_seconds := 1.5

var _wire_coil_sprite: Sprite2D = null
var _pulse_tween: Tween = null
var _picked_up := false
var _pulse_hue := 0.0
var _pulse_saturation := 0.0

func _ready() -> void:
	super._ready()
	_wire_coil_sprite = get_node_or_null(wire_coil_sprite_path) as Sprite2D
	interacted.connect(_on_interacted)
	GameState.flag_changed.connect(_on_flag_changed)
	_refresh_sprite_state()

func _on_interacted(_interactable_id: String) -> void:
	if item_id == "":
		return
	Inventory.give(item_id)
	if note_id != "":
		NotesManager.add_note_by_id(note_id)
	_picked_up = true
	_stop_sprite_pulse()
	if _wire_coil_sprite != null:
		_wire_coil_sprite.visible = false
	_set_node_enabled_recursive(self, false)

func _on_flag_changed(flag: String, _value: bool) -> void:
	if flag == "slime_trap_plan":
		_refresh_sprite_state()

func _refresh_sprite_state() -> void:
	if _wire_coil_sprite == null:
		return
	var available: bool = GameState.get_flag("slime_trap_plan") and not _picked_up
	_wire_coil_sprite.visible = available
	if available:
		_start_sprite_pulse()
	else:
		_stop_sprite_pulse()

func _start_sprite_pulse() -> void:
	if _wire_coil_sprite == null or _pulse_tween != null:
		return
	var minimum_value: float = minf(pulse_value_min, pulse_value_max)
	var maximum_value: float = maxf(pulse_value_min, pulse_value_max)
	_pulse_hue = _wire_coil_sprite.modulate.h
	_pulse_saturation = _wire_coil_sprite.modulate.s
	_set_sprite_value(minimum_value)
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(_set_sprite_value, minimum_value, maximum_value, pulse_half_cycle_seconds)
	_pulse_tween.tween_method(_set_sprite_value, maximum_value, minimum_value, pulse_half_cycle_seconds)

func _stop_sprite_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if _wire_coil_sprite != null:
		_wire_coil_sprite.modulate.a = 1.0

func _set_sprite_value(value: float) -> void:
	if _wire_coil_sprite == null:
		return
	_wire_coil_sprite.modulate = Color.from_hsv(
		_pulse_hue,
		_pulse_saturation,
		clampf(value, 0.0, 1.0),
		1.0
	)
