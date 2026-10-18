class_name FishAttack
extends Node3D
## A fish's auto-attack in Unnatural (planning_unnatural.md §5): each fish
## fires its own on a cooldown, aimed for it. make() builds the one for a fish
## (FOR_FAMILY, or UnnaturalSettings.fish_attack for every fish).
##
## A subclass gives cooldown() and damage(), and fire() returns whether it went
## off (nothing in range: it waits, ready). _animate() runs every frame, firing
## or not. Every zombie it hurts goes through strike(), which hands it to
## on_hit (UnnaturalRun.hit) with the attack's source and proc coefficient.
##
## Melee attacks (the sting, the bite) must out-reach the bow wave
## (GhostBite.bow_reach) at its biggest: aiming in 3D water is hard, and
## otherwise ramming would do the same job (D8).

enum Kind { OWN, STING, BITE, LASH, THRUST, BUBBLES, SPINES }
## Each fish's own.
const FOR_FAMILY := {
	FishCharacter.Family.OCTANE: Kind.STING,
	FishCharacter.Family.DOMINUS: Kind.BITE,
	FishCharacter.Family.PLANK: Kind.LASH,
	FishCharacter.Family.BREAKOUT: Kind.THRUST,
	FishCharacter.Family.HYBRID: Kind.BUBBLES,
	FishCharacter.Family.MERC: Kind.SPINES,
}
## Kind -> [name, hit source].
const INFO := {
	Kind.STING: ["Anemone Sting", "sting"],
	Kind.BITE: ["Ghost Bite", "bite"],
	Kind.LASH: ["Shock Lash", "lash"],
	Kind.THRUST: ["Bill Thrust", "thrust"],
	Kind.BUBBLES: ["Bubble Volley", "bubbles"],
	Kind.SPINES: ["Spine Burst", "spines"],
}

var fish: FishController
var horde: Horde
var settings: UnnaturalSettings
## Called for each zombie hurt: (index, damage, by, source, push, proc).
var on_hit: Callable
## Which attack this is (Kind).
var kind := Kind.BITE
## The player's stats on it: attacks per second scale (attack speed), size
## scale (area), damage scale (the Damage stat applies in UnnaturalRun.hit(),
## not here), extra projectiles and the projectiles' speed scale.
var attack_speed := 1.0
var area_scale := 1.0
var damage_scale := 1.0
var extra_projectiles := 0
var projectile_speed := 1.0
## Its weapon facets on top (Weapons, set by UnnaturalRun._apply_stats): how
## hard it knocks zombies back, and the milestones it has reached (0 to 4).
var knock_scale := 1.0
var milestones := 0
var cooldown_left := 0.0
## Attacks made, and zombies hurt.
var uses := 0
var struck := 0


## The attack for `family`, or `override` (a Kind, not OWN) for every fish.
static func kind_for(family: FishCharacter.Family, override := Kind.OWN) -> Kind:
	if override != Kind.OWN and INFO.has(override):
		return override
	return FOR_FAMILY.get(family, Kind.BITE)


## A new attack of `attack_kind` (set fish, horde, settings and on_hit, then add it).
static func make(attack_kind: Kind) -> FishAttack:
	var attack: FishAttack
	match attack_kind:
		Kind.STING:
			attack = AnemoneSting.new()
		Kind.LASH:
			attack = ShockLash.new()
		Kind.THRUST:
			attack = BillThrust.new()
		Kind.BUBBLES:
			attack = BubbleVolley.new()
		Kind.SPINES:
			attack = SpineBurst.new()
		_:
			attack = GhostBite.new()
			attack_kind = Kind.BITE
	attack.kind = attack_kind
	return attack


static func title(attack_kind: Kind) -> String:
	return INFO[attack_kind][0] if INFO.has(attack_kind) else "?"


static func source_of(attack_kind: Kind) -> String:
	return INFO[attack_kind][1] if INFO.has(attack_kind) else "attack"


## Every attack's hit source.
static func sources() -> Array[String]:
	var all: Array[String] = []
	for k: Kind in INFO:
		all.append(INFO[k][1])
	return all


## This attack's hit source ("sting", "bite"...).
func source() -> String:
	return source_of(kind)


## Seconds between attacks, before attack speed.
func cooldown() -> float:
	return 1.0


## Damage per hit, before damage_scale and the player's stats.
func damage() -> float:
	return 0.0


## Its proc coefficient: how strongly its hits start powerups. Attacks that
## hit many at once have lower ones.
func proc() -> float:
	return 1.0


## Whether the player's stat `id` does anything for it (projectile stats are
## offered on cards only to fish whose attack uses them).
func uses_stat(_id: String) -> bool:
	return false


## Counts down and fires; `active` false holds it (down, picking a card).
func update(delta: float, active := true) -> void:
	_animate(delta)
	cooldown_left = maxf(cooldown_left - delta * attack_speed, 0.0)
	if not active or cooldown_left > 0.0 or busy() or fish.battered or damage() <= 0.0:
		return
	if fire():
		cooldown_left = cooldown()
		uses += 1


## Fires if there's something to fire at; returns whether it did.
func fire() -> bool:
	return false


## Still playing out the last one (it can't fire again yet).
func busy() -> bool:
	return false


func _animate(_delta: float) -> void:
	pass


## Hurts zombie `index` by `amount` (before damage_scale), pushed along `push`.
func strike(index: int, amount: float, push: Vector3, coefficient := -1.0) -> void:
	struck += 1
	on_hit.call(index, amount * damage_scale, fish, source(), push * knock_scale, proc() if coefficient < 0.0 else coefficient)


## The fish's hitbox middle (where reaches are measured from).
func origin() -> Vector3:
	return (fish.get_node("Collision") as Node3D).global_position


## The way the fish's nose points.
func nose() -> Vector3:
	return -fish.global_basis.z


## The way from `from` to zombie `index` (unit), or `fallback`.
func toward(from: Vector3, index: int, fallback: Vector3) -> Vector3:
	var offset := horde.enemy_position(index) - from
	return offset.normalized() if offset.length_squared() > 0.0001 else fallback


## A glowing, unshaded, additive material.
static func ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material
