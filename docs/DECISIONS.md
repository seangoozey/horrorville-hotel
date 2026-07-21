# Technical Decisions

Record decisions that future work might otherwise accidentally reverse. Keep entries concise and remove obsolete decisions when the architecture changes.

## Playtest feature freeze

The project is in cleanup, optimization, and playtest stabilization.

Do not introduce major features or broad refactors before initial playtest feedback. Accept changes that fix defects, remove verified waste, improve measured performance, or resolve a playtest blocker. Preserve current behavior unless a change has a concrete stabilization benefit.

## Exterior-only slime

The slime does not enter the office or cellar. Supporting multi-layer slime navigation did not justify the required navigation, collision, masking, and unstuck complexity.

Generic layer triggers must not teleport the slime. `LayerController.gd` supplies only the exterior collision context needed by the slime.

## Field-backed slime trail

The outside-pool trail uses a floating scalar field rather than spawned particles, burst sprites, or a fixed SubViewport stamp canvas.

Reasons:

- Stable world-space residue and repeat-path pooling.
- Explicit control over decay and deposition.
- Active-cell and dirty-region optimization.
- A floating window avoids requiring a level-sized field.

Trail placement uses direction-specific sprite contact offsets, while distance and stretch calculations use body movement. This prevents animation-facing changes from being mistaken for physical travel.

## Player-facing performance settings

Players choose one performance preset. Raw trail and ripple implementation values remain internal, and there are no separate player-facing slime toggles.

Fast disables slime trail and pool-ripple visuals without changing slime gameplay. Nice restores the scene-authored maximum settings. Balanced keeps the effects recognizable while reducing trail resolution, ripple count, droplets, blur, and update frequency.

## Separate gameplay and UI input

Gameplay movement uses `move_*`; menus use `ui_*`. This allows gameplay rebinding without making menu navigation inaccessible.

Controller movement retains the left stick as the primary movement input. D-pad directions are separately rebindable.

## Incremental UI scene extraction

Do not split every UI node into a separate scene. Extract a UI subsystem only when it has meaningful behavior, reuse, or editing complexity that benefits from isolated ownership.
