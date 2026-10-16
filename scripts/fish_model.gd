class_name FishModel
extends Node3D
## A playable fish's look (one per FishCharacter), built from simple shapes to
## fill its character's hitbox at scale 1: width x height x length, centred on
## the hitbox centre, nose toward -Z. The body fills the box, so what you see is
## what the ball meets; fins and tails may poke out of it a little.
##
## Every model has the nodes the swim animation moves (TailPivot, FinLeftPivot,
## FinRightPivot) and a Body whose colour set_body_color() changes (replays
## tint each fish in its team's colour). Parts sharing the body's material
## change with it, as do its shader skins (_skins). Fins and skins that ripple as
## it swims (_waving) are moved by react(), which also squashes and stretches a
## model's `squash` node, if it has one, with the fish's acceleration.

const BLACK := Color(0.04, 0.04, 0.06)
const WHITE := Color(0.97, 0.97, 0.95)
const RAY_SKIN := preload("res://shaders/ray_skin.gdshader")
const KOI_SKIN := preload("res://shaders/koi_skin.gdshader")
const BOX_SKIN := preload("res://shaders/box_skin.gdshader")
const SHARK_SKIN := preload("res://shaders/shark_skin.gdshader")
const SWORD_SKIN := preload("res://shaders/sword_skin.gdshader")
const CLOWN_SKIN := preload("res://shaders/clown_skin.gdshader")
const FIN_MEMBRANE := preload("res://shaders/fin_membrane.gdshader")
const STRIDE_OVERLAY := preload("res://shaders/stride_overlay.gdshader")

var family := FishCharacter.Family.OCTANE
var tail: Node3D
var fin_left: Node3D
var fin_right: Node3D

## Scaled by react() to squash and stretch, if the model has one.
var squash: Node3D

## What the swimmer is doing, set before react(): resting on a surface, and
## an Extra Swishy stride's tail swing (SwishySwim.tail_swing) and power, 0..1.
## The ray banks and beats its wings with them.
var grounded := false
var stride_swing := Vector2.ZERO
var stride_power := 0.0

var _size := Vector3.ONE  # the hitbox (m): width, height, length
var _body_material: StandardMaterial3D
var _own_body_color: Variant = null  # before set_body_color()
var _squash_base := Vector3.ONE  # squash's scale at rest
var _last_velocity := Vector3.ZERO
var _acceleration := Vector3.ZERO  # smoothed, world space
var _stretch := Vector2.ZERO  # current (along, up): + longer / taller
var _stretch_speed := Vector2.ZERO
## Face features that ride the squash without squashing: each anchor's spot
## on the body at rest, moved with the squash in react().
var _face_anchors: Array[Node3D] = []
var _face_rest: Array[Vector3] = []
## Shader skins set_body_color() tints (their "albedo"), and the shaders react()
## ripples with the swim (their "phase" and "effort").
var _skins: Array[ShaderMaterial] = []
var _waving: Array[ShaderMaterial] = []
var _swim_phase := 0.0
## The ray's skin, body and tail (ray_skin.gdshader), whose wings and whip
## react() also bends.
var _skin: ShaderMaterial
var _tail_skin: ShaderMaterial
## The ray's whip: a chain of WHIP_LINKS springy links (_bend_whip), each an
## angle off the body (yaw, pitch) chasing the one before it, so a swing at the
## root travels down to the tip as a lash. The root takes WHIP_ROOT of the
## tail pivot's swing and the links bend the rest in; they also trail behind
## turns and stream back along the way it's moving.
const WHIP_LINKS := 4
const WHIP_ROOT := 0.5
var _whip: MeshInstance3D
var _whip_rest_tip := Vector3.ZERO  # the tip of the unbent whip, in its own space
var _whip_root := Vector2.ZERO
var _whip_links: Array[Vector2] = []
var _whip_spin: Array[Vector2] = []
var _whip_basis := Basis.IDENTITY  # the body's last frame, for how far it turned
var _whip_basis_set := false
## The ray's bank into turns (rad, + rolls its left wing down) and its wings'
## stride beats (rad on each wing's flap: left, right), springing (_bank_ray,
## _beat_wings), and its wings' own wave phase.
const RAY_BANK := 0.6
const RAY_BEAT := 0.5
const RAY_LIFT := 0.35
var _last_stride_power := 0.0
var _bank := 0.0
var _bank_speed := 0.0
var _beat := Vector2.ZERO
var _beat_speed := Vector2.ZERO
var _wing_phase := 0.0
## The tail's meshes that show set_stride_cue(), found the first time it shows.
var _tail_cue: Array[GeometryInstance3D] = []


static func build(character: FishCharacter.Family) -> FishModel:
	var model := FishModel.new()
	model.name = "Visual"
	model.family = character
	model._size = FishCharacter.hitbox_size(character)
	match character:
		FishCharacter.Family.OCTANE:
			model._build_clownfish()
		FishCharacter.Family.DOMINUS:
			model._build_shark()
		FishCharacter.Family.PLANK:
			model._build_ray()
		FishCharacter.Family.BREAKOUT:
			model._build_swordfish()
		FishCharacter.Family.HYBRID:
			model._build_koi()
		FishCharacter.Family.MERC:
			model._build_boxfish()
	return model


## Squash and stretch with the fish's acceleration (from `velocity`, world
## space, given every frame), on a springy wobble. Speeding up stretches it
## along its length and braking squashes it; falling stretches it tall and
## landing squashes it flat. Volume is kept, so it bulges the other way. The
## edge it's moving toward stays put and the trailing side does the stretching
## (the bottom, when it isn't moving up or down, so it squashes onto the floor).
func react(delta: float, velocity: Vector3) -> void:
	if not _waving.is_empty():
		_swim(delta, velocity)
	if squash == null or delta <= 0.0:
		return
	var raw := (velocity - _last_velocity) / delta
	_last_velocity = velocity
	# Physics ticks and frames don't line up: smooth the per-frame acceleration.
	_acceleration = _acceleration.lerp(raw, 1.0 - exp(-15.0 * delta))
	var to_local := global_basis.orthonormalized().inverse()
	var local := to_local * _acceleration
	var target := Vector2(clampf(-local.z / 35.0, -0.3, 0.35), clampf(-local.y / 45.0, -0.35, 0.2))
	_stretch_speed += ((target - _stretch) * 160.0 - _stretch_speed * 11.0) * delta
	_stretch += _stretch_speed * delta
	var along := 1.0 + _stretch.x
	var up := 1.0 + _stretch.y
	var shape := Vector3(1.0 / sqrt(along * up), up, along)
	# Which end leads, blended over 1 m/s so it never snaps: -1 = the front (-Z)
	# or the bottom, +1 = the back or the top.
	var moving := to_local * velocity
	var lead_z := clampf(moving.z, -1.0, 1.0)
	var lead_y := lerpf(-1.0, signf(moving.y), clampf(absf(moving.y), 0.0, 1.0))
	var shift := -Vector3(0.0, lead_y * (up - 1.0), lead_z * (along - 1.0)) * _squash_base / 2.0
	squash.scale = _squash_base * shape
	squash.position = shift
	for i in _face_anchors.size():
		_face_anchors[i].position = _face_rest[i] * shape + shift


## Extra Swishy's timing cue (SwishySwim): the tail lights up from its root
## to its tip like a progress bar, `fill` 0..1 (the tip is the stride's peak),
## at brightness `glow`, turning gold as `sweet` goes to 1 (at the peak). The
## tail's own shaders draw it (stride_cue.gdshaderinc); plain parts get an
## overlay that does. glow 0 turns it off.
func set_stride_cue(fill: float, glow: float, sweet: float) -> void:
	if _tail_cue.is_empty():
		if glow <= 0.0:
			return
		_setup_tail_cue()
	for part: GeometryInstance3D in _tail_cue:
		part.set_instance_shader_parameter("stride_fill", fill)
		part.set_instance_shader_parameter("stride_glow", glow)
		part.set_instance_shader_parameter("stride_sweet", sweet)


## Finds the tail's meshes for set_stride_cue(). Fins and the ray's whip already
## draw the cue (their shaders include it); plain parts get an overlay that
## works out how far back along the tail each point is.
func _setup_tail_cue() -> void:
	var plain: Array[MeshInstance3D] = []
	var bounds := AABB()
	for node in tail.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var shader_material := part.material_override as ShaderMaterial
		if shader_material and shader_material.shader in [FIN_MEMBRANE, RAY_SKIN]:
			_tail_cue.append(part)
			continue
		var in_pivot := _transform_in_tail(part)
		var box := in_pivot * part.get_aabb()
		bounds = box if plain.is_empty() else bounds.merge(box)
		plain.append(part)
	for part in plain:
		var overlay := ShaderMaterial.new()
		overlay.shader = STRIDE_OVERLAY
		overlay.set_shader_parameter("to_pivot", Projection(_transform_in_tail(part)))
		overlay.set_shader_parameter("root", bounds.position.z)
		overlay.set_shader_parameter("tip", bounds.end.z)
		part.material_overlay = overlay
		_tail_cue.append(part)


## The tail's tip in the tail pivot's space (the back of its meshes; the ray's
## whip tip as it bends).
func tail_tip() -> Vector3:
	if _whip:
		return _whip.transform * (_whip_rest_tip + _whip_offset(1.0))
	var bounds := AABB()
	var first := true
	for node in tail.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var box := _transform_in_tail(part) * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return Vector3(0.0, 0.0, bounds.end.z)


## `part`'s transform in the tail pivot's space.
func _transform_in_tail(part: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node3D = part
	while node != tail:
		xform = node.transform * xform
		node = node.get_parent_node_3d()
	return xform


func set_body_color(color: Color) -> void:
	if _own_body_color == null:
		_own_body_color = _body_material.albedo_color
	_tint(color)


## The body's colour now: the character's own, or the one set_body_color() gave it.
func body_color() -> Color:
	return _body_material.albedo_color


## Back to the character's own colour after set_body_color().
func reset_body_color() -> void:
	if _own_body_color != null:
		_tint(_own_body_color)


func _tint(color: Color) -> void:
	_body_material.albedo_color = color
	for skin in _skins:
		skin.set_shader_parameter("albedo", color)


## The swim wave: fins and skins ripple, harder and quicker with speed. The
## ray's wings also follow the fin pivots (their roll lifts the tips, their turn
## sweeps them back) and beat with strides, it banks into turns, and its tail
## whips.
func _swim(delta: float, velocity: Vector3) -> void:
	var effort := clampf(velocity.length() / 23.0, 0.0, 1.0)
	_swim_phase = fmod(_swim_phase + delta * lerpf(2.5, 9.0, effort), TAU * 100.0)
	for material in _waving:
		material.set_shader_parameter("phase", _swim_phase)
		material.set_shader_parameter("effort", effort)
	if _skin == null or delta <= 0.0:
		return
	# The ray: how far its body (not counting its own bank) turned this frame.
	var body := _body_frame()
	var turned := Vector2.ZERO
	if _whip_basis_set:
		var euler := (_whip_basis.inverse() * body).get_euler()
		turned = Vector2(euler.y, euler.x)
		if turned.length() > 0.5:
			turned = Vector2.ZERO  # a respawn or a cut, not a turn
	_whip_basis = body
	_whip_basis_set = true
	var moving := body.inverse() * velocity
	var yaw_rate := turned.x / delta
	_bank_ray(delta, yaw_rate, -moving.z)
	_beat_wings(delta)
	# The wings' wave runs nose to tail, quicker and deeper with speed and with a
	# stride's push, and deeper on the wing that's working harder: the outside
	# of a turn, or the side a stride beats.
	_wing_phase = fmod(_wing_phase + delta * lerpf(3.0, 12.0, effort) * (1.0 + 0.6 * stride_power), TAU * 100.0)
	_skin.set_shader_parameter("phase", _wing_phase)
	_skin.set_shader_parameter("ripple", lerpf(0.014, 0.045, effort) * (1.0 + 0.5 * stride_power))
	var bias := clampf(yaw_rate * 0.15, -0.6, 0.6) - 0.4 * stride_swing.x * stride_power
	_skin.set_shader_parameter("ripple_bias", clampf(bias, -0.7, 0.7))
	_skin.set_shader_parameter("flap_left", -fin_left.rotation.z + _beat.x)
	_skin.set_shader_parameter("flap_right", fin_right.rotation.z + _beat.y)
	_skin.set_shader_parameter("sweep_left", fin_left.rotation.y)
	_skin.set_shader_parameter("sweep_right", -fin_right.rotation.y)
	_tail_skin.set_shader_parameter("tail_ripple", lerpf(0.02, 0.05, effort))
	_bend_whip(delta, moving, turned)


## The frame the ray's body swims in: the model's own, less its bank.
func _body_frame() -> Basis:
	var parent := get_parent_node_3d()
	var outer := parent.global_basis if parent else Basis.IDENTITY
	return (outer * Basis.from_euler(Vector3(rotation.x, rotation.y, 0.0))).orthonormalized()


## The ray banks into its turns like a bird, more the faster it's going
## (`forward`, m/s) and the harder it turns (`yaw_rate`, rad/s, + to the left),
## and toward the side a stride pushes it; level again on a surface, where a
## wing would dig in.
func _bank_ray(delta: float, yaw_rate: float, forward: float) -> void:
	var target := 0.0
	if not grounded:
		target = clampf(yaw_rate * maxf(forward, 0.0) * 0.012, -RAY_BANK, RAY_BANK)
		target = clampf(target - stride_swing.x * stride_power * 0.25, -RAY_BANK, RAY_BANK)
	_bank_speed += ((target - _bank) * 64.0 - _bank_speed * 11.0) * delta
	_bank += _bank_speed * delta
	rotation.z = _bank


## Each stride is a beat of the wings: their tips sweep down as its push builds
## and lift back up past level as it fades (RAY_LIFT), the recovery stroke. A sideways
## stride beats the wing away from the push harder (as a ray turns, pulling with
## its outside wing); an up or down one beats both alike. On a surface the tips
## stay out of the floor.
func _beat_wings(delta: float) -> void:
	var lean := clampf(stride_swing.x, -1.0, 1.0) * 0.7
	# Fading (power falling over about a third of a second) lifts them.
	var fading := clampf((_last_stride_power - stride_power) / delta * 0.35, 0.0, 1.0)
	_last_stride_power = stride_power
	var target := Vector2(1.0 + lean, 1.0 - lean) * (RAY_LIFT * fading - RAY_BEAT * stride_power)
	var steps := ceili(delta * 120.0)
	var h := delta / steps
	for k in steps:
		_beat_speed += ((target - _beat) * 196.0 - _beat_speed * 2.0 * 0.35 * 14.0) * h
		_beat += _beat_speed * h
	if grounded:
		_beat = _beat.max(Vector2(-0.15, -0.15))


## Bends the ray's whip (WHIP_LINKS): its root turns WHIP_ROOT of the way the
## swim animation turned the tail pivot, and each link springs toward the one
## before it plus its share of the rest of that swing, lagging and overshooting
## so a stride's swing cracks down it. Turning (`turned`, rad this frame: yaw,
## pitch) leaves the links partly behind (they keep some of their heading in
## the water), and they stream back along the way it's moving (`moving`, in the
## body's frame), more the faster it goes.
func _bend_whip(delta: float, moving: Vector3, turned: Vector2) -> void:
	if _whip == null:
		return
	if _whip_links.is_empty():
		_whip_links.resize(WHIP_LINKS)
		_whip_spin.resize(WHIP_LINKS)
		_whip_links.fill(Vector2.ZERO)
		_whip_spin.fill(Vector2.ZERO)
	var swing := Vector2(tail.rotation.y, tail.rotation.x)  # (yaw: tip toward +X, pitch: tip down)
	var stream := Vector2.ZERO
	if -moving.z > 0.5:
		stream = Vector2(atan2(-moving.x, -moving.z), atan2(moving.y, -moving.z)) * clampf(-moving.z / 12.0, 0.0, 1.0)
		stream = stream.clampf(-0.8, 0.8)
	_whip_root = swing * WHIP_ROOT
	var step := (swing + stream * 0.7 - _whip_root) / WHIP_LINKS
	for i in WHIP_LINKS:
		_whip_links[i] -= turned * 0.7
	var steps := ceili(delta * 120.0)
	var h := delta / steps
	for k in steps:
		for i in WHIP_LINKS:
			var before := _whip_links[i - 1] if i > 0 else _whip_root
			var omega := lerpf(24.0, 13.0, float(i) / (WHIP_LINKS - 1))
			var pull := (before + step - _whip_links[i]) * omega * omega - _whip_spin[i] * 2.0 * 0.5 * omega
			_whip_spin[i] += pull * h
			_whip_links[i] = (_whip_links[i] + _whip_spin[i] * h).clampf(-1.4, 1.4)
	var bend_yaw := Vector4()
	var bend_pitch := Vector4()
	for i in WHIP_LINKS:
		bend_yaw[i] = _whip_links[i].x - _whip_root.x
		bend_pitch[i] = _whip_links[i].y - _whip_root.y
	_tail_skin.set_shader_parameter("bend_yaw", bend_yaw)
	_tail_skin.set_shader_parameter("bend_pitch", bend_pitch)
	# The pivot carries the whole swing: undo it on the whip but for the root's share.
	_whip.basis = Basis.from_euler(tail.rotation).inverse() * Basis.from_euler(Vector3(_whip_root.y, _whip_root.x, 0.0))


## How far the bent whip's middle has moved `along` it (0 root to 1 tip), in its
## own space, from the links' bends: as ray_skin.gdshader bends it (keep in step).
func _whip_offset(along: float) -> Vector3:
	var length: float = _tail_skin.get_shader_parameter("tail_length")
	var steps := 12
	var h := along / steps
	var offset := Vector3.ZERO
	for k in steps:
		var bend := _whip_bend_at((k + 0.5) * h)
		offset += Vector3(sin(bend.x), -sin(bend.y), cos(bend.x) + cos(bend.y) - 2.0) * h
	return offset * length


## The whip's bend (yaw, pitch) off its root `along` it: 0 at the root, through
## each link's at their ends (WHIP_LINKS evenly spaced), straight between.
func _whip_bend_at(along: float) -> Vector2:
	if _whip_links.is_empty():
		return Vector2.ZERO
	var at := clampf(along, 0.0, 1.0) * WHIP_LINKS
	var i := mini(floori(at), WHIP_LINKS - 1)
	var from := _whip_links[i - 1] - _whip_root if i > 0 else Vector2.ZERO
	return from.lerp(_whip_links[i] - _whip_root, at - i)


# --- The fish -------------------------------------------------------------------

## Octane: an ocellaris clownfish, a plump oval in orange with three white bands
## edged in black (clown_skin.gdshader), rounded fins with black margins, and big
## orange-ringed eyes.
func _build_clownfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var ends := Vector2(-l * 0.48, l * 0.33)
	var semi := Vector2(w * 0.21, h * 0.5)
	var profile := func(along: float) -> Vector3:
		var r := _taper(along, 0.42, 0.86, 0.3)
		return Vector3(semi.x * r * lerpf(1.0, 0.6, along), semi.y * r, 0.0)
	var span := ends.y - ends.x
	var at := func(along: float) -> float: return ends.x + span * along
	var skin := _skin_body(CLOWN_SKIN, Color(1.0, 0.45, 0.06), ends, profile)
	skin.set_shader_parameter("band_z", Vector3(at.call(0.26), at.call(0.56), at.call(0.9)))
	skin.set_shader_parameter("band_width", Vector3(l * 0.04, l * 0.045, l * 0.02))
	skin.set_shader_parameter("band_bulge", Vector3(l * 0.035, -l * 0.07, 0.0))
	skin.set_shader_parameter("rim", l * 0.006)
	skin.set_shader_parameter("height", semi.y)
	skin.set_shader_parameter("girth", (semi.x + semi.y) / 2.0)
	# Orange fins with black margins, tinted with the body; plain orange pectorals.
	var fins := _fin_material(Color(1.0, 0.45, 0.06), Color(), 11.0, 0.012, 1.4, 0.9)
	fins.set_shader_parameter("edge_shade", 1.1)
	fins.set_shader_parameter("margin", 0.1)
	_skins.append(fins)
	var paddles := _fin_material(Color(1.0, 0.5, 0.1), Color(), 9.0, 0.012, 2.2, 0.55)
	paddles.set_shader_parameter("edge_shade", 1.2)
	_skins.append(paddles)
	var top := func(along: float) -> Vector3: return _loft_point(ends, profile, at.call(along), 1.0)
	var bottom := func(along: float) -> Vector3: return _loft_point(ends, profile, at.call(along), -1.0)
	# A dorsal fin along the back, low and spiny in front, then a notch and a
	# taller soft part; an anal fin under the back half; little pelvic fins.
	_membrane(self, fins, top.call(0.3) * Vector3(0.0, 0.93, 1.0), top.call(0.84) * Vector3(0.0, 0.9, 1.0), Vector3(0.0, 1.0, 0.45),
			[h * 0.12, h * 0.22, h * 0.19, h * 0.12, h * 0.26, h * 0.32, h * 0.26, h * 0.08], 0.0, 0.03)
	_membrane(self, fins, bottom.call(0.6) * Vector3(0.0, 0.93, 1.0), bottom.call(0.84) * Vector3(0.0, 0.9, 1.0), Vector3(0.0, -1.0, 0.55),
			[h * 0.18, h * 0.26, h * 0.2, h * 0.06], 0.0, 0.04)
	for side: float in [-1.0, 1.0]:
		var pelvic := _loft_point(ends, profile, at.call(0.36), -0.85) * Vector3(side * 0.8, 0.97, 1.0)
		_membrane(self, fins, pelvic, pelvic + Vector3(0.0, 0.0, l * 0.06), Vector3(side * 0.4, -1.0, 0.6), [h * 0.24, h * 0.14], 0.0, 0.04)
	# Round paddle pectorals behind the head on the swim animation's pivots.
	var pectoral := _loft_point(ends, profile, at.call(0.3), -0.25)
	_fin_pivots(Vector3(pectoral.x * 0.9, pectoral.y, pectoral.z))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, paddles, Vector3(0.0, h * 0.07, 0.0), Vector3(0.0, -h * 0.07, 0.0), Vector3(side * 0.6, -0.1, 1.0),
				[l * 0.12, l * 0.16, l * 0.16, l * 0.12], 0.9, 0.03)
	# A rounded tail fan.
	_tail_pivot(Vector3(0.0, 0.0, ends.y - l * 0.03))
	var stalk: float = profile.call(inverse_lerp(ends.x, ends.y, ends.y - l * 0.03)).y
	_membrane(tail, fins, Vector3(0.0, stalk, 0.0), Vector3(0.0, -stalk, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.19, l * 0.23, l * 0.24, l * 0.23, l * 0.19], -1.0, 0.03)
	# Big eyes with orange rings, and a small mouth on the front of the snout.
	for side: float in [-1.0, 1.0]:
		var eye := _loft_point(ends, profile, at.call(0.15), 0.3) * Vector3(side * 0.9, 1.0, 1.0)
		_eye(eye, h * 0.13, Vector3(side * 0.85, 0.1, -0.5), 0.72, null, Color(1.0, 0.5, 0.1), 0.4)
	_mouth(Vector3(0.0, -semi.y * 0.2, ends.x + l * 0.012), Vector3(w * 0.07, h * 0.05, 0.03))


## Dominus: a stout little shark, one smooth shape from its pointed snout back
## to a slim tail stalk, slate over a white belly with gill slits and a toothy
## grin painted under its snout (shark_skin.gdshader). Stiff fins: a tall swept
## dorsal fin, long pectorals, and a tail whose top lobe is the longer.
func _build_shark() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var ends := Vector2(-l * 0.5, l * 0.36)
	var semi := Vector2(w * 0.27, h * 0.48)
	var profile := func(along: float) -> Vector3:
		var head := smoothstep(0.0, 0.35, along)
		var r := _taper(along, 0.36, 0.88, 0.15, 0.8)
		return Vector3(semi.x * r, semi.y * r * lerpf(0.72, 1.0, head), -semi.y * 0.16 * (1.0 - head))
	var span := ends.y - ends.x
	var at := func(along: float) -> float: return ends.x + span * along
	var color := Color(0.42, 0.52, 0.64)
	var skin := _skin_body(SHARK_SKIN, color, ends, profile)
	skin.set_shader_parameter("gill_z", at.call(0.26))
	skin.set_shader_parameter("gill_step", l * 0.028)
	skin.set_shader_parameter("gill_height", h * 0.15)
	var jaw: Vector3 = profile.call(0.1)
	skin.set_shader_parameter("mouth_z", at.call(0.1))
	skin.set_shader_parameter("mouth_width", jaw.x * 0.85)
	skin.set_shader_parameter("mouth_back", l * 0.045)
	skin.set_shader_parameter("tooth_width", w * 0.02)
	# Stiff fins in the body's colour (tinted with it), darker toward their tips.
	var fins := _fin_material(color, Color(), 0.0, 0.004, 1.0, 1.0)
	fins.set_shader_parameter("edge_shade", 0.72)
	_skins.append(fins)
	var top := func(along: float) -> Vector3: return _loft_point(ends, profile, at.call(along), 1.0)
	var bottom := func(along: float) -> Vector3: return _loft_point(ends, profile, at.call(along), -1.0)
	# A tall dorsal fin swept back, a small second one, an anal fin and pelvics.
	_membrane(self, fins, top.call(0.36) * Vector3(0.0, 0.94, 1.0), top.call(0.55) * Vector3(0.0, 0.92, 1.0), Vector3(0.0, 1.0, 0.8),
			[h * 0.78, h * 0.62, h * 0.36, h * 0.14], -0.25, 0.0)
	_membrane(self, fins, top.call(0.8) * Vector3(0.0, 0.9, 1.0), top.call(0.87) * Vector3(0.0, 0.9, 1.0), Vector3(0.0, 1.0, 0.9),
			[h * 0.2, h * 0.12, h * 0.04], -0.2, 0.0)
	_membrane(self, fins, bottom.call(0.78) * Vector3(0.0, 0.9, 1.0), bottom.call(0.85) * Vector3(0.0, 0.9, 1.0), Vector3(0.0, -1.0, 0.9),
			[h * 0.18, h * 0.1, h * 0.04], 0.2, 0.0)
	for side: float in [-1.0, 1.0]:
		var pelvic := _loft_point(ends, profile, at.call(0.66), -0.8) * Vector3(side * 0.85, 0.97, 1.0)
		_membrane(self, fins, pelvic, pelvic + Vector3(0.0, 0.0, l * 0.06), Vector3(side * 0.7, -0.6, 0.9), [h * 0.24, h * 0.14, h * 0.05], 0.0, 0.0)
	# Long pectorals low behind the gills, on the swim animation's pivots.
	var pectoral := _loft_point(ends, profile, at.call(0.36), -0.55)
	_fin_pivots(Vector3(pectoral.x * 0.9, pectoral.y, pectoral.z))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, fins, Vector3(0.0, 0.0, -l * 0.06), Vector3(0.0, 0.0, l * 0.05), Vector3(side, -0.3, 0.55),
				[l * 0.26, l * 0.21, l * 0.1, l * 0.03], 0.0, 0.0)
	# The tail: its top lobe long and swept up, its bottom one short.
	_tail_pivot(Vector3(0.0, 0.0, ends.y - l * 0.04))
	var stalk: float = profile.call(inverse_lerp(ends.x, ends.y, ends.y - l * 0.04)).y
	_membrane(tail, fins, Vector3(0.0, stalk * 0.9, 0.0), Vector3(0.0, -stalk * 0.9, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.38, l * 0.24, l * 0.08, l * 0.13, l * 0.19], -1.6, 0.0)
	# Small dark eyes on the sides of the head.
	for side: float in [-1.0, 1.0]:
		var eye := _loft_point(ends, profile, at.call(0.17), 0.3) * Vector3(side * 0.88, 1.0, 1.0)
		_eye(eye, h * 0.1, Vector3(side * 0.9, 0.15, -0.45), 0.8, null, Color(0.12, 0.14, 0.2))


## Plank: a string ray, one smooth shape from its domed head out to thin wing
## membranes that bend, sweep and ripple as it swims (ray_skin.gdshader). Deep
## blue with pale spots over a white belly, big sleepy brown eyes over a round
## snout, and a long whip tail curling up behind. Its wings reach out past the
## hitbox's sides and its tail well past the back.
func _build_ray() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var color := Color(0.05, 0.17, 0.47)
	_body_material = _material(color, 0.45)  # for set_body_color(); the skin is shaded by _skin
	_skin = ShaderMaterial.new()
	_skin.shader = RAY_SKIN
	_skin.set_shader_parameter("albedo", color)
	_skin.set_shader_parameter("hinge", w * 0.18)
	_skin.set_shader_parameter("span", _ray_edge(RAY_TIPS))
	_skin.set_shader_parameter("spot_cell", w * 0.08)
	_skin.set_shader_parameter("wave", TAU / (l * 0.9))
	_skin.set_shader_parameter("wave_from", _ray_ends().x)
	_skin.set_shader_parameter("wave_to", _ray_ends().y)
	_skin.set_shader_parameter("streak_from", -l * 0.33)
	_skin.set_shader_parameter("streak_to", -l * 0.12)
	_skin.set_shader_parameter("streak_gap", w * 0.04)
	_skin.set_shader_parameter("gill_from", -l * 0.27)
	_skin.set_shader_parameter("gill_to", -l * 0.1)
	_skin.set_shader_parameter("gill_x", w * 0.1)
	_skin.set_shader_parameter("gill_length", w * 0.026)
	_skin.set_shader_parameter("mouth_z", -l * 0.34)
	_skin.set_shader_parameter("mouth_width", w * 0.05)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _ray_mesh()
	body.material_override = _skin
	body.extra_cull_margin = 0.3  # the shader bends the wings out of the mesh's bounds
	add_child(body)
	# A little smile under the round snout.
	_mouth(Vector3(0.0, -h * 0.05, -l * 0.45), Vector3(w * 0.15, h * 0.035, l * 0.05))
	# Big brown eyes peeping out of the front of the brow mounds (_ray_thickness).
	for side: float in [-1.0, 1.0]:
		var brow := _ray_brow(side)
		var radius := h * 0.15
		var at := Vector3(brow.x, _ray_top(brow.x, brow.z - radius * 0.9) - radius * 0.55, brow.z - radius * 0.9)
		_eye(at, radius, Vector3(side * 0.6, 0.2, -0.75), 0.7, null, Color(0.35, 0.13, 0.06))
	# The wings bend in the shader: the pivots only carry the swim animation's
	# flap and sweep to it (_swim).
	_fin_pivots(Vector3(w * 0.18, 0.0, -l * 0.06))
	_tail_pivot(Vector3(0.0, 0.0, l * 0.26))
	var tail_length := l * 0.7
	_tail_skin = ShaderMaterial.new()
	_tail_skin.shader = RAY_SKIN
	_tail_skin.set_shader_parameter("tail_mode", true)
	_tail_skin.set_shader_parameter("albedo", color)
	_tail_skin.set_shader_parameter("tail_length", tail_length)
	_skins.append_array([_skin, _tail_skin])
	_waving.append_array([_skin, _tail_skin])
	_whip = MeshInstance3D.new()
	_whip.name = "Whip"
	_whip.mesh = _tube_mesh(tail_length, 0.034, 1.2)
	_whip.material_override = _tail_skin
	_whip.extra_cull_margin = tail_length  # the shader bends it out of the mesh's bounds
	tail.add_child(_whip)
	var bounds := _whip.mesh.get_aabb()
	_whip_rest_tip = Vector3(0.0, bounds.end.y, bounds.end.z)


const RAY_TIPS := 0.56  # how far back the wingtips are, nose 0 to tail 1


## The ray's outline: how far out (m) its edge is `along` it (the nose 0, where
## the tail starts 1), widest at the wingtips and rounded at both ends.
func _ray_edge(along: float) -> float:
	var span := _size.x * 0.62
	if along < RAY_TIPS:
		return span * pow(sin(PI / 2.0 * along / RAY_TIPS), 0.55)
	return span * pow(maxf(cos(PI / 2.0 * (along - RAY_TIPS) / (1.0 - RAY_TIPS)), 0.0), 0.75)


## How far the ray's top (or its belly, below) is from its middle at (x, z),
## before rounding off at the rim: a dome for the body falling smoothly away into
## thin wings, with the head rising off the front of it over a round snout.
func _ray_thickness(x: float, z: float, top: bool) -> float:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var membrane := 0.007
	var body := exp(-2.6 * (pow(x / (w * 0.24), 2.0) + pow((z + l * 0.06) / (l * 0.36), 2.0)))
	var snout := exp(-pow(x / (w * 0.14), 2.0) - pow((z + l * 0.43) / (l * 0.08), 2.0))
	if not top:
		return h * 0.4 * body + h * 0.14 * snout + membrane
	var head := exp(-3.0 * (pow(x / (w * 0.2), 2.0) + pow((z + l * 0.26) / (l * 0.2), 2.0)))
	var brows := 0.0
	for side: float in [-1.0, 1.0]:
		var brow := _ray_brow(side)
		brows = maxf(brows, exp(-pow((x - brow.x) / (w * 0.07), 2.0) - pow((z - brow.z) / (l * 0.06), 2.0)))
	return h * 0.45 * body + h * 0.18 * head + h * 0.17 * brows + h * 0.14 * snout + membrane


## Where the mound over each eye (side -1 left, 1 right) is highest.
func _ray_brow(side: float) -> Vector3:
	return Vector3(side * _size.x * 0.15, 0.0, -_size.z * 0.25)


## The nose and tail ends of the ray's body (z).
func _ray_ends() -> Vector2:
	return Vector2(-_size.z * 0.47, _size.z * 0.3)


## How high the ray's top is at (x, z), rim and all.
func _ray_top(x: float, z: float) -> float:
	var ends := _ray_ends()
	var edge := _ray_edge(inverse_lerp(ends.x, ends.y, z))
	var across := clampf(x / maxf(edge, 0.001), -1.0, 1.0)
	return _ray_thickness(x, z, true) * sqrt(1.0 - across * across)


## The ray's body and wings as one shape: a top and a belly (UV.y 1 and 0)
## meeting at a rounded rim, the columns bunched toward the rim.
func _ray_mesh() -> ArrayMesh:
	var ends := _ray_ends()
	var rows := 56
	var columns := 48
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in 2:
		var top := surface == 0
		for i in rows + 1:
			var along := float(i) / rows
			var z := lerpf(ends.x, ends.y, along)
			var edge := _ray_edge(along)
			for j in columns + 1:
				var across := sin(PI / 2.0 * (2.0 * j / columns - 1.0))
				var x := across * edge
				var y := _ray_thickness(x, z, top) * sqrt(maxf(1.0 - across * across, 0.0))
				tool.set_uv(Vector2(along, 1.0 if top else 0.0))
				tool.add_vertex(Vector3(x, y if top else -y, z))
	for surface in 2:
		var first := surface * (rows + 1) * (columns + 1)
		for i in rows:
			for j in columns:
				var a := first + i * (columns + 1) + j
				var b := a + 1
				var c := a + columns + 1
				var d := c + 1
				var corners := [a, b, c, b, d, c] if surface == 0 else [a, c, b, b, c, d]
				for corner: int in corners:
					tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A whip tail or whisker: a tube along +Z, `radius` thick at its base and
## thinning to a point as it curls up by `curl` (rad, down if less than 0);
## UV.x runs 0 at the base to 1 at the tip and UV.y round it.
func _tube_mesh(length: float, radius: float, curl: float) -> ArrayMesh:
	var rings := 32
	var sides := 8
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := Vector3.ZERO
	for i in rings + 1:
		var along := float(i) / rings
		var pitch := curl * pow(along, 1.6)
		var forward := Vector3(0.0, sin(pitch), cos(pitch))
		var up := Vector3(0.0, cos(pitch), -sin(pitch))
		var thickness := radius * lerpf(1.0, 0.1, along)
		for k in sides + 1:
			var angle := TAU * k / sides
			tool.set_uv(Vector2(along, float(k) / sides))
			tool.add_vertex(at + (Vector3.RIGHT * cos(angle) + up * sin(angle)) * thickness)
		at += forward * length / rings
	for i in rings:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			for corner: int in [a, c, b, b, c, d]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## Breakout: a swordfish, one sleek shape from the tip of its long flat sword to
## its tail stalk, deep blue with a purple sheen over a silver belly
## (sword_skin.gdshader). A tall sickle dorsal fin, long sickle pectorals and a
## crescent tail, stiff and dark, and big eyes. The sword reaches the front of
## the hitbox and the tail pokes out past the back.
func _build_swordfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var ends := Vector2(-l * 0.5, l * 0.37)
	var semi := Vector2(w * 0.23, h * 0.5)
	var blade := Vector2(w * 0.045, h * 0.05)  # the sword's half width and height at its base
	var bill := 0.3  # how far back the sword runs, nose 0 to tail 1
	var profile := func(along: float) -> Vector3:
		var body := along - bill * 0.75
		var r := 0.0 if body <= 0.0 else _taper(body / (1.0 - bill * 0.75), 0.3, 0.9, 0.14, 0.65)
		var sword := pow(clampf(along / bill, 0.0, 1.0), 0.75)
		var low := -semi.y * 0.1 * (1.0 - smoothstep(0.15, 0.4, along))
		return Vector3(maxf(semi.x * r, blade.x * sword), maxf(semi.y * r, blade.y * sword), low)
	var span := ends.y - ends.x
	var at := func(along: float) -> float: return ends.x + span * along
	var color := Color(0.12, 0.2, 0.5)
	var skin := _skin_body(SWORD_SKIN, color, ends, profile, 120)
	skin.set_shader_parameter("bill_end", at.call(bill * 0.82))
	skin.set_shader_parameter("lateral_y", semi.y * 0.2)
	skin.set_shader_parameter("girth", (semi.x + semi.y) / 2.0)
	# Stiff dark fins, tinted with the body.
	var fins := _fin_material(color, Color(), 8.0, 0.004, 1.0, 0.95)
	fins.set_shader_parameter("edge_shade", 0.55)
	fins.set_shader_parameter("ray_color", color.darkened(0.3))
	_skins.append(fins)
	var top := func(along: float) -> Vector3: return _loft_point(ends, profile, at.call(along), 1.0)
	var bottom := func(along: float) -> Vector3: return _loft_point(ends, profile, at.call(along), -1.0)
	# A tall sickle dorsal fin right behind the head, a tiny second one and an
	# anal fin near the tail.
	_membrane(self, fins, top.call(0.36) * Vector3(0.0, 0.94, 1.0), top.call(0.5) * Vector3(0.0, 0.94, 1.0), Vector3(0.0, 1.0, 0.35),
			[h * 1.0, h * 0.75, h * 0.3, h * 0.12, h * 0.05], -0.6, 0.0)
	_membrane(self, fins, top.call(0.86) * Vector3(0.0, 0.9, 1.0), top.call(0.9) * Vector3(0.0, 0.9, 1.0), Vector3(0.0, 1.0, 0.9),
			[h * 0.12, h * 0.05], 0.0, 0.0)
	_membrane(self, fins, bottom.call(0.62) * Vector3(0.0, 0.92, 1.0), bottom.call(0.72) * Vector3(0.0, 0.92, 1.0), Vector3(0.0, -1.0, 0.6),
			[h * 0.45, h * 0.25, h * 0.08], 0.5, 0.0)
	# Long sickle pectorals low behind the head, on the swim animation's pivots.
	var pectoral := _loft_point(ends, profile, at.call(0.4), -0.6)
	_fin_pivots(Vector3(pectoral.x * 0.9, pectoral.y, pectoral.z))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, fins, Vector3(0.0, 0.0, -l * 0.03), Vector3(0.0, 0.0, l * 0.03), Vector3(side * 0.8, -0.5, 1.0),
				[l * 0.28, l * 0.2, l * 0.06], 0.3, 0.0)
	# A big crescent tail.
	_tail_pivot(Vector3(0.0, 0.0, ends.y - l * 0.04))
	var stalk: float = profile.call(inverse_lerp(ends.x, ends.y, ends.y - l * 0.04)).y
	_membrane(tail, fins, Vector3(0.0, stalk * 0.9, 0.0), Vector3(0.0, -stalk * 0.9, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.27, l * 0.11, l * 0.04, l * 0.11, l * 0.27], -2.3, 0.0)
	# Big eyes, as swordfish have, deep blue round the pupil.
	for side: float in [-1.0, 1.0]:
		var eye := _loft_point(ends, profile, at.call(0.34), 0.2) * Vector3(side * 0.88, 1.0, 1.0)
		_eye(eye, h * 0.14, Vector3(side * 0.85, 0.1, -0.5), 0.72, null, Color(0.1, 0.22, 0.5), 0.4)


## Hybrid: a butterfly koi, white with orange-red patches and a few ink spots
## (koi_skin.gdshader), with long flowing fins and a big forked tail, all thin
## frilly membranes that ripple as it swims (fin_membrane.gdshader), whiskers
## and round lips. Its fins and tail reach out past the hitbox.
func _build_koi() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var color := Color(0.93, 0.3, 0.07)
	_body_material = _material(color)  # for set_body_color(); the skin is shaded by koi_skin
	var skin := ShaderMaterial.new()
	skin.shader = KOI_SKIN
	skin.set_shader_parameter("albedo", color)
	_skins.append(skin)
	var ends := Vector2(-l * 0.5, l * 0.36)
	var semi := Vector2(w * 0.24, h * 0.46)
	skin.set_shader_parameter("girth", (semi.x + semi.y) / 2.0)
	skin.set_shader_parameter("scales_from", -l * 0.33)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _koi_mesh(ends, semi)
	body.material_override = skin
	add_child(body)
	var fins := _fin_material(Color(1.0, 0.86, 0.74), Color(1.0, 0.97, 0.93), 14.0, 0.035, 0.8, 0.5)
	fins.set_shader_parameter("ray_color", Color(1.0, 0.6, 0.4))
	# Long flowing pectorals on the swim animation's pivots, little pelvics.
	_fin_pivots(Vector3(semi.x * 0.7, -semi.y * 0.45, -l * 0.22))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, fins, Vector3(0.0, 0.0, -0.03), Vector3(0.0, 0.0, 0.05), Vector3(side, -0.3, 0.9),
				[l * 0.16, l * 0.24, l * 0.26, l * 0.22], 0.5, 0.15, 0.08)
		_membrane(self, fins, Vector3(side * semi.x * 0.35, -_koi_height(ends, semi, 0.0) * 0.8, -l * 0.02), Vector3(side * semi.x * 0.3, -_koi_height(ends, semi, l * 0.06) * 0.8, l * 0.06),
				Vector3(side * 0.5, -0.7, 0.8), [l * 0.08, l * 0.11, l * 0.09], 0.3, 0.12, 0.05)
	# A long ruffled dorsal fin along the back, a small anal fin underneath.
	_membrane(self, fins, Vector3(0.0, _koi_height(ends, semi, -l * 0.1) * 0.93, -l * 0.1), Vector3(0.0, _koi_height(ends, semi, l * 0.26) * 0.9, l * 0.26), Vector3(0.0, 1.0, 0.9),
			[h * 0.28, h * 0.42, h * 0.4, h * 0.34, h * 0.26], 0.0, 0.14, 0.12)
	_membrane(self, fins, Vector3(0.0, -_koi_height(ends, semi, l * 0.17) * 0.9, l * 0.17), Vector3(0.0, -_koi_height(ends, semi, l * 0.28) * 0.9, l * 0.28), Vector3(0.0, -1.0, 0.8),
			[h * 0.2, h * 0.26, h * 0.18], 0.0, 0.12, 0.06)
	# The big forked tail: two long lobes fanning up and down.
	_tail_pivot(Vector3(0.0, 0.0, ends.y - l * 0.04))
	var stalk := _koi_height(ends, semi, ends.y - l * 0.04)
	_membrane(tail, fins, Vector3(0.0, stalk * 0.9, 0.0), Vector3(0.0, -stalk * 0.9, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.34, l * 0.25, l * 0.14, l * 0.25, l * 0.34], 1.3, 0.15, 0.08)
	# Eyes on the sides of the head, round lips, and two pairs of whiskers.
	var head_z := -l * 0.37
	var head := semi.x * _koi_radius(inverse_lerp(ends.x, ends.y, head_z))
	for side: float in [-1.0, 1.0]:
		_eye(Vector3(side * head * 0.8, semi.y * 0.18, head_z), h * 0.12, Vector3(side * 0.8, 0.15, -0.6), 0.65)
	var lips_at := Vector3(0.0, -semi.y * 0.06, ends.x + 0.01)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.5
	var lip_material := _material(Color(1.0, 0.8, 0.74), 0.4)
	_part(self, ring, lip_material, lips_at, Vector3(w * 0.09, 0.07, w * 0.075), Vector3(PI / 2.0, 0.0, 0.0)).name = "Lips"
	_mouth(lips_at + Vector3(0.0, 0.0, -0.008), Vector3(w * 0.03, w * 0.025, 0.02))
	for side: float in [-1.0, 1.0]:
		for whisker: Vector2 in [Vector2(l * 0.06, 0.6), Vector2(l * 0.035, -0.2)]:
			var root := lips_at + Vector3(side * w * 0.045, -0.005, 0.02)
			var barbel := MeshInstance3D.new()
			barbel.name = "Whisker"
			barbel.mesh = _tube_mesh(whisker.x, 0.006, -0.9)
			barbel.material_override = lip_material
			barbel.position = root
			barbel.basis = Basis.looking_at(-Vector3(side * 0.8, -0.4, whisker.y).normalized())
			add_child(barbel)


## How thick a koi is (of its widest) `along` it, nose 0 to tail 1: a round
## head, widest a third of the way back, narrowing to a slim tail stalk with a
## rounded end.
static func _koi_radius(along: float) -> float:
	return _taper(along, 0.33, 0.93, 0.2)


## How high a koi's top is (m) at z, the body running nose `ends.x` to tail
## `ends.y`, `semi.y` at its tallest.
static func _koi_height(ends: Vector2, semi: Vector2, z: float) -> float:
	return semi.y * _koi_radius(inverse_lerp(ends.x, ends.y, z))


## A koi's body from its nose (`ends.x`) to its tail (`ends.y`), `semi` its
## widest half width and height.
func _koi_mesh(ends: Vector2, semi: Vector2) -> ArrayMesh:
	return _loft_mesh(ends, func(along: float) -> Vector3:
		var radius := _koi_radius(along)
		return Vector3(semi.x * radius, semi.y * radius, 0.0))


## How thick a fish is (of its widest) `along` it, nose 0 to tail 1: a snout
## swelling to its widest at `widest` (`nose` 0.5 a round head, toward 1 a
## pointed one), narrowing to a tail stalk `stalk_size` thick at `stalk`, with a
## rounded end.
static func _taper(along: float, widest: float, stalk: float, stalk_size: float, nose := 0.5) -> float:
	if along < widest:
		return pow(maxf(1.0 - pow((widest - along) / widest, 2.0), 0.0), nose)
	if along < stalk:
		var t := (along - widest) / (stalk - widest)
		return lerpf(1.0, stalk_size, t * t * (3.0 - 2.0 * t))
	return stalk_size * sqrt(maxf(1.0 - pow((along - stalk) / (1.0 - stalk), 2.0), 0.0))


## A body of oval slices from its nose (`ends.x`) to its tail (`ends.y`):
## `profile` gives each slice `along` it (nose 0 to tail 1) as (half width, half
## height, height of its middle); it should be 0 thick at both ends to close.
## UV.x runs nose to tail and UV.y round it.
func _loft_mesh(ends: Vector2, profile: Callable, rows := 48, around := 32) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var along := float(i) / rows
		var z := lerpf(ends.x, ends.y, along)
		var slice: Vector3 = profile.call(along)
		for k in around:
			var angle := TAU * k / around
			tool.set_uv(Vector2(along, float(k) / around))
			tool.add_vertex(Vector3(sin(angle) * slice.x, slice.z + cos(angle) * slice.y, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A point on the right side of a lofted body (_loft_mesh) at `z`, `up` of the
## way from its slice's middle to its top (-1 its bottom).
static func _loft_point(ends: Vector2, profile: Callable, z: float, up: float) -> Vector3:
	var slice: Vector3 = profile.call(inverse_lerp(ends.x, ends.y, z))
	return Vector3(slice.x * sqrt(maxf(1.0 - up * up, 0.0)), slice.z + slice.y * up, z)


## The Body: a lofted shape (_loft_mesh) in a `shader` skin painted `color`,
## which set_body_color() tints.
func _skin_body(shader: Shader, color: Color, ends: Vector2, profile: Callable, rows := 48) -> ShaderMaterial:
	_body_material = _material(color)  # for set_body_color(); the skin does the shading
	var skin := ShaderMaterial.new()
	skin.shader = shader
	skin.set_shader_parameter("albedo", color)
	_skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _loft_mesh(ends, profile, rows)
	body.material_override = skin
	add_child(body)
	return skin


## Merc: a yellow boxfish, a rounded box narrowing to its tail, armoured in
## faint plates most with a black spot (box_skin.gdshader), with big eyes, pouty
## lips and little fan fins that flutter fast (fin_membrane.gdshader). It
## squashes and stretches with its acceleration (react) like a jelly sweet: long
## and thin speeding up, short and wide braking, tall falling, flat landing.
func _build_boxfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var color := Color(1.0, 0.8, 0.06)
	# A unit box scaled to the hitbox, so it all squashes as one; `inside` it
	# undoes that so the parts are placed in metres.
	squash = Node3D.new()
	squash.name = "Squash"
	_squash_base = _size
	squash.scale = _squash_base
	add_child(squash)
	var inside := Node3D.new()
	inside.name = "Inside"
	inside.scale = Vector3.ONE / _squash_base
	squash.add_child(inside)
	_body_material = _material(color)  # for set_body_color(); the skin is shaded by box_skin
	var skin := ShaderMaterial.new()
	skin.shader = BOX_SKIN
	skin.set_shader_parameter("albedo", color)
	skin.set_shader_parameter("plate_size", w * 0.17)
	_skins.append(skin)
	var centre := Vector3(0.0, 0.0, -l * 0.04)
	var semi := Vector3(w * 0.46, h * 0.47, l * 0.42)
	var taper := 0.36
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _box_mesh(semi, 0.5, taper)
	body.material_override = skin
	body.position = centre
	inside.add_child(body)
	# Big eyes high on the front of its sides and pouty lips, riding the squash
	# without squashing (_face_anchor).
	for side: float in [-1.0, 1.0]:
		var eye := centre + Vector3(side * semi.x * 0.9, semi.y * 0.4, -semi.z * 0.62)
		_eye(Vector3.ZERO, h * 0.15, Vector3(side * 0.65, 0.15, -0.75), 0.62, _face_anchor(eye))
	var lips := _face_anchor(centre + Vector3(0.0, -semi.y * 0.28, -semi.z + 0.004))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.5
	_part(lips, ring, _material(Color(1.0, 0.5, 0.45), 0.35), Vector3.ZERO, Vector3(w * 0.12, 0.09, h * 0.15), Vector3(PI / 2.0, 0.0, 0.0)).name = "Lips"
	_part(lips, _sphere(), _material(Color(0.25, 0.05, 0.08), 0.4), Vector3(0.0, 0.0, -0.022), Vector3(w * 0.03, h * 0.04, 0.02)).name = "Mouth"
	# Fan fins: pectorals behind the eyes on the swim animation's pivots, a
	# small dorsal and anal fin near the back, and a rounded tail fan.
	var fins := _fin_material(Color(1.0, 0.62, 0.12), Color(1.0, 0.88, 0.5), 9.0, 0.014, 2.6, 0.45)
	_fin_pivots(Vector3(semi.x * 0.96, -semi.y * 0.12, centre.z - semi.z * 0.18), inside)
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, fins, Vector3(0.0, h * 0.12, 0.0), Vector3(0.0, -h * 0.12, 0.0), Vector3(side * 0.7, 0.0, 1.0),
				[l * 0.11, l * 0.15, l * 0.15, l * 0.11], 0.9, 0.1)
	_membrane(inside, fins, centre + Vector3(0.0, semi.y * _box_narrowing(0.45, taper) * 0.92, semi.z * 0.45), centre + Vector3(0.0, semi.y * _box_narrowing(0.75, taper) * 0.85, semi.z * 0.75),
			Vector3(0.0, 1.0, 0.7), [l * 0.06, l * 0.09, l * 0.06], 0.0, 0.1)
	_membrane(inside, fins, centre + Vector3(0.0, -semi.y * _box_narrowing(0.45, taper) * 0.92, semi.z * 0.45), centre + Vector3(0.0, -semi.y * _box_narrowing(0.75, taper) * 0.85, semi.z * 0.75),
			Vector3(0.0, -1.0, 0.7), [l * 0.06, l * 0.09, l * 0.06], 0.0, 0.1)
	_tail_pivot(centre + Vector3(0.0, 0.0, semi.z * 0.92), inside)
	var stalk := semi.y * _box_narrowing(0.95, taper)
	_membrane(tail, fins, Vector3(0.0, stalk * 0.8, 0.0), Vector3(0.0, -stalk * 0.8, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.18, l * 0.23, l * 0.24, l * 0.23, l * 0.18], 1.2, 0.1)


## How much a boxfish narrows `along` it (-1 the nose to 1 the tail): a little
## toward its snout, down to `taper` at the tail.
static func _box_narrowing(along: float, taper: float) -> float:
	var t := clampf((along - 0.15) / 0.85, 0.0, 1.0)
	var snout := clampf((-along - 0.5) / 0.5, 0.0, 1.0)
	return lerpf(1.0, taper, t * t * (3.0 - 2.0 * t)) * lerpf(1.0, 0.85, snout * snout)


## `value` to the `power`, keeping its sign.
static func _signed_pow(value: float, power: float) -> float:
	return signf(value) * pow(absf(value), power)


## A rounded box (a superellipsoid: `roundness` 1 an ellipsoid, toward 0 a
## box) with half sizes `semi`, narrowing toward the tail (+Z) to `taper`.
func _box_mesh(semi: Vector3, roundness: float, taper: float) -> ArrayMesh:
	var rows := 36
	var around := 56
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var latitude := lerpf(-PI / 2.0, PI / 2.0, float(i) / rows)
		for k in around:
			var longitude := TAU * k / around - PI  # starting at the tail
			var flat := _signed_pow(cos(latitude), roundness)
			var z := -semi.z * flat * _signed_pow(cos(longitude), roundness)
			var narrow := _box_narrowing(z / semi.z, taper)
			var x := semi.x * flat * _signed_pow(sin(longitude), roundness) * narrow
			var y := semi.y * _signed_pow(sin(latitude), roundness) * narrow
			tool.add_vertex(Vector3(x, y, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A spot on a squashing body (`at`, m, at rest) for a face feature: it moves
## with the squash, but what's on it keeps its shape.
func _face_anchor(at: Vector3) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "Face"
	anchor.position = at
	add_child(anchor)
	_face_anchors.append(anchor)
	_face_rest.append(at)
	return anchor


## A fin membrane's look (fin_membrane.gdshader): `root` fading to see-through
## `edge`, `rays` across it, rippling `flutter` m at the edge at `tempo`.
func _fin_material(root: Color, edge: Color, rays: float, flutter: float, tempo := 1.0, edge_alpha := 0.45) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIN_MEMBRANE
	material.set_shader_parameter("albedo", root)
	material.set_shader_parameter("edge_color", edge)
	material.set_shader_parameter("ray_color", root.darkened(0.12))
	material.set_shader_parameter("rays", rays)
	material.set_shader_parameter("flutter", flutter)
	material.set_shader_parameter("tempo", tempo)
	material.set_shader_parameter("edge_alpha", edge_alpha)
	_waving.append(material)
	return material


## A thin fin on `parent`: rays fanning out of a root line from `from` to `to`
## (parent space) toward `out`, as long as `lengths` says along the root (spread
## evenly from its start to its end). `spread` (rad) fans the outer rays apart;
## the edge dips between the rays by `frill` (of their length) and the membrane
## ruffles by `ruffle`.
func _membrane(parent: Node3D, material: ShaderMaterial, from: Vector3, to: Vector3, out: Vector3, lengths: Array,
		spread := 0.0, frill := 0.12, ruffle := 0.0) -> MeshInstance3D:
	var columns := 72
	var rows := 10
	var rays: float = material.get_shader_parameter("rays")
	var along := to - from
	var normal := along.cross(out).normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in columns + 1:
		var u := float(i) / columns
		var direction := out.normalized().rotated(normal, (u - 0.5) * spread)
		var length := _sample(lengths, u) * (1.0 - frill * 0.5 * (1.0 - cos(u * rays * TAU)))
		for j in rows + 1:
			var v := float(j) / rows
			var wave := normal * ruffle * length * v * v * sin(u * TAU * 2.5)
			tool.set_uv(Vector2(u, v))
			tool.add_vertex(from + along * u + direction * length * v + wave)
	for i in columns:
		for j in rows:
			var a := i * (rows + 1) + j
			var b := a + rows + 1
			for corner: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(corner)
	tool.generate_normals()
	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	fin.mesh = tool.commit()
	fin.material_override = material
	fin.extra_cull_margin = 0.1  # it ripples out of its bounds
	parent.add_child(fin)
	return fin


## `values` spread evenly over 0..1, read off smoothly at `t`.
static func _sample(values: Array, t: float) -> float:
	var at := clampf(t, 0.0, 1.0) * (values.size() - 1)
	var i := mini(int(at), values.size() - 2)
	var before: float = values[maxi(i - 1, 0)]
	var after: float = values[mini(i + 2, values.size() - 1)]
	return cubic_interpolate(values[i], values[i + 1], before, after, at - i)


# --- Parts ----------------------------------------------------------------------

func _tail_pivot(at: Vector3, parent: Node3D = null) -> void:
	tail = Node3D.new()
	tail.name = "TailPivot"
	tail.position = at
	(parent if parent else self).add_child(tail)


## Fin pivots either side, at `at` and its mirror (at.x is the right one's).
func _fin_pivots(at: Vector3, parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	fin_left = Node3D.new()
	fin_left.name = "FinLeftPivot"
	fin_left.position = Vector3(-at.x, at.y, at.z)
	parent.add_child(fin_left)
	fin_right = Node3D.new()
	fin_right.name = "FinRightPivot"
	fin_right.position = at
	parent.add_child(fin_right)


## A big round eye: white, a dark pupil looking along `look`, and a sparkle.
## With an `iris` colour the pupil is that colour with a smaller black one on it,
## `dot` (of the pupil's size) in front of its middle: past 0.35 it shows.
func _eye(at: Vector3, radius: float, look: Vector3, pupil := 0.6, parent: Node3D = null, iris := BLACK, dot := 0.3) -> void:
	if parent == null:
		parent = self
	var direction := look.normalized()
	var eye := _part(parent, _sphere(), _material(WHITE, 0.2), at, Vector3.ONE * radius * 2.0)
	eye.name = "Eye"
	var pupil_at := at + direction * radius * (1.0 - pupil * 0.45)
	_part(parent, _sphere(), _material(iris, 0.15), pupil_at, Vector3.ONE * radius * 2.0 * pupil)
	if iris != BLACK:
		_part(parent, _sphere(), _material(BLACK, 0.15), pupil_at + direction * radius * pupil * dot, Vector3.ONE * radius * 1.3 * pupil)
	var sparkle := _material(Color.WHITE)
	sparkle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part(parent, _sphere(), sparkle, pupil_at + (direction + Vector3(0.3, 0.6, 0.0)).normalized() * radius * pupil * 0.75,
			Vector3.ONE * radius * 0.45)


func _mouth(at: Vector3, size: Vector3) -> void:
	var mouth := _part(self, _sphere(), _material(Color(0.25, 0.05, 0.08), 0.4), at, size)
	mouth.name = "Mouth"


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, size: Vector3, rotation_euler := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = rotation_euler
	part.scale = size
	parent.add_child(part)
	return part


func _material(color: Color, roughness := 0.6, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = roughness
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# Unit meshes (1 m across), sized by each part's scale.

func _sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return mesh


func _prism() -> PrismMesh:
	return PrismMesh.new()


func _capsule() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return mesh


func _cylinder() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	return mesh
