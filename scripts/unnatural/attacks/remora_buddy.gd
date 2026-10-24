class_name RemoraBuddy
extends FishAttack
## Remora Buddy (planning_unnatural.md §7b, D14), a steady weapon (FishAttack),
## the Baby Whale Shark's own: remoras ride
## along under the fish (count(): remora_count, + the count facet). Each nips
## the nearest zombie within reach() every interval() s for damage() (proc
## coefficient remora_proc); they take turns, so the nips come evenly.
## Milestones: at the first, a nip latches on, biting LATCH_BITES more times
## (LATCH_SHARE of the damage); at the second, a remora's kill splits one off
## for SPLIT_TIME s (up to as many more as there are); at the third, each nip
## tears into every other zombie within TEAR_REACH for TEAR_SHARE of it; at
## the fourth, a remora's kill heals its fish HEAL_SHARE of its max hp (at
## most once every HEAL_GAP s).

const LATCH_BITES := 3
const LATCH_GAP := 0.3
const LATCH_SHARE := 0.5
const SPLIT_TIME := 6.0
const TEAR_REACH := 2.5
const TEAR_SHARE := 0.5
const HEAL_SHARE := 0.01
const HEAL_GAP := 0.25

## How long a remora takes to dart out to its zombie, and to swim back (s).
const LUNGE_TIME := 0.09
const RETURN_TIME := 0.25

## Nips so far, for the probes.
var nips := 0
## Remoras sent darting out (the nips you can see), for the probes.
var lunges := 0
## Tears into the zombies round a nip (the third milestone), for the probes.
var tears := 0
var _next := 0.0
## The first milestone's latched bites: [zombie, bites left, s to the next].
var _latched: Array = []
## The second's split-off remoras: when each goes (s left).
var _splits := PackedFloat32Array()
var _heal_left := 0.0


## It reads its own facets, and has no attacks to count (FishAttack).
func own_facets() -> bool:
	return true


func counts_uses() -> bool:
	return false


func count() -> int:
	return powers.remora_count + facet_count("count") + _splits.size()


func damage() -> float:
	return powers.remora_damage * (1.0 + facet("damage"))


func interval() -> float:
	return powers.remora_interval / (1.0 + facet("rate")) / attack_speed


func reach() -> float:
	return powers.remora_range * (1.0 + facet("reach")) * size_scale


func _level_changed() -> void:
	take_off()  # worn again with the new number of remoras


func _work(delta: float) -> void:
	_heal_left -= delta
	_tick_splits(delta)
	_tick_latched(delta)
	var n := count()
	if n <= 0:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next += interval() / n
	_next = maxf(_next, 0.0)
	var at := fish.global_position
	var target := run.horde.nearest_in_cone(at, Vector3.FORWARD, reach(), -1.0)
	if target < 0:
		_next = 0.1  # nothing near: look again shortly
		return
	nips += 1
	var to := run.horde.enemy_position(target)
	_lunge(nips, to)
	PowerupFx.flash(run, to, 0.8, tint(), 0.2)
	strike(target, damage(), (to - at).normalized(), powers.remora_proc)
	if milestone(3):
		for i in run.horde.query_sphere(to, TEAR_REACH):
			if i != target:
				tears += 1
				strike(i, damage() * TEAR_SHARE, (run.horde.enemy_position(i) - to).normalized(), powers.remora_proc * TEAR_SHARE)
	if milestone(1) and run.horde.is_alive(target):
		_latched.append([target, LATCH_BITES, LATCH_GAP])


## A worn remora (the `turn`th nip's, in turn) darts off its flank to the zombie
## at `to`, then swims back: what you see of a nip. (The damage itself lands at
## once, so the timing stays the same wherever the zombie is.)
func _lunge(turn: int, to: Vector3) -> void:
	if _worn == null or not is_instance_valid(_worn) or _worn.get_child_count() == 0:
		return
	var home := _worn.get_child(turn % _worn.get_child_count()) as MeshInstance3D
	if home == null or not home.visible or not home.is_inside_tree():
		return  # already out
	var from := home.global_position
	var direction := (to - from).normalized() if to.distance_to(from) > 0.01 else Vector3.FORWARD
	var dart := MeshInstance3D.new()
	dart.mesh = home.mesh
	dart.material_override = home.material_override
	dart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	run.add_child(dart)
	var up := Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT
	dart.global_transform = Transform3D(Basis.looking_at(direction, up) * Basis(Vector3.RIGHT, PI / 2.0), from)
	dart.scale = home.global_transform.basis.get_scale()
	home.visible = false
	lunges += 1
	# The worn remoras are rebuilt when a split one comes or goes: hold its
	# home weakly, so a dart out when that happens just doesn't swim back.
	var home_ref: WeakRef = weakref(home)
	var tween := dart.create_tween()
	tween.tween_property(dart, "global_position", to, LUNGE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(t: float) -> void:
		var back := home_ref.get_ref() as Node3D
		if back and back.is_inside_tree():
			dart.global_position = to.lerp(back.global_position, t), 0.0, 1.0, RETURN_TIME)
	tween.tween_callback(func() -> void:
		var back := home_ref.get_ref() as Node3D
		if back:
			back.visible = true
		dart.queue_free())


## The second milestone: a remora's kill splits one off for a while.
func on_kill(_at: Vector3, source: String) -> void:
	if source == source() and milestone(4) and _heal_left <= 0.0:
		var health := run.health_of(fish)
		if health and not health.down:
			_heal_left = HEAL_GAP
			health.heal(health.max_hp * HEAL_SHARE)
	if source == source() and milestone(2) and _splits.size() < powers.remora_count + facet_count("count"):
		_splits.append(SPLIT_TIME)
		wear()


func _tick_splits(delta: float) -> void:
	var gone := false
	for k in range(_splits.size() - 1, -1, -1):
		_splits[k] -= delta
		if _splits[k] <= 0.0:
			_splits.remove_at(k)
			gone = true
	if gone:
		wear()


func _tick_latched(delta: float) -> void:
	for k in range(_latched.size() - 1, -1, -1):
		var latch: Array = _latched[k]
		latch[2] -= delta
		if latch[2] > 0.0:
			continue
		var target: int = latch[0]
		if not run.horde.is_alive(target) or latch[1] <= 0:
			_latched.remove_at(k)
			continue
		latch[1] -= 1
		latch[2] = LATCH_GAP
		nips += 1
		var to := run.horde.enemy_position(target)
		PowerupFx.flash(run, to, 0.3, tint(), 0.12)
		strike(target, damage() * LATCH_SHARE, Vector3.ZERO, powers.remora_proc * LATCH_SHARE)


func on_removed() -> void:
	_latched.clear()
	_splits.clear()


func wear() -> void:
	super.wear()
	if _worn == null or not is_instance_valid(_worn):
		return
	if _worn.get_child_count() != mini(count(), 8):
		take_off()
		super.wear()


## The remoras stuck low on the flanks, nose to tail, where the follow cam
## (behind and above) can see them past the body: pale, with a faint glow in
## the powerup's colour so they read in the murk.
func make_worn() -> Node3D:
	var school := Node3D.new()
	school.name = "Remoras"
	var skin := worn_material(0.35)
	skin.albedo_color = Color(0.78, 0.82, 0.9)
	var n := mini(count(), 8)
	for k in n:
		var body := CapsuleMesh.new()
		body.radius = 0.09
		body.height = 0.55
		body.radial_segments = 8
		body.rings = 2
		var side := (k % 2) * 2.0 - 1.0 if n > 1 else 1.0
		var at := Vector3(side * fish.hitbox_width * 0.5, -fish.hitbox_height * 0.3, (k / 2) * 0.4 - 0.15)
		school.add_child(worn_mesh(body, skin, at, Vector3(PI / 2.0, 0.0, 0.0)))
	return school
