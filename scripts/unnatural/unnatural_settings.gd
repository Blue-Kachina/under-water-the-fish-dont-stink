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

@export_group("Camera")
## The survivor cam: it follows the way the fish swims (smoothed), not its
## facing, so stride sweeps don't swing the view. Off: the usual chase camera.
@export var steady_camera := true
## Which survivor cam each player starts with; the ball cam button swaps them.
## Follow turns with the way the fish swims. Free turns only with the right
## stick, and stays where it's put.
@export_enum("Follow", "Free") var camera_mode := 0
## Follow cam: hold its direction while accelerate or reverse is held, and turn
## to the way the fish swims once they're let go. Off: it always turns.
@export var camera_hold_on_throttle := true
## Free cam: how fast the right stick turns it at full tilt (degrees/s), how
## far it can look up or down (degrees), and how quickly it drifts round
## behind the way the fish swims (1/s; 0: never, it stays where it's put).
@export_range(10.0, 720.0, 5.0, "or_greater") var free_cam_speed := 150.0
@export_range(0.0, 89.0, 1.0) var free_cam_pitch := 70.0
@export_range(0.0, 10.0, 0.05, "or_greater") var free_cam_follow := 0.0
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
## Packs turn up this far from a player (m), out of every player's view.
@export_range(5.0, 200.0, 1.0, "or_greater") var spawn_distance_min := 28.0
@export_range(5.0, 300.0, 1.0, "or_greater") var spawn_distance_max := 45.0
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
@export_range(0.0, 10.0, 0.05, "or_greater") var enemy_damage_scale := 1.0
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
@export_range(0.0, 20.0, 0.1, "or_greater") var burst_radius := 3.5
@export_range(0.0, 200.0, 1.0, "or_greater") var burst_damage := 12.0
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
@export_range(0.0, 1000.0, 1.0, "or_greater") var battery_damage := 40.0
## ...times (speed / battering speed) to this power, so faster hits harder.
@export_range(0.0, 4.0, 0.05, "or_greater") var battery_speed_power := 1.0
## Ramming at speed is rewarded: a battery gives this many seconds of i-frames.
@export_range(0.0, 2.0, 0.05, "or_greater") var battery_iframes := 0.3
## Battering a big zombie (size 1.5 or more) takes this share of your speed; small ones you plough through.
@export_range(0.0, 1.0, 0.01) var big_enemy_slow := 0.2
## The same zombie can't be battered again for this long (s).
@export_range(0.0, 2.0, 0.05, "or_greater") var battery_repeat := 0.35

@export_group("Attacks")
## Each fish fires its own auto-attack (FishAttack.FOR_FAMILY); pick one here
## to give every fish that one instead (testing). Live.
@export_enum("Own fish's", "Anemone Sting", "Ghost Bite", "Shock Lash", "Bill Thrust", "Bubble Volley", "Spine Burst") var fish_attack := 0

@export_group("Ghost Bite")
## The Shark's auto-attack: huge spectral jaws that snap shut on the zone in front.
@export_range(0.0, 1000.0, 1.0, "or_greater") var bite_damage := 30.0
## Seconds between bites.
@export_range(0.05, 10.0, 0.05, "or_greater") var bite_cooldown := 1.1
## How far the jaws reach (m) and their half-width (m)...
@export_range(0.0, 60.0, 0.5, "or_greater") var bite_reach := 8.0
@export_range(0.0, 40.0, 0.5, "or_greater") var bite_width := 4.5
## ...never less than this times the bow wave's full size (so a bite always
## out-reaches ramming, bow wave powerups included).
@export_range(1.0, 5.0, 0.05, "or_greater") var bite_over_bow := 1.6
## The jaws aim at the nearest zombie within this angle of the nose (degrees).
@export_range(0.0, 180.0, 5.0) var bite_aim_cone := 75.0

@export_group("Anemone Sting")
## The Clownfish's: a stinging pulse all round it that hits everything inside.
@export_range(0.0, 1000.0, 1.0, "or_greater") var sting_damage := 16.0
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
@export_range(0.0, 1000.0, 1.0, "or_greater") var lash_damage := 26.0
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
@export_range(0.0, 1000.0, 1.0, "or_greater") var bubble_damage := 12.0
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
@export_range(0.0, 1000.0, 1.0, "or_greater") var spine_damage := 14.0
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
## Swordfish, Dash: a dodge adds dash_speed (m/s) along it, untouchable for dash_iframes s.
@export_range(0.0, 100.0, 0.5, "or_greater") var dash_speed := 14.0
@export_range(0.0, 2.0, 0.05, "or_greater") var dash_iframes := 0.3
## Butterfly Koi, Leap: a jump also leaps up leap_impulse (m/s); as it tops
## out, it splashes down: leap_damage to every zombie within leap_radius (m).
## Then leap_cooldown s before the next.
@export_range(0.0, 100.0, 0.5, "or_greater") var leap_impulse := 12.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var leap_damage := 30.0
@export_range(0.0, 50.0, 0.5, "or_greater") var leap_radius := 7.0
@export_range(0.0, 20.0, 0.25, "or_greater") var leap_cooldown := 2.5
## Boxfish, Armoured: takes this share of damage, and swims at this share of speed.
@export_range(0.0, 1.0, 0.05) var armour_taken := 0.7
@export_range(0.1, 1.0, 0.05) var armour_speed := 0.88

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
## When the boss comes, the zombies further than this from every player (m)
## are cleared away (0: none are).
@export_range(0.0, 300.0, 5.0, "or_greater") var boss_cleanup := 40.0

@export_group("Drowned Shark")
## The mini-boss: a huge zombie shark. Its hp (times 1 + coop_scale per extra
## player), swim speed (m/s), size (times the Shark's) and contact damage.
@export_range(1.0, 100000.0, 50.0, "or_greater") var shark_hp := 2500.0
@export_range(0.0, 60.0, 0.5, "or_greater") var shark_speed := 8.0
@export_range(1.0, 15.0, 0.25, "or_greater") var shark_size := 5.0
@export_range(0.0, 500.0, 1.0, "or_greater") var shark_contact := 25.0
## Every shark_charge_every s it glows red for shark_telegraph s, then charges
## at shark_charge_speed (m/s) for shark_charge_time s.
@export_range(0.0, 60.0, 0.5, "or_greater") var shark_charge_every := 6.0
@export_range(0.0, 5.0, 0.05, "or_greater") var shark_telegraph := 1.0
@export_range(0.0, 100.0, 1.0, "or_greater") var shark_charge_speed := 28.0
@export_range(0.0, 5.0, 0.05, "or_greater") var shark_charge_time := 1.2
## Every shark_call_every s it calls a ring of shark_call_count sardines round its target.
@export_range(0.0, 120.0, 1.0, "or_greater") var shark_call_every := 12.0
@export_range(0, 200, 1, "or_greater") var shark_call_count := 16
## Killing it drops a chest (a powerup pick) and XP worth this much.
@export_range(0.0, 1000.0, 5.0, "or_greater") var shark_xp := 80.0

@export_group("Blood Leviathan")
## The boss: a giant serpent. Beating it completes the stage. Its hp (times 1 +
## coop_scale per extra player), swim speed (m/s), segments and contact damage.
@export_range(1.0, 1000000.0, 100.0, "or_greater") var leviathan_hp := 9000.0
@export_range(0.0, 60.0, 0.5, "or_greater") var leviathan_speed := 11.0
@export_range(2, 60, 1, "or_greater") var leviathan_segments := 14
@export_range(0.5, 6.0, 0.1, "or_greater") var leviathan_girth := 2.2
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
@export_range(0.5, 3.0, 0.05, "or_greater") var xp_curve := 1.35
## Every XP pearl is worth this many times its value.
@export_range(0.0, 10.0, 0.05, "or_greater") var xp_gain := 1.0
## Each level-up offers this many cards, each a different stat (0: no cards,
## just the hp and signature stat).
@export_range(0, 6, 1) var card_choices := 3
## Solo, the game pauses while the cards are up (co-op: the picker can't be
## hurt or seen by zombies instead).
@export var cards_pause := true
## The signature stat's +1 each level, in steps.
@export_range(0.0, 5.0, 0.25, "or_greater") var signature_steps := 1.0

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

@export_group("XP Pearls")
## Pearls this near a fish (m) are drawn in: the pickup range.
@export_range(0.0, 60.0, 0.5, "or_greater") var pickup_range := 7.0
@export_range(0.0, 100.0, 0.5, "or_greater") var pickup_pull := 12.0
## How long (s) an XP pearl waits before fading away.
@export_range(1.0, 600.0, 1.0, "or_greater") var pearl_lifetime := 60.0
@export_range(0.05, 3.0, 0.01, "or_greater") var pearl_size := 0.18
## Each pearl's own light (pretty, but costly with hundreds out).
@export var pearl_lights := false
## At most this many pearls out; past it, a new drop adds its XP to the oldest.
@export_range(10, 2000, 10, "or_greater") var max_pearls := 300

@export_group("Test Tank")
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
## Show the director's live numbers (target alive, alive, next pack) on the HUD.
@export var show_director := false
