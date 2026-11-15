# Planning: a procedurally generated underwater world

Planned 2026-11-15. Status: **plan only, nothing built.** Decisions D1-D9 (§3) answered 2026-11-15.

Goal: seabeds as rich and lush as abyssal-garden's (github.com/Noniv/abyssal-garden, MIT). That means real terrain (canyons, mesas, overhangs, arches, tunnels, grottoes), flora that grows where the terrain says it should, regions with their own palette, and light that the rock blocks. All of it generated from a seed, so every co-op machine builds the same world.

Related: `planning_abyssal_look.md` (the water look, built), `PROGRESS_abyssal_look.md` (flora pass, rocky floor), `planning_environment.md` (E2 terrain, parked here until now). Licence rules from `planning_abyssal_look.md` §0 apply: porting their maths or constants line by line needs the notice header. Ideas need nothing.

---

## 1. What makes theirs lush (from their source)

Their whole world is one 384 × 60 × 384 m density field on a 0.75 m grid (512 × 80 × 512), meshed once with surface nets. Then about a million props are scattered *by the terrain*. The look comes from six things, in this order of importance:

1. **Enclosure.** 19 hand-placed **mesas** are extruded capsules with base flare, overhang and waist, so they read as canyon walls and grotto lips. Noise **plateaus** raise whole regions 26-43 m. A **ring** at the edge rises to 60 m, so the world is a bowl and you never see an edge. 8 **clearings** suppress plateaus to keep sightlines open. Floors rise 4.5 m within 10 m of a wall, so walls meet the floor in a slope, not a crease.
2. **Rock that reads as rock.** Domain-warped fbm (warp 15/6/15 m), two Worley erosion layers (0.17 and 0.41 /m) plus fbm, and strata bands about 4.8 m apart. The erosion fades near the floor so the sand stays smooth. Floating specks are removed by a flood fill from the seabed.
3. **Set pieces and holes.** 3 torus **arches**, 2 capsule **tunnels**, a whale fluke, a ship hull, a pillar to the surface. Each one is a focal point.
4. **Terrain-driven scatter.** Every prop samples a terrain vertex and checks its normal and headroom:
   - kelp needs flat floor with more than 9 m of open water above it, and grows to that headroom (15-40 m);
   - fronds hang only from overhangs (normal y < -0.35), and wall tufts grow only on walls;
   - carpets and tufts grow on flats, coral and sponges below a depth, pebbles on flats (170k of them).
   - Density comes from noise times hand-placed "hot" discs, so growth clumps instead of spreading evenly.
5. **Zones.** A purple grotto is a disc. Inside it the water colour, absorption, rock tint, kelp kind and cluster weights all change. Magenta carpet regions are noise times discs. One 512² ground map carries the zones to the shaders.
6. **Light that rock blocks.** A shadow map is baked once from the sun. A 1.5 m **openness/skylight volume** (RG8 3D texture) holds R = distance to rock (used for AO and shaft mist) and G = skylight swept down from the top, blurred, and absorbed by rock and kelp. Ambient, fog and shafts all read it, so grottoes are dark and the gap is bright.

Our current floor is one flat plane with a sand shader. We have no walls, no overhangs and no blocked light, and scatter that ignores the ground. Items 1, 4 and 6 are why the reference shot (purple grotto) looks so much better than ours (see the 2026-11-15 grotto comparison in `PROGRESS_abyssal_look.md`).

## 2. Constraints of our game (what theirs doesn't have to deal with)

- **It's a game, not a flythrough.** Their camera follows a fixed spline. Their props are kept clear of it, and the camera only gets push-out from a distance field. Ours has to support:
  - fish that are RigidBodies, and drive on surfaces (`rl_surface_mechanics`), so the terrain needs real **collision**;
  - a horde of zombies with their own steering (`horde.gd`, no physics);
  - bots (survivor, prey, Hunter), chests that sink to the seabed, shrines, whirlpools, bosses with ground moves, and the follow cam.
  - Every one of these assumes a flat floor at `arena_floor` today.
- **Determinism.** Co-op and online machines must lay out the same world. Their terrain runs in WGSL f32 on the GPU, which is not bit-exact across devices. **Ours must generate on the CPU** (GDScript is too slow for 20M samples, see D2), with integer-hash noise like their `math.js`.
- **Split-screen and the horde are GPU-bound** (perf passes 2 and 3). Terrain adds triangles to every view. Budgets are measured with `split_bench` and `horde_bench` as usual.
- **Murk.** Scenery culls beyond `fog_reach(murk_cull)`, and `fog_reach` semantics stay. Terrain walls must also cull or LOD by chunk.
- **Arena shapes per mode.** Unnatural has a 150 m disc with a soft edge and a ceiling at 15 m. What Stinks is a 220 m sphere (now with a floor). Hunt and Nature are open ocean with a boundary radius. Free Swim is endless. The generator takes a radius and a height band, and the edge ring doubles as the arena wall.
- **Build time.** Stages rebuild the seabed (`_build_seabed` per stage). The budget is under ~1.5 s on this machine, or it has to be threaded or cached per seed.
- **House rules.** Every number is a panel setting with a wide range, and 0 switches it off ([[flexible-tuning]]). Seamless, smooth-shaded meshes. Keep `INVENTORY.md`-style docs current.

## 3. Decisions for you

**Answers (2026-11-15):** each one took the recommendation.
- D1 (b): Unnatural and What Stinks first. Every Ocean mode and streaming come in phase 8.
- D2 (a): the C++ GDExtension generator.
- D3: 1.0 m cells, with 0.75 m as a quality option.
- D4 (a): procedural, with rule sets per biome (canyon, grotto, plateau field, open reef).
- D5 (a): a trimesh per chunk. Zombies steer on the coarse SDF grid.
- D6 (a): an open middle, with terrain at the edges and in landmarks. (b), full canyons, is logged in `BACKLOG.md` for later.
- D7 (a)+(b): the openness/skylight volume plus a baked sun shadow.
- D8 (a): region discs plus noise.
- D9: keep the flat rocky floor regions between terrain features.
- Build time: if a stage goes over ~1.5 s, build the next stage's terrain on a thread during the stage-clear screen (not a visible load or an automatic quality cut).

- **D1. Where does it go first?** (a) Unnatural only (the Test Tank and Look Tank get it free). (b) Unnatural and What Stinks. (c) Every Ocean mode, with Free Swim tiling chunks endlessly. *Recommended: (b) first, (c) later.* Endless terrain needs streaming, which is its own phase.
- **D2. Where does the generator run?** (a) In the existing C++ GDExtension (`native/`): density, flood fill and surface nets in about 0.3-1 s, threadable. (b) A GDScript generator, cached to disk per seed. (c) A compute shader with a CPU fallback for the host's layout. *Recommended: (a).* (c) breaks determinism, and (b) is minutes per world.
- **D3. How big and how fine?** Theirs is 384 m at 0.75 m (21M samples). Our Unnatural arena is a 150 m radius, about 340 m across with the edge ring. *Recommended:* 1.0 m cells (about 340 × 64 × 340 = 7.4M samples), with 0.75 m as a quality option.
- **D4. How hand-made?** Theirs places mesas, arches, tunnels and set pieces by hand around six camera poses. Ours must work for any seed. (a) Fully procedural: mesa, arch and tunnel records rolled by rules (walls toward the edge, clearings at the start and at shrines). (b) A few authored "biome templates" with procedural detail. *Recommended: (a) with template-like rules per biome* (canyon, grotto, plateau field, open reef).
- **D5. Collision.** (a) A ConcavePolygonShape3D per terrain chunk (trimesh, static). (b) A HeightMapShape3D for the floor only, with walls as convex pieces. (c) No physics, just a distance-field push like theirs. *Recommended: (a)*, since fish drive on surfaces and walls must be drivable. Zombies use a coarse SDF grid for steering, not physics.
- **D6. Does gameplay change?** Walls and overhangs block movement and sight. (a) Keep the playable middle open, with terrain mostly at the edges and in a few landmarks. (b) Full canyons through the arena: bots, the horde, chests, shrines and spawns all learn the terrain. *Recommended: (a) first.* (b) is a large AI pass.
- **D7. Light.** (a) The openness/skylight volume (AO, dark grottoes, shaft mist). (b) Plus a shadow map baked once from the sun (shafts and caustics stop under rock). (c) Neither. *Recommended: (a)+(b).* This is what makes their shot read. We already have the shafts and caustics to feed.
- **D8. Zones.** (a) Region discs plus noise like theirs (one grotto biome per stage, with its palette pushed through WaterLook's biome tint). (b) Per-run biome only (today's). *Recommended: (a).*
- **D9. The flat rocky floor regions.** Keep them as the sand shader's look between terrain features, or let terrain rock replace them. *Recommended: keep them* (cheap, and they sit well in open areas).

## 4. Phases

Every phase lands behind a switch (`terrain_enabled`, off until phase 4 passes), gets look_shots from the Look Tank, keeps `split_bench` and `horde_bench` numbers, and runs the probes.

### Phase 0: the bench and the seam
- `scripts/terrain/terrain_settings.gd` (or a "Terrain" group in UnnaturalSettings): every constant below, wide ranges.
- A **ground query API** that every system uses instead of `arena_floor`: `Terrain.floor_y(xz)`, `Terrain.sdf(p)`, `Terrain.normal(p)`, `Terrain.headroom(xz)`, `Terrain.is_open(p, radius)`. Today these return the flat floor, so the switch-over is safe. Move chests, shrines, whirlpools, spawns, the horde's floor push, `_keep_in_arena`, the boss ground moves, the octopus crawl and the Look Tank spots onto it, and grep for the rest (`arena_floor` has about 30 users).
- A Terrain Tank view: a top-down map shot and a fly-around (extend `look_shots`).

### Phase 1: density field and meshing (native)
- GDExtension class `TerrainField` (seeded, CPU integer-hash value noise, fbm, Worley F1, smin/smax):
  - **Floor:** g0 = base + 7·fbm(0.011) + 1.6·fbm(0.07), domain-warped (warp 15/6/15 m, fbm 0.04).
  - **Mesas:** capsule extrusions with flare/overhang/waist, floor rise near walls, ceiling noise.
  - **Plateaus:** fbm(0.0125) thresholded and suppressed in clearings.
  - **Edge ring:** rising to the arena's wall height at `radius`, warped. It replaces the edge rock outcrops and doubles as the wall.
  - **Arches:** vertical tori. **Tunnels:** carved capsules. **Grotto:** an overhanging mesa lip plus a carved cavity.
  - **Erosion:** two Worley layers plus fbm, faded near the floor; strata bands.
  - **Flood fill** from the floor to drop floating specks.
- **Surface nets** per 24-32 m chunk (shared borders, no seams), with normals from SDF central differences. Each chunk is one ArrayMesh with a ConcavePolygonShape3D (D5).
- Coarse SDF grid (2 m, int8) kept for queries and the horde.
- Determinism probe: the same seed hashes the same on two runs, and on a guest. Timing printed (target under 1 s at D3's size).

### Phase 2: rules that place features
- A layout pass rolls the records (D4) from the stage seed:
  - walls on 2-3 sides as canyon arcs near the edge; one grotto per stage, set back from the start;
  - 1-3 arches and 0-2 tunnels where there is room; plateaus in the outer ring;
  - clearings at the start, at shrines and chests, and along a few sightlines from the middle.
- The playable middle keeps a configurable open radius (D6a).
- Ruin clusters sit on plateaus or in clearings, with their platforms flush to `floor_y`.

### Phase 3: terrain material
- A triplanar rock shader built from our existing pieces: `wm_detail`, strata, encrustation, algae, the rocky floor's violet/teal/ochre crust with fluorescence, and sand where the slope is flat and low. Port their W_SOLID rock blend (rock vs sand by normal and height, encrustation on top faces).
- Zone tint from a ground map texture (D8). The sand shader's flat regions blend in where the terrain is floor.

### Phase 4: terrain-driven scatter
Rewrite the placement rules in `Seabed` and `FloraField` to sample the terrain:
- **Kelp columns** where the floor is flat (ny ≥ 0.55) with more than 9 m of headroom. Height = min(headroom − U(0.8, 5), U(15, 40)), noise × hot discs, a dedupe grid, and none in clearings.
- **Fronds** hang under overhangs (ny < −0.35). **Wall tufts** grow on walls (−0.2 < ny < 0.8). **Blades and ribbons** grow on top faces, with weights from heat and zone.
- **Carpets and tufts** go on flats by the magenta map; **coral and sponge gardens** in discs below a depth, snapped to the surface by marching along −n.
- **Rocks, chunks and pebbles** go on flats, with chunk density by slope.
- Area-weighted sampling, not per vertex like theirs: surface nets vertex density is even, but area weighting is what we want.
- Budgets and the far LOD stay as in the flora pass. Draw distance follows the murk.

### Phase 5: light
- **Openness/skylight volume:** an RG8 ImageTexture3D (1.5 m) baked at stage build. R = openness from the SDF grid. G = skylight swept top-down with a (1,2,1) blur, absorbed by rock and kelp columns. A shared global sampler; the materials' ambient and AO read it, and the shafts' mist and the fog's in-scatter read G along the ray (their recipe).
- **Static sun shadow:** a baked ortho depth map over the arena from the sun direction, sampled by the shafts, the caustics and `wm_light`. Fallback: the DirectionalLight3D's own shadows on terrain only, if the bake costs too much.
- Look shots against the purple grotto reference.

### Phase 6: gameplay on terrain (D6)
- **Fish:** collision from phase 1, so surface driving on walls just works. Tune the follow cam's collision (the follow cam already avoids walls in Marco arenas).
- **Horde:** steering avoids the SDF (a gradient push like `_keep_in_arena`), and cull or LOD behind walls is optional.
- **Bots:** headroom and line-of-sight queries through the coarse grid. Spawns, chests and shrines go through `is_open`.
- **Bosses:** ground moves use `floor_y`, and the boss rift sits in a canyon floor.
- Probes: `stage_probe`, `survivor_cam_probe`, the `what_stinks_*` probes, `boss` probes, plus a new `terrain_probe` (queries, determinism, collision, no spawn inside rock).

### Phase 7: set pieces and life
- Procedural set pieces (each placed by rule): a whale fall skeleton (we have whale meshes), a sunken hull, a pillar to the surface, a bubble vent field.
- Background life: distant fish schools on orbits and mantas (ties into Nature's schools).

### Phase 8: quality, streaming and the other modes
- Quality tiers: cell size, scatter budgets, volume resolution, shadow bake size.
- D1(c): Hunt and Nature arenas, and Free Swim streaming chunks around the player (seeded per chunk, built on a thread).

## 5. Files (expected)
- `native/src/terrain_field.{h,cpp}` (density, flood fill, surface nets, SDF grid) and its registration.
- `scripts/terrain/terrain.gd` (query API, chunk nodes, collision), `scripts/terrain/terrain_layout.gd` (feature records).
- `shaders/terrain_rock.gdshader`, `shaders/water_openness.gdshaderinc`.
- Changes: `scripts/unnatural/seabed.gd`, `scripts/scenery/flora_field.gd`, `scripts/unnatural/unnatural_run.gd`, `scripts/unnatural/horde.gd`, `scripts/what_stinks/what_stinks_match.gd`, `scripts/ocean.gd`, `scripts/water_look.gd`, `scripts/look_tank.gd`.
- Tests: `tests/terrain_probe`, `tests/terrain_shots`, plus extending `look_shots` and `split_bench`.

## 6. Risks
- **Collision cost.** Trimesh shapes for about 100 chunks with 200-400k triangles total. Godot Physics handles static trimesh well, but the fish's surface sticking near sharp concave edges needs testing early (phase 1 spike).
- **Horde through walls.** Zombies don't collide. Without phase 6 they will swim through rock. This is why D6(a) is recommended: keep the walls where the horde rarely goes.
- **GPU budget.** Terrain triangles in every split-screen view. Cull per chunk, plus the murk. Measure in phase 1.
- **Build time per stage.** Thread it, or build the next stage's terrain during the stage-clear screen.
- **Determinism.** Float order in C++ across compilers and CPUs. Use integer hashes and fixed iteration order, and test host vs guest in a probe.

## 7. Done means
- A Look Tank shot from inside a generated grotto that holds up next to `purple-grotto.jpg`: framing walls, layered depth, blocked shafts, dense terrain-fitted kelp.
- Every stage and seed is valid: no spawn in rock, no floating specks, no seams. Host and guest are identical.
- `split_bench` 3P and `horde_bench` stay within agreed budgets. Stage build is under 1.5 s.
- All probes pass, and every value is in the panel.
