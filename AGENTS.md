# AI Directives

Use this file as persistent project guidance for any AI working in this repository.

## Required workflow

- Read `FILE_DIRECTORY.txt` before making changes when file ownership, locations, or system purpose matter.
- Keep `FILE_DIRECTORY.txt` updated whenever you add files, remove files, or materially change a file's responsibility.
- Prefer editing existing systems in place instead of creating duplicate scripts or parallel implementations.

## GDScript rules

- Keep variables explicitly typed when the type is not guaranteed to infer cleanly.
- Prefer explicit typing for locals derived from `Variant`, mixed arrays, node properties, dictionary lookups, and numeric calculations.
- Use typed arrays such as `Array[Node2D]` instead of untyped literal arrays when iteration types matter.
- Avoid introducing parser ambiguity in Godot by annotating floats, nodes, and collections where needed.
- Match the project's existing typed GDScript style in new code.

## Change discipline

- Make focused changes that fit the current architecture.
- Do not remove or overwrite unrelated user changes.
- Before editing `.tscn` scene files, explicitly remind the user to save any open Godot editor changes, because unsaved editor changes cannot be detected from disk and may be overwritten by file edits.
- Update lightweight documentation when behavior changes affect how future AI should reason about the project.

## Project memory

- `FILE_DIRECTORY.txt` is the quick reference for file locations and purposes.
- Root-level `AGENTS.md` is the persistent instruction file for cross-session AI behavior.
- Check root-level `BACKLOG.md` for unfinished work before resuming an active feature.
- Check `docs/SYSTEMS.md` for current behavior and ownership, and `docs/DECISIONS.md` before revisiting an established architectural choice.
- Keep completed implementation history out of `BACKLOG.md`; update system or decision documentation only when the durable behavior changes.
- Godot is available on PATH as `Godot_v4.5.1-stable_win64.exe`; use that executable for project checks or editor/headless commands.
- Slime behavior has two distinct pursuit contexts that must be preserved:
- With grid power off, the slime can track from farther away.
- With grid power on, the slime is more anchored to `pump_anchor` and should prefer staying near that area.
- When the slime acquires a chase target in either pursuit context, it should face the target, pause for the raise animation, then use the matching `*_follow` animation while moving.
- The slime is intentionally exterior-only; do not let generic layer triggers teleport it into interior or cellar spaces without adding explicit slime navigation/unstuck rules.
- `LayerController.gd` keeps the exterior-only slime on the normal world collision layer; interior and cellar geometry are spatially separated and are not slime navigation spaces.
