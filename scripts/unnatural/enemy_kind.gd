class_name EnemyKind
extends Resource
## One kind of zombie fish in Unnatural's Horde (planning_unnatural.md §3): a
## zombie version of one of our fish (its baked SchoolLook, tinted by the
## Horde's rot overlay), with its own hp, speed, contact damage, size and XP.
## defaults() is the stage's line-up; the EvilDirector mixes them in over time
## (unlock_minute, weight).

enum Behaviour { CHASE, SWARM, TANK, LUNGE, GLIDE }

@export var id := ""
@export var display_name := ""
## Which fish's model it wears.
@export var family := FishCharacter.Family.OCTANE
## Its size against that fish.
@export_range(0.1, 10.0, 0.05, "or_greater") var size := 1.0
@export_range(1.0, 100000.0, 1.0, "or_greater") var hp := 20.0
## Cruising speed of its chase (m/s), and how quickly it changes velocity (m/s²).
@export_range(0.0, 60.0, 0.5, "or_greater") var speed := 5.0
@export_range(0.0, 200.0, 1.0, "or_greater") var accel := 12.0
## Damage on touching a player.
@export_range(0.0, 1000.0, 1.0, "or_greater") var contact_damage := 10.0
## XP its pearl is worth.
@export_range(0.0, 1000.0, 1.0, "or_greater") var xp := 1.0
@export var behaviour := Behaviour.CHASE
## The director mixes it in from this minute of the run, at this weight.
@export_range(0.0, 60.0, 0.25, "or_greater") var unlock_minute := 0.0
@export_range(0.0, 100.0, 0.5, "or_greater") var weight := 1.0
## Its rot's tint (the Horde's overlay).
@export var tint := Color(0.35, 0.45, 0.3)


## Its hit radius (m): how near a player or an attack must come.
func radius() -> float:
	var box := FishCharacter.hitbox_size(family)
	return maxf(box.z * 0.5, box.x * 0.5) * size * 0.8


## Unnatural's zombies (§3). Rotten sardines are small clownfish shapes for now
## (there's no sardine model yet).
static func defaults() -> Array[EnemyKind]:
	var kinds: Array[EnemyKind] = []
	kinds.append(make("sardine", "Rotten Sardine", FishCharacter.Family.OCTANE, 0.55, 8.0, 7.0, 6.0, 1.0,
			Behaviour.SWARM, 0.0, 6.0, Color(0.42, 0.5, 0.42)))
	kinds.append(make("clownfish", "Ghoul Clownfish", FishCharacter.Family.OCTANE, 1.0, 22.0, 5.0, 10.0, 2.0,
			Behaviour.CHASE, 0.0, 3.0, Color(0.45, 0.42, 0.3)))
	kinds.append(make("boxfish", "Bloated Boxfish", FishCharacter.Family.MERC, 1.6, 90.0, 3.0, 18.0, 6.0,
			Behaviour.TANK, 2.0, 1.0, Color(0.4, 0.48, 0.25)))
	kinds.append(make("swordfish", "Lunging Swordfish", FishCharacter.Family.BREAKOUT, 1.2, 45.0, 6.5, 16.0, 5.0,
			Behaviour.LUNGE, 4.0, 1.0, Color(0.3, 0.35, 0.42)))
	kinds.append(make("ray", "Grave Ray", FishCharacter.Family.PLANK, 1.4, 55.0, 7.5, 14.0, 5.0,
			Behaviour.GLIDE, 6.0, 1.0, Color(0.32, 0.3, 0.38)))
	return kinds


static func make(kind_id: String, title: String, kind_family: FishCharacter.Family, kind_size: float, kind_hp: float,
		kind_speed: float, damage: float, kind_xp: float, kind_behaviour: Behaviour, unlock: float, kind_weight: float,
		kind_tint: Color) -> EnemyKind:
	var kind := EnemyKind.new()
	kind.id = kind_id
	kind.display_name = title
	kind.family = kind_family
	kind.size = kind_size
	kind.hp = kind_hp
	kind.speed = kind_speed
	kind.accel = kind_speed * 2.5
	kind.contact_damage = damage
	kind.xp = kind_xp
	kind.behaviour = kind_behaviour
	kind.unlock_minute = unlock
	kind.weight = kind_weight
	kind.tint = kind_tint
	return kind
