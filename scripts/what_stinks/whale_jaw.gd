class_name WhaleJaw
extends HunterJaw
## A whale Hunter's hinged lower jaw (two-stage-attack.md 4b; meta "hunter_jaw" on the model, as the shark's):
## the Titan model's jaw (TitanModel.hunter_jaw: a belly patch or the sperm whale's rod, the inside, the baleen
## or teeth) posed from the Bite's `open`. Exaggerated, Battletoads style: it drops to `whale_gape_deg`, the jaw
## stretches `whale_smear` times as long as it opens, the Bite's fling past wide swings it further, and
## `fullness` (0 to 1; EngulfAttack sets it as fish go in) balloons the throat. Built only on a Hunter's model:
## Marco Polo's Titans never get one, so their mouth stays the painted line, shut.

var settings := WhatStinksSettings.shared()
## How full the mouth is (0 to 1): the throat's pleats swell to it. Set by the attack, applied by the next pose().
var fullness := 0.0
## The Titan model's jaw pieces (TitanModel.hunter_jaw's dictionary).
var info := {}
var _model: FishModel
var _open_shown := -999.0
var _full_shown := -999.0


## The jaw on `model` (a Titan's), which this builds the pieces for.
func build(model: FishModel, _skin_color: Color) -> void:
	_model = model
	var titan := load(FishModel.TITAN_MODEL) as GDScript
	info = titan.call("hunter_jaw", model)
	mouth = {"front": info.mouth, "length": float(info.length), "width": float(info.width)}
	pose(0.0)


## Puts a WhaleJaw on `fish`'s Titan model once (safe to call every round): meta "hunter_jaw". Returns it.
static func wear(fish: FishController) -> WhaleJaw:
	var model := fish.get("_visual") as FishModel
	if model == null:
		return null
	if model.has_meta("hunter_jaw"):
		return model.get_meta("hunter_jaw") as WhaleJaw
	var jaw := WhaleJaw.new()
	jaw.build(model, Color.WHITE)
	model.set_meta("hunter_jaw", jaw)
	if model.has_meta("titan_lod_rescale"):
		(model.get_meta("titan_lod_rescale") as Callable).call(fish.body_scale)  # the jaw's LODs follow the fish's scale too
	return jaw


## Where the mouth is, in the model's space: the lips' front.
func mouth_local() -> Vector3:
	return info.mouth


## How far the jaw is dropped now (rad, 0 shut), for the probes and the attack's box.
func angle() -> float:
	return _angle_of(_open_shown)


## The mouth's half width and length (m, model space).
func mouth_width() -> float:
	return float(info.width)


func mouth_length() -> float:
	return float(info.length)


func _angle_of(jaw: float) -> float:
	var open := smoothstep(0.0, 1.0, jaw)
	if open <= 0.0:
		return 0.0
	var swing := maxf(open + overshoot * (1.0 if open > 0.03 else 0.0), -0.1)
	return clampf(-deg_to_rad(settings.whale_gape_deg) * swing, -2.2, 0.2)


func pose(jaw: float) -> void:
	if info.is_empty() or (is_equal_approx(jaw + overshoot, _open_shown) and is_equal_approx(fullness, _full_shown)):
		return
	_open_shown = jaw + overshoot
	_full_shown = fullness
	var open := smoothstep(0.0, 1.0, jaw)
	var cut := open > 0.03
	var angle := _angle_of(jaw)
	var stretch := lerpf(1.0, settings.whale_smear, clampf(open + overshoot, 0.0, 1.0)) if cut else 1.0
	var jaw_skin: ShaderMaterial = info.jaw_skin
	if bool(info.sperm):
		if jaw_skin != null:
			jaw_skin.set_shader_parameter("jaw_angle", angle)
			jaw_skin.set_shader_parameter("jaw_stretch", stretch)
	else:
		var skin: ShaderMaterial = info.skin
		skin.set_shader_parameter("jaw_cut", 1.0 if cut else 0.0)
		skin.set_shader_parameter("throat_swell", fullness * float(info.swell) * settings.engulf_swell)
		jaw_skin.set_shader_parameter("jaw_angle", angle)
		jaw_skin.set_shader_parameter("jaw_stretch", stretch)
		for patch: MeshInstance3D in info.patches:
			patch.visible = cut
	var jaw_node: Node3D = info.jaw
	var head: Node3D = info.head
	jaw_node.rotation.x = angle
	jaw_node.scale = Vector3(1.0, 1.0, stretch)
	jaw_node.visible = cut
	head.visible = cut
