class_name HagfishBrood
extends Powerup
## Hagfish Brood (planning_bosses_and_survival.md §2, boss item: the Whale
## Fall's). count() hagfish ride round the fish on tethers. Each, every
## brood_every s (sooner with attack speed), lunges at a zombie within
## brood_reach m (the nearest no other hagfish has), bites it for damage()
## and knots onto it, holding it still for brood_hold s; then it lets go,
## leaving it slimed (brood_slow of its speed gone for brood_slow_time s),
## and swims back. A boss is only bitten (not held or slowed).

enum Phase { IDLE, LUNGE, KNOT, BACK }
## How far behind and round the fish they ride (in its hitbox lengths).
const RIDE := 0.7
const SLIME := Color(0.6, 0.8, 0.45)

## Bites, holds (knots) and slimings so far, for the probes.
var bites := 0
var knots := 0
var slimed := 0
## Each hagfish: {"phase", "target", "left" (s), "cool" (s), "from", "body", "line"}.
var _brood: Array[Dictionary] = []


func count() -> int:
	return maxi(settings.brood_count + roundi(settings.brood_count_per_stack * extra()), 0)


func damage() -> float:
	return settings.brood_damage + settings.brood_damage_per_stack * extra()


## Where hagfish `n` of `of` rides when it's not hunting.
func home(n: int, of: int) -> Vector3:
	var basis := fish.global_basis
	var angle := TAU * (n + 0.5) / maxf(of, 1)
	var round_off := (basis.x * cos(angle) + basis.y * sin(angle)) * fish.hitbox_width * 0.9
	return fish.global_position + basis.z * fish.hitbox_length * RIDE + round_off


## The zombies held by a hagfish now (indices), for the probes.
func held() -> PackedInt32Array:
	var holding := PackedInt32Array()
	for one in _brood:
		if one.phase == Phase.KNOT:
			holding.append(one.target)
	return holding


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish):
		return
	_fit(count())
	var horde := run.horde
	for n in _brood.size():
		var one := _brood[n]
		var rest := home(n, _brood.size())
		var at := rest
		match one.phase:
			Phase.IDLE:
				one.cool -= delta
				if one.cool <= 0.0:
					var target := _find(rest)
					if target >= 0:
						one.phase = Phase.LUNGE
						one.target = target
						one.left = settings.brood_lunge_time
						one.from = rest
					else:
						one.cool = 0.25  # nothing in reach: look again soon
			Phase.LUNGE:
				one.left -= delta
				if not horde.is_alive(one.target):
					_back(one, rest)
				else:
					var share := 1.0 - clampf(one.left / settings.brood_lunge_time, 0.0, 1.0)
					at = (one.from as Vector3).lerp(horde.enemy_position(one.target), share * share)
					if one.left <= 0.0:
						_bite(one)
			Phase.KNOT:
				one.left -= delta
				if not horde.is_alive(one.target):
					_back(one, rest)
				else:
					at = horde.enemy_position(one.target)
					if one.left <= 0.0:
						_let_go(one)
						_back(one, at)
			Phase.BACK:
				one.left -= delta
				var share := 1.0 - clampf(one.left / settings.brood_back_time, 0.0, 1.0)
				at = (one.from as Vector3).lerp(rest, share)
				if one.left <= 0.0:
					one.phase = Phase.IDLE
					one.cool = settings.brood_every / rate_scale()
		_draw(one, at, rest)


## Bites its target and knots onto it.
func _bite(one: Dictionary) -> void:
	var target: int = one.target
	var horde := run.horde
	run.hit(target, damage(), fish, id, Vector3.ZERO, settings.brood_proc, [id])
	bites += 1
	Sfx.play_at("pw/brood_bite", horde.enemy_position(target))
	if not horde.is_alive(target):
		_back(one, horde.enemy_position(target))
		return
	one.phase = Phase.KNOT
	one.left = settings.brood_hold * duration_scale()
	if not horde.is_proxy(target):
		horde.slow(target, 1.0, one.left)
		knots += 1


## Lets go of its target: slimed, slowed.
func _let_go(one: Dictionary) -> void:
	var target: int = one.target
	var horde := run.horde
	if horde.is_alive(target) and not horde.is_proxy(target):
		horde.slow(target, settings.brood_slow, settings.brood_slow_time * duration_scale())
		slimed += 1
		PowerupFx.pop(run, horde.enemy_position(target), horde.enemy_radius(target) * 1.4, SLIME, 0.35)


func _back(one: Dictionary, from: Vector3) -> void:
	one.phase = Phase.BACK
	one.target = -1
	one.left = settings.brood_back_time
	one.from = from


## The nearest zombie within brood_reach of `from` no other hagfish is after.
func _find(from: Vector3) -> int:
	var taken := {}
	for other in _brood:
		if other.target >= 0:
			taken[other.target] = true
	var horde := run.horde
	var best := -1
	var best_gap := INF
	for i in horde.query_sphere(fish.global_position, settings.brood_reach):
		if taken.has(i):
			continue
		var gap := horde.enemy_position(i).distance_squared_to(from)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## As many hagfish as `wanted` (more come at the fish; spare ones go).
func _fit(wanted: int) -> void:
	while _brood.size() > wanted:
		var gone: Dictionary = _brood.pop_back()
		(gone.body as Node).queue_free()
		(gone.line as Node).queue_free()
	while _brood.size() < wanted:
		var body := BossItemFx.creature(run, 0.55, 0.09, color(id))
		body.name = "Hagfish"
		var line := BossItemFx.tether(run, color(id).lightened(0.3), 0.03)
		_brood.append({"phase": Phase.IDLE, "target": -1, "left": 0.0, "cool": 0.3 * _brood.size(), "from": fish.global_position,
				"body": body, "line": line})


func _draw(one: Dictionary, at: Vector3, rest: Vector3) -> void:
	var body: MeshInstance3D = one.body
	var facing := at - rest if at.distance_squared_to(rest) > 0.01 else -fish.global_basis.z
	var wriggle := sin(Time.get_ticks_msec() / 1000.0 * (18.0 if one.phase == Phase.KNOT else 6.0)) * 0.4
	BossItemFx.place(body, at, facing, wriggle)
	BossItemFx.stretch(one.line as MeshInstance3D, fish.global_position + fish.global_basis.z * fish.hitbox_length * 0.3, at)


func on_removed() -> void:
	_fit(0)


## A knot of slime on the tail, where the tethers are tied.
func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "WornBrood"
	look.position = Vector3(0.0, 0.0, fish.hitbox_length * 0.3)
	look.add_child(worn_mesh(WornKit.ring(fish.hitbox_width * 0.3, 0.05), worn_material(0.5), Vector3.ZERO))
	return look
