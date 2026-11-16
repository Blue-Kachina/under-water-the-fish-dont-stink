# PROGRESS: procedural world (planning_procedural_world.md)

Started 2026-11-15. Newest entries at the bottom of each phase. Status key: TODO / WIP / DONE / PARKED.

## Workflow
- Main session owns the native generator (phase 1), the seam (phase 0), the layout + navigability (phase 2) and integration.
- Once the generator exists, independent pieces fan out to background workers with one owner per file (material, light, gameplay/probes, scatter).
- Each phase: build behind `terrain_enabled`, headless probes, timings, then a debug build at the end for play-testing.

## Toolchain notes
- Native build: `cmake-build-debug` + ninja through `vcvars64.bat` (MSVC 14.38). The DLL is copied to `addons/under-water-the-fish-dont-stinkExt/bin/windows/` on build.
- The tree is CMake **Debug**. The terrain source is compiled with per-file optimisation so generation stays fast.

## Status

| Phase | What | Status |
|---|---|---|
| 0 | Settings, ground query API (`Terrain`), Terrain Tank shots | DONE (call sites move in phase 6) |
| 1 | Native `TerrainField`: density, flood fill, surface nets, chunks, collision | DONE |
| 2 | Layout rules + navigability pass (rule N) | DONE (first pass) |
| 3 | Terrain rock material | DONE (first pass) |
| 4 | Terrain-driven scatter | DONE (first pass) |
| 5 | Openness/skylight volume + sun shadow | DONE (first pass) |
| 6 | Gameplay on terrain + terrain_play_probe | DONE (first pass) |
| 7 | Set pieces and life | DONE (first pass) |
| 8 | Quality tiers, other modes, streaming | DONE (first pass; Hunt/Nature floors opt-in) |

## Log

### 2026-11-15
- Read the plan. Confirmed the GDExtension builds (it only held the template ExampleClass until now).
- Both Unnatural (`unnatural_run._build_seabed`) and What Stinks (`_build_floor`) lay their floor through `Seabed`, so terrain is built by `Seabed` and both modes get it.
- **Phase 1 built.** `native/.../src/terrain_field.{h,cpp}` (class `TerrainField`, registered in `register_types.cpp`). Integer-hash value noise, fbm, Worley F1, smin/smax; per-column floor/plateau/ring heights, a coarse 3D warp, mesas, arches, tunnels and cavities, erosion and strata near the surface only. It is threaded over z slabs, and every sample is independent, so the output is deterministic.
  - Navigability (rule N) runs natively on exact distance transforms (Felzenszwalb EDT, separable, threaded):
    1. Lips: rock thinner than 2 x `terrain_lip` is rounded off (an opening of the rock).
    2. Specks: rock not joined to the grid's bottom is dropped.
    3. Clearance: the water is opened by a ball of `terrain_clearance` flood-filled from the spawn. Unreachable pockets and slots narrower than the ball fill with rock along the ball's own surface. No sealed caves, no wedge slots, creases rounded.
  - An exact signed distance grid answers the queries: `sdf`, `gradient`, `floor_y`, `headroom`, `open_above`, `is_reachable`, `segment_clear`, `push_out`. `sample_surface` samples the meshed triangles, area-weighted, for scatter.
  - Light bakes are ready for phase 5: `bake_openness` (RG8: R openness, G skylight swept down with a 1-2-1 blur) and `bake_sun_shadow` (the height of the first rock along the sun's line per x, z).
  - Surface nets per 32-cell chunk share borders, so there are no seams. Normals come from field gradients and AO is baked into COLOR.r. Quads below the sand cut (-0.3) and beyond the ring's outer edge are skipped.
- **Timings** (Unnatural, 349 x 61 x 349 cells at 1 m, this machine): columns 10 ms, field 30 ms, nav 210-250 ms, exact distance 55-70 ms (generate ~0.3-0.37 s). Meshing 110-140 ms, node build 150-200 ms. **About 0.65 s per stage**, under the 1.5 s budget, so no threading is needed yet. 260-300k triangles in about 85-90 chunks.
- **Phase 0:** `scripts/terrain/terrain.gd` (`Terrain`) holds the chunk meshes, one StaticBody3D (layer 1) with a trimesh shape per chunk, and the static ground query API. With no terrain it answers for the flat floor: `floor_y(x, z, flat)`, `sdf`, `normal`, `headroom`, `is_open`, `push`, `line_clear`. Settings: the "Terrain" group in UnnaturalSettings, every value with a wide range. `terrain_enabled` stays off until the probes pass.
- **Phase 2:** `scripts/terrain/terrain_layout.gd` rolls the features:
  - 2-3 canyon arcs of joined capsule mesas, plus singles;
  - one grotto (an overhanging mesa with a cavity facing the middle);
  - arches whose holes are at least 2 x clearance tall;
  - radial tunnels through the biggest mesas;
  - plateaus in the outer band and the edge ring.
  - Clearings keep the floor flat round arches, grotto mouths and tunnel ends. The middle stays open (`terrain_open_radius`).
- **Phase 4 (first pass):** `Seabed` builds the Terrain when the setting is on. The reef, ruins, kelp forests and rubble keep to the flat sand (`_flat`, D9). The edge outcrops are dropped (the ring replaces them). `_grow_terrain` dresses the rock from `sample_surface`:
  - kelp on flats with more than 9 m of headroom, as tall as the water allows (15-34 m);
  - fronds under overhangs and wall tufts out of walls;
  - carpets on flats, corals/sponges/anemones on the lower flats, boulders on slopes.
  - Heat comes from noise x hot discs (the grottoes plus 5 rolled ones), and kelp is deduped on a 2.5 m grid.
- `tests/terrain_probe` passes. It covers: the flat fallback, determinism (same seed same checksum, another seed different), build time, chunks and collision, the open middle, the ring is rock, push, line blocking, and rule N over 12 seeds (start reachable, 36 arch/tunnel bores pass a clearance ball).
- `tests/terrain_shots` (needs a window): 7 terrain viewpoints, `--seed=`, `--set=`. First shots are in `logs/terrain_shots/p1_first/`. Mesas and the grotto read as walls with overhangs, and tall kelp stands on the rock. The rock material is flat and too dark (phase 3).

### Phase 7 + 8 (main session)
- **Phase 7 set pieces.** `scripts/terrain/set_pieces.gd` (`SetPieces`) builds MeshKit pieces on the stone shader:
  - a **whale fall** (skull, splayed jaws, a spine of vertebra bulges, ribs, some broken short or fallen flat);
  - a **sunken hull** (two broken shell pieces, double-sided, ribs inside, a mast, rolled and half sunk; beam 8.5-10 m so the clearance ball fits);
  - a **vent field** (4-7 lathed chimneys at least 9 m apart, trailing round GPU-particle bubbles).
  - `TerrainLayout` places each one on a clearing of flat floor in the outer band and keeps later features off it. It also adds **pillars**: slim flared mesas up to the top of the depth band.
  - Rule N collision: the spine and skull, hull shells and chimneys collide. Ribs don't, so nothing wedges between them.
  - The reef, rubble and ruins keep clear of the pieces (`_flat`).
  - Settings: `terrain_whale_falls`, `terrain_hulls`, `terrain_vents`, `terrain_pillars` (1 each).
- **Background life.** `terrain_schools` (3) Nature `School`s of `terrain_school_fish` (24) roam high over the outer band (0.82 x the depth band), above the mesa tops. Shots: `logs/terrain_shots/p7_pieces/` (views 8-10 added to terrain_shots).
- **Phase 8 quality tiers.** `terrain_quality` 0/1/2: 1.5x / 1x / 0.75x the cell (chunks stay ~32 m), and 60% / 100% / 125% of the rock dressing.
- **Phase 8 streaming.** `scripts/terrain/terrain_stream.gd` (`TerrainStream`) builds endless 96 m tiles round a followed node:
  - each tile is its own TerrainField, built on WorkerThreadPool tasks, and its nodes are made on the main thread, one new tile a frame;
  - far tiles are freed;
  - the floor itself is meshed with collision, at a 2 m cell;
  - seams: each tile takes in its 8 neighbours' features and is generated with a one-chunk margin, meshing only its core.
  - Wired into **Free Swim** (`terrain_stream`, on; the mode is off the menus). Settings: `terrain_stream`, `_tile`, `_reach`, `_cell`, `_depth`.
  - `tests/terrain_stream_probe`: params are deterministic, **0 of 168** near-surface edge samples differ between neighbours, 9 tiles in 10 frames, a far tile drops. **30 ms per tile.** Shot: `logs/terrain_shots/p8_stream/stream.png`.
- **Phase 8 other modes (D1c).** `scripts/terrain/ocean_floor.gd` (`OceanFloor`) provides `seabed()` (What Stinks' pattern), `stream()` and `keep_above()`. NatureSettings "Sea Floor":
  - `hunt_floor` gives Hunt a seabed with terrain under its 90 m arena, and keeps fish above it;
  - `nature_floor` gives Nature endless terrain 60 m down;
  - **both are off by default** (opt-in until play-tested).
  - `tests/ocean_floor_probe` passes (Free Swim stream, Hunt off/on with push-up, Nature stream). hunt_probe, nature_probe and modes_probe pass with the defaults.
- Open: streamed tiles have no dressing (kelp, flora) yet, and the Terrain query API doesn't answer for streamed tiles. Hunt's HunterBot and Nature's schools don't know about rock (only matters with the opt-in floors).
- **Stage build time.** Headless, Seabed.setup for a whole stage: **1.85-1.9 s with terrain off** (the existing reef and flora scatter, already over the 1.5 s budget before this work), **2.2 s with terrain on**. Per the build-time decision, `Seabed.prefetch()` now generates the next stage's terrain on a worker thread, and setup() only builds its nodes: **1.83 s after a prefetch**. The play worker is calling it from the stage-clear screen. The flora scatter itself is the bigger cost; it's an open item outside this plan.
- 2026-11-15 evening: the session moved to a new login. The look worker hit the old login's rate limit and was resumed from where it stopped.

### Phase 3 + 5 (look worker)
- **Rock material** (`shaders/terrain_rock.gdshader`): triplanar detail at two scales (fine texture plus coarse lumps; the per-pixel fbm was swapped for a second detail sample), strata beds, violet/teal/ochre mineral crust (magenta-heavy and faintly glowing in grotto zones), algae, sand settling on low flats/drifts/the seam, baked AO from vertex colour, rim, fluorescence, caustics. Zones are pushed from the layout's grottoes each frame by `terrain.gd` (`_push_look`).
- **Light bake** (`scripts/terrain/terrain_light.gd`, `TerrainLight`): runs in `Terrain.apply()` on the main thread (never in prefetch). It builds an RG8 3D openness volume (`TerrainField.bake_openness`: G = sky, R = openness) and an RH sun height map (`bake_sun_shadow`, using WaterLook.sun_dir). Both are global shader params. It is cleared on `_exit_tree`. Timings: volume ~25 ms, shadow ~4 ms, ms_light ~30 ms in all.
- **Shared include** (`shaders/water_openness.gdshaderinc`): `wo_vol / wo_sun / wo_scene / wo_ray_sky`. Users:
  - sand, reef, stone, flora_blade, kelp_plant and fan_coral (`wo_scene`);
  - caustics (`wo_sun`);
  - `wm_light` (sun x shadow x sky, ambient x sky);
  - light shafts (cut by rock);
  - the fog pass (in-scatter darkened along the view ray in grottoes).
- **Fallback:** `terrain_light.w = 0` when no terrain owns a bake: terrain OFF, other modes, and TerrainStream tiles, which have no bake. Every `wo_*` then returns exactly 1.0, so the old look is unchanged by construction. Checked with look_shots `terrain_off_p5` against `rock2`; the diffs come only from animation.
- **Settings** (UnnaturalSettings "Terrain Look", after `terrain_boulders`; 0 switches each off):

  | Setting | Value |
  |---|---|
  | terrain_crust | 0.65 |
  | terrain_crust_glow | 1 |
  | terrain_sand_blend | 1 |
  | terrain_zone_tint | 0.8 |
  | terrain_rock_bright | 1 |
  | terrain_light_enabled | on |
  | terrain_light_cell | 1.5 |
  | terrain_open_reach | 8 |
  | terrain_sky_absorb | 0 |
  | terrain_skylight | 0.7 |
  | terrain_grotto_dark | 0.3 |
  | terrain_sun_shadow | 0.7 |
  | terrain_shadow_cell | 1 |
  | terrain_shadow_soft | 1.5 |
  | terrain_open_ao | 0.3 |
  | terrain_fog_dark | 0.45 |
  | terrain_shaft_cut | 1 |

- **GPU** (terrain_shots, ms per view):

  | Shot set | Times (ms) |
  |---|---|
  | p1_first (before) | 1.67 / 1.70 / 1.67 / 1.59 / 1.87 / 0.97 / 2.34 |
  | p3_e (final) | 1.81 / 1.98 / 2.07 / 2.08 / 2.53 / 1.50 / 2.73 |

  Rock close-ups (p3_d) are 1.6-2.3 ms.
- **Shots:** logs/terrain_shots/p3_a..p3_e, p3_b_nolight; logs/look_shots/terrain_off_p5. Close-up tool: `tests/terrain_rock_shots.tscn`.
- **Probes:** terrain_probe, flora_probe, look_tank_probe and murk_probe all pass.
- **Open items:**
  - The grotto cavity fills with kelp from the scatter, so the "inside" view sits in kelp.
  - Crust colour reads only within ~20 m; fog takes over beyond that.
  - Fish and zombie skins aren't darkened in grottoes.
  - The shadow uses the sun direction at bake time, and the Blood Moon shafts' direction differs slightly.
  - There is no clean pre-change look_shots baseline.

### Phase 6 (play worker)
- **The ground API is in.** `UnnaturalRun` has `ground_y(x, z)` (Terrain.floor_y over the flat seabed), `chest_rest(at)`, `out_of_rock(at, room)`, `ground_open(spot, room)`, `ground_flat(spot, room)` and `_seabed_seed_for(stage)`. Every `arena_floor` user now goes through it:
  - the fish's floor push in `_keep_in_arena`;
  - spawn points (clamped above the ground, pushed out of rock);
  - buried, dropped, boss, Deep and Tide chests (they rest on or sink to the ground under them; buried picks retry off the rock);
  - shrines and the rift (flat sand, room clear of rock);
  - the whirlpool column (from the ground);
  - the rift's throw landing;
  - boss `_keep_in_arena` (floor from the ground, pushed `BOSS_ROCK_ROOM` 3 m out of rock), Fallen Angel lock slots, Whale Fall's floor;
  - survivor bot goals, Test Tank boss spawns.
  - With no terrain every helper answers the flat seabed and picks consume the same rolls, so terrain-off runs are unchanged.
- **Horde:** `Horde._keep_out_of_rock()` runs after steering. It makes one batched `TerrainField.push_out` per step for the zombies due a check (`terrain_horde_check_every`), using each zombie's own radius plus `terrain_horde_room`, and removes the velocity into the rock.
- **Fish don't drive on rock** (`terrain_stick_to_rock`, off by default). Unnatural sets it in `_join` and gives it back in `_leave`. What Stinks sets it in `apply_role`, and `rl_surface_mechanics` was added to its `_player_base`, so it is restored. The follow cam already sweeps against layer 1, so it avoids rock with no change. The octopus crawl ray-casts, so it plants on rock with no change.
- **Bots:** survivor bot goals go round rock (`_around_rock`: `Terrain.line_clear`, headings turned 30-120 degrees; `terrain_bot_sight`).
- **What Stinks:**
  - the floor push follows `Terrain.floor_y`;
  - prey spawns and decoy schools are pushed out of rock (`WhatStinksMatch.clear_of_rock`);
  - shadow spots (kelp stands, arches) retry onto open sand.
  - The terrain builds for its 220 m sphere (ring at 212-236 m, floor 18 m down).
- **Stage-change prefetch:** when a non-last stage's whirlpool opens, `seabed.prefetch(...)` generates the next stage's terrain on a thread.
  - Stage change with terrain on: **about 2.2 s cold, about 1.5 s prefetched** (`terrain_play_probe`). Terrain prepare is about 0.45-0.5 s of that; the rest is the existing seabed and flora.
- **Settings:** group "Terrain Play" in UnnaturalSettings: `terrain_spot_room` 2, `terrain_stick_to_rock` off, `terrain_horde_push` 1, `terrain_horde_room` 0.5, `terrain_horde_check_every` 2, `terrain_bot_sight` on.
- **Tests:**
  - `tests/terrain_play_probe` (all pass) covers a real run over 4 stages: 76 chests/shrines/rifts, none in or under rock; 160 spawn points clear; ground on the middle and the ring; a zombie 11.5 m deep pushed out; boss push; fish swept through arches and tunnels with physics, no wedging; the surface setting restored.
  - `tests/with_terrain.tscn -- --probe=res://tests/X.tscn` runs any probe with terrain on.
  - `powerup_probe`'s chest-height check now uses `run.ground_y`.
- **Probes, off and on:** stage, rift, unnatural_combat, compass, powerup, final_boss, boss_items, chest_multi and the four what_stinks probes pass both ways. The compass "far shrine starts hidden" failure in the first terrain-on run is the known flake; it passed on rerun.
  - `survivor_cam_probe` ("long turn ... 78/79 deg") and `boss_moves_probe` ("in fury ... sucked in, -1.3 m") fail **identically off and on**. With terrain off the new code paths are no-ops, so these are not from terrain.
- **Bench** (`split_bench`, 3 views, 2000 zombies, spread 150): off frame 13.63 ms, GPU 4.52, horde step 3.31 ms. On frame 13.89 ms, GPU 5.46 (+0.94 for the rock in 3 views), horde step 3.41 ms (the rock push costs about 0.1 ms a step). `horde_bench` is Free Swim (no terrain), so it is unchanged.
- **Open items:**
  1. One of 3 arch/tunnel routes in the last probe stage had no clear straight crossing at 0.6 m. The arch axis is rolled at random and the probe tries 2 headings. Worth a look in phase 2 layout.
  2. Boss bodies longer than the head (King coil, Lamprey) only keep their middle out of rock.
  3. The What Stinks hunter start isn't rock-checked; it's the middle, which is open.


### Integration (main, 19:10)
- Grotto kelp: terrain kelp now needs open sky (`open_above` finds no roof), so cavities and overhangs get fronds and tufts, not kelp.
- Setting docs regenerated (2414 descriptions).
- Regression, terrain ON (through `tests/with_terrain.tscn`): terrain_play, stage, rift, unnatural_combat, powerup, chest_multi, final_boss, flora, murk, look_tank, what_stinks, compass all pass. Terrain OFF: terrain, terrain_stream, ocean_floor, modes, hunt, nature all pass.
- **`terrain_enabled` is now ON by default** (the plan's gate: probes pass with it on).
- Debug build 19:10: `builds/windows/FishPlayground.exe`.

### Open items for play-test
- Feel: rock density/heights, grotto darkness, arch/tunnel sizes, crust colours (they fade into fog past ~20 m).
- Streamed tiles (Free Swim, Nature/Hunt floors) have no dressing and the Terrain query API doesn't answer for them.
- HunterBot and Nature schools ignore rock (only matters with the opt-in Hunt/Nature floors).
- Long bosses (King coil, Lamprey): only the body's middle is kept out of rock.
- One of three arch/tunnel routes in a probe stage had no straight clear line through; check arch direction picks.
- Fish/zombie skins aren't darkened inside grottoes; the sun shadow uses the bake-time sun direction.
- Stage build 2.2 s cold / 1.5 s prefetched; the flora scatter is most of it (pre-existing, over the 1.5 s budget).
- Pre-existing failures unrelated to terrain: survivor_cam_probe long-turn angle (78-79 deg), boss_moves_probe fury suction.
