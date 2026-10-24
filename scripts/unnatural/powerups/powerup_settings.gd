class_name PowerupSettings
extends Resource
## Unnatural's powerups' tuning (planning_unnatural.md §7, §10): one group per
## powerup, its base numbers and how each stack adds to them, and a `stacks`
## override for testing (a player has at least that many). Weapons (Weapons:
## Greek Fire, the Halo, Depth Charges, Remoras, the Coil, and the fish's own
## attack) level up instead of stacking: their `*_step` (and some
## `*_per_stack`) values are what one common step of each facet adds, and
## their `stacks` override is a level override. Shown in the tuning panel's
## POWERUPS section and saved with presets ([powerups]). One shared copy
## (shared()), read live.

static var _shared: PowerupSettings


static func shared() -> PowerupSettings:
	if _shared == null:
		_shared = PowerupSettings.new()
	return _shared


@export_group("Procs")
## Every hit carries a proc coefficient (an attack or battery 1, a lightning
## jump chain_proc, a torpedo torpedo_proc, a burn fire_proc): proc chances
## are multiplied by it, and a hit a powerup started can't start that powerup
## again, so chains stay fun without running away. Weapons that hit very often have
## low ones (P4): Greek Fire's burn 0, the Halo 0.1, the Coil 0.15.
@export_range(0.0, 1.0, 0.05) var chain_proc := 0.3
@export_range(0.0, 1.0, 0.05) var torpedo_proc := 0.5
@export_range(0.0, 1.0, 0.05) var fire_proc := 0.0

@export_group("Fish attack (weapon)")
## The fish's own attack is a weapon too: each upgrade card raises some of its
## facets by these steps (a common card's; rarer ones more). Damage, rate
## (attacks a second), size (reach, area), knockback and speed are shares
## (0.2: +20%); count adds projectiles (or arcs, or spine rings). attack_level
## is a level override for testing (the fish's attack acts at least this level).
@export_range(0, 20, 1, "or_greater") var attack_level := 0
@export_range(0.0, 2.0, 0.01, "or_greater") var attack_damage_step := 0.2
@export_range(0.0, 2.0, 0.01, "or_greater") var attack_rate_step := 0.12
@export_range(0.0, 2.0, 0.01, "or_greater") var attack_size_step := 0.12
@export_range(0.0, 5.0, 0.05, "or_greater") var attack_knock_step := 0.3
@export_range(0, 10, 1, "or_greater") var attack_count_step := 1
@export_range(0.0, 2.0, 0.01, "or_greater") var attack_speed_step := 0.15

@export_group("Greek Fire Trail")
## A weapon. Burning patches left behind as you swim (one every fire_spacing m,
## divided by 1 + the density facet), each fire_radius round (times 1 + the
## size facet), lasting fire_life s (+ the life facet; times 1 + Duration) and
## burning zombies in them for fire_dps a second (times 1 + the burn facet). A
## facet step: fire_dps_step burn, fire_life_per_stack s of life,
## fire_radius_step size, fire_density_step density, fire_patches_step more
## patches out. fire_stacks: a level override for testing.
@export_range(0, 20, 1, "or_greater") var fire_stacks := 0
@export_range(0.2, 20.0, 0.1, "or_greater") var fire_spacing := 1.6
@export_range(0.2, 20.0, 0.1, "or_greater") var fire_radius := 1.6
@export_range(0.1, 30.0, 0.1, "or_greater") var fire_life := 2.0
@export_range(0.0, 30.0, 0.1, "or_greater") var fire_life_per_stack := 0.4
@export_range(0.0, 500.0, 1.0, "or_greater") var fire_dps := 40.0
@export_range(0.0, 5.0, 0.05, "or_greater") var fire_dps_step := 0.25
@export_range(0.0, 2.0, 0.01, "or_greater") var fire_radius_step := 0.1
@export_range(0.0, 2.0, 0.01, "or_greater") var fire_density_step := 0.12
@export_range(0, 200, 1, "or_greater") var fire_patches_step := 5
## At most this many patches out per player (+ the patches facet).
@export_range(1, 500, 1, "or_greater") var fire_max_patches := 60

@export_group("Chain Lightning")
## Any hit has lightning_chance (+ per stack, times the hit's proc
## coefficient) to start lightning that jumps lightning_jumps (+ per stack)
## times, lightning_range m between zombies, lightning_damage a jump.
@export_range(0, 20, 1, "or_greater") var lightning_stacks := 0
@export_range(0.0, 1.0, 0.01) var lightning_chance := 0.15
@export_range(0.0, 1.0, 0.01) var lightning_chance_per_stack := 0.08
@export_range(0, 50, 1, "or_greater") var lightning_jumps := 3
@export_range(0, 20, 1, "or_greater") var lightning_jumps_per_stack := 1
@export_range(0.5, 60.0, 0.5, "or_greater") var lightning_range := 8.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var lightning_damage := 22.0
## At most this many strikes a second per player (more procs fizzle), so a
## big proc chain stays smooth.
@export_range(1.0, 1000.0, 1.0, "or_greater") var lightning_max_rate := 30.0

@export_group("Torpedo Launcher")
## Any hit has torpedo_chance (+ per stack, times the hit's proc coefficient)
## to fire torpedoes (1, +1 every torpedo_stacks_per_extra stacks) that seek
## the nearest zombies at torpedo_speed and explode on impact:
## torpedo_damage within torpedo_blast (+ per stack) m.
@export_range(0, 20, 1, "or_greater") var torpedo_stacks := 0
@export_range(0.0, 1.0, 0.01) var torpedo_chance := 0.08
@export_range(0.0, 1.0, 0.01) var torpedo_chance_per_stack := 0.05
@export_range(1, 10, 1, "or_greater") var torpedo_stacks_per_extra := 2
@export_range(1.0, 100.0, 0.5, "or_greater") var torpedo_speed := 18.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var torpedo_damage := 40.0
@export_range(0.5, 30.0, 0.1, "or_greater") var torpedo_blast := 3.0
@export_range(0.0, 10.0, 0.1, "or_greater") var torpedo_blast_per_stack := 0.6
## A torpedo gives up after this long (s).
@export_range(0.5, 20.0, 0.1, "or_greater") var torpedo_life := 3.0
## At most this many flying per player (more launches wait), and at most this
## many blasts a second are shown (the rest still hurt): a big launcher stays smooth.
@export_range(1, 1000, 1, "or_greater") var torpedo_max := 48
@export_range(0.0, 100.0, 0.5, "or_greater") var torpedo_fx_rate := 10.0

@export_group("Bow Grow Bow")
## Wearing the bow makes the bow wave bigger (its length and girth times 1 +
## bow_growth per stack), so you batter far wider. From bow_low_speed_stacks
## stacks on, the bow wave batters below the battering speed too (down to
## bow_low_speed of it).
@export_range(0, 20, 1, "or_greater") var bow_stacks := 0
@export_range(0.0, 5.0, 0.05, "or_greater") var bow_growth := 0.5
@export_range(1, 20, 1, "or_greater") var bow_low_speed_stacks := 3
@export_range(0.0, 1.0, 0.05) var bow_low_speed := 0.5


@export_group("Barnacle Plating")
## Barnacles on the back: +barnacle_armour armour a stack (each hit taken is
## that much less, down to 1).
@export_range(0, 20, 1, "or_greater") var barnacle_stacks := 0
@export_range(0.0, 50.0, 0.5, "or_greater") var barnacle_armour := 2.0

@export_group("Hermit Shell")
## A shell on the back: +hermit_hp max hp a stack.
@export_range(0, 20, 1, "or_greater") var hermit_stacks := 0
@export_range(0.0, 500.0, 1.0, "or_greater") var hermit_hp := 15.0

@export_group("Fizzy Soda")
## Bubbles fizzing off the gills: +soda_attack_speed attack speed a stack (0.08: +8%).
@export_range(0, 20, 1, "or_greater") var soda_stacks := 0
@export_range(0.0, 2.0, 0.01, "or_greater") var soda_attack_speed := 0.08

@export_group("Speedy Seahorse")
## A seahorse riding along: +seahorse_speed swim speed a stack (0.06: +6%).
@export_range(0, 20, 1, "or_greater") var seahorse_stacks := 0
@export_range(0.0, 2.0, 0.01, "or_greater") var seahorse_speed := 0.06

@export_group("Remora Buddy")
## A weapon. Remoras stuck on the fish (remora_count, + the count facet): each
## nips the nearest zombie within remora_range every remora_interval s for
## remora_damage (proc coefficient remora_proc). A facet step:
## remora_count_per_stack more remoras, remora_damage_step damage,
## remora_rate_step bite rate, remora_range_step reach. remora_stacks: a level
## override for testing.
@export_range(0, 20, 1, "or_greater") var remora_stacks := 0
@export_range(0, 20, 1, "or_greater") var remora_count := 1
@export_range(0, 10, 1, "or_greater") var remora_count_per_stack := 1
@export_range(0.05, 20.0, 0.05, "or_greater") var remora_interval := 1.5
@export_range(0.5, 60.0, 0.5, "or_greater") var remora_range := 7.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var remora_damage := 55.0
@export_range(0.0, 1.0, 0.05) var remora_proc := 0.5
@export_range(0.0, 2.0, 0.01, "or_greater") var remora_damage_step := 0.25
@export_range(0.0, 2.0, 0.01, "or_greater") var remora_rate_step := 0.15
@export_range(0.0, 2.0, 0.01, "or_greater") var remora_range_step := 0.15

@export_group("Bubble Wrap")
## A bubble round the fish: once it's gone bubble_ready s untouched (less
## bubble_ready_per_stack a stack, down to bubble_ready_min), it takes the
## next hit instead of the fish, and pops.
@export_range(0, 20, 1, "or_greater") var bubble_stacks := 0
@export_range(0.1, 60.0, 0.1, "or_greater") var bubble_ready := 8.0
@export_range(0.0, 10.0, 0.1, "or_greater") var bubble_ready_per_stack := 1.0
@export_range(0.1, 30.0, 0.1, "or_greater") var bubble_ready_min := 2.0

@export_group("Pufferfish Spines")
## Spines out: a zombie that touches you takes spine_reflect (+ per stack) of
## what it did back, and a burst of spines hits everything within
## spine_burst_radius for spine_burst_damage (+ per stack), proc spine_proc.
@export_range(0, 20, 1, "or_greater") var spine_stacks := 0
@export_range(0.0, 20.0, 0.05, "or_greater") var spine_reflect := 0.5
@export_range(0.0, 20.0, 0.05, "or_greater") var spine_reflect_per_stack := 0.25
@export_range(0.5, 40.0, 0.5, "or_greater") var spine_burst_radius := 4.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var spine_burst_damage := 25.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var spine_burst_damage_per_stack := 15.0
@export_range(0.0, 1.0, 0.05) var spine_proc := 0.5

@export_group("Jellyfish Halo")
## A weapon. Jellies orbiting the fish (jelly_count, + the count facet)
## halo_radius m out, halo_spin turns a second: each stings zombies it touches
## (jelly_radius) for jelly_damage every jelly_tick s, proc jelly_proc. A facet
## step: jelly_count_per_stack more jellies, jelly_damage_step damage,
## halo_radius_step orbit size, halo_spin_step orbit speed, jelly_rate_step
## sting rate. jelly_stacks: a level override for testing.
@export_range(0, 20, 1, "or_greater") var jelly_stacks := 0
@export_range(0, 20, 1, "or_greater") var jelly_count := 2
@export_range(0, 10, 1, "or_greater") var jelly_count_per_stack := 1
@export_range(0.5, 30.0, 0.1, "or_greater") var halo_radius := 3.2
@export_range(0.0, 5.0, 0.05, "or_greater") var halo_spin := 0.5
@export_range(0.1, 10.0, 0.05, "or_greater") var jelly_radius := 1.2
@export_range(0.0, 1000.0, 1.0, "or_greater") var jelly_damage := 35.0
@export_range(0.05, 5.0, 0.05, "or_greater") var jelly_tick := 0.25
@export_range(0.0, 1.0, 0.05) var jelly_proc := 0.1
@export_range(0.0, 2.0, 0.01, "or_greater") var jelly_damage_step := 0.25
@export_range(0.0, 2.0, 0.01, "or_greater") var halo_radius_step := 0.12
@export_range(0.0, 2.0, 0.01, "or_greater") var halo_spin_step := 0.15
@export_range(0.0, 2.0, 0.01, "or_greater") var jelly_rate_step := 0.15

@export_group("Electric Eel")
## An eel coiled on: a battery sends out a shock ring, eel_radius (+ per
## stack) m round, eel_damage (+ per stack) to every zombie in it, proc
## eel_proc. At most one ring every eel_cooldown s.
@export_range(0, 20, 1, "or_greater") var eel_stacks := 0
@export_range(0.5, 40.0, 0.5, "or_greater") var eel_radius := 5.0
@export_range(0.0, 20.0, 0.25, "or_greater") var eel_radius_per_stack := 1.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var eel_damage := 30.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var eel_damage_per_stack := 20.0
@export_range(0.0, 10.0, 0.05, "or_greater") var eel_cooldown := 0.3
@export_range(0.0, 1.0, 0.05) var eel_proc := 0.5

@export_group("Depth Charges")
## A weapon. A mine rack: every charge_interval s (divided by 1 + the rate
## facet, and by attack speed weighted charge_speed_weight) it drops
## charge_per_drop mines (+ the mines facet, + Quantity), each lobbed over
## charge_lob_time s to a zombie within charge_lob m of the tail (times Size),
## else fanned out behind. A mine arms after charge_arm s (divided by 1 + the
## arming facet), then blows when a zombie comes within charge_trigger m
## (times Size) or after charge_life s (times 1 + Duration): charge_damage
## within charge_blast m (each times 1 + its facet), proc charge_proc. At most
## charge_max mines out, the oldest go (a cap for performance). A facet step:
## charge_damage_step damage, charge_blast_step blast size, charge_rate_step
## drop rate, charge_count_step more mines per drop, charge_arm_step arming
## speed. charge_stacks: a level override for testing.
@export_range(0, 20, 1, "or_greater") var charge_stacks := 0
@export_range(0.1, 60.0, 0.1, "or_greater") var charge_interval := 3.0
@export_range(0.0, 5.0, 0.05, "or_greater") var charge_speed_weight := 2.0
@export_range(1, 20, 1, "or_greater") var charge_per_drop := 1
@export_range(0.0, 30.0, 0.25, "or_greater") var charge_lob := 6.0
@export_range(0.05, 3.0, 0.05, "or_greater") var charge_lob_time := 0.35
@export_range(0.0, 10.0, 0.05, "or_greater") var charge_arm := 0.5
@export_range(0.2, 20.0, 0.1, "or_greater") var charge_trigger := 3.0
@export_range(0.5, 120.0, 0.5, "or_greater") var charge_life := 10.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var charge_damage := 24.0
@export_range(0.5, 40.0, 0.25, "or_greater") var charge_blast := 5.0
@export_range(1, 200, 1, "or_greater") var charge_max := 30
@export_range(0.0, 1.0, 0.05) var charge_proc := 0.5
@export_range(0.0, 2.0, 0.01, "or_greater") var charge_damage_step := 0.2
@export_range(0.0, 2.0, 0.01, "or_greater") var charge_blast_step := 0.15
@export_range(0.0, 2.0, 0.01, "or_greater") var charge_rate_step := 0.2
@export_range(0, 10, 1, "or_greater") var charge_count_step := 1
@export_range(0.0, 2.0, 0.01, "or_greater") var charge_arm_step := 0.3

@export_group("Anglerfish Lure")
## A glowing lure: every lure_interval s (times 1 - lure_interval_per_stack a
## stack) it drops a decoy the zombies chase (lure_pull: it wins over a player
## up to that many times nearer), for lure_life s. Then it bursts:
## lure_damage (+ per stack) within lure_blast m, proc lure_proc.
@export_range(0, 20, 1, "or_greater") var lure_stacks := 0
@export_range(0.5, 120.0, 0.5, "or_greater") var lure_interval := 10.0
@export_range(0.0, 0.9, 0.01) var lure_interval_per_stack := 0.1
@export_range(0.5, 60.0, 0.5, "or_greater") var lure_life := 5.0
@export_range(1.0, 20.0, 0.1, "or_greater") var lure_pull := 3.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var lure_damage := 80.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var lure_damage_per_stack := 50.0
@export_range(0.5, 40.0, 0.25, "or_greater") var lure_blast := 6.0
@export_range(0.0, 1.0, 0.05) var lure_proc := 0.5
## At most this many lures out at once (the next waits).
@export_range(1, 50, 1, "or_greater") var lure_max := 3

@export_group("Tsunami Heart")
## A glowing heart: a battery sends a wave along your heading, tsunami_width
## (+ per stack) m wide, rolling tsunami_length m at tsunami_speed m/s; every
## zombie it reaches takes tsunami_damage (+ per stack) and is swept along,
## proc tsunami_proc. At most one wave every tsunami_cooldown s.
@export_range(0, 20, 1, "or_greater") var tsunami_stacks := 0
@export_range(0.5, 60.0, 0.5, "or_greater") var tsunami_width := 6.0
@export_range(0.0, 20.0, 0.5, "or_greater") var tsunami_width_per_stack := 2.0
@export_range(1.0, 200.0, 1.0, "or_greater") var tsunami_length := 24.0
@export_range(1.0, 200.0, 1.0, "or_greater") var tsunami_speed := 30.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var tsunami_damage := 60.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var tsunami_damage_per_stack := 40.0
@export_range(0.0, 30.0, 0.05, "or_greater") var tsunami_cooldown := 1.0
@export_range(0.0, 1.0, 0.05) var tsunami_proc := 1.0


@export_group("Leviathan's Coil (boss)")
## A boss weapon, the Blood Leviathan's (it arrives at coil_arrive_level):
## coil_segments (+ the count facet) glowing coils trail the fish
## coil_spacing m apart; every coil_tick s each hurts what it touches
## (coil_radius) for coil_damage, proc coil_proc. A facet step:
## coil_segments_per_stack more coils, coil_damage_step damage,
## coil_radius_step coil size, coil_rate_step hit rate. coil_stacks: a level
## override for testing.
@export_range(0, 20, 1, "or_greater") var coil_stacks := 0
@export_range(1, 20, 1, "or_greater") var coil_arrive_level := 5
@export_range(1, 100, 1, "or_greater") var coil_segments := 6
@export_range(0, 50, 1, "or_greater") var coil_segments_per_stack := 3
@export_range(0.2, 10.0, 0.1, "or_greater") var coil_spacing := 1.4
@export_range(0.1, 10.0, 0.05, "or_greater") var coil_radius := 0.9
@export_range(0.0, 1000.0, 1.0, "or_greater") var coil_damage := 55.0
@export_range(0.05, 5.0, 0.05, "or_greater") var coil_tick := 0.25
@export_range(0.0, 1.0, 0.05) var coil_proc := 0.15
@export_range(0.0, 2.0, 0.01, "or_greater") var coil_damage_step := 0.25
@export_range(0.0, 2.0, 0.01, "or_greater") var coil_radius_step := 0.15
@export_range(0.0, 2.0, 0.01, "or_greater") var coil_rate_step := 0.15
## So it never hides your fish: no coils are drawn within coil_clear m of it (they
## still hurt there), each fades out from coil_fade_far m to coil_fade_near m from
## the camera, and none is drawn bigger than coil_draw_max m (its reach still grows).
@export_range(0.0, 20.0, 0.25, "or_greater") var coil_clear := 3.5
@export_range(0.0, 30.0, 0.5, "or_greater") var coil_fade_near := 6.0
@export_range(0.0, 60.0, 0.5, "or_greater") var coil_fade_far := 13.0
@export_range(0.1, 10.0, 0.05, "or_greater") var coil_draw_max := 0.9

@export_group("Cursed")
## Blood Moon Shard: +shard_damage damage, +shard_taken damage taken, a stack.
@export_range(0, 20, 1, "or_greater") var shard_stacks := 0
@export_range(0.0, 10.0, 0.05, "or_greater") var shard_damage := 1.0
@export_range(0.0, 10.0, 0.05, "or_greater") var shard_taken := 0.5
## Glass Coral: +coral_damage damage; max hp times coral_hp, a stack.
@export_range(0, 20, 1, "or_greater") var coral_stacks := 0
@export_range(0.0, 10.0, 0.05, "or_greater") var coral_damage := 1.0
@export_range(0.05, 1.0, 0.05) var coral_hp := 0.5
## Siren's Song: +siren_xp XP gain (1: double); siren_horde more zombies, a stack.
@export_range(0, 20, 1, "or_greater") var siren_stacks := 0
@export_range(0.0, 10.0, 0.05, "or_greater") var siren_xp := 1.0
@export_range(0.0, 10.0, 0.05, "or_greater") var siren_horde := 0.5
## Abyssal Hunger: a kill heals hunger_heal of max hp; lose hunger_drain of
## max hp a second (a stack). Off hunger_can_kill, the drain stops at 1 hp.
@export_range(0, 20, 1, "or_greater") var hunger_stacks := 0
@export_range(0.0, 1.0, 0.005) var hunger_heal := 0.03
@export_range(0.0, 0.5, 0.005) var hunger_drain := 0.02
@export var hunger_can_kill := false
## Sunken Idol: one more pick from every chest; each stage event takes a stack
## of a random other powerup, a stack.
@export_range(0, 20, 1, "or_greater") var idol_stacks := 0

@export_group("Kelp Wrap")
## Kelp ribbons trailing: +kelp_regen hp a second a stack.
@export_range(0, 20, 1, "or_greater") var kelp_stacks := 0
@export_range(0.0, 20.0, 0.1, "or_greater") var kelp_regen := 0.5

@export_group("Sea Salt")
## Glittering salt crystals: +salt_crit crit chance a stack (0.05: +5%).
@export_range(0, 20, 1, "or_greater") var salt_stacks := 0
@export_range(0.0, 1.0, 0.01, "or_greater") var salt_crit := 0.05

@export_group("Coral Knuckles")
## Coral on the nose: +knuckles_battery battery damage a stack (0.2: +20%).
@export_range(0, 20, 1, "or_greater") var knuckles_stacks := 0
@export_range(0.0, 5.0, 0.05, "or_greater") var knuckles_battery := 0.2

@export_group("Diver's Goggles")
## Goggles: +goggles_range pickup range a stack (0.25: +25%).
@export_range(0, 20, 1, "or_greater") var goggles_stacks := 0
@export_range(0.0, 5.0, 0.05, "or_greater") var goggles_range := 0.25

@export_group("Lucky Sand Dollar")
## A coin on the forehead: +dollar_luck luck a stack.
@export_range(0, 20, 1, "or_greater") var dollar_stacks := 0
@export_range(0.0, 5.0, 0.01, "or_greater") var dollar_luck := 0.1

@export_group("Lamprey")
## A lamprey trailing: a kill heals lamprey_heal hp (a stack), at most once
## every lamprey_gap s.
@export_range(0, 20, 1, "or_greater") var lamprey_stacks := 0
@export_range(0.0, 100.0, 0.5, "or_greater") var lamprey_heal := 1.0
@export_range(0.0, 5.0, 0.05, "or_greater") var lamprey_gap := 0.1

@export_group("Clam Shield")
## A clam: once it's gone clam_ready s untouched (less clam_ready_per_stack a
## stack, down to clam_ready_min) it takes the next hit for you, then shuts for
## that long. Unlike Bubble Wrap it recharges whether or not you're hurt.
@export_range(0, 20, 1, "or_greater") var clam_stacks := 0
@export_range(0.1, 120.0, 0.5, "or_greater") var clam_ready := 12.0
@export_range(0.0, 20.0, 0.1, "or_greater") var clam_ready_per_stack := 2.0
@export_range(0.1, 60.0, 0.1, "or_greater") var clam_ready_min := 3.0

@export_group("Momentum Fin")
## Streamers: your hits do momentum_damage more damage per momentum_speed m/s
## you're swimming (0.1 per 10 m/s: +10%), a stack.
@export_range(0, 20, 1, "or_greater") var momentum_stacks := 0
@export_range(0.0, 5.0, 0.01, "or_greater") var momentum_damage := 0.1
@export_range(1.0, 100.0, 0.5, "or_greater") var momentum_speed := 10.0

@export_group("Treasure Map")
## A rolled map: zombies drop chests treasure_chests (a stack) more often, and
## your HUD pings chests treasure_ping more metres out (a stack).
@export_range(0, 20, 1, "or_greater") var map_stacks := 0
@export_range(0.0, 10.0, 0.05, "or_greater") var treasure_chests := 0.3
@export_range(0.0, 500.0, 1.0, "or_greater") var treasure_ping := 10.0

@export_group("Sticky Anemone")
## A tuft of anemone (common): a hit has anemone_chance (more
## anemone_chance_per_stack a stack, times the hit's proc) to take
## anemone_slow of the zombie's speed for anemone_time s.
@export_range(0, 20, 1, "or_greater") var anemone_stacks := 0
@export_range(0.0, 1.0, 0.01) var anemone_chance := 0.1
@export_range(0.0, 1.0, 0.01) var anemone_chance_per_stack := 0.05
@export_range(0.0, 1.0, 0.05) var anemone_slow := 0.4
@export_range(0.0, 20.0, 0.1, "or_greater") var anemone_time := 2.0

@export_group("Ink Sac")
## A dark sac (common): when you're hurt, an ink cloud ink_radius m round you
## blinds the zombies in it for ink_time s (more ink_time_per_stack a stack):
## they lose you (all but ink_blind of their speed) and are pushed off you. At
## most once every ink_cooldown s.
@export_range(0, 20, 1, "or_greater") var ink_stacks := 0
@export_range(0.5, 40.0, 0.5, "or_greater") var ink_radius := 6.0
@export_range(0.0, 20.0, 0.1, "or_greater") var ink_time := 2.0
@export_range(0.0, 10.0, 0.1, "or_greater") var ink_time_per_stack := 0.5
@export_range(0.0, 1.0, 0.05) var ink_blind := 0.9
@export_range(0.0, 30.0, 0.5, "or_greater") var ink_cooldown := 3.0

@export_group("Sonar Pinger")
## A dish on the head (uncommon): every sonar_every s a pulse marks every
## zombie within sonar_radius m till the next one; your hits on marked zombies
## do sonar_bonus more damage (more sonar_bonus_per_stack a stack).
@export_range(0, 20, 1, "or_greater") var sonar_stacks := 0
@export_range(0.5, 60.0, 0.5, "or_greater") var sonar_every := 6.0
@export_range(1.0, 200.0, 1.0, "or_greater") var sonar_radius := 25.0
@export_range(0.0, 5.0, 0.05, "or_greater") var sonar_bonus := 0.25
@export_range(0.0, 5.0, 0.05, "or_greater") var sonar_bonus_per_stack := 0.1

@export_group("Cold Seep")
## Frosted fins (uncommon): a hit has seep_chance (more seep_chance_per_stack
## a stack, times the hit's proc) to freeze the zombie solid for seep_time s.
## Bosses shrug it off.
@export_range(0, 20, 1, "or_greater") var seep_stacks := 0
@export_range(0.0, 1.0, 0.01) var seep_chance := 0.08
@export_range(0.0, 1.0, 0.01) var seep_chance_per_stack := 0.04
@export_range(0.0, 20.0, 0.1, "or_greater") var seep_time := 1.5

@export_group("Whirlpool Charm")
## A spiral shell (uncommon): a kill has charm_chance (more
## charm_chance_per_stack a stack) to open a little whirlpool there for
## charm_time s: it pulls zombies within charm_radius m in (charm_pull m/s)
## and grinds them, charm_dps a second (more charm_dps_per_stack a stack). At
## most charm_max out at once.
@export_range(0, 20, 1, "or_greater") var charm_stacks := 0
@export_range(0.0, 1.0, 0.01) var charm_chance := 0.06
@export_range(0.0, 1.0, 0.01) var charm_chance_per_stack := 0.03
@export_range(0.5, 40.0, 0.5, "or_greater") var charm_radius := 6.0
@export_range(0.0, 60.0, 0.5, "or_greater") var charm_pull := 12.0
@export_range(0.0, 2000.0, 1.0, "or_greater") var charm_dps := 30.0
@export_range(0.0, 2000.0, 1.0, "or_greater") var charm_dps_per_stack := 15.0
@export_range(0.1, 30.0, 0.1, "or_greater") var charm_time := 3.0
@export_range(1, 50, 1, "or_greater") var charm_max := 4

@export_group("Kraken's Grasp")
## A tentacle (rare): a hit has kraken_chance (more kraken_chance_per_stack a
## stack, times the hit's proc) to bring a tentacle slamming down on the
## zombie: kraken_damage (more kraken_damage_per_stack a stack) to every
## zombie within kraken_radius m, held still for kraken_hold s. At most
## kraken_max_rate slams a second.
@export_range(0, 20, 1, "or_greater") var kraken_stacks := 0
@export_range(0.0, 1.0, 0.01) var kraken_chance := 0.05
@export_range(0.0, 1.0, 0.01) var kraken_chance_per_stack := 0.025
@export_range(0.0, 5000.0, 5.0, "or_greater") var kraken_damage := 120.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var kraken_damage_per_stack := 60.0
@export_range(0.5, 30.0, 0.5, "or_greater") var kraken_radius := 4.5
@export_range(0.0, 10.0, 0.1, "or_greater") var kraken_hold := 1.5
@export_range(0.1, 20.0, 0.1, "or_greater") var kraken_max_rate := 2.0

@export_group("Ghost Swordfish")
## A phantom swordfish escort (rare): every ghost_every s each (one a stack)
## dashes ghost_length m through the nearest line of zombies within
## ghost_range m, ghost_damage to each within ghost_width m of its path.
@export_range(0, 20, 1, "or_greater") var ghost_stacks := 0
@export_range(0.2, 30.0, 0.1, "or_greater") var ghost_every := 3.0
@export_range(1.0, 100.0, 1.0, "or_greater") var ghost_range := 20.0
@export_range(1.0, 100.0, 1.0, "or_greater") var ghost_length := 18.0
@export_range(0.1, 10.0, 0.1, "or_greater") var ghost_width := 1.5
@export_range(0.0, 5000.0, 5.0, "or_greater") var ghost_damage := 60.0

@export_group("Ammonite Spiral")
## A spiral shell (rare): a projectile's hit (spears, bubbles, spines,
## torpedoes) splits into ammonite_splits shards (one more a stack), each to
## another zombie within ammonite_range m for ammonite_share of the hit. At
## most ammonite_max_rate splits a second.
@export_range(0, 20, 1, "or_greater") var ammonite_stacks := 0
@export_range(1, 20, 1, "or_greater") var ammonite_splits := 3
@export_range(0.0, 2.0, 0.05, "or_greater") var ammonite_share := 0.35
@export_range(1.0, 50.0, 0.5, "or_greater") var ammonite_range := 8.0
@export_range(1.0, 200.0, 1.0, "or_greater") var ammonite_max_rate := 20.0

@export_group("Riptide")
## Swirling water (rare): a stride timed at its peak (timing riptide_timing or
## better) leaves a current riptide_length m behind you for riptide_time s:
## zombies in it (riptide_width m either side) are dragged back riptide_drag
## m/s and take riptide_dps a second (more riptide_dps_per_stack a stack).
@export_range(0, 20, 1, "or_greater") var riptide_stacks := 0
@export_range(0.0, 1.0, 0.05) var riptide_timing := 0.75
@export_range(1.0, 60.0, 0.5, "or_greater") var riptide_length := 10.0
@export_range(0.5, 20.0, 0.5, "or_greater") var riptide_width := 2.5
@export_range(0.1, 20.0, 0.1, "or_greater") var riptide_time := 3.0
@export_range(0.0, 100.0, 0.5, "or_greater") var riptide_drag := 8.0
@export_range(0.0, 2000.0, 1.0, "or_greater") var riptide_dps := 25.0
@export_range(0.0, 2000.0, 1.0, "or_greater") var riptide_dps_per_stack := 12.0
## At most this many currents out at once (a new one replaces the oldest).
@export_range(1, 50, 1, "or_greater") var riptide_max := 6

@export_group("Reef Guardian")
## A coral crown (rare): dropping under guardian_threshold of your max hp makes
## you untouchable for guardian_time s, then it rests guardian_cooldown s (each
## more stack takes guardian_cooldown_per_stack of that off).
@export_range(0, 20, 1, "or_greater") var guardian_stacks := 0
@export_range(0.0, 1.0, 0.05) var guardian_threshold := 0.25
@export_range(0.0, 20.0, 0.25, "or_greater") var guardian_time := 3.0
@export_range(1.0, 600.0, 1.0, "or_greater") var guardian_cooldown := 60.0
@export_range(0.0, 0.9, 0.05) var guardian_cooldown_per_stack := 0.15

@export_group("Bioluminescence")
## Glowing spots (rare): every level-up and chest you open sends out a flash
## biolum_radius m round you (more biolum_radius_per_stack a stack), doing
## biolum_damage per team level (more biolum_damage_per_stack a stack).
@export_range(0, 20, 1, "or_greater") var biolum_stacks := 0
@export_range(1.0, 100.0, 1.0, "or_greater") var biolum_radius := 12.0
@export_range(0.0, 50.0, 0.5, "or_greater") var biolum_radius_per_stack := 2.0
@export_range(0.0, 500.0, 1.0, "or_greater") var biolum_damage := 10.0
@export_range(0.0, 500.0, 1.0, "or_greater") var biolum_damage_per_stack := 5.0

@export_group("Poseidon's Trident")
## A trident (legendary): every trident_every-th attack (a fish with no attack
## of its own: every trident_every s) calls lightning down on the biggest
## zombie within trident_range m: trident_damage (more trident_damage_per_stack
## a stack) to everything within trident_radius m of it.
@export_range(0, 20, 1, "or_greater") var trident_stacks := 0
@export_range(1, 20, 1, "or_greater") var trident_every := 3
@export_range(1.0, 100.0, 1.0, "or_greater") var trident_range := 30.0
@export_range(0.5, 20.0, 0.5, "or_greater") var trident_radius := 4.0
@export_range(0.0, 10000.0, 10.0, "or_greater") var trident_damage := 250.0
@export_range(0.0, 10000.0, 10.0, "or_greater") var trident_damage_per_stack := 150.0

@export_group("Megalodon Tooth")
## A huge tooth (legendary): a crit finishes off a zombie left under
## tooth_execute of its hp (more tooth_execute_per_stack a stack, up to
## tooth_execute_max). Not bosses.
@export_range(0, 20, 1, "or_greater") var tooth_stacks := 0
@export_range(0.0, 1.0, 0.01) var tooth_execute := 0.15
@export_range(0.0, 1.0, 0.01) var tooth_execute_per_stack := 0.05
@export_range(0.0, 1.0, 0.01) var tooth_execute_max := 0.5

@export_group("Moon Pearl")
## A pearl on a chain (legendary): every level-up lets you take pearl_picks more
## cards (a stack) from the same offer.
@export_range(0, 20, 1, "or_greater") var moon_pearl_stacks := 0
@export_range(0, 5, 1, "or_greater") var pearl_picks := 1

@export_group("Abyssal Engine")
## A churning engine (legendary): engine_projectiles more projectiles and
## engine_size more Size (0.15: +15%) to every attack, a stack.
@export_range(0, 20, 1, "or_greater") var engine_stacks := 0
@export_range(0.0, 10.0, 1.0, "or_greater") var engine_projectiles := 1.0
@export_range(0.0, 2.0, 0.05, "or_greater") var engine_size := 0.15

## Powerup id -> its testing override's setting.
const STACKS := {
	"sticky_anemone": "anemone_stacks",
	"ink_sac": "ink_stacks",
	"sonar_pinger": "sonar_stacks",
	"cold_seep": "seep_stacks",
	"whirlpool_charm": "charm_stacks",
	"krakens_grasp": "kraken_stacks",
	"ghost_swordfish": "ghost_stacks",
	"ammonite_spiral": "ammonite_stacks",
	"riptide": "riptide_stacks",
	"reef_guardian": "guardian_stacks",
	"bioluminescence": "biolum_stacks",
	"poseidons_trident": "trident_stacks",
	"megalodon_tooth": "tooth_stacks",
	"moon_pearl": "moon_pearl_stacks",
	"abyssal_engine": "engine_stacks",
	"kelp_wrap": "kelp_stacks",
	"sea_salt": "salt_stacks",
	"coral_knuckles": "knuckles_stacks",
	"divers_goggles": "goggles_stacks",
	"lucky_sand_dollar": "dollar_stacks",
	"lamprey": "lamprey_stacks",
	"clam_shield": "clam_stacks",
	"momentum_fin": "momentum_stacks",
	"treasure_map": "map_stacks",
	"attack_greek_fire": "fire_stacks",
	"chain_lightning": "lightning_stacks",
	"torpedo": "torpedo_stacks",
	"bow_grow_bow": "bow_stacks",
	"barnacle_plating": "barnacle_stacks",
	"hermit_shell": "hermit_stacks",
	"fizzy_soda": "soda_stacks",
	"speedy_seahorse": "seahorse_stacks",
	"attack_remora_buddy": "remora_stacks",
	"bubble_wrap": "bubble_stacks",
	"pufferfish_spines": "spine_stacks",
	"attack_jellyfish_halo": "jelly_stacks",
	"electric_eel": "eel_stacks",
	"attack_depth_charges": "charge_stacks",
	"anglerfish_lure": "lure_stacks",
	"tsunami_heart": "tsunami_stacks",
	"attack_leviathans_coil": "coil_stacks",
	"blood_moon_shard": "shard_stacks",
	"glass_coral": "coral_stacks",
	"sirens_song": "siren_stacks",
	"abyssal_hunger": "hunger_stacks",
	"sunken_idol": "idol_stacks",
}


## The testing override for powerup `id`'s stacks (0: none).
func stacks_override(id: String) -> int:
	return get(STACKS[id]) if STACKS.has(id) else 0
