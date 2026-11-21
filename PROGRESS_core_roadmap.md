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
| T0b boundary | 0 | mode_boundary_probe (report only) | track/boundary | not started |
| T0c swimstate | 0 | M5 SwimState | track/swimstate | not started |
| T1 swim | 1 | M4, M1, M2 | track/swim | blocked on phase 0 |
| T2 rig | 2 | P1-P4 shark rig | track/rig | blocked on phase 0 |
| T3 hunt | 3 | H0-H7 | track/hunt | blocked on phase 0 (H0 may start early) |
| T4 carve/rollout | 4 | M3, P5, Nature migration | track/carve etc | blocked |

## Track sections
### T0a metrics
(agent fills: status, commits, probe results, open items)
### T0b boundary
### T0c swimstate
### T1 swim
### T2 rig
### T3 hunt
### T4 carve + rollout

## Open items / decisions for the user
(coordinator collects)

## Log
- 2026-11-20: roadmap branch created, phase 0 launching.
