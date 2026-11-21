# PROGRESS: core roadmap (planning_core_roadmap.md)

Coordinator-run, resumeable. Started 2026-11-20. Scope: phases 0-4. Decisions taken: D1 Nature identity,
D2 M1 behind toggle, D3 M3 behind toggle (default off), D4 shark prototype, D5 Hunt first,
D6 file moves done in worktree + committed, git: branch per track, push branches, nothing to master.

## How to resume
- Integration branch: `roadmap/core`. Track branches: `track/<name>`, worktrees under `D:/Dev/GameDev/wt/<name>`.
- Each agent edits ONLY its own track section below (avoid merge conflicts) and commits it with its work.
- Godot: `C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`;
  see memory notes (probe-running-tips): `--import` first, always `timeout`, no bare python (use uv).
- New worktree needs `.godot/` and `addons/godotsteam` copied from the main checkout, then `--import`.

## Dashboard (coordinator maintains)
| Track | Phase | Items | Branch | Status |
|---|---|---|---|---|
| T0a metrics | 0 | M0 swim_metrics_probe + fixture | track/metrics | not started |
| T0b boundary | 0 | mode_boundary_probe (report only) | track/boundary | done |
| T0c swimstate | 0 | M5 SwimState | track/swimstate | not started |
| T1 swim | 1 | M4, M1, M2 | track/swim | blocked on phase 0 |
| T2 rig | 2 | P1-P4 shark rig | track/rig | blocked on phase 0 |
| T3 hunt | 3 | H0-H7 | track/hunt | blocked on phase 0 (H0 may start early) |
| T4 carve/rollout | 4 | M3, P5, Nature migration | track/carve etc | blocked |

## Track sections
### T0a metrics
(agent fills: status, commits, probe results, open items)
### T0b boundary
- Status: DONE (reporting only), branch track/boundary.
- Built `tests/mode_boundary_probe.gd/.tscn` (text scan; no scene) + baseline `tests/fixtures/mode_boundary_baseline.json`.
- Run: `Godot_console.exe --headless --path . res://tests/mode_boundary_probe.tscn [-- --record | --strict | --verbose]`. Usage is also in the script header.
- CORE / KITS / MODE_DIRS / MODE_FILES const lists at the top map §3.2 onto today's files; repoint them after the folder move. Mode class names are derived from every `class_name` in mode files; strings and comments are ignored; `res://scripts/<mode file>` paths also count.
- Today: 242 violations in 21 files. By mode: unnatural 119 (17 files), marco 38, what_stinks 38, nature 20, 1v1 13, hunt 12, course 2. Worst files: main.gd 51, traversal.gd 32 (kit naming Unnatural stuff), ui/mode_setups.gd 32, hud.gd 21, chomp_kit.gd 19, coop_session.gd 15, local_coop.gd 15, sfx_hooks.gd 12, debug_panel.gd 11.
- Caveats: 22 scripts unclassified (not scanned); `--strict` currently passes (0 new); detects class-name use only, not `set_meta`/string-keyed side channels or duck-typed field pokes.
### T0c swimstate
### T1 swim
### T2 rig
### T3 hunt
### T4 carve + rollout

## Open items / decisions for the user
(coordinator collects)

## Log
- 2026-11-20: roadmap branch created, phase 0 launching.
