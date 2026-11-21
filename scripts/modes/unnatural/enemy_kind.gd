class_name EnemyKind
extends Resource
## One kind of zombie fish in Unnatural's Horde (planning_unnatural.md §3): a
## zombie version of one of our fish (its baked SchoolLook, tinted by the
## Horde's rot overlay), with its own hp, speed, contact damage, size and XP.
## defaults() is the whole roster (every class has a zombie, big_changes.md
## §8); each stage plays a rotation of some of them (rotation(), D10), and the
## EvilDirector mixes those in over time (unlock_minute, weight).

## Stored by index (and kinds by their place in defaults(), which goes over
## the network): add at the end, never reorder.
## SCHOOL: closes to a ring round its target, circles it, then darts in
## (Drowned Koi). DRIFT: slow, surging toward you a pulse at a time (Grave
## Jelly). PUNCH: stops short, winds up, and throws a punch that reaches a few
## metres (Rotten Mantis).
enum Behaviour { CHASE, SWARM, TANK, LUNGE, GLIDE, SCHOOL, DRIFT, PUNCH }

@export var id := ""
@export var display_name := ""
## Which fish's model it wears.
@export var fish_class := FishCharacter.FishClass.SKIRMISHER
## A model of its own instead (ZombieLooks: "sardine", "sea_butterfly"); empty
## to wear fish_class's.
@export var look := ""
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

@export_group("Quirks")
## Leaves short-lived patches of fire behind it (UnnaturalSettings cinder_*;
## the Cinder Lionfish).
@export var trail := false
## Dying, it leaves a cloud that slows players (zombie_haze_*; the Sour Sea Hare).
@export var death_cloud := false
## Dying, it spills this many rotten sardines (the Bloated Whale Calf).
@export_range(0, 50, 1, "or_greater") var death_spawn := 0
## Its touch stings and slows (jelly_sting_time; the Grave Jelly).
@export var contact_slow := false
## How far it rises and falls as it swims (m/s on its chase; the whale calf).
@export_range(0.0, 10.0, 0.05, "or_greater") var bob := 0.0
## Lungers: its wind-up and its lunge's speed, times the shared lunge_* ones
## (the Ghoul Shark: shorter and faster).
@export_range(0.1, 4.0, 0.05, "or_greater") var telegraph_scale := 1.0
@export_range(0.1, 4.0, 0.05, "or_greater") var lunge_scale := 1.0
## Whether a stage's rotation always has it (the sardines, so swarms and
## bursts always have them), and whether it can open a stage (an easy kind
## from minute 0: each rotation has one besides the sardines).
@export var always := false


## What its look is baked from (SchoolLook): its own model's id, or its class.
func look_key() -> Variant:
	return look if look != "" else fish_class


## Its hit radius (m): how near a player or an attack must come.
func radius() -> float:
	var box := FishCharacter.hitbox_size(fish_class)
	return maxf(box.z * 0.5, box.x * 0.5) * size * 0.8


## Unnatural's zombies (planning_unnatural.md §3, big_changes.md §8): one per
## class, plus the sardines (their own small model, ZombieLooks). The first is
## the sardines (bursts and Bloated elites spawn kind 0).
static func defaults() -> Array[EnemyKind]:
	var kinds: Array[EnemyKind] = []
	var sardine := make("sardine", "Rotten Sardine", FishCharacter.FishClass.SKIRMISHER, 0.55, 8.0, 7.0, 6.0, 1.0,
			Behaviour.SWARM, 0.0, 6.0, Color(0.42, 0.5, 0.42))
	sardine.look = "sardine"
	sardine.always = true
	kinds.append(sardine)
	kinds.append(make("clownfish", "Ghoul Clownfish", FishCharacter.FishClass.SKIRMISHER, 1.0, 22.0, 5.0, 10.0, 2.0,
			Behaviour.CHASE, 0.0, 3.0, Color(0.45, 0.42, 0.3)))
	kinds.append(make("boxfish", "Bloated Boxfish", FishCharacter.FishClass.BULWARK, 1.6, 90.0, 3.0, 18.0, 6.0,
			Behaviour.TANK, 2.0, 1.0, Color(0.4, 0.48, 0.25)))
	kinds.append(make("swordfish", "Lunging Swordfish", FishCharacter.FishClass.LANCER, 1.2, 45.0, 6.5, 16.0, 5.0,
			Behaviour.LUNGE, 4.0, 1.0, Color(0.3, 0.35, 0.42)))
	kinds.append(make("ray", "Grave Ray", FishCharacter.FishClass.GLIDER, 1.4, 55.0, 7.5, 14.0, 5.0,
			Behaviour.GLIDE, 6.0, 1.0, Color(0.32, 0.3, 0.38)))
	# Phase 6: the rest of the classes.
	kinds.append(make("koi", "Drowned Koi", FishCharacter.FishClass.CHARMER, 1.0, 28.0, 6.5, 10.0, 3.0,
			Behaviour.SCHOOL, 0.0, 2.5, Color(0.5, 0.42, 0.36)))
	var lionfish := make("lionfish", "Cinder Lionfish", FishCharacter.FishClass.SCORCHER, 1.0, 35.0, 5.5, 12.0, 4.0,
			Behaviour.CHASE, 3.0, 1.0, Color(0.5, 0.3, 0.22))
	lionfish.trail = true
	kinds.append(lionfish)
	var jelly := make("jelly", "Grave Jelly", FishCharacter.FishClass.DRIFTER, 1.1, 40.0, 3.5, 8.0, 3.0,
			Behaviour.DRIFT, 0.0, 2.0, Color(0.4, 0.46, 0.5))
	jelly.contact_slow = true
	kinds.append(jelly)
	kinds.append(make("mantis", "Rotten Mantis", FishCharacter.FishClass.BRAWLER, 1.0, 50.0, 5.5, 18.0, 5.0,
			Behaviour.PUNCH, 4.0, 1.0, Color(0.42, 0.44, 0.28)))
	var whale := make("whale", "Bloated Whale Calf", FishCharacter.FishClass.BREACHER, 1.5, 120.0, 2.8, 18.0, 8.0,
			Behaviour.TANK, 5.0, 0.8, Color(0.36, 0.42, 0.34))
	whale.bob = 1.2
	whale.death_spawn = 4
	kinds.append(whale)
	var sea_hare := make("sea_hare", "Sour Sea Hare", FishCharacter.FishClass.ALCHEMIST, 1.0, 40.0, 4.0, 10.0, 4.0,
			Behaviour.CHASE, 2.0, 1.0, Color(0.46, 0.36, 0.46))
	sea_hare.death_cloud = true
	kinds.append(sea_hare)
	var shark := make("shark", "Ghoul Shark", FishCharacter.FishClass.HUNTER, 1.2, 60.0, 7.5, 18.0, 6.0,
			Behaviour.LUNGE, 7.0, 0.8, Color(0.34, 0.38, 0.4))
	shark.telegraph_scale = 0.6
	shark.lunge_scale = 1.3
	kinds.append(shark)
	# Phase 7: the Fallen Angel's prey. Only it sheds them (weight 0: the
	# director never picks them, nor does a stage's rotation).
	var butterfly := make("butterfly", "Sea Butterfly", FishCharacter.FishClass.SKIRMISHER, 0.45, 6.0, 6.5, 4.0, 0.5,
			Behaviour.SWARM, 0.0, 0.0, Color(0.5, 0.42, 0.34))
	butterfly.look = "sea_butterfly"
	kinds.append(butterfly)
	return kinds


## Which of `kinds` a stage plays (D10: a rotation, to keep the draw calls
## down): every `always` kind, one that comes from minute 0 (so the stage
## opens with more than sardines), then the rest by chance up to `count`
## kinds, favouring those `before` (the last stage's) didn't have. count 0 or
## at least the roster: all of them. Returns a flag per kind (1: in it).
static func rotation(kinds: Array[EnemyKind], count: int, rng: RandomNumberGenerator, before := PackedByteArray()) -> PackedByteArray:
	var picked := PackedByteArray()
	picked.resize(kinds.size())
	if count <= 0 or count >= kinds.size():
		picked.fill(1)
		return picked
	picked.fill(0)
	var taken := 0
	for k in kinds.size():
		if kinds[k].always:
			picked[k] = 1
			taken += 1
	var openers: Array[int] = []
	for k in kinds.size():
		if picked[k] == 0 and kinds[k].unlock_minute <= 0.0 and kinds[k].weight > 0.0:
			openers.append(k)
	if not openers.is_empty() and taken < count:
		picked[openers[rng.randi_range(0, openers.size() - 1)]] = 1
		taken += 1
	while taken < count:
		var total := 0.0
		for k in kinds.size():
			if picked[k] == 0 and kinds[k].weight > 0.0:
				total += _rotation_weight(k, before)
		if total <= 0.0:
			break
		var roll := rng.randf() * total
		for k in kinds.size():
			if picked[k] == 1 or kinds[k].weight <= 0.0:
				continue
			roll -= _rotation_weight(k, before)
			if roll <= 0.0:
				picked[k] = 1
				taken += 1
				break
	return picked


static func _rotation_weight(k: int, before: PackedByteArray) -> float:
	return 0.35 if k < before.size() and before[k] == 1 else 1.0


static func make(kind_id: String, title: String, kind_class: FishCharacter.FishClass, kind_size: float, kind_hp: float,
		kind_speed: float, damage: float, kind_xp: float, kind_behaviour: Behaviour, unlock: float, kind_weight: float,
		kind_tint: Color) -> EnemyKind:
	var kind := EnemyKind.new()
	kind.id = kind_id
	kind.display_name = title
	kind.fish_class = kind_class
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
