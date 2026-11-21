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
Status 2026-11-20: M5 BUILT and verified on `track/swimstate`, pushed; ready to merge into roadmap/core.
- `scripts/swim_state.gd` (`SwimState`, RefCounted, reused): speed, speed_frac (of max_speed*speed_scale), effort,
  forward_speed, accel (body frame, 60 ms smoothing), spin (body frame), slip (body frame, z = 0), drift_angle (deg),
  stride_* (phase, power, dir, fluke, peak, fade, timing, flow 0..1, sweet, cue), striding, grounded, surface_normal,
  bell_lean (-1 = not a bell swimmer), gait, plus pose cues of the controls: boosting, reverse, slide, slide_kick,
  stroke_dir (legacy plain-stroke sweep). `advance()` (physics fills it), `advance_from_velocity()` (spin from the
  basis delta), `from_velocity_history()` (static), `reset()`.
- Controller: `FishController.swim_state`, filled by `_fill_swim_state` at the end of `_integrate_forces`;
  `_process`, `_pour_bubbles`, `_trail_tail`, `_process_puppet`, `replay_fx()` read it. No `input_*` or `swishy.*` left
  in them. `set_net_state(..., step := -1)` synthesises a puppet's state (stride from fx, motion from velocity).
- Model: `FishModel.react(delta, state: SwimState)` (stores it as `swim`); `react_velocity(delta, velocity)` for fish with
  no controller (school fish, home screen/pick card previews, shots/probes) keeps a model-owned state. The model's old
  public fields (grounded, stride_swing/power/phase/peak/fade, bell_lean, bell_gait) are gone: tests/shots now write
  `model.swim.*` (stride_swing is `stride_dir`, bell_gait is `gait`). Tracks T2+ should use the same.
- ReplayCar synthesises its state from linear_velocity + facing each frame (fx stride fields from the clip).
- Wire format unchanged: 19 floats, FX_* from the struct (FX_TAIL_* still from the tail pivot, the pose output).
Pose decisions (no feel change): the model's `_swim` effort stays `speed / SWIM_REF_SPEED(23)` (switching to
state.effort would silence a coasting fish's ripple and is the rig's F4 job); the ray's frame-measured turn
(`turned`, `_turn_rate` for Titans) stays measured from the model's frames; the controller pose's `effort` is
state.effort = max(throttle, boost, stride power) (differs from old only when strides run without throttle,
`stride_needs_throttle` off). `slide_kick`, `stroke_dir`, `reverse`, `boosting` are control-derived cues kept so
the old pose formulas are unchanged; they're the first things the rig phase should replace with motion.
Render-time velocity is now the tick-end velocity (state.velocity) not the node's linear_velocity: same up to
Jolt's post-step, only feeds the whip streaming and the squash (squash_strength 0 everywhere).
Acceptance (see Log for numbers): parity game.json byte-identical to HEAD; gait_probe (baseline 1e-4) and swishy_probe
pass; swim_state_probe all pass; tick cost: `_fill_swim_state` 5.1 us/call, ~1 % of the ~500 us physics frame
(`tests/swim_state_bench`, noise +-15 % between runs so the 5 % criterion can only be met by that bound).
Regression vs HEAD (git-archive copy at wt/swimstate_head, 55 fish/model/replay/coop/school/hunter/camera probes run
on both trees): identical results except flakiness. Failing on BOTH (pre-existing): pick_card_probe (2 fail),
pause_probe (4 fail), unnatural_coop_probe (timeout, 4 pass/8 fail), preview_jitter_probe (1-6 fails, varies run to
run), school_probe (varies 0-3 fails run to run, stochastic), hider_looks_probe (168 script errors, 0 checks).
school_join_probe failed 16 once on the new tree while two suites ran side by side, passed 104/104 on four
re-runs (both trees). gait_probe's camera check reads 0.001 m on HEAD and ~0.007 m now at 120 frames after reset
(limit 0.05); at 500 frames both read 0.002-0.003 m: camera settle timing, not a regression.
Caught and fixed by the suite: FishController._process read `swim_state.gait` before the first tick (null);
`_apply_character` now seeds it.
Open for T2 (rig): react() still derives the ray's `turned` and the Titan `_turn_rate` from the model's own frames;
switching them to `swim.spin.y` is a feel change (render vs tick rate) so was left.
### T1 swim
### T2 rig
### T3 hunt
### T4 carve + rollout

## Open items / decisions for the user
(coordinator collects)

## Log
- 2026-11-20: roadmap branch created, phase 0 launching.
