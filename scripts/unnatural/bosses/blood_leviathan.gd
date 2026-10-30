class_name BloodLeviathan
extends Boss
## The final boss (planning_unnatural.md §3, D5), and the base of every final
## boss: by default the King of Herrings, a giant oarfish weeks dead; its
## alternates (GulperBoss, WhaleFallBoss, LampreyBoss, FallenAngelBoss) extend it. Beating it
## opens the whirlpool. Its body is one seamless mesh bent along the way it
## swam (SpineRig, spine_bend.gdshaderinc), with leviathan_segments proxies
## along it. Its phases, by the hp it has left:
## 1. CIRCLE: it circles the players at a distance, cutting in through them
##    now and then;
## 2. SPIT (from two thirds): as well, every leviathan_bolt_every s it spits a
##    fan of leviathan_bolts bolts at its target (they hurt players): the
##    King's are shards of its rotting scales;
## 3. FURY (under a third): faster, it charges the target again and again.
## Each dive is wound up first (leviathan_dive_telegraph: slower, glowing, its
## lane showing, telegraph()), and it glows before it spits.
## Not beaten leviathan_enrage s after it came, it enrages (enrage_scale on
## speed and contact damage; UnnaturalRun has the director escalate too).
## An alternate can grab a player (hold(): drawn into its mouth over
## grab_catch_time, drained, until they stride their way out or it lets go).
## The King itself chomps in any phase (king_chomp_*: its jaw gapes on its
## hinge, spine_hinge, then snaps shut), and in fury it coils round a player it
## reaches, its body wrapped coil_loops times round them, tightening.

signal enraged_now
signal phase_changed(phase: int)
## It spat bolts from `from`, along `directions` (online: the guests' puppets spit them too).
signal spat(from: Vector3, directions: PackedVector3Array)
## It grabbed a player, or let them go.
signal held_changed(fish: FishController, held: bool)
## Its jaws snapped shut at `at`, biting `bit` players.
signal chomped(at: Vector3, bit: int)

enum Phase { CIRCLE, SPIT, FURY }

const BLOOD := Color(0.5, 0.03, 0.05)
const BOLT_SPEED := 18.0
const BOLT_LIFE := 3.5
## How far apart the proxies sit along the body (times leviathan_girth).
const SPACING := 1.3
const SKIN := preload("res://shaders/boss_oarfish.gdshader")
const EYE_SHADER := preload("res://shaders/fish_eye.gdshader")

var phase := Phase.CIRCLE
var bolts_fired := 0
var dives := 0
## Its spine, and every material bent along it (flash, warn, rage, dissolve go to each).
var rig: SpineRig
var skins: Array[ShaderMaterial] = []
## The player it holds (null: none), and how they're getting free.
var held: FishController
var hold_strides := 0

## Riders on the body: each [node, rest point, rest basis, sway].
var _riders: Array = []
var _trail := PackedVector3Array()
var _bolt_left := 0.0
var _dive_left := 4.0
var _diving := 0.0
## Winding up a dive (s left; leviathan_dive_telegraph), and the way it'll go.
## A puppet only knows that it is (the host's mode says so).
var _dive_warn := 0.0
var _dive_dir := Vector3.FORWARD
var _puppet_warn := false
var _orbit := 1.0
var _bolts: Array[Dictionary] = []
var _bolt_mesh := MultiMeshInstance3D.new()
var _dissolve := 0.0
var _hold_left := 0.0
var _drain_left := 0.0
var _hold_hook := Callable()
var _regrab_left := 0.0
## Where the held player was caught, and how far they've been drawn in (0 to 1).
var _catch_from := Vector3.ZERO
var _catch_t := 1.0
## Its chomp: how far its jaw is open (-1 snapped shut, 0 at rest, 1 gaping),
## its wind-up and snap (s left), the wait for the next, and the counts.
var jaw := 0.0
var chomp_count := 0
var chomp_hits := 0
var _chomp_wind := 0.0
var _snap_left := 0.0
var _chomp_cool := 1.5
var _puppet_jaw := 0
## The King's jaw hinge (rest y, z) and the skin it's on.
var _jaw_hinge := Vector2.ZERO
var _jaw_skin: ShaderMaterial
## The coil (the King in fury): round where it caught its prey, how far
## wrapped (0 to 1) and how tight (0 to 1), the pose it caught them in, and
## the damage friends have done it since (prying it loose).
var _coil_center := Vector3.ZERO
var _coil_angle := 0.0
var _coil_wrap := 0.0
var _coil_tight := 0.0
var _coil_from := PackedVector3Array()
var _coil_hurt := 0.0


func _ready() -> void:
	super()
	title = boss_title()
	name = "BloodLeviathan"
	rig = SpineRig.new(body_length(), settings.leviathan_girth * 1.6)
	_build_look()
	for n in proxy_count():
		add_part(global_position, proxy_radius(n))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _bolt_mesh_look()
	_bolt_mesh.multimesh = multimesh
	_bolt_mesh.top_level = true
	_bolt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_bolt_mesh)
	_bolt_left = settings.leviathan_bolt_every
	velocity = Vector3.FORWARD * settings.leviathan_speed
	_trail.append(global_position)
	_pose()


# --- What each final boss sets (the King's here) ----------------------------

func boss_title() -> String:
	return "THE KING OF HERRINGS"


## The line under its name when it comes.
func boss_line() -> String:
	return "FORTY FATHOMS OF ROTTING SILVER"


## Its id online (UnnaturalNet: the guests build the same one).
func net_kind() -> String:
	return "boss"


## How long its body is (m), nose to tail.
func body_length() -> float:
	return settings.leviathan_segments * settings.leviathan_girth * SPACING


func proxy_count() -> int:
	return settings.leviathan_segments


## How far back from the head proxy `n` sits (m), and its radius.
func proxy_distance(n: int) -> float:
	return n * settings.leviathan_girth * SPACING


func proxy_radius(n: int) -> float:
	var t := float(n) / maxf(proxy_count() - 1, 1)
	return settings.leviathan_girth * lerpf(1.0, 0.35, t * t)


## Where a grabbed player is held (the mouth), in the world.
func mouth_point() -> Vector3:
	return rig.place(Vector3(0.0, -settings.leviathan_girth * 0.3, 0.5))


## Whether it grabs players who touch its mouth while charging (the King: in
## fury, to coil round them).
func grabs() -> bool:
	return coils() and phase == Phase.FURY


## Whether it chomps, and whether it coils round what it grabs (both the King's).
func chomps() -> bool:
	return net_kind() == "boss"


func coils() -> bool:
	return net_kind() == "boss"


## Where a held player is kept (its mouth; the King's coil: inside it).
func hold_point() -> Vector3:
	return _coil_center if coils() else mouth_point()


## Whether a player it holds is out of sight (swallowed).
func hides_held() -> bool:
	return false


## What it's doing to the player it holds, for the HUD ("COILED", "SWALLOWED").
func hold_verb() -> String:
	return "COILED" if coils() else "HELD"


## How much of the hold is left (1 just caught, 0 it lets go).
func hold_share_left() -> float:
	return clampf(_hold_left / maxf(settings.final_hold_time, 0.01), 0.0, 1.0) if held else 0.0


## How hard its hold drains now (times final_hold_damage).
func hold_drain_scale() -> float:
	return lerpf(1.0, settings.coil_squeeze, _coil_tight) if coils() else 1.0


## A held player strode (one of final_hold_strides toward getting free).
func _held_strode() -> void:
	if coils():
		_coil_tight = maxf(_coil_tight - settings.coil_loosen, 0.0)


## It just caught `fish` (the look each boss gives it).
func _caught(fish: FishController) -> void:
	if coils():
		_coil_center = fish.global_position
		var off := Vector3(global_position.x - _coil_center.x, 0.0, global_position.z - _coil_center.z)
		if off.length_squared() < 0.01:
			off = -Vector3(velocity.x, 0.0, velocity.z)
		_coil_angle = atan2(off.z, off.x)
		_coil_wrap = 0.0
		_coil_tight = 0.0
		_coil_hurt = 0.0
		_coil_from = rig.points.duplicate()
		_trail.clear()


## It's letting `fish` go.
func _let_go(_fish: FishController) -> void:
	pass


## How hard a held player is thrown clear when let go.
func release_push(fish: FishController) -> Vector3:
	var away := fish.global_position - global_position
	if coils():
		away = fish.global_position - mouth_point()
		away.y = 0.0
	return away.normalized() * 18.0 + Vector3.UP * 4.0


## Its own extra moves each tick (the host's), with its target (null: none).
func _special(_delta: float, _prey: FishController) -> void:
	pass


## Its look: the King of Herrings. Built straight (head at z 0), bent by the rig.
func _build_look() -> void:
	var length := body_length()
	var g := settings.leviathan_girth
	var k := g / 6.0
	var deep := g * 0.8
	var mesh := BossMesh.new(length)
	var profile := func(along: float) -> Vector4:
		var h := deep * BossMesh.taper(along, 0.065, 0.05, 0.42)
		var head := 1.0 - smoothstep(0.0, 0.1, along)
		return Vector4(h * lerpf(0.22, 0.42, head), h, -h * 0.08 * head, 1.6)
	mesh.loft(0.0, length, profile, 280, 30, BossMesh.BODY)
	var top := func(z: float) -> Vector3:
		var slice: Vector4 = profile.call(z / length)
		return Vector3(0.0, slice.z + slice.y * 0.96, z)
	# The dorsal fin, the whole length of the back: torn crimson, rippling as
	# a real oarfish's does.
	var fin_from := 5.5 * k
	var fin_to := length * 0.985
	mesh.membrane(func(u: float) -> Vector3: return top.call(lerpf(fin_from, fin_to, u)),
		func(u: float) -> Vector3:
			var a := lerpf(fin_from, fin_to, u) / length
			var h := deep * 0.42 * lerpf(1.0, 0.45, a) * (1.0 - pow(maxf(a - 0.9, 0.0) / 0.1, 2.0))
			return Vector3(0.0, h, h * 0.3),
		320, 4, Vector2(0.0, 1.0), BossMesh.FIN)
	# The crest: the fin's first rays, grown into long blood-red filaments that
	# rise off the head and stream back, joined at their base by membrane.
	var crest_from := 1.2 * k
	var crest_to := 5.5 * k
	mesh.membrane(func(u: float) -> Vector3: return top.call(lerpf(crest_from, crest_to, u)),
		func(u: float) -> Vector3: return Vector3(0.0, lerpf(2.8, 1.6, u) * k, lerpf(0.6, 1.4, u) * k),
		40, 4, Vector2(0.1, 0.9), BossMesh.FIN)
	for n in 11:
		var t := n / 10.0
		var base: Vector3 = top.call(lerpf(crest_from, crest_to, t))
		var rise := lerpf(6.0, 2.6, t) * k
		var back := lerpf(19.0, 9.0, t) * k
		var lean := (0.3 + 0.9 * t) * k * (1.0 if n % 2 == 0 else -1.0)
		var path := PackedVector3Array()
		for i in 28:
			var s := i / 27.0
			var y := base.y + rise * sin(minf(s * 1.4, 1.0) * PI * 0.5) - rise * 0.35 * maxf(s - 0.6, 0.0) + 0.5 * k * sin(s * 6.0 + n) * s
			path.append(Vector3(lean * s, y, base.z + back * pow(s, 1.25)))
		mesh.tube(path, func(s: float) -> float: return lerpf(0.24, 0.035, s) * k, 7, BossMesh.FILAMENT, Vector2(0.1, 1.0))
	# The pelvic "oars": a long single ray each side, hanging down and back,
	# ending in a red paddle.
	for side: float in [-1.0, 1.0]:
		var z0 := 8.0 * k
		var slice: Vector4 = profile.call(z0 / length)
		var base := Vector3(side * slice.x * 0.4, slice.z - slice.y * 0.85, z0)
		var path := PackedVector3Array()
		for i in 22:
			var s := i / 21.0
			path.append(base + Vector3(side * (0.5 + 1.6 * s) * k, -8.0 * k * s, 6.0 * k * s * s))
		mesh.tube(path, func(s: float) -> float: return lerpf(0.16, 0.08, s) * k, 7, BossMesh.FILAMENT, Vector2(0.05, 0.8))
		var tip := path[path.size() - 1]
		mesh.blob(tip + Vector3(0.0, -0.7 * k, 0.3 * k), Vector3(0.14, 0.95, 0.5) * k, Basis(Vector3.RIGHT, 0.3), 8, 12, BossMesh.FILAMENT)
	# The lower jaw, hanging open on its hinge (it gapes and snaps: the chomp),
	# needle teeth along both jaws.
	var jaw_from := -1.0 * k
	var jaw_to := 4.4 * k
	var jaw := func(along: float) -> Vector4:
		var grow := pow(sin(minf(along * 1.5, 1.0) * PI * 0.5), 0.6)
		var drop := lerpf(-deep * 0.55 - 2.2 * k, -deep * 0.32, along)
		return Vector4(1.15 * k * grow, 0.42 * k * grow, drop, 1.8)
	_jaw_hinge = Vector2(-deep * 0.32, jaw_to)
	mesh.hinge = 1.0
	mesh.loft(jaw_from, jaw_to, jaw, 24, 16, BossMesh.INSIDE)
	for side: float in [-1.0, 1.0]:
		mesh.hinge = 1.0
		for n in 13:
			var t := lerpf(0.08, 0.75, n / 12.0)
			var slice: Vector4 = jaw.call(t)
			var z := lerpf(jaw_from, jaw_to, t)
			mesh.tooth(Vector3(side * slice.x * 0.75, slice.z + slice.y * 0.75, z), Vector3(-side * 0.12, 1.0, 0.2).normalized() * lerpf(0.75, 0.4, t) * k,
					0.1 * k, Vector3(0.0, 0.0, 0.35))
		mesh.hinge = 0.0
		for n in 11:
			var z := lerpf(0.2, 3.4, n / 10.0) * k
			var slice: Vector4 = profile.call(z / length)
			mesh.tooth(Vector3(side * slice.x * 0.8, slice.z - slice.y * 0.72, z), Vector3(side * 0.05, -1.0, 0.15).normalized() * lerpf(0.7, 0.35, n / 10.0) * k,
					0.09 * k, Vector3(0.0, 0.0, 0.3))
	var skin := _spine_material(SKIN)
	_jaw_skin = skin
	skin.set_shader_parameter("girth", deep)
	var eye_z := 3.3 * k
	var eye_slice: Vector4 = profile.call(eye_z / length)
	var eye_rest := Vector3(eye_slice.x * 0.86, eye_slice.z + eye_slice.y * 0.36, eye_z)
	skin.set_shader_parameter("eye_at", eye_rest)
	skin.set_shader_parameter("eye_ring", 1.15 * k)
	skin.set_shader_parameter("spine_wave", Vector4(0.35 * k, 0.12, 1.6, 0.15))
	skin.set_shader_parameter("flutter", Vector3(0.45 * k, 0.9, 4.5))
	rig.add_mesh(self, mesh.commit(), skin)
	# Milky dead eyes.
	for side: float in [-1.0, 1.0]:
		var eye := _eye(0.85 * k, Color(0.8, 0.82, 0.83), Color(0.68, 0.7, 0.71), 0.3)
		_add_rider(eye, Vector3(side * eye_rest.x, eye_rest.y, eye_rest.z), Basis.looking_at(Vector3(side, 0.1, -0.15), Vector3.UP))
	# Lampreys feeding on its flanks, hanging and swaying.
	var lamprey := _lamprey_mesh(3.6 * k, 0.32 * k)
	var lamprey_skin := StandardMaterial3D.new()
	lamprey_skin.albedo_color = Color(0.24, 0.21, 0.15)
	lamprey_skin.roughness = 0.45
	lamprey_skin.metallic_specular = 0.7
	var spots := [[0.17, 1.0, 0.1], [0.26, -1.0, -0.2], [0.37, 1.0, -0.35], [0.44, -1.0, 0.25], [0.56, 1.0, 0.0], [0.65, -1.0, -0.3], [0.79, 1.0, 0.15]]
	for spot: Array in spots:
		var z: float = spot[0] * length
		var side: float = spot[1]
		var slice: Vector4 = profile.call(spot[0])
		var y: float = slice.z + slice.y * float(spot[2])
		var node := MeshInstance3D.new()
		node.mesh = lamprey
		node.material_override = lamprey_skin
		var hang := Basis.looking_at(Vector3(side * 0.35, -0.85, 0.4).normalized(), Vector3(side, 0.3, 0.0))
		_add_rider(node, Vector3(side * slice.x * 0.95, y, z), hang * Basis(Vector3.UP, PI), 0.25)


## A small lamprey (rest: its disc at z 0, its tail at +z `length`).
static func _lamprey_mesh(length: float, radius: float) -> ArrayMesh:
	var mesh := BossMesh.new(length)
	mesh.loft(0.0, length, func(along: float) -> Vector4:
		var r := radius * BossMesh.taper(along, 0.08, 0.25, 0.25)
		return Vector4(r, r, 0.0, 2.0), 20, 10)
	return mesh.commit()


## A spine material: `shader` with the rig's uniforms, kept in `skins`.
func _spine_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	skins.append(material)
	return material


## A lifelike eye (fish_eye.gdshader), `radius` m.
func _eye(radius: float, iris: Color, inner: Color, pupil: float) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = EYE_SHADER
	material.set_shader_parameter("iris", iris)
	material.set_shader_parameter("iris_inner", inner)
	material.set_shader_parameter("pupil", pupil)
	material.set_shader_parameter("sheen", 0.15)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var eye := MeshInstance3D.new()
	eye.mesh = sphere
	eye.material_override = material
	eye.scale = Vector3.ONE * radius * 2.0
	return eye


## `node` riding the body at rest point `at`, turned by `basis` in the body's
## frame there, swaying `sway` rad.
func _add_rider(node: Node3D, at: Vector3, basis: Basis, sway := 0.0) -> void:
	node.top_level = true
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_riders.append([node, at, basis.scaled(node.scale), sway])


## The bolts' look: the King spits shards of its rotting scales.
func _bolt_mesh_look() -> Mesh:
	var flake := FxLooks.scale_shard().duplicate() as ArrayMesh  # its own material slot
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.85, 0.85, 0.9)
	glow.metallic = 0.9
	glow.roughness = 0.2
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.25, 0.25)
	glow.emission_energy_multiplier = 0.8
	glow.rim_enabled = true
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	flake.surface_set_material(0, glow)
	return flake


# --- The fight ----------------------------------------------------------------

func contact() -> float:
	return settings.leviathan_contact * (settings.enrage_scale if enraged else 1.0) * settings.enemy_damage_scale


func speed() -> float:
	var s := settings.leviathan_speed * settings.enemy_speed_scale
	if phase == Phase.FURY:
		s *= 1.35
	if enraged:
		s *= settings.enrage_scale
	return s


func take(amount: float, by: FishController, source: String) -> void:
	super(amount, by, source)
	if held and coils() and by != held and not puppet:
		# A friend's hits pry the coil loose: coil_loosen per 1% of its hp.
		_coil_hurt += amount
		var step := max_hp * 0.01
		while _coil_hurt >= step and step > 0.0:
			_coil_hurt -= step
			_coil_tight = maxf(_coil_tight - settings.coil_loosen, 0.0)
	var now := Phase.CIRCLE
	if share() <= 1.0 / 3.0:
		now = Phase.FURY
	elif share() <= 2.0 / 3.0:
		now = Phase.SPIT
	if now != phase and not dying:
		phase = now
		phase_changed.emit(phase)


func _move(delta: float) -> void:
	if not enraged and settings.leviathan_enrage > 0.0 and age >= settings.leviathan_enrage:
		_enrage_now()
	var prey := target()
	if held and coils():
		_coil(delta)
		_update_hold(delta)
		_update_bolts(delta)
		_glow_now()
		return
	var middle := run.centre
	if prey:
		middle = prey.global_position
	var wanted: Vector3
	var to_prey := middle - global_position
	_dive_left -= delta
	if phase == Phase.FURY or _diving > 0.0:
		# Straight through the target.
		wanted = to_prey.normalized() * speed() * 1.4
		_diving -= delta
		if _diving <= 0.0 and phase != Phase.FURY:
			_dive_left = 5.0
	else:
		# Circle it at about 22 m (more for a big body), a little up and down.
		var flat := Vector3(to_prey.x, 0.0, to_prey.z)
		var gap := flat.length()
		var ring := circle_radius()
		var round_dir := Vector3.UP.cross(flat.normalized()) * _orbit if gap > 0.01 else Vector3.FORWARD
		var inward := flat.normalized() * clampf((gap - ring) / 10.0, -1.0, 1.0) if gap > 0.01 else Vector3.ZERO
		wanted = (round_dir + inward + Vector3.UP * sin(age * 0.7) * 0.3).normalized() * speed()
		if _dive_warn > 0.0:
			# Gathering itself to dive: slower, glowing, its lane showing.
			_dive_warn -= delta
			_dive_dir = to_prey.normalized() if to_prey.length_squared() > 0.01 else -global_basis.z
			wanted *= 0.5
			if _dive_warn <= 0.0:
				_dive()
		elif _dive_left <= 0.0 and prey:
			if settings.leviathan_dive_telegraph > 0.0:
				_dive_warn = settings.leviathan_dive_telegraph
				_dive_dir = to_prey.normalized() if to_prey.length_squared() > 0.01 else -global_basis.z
			else:
				_dive()
	if held:
		wanted *= 0.6  # dragging its prey
	steer(wanted, 1.4 if phase != Phase.FURY else 2.2, 10.0, delta)
	global_position += velocity * delta
	face(velocity)
	if phase != Phase.CIRCLE and prey and settings.leviathan_bolts > 0 and settings.leviathan_bolt_every > 0.0:
		_bolt_left -= delta
		if _bolt_left <= 0.0:
			_bolt_left = settings.leviathan_bolt_every / (settings.enrage_scale if enraged else 1.0)
			_spit(prey.global_position)
	_special(delta, prey)
	if chomps():
		_update_chomp(delta, prey)
	_update_hold(delta)
	_update_bolts(delta)
	_pose()
	_glow_now()


## How far out it circles its target (m).
func circle_radius() -> float:
	return 22.0 + body_length() * 0.08


## Straight through its target, now.
func _dive() -> void:
	_dive_warn = 0.0
	_diving = 2.2
	dives += 1
	_orbit = -_orbit


## Winding up a dive (a puppet: the host says it is).
func winding_up() -> bool:
	return _puppet_warn if puppet else _dive_warn > 0.0


## Its dive's lane while it winds one up.
func telegraph() -> Dictionary:
	if not winding_up():
		return {}
	var dir := -global_basis.z if puppet else _dive_dir
	var progress := 0.6 if puppet else 1.0 - _dive_warn / maxf(settings.leviathan_dive_telegraph, 0.01)
	return {"from": global_position, "dir": dir, "length": speed() * 1.4 * 2.2, "width": settings.leviathan_girth * 1.4, "progress": progress}


## Its glow: brighter enraged, flashing when hit, pulsing while it winds up a
## dive or is about to spit (telegraph_glow).
func _glow_now() -> void:
	var warn := winding_up()
	if not puppet and phase != Phase.CIRCLE and settings.leviathan_bolts > 0 and _bolt_left < settings.leviathan_spit_telegraph:
		warn = true
	var pulse := (0.5 + 0.5 * sin(age * 26.0)) * settings.telegraph_glow if warn else 0.0
	for material in skins:
		material.set_shader_parameter("flash", flash)
		material.set_shader_parameter("warn", pulse)
		material.set_shader_parameter("rage", 1.0 if enraged else 0.0)
	if _jaw_skin:
		# Gaping drops the jaw a long way on its hinge; snapped, it shuts up tight.
		var angle := jaw * 0.55 if jaw > 0.0 else jaw * 0.34
		_jaw_skin.set_shader_parameter("hinge", Vector3(_jaw_hinge.x, _jaw_hinge.y, angle))


func _enrage_now() -> void:
	enraged = true
	enraged_now.emit()


## Its phase, plus 8 while it winds up a dive, 16 while it winds up a chomp
## and 32 while it snaps (subclasses that don't chomp add more above 15).
func _net_mode() -> int:
	return phase + (8 if _dive_warn > 0.0 else 0) + (16 if _chomp_wind > 0.0 else 0) + (32 if _snap_left > 0.0 else 0)


func _set_net_mode(net_mode: int) -> void:
	_puppet_warn = (net_mode & 8) != 0
	if chomps():
		_puppet_jaw = 1 if (net_mode & 16) != 0 else (-1 if (net_mode & 32) != 0 else 0)
	var now := net_mode & 7
	if now != phase:
		phase = now as Phase
		phase_changed.emit(phase)


func _place_body() -> void:
	_pose()


func _puppet_update(delta: float) -> void:
	if chomps():
		jaw = move_toward(jaw, float(_puppet_jaw), delta * (14.0 if _puppet_jaw < 0 else 2.5))
	_update_bolts(delta)
	_glow_now()


# --- The chomp (the King) -----------------------------------------------------

## Its chomp each tick: a player ahead of its mouth and in range starts one;
## its jaw gapes over king_chomp_wind, then snaps shut, biting.
func _update_chomp(delta: float, prey: FishController) -> void:
	_chomp_cool -= delta
	if _snap_left > 0.0:
		_snap_left -= delta
		jaw = move_toward(jaw, -1.0, delta * 14.0)
	elif _chomp_wind > 0.0:
		_chomp_wind -= delta
		jaw = move_toward(jaw, 1.0, delta * 1.3 / maxf(settings.king_chomp_wind, 0.05))
		if _chomp_wind <= 0.0:
			_snap(settings.king_chomp_reach, settings.king_chomp_damage)
	else:
		jaw = move_toward(jaw, 0.0, delta * 2.5)
		if held == null and prey and _chomp_cool <= 0.0 and settings.king_chomp_range > 0.0 and _ahead(prey, settings.king_chomp_range):
			_chomp_wind = settings.king_chomp_wind


## Whether `fish` is within `reach` m of its mouth, in front of it.
func _ahead(fish: FishController, reach: float) -> bool:
	var off := fish.global_position - mouth_point()
	var forward := -rig.frame_at(0.0).basis.z
	return off.length() <= reach and off.dot(forward) > -off.length() * 0.2


## Its jaws snap shut: everyone within `reach` m of its mouth is bitten.
func _snap(reach: float, damage: float) -> void:
	_snap_left = 0.3
	_chomp_cool = settings.king_chomp_every
	chomp_count += 1
	var mouth := mouth_point()
	var bit := 0
	for fish in run.players:
		if fish.puppet or not run.is_up(fish) or fish == held:
			continue
		if fish.global_position.distance_to(mouth) <= reach + UnnaturalRun.PLAYER_RADIUS:
			run.hurt(fish, damage * settings.enemy_damage_scale * run.stage_damage(), -1, title.capitalize())
			bit += 1
	chomp_hits += bit
	chomped.emit(mouth, bit)


# --- The coil (the King, in fury) ---------------------------------------------

## Coiled round its prey: its head circles them, its body a helix of up to
## coil_loops turns round them, coil_radius tightening to coil_tight, eased in
## from the pose it caught them in.
func _coil(delta: float) -> void:
	_coil_wrap = minf(_coil_wrap + delta / 0.7, 1.0)
	_coil_tight = minf(_coil_tight + delta / maxf(settings.final_hold_time * 0.75, 0.1), 1.0)
	var r := lerpf(settings.coil_radius, settings.coil_tight, _coil_tight) * (1.0 + (1.0 - _coil_wrap) * 0.5)
	var length := body_length()
	var loops := minf(settings.coil_loops, length * 0.85 / (TAU * r))
	var pitch := settings.leviathan_girth * 1.75
	var top := _coil_center.y + pitch * loops * 0.5
	# It slides slowly round itself, squeezing.
	_coil_angle += delta * speed() * 0.35 / r * _orbit
	var at := func(d: float) -> Vector3:
		var wound := clampf(d, 0.0, loops * TAU * r)
		var a := _coil_angle - wound / r * _orbit
		var p := _coil_center + Vector3(cos(a), 0.0, sin(a)) * r
		p.y = top - pitch * wound / (TAU * r)
		if d > wound or d < 0.0:
			# Past the coil (or ahead of its head), straight on along the turn.
			var back := Vector3(-sin(a), 0.0, cos(a)) * -_orbit
			p += back * (d - wound)
		return p
	var head: Vector3 = at.call(0.0)
	var ahead: Vector3 = at.call(-1.0)
	velocity = (ahead - head).normalized() * speed() * 0.35
	global_position = head
	face(ahead - head)
	var trail := PackedVector3Array()
	var d := length + 4.0
	while d > 0.0:
		trail.append(at.call(d))
		d -= 1.0
	_trail = trail
	rig.follow_trail(head, _trail, (at.call(length + 1.0) - at.call(length)).normalized())
	if _coil_from.size() == rig.points.size() and _coil_wrap < 1.0:
		var blend := smoothstep(0.0, 1.0, _coil_wrap)
		for s in rig.points.size():
			rig.points[s] = _coil_from[s].lerp(rig.points[s], blend)
		rig._frames()
	_pose_parts()
	_pose_riders()
	rig.apply()


## A fan of bolts at `at`.
func _spit(at: Vector3) -> void:
	var from := mouth_point()
	var aim := (at - from).normalized()
	var count := settings.leviathan_bolts
	var side := aim.cross(Vector3.UP).normalized()
	var directions := PackedVector3Array()
	for n in count:
		var offset := (n - (count - 1) * 0.5) * 0.14
		directions.append((aim + side * offset).normalized())
	add_bolts(from, directions)
	spat.emit(from, directions)


## Bolts from `from` along each of `directions`.
func add_bolts(from: Vector3, directions: PackedVector3Array) -> void:
	for direction in directions:
		_bolts.append({"at": from + direction * 2.0, "velocity": direction * BOLT_SPEED, "life": BOLT_LIFE})
		bolts_fired += 1


func _update_bolts(delta: float) -> void:
	var i := 0
	while i < _bolts.size():
		var bolt: Dictionary = _bolts[i]
		bolt.life -= delta
		bolt.at += bolt.velocity * delta
		var spent: bool = bolt.life <= 0.0
		if not spent:
			for fish in run.players:
				if not fish.puppet and run.is_up(fish) and fish.global_position.distance_to(bolt.at) <= UnnaturalRun.PLAYER_RADIUS + 0.45:
					run.hurt(fish, settings.leviathan_bolt_damage * settings.enemy_damage_scale, -1, "%s's bolt" % title.capitalize())
					spent = true
					break
		if spent:
			_bolts.remove_at(i)
		else:
			i += 1
	var multimesh := _bolt_mesh.multimesh
	if multimesh.instance_count < _bolts.size():
		multimesh.instance_count = maxi(_bolts.size(), 16)
	multimesh.visible_instance_count = _bolts.size()
	for b in _bolts.size():
		var spin := Basis(Vector3(0.3, 1.0, 0.2).normalized(), age * 6.0 + b)
		multimesh.set_instance_transform(b, Transform3D(spin, _bolts[b].at))


# --- Holding a player (the alternates) ---------------------------------------

## Grabs `fish` (a player played here): held at the mouth, drained
## final_hold_damage every 0.75 s, until they stride final_hold_strides times
## or final_hold_time runs out.
func hold(fish: FishController) -> void:
	if held or fish.puppet or not run.is_up(fish) or _regrab_left > 0.0:
		return
	held = fish
	hold_strides = 0
	_hold_left = settings.final_hold_time
	_drain_left = 0.4
	_catch_from = fish.global_position
	_catch_t = 0.0 if settings.grab_catch_time > 0.0 else 1.0
	_chomp_wind = 0.0
	_hold_hook = func(_timing: float, _flow: float) -> void:
		hold_strides += 1
		_held_strode()
	fish.strode.connect(_hold_hook)
	_caught(fish)
	held_changed.emit(fish, true)


## Lets go of the held player, flinging them clear, a moment untouchable.
func release() -> void:
	if held == null:
		return
	var fish := held
	held = null
	_regrab_left = 2.5
	if is_instance_valid(fish):
		if fish.strode.is_connected(_hold_hook):
			fish.strode.disconnect(_hold_hook)
		_let_go(fish)
		fish.apply_push(release_push(fish))
		var health := run.health_of(fish)
		if health:
			health.shield(1.0)
		held_changed.emit(fish, false)


func _update_hold(delta: float) -> void:
	_regrab_left = maxf(_regrab_left - delta, 0.0)
	if held == null:
		if grabs() and phase == Phase.FURY or (grabs() and _diving > 0.0):
			var mouth := mouth_point()
			for fish in run.local_players():
				if run.is_up(fish) and not run.is_picking(fish) and fish.global_position.distance_to(mouth) <= hold_reach():
					hold(fish)
					break
		return
	if not is_instance_valid(held) or not run.is_up(held) or dying:
		release()
		return
	_hold_left -= delta
	_catch_t = minf(_catch_t + delta / maxf(settings.grab_catch_time, 0.01), 1.0)
	var spot := hold_point()
	held.global_position = _catch_from.lerp(spot, smoothstep(0.0, 1.0, _catch_t)) if _catch_t < 1.0 else spot
	held.linear_velocity = velocity
	var health := run.health_of(held)
	if health:
		health.shield(0.1)  # nothing else bites it while it's held
	_drain_left -= delta
	if _drain_left <= 0.0:
		_drain_left = 0.75
		if health:
			health.iframes_left = 0.0
		run.hurt(held, settings.final_hold_damage * hold_drain_scale() * settings.enemy_damage_scale * run.stage_damage(), -1, title.capitalize())
	if hold_strides >= settings.final_hold_strides or _hold_left <= 0.0:
		release()


## How near its mouth a player must be to be grabbed (m).
func hold_reach() -> float:
	return settings.leviathan_girth * 0.8


# --- The body -----------------------------------------------------------------

## The spine follows the head's path; the proxies and riders sit along it.
func _pose() -> void:
	var head := global_position
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(head) > 0.25:
		_trail.append(head)
	# Trim the trail to what the body needs.
	var needed := body_length() + 4.0
	var length := 0.0
	var keep := _trail.size() - 1
	while keep > 0 and length < needed:
		length += _trail[keep].distance_to(_trail[keep - 1])
		keep -= 1
	if keep > 0:
		_trail = _trail.slice(keep)
	var back := -velocity.normalized() if velocity.length_squared() > 0.01 else global_basis.z
	rig.follow_trail(head, _trail, back)
	_pose_parts()
	_pose_riders()
	rig.apply()


## Its body laid along `trail` (oldest first), for screenshots (boss_shots).
func pose_for_shot(trail: PackedVector3Array) -> void:
	_trail = trail
	_pose()
	_glow_now()


## The proxies along the spine.
func _pose_parts() -> void:
	for n in parts.size():
		var frame := rig.frame_at(proxy_distance(n))
		run.horde.place(parts[n], frame.origin, -frame.basis.z)


func _pose_riders() -> void:
	for rider: Array in _riders:
		var node: Node3D = rider[0]
		if not is_instance_valid(node):
			continue
		var at: Vector3 = rider[1]
		var frame := rig.frame_at(at.z)
		var basis: Basis = rider[2]
		var sway: float = rider[3]
		if sway > 0.0:
			basis = Basis(Vector3.RIGHT, sin(age * 1.7 + at.z) * sway) * basis
		node.global_transform = Transform3D(frame.basis * basis, frame.origin + frame.basis.x * at.x + frame.basis.y * at.y)


## Beaten: the body sinks and dissolves; the bolts go; anyone held is let go.
func _process(delta: float) -> void:
	if not dying:
		return
	release()
	_bolts.clear()
	_bolt_mesh.multimesh.visible_instance_count = 0
	_dissolve = minf(_dissolve + delta / Boss.DEATH_TIME, 1.0)
	for s in rig.points.size():
		rig.points[s] += Vector3.DOWN * 3.0 * delta
	_pose_riders()
	rig.apply()
	for material in skins:
		material.set_shader_parameter("dissolve", _dissolve * 0.95)
	for rider: Array in _riders:
		if is_instance_valid(rider[0]):
			(rider[0] as Node3D).visible = _dissolve < 0.6


func _exit_tree() -> void:
	release()
	super()
