# res://scripts/gameplay/GasStationPuzzle.gd
extends Node

@export var hint_label: Label
@export var debug_label: Label

@export var wrench: Area2D
@export var window: Area2D
@export var breakers: Area2D
@export var door_latch: Area2D
@export var generator: Area2D

# require slime blob distance > threshold
@export var slime_blob: ColorRect
@export var wrench_safe_distance := 90.0

func _ready() -> void:
	# connect interactables
	(wrench as Area2D).interacted.connect(_on_interacted)
	(window as Area2D).interacted.connect(_on_interacted)
	(breakers as Area2D).interacted.connect(_on_interacted)
	(door_latch as Area2D).interacted.connect(_on_interacted)
	(generator as Area2D).interacted.connect(_on_interacted)

	GameState.power_mode_changed.connect(_refresh_ui)
	GameState.flag_changed.connect(func(_f,_v): _refresh_ui())
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("switch_character"):
		return

	# Gate switching until GSA is discovered
	if not GameState.get_flag("gsa_discovered"):
		return

	if GameState.active_character_id == "journalist":
		GameState.set_active_character("gsa")
	else:
		GameState.set_active_character("journalist")

func _on_interacted(id: String) -> void:
	match id:
		"window":
			# Discover GSA
			if not GameState.get_flag("gsa_discovered"):
				GameState.set_flag("gsa_discovered", true)
			# window is also where you pass the wrench later
			if Inventory.has("wrench") and not GameState.get_flag("wrench_passed"):
				# Require the slime to be "contained" (grid on) OR power off - you decide.
				# For now: allow anytime after wrench is acquired.
				Inventory.take("wrench")
				GameState.set_flag("wrench_passed", true)

		"breakers":
			# GSA only (set allowed_character on interactable)
			# Toggle between GRID_ON and POWER_OFF; generator mode is separate.
			if GameState.power_mode == GameState.PowerMode.GRID_ON:
				GameState.set_power_mode(GameState.PowerMode.POWER_OFF)
			elif GameState.power_mode == GameState.PowerMode.POWER_OFF:
				GameState.set_power_mode(GameState.PowerMode.GRID_ON)
			elif GameState.power_mode == GameState.PowerMode.GENERATOR_ON:
				# If generator is running, breakers still represent "grid" state.
				# For MVP: disallow toggling while generator on.
				pass

		"wrench":
			# Journalist only (set allowed_character on interactable)
			if slime_blob and slime_blob.global_position.distance_to(wrench.global_position) < wrench_safe_distance:
				return

			# The wrench is only safe to pick up if power is off (so slime can be lured away).
			if GameState.power_mode != GameState.PowerMode.POWER_OFF:
				# can't pick up while contained/active
				return
			if GameState.get_flag("wrench_found"):
				return
			Inventory.give("wrench")
			GameState.set_flag("wrench_found", true)

		"door_latch":
			# GSA only; requires wrench_passed
			if not GameState.get_flag("wrench_passed"):
				return
			if GameState.get_flag("gsa_freed"):
				return
			GameState.set_flag("gsa_freed", true)

		"generator":
			# GSA only; generator should only be started after GSA freed
			if not GameState.get_flag("gsa_freed"):
				return
			# Final configuration you want: pumps off, slime dead.
			# We'll enforce: must cut grid power first, then start generator.
			if GameState.power_mode != GameState.PowerMode.POWER_OFF:
				return
			GameState.set_power_mode(GameState.PowerMode.GENERATOR_ON)
			# In MVP, we can mark slime dead after a short delay; see SlimeSystem
			# Pumps disabled flag could be set once generator on and grid off
			GameState.set_flag("pumps_disabled", true)

func _refresh_ui(_new_mode:int=0) -> void:
	if hint_label:
		hint_label.text = _get_hint_text()
	if debug_label:
		debug_label.text = "Char: %s | Power: %s | flags: %s" % [
			GameState.active_character_id,
			_power_name(GameState.power_mode),
			str(GameState.flags)
		]

func _power_name(m: int) -> String:
	match m:
		GameState.PowerMode.GRID_ON: return "GRID_ON"
		GameState.PowerMode.POWER_OFF: return "POWER_OFF"
		GameState.PowerMode.GENERATOR_ON: return "GENERATOR_ON"
	return "?"

func _get_hint_text() -> String:
	if not GameState.get_flag("gsa_discovered"):
		return "Find the source of the banging."
	if not GameState.get_flag("wrench_found"):
		return "Cut power, lure the slime away, grab the wrench."
	if not GameState.get_flag("wrench_passed"):
		return "Bring the wrench to the window."
	if not GameState.get_flag("gsa_freed"):
		return "Switch to the attendant and force the latch."
	if not GameState.get_flag("slime_dead"):
		return "Cut grid power, then start the generator."
	return "Done."
