class_name RemoraBuddy
extends Powerup
## Remora Buddy (planning_unnatural.md §7b, D14), a weapon: remoras ride
## along under the fish (count(): remora_count, + the count facet). Each nips
## the nearest zombie within reach() every interval() s for damage() (proc
## coefficient remora_proc); they take turns, so the nips come evenly.
## Milestones: at the first, a nip latches on, biting LATCH_BITES more times
## (LATCH_SHARE of the damage); at the second, a remora's kill splits one off
## for SPLIT_TIME s (up to as many more as there are).

const LATCH_BITES := 3
const LATCH_GAP := 0.3
const LATCH_SHARE := 0.5
const SPLIT_TIME := 6.0

## Nips so far, for the probes.
var nips := 0
var _next := 0.0
## The first milestone's latched bites: [zombie, bites left, s to the next].
var _latched: Array = []
## The second's split-off remoras: when each goes (s left).
var _splits := PackedFloat32Array()


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
	PowerupFx.flash(run, to, 0.45, color(id), 0.18)
	run.hit(target, damage(), fish, id, (to - at).normalized(), settings.remora_proc, [id])
	if milestone(1) and run.horde.is_alive(target):
		_latched.append([target, LATCH_BITES, LATCH_GAP])


## The second milestone: a remora's kill splits one off for a while.
func on_kill(_at: Vector3, source: String) -> void:
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


## The remoras stuck under the belly, nose to tail.
func make_worn() -> Node3D:
	var school := Node3D.new()
	school.name = "Remoras"
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.5, 0.55, 0.62)
	skin.roughness = 0.6
	var n := mini(count(), 8)
	for k in n:
		var body := CapsuleMesh.new()
		body.radius = 0.05
		body.height = 0.3
		body.radial_segments = 8
		body.rings = 2
		var side := (k % 2) * 2.0 - 1.0 if n > 1 else 0.0
		var at := Vector3(side * fish.hitbox_width * 0.3, -fish.hitbox_height * 0.5, (k / 2) * 0.22 - 0.1)
		school.add_child(worn_mesh(body, skin, at, Vector3(PI / 2.0, 0.0, 0.0)))
	return school
