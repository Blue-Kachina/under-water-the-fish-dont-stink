class_name PowerupSettings
extends Resource
## Unnatural's powerups' tuning (planning_unnatural.md §7, §10): one group per
## powerup, its base numbers and how each stack adds to them, and a `stacks`
## override for testing (a player has at least that many). Shown in the tuning
## panel's POWERUPS section and saved with presets ([powerups]). One shared
## copy (shared()), read live.

static var _shared: PowerupSettings


static func shared() -> PowerupSettings:
	if _shared == null:
		_shared = PowerupSettings.new()
	return _shared


@export_group("Procs")
## Every hit carries a proc coefficient (an attack or battery 1, a lightning
## jump chain_proc, a torpedo torpedo_proc, a burn fire_proc): proc chances
## are multiplied by it, and a hit a powerup started can't start that powerup
## again, so chains stay fun without running away.
@export_range(0.0, 1.0, 0.05) var chain_proc := 0.3
@export_range(0.0, 1.0, 0.05) var torpedo_proc := 0.5
@export_range(0.0, 1.0, 0.05) var fire_proc := 0.1

@export_group("Greek Fire Trail")
## Burning patches left behind as you swim (one every fire_spacing m), each
## fire_radius round, lasting fire_life + fire_life_per_stack s and burning
## zombies in them for fire_dps + fire_dps_per_stack a second.
@export_range(0, 20, 1, "or_greater") var fire_stacks := 0
@export_range(0.2, 20.0, 0.1, "or_greater") var fire_spacing := 1.6
@export_range(0.2, 20.0, 0.1, "or_greater") var fire_radius := 1.6
@export_range(0.1, 30.0, 0.1, "or_greater") var fire_life := 2.0
@export_range(0.0, 30.0, 0.1, "or_greater") var fire_life_per_stack := 1.0
@export_range(0.0, 500.0, 1.0, "or_greater") var fire_dps := 12.0
@export_range(0.0, 500.0, 1.0, "or_greater") var fire_dps_per_stack := 8.0
## At most this many patches out per player.
@export_range(1, 500, 1, "or_greater") var fire_max_patches := 80

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
## Remoras stuck on the fish (remora_count, + per stack): each nips the
## nearest zombie within remora_range every remora_interval s for
## remora_damage (proc coefficient remora_proc).
@export_range(0, 20, 1, "or_greater") var remora_stacks := 0
@export_range(0, 20, 1, "or_greater") var remora_count := 1
@export_range(0, 10, 1, "or_greater") var remora_count_per_stack := 1
@export_range(0.05, 20.0, 0.05, "or_greater") var remora_interval := 1.5
@export_range(0.5, 60.0, 0.5, "or_greater") var remora_range := 7.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var remora_damage := 14.0
@export_range(0.0, 1.0, 0.05) var remora_proc := 0.5

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
## Jellies orbiting the fish (jelly_count, + per stack) halo_radius m out,
## halo_spin turns a second: each stings zombies it touches (jelly_radius)
## for jelly_damage every jelly_tick s, proc jelly_proc.
@export_range(0, 20, 1, "or_greater") var jelly_stacks := 0
@export_range(0, 20, 1, "or_greater") var jelly_count := 1
@export_range(0, 10, 1, "or_greater") var jelly_count_per_stack := 1
@export_range(0.5, 30.0, 0.1, "or_greater") var halo_radius := 3.2
@export_range(0.0, 5.0, 0.05, "or_greater") var halo_spin := 0.5
@export_range(0.1, 10.0, 0.05, "or_greater") var jelly_radius := 1.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var jelly_damage := 10.0
@export_range(0.05, 5.0, 0.05, "or_greater") var jelly_tick := 0.25
@export_range(0.0, 1.0, 0.05) var jelly_proc := 0.2

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
## A mine rack: a mine drops behind the fish every charge_interval s (times
## 1 - charge_interval_per_stack a stack). It arms after charge_arm s, then
## blows when a zombie comes within charge_trigger m (or after charge_life
## s): charge_damage (+ per stack) within charge_blast (+ per stack) m, proc
## charge_proc. At most charge_max mines out.
@export_range(0, 20, 1, "or_greater") var charge_stacks := 0
@export_range(0.1, 60.0, 0.1, "or_greater") var charge_interval := 4.0
@export_range(0.0, 0.9, 0.01) var charge_interval_per_stack := 0.1
@export_range(0.0, 10.0, 0.05, "or_greater") var charge_arm := 0.5
@export_range(0.2, 20.0, 0.1, "or_greater") var charge_trigger := 2.0
@export_range(0.5, 120.0, 0.5, "or_greater") var charge_life := 10.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var charge_damage := 120.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var charge_damage_per_stack := 60.0
@export_range(0.5, 40.0, 0.25, "or_greater") var charge_blast := 5.0
@export_range(0.0, 10.0, 0.25, "or_greater") var charge_blast_per_stack := 1.0
@export_range(1, 200, 1, "or_greater") var charge_max := 12
@export_range(0.0, 1.0, 0.05) var charge_proc := 0.5

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

@export_group("Drowned Fin (boss)")
## The Drowned Shark's: pressing boost with it ready charges, a dash at
## fin_dash_speed for fin_dash_time s (untouchable), every zombie it passes
## within fin_radius taking fin_damage (+ per stack) once, proc fin_proc. Then
## fin_cooldown s (times 1 - fin_cooldown_per_stack a stack).
@export_range(0, 20, 1, "or_greater") var fin_stacks := 0
@export_range(5.0, 200.0, 1.0, "or_greater") var fin_dash_speed := 45.0
@export_range(0.05, 3.0, 0.05, "or_greater") var fin_dash_time := 0.45
@export_range(0.5, 20.0, 0.25, "or_greater") var fin_radius := 3.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var fin_damage := 90.0
@export_range(0.0, 5000.0, 5.0, "or_greater") var fin_damage_per_stack := 45.0
@export_range(0.1, 60.0, 0.1, "or_greater") var fin_cooldown := 3.0
@export_range(0.0, 0.9, 0.01) var fin_cooldown_per_stack := 0.15
@export_range(0.0, 1.0, 0.05) var fin_proc := 1.0

@export_group("Leviathan's Coil (boss)")
## The Blood Leviathan's: coil_segments (+ per stack) glowing coils trail the
## fish coil_spacing m apart; every coil_tick s each hurts what it touches
## (coil_radius) for coil_damage, proc coil_proc.
@export_range(0, 20, 1, "or_greater") var coil_stacks := 0
@export_range(1, 100, 1, "or_greater") var coil_segments := 6
@export_range(0, 50, 1, "or_greater") var coil_segments_per_stack := 3
@export_range(0.2, 10.0, 0.1, "or_greater") var coil_spacing := 1.4
@export_range(0.1, 10.0, 0.05, "or_greater") var coil_radius := 0.9
@export_range(0.0, 1000.0, 1.0, "or_greater") var coil_damage := 16.0
@export_range(0.05, 5.0, 0.05, "or_greater") var coil_tick := 0.25
@export_range(0.0, 1.0, 0.05) var coil_proc := 0.3

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

## Powerup id -> its testing override's setting.
const STACKS := {
	"greek_fire": "fire_stacks",
	"chain_lightning": "lightning_stacks",
	"torpedo": "torpedo_stacks",
	"bow_grow_bow": "bow_stacks",
	"barnacle_plating": "barnacle_stacks",
	"hermit_shell": "hermit_stacks",
	"fizzy_soda": "soda_stacks",
	"speedy_seahorse": "seahorse_stacks",
	"remora_buddy": "remora_stacks",
	"bubble_wrap": "bubble_stacks",
	"pufferfish_spines": "spine_stacks",
	"jellyfish_halo": "jelly_stacks",
	"electric_eel": "eel_stacks",
	"depth_charges": "charge_stacks",
	"anglerfish_lure": "lure_stacks",
	"tsunami_heart": "tsunami_stacks",
	"drowned_fin": "fin_stacks",
	"leviathans_coil": "coil_stacks",
	"blood_moon_shard": "shard_stacks",
	"glass_coral": "coral_stacks",
	"sirens_song": "siren_stacks",
	"abyssal_hunger": "hunger_stacks",
	"sunken_idol": "idol_stacks",
}


## The testing override for powerup `id`'s stacks (0: none).
func stacks_override(id: String) -> int:
	return get(STACKS[id]) if STACKS.has(id) else 0
