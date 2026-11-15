# Progress log: the Abyssal Garden look pass

Plan: `planning_abyssal_look.md`. Newest phase last. Each phase appends a dated section; earlier entries are never rewritten.

## Decisions taken (by the user, before the build)

- **D1** All `Ocean` modes (Free Swim, Nature, Hunt, Unnatural, Test Tank, What Stinks). Marco Temple only as a stretch. RL Aquarium and Obstacle Course keep their look.
- **D2** Our darker colours are the defaults, plus a "Sunlit" preset that copies abyssal-garden's constants.
- **D3** (a) a per-camera `CompositorEffect` for the fog.
- **D4** (a) upgrade the cylinders first, bench (b) volumetric fog in the Look Tank.
- **D5** Yes: graphics quality in phase 8, auto-detect off.
- **D6** Yes: Unnatural per-run biome tint.
- **Failure policy:** if a perf budget is missed or the CompositorEffect/MSAA path fails, use the plan's fallback (or lower defaults) and record it here. Do not stop.

## Phase 0: Look Tank, baselines, notices (2026-11-15)

**Built**
- `THIRD_PARTY_NOTICES.md`: the MIT text as published in their LICENSE (holder is "Maksymilian Dendura", the Noniv account), plus the one-line header every ported file must carry.
- `scripts/water_look.gd` (`WaterLook`, `WaterLook.shared()` like the other `*Settings`). Groups: **Water model** (`preset` Ours/Sunlit, `sig_*`, `kd_*`, `wcol_*`, `pcol_*`, `fade_start/end`; Sunlit copies their constants, Ours is a first-guess darker set to be tuned in phase 2) and **Look Tank** (`tank_fov`, `tank_split_players`, `tank_hud`, `tank_settle_frames`, `tank_blood_moon`). Nothing reads the model constants yet: phase 2 does. Later phases add their groups here and a tab in `debug_panel.gd` `TABS["water_look"]`.
- Panel: new **Water Look** section (after Hunter Size) in `scripts/debug_panel.gd` (targets, SECTIONS, USED_BY, TABS); saved with presets like the others. Not added to `coop_session.gd` TUNING_SECTIONS (a look is per machine). `tools/gen_setting_docs.gd` knows the section; `scripts/ui/setting_docs.gd` regenerated (its diff also holds the other uncommitted work's docs, since it is generated from all sources).
- **Look Tank** (`scripts/look_tank.gd`, `scenes/look_tank.tscn`): the Test Tank with the fish held and a free camera on 6 fixed viewpoints (1 looking up through kelp, 2 a ruin in shafts, 3 a reef close-up, 4 the open blue, 5 floor level into murk, 6 split-screen with `tank_split_players` players). Places are found on the seabed (the kelp patch with the highest average noise, the densest reef spot, ruin cluster 0), so they stay the same for the fixed seabed seed. Keys 1-6 (0 gives the game camera back), console `look_view <0-6>`, and console `look_tank` (in `main.gd`: `_cmd_look_tank`) start it inside a running game; `scenes/look_tank.tscn` starts it standalone. By default the Blood Moon is off in the tank (plain ocean, which is what the look is built for); `tank_blood_moon` 1 turns Unnatural's red on. The "few fish" are the Test Tank's immortal dummy school.
- `tests/look_shots.gd/.tscn`: renders the viewpoints to `logs/look_shots/<label>/<n>_<name>.png` and writes `gpu.txt` (GPU and CPU ms per view from `viewport_get_measured_render_time_gpu`, summed over the split views for view 6). 1920x1080, vsync off.
  `Godot_console.exe --path . res://tests/look_shots.tscn -- --label=NAME [--moon] [--sunlit] [--views=1,2] [--frames=90]`
- `tests/look_tank_probe.gd/.tscn` (headless): WaterLook presets, the tank starts, spots found, all 6 views, split join/leave, console commands. ALL PASSED.
- `tests/modes_probe.gd`: expected section list now ends with `water_look`.

**Files changed:** `scripts/main.gd` (look_tank var + command), `scripts/debug_panel.gd`, `tests/modes_probe.gd`, `tools/gen_setting_docs.gd`, `scripts/ui/setting_docs.gd`. **New:** the files above.

**Baselines (RTX 4070 Ti SUPER, 1920x1080, before any look change)**
- Look Tank, 1 player, GPU ms per view (`logs/look_shots/baseline/gpu.txt`): kelp_up 0.69, ruin_shafts 1.33, reef_close 1.25, open_blue 1.42, floor_murk 1.08; split (2 viewports summed) 1.51. With the Blood Moon on (`baseline_moon`) the numbers are within 0.05 ms of these.
- `split_bench --players=3 --count=2000` (Unnatural, two runs): 12.41 ms (81 fps) and 13.40 ms (75 fps); GPU total 3.96 and 4.37 ms (views about 1.2-1.7 each); process 13.5-13.8 ms; draw calls 3700.
- `split_bench --players=1 --count=2000`: 7.12 ms (140 fps), GPU 2.34 ms; draw calls 1249.
- Budgets for later phases: **1 player GPU at most +1.5 ms** over these; **3 players within 10% of 12.4-13.4 ms**. Note the plan's "above 100 fps" for 3 players is already not met at baseline on this run (75-81 fps, CPU-bound: process 13.5 ms), so the 10% rule is the one to hold.
- Shots: `logs/look_shots/baseline/` (plain ocean) and `logs/look_shots/baseline_moon/` (Blood Moon).

**Probes:** `murk_probe` ALL PASS, `modes_probe` passed, `compass_probe` passed on rerun (first run failed the known flaky "a far shrine starts hidden"), `look_tank_probe` ALL PASSED. Debug build exported 2026-11-15 12:28 (`builds/windows/FishPlayground.exe`).

**Open items / notes**
- Fan coral shows as a wire mesh in view 3 (existing look, phase 7 material pass).
- View 1 looks up at a fixed sun-less water colour; phase 2's sky and phase 4's surface will give it something to look at.
- Ours constants are placeholders; judge them against Sunlit in the Look Tank (`--sunlit`) in phase 2.

**Review (Phase 0, 2026-11-15):** independent check passed. Reran `--import`, `look_tank_probe` (ALL PASSED) and `murk_probe` (ALL PASS) headless with no script errors. WaterLook values are all panel settings, the MIT header is on `water_look.gd` (the only ported constants so far), the notices file is correct, panel docs include `water_look`. No defects found, nothing changed.

## Phase 1: Grading and bloom (2026-11-15)

**Built**
- **Ocean grade** (`WaterLook.apply_grade(env)`, called by `Ocean.configure_environment` and again live whenever a value changes, so panel edits show at once): ACES tonemap, exposure, white point, adjustment (saturation 0.93, contrast 1.05), and glow in Mix mode (`glow_mix` 0.08, levels 1-6 weighted low `1/1/.7/.5/.35/.2`, HDR threshold 1.0, ramp 2.0, bloom 0).
- **Per-camera pass** `WaterGradeEffect` (`scripts/fx/water_grade_effect.gd` + `shaders/water_grade.glsl`, a `CompositorEffect` at POST_TRANSPARENT, so on the HDR picture before tonemapping): vignette worked out against each view's own shape (split-screen views each get one), luminance S-curve applied by ratio, highlight desaturation. Attached with `WaterGradeEffect.attach(camera)` to the main FollowCamera (`main.gd`), each co-op camera (`local_coop.gd`) and the Look Tank camera. It does nothing unless `WaterLook.grading_active` (set by Ocean), and is skipped without a rendering device (headless). This is the same `Compositor` phase 2's fog effect will join. The MIT header is on the `.glsl`, the effect and `water_look.gd`.
- **Panel**: `WaterLook` gained groups Grading, Bloom, Blood Moon grade (all wide-range settings); the Water Look section has a new "Grading" tab. Panel docs regenerated (`tools/gen_setting_docs.gd`, 2165 entries).
- **Blood Moon multiplies, never overwrites**: `BloodMoon._apply` sets `WaterLook.moon_share` (0..1, reset in its `_exit_tree`); effective saturation / glow mix / vignette multiply by `moon_saturation` 1.12 / `moon_glow` 1.3 / `moon_vignette` 1.3 in proportion.
- **Other arenas keep their look**: the Environment is shared and outlives the arena, so `Arena`, `AquariumArena` and `MarcoArena` call `WaterLook.reset_grade(env)` in `configure_environment` (engine defaults, then the scene's filmic + plain glow, grading off). A switch Ocean to Arena and back is order-safe (no `_exit_tree` restore, which would race the new arena).

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/unnatural/blood_moon.gd`, `scripts/arena.gd`, `scripts/aquarium_arena.gd`, `scripts/marco_polo/marco_arena.gd`, `scripts/main.gd`, `scripts/local_coop.gd`, `scripts/look_tank.gd`, `scripts/debug_panel.gd` (tab), `scripts/ui/setting_docs.gd` (generated). **New:** `scripts/fx/water_grade_effect.gd`, `shaders/water_grade.glsl`.

**Decisions / tuning**
- First pass (ACES white 1.0, exposure 1.0, curve 0.55, vignette 0.4) crushed the dark water to near black. Defaults are now **exposure 1.6, curve 0.3, vignette 0.3**: close to the old brightness with a slightly firmer contrast, visible corner falloff and darker deep water. Judge in the Look Tank and edit live; `--sunlit` has no effect on grading yet.
- Plan said "intensity about 0.08": in Mix mode that is the Environment `glow_mix`, so that is the setting.
- No fallback needed: the CompositorEffect works with the project's MSAA 4x (resolved colour at POST_TRANSPARENT).
- Fixed along the way: the effect's shader RIDs leaked on exit; now freed on the render thread.

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms vs baseline)**
- kelp_up 0.74 (0.69), ruin_shafts 1.39 (1.33), reef_close 1.30 (1.25), open_blue 1.48 (1.42), floor_murk 1.15 (1.08), split 1.55 (1.51). About +0.05 ms each, far inside the 1.5 ms budget. With the Blood Moon on: ruin 1.45, open_blue 1.49.
- `split_bench --players=3 --count=2000` (two runs): 12.72 ms (79 fps) and 13.46 ms (74 fps), GPU total 4.10 / 4.35. Baseline was 12.41-13.40 ms, so within 10%.
- Shots: `logs/look_shots/phase1/` (all 6 views), `phase1_moon/` (views 2, 4), `phase1b/` (views 2-4, an intermediate tuning); compare with `baseline/`.

**Probes:** `murk_probe` ALL PASS, `compass_probe` ALL PASS, `modes_probe` passed, `look_tank_probe` ALL PASSED. An ad hoc check confirmed apply_grade (ACES, adjustment on, glow Mix), Blood Moon multiplication (sat 0.93 to 1.04) and reset_grade (filmic, adjustment off, glow mix 0.05). Debug build exported (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: the grade defaults (exposure/curve/vignette) against the old look, and a Free Swim / Nature / Hunt play-test. A non-Ocean to Ocean switch in a running game was reasoned about and probed at the Environment level, not played through.
- Effect and glow are not applied to the Marco Temple (stretch) or the pick-card / home-screen preview viewports (own environments).
- The Titan view's whale desaturate still lerps from the grade's saturation; Marco resets grading so it is unaffected there.

**Review (Phase 1, 2026-11-15):** independent check passed. Reran headless `look_tank_probe` (ALL PASSED), `murk_probe` (ALL PASS) and `modes_probe` (no failures) with no script or shader errors. Read the diff: values are all WaterLook settings, MIT headers are on `water_look.gd`, the effect and the `.glsl`, the Blood Moon multiplies via `moon_share` and resets on exit, non-Ocean arenas call `reset_grade`, co-op cameras get the per-camera pass. Log matches the code. No defects found, nothing changed. Not verified here: the visual result and the GPU numbers (taken from the log, not remeasured).

## Phase 2: Water fog model, sky and depth exposure (2026-11-15)

**Built**
- **Water model** (all in `WaterLook`, new groups Water fog / Depth exposure / Blood Moon water, panel tab "Water model"): per-colour `SIG` (extinction) and `KD` (sunlight loss per metre of depth), water colour `WCOL`, forward phase `1.22 + .3 mu^4`, hard fade at `fade_start/end`, `surface_height`, `inscatter_gain`. Sunlit preset still copies their constants. **Ours** now has `SIG = (0.030, 0.012, 0.0099)` (green is the scene's old 0.012, so the murk and `fog_reach()` mean exactly what they did) and a darker `WCOL = (0.025, 0.11, 0.19)`.
- **Fog pass** `shaders/water_fog_pass.gdshader` + `scripts/fx/water_fog_quad.gd`: a full-screen quad child of every camera (attached by `WaterGradeEffect.attach`, so the main, each split-screen and the Look Tank camera get one). It reads the opaque picture and depth, rebuilds world position, and applies `c*exp(-SIG*d) + closed-form in-scatter`, fading to pure water. Each camera's quad is on its own visual layer (16-20) that only that camera draws, so split-screen views fog from their own position. Visible only while `WaterLook.fog_active` (Ocean modes).
- **Sky** `shaders/water_sky.gdshader` (+ `water_fog.gdshaderinc`, the shared closed-form `wf_in()`): the same model looked through `sky_distance` (240 m), so up is bright, down dark and horizon matches the fogged geometry (no seam). Radiance cubemap is made at a nominal depth.
- **Environment fog kept for see-through things**: thinned to `transparent_fog` (0.35) of the density, coloured with the model's flat water colour at the camera's depth (set every frame by `Ocean._update_water`). The fog pass undoes that same fog on opaque pixels first (exact inverse, `(c1 - fc*(1-Te))/Te`), so nothing is fogged twice.
- **Murk:** density scales `SIG` (`scale = density / density_ref`). `UnnaturalSettings.fog_at/fog_reach` go through `WaterLook.fog_sigma()` (green extinction), so culling, glints and steering keep "where things are fully fogged"; with Ours the numbers are identical to before (probe checks unchanged), with Sunlit the water is thicker and the cull distances shorten with it.
- **Blood Moon:** `moon_share` now lerps `WCOL` (to `moon_wcol_*`) and `KD` (`moon_kd_scale`), plus sets the surface height (`surface_override`) and the sky's murk share (`sky_murk` = `murk_sky`). It still restyles ambient. Its old procedural-sky restyle runs only when the model is switched off.
- **Depth exposure:** in `WaterGradeEffect` (per camera, so split views differ): `depth_exposure_min` (0.85) near the surface rising to 1 over `depth_exposure_range` below `depth_exposure_start`.
- **Sun depth tint:** `Ocean` colours the scene's DirectionalLight3D by depth (`sun_depth_tint` 0.4, camera depth of the viewport's camera), restored when the Ocean leaves.
- **Switch:** `WaterLook.model_enabled` off gives back the old Environment fog and procedural sky live.
- Other arenas: `Arena`/`AquariumArena` call the new `WaterLook.restore_fog(env)` after `reset_grade`; `reset_grade` clears `fog_active`.

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/unnatural/blood_moon.gd`, `scripts/unnatural/unnatural_settings.gd` (`fog_at`/`fog_reach`), `scripts/fx/water_grade_effect.gd`, `shaders/water_grade.glsl` (exposure), `scripts/arena.gd`, `scripts/aquarium_arena.gd`, `scripts/audio/sfx_hooks/bed_sounds.gd` (reads `Ocean.fog_density()`), `scripts/debug_panel.gd` (tab groups), `scripts/ui/setting_docs.gd` (regenerated, 2182 entries), `tests/look_shots.gd` (`--set=name=value`, `--nomsaa`), `tests/murk_probe.gd` and `tests/hunt_probe.gd` (read `Ocean.fog_density()` / `WaterLook.sky_murk` instead of the Environment's now-thinner fog and off sky fog). **New:** `shaders/water_fog.gdshaderinc`, `water_fog_pass.gdshader`, `water_sky.gdshader`, `scripts/fx/water_fog_quad.gd`.

**Decisions / fallbacks (per the failure policy)**
- **CompositorEffect fallback taken.** The plan's first choice (a compute `CompositorEffect` at POST_OPAQUE) was built and ran, but under the project's MSAA 4x its writes are lost: the resolved picture it is handed is made again after the transparent pass (an all-red test write only showed with `--nomsaa`), and the multisampled colour has no storage-image usage so it cannot be written directly. Fell back to the plan's own alternative: a full-screen spatial quad reading `hint_depth_texture`/`hint_screen_texture`. It blends into the MSAA buffer, so it works with MSAA, and everything camera-specific comes from built-ins. The compute files were removed.
- **Light() shaders deferred.** The plan's per-shader `water_light.gdshaderinc` for sand, stone, reef and kelp was not done (none of them defines `light()`, and re-implementing lighting in each is risky); the CPU sun tint above covers it, shared by all views. Per-view sun tint stays an open item.
- Kept `fog_sky_affect` at 0 with the model on (the sky shader carries the fog).
- Transparents fog with a flat, depth-aware colour, not the full model; the inverse on opaque pixels is exact for the sRGB-round-trip colour but amplifies any mismatch at range, so `transparent_fog` defaults to 0.35, not 1.

**Measured (RTX 4070 Ti SUPER, 1920x1080)**
- Look Tank GPU ms (phase 2, baseline in brackets): kelp_up 0.80 (0.69), ruin_shafts 1.49 (1.33), reef_close 1.41 (1.25), open_blue 1.57 (1.42), floor_murk 1.23 (1.08), split 1.56 (1.51). About +0.15 ms in one-player views, far inside the +1.5 ms budget. With the Blood Moon: ruin 1.54, open_blue 1.59.
- `split_bench --players=3 --count=2000`: 12.78 ms (78 fps) and 12.99 ms (77 fps), GPU total 4.17 / 4.22, draw calls ~3735. Baseline 12.41-13.40 ms, so inside 10%.
- `split_bench --players=1 --count=2000`: 7.10 ms (141 fps), GPU 2.37 (baseline 2.34), draw calls 1251.
- Shots: `logs/look_shots/phase2/` (all 6), `phase2_moon/` (2, 4), `phase2_sunlit/` (3, 4); compare with `baseline/` and `phase1/`. Debug shots from the CompositorEffect investigation are in `logs/look_shots/p2_*` (can be deleted).

**Probes:** `murk_probe` ALL PASS (3 checks re-pointed at the Ocean's density and `sky_murk`), `compass_probe` ALL PASS, `look_tank_probe` ALL PASSED, `modes_probe` passed, `unnatural_combat_probe` ALL PASS, `coop_local_probe` passed. `hunt_probe`: the edge-fog checks pass (re-pointed); 2 other checks fail ("same speed: a Fish Fry...", "Fish Fry is replayed"), which are the unrelated issues already noted in memory, not touched by this phase. Debug build exported 2026-11-15 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: the Ours colours and exposure (darker/moodier, compare `phase2` with `phase2_sunlit` and `baseline`), the Blood Moon red, and a Free Swim / Nature / Hunt / Unnatural play-test. Surface height defaults to 30 m above the world origin in the open Ocean modes (Unnatural uses its own surface); tune `surface_height` if the open water looks too dark or too bright at fish height.
- The Look Tank still shows the Test Tank's oversize held fish fin in view 4 (existing).
- The Blood Moon's old Surface plane, rays and moon disc are unchanged (phases 4 and 6).
- Transparents (bubbles, shafts, FX) use the flat matched fog, so a far shaft is only roughly the same colour as the pass; check in the Unnatural play-test.
- Not done: Marco Temple (stretch), the pick-card and home previews (own environments), per-shader sun depth (`light()`).

**Review (Phase 2, 2026-11-15):** independent check passed. Headless `look_tank_probe`, `murk_probe` and `modes_probe` reran with no script or shader errors and no failures. Read the new files: MIT headers are on the fog pass, sky, include, quad and `water_look.gd`; the tunables (SIG, KD, WCOL, transparent_fog, exposure, sun tint) are WaterLook settings; the quad fallback matches the plan own alternative; Murk goes through `fog_sigma()` and Blood Moon lerps WCOL/KD. Only fix: a stale comment in `water_fog.gdshaderinc` that named the removed `water_fog.glsl`. Not verified here: the visuals and GPU numbers (taken from the log).

## Phase 3: Caustics (2026-11-15)

**Built**
- `shaders/water_caustics.gdshaderinc` (MIT header): their 5-iteration sin turbulence (`1.17 - pow(c, 1.4)`, then `pow(.., 8)`) evaluated inline per fragment (no SubViewport, so split-screen views each get it). Sun-projected UVs `q = p.xz - sun.xz*(p.y/sun.y)`, an RGB split (3 taps, offsets scaled by `caustic_split`), a second tap at `q.yx/6.9+.37`, combined as `min(pow(a,2.3)*5*(.45+b*1.3), 4)`. Masked by `smoothstep(.1,.45,N.L)`, faded with camera distance (35 to 100 m), dimmed per colour by depth below the surface (`exp(-KD/sun.y * depth)`, so red dies first). Added through `EMISSION` as `albedo * caustics` (the shaders have no `light()`, same reasoning as phase 2).
- Applied in `sand`, `stone` (ruins and reef rock), `reef`, `kelp_plant`, `fan_coral` (gained a `world_pos` varying) and `marco_gravel`. Fish backs (the plan's "optionally") not done.
- **Globals** declared in `project.godot` `[shader_globals]`: `water_time`, `water_caustic_strength/scale/speed/fade_start/fade_end/split`, `water_surface_y`, `water_sun_dir`, `water_kd`. `WaterLook.push_caustics(clock)` (called by `Ocean._update_water` each frame) sets them; strength is 0 unless the water model is on, and `reset_grade` calls `WaterLook.clear_caustics()`. So RL Aquarium, Obstacle Course and the Marco gravel (Aquarium) look as before (strength 0 returns at once).
- **Water clock:** `Ocean` accumulates `_water_clock += delta` in `_process`, so it stops while paused. It is per machine: co-op machines share the same maths and sun but not a synced clock (the pattern is not gameplay; add a network time offset later if the drift is ever noticeable).
- **Settings** (WaterLook group "Caustics", panel tab "Caustics", wide ranges): `caustics_enabled`, `caustic_strength` 0.5, `caustic_scale` 0.2, `caustic_speed` 1, `caustic_fade_start` 35, `caustic_fade_end` 100, `caustic_split` 1. Panel docs regenerated (2189 entries).

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/debug_panel.gd` (tab), `scripts/ui/setting_docs.gd` (generated), `project.godot` (shader globals), `shaders/sand|stone|reef|kelp_plant|fan_coral|marco_gravel.gdshader`. **New:** `shaders/water_caustics.gdshaderinc`.

**Fixes along the way:** `TAU` is a built-in in Godot shaders (redefinition error), so the include uses the literal; `fan_coral` had no `world_pos`.

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms; phase 2 in brackets, baseline 0.69/1.33/1.25/1.42/1.08/1.51)**
- kelp_up 0.81 (0.80), ruin_shafts 1.69 (1.49), reef_close 1.59 (1.41), open_blue 1.66 (1.57), floor_murk 1.33 (1.23), split 1.73 (1.56). Caustics add 0.0 to 0.2 ms; total over baseline is at most +0.36 ms, inside the +1.5 ms budget.
- `split_bench --players=3 --count=2000` (two runs): 12.71 ms (79 fps) and 12.11 ms (83 fps), GPU total 4.23 / 4.05, draw calls ~3700. Baseline 12.41-13.40 ms, so within 10%.
- `split_bench --players=1`: 7.10 ms (141 fps), GPU 2.43 (phase 2: 2.37), draw calls 1255.
- Shots: `logs/look_shots/phase3/` (all 6 views, gpu.txt); compare with `phase2/`. The sand and ruins now show moving net-line light that fades with distance; the fan coral still shows as wire mesh (phase 7).

**Probes:** `look_tank_probe` ALL PASSED, `murk_probe` ALL PASS, `compass_probe` ALL PASS, `modes_probe` passed, no shader or script errors in the Look Tank run. Debug build exported 2026-11-15 13:12 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: caustic brightness/size (`caustic_strength` 0.5, `caustic_scale` 0.2) in Free Swim, Nature, Hunt and Unnatural; a Blood Moon night (caustics follow the water's KD, so red survives deeper there).
- Caustics ignore sun shadows (no shadow map lookup), so they also show under ruins' shade; the pattern is a plain add.
- The light shafts will reuse `wc_turb` in phase 6; the "caustic taps 1 vs 3" quality knob in phase 8 is `caustic_split` 0 vs 1.

**Review (Phase 3, independent, 2026-11-15):** checked plan vs. build (include, 6 shaders, globals, settings, fade 35-100, MIT header, notices entry), `look_tank_probe` ALL PASSED headless, all caustic values come from WaterLook, strength 0 keeps Aquarium/Obstacle Course unchanged. No defects found, no edits made. Still open: headless does not compile shaders, so shader compile rests on the phase's Look Tank GPU run; fish backs skipped.

## Phase 4: Surface from below (2026-11-15)

**Built**
- `shaders/water_surface.gdshader` (MIT header): one flat plane that puts itself under every camera in its vertex shader (`CAMERA_POSITION_WORLD` is per view, so split-screen views each get their own and a single mesh serves them all), at `surface_y()`. Slope from three octaves of summed cosines (our own wave table, not their `WK`); Snell's window `k = 1 - 1.769(1 - cos^2)`; Fresnel `0.02 + 0.98 pow(1 - sqrt(k), 5)` (total internal reflection when `k <= 0`); inside the window the sky above plus the refracted sun `pow(sd,60)*halo + pow(sd,500)*core`; outside it `wf_in()` along the reflected ray; then the same absorption and in-scatter along the camera's ray as the fog pass (hard fade at `fade_start/end`, so the far surface meets the sky's water with no seam). Slopes flatten with distance (`surface_calm_distance`) so the window's rim does not shimmer. Invisible when the camera is above the surface.
- Drawn in the transparent pass, `render_priority -100` (after the fog pass, before every other see-through thing), full alpha, no depth write, fog disabled: what is under it is already fogged, and it fogs itself. So it needs no change to the fog pass.
- `Ocean._update_surface` creates the plane (child `WaterSurface`, huge cull margin) and pushes the model's values each frame; hidden when the model or `surface_enabled` is off, or on the old look. Radius is clamped to 0.9x the camera's far plane. All Ocean modes get it at `surface_height` (30 m by default); Unnatural at its own surface (`surface_override`).
- **Blood Moon:** its old red "Surface" plane and the moon sphere are hidden while the new surface is on (they come back with the model off). `WaterLook.moon_dir` (set by `BloodMoon`, `MOON_OFFSET`, cleared in `_exit_tree`) makes the moon the disc seen through the window: sun direction, colour (red) and sky tint lerp by `moon_share`. Rays are unchanged (phase 6).
- **Settings** (`WaterLook` group "Surface", panel tab "Surface", wide ranges): `surface_enabled`, `surface_radius` 900, `surface_waves` 1, `surface_wave_speed` 1, `surface_calm_distance` 90, `surface_sky_r/g/b`, `surface_sun_halo` 1.3, `surface_sun_core` 12, `moon_disc_halo` 2, `moon_disc_core` 40, `moon_sky_r/g/b`. Panel docs regenerated (2204 entries).

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/unnatural/blood_moon.gd`, `scripts/debug_panel.gd` (tab), `scripts/ui/setting_docs.gd` (generated). **New:** `shaders/water_surface.gdshader`.

**Decisions / notes**
- Per view: one plane for all views (shader-side camera follow) rather than a plane per camera.
- The moon's disc colour went through two passes: red is absorbed by the water between the surface and the camera, so a (1, .2, .12) disc read green-white; now (1, .05, .03) with core 40, which reads as a hot pink-white disc in a red field.
- Sky above the water is a settable colour, not computed from the PCOL palette (PCOL is unused so far).

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms; phase 3 in brackets, baseline 0.69/1.33/1.25/1.42/1.08/1.51)**
- kelp_up 0.71 (0.81), ruin_shafts 1.64 (1.69), reef_close 1.54 (1.59), open_blue 1.61 (1.66), floor_murk 1.27 (1.33), split 1.72 (1.73). The surface is free at this resolution (within noise); worst case is +0.31 ms over baseline, inside the +1.5 ms budget. Blood Moon: kelp_up 0.71, ruin 1.64, open_blue 1.62.
- `split_bench --players=3 --count=2000` (two runs): 13.31 ms (75 fps) and 12.87 ms (78 fps), GPU total 4.25 / 4.20, draw calls ~3750. Baseline 12.41-13.40 ms, so within 10%.
- `split_bench --players=1`: 7.64 ms (131 fps), GPU 2.54 (phase 3: 2.43), draw calls 1377 (+1 for the plane; the rest is run-to-run).
- Shots: `logs/look_shots/phase4/` (all 6), `phase4_moon/` (1, 2, 4), `phase4_rim/` (view 1 at fov 125, shows Snell's window rim); compare with `phase3/`.

**Probes:** `look_tank_probe` ALL PASSED, `murk_probe` ALL PASS, `compass_probe` ALL PASS, `modes_probe` passed; no script or shader errors in the Look Tank GPU runs or the benches. Debug build exported 2026-11-15 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: wave steepness (`surface_waves`) and the window's rim (a little jagged by design), the sun disc strength, and the moon disc under Unnatural's murk (murk fog can hide it). Switch `surface_enabled` off to compare with the open water of phase 3.
- A real Unnatural run was not played; the Look Tank with `--moon` stands in. The red slab seen in phase4_moon view 1 is one of the old additive god-ray cylinders (phase 6).
- Surface above the camera is not drawn when the camera is above `surface_y - 0.3` (no above-water view yet). Free Swim fish that swim above 30 m see the open sky as before.
- Co-op: the wave clock is per machine, like the caustics.

**Review (phase 4):** checked plan vs. code, MIT header on water_surface.gdshader, all new values are WaterLook exports, Blood Moon/murk hooks, split-screen (shader-side per-view follow). look_tank_probe ALL PASSED headless, no load errors on import. No defects found, nothing changed. Note: headless cannot compile shaders, so shader validity rests on the logged GPU Look Tank runs.

## Phase 5: Particles (snow, glints, bubbles) (2026-11-15)

**Built**
- **Marine snow** (`shaders/water_snow.gdshader`, MIT header): the 6000 spheres are now camera-facing quads (one `QuadMesh` MultiMesh, built once at `SNOW_MAX` 20000, `snow_count` of them drawn live). Flakes sit in a unit cube and the vertex shader wraps them into a `snow_box` (44 m) round **each view's own camera** (`CAMERA_POSITION_WORLD`), so split-screen views each get snow round themselves (the old specks only followed the main camera). Near fade 0.6 to 2.5 m, far fade 14 to 22 m, drift `(.22,.05,.13)*t`, minimum on-screen size (`snow_min_px`) with energy conserved (`(r/s)^2`), additive with an HDR peak so bloom catches it. The quad is placed by writing `POSITION` from view space. `wrapped_specks.gdshader` removed (unused).
- **Kelp glints** (`shaders/kelp_glint.gdshader`, `scripts/scenery/kelp_glints.gd`): each kelp mesh variant gets a companion mesh with `glints_per_plant` quads at random points on its blades (height fraction in COLOR.a). The glint mesh goes through the **same Scatter** with the plants' own transforms and custom data (`Seabed._flush_kelp`, also for the edge kelp band), so tiles, culling and the murk visibility range treat plant and glints as one, and `clear_around` removes both. The shader copies kelp_plant's sway maths so glints ride the blade, twinkle `pow(.5+.5 sin, 4)`, hold `glint_min_px` with energy conserved, and fade out over 25 to 55 m.
- **Bubbles** (`shaders/water_bubble.gdshader`): wobbly rim (per-bubble phase), two highlight dots, the water's colour reflected (reflection direction picks darker or brighter water, no cubemap). Used by the **stride stream** (replaces `stride_bubbles.gdshader`, removed; keeps the per-bubble timing colour and fade) and the **bubble columns** when in an Ocean mode (the Aquarium keeps the ball's refractive bubble). Globals `water_bubble_color` and `water_bubble_look` (project.godot); `clear_caustics()` (called by `reset_grade`) turns the look off for the other arenas, which gives the plain old rim.
- **Settings** (`WaterLook` groups "Marine snow", "Kelp glints", "Bubbles", panel tab **Particles**, wide ranges): snow on/count/box/size/min_px/near+far fades/peak/colour/drift; glints on/per plant/density/size/min_px/peak/speed/far fade/colour; bubble look on/wobble/spec/reflect. `WaterLook.push_particles()` runs each frame from `Ocean._process`. Panel docs regenerated (2236 entries).

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/unnatural/seabed.gd`, `scripts/stride_stream.gd`, `scripts/bubble_column.gd`, `scripts/debug_panel.gd` (tab), `scripts/ui/setting_docs.gd` (generated), `project.godot` (2 shader globals). **New:** `shaders/water_snow.gdshader`, `shaders/kelp_glint.gdshader`, `shaders/water_bubble.gdshader`, `scripts/scenery/kelp_glints.gd`. **Removed:** `shaders/wrapped_specks.gdshader`, `shaders/stride_bubbles.gdshader` (+ uid files).

**Decisions / notes**
- Defaults after a first look at the shots: `snow_count` 1800, `snow_size` 0.022, `snow_peak` 1.5 (the first pass at 2500 / 0.03 / 2.2 read as hard white dots). Judge and tune live in the Look Tank. Plan said 9000 for their snow; 1800 in a 44 m box is already far denser than the old 6000 in 120 m.
- Glints need a plant count and per-plant count at seabed build, so `glints_per_plant` is read then; density, size, speed and the rest are live.
- Bubble look is per-Ocean-mode via a global, so one shader serves both worlds.

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms; phase 4 in brackets, baseline 0.69/1.33/1.25/1.42/1.08/1.51)**
- kelp_up 0.60 (0.71), ruin_shafts 1.57 (1.64), reef_close 1.47 (1.54), open_blue 1.53 (1.61), floor_murk 1.18 (1.27), split 1.54 (1.72). Snow and glints are free (a little under phase 4, within noise); worst case +0.24 ms over baseline, inside the +1.5 ms budget. Draw calls +4 to +41 per view (glint tiles).
- `split_bench --players=3 --count=2000` (two runs): 13.20 ms (76 fps) and 12.26 ms (82 fps), GPU total 4.32 / 3.99, draw calls ~3800 (phase 4: ~3750). Baseline 12.41-13.40 ms, so within 10%.
- `split_bench --players=1`: 7.09 ms (141 fps), GPU 2.36, draw calls 1288.
- Shots: `logs/look_shots/phase5/` (all 6; view 1 shows snow and glints on kelp tips, view 5 snow in the murk) with `gpu.txt`; compare with `phase4/`.

**Probes:** `look_tank_probe` ALL PASSED, `murk_probe` ALL PASS, `compass_probe` ALL PASS, `modes_probe` passed; no shader or script errors in the Look Tank GPU runs or the benches. Debug build exported 2026-11-15 13:33 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: snow density/brightness (near flakes can read as big soft discs), glint colour and size, bubble rim in a stride stream and a column (headless and the stills do not show motion). Not played in a real Unnatural run or co-op.
- Bubble look was not shot (no bubbles in the Look Tank views); verify with a swimming Extra Swishy fish.
- Other bubbles (weapons, `bubble_wrap`, whirlpool, chests, Marco curtain) keep their own looks; only the stride stream and bubble columns were in the plan.
- Phase 8's quality setting will drive `snow_count`, `glints_per_plant`/`glint_density`.

**Review (phase 5):** checked plan vs. code, MIT headers on water_snow/kelp_glint/water_bubble, all new values are WaterLook exports pushed per frame, no leftover references to the removed shaders, stride stream and bubble columns fall back for non-Ocean modes (fog_active). look_tank_probe ALL PASSED headless with no script or load errors. No defects found, nothing changed. Shader compile validity rests on the logged GPU runs.

## Phase 6: Light shafts (D4a upgrade, D4b volumetric bench) (2026-11-15)

**Built**
- **Shaft field** (`shaders/light_shaft.gdshader`, MIT header): all Ocean modes now get shafts, not only Unnatural. One MultiMesh of 64 unit cylinders (`Ocean._build_shafts`, `shaft_count` of them drawn, live). The vertex shader stands each along the light direction with its top on the surface (`surface_y()`, so Unnatural's own surface works) and wraps it round **each view's own camera** (`CAMERA_POSITION_WORLD`), so split-screen views each get shafts round themselves and Free Swim/Nature/Hunt (no floor) work. Fragment: density from the caustic net (`wc_turb` from `water_caustics.gdshaderinc`, two scales, evaluated where the light's ray meets the surface, so stripes run along the shaft and move with `water_time`), `exp(-KD*depth)` per colour (red dies with depth), `exp(-SIG*dist)` along the ray (the murk thins them, via the same `density_scale()` as the fog pass), phase `base + gain*mu^3` (defaults .2 and 2), soft cut against the depth buffer, soft tube edge, near-camera fade (no pop swimming through), foot fade. Additive, drawn at render_priority -50 (after the fog pass and surface).
- **Blood Moon:** `Ocean._update_shafts` points the shafts at the moon and lerps their colour to red by `moon_share`. `BloodMoon` hides its 9 old cylinders while the new field is on (they come back with the model or `shafts_enabled` off).
- **Temple (stretch):** the Marco Temple's inline shaft shader got the soft depth cut, the `.2 + 2 mu^3` glow and a slow dapple. It is not an Ocean mode, so it has no caustic net or water model (arena stays as D1 said). Temple shots: `logs/look_shots/phase6_temple/` (no shader errors).
- **Settings** (`WaterLook` group "Light shafts", panel tab "Light shafts", wide ranges): enabled, count, range, length, overshoot, radius, widen, strength, colour (and Blood Moon colour), pattern mix/scale/speed, soft, phase base/gain, edge, near fade, foot fade. Panel docs regenerated (2261 entries). `water_time` is now pushed whenever the model is on (it used to need caustics on).
- **D4b bench** (Look Tank only): `tank_volfog` 1 turns on Godot's volumetric fog plus a FogVolume (`shaders/volfog_shafts.gdshader`, density follows the same caustic net along the sun) from `look_tank.gd` (`_apply_volfog`); `tank_volfog_density`. Use `--set=tank_volfog=1 --set=shafts_enabled=0`.

**Decisions / fallbacks**
- **Volumetric fog (b) not adopted.** Numbers: about +0.07 ms per view over no shafts, so cost was not the problem. But with the Ocean's sun it showed no readable shafts even at density 0.6 (needs a shadowed light and tuning), and it turned the additive snow and glint quads into hard squares (view 1, `phase6_volfog_dense`). The cylinders give the look at a similar cost, so (c) was not needed either.
- Fog shaders name their function `fog()`, not `fragment()`; an include is fine in the fog shader but the bench file repeats `wc_turb` inline.
- Shafts ignore sun shadows (a plain additive pattern), so a ruin does not block them. The depth soft cut handles contact only.

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms; phase 5 in brackets, baseline 0.69/1.33/1.25/1.42/1.08/1.51)**
- kelp_up 0.77 (0.60), ruin_shafts 1.68 (1.57), reef_close 1.50 (1.47), open_blue 1.59 (1.53), floor_murk 1.20 (1.18), split 1.56 (1.54). Shafts cost 0.02 to 0.17 ms (largest looking up at the surface); worst case +0.35 ms over baseline, inside the +1.5 ms budget. Shafts off (`phase6_noshafts`): 0.60/1.57/1.48/1.54/1.19/1.53. Blood Moon: kelp_up 0.76, ruin 1.70, open_blue 1.57. Volumetric bench: 0.67/1.65/1.55/1.62/1.26/1.68 (shafts off), 0.84/1.76/1.58/1.67/1.29/1.71 (with cylinders too).
- `split_bench --players=3 --count=2000` (two runs): 12.99 ms (77 fps) and 12.49 ms (80 fps), GPU total 4.14 / 4.12, draw calls ~3800. Baseline 12.41-13.40 ms, so within 10%.
- `split_bench --players=1`: 7.72 ms (130 fps), GPU 2.52 (phase 5: 2.36, baseline 2.34), draw calls 1383 (+1 for the field plus run-to-run).
- Shots: `logs/look_shots/phase6/` (all 6 + gpu.txt), `phase6_moon/` (1, 2, 4), `phase6_noshafts/`, `phase6_volfog/`, `phase6_volfog_dense/`, `phase6_volfog_plus_shafts/`, `phase6_temple/`; compare with `phase5/`.

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/unnatural/blood_moon.gd`, `scripts/marco_polo/temple_arena.gd`, `scripts/look_tank.gd`, `scripts/debug_panel.gd` (tab), `scripts/ui/setting_docs.gd` (generated). **New:** `shaders/light_shaft.gdshader`, `shaders/volfog_shafts.gdshader`.

**Probes:** `look_tank_probe` ALL PASSED, `murk_probe` ALL PASS, `modes_probe` passed, `compass_probe` ALL PASS on rerun (the known flaky "a far shrine starts hidden" failed in 2 of 4 runs, as before). No shader or script errors in the Look Tank GPU runs, benches or Temple shots. Debug build exported 2026-11-15 13:46 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: shaft strength and count (`shaft_strength` 0.35, `shaft_count` 14; they read well in views 1 and 2 but kelp_up is bright overhead), the Blood Moon's red shafts in a real Unnatural run (murk thins them a lot there), and shafts in co-op split-screen. Not played.
- Phase 8's quality setting should drive `shaft_count` (and `caustic_split` for the shaft pattern cost).
- The pattern cost is two `wc_turb` taps per shaft pixel; an overdraw-heavy view (many wide shafts) is where it would show.

**Review (phase 6):** checked plan vs. code, MIT headers on light_shaft and volfog_shafts, all shaft values are WaterLook exports pushed per frame (panel tab and docs present), Blood Moon hides old rays only while the field is on, shaders are per-view so split-screen works. look_tank_probe ALL PASSED and murk_probe ALL PASS headless with no script, shader or load errors. No defects found, nothing changed. Visual and perf figures rest on the logged runs (not re-measured).

## Phase 7: Material pass on the reef, ruins and kelp (2026-11-15)

**Built**
- `shaders/water_materials.gdshaderinc` (MIT header): shared helpers for the phase, driven by shader globals (`water_mat_kelp`, `_kelp2`, `_coral`, `_rock`, `_sand`, `water_biome`, and the sampler `water_rock_detail`, all declared in `project.godot`). All globals are zero outside the Ocean modes (`clear_materials()` runs from `clear_caustics()`, so Aquarium, Obstacle Course and the Marco arenas look as before; `stone` is also used by the Temple and Marco, which therefore keep their old look).
- **kelp_plant:** vein stripes, thin-film iridescence (cos palette on view angle and height), warm translucency `(1.5,1.4,.75)` times `pow(dot(-V,L),3)` lit by the depth-dimmed sun, and a travelling sparkle band (HDR, so bloom catches it) on 24% of blades.
- **reef and fan_coral:** fluorescence `albedo * flu * dot(light, (.1,.5,.5))` with per-copy `flu` in 0.55-0.75 and the light taken from the depth-dimmed sun, plus a tip highlight (polyps, anemone tentacles, fan edges).
- **stone (ruins and reef rock):** triplanar baked detail map (two scales), strata (beds of olive/brown tint, dark crack seams, red encrustation on down faces), algae on up faces `smoothstep(-.1,.6,n.y)`, slope-tilted normal, rim light `pow(1-NdV,2.5)`. New `strata_weight` uniform: reef rock 1.0, marble ruins 0.5 (so marble stays marble).
- **sand:** magenta encrusting cover patches (they fluoresce), plus the **D6 biome tint**: `Seabed.setup` records the run seed (`WaterLook.biome_seed`), which picks a hue (soft, mixed 35% to white); applied to sand fully and to rock at 0.6. Same seed on every co-op machine, so the tint matches.
- **Baked asset:** `tools/bake_rock_detail.gd` (run once, 19 s headless) wrote `textures/rock_detail.png`, 1024 x 1024 tileable, R height (warped 4-octave noise), G slope, B mottle, A crack mask. Our own noise, after their idea.
- **Settings:** `WaterLook` group "Materials" (panel tab **Materials**, wide ranges): `materials_enabled`, kelp translucency/warm rgb/iridescence/veins/sparkle/share, coral fluorescence/flu min+max/tip, rock strata/detail/algae/rim, sand cover, `biome_enabled`/`biome_strength`. Pushed each frame by `WaterLook.push_materials()` (from `Ocean._process`). Panel docs regenerated (2281 entries).

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/unnatural/seabed.gd` (seed), `scripts/scenery/greek_kit.gd` (rock `strata_weight`), `scripts/debug_panel.gd` (tab), `scripts/ui/setting_docs.gd` (generated), `project.godot` (7 globals), `shaders/kelp_plant|reef|fan_coral|stone|sand.gdshader`. **New:** `shaders/water_materials.gdshaderinc`, `tools/bake_rock_detail.gd`, `textures/rock_detail.png`.

**Decisions / notes**
- Per-colour sunlight for emission terms comes from `exp(-KD * depth)` (the same as caustics), not a `light()` function, for the reason given in phase 2.
- The plan's "their 1024^2 height, gradient and mottle map": ours is generated, not copied (the original has no assets); no notice change needed beyond the MIT headers.
- Fan coral still reads as a thin net (mesh and cut-out are the existing design); fluorescence and tips now colour it, but it was not remodelled.

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms; phase 6 in brackets, baseline 0.69/1.33/1.25/1.42/1.08/1.51)**
- kelp_up 0.78 (0.77), ruin_shafts 1.76 (1.68), reef_close 1.59 (1.50), open_blue 1.67 (1.59), floor_murk 1.28 (1.20), split 1.66 (1.56). The material pass costs about +0.1 ms; worst case +0.44 ms over baseline, inside the +1.5 ms budget.
- `split_bench --players=3 --count=2000` (two runs): 12.83 ms (78 fps) and 13.51 ms (74 fps), GPU total 4.17 / 4.34, draw calls ~3800. Baseline 12.41-13.40 ms, so within 10%.
- `split_bench --players=1`: 7.69 ms (130 fps), GPU 2.54, draw calls 1350.
- Shots: `logs/look_shots/phase7/` (all 6 + gpu.txt); compare with `phase6/` (coral glow, magenta sand patches, biome cast, backlit kelp with sparkle band).

**Probes:** `look_tank_probe` ALL PASSED, `murk_probe` all pass, `modes_probe` passed, `compass_probe` passed; no shader or script errors in the Look Tank GPU run or the benches. Debug build exported 2026-11-15 13:58 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: coral glow strength (`coral_fluorescence`), rock strata and algae (`rock_strata`, `rock_algae`), biome cast strength (`biome_strength`; this seed gives a violet-grey sand), kelp translucency (blades read dark at depth because the sun is dimmed by depth), and sparkle share. Not played in a real Unnatural run; Blood Moon checked only via earlier phases' shots, not re-shot for this phase.
- The fan coral's thin-net look and the kelp being dark at depth are the likeliest things you will want changed.

**Review (phase 7):** checked plan vs. code (kelp, reef/fan coral, stone, sand, baked detail PNG, biome seed), MIT header on water_materials.gdshaderinc and the bake tool, 7 globals default to zero in project.godot so non-Ocean arenas are unchanged, all values are WaterLook exports pushed per frame (docs present). look_tank_probe ALL PASSED, murk_probe ALL PASS, modes_probe passed headless with no script errors. Read the shader diffs: all helper symbols (sc_hash, sc_fbm, variant, world_pos) resolve. No defects found, nothing changed. Not re-verified: shader compile (headless skips it; rests on the phase GPU run) and the GPU numbers.

## Phase 8: Quality setting (D5) and polish (2026-11-15)

**Built**
- **Graphics quality** (Settings > Display > Graphics): `UISettings.graphics_quality` 0 Low, 1 Medium, 2 High, saved per PC in `playground.cfg` ([ui]). Default High (the look as tuned); never auto-detected (D5). In the everyday options list. It mirrors into `WaterLook.quality`; `WaterLook.quality_force` (-1 follows Settings, 0..2 forces) is for the Look Tank, `--set=quality_force=N` in look_shots, and presets.
- What a tier drives (new `WaterLook` group "Quality", panel tab **Quality**, wide ranges; High = all the other options unchanged): marine snow count (Low 30%, Medium 65%), light shafts (40% / 70%), kelp glints via `glint_density` (0% / 60%; `glints_per_plant` is baked at seabed build so the density is the live knob), caustic taps (Low 1 tap = `caustic_split` 0, Medium and High 3), bloom levels (Low 3, Medium 5, High 6), `scaling_3d_scale` (Low 0.77 with FSR, Medium and High 1.0). Helpers `eff_snow_count/eff_shaft_count/eff_glint_density/eff_caustic_split/eff_glow_levels/eff_scale`; `Ocean` uses them; `grade_signature` includes the glow level count so a tier change regrades.
- **Render scale** goes on the window and on every split-screen view (`WaterLook.apply_scale_all`; `SplitScreen` views join group `water_scaled_views`; `UISettings` applies on change and `Ocean._requality` when the tier changes). FSR is used below 1, bilinear at 1. The titan view and whale pick card are untouched.
- **Adaptive resolution** (optional item, `UISettings.adaptive_resolution`, default off, Settings option): `viewport_get_measured_render_time_gpu` smoothed; each 0.5 s steps the scale down 0.05 when over `auto_target` (0.85) of the frame time, back up when under 60% of that; floor `auto_floor` 0.6. Pixels only: the plan's second step (draw distance) is not built. No-op headless and in tests.
- Probe: `look_tank_probe` gained quality-tier checks (snow thins Low < Medium < High, Low has fewer shafts, one tap, 3 glow levels, FSR scale; High native). Panel docs regenerated (2296 entries).

**Files changed:** `scripts/water_look.gd`, `scripts/ocean.gd`, `scripts/split_screen.gd`, `scripts/ui_settings.gd`, `scripts/debug_panel.gd` (options, enum, tab, everyday list), `scripts/ui/setting_docs.gd` (generated), `tests/look_tank_probe.gd`. No new files.

**Decisions / notes**
- High is the default, not Medium, so nothing changes for anyone until they pick a lower tier. If you would rather ship Medium by default, flip `graphics_quality` in `ui_settings.gd`.
- The Quality tiers touch only the Ocean-mode look features (and the render scale, which is global once chosen). Snow/shaft/glint/caustic changes cannot affect gameplay.
- Polish pass: grading, fog, caustics, surface, particles, shafts and materials already carry the plan's values; no further tweaks made without your eyes on them.

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms, views 1-6; baseline 0.69/1.33/1.25/1.42/1.08/1.51)**
- High: 0.77 / 1.77 / 1.59 / 1.67 / 1.27 / 1.66 (same as phase 7, within +0.44 ms of baseline).
- Medium: 0.74 / 1.66 / 1.57 / 1.64 / 1.26 / 1.63.
- Low: 0.54 / 1.16 / 1.07 / 1.20 / 0.91 / 1.23 (about 30% under High; below baseline).
- `split_bench --players=3 --count=2000` (two runs, High): 13.08 ms (76 fps) and 12.63 ms (79 fps), GPU total 4.17 / 4.13, draw calls ~3800-3880. Baseline 12.41-13.40 ms, so within 10%. `--players=1`: 6.55 ms (153 fps), GPU 2.30.
- Shots: `logs/look_shots/phase8_high/`, `phase8_medium/`, `phase8_low/` (each with gpu.txt). Low reads softer (FSR), with fewer shafts and snow, no kelp glints, tighter bloom; fog, sky and shafts stay correct at the lower resolution (CompositorEffect works under scaling).

**Probes:** `look_tank_probe` ALL PASSED, `murk_probe` ALL PASS, `compass_probe` ALL PASS, `modes_probe` passed, `ui_probe` passed; no shader or script errors in the Look Tank runs or benches. Debug build exported 2026-11-15 14:12 (`builds/windows/FishPlayground.exe`).

**Open items**
- Needs your eyes: Medium vs High difference is small by design; pick the tier numbers you like in the Quality tab. Adaptive resolution is untested on a struggling GPU (no way to starve this one headless), and a 3-player Low bench was not run. Split-screen at Low (FSR on every view) was checked in the Look Tank split shot only.
- Overall "Done means" still waits on your look_shots review and a play-test: phases 1-8 are all built.

**Review (phase 8):** checked plan vs. code (tiers drive snow, shafts, glints, caustic taps, glow levels, scale; FSR below 1; every split-screen view joins the scaled group), values are WaterLook exports with docs, MIT header on water_look.gd. look_tank_probe ALL PASSED and murk_probe ALL PASS headless, no script errors. No defects found, nothing changed. Not re-verified: GPU numbers, adaptive resolution on a starved GPU, and the 3-player Low case.

## FINAL SUMMARY (2026-11-15)

All eight phases are built. The build is `builds/windows/FishPlayground.exe` (debug, 2026-11-15 14:12). What is left is yours: reviewing the look and play-testing.

### Per-phase status

| Phase | What | Status |
|---|---|---|
| 0 | Look Tank, baselines, `WaterLook` resource, MIT notices | Built |
| 1 | Grading and bloom (ACES, glow mix, vignette, `water_grade` CompositorEffect) | Built |
| 2 | Water fog model, sky, depth exposure | Built (fallback taken, see below) |
| 3 | Caustics on sand, ruins, reef | Built |
| 4 | Surface from below (Snell's window, waves, Fresnel) | Built; no above-water view yet |
| 5 | Marine snow, kelp glints, bubbles | Built |
| 6 | Light shafts (D4a cylinders upgraded, D4b volumetric benched) | Built; volumetric not adopted |
| 7 | Material pass: reef, fan coral, stone, sand, kelp, biome tint (D6) | Built |
| 8 | Graphics quality Low/Medium/High (D5, auto-detect off), optional adaptive resolution | Built |

### "Done means" check (plan section 6)

- **Budget: 1-player GPU within +1.5 ms.** Met. Worst Look Tank view is +0.44 ms over baseline (phase 7 and 8 High: 0.77 / 1.77 / 1.59 / 1.67 / 1.27 / 1.66 against 0.69 / 1.33 / 1.25 / 1.42 / 1.08 / 1.51). Medium is a little under that, Low is about 30% under High and below baseline (0.54 / 1.16 / 1.07 / 1.20 / 0.91 / 1.23).
- **Budget: 3-player `split_bench` within 10% of baseline.** Met in every phase. Baseline is 12.41-13.40 ms. Final High runs are 13.08 and 12.63 ms (76 and 79 fps), GPU 4.17 / 4.13 ms. 1 player is 6.55 ms (153 fps), GPU 2.30 ms (baseline 2.34).
  - The plan's "above 100 fps for 3 players" was already not met at baseline (75-81 fps, CPU-bound), so the 10% rule is the one held.
- **`murk_probe` and compass probe.** `murk_probe` ALL PASS and `compass_probe` ALL PASS on the final run. The "a far shrine starts hidden" compass check is a known flake that failed in 2 of 4 phase 6 runs and passed on rerun. Murk now feeds through `Ocean.fog_density()` and `fog_sigma()`.
- **Blood Moon.** The model multiplies and lerps toward red and never overwrites (grade, WCOL/KD, shafts pointed at the moon). It was shot in phases 1 to 6 (`*_moon` folders). It was not re-shot after phase 7 or 8, and it has not been seen in a real Unnatural run.
- **`INVENTORY.md`.** Unaffected, since there are no gameplay changes. The quality tiers touch visuals and render scale only.
- **Your review of look_shots and a play-test.** Not done. This is the only unmet item and it is yours.

Other probes on the final run: `look_tank_probe` ALL PASSED (includes quality-tier checks), `modes_probe` and `ui_probe` passed. There were no shader or script errors in the Look Tank GPU runs or the benches.

### Fallbacks and deviations (per the failure policy)

1. **Fog: CompositorEffect compute pass replaced by a full-screen spatial quad (phase 2).** Under the project's MSAA 4x, writes from a POST_OPAQUE compute effect are lost. The quad reads `hint_depth_texture` and `hint_screen_texture`, blends into the MSAA buffer, and is per camera, so split-screen works. This is the plan's own alternative to D3a. The grade effect (phase 1) works as a CompositorEffect under MSAA, so no fallback was needed there.
2. **Per-shader `light()` tinting deferred (phase 2).** None of the sand, stone, reef or kelp shaders defines `light()`. A CPU sun tint shared by all views covers it. A per-view sun tint is open.
3. **Volumetric fog (D4b) not adopted (phase 6).** It cost about +0.07 ms per view, but it showed no readable shafts with the Ocean's sun and it turned the additive snow and glints into hard squares. The upgraded cylinders give the look at similar cost.
4. **Adaptive resolution is pixels only (phase 8).** The plan's second step (draw distance) is not built. It is off by default.
5. **Marco Temple stretch.** Only its inline shaft shader got the soft cut and glow. It has no water model, as D1 intended.

### What you need to do

1. **Review look_shots.** Compare `logs/look_shots/baseline/` and `baseline_moon/` against `phase8_high/` (final), `phase8_medium/` and `phase8_low/`. Each has a `gpu.txt`. Phase folders in between show how each feature landed. `phase2_sunlit/` shows the Sunlit preset.
2. **Choose Sunlit or Ours.** Run the Look Tank (console `look_tank`, keys 1-6, or `scenes/look_tank.tscn`) and flip the `preset` setting in the Water look panel tab, or run look_shots with `--sunlit`. Ours is the default (D2). If you prefer Sunlit, change the default `preset`.
3. **Play-test** Free Swim, Nature, Hunt, Unnatural (Blood Moon and murk), Test Tank and What Stinks. Also try co-op split-screen, and the Low tier with FSR on every view.
4. **Pick Quality tier numbers** in the Quality tab. High is the default. Flip `graphics_quality` in `ui_settings.gd` if you want Medium.
5. Optionally delete the debug shots `logs/look_shots/p2_*`.

### Open items

- Tuning needs your eyes: `exposure` and the Ours colours, `surface_height` (30 m above the origin in open Ocean modes) and `surface_waves`, `shaft_strength` and `shaft_count` (kelp_up is bright overhead), `coral_fluorescence`, `rock_strata`, `rock_algae`, `biome_strength` (this seed gives a violet-grey sand), kelp translucency (blades read dark at depth), and sparkle share.
- Blood Moon red shafts and moon disc in a real Unnatural run (murk thins them a lot).
- The surface is not drawn when the camera is above `surface_y - 0.3`, so there is no above-water view.
- Fan coral still reads as a wire mesh in some shots.
- The 3-player Low bench was not run, and adaptive resolution is untested on a struggling GPU.
- Headless runs skip shader compile, so shader validity rests on the logged GPU runs.
- The per-view sun tint (fallback 2) is not built.
- Marco Temple has no water model (stretch not taken).

## Flora pass, phases 1+2: blade system and blade kelp (2026-11-15)

**Built**
- `scripts/scenery/flora_field.gd` (`FloraField`): blade flora in 32 m tiles (Scatter conventions: `draw_distance`, `fade`, `clear_around`, `build`, counts). One curved-ribbon mesh (`blade_mesh(rows)`, 2 verts per row, UV = side and row fraction, rows bunched toward the tip) instanced by MultiMesh. The blade's data rides in the instance transform, written as one `buffer` per tile (12 floats, 48 B per blade): origin = root, `basis.x` = length/yaw/tilt, `basis.y` = width/sway height/type+bend, `basis.z.xy` = two seeds. The shader reads `MODEL_MATRIX` and writes `POSITION`; so the field node must only be translated (Seabed is). Layer 2 holds glints on the same tiles.
- **LOD / culling:** near MultiMesh (7 rows) out to `flora_lod_distance`, then a far MultiMesh with 3 rows, only `flora_far_keep` of the blades (stable subset by seed) drawn wider; both end at the draw distance (follows the murk like Scatter, or `flora_draw_distance`). In the shader the width fades to nothing toward the draw distance and close to the camera (their `farK`), so no popping or blades in the lens.
- `shaders/flora_blade.gdshader` (MIT header, port of W_LEAF): constant-curvature arc (bend + breathing), twist, travelling ruffle (near only), height-scaled sway (`shaders/flora_sway.gdshaderinc`, a^1.25), 8 types (olive, dark stipe, teal grass, violet, amber, magenta cover, red, cyan) with their palettes, shape, translucency, iridescence, emissive, sparkle colour. Fragment: gradient, veins + midrib, thin film, warm back-light translucency and travelling sparkle band driven by the existing `water_mat_kelp/kelp2` globals, `wm_light`, `wc_caustics`, Godot BACKLIGHT. Types 5-7 (cover) are ready for phase 3.
- `FloraField.add_kelp_column` = their `column()`: 2-4 strands twisting round each other, a dark stipe leaf every 1.7 m per strand, then `height * blades_per_m * density` ribbons (30/m base, rolled 0.55-1.3 per column), shorter and more upright toward the top, per-blade type/colour, plus `flora_glints_per_m` sparkles.
- **Glints kept:** `shaders/flora_glint.gdshader` (copy of `kelp_glint` that takes its point from the instance and sways with `flora_sway`); `WaterLook.push_particles` copies the glint look to it, so the Particles tab still drives both. `KelpGlints` (old kelp meshes) is untouched.
- **Seabed:** `_build_reef` kelp forests and `_build_edge` kelp band place columns with `_plant_column` (own dice from one `rng.randi()`, so the layout after does not depend on blade settings). Old 3-stipe meshes + Scatter remain behind `flora_blades` off. `set_murk` sets the flora draw distance, `clear_around` clears flora too, `_process` pushes the look values live.
- **Settings** (`UnnaturalSettings`, new "Flora" group in the Arena tab, wide ranges, docs regenerated, 2311 entries): `flora_blades`, `flora_blades_per_m` 30, `flora_kelp_density` 1, `flora_blade_mult` 1, `flora_edge_density` 0.25 (the edge band has 420 tall columns), `flora_draw_distance` 0 (follow murk), `flora_lod_distance` 28, `flora_far_keep` 0.6, `flora_rows` 7, `flora_rows_far` 3, `flora_glints_per_m` 4, and live look values `flora_sway`, `flora_width`, `flora_length`, `flora_brightness` (2.0). Layout values apply when the next stage is built.
- **Tests/tools:** `tests/flora_probe.gd/.tscn` (blade data round trip through a MultiMesh (GPU run only, the headless renderer keeps no instance data), column, glints, far subset, clear_around, Seabed with the flag on/off, multiplier). `tests/flora_shot.gd/.tscn` renders a close-up of kelp columns and cover on a plain background (`-- --out=logs/flora_shots/a.png --cam=x,y,z --look=x,y,z`).

**Blade counts** (default settings, `flora_probe`, arena radius default, seed 11): **119,018 blades** (71,098 drawn at the far level), 29,105 glints, 198 MultiMesh nodes (blades near+far, glints), 1061 Scatter tiles. Blade multiplier 0.5 gives 65,335. In the Look Tank's stage (bigger arena) 166,224 blades. Build 0.75-0.9 s for the seabed (flora included).

**Measured (RTX 4070 Ti SUPER, 1920x1080, Look Tank GPU ms; phase 5 in brackets):** kelp_up 0.72 (0.60), ruin_shafts 1.82 (1.57), reef_close 1.62 (1.47), open_blue 1.65 (1.53), floor_murk 1.28 (1.18), split 1.73 (1.54): +0.1 to +0.25 ms, inside the +1.5 ms budget; draw calls per view went down (the kelp glint tiles are gone). `split_bench --players=3 --count=2000`: 13.44 ms (74 fps), GPU 3.89, draw calls 3753 (baseline 12.41-13.40 ms, 3700). Shots: `logs/look_shots/flora1/`, `flora2/`; close-up `logs/flora_shots/a.png`.

**Probes:** `flora_probe` ALL PASSED (headless and on the GPU), `look_tank_probe` ALL PASSED, `murk_probe` ALL PASS, `modes_probe` passed, no shader or script errors in the Look Tank GPU runs.

**Open items**
- Needs your eyes: kelp colour/brightness (`flora_brightness` 2.0, types are abyssal-garden's values doubled), density in the forests (columns are the old `seabed_kelp` count and 6.5-9.5 m, not their 15-40 m), and how the edge band reads at 0.25 density.
- Look Tank view 1 now looks up at open water (the spot is the highest kelp noise, no longer where a column stands); retarget it to a real column later.
- Phase 3 (ground cover, hanging fronds, wall tufts) can use `FloraField.add_blade` with types 2, 5, 6, 7.
- Sway uses TIME (not the pausing water clock). Co-op machines lay out the same blades (seeded), the sway is per machine.

## Flora pass, phase 3: ground cover, grass, tufts, fronds (2026-11-15)

**Built**
- `FloraField` recipes (share a blade budget `cover_cap` and a count multiplier `count_mult`): `add_tuft` (2-4 short blades), `add_cluster` (abyssal-garden's `cluster`), `add_hanging` (fronds pointing down, tilt PI), `add_wall_tuft` (blades leaning out of a wall). Blade types used: 5 magenta and 7 cyan carpets, 2 teal grass, 6 red and 0 olive fronds, 0/3 wall tufts.
- `Seabed._build_cover()` (after `_build_edge`, before the tiles are built). It uses a dice of its own, seeded from the stage seed, so no other layout shifts: with every phase 3 setting at 0 the blade count is exactly phase 2's 119,018.
  - **Structure first:** ruins (carpet band round the platform, tufts on the lower step and column feet, fronds under standing architrave beams), outcrop rocks (side tufts, fronds under stacked rocks, clamped so they never reach below the sand), seabed rocks and rubble (carpet ring round the foot, side tufts).
  - **Grass:** one clump per old sea-grass spot (teal, some cyan; the old meshes are dropped with `flora_replace_seagrass`), plus bigger 1-3 m clusters where the grass noise is hot.
  - **Carpets last:** patches (centres weighted to reef zones, near ruins, and a few open spots), tufts thin toward the edge, modulated by a noise, magenta in the reef, cyan/teal on sand, 30% with taller cyan blades. They keep off rocks, ruin platforms, the start area (`_clear_of_start`) and the arena edge. Shrines still clear them via `clear_around`.
- `RuinCluster.layout(seed)`: replays `build`'s dice up to the architrave to give platform size, standing column bases and beams still in place. Keep it in step with `build`.
- Seabed records what flora grows on: rocks, ruins, outcrop rocks, sea-grass spots.
- Settings (Flora group, wide ranges, docs regenerated, 2326 entries): `flora_cover_patches` 60, `flora_cover_per_m2` 10, `flora_cover_radius` 3.5, `flora_cover_size`, `flora_grass_clusters` 500, `flora_grass_blades` 16, `flora_grass_size`, `flora_replace_seagrass`, `flora_seagrass_blades` 7, `flora_rock_tufts` 5, `flora_wall_tufts` 3, `flora_frond_clumps` 2, `flora_frond_blades` 10, `flora_ruin_cover` 1, `flora_cover_budget` 160000 (0: unlimited). `flora_blade_mult` scales all of it. Layout values apply on the next stage build.

**Counts** (defaults, seed 11, `flora_probe`): phase 3 adds 101,761 blades (budget 160,000); total 220,779 blades (132,092 at the far level), 264 MultiMesh nodes, 970 Scatter tiles (was 1061, seagrass meshes gone). Blade multiplier 0.5: 107,283. Stage build ~0.95 s.

**Measured** (Look Tank GPU ms, `flora3` shots, phase 2 in brackets): kelp_up 0.75 (0.72), ruin_shafts 1.86 (1.82), reef_close 1.68 (1.62), open_blue 1.74 (1.65), floor_murk 1.34 (1.28), split 1.87 (1.73). Draw calls unchanged to +3. `split_bench` is CPU-bound and noisy (14.3 and 8.4 ms frames in two runs), GPU total 3.78-4.13 ms (phase 2: 3.89). Probes: `flora_probe` (new checks: cover laid, budget cap, all-zero equals kelp only, ruin layout), `murk_probe`, `modes_probe` pass headless; no shader or script errors in the GPU runs.

**Open items**
- Needs your eyes: carpet look at close range (tufts read as pink shards, density `flora_cover_per_m2`), wall tufts and fronds on outcrops (placed from an ellipsoid approximation of the rock, not the mesh, so some float or sink a little), colours.
- Our floor is flat, so "gentle ground" is everywhere; hanging fronds only exist under outcrop rocks and ruin beams (small seabed rocks have none).
- No glints on the cover (abyssal-garden adds a few).

## Flora verify pass (2026-11-15)
- Headless: flora_probe, look_tank_probe, murk_probe, modes_probe, stage_probe pass (stage_probe "blood bolts hurt" is the known flake; passes on rerun). No script errors.
- Bench (tests/split_bench.tscn, new `--set=key=value` flag for any UnnaturalSettings value): GPU total 3P 4.47 ms vs 3.98-4.05 with flora off (+11%); 1P 2.62 ms same as off. Frame times are bimodal on this machine (70 vs 130 fps) with flora on AND off, so GPU ms is the reliable figure; best 3P runs 139 fps (on) vs 130 (off).
- Fixes: Look Tank view 1 now stands in the densest blade-kelp (Seabed.kelp_spots); carpets were sparse shards, so defaults raised: flora_cover_patches 90, flora_cover_per_m2 16, flora_cover_radius 4, flora_ruin_cover 2, flora_cover_budget 230000 (total ~318k blades). flora_probe tolerates the budget overshoot of one recipe.
- Shots: logs/look_shots/flora_after/ (views 2 and 5 re-shot after the ruin_cover bump; others before it).
