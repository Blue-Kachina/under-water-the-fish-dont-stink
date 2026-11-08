extends Node
## The Lamprey Queen's Battletoads-style drill (planning_new_hunters.md B6), driven by AttackExaggerate. It lives beside the
## rig (a child of lamprey_rig.gd's node, made by lamprey_jaw.gd the first time the bite poses the disc) and runs AFTER the rig's
## own _process each frame, so it only ever adds to what the rig just posed:
##   disc     the oral disc flares wide (the skin's `disc`, which the shader turns into a radius), pinches on the press, snaps wider on the
##            release and stays flared through the dash
##   teeth    the whole disc (its rings of hooked teeth and the rasp) spins: backwards a hair on the press (anticipation), up to speed on the hold,
##            faster still on the release and the dash (the shader's `disc_spin`, added here by patching a copy of the skin shader)
##   body     the spine telescopes: it draws in and fattens as the charge winds (a coiled spring), shoots out long and thin on the release and
##            through the dash, then rings back to rest (the spine points are scaled about the head, and the riders re-seated)
## Beats come from the HunterBite (opened, aborted, landed and its phase), so a guest's puppet plays the host's. Hit-stop on contact freezes this
## script's own clocks (the spin) for a few ticks; the camera punch is the kit's signal, converted here.
## Not a class_name: the Lamprey form's jaw preloads it.

const SKIN := preload("res://shaders/boss_lamprey.gdshader")
const KIT := preload("res://scripts/what_stinks/attack_exaggerate.gd")

## Per-channel look of the drill (AttackExaggerate channel keys). disc: flare factor. body: length factor (below 1 is drawn in).
## spin: a multiplier on the teeth's spin (the rate is (scale - 1) x lamprey_teeth_spin rad/s, so below 1 it winds backwards).
const PRESET := {
	"channels": {
		"disc": {"hold_peak": 2.3, "squash": 0.72, "release_peak": 2.6, "omega": 17.0, "zeta": 0.34, "volume": 0.0},
		"body": {"hold_peak": 0.72, "squash": 0.88, "release_peak": 1.5, "omega": 13.0, "zeta": 0.36, "volume": 0.0},
		"spin": {"hold_peak": 3.0, "squash": 0.6, "release_peak": 4.5, "omega": 10.0, "zeta": 0.55, "volume": 0.0},
	},
	"antic_time": 0.14, "snap_time": 0.1, "snap_omega": 36.0,
}

## Panel settings (tolerant: a missing property falls back to the default; a meta of the same name on the settings stands in for a probe).
## id -> [default, min, max]. Registered in WhatStinksSettings by the orchestrator (see the B6 log).
const SETTINGS := {
	"lamprey_disc_flare": [1.35, 0.0, 6.0],
	"lamprey_teeth_spin": [7.0, 0.0, 40.0],
	"lamprey_telescope_max": [1.9, 1.0, 4.0],
	"lamprey_dash_stretch": [1.3, 1.0, 2.5],
	"lamprey_dash_flare": [1.7, 1.0, 4.0],
	"lamprey_dash_spin": [14.0, 0.0, 60.0],
}

static var _shader_cache: Shader = null
static var _shader_tried := false

var rig: Node3D
var ex: KIT
var bite: HunterBite
## Teeth spin now (rad), the dash's smoothed envelope (0..1), and the multiple of the rest radius the exaggerated parts reach (cameras).
var spin_angle := 0.0
var dash_k := 0.0
var reach_mult := 1.0
## Whether the skin shader took the patch (the teeth spin and the girth need it), and the stretch and girth shown now.
var patched := false
var stretch := 1.0
var girth := 1.0
var disc_shown := 0.0
## The settings object the numbers come from (the probe swaps it); null: WhatStinksSettings.shared().
var settings_source: Object = null
var _active := false
var _prev_phase := -1
var _connected: HunterBite = null


func _init() -> void:
	name = "LampreyExaggerate"
	process_priority = 100  # after the rig (and everything else at 0): this only adds to the pose the rig just made


## A patched copy of the Queen's skin shader with `disc_spin` (the oral disc turning, from the lip back over the disc) and `girth`
## (the body's width) added. One Shader for all Queens; null if the skin's text is not what the patch expects (the exaggeration
## then keeps the flare and the telescope's length but not the spin or the width).
static func patched_shader() -> Shader:
	if _shader_tried:
		return _shader_cache
	_shader_tried = true
	var code := SKIN.code
	var anchor_uniform := "uniform float disc_len = 6.0;"
	var old_vertex := "\tif (VERTEX.z < disc_len) {\n\t\tfloat m = 1.0 - max(VERTEX.z, 0.0) / max(disc_len, 0.01);\n\t\tVERTEX.xy *= 1.0 + disc * 0.4 * m * m;\n\t}\n"
	var new_vertex := "\tVERTEX.xy *= girth;\n\tif (VERTEX.z < disc_len) {\n\t\tfloat m = 1.0 - max(VERTEX.z, 0.0) / max(disc_len, 0.01);\n\t\tVERTEX.xy *= 1.0 + disc * 0.4 * m * m;\n\t\tfloat a = disc_spin * smoothstep(0.35, 0.72, m);\n\t\tfloat ca = cos(a);\n\t\tfloat sa = sin(a);\n\t\tVERTEX.xy = vec2(ca * VERTEX.x - sa * VERTEX.y, sa * VERTEX.x + ca * VERTEX.y);\n\t\tNORMAL.xy = vec2(ca * NORMAL.x - sa * NORMAL.y, sa * NORMAL.x + ca * NORMAL.y);\n\t}\n"
	if not code.contains(anchor_uniform) or not code.contains(old_vertex):
		push_warning("LampreyExaggerate: boss_lamprey.gdshader changed; the teeth spin and girth are off")
		return null
	code = code.replace(anchor_uniform, anchor_uniform + "\nuniform float disc_spin = 0.0;  // rad, the oral disc turning (lamprey_exaggerate.gd)\nuniform float girth = 1.0;  // the body's width (lamprey_exaggerate.gd)")
	code = code.replace(old_vertex, new_vertex)
	var shader := Shader.new()
	shader.code = code
	_shader_cache = shader
	return shader


## A numeric panel setting (clamped to its range), `fallback` when unknown.
func setting(id: String) -> float:
	var spec: Array = SETTINGS[id]
	var source: Object = settings_source if settings_source != null else WhatStinksSettings.shared()
	var v: Variant = source.get(id)
	if v == null and source.has_meta(id):
		v = source.get_meta(id)
	return clampf(float(v), spec[1], spec[2]) if v != null else float(spec[0])


## The exaggeration's reach on cameras: the largest multiple of the rest body the part now shows (flare radius or stretch).
func camera_margin(radius: float) -> float:
	return radius * maxf(1.0, reach_mult)


func _master() -> float:
	var source: Object = settings_source if settings_source != null else WhatStinksSettings.shared()
	var v: Variant = source.get("hunter_exaggeration")
	if v == null and source.has_meta("hunter_exaggeration"):
		v = source.get_meta("hunter_exaggeration")
	return maxf(float(v), 0.0) if v != null else 1.0


func _ready() -> void:
	_setup()


func _setup() -> void:
	if rig == null or ex != null:
		return
	var form := {}
	var fish: FishController = rig.get("fish")
	if fish != null and fish.has_meta("ws_bite") and is_instance_valid(fish.get_meta("ws_bite")):
		form = (fish.get_meta("ws_bite") as HunterBite).form
	var form_params := {"exaggerate": PRESET, "exaggeration": float(form.get("exaggeration", 1.0))}
	var source: Object = settings_source if settings_source != null else WhatStinksSettings.shared()
	ex = KIT.new(KIT.params_from(source, form_params))
	ex.set_strength(_master(), float(form_params["exaggeration"]))
	ex.camera_punch.connect(_on_punch)
	var shader := patched_shader()
	var skin: ShaderMaterial = rig.get("skin")
	if shader != null and skin != null:
		skin.shader = shader
		patched = true
	if rig.get("rig") != null:
		(rig.get("rig") as SpineRig).reach = maxf((rig.get("rig") as SpineRig).reach, float(rig.get("radius")) * 5.0)  # the flared disc and the stretched body stay inside the bounds


func _on_punch(amount: float, dir: Vector3) -> void:
	var fish: FishController = rig.get("fish")
	if fish == null or fish.puppet:
		return
	var camera := ChompKit.view_camera(fish)
	if camera != null:
		camera.call("punch", amount, dir)


func _find_bite() -> void:
	var fish: FishController = rig.get("fish")
	var found := fish.get_node_or_null("HunterBite") as HunterBite if fish != null else null
	if found == bite:
		return
	bite = found
	if bite == null or _connected == bite:
		return
	_connected = bite
	bite.opened.connect(_on_opened)
	bite.aborted.connect(_on_aborted)
	bite.landed.connect(_on_landed)
	if ex != null:
		_setup_form(bite)


func _setup_form(with_bite: HunterBite) -> void:
	ex.set_strength(_master(), float(with_bite.form.get("exaggeration", 1.0)))


func _on_opened() -> void:
	if ex != null:
		ex.press()


func _on_aborted() -> void:
	if ex != null:
		ex.abort()


func _on_landed(taken: int) -> void:
	if ex == null:
		return
	var cap := float(maxi(bite.capacity(), 1)) if bite != null else 1.0
	ex.contact(clampf(float(taken) / cap, 0.2, 1.0) if taken > 0 else 0.2)


func _process(delta: float) -> void:
	if rig == null or not is_instance_valid(rig) or not is_instance_valid(rig.get("fish")) or not rig.is_visible_in_tree():
		return
	step(delta)


## One frame, after the rig posed (public so a probe can drive it with a fixed delta).
func step(delta: float) -> void:
	if ex == null:
		_setup()
	if ex == null:
		return
	_find_bite()
	var strength_now := _master()
	if not is_equal_approx(strength_now, ex.strength):
		ex.set_strength(strength_now, float(bite.form.get("exaggeration", 1.0)) if bite != null else 1.0)
	_read_beats()
	var dt := ex.tick(delta)
	var drill: DrillAttack = bite.attack as DrillAttack if bite != null else null
	var env := drill.dash_envelope() if drill != null else 0.0
	dash_k = lerpf(dash_k, env, 1.0 - exp(-(14.0 if env > dash_k else 5.0) * delta))
	if dash_k < 0.001:
		dash_k = 0.0
	var s := ex.strength
	var s_disc := ex.scale_of(&"disc")
	var s_body := ex.scale_of(&"body")
	var s_spin := ex.scale_of(&"spin")
	# The teeth: a rate off the spin channel's departure from 1 (reverses on the press's dip) and the dash's sustained turn.
	var rate := (s_spin - 1.0) * setting("lamprey_teeth_spin") + dash_k * s * setting("lamprey_dash_spin")
	if absf(rate) < 0.3:
		# Slowed to a stop: the disc eases to the nearest whole turn so no twist is left in the skin at rest.
		var home := roundf(spin_angle / TAU) * TAU
		spin_angle = lerpf(spin_angle, home, 1.0 - exp(-7.0 * dt))
		if absf(spin_angle - home) < 0.004:
			spin_angle = home
	else:
		spin_angle += rate * dt
	spin_angle = fposmod(spin_angle, TAU * 8.0)
	# The telescope: the kit's length factor, with the dash's sustained stretch on top, within the setting's cap.
	var dash_stretch := 1.0 + (setting("lamprey_dash_stretch") - 1.0) * dash_k * s
	var cap := setting("lamprey_telescope_max")
	var want_stretch := clampf(s_body * dash_stretch, 0.5, cap)
	var want_girth := clampf(pow(want_stretch, -0.45), 0.78, 1.3)
	var skin: ShaderMaterial = rig.get("skin")
	var base_disc := float(skin.get_shader_parameter("disc"))
	var flare := (s_disc - 1.0) + (setting("lamprey_dash_flare") - 1.0) * dash_k * s
	var flare_k := setting("lamprey_disc_flare")
	var want_disc := base_disc + flare * flare_k
	var turned := absf(spin_angle - roundf(spin_angle / TAU) * TAU) > 0.0005
	var moving := absf(flare) > 0.003 or absf(want_stretch - 1.0) > 0.003 or absf(rate) > 0.01 or dash_k > 0.0 or turned
	if not moving and not _active:
		stretch = 1.0
		girth = 1.0
		reach_mult = 1.0
		_publish(1.0)
		return
	_active = moving
	stretch = want_stretch
	girth = want_girth
	disc_shown = want_disc
	skin.set_shader_parameter("disc", want_disc)
	if patched:
		skin.set_shader_parameter("disc_spin", fposmod(spin_angle, TAU))
		skin.set_shader_parameter("girth", girth)
	skin.set_shader_parameter("breath", float(skin.get_shader_parameter("breath")) + 0.25 * maxf(s_spin - 1.0, 0.0) * minf(s, 1.5) + 0.25 * dash_k)
	var spine: SpineRig = rig.get("rig")
	if absf(stretch - 1.0) > 0.002:
		var head: Vector3 = spine.points[0]
		for i in range(1, SpineRig.SPINE_N):
			spine.points[i] = head + (spine.points[i] - head) * stretch
		spine.call("_frames")
		spine.apply()
		_reseat_riders(spine)
	elif absf(girth - 1.0) > 0.002:
		_reseat_riders(spine)
	var flare_radius := 1.0 + 0.4 * maxf(want_disc, 0.0)
	reach_mult = maxf(maxf(flare_radius / 1.4, stretch), 1.0)
	_publish(reach_mult)


## Beat detection off the bite's phase: the press is the `opened` signal, the release is the strike (held, tapped or snapped alike).
func _read_beats() -> void:
	if bite == null or bite.bite == null:
		return
	var phase: int = bite.bite.phase
	if bite.holding() and bite.bite.held_open:
		ex.hold(bite.charge())
	elif phase == ChompKit.Phase.ANTICIPATE or phase == ChompKit.Phase.GAPE or phase == ChompKit.Phase.HOLD:
		ex.hold(clampf(bite.bite.t / maxf(bite.bite.wind, 0.05), 0.0, 1.0))  # a tapped wind-up: the swell follows its clock
	if phase == ChompKit.Phase.STRIKE and _prev_phase != ChompKit.Phase.STRIKE:
		if ex.phase == KIT.Phase.IDLE:
			ex.press()  # a snap bite or a missed signal: the press and the release in one
		ex.release(bite.strike_charge())
	elif phase == ChompKit.Phase.IDLE and _prev_phase != ChompKit.Phase.IDLE and (ex.phase == KIT.Phase.ANTICIPATE or ex.phase == KIT.Phase.HOLD):
		ex.abort()
	_prev_phase = phase


## The riders (her eyes, her brood) follow the stretched spine and the body's new width.
func _reseat_riders(spine: SpineRig) -> void:
	var riders: Array = rig.get("_riders")
	var age := float(rig.get("_age"))
	for rider: Array in riders:
		var node: Node3D = rider[0]
		var at: Vector3 = rider[1]
		var frame := spine.frame_at(at.z)
		var basis: Basis = rider[2]
		var sway: float = rider[3]
		if sway > 0.0:
			basis = Basis(Vector3.RIGHT, sin(age * 1.7 + at.z) * sway) * basis
		node.global_transform = Transform3D(frame.basis * basis, frame.origin + frame.basis.x * at.x * girth + frame.basis.y * at.y * girth)


## What the rest of the game reads: the multiple of her rest size she shows (a camera's collision margin).
func _publish(mult: float) -> void:
	var fish: FishController = rig.get("fish")
	if fish != null:
		fish.set_meta("exaggerate_peak", mult)
