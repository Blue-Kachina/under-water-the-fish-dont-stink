class_name UnnaturalSettings
extends Resource
## Unnatural's own tuning (planning_unnatural.md §10): the arena, the
## EvilDirector's curves, the zombies, the players' health and attacks, levels
## and XP pearls. Shown in the tuning panel's UNNATURAL section and saved with
## presets ([unnatural]). One shared copy (shared()) is what the panel edits and
## what UnnaturalRun, its Horde and its EvilDirector read, live.
##
## As with NatureSettings, ranges are wide: 0 switches a feature off and the
## top end is several times the sensible value. Sliders marked or_greater take
## bigger values typed into a preset too.

static var _shared: UnnaturalSettings


## The copy the panel edits and Unnatural reads.
static func shared() -> UnnaturalSettings:
	if _shared == null:
		_shared = UnnaturalSettings.new()
	return _shared


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
## Rocks and kelp on the seabed (how many of each).
@export_range(0, 2000, 10, "or_greater") var seabed_rocks := 260
@export_range(0, 4000, 10, "or_greater") var seabed_kelp := 600
## The arena's edge, so it reads from far off: tall rock outcrops and a thick
## band of tall kelp round it (and a faint red wall of light), from the seabed
## to the top of the depth band.
@export_range(0, 1000, 5, "or_greater") var edge_rocks := 90
@export_range(0, 8000, 10, "or_greater") var edge_kelp := 900

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
## fading with distance.
@export_range(0.0, 1.0, 0.05) var glint_from := 0.8
@export_range(0.0, 600.0, 5.0, "or_greater") var glint_distance := 170.0
@export_range(0.0, 5.0, 0.05, "or_greater") var glint_strength := 1.0
## Each eye's size (m), times the zombie's size.
@export_range(0.01, 1.0, 0.01, "or_greater") var glint_size := 0.09

@export_group("Minimap")
## A flat map in the corner of each player's view: players and bosses as
## icons, elites as dots, the zombie swarms as faint clouds, and chests.
@export var minimap := true
## Its size (a share of the view's height).
@export_range(0.05, 0.6, 0.01) var minimap_size := 0.26
## How far it shows (m, centre to rim; 0: the whole arena).
@export_range(0.0, 1000.0, 5.0, "or_greater") var minimap_range := 90.0
## The way you face is up (off: north is up).
@export var minimap_heading_up := true
## How often the swarm clouds are redrawn (per second).
@export_range(1.0, 60.0, 1.0) var minimap_rate := 6.0
@export_range(0.1, 1.0, 0.05) var minimap_opacity := 0.85

@export_group("Camera")
## The survivor cam: it follows the way the fish swims (smoothed), not its
## facing, so stride sweeps don't swing the view. Off: the usual chase camera.
@export var steady_camera := true
## Which survivor cam each player starts with; the ball cam button swaps them.
## Follow turns with the way the fish swims. Free turns only with the right
## stick, and stays where it's put.
@export_enum("Follow", "Free") var camera_mode := 0
## Follow cam: hold its direction while accelerate, reverse or boost is held, and
## swing round behind the fish once they're let go, this quickly (1/s). Off: it
## always turns, at camera_turn_rate.
@export var camera_hold_on_throttle := true
@export_range(0.2, 30.0, 0.1, "or_greater") var camera_swing_rate := 4.0
## Free cam: how fast the right stick turns it at full tilt (degrees/s), how
## far it can look up or down (degrees), and how quickly it drifts round
## behind the way the fish swims (1/s; 0: never, it stays where it's put).
@export_range(10.0, 720.0, 5.0, "or_greater") var free_cam_speed := 150.0
@export_range(0.0, 89.0, 1.0) var free_cam_pitch := 70.0
@export_range(0.0, 10.0, 0.05, "or_greater") var free_cam_follow := 0.0
## Free cam: down on the right stick looks up, as a flight sim (D11).
@export var free_cam_invert_y := true
## How quickly it turns to the way the fish swims (1/s; lower is calmer).
@export_range(0.1, 20.0, 0.1, "or_greater") var camera_turn_rate := 2.0
## How much of the fish's climb or dive it follows (0: always level).
@export_range(0.0, 1.0, 0.05) var camera_climb := 0.4
## Further back, higher and tilted further down than the tuned chase view
## (m, m, degrees), to see the horde around you.
@export_range(0.0, 40.0, 0.25, "or_greater") var camera_distance := 4.5
@export_range(0.0, 30.0, 0.25, "or_greater") var camera_height := 2.0
@export_range(-60.0, 30.0, 0.5) var camera_tilt := -10.0

@export_group("Director")
## Zombies alive the director aims for: base_alive + alive_per_minute *
## minutes ^ alive_curve, times 1 + coop_scale per extra player.
@export_range(0, 200, 1, "or_greater") var base_alive := 4
@export_range(0.0, 1000.0, 1.0, "or_greater") var alive_per_minute := 30.0
@export_range(0.5, 3.0, 0.05, "or_greater") var alive_curve := 1.3
@export_range(0.0, 3.0, 0.05, "or_greater") var coop_scale := 0.6
## Zombies come in packs of swarm_base + swarm_per_minute * minutes...
@export_range(1, 100, 1, "or_greater") var swarm_base := 2
@export_range(0.0, 100.0, 0.5, "or_greater") var swarm_per_minute := 4.0
## ...at most one pack every this many seconds.
@export_range(0.05, 20.0, 0.05, "or_greater") var spawn_interval := 1.2
## Once the final boss falls (the whirlpool's open), packs come cleared_spawn_rate
## times as often, and the director wants cleared_alive_scale times as many out
## (1, 1: no change).
@export_range(1.0, 10.0, 0.05, "or_greater") var cleared_spawn_rate := 2.0
@export_range(1.0, 10.0, 0.05, "or_greater") var cleared_alive_scale := 1.5
## Packs turn up this far from a player (m): out of every player's view, or
## anywhere round them in the murk (murk_spawn_anywhere).
@export_range(5.0, 200.0, 1.0, "or_greater") var spawn_distance_min := 35.0
@export_range(5.0, 300.0, 1.0, "or_greater") var spawn_distance_max := 55.0
## A zombie further than this from every player (m) is moved to a spawn point
## near them (not killed and respawned), keeping the pressure on.
@export_range(20.0, 600.0, 5.0, "or_greater") var leash := 90.0
## Spawning on (off: only what's out already, for testing).
@export var spawning := true
## Mowing through them too easily (each player killing easy_kill_rate a
## second or more, over the last 10 s, while intensity is under
## calm_intensity) raises the pressure, a multiplier on the target alive, by
## pressure_rate a second up to pressure_max; high intensity lowers it, down to
## pressure_min.
@export_range(0.0, 50.0, 0.1, "or_greater") var easy_kill_rate := 1.5
@export_range(0.0, 2.0, 0.01, "or_greater") var calm_intensity := 0.15
@export_range(0.0, 1.0, 0.005, "or_greater") var pressure_rate := 0.03
@export_range(1.0, 5.0, 0.05, "or_greater") var pressure_max := 1.6
@export_range(0.1, 1.0, 0.05) var pressure_min := 0.75
## Intensity: the share of their max hp the players lost recently, fading by
## intensity_fade a second. At relief_intensity or more the director holds off
## new packs for relief_time seconds: a breather, then it comes again.
@export_range(0.0, 5.0, 0.01, "or_greater") var intensity_fade := 0.2
@export_range(0.0, 5.0, 0.05, "or_greater") var relief_intensity := 0.6
@export_range(0.0, 60.0, 0.5, "or_greater") var relief_time := 6.0

@export_group("Enemies")
## Every zombie's hp, speed and contact damage are multiplied by these.
@export_range(0.0, 10.0, 0.05, "or_greater") var enemy_hp_scale := 1.0
@export_range(0.0, 5.0, 0.05, "or_greater") var enemy_speed_scale := 1.0
@export_range(0.0, 10.0, 0.05, "or_greater") var enemy_damage_scale := 1.2
## Difficulty: a level that grows difficulty_per_minute a minute. Each zombie
## keeps the level it spawned at: per level, difficulty_hp more hp,
## difficulty_damage more contact damage, difficulty_speed more speed, and
## difficulty_size bigger, up to difficulty_size_max times its size.
@export_range(0.0, 5.0, 0.05, "or_greater") var difficulty_per_minute := 0.5
@export_range(0.0, 5.0, 0.01, "or_greater") var difficulty_hp := 0.3
## How hp grows with the difficulty level: 1 + difficulty_hp x level ^ this
## (1: in a line; more: faster and faster, to keep up with a build's power).
@export_range(0.5, 3.0, 0.05, "or_greater") var difficulty_hp_curve := 1.55
@export_range(0.0, 5.0, 0.01, "or_greater") var difficulty_damage := 0.15
@export_range(0.0, 2.0, 0.01, "or_greater") var difficulty_speed := 0.04
@export_range(0.0, 2.0, 0.01, "or_greater") var difficulty_size := 0.08
@export_range(1.0, 10.0, 0.05, "or_greater") var difficulty_size_max := 2.0
## Zombies closer than this (m, edge to edge) push apart, this hard (m/s² at contact).
@export_range(0.0, 10.0, 0.05, "or_greater") var separation := 0.6
@export_range(0.0, 200.0, 1.0, "or_greater") var separation_strength := 18.0
## A little drift on their chase (m/s), so they don't swim on rails.
@export_range(0.0, 10.0, 0.05, "or_greater") var wander := 1.0
## How hard a hit knocks a zombie back (m/s per hit).
@export_range(0.0, 50.0, 0.5, "or_greater") var knockback := 6.0
## The chance a zombie spawns elite (bigger, 5x hp, glowing, a 5x XP pearl):
## elite_chance + elite_per_minute * minutes.
@export_range(0.0, 1.0, 0.005) var elite_chance := 0.01
@export_range(0.0, 0.2, 0.001, "or_greater") var elite_per_minute := 0.008
## Swordfish stalk to lunge_range (m), telegraph for lunge_telegraph (s, a red
## glow), lunge at lunge_speed (m/s) for lunge_time (s), then rest lunge_rest (s).
@export_range(0.0, 100.0, 0.5, "or_greater") var lunge_range := 14.0
@export_range(0.0, 5.0, 0.05, "or_greater") var lunge_telegraph := 0.7
@export_range(0.0, 100.0, 0.5, "or_greater") var lunge_speed := 24.0
@export_range(0.0, 5.0, 0.05, "or_greater") var lunge_time := 0.7
@export_range(0.0, 10.0, 0.05, "or_greater") var lunge_rest := 1.4
## Rays aim where the player will be in glide_lead seconds, sweeping glide_sweep m either side.
@export_range(0.0, 5.0, 0.05, "or_greater") var glide_lead := 1.2
@export_range(0.0, 60.0, 0.5, "or_greater") var glide_sweep := 10.0
## A boxfish bursts on death into a cloud burst_radius m round that hurts
## (burst_damage a touch, with i-frames) for burst_time s: don't batter one point blank.
@export_range(0.0, 20.0, 0.1, "or_greater") var burst_radius := 3.0
@export_range(0.0, 200.0, 1.0, "or_greater") var burst_damage := 8.0
@export_range(0.0, 20.0, 0.1, "or_greater") var burst_time := 2.5
## The rot on their skins (0: their own colours, 1: all rot) and their eyes' glow.
@export_range(0.0, 1.0, 0.01) var rot := 0.5
@export_range(0.0, 8.0, 0.1, "or_greater") var eye_glow := 2.0

@export_group("Player")
## Max hp: base_hp + hp_per_level * (level - 1).
@export_range(1.0, 2000.0, 1.0, "or_greater") var base_hp := 100.0
@export_range(0.0, 500.0, 1.0, "or_greater") var hp_per_level := 10.0
## Seconds a fish can't be hurt again after a hit (it flickers).
@export_range(0.0, 5.0, 0.05, "or_greater") var iframes := 0.7
## Hp healed per second.
@export_range(0.0, 50.0, 0.1, "or_greater") var regen := 0.0
## Can't die (testing).
@export var god_mode := false
## Co-op (D7): a downed player is revived by a teammate staying within
## revive_range (m) of them for revive_time (s), back up with revive_hp of their max hp.
@export_range(0.5, 50.0, 0.5, "or_greater") var revive_range := 4.0
@export_range(0.0, 30.0, 0.25, "or_greater") var revive_time := 3.0
@export_range(0.05, 1.0, 0.05) var revive_hp := 0.5

@export_group("Batteries")
## A battery (ramming a zombie at nature_batter_speed or faster, the bow wave
## counting) does this much damage at the battering speed...
@export_range(0.0, 1000.0, 1.0, "or_greater") var battery_damage := 60.0
## ...times (speed / battering speed) to this power, so faster hits harder.
@export_range(0.0, 4.0, 0.05, "or_greater") var battery_speed_power := 1.5
## Ramming at speed is rewarded: a battery gives this many seconds of i-frames.
@export_range(0.0, 2.0, 0.05, "or_greater") var battery_iframes := 0.3
## Battering a big zombie (size 1.5 or more) takes this share of your speed; small ones you plough through.
@export_range(0.0, 1.0, 0.01) var big_enemy_slow := 0.2
## The same zombie can't be battered again for this long (s).
@export_range(0.0, 2.0, 0.05, "or_greater") var battery_repeat := 0.35
## Swimming into a zombie doesn't hurt you (even below battering speed, say
## between strides): one within safe_ram_cone degrees of the way you're
## swimming, while you're faster than it. With the bow wave up, every zombie
## ahead of you (in front of your middle) is safe while you're swimming
## forward. Bosses' bodies still bite.
@export var safe_ramming := true
@export_range(0.0, 90.0, 1.0) var safe_ram_cone := 60.0

@export_group("Attacks")
## Each fish fires its own auto-attack (FishAttack.FOR_FAMILY); pick one here
## to give every fish that one instead (testing). Live.
@export_enum("Own fish's", "Anemone Sting", "Ghost Bite", "Shock Lash", "Bill Thrust", "Bubble Volley", "Spine Burst") var fish_attack := 0

@export_group("Ghost Bite")
## The Shark's auto-attack: huge spectral jaws that snap shut on the zone in front.
@export_range(0.0, 1000.0, 1.0, "or_greater") var bite_damage := 26.0
## Seconds between bites.
@export_range(0.05, 10.0, 0.05, "or_greater") var bite_cooldown := 0.9
## How far the jaws reach (m) and their half-width (m)...
@export_range(0.0, 60.0, 0.5, "or_greater") var bite_reach := 8.0
@export_range(0.0, 40.0, 0.5, "or_greater") var bite_width := 4.5
## ...never less than this times the bow wave's full size (so a bite always
## out-reaches ramming, bow wave powerups included).
@export_range(1.0, 5.0, 0.05, "or_greater") var bite_over_bow := 1.6
## The jaws aim at the nearest zombie within this angle of the nose (degrees).
@export_range(0.0, 180.0, 5.0) var bite_aim_cone := 110.0

@export_group("Anemone Sting")
## The Clownfish's: a stinging pulse all round it that hits everything inside.
@export_range(0.0, 1000.0, 1.0, "or_greater") var sting_damage := 9.0
@export_range(0.05, 10.0, 0.05, "or_greater") var sting_cooldown := 0.9
## The pulse's radius (m)...
@export_range(0.0, 60.0, 0.5, "or_greater") var sting_radius := 6.5
## ...never less than this times the bow wave's full reach (it's melee: it
## must out-reach ramming).
@export_range(1.0, 5.0, 0.05, "or_greater") var sting_over_bow := 1.4

@export_group("Shock Lash")
## The String Ray's: its tail whips the nearest zombie within lash_range (m),
## and the shock arcs on to lash_arcs more (one more per Projectiles), each
## within lash_arc_range (m) of the last, for lash_arc_share of the damage.
@export_range(0.0, 1000.0, 1.0, "or_greater") var lash_damage := 47.0
@export_range(0.05, 10.0, 0.05, "or_greater") var lash_cooldown := 0.8
@export_range(0.0, 100.0, 0.5, "or_greater") var lash_range := 14.0
@export_range(0, 20, 1, "or_greater") var lash_arcs := 1
@export_range(0.0, 50.0, 0.5, "or_greater") var lash_arc_range := 8.0
@export_range(0.0, 2.0, 0.05, "or_greater") var lash_arc_share := 0.7

@export_group("Bill Thrust")
## The Swordfish's: a spear of light shot ahead (at the nearest zombie within
## thrust_aim_cone degrees of the nose, else straight on), piercing up to
## thrust_pierce zombies. More Projectiles: more spears, thrust_spread degrees apart.
@export_range(0.0, 1000.0, 1.0, "or_greater") var thrust_damage := 34.0
@export_range(0.05, 10.0, 0.05, "or_greater") var thrust_cooldown := 1.0
## Its speed (m/s), how far it flies (m) and its hit radius (m).
@export_range(1.0, 300.0, 1.0, "or_greater") var thrust_speed := 45.0
@export_range(1.0, 300.0, 1.0, "or_greater") var thrust_range := 40.0
@export_range(0.05, 10.0, 0.05, "or_greater") var thrust_size := 0.7
@export_range(1, 100, 1, "or_greater") var thrust_pierce := 6
@export_range(0.0, 180.0, 5.0) var thrust_aim_cone := 60.0
@export_range(0.0, 45.0, 0.5) var thrust_spread := 8.0

@export_group("Bubble Volley")
## The Butterfly Koi's: bubble_count homing bubbles (plus Projectiles) at the
## nearest zombies within bubble_range (m); each pops on the first it touches,
## hurting everything within bubble_pop (m).
@export_range(0.0, 1000.0, 1.0, "or_greater") var bubble_damage := 9.0
@export_range(0.05, 10.0, 0.05, "or_greater") var bubble_cooldown := 1.2
@export_range(1, 50, 1, "or_greater") var bubble_count := 4
@export_range(1.0, 200.0, 1.0, "or_greater") var bubble_speed := 18.0
## How quickly a bubble turns after its zombie (1/s) and how long it lasts (s).
@export_range(0.0, 30.0, 0.5, "or_greater") var bubble_turn := 6.0
@export_range(0.2, 20.0, 0.1, "or_greater") var bubble_life := 2.5
@export_range(0.05, 5.0, 0.05, "or_greater") var bubble_size := 0.45
@export_range(0.0, 20.0, 0.1, "or_greater") var bubble_pop := 2.0
@export_range(1.0, 200.0, 1.0, "or_greater") var bubble_range := 30.0

@export_group("Spine Burst")
## The Boxfish's: spine_count spines (plus 4 per Projectiles) out in every
## direction whenever a zombie is within spine_range (m), each piercing up to
## spine_pierce zombies.
@export_range(0.0, 1000.0, 1.0, "or_greater") var spine_damage := 32.0
@export_range(0.05, 10.0, 0.05, "or_greater") var spine_cooldown := 1.4
@export_range(1, 200, 1, "or_greater") var spine_count := 18
@export_range(1.0, 300.0, 1.0, "or_greater") var spine_speed := 30.0
@export_range(1.0, 100.0, 0.5, "or_greater") var spine_range := 12.0
@export_range(0.05, 5.0, 0.05, "or_greater") var spine_size := 0.5
@export_range(1, 50, 1, "or_greater") var spine_pierce := 2

@export_group("Twists")
## Each fish's traversal twist (Traversal). Off: every fish swims the same.
@export var twists := true
## Clownfish, Nimble: turns this many times as sharply.
@export_range(1.0, 4.0, 0.05, "or_greater") var nimble_turn := 1.4
## Shark, Frenzy: each kill adds frenzy_per_kill to its swim speed (up to
## frenzy_max), held for frenzy_time s after the last kill, then fading.
@export_range(0.0, 1.0, 0.005, "or_greater") var frenzy_per_kill := 0.04
@export_range(0.0, 3.0, 0.05, "or_greater") var frenzy_max := 0.5
@export_range(0.0, 20.0, 0.25, "or_greater") var frenzy_time := 3.0
## String Ray, Glide: keeps this share of the water's drag when coasting (0: none).
@export_range(0.0, 1.0, 0.05) var glide_drag := 0.3
## Swordfish, Dash (mobility): adds dash_speed (m/s) along its nose, untouchable for dash_iframes s.
@export_range(0.0, 100.0, 0.5, "or_greater") var dash_speed := 14.0
@export_range(0.0, 2.0, 0.05, "or_greater") var dash_iframes := 0.3
## Butterfly Koi, Leap (mobility): leaps up leap_impulse (m/s); as it tops
## out, it splashes down: leap_damage to every zombie within leap_radius (m).
## Then leap_cooldown s before the next.
@export_range(0.0, 100.0, 0.5, "or_greater") var leap_impulse := 12.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var leap_damage := 30.0
@export_range(0.0, 50.0, 0.5, "or_greater") var leap_radius := 7.0
@export_range(0.0, 20.0, 0.25, "or_greater") var leap_cooldown := 2.5
## Boxfish, Armoured: takes this share of damage, and swims at this share of speed.
@export_range(0.0, 1.0, 0.05) var armour_taken := 0.7
@export_range(0.1, 1.0, 0.05) var armour_speed := 0.88
## Lionfish, Wake: Greek Fire burns up to this much harder (+share) the nearer
## it swims to battering speed.
@export_range(0.0, 5.0, 0.05, "or_greater") var wake_damage := 0.6
## Mantis Shrimp, Snap (mobility): lunges ahead snap_speed (m/s) and cracks a shockwave, snap_damage to every zombie
## within snap_radius m, then snap_cooldown s before the next.
@export_range(0.0, 1000.0, 1.0, "or_greater") var snap_damage := 70.0
@export_range(0.0, 40.0, 0.5, "or_greater") var snap_radius := 6.0
@export_range(0.0, 20.0, 0.25, "or_greater") var snap_cooldown := 2.0
@export_range(0.0, 100.0, 0.5, "or_greater") var snap_speed := 18.0
## Baby Whale Shark, Escort: holding still (slower than chest_still_speed), it heals this
## many hp a second.
@export_range(0.0, 100.0, 0.25, "or_greater") var escort_regen := 4.0
## Swordfish, Streamlined: swims this much faster (+share).
@export_range(0.0, 1.0, 0.01, "or_greater") var streamline_speed := 0.1
## Butterfly Koi, Graceful: this many seconds more of i-frames after a hit.
@export_range(0.0, 3.0, 0.05, "or_greater") var graceful_iframes := 0.5
## Moon Jelly, Many Arms: its Halo has this many more jellies.
@export_range(0, 10, 1, "or_greater") var arms_extra := 1
@export_group("Mobility")
## Every fish's mobility skill is on the boost button (RB, Shift): it takes
## the place of boosting in Unnatural. Each has its own cooldown (s).
@export_range(0.0, 60.0, 0.25, "or_greater") var dash_cooldown := 2.5
## Shark, Fin Dash: charges ahead at fin_dash_speed (m/s) for fin_dash_time s,
## untouchable, battering everything in the way; every zombie it passes within
## fin_radius m takes fin_damage once.
@export_range(5.0, 200.0, 1.0, "or_greater") var fin_dash_speed := 45.0
@export_range(0.05, 3.0, 0.05, "or_greater") var fin_dash_time := 0.45
@export_range(0.5, 20.0, 0.25, "or_greater") var fin_radius := 3.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var fin_damage := 90.0
@export_range(0.1, 60.0, 0.1, "or_greater") var fin_cooldown := 3.0
## Clownfish, Wriggle: a burst of wriggle_speed (m/s) sideways (the way the
## stick leans, else back), untouchable for wriggle_iframes s.
@export_range(0.0, 100.0, 0.5, "or_greater") var wriggle_speed := 16.0
@export_range(0.0, 2.0, 0.05, "or_greater") var wriggle_iframes := 0.3
@export_range(0.1, 60.0, 0.1, "or_greater") var wriggle_cooldown := 2.0
## String Ray, Surge: a stroke of surge_speed (m/s) forward, with no drag for surge_time s.
@export_range(0.0, 100.0, 0.5, "or_greater") var surge_speed := 22.0
@export_range(0.0, 6.0, 0.1, "or_greater") var surge_time := 1.5
@export_range(0.1, 60.0, 0.1, "or_greater") var surge_cooldown := 4.0
## Boxfish, Brace: for brace_time s it takes brace_taken of the damage and
## swims at brace_speed of its speed.
@export_range(0.0, 20.0, 0.1, "or_greater") var brace_time := 2.5
@export_range(0.0, 1.0, 0.05) var brace_taken := 0.25
@export_range(0.1, 1.0, 0.05) var brace_speed := 0.7
@export_range(0.1, 60.0, 0.1, "or_greater") var brace_cooldown := 8.0
## Lionfish, Flare Dash: dashes flare_speed (m/s) for flare_time s, its spines
## flaring: flare_damage to every zombie within flare_radius m on the way.
@export_range(0.0, 200.0, 1.0, "or_greater") var flare_speed := 30.0
@export_range(0.05, 3.0, 0.05, "or_greater") var flare_time := 0.35
@export_range(0.0, 1000.0, 1.0, "or_greater") var flare_damage := 60.0
@export_range(0.5, 30.0, 0.5, "or_greater") var flare_radius := 4.0
@export_range(0.1, 60.0, 0.1, "or_greater") var flare_cooldown := 3.5
## Moon Jelly, Go Quiet: switches its stink off for up to quiet_time s: nothing
## fires, and zombies lose track of it. Ends if it's hurt; then quiet_cooldown s.
@export_range(0.5, 60.0, 0.5, "or_greater") var quiet_time := 8.0
@export_range(0.1, 60.0, 0.1, "or_greater") var quiet_cooldown := 6.0
## Baby Whale Shark, Gulp: sucks every zombie within gulp_range m ahead of it
## in (pulled at gulp_pull m/s), gulp_damage each.
@export_range(1.0, 60.0, 0.5, "or_greater") var gulp_range := 14.0
@export_range(0.0, 100.0, 0.5, "or_greater") var gulp_pull := 25.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var gulp_damage := 25.0
@export_range(0.1, 60.0, 0.1, "or_greater") var gulp_cooldown := 5.0

@export_group("Stage")
## The stage's timeline (StageTimeline, D5): when each event comes (s into the
## run; 0 skips it). Off: no events, just the director's curve.
@export var stage_events := true
@export_range(0.0, 3600.0, 5.0, "or_greater") var ring_time := 150.0
@export_range(0.0, 3600.0, 5.0, "or_greater") var miniboss_time := 300.0
@export_range(0.0, 3600.0, 5.0, "or_greater") var stampede_time := 450.0
@export_range(0.0, 3600.0, 5.0, "or_greater") var tide_time := 570.0
@export_range(0.0, 3600.0, 5.0, "or_greater") var boss_time := 600.0
## Each event is announced this long before it comes (s), and the director
## sends no packs for this long before it (s).
@export_range(0.0, 30.0, 0.5, "or_greater") var event_warning := 5.0
@export_range(0.0, 60.0, 0.5, "or_greater") var event_hush := 6.0
## The ring closes in from ring_radius (m) round each player, ring_count zombies
## each; the stampede is a bait ball of stampede_count sardines charging
## across; the tide is a wall of tide_count zombies from one side. (Times 1 +
## coop_scale per extra player.)
@export_range(0, 2000, 5, "or_greater") var ring_count := 60
@export_range(5.0, 100.0, 1.0, "or_greater") var ring_radius := 22.0
@export_range(0, 3000, 10, "or_greater") var stampede_count := 160
@export_range(0, 3000, 10, "or_greater") var tide_count := 120
## The ring, stampede and tide are swarm events: each lasts swarm_event_time s,
## a fresh wave (another ring, bait ball or wall, from a new side) every
## swarm_wave_every s, each swarm_wave_ramp bigger than the first (0.25: the
## fifth is twice the first). The HUD counts it down. 0 s: one wave, as before.
@export_range(0.0, 300.0, 1.0, "or_greater") var swarm_event_time := 30.0
@export_range(1.0, 60.0, 0.5, "or_greater") var swarm_wave_every := 6.0
@export_range(0.0, 2.0, 0.05, "or_greater") var swarm_wave_ramp := 0.25
## When the boss comes, the zombies further than this from every player (m)
## are cleared away (0: none are).
@export_range(0.0, 300.0, 5.0, "or_greater") var boss_cleanup := 40.0

@export_group("Drowned Shark")
## The mini-boss: a huge zombie shark. Its hp (times 1 + coop_scale per extra
## player), swim speed (m/s), size (times the Shark's) and contact damage.
@export_range(1.0, 100000.0, 50.0, "or_greater") var shark_hp := 30000.0
@export_range(0.0, 60.0, 0.5, "or_greater") var shark_speed := 12.0
@export_range(1.0, 15.0, 0.25, "or_greater") var shark_size := 15.0
@export_range(0.0, 500.0, 1.0, "or_greater") var shark_contact := 25.0
## Every shark_charge_every s it glows red for shark_telegraph s, then charges
## at shark_charge_speed (m/s) for shark_charge_time s.
@export_range(0.0, 60.0, 0.5, "or_greater") var shark_charge_every := 6.0
@export_range(0.0, 5.0, 0.05, "or_greater") var shark_telegraph := 1.0
@export_range(0.0, 100.0, 1.0, "or_greater") var shark_charge_speed := 36.0
@export_range(0.0, 5.0, 0.05, "or_greater") var shark_charge_time := 1.2
## Every shark_call_every s it calls a ring of shark_call_count sardines round its target.
@export_range(0.0, 120.0, 1.0, "or_greater") var shark_call_every := 12.0
@export_range(0, 200, 1, "or_greater") var shark_call_count := 16
## Killing it drops a chest (a powerup pick) and XP worth this much.
@export_range(0.0, 1000.0, 5.0, "or_greater") var shark_xp := 80.0

@export_group("Blood Leviathan")
## The boss: a giant serpent. Beating it completes the stage. Its hp (times 1 +
## coop_scale per extra player), swim speed (m/s), segments and contact damage.
@export_range(1.0, 1000000.0, 100.0, "or_greater") var leviathan_hp := 90000.0
## The whirlpool that opens where it falls: swim within this many metres and press
## Jump to enter it, which is what completes the stage (the run goes on until you do).
@export_range(1.0, 100.0, 1.0, "or_greater") var whirlpool_range := 15.0
@export_range(0.0, 60.0, 0.5, "or_greater") var leviathan_speed := 15.0
@export_range(2, 60, 1, "or_greater") var leviathan_segments := 14
@export_range(0.5, 6.0, 0.1, "or_greater") var leviathan_girth := 6.0
@export_range(0.0, 500.0, 1.0, "or_greater") var leviathan_contact := 30.0
## From two thirds of its hp down it spits leviathan_bolts blood bolts every
## leviathan_bolt_every s (leviathan_bolt_damage each); under a third it
## charges again and again.
@export_range(0, 50, 1, "or_greater") var leviathan_bolts := 7
@export_range(0.0, 30.0, 0.25, "or_greater") var leviathan_bolt_every := 4.0
@export_range(0.0, 500.0, 1.0, "or_greater") var leviathan_bolt_damage := 15.0
## Not beaten leviathan_enrage s after it came, it enrages: faster and harder
## by enrage_scale, and the director keeps escalating (D5: no time limit).
@export_range(0.0, 3600.0, 5.0, "or_greater") var leviathan_enrage := 120.0
@export_range(1.0, 5.0, 0.05, "or_greater") var enrage_scale := 1.5

@export_group("Levels")
## XP to the next level: xp_base * level ^ xp_curve.
@export_range(1.0, 1000.0, 1.0, "or_greater") var xp_base := 5.0
@export_range(0.5, 3.0, 0.05, "or_greater") var xp_curve := 1.9
## Every kill's XP (it's the team's at once, no pickup) is worth this many
## times its value.
@export_range(0.0, 10.0, 0.05, "or_greater") var xp_gain := 1.0
## Each level-up offers this many cards, each a different weapon or tome (0:
## no cards, just the hp and signature stat). Every weapon (each fish's own
## attack and the powerup weapons) is equally likely as a new one, and a card's
## rarity is rolled for it, not fixed by the weapon.
@export_range(0, 6, 1) var card_choices := 3
## Solo, the game pauses while the cards are up (co-op: the picker can't be
## hurt or seen by zombies instead).
@export var cards_pause := true
## The signature stat's +1 each level, in steps.
@export_range(0.0, 5.0, 0.25, "or_greater") var signature_steps := 1.0

@export_group("Weapons and Tomes")
## Slots (planning_unnatural.md, Playability pass, D17): a player holds this
## many weapons (the fish's own attack is one of them) and this many tomes.
## More come from meta-progression later.
@export_range(1, 8, 1, "or_greater") var weapon_slots := 2
@export_range(0, 8, 1, "or_greater") var tome_slots := 2
## A weapon or tome stops being offered at this level.
@export_range(1, 50, 1, "or_greater") var weapon_max_level := 20
@export_range(1, 200, 1, "or_greater") var tome_max_level := 99
## Each level-up card is one of these, by weight: upgrade a weapon you hold,
## upgrade a tome you hold, a new weapon (only with a weapon slot free), a new
## tome (only with a tome slot free).
@export_range(0.0, 100.0, 1.0, "or_greater") var card_weight_weapon := 40.0
@export_range(0.0, 100.0, 1.0, "or_greater") var card_weight_tome := 30.0
@export_range(0.0, 100.0, 1.0, "or_greater") var card_weight_new_weapon := 15.0
@export_range(0.0, 100.0, 1.0, "or_greater") var card_weight_new_tome := 15.0
## A weapon upgrade raises this many facets (different ones), by its rarity...
@export_range(1, 6, 1, "or_greater") var facets_common := 1
@export_range(1, 6, 1, "or_greater") var facets_uncommon := 1
@export_range(1, 6, 1, "or_greater") var facets_rare := 2
@export_range(1, 6, 1, "or_greater") var facets_epic := 2
@export_range(1, 6, 1, "or_greater") var facets_legendary := 3
## ...each by this many of its steps.
@export_range(0.0, 10.0, 0.1, "or_greater") var facet_size_common := 1.0
@export_range(0.0, 10.0, 0.1, "or_greater") var facet_size_uncommon := 1.5
@export_range(0.0, 10.0, 0.1, "or_greater") var facet_size_rare := 1.5
@export_range(0.0, 10.0, 0.1, "or_greater") var facet_size_epic := 2.0
@export_range(0.0, 10.0, 0.1, "or_greater") var facet_size_legendary := 2.5
## At these weapon levels each weapon gains a new behaviour (0: never).
@export_range(0, 50, 1, "or_greater") var milestone_first := 5
@export_range(0, 50, 1, "or_greater") var milestone_second := 10
@export_range(0, 50, 1, "or_greater") var milestone_third := 15
@export_range(0, 50, 1, "or_greater") var milestone_fourth := 20
## A tome with more than one stat gives each this share of a step.
@export_range(0.0, 2.0, 0.05, "or_greater") var tome_multi_share := 0.7
## When there's nothing left to offer: a pearl purse of fallback_pearls
## (times 1 + level / 10), or a team heal of fallback_heal of max hp.
@export_range(0, 1000, 1, "or_greater") var fallback_pearls := 10
@export_range(0.0, 1.0, 0.05) var fallback_heal := 0.3

@export_group("Chests")
## Chests buried round the arena at the start, one more uncovered every
## chest_interval seconds, up to chest_max out (unopened) at once.
@export_range(0, 100, 1, "or_greater") var chest_count := 10
@export_range(0.0, 600.0, 5.0, "or_greater") var chest_interval := 60.0
@export_range(0, 200, 1, "or_greater") var chest_max := 16
## Within this (m) the HUD pings a chest.
@export_range(0.0, 500.0, 5.0, "or_greater") var chest_sense_range := 35.0
## Open one by battering it (at the battering speed, within chest_reach m of
## your front), or by holding still (under chest_still_speed m/s) within
## chest_reach for chest_open_time s. Opening and picking its powerup, you
## can't be hurt or seen (D3).
@export_range(0.5, 20.0, 0.1, "or_greater") var chest_reach := 8.0
@export_range(0.0, 20.0, 0.1, "or_greater") var chest_still_speed := 3.0
@export_range(0.0, 10.0, 0.1, "or_greater") var chest_open_time := 2.0
## A chest offers this many powerups (different ones) to pick from.
@export_range(1, 4, 1) var chest_choices := 3
## A buried chest's chance of being cursed (blood red): it offers cursed
## powerups, strong with a catch. Luck doesn't change it (D13).
@export_range(0.0, 1.0, 0.01) var cursed_chest_chance := 0.1
## Each kill has this chance of dropping a chest (an elite's: elite_chest_scale
## times it), times 1 + the killer's luck x chest_drop_luck (which lifts the
## drops' chances too). Every chest is every player's: each opens it for themselves.
@export_range(0.0, 1.0, 0.0005) var chest_drop_chance := 0.002
@export_range(0.0, 50.0, 0.5, "or_greater") var elite_chest_scale := 2.0
@export_range(0.0, 20.0, 0.1, "or_greater") var chest_drop_luck := 1.0
## Chests cost pearls (D23; off: free). The price is chest_price_base x (1 +
## chest_price_growth x minutes into the run; 0: no growth over time); a cursed
## chest's is chest_cursed_price times that, a boss's free. Each player pays
## from their own purse for the chests they open.
@export var chest_cost := true
@export_range(0.0, 1000.0, 1.0, "or_greater") var chest_price_base := 8.0
@export_range(0.0, 5.0, 0.05, "or_greater") var chest_price_growth := 0.0
## Each chest a player has paid for on this map raises their next one's price
## by this share of the base (0.25: the 10th costs 3.25x the first).
@export_range(0.0, 2.0, 0.01, "or_greater") var chest_price_step := 0.25
@export_range(0.0, 10.0, 0.05, "or_greater") var chest_cursed_price := 1.5

@export_group("Drops")
## A kill's chance of dropping a heart (heals the whole team heart_heal of max
## hp), a magnet (every XP pearl out flies to the taker) or an hourglass
## (every zombie stops dead for hourglass_time s; bosses don't). An elite's:
## 5x. The first player to touch one takes it.
@export_range(0.0, 1.0, 0.0005) var heart_chance := 0.004
@export_range(0.0, 1.0, 0.01) var heart_heal := 0.5
@export_range(0.0, 1.0, 0.0005) var magnet_chance := 0.0015
@export_range(0.0, 1.0, 0.0005) var hourglass_chance := 0.002
@export_range(0.0, 120.0, 0.5, "or_greater") var hourglass_time := 15.0

@export_group("Rarity")
## Each card's rarity: these base weights, each times (1 + luck * luck_effect) ^ tier.
@export_range(0.0, 100.0, 0.5, "or_greater") var weight_common := 60.0
@export_range(0.0, 100.0, 0.5, "or_greater") var weight_uncommon := 25.0
@export_range(0.0, 100.0, 0.5, "or_greater") var weight_rare := 10.0
@export_range(0.0, 100.0, 0.5, "or_greater") var weight_epic := 4.0
@export_range(0.0, 100.0, 0.5, "or_greater") var weight_legendary := 1.0
@export_range(0.0, 10.0, 0.05, "or_greater") var luck_effect := 1.0
## What each rarity's card gives, in steps of its stat.
@export_range(0.0, 20.0, 0.1, "or_greater") var multiplier_common := 1.0
@export_range(0.0, 20.0, 0.1, "or_greater") var multiplier_uncommon := 1.5
@export_range(0.0, 20.0, 0.1, "or_greater") var multiplier_rare := 2.0
@export_range(0.0, 20.0, 0.1, "or_greater") var multiplier_epic := 3.0
@export_range(0.0, 20.0, 0.1, "or_greater") var multiplier_legendary := 5.0

@export_group("Pearls")
## Pearls are the currency (D23): chests cost them. A kill drops one by chance,
## pearl_drop_chance x (1 + the killer's Pearl Chance); an elite's by
## pearl_elite_chance (likewise), worth pearl_elite_value; a beaten mini-boss
## drops boss_pearls.
@export_range(0.0, 1.0, 0.005) var pearl_drop_chance := 0.05
@export_range(0.0, 1.0, 0.01) var pearl_elite_chance := 0.3
@export_range(1, 100, 1, "or_greater") var pearl_elite_value := 1
@export_range(0, 1000, 1, "or_greater") var boss_pearls := 25
## Pearls this near a fish (m) are drawn in: the pickup range.
@export_range(0.0, 60.0, 0.5, "or_greater") var pickup_range := 10.0
@export_range(0.0, 100.0, 0.5, "or_greater") var pickup_pull := 12.0
## Pearls never fade: they wait until someone takes them.
@export_range(0.05, 3.0, 0.01, "or_greater") var pearl_size := 0.18
## Each pearl's own light (pretty, but costly with hundreds out).
@export var pearl_lights := false
## At most this many pearls out; past it, a new drop adds its worth to the
## nearest pearl, which grows with what it holds.
@export_range(10, 4000, 10, "or_greater") var max_pearls := 600

@export_group("Run Logs")
## Each run's log (RunLog: a sample a minute, the picks, how it ended) is
## saved to user://run_logs/ when it ends, keeping the newest run_logs_keep.
@export var run_logs := true
@export_range(1, 1000, 1, "or_greater") var run_logs_keep := 50
## The run simulator (tests/run_sim.tscn) flags the minutes when the horde's
## fill (zombies out over the number the director wants out) is under this:
## the build wipes each pack as it comes, too strong for the curve.
@export_range(0.0, 1.0, 0.01) var fill_target_min := 0.25

@export_group("Test Tank")
## A preset for power and frame benchmarks: every weapon slot full (the
## attack, then Greek Fire, Jellyfish Halo, Depth Charges, Remora Buddy, the
## Coil) and every tome slot (Teeth, Tides, the Reef, the Shell...), all at
## that level. It sets the weapons' level overrides (POWERUPS) and the tank's
## stats below; Off clears what it set.
@export_enum("Off", "Full slots Lv 5", "Full slots Lv 10", "Full slots Lv 20") var tank_preset := 0
## The Test Tank's dummies' hp (applies on R), and whether they drift towards
## you (at tank_walk_speed m/s) or hold still.
@export_range(1.0, 100000.0, 10.0, "or_greater") var tank_dummy_hp := 100.0
@export var tank_slow_walkers := false
@export_range(0.0, 20.0, 0.25, "or_greater") var tank_walk_speed := 1.5
## Keeps this many chasing zombies out too (the perf bench: try 2000).
@export_range(0, 10000, 50, "or_greater") var tank_horde := 0
## Zombies hurt in the Test Tank (off: practise unhurt).
@export var tank_contact := false
## The team's level there.
@export_range(1, 100, 1, "or_greater") var tank_level := 1
## Each stat's bonus there (as StatBlock has them: 0.1 = +10%; hp, hp/s,
## armour, projectiles and luck are flat).
@export_range(0.0, 1000.0, 5, "or_greater") var tank_max_hp := 0.0
@export_range(0.0, 50.0, 0.1, "or_greater") var tank_regen := 0.0
@export_range(0.0, 50.0, 0.5, "or_greater") var tank_armour := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_damage := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_attack_speed := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_area := 0.0
@export_range(0.0, 20.0, 1, "or_greater") var tank_projectile_count := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_projectile_speed := 0.0
@export_range(0.0, 1.0, 0.01, "or_greater") var tank_crit_chance := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_crit_damage := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var tank_swim_speed := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var tank_stride_power := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_battery_damage := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_knockback := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_duration := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_pickup_range := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_xp_gain := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_pearl_chance := 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tank_luck := 0.0

@export_group("Performance")
## The most zombies at once (the Horde's arrays are this big).
@export_range(10, 20000, 10, "or_greater") var max_enemies := 3000
## How often zombies steer (steps per second); drawn between steps every frame.
@export_range(5.0, 120.0, 1.0) var sim_rate := 30.0
## Zombies further than far_distance (m) from every player steer only every
## far_update_divisor-th step (they still move every step).
@export_range(10.0, 500.0, 5.0, "or_greater") var far_distance := 60.0
@export_range(1, 16, 1) var far_update_divisor := 4
## Zombies cast shadows.
@export var enemy_shadows := false
## Zombie detail by distance from the camera (scaled by their size): each part
## of a fish at its coarsest LOD within the error (a share of the part's size;
## 0: full detail). lod_near_error out to lod_mid_distance m, lod_mid_error out
## to lod_far_distance m, lod_far_error beyond.
@export_range(0.0, 0.2, 0.001, "or_greater") var lod_near_error := 0.004
@export_range(0.0, 200.0, 1.0, "or_greater") var lod_mid_distance := 12.0
@export_range(0.0, 0.5, 0.001, "or_greater") var lod_mid_error := 0.02
@export_range(0.0, 400.0, 1.0, "or_greater") var lod_far_distance := 30.0
@export_range(0.0, 1.0, 0.001, "or_greater") var lod_far_error := 0.1
## Split-screen: each view draws only the zombies its own camera sees (on its
## player's render layer), rather than every view drawing what any of them sees.
@export var per_view_horde := true
## Show the director's live numbers (target alive, alive, next pack) on the HUD.
@export var show_director := false


## The fog's amount `distance` m out at `density` (Godot's exponential fog).
static func fog_at(distance: float, density: float) -> float:
	return 1.0 - exp(-maxf(distance, 0.0) * maxf(density, 0.0))


## How far out the fog reaches `amount` at `density` (INF: never).
static func fog_reach(amount: float, density: float) -> float:
	if density <= 0.0 or amount >= 1.0:
		return INF
	return -log(1.0 - clampf(amount, 0.0, 0.999999)) / density


## Murk is on (a density set).
func murky() -> bool:
	return murk_density > 0.0


## How many facets a weapon upgrade of rarity `tier` raises.
func facets_for(tier: int) -> int:
	return [facets_common, facets_uncommon, facets_rare, facets_epic, facets_legendary][clampi(tier, 0, 4)]


## How many steps each facet a weapon upgrade of rarity `tier` raises goes up.
func facet_size_for(tier: int) -> float:
	return [facet_size_common, facet_size_uncommon, facet_size_rare, facet_size_epic, facet_size_legendary][clampi(tier, 0, 4)]


## The level milestone `n` (1 to 4) comes at (0: never).
func milestone_level(n: int) -> int:
	return [milestone_first, milestone_second, milestone_third, milestone_fourth][n - 1] if n >= 1 and n <= 4 else 0


## How many milestones a weapon at `level` has reached (0 to 4).
func milestones_at(level: int) -> int:
	var reached := 0
	for n in range(1, 5):
		var at := milestone_level(n)
		reached += 1 if at > 0 and level >= at else 0
	return reached


## A zombie's hp multiplier at difficulty `level`: 1 + difficulty_hp x level ^ difficulty_hp_curve.
func hp_growth(level: float) -> float:
	return 1.0 + difficulty_hp * pow(maxf(level, 0.0), difficulty_hp_curve)
