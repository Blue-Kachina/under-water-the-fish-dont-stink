class_name TerrainSettings
extends Resource
## The seabed kit's tuning (Seabed, Terrain, TerrainLayout, TerrainLight, OceanFloor): the arena's
## size and edge, the living reef, the procedural rock, its look, flora, ground play and the murk.
## A mode with a seabed extends the chain (Unnatural's UnnaturalSettings does), so its panel section
## shows these too. shared() is the copy the panel edits: the mode registers itself as the provider
## (UnnaturalSettings.shared()); without one a plain fallback copy answers.

## Set by the mode whose settings extend this chain: returns its shared copy.
static var provider := Callable()

static var _fallback: TerrainSettings


## The copy the panel edits and the kit reads.
static func shared() -> TerrainSettings:
	if provider.is_valid():
		return provider.call()
	if _fallback == null:
		_fallback = TerrainSettings.new()
	return _fallback


@export_group("Arena")
## The arena's radius (m), around the ocean's spawn. D1: 300 m across.
@export_range(20.0, 1000.0, 5.0, "or_greater") var arena_radius := 150.0
## The seabed's height (m), and the top of the depth band fish and zombies keep within.
@export_range(-200.0, 0.0, 1.0, "or_less") var arena_floor := -25.0
@export_range(0.0, 200.0, 1.0, "or_greater") var arena_ceiling := 15.0
## How hard the arena's edge pushes a fish back in (m/s² at 1 m past it, more further out).
@export_range(0.0, 200.0, 1.0, "or_greater") var edge_push := 30.0
## The blood moon's strength: the red in the fog and light (0: plain ocean).
@export_range(0.0, 2.0, 0.05, "or_greater") var blood_moon := 1.0
## The arena's edge, so it reads from far off: tall rock outcrops and a thick
## band of tall kelp round it (and a faint red wall of light), from the seabed
## to the top of the depth band.
@export_range(0, 1000, 5, "or_greater") var edge_rocks := 90
@export_range(0, 8000, 10, "or_greater") var edge_kelp := 420

@export_group("Seabed")
## The living reef (planning_environment.md, Phase 5), all laid out from the
## stage's seed: reef patches (corals, sponges, anemones) where a slow noise
## says so, open sand and sea-grass meadows between them, a few kelp forests,
## rocks, small life, and the ruins (Phase 4). The numbers are how many of
## each across the arena; 0 switches one off.
@export_range(0, 2000, 10, "or_greater") var seabed_rocks := 220
## Giant kelp plants (about 8 m tall), in forests.
@export_range(0, 3000, 10, "or_greater") var seabed_kelp := 320
## Sea-grass clumps, in meadows.
@export_range(0, 20000, 50, "or_greater") var seagrass := 2600
## Corals (staghorn, brain, table and fan) and sponges (tube, barrel), in reef patches.
@export_range(0, 10000, 10, "or_greater") var corals := 1400
@export_range(0, 4000, 10, "or_greater") var sponges := 260
@export_range(0, 4000, 10, "or_greater") var anemones := 420
## Starfish, urchins and clams on the sand.
@export_range(0, 4000, 10, "or_greater") var small_life := 500
## How much of the floor is reef (0..1 of it, roughly).
@export_range(0.0, 1.0, 0.05) var reef_cover := 0.35
## Ruins (Phase 4): broken drums, capitals, blocks and pots scattered thinly,
## thickening round ruin_clusters small temple ruins, which keep at least
## ruin_spacing m apart and clear of the start.
@export_range(0, 4000, 10, "or_greater") var ruin_rubble := 220
@export_range(0, 20, 1, "or_greater") var ruin_clusters := 4
@export_range(10.0, 200.0, 5.0, "or_greater") var ruin_spacing := 55.0
## A clear circle round the start (m), and round each shrine.
@export_range(0.0, 100.0, 1.0, "or_greater") var scenery_clearing := 12.0
## How far scenery is drawn (m; 0: follow the murk, as the horde does).
@export_range(0.0, 1000.0, 5.0, "or_greater") var scenery_draw_distance := 0.0

@export_group("Terrain")
## Procedural terrain (planning_procedural_world.md): a rock field round the open middle (canyon walls, a grotto, arches,
## tunnels, plateaus and an edge ring), built natively from the stage's seed, so every machine builds the same world.
## Applies when the next stage (or match) is built.
@export var terrain_enabled := true
## The grid's cell (m): finer is smoother rock and more triangles. 0.75 is the quality option.
@export_range(0.25, 4.0, 0.05, "or_greater") var terrain_cell := 1.0
## Cells per chunk side (each chunk is one mesh and one collision shape, culled by the murk).
@export_range(8, 128, 1, "or_greater") var terrain_chunk_cells := 32
## Quality tier (phase 8): 0 low (1.5 x the cell, 60% of the dressing), 1 medium (as set), 2 high (0.75 x the cell,
## 125% of the dressing). Chunks keep about the same size in metres.
@export_range(0, 2, 1) var terrain_quality := 1
## Endless terrain in Free Swim (phase 8): tiles of rock and seabed streamed round the fish, built on worker threads.
## Tile side (m), how far round the fish tiles are kept (m), the tiles' cell (m), and how far below the start the floor lies (m).
@export var terrain_stream := true
@export_range(32.0, 512.0, 8.0, "or_greater") var terrain_stream_tile := 96.0
@export_range(32.0, 1000.0, 8.0, "or_greater") var terrain_stream_reach := 160.0
@export_range(0.5, 6.0, 0.25, "or_greater") var terrain_stream_cell := 2.0
@export_range(5.0, 300.0, 1.0, "or_greater") var terrain_stream_depth := 45.0
## The open middle (m): no walls, mesas or plateaus inside it (D6a). Capped at 0.7 x the arena's radius.
@export_range(0.0, 500.0, 5.0, "or_greater") var terrain_open_radius := 75.0
## The floor's relief outside the open middle: big swells (m) and small detail (m).
@export_range(0.0, 40.0, 0.5, "or_greater") var terrain_floor_swell := 6.0
@export_range(0.0, 10.0, 0.1, "or_greater") var terrain_floor_detail := 1.4
## The edge ring: how tall it rises (x the depth band's height, 0: none), how far inside the edge its foot starts (m), and
## how wide its rise is (m).
@export_range(0.0, 3.0, 0.05, "or_greater") var terrain_ring_height := 1.05
@export_range(-50.0, 100.0, 1.0, "or_greater") var terrain_ring_inset := 8.0
@export_range(1.0, 100.0, 1.0, "or_greater") var terrain_ring_width := 24.0
## Plateaus in the outer band: how much of it they cover (0..1, 0: none) and their height range (m).
@export_range(0.0, 1.0, 0.05) var terrain_plateau_cover := 0.3
@export_range(0.0, 80.0, 1.0, "or_greater") var terrain_plateau_min := 7.0
@export_range(0.0, 80.0, 1.0, "or_greater") var terrain_plateau_max := 18.0
## Mesas (extruded rock walls): how many in all (most in 2-3 canyon arcs near the edge), their radius (m) and height
## (x the depth band's height).
@export_range(0, 60, 1, "or_greater") var terrain_mesas := 14
@export_range(1.0, 40.0, 0.5, "or_greater") var terrain_mesa_radius := 8.0
@export_range(0.05, 2.0, 0.05, "or_greater") var terrain_mesa_height := 0.65
## Canyon arcs the mesas line up in.
@export_range(0, 6, 1, "or_greater") var terrain_canyons := 3
## A grotto per stage: an overhanging mesa with a cavity under its lip (0: none).
@export_range(0, 4, 1, "or_greater") var terrain_grottoes := 1
## Rock arches (most stages get 1-3) and tunnels bored through mesas.
@export_range(0, 8, 1, "or_greater") var terrain_arches := 2
@export_range(0, 6, 1, "or_greater") var terrain_tunnels := 1
## The rock's surface: erosion pits (x), strata band depth (m), domain warp (m), how softly pieces blend (m).
@export_range(0.0, 4.0, 0.05, "or_greater") var terrain_erosion := 1.0
@export_range(0.0, 3.0, 0.05, "or_greater") var terrain_strata := 0.35
@export_range(0.0, 60.0, 0.5, "or_greater") var terrain_warp := 14.0
@export_range(0.0, 20.0, 0.25, "or_greater") var terrain_blend := 4.0
## Rule N (navigable terrain): the clearance (m) every gap, bore and pocket must leave (the biggest body's radius plus a
## margin; water a ball this size can't reach from the start is filled in), and the thinnest rock lip kept (m; thinner
## fins are rounded off). 0 switches either off.
@export_range(0.0, 30.0, 0.25, "or_greater") var terrain_clearance := 4.0
@export_range(0.0, 6.0, 0.1, "or_greater") var terrain_lip := 1.0
## Collision for the rock (fish bump and slide on it).
@export var terrain_collision := true
## Ambient occlusion baked into the rock (0: none, 1: full).
@export_range(0.0, 1.0, 0.05) var terrain_ao := 1.0
## Set pieces (phase 7), each on a clearing of flat floor in the outer band, per stage: a whale fall skeleton, a sunken
## hull, a field of bubbling vents, and rock pillars rising to the top of the depth band. 0 switches one off.
@export_range(0, 4, 1, "or_greater") var terrain_whale_falls := 1
@export_range(0, 4, 1, "or_greater") var terrain_hulls := 1
@export_range(0, 4, 1, "or_greater") var terrain_vents := 1
@export_range(0, 6, 1, "or_greater") var terrain_pillars := 1
## Background life: schools of fish roaming high over the outer band (how many, and fish in each).
@export_range(0, 12, 1, "or_greater") var terrain_schools := 3
@export_range(1, 200, 1, "or_greater") var terrain_school_fish := 24
## Dressing the rock (phase 4), all placed by the terrain: kelp columns on its flats with more than 9 m of water above
## (as tall as that allows, up to terrain_kelp_max m), frond clumps under overhangs, tufts on walls, carpet tufts on
## flats, corals/sponges/anemones on the lower flats and boulders on slopes. Counts across the arena; 0 switches one off.
@export_range(0, 2000, 10, "or_greater") var terrain_kelp := 160
@export_range(15.0, 80.0, 1.0, "or_greater") var terrain_kelp_max := 34.0
@export_range(0, 4000, 10, "or_greater") var terrain_fronds := 420
@export_range(0, 8000, 10, "or_greater") var terrain_wall_tufts := 1400
@export_range(0, 20000, 50, "or_greater") var terrain_carpets := 2500
@export_range(0, 4000, 10, "or_greater") var terrain_corals := 360
@export_range(0, 2000, 10, "or_greater") var terrain_boulders := 160

@export_group("Terrain Look")
## The rock's material (phase 3): how much of the rocky floor's violet/teal/ochre crust it wears (0..1) and how much that
## crust fluoresces, sand settling on its low flats (blending into the sand floor), the grotto zone's violet tint, and
## an overall brightness. Live.
@export_range(0.0, 1.0, 0.05) var terrain_crust := 0.65
@export_range(0.0, 4.0, 0.05, "or_greater") var terrain_crust_glow := 1.0
@export_range(0.0, 1.0, 0.05) var terrain_sand_blend := 1.0
@export_range(0.0, 1.0, 0.05) var terrain_zone_tint := 0.8
@export_range(0.0, 3.0, 0.05, "or_greater") var terrain_rock_bright := 1.0
## Light that rock blocks (phase 5): a skylight/openness volume and a static sun shadow, baked when the terrain is built.
## Off: everything lit as in open water.
@export var terrain_light_enabled := true
## The volume's cell (m) and the openness it measures out to (m); how much skylight the water itself soaks up per cell
## (0: only rock blocks it). Applied at the next build.
@export_range(0.25, 8.0, 0.25, "or_greater") var terrain_light_cell := 1.5
@export_range(0.5, 40.0, 0.5, "or_greater") var terrain_open_reach := 8.0
@export_range(0.0, 0.2, 0.002) var terrain_sky_absorb := 0.0
## How dark the skylight makes covered places (0: not at all, 1: fully) and the darkest a deep grotto gets (0..1). Live.
@export_range(0.0, 1.0, 0.05) var terrain_skylight := 0.7
@export_range(0.0, 1.0, 0.02) var terrain_grotto_dark := 0.3
## The sun's shadow from the rock: strength (0: none), the bake's cell (m, next build) and the edge softness (m, live).
@export_range(0.0, 1.0, 0.05) var terrain_sun_shadow := 0.7
@export_range(0.25, 8.0, 0.25, "or_greater") var terrain_shadow_cell := 1.0
@export_range(0.0, 10.0, 0.1, "or_greater") var terrain_shadow_soft := 1.5
## Darkening near rock from the openness (contact AO for everything, 0..1), how much the fog's glow darkens inside
## covered water (0..1), and whether the light shafts stop under rock (0..1). Live.
@export_range(0.0, 1.0, 0.05) var terrain_open_ao := 0.3
@export_range(0.0, 1.0, 0.05) var terrain_fog_dark := 0.45
@export_range(0.0, 1.0, 0.05) var terrain_shaft_cut := 1.0

@export_group("Flora")
## Blade flora (planning_abyssal_look.md): the kelp is built from thousands of curved ribbon blades, each one instance of a
## small mesh, shaded for arc, twist, ruffle, sway, translucency and sparkle. Off: the old three-stipe kelp meshes.
## (Layout values apply when the next stage is built; the look values below apply live.)
@export var flora_blades := true
## Blades per metre of strand height in a kelp column (the base the density multiplies).
@export_range(0.0, 200.0, 1.0, "or_greater") var flora_blades_per_m := 30.0
## Kelp density: multiplies the blades of every forest column.
@export_range(0.0, 8.0, 0.05, "or_greater") var flora_kelp_density := 1.6
## How tall the kelp columns grow, as a multiple of the 6.5-9.5 m base (towering kelp frames the view).
@export_range(0.3, 5.0, 0.05, "or_greater") var flora_kelp_height := 1.8
## Blade count multiplier for all blade flora (kelp now, cover and grass as they are added).
@export_range(0.0, 8.0, 0.05, "or_greater") var flora_blade_mult := 1.0
## How dense the arena edge's tall kelp band is compared with a forest (it has far more, taller, columns).
@export_range(0.0, 4.0, 0.05, "or_greater") var flora_edge_density := 0.25
## How far blade flora is drawn (m; 0: follow the murk like the rest of the scenery).
@export_range(0.0, 1000.0, 5.0, "or_greater") var flora_draw_distance := 0.0
## Where the full blade mesh gives way to the thin far level (m; 0: always full).
@export_range(0.0, 300.0, 1.0, "or_greater") var flora_lod_distance := 28.0
## The share of blades the far level keeps (the rest are dropped there, the kept ones drawn wider).
@export_range(0.05, 1.0, 0.01) var flora_far_keep := 0.6
## Rows (pairs of vertices) in the near blade mesh, and in the far one.
@export_range(2, 24, 1, "or_greater") var flora_rows := 7
@export_range(2, 12, 1, "or_greater") var flora_rows_far := 3
## Sparkles riding on the kelp per metre of column height (0: none; the global Kelp glints switch also applies).
@export_range(0.0, 40.0, 0.1, "or_greater") var flora_glints_per_m := 4.0
## Ground-cover carpets: how many patches of small tufts are laid (they go where the reef is, round rocks and ruins, and in a few
## open spots). 0: no carpets. Layout values apply when the next stage is built.
@export_range(0, 3000, 5, "or_greater") var flora_cover_patches := 90
## Carpet tufts per square metre at a patch's middle (thinning toward its edge; each tuft is 2-4 blades).
@export_range(0.0, 400.0, 0.5, "or_greater") var flora_cover_per_m2 := 16.0
## Mean radius of a carpet patch (m).
@export_range(0.5, 120.0, 0.5, "or_greater") var flora_cover_radius := 4.0
## Size of the carpet tufts (1: abyssal-garden's 8-26 cm).
@export_range(0.1, 10.0, 0.05, "or_greater") var flora_cover_size := 1.0
## Grass clusters (long teal and cyan ribbons, 8-22 at a time) on open ground in the grass zones, on top of the old sea-grass spots.
@export_range(0, 20000, 10, "or_greater") var flora_grass_clusters := 500
## Blades in each of those clusters.
@export_range(1.0, 200.0, 1.0, "or_greater") var flora_grass_blades := 16.0
## Length of the grass blades (1: 1-3 m for the big clusters, 0.5-1.4 m for the sea-grass spots).
@export_range(0.1, 10.0, 0.05, "or_greater") var flora_grass_size := 1.0
## The sea-grass spots grow blade grass in place of the old sea-grass meshes (off: the meshes stay and no blades grow there).
@export var flora_replace_seagrass := true
## Blades in the grass clump that stands in for each old sea-grass mesh.
@export_range(0.0, 100.0, 0.5, "or_greater") var flora_seagrass_blades := 7.0
## Tufts ringing the foot of every seabed rock (per metre of its width), and tufts on the sides of rocks and outcrops (each).
@export_range(0.0, 60.0, 0.1, "or_greater") var flora_rock_tufts := 5.0
@export_range(0.0, 60.0, 0.1, "or_greater") var flora_wall_tufts := 3.0
## Hanging clumps under outcrop rocks and ruin architraves (per overhang), and the blades in each clump.
@export_range(0.0, 60.0, 0.1, "or_greater") var flora_frond_clumps := 2.0
@export_range(1.0, 200.0, 1.0, "or_greater") var flora_frond_blades := 10.0
## Growth on the ruins (carpet at their edge, tufts on the platform and column feet, fronds under the beams): multiplies those counts.
@export_range(0.0, 20.0, 0.05, "or_greater") var flora_ruin_cover := 2.0
## The most blades the carpets, grass, tufts and fronds may add in all (0: no limit).
@export_range(0, 2000000, 1000, "or_greater") var flora_cover_budget := 600000
## Sway of the blades in the current (1: as in abyssal-garden), their width, their length and their brightness.
@export_range(0.0, 10.0, 0.05, "or_greater") var flora_sway := 1.0
@export_range(0.1, 6.0, 0.05, "or_greater") var flora_width := 1.4
@export_range(0.1, 6.0, 0.05, "or_greater") var flora_length := 1.0
@export_range(0.0, 8.0, 0.05, "or_greater") var flora_brightness := 2.0

@export_group("Terrain Play")
## Gameplay on the terrain (planning_procedural_world.md, phase 6). Room (m) kept round anything placed on the seabed
## (chests, shrines, the rift) and round spawns, beyond its own size: picks that land on or under the rock move.
@export_range(0.0, 20.0, 0.25, "or_greater") var terrain_spot_room := 2.0
## Fish drive on the rock when they touch it (rl_surface_mechanics) instead of swimming off it. Off: the rock is
## scenery to swim round (rule N).
@export var terrain_stick_to_rock := false
## Zombies have no physics: each one inside the rock (or closer than its radius plus terrain_horde_room m) is pushed out
## along the rock's normal, this share of the way per physics tick (0: off, 1: all the way).
@export_range(0.0, 1.0, 0.05) var terrain_horde_push := 1.0
@export_range(0.0, 10.0, 0.1, "or_greater") var terrain_horde_room := 0.5
## How many physics ticks each zombie waits between rock checks (1: every tick; more spreads the cost over the horde).
@export_range(1, 30, 1, "or_greater") var terrain_horde_check_every := 2
## Bots don't head for a spot the rock blocks (a line check, Terrain.line_clear).
@export var terrain_bot_sight := true

@export_group("Murk")
## Murky water (planning_murk.md): the fog's density in the arena (0: the
## ocean's own, with the blood moon's). The edge's thickening goes on top.
## At 0.035 the fog is 50% at 20 m, 85% at 55 m and 95% at 86 m.
@export_range(0.0, 0.2, 0.001, "or_greater") var murk_density := 0.035
## How much of the sky the fog covers while it's murky (1: all of it, so
## nothing fogged out stands against the sky).
@export_range(0.0, 1.0, 0.05) var murk_sky := 1.0
## Zombies are drawn only while the fog over them is under this (1: always
## drawn): -ln(1 - murk_cull) / density metres from the camera, plus
## murk_cull_margin. 0.98 at 0.035 is about 112 m.
@export_range(0.5, 1.0, 0.005) var murk_cull := 0.98
@export_range(0.0, 100.0, 1.0, "or_greater") var murk_cull_margin := 5.0
## Zombies behind every camera aren't drawn either.
@export var murk_frustum := true
## Zombies where the fog over them is this thick or more (from every player)
## steer only every far_update_divisor-th step, instead of past far_distance
## (0: far_distance). 0.85 at 0.035 is about 54 m.
@export_range(0.0, 0.999, 0.01) var murk_far := 0.85
## With murk, packs may turn up in view too (in the murk, all round you), not
## only out of every player's view.
@export var murk_spawn_anywhere := true
## Red eyes in the dark: zombies from where the fog is glint_from thick out to
## glint_distance (m; 0: none) show a pair of glowing eyes through the murk,
## fading with distance. A hint of the next wave, not a beacon.
@export_range(0.0, 1.0, 0.05) var glint_from := 0.8
@export_range(0.0, 600.0, 5.0, "or_greater") var glint_distance := 110.0
@export_range(0.0, 5.0, 0.05, "or_greater") var glint_strength := 0.25
## Each eye's size (m), times the zombie's size.
@export_range(0.01, 1.0, 0.01, "or_greater") var glint_size := 0.09
## The eyes grow with distance, times (1 + d / glint_grow) (d in m), so far ones
## stay a pixel or two instead of shrinking away (0: they never grow; lower: bigger far eyes).
@export_range(0.0, 1000.0, 5.0, "or_greater") var glint_grow := 120.0
## The share of the glint band (from where they start out to glint_distance)
## over which the eyes dim away at its far end, a smooth ramp (0: a hard edge;
## 1: they dim all the way out).
@export_range(0.0, 1.0, 0.05) var glint_fade_far := 0.5
## Zombies close enough to see have a pair of red eyes on their heads
## (near_eye_strength, their glow; 0: none). For the last eye_handoff m before
## the glints start, the eyes cross over to the glints, so they never vanish as
## a zombie closes in. head_glow: the faint red rot glow over the front of the head (times eye_glow).
@export_range(0.0, 20.0, 0.1, "or_greater") var near_eye_strength := 4.0
@export_range(0.0, 60.0, 0.5, "or_greater") var eye_handoff := 8.0
@export_range(0.0, 4.0, 0.05, "or_greater") var head_glow := 0.25


## The fog's amount `distance` m out at `density` (Godot's exponential fog).
static func fog_at(distance: float, density: float) -> float:
	return 1.0 - exp(-maxf(distance, 0.0) * maxf(WaterLook.fog_sigma(density), 0.0))


## How far out the fog reaches `amount` at `density` (INF: never). With the water model on it is where green
## light has died by `amount`: exp(-SIG.g * d) < 1 - amount, SIG scaled by density / density_ref.
static func fog_reach(amount: float, density: float) -> float:
	var sigma := WaterLook.fog_sigma(density)
	if sigma <= 0.0 or amount >= 1.0:
		return INF
	return -log(1.0 - clampf(amount, 0.0, 0.999999)) / sigma


## Murk is on (a density set).
func murky() -> bool:
	return murk_density > 0.0
