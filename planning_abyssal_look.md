# Planning: the Abyssal Garden look pass

Planned 2026-11-15. Status: **built 2026-11-15** (phases 0-8 all done; the look_shots review and play-test are still yours). See `PROGRESS_abyssal_look.md`, FINAL SUMMARY. The open decisions (§3) were answered before the build.

## 0. Source and licence

- Source: https://github.com/Noniv/abyssal-garden, Nonivs WebGPU demo, live at https://noniv.github.io/abyssal-garden/.
  - It is one 97 KB HTML file with no assets. Everything is procedural WGSL.
  - Readable source is in `source/src/` (`shaders.js`, `main.js`, `world.js`, `math.js`, `quality.js`).
- Licence: **MIT**. We may copy, port and change it, including commercially. The condition is that the copyright and permission notice travels with any "substantial portion".
  - Add `THIRD_PARTY_NOTICES.md` at the repo root with their LICENSE text.
  - Add a one-line header to every shader we port from theirs: `// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md`.
  - Using their *ideas* needs no notice. Porting their maths or constants line by line does.
- We are porting **techniques and maths, not assets**. Nothing can be dropped in as is: it is raw WebGPU with no engine, and we are on Godot 4.7 Forward+.

## 1. Why it looks good, and what we lack

Their look comes from five things working together:

| # | What sells it | What we have today |
|---|---|---|
| 1 | **Per-channel water absorption.** Red dies about 3× faster than blue, both with distance *and* with depth below the surface (Beer–Lambert). The water colour is in-scattered and gets brighter toward the sun and the surface. | One flat exponential Environment fog colour, `(0.04,0.2,0.28)` at density 0.012, or the murk in Unnatural. No depth coupling. |
| 2 | **Caustics** projected along the sun onto every sun-facing surface, and also inside the light shafts. | None anywhere. |
| 3 | **Light shafts** shaped by the caustic pattern: a half-res raymarch with 34 steps. | 9 additive cylinders in Unnatural (`blood_moon.gd`) and boxes in the Temple. |
| 4 | **Ceiling from below**: Snell's window, total internal reflection outside it, and a refracted sun disc. | Unnatural has a flipped plane at alpha 0.55. Ocean shows only the sky gradient. |
| 5 | **Grading**: ACES, a gentle S-curve, saturation 0.93, a vignette, and soft bloom fed by HDR sparkles (kelp glints, marine snow, coral fluorescence). | Filmic tonemap and default glow. No adjustments. |

Smaller items:
- kelp translucency and back-light, with a twinkling sparkle band;
- **fluorescence re-emission** on coral and encrusting cover, which is why their reef "glows";
- rock strata and algae on up-facing faces (triplanar);
- a baked 3D "openness" volume used as AO and skylight;
- bubbles that reflect the water colour without a cubemap;
- a region palette blend (their purple grotto);
- adaptive resolution.

Full technique catalogue, with formulas and source locations: see Appendix A.

## 2. Constraints this plan has to respect

- **Split-screen shares one World3D, and therefore one Environment** (`split_screen.gd`, 2 to 4 SubViewports).
  - Anything that depends on the camera, such as exposure by depth or "brighter near the surface", must be worked out **per view**: in shaders from `CAMERA_POSITION_WORLD`, or in a per-Camera3D `Compositor`. It must not be done by tweening the shared Environment.
- **Perf budgets:**
  - At most 1.5 ms extra GPU with 1 player (`planning_environment.md`).
  - 3-player `split_bench` within 10% of baseline and above 100 fps (`big_changes.md`).
  - Unnatural is already CPU-bound at about 8.4 ms with 2000 zombies, so there is some GPU headroom.
- **The Murk must keep working.** Unnatural culling uses `fog_reach()`, worked out from `murk_density`. If the fog model changes, `fog_reach()` must still mean "where things are fully fogged".
- **Blood Moon** (`blood_moon.gd`) restyles the fog, sky and ambient. It has to drive the new model's colours instead.
- **Flexible tuning**: every new value is a panel setting with a wide range, not a const. The panel docs are regenerated with `tools/gen_setting_docs.gd`.
- **There is no graphics or quality menu yet.** Only fullscreen exists.
- Other modes keep their own look unless D1 says otherwise. The Marco arenas and the RL Aquarium override the environment in `configure_environment`.

## 3. Decisions for you (D1 to D6)

**D1. Which modes get the look?**
- *Recommended:* everything that uses `Ocean`, which covers Free Swim, Nature, Hunt, Unnatural, Test Tank and What Stinks.
- Then the Marco Temple as a stretch.
- The RL Aquarium Arena and the Obstacle Course keep their clean, readable look.

**D2. How far toward their palette?**
- Theirs is bright teal and sunny. Ours is darker and moodier, and Unnatural is murky on purpose.
- *Recommended:* adopt their *model* with our colours as the defaults, plus a "Sunlit" preset that copies their constants. You compare the two in the Look Tank and pick.

**D3. How should the fog be done?**
- (a) A per-camera `CompositorEffect` that applies absorption and in-scatter from the depth buffer to all opaque geometry in one pass. Transparents keep a matched built-in fog.
- (b) A `water.gdshaderinc` called at the end of every material.
- *Recommended: (a).* We have dozens of shaders, plus fish, zombies and FX, and (a) touches none of them. It is also per-camera, so it handles split-screen for free. The include is still used for the sky and for the water surface.

**D4. Which light shafts?**
- (a) Upgrade our cylinders: sample the caustic pattern in them, fade them by depth, and soften them against the depth buffer. This is cheap.
- (b) Godot volumetric fog plus a `FogVolume` whose density follows the caustics. `planning_murk.md` ruled volumetric fog out as too costly, but it was never benched.
- (c) Port their raymarch as a CompositorEffect. This is the most faithful option, but it needs our own shadow map.
- *Recommended:* (a) first, and bench (b) in the Look Tank. Take (c) only if neither is good enough.

**D5. Should a graphics quality setting be added now?**
- It would be Low, Medium and High, controlling shaft quality, caustic taps, snow count, glints and render scale.
- *Recommended:* yes, as a small Settings entry in phase 8, with auto-detect off. Leave adaptive resolution until later.

**D6. Should regional palettes be added?**
- Their purple grotto blends the water colour, absorption and ambient by region.
- *Recommended:* yes for Unnatural, as one per-run "biome" tint, for example a violet ruin district. It is cheap once phase 2 exists.

## 4. Phases

Each phase ends with before/after shots from the same cameras, made with `look_shots` (phase 0). Phases 2 onward also end with a `split_bench` (3 players) compared against the phase-0 baseline.

### Phase 0: Look Tank, baselines, notices
- Add `THIRD_PARTY_NOTICES.md`.
- **Look Tank**: a hidden test scene, launched like `tank_boss` from the console, with Ocean, the Unnatural seabed (reef, ruins, kelp), a few fish, and 6 fixed viewpoints. These copy their idea of numbered viewpoints:
  1. looking up through kelp;
  2. a ruin in shafts;
  3. a reef close-up;
  4. the open blue;
  5. floor level into murk;
  6. split-screen.
- **`tests/look_shots.gd`**: renders the 6 viewpoints to `logs/look_shots/<label>/`. This lets every phase be compared side by side.
- Baselines: `split_bench --players 3` and a 1-player GPU time (use `viewport_get_measured_render_time_gpu`).
- New settings group: a **`WaterLook`** resource (autoload-backed, like the other `*Settings`), with a tab in `debug_panel.gd`.

### Phase 1: Grading and bloom (about an hour, biggest win for the effort)
- Ocean `configure_environment`:
  - `tonemap_mode` ACES with matching white;
  - `adjustment_enabled` with saturation 0.93 and contrast about 1.05;
  - glow at levels 1–6 weighted to the low levels, mix mode, intensity about 0.08, HDR threshold about 1.0.
- Vignette and luminance S-curve: either extend `arcade_vignette` or add a tiny per-camera compositor pass. Their curve is `mix(l, smoothstep(l), .55)` applied by ratio, plus desaturating highlights above 0.55.
- All values go in WaterLook. Blood Moon multiplies them; it does not overwrite them.

### Phase 2: Water fog model (D3), sky and depth exposure
- `shaders/water_fog.gdshaderinc` holds their `fogIn`/`fog` in closed form:
  - per-channel `SIG` (extinction per metre) and `KD` (sunlight loss per metre of depth);
  - albedo `WCOL`;
  - forward phase `1.22 + .3·mu⁴`;
  - hard fade to pure water at `fade_start`/`fade_end`.
- **`WaterFogEffect`** (CompositorEffect, `POST_OPAQUE`, compute shader). It reconstructs world position from depth and applies `c·exp(-SIG·d) + fogIn(...)`. One `Compositor` is attached per Camera3D: the main camera, each split-screen camera, and the titan view.
- **Sky:** replace the Ocean ProceduralSkyMaterial with a `sky_shader` that evaluates the same `fog()` 240 m out. Then "up is bright, down is dark" matches the fog exactly and the light-ring seam cannot come back.
- **Transparents and additive FX:** keep Environment fog on, but drive its colour and density from WaterLook so they roughly match. Check the edge glow wall, the shafts and the bubble refraction.
- **Murk:** murk density scales `SIG`. `fog_reach()` is rewritten as the distance where `exp(-SIG.g·d) < 1 - murk_cull`, with the same meaning. Probe this with `murk_probe`.
- **Blood Moon:** lerps `WCOL`, `SIG` and the ambient tint instead of the Environment fields.
- **Depth exposure:** in the compositor, apply `exposure · (0.6 + 0.4·clamp((-camY - a)/b))` per camera. Arenas are shallower than theirs, so `a` and `b` are settings.
- **Sun:** keep the DirectionalLight3D, but colour and dim it by depth in the shaders that matter (sand, stone, reef, kelp) through `light()`. This uses a shared `water_light.gdshaderinc` with `exp(KD·y/sun.y)`. Fish and zombies get it in phase 7 only if needed.
- **Risk:** the CompositorEffect API in 4.7 and MSAA. MSAA depth needs a resolve. Fallback: a full-screen quad mesh in front of each camera that reads `hint_depth_texture` (a spatial shader). That is uglier but proven.

### Phase 3: Caustics
- `water_caustics.gdshaderinc` has two parts:
  - their 5-iteration turbulence function, evaluated **inline** (about 30 ALU). This avoids a SubViewport per view and works in split-screen;
  - sun-projected UVs `q = p.xz - sun.xz·(p.y/sun.y)` with an RGB split and a second rotated tap to break the tiling.
- Applied to sun-facing surfaces as `smoothstep(.1,.45,N·L)`, faded with distance (35 to 100 m), in `sand`, `stone`, `reef`, `kelp_plant`, `fan_coral` and `marco_gravel`, and optionally on fish backs.
- Global uniform `water_time`, so co-op machines match and pause freezes it.
- Settings: `caustic_strength`, `caustic_scale`, `caustic_speed`, `caustic_fade`.

### Phase 4: Surface from below
- New `water_surface.gdshader`: a PlaneMesh that follows the camera at the surface height, two-sided and unshaded. It contains:
  - slope from 3 octaves of summed cosines (their `WK` wave table);
  - Snell's window `k = 1 - 1.769(1 - cos²)`;
  - Fresnel `pow(1-√k, 5)`;
  - inside the window: sky plus a refracted sun `pow(sd,60)·1.3 + pow(sd,500)·12`;
  - outside the window: `fogIn` along the reflected ray;
  - then `fog()`.
- Replaces the Blood Moon "Surface" plane. In Unnatural the Moon becomes the refracted "sun" disc.
- Ocean modes get it too, at a WaterLook `surface_height`. Nature, Hunt and Free Swim have no floor and need a ceiling height.
- Per view: each split camera follows its own plane, or one big plane does it.

### Phase 5: Particles
- **Marine snow:** convert `wrapped_specks` from spheres to camera-facing quads. Changes:
  - 44 m box (ours is 120 m);
  - near fade 0.6 to 2.5 m, far fade 14 to 22 m;
  - minimum on-screen size with brightness conserved, so there are no shimmering sub-pixel specks;
  - additive with an HDR peak, so bloom catches it;
  - drift `(.22,.05,.13)·t`.
  - Count stays a setting. This is probably *fewer* than the current 6000 spheres, and cheaper.
- **Kelp glints:** additive billboards attached to kelp blades. They follow the same sway as the blade and twinkle `pow(.5+.5 sin(...),4)`. Built as a MultiMesh per Scatter tile, under Scatter's visibility range.
- **Bubbles:** their bubble fragment shader (wobbly rim, two spec dots, water-colour reflection with no cubemap) goes into `stride_bubbles` and the bubble columns.

### Phase 6: Light shafts (D4)
- (a) Upgrade the `blood_moon.gd` cylinders and the Temple shafts:
  - caustic-pattern density (their `pat` term);
  - `exp(-SIG·t)` falloff;
  - soft depth intersection;
  - phase `.2 + 2·mu³` so they glow when you look toward the sun.
- Ocean modes get the same shaft field around the camera: a few moving shafts, so they work with no floor.
- (b) Bench Godot volumetric fog plus a caustic `FogVolume` in the Look Tank at 1 player and 3 players, and record the numbers here. Adopt it only if it stays inside budget.

### Phase 7: Material pass on the reef, ruins and kelp
- **`kelp_plant`:**
  - translucency with a warm tint `(1.5,1.4,.75)` and back-light `pow(dot(-V,L),3)`;
  - thin-film iridescence;
  - vein stripes;
  - a sparkle band on about 24% of blades.
- **`reef` and `fan_coral`:** a **fluorescence** term `alb·flu·dot(light, (.1,.5,.5))`, with per-palette `flu` 0.55–0.75, plus a tip highlight.
- **`stone` and rock:**
  - their triplanar strata (bed tint, dark seams, olive and brown mix, red encrustation, algae on up faces from `smoothstep(-.1,.6,n.y)`);
  - one baked **detail texture**: their 1024² height, gradient and mottle map, generated once by a tool script and saved as a PNG asset;
  - rim light `pow(1-NdV, 2.5)`.
- **`sand`:** ripple normals already exist, so add a magenta or encrusting cover mask in deep spots, plus the D6 biome tint.

### Phase 8: Quality setting (D5) and polish
- `graphics_quality` with Low, Medium and High in the Settings screen. It controls:
  - shaft steps or count;
  - caustic taps (1 vs 3, the RGB split);
  - snow count;
  - glints;
  - glow levels;
  - `scaling_3d_scale` (FSR on Low).
- Optional: auto-adapt render scale from `viewport_get_measured_render_time_gpu`. Their scheme scales pixels first, then draw distance.

### Parked / later
- **Baked openness/skylight volume** (their AO and GI trick):
  - an RG8 `ImageTexture3D` baked from the scenery at run start;
  - R = blurred distance to rock, used for AO;
  - G = skylight propagated top-down, with kelp absorbing it.
  - It is worth it once there is real terrain.
- **E2 terrain** (parked in `planning_environment.md`): their SDF seabed (domain-warped fbm, mesa extrusions, torus arches, capsule tunnels, Worley erosion, then surface nets) is a ready-made recipe. It would revive E2 with collision. It is a separate plan.
- Manta rays and ambient Lissajous fish schools as background life: it fits Nature, but is not part of this pass.

## 5. Files (expected)

| New | Changed |
|---|---|
| `THIRD_PARTY_NOTICES.md` | `scripts/ocean.gd` (environment, sky, specks, surface) |
| `scripts/water_look.gd` (settings resource) | `scripts/unnatural/blood_moon.gd` (surface, shafts, tint) |
| `scripts/fx/water_fog_effect.gd` and `shaders/water_fog.glsl` | `scripts/split_screen.gd`, `titan_view.gd` (a Compositor per camera) |
| `shaders/water_fog.gdshaderinc`, `water_light.gdshaderinc`, `water_caustics.gdshaderinc` | `sand`, `stone`, `reef`, `kelp_plant`, `fan_coral`, `wrapped_specks`, `stride_bubbles` shaders |
| `shaders/water_surface.gdshader`, `water_sky.gdshader`, `kelp_glint.gdshader`, `light_shaft.gdshader` | `scripts/unnatural/unnatural_settings.gd` (`fog_reach`), `horde.gd` if the murk maths moves |
| `scenes/look_tank.tscn` and `tests/look_shots.gd` | `scripts/debug_panel.gd` (WaterLook tab), `tools/gen_setting_docs.gd` output |
| `textures/rock_detail.png` (baked) | `scripts/temple_arena.gd` (shafts), if D1 includes the Temple |

## 6. Done means

- The look_shots before/after set has been reviewed by you, and a play-test has been done.
- Budgets are met: 1-player GPU within +1.5 ms, and 3-player `split_bench` within 10% of baseline.
- `murk_probe` and the compass probe pass, and murk culling still hides spawns.
- The Blood Moon still reads as Blood Moon.
- `INVENTORY.md` is unaffected, since there are no gameplay changes.

---

## Appendix A: technique catalogue (from their source)

Line numbers are approximate. W = water, S = their shared scene code.

1. **Fog and in-scatter**, `S_G` `fogIn`/`fog` (shaders.js ~193–269):
   - `SIG=(.058,.0235,.0195)`, `KD=(.056,.0245,.017)`, `WCOL=(.16,.58,.90)`, `PCOL=(.58,.66,.98)`.
   - `I = (1-exp(-a·d))/a`, with `a = SIG - k·rd.y`.
   - In-scatter `= WCOL·SIG·exp(k·ro.y)·I·(1.22+.3·mu⁴)`.
   - Surfaces: `c·exp(-SIG·d)`, hard fade between 185 and 230 m.
2. **Sun and ambient**, `sunE`/`amb`/`side` (~257–264):
   - `SUNC=(1.7,1.6,1.45)·exp(KD·y/sun.y)`;
   - teal dome ambient `(.22,.60,.80)`;
   - horizontal water bounce;
   - exposure follows camera depth (main.js ~442).
3. **Caustics**, `W_WATER.caus` (~164), `cuv` (~243):
   - 5-iteration sin turbulence, `pow(1.17 - pow(c/5,1.4), 8)`;
   - sun-projected, RGB split `(.004,.0025)`;
   - second tap `q.yx/6.9+.37`;
   - `min(pow(a,2.3)·5·(.45+b·1.3), 4)`.
4. **Shafts**, `W_RAYS` (~686–723):
   - half-res, 34 steps with IGN jitter, up to 120 m or the surface;
   - per step: shadow map × caustic pattern at scales 27 and 11 × openness "mist";
   - phase `.2+2mu³`, `RAYS=.54`;
   - depth-weighted blur, bilateral upsample.
5. **Post**, `W_POST` (~742–781): bloom mix .06, exposure, vignette `.55`, ACES (Narkowicz), S-curve .55, highlight desaturation, saturation .93, lift `(.008,.002,0)`, triangular dither.
6. **Bloom**: 6-level pyramid with Karis firefly weighting on the first downsample.
7. **Surface**, `W_SURF` (~582–608): 3-scale slope, Snell's window `1-1.769(1-cos²)`, Fresnel `pow(1-√k,5)`, TIR = `fogIn(reflect)`.
8. **Openness volume** (world.js ~343–357): RG8 256×40×256. AO from 2 taps along N at 1.5 m and 4.5 m.
9. **Rock** (`W_DETAIL` ~98–130, `W_SOLID` ~304–377):
   - 4-octave triplanar from one 1024² detail map;
   - strata, encrustation, algae, sand ripples;
   - fluorescence `alb·flu·dot(dl+am,(.1,.5,.5))`.
10. **Kelp** (`W_LEAF` ~401–446): constant-curvature arc blades with travelling ruffles; sway grows with height `.024h^1.25`; translucency, iridescence and the 24% sparkle band; 3 LOD row counts.
11. **Glints**: additive billboards with a minimum pixel size and energy conserved.
12. **Snow**: 9000 points, 44 m wrap box, fades 0.6–2.5 m near and 14–22 m far.
13. **Bubbles**: helical columns, wobbly rim, spec dots, `fogIn` reflection.
14. **Zone blend**: camera distance plus a per-pixel ground map blends SIG, KD, WCOL, ambient and shafts.
15. **Shadows**: a static ortho map baked once at 4096², 9-tap PCF.
16. **Terrain**: GPU SDF on a 0.75 m grid, then surface nets.
17. **Fish and manta**: GPU Lissajous orbits, body wave, manta flap with corrected normals.
18. **Coral and sponge**: lathe meshes with profile AO, per-instance hue, fluorescence 0.55–0.75.
19. **Culling**: 24 m XZ cells, merged instanced draws, distance bands, small props shrink at their band edge.
20. **Adaptive resolution**: GPU timestamp target of about 11.7 ms; pixels first, then draw distance.
