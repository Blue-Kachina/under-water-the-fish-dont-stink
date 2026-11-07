extends Node3D
## The Whale Fall's body on a Hunter's fish (a child of the fish's model): a dead whale carrying giant
## hagfish, each a rope bent by a SpineRig, in the model's own space and driven by the fish's own motion
## instead of the boss's AI. The carcass is rigid (as the boss's): it rocks and leans into turns. The
## hagfish trail the swim (they stream back from the speed and lag each turn). The bite is theirs: on its
## wind-up they rear back and glow, as the jaws shut they lash into the cone and tie a knot that slides down
## the body, and a cloud of slime is let go where the cone ends (`slimed`, for the mode to scatter fish with).

## The slime was let go: world point, radius (m), how long it hangs (s).
signal slimed(at: Vector3, radius: float, life: float)

const MODEL := preload("res://scripts/what_stinks/forms/whalefall_model.gd")
const JAW := preload("res://scripts/what_stinks/forms/whalefall_jaw.gd")
const SKIN := preload("res://shaders/boss_hagfish.gdshader")
const ROPE := 20
const IDLE := 0
const WIND := 1
const LASH := 2

## How many hagfish (the carcass has six holes).
@export_range(0, 6, 1) var ropes := 6
## How hard the carcass rocks at rest and at full speed (rad), and how far it leans into a turn (rad per rad/s).
@export_range(0.0, 0.5, 0.01, "or_greater") var rock_idle := 0.03
@export_range(0.0, 0.5, 0.01, "or_greater") var rock_swim := 0.07
@export_range(0.0, 0.5, 0.01, "or_greater") var lean := 0.07
## How far the hagfish stream back at full speed and sway at rest (x their length).
@export_range(0.0, 1.5, 0.05, "or_greater") var stream := 0.45
@export_range(0.0, 0.5, 0.01, "or_greater") var sway := 0.16
## The lash: how long the hagfish take to reach into the cone, and how long they hold the knot (s).
@export_range(0.05, 3.0, 0.05, "or_greater") var lash_time := 0.3
@export_range(0.1, 5.0, 0.05, "or_greater") var knot_time := 1.0
## The speed the swim is full at (x the fish's top boost speed).
@export_range(0.1, 2.0, 0.05, "or_greater") var full_speed := 0.6
## How long the slime cloud hangs (s), and the stand-in sound id played when it is let go ("" for none).
@export_range(0.2, 20.0, 0.1, "or_greater") var cloud_life := 3.5
@export var slime_sound := ""

var fish: FishController
var sheet := {}
var jaw: JAW
var unit := 0.02
var carcass: MeshInstance3D
var xf := Transform3D.IDENTITY
var skins: Array[ShaderMaterial] = []
var hagfish: Array[Rope] = []
var cloud: CPUParticles3D
var light: OmniLight3D
## What the swim reads now: 0 to 1 of full speed.
var speed_frac := 0.0
## 0 idle, 1 winding up, 2 lashing.
var state := IDLE
## Seconds into the lash, whether its slime has been let go, and the cloud's last place (world) and radius.
var lash_t := 0.0
var slimed_yet := false
var cloud_at := Vector3.ZERO
var cloud_radius := 0.0
var cloud_left := 0.0
var age := 0.0

var _exits: Array = []
var _peak := 0.0
var _bite: HunterBite
var _turn := Vector2.ZERO
var _local_velocity := Vector3.ZERO
var _last_basis := Basis.IDENTITY
var _last_at := Vector3.ZERO
var _speed := 0.0
var _fresh := true
var _length := 26.0


## One hagfish.
class Rope:
	var index := 0
	var rig: SpineRig
	var skin: ShaderMaterial
	var mesh: MeshInstance3D
	var nodes := PackedVector3Array()
	var head := Vector3.ZERO
	var phase := 0.0
	var knot := 0.0
	var knot_size := 0.0


func setup(for_fish: FishController, for_sheet: Dictionary) -> void:
	name = "WhaleFall"
	fish = for_fish
	sheet = for_sheet
	unit = FishCharacter.hitbox_size(FishCharacter.FishClass.MONSTER).z / MODEL.LENGTH * 0.97
	scale = Vector3.ONE * unit
	_length = MODEL.HAG_LENGTH
	var look: Dictionary = MODEL.build()
	xf = look.xf
	_exits = look.exits
	var body_skin: ShaderMaterial = look.skin
	skins.append(body_skin)
	carcass = MeshInstance3D.new()
	carcass.name = "Carcass"
	carcass.mesh = look.mesh
	carcass.material_override = body_skin
	carcass.transform = xf
	carcass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(carcass)
	for i in ropes:
		var h := Rope.new()
		h.index = i
		h.phase = i * 1.7
		h.rig = SpineRig.new(_length, _length * 0.2)
		h.skin = ShaderMaterial.new()
		h.skin.shader = SKIN
		h.skin.set_shader_parameter("radius", MODEL.HAG_RADIUS)
		h.skin.set_shader_parameter("spine_wave", Vector4(0.35, 0.5, 3.0, 0.4))
		h.skin.set_shader_parameter("flutter", Vector3(0.25, 2.2, 6.0))
		h.skin.set_shader_parameter("flutter_phase", i * 1.3)
		h.mesh = MeshInstance3D.new()
		h.mesh.name = "Hagfish%d" % i
		h.mesh.mesh = look.hag_mesh
		h.mesh.material_override = h.skin
		h.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h.mesh)
		h.rig.materials.append(h.skin)
		h.rig.instances.append(h.mesh)
		skins.append(h.skin)
		h.head = _anchor(i) + _out(i) * _length * 0.6
		hagfish.append(h)
	# The mouth: near the carcass's nose, in the model's space (not ours).
	jaw = JAW.new()
	jaw.mouth_at = (xf * Vector3(0.0, 0.0, 0.5)) * unit
	# The slime: a puff of sickly cloud left hanging in the water where it was let go (world space, so it stays as the Hunter swims on).
	cloud = _cloud_particles()
	fish.add_child(cloud)
	# A dull green glow from the torn chest, so it reads in the murk.
	light = OmniLight3D.new()
	light.name = "Gloom"
	light.light_color = Color(0.7, 0.85, 0.4)
	light.light_energy = 1.2
	light.position = xf * Vector3(0.0, 0.0, 0.45 * MODEL.LENGTH)
	add_child(light)
	for _step in 40:
		_step_ropes(0.05, false)
	_pose_ropes()


func _exit_of(i: int) -> Array:
	return _exits[i % _exits.size()] as Array


func _anchor(i: int) -> Vector3:
	return xf * (_exit_of(i)[0] as Vector3)


func _out(i: int) -> Vector3:
	return (xf.basis * (_exit_of(i)[1] as Vector3)).normalized()


## The slime puff: world-space billboards that swell and fade (sized and placed when let go).
func _cloud_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "SlimeCloud"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 40
	p.lifetime = cloud_life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.0
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.6
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.gravity = Vector3(0.0, 0.1, 0.0)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.15, Color(1.0, 1.0, 1.0, 0.55))
	fade.add_point(0.6, Color(1.0, 1.0, 1.0, 0.35))
	p.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.vertex_color_use_as_albedo = true
	look.albedo_color = Color(0.78, 0.82, 0.45)
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	soft.gradient = ramp
	look.albedo_texture = soft
	puff.material = look
	p.mesh = puff
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _process(delta: float) -> void:
	if not is_instance_valid(fish) or delta <= 0.0 or not is_visible_in_tree():
		return
	age += delta
	var basis := fish.global_basis.orthonormalized()
	var at := fish.global_position
	if _fresh or at.distance_to(_last_at) > 20.0 or (basis * _last_basis.inverse()).get_rotation_quaternion().get_angle() > 1.0:  # the first frame, or put somewhere new
		_fresh = false
		_last_basis = basis
		_last_at = at
		_turn = Vector2.ZERO
		_local_velocity = Vector3.ZERO
	var spin := (basis * _last_basis.inverse()).get_rotation_quaternion()
	var angle := spin.get_angle()
	var omega := Vector3.ZERO
	if angle > 0.0001:
		omega = spin.get_axis() * (angle if angle < PI else angle - TAU) / delta
	_turn = _turn.lerp(Vector2(omega.dot(basis.y), omega.dot(basis.x)).limit_length(8.0), 1.0 - exp(-10.0 * delta))
	var world_velocity := (at - _last_at) / delta
	_local_velocity = _local_velocity.lerp(basis.inverse() * world_velocity, 1.0 - exp(-6.0 * delta))
	_speed = _local_velocity.length()
	_last_basis = basis
	_last_at = at
	speed_frac = clampf(_speed / maxf(fish.max_boost_speed * fish.top_speed_scale * full_speed, 0.1), 0.0, 1.0)
	_hook_bite()
	_follow_bite(delta)
	_rock()
	_step_ropes(delta, true)
	_pose_ropes()
	cloud_left = maxf(cloud_left - delta, 0.0)
	light.omni_range = 0.5 * fish.hitbox_length


## The slime lets go the instant a bite lands (a snap chomp may open and shut between two frames).
func _hook_bite() -> void:
	if _bite != null and is_instance_valid(_bite):
		return
	_bite = fish.get_node_or_null("HunterBite") as HunterBite
	if _bite == null:
		return
	_bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void:
		if state != LASH:
			state = LASH
			lash_t = 0.0
			slimed_yet = true
			_let_go())


## The bite's phase from how open the jaw is: winding up while it opens, lashing once it starts to shut.
func _follow_bite(delta: float) -> void:
	var open := jaw.opened
	match state:
		IDLE:
			if open > 0.05:
				state = WIND
				_peak = open
		WIND:
			_peak = maxf(_peak, open)
			if open < _peak - 0.01 and _peak > 0.2:
				state = LASH
				lash_t = 0.0
				slimed_yet = false
			elif open < 0.02:
				state = IDLE
		LASH:
			lash_t += delta
			if not slimed_yet and open < 0.15:
				slimed_yet = true
				_let_go()
			if lash_t > lash_time + knot_time and open < 0.02:
				state = IDLE
				_peak = 0.0
			elif open > 0.05 and lash_t > 0.5:  # a new bite already
				state = WIND
				_peak = open


## The slime goes where the cone ends: a cloud in the water and a call for the mode to scatter fish.
func _let_go() -> void:
	var size := HunterSize.shared()
	var reach := size.bite_reach(fish, sheet)
	var radius := size.bite_radius(fish, sheet)
	var model := get_parent() as Node3D
	var mouth := model.to_global(jaw.mouth_local())
	cloud_at = mouth - fish.global_basis.z.normalized() * reach * 0.7
	cloud_radius = radius * 0.8
	cloud_left = cloud_life
	cloud.lifetime = cloud_life
	cloud.position = fish.to_local(cloud_at)
	cloud.emission_sphere_radius = cloud_radius * 0.6
	(cloud.mesh as QuadMesh).size = Vector2.ONE * cloud_radius * 1.1
	cloud.initial_velocity_max = cloud_radius * 0.3
	cloud.restart()
	cloud.emitting = true
	if slime_sound != "":
		Sfx.play_at(slime_sound, cloud_at)
	slimed.emit(cloud_at, cloud_radius, cloud_life)


## The carcass rocks gently and leans into the turn.
func _rock() -> void:
	var rocking := lerpf(rock_idle, rock_swim, speed_frac)
	var roll := sin(age * 1.1) * rocking
	var yaw := clampf(-_turn.x * lean, -0.3, 0.3) + sin(age * 0.7 + 1.0) * rocking * 0.5
	var pitch := clampf(_turn.y * lean, -0.3, 0.3) + sin(age * 0.9) * rocking * 0.5
	carcass.transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3.ZERO) * xf


## Where hagfish `i` reaches in a lash, in the rig's own space: in the cone, spread about its axis.
func _aim(i: int, count: int) -> Vector3:
	var size := HunterSize.shared()
	var gs := maxf(global_basis.get_scale().x, 0.0001)
	var reach := size.bite_reach(fish, sheet) / gs
	var radius := size.bite_radius(fish, sheet) / gs
	var mouth := jaw.mouth_local() / unit
	var around := TAU * i / float(maxi(count, 1)) + 0.4
	var along := lerpf(0.5, 0.9, (i % 3) / 2.0)
	return mouth + Vector3(0.0, 0.0, -1.0) * reach * along + (Vector3.RIGHT * cos(around) + Vector3.UP * sin(around)) * radius * 0.5 * along


func _step_ropes(delta: float, live: bool) -> void:
	var drag_dir := -_local_velocity.normalized() if _local_velocity.length() > 0.1 else Vector3.ZERO
	var open := jaw.opened if live else 0.0
	var wind := clampf(open, 0.0, 1.0) if state == WIND else 0.0
	for h in hagfish:
		var anchor := _anchor(h.index)
		var out := _out(h.index)
		var sway_v := Vector3(sin(age * 0.7 + h.phase), sin(age * 0.9 + h.phase * 1.3) * 0.6, cos(age * 0.6 + h.phase)) * _length * sway
		var streaming := drag_dir * speed_frac * _length * stream + Vector3(-_turn.x, _turn.y, 0.0) * _length * 0.06
		var rest := anchor + out * _length * 0.55 + sway_v + streaming
		var want := rest
		var rate := 2.5
		var knot_r := 0.0
		var scale_rope := 1.0
		if state == WIND:
			# Rear back toward the hole and coil, glowing.
			want = rest.lerp(anchor + out * _length * 0.28 + sway_v * 0.4, wind)
			rate = 5.0
		if state == LASH:
			want = _aim(h.index, hagfish.size())
			rate = 16.0 if lash_t < lash_time else 6.0
			var u := clampf((lash_t - lash_time) / knot_time, 0.0, 1.0)
			h.knot = smoothstep(0.0, 1.0, u)
			h.knot_size = sin(PI * u)
			knot_r = _length * 0.07 * h.knot_size
			scale_rope = 1.0 - 0.3 * h.knot_size
		else:
			h.knot = 0.0
			h.knot_size = 0.0
		var gap := want - anchor
		if gap.length() > _length * 0.96:
			want = anchor + gap.normalized() * _length * 0.96
		h.head = h.head.lerp(want, 1.0 - exp(-rate * maxf(delta, 0.0)))
		_solve(h, anchor, out, scale_rope)
		h.rig.follow_chain(_knotted(h, knot_r) if knot_r > 0.01 else h.nodes)
		var warn := 0.0
		if state == WIND:
			warn = (0.5 + 0.5 * sin(age * 26.0)) * clampf(open * 1.5, 0.0, 1.0) * 0.8
		h.skin.set_shader_parameter("warn", warn)
		var swim := lerpf(0.7, 1.5, speed_frac)
		h.skin.set_shader_parameter("spine_wave", Vector4(0.35 * swim, 0.5, 3.0, 0.4))


func _pose_ropes() -> void:
	for h in hagfish:
		h.rig.apply()


## A hagfish's rope (the boss's solver): its head where it is, its tail end in the carcass, every link its
## length (times `scale_rope`), slack bowing outward and up.
func _solve(h: Rope, anchor: Vector3, out: Vector3, scale_rope: float) -> void:
	var link := _length * scale_rope / float(ROPE - 1)
	if h.nodes.size() != ROPE:
		h.nodes.resize(ROPE)
		for n in ROPE:
			h.nodes[n] = h.head.lerp(anchor, n / float(ROPE - 1))
	h.nodes[0] = h.head
	h.nodes[ROPE - 1] = anchor
	for n in range(1, ROPE - 1):
		h.nodes[n] += (out * 0.5 + Vector3.UP * 0.2) * link * 0.04
	for _smooth in 2:
		for n in range(1, ROPE - 1):
			h.nodes[n] = h.nodes[n].lerp((h.nodes[n - 1] + h.nodes[n + 1]) * 0.5, 0.35)
	for _pass in 10:
		for n in range(1, ROPE):
			var a := h.nodes[n - 1]
			var b := h.nodes[n]
			var gap := b - a
			var d := gap.length()
			if d < 0.0001:
				continue
			var fix := gap * (1.0 - link / d)
			var pin_b := n == ROPE - 1
			if n - 1 == 0:
				if not pin_b:
					h.nodes[n] = b - fix
			elif pin_b:
				h.nodes[n - 1] = a + fix
			else:
				h.nodes[n - 1] = a + fix * 0.5
				h.nodes[n] = b - fix * 0.5
		h.nodes[ROPE - 1] = anchor
		h.nodes[0] = h.head


## The rope with its knot: a loop tied at `knot` of the way from its tail to its head (the boss's).
func _knotted(h: Rope, r: float) -> PackedVector3Array:
	var n := h.nodes.size()
	var k := clampi(roundi(lerpf(n - 4.0, 3.0, smoothstep(0.0, 1.0, h.knot))), 2, n - 3)
	var at := h.nodes[k]
	var tailward := (h.nodes[k + 1] - h.nodes[k - 1]).normalized()
	var side := tailward.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = tailward.cross(Vector3.RIGHT)
	side = side.normalized()
	var lift_v := side.cross(tailward).normalized()
	var shift := MODEL.HAG_RADIUS * 2.3
	var path := PackedVector3Array()
	for i in k + 1:
		path.append(h.nodes[i])
	var steps := 14
	for j in range(1, steps + 1):
		var a := TAU * j / steps
		path.append(at + lift_v * r * (1.0 - cos(a)) + tailward * r * sin(a) + side * shift * a / TAU)
	for i in range(k + 1, n):
		var fade := 1.0 - float(i - k) / float(n - 1 - k)
		path.append(h.nodes[i] + side * shift * fade)
	return path
