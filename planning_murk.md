# Plan: Murk (murky water, the minimap, and no more light ring)

## Context
Make Unnatural's water murky. That serves two goals:
1. **Mood.** Zombies come out of the dark instead of being seen across the arena. That eeriness
   suits the blood moon.
2. **Performance.** Unnatural is heading for thousands of zombies. Anything hidden in the murk
   shouldn't cost anything.

**The key fact: fog on its own saves nothing.** Godot's depth fog is close to free (a few math
operations per pixel), but a fully fogged fish still gets transformed, rasterised and shaded, and
then painted fog-coloured. The savings come from what the murk lets us **skip** without anyone
seeing the difference:
- not drawing zombies past the murk line;
- steering them less often out there;
- using the murk band to hide pop-in (spawns, relocations, the cull line itself).

**Volumetric fog is out.** It costs frames instead of saving them. Exponential depth fog
(what `scenes/main.tscn` already uses) is the right tool.

Two more things came with it (user, 2026-10-17):
- **The light ring near the top of the arena goes** (§0).
- **A minimap** (§7): a flat 2D map with players, bosses, elites, swarms and chests.

## Decisions (user, 2026-10-17)
- **D1. How murky:** a sensible default, tuned later. It stays the same all night (no thickening
  over time). Default `murk_density = 0.035`: fog is 50% at 20 m, 85% at 55 m, 95% at 86 m.
- **D2. Red eye glints, as direction indicators:** zombies past the fog line show as pairs of red
  eyes, so you can tell where the next wave is coming from (§5).
- **D3. Unnatural only.** Nature, Hunt and the rest keep their water.
- **D4. Spawning like Megabonk:** zombies spawn near you, all around, not just out of view. The
  murk hides them as they arrive (§4).
- **Minimap:** players and bosses as icons, elites as dots, swarms as faint clouds of roughly their
  size, and chests (§7).

## Where things stand today
- **Fog.** `scenes/main.tscn` sets exponential fog at `fog_density = 0.012`. `Ocean` thickens it
  toward the arena's edge (`EDGE_FOG_THICKEN`, up to x3.5) through `set_fog_base`. `BloodMoon`
  tints it red and adds 25%. At 0.012 the water is close to clear: fog is 50% at 58 m and 95% at
  250 m, so the whole 300 m arena is visible.
- **Sky behind the fog.** `fog_sky_affect = 0.25` (`ocean.gd`). A fully fogged object ends up
  fog-coloured against a sky that's only 25% fog, so **its silhouette stays visible**. That's also
  what causes the light ring (§0).
- **Horde drawing** (`horde.gd` `_draw_horde`). One MultiMesh per kind per tail pose (15 looks),
  plus the rot overlay pass. Every live zombie's transform and custom data are written every
  frame. The MultiMesh AABB is the **whole arena**, so Godot never frustum-culls it: all instances
  are drawn, even those behind the camera. Nothing is distance-culled.
- **Horde sim LOD already exists.** Zombies more than `far_distance` (60 m) from every player steer
  only every `far_update_divisor`-th (4th) step. They still move, use separation and go in the grid
  every step.
- **Spawning** (`UnnaturalRun`, the spawn point near line 879). 28 to 45 m from a player
  (`spawn_distance_min` / `max`), at a point out of every player's view.
- **The bench** (`tests/horde_bench.tscn`, planning_unnatural.md phase 0). At 5,000 zombies a frame
  takes 30 ms: about 6 ms per step, 3 ms of draw-buffer filling, and **about 21 ms of rendering**
  (about 480 draw calls). The bench used to spawn zombies only 8 to 70 m from the player, which is
  nearer than a real late-game spread. It now takes `--spread`, `--murk` and `--cull`, and reports
  GPU time (phase 0).

## Design

### 0. The light ring near the top of the arena
**Found** (screenshots with each suspect hidden, 2026-10-17). It's the edge of `BloodMoon`'s
water-surface plane (`Surface`: a 450 m square, translucent and metallic). Fog paints the plane's
far edge fog-coloured. Past the edge is the sky, only 25% fogged, which is a different red. So a
light line runs round the arena near the top. Hiding `Surface` removes it. `EdgeGlow` (the red
wall rising from the seabed at the rim) isn't it.

**Fix:**
- The murk's `fog_sky_affect` of 1.0 (§1) makes the sky fog-coloured too, so the seam goes.
- Also make the surface big enough (`radius * 12`) that its edge is always deep in the fog,
  whatever the murk setting (`murk_density = 0` included).

### 1. Murk settings (UnnaturalSettings, a new Murk group)
These follow the flexible-tuning rule: wide ranges, and `0` turns a feature off.
- `murk_density`: the fog density in the arena. Default **0.035** (D1). `0` keeps the ocean's own
  0.012. Range 0 to 0.2. The edge thickening and the blood moon's tint stack on top, as they do now.
- `murk_sky`: `fog_sky_affect` while murky. Default 1.0, so fogged silhouettes (and the surface's
  seam) vanish. The moon disc has `disable_fog`, so it still shows.
- `murk_cull`: the fog amount at which we stop drawing a zombie. Default **0.98**, and `1.0` means
  never cull. The cull distance comes from the density, so the two can't drift apart:
  `cull_distance = -ln(1 - murk_cull) / density`. At 0.035 that's about 112 m. Use the **base**
  density, not the edge-thickened one, so the cull never comes inside what's visible.
- `murk_cull_margin`: extra metres past the cull distance (default 5 m) for interpolation and
  camera lag.
- `murk_far`: on by default. It makes `far_distance` follow the cull distance (hidden equals far),
  instead of the fixed 60 m. Off puts the existing `far_distance` setting back.

`BloodMoon` already owns the arena's fog and puts it back after a run, so it applies the density
and the sky affect too. `UnnaturalRun` hands the Horde the cull distance every frame (it's cheap,
and it follows panel edits live).

### 2. Distance culling in the Horde's draw
In `_draw_horde`, right after the interpolated position `at` is computed:
- Measure the distance to the **nearest local camera**. That's every split-screen viewport's
  camera (up to 4). Online, each peer culls for its own cameras only.
- Past `cull_distance + margin`, still fade the hit flash (so a zombie coming back doesn't flash
  from stale state). Then `continue`: no buffer write, no tail advance (a paused wag can't be seen).
- Nothing else changes. `visible_instance_count` and the buffer upload already scale with
  `used[look]`, and a look with nothing visible already uploads nothing.

**What this saves:** vertex and shading work for every hidden zombie (the main pass and the rot
overlay, and shadows if `enemy_shadows` is on), the CPU buffer writes, and the upload bandwidth.
**What it doesn't save:** draw calls, unless a whole look empties. Every look will usually still
have a few zombies nearby, so the roughly 480 calls stay. If phase 0 shows draw calls are the
bottleneck, the fix is the old phase 0 note: fewer surfaces per look (merge by material). That's a
separate item, not murk.

**Optional, cheap frustum check.** A dot-product test against each camera's forward vector would
also skip zombies behind the camera (a third or more of the horde with a chase cam). It goes with
the same `continue`. It's measured in phase 0; it's only worth keeping if it pays for its own
per-zombie cost.

### 3. Sim LOD tied to the murk
- `far_distance` follows the cull distance when `murk_far` is on, and is measured from players, as
  it is today.
- **Measure before cutting more.** Hidden zombies still use separation and the grid every step.
  Phase 0 times how much of the 6 ms step is separation. If it's a big share, hidden zombies use
  separation only on their steer steps too. They're unseen, so a looser crowd out there can't be
  seen. Grid insertion stays every step, because attacks and powerups with long reach query it.
- Contact damage and attacks are unchanged. They only matter near players anyway.

### 4. Spawning near you, out of the murk (D4)
Megabonk spawns enemies round the player, in every direction, just past what you can make out.
With murk we can do the same:
- With murk on, packs spawn **all round** a player, not only out of view, at
  `spawn_distance_min` to `max`. The new defaults are 35 to 55 m (71% to 85% fogged at 0.035).
  A newly spawned zombie also swims in from a little further out over its first second.
- `murk_spawn_anywhere` (on by default): off puts back the out-of-view-only rule.
- Leash relocation drops zombies past the cull distance, so it never pops in view.

### 5. Red eye glints: where they're coming from (D2)
Zombies from about where the fog swallows them (`glint_from`, the fog amount: 0.8, about 46 m) out
to `glint_distance` (default 1.5x the cull distance, about 170 m) draw as **a pair of small red
eyes**:
- One MultiMesh of tiny camera-facing quads (two per zombie), unshaded and additive, with the fog
  turned down by the shader's `FOG` output so they read through the murk. That's one extra draw
  call, and the same loop as §2 fills it.
- They fade in as the body fades out, so near the fog line you see the body and its eyes, and
  further out only the eyes. Brightness falls off with distance (`glint_strength`), so a big wave
  far off reads as a faint red haze of eyes in that direction.
- Elites' eyes are bigger. Bosses' too (bosses are real models, so theirs are separate).
- `glint_distance = 0` turns them off.

The god-rays are alpha-blended and fogged, so under the murk they'll fade. That's probably right
for the mood. Check it in the build.

### 6. Other entities (later, if needed)
Specks (`ocean.gd`, 6,000 instances), seabed kelp and rocks (`seabed.gd`) and pearls / XP pickups
can take the same cull distance: `visibility_range_end` on plain nodes, the same buffer filter on
MultiMeshes. Do it only if phase 0 shows they matter. The horde is the big cost.

### 7. The minimap
A flat 2D, top-down map in a corner of each player's view (its own Control in `UnnaturalHud`, so
split-screen gets one each).
- **Shape:** a round map, `minimap_range` m across (default 120 m round the player; `0` shows the
  whole arena), turned so the player's heading is up (`minimap_heading_up`, on; off = north-up).
  The arena's edge shows as an arc when it's in range.
- **Players:** an arrow icon each, in their colour, pointing the way they face. Downed players get
  a cross.
- **Bosses:** a skull-style icon (the mini-boss smaller), pinned to the map's rim with an arrow
  when out of range.
- **Elites:** a red dot each.
- **Swarms** ("schools"; Unnatural has no Nature schools, so these are the zombie packs): a
  **mostly transparent red cloud** of roughly their size and shape. The horde's zombies are binned
  into a coarse grid (about 4 m cells, a 64x64 image round the player), each cell's count turned
  into alpha, and drawn as one texture with linear filtering, so it reads as soft clouds. It's
  rebuilt a few times a second (`minimap_rate`, 6 Hz), not every frame. Elites and bosses are left
  out of the cloud (they have their own marks).
- **Chests:** a small gold box for each chest **you** haven't opened yet (each player's own, as in
  Round 2). Out of range: pinned to the rim with its direction, as the current chest pointer does.
- **Pearls and drops:** not shown (too many, and not asked for).
- Settings (UnnaturalSettings, a new Minimap group): `minimap` (on), `minimap_size` (px, scaled to
  the view), `minimap_range`, `minimap_heading_up`, `minimap_rate`, `minimap_opacity`.
- **Online:** it draws from what each peer already has (the horde's mirrored zombies, the bosses,
  the chests), so it needs no new network traffic.

## Phases
### Phase 0: measure (before building the culling)
`tests/horde_bench.gd` now takes:
- `--spread=N`: spawn 8 to N m out (150 is the arena's radius, a late-game spread);
- `--murk=D` and `--cull=F`: apply the density and the cull threshold;
- and it reports GPU and render-thread time next to the frame time.

Run 2,000 and 5,000 zombies: no murk, murk with no cull, murk with cull, cull plus the frustum
check. Also time the step's parts (steer, separation, grid). The result tells us whether the 21 ms
is vertex/shading cost (culling helps a lot) or draw-call cost (culling helps little, and merging
surfaces is the real fix). It goes in **Status** below.

### Phase 1: the look, and no light ring
The Murk settings group, applied and restored by `BloodMoon`, and the bigger surface plane.

### Phase 2: draw culling
The cull distance from the density, nearest-local-camera culling in `_draw_horde`, and the frustum
check if phase 0 shows it pays.

### Phase 3: sim LOD and spawns
`murk_far`, and hidden separation if phase 0 says so. Spawning all round, out of the murk (§4).

### Phase 4: eye glints
§5.

### Phase 5: the minimap
§7.

### Phase 6 (optional): the rest
Specks, seabed and pickups (§6).

## Verification
Headless probes can't render, but they can check the logic:
- **`tests/murk_probe.gd`** (new):
  - The cull distance matches the formula at a few densities, and `murk_cull = 1` never culls.
  - Zombies at 20 m are drawn and zombies at 200 m aren't (`visible_instance_count`). Zombies
    between the fog line and `glint_distance` get glints. Those nearer or further don't.
  - Two cameras (split-screen): a zombie near either camera is drawn.
  - `murk_density = 0` brings back the ocean's own fog, and ending a run brings back the fog and
    sky affect it started with. Other modes never get murk.
  - The far-sim distance follows the cull distance when `murk_far` is on, and doesn't when it's off.
  - With `murk_spawn_anywhere`, spawns land in every direction within the spawn band.
- **`tests/minimap_probe.gd`** (new): the map's marks for a known layout (players, an elite, a boss
  in and out of range, a pack's cloud cells, chests opened by one player but not the other).
- **Regression:** `unnatural_combat_probe`, `powerup_probe`, `survivor_cam_probe`, `drops_probe`,
  `tests/unnatural_net.sh` (online).
- **The bench** (windowed, real renderer) before and after, with the numbers recorded here.
- **Screenshots** (`tests/unnatural_shots.tscn`): the murk, the glints, the minimap, and no ring.
- **The build**, then manual testing (the mood, readability, and no visible pop at the cull line).

## Risks
- **The gain may be smaller than hoped** if the 21 ms is mostly draw calls. Phase 0 settles that.
  The fallback (merging surfaces per look) is worth doing anyway.
- **Long-reach attacks** (powerups that hit beyond the cull distance) would hit zombies the player
  can't see. Check the ranges against the default cull distance. Most are well under it.
- **Online:** culling and glints are per peer and only affect drawing, so the simulation and the
  network state are unchanged. Sim LOD is host-side only, as it is today.
- **A high camera** (free cam, or a tuned `camera_height`): the distance is measured from the
  camera, so a high camera sees a smaller murk disc on the seabed. That's fine, but tune with the
  real survivor cam.
- **Readability with the murk:** spawning all round at 35 to 55 m means a zombie is only a few
  seconds from you when it's first seen. The glints and the minimap are what make that fair, so
  tune the three together.

## Status
**Phases 0 to 5 are built (2026-10-17). Awaiting the user's play-test.** The build is in
`builds/windows/` (17:19). `tests/murk_probe.tscn` passes.

### The bench (phase 0, 1920x1080, RTX 4070 Ti SUPER)
`tests/horde_bench.tscn -- --count=N --spread=S --murk=D --cull=F --frustum=0|1`:

| Zombies (spread) | Setup | Drawn | GPU | Frame |
|---|---|---|---|---|
| 5,000 (150 m) | no culling (before) | 5,000 | 32.8 ms | 30 fps |
| 5,000 (150 m) | murk 0.035, no culling | 5,000 | 32.7 ms | 30 fps |
| 5,000 (150 m) | behind-the-camera only | 2,193 | 17.5 ms | 56 fps |
| 5,000 (150 m) | murk 0.035 + both culls | 1,980 | 16.1 ms | 61 fps |
| 5,000 (150 m) | murk, distance cull only | 4,487 | 30.2 ms | 33 fps |
| 2,000 (70 m) | no culling (before) | 2,000 | 14.8 ms | 66 fps |
| 2,000 (70 m) | murk + both culls | 1,002 | 9.2 ms | 104 fps |

- **It's GPU-bound on the fish themselves** (vertex and shading work), not draw calls: the render
  thread is about 0.7 ms. Fewer fish drawn means faster frames almost one for one.
- **Fog alone saves nothing** (as expected). **The behind-the-camera check is the big win.** The
  distance cull adds a little in solo, because the leash (90 m) keeps nearly every zombie inside
  the cull distance (about 117 m). It matters more in co-op, where a partner's swarm is far from
  you.
- The step (about 5.5 ms at 5,000) barely moved: the murk's far-steering starts at 54 m instead of
  60 m. Separation wasn't split out. That's for a later perf pass if the step becomes the limit.
- **Next perf lever, if needed:** the fish that are drawn are expensive (about 8 µs of GPU each).
  Simpler far looks (fewer parts, no overlay pass, past ~40 m where the murk blurs them) would cut
  that.

### How the build differs from the design above
- **The light ring (§0):** confirmed with screenshots (each suspect hidden in turn). The surface
  plane now reaches `max(radius * 12, 2000)` m, and the murk fogs the sky fully. The red **edge
  glow** at the arena's rim was fog-free, so it shone through the murk. It now fades with distance
  at the murk's density (`Seabed.set_murk`). If the "light ring" the user meant was this glow and
  not the surface's seam, removing it is a one-liner in `Seabed._build_edge`.
- **`murk_density` is the arena's density as it is.** The blood moon's +25% only applies without
  murk.
- **`murk_far` is a fog amount** (0.85, about 54 m), not "the cull distance". Following the cull
  distance (117 m) would have made solo slower than the old 60 m, since the leash keeps zombies
  within 90 m.
- **The behind-the-camera check is core**, not optional (`murk_frustum`, on). It also works
  without murk.
- **Spawning (§4):** new spawn band 35 to 55 m, any direction with murk. The "swims in from a
  little further out" idea wasn't built. The murk already hides the arrival (71% to 85% fog).
- **The minimap (§7):** chests show only when in range (pinning every buried chest to the rim
  crowded it). Bosses are pinned to the rim. It sits bottom-right, 26% of the view's height,
  90 m to the rim.
- **Eye glints:** they grow with distance (`1 + d / 25`) so they stay a few pixels wide.
  `glint_size` 0.09 and `glint_strength` 1.0 are the knobs. They're drawn over bodies from 46 m,
  so a pack at 50 m shows bodies and eyes.

### Open items for the user
- Is 0.035 murky enough, or too much? (`murk_density`; the eyes and the cull follow it.)
- Are the eyes too big or too bright far out? (`glint_size`, `glint_strength`, `glint_distance`.)
- Minimap size, range and heading-up vs north-up (`minimap_size`, `minimap_range`,
  `minimap_heading_up`).
- Was the light ring the surface's seam (fixed) or the red edge glow (now fades into the murk)?
