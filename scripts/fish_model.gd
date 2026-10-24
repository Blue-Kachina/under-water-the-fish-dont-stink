class_name FishModel
extends Node3D
## A playable fish's look (one per FishCharacter, in one of its species), made to
## fill its character's hitbox at scale 1: width x height x length, centred on
## the hitbox centre, nose toward -Z. The body fills the box, so what you see is
## what the ball meets; fins and tails may poke out of it a little. Each class
## builds its own in scripts/fish_models/ from the helpers here: lofted bodies,
## fin membranes, lifelike eyes, and the bend that keeps the tail on the body
## (_bend_body).
##
## Every model has the nodes the swim animation moves (TailPivot, FinLeftPivot,
## FinRightPivot) and a Body whose colour set_body_color() changes (replays
## tint each fish in its team's colour). Parts sharing the body's material
## change with it, as do its shader skins (_skins). Fins and skins that ripple as
## it swims (_waving) are moved by react(), which also squashes and stretches a
## model's `squash` node, if it has one, with the fish's acceleration.

const RAY_SKIN := preload("res://shaders/ray_skin.gdshader")
const FIN_MEMBRANE := preload("res://shaders/fin_membrane.gdshader")
const STRIDE_OVERLAY := preload("res://shaders/stride_overlay.gdshader")
const FISH_EYE := preload("res://shaders/fish_eye.gdshader")

var fish_class := FishCharacter.FishClass.SKIRMISHER
## Which of the class's species it wears (FishCharacter.SPECIES).
var species := 0
var tail: Node3D
var fin_left: Node3D
var fin_right: Node3D

## Scaled by react() to squash and stretch, if the model has one.
var squash: Node3D
## How much it squashes and stretches (0: not at all, the realistic models'
## default; 1: the old jelly-sweet boxfish).
var squash_strength := 0.0

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
## The body's bend into its tail (_bend_body, fish_bend.gdshaderinc): behind
## `_bend_span.x` the spine curves in an even arc up to the tail pivot's place
## at rest (`_tail_rest`), turned by `bend_share` of the tail pivot's swing
## there; the pivot rides the end of the arc and swings the rest. `_bent` are
## the meshes the shader bends; `_riders` are nodes carried along the bend
## (bend_rider), at their rest transforms `_rider_rest`.
var bend_share := 0.6
var _bend_span := Vector2.ZERO
var _bend_turn := Vector3.ZERO
var _tail_rest := Vector3.ZERO
var _bent: Array[GeometryInstance3D] = []
var _riders: Array[Node3D] = []
var _rider_rest: Array[Transform3D] = []


static func build(character: FishCharacter.FishClass, species := 0) -> FishModel:
	var model := FishModel.new()
	model.name = "Visual"
	model.fish_class = character
	model.species = clampi(species, 0, FishCharacter.species_count(character) - 1)
	model._size = FishCharacter.hitbox_size(character)
	match character:
		FishCharacter.FishClass.SKIRMISHER:
			ClownfishModel.build(model)
		FishCharacter.FishClass.HUNTER:
			SharkModel.build(model)
		FishCharacter.FishClass.GLIDER:
			RayModel.build(model)
		FishCharacter.FishClass.LANCER:
			SwordfishModel.build(model)
		FishCharacter.FishClass.CHARMER:
			KoiModel.build(model)
		FishCharacter.FishClass.BULWARK:
			BoxfishModel.build(model)
		FishCharacter.FishClass.SCORCHER:
			LionfishModel.build(model)
		FishCharacter.FishClass.DRIFTER:
			JellyModel.build(model)
		FishCharacter.FishClass.BRAWLER:
			MantisModel.build(model)
		FishCharacter.FishClass.BREACHER:
			WhaleSharkModel.build(model)
		FishCharacter.FishClass.ALCHEMIST:
			SeaHareModel.build(model)
	return model


## Squash and stretch with the fish's acceleration (from `velocity`, world
## space, given every frame), on a springy wobble. Speeding up stretches it
## along its length and braking squashes it; falling stretches it tall and
## landing squashes it flat. Volume is kept, so it bulges the other way. The
## edge it's moving toward stays put and the trailing side does the stretching
## (the bottom, when it isn't moving up or down, so it squashes onto the floor).
func react(delta: float, velocity: Vector3) -> void:
	apply_bend()
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
	var target := Vector2(clampf(-local.z / 35.0, -0.3, 0.35), clampf(-local.y / 45.0, -0.35, 0.2)) * squash_strength
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


## Bends the body into the tail: the spine behind `from_z` curves in an even
## arc up to the tail pivot (made first, with _tail_pivot), so the tail stays
## on the body however it swings. The Body and any `parts` (fins on the body's
## bending part, drawn by shaders that include fish_bend.gdshaderinc) bend with
## it; the tail's own fins ride the pivot. bend_share sets how much of the
## swing the body takes.
func _bend_body(from_z: float, parts: Array = []) -> void:
	_tail_rest = tail.position
	_bend_span = Vector2(from_z, _tail_rest.z)
	var body := find_child("Body", true, false) as GeometryInstance3D
	if body and not parts.has(body):
		bend_part(body)
	for part: GeometryInstance3D in parts:
		bend_part(part)


## Has the shader bend `part` with the body (its shader must include
## fish_bend.gdshaderinc). It must sit in the model's own space (a child of the
## model, or of nodes that don't move it).
func bend_part(part: GeometryInstance3D) -> void:
	if _bent.has(part):
		return
	_bent.append(part)
	part.set_instance_shader_parameter("bend_span", _bend_span)
	part.extra_cull_margin = maxf(part.extra_cull_margin, 0.3)  # bent out of its bounds


## A node at `at` (model space, at rest) carried along the body's bend: put
## plain parts (spines, StandardMaterial bits) on it so they ride the bending
## part of the body.
func bend_rider(at: Vector3) -> Node3D:
	var rider := Node3D.new()
	rider.name = "BendRider"
	rider.position = at
	add_child(rider)
	_riders.append(rider)
	_rider_rest.append(rider.transform)
	return rider


## Sets the bend from the tail pivot's swing (react() does, each frame): the
## bent meshes' shaders, the pivot's place on the end of the arc, and the
## riders. Call it after changing tail.rotation without react().
func apply_bend() -> void:
	if _bend_span.y <= _bend_span.x or tail == null:
		return
	_bend_turn = Vector3(tail.rotation.x, tail.rotation.y, 0.0) * bend_share
	for part in _bent:
		part.set_instance_shader_parameter("bend_turn", _bend_turn)
	tail.position = bend_point(_tail_rest)
	for i in _riders.size():
		var rest := _rider_rest[i]
		var bent := bend_transform(rest.origin)
		_riders[i].transform = Transform3D(bent.basis * rest.basis, bent.origin)


## Where `at` (model space, at rest) is with the body bent now: as
## fish_bend.gdshaderinc moves it (keep in step).
func bend_point(at: Vector3) -> Vector3:
	return bend_transform(at).origin


## The bend's turn and move at `at` (model space, at rest): the slice there
## turns with the spine; in front of the bend, nothing moves.
func bend_transform(at: Vector3) -> Transform3D:
	var span := _bend_span.y - _bend_span.x
	var angle := _bend_turn.length()
	if span <= 0.0 or angle < 1e-5 or at.z <= _bend_span.x:
		return Transform3D(Basis.IDENTITY, at)
	var axis := _bend_turn / angle
	var s := minf(at.z - _bend_span.x, span)
	var turn := angle * s / span
	var curve := angle / span
	var side := axis.cross(Vector3.BACK)
	var spine := Vector3(0.0, 0.0, _bend_span.x + sin(turn) / curve) + side * (1.0 - cos(turn)) / curve
	var turned := Basis(axis, turn)
	return Transform3D(turned, spine + turned * Vector3(at.x, at.y, at.z - _bend_span.x - s))


## Whether `part` bends with the body (bend_part).
func is_bent(part: GeometryInstance3D) -> bool:
	return _bent.has(part)


# --- Shapes ---------------------------------------------------------------------

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


## A lifelike eye (fish_eye.gdshader): a glossy ball `radius` m looking along
## `look`, its `iris` ring round a big dark pupil (`pupil`, of the disc). Set it
## into the head (sink most of it in the body so only a cap shows). Returns the
## eye so its material can be tuned (iris_inner, rim_color, pupil_stretch, sheen).
func _real_eye(at: Vector3, radius: float, look: Vector3, iris: Color, pupil := 0.42, parent: Node3D = null) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = FISH_EYE
	material.set_shader_parameter("iris", iris)
	material.set_shader_parameter("iris_inner", iris.darkened(0.55))
	material.set_shader_parameter("pupil", pupil)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var eye := _part(parent if parent else self, mesh, material, at, Vector3.ONE)
	eye.name = "Eye"
	var facing := look.normalized()
	eye.basis = Basis.looking_at(facing, Vector3.BACK if absf(facing.y) > 0.95 else Vector3.UP).scaled(Vector3.ONE * radius * 2.0)
	return eye


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
