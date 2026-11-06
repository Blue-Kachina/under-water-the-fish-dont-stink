extends Node3D
## The water a whale's tail pushes (planning_marco_whales.md §7): on each fluke
## power stroke, on every machine,
##  - a vortex ring shed behind the flukes: a thin ring that widens, drifts back and fades;
##  - a pressure ripple of silt and plankton pushed outward;
##  - near the floor a silt cloud kicked up, near the roof a boil;
##  - bubbles from the fluke tips at hard strokes (boost).
## It listens to the Titans' FishModel.power_stroke(strength, at) and, until a model has
## the signal, fires a stand-in stroke every whale_stroke_gap s while the whale moves
## (the same stand-in the match uses for the wake push). Effects are pooled by count
## (wake_fx_max) so four whales don't flood the scene.
##
## Loaded by path (HiderLooks), no class_name.

const RING_SHADER_CODE := "
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.7, 0.95, 1.0, 1.0);
uniform float life = 1.0;
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = clamp(life * life * 0.35, 0.0, 1.0);
}
"

var match_node: Node
var settings: Resource
var _ring_shader: Shader
var _puff: GradientTexture2D
var _live: Array[Dictionary] = []  # {node, age, life, kind, ...}
var _watched := {}  # fish -> model
var _stub_left := {}  # fish -> s to the next stand-in stroke
var _clock := 0.0


func bind(mp_match: Node) -> void:
	match_node = mp_match
	var from_match: Variant = mp_match.get("settings")
	settings = from_match as Resource if from_match is Resource else MarcoPoloSettings.shared()
	top_level = true
	_ring_shader = Shader.new()
	_ring_shader.code = RING_SHADER_CODE


func _setting(setting: String, fallback: Variant) -> Variant:
	var value: Variant = settings.get(setting) if settings else null
	return fallback if value == null else value


func _process(delta: float) -> void:
	if not is_instance_valid(match_node) or not bool(_setting("wake_fx", true)):
		_clear()
		return
	_clock += delta
	for fish: Variant in _titans():
		_watch(fish as FishController, delta)
	_age(delta)


## Every Titans-class fish in the match.
func _titans() -> Array:
	var out: Array = []
	var players: Variant = match_node.get("players")
	if players is Array:
		for fish: Variant in players:
			if is_instance_valid(fish) and fish is FishController and int((fish as FishController).character) == int(FishCharacter.FishClass.get("TITAN", -1)):
				out.append(fish)
	return out


func _watch(fish: FishController, delta: float) -> void:
	var model: Variant = fish.get("_visual")
	if model == null:
		return
	if _watched.get(fish) != model:
		_watched[fish] = model
		if (model as Object).has_signal("power_stroke"):
			(model as Object).connect("power_stroke", _on_stroke.bind(fish))
	if (model as Object).has_signal("power_stroke"):
		return
	var left: float = float(_stub_left.get(fish, 0.0)) - delta
	if left <= 0.0:
		var speed := fish.swim_velocity().length() if fish.has_method("swim_velocity") else fish.linear_velocity.length()
		if speed > 1.0:
			var tail := fish.global_transform.translated_local(Vector3(0.0, 0.0, float(fish.get("hitbox_length")) * 0.5 if fish.get("hitbox_length") != null else 3.0))
			_on_stroke(clampf(speed / 15.0, 0.3, 1.0), tail, fish)
		left = float(_setting("whale_stroke_gap", 1.0))
	_stub_left[fish] = left


## A power stroke: `strength` 0..1 at the flukes' transform `at` (-Z the fish's nose, so the tail drifts toward +Z).
func _on_stroke(strength: float, at: Transform3D, fish: FishController) -> void:
	if not bool(_setting("wake_fx", true)) or not is_inside_tree():
		return
	var cap := int(_setting("wake_fx_max", 24))
	var width := _whale_width(fish)
	_sound("mp/whomp_boost" if fish.is_boosting else "mp/whomp", at.origin, strength)
	_ring(at, strength, width)
	_silt(at, strength, width)
	var space := get_world_3d().direct_space_state
	var floor_hit := _ray(space, at.origin, Vector3.DOWN, float(_setting("wake_floor_reach", 9.0)))
	if not floor_hit.is_empty():
		_cloud(floor_hit.position as Vector3 + Vector3.UP * 0.2, strength, width, Vector3.UP, Color(0.62, 0.58, 0.5, 0.5), 1.0)
	var roof_hit := _ray(space, at.origin, Vector3.UP, float(_setting("wake_roof_reach", 9.0)))
	if not roof_hit.is_empty():
		_cloud(roof_hit.position as Vector3 - Vector3.UP * 0.3, strength, width, Vector3.DOWN, Color(0.8, 0.95, 1.0, 0.45), 0.6)
	if strength >= float(_setting("wake_bubble_strength", 0.75)):
		_bubbles(at, width)
	while _live.size() > cap:
		_drop(0)


## A 3D cue through the Sfx autoload (absent in a bare probe).
func _sound(id: String, at: Vector3, volume: float) -> void:
	var sfx: Node = get_tree().root.get_node_or_null("Sfx") if is_inside_tree() else null
	if sfx and sfx.has_method("play_at"):
		sfx.call("play_at", id, at, clampf(volume, 0.0, 1.0))


func _whale_width(fish: FishController) -> float:
	var length: Variant = fish.get("hitbox_length")
	return float(length) * 0.36 if length != null else 2.4


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach, 1 | (1 << 5))
	return space.intersect_ray(query)


func _ring(at: Transform3D, strength: float, width: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(at.origin) < float(_setting("wake_swirl_reach", 14.0)):
		_sound("mp/wake_swirl", at.origin, 0.4 + 0.6 * strength)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 8
	var material := ShaderMaterial.new()
	material.shader = _ring_shader
	var node := MeshInstance3D.new()
	node.mesh = torus
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	# The ring stands across the whale's travel: its plane is the fish's x/y.
	node.global_transform = Transform3D(at.basis.orthonormalized() * Basis(Vector3.RIGHT, PI * 0.5), at.origin)
	var life := float(_setting("wake_ring_life", 1.8))
	_live.append({"node": node, "age": 0.0, "life": life, "kind": "ring", "material": material, "origin": at.origin,
			"drift": at.basis.z.normalized() * float(_setting("wake_ring_drift", 2.5)),
			"size": width * float(_setting("wake_ring_size", 0.7)) * (0.6 + 0.4 * strength)})


## A pressure ripple of silt and plankton pushed outward round the flukes.
func _silt(at: Transform3D, strength: float, width: float) -> void:
	_cloud(at.origin, strength, width, at.basis.z.normalized(), Color(0.75, 0.85, 0.8, 0.35), 1.6)


## One-shot burst of soft quads: `amount` scaled by wake_silt_amount.
func _cloud(origin: Vector3, strength: float, width: float, up: Vector3, tint: Color, spread: float) -> void:
	var amount := int(float(_setting("wake_silt_amount", 36)) * (0.5 + 0.5 * strength) * spread)
	if amount <= 0:
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = clampi(amount, 4, 200)
	particles.lifetime = float(_setting("wake_silt_life", 2.4))
	particles.explosiveness = 0.9
	particles.randomness = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = width * 0.35
	particles.direction = up
	particles.spread = 80.0
	particles.initial_velocity_min = width * 0.3 * spread
	particles.initial_velocity_max = width * 0.9 * spread
	particles.damping_min = 1.0
	particles.damping_max = 2.5
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * width * 0.28
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = _puff_texture()  # soft and round, not a square
	material.billboard_keep_scale = true
	material.disable_receive_shadows = true
	quad.material = material
	particles.mesh = quad
	particles.color = tint
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.global_position = origin
	particles.emitting = true
	_live.append({"node": particles, "age": 0.0, "life": particles.lifetime + 0.2, "kind": "cloud"})


## A white disc fading to clear at its rim: the silt puffs' sprite (made once).
func _puff_texture() -> Texture2D:
	if _puff == null:
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
		_puff = GradientTexture2D.new()
		_puff.gradient = fade
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
		_puff.width = 64
		_puff.height = 64
	return _puff


## Bubbles from the fluke tips at a hard stroke.
func _bubbles(at: Transform3D, width: float) -> void:
	for side in [-1.0, 1.0]:
		var particles := CPUParticles3D.new()
		particles.one_shot = true
		particles.emitting = false
		particles.amount = 14
		particles.lifetime = 1.6
		particles.explosiveness = 0.7
		particles.randomness = 0.8
		particles.direction = Vector3.UP
		particles.spread = 40.0
		particles.initial_velocity_min = 0.6
		particles.initial_velocity_max = 1.8
		particles.gravity = Vector3(0.0, 1.2, 0.0)
		var sphere := SphereMesh.new()
		sphere.radius = 0.04
		sphere.height = 0.08
		sphere.radial_segments = 6
		sphere.rings = 3
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.85, 0.97, 1.0, 0.7)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere.material = material
		particles.mesh = sphere
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particles)
		particles.global_position = at.origin + at.basis.x.normalized() * side * width * 0.9
		particles.emitting = true
		_live.append({"node": particles, "age": 0.0, "life": 2.0, "kind": "bubbles"})


func _age(delta: float) -> void:
	for i in range(_live.size() - 1, -1, -1):
		var entry := _live[i]
		entry.age = float(entry.age) + delta
		var t := clampf(float(entry.age) / maxf(float(entry.life), 0.01), 0.0, 1.0)
		if entry.kind == "ring":
			var node := entry.node as MeshInstance3D
			var size := float(entry.size) * (0.35 + 0.9 * (1.0 - pow(1.0 - t, 2.0)))
			node.scale = Vector3(size, size, maxf(size * 0.5, 0.05))
			node.global_position = (entry.origin as Vector3) + (entry.drift as Vector3) * t
			(entry.material as ShaderMaterial).set_shader_parameter("life", 1.0 - t)
		if t >= 1.0:
			_drop(i)


func _drop(index: int) -> void:
	var entry := _live[index]
	if is_instance_valid(entry.node):
		(entry.node as Node).queue_free()
	_live.remove_at(index)


func _clear() -> void:
	while not _live.is_empty():
		_drop(_live.size() - 1)


func _exit_tree() -> void:
	_clear()
