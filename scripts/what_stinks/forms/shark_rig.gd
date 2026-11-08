extends Node
## The Drowned Shark's exaggerated chomp (planning_new_hunters.md phase B2): a child of the Hunter's model that listens to
## its HunterBite and plays the Battletoads-style version of press / hold / release on top of the plain bite:
##   press    the head pulls back and the jaw tightens (anticipation squash), then everything swells
##   hold     the jaw unhinges wider than the bite's own gape (HunterJaw overshoot), the head leans into the bite, the
##            teeth grow, the eyes burn hotter: all of it climbing with the charge
##   release  the head THRUSTS forward, the teeth balloon for the snap and the jaw slams past shut, eyes flare, then
##            everything rings out (damped springs, overshoot) and settles; the landing adds hit-stop and a camera punch
## Every size comes from AttackExaggerate (scripts/what_stinks/attack_exaggerate.gd); nothing here touches the world's
## clock. The bite's own pose runs first (process_priority), this layers on top and puts everything back exactly at rest.
## Nodes it touches: the model (position z / stretch), HunterJaw's upper jaw and lower jaw (the teeth rows are split into one
## mesh per tooth so each grows about its own root and stays rooted in the gum), the Eye* meshes (scale + ember glow).

## How far past the bite's own gape the jaw swings per unit of the jaw channel's growth (rad), capped by MAX_EXTRA.
const GAPE_PER_UNIT := 1.0
const MAX_EXTRA := 1.3
## Head thrust: model lengths forward per unit of the head channel's growth, and how much of it stretches the body.
const THRUST := 0.10
const STRETCH := 0.12
const EYE_HOT := Color(1.0, 0.5, 0.12)

var fish: FishController
var model: Node3D
var jaw: HunterJaw
var ex: AttackExaggerate
var bite: HunterBite
var form: Dictionary = {}

var _base_scale := Vector3.ONE
var _base_pos := Vector3.ZERO
var _applied_scale := Vector3.ONE
var _applied_pos := Vector3.ZERO
var _teeth: Array[Dictionary] = []  # {node, jitter}
var _eyes: Array[Dictionary] = []  # {node, mat, scale, glow, iris}
var _dirty := false
var _built := false
var _gape := GAPE_PER_UNIT
var _thrust := THRUST
var _stretch := STRETCH
var _teeth_gain := 1.0
var _eye_gain := 1.0
var _shown_peak := 1.0


func _init() -> void:
	name = "SharkRig"
	process_physics_priority = 100  # after HunterBite (0): its pose first, ours on top


## Builds the rig on the model it is a child of: splits the tooth rows, finds the eyes. Safe to call again (it re-reads the settings).
func build(with_fish: FishController, with_form: Dictionary) -> void:
	fish = with_fish
	form = with_form
	model = get_parent() as Node3D
	configure(with_form)
	if _built or model == null:
		return
	_built = true
	if model.has_meta("hunter_jaw"):
		jaw = model.get_meta("hunter_jaw") as HunterJaw
	_base_scale = model.scale
	_base_pos = model.position
	_applied_scale = _base_scale
	_applied_pos = _base_pos
	if jaw != null and jaw._upper != null and jaw._lower != null:
		var upper_teeth := jaw._upper.get_child(0) as MeshInstance3D
		_split_teeth(jaw._upper, upper_teeth)
		for child in jaw._lower.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).material_override is StandardMaterial3D:
				_split_teeth(jaw._lower, child as MeshInstance3D)
				break
	for node in model.find_children("Eye*", "MeshInstance3D", true, false):
		var mat := (node as MeshInstance3D).material_override as ShaderMaterial
		if mat != null and mat.shader == FishModel.FISH_EYE:
			var own := mat.duplicate() as ShaderMaterial
			(node as MeshInstance3D).material_override = own
			var glow_now: Variant = own.get_shader_parameter("glow")
			var iris_now: Variant = own.get_shader_parameter("iris")
			_eyes.append({
				"node": node, "mat": own, "scale": (node as Node3D).scale,
				"glow": float(glow_now) if glow_now != null else 0.0,
				"iris": iris_now if iris_now is Color else Color(0.75, 0.6, 0.25),
			})


## Reads the panel's tuning (hunter_exaggeration and friends) and the form's own preset into the kit.
func configure(with_form: Dictionary) -> void:
	form = with_form
	var settings := WhatStinksSettings.shared()
	var fresh := AttackExaggerate.new(AttackExaggerate.params_from(settings, with_form))
	if ex == null:
		ex = fresh
		ex.camera_punch.connect(_on_punch)
	else:
		ex.params = fresh.params
		ex.set_strength(float(fresh.params["master"]), float(fresh.params["form_mult"]))
	_gape = _setting(settings, "shark_jaw_gape", GAPE_PER_UNIT)
	_thrust = _setting(settings, "shark_head_thrust", THRUST)
	_stretch = _setting(settings, "shark_body_stretch", STRETCH)
	_teeth_gain = _setting(settings, "shark_teeth_gain", 1.0)
	_eye_gain = _setting(settings, "shark_eye_flare", 1.0)


static func _setting(settings: Object, id: String, fallback: float) -> float:
	var got: Variant = settings.get(id) if settings != null else null
	return float(got) if got != null else fallback


## The worst-case size multiplier the exaggeration can show now (cameras pad their collision radius by it).
func camera_margin(radius: float) -> float:
	return ex.camera_margin(radius)


func _exit_tree() -> void:
	_unhook()
	if is_instance_valid(fish) and fish.has_meta("ws_exaggerate_peak"):
		fish.remove_meta("ws_exaggerate_peak")


# ------------------------------------------------------------------ beats

func _on_open() -> void:
	ex.press()
	_dirty = true


func _on_release(at_charge: float) -> void:
	ex.release(at_charge)
	_dirty = true


func _on_landed(taken: int) -> void:
	var share := 1.0
	if taken == 0:
		share = 0.35
	elif taken > 0:
		share = clampf(float(taken) / 4.0, 0.5, 1.0)
	ex.contact(share)
	_dirty = true


func _on_abort() -> void:
	ex.abort()
	_dirty = true


## Called by the style when the held bite is called off or the Hunter goes.
func cancel() -> void:
	if not ex.idle():
		ex.abort()
		_dirty = true


func _on_punch(amount: float, dir: Vector3) -> void:
	if not is_instance_valid(fish) or fish.puppet:
		return
	var camera := ChompKit.view_camera(fish)
	if camera != null:
		camera.call("punch", amount, dir)


func _unhook() -> void:
	if bite != null and is_instance_valid(bite):
		for pair: Array in [[bite.opened, _on_open], [bite.released, _on_release], [bite.landed, _on_landed], [bite.aborted, _on_abort]]:
			var sig := pair[0] as Signal
			if sig.is_connected(pair[1] as Callable):
				sig.disconnect(pair[1] as Callable)
	bite = null


func _poll_bite() -> void:
	var now: Variant = null
	if is_instance_valid(fish) and fish.has_meta("ws_bite"):
		now = fish.get_meta("ws_bite")
	if now == bite:
		return
	_unhook()
	bite = now as HunterBite
	if bite != null:
		bite.opened.connect(_on_open)
		bite.released.connect(_on_release)
		bite.landed.connect(_on_landed)
		bite.aborted.connect(_on_abort)


# ------------------------------------------------------------------ per tick

func _physics_process(delta: float) -> void:
	if not _built or not is_instance_valid(fish):
		return
	_poll_bite()
	if bite != null and bite.holding():
		ex.hold(bite.charge())
	ex.tick(delta)
	if ex.idle():
		if _dirty:
			_dirty = false
			_apply(true)
		return
	_dirty = true
	_apply(false)


func _apply(rest: bool) -> void:
	_apply_body(rest)
	_apply_jaw(rest)
	_apply_teeth(rest)
	_apply_eyes(rest)
	var peak := 1.0 if rest else ex.peak_scale()
	if not is_equal_approx(peak, _shown_peak):
		_shown_peak = peak
		if is_instance_valid(fish):
			fish.set_meta("ws_exaggerate_peak", peak)


func _apply_body(rest: bool) -> void:
	if model == null:
		return
	# The controller or the bite may set these themselves (a size change): take their value as the new base.
	if not model.scale.is_equal_approx(_applied_scale):
		_base_scale = model.scale
	if not model.position.is_equal_approx(_applied_pos):
		_base_pos = model.position
	var size_z: float = float(model.get("_size").z) if model.get("_size") is Vector3 else 1.0
	var length := size_z * _base_scale.z
	var scale_now := _base_scale
	var pos_now := _base_pos
	if not rest:
		var head := ex.scale_of(&"head")
		var basis := ex.scale_basis(&"head", Vector3.BACK)
		var along := 1.0 + (basis.z.z - 1.0) * _stretch
		var across := 1.0 + (basis.x.x - 1.0) * _stretch * 3.0
		scale_now = _base_scale * Vector3(across, across, along)
		# The tail stays put, the head goes out: stretch about the tail end, then the thrust itself.
		pos_now = _base_pos + Vector3(0.0, 0.0, -length * 0.5 * (along - 1.0) - (head - 1.0) * length * _thrust)
	model.scale = scale_now
	model.position = pos_now
	_applied_scale = scale_now
	_applied_pos = pos_now


func _apply_jaw(rest: bool) -> void:
	if jaw == null or bite == null or bite.bite == null:
		return
	var open_raw := bite.bite.open
	var extra := 0.0
	if not rest:
		extra = clampf((ex.scale_of(&"jaw") - 1.0) * _gape, -0.35, MAX_EXTRA) * smoothstep(0.0, 1.0, open_raw)
	jaw.set_overshoot(bite.bite.over + extra)
	jaw.pose(open_raw)
	# The upper jaw's push-out is the jaw's own; teeth are ours. Nothing else to do for it.


func _apply_teeth(rest: bool) -> void:
	var s := 1.0 if rest else 1.0 + (ex.scale_of(&"teeth") - 1.0) * _teeth_gain
	for entry in _teeth:
		var node := entry["node"] as Node3D
		if is_instance_valid(node):
			var ks := 1.0 + (s - 1.0) * (0.8 + 0.4 * float(entry["jitter"]))
			var wide := 1.0 + (ks - 1.0) * 0.6
			node.scale = Vector3(wide, ks, wide)


func _apply_eyes(rest: bool) -> void:
	var e := 1.0 if rest else 1.0 + (ex.scale_of(&"eye") - 1.0) * _eye_gain
	for entry in _eyes:
		var node := entry["node"] as Node3D
		if not is_instance_valid(node):
			continue
		node.scale = (entry["scale"] as Vector3) * (1.0 + (e - 1.0) * 0.45)
		var mat := entry["mat"] as ShaderMaterial
		var base_glow := float(entry["glow"])
		var glow := base_glow
		if e > 1.0:
			glow += (e - 1.0) * 1.8
		else:
			glow = base_glow * lerpf(0.2, 1.0, clampf(e, 0.0, 1.0))
		mat.set_shader_parameter("glow", glow)
		mat.set_shader_parameter("iris", (entry["iris"] as Color).lerp(EYE_HOT, clampf((e - 1.0) * 0.9, 0.0, 1.0)))


# ------------------------------------------------------------------ teeth

## Replaces the tooth row `source` (12 vertices a tooth: four triangles, base corners c0 c1 c2 c3 and the apex last) on `parent`
## by one mesh per tooth, positioned at its base centre so it can scale about it.
func _split_teeth(parent: Node3D, source: MeshInstance3D) -> void:
	if source == null or source.mesh == null:
		return
	var arrays := source.mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var norms := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	if verts.size() == 0 or verts.size() % 12 != 0 or norms.size() != verts.size():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + verts.size()
	for t in verts.size() / 12:
		var o := t * 12
		var root := (verts[o] + verts[o + 1] + verts[o + 4] + verts[o + 7]) * 0.25
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		for i in 12:
			pv.append(verts[o + i] - root)
			pn.append(norms[o + i])
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pv
		arr[Mesh.ARRAY_NORMAL] = pn
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var node := MeshInstance3D.new()
		node.name = "Tooth%d" % t
		node.mesh = mesh
		node.material_override = source.material_override
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = root
		parent.add_child(node)
		_teeth.append({"node": node, "jitter": rng.randf()})
	source.visible = false
