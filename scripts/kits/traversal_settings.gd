class_name TraversalSettings
extends SurvivorCamSettings
## The traversal kit's tuning (Traversal): each fish's twist and mobility skill.

static var _fb_trav: TraversalSettings


## The copy the panel edits and the kit reads (the mode's own, once it has registered).
static func shared() -> TraversalSettings:
	var mode_copy = TerrainSettings.provider.call() if TerrainSettings.provider.is_valid() else null
	if mode_copy is TraversalSettings:
		return mode_copy
	if _fb_trav == null:
		_fb_trav = TraversalSettings.new()
	return _fb_trav


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
## Mantis Shrimp, Heavy Hitter: a zombie its punches knock back flies as a
## missile for heavy_time s: each other zombie it hits (up to heavy_max) takes
## heavy_share of the punch's damage, knocked on the way it flew. At most
## heavy_flings missiles at once (the oldest goes), to keep big hordes cheap.
@export_range(0.0, 3.0, 0.05, "or_greater") var heavy_share := 0.5
@export_range(0.0, 2.0, 0.05, "or_greater") var heavy_time := 0.35
@export_range(0, 20, 1, "or_greater") var heavy_max := 3
@export_range(1, 200, 1, "or_greater") var heavy_flings := 24
## Breachers (baby whales), Escort: holding still (slower than chest_still_speed), it heals this
## many hp a second.
@export_range(0.0, 100.0, 0.25, "or_greater") var escort_regen := 4.0
## Swordfish, Streamlined: swims this much faster (+share).
@export_range(0.0, 1.0, 0.01, "or_greater") var streamline_speed := 0.1
## Butterfly Koi, Graceful: this many seconds more of i-frames after a hit.
@export_range(0.0, 3.0, 0.05, "or_greater") var graceful_iframes := 0.5
## Moon Jelly, Many Arms: its Halo has this many more jellies.
@export_range(0, 10, 1, "or_greater") var arms_extra := 1
## Sea Hare, Unpalatable: a zombie that touches it is coated for coat_time s:
## slowed coat_slow (a share of its speed taken), and Purple Haze does
## coat_bonus more to it (+share).
@export_range(0.0, 20.0, 0.1, "or_greater") var coat_time := 2.0
@export_range(0.0, 1.0, 0.05) var coat_slow := 0.3
@export_range(0.0, 3.0, 0.05, "or_greater") var coat_bonus := 0.2
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
## Mantis Shrimp, Recoil Dash: throws a full Cavitation Punch one way and is
## thrown the other at recoil_speed (m/s), with no drag for recoil_time s, untouchable for
## recoil_iframes s. It goes the way the stick leans (else backwards), so the
## punch goes the opposite way (else ahead).
@export_range(0.0, 100.0, 0.5, "or_greater") var recoil_speed := 20.0
@export_range(0.0, 2.0, 0.05, "or_greater") var recoil_time := 0.25
@export_range(0.0, 2.0, 0.05, "or_greater") var recoil_iframes := 0.2
@export_range(0.1, 60.0, 0.1, "or_greater") var recoil_cooldown := 2.0
## Breachers (baby whales), Gulp: sucks every zombie within gulp_range m ahead of it
## in (pulled at gulp_pull m/s), gulp_damage each.
@export_range(1.0, 60.0, 0.5, "or_greater") var gulp_range := 14.0
@export_range(0.0, 100.0, 0.5, "or_greater") var gulp_pull := 25.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var gulp_damage := 25.0
@export_range(0.1, 60.0, 0.1, "or_greater") var gulp_cooldown := 5.0
## Sea Hare, Flutter: flutter_flaps flaps, flutter_gap s apart, each a push of
## flutter_speed (m/s) forward and up (flutter_lift of it up), carrying it up
## over the pack; a Purple Haze cloud bursts where it took off. Then
## flutter_cooldown s.
@export_range(1, 10, 1, "or_greater") var flutter_flaps := 3
@export_range(0.0, 2.0, 0.05, "or_greater") var flutter_gap := 0.25
@export_range(0.0, 100.0, 0.5, "or_greater") var flutter_speed := 9.0
@export_range(0.0, 1.0, 0.05) var flutter_lift := 0.6
@export_range(0.1, 60.0, 0.1, "or_greater") var flutter_cooldown := 4.0
