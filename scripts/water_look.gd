class_name WaterLook
extends Resource
## The underwater look (planning_abyssal_look.md): the water model's constants
## (how fast each colour dies with distance and with depth, the water's own
## colour), the Sunlit preset that copies abyssal-garden's, and the Look Tank's
## own options. Shown in the tuning panel's WATER LOOK section and saved with
## presets ([water_look]). One shared copy (shared()) is what the water code
## reads, live. Later phases add their groups here (grading, caustics, surface,
## particles, shafts, quality), as panel settings with wide ranges.
##
## Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
## (the Sunlit constants).

## Which constants the model uses: ours (darker, moodier) or Sunlit (bright teal, as in abyssal-garden). Choosing one copies its values in below; edit any of them after.
enum Preset { OURS, SUNLIT }

## abyssal-garden's constants (Appendix A, 1).
const SUNLIT_SIG := Vector3(0.058, 0.0235, 0.0195)
const SUNLIT_KD := Vector3(0.056, 0.0245, 0.017)
const SUNLIT_WCOL := Vector3(0.16, 0.58, 0.90)
const SUNLIT_PCOL := Vector3(0.58, 0.66, 0.98)
const SUNLIT_FADE := Vector2(185.0, 230.0)
## Ours: the same shape, a little clearer water and a darker, greener colour. First guesses, tuned against the Look Tank in phase 2.
## (Green is 0.012, the scene's old fog density, so the murk's numbers and fog_reach() mean what they always did.)
const OURS_SIG := Vector3(0.030, 0.012, 0.0099)
const OURS_KD := Vector3(0.056, 0.0245, 0.017)
const OURS_WCOL := Vector3(0.025, 0.11, 0.19)
const OURS_PCOL := Vector3(0.36, 0.44, 0.70)
const OURS_FADE := Vector2(150.0, 220.0)

static var _shared: WaterLook


static func shared() -> WaterLook:
	if _shared == null:
		_shared = WaterLook.new()
	return _shared


@export_group("Water model")
## Ours or Sunlit; picking one copies its constants into the options below (so a preset loaded from a file, which lists them all, still wins).
@export var preset := Preset.OURS:
	set(value):
		preset = value
		if value == Preset.SUNLIT:
			_copy(SUNLIT_SIG, SUNLIT_KD, SUNLIT_WCOL, SUNLIT_PCOL, SUNLIT_FADE)
		else:
			_copy(OURS_SIG, OURS_KD, OURS_WCOL, OURS_PCOL, OURS_FADE)
## How fast each colour dies per metre of water you look through (red, green, blue). Red goes about 3 times faster than blue.
@export_range(0.0, 1.0, 0.0005, "or_greater") var sig_r := OURS_SIG.x
@export_range(0.0, 1.0, 0.0005, "or_greater") var sig_g := OURS_SIG.y
@export_range(0.0, 1.0, 0.0005, "or_greater") var sig_b := OURS_SIG.z
## How fast sunlight loses each colour per metre of depth below the surface (red, green, blue).
@export_range(0.0, 1.0, 0.0005, "or_greater") var kd_r := OURS_KD.x
@export_range(0.0, 1.0, 0.0005, "or_greater") var kd_g := OURS_KD.y
@export_range(0.0, 1.0, 0.0005, "or_greater") var kd_b := OURS_KD.z
## The water's own colour (the albedo of what scatters sunlight toward you), red, green, blue.
@export_range(0.0, 4.0, 0.01, "or_greater") var wcol_r := OURS_WCOL.x
@export_range(0.0, 4.0, 0.01, "or_greater") var wcol_g := OURS_WCOL.y
@export_range(0.0, 4.0, 0.01, "or_greater") var wcol_b := OURS_WCOL.z
## The water's colour in the shallows and toward the surface (the second, paler palette the model fades to), red, green, blue.
@export_range(0.0, 4.0, 0.01, "or_greater") var pcol_r := OURS_PCOL.x
@export_range(0.0, 4.0, 0.01, "or_greater") var pcol_g := OURS_PCOL.y
@export_range(0.0, 4.0, 0.01, "or_greater") var pcol_b := OURS_PCOL.z
## Where things start fading to pure water colour (m), and where they are gone.
@export_range(0.0, 2000.0, 5.0, "or_greater") var fade_start := OURS_FADE.x
@export_range(0.0, 2000.0, 5.0, "or_greater") var fade_end := OURS_FADE.y

@export_group("Water fog")
## Phase 2: the water model itself (per-colour absorption and in-scattered water colour, worked out per camera from the depth buffer). Off gives back the plain one-colour Environment fog and procedural sky.
@export var model_enabled := true
## The fog density that means "1x" (the scene's own, 0.012). The Environment's fog density, the murk and the arena edge are all measured against it: they scale the whole water model (SIG) by density / this.
@export_range(0.001, 0.2, 0.001, "or_greater") var density_ref := 0.012
## Where the water's surface is (world height, m) in the Ocean modes. Depth below it drives how much sunlight and colour is left. Unnatural uses its own surface instead.
@export_range(-1000.0, 1000.0, 0.5, "or_greater", "or_less") var surface_height := 30.0
## How much of the water colour is added as light in the fog (1 as modelled; below it the water looks emptier, above it thicker and brighter).
@export_range(0.0, 8.0, 0.01, "or_greater") var inscatter_gain := 1.0
## The fog glows toward the sun: this much everywhere (base) and this much more looking at it (forward, rises with the 4th power of how directly you look at the sun).
@export_range(0.0, 8.0, 0.01, "or_greater") var phase_base := 1.22
@export_range(0.0, 8.0, 0.01, "or_greater") var phase_forward := 0.3
## How much of the Environment's own fog stays on for see-through things (bubbles, shafts, jellies) that the per-camera pass cannot reach. The opaque world has this part undone first, so it is not fogged twice; 1 matches the water exactly in density, 0 leaves see-through things unfogged.
@export_range(0.0, 2.0, 0.01) var transparent_fog := 0.35
## The sky: how far out (m) the water is looked through (the horizon's colour), and its brightness.
@export_range(10.0, 2000.0, 5.0, "or_greater") var sky_distance := 240.0
@export_range(0.0, 8.0, 0.01, "or_greater") var sky_gain := 1.0
@export_group("Depth exposure")
## The picture's brightness near the surface (1 is unchanged). It rises to 1 with depth, so the shallows are not blown out and the deep reads as dim, not black.
@export_range(0.0, 2.0, 0.01) var depth_exposure_min := 0.85
## How deep (m below the surface) the brightness starts rising, and how many metres it takes to reach full.
@export_range(0.0, 500.0, 0.5, "or_greater") var depth_exposure_start := 6.0
@export_range(1.0, 500.0, 0.5, "or_greater") var depth_exposure_range := 40.0
## How much the sun's colour and brightness follow the depth (0 a flat sun, 1 sunlight dies per colour exactly as the model says).
@export_range(0.0, 1.0, 0.01) var sun_depth_tint := 0.4
@export_group("Caustics")
## Phase 3: the sun's rippled light drawn on sun-facing sand, stone, reef, kelp and coral. Off turns it off everywhere.
@export var caustics_enabled := true
## How bright the caustics are (0 none; 1 adds about the surface's own colour times the pattern at the surface, dimmed by depth like sunlight).
@export_range(0.0, 8.0, 0.01, "or_greater") var caustic_strength := 0.5
## Pattern size: how many pattern tiles per metre (smaller is bigger, slower-looking ripples).
@export_range(0.01, 4.0, 0.01, "or_greater") var caustic_scale := 0.2
## How fast the pattern moves (1 as abyssal-garden's; the clock stops while the game is paused).
@export_range(0.0, 8.0, 0.01, "or_greater") var caustic_speed := 1.0
## The distance (m) the caustics start fading, and the distance they are gone.
@export_range(0.0, 1000.0, 1.0, "or_greater") var caustic_fade_start := 35.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var caustic_fade_end := 100.0
## The colour split between red, green and blue (the colours bend differently): 0 one pattern (cheapest, grey-white), 1 as abyssal-garden's.
@export_range(0.0, 8.0, 0.05, "or_greater") var caustic_split := 1.0
@export_group("Surface")
## Phase 4: the water's surface seen from below (waves, Snell's window onto the sky and sun, a mirror of the deep past its rim). Off leaves open water with no ceiling (and Unnatural's old red plane).
@export var surface_enabled := true
## How far the surface plane reaches around each camera (m); past it the sky's water takes over. Kept inside the camera's far plane.
@export_range(50.0, 20000.0, 10.0, "or_greater") var surface_radius := 900.0
## How steep the waves are (1 as built; 0 a flat mirror, higher is choppier).
@export_range(0.0, 8.0, 0.01, "or_greater") var surface_waves := 1.0
## How fast the waves move (1 normal; the clock stops while the game is paused).
@export_range(0.0, 8.0, 0.01, "or_greater") var surface_wave_speed := 1.0
## How far (m) the waves flatten out toward the horizon, so the rim of the window does not shimmer.
@export_range(5.0, 2000.0, 5.0, "or_greater") var surface_calm_distance := 90.0
## The sky seen through the window, red, green and blue (brightness included).
@export_range(0.0, 8.0, 0.01, "or_greater") var surface_sky_r := 0.45
@export_range(0.0, 8.0, 0.01, "or_greater") var surface_sky_g := 0.65
@export_range(0.0, 8.0, 0.01, "or_greater") var surface_sky_b := 1.0
## The sun's disc through the window: the soft halo, and the hard core (HDR, so the glow catches it).
@export_range(0.0, 64.0, 0.05, "or_greater") var surface_sun_halo := 1.3
@export_range(0.0, 256.0, 0.1, "or_greater") var surface_sun_core := 12.0
## The Blood Moon's disc through the window instead of the sun (halo, core), and the red sky around it (red, green, blue).
@export_range(0.0, 64.0, 0.05, "or_greater") var moon_disc_halo := 2.0
@export_range(0.0, 256.0, 0.1, "or_greater") var moon_disc_core := 40.0
@export_range(0.0, 8.0, 0.01, "or_greater") var moon_sky_r := 0.45
@export_range(0.0, 8.0, 0.01, "or_greater") var moon_sky_g := 0.04
@export_range(0.0, 8.0, 0.01, "or_greater") var moon_sky_b := 0.05
@export_group("Blood Moon water")
## The water's colour when the Blood Moon is fully on (red, green, blue), and how much of the sunlight's depth loss is left (1 the normal loss, below it the red survives deeper).
@export_range(0.0, 4.0, 0.01, "or_greater") var moon_wcol_r := 0.18
@export_range(0.0, 4.0, 0.01, "or_greater") var moon_wcol_g := 0.028
@export_range(0.0, 4.0, 0.01, "or_greater") var moon_wcol_b := 0.038
@export_range(0.0, 2.0, 0.01) var moon_kd_scale := 0.35

@export_group("Grading")
## Phase 1: the colour grade every Ocean mode wears (an Environment adjustment plus a per-camera vignette and S-curve pass). Off gives back the old plain filmic look.
@export var grade_enabled := true
## ACES tonemapping (on) or the game's old filmic curve (off).
@export var tonemap_aces := true
## The tonemapper's white point (the brightness that maps to white). Lower is punchier, higher flatter.
@export_range(0.25, 16.0, 0.05, "or_greater") var tonemap_white := 1.0
## Overall exposure going into the tonemapper (1 is unchanged).
@export_range(0.0, 8.0, 0.01, "or_greater") var exposure := 1.6
## Colour saturation after tonemapping. Below 1 pulls the colours back a little (abyssal-garden uses 0.93).
@export_range(0.0, 3.0, 0.01, "or_greater") var grade_saturation := 0.93
## Contrast after tonemapping (1 is unchanged; about 1.05 is a gentle S).
@export_range(0.25, 3.0, 0.01, "or_greater") var grade_contrast := 1.05
## Brightness after tonemapping (1 is unchanged).
@export_range(0.25, 3.0, 0.01, "or_greater") var grade_brightness := 1.0
## How dark the screen's corners get (0 none, 1 black at the very corner). Worked out per view, so split-screen views each get their own.
@export_range(0.0, 1.0, 0.01) var vignette := 0.3
## How far from the centre the vignette begins (0 the middle, 1 the corner).
@export_range(0.0, 1.0, 0.01) var vignette_start := 0.35
## The luminance S-curve: how much of a smoothstep is mixed into the brightness (0 none, 1 full). Deepens shadows and lifts highlights without changing colour.
@export_range(0.0, 1.0, 0.01) var curve := 0.3
## How much highlights lose their colour toward white (0 none, 1 fully grey above the start).
@export_range(0.0, 1.0, 0.01) var highlight_desat := 0.3
## The brightness where highlights begin to desaturate.
@export_range(0.0, 4.0, 0.01, "or_greater") var highlight_start := 0.55
@export_group("Bloom")
## Soft glow around bright things (sparkles, lamps, flashes).
@export var glow_enabled := true
## How much of the glow is mixed over the picture (Mix blend mode; about 0.08 is soft).
@export_range(0.0, 1.0, 0.005) var glow_mix := 0.08
## How strongly the glow itself is boosted before it is mixed.
@export_range(0.0, 8.0, 0.05, "or_greater") var glow_strength := 1.0
## How much of the whole picture (not just the bright parts) feeds the glow. 0 means only things brighter than the threshold glow.
@export_range(0.0, 1.0, 0.01) var glow_bloom := 0.0
## The brightness above which things start to glow.
@export_range(0.0, 8.0, 0.05, "or_greater") var glow_threshold := 1.0
## How quickly the glow comes in above the threshold.
@export_range(0.0, 8.0, 0.05, "or_greater") var glow_ramp := 2.0
## The glow's blur levels, 1 the tightest to 6 the widest. Weighted to the low levels it is a close halo, not a wash.
@export_range(0.0, 2.0, 0.05, "or_greater") var glow_level_1 := 1.0
@export_range(0.0, 2.0, 0.05, "or_greater") var glow_level_2 := 1.0
@export_range(0.0, 2.0, 0.05, "or_greater") var glow_level_3 := 0.7
@export_range(0.0, 2.0, 0.05, "or_greater") var glow_level_4 := 0.5
@export_range(0.0, 2.0, 0.05, "or_greater") var glow_level_5 := 0.35
@export_range(0.0, 2.0, 0.05, "or_greater") var glow_level_6 := 0.2
@export_group("Blood Moon grade")
## The Blood Moon multiplies the grade by these, in step with how red it is (1 leaves the grade alone). Saturation:
@export_range(0.0, 3.0, 0.01, "or_greater") var moon_saturation := 1.12
## Vignette strength under the Blood Moon.
@export_range(0.0, 4.0, 0.01, "or_greater") var moon_vignette := 1.3
## Glow (mix) under the Blood Moon.
@export_range(0.0, 4.0, 0.01, "or_greater") var moon_glow := 1.3

@export_group("Light shafts")
## Phase 6: shafts of sunlight (or the Blood Moon's light) slanting down from the surface, shaped by the caustic pattern, fading with depth, with a glow when you look toward the sun. Replaces Unnatural's old red cylinders.
@export var shafts_enabled := true
## How many shafts are out in the water round each camera (they wrap round it as it moves). Changes live up to 64.
@export_range(0, 64, 1, "or_greater") var shaft_count := 14
## Edge of the square of water the shafts fill round each camera (m).
@export_range(10.0, 2000.0, 1.0, "or_greater") var shaft_range := 110.0
## How far down (m, along the light) a shaft reaches from the surface.
@export_range(5.0, 1000.0, 1.0, "or_greater") var shaft_length := 90.0
## How far above the surface line (m) a shaft starts, so none ends in view while you look up.
@export_range(0.0, 200.0, 0.5, "or_greater") var shaft_overshoot := 6.0
## A shaft's radius at the surface (m); each shaft is between 0.6 and 1.6 times this.
@export_range(0.1, 100.0, 0.05, "or_greater") var shaft_radius := 2.6
## How many times wider a shaft is at its foot than at the surface.
@export_range(0.5, 10.0, 0.05, "or_greater") var shaft_widen := 2.5
## Overall brightness (HDR above 1, so the bloom catches it).
@export_range(0.0, 32.0, 0.01, "or_greater") var shaft_strength := 0.35
## The light's colour before the water takes the red out of it (red, green, blue).
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_color_r := 0.9
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_color_g := 0.95
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_color_b := 1.0
## The Blood Moon's shaft colour (red, green, blue), blended in by how red the night is.
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_moon_r := 1.0
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_moon_g := 0.2
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_moon_b := 0.12
## How much of a shaft is the caustic net (0: a smooth shaft, 1: striped by the pattern).
@export_range(0.0, 1.0, 0.01) var shaft_pattern := 0.8
## Size of the pattern in the shafts (cells per metre; the caustics use 0.2 on the ground) and how fast it moves (1: the same as the caustics).
@export_range(0.005, 4.0, 0.005, "or_greater") var shaft_pattern_scale := 0.11
@export_range(0.0, 8.0, 0.01, "or_greater") var shaft_pattern_speed := 1.0
## A shaft fades out over this many metres where it meets something solid, so it has no hard cut.
@export_range(0.0, 50.0, 0.05, "or_greater") var shaft_soft := 3.0
## How strongly a shaft glows when you look toward the light: brightness is base + gain x (facing the light)^3.
@export_range(0.0, 4.0, 0.01, "or_greater") var shaft_phase_base := 0.2
@export_range(0.0, 16.0, 0.01, "or_greater") var shaft_phase_gain := 2.0
## How much a shaft's edge fades (higher: a softer, more tube-like core).
@export_range(0.0, 8.0, 0.05, "or_greater") var shaft_edge := 1.5
## Shafts fade out within this many metres of the camera, so you can swim through them without a pop.
@export_range(0.0, 50.0, 0.1, "or_greater") var shaft_near_fade := 4.0
## The share of a shaft's length at its foot that fades to nothing.
@export_range(0.0, 1.0, 0.01) var shaft_foot_fade := 0.4
@export_group("Marine snow")
## Specks of marine snow drifting through the water (quads that face the camera, wrapped round each view).
@export var snow_enabled := true
## How many flakes are out (the cube holds this many; fewer is cheaper). Changes live up to snow_max.
@export_range(0, 20000, 100, "or_greater") var snow_count := 1800
## Edge of the cube of water the flakes fill round each camera (m).
@export_range(5.0, 400.0, 1.0, "or_greater") var snow_box := 44.0
## A flake's radius (m); the largest flakes are up to three times this.
@export_range(0.002, 1.0, 0.001, "or_greater") var snow_size := 0.022
## No flake is drawn smaller than this many pixels across; it gets dimmer instead, so the total light stays the same and nothing shimmers.
@export_range(0.0, 16.0, 0.1, "or_greater") var snow_min_px := 1.6
## Fades in from snow_near_a to snow_near_b metres from the camera, and out from snow_far_a to snow_far_b.
@export_range(0.0, 100.0, 0.05, "or_greater") var snow_near_a := 0.6
@export_range(0.0, 100.0, 0.05, "or_greater") var snow_near_b := 2.5
@export_range(0.0, 1000.0, 0.5, "or_greater") var snow_far_a := 14.0
@export_range(0.0, 1000.0, 0.5, "or_greater") var snow_far_b := 22.0
## Brightness above 1 is HDR, so the bloom catches the flakes.
@export_range(0.0, 32.0, 0.05, "or_greater") var snow_peak := 1.5
@export_range(0.0, 4.0, 0.01, "or_greater") var snow_color_r := 0.7
@export_range(0.0, 4.0, 0.01, "or_greater") var snow_color_g := 0.9
@export_range(0.0, 4.0, 0.01, "or_greater") var snow_color_b := 1.0
## How fast the flakes drift (m/s along each axis).
@export_range(-5.0, 5.0, 0.01, "or_greater", "or_less") var snow_drift_x := 0.22
@export_range(-5.0, 5.0, 0.01, "or_greater", "or_less") var snow_drift_y := 0.05
@export_range(-5.0, 5.0, 0.01, "or_greater", "or_less") var snow_drift_z := 0.13
@export_group("Kelp glints")
## Sparkles that twinkle on the kelp (additive billboards that sway with the blade). Plant count and glints per plant are read when the seabed is built.
@export var glints_enabled := true
## Glints on each kelp plant (read when the seabed is built).
@export_range(0, 64, 1, "or_greater") var glints_per_plant := 8
## The share of glints shown (0..1), live.
@export_range(0.0, 1.0, 0.01) var glint_density := 1.0
## A glint's radius (m).
@export_range(0.002, 1.0, 0.001, "or_greater") var glint_size := 0.05
## Smallest size on screen (pixels across); dimmer when held up to it.
@export_range(0.0, 16.0, 0.1, "or_greater") var glint_min_px := 2.5
@export_range(0.0, 32.0, 0.05, "or_greater") var glint_peak := 4.0
## How fast they twinkle.
@export_range(0.0, 20.0, 0.05, "or_greater") var glint_speed := 2.2
@export_range(0.0, 1000.0, 0.5, "or_greater") var glint_far_a := 25.0
@export_range(0.0, 1000.0, 0.5, "or_greater") var glint_far_b := 55.0
@export_range(0.0, 4.0, 0.01, "or_greater") var glint_color_r := 1.0
@export_range(0.0, 4.0, 0.01, "or_greater") var glint_color_g := 0.95
@export_range(0.0, 4.0, 0.01, "or_greater") var glint_color_b := 0.6
@export_group("Bubbles")
## Bubbles (a stride's stream and the bubble columns) get a wobbly rim, two highlights and a reflection of the water.
@export var bubbles_water_look := true
## How wobbly the rim is (0: a smooth ring).
@export_range(0.0, 2.0, 0.01, "or_greater") var bubble_wobble := 0.35
## Strength of the two highlight dots.
@export_range(0.0, 16.0, 0.05, "or_greater") var bubble_spec := 2.0
## How much of the water's colour shows reflected in a bubble.
@export_range(0.0, 16.0, 0.05, "or_greater") var bubble_reflect := 3.0

@export_group("Materials")
## Phase 7: the extra surface terms the reef, ruins, kelp and sand wear in the Ocean modes (fluorescence, kelp translucency and sparkle, rock strata and rim light, sand cover, the run's biome tint). Off gives back the old materials.
@export var materials_enabled := true
## Kelp: how much warm light shows through blades lit from behind (0 none).
@export_range(0.0, 8.0, 0.05, "or_greater") var kelp_translucency := 0.9
## Kelp: the warm tint of that translucent light, red, green and blue (above 1 is brighter than the blade).
@export_range(0.0, 4.0, 0.01, "or_greater") var kelp_warm_r := 1.5
@export_range(0.0, 4.0, 0.01, "or_greater") var kelp_warm_g := 1.4
@export_range(0.0, 4.0, 0.01, "or_greater") var kelp_warm_b := 0.75
## Kelp: thin-film iridescence, a hue shift with viewing angle (0 none, 1 strong).
@export_range(0.0, 2.0, 0.01, "or_greater") var kelp_iridescence := 0.3
## Kelp: how dark the vein stripes along each blade are (0 none).
@export_range(0.0, 2.0, 0.01, "or_greater") var kelp_veins := 0.4
## Kelp: the brightness of the sparkle band that travels up some blades (HDR, so the glow catches it), and the share of blades that have one.
@export_range(0.0, 16.0, 0.05, "or_greater") var kelp_sparkle := 1.6
@export_range(0.0, 1.0, 0.01) var kelp_sparkle_share := 0.24
## Reef and fan coral: how strongly the blue-green light that reaches them is re-emitted in their own colour (0 none, 1 as modelled), and each copy's fluorescence range.
@export_range(0.0, 8.0, 0.05, "or_greater") var coral_fluorescence := 1.0
@export_range(0.0, 4.0, 0.01, "or_greater") var coral_flu_min := 0.55
@export_range(0.0, 4.0, 0.01, "or_greater") var coral_flu_max := 0.75
## Coral tips: a highlight on the upper ends of polyps, tentacles and fans (0 none).
@export_range(0.0, 4.0, 0.01, "or_greater") var coral_tip := 0.5
## Rock and ruins: the strata (beds of tint, dark seams, olive and brown mix, red encrustation), the baked detail map, algae on up faces (1 as modelled), and the rim light.
@export_range(0.0, 2.0, 0.01, "or_greater") var rock_strata := 0.6
@export_range(0.0, 2.0, 0.01, "or_greater") var rock_detail := 0.5
@export_range(0.0, 4.0, 0.01, "or_greater") var rock_algae := 1.0
@export_range(0.0, 4.0, 0.01, "or_greater") var rock_rim := 0.35
## Sand: how much of the floor is covered by magenta encrusting growth (0 none).
@export_range(0.0, 2.0, 0.01, "or_greater") var sand_cover := 0.5
## The per-run biome tint on sand and rock (Unnatural): a colour cast picked from the run's seed, and how strong it is (0 none).
@export var biome_enabled := true
@export_range(0.0, 1.0, 0.01) var biome_strength := 0.4
@export_group("Quality")
## Which graphics quality to use whatever the Settings screen says: -1 follows Settings (Low, Medium or High, remembered per PC), 0 Low, 1 Medium, 2 High. For the Look Tank and benches.
@export_range(-1, 2, 1) var quality_force := -1
## Low and Medium keep this fraction of the marine snow (High keeps all of snow_count).
@export_range(0.0, 1.0, 0.01, "or_greater") var q_snow_low := 0.3
@export_range(0.0, 1.0, 0.01, "or_greater") var q_snow_med := 0.65
## ... and this fraction of the light shafts (shaft_count).
@export_range(0.0, 1.0, 0.01, "or_greater") var q_shaft_low := 0.4
@export_range(0.0, 1.0, 0.01, "or_greater") var q_shaft_med := 0.7
## ... and this fraction of the kelp glints (glint_density; 0 none).
@export_range(0.0, 1.0, 0.01, "or_greater") var q_glint_low := 0.0
@export_range(0.0, 1.0, 0.01, "or_greater") var q_glint_med := 0.6
## Caustics on Low cost one pattern tap instead of three (no red/green/blue split).
@export var q_low_single_caustic := true
## How many of the bloom's six levels run (the highest, widest-blur ones go first).
@export_range(0, 6, 1) var q_glow_levels_low := 3
@export_range(0, 6, 1) var q_glow_levels_med := 5
## The 3D render scale (1 is native). Below 1 the picture is rebuilt with FSR, so Low is a little soft and much cheaper.
@export_range(0.25, 2.0, 0.01, "or_greater") var q_scale_low := 0.77
@export_range(0.25, 2.0, 0.01, "or_greater") var q_scale_med := 1.0
@export_range(0.25, 2.0, 0.01, "or_greater") var q_scale_high := 1.0
## Auto render scale (Settings: Adaptive Resolution): it aims the GPU time at this share of the frame time, never below the floor scale.
@export_range(0.2, 1.5, 0.01) var auto_target := 0.85
@export_range(0.25, 1.0, 0.01) var auto_floor := 0.6
@export_group("Look Tank")
## The Look Tank camera's field of view (degrees) for its numbered viewpoints.
@export_range(20.0, 120.0, 1.0) var tank_fov := 70.0
## How many players the Look Tank's split-screen viewpoint (6) joins.
@export_range(2, 4, 1) var tank_split_players := 2
## Keeps the HUD (and the tuning panel's button hints) on screen in the Look Tank, off for clean shots.
@export var tank_hud := false
## Frames the Look Tank waits after moving to a viewpoint before a shot or a GPU reading, so fog, glints and the compositor have settled.
@export_range(0, 600, 1, "or_greater") var tank_settle_frames := 20
## The Blood Moon's strength in the Look Tank (0: the plain ocean the look is built for, 1: Unnatural's own red). Unnatural itself keeps UnnaturalSettings.blood_moon.
@export_range(0.0, 2.0, 0.05, "or_greater") var tank_blood_moon := 0.0
## Phase 6, option D4b bench: 1 turns on Godot's volumetric fog plus a FogVolume whose density follows the caustic net, in the Look Tank only (to measure its cost against the cheap shafts, which it replaces when on: set shafts_enabled 0 to compare).
@export_range(0, 1, 1) var tank_volfog := 0
## Density of that volumetric fog's FogVolume.
@export_range(0.0, 2.0, 0.001, "or_greater") var tank_volfog_density := 0.06


## The Environment properties the grade touches, so they can be given back (reset_grade).
const GRADE_PROPS: Array[String] = ["tonemap_mode", "tonemap_exposure", "tonemap_white", "adjustment_enabled", "adjustment_brightness",
		"adjustment_contrast", "adjustment_saturation", "glow_enabled", "glow_levels/1", "glow_levels/2", "glow_levels/3", "glow_levels/4",
		"glow_levels/5", "glow_levels/6", "glow_levels/7", "glow_normalized", "glow_intensity", "glow_strength", "glow_mix", "glow_bloom",
		"glow_blend_mode", "glow_hdr_threshold", "glow_hdr_scale", "glow_hdr_luminance_cap"]

## True while an Ocean mode's grade is on the environment (the per-camera pass reads it, so it does nothing in the other arenas).
static var grading_active := false

## How red the Blood Moon is now (0..1), set by BloodMoon; the grade multiplies by it.
var moon_share := 0.0

## The colour the water darkens to at an arena's edge (Ocean.boundary_radius).
const EDGE_COLOR := Color(0.01, 0.04, 0.08)
## True while an Ocean mode's water model is on (the per-camera fog pass and the sky read it). Set by Ocean, cleared by reset_grade.
static var fog_active := false
## The fog density now, as the arena and murk set it (1x is density_ref), before transparent_fog thins the Environment's own.
static var density_now := 0.012
## How far the camera is toward the arena's edge (0..1): the water darkens toward EDGE_COLOR.
static var edge_amount := 0.0
## A mode's own surface height (Unnatural's), or NAN for surface_height.
static var surface_override := NAN
## Where the Blood Moon's disc is (a direction from the camera), or (0,0,0) for none: the surface shows it through the window in place of the sun.
static var moon_dir := Vector3.ZERO
## How much of the density scale the sky gets (UnnaturalSettings.murk_sky: 1 the murk covers the sky fully, 0 the sky stays clear).
static var sky_murk := 1.0
## Direction toward the sun (Ocean keeps it in step with the DirectionalLight3D).
static var sun_dir := Vector3(0.4, 0.84, 0.4).normalized()
## What the Environment's fog is set to (linear), so the per-camera pass can undo it on opaque things exactly. Ocean keeps it current.
static var env_fog_linear := Color(0.0, 0.0, 0.0)
static var env_fog_density := 0.0


## The extinction of green light per metre at `density`: what fog_at() and fog_reach() measure the murk by. With the model on it is
## the water model's own (sig_g at density_ref is the old fog density, so by default it is `density` itself).
static func fog_sigma(density: float) -> float:
	if not fog_active:
		return density
	var look := shared()
	return density * look.sig_g / maxf(look.density_ref, 0.0001)


func surface_y() -> float:
	return surface_height if is_nan(surface_override) else surface_override


func density_scale() -> float:
	return density_now / maxf(density_ref, 0.0001)


## The water's colour now: the Blood Moon's red and the arena edge's dark folded in.
func eff_wcol() -> Vector3:
	var moon := Vector3(moon_wcol_r, moon_wcol_g, moon_wcol_b)
	var edge := Vector3(EDGE_COLOR.r, EDGE_COLOR.g, EDGE_COLOR.b)
	return wcol().lerp(moon, moon_share).lerp(edge, edge_amount)


func eff_kd() -> Vector3:
	return kd() * lerpf(1.0, moon_kd_scale, moon_share)


func sun_y() -> float:
	return maxf(sun_dir.y, 0.2)


## KD per metre of height along the sunlight (what `exp(k * y)` uses).
func kd_k() -> Vector3:
	return eff_kd() / sun_y()


## The brightness multiplier for a camera `camera_y` high: depth_exposure_min near the surface, 1 at depth.
func depth_exposure(camera_y: float) -> float:
	var depth := surface_y() - camera_y
	return lerpf(depth_exposure_min, 1.0, clampf((depth - depth_exposure_start) / maxf(depth_exposure_range, 0.01), 0.0, 1.0))


## The flat colour (linear) of the water for see-through things, `depth` m below the surface: the model's far colour there.
func flat_fog_color(depth: float) -> Color:
	var k := kd_k()
	var phase := (phase_base + phase_forward * 0.3) * inscatter_gain
	var c := eff_wcol() * phase
	return Color(c.x * exp(-k.x * depth), c.y * exp(-k.y * depth), c.z * exp(-k.z * depth))


## The sunlight's colour factor `depth` m down (1 at the surface), eased by sun_depth_tint.
func sun_factor(depth: float) -> Color:
	var k := kd_k()
	var t := Vector3(exp(-k.x * depth), exp(-k.y * depth), exp(-k.z * depth))
	t = Vector3.ONE.lerp(t, sun_depth_tint)
	return Color(t.x, t.y, t.z)


## Puts the grade on `env` (an Ocean mode's look). Safe to call again when a value changed.
func apply_grade(env: Environment) -> void:
	grading_active = grade_enabled
	if not grade_enabled:
		reset_grade(env, true)
		return
	env.tonemap_mode = Environment.TONE_MAPPER_ACES if tonemap_aces else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.tonemap_white = tonemap_white
	env.adjustment_enabled = true
	env.adjustment_brightness = grade_brightness
	env.adjustment_contrast = grade_contrast
	env.adjustment_saturation = eff_saturation()
	env.glow_enabled = glow_enabled
	var levels := [glow_level_1, glow_level_2, glow_level_3, glow_level_4, glow_level_5, glow_level_6, 0.0]
	var kept := eff_glow_levels()  # the quality tier drops the highest levels
	for i in levels.size():
		if i >= kept:
			levels[i] = 0.0
	for i in levels.size():
		env.set("glow_levels/%d" % (i + 1), levels[i])
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_MIX
	env.glow_mix = eff_glow()
	env.glow_strength = glow_strength
	env.glow_bloom = glow_bloom
	env.glow_hdr_threshold = glow_threshold
	env.glow_hdr_scale = glow_ramp


## Gives `env` the engine's own grade settings back, then the scene's (filmic, glow on), so the arenas that are not the Ocean look as they always did.
static func reset_grade(env: Environment, keep_active := false) -> void:
	if not keep_active:
		grading_active = false
		fog_active = false
		clear_caustics()
	var plain := Environment.new()
	for property in GRADE_PROPS:
		env.set(property, plain.get(property))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true


## Gives `env` the scene's own plain fog back (what the Ocean modes' water model changed), for the arenas that do not set their own.
static func restore_fog(env: Environment) -> void:
	env.fog_light_color = Color(0.04, 0.2, 0.28)
	env.fog_density = 0.012
	env.fog_sky_affect = 1.0


## A number that changes whenever anything the Environment grade uses changes (so a live panel edit is noticed cheaply).
func grade_signature() -> int:
	return [grade_enabled, tonemap_aces, tonemap_white, exposure, eff_saturation(), grade_contrast, grade_brightness, glow_enabled, eff_glow(),
			glow_strength, glow_bloom, glow_threshold, glow_ramp, glow_level_1, glow_level_2, glow_level_3, glow_level_4, glow_level_5,
			glow_level_6, eff_glow_levels()].hash()


func eff_saturation() -> float:
	return grade_saturation * lerpf(1.0, moon_saturation, moon_share)


func eff_glow() -> float:
	return glow_mix * lerpf(1.0, moon_glow, moon_share)


func eff_vignette() -> float:
	return vignette * lerpf(1.0, moon_vignette, moon_share)


func sig() -> Vector3:
	return Vector3(sig_r, sig_g, sig_b)


func kd() -> Vector3:
	return Vector3(kd_r, kd_g, kd_b)


func wcol() -> Vector3:
	return Vector3(wcol_r, wcol_g, wcol_b)


func pcol() -> Vector3:
	return Vector3(pcol_r, pcol_g, pcol_b)


func _copy(sig_v: Vector3, kd_v: Vector3, wcol_v: Vector3, pcol_v: Vector3, fade: Vector2) -> void:
	sig_r = sig_v.x
	sig_g = sig_v.y
	sig_b = sig_v.z
	kd_r = kd_v.x
	kd_g = kd_v.y
	kd_b = kd_v.z
	wcol_r = wcol_v.x
	wcol_g = wcol_v.y
	wcol_b = wcol_v.z
	pcol_r = pcol_v.x
	pcol_g = pcol_v.y
	pcol_b = pcol_v.z
	fade_start = fade.x
	fade_end = fade.y


## The shader globals the caustics read (water_caustics.gdshaderinc). Ocean calls this every frame with the water clock; it is
## a no-op to call it without the model on (the strength goes to 0, which is what every other arena sees).
func push_caustics(clock: float) -> void:
	var on := fog_active and caustics_enabled
	RenderingServer.global_shader_parameter_set("water_caustic_strength", caustic_strength if on else 0.0)
	if fog_active:
		RenderingServer.global_shader_parameter_set("water_time", clock)  # the shafts use the clock too
	if not on:
		return
	RenderingServer.global_shader_parameter_set("water_time", clock)
	RenderingServer.global_shader_parameter_set("water_caustic_scale", caustic_scale)
	RenderingServer.global_shader_parameter_set("water_caustic_speed", caustic_speed)
	RenderingServer.global_shader_parameter_set("water_caustic_fade_start", caustic_fade_start)
	RenderingServer.global_shader_parameter_set("water_caustic_fade_end", caustic_fade_end)
	RenderingServer.global_shader_parameter_set("water_caustic_split", eff_caustic_split())
	RenderingServer.global_shader_parameter_set("water_surface_y", surface_y())
	RenderingServer.global_shader_parameter_set("water_sun_dir", sun_dir)
	RenderingServer.global_shader_parameter_set("water_kd", kd_k())


## The run's seed (Seabed.setup sets it), which picks the biome tint.
static var biome_seed := 11


## The biome's colour cast: a hue from the seed, kept soft, so one run is violet ruins, another a green-gold garden.
func biome_color() -> Color:
	var h := fposmod(float(biome_seed) * 0.6180339, 1.0)
	return Color.from_hsv(h, 0.55, 1.0).lerp(Color.WHITE, 0.35)


## The shader globals the material pass reads (water_materials.gdshaderinc); Ocean calls this every frame. All zero (no model,
## or materials off) leaves every material as it was.
func push_materials() -> void:
	var on := fog_active and materials_enabled
	if not on:
		clear_materials()
		return
	var g := RenderingServer
	g.global_shader_parameter_set("water_mat_kelp", Vector4(kelp_translucency, kelp_iridescence, kelp_veins, kelp_sparkle))
	g.global_shader_parameter_set("water_mat_kelp2", Vector4(kelp_warm_r, kelp_warm_g, kelp_warm_b, kelp_sparkle_share))
	g.global_shader_parameter_set("water_mat_coral", Vector4(coral_fluorescence, coral_flu_min, maxf(coral_flu_max, coral_flu_min), coral_tip))
	g.global_shader_parameter_set("water_mat_rock", Vector4(rock_strata, rock_detail, rock_algae, rock_rim))
	g.global_shader_parameter_set("water_mat_sand", Vector4(sand_cover, 0.0, 0.0, 0.0))
	var c := biome_color()
	g.global_shader_parameter_set("water_biome", Vector4(c.r, c.g, c.b, biome_strength if biome_enabled else 0.0))


## Material pass off (any arena that is not an Ocean mode): everything reads zero and looks as before.
static func clear_materials() -> void:
	var z := Vector4(0.0, 0.0, 0.0, 0.0)
	for n in ["water_mat_kelp", "water_mat_kelp2", "water_mat_coral", "water_mat_rock", "water_mat_sand", "water_biome"]:
		RenderingServer.global_shader_parameter_set(n, z)


## Caustics off (any arena that is not an Ocean mode).
static func clear_caustics() -> void:
	RenderingServer.global_shader_parameter_set("water_caustic_strength", 0.0)
	clear_materials()
	RenderingServer.global_shader_parameter_set("water_bubble_look", Vector3(0.0, 0.0, 0.0))  # other arenas keep the plain bubbles


## The most shafts ever built (shaft_count can go up to this live).
const SHAFT_MAX := 64

static var shaft_material: ShaderMaterial


static func get_shaft_material() -> ShaderMaterial:
	if shaft_material == null:
		shaft_material = ShaderMaterial.new()
		shaft_material.shader = preload("res://shaders/light_shaft.gdshader")
		shaft_material.render_priority = -50  # after the fog pass and the surface, before the other see-through things
	return shaft_material


## Pushes the shafts' values to their shader. `dir` is the light's direction (toward it), `scale` the murk's multiplier on the water's
## extinction, and `moon` how red it is (0..1).
func push_shafts(dir: Vector3, scale: float, moon: float) -> void:
	var m := get_shaft_material()
	var d := dir.normalized()
	m.set_shader_parameter("sh_dir", d)
	m.set_shader_parameter("sh_surface_y", surface_y())
	m.set_shader_parameter("sh_range", shaft_range)
	m.set_shader_parameter("sh_len", shaft_length)
	m.set_shader_parameter("sh_over", shaft_overshoot)
	m.set_shader_parameter("sh_widen", shaft_widen)
	m.set_shader_parameter("sh_sig", sig() * scale)
	m.set_shader_parameter("sh_kd", eff_kd() / maxf(d.y, 0.2))
	var tint := Vector3(shaft_color_r, shaft_color_g, shaft_color_b).lerp(Vector3(shaft_moon_r, shaft_moon_g, shaft_moon_b), moon)
	m.set_shader_parameter("sh_color", tint * (shaft_strength if shafts_enabled else 0.0))
	m.set_shader_parameter("sh_pattern", shaft_pattern)
	m.set_shader_parameter("sh_pat_scale", shaft_pattern_scale)
	m.set_shader_parameter("sh_pat_speed", shaft_pattern_speed)
	m.set_shader_parameter("sh_soft", maxf(shaft_soft, 0.001))
	m.set_shader_parameter("sh_phase", Vector2(shaft_phase_base, shaft_phase_gain))
	m.set_shader_parameter("sh_edge", shaft_edge)
	m.set_shader_parameter("sh_near", maxf(shaft_near_fade, 0.01))
	m.set_shader_parameter("sh_foot", maxf(shaft_foot_fade, 0.001))


## The most flakes ever built (snow_count can go up to this live).
const SNOW_MAX := 20000

## Shared materials the particle shaders read (Ocean pushes them every frame, the seabed and stride streams use them).
static var glint_material: ShaderMaterial
static var snow_material: ShaderMaterial


static func get_glint_material() -> ShaderMaterial:
	if glint_material == null:
		glint_material = ShaderMaterial.new()
		glint_material.shader = preload("res://shaders/kelp_glint.gdshader")
	return glint_material


static func get_snow_material() -> ShaderMaterial:
	if snow_material == null:
		snow_material = ShaderMaterial.new()
		snow_material.shader = preload("res://shaders/water_snow.gdshader")
	return snow_material


## Pushes the particle values (snow, glints, bubbles' water colour) to the shaders. Called each frame by the Ocean.
func push_particles() -> void:
	var s := get_snow_material()
	s.set_shader_parameter("box_size", snow_box)
	s.set_shader_parameter("size", snow_size)
	s.set_shader_parameter("min_px", snow_min_px)
	s.set_shader_parameter("near_a", snow_near_a)
	s.set_shader_parameter("near_b", maxf(snow_near_b, snow_near_a + 0.01))
	s.set_shader_parameter("far_a", snow_far_a)
	s.set_shader_parameter("far_b", maxf(snow_far_b, snow_far_a + 0.01))
	s.set_shader_parameter("peak", snow_peak if snow_enabled else 0.0)
	s.set_shader_parameter("color", Vector3(snow_color_r, snow_color_g, snow_color_b))
	s.set_shader_parameter("drift", Vector3(snow_drift_x, snow_drift_y, snow_drift_z))
	var g := get_glint_material()
	g.set_shader_parameter("size", glint_size)
	g.set_shader_parameter("min_px", glint_min_px)
	g.set_shader_parameter("peak", glint_peak if glints_enabled else 0.0)
	g.set_shader_parameter("speed", glint_speed)
	g.set_shader_parameter("density", eff_glint_density())
	g.set_shader_parameter("far_a", glint_far_a)
	g.set_shader_parameter("far_b", maxf(glint_far_b, glint_far_a + 0.01))
	g.set_shader_parameter("color", Vector3(glint_color_r, glint_color_g, glint_color_b))
	# The blade flora's glints (FloraField) share the look, with their own sway.
	var fg := FloraField.glint_material()
	for param: String in ["size", "min_px", "peak", "speed", "density", "far_a", "far_b", "color"]:
		fg.set_shader_parameter(param, g.get_shader_parameter(param))
	push_bubbles()


## The bubble shader's globals (the water's colour to reflect, and the look's switches).
func push_bubbles() -> void:
	var c := flat_fog_color(maxf(surface_y() - 20.0, 0.0))  # the water a bubble sees round it, at a typical depth
	RenderingServer.global_shader_parameter_set("water_bubble_color", Vector3(c.r, c.g, c.b) * bubble_reflect)
	RenderingServer.global_shader_parameter_set("water_bubble_look", Vector3(1.0 if bubbles_water_look else 0.0, bubble_wobble, bubble_spec))


# ---- Quality (phase 8) ----

## Graphics quality tiers (UISettings.graphics_quality mirrors into `quality`; quality_force overrides it).
enum Quality { LOW, MEDIUM, HIGH }
const SCALED_GROUP := &"water_scaled_views"

## The Settings screen's choice (UISettings sets it).
static var quality := Quality.HIGH
## The adaptive-resolution factor on top of the tier's scale (1 when it is off or the GPU keeps up).
static var auto_scale := 1.0


## The tier in force.
func tier() -> int:
	return quality_force if quality_force >= 0 else quality


## `high` on High, `med` on Medium, `low` on Low.
func _by_tier(low: Variant, med: Variant, high: Variant) -> Variant:
	match tier():
		Quality.LOW:
			return low
		Quality.MEDIUM:
			return med
	return high


func eff_snow_count() -> int:
	return roundi(snow_count * float(_by_tier(q_snow_low, q_snow_med, 1.0)))


func eff_shaft_count() -> int:
	return roundi(shaft_count * float(_by_tier(q_shaft_low, q_shaft_med, 1.0)))


func eff_glint_density() -> float:
	return glint_density * float(_by_tier(q_glint_low, q_glint_med, 1.0))


## 0 is one caustic tap (cheapest); otherwise the RGB split as set.
func eff_caustic_split() -> float:
	return 0.0 if tier() == Quality.LOW and q_low_single_caustic else caustic_split


## How many of the bloom's levels run.
func eff_glow_levels() -> int:
	return int(_by_tier(q_glow_levels_low, q_glow_levels_med, 6))


## The 3D render scale for the tier, times the adaptive factor.
func eff_scale() -> float:
	return clampf(float(_by_tier(q_scale_low, q_scale_med, q_scale_high)) * auto_scale, 0.25, 2.0)


## Puts the tier's render scale on one viewport (FSR when below 1, so the picture stays sharp).
func apply_scale(viewport: Viewport) -> void:
	if viewport == null:
		return
	var s := eff_scale()
	var mode := Viewport.SCALING_3D_MODE_FSR if s < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
	if viewport.scaling_3d_mode != mode:
		viewport.scaling_3d_mode = mode
	if not is_equal_approx(viewport.scaling_3d_scale, s):
		viewport.scaling_3d_scale = s


## ... on the window and on every split-screen view.
func apply_scale_all(tree: SceneTree) -> void:
	if tree == null:
		return
	apply_scale(tree.root)
	for node in tree.get_nodes_in_group(SCALED_GROUP):
		apply_scale(node as Viewport)


## Whatever the quality changes, as one number (so Ocean notices a change cheaply).
func quality_signature() -> int:
	return [tier(), eff_scale(), q_glow_levels_low, q_glow_levels_med].hash()
