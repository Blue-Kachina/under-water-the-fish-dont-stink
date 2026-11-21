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
| T0a metrics | 0 | M0 swim_metrics_probe + fixture | track/metrics | done |
| T0b boundary | 0 | mode_boundary_probe (report only) | track/boundary | done |
| T0c swimstate | 0 | M5 SwimState | track/swimstate | not started |
| T1 swim | 1 | M4, M1, M2 | track/swim | blocked on phase 0 |
| T2 rig | 2 | P1-P4 shark rig | track/rig | blocked on phase 0 |
| T3 hunt | 3 | H0-H7 | track/hunt | blocked on phase 0 (H0 may start early) |
| T4 carve/rollout | 4 | M3, P5, Nature migration | track/carve etc | blocked |

## Track sections
### T0a metrics
Status: DONE 2026-11-20 (branch track/metrics). No gameplay scripts touched; no test seam needed.
- Built `tests/swim_metrics_probe.{gd,tscn}`: Nature preset, Ocean, 4 s runs. Flat metrics (167 keys) written to
  `tests/fixtures/swim_metrics.json`: 10 §1.3 scenarios (+ no-throttle sides), timing sweep `timing_00..09`
  (flip interval 0.5x peak -> peak+fade, 0.175..0.700 s), turn sweep `turn_5/15/30` (full stick, no throttle,
  velocity set to v, stop at 90 deg: radius, drift, speed lost per 90, turned), `held_vs_released/ratio`,
  `camera_wobble*` (detrended half peak-to-peak yaw of FollowCamera and fish, sampled per rendered frame; works headless).
- Run: `Godot_console.exe --headless --path . res://tests/swim_metrics_probe.tscn` (diff; exit 1 past tolerance:
  max(3% of recorded, per-metric floor)). Re-record: append `-- --record`. About 1 min.
- Fixture IS recorded. It reproduces the §1.3 table exactly (e.g. held 16.0 m, release 88.4 m, lock 92.1 m; ratio 0.180).
- Numbers: turn radius 1.36 / 4.23 / 8.54 m at 5 / 15 / 30 m/s (90 deg always 0.59 s, so radius scales with speed;
  speed lost per 90 deg 2.4 / 7.3 / 14.5 m/s, drift 81 deg). Timing sweep end speeds: 10.0, 20.4, 21.1, 23.3, 20.5,
  16.0, 6.4, 9.3, 5.2, 3.1.
- Camera finding: in open Ocean with the Nature preset the FollowCamera does NOT turn with the fish at all (yaw
  amplitude 0.00): `follow_air_rotation` is false and the fish is never `on_surface`, so the view holds its takeoff
  heading (RL air hold). With the probe setting `follow_air_rotation` true the camera wobble is 7.17 deg
  (fish 8.81 deg). Both recorded (`camera_wobble`, `camera_wobble_follow`). The §1.4 F6 premise needs checking
  against how Nature really sets the camera (near the seabed `on_surface` is true).
- Worktree note: copying addons/ from main over the checkout dirties tracked files (import rewrites); `git checkout -- .`
  restores them. The Ext dll under addons/.../bin/windows (gitignored) must be present or fish_controller fails to compile.
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
- 2026-11-20: T0a + T0b merged into roadmap/core. Finding (T0a): in open Ocean on Nature the FollowCamera yaw wobble is 0.00 deg (follow_air_rotation off), so plan F6 holds only near a surface; M4 acceptance must use `camera_wobble_follow` (7.17 deg). Verify F6 in real play.
