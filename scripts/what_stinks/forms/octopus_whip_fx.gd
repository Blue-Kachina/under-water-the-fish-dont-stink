class_name OctopusWhipFx
extends Node3D
## The look and sound of the Ember Octopus' Tendril Lash (WhipAttack, planning_new_hunters.md C3). Pure presentation: the attack
## calls it, it never decides anything. A child of the HunterBite (like HunterBiteFx), top level so everything sits in world space.
##
##   aura()        the targeting cone: a faint ember cone from the mouth with a bright band sweeping out along it (faster with charge)
##   lock_on()     a spark and a reticle ring on a target the instant it is locked; set_lock() follows it and tightens with the charge
##   drop_lock()   the reticle breaks off in a small spark
##   trail()       the glowing streak behind an arm in flight (tip bright, fading toward the base)
##   crack()       the whip-crack at the tip: a white flash, a shockwave ring facing the lash, sparks (more and brighter on a hit)
##   play()        a beat's sound (ids below; stand-ins live in SoundCatalog.FALLBACKS), or sound_log(beat, id) in a probe
##
## Everything is pooled: no node is made after the first use of each kind.

## Beat -> sound id (registered in SoundCatalog; stand-ins listed with the C3 log).
const SOUNDS := {
	&"flare": "octopus/flare", &"lock": "octopus/lock", &"lost": "octopus/lock_lost", &"whoosh": "octopus/lash", &"lash": "octopus/lash",
	&"crack": "octopus/crack", &"hit": "octopus/hit", &"miss": "octopus/miss",
}
const EMBER := Color(1.0, 0.55, 0.18, 1.0)
const HOT := Color(1.0, 0.92, 0.7, 1.0)
const VIOLET := Color(0.62, 0.35, 1.0, 1.0)
const FLASHES := 10
const RINGS := 10
const SPARKS := 5

## The bite this belongs to (set by the attack).
var hb: HunterBite
## Probes: called as (beat: String, id: String) instead of playing a sound.
var sound_log: Callable
## Counts, for probes.
var cracks := 0
var locks_shown := 0

var _flashes: Array[Dictionary] = []   # {node, age, life, size}
var _rings: Array[Dictionary] = []
var _spark_pool: Array[CPUParticles3D] = []
var _next_flash := 0
var _next_ring := 0
var _next_spark := 0
var _reticles: Array[MeshInstance3D] = []
var _reticle_seen: Array[float] = []
var _trails: Array[MeshInstance3D] = []
var _aura: MeshInstance3D
var _aura_mat: ShaderMaterial
var _aura_on := 0.0
var _aura_want := 0.0
var _loop := 0
var _built := false


func _ready() -> void:
	top_level = true
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	top_level = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i in FLASHES:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = _billboard(FxKit.dot(), HOT)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_flashes.append({"node": mi, "age": 99.0, "life": 0.15, "size": 1.0})
	for i in RINGS:
		var mi2 := MeshInstance3D.new()
		mi2.mesh = quad
		mi2.material_override = FxKit.glow(HOT, FxKit.band(), true)
		mi2.visible = false
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi2)
		_rings.append({"node": mi2, "age": 99.0, "life": 0.4, "size": 1.0})
	for i in SPARKS:
		_spark_pool.append(_make_sparks())
	for a in 8:
		var r := MeshInstance3D.new()
		r.mesh = quad
		r.material_override = _billboard(FxKit.band(), EMBER)
		r.visible = false
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(r)
		_reticles.append(r)
		_reticle_seen.append(0.0)
		var tr := MeshInstance3D.new()
		var m := FxKit.glow(Color(1.0, 0.7, 0.35, 0.9), FxKit.across(), true)
		m.vertex_color_use_as_albedo = true
		tr.material_override = m
		tr.visible = false
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tr)
		_trails.append(tr)
	_make_aura()


static func _billboard(texture: Texture2D, color: Color) -> StandardMaterial3D:
	var m := FxKit.glow(color, texture, true)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	return m


func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.45
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 9.0
	p.damping_min = 6.0
	p.damping_max = 11.0
	p.gravity = Vector3(0.0, 0.8, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var m := FxKit.glow(EMBER, FxKit.dot(), true)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	fade.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	p.color_ramp = fade
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


const AURA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform float sweep = 0.0;
uniform float strength = 0.0;
uniform float charge = 0.0;
varying float along;
void vertex() { along = clamp(-VERTEX.y + 0.5, 0.0, 1.0); }
void fragment() {
	// A cone along -Y of a unit-height cylinder: along 0 at the apex, 1 at the far rim.
	float band = exp(-pow((along - sweep) * 7.0, 2.0));
	float band2 = exp(-pow((along - fract(sweep + 0.5)) * 9.0, 2.0)) * (0.35 + 0.65 * charge);
	vec3 n = normalize(NORMAL);
	float rim = pow(1.0 - abs(dot(n, normalize(VIEW))), 1.6);
	float a = (0.05 + 0.5 * band + 0.3 * band2) * (0.35 + 0.65 * rim) * (1.0 - along * 0.5) * smoothstep(0.03, 0.4, along) * strength;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.9, 0.7), band * 0.6 + charge * 0.3);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


func _make_aura() -> void:
	_aura = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 28
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_aura.mesh = cone
	var shader := Shader.new()
	shader.code = AURA_SHADER
	_aura_mat = ShaderMaterial.new()
	_aura_mat.shader = shader
	_aura.material_override = _aura_mat
	_aura.visible = false
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)


# ------------------------------------------------------------------------------ calls from the attack

## The press: the crown flares. A burst of embers at the mouth and the charge loop.
func flare(origin: Vector3, _forward: Vector3) -> void:
	_build()
	_spark(origin, 0.7, EMBER)
	_aura_want = 1.0
	_start_loop()


## The targeting cone from `origin` along `forward`, `range_m` long, `half_deg` half-angle; `sweep` 0..1 is the bright band's place.
func aura(origin: Vector3, forward: Vector3, range_m: float, half_deg: float, sweep: float, charge: float) -> void:
	_build()
	_aura_want = 1.0
	var length := maxf(range_m, 0.1)
	var radius := length * tan(deg_to_rad(clampf(half_deg, 1.0, 85.0)))
	# The cylinder's axis is Y with its tip (radius 0) at +Y: turn that to point back to the apex; the base sits at the far end.
	var dir := forward.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x_axis := dir.cross(up).normalized()
	var z_axis := x_axis.cross(dir).normalized()
	var basis := Basis(x_axis * radius, -dir * length, z_axis * radius)
	_aura.global_transform = Transform3D(basis, origin + dir * length * 0.5)
	_aura.visible = true
	_aura_mat.set_shader_parameter("sweep", sweep)
	_aura_mat.set_shader_parameter("charge", charge)


func aura_off() -> void:
	_aura_want = 0.0
	if _aura != null:
		_aura.visible = false
	_stop_loop()
	for r in _reticles:
		r.visible = false


func lock_on(arm: int, at: Vector3) -> void:
	_build()
	locks_shown += 1
	_spark(at, 0.5, HOT)
	_flash(at, 0.9, 0.18, EMBER)
	var r := _reticles[arm]
	r.global_position = at
	r.visible = true
	_reticle_seen[arm] = 1.0


func set_lock(arm: int, at: Vector3, charge: float) -> void:
	if not _built:
		return
	var r := _reticles[arm]
	r.visible = true
	r.global_position = at
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012 + float(arm))
	var size := lerpf(1.5, 0.8, charge) * pulse
	r.scale = Vector3.ONE * size
	var m := r.material_override as StandardMaterial3D
	m.albedo_color = EMBER.lerp(HOT, charge)


func hide_lock(arm: int) -> void:
	if _built:
		_reticles[arm].visible = false


func drop_lock(arm: int, at: Vector3) -> void:
	if not _built:
		return
	_reticles[arm].visible = false
	_spark(at, 0.35, VIOLET)


## A streak along the arm (world points, base first) in flight: the tip end bright.
func trail(arm: int, points: PackedVector3Array, alpha: float) -> void:
	if not _built or points.size() < 2:
		return
	var reversed := PackedVector3Array()
	for i in range(points.size() - 1, -1, -1):
		reversed.append(points[i])
	var tr := _trails[arm]
	tr.mesh = FxKit.ribbons([reversed], [0.22 * alpha], true, true)
	tr.visible = true


func trail_off(arm: int) -> void:
	if _built and _trails[arm].visible:
		_trails[arm].visible = false
		_trails[arm].mesh = null


## The whip-crack at `at`: `dir` is the lash's heading, `power` ~1, `hit` a landed one.
func crack(at: Vector3, dir: Vector3, power: float, hit: bool) -> void:
	_build()
	cracks += 1
	_flash(at, 1.4 * power, 0.12, HOT)
	_ring(at, dir, 1.3 * power, 0.38, HOT if hit else EMBER)
	if hit:
		_ring(at, dir, 0.7 * power, 0.5, VIOLET)
		_flash(at, 2.2 * power, 0.2, EMBER)
	_spark(at, power * (1.0 if hit else 0.45), HOT if hit else EMBER)


func play(beat: StringName, at: Vector3, step := 0) -> void:
	var id: String = SOUNDS.get(beat, "")
	if id == "":
		return
	if sound_log.is_valid():
		sound_log.call(String(beat), id)
		return
	if not is_inside_tree():
		return
	if beat == &"lock" or beat == &"hit":
		Sfx.play_pitched(id, mini(step, 12), at, 0.8)
	else:
		Sfx.play_at(id, at, 1.0)


# ------------------------------------------------------------------------------ internals

func _flash(at: Vector3, size: float, life: float, color: Color) -> void:
	var f: Dictionary = _flashes[_next_flash]
	_next_flash = (_next_flash + 1) % FLASHES
	var mi := f["node"] as MeshInstance3D
	mi.global_position = at
	(mi.material_override as StandardMaterial3D).albedo_color = color
	f["age"] = 0.0
	f["life"] = life
	f["size"] = size
	mi.visible = true


func _ring(at: Vector3, normal: Vector3, size: float, life: float, color: Color) -> void:
	var r: Dictionary = _rings[_next_ring]
	_next_ring = (_next_ring + 1) % RINGS
	var mi := r["node"] as MeshInstance3D
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	var x_axis := n.cross(up).normalized()
	var y_axis := n.cross(x_axis).normalized()
	mi.global_transform = Transform3D(Basis(x_axis, y_axis, n), at)  # the quad faces the lash's heading
	(mi.material_override as StandardMaterial3D).albedo_color = color
	r["age"] = 0.0
	r["life"] = life
	r["size"] = size
	mi.visible = true


func _spark(at: Vector3, power: float, color: Color) -> void:
	if power <= 0.0:
		return
	var p := _spark_pool[_next_spark]
	_next_spark = (_next_spark + 1) % SPARKS
	p.global_position = at
	p.scale_amount_min = 0.7 * power
	p.scale_amount_max = 1.3 * power
	p.color = color
	p.restart()


func _process(delta: float) -> void:
	if not _built:
		return
	for f in _flashes:
		var age: float = f["age"]
		if age > float(f["life"]):
			(f["node"] as MeshInstance3D).visible = false
			continue
		age += delta
		f["age"] = age
		var x := clampf(age / float(f["life"]), 0.0, 1.0)
		var node := f["node"] as MeshInstance3D
		node.scale = Vector3.ONE * float(f["size"]) * (0.4 + 1.6 * sqrt(x)) * (1.0 - x * x)
	for r in _rings:
		var age_r: float = r["age"]
		if age_r > float(r["life"]):
			(r["node"] as MeshInstance3D).visible = false
			continue
		age_r += delta
		r["age"] = age_r
		var xr := clampf(age_r / float(r["life"]), 0.0, 1.0)
		var node_r := r["node"] as MeshInstance3D
		node_r.scale = Vector3.ONE * float(r["size"]) * (0.2 + 2.6 * (1.0 - pow(1.0 - xr, 3.0)))
		var m := node_r.material_override as StandardMaterial3D
		m.albedo_color.a = 1.0 - xr * xr
	_aura_on = move_toward(_aura_on, _aura_want, delta * 6.0)
	if _aura_mat != null:
		_aura_mat.set_shader_parameter("strength", _aura_on)
	if hb != null and is_instance_valid(hb) and _loop != 0:
		Sfx.set_loop(_loop, clampf(lerpf(0.4, 0.95, hb.charge()), 0.0, 1.0), lerpf(0.8, 1.6, hb.charge()))


func _start_loop() -> void:
	_stop_loop()
	if hb == null or not is_instance_valid(hb.fish) or not is_inside_tree():
		return
	if sound_log.is_valid():
		sound_log.call("charge", "octopus/charge")
		return
	_loop = Sfx.start_loop("octopus/charge", hb.fish)


func _stop_loop() -> void:
	if _loop != 0:
		Sfx.stop_loop(_loop, 0.12)
		_loop = 0


func _exit_tree() -> void:
	_stop_loop()


## Ids this FX plays (for the sound catalog registration).
static func sound_ids() -> Array[String]:
	var out: Array[String] = ["octopus/charge"]
	for id: String in SOUNDS.values():
		if not out.has(id):
			out.append(id)
	return out
