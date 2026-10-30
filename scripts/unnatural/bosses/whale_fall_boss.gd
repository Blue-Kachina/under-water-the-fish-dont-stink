class_name WhaleFallBoss
extends BloodLeviathan
## The Whale Fall, an alternate final boss: a dead blue whale on its side,
## lifted off the seabed by the hagfish_count giant hagfish that have eaten it
## hollow and now wear it. The carcass drifts slowly after its prey; the
## hagfish come out of its eye sockets, its torn chest, a flank wound and its
## blowhole, each a rope of hagfish_length m bent along a spine (SpineRig):
## - each lunges at a player within reach of where it comes out every
##   hagfish_lunge_every s, glowing as it winds up;
## - a striking hagfish that reaches a player bites and holds on
##   (hagfish_grabs), reeling them in toward its hole as it ties itself in a
##   knot that slides down its body to its head, as real hagfish do to tear
##   flesh; it slimes them when it lets go;
## - spitting (from two thirds), they spray slime that stings and slows;
## - in fury they tear free and hunt on their own, and the carcass sinks.
## The hagfish hold hagfish_share of its hp between them, each its own share:
## at none it goes limp and sinks away. Until they're all dead the carcass
## takes only carcass_armour of the damage.

const WHALE_SKIN := preload("res://shaders/boss_whale.gdshader")
const HAG_SKIN := preload("res://shaders/boss_hagfish.gdshader")
const CARCASS_PROXIES := 7
const HAG_PROXIES := 3
## How many points make a hagfish's rope, and the carcass's roll onto its side (rad).
const ROPE := 20
const ROLL := 1.75
## A hagfish's lunge: its wind-up, how long it strikes (s) and how fast (m/s).
const WIND := 0.7
const STRIKE := 1.1
const STRIKE_SPEED := 34.0

var hagfish: Array[Hagfish] = []
var _carcass: MeshInstance3D
var _carcass_skin: ShaderMaterial
## The carcass's rest shape into the boss's own space (rolled, centred).
var _carcass_xf := Transform3D.IDENTITY
## Where each hagfish comes out: [rest point, rest outward direction].
var _exits: Array = []
var _carcass_points := PackedVector3Array()
## The hagfish holding a player (null: none), and how many have bitten one.
var _grabber: Hagfish
var bites := 0


## One of its hagfish.
class Hagfish:
	var index := 0
	var rig: SpineRig
	var skin: ShaderMaterial
	var mesh: MeshInstance3D
	var nodes := PackedVector3Array()
	var head := Vector3.ZERO
	var velocity := Vector3.ZERO
	var hp := 1.0
	var alive := true
	var loose := false
	## 0 idle, 1 winding up, 2 striking, 3 drawing back, 4 holding a player.
	var state := 0
	var state_left := 0.0
	var lunge_left := 2.0
	var slime_left := 3.0
	var aim := Vector3.ZERO
	var dead_for := 0.0
	var parts := PackedInt32Array()
	var phase := 0.0
	## Its knot: how far it has slid from its tail to its head (0 to 1),
	## and how tied it is (0 none to 1 a whole loop).
	var knot := 0.0
	var knot_size := 0.0


func boss_title() -> String:
	return "THE WHALE FALL"


func boss_line() -> String:
	return "THE HAGFISH WEAR IT NOW"


func net_kind() -> String:
	return "whale"


## The carcass's length (m).
func body_length() -> float:
	return settings.leviathan_girth * 7.5


func proxy_count() -> int:
	return CARCASS_PROXIES + settings.hagfish_count * HAG_PROXIES


func proxy_distance(_n: int) -> float:
	return 0.0


func proxy_radius(n: int) -> float:
	var k := settings.leviathan_girth / 6.0
	if n < CARCASS_PROXIES:
		var a := lerpf(0.1, 0.88, n / float(CARCASS_PROXIES - 1))
		return 3.4 * k * BossMesh.taper(a, 0.32, 0.25, 0.55, false)
	return settings.hagfish_length * 0.055 * 1.5


func grabs() -> bool:
	return false


func hold_verb() -> String:
	return "KNOTTED"


## In the biting hagfish's jaws.
func hold_point() -> Vector3:
	return _grabber.head if _grabber else mouth_point()


## It lets go: it slimes them.
func _let_go(fish: FishController) -> void:
	var k := settings.leviathan_girth / 6.0
	run._hazard(fish.global_position, 3.2 * k, settings.slime_time, settings.slime_damage, Color(0.78, 0.82, 0.45, 0.35), "a hagfish's slime", true)
	if _grabber:
		_grabber.state = 3
		_grabber.state_left = 1.0
	_grabber = null


func release_push(fish: FishController) -> Vector3:
	var away := fish.global_position - global_position
	away.y = maxf(away.y, 0.0)
	return away.normalized() * 18.0 + Vector3.UP * 4.0


func telegraph() -> Dictionary:
	return {}


func mouth_point() -> Vector3:
	return global_transform * (_carcass_xf * Vector3(0.0, -1.0, 2.0))


func _ready() -> void:
	super()
	name = "WhaleFall"
	var pool := max_hp * settings.hagfish_share / maxf(hagfish.size(), 1)
	for h in hagfish:
		h.hp = pool
		for p in HAG_PROXIES:
			var n := CARCASS_PROXIES + h.index * HAG_PROXIES + p
			if n < parts.size():
				h.parts.append(parts[n])
		_settle(h)
	_pose()


## Whether any of its hagfish is still alive.
func any_alive() -> bool:
	for h in hagfish:
		if h.alive:
			return true
	return false


## A hit on a hagfish goes to its share as well as the whole; a hit on the
## carcass does carcass_armour while any hagfish lives.
func take_part(index: int, amount: float, by: FishController, source: String) -> void:
	for h in hagfish:
		if h.alive and h.parts.has(index):
			if not puppet:
				h.hp -= amount
				if h.hp <= 0.0:
					_kill(h)
			take(amount, by, source)
			return
	take(amount * (settings.carcass_armour if any_alive() else 1.0), by, source)


## Hagfish `h` is dead: limp, sinking, its proxies gone.
func _kill(h: Hagfish) -> void:
	if not h.alive:
		return
	if h == _grabber:
		release()
	h.alive = false
	h.dead_for = 0.0
	for index in h.parts:
		if run.horde.is_proxy(index):
			run.horde.remove(index)
		var at := parts.find(index)
		if at >= 0:
			parts.remove_at(at)
	h.parts.clear()


func _move(delta: float) -> void:
	if not enraged and settings.leviathan_enrage > 0.0 and age >= settings.leviathan_enrage:
		_enrage_now()
	var prey := target()
	var middle := prey.global_position if prey else run.centre
	var k := settings.leviathan_girth / 6.0
	# The carcass drifts after its prey, staying near enough for the hagfish to
	# reach; in fury it settles onto the seabed.
	var to := middle - global_position
	to.y = 0.0
	var want := Vector3.ZERO
	if to.length() > 14.0 * k:
		want = to.normalized() * speed() * 0.28
	var floor_y := run.centre.y + settings.arena_floor + (3.6 * k if phase == Phase.FURY else 9.0 * k)
	want.y = clampf((floor_y - global_position.y) * 0.5, -4.0, 4.0)
	velocity = velocity.lerp(want, 1.0 - exp(-0.7 * delta))
	global_position += velocity * delta
	if to.length() > 1.0:
		var ahead := -global_basis.z
		ahead.y = 0.0
		face(ahead.normalized().slerp(to.normalized(), 1.0 - exp(-0.25 * delta)))
	if phase == Phase.FURY:
		for h in hagfish:
			h.loose = true
	for h in hagfish:
		_update(h, delta, prey)
	_update_hold(delta)
	_pose()
	_glow_now()


func _puppet_update(delta: float) -> void:
	if phase == Phase.FURY:
		for h in hagfish:
			h.loose = true
	for h in hagfish:
		_update(h, delta, target())
	_glow_now()


## Where hagfish `i` comes out of the carcass now, and the way it faces.
func _exit_point(i: int) -> Vector3:
	var exit: Array = _exits[i % _exits.size()]
	return global_transform * (_carcass_xf * (exit[0] as Vector3))


func _exit_out(i: int) -> Vector3:
	var exit: Array = _exits[i % _exits.size()]
	return (global_basis * (_carcass_xf.basis * (exit[1] as Vector3))).normalized()


## One hagfish's tick: idle sway, a lunge, slime, or (loose) hunting; its rope
## solved, its spine and proxies placed.
func _update(h: Hagfish, delta: float, prey: FishController) -> void:
	var length := settings.hagfish_length
	if not h.alive:
		h.dead_for += delta
		for n in h.nodes.size():
			h.nodes[n] += Vector3(0.0, -2.5, 0.0) * delta
		h.skin.set_shader_parameter("dissolve", clampf(h.dead_for / 3.0, 0.0, 1.0))
		h.mesh.visible = h.dead_for < 3.2
		h.rig.follow_chain(h.nodes)
		h.rig.apply()
		return
	var anchor := _exit_point(h.index)
	var out := _exit_out(h.index)
	var rate := settings.enrage_scale if enraged else 1.0
	if h.loose:
		var goal := prey.global_position if prey else anchor
		h.velocity = h.velocity.lerp((goal - h.head).normalized() * 13.0 * rate, 1.0 - exp(-1.6 * delta))
		h.head += h.velocity * delta
	else:
		var sway := Vector3(sin(age * 0.7 + h.phase), sin(age * 0.9 + h.phase * 1.3) * 0.6, cos(age * 0.6 + h.phase)) * length * 0.16
		var rest := anchor + out * length * 0.55 + sway
		match h.state:
			0:
				h.head = h.head.lerp(rest, 1.0 - exp(-1.5 * delta))
				h.lunge_left -= delta
				var reach := minf(settings.hagfish_reach, length * 0.95)
				if not puppet and prey and h.lunge_left <= 0.0 and prey.global_position.distance_to(anchor) <= reach:
					h.state = 1
					h.state_left = WIND
					h.aim = prey.global_position
			1:
				h.head = h.head.lerp(anchor + out * length * 0.35, 1.0 - exp(-3.0 * delta))
				h.state_left -= delta
				if h.state_left <= 0.0:
					h.state = 2
					h.state_left = STRIKE
			2:
				h.head = h.head.move_toward(h.aim, STRIKE_SPEED * rate * delta)
				h.state_left -= delta
				_try_bite(h)
				if h.state == 2 and (h.state_left <= 0.0 or h.head.distance_to(h.aim) < 0.5):
					h.state = 3
					h.state_left = 1.0
			4:
				# Holding on: reeling its prey in toward its hole as it knots.
				var toward := h.head - anchor
				var gap := toward.length()
				h.head = anchor + toward / maxf(gap, 0.01) * move_toward(gap, length * 0.42, delta * 7.0)
				h.knot = minf(h.knot + delta / maxf(settings.hagfish_knot_time, 0.05), 1.0)
				if _grabber != h:
					h.state = 3
					h.state_left = 1.0
			_:
				h.head = h.head.lerp(rest, 1.0 - exp(-2.0 * delta))
				h.state_left -= delta
				if h.state_left <= 0.0:
					h.state = 0
					h.lunge_left = settings.hagfish_lunge_every * run.rng.randf_range(0.8, 1.25) / rate
		var off := h.head - anchor
		if off.length() > length * 0.97:
			h.head = anchor + off.normalized() * length * 0.97
	# Spitting: slime from its head toward the prey.
	if not puppet and phase != Phase.CIRCLE and prey:
		h.slime_left -= delta
		if h.slime_left <= 0.0:
			h.slime_left = run.rng.randf_range(3.5, 5.5) / rate
			var toward := (prey.global_position - h.head).normalized()
			var k := settings.leviathan_girth / 6.0
			run._hazard(h.head + toward * 3.0 * k, 3.2 * k, settings.slime_time, settings.slime_damage, Color(0.78, 0.82, 0.45, 0.35),
					"a hagfish's slime", true)
	# Its knot: tied while it holds a player, slipping loose after.
	var loop := TAU * settings.hagfish_length * 0.055 * 1.6
	var room := clampf((length - h.head.distance_to(anchor) * 1.05) / loop, 0.0, 1.0) if not h.loose else 1.0
	h.knot_size = minf(move_toward(h.knot_size, 1.0 if h.state == 4 else 0.0, delta * 2.5), room)
	if h.knot_size <= 0.0:
		h.knot = 0.0
	_solve(h, anchor, not h.loose, 1.0 - loop * h.knot_size / length)
	h.rig.follow_chain(_knotted(h, loop * h.knot_size / TAU))
	h.rig.apply()
	var at := PackedFloat32Array([0.06, 0.4, 0.75])
	for p in h.parts.size():
		var frame := h.rig.frame_at(length * at[p])
		run.horde.place(h.parts[p], frame.origin, -frame.basis.z)


## A striking hagfish's bite: a player its head reaches is held (hagfish_grabs).
func _try_bite(h: Hagfish) -> void:
	if puppet or not settings.hagfish_grabs or held or _regrab_left > 0.0:
		return
	var reach := settings.hagfish_length * 0.055 * 2.2
	for fish in run.local_players():
		if run.is_up(fish) and not run.is_picking(fish) and fish.global_position.distance_to(h.head) <= reach + UnnaturalRun.PLAYER_RADIUS:
			_grabber = h
			hold(fish)
			if held == fish:
				bites += 1
				h.state = 4
				h.knot = 0.0
			else:
				_grabber = null
			return


## The rope's points with its knot tied in: a loop `r` m round where the knot
## has slid to (from its tail toward its head as h.knot runs), the rope coming
## out of it beside where it went in, as an overhand knot lies.
func _knotted(h: Hagfish, r: float) -> PackedVector3Array:
	if r <= 0.01:
		return h.nodes
	var n := h.nodes.size()
	var k := clampi(roundi(lerpf(n - 4.0, 3.0, smoothstep(0.0, 1.0, h.knot))), 2, n - 3)
	var at := h.nodes[k]
	var tailward := (h.nodes[k + 1] - h.nodes[k - 1]).normalized()
	var side := tailward.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = tailward.cross(Vector3.RIGHT)
	side = side.normalized()
	var lift := side.cross(tailward).normalized()
	var shift := settings.hagfish_length * 0.055 * 2.3
	var out := PackedVector3Array()
	for i in k + 1:
		out.append(h.nodes[i])
	var steps := 14
	for j in range(1, steps + 1):
		var a := TAU * j / steps
		out.append(at + lift * r * (1.0 - cos(a)) + tailward * r * sin(a) + side * shift * a / TAU)
	for i in range(k + 1, n):
		var fade := 1.0 - float(i - k) / float(n - 1 - k)
		out.append(h.nodes[i] + side * shift * fade)
	return out


## A hagfish's rope: its head where it is, its tail end in the carcass (unless
## loose), every link its length (times `scale`: shorter while its knot takes
## up some of it), slack bowing outward and up.
func _solve(h: Hagfish, anchor: Vector3, anchored: bool, scale := 1.0) -> void:
	var link := settings.hagfish_length * scale / float(ROPE - 1)
	if h.nodes.size() != ROPE:
		h.nodes.resize(ROPE)
		for n in ROPE:
			h.nodes[n] = h.head.lerp(anchor, n / float(ROPE - 1))
	h.nodes[0] = h.head
	if anchored:
		h.nodes[ROPE - 1] = anchor
		var out := _exit_out(h.index)
		for n in range(1, ROPE - 1):
			h.nodes[n] += (out * 0.5 + Vector3.UP * 0.2) * link * 0.04
	for smooth_n in 2:
		for n in range(1, ROPE - 1):
			h.nodes[n] = h.nodes[n].lerp((h.nodes[n - 1] + h.nodes[n + 1]) * 0.5, 0.35)
	for pass_n in 10:
		for n in range(1, ROPE):
			var a := h.nodes[n - 1]
			var b := h.nodes[n]
			var gap := b - a
			var d := gap.length()
			if d < 0.0001:
				continue
			var fix := gap * (1.0 - link / d)
			var pin_b := anchored and n == ROPE - 1
			if n - 1 == 0:
				if not pin_b:
					h.nodes[n] = b - fix
			elif pin_b:
				h.nodes[n - 1] = a + fix
			else:
				h.nodes[n - 1] = a + fix * 0.5
				h.nodes[n] = b - fix * 0.5
		if anchored:
			h.nodes[ROPE - 1] = anchor
		h.nodes[0] = h.head


## Puts a hagfish at rest out of its hole at once (a new boss, a screenshot).
func _settle(h: Hagfish) -> void:
	var anchor := _exit_point(h.index)
	h.head = anchor + _exit_out(h.index) * settings.hagfish_length * 0.6
	h.nodes = PackedVector3Array()
	for step in 30:
		_update(h, 0.05, null)


func pose_for_shot(_trail: PackedVector3Array) -> void:
	for h in hagfish:
		_settle(h)
	_pose()
	_glow_now()


func _pose() -> void:
	_pose_parts()


## The carcass's proxies along it.
func _pose_parts() -> void:
	for n in mini(CARCASS_PROXIES, parts.size()):
		run.horde.place(parts[n], global_transform * (_carcass_xf * _carcass_points[n]), -global_basis.z)


func _glow_now() -> void:
	for material in skins:
		material.set_shader_parameter("flash", flash)
		material.set_shader_parameter("rage", 1.0 if enraged else 0.0)
	for h in hagfish:
		var warn := (0.5 + 0.5 * sin(age * 26.0)) * settings.telegraph_glow if h.state == 1 else 0.0
		h.skin.set_shader_parameter("warn", warn)


## Its phase, plus which hagfish live (bit 4 on).
func _net_mode() -> int:
	var mask := 0
	for h in hagfish:
		if h.alive:
			mask |= 1 << h.index
	return phase + (mask << 4)


func _set_net_mode(net_mode: int) -> void:
	super(net_mode & 15)
	var mask := net_mode >> 4
	for h in hagfish:
		if h.alive and (mask & (1 << h.index)) == 0:
			_kill(h)


func _process(delta: float) -> void:
	super(delta)
	if not dying:
		return
	for h in hagfish:
		for n in h.nodes.size():
			h.nodes[n] += Vector3.DOWN * 3.0 * delta
		h.rig.follow_chain(h.nodes)
		h.rig.apply()


func _build_look() -> void:
	var k := settings.leviathan_girth / 6.0
	var length := body_length()
	_carcass_xf = Transform3D(Basis(Vector3.BACK, ROLL), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -length * 0.5))
	var profile := func(a: float) -> Vector4:
		var t := BossMesh.taper(a, 0.3, 0.1, 0.35, false)
		var head := 1.0 - smoothstep(0.0, 0.3, a)
		var stock := smoothstep(0.75, 0.95, a)
		var hw := 3.7 * k * t * lerpf(1.0, 1.25, head) * lerpf(1.0, 0.55, stock)
		var hh := 3.3 * k * t * lerpf(1.0, 0.68, head) * lerpf(1.0, 1.3, stock)
		var close := sqrt(maxf(1.0 - pow(maxf(a - 0.97, 0.0) / 0.03, 2.0), 0.0))
		return Vector4(hw * close, hh * close, -hh * 0.08 * head, 2.0)
	var mesh := BossMesh.new(length)
	# Throat pleats under the jaw, and the bloat of a body weeks dead.
	var pleats := func(a: float, angle: float) -> float:
		var throat := smoothstep(0.65, 1.0, -cos(angle)) * (1.0 - smoothstep(0.34, 0.44, a))
		var groove := pow(0.5 + 0.5 * sin(angle * 30.0), 4.0)
		return 1.0 - 0.03 * groove * throat + 0.025 * sin(a * 37.0 + angle * 3.0) * sin(angle * 5.0 + a * 11.0)
	mesh.loft(0.0, length, profile, 200, 60, BossMesh.BODY, Callable(), 0.0, pleats)
	# The ribs, bared where its chest is torn open, and the spine behind them.
	for i in 7:
		var z := lerpf(0.37, 0.56, i / 6.0) * length
		var slice: Vector4 = profile.call(z / length)
		var reach := 0.6 if i == 2 else (0.9 if i == 5 else 1.25)
		var path := PackedVector3Array()
		for j in 16:
			var phi := lerpf(-1.25, reach, j / 15.0)
			path.append(Vector3(slice.x * 0.88 * cos(phi), slice.z + slice.y * 0.88 * sin(phi), z))
		mesh.tube(path, func(_t: float) -> float: return 0.3 * k, 7, BossMesh.BONE)
	var spine := PackedVector3Array()
	for j in 20:
		var z := lerpf(0.3, 0.66, j / 19.0) * length
		var slice: Vector4 = profile.call(z / length)
		spine.append(Vector3(0.0, slice.z + slice.y * 0.5, z))
	mesh.tube(spine, func(t: float) -> float: return (0.55 + 0.12 * sin(t * 60.0)) * k, 8, BossMesh.BONE)
	# Baleen along the upper jaw, hanging into the mouth.
	for side: float in [-1.0, 1.0]:
		mesh.membrane(func(u: float) -> Vector3:
				var z := lerpf(0.03, 0.24, u) * length
				var slice: Vector4 = profile.call(z / length)
				return Vector3(side * slice.x * 0.86, slice.z - slice.y * 0.18, z),
			func(u: float) -> Vector3: return Vector3(0.0, -1.3 * k * sin(u * PI * 0.9 + 0.1), 0.0),
			60, 3, Vector2.ZERO, BossMesh.EXTRA)
	# Flippers and flukes.
	for side: float in [-1.0, 1.0]:
		var slice: Vector4 = profile.call(0.27)
		mesh.blob(Vector3(side * slice.x * 0.96, slice.z - slice.y * 0.42, 0.27 * length), Vector3(2.5, 0.24, 0.7) * k,
				Basis(Vector3.UP, side * 0.5) * Basis(Vector3.BACK, -side * 0.45), 8, 14, BossMesh.FIN)
		mesh.blob(Vector3(side * 2.7 * k, 0.0, length - 0.9 * k), Vector3(3.7, 0.32, 1.4) * k, Basis(Vector3.UP, -side * 0.5), 8, 14, BossMesh.FIN)
	_carcass_skin = ShaderMaterial.new()
	_carcass_skin.shader = WHALE_SKIN
	skins.append(_carcass_skin)
	var chest: Vector4 = profile.call(0.46)
	var eye_slice: Vector4 = profile.call(0.2)
	var eye_y := eye_slice.z - eye_slice.y * 0.1
	_carcass_skin.set_shader_parameter("cavity", Vector4(0.46 * length, chest.z, 0.1 * length, chest.y * 0.55))
	_carcass_skin.set_shader_parameter("wound", Vector4(0.62 * length, 0.3 * k, 2.3 * k, 1.7 * k))
	_carcass_skin.set_shader_parameter("eye", Vector3(0.2 * length, eye_y, 0.95 * k))
	_carcass_skin.set_shader_parameter("blowhole", Vector3(0.17 * length, 0.0, 0.8 * k))
	_carcass_skin.set_shader_parameter("length_m", length)
	_carcass = MeshInstance3D.new()
	_carcass.name = "Carcass"
	_carcass.mesh = mesh.commit()
	_carcass.material_override = _carcass_skin
	_carcass.transform = _carcass_xf
	_carcass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_carcass)
	for n in CARCASS_PROXIES:
		var a := lerpf(0.1, 0.88, n / float(CARCASS_PROXIES - 1))
		var slice: Vector4 = profile.call(a)
		_carcass_points.append(Vector3(0.0, slice.z, a * length))
	# Where the hagfish come out, each a little inside its hole.
	var at := func(a: float) -> Vector4: return profile.call(a)
	var eye_x: float = (at.call(0.2) as Vector4).x
	var c1: Vector4 = at.call(0.43)
	var c2: Vector4 = at.call(0.5)
	var w: Vector4 = at.call(0.62)
	var b: Vector4 = at.call(0.17)
	_exits = [
		[Vector3(eye_x * 0.75, eye_y, 0.2 * length), Vector3(1.0, 0.0, -0.2)],
		[Vector3(-eye_x * 0.75, eye_y, 0.2 * length), Vector3(-1.0, 0.0, -0.2)],
		[Vector3(c1.x * 0.5, c1.z + c1.y * 0.3, 0.43 * length), Vector3(1.0, 0.3, 0.0)],
		[Vector3(c2.x * 0.5, c2.z - c2.y * 0.25, 0.5 * length), Vector3(1.0, -0.15, 0.2)],
		[Vector3(-w.x * 0.7, 0.3 * k, 0.62 * length), Vector3(-1.0, 0.25, 0.1)],
		[Vector3(0.0, b.z + b.y * 0.8, 0.17 * length), Vector3(0.0, 1.0, -0.3)],
	]
	# The hagfish: one rest mesh, each its own spine and material.
	var hag_length := settings.hagfish_length
	var hag_mesh := _hagfish_mesh(hag_length, hag_length * 0.055)
	for i in settings.hagfish_count:
		var h := Hagfish.new()
		h.index = i
		h.phase = i * 1.7
		h.rig = SpineRig.new(hag_length, hag_length * 0.2)
		h.skin = _spine_material(HAG_SKIN)
		h.skin.set_shader_parameter("radius", hag_length * 0.055)
		h.skin.set_shader_parameter("spine_wave", Vector4(0.35 * k, 0.5, 3.0, 0.4))
		h.skin.set_shader_parameter("flutter", Vector3(0.25 * k, 2.2, 6.0))
		h.skin.set_shader_parameter("flutter_phase", i * 1.3)
		h.mesh = h.rig.add_mesh(self, hag_mesh, h.skin)
		h.head = global_position
		hagfish.append(h)


## A giant hagfish's rest mesh (its head at z 0): a slick tube, its tail
## flattened into a paddle fringed with a fin fold, barbels round its mouth,
## two combs of teeth on its tongue.
static func _hagfish_mesh(length: float, radius: float) -> ArrayMesh:
	var mesh := BossMesh.new(length)
	var profile := func(a: float) -> Vector4:
		var t := BossMesh.taper(a, 0.06, 0.8, 0.6, true)
		var tail := smoothstep(0.72, 1.0, a)
		return Vector4(radius * t * lerpf(1.0, 0.4, tail), radius * t * lerpf(1.0, 1.15, tail), 0.0, 2.0)
	# Fine wrinkles round its length.
	var wrinkles := func(a: float, angle: float) -> float:
		return 1.0 + 0.007 * sin(a * length / (radius * 0.16)) * (0.5 + 0.5 * sin(angle * 4.0 + a * 31.0))
	mesh.loft(0.0, length, profile, 140, 20, BossMesh.BODY, Callable(), 0.0, wrinkles)
	for sign_y: float in [1.0, -1.0]:
		mesh.membrane(func(u: float) -> Vector3:
				var a := lerpf(0.68, 0.99, u)
				var slice: Vector4 = profile.call(a)
				return Vector3(0.0, slice.y * 0.95 * sign_y, a * length),
			func(u: float) -> Vector3:
				var h := radius * 0.6 * sin(u * PI) * lerpf(0.6, 1.0, u)
				return Vector3(0.0, h * sign_y, h * 0.3),
			40, 3, Vector2(0.0, 1.0), BossMesh.FIN)
	var barbels := [Vector2(-0.45, 0.55), Vector2(0.45, 0.55), Vector2(-0.85, 0.0), Vector2(0.85, 0.0), Vector2(-0.5, -0.65), Vector2(0.5, -0.65)]
	for n in barbels.size():
		var dir: Vector2 = barbels[n]
		var base := Vector3(dir.x * radius * 0.55, dir.y * radius * 0.55, radius * 0.2)
		var reach := radius * (1.6 + 0.5 * (n % 2))
		var path := PackedVector3Array()
		for i in 10:
			var s := i / 9.0
			path.append(base + Vector3(dir.x * 0.7 * s, dir.y * 0.45 * s - 0.15 * s * s, -1.0 * s) * reach)
		mesh.tube(path, func(t: float) -> float: return lerpf(0.13, 0.03, t) * radius, 6, BossMesh.FILAMENT, Vector2(0.2, 1.0))
	for row: float in [-1.0, 1.0]:
		for j in 7:
			var x := (j - 3) * 0.16 * radius
			mesh.tooth(Vector3(x, -radius * 0.5, radius * (0.16 + row * 0.08)), Vector3(0.0, -0.45, -1.0).normalized() * 0.4 * radius, 0.06 * radius,
					Vector3(0.0, -0.3, 0.0), 5)
	return mesh.commit()
