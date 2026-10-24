class_name FishAttack
extends Node3D
## A fish's weapon in Unnatural (planning_unnatural.md §5): every weapon is
## one of these, the fish's own (FOR_CLASS, or UnnaturalSettings.fish_attack
## for every fish) and any second one alike (AttackWeapon holds those). make()
## builds one of a kind.
##
## Two sorts:
## - Fired ones (the sting, the bite...): a subclass gives cooldown() and
##   damage(), and fire() returns whether it went off (nothing in range: it
##   waits, ready).
## - Steady ones (the fire trail, the halo, the haze, the remoras, the coil):
##   they do their work in _work(delta), every tick they're active, on their
##   own timers. They read their own facets (facet()), so own_facets() is true.
## _animate() runs every frame, active or not. Every zombie it hurts goes
## through strike(), which hands it to on_hit (UnnaturalRun.hit) with the
## attack's source and proc coefficient.
##
## Melee attacks (the sting, the bite) must out-reach the bow wave
## (GhostBite.bow_reach) at its biggest: aiming in 3D water is hard, and
## otherwise ramming would do the same job (D8).

## The attack went off (fire() returned true).
signal fired

## HAZE took Depth Charges' place (CHARGES, retired in big_changes.md Phase 3): same index.
enum Kind { OWN, STING, BITE, LASH, THRUST, BUBBLES, SPINES, FIRE, HALO, HAZE, REMORA, COIL, PUNCH }
## Each fish's own.
const FOR_CLASS := {
	FishCharacter.FishClass.SKIRMISHER: Kind.STING,
	FishCharacter.FishClass.HUNTER: Kind.BITE,
	FishCharacter.FishClass.GLIDER: Kind.LASH,
	FishCharacter.FishClass.LANCER: Kind.THRUST,
	FishCharacter.FishClass.CHARMER: Kind.BUBBLES,
	FishCharacter.FishClass.BULWARK: Kind.SPINES,
	FishCharacter.FishClass.SCORCHER: Kind.FIRE,
	FishCharacter.FishClass.DRIFTER: Kind.HALO,
	FishCharacter.FishClass.BRAWLER: Kind.PUNCH,
	FishCharacter.FishClass.BREACHER: Kind.REMORA,
	FishCharacter.FishClass.ALCHEMIST: Kind.HAZE,
}
## Kind -> [name, hit source]. Held as a second weapon, its id is "attack_" +
## its source (Weapons.ATTACK_WEAPONS).
const INFO := {
	Kind.STING: ["Anemone Sting", "sting"],
	Kind.BITE: ["Ghost Bite", "bite"],
	Kind.LASH: ["Shock Lash", "lash"],
	Kind.THRUST: ["Bill Thrust", "thrust"],
	Kind.BUBBLES: ["Bubble Volley", "bubbles"],
	Kind.SPINES: ["Spine Burst", "spines"],
	Kind.FIRE: ["Greek Fire Trail", "greek_fire"],
	Kind.HALO: ["Jellyfish Halo", "jellyfish_halo"],
	Kind.HAZE: ["Purple Haze", "purple_haze"],
	Kind.REMORA: ["Remora Buddy", "remora_buddy"],
	Kind.COIL: ["Leviathan's Coil", "leviathans_coil"],
	Kind.PUNCH: ["Cavitation Punch", "punch"],
}

var fish: FishController
var horde: Horde
var settings: UnnaturalSettings
## The run it fights in (the steady weapons drop things into it, heal, and roll).
var run: UnnaturalRun
## The weapon numbers (PowerupSettings: the steady weapons' fire_*, jelly_*...).
var powers := PowerupSettings.shared()
## Called for each zombie hurt: (index, damage, by, source, push, proc).
var on_hit: Callable
## Which attack this is (Kind).
var kind := Kind.BITE
## The player's stats on it: attacks per second scale (attack speed), size
## scale (Size), damage scale (the Damage stat applies in UnnaturalRun.hit(),
## not here), extra projectiles, the projectiles' speed scale and how much
## longer timed things last (Duration).
var attack_speed := 1.0
var size_scale := 1.0
var damage_scale := 1.0
var extra_projectiles := 0
var projectile_speed := 1.0
var duration_scale := 1.0
## Its weapon facets on top (Weapons, set by configure()): how hard it knocks
## zombies back, and the milestones it has reached (0 to 4) at its level.
var knock_scale := 1.0
var milestones := 0
var level := 0
## Its facets' totals (facet id -> amount), for the steady weapons to read.
var facets := {}
var cooldown_left := 0.0
## Attacks made, and zombies hurt.
var uses := 0
var struck := 0
## Its look on the fish (make_worn()), while it's out.
var _worn: Node3D


## The attack for `fish_class`, or `override` (a Kind, not OWN) for every fish.
static func kind_for(fish_class: FishCharacter.FishClass, override := Kind.OWN) -> Kind:
	if override != Kind.OWN and INFO.has(override):
		return override
	return FOR_CLASS.get(fish_class, Kind.BITE)


## A new attack of `attack_kind` (set fish, horde, settings, run and on_hit, then add it).
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
		Kind.FIRE:
			attack = GreekFire.new()
		Kind.HALO:
			attack = JellyfishHalo.new()
		Kind.HAZE:
			attack = PurpleHaze.new()
		Kind.REMORA:
			attack = RemoraBuddy.new()
		Kind.COIL:
			attack = LeviathansCoil.new()
		Kind.PUNCH:
			attack = CavitationPunch.new()
		_:
			attack = GhostBite.new()
			attack_kind = Kind.BITE
	attack.kind = attack_kind
	return attack


static func title(attack_kind: Kind) -> String:
	return INFO[attack_kind][0] if INFO.has(attack_kind) else "?"


static func source_of(attack_kind: Kind) -> String:
	return INFO[attack_kind][1] if INFO.has(attack_kind) else "attack"


## Its id held as a second weapon ("attack_sting", "attack_greek_fire"...).
static func weapon_id_of(attack_kind: Kind) -> String:
	return "attack_" + source_of(attack_kind)


## Every attack's hit source.
static func sources() -> Array[String]:
	var all: Array[String] = []
	for k: Kind in INFO:
		all.append(INFO[k][1])
	return all


## This attack's hit source ("sting", "bite", "greek_fire"...).
func source() -> String:
	return source_of(kind)


## Its colour (the weapon's, Powerup.INFO).
func tint() -> Color:
	return Powerup.color(weapon_id_of(kind))


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


## Whether it reads its own facets (the steady weapons) rather than having
## the shared ones (rate, size, damage, knock, count, speed) put on its scales.
func own_facets() -> bool:
	return false


## Whether its uses count as attacks (Poseidon's Trident counts them). The
## steady weapons have none: the Trident strikes on its own timer for them.
func counts_uses() -> bool:
	return true


## Whether the player's stat `id` does anything for it (Quantity and
## Projectile Speed are offered on cards only to fish whose attack uses them).
func uses_stat(id: String) -> bool:
	return kind_uses_stat(kind, id)


## Whether an attack of `attack_kind` uses the player's stat `id` (Quantity,
## Projectile Speed).
static func kind_uses_stat(attack_kind: Kind, id: String) -> bool:
	match attack_kind:
		Kind.THRUST, Kind.BUBBLES, Kind.SPINES:
			return id == "quantity" or id == "projectile_speed"
		Kind.LASH, Kind.HAZE, Kind.PUNCH, Kind.HALO:
			return id == "quantity"
	return false


## The player's stats (`block`), this weapon's facets (`held`: facet id ->
## total) and its level on it: UnnaturalRun does it for the fish's own, an
## AttackWeapon for a second.
func configure(block: StatBlock, held: Dictionary, at_level: int) -> void:
	facets = held
	var rate := maxf(1.0 + block.value("attack_speed"), 0.1)
	var bigger := maxf(1.0 + block.value("size"), 0.1)
	duration_scale = 1.0 + block.value("duration")
	if own_facets():
		attack_speed = rate
		size_scale = bigger
		damage_scale = 1.0
		knock_scale = 1.0
		extra_projectiles = floori(block.value("quantity") + 0.0001)  # D8: Quantity may be fractional; spawn the floor
		projectile_speed = 1.0 + block.value("projectile_speed")
	else:
		attack_speed = rate * (1.0 + facet("rate"))
		size_scale = bigger * (1.0 + facet("size"))
		damage_scale = 1.0 + facet("damage")
		knock_scale = 1.0 + facet("knock")
		extra_projectiles = floori(block.value("quantity") + 0.0001) + facet_count("count")
		projectile_speed = (1.0 + block.value("projectile_speed")) * (1.0 + facet("speed"))
	milestones = settings.milestones_at(at_level) if settings else 0
	if at_level != level:
		level = at_level
		_level_changed()
		wear()


## Its level went up or down (or a testing override changed it).
func _level_changed() -> void:
	pass


## Facet `facet_id`'s total (0: none).
func facet(facet_id: String) -> float:
	return float(facets.get(facet_id, 0.0))


## A whole-number facet (a count).
func facet_count(facet_id: String) -> int:
	return roundi(facet(facet_id))


## Whether it has reached milestone `n` (1 to 4: Lv milestone_first to milestone_fourth).
func milestone(n: int) -> bool:
	if settings == null or n <= 0:
		return false
	var at := settings.milestone_level(n)
	return at > 0 and level >= at


## Counts down and fires; `active` false holds it (down, picking a card, quiet).
func update(delta: float, active := true) -> void:
	_animate(delta)
	if active:
		_work(delta)
	cooldown_left = maxf(cooldown_left - delta * attack_speed, 0.0)
	if not active or cooldown_left > 0.0 or busy() or fish.battered or damage() <= 0.0:
		return
	if fire():
		cooldown_left = cooldown()
		if settings and settings.limits:
			cooldown_left = maxf(cooldown_left, settings.min_cooldown * attack_speed)  # P4: the floor, in real seconds
		uses += 1
		fired.emit()


## Fires if there's something to fire at; returns whether it did.
func fire() -> bool:
	return false


## The zombie it would aim at if it fired now (-1: none, or it doesn't aim:
## the area and steady weapons). The HUD's target marker shows it.
func aim_target() -> int:
	return -1


## A steady weapon's tick while it's active.
func _work(_delta: float) -> void:
	pass


## Still playing out the last one (it can't fire again yet).
func busy() -> bool:
	return false


func _animate(_delta: float) -> void:
	pass


## A zombie died to one of `fish`'s hits from `source` (a kill of its own if
## it's this attack's source).
func on_kill(_at: Vector3, _source: String) -> void:
	pass


## Going away: clears what it put in the world (patches, mines, jellies...).
func on_removed() -> void:
	pass


func _exit_tree() -> void:
	on_removed()
	take_off()


## Hurts zombie `index` by `amount` (before damage_scale), pushed along `push`.
func strike(index: int, amount: float, push: Vector3, coefficient := -1.0) -> void:
	struck += 1
	on_hit.call(index, amount * damage_scale, fish, source(), push * knock_scale, proc() if coefficient < 0.0 else coefficient)


## Hurts every zombie in `targets` by `amount` (before damage_scale) at once (an
## area: a blast, a tick of fire, a swing), as UnnaturalRun.hit_area(): pushed
## along `pushes` (one each), or away from `centre` (Vector3.INF: not pushed).
## Hands each to on_hit if that isn't the run's own hit().
func strike_area(targets: PackedInt32Array, amount: float, centre := Vector3.INF, coefficient := -1.0, pushes := PackedVector3Array()) -> void:
	if targets.is_empty():
		return
	var proc_now := proc() if coefficient < 0.0 else coefficient
	if run == null or on_hit.get_object() != run or on_hit.get_method() != &"hit":
		for n in targets.size():
			var push := pushes[n] if n < pushes.size() else (toward(centre, targets[n], Vector3.UP) if centre != Vector3.INF else Vector3.ZERO)
			strike(targets[n], amount, push, proc_now)
		return
	struck += targets.size()
	var scaled := PackedVector3Array()
	for push in pushes:
		scaled.append(push * knock_scale)
	run.hit_area(targets, amount * damage_scale, fish, source(), centre, knock_scale, proc_now, [], scaled)


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


## Its look on the fish, built fresh (null: none), grown a little each level.
func make_worn() -> Node3D:
	return null


## Puts its look on the fish (once), sized by its level.
func wear() -> void:
	if not is_instance_valid(fish):
		return
	if _worn == null or not is_instance_valid(_worn):
		_worn = make_worn()
		if _worn == null:
			return
		fish.add_child(_worn)
	_worn.scale = Vector3.ONE * minf(1.0 + 0.15 * (level - 1), 2.0)


## Takes its look off the fish.
func take_off() -> void:
	if _worn and is_instance_valid(_worn):
		if _worn.get_parent():
			_worn.get_parent().remove_child(_worn)  # off now, not at the frame's end
		_worn.queue_free()
	_worn = null


## A glowing material in this weapon's colour, for its look.
func worn_material(glow := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint()
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = tint()
	material.emission_energy_multiplier = glow
	return material


static func worn_mesh(mesh: Mesh, material: Material, at: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	return Powerup.worn_mesh(mesh, material, at, turn)
