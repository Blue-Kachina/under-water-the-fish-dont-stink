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

@export_group("Bow Grow Bow")
## Wearing the bow makes the bow wave bigger (its length and girth times 1 +
## bow_growth per stack), so you batter far wider. From bow_low_speed_stacks
## stacks on, the bow wave batters below the battering speed too (down to
## bow_low_speed of it).
@export_range(0, 20, 1, "or_greater") var bow_stacks := 0
@export_range(0.0, 5.0, 0.05, "or_greater") var bow_growth := 0.5
@export_range(1, 20, 1, "or_greater") var bow_low_speed_stacks := 3
@export_range(0.0, 1.0, 0.05) var bow_low_speed := 0.5


## The testing override for powerup `id`'s stacks (0: none).
func stacks_override(id: String) -> int:
	match id:
		"greek_fire":
			return fire_stacks
		"chain_lightning":
			return lightning_stacks
		"torpedo":
			return torpedo_stacks
		"bow_grow_bow":
			return bow_stacks
	return 0
