# Backlog

Keep this file limited to unfinished, actionable work. Remove completed items instead of adding implementation history.

## Playtest stabilization

Major feature work is frozen until playtest feedback is reviewed. Prioritize defects, measurable performance problems, usability blockers, and safe cleanup.

### Correctness

- [x] Complete a warning-free Godot editor startup and gameplay run.
- [x] Test full Retry/reset repeatedly from pause and from each character death.
- [x] Exercise the complete puzzle path with both characters.
- [x] Test exterior, office, and cellar transitions in each relevant power state.
- [x] Test slime pursuit, damage, corpse separation, trap death, and game-over timing.
- [x] Test journal collection/navigation, dialogue queues, and repeated knock bubbles.
- [x] Test every Options control with keyboard, mouse, and gamepad.
- [x] Verify settings persistence and Restore Defaults across a full application restart.

### Performance

- [x] Profile Fast, Balanced, and Nice in representative slime scenarios.
- [x] Record frame time, FPS, memory, node count, and visible stutter before optimizing.
- [x] Stress-test blocked slime movement, long trail coverage, pool ripples, and repeated scene restarts.
- [x] Optimize only bottlenecks demonstrated by profiling.

### Project hygiene

- [x] Audit unused scene nodes, exports, scripts, resources, and source assets.
- [x] Remove only assets confirmed to have no runtime, editor, or documentation references.
- [x] Audit audio players, streams, buses, loop behavior, and volume consistency.
- [x] Review stale comments and documentation against current behavior.
- [ ] Review oversized scripts for concrete duplication or defect risk; avoid speculative rewrites.

### Build readiness

- [ ] Add a visible or easily retrievable playtest build identifier.
- [X] Create and verify a desktop export preset.
- [X] Run the full smoke test against an exported build, not only the editor.
- [X] Test startup, input, audio, display settings, save persistence, Retry, and Quit in the export.
- [ ] Prepare a short known-issues list and structured playtest feedback form.

## Deferred

Do not begin these items during stabilization unless playtest feedback makes one necessary.

- [ ] Consider additional display settings if testing justifies them: VSync, frame cap, borderless mode, brightness, or render scale.
- [ ] Consider accessibility settings: reduced flicker, screen-shake intensity, text speed, high-contrast text, and text scaling.
- [ ] Extract complex UI from `GasStation.tscn` only when in-scene editing becomes costly.
  - Likely candidates: journal, menu/options, character HUD, and special-action button.
- [ ] Investigate Web export only if it becomes a target platform.
  - Create an export preset and test with the Compatibility renderer.
  - Profile the large sprite sheets and slime image-upload systems before committing to support.
