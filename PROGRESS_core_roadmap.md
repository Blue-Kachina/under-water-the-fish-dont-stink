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
| T3 hunt | 3 | H0-H4 done; H5-H7 wait on M5 | track/hunt | H0-H4 merged |
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
**H0 DONE (2026-11-20, branch track/hunt, worktree D:/Dev/GameDev/wt/hunt).** Tests only; no gameplay script touched.
- `tests/hunt_probe.gd` already drove kickoff, slow bump, player battery (+arcade replay), opponent battery, head-on faster, Fish Fry (+replay), time-up on points, new match, overtime start/live/battery win, arena edge, leave, Nature->Hunt. H0 added: `seed(20261120)` in `_ready`, 12 `_snap(label)` rows (phase, scores, style points, clock @0.01, overtime, overtime_elapsed, winner, fish_fry, battered[2], replay alive, event count) plus the `stat_event` log, written to `tests/fixtures/hunt_baseline.json`.
- Record: `Godot_console --headless --path . res://tests/hunt_probe.tscn -- --record` (`--record` is read from the user args or the engine args). A normal run diffs against the fixture and adds one check "matches hunt_baseline.json" (prints each differing row).
- Determinism: 4 consecutive runs (1 record + 3 diffs) identical. Nothing needed fixing: the bot is already `PROCESS_MODE_DISABLED` in the probe and all stepping is by physics frames. The only RNG left (opponent name, kickoff layout) is fixed by the seed.
- Worktree gotchas: besides `.godot/` and `addons/godotsteam`, the gitignored native binaries `addons/under-water-the-fish-dont-stinkExt/bin/windows/` must be copied from the main checkout, or `TerrainField` etc. fail to parse (main.gd:911 `_sync_terrain_stream` errors; 72 import errors) and probe runs are unrepresentative. On the first run after import the two Fish Fry checks failed in 3 consecutive runs, then passed in every later run (cause not pinned down: caches/terrain warm-up). If H1+ sees exactly those two fail on a cold worktree, re-run.
- `git status` in a fresh worktree shows ~800 CRLF-noise "modified" files (autocrlf); `git add` only your own paths. Scripts here are CRLF (keep it; edit with LF-aware tools carefully).

**H1 + H2 DONE (2026-11-20, second worker, branch track/hunt).**
- H1: `scripts/core/game_mode.gd` (GameMode extends Node: static `descriptor()`, `enter(world)`, `start()`, `end()`, `release()`, `reset()`, `playing()`, signals `teleported`, `over`), `mode_registry.gd` (ModeRegistry: static `scripts()` is THE registry, one line `[HuntMatch]`; `describe(id)`, `has_mode`, `merged(core, only)`, `merged_tiles`, `tuned_ids`; instance `start(id, world)`, `end()`, `active`, `active_id()`), `mode_world.gd` (ModeWorld: host, environment, fish, camera, hud). `HuntMatch` now `extends GameMode` and carries the Hunt descriptor (id, tile, pitch, environment "Ocean", tuning_preset, card_text, reset_label, after/tile_before); there is NO separate hunt_mode.gd, the match node is the mode node (H7 can split a thin HuntMode out if wanted). main.gd: `_modes := ModeRegistry.new()`; consts renamed `_CORE_MODES/_CORE_MATCH_MODES/_CORE_NATURE_MODES/_CORE_TILES`, and `MODES/MATCH_MODES/NATURE_MODES/MODE_TILES` are now instance vars merged with registered descriptors (same names, same readers); `hunt_match` is a compat getter (`_modes.active` when its id is HUNT); `HUNT := "Hunt"` const kept for probes. Unregistered ids fall through to the old code everywhere (`_start_match`, `_end_match`, `_playing_mode`, `_playing`, `reset_play`, `_reset_label`, `_match_card_text`, `mode_environment`). `_start_hunt` and the Hunt `_end_match` body are gone.
- H2: hud.gd is the HudHost: slot accessors `scorebug`, `splash`, `board`, `replay_overlay`, `course_text`, methods `feed_add/feed_clear`, `name_of`, `speed_text`, `share_bar`, `set_mode_hud(ModeHud)`; per-frame branches call `mode_hud.update_slots/countdown_text/update_board/replay_live`, hint wording from `mode_hud.restart_hint/camera_word/has_board`. `scripts/core/mode_hud.gd` (ModeHud base, RefCounted) and `scripts/modes/hunt/hunt_hud.gd` (HuntHud, `HUNT_HEADINGS` moved there; hunt_probe repointed). hud.gd has no Hunt code left. `HuntMatch.start()` does `hud.set_mode_hud(HuntHud.new(self))`, `release()` clears it.
- Probe notes: `hunt_probe` baseline compare now tolerates float diffs of 0.011 (one physics tick): `overtime_elapsed` flaked 0.57/0.58 in ~1 of 3 runs (not caused by the refactor, contact frame varies). Boundary probe: `core/` is CORE, `core/mode_registry.gd` is exempt (the one allowed place naming modes), `modes/hunt/` is a mode dir; hunt violations 9 (before H1: main.gd had HuntMatch hits too) -> 1 (sfx_hooks), total 242 -> 231, baseline re-recorded. Battery replay screenshots before/after H2 show identical HUD (the shot tool itself is flaky: 0-7 frames per run).

**H3 DONE (same session).** follow_camera.gd got ONE additive block (19 lines, inserted right above `set_ball_cam()`, nothing existing edited, for T1's M4 merge): `claim(focus: Node3D, ball_cam_on := true)` (sets `ball = focus; ball_cam = ball_cam_on`, no swing, no signal, exactly what main.gd did), `release()` (`ball = null`; ball_cam deliberately left as is, same as the old `_end_match`), `focus_node()` (read-out). `HuntMatch.start()` calls `_world.camera.claim(opponent)`, `release()` calls `camera.release()`. `ball`/`ball_cam` stay the real storage, so hunt_probe's `camera.ball == opponent and ball_cam` / `ball == null` checks are unchanged. When M4 introduces CameraStyle/CameraClaim, fold `claim/release` into it and keep the three names (or edit the two HuntMatch lines). Gate: hunt_probe, camera_probe, hunter_cam_wiggle_probe, survivor_cam_probe green.

**H4 DONE (same session). Resume at H5.** Audio via the descriptor: HuntMatch's descriptor has `"sfx": [[MatchSounds, &"sfx_hook"], [BatteredSounds, &"sfx_battered"], [HuntSounds, &"sfx_hunt"]]`; `SfxHooks._on_node_added` has a generic `elif node is GameMode:` branch attaching each entry (deferred, same `_attach`), and `Match1v1` keeps its own branch attaching MatchSounds + BatteredSounds. The `is HuntMatch` checks are gone from battered_sounds.gd / match_sounds.gd: games now share a tiny duck interface (`opponent_fish()`, `replay_signal_names()`, `battery_speed(fallback)`; added to HuntMatch and Match1v1). The three Hunt-only sounds (`hunt/target_spotted`, `hunt/caught`, `hunt/escaped`, ids unchanged) moved out of BatteredSounds into new `scripts/modes/hunt/hunt_sounds.gd` (HuntSounds). Gate: hunt_probe, audio_hooks/2/3/4, replay_audio, mode_setup, ui probes green. `audio_probe` has 2 FAILs (octopus ids; Sound Board count 275) that are PRE-EXISTING at ae98f0f (verified in a clean worktree), not from this track. Boundary probe: Hunt now has ZERO hits in core/kit files (before H1: hunt in main 4+, hud 8, sfx_hooks 1, ...); total violations 242 -> 230, baseline re-recorded.
- NEXT for H5-H7: files still flat: `scripts/hunt_match.gd` (descriptor + GameMode), `hunter_bot.gd`; new Hunt files already live in `scripts/modes/hunt/` (hunt_hud.gd, hunt_sounds.gd) and core files in `scripts/core/`. `main.gd` keeps `const HUNT := "Hunt"` for the probes. H5 needs fish_controller.gd (wait for M5). To check the discard test at H7: the registry line is `ModeRegistry.scripts()` (`return [HuntMatch]`); with it commented out `main.MODES` loses Hunt and `hunt_match` getter returns null, so hunt-only probes (hunt_probe, battery_replay_shots, hunter_bot_probe, style_points_probe, ocean_floor_probe, audio_hooks2 hunt block, mode_setup_probe loop, ui_probe `main.set_mode(main.HUNT)`) fail by design.

**H1-H7 execution plan** (file:line at 2336b54; re-verify, the jcodemunch index may be stale).
Gate for EVERY step: `tests/hunt_probe` shows "matches hunt_baseline.json" and all checks PASS, plus the per-step gate in planning_core_roadmap.md section 3.3. Hunt files today are flat in `scripts/`: `hunt_match.gd` (435 lines, `class_name HuntMatch`), `hunter_bot.gd` (HuntMatch's bot; also the base of `unnatural/survivor_bot.gd`), shared kits `battery.gd`, `style_points.gd`, `goal_replay.gd`, `goal_recorder.gd`.

How Hunt is launched in probes: `main.set_mode(main.HUNT)` parks on a MatchCard with the fish hidden; then `main._match_card.play_requested.emit()` (or `main.play_match()`) -> `_start_match` -> `_start_hunt`. Probes read `main.hunt_match` (a HuntMatch) and `main.get_node("FollowCamera")`. Probes that touch Hunt and must stay green: hunt_probe; audio_hooks2_probe (:104-148, reads `hunt.get_node_or_null("Sounds") is MatchSounds` and `"BatteredSounds"`, emits `battered`/`stat_event`); mode_setup_probe (:316-326, loops `[NATURE, HUNT, ONE_V_ONE]` reading `main.hunt_match` vs `nature_run`/`match_1v1`); ui_probe; battery_replay_shots; feel_probe/feel_shots; hunter_bot_probe; style_points_probe; ocean_floor_probe. If H1 moves `main.hunt_match`, keep a compatibility getter until those probes are edited (tests may be edited, in the same commit).

**H1 (GameMode, ModeRegistry, ModeWorld; Hunt the only registered mode).**
- New core files (suggest `scripts/core/game_mode.gd`, `mode_registry.gd`, `mode_world.gd`; unique class_names). Every `main.gd` mode entry point asks `ModeRegistry.get_mode(id)` first and otherwise falls through to today's code.
- Hunt rows in main.gd to move into `HuntMode.descriptor()`:
  - const `HUNT := "Hunt"` :53 (keep the id string; probes use `main.HUNT`).
  - `MODES` :60, `MATCH_MODES` :62, `NATURE_MODES` :64 (HUNT is in all three; tuning preset is NATURE_PRESET :66 via `_use_nature_tuning(current_mode in NATURE_MODES)` :875 and `wanted ... in MATCH_MODES` :877). They must become "static list + registered ids". Other readers: :187, :329, :373, :839; `ui/mode_picker.gd:21` `PRIMARY` contains "Hunt" (ordering, stays).
  - `MODE_ENVIRONMENTS` Hunt row :73 ("Ocean"); read in `mode_environment()` :352/:361 and :877. `ENVIRONMENTS` :41 stays core.
  - `MODE_TILES` Hunt row :94-96 (title, icon "mode_hunt" whose path data is `ui/hex_badge.gd:93` and stays core, colours, pitch, short, `play: ["Solo"]`).
  - `_match_card_text` HUNT case :800-801 -> descriptor card text. `var hunt_match: HuntMatch` :134. Header doc :7-13.
- Lifecycle into `HuntMode`:
  - `_start_match` dispatch :983-984 -> `mode.start()`.
  - `_start_hunt()` :1154-1165 -> `HuntMode.start()`: `HuntMatch.new()`, name "Hunt", `setup(_environment as Ocean, _fish)`, `battery_replays = UISettings.goal_replays`, `fish_teleported` -> `camera.snap()` for the local fish, `_environment.add_child`, camera (H3), `_hud.set_hunt` (H2).
  - `_end_match` Hunt branch :1251-1256 (`end()`, `queue_free()`, null, `_camera.ball = null`, `_hud.set_hunt(null)`) -> `HuntMode.end()`. `_end_match` is :1224-; branch order Unnatural, Marco, WhatStinks, Hunt, Nature; leave the others alone.
  - `_playing_mode()` :929-940: line :940 `return HUNT if hunt_match else ""` -> `registry.active_id()`; the predicate at :923-925 (`hunt_match != null` in the or-chain) -> `registry.playing()`.
  - `reset_play()` :502-504 (`hunt_match.restart()`) and `_reset_label()` :531-532 ("Restart match") -> `mode.reset()` / descriptor reset label.
  - Mixed sites: :415, :420-422 (`elif not (match_1v1 or nature_run or hunt_match or marco_polo or what_stinks)`), :879 (Nature -> Hunt in the same water; the probe's "nature to hunt" block covers it), `set_mode`/`_apply_mode` :833-880, `_show_match_card`/`play_match` :729-752.
  - ModeWorld gives the mode: environment, slot-0 fish (`_fish`), camera, hud.
- Gate: hunt_probe matches fixture; mode_setup_probe, audio_hooks2_probe, ui_probe green; then the every-other-probe sweep.

**H2 (HudHost slots + `HuntHud`).** Hunt lines in hud.gd (`grep -n -i hunt scripts/hud.gd`, 50 hits; the "47"): doc :20; `const HUNT_HEADINGS` :42-44 (also read by hunt_probe: `load("res://scripts/hud.gd").HUNT_HEADINGS`, repoint to the HuntHud constant); `var hunt_match` :84; points feed var :86; `set_hunt()` :304-316 (connects `battered`, `battery_replay_started`, `battery_replay_ended` -> `_replay_overlay.stop`, `match_over`, `stat_event`); `_on_hunt_battered` :325-334 (BATTERED! splash via `_splash.play`, `_name_of`, `_speed_text`); `_on_hunt_event` :336-362 (feed); battery replay start :364-377 (`_replay_overlay.start`; the overlay is a shared kit, stays in hud); `_on_hunt_over` :379-387; `_update_hunt_scorebug` :388-405 (team_names, scores, "%d PTS" players, clock / overtime clock, caption REPLAY/OVER/OVERTIME/HUNT); `_process` branches :506 (`_scorebug.visible`), :524-525, :539-543 (countdown text from `countdown_left`/`go_time_left`); :606-609 (replay-active predicate counts Hunt's REPLAY phase), :614-615 (`_update_hunt_board`); `_update_hunt_board` :649-680 (headings, footer "NEXT MATCH IN", "POINTS" share bar, per-team rows from `style.counts`); hint line :453-455 ("restart match", "fish" vs "ball", "Hold D-pad up/B: scoreboard", all keyed on `match_1v1 or hunt_match or nature_run`).
- Core slots needed on `HudHost`: scorebug (team_names, scores, players, clock, caption, visible), countdown label, splash `play(title, who, detail, colour)`, feed (lines with colour and lifetime), board (headings, rows, bars, footer, visibility rule), hint-line parts, replay overlay start/stop. `Match1v1` keeps calling the same slots unchanged.
- Gate: `battery_replay_shots` images unchanged (shoot before and after, compare), hunt_probe, ui_probe.

**H3 (camera claim).** Hunt's only camera use: main.gd:1163-1164 (`_camera.ball = hunt_match.opponent`; `_camera.ball_cam = true`) and :1255 (`_camera.ball = null`); `set_environment` :397 resets `ball` per environment. follow_camera.gd: `var ball: Node3D` :64, `var ball_cam := false` :69, `set_ball_cam()` :331, `_ball_cam_button` :342-367 (press toggles; hold opens the Nature wheel when `hold_opens_wheel` :74), `signal ball_cam_toggled` :50; no "hunt" text in the file. Replace with `world.camera.claim(...)` focus on the opponent with ball cam on, `release()` on end. Note `_end_match` nulls `ball` but does NOT reset `ball_cam` today: decide and document. hunt_probe asserts `camera.ball == opponent and camera.ball_cam` (kickoff) and `camera.ball == null` (leaving); keep `ball` as the claim's read-out so those two checks stand. Gate: camera_probe, hunter_cam_wiggle_probe, hunt_probe.

**H4 (audio).** `scripts/audio/sfx_hooks/sfx_hooks.gd:106-108`: `elif node is Match1v1 or node is HuntMatch:` attaches `MatchSounds` (child "Sounds", hook `&"sfx_hook"`) and `BatteredSounds` (child "BatteredSounds", `&"sfx_battered"`). HuntMatch type checks inside the hooks: `battered_sounds.gd:25,32-33,41,49,55` (`game is HuntMatch`, `hunt.style.is_threatened(0)`, `game.opponent` vs `game.bot_fish`, `victim == player`); `match_sounds.gd:21-22` (picks `battery_replay_started` vs `goal_replay_started` by `game is HuntMatch`). Plan: descriptor lists `sfx: [MatchSounds, BatteredSounds]`; SfxHooks attaches descriptor scripts to the mode node; give HuntMatch and Match1v1 a tiny shared interface (`opponent_fish()`, `replay_signal_names()`) so the `is HuntMatch` branches go. Sound ids `hunt/caught`, `hunt/escaped`, `hunt/target_spotted` are catalog names, do not rename. Gate: audio_hooks_probe family (audio_hooks2_probe :104-148 is the Hunt one).

**H5 (fish fields).** fish_controller.gd: `nature_batter_speed` :339 (default 22.0; readers `hunt_match.gd:6,201`, `nature_run.gd:369,402,609,758`, `audio/sfx_hooks/nature_sounds.gd:112`, Unnatural's ram, setting_docs :98 and :1143, debug_panel Fish section) -> `BatterySettings`; `controls_locked` :586; `team_color` :622-626 (setter -> `_apply_team_color` :858-862; read :855); `battered` :627; `team` :629; `batter()` :1052; `revive(spawn)` :1062. HuntMatch writes: `opponent.team = 1` / `team_color` :119-124; exit :154-160 (`team_color = TRANSPARENT`, `team = -1`, `controls_locked = false`, `revive(...)`); `controls_locked` :183, 215-216, 322-323, 381; `revive(kickoff_transform)` :184, 321; `victim.batter()` :269, 283. Map to `play_state` (HELD for locked, OUT for battered) and `capabilities` pushes (Nature's tuning today: `_use_nature_tuning` main.gd:875). Keep `controls_locked` as an alias until the other modes migrate (17 write sites outside Hunt). Gate: swishy_probe, nature_probe, gait_baseline, hunt_probe "leaving" block (team -1, TRANSPARENT, unlocked, ORIGINAL strokes and boost back, max_speed restored).

**H6 (settings).** nature_settings.gd:166-167 `hunt_floor`, `hunt_floor_depth`. Readers: `hunt_match.gd:141-142` (`OceanFloor.seabed(self, center, ARENA_RADIUS, floor_settings.hunt_floor_depth, 29, ...)`) and :207 (`OceanFloor.keep_above(... center.y - hunt_floor_depth, floor_clearance, floor_push, delta)`); `floor_clearance`/`floor_push` are shared floor kit values and stay out of HuntSettings. `ui/setting_docs.gd:732-733` keys `nature/hunt_floor`, `nature/hunt_floor_depth` -> `hunt/...` (regenerate). NatureSettings is persisted: migrate old saved values once or accept a reset (check `presets/nature.cfg` and `ocean_floor_probe`). Panel: debug_panel.gd `SECTIONS` :43 and singleton map :220 (label :50 "Nature, Hunt and Unnatural"); add the Hunt section from the descriptor `settings`. `game/goal_replays` (debug_panel.gd:63, `UISettings.goal_replays`) is shared with 1v1 and stays.

**H7 (files + discard test).** Plain moves (user commits; no `git mv`): `scripts/hunt_match.gd` -> `scripts/modes/hunt/` with `hunt_mode.gd`, `hunt_hud.gd`, `hunt_settings.gd`; `hunter_bot.gd` goes to kits (SurvivorBot extends it). Check `unnatural/bosses/drowned_shark.gd`, `unnatural/survivor_bot.gd` and `battery.gd` mentions of HuntMatch are comments only before moving. Carry the `.uid` files, then `--import` to refresh the class cache. Gate: `mode_boundary_probe` green; discard test = comment out the registry line, run the whole suite (hunt-only probes fail by design: list them), restore.

### T4 carve + rollout

## Open items / decisions for the user
(coordinator collects)

## Log
- 2026-11-20: roadmap branch created, phase 0 launching.
- 2026-11-20: T0a + T0b merged into roadmap/core. Finding (T0a): in open Ocean on Nature the FollowCamera yaw wobble is 0.00 deg (follow_air_rotation off), so plan F6 holds only near a surface; M4 acceptance must use `camera_wobble_follow` (7.17 deg). Verify F6 in real play.
- 2026-11-20: T3 H1-H4 merged. hunt_probe baseline compare tolerates 0.011 float wobble (overtime_elapsed 1-tick jitter). audio_probe has 2 pre-existing failures.
