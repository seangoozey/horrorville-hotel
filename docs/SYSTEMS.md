# Current Systems

This document describes current behavior and ownership. Exact tuning values belong in scripts and scenes; do not duplicate volatile inspector values here.

## Project phase

The project is feature-frozen for initial playtesting. Current work should focus on correctness, measured optimization, safe cleanup, export validation, and playtest readiness.

## Settings and options

`SettingsManager.gd` is the persistent settings authority. It saves audio, display, performance preset, FPS visibility, and keyboard/gamepad binding overrides to `user://settings.cfg`, applies them at startup, and emits `settings_changed`.

Alt+Enter globally toggles fullscreen through `SettingsManager.gd`, persists the display setting, and updates the Options display state through the existing `settings_changed` flow. Fullscreen uses exclusive fullscreen at the monitor's active/native size and preserves default canvas-item scaling for crisp UI/art. The Resolution option displays `Native` and is non-editable while fullscreen is active; returning to windowed mode reapplies the stored window size and recenters the window on the current monitor.

The Options menu currently provides:

- Master, Music, and SFX volume plus mute. Cutscene video uses a dedicated fixed-gain Video bus.
- Fullscreen/windowed mode and windowed resolution; fullscreen displays native resolution and does not expose a non-native resolution switch.
- Fast, Balanced, and Nice performance presets plus an FPS display checkbox.
- Keyboard/mouse and gamepad rebinding with restore defaults.

Performance presets configure both the frame cap and slime visual cost:

- Fast caps at 60 FPS and disables slime trail and pool-ripple visuals while preserving slime gameplay.
- Balanced caps at 120 FPS, keeps both effects, halves trail resolution, disables trail blur, reduces droplets and ripple count, and throttles visual updates.
- Nice leaves FPS uncapped and restores the scene-authored slime visual settings.

Gameplay movement uses `move_*` actions. Menu navigation keeps the standard `ui_*` actions so gameplay rebinding does not rewrite menu controls.

## Character health, death, and audio

`CharacterBase.gd` owns health and emits damage, health, death, and death-sequence signals.

The Journalist and GSA are siblings under the Y-sorted `Characters` parent in `GasStation.tscn`; when their sprites overlap, the character with the lower screen position / larger Y value draws in front.

`CharacterAudio.gd` owns character audio playback:

- Walking audio loops while moving.
- Nonlethal damage selects one configured `Damage1Audio` through `Damage4Audio` player at random.
- Named one-shot players support special actions and death.

`TopDownController.gd` owns directional death animation selection, death audio, corpse-perimeter expansion, and the two-second delay between animation completion and the death menu.

`Interactable.gd` owns special-action success/failure routing. Failed special actions still complete their fail animation/audio before dialogue; when the GSA tries to fix an examine-only area, he uses the specific `gsa_repair_examine_only` line instead of the generic no-action line.

Special actions are non-cancellable once started. While the active character is performing any special action, movement is held at zero and `InputRouter.gd` blocks gameplay Use, Special Action, Swap, and Journal requests until the action completes.

`DialogueManager.gd` owns the default bubble duration and fade timing. Callers may still provide an explicit duration for special cases. Active and queued bubbles can be retargeted without restarting their duration. The GSA discovery and right-tool lines use the knocking-area anchor while the journalist is active and the GSA's character anchor while the GSA is active, following character switches in either direction.

## UI ownership

`UIManager.gd` owns the gameplay HUD, character life displays, special-action visuals, journal behavior, and delayed death-menu activation.

HUD action buttons expose Use, Special Action, Journal, and Swap key labels from the current keyboard/gamepad bindings. `InputRouter.gd` tracks the last-used input family so those labels switch between keyboard and gamepad names. Use/Special button backgrounds use neutral/hover/pressed alpha feedback, keyboard/gamepad activation flashes the same pressed alpha, and the Special Action radial progress wipe applies to both the active action icon and its button background.

While the journal is open, `GameState.is_journal_open` blocks character movement so left/right page navigation cannot also move the active character.

`TitleScreen.gd` owns the startup Play/Options/Exit menu. Play resets runtime state and routes to the intro cutscene. The title Options panel and list container are scene-authored in `TitleScreen.tscn` for inspector editing, while setting rows and non-focusable Audio/Video/Controls section headers are populated at runtime from `SettingsManager.gd`. `TitleOptionsPanel.gd` owns inspector-facing title Options colors, option row width, and scrollbar spacing/color. Options exposes audio, display, performance/FPS, and control-binding settings; `ui_enter.wav` plays when entering menus or selecting/toggling options, and `ui_change.wav` plays when changing staged values such as volume, resolution, performance preset, or control bindings.

`VideoScreen.gd` owns reusable fullscreen intro/outro video playback using the GDE GoZen `VideoPlayback` addon node, so the project uses the existing MP4/H.264 cutscene files in `data/video` during editor runs and resolves exported builds to MP4 files placed beside the executable by filename. It asks `SceneRouter.gd` to threaded-preload the inspector-configured next scene during playback, advances on video completion or configured skip input, and then routes through the preloaded scene when available. Intro routes into gameplay; outro routes back to the title screen. Export builds must ship the external MP4 files and the GDE GoZen native library for the target platform.

`MenuScreen.gd` owns pause/death/win menu behavior, Retry, Options navigation, settings controls, and input rebinding UI. Retry resets runtime state and reloads the configured gameplay scene directly, independent of the project's startup scene.

Menu feedback audio uses the `SFX` bus: `ui_enter.wav` plays when entering an option edit state or changing menu/submenu, and `ui_change.wav` plays when an option value changes.

`DebugManager.gd` owns `DebugLabel`, the independently configurable `FPSDisplayLabel`, and the editor-only scene preview controls. The FPS display samples one-second windows and reports measured FPS, average frame time, and the worst individual frame time so periodic stalls remain visible instead of being hidden by an average-only FPS value.

## Slime behavior

The slime is exterior-only.

- With grid power off, it can acquire targets from farther away.
- With grid power on, it remains more strongly biased toward `pump_anchor`.
- Target acquisition faces the target, pauses for the matching raise animation, then moves with the matching `*_follow` animation.
- Pursuit and damage stop when either character dies.
- Collision recovery uses requested-direction progress checks and collision-tested detour waypoints.
- Wire-trap victory waits for the slime death animation inside `SlimeSystem.gd`, then hands off to `SceneRouter.gd`. `SceneRouter.gd` starts threaded-preloading the configured outro scene immediately, waits at least three seconds, and routes only after both the delay and preload are complete. If no outro scene is configured, it falls back to the `SOLVED` menu.

`LayerController.gd` keeps the slime on exterior collision. Interior and cellar spaces are not slime navigation areas.

## Slime visuals and performance

The outside-pool trail is a field-backed system:

- `SlimeBody.gd` owns inspector configuration and integration.
- `SlimeTrailEmitter.gd` samples real body travel and deposits from direction-specific sprite contact points.
- `SlimeTrailManager.gd` owns the floating scalar field, decay, uploads, recentering, rendering, and alpha masks.

Deposits require accumulated body travel, preventing blocked movement and collision jitter from overproducing trail. Repeat pooling is capped at 1.5 times the authored base width, and deposits whose center is already saturated are skipped. Active-cell tracking, dirty bounds, throttled decay/uploads, and sleep behavior limit CPU work.

Gas-spill ripples are a separate pool-only system. `SlimeBody.gd` schedules ripple bursts, and `SlimePoolRipple.gd` renders and throttles each ripple.

Treat the values saved on `World/Hazard/SlimeBlob` in `GasStation.tscn` as the active tuning source. Script exports are defaults, not necessarily the runtime scene values.

## Audio

Gameplay effects use the `SFX` bus, music uses `Music`, non-positional menu/journal sounds use `UI`, and cutscene playback uses `Video`. The Video bus is +3 dB into Master so 100% master at its -3 dB ceiling produces 0 dB effective video playback.

Spatial environmental audio includes the generator, grid switching, pumps, flicker, wire sparks, knocks, and slime movement/death. Character walk, action, damage, and death audio are non-positional children of each character's `CharacterAudio`.

Successful inventory pickups play `ui_pickup.wav` through the `SFX` bus.
