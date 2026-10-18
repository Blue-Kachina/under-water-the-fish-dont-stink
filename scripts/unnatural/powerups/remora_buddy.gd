class_name RemoraBuddy
extends Powerup
## Remora Buddy (planning_unnatural.md §7b, D14), a weapon: remoras ride
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

## Nips so far, for the probes.
var nips := 0
## Tears into the zombies round a nip (the third milestone), for the probes.
var tears := 0
var _next := 0.0
## The first milestone's latched bites: [zombie, bites left, s to the next].
var _latched: Array = []
## The second's split-off remoras: when each goes (s left).
var _splits := PackedFloat32Array()
var _heal_left := 0.0


func count() -> int:
	return settings.remora_count + facet_count("count") + _splits.size()


func damage() -> float:
	return settings.remora_damage * (1.0 + facet("damage"))


func interval() -> float:
	return settings.remora_interval / (1.0 + facet("rate"))


func reach() -> float:
	return settings.remora_range * (1.0 + facet("reach"))


func on_stacks_changed() -> void:
	take_off()  # worn again with the new number of remoras


func on_tick(delta: float) -> void:
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
	PowerupFx.flash(run, to, 0.8, color(id), 0.2)
	run.hit(target, damage(), fish, id, (to - at).normalized(), settings.remora_proc, [id])
	if milestone(3):
		for i in run.horde.query_sphere(to, TEAR_REACH):
			if i != target:
				tears += 1
				run.hit(i, damage() * TEAR_SHARE, fish, id, (run.horde.enemy_position(i) - to).normalized(), settings.remora_proc * TEAR_SHARE, [id])
	if milestone(1) and run.horde.is_alive(target):
		_latched.append([target, LATCH_BITES, LATCH_GAP])


## The second milestone: a remora's kill splits one off for a while.
func on_kill(_at: Vector3, source: String) -> void:
	if source == id and milestone(4) and _heal_left <= 0.0:
		var health := run.health_of(fish)
		if health and not health.down:
			_heal_left = HEAL_GAP
			health.heal(health.max_hp * HEAL_SHARE)
	if source == id and milestone(2) and _splits.size() < settings.remora_count + facet_count("count"):
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
		PowerupFx.flash(run, to, 0.3, color(id), 0.12)
		run.hit(target, damage() * LATCH_SHARE, fish, id, Vector3.ZERO, settings.remora_proc * LATCH_SHARE, [id])


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
