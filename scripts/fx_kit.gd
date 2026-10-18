class_name FxKit
extends RefCounted
## Shared pieces for effects (the arsenal pass, 2026-10-18: Unnatural's weapons,
## and Explosion): soft textures, glowing materials, jagged paths and the
## ribbons drawn along them, a bubble/shell shader that's bright at the rim
## and clear in the middle, and the near-camera fade. Textures, the shader
## and the shared materials are made once.
##
## The near-camera fade: the camera follows from behind, so whatever a fish
## leaves behind it (a fire trail, mines, a coil) sweeps right past the lens.
## Within NEAR m it can't be seen; by FAR it's at full strength.

const NEAR := 2.0
const FAR := 6.0

static var _dot: GradientTexture2D
static var _across: GradientTexture2D
static var _band: GradientTexture2D
static var _along: GradientTexture2D
static var _rim_shader: Shader


## A glowing material: unshaded, added on, never hiding what's behind it, both
## sides drawn. `texture` multiplies it (its alpha too); `fade` fades it near the camera.
static func glow(color: Color, texture: Texture2D = null, fade := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.albedo_texture = texture
	if fade:
		fade_near(material)
	return material


## Fades `material` out near the camera (see the class note). Opaque ones
## dither out (no sorting trouble); see-through ones fade their alpha.
static func fade_near(material: BaseMaterial3D, near := NEAR, far := FAR) -> void:
	var opaque := material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER if opaque else BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = near
	material.distance_fade_max_distance = far


## A soft round glow: white in the middle, gone at the edge.
static func dot() -> GradientTexture2D:
	if _dot == null:
		_dot = _radial([[0.0, 1.0], [0.25, 0.7], [0.6, 0.18], [1.0, 0.0]])
	return _dot


## A soft ring: clear in the middle, a bright band near the edge, gone at it
## (a shockwave seen face on).
static func band() -> GradientTexture2D:
	if _band == null:
		_band = _radial([[0.0, 0.0], [0.55, 0.05], [0.82, 0.55], [0.9, 1.0], [1.0, 0.0]])
	return _band


## Across a ribbon (u): clear at the edges, white in the middle.
static func across() -> GradientTexture2D:
	if _across == null:
		var gradient := _gradient([[0.0, 0.0], [0.3, 0.25], [0.5, 1.0], [0.7, 0.25], [1.0, 0.0]])
		_across = GradientTexture2D.new()
		_across.gradient = gradient
		_across.width = 32
		_across.height = 1
	return _across


## Along v: full at 0, gone at 1 (a streak trailing off).
static func along() -> GradientTexture2D:
	if _along == null:
		var gradient := _gradient([[0.0, 1.0], [0.4, 0.45], [1.0, 0.0]])
		_along = GradientTexture2D.new()
		_along.gradient = gradient
		_along.fill_from = Vector2(0.5, 0.0)
		_along.fill_to = Vector2(0.5, 1.0)
		_along.width = 1
		_along.height = 32
	return _along


## A see-through shell, bright at its rim and nearly clear face on, with a
## little highlight: bubbles, a shockwave, a jelly's bell. Added on. `fade`
## fades it near the camera. Set "tint" (colour and strength) to animate it.
static func rim(color: Color, core := 0.06, shine := 0.5, fade := false) -> ShaderMaterial:
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(1.0);
uniform float core = 0.06;
uniform float shine = 0.5;
uniform float rim_power = 2.2;
uniform float fade_near = 0.0;
uniform float fade_far = 0.0;
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(1.0 - facing, rim_power);
	float spot = pow(clamp(dot(NORMAL, normalize(vec3(-0.45, 0.55, 0.7))), 0.0, 1.0), 48.0);
	float alpha = tint.a * (core + edge) + shine * spot * tint.a;
	if (fade_far > 0.0) {
		alpha *= smoothstep(fade_near, fade_far, -VERTEX.z);
	}
	ALBEDO = tint.rgb + vec3(spot * shine);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _rim_shader
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("core", core)
	material.set_shader_parameter("shine", shine)
	if fade:
		material.set_shader_parameter("fade_near", NEAR)
		material.set_shader_parameter("fade_far", FAR)
	return material


## A jagged line from `a` to `b` in `steps` steps: each point in between knocked
## up to `jitter` m off, and bowed `bow` (a vector) at the middle. Both ends kept.
static func jagged(a: Vector3, b: Vector3, steps: int, jitter: float, dice: RandomNumberGenerator, bow := Vector3.ZERO) -> PackedVector3Array:
	var points := PackedVector3Array([a])
	for k in range(1, steps):
		var t := float(k) / steps
		var p := a.lerp(b, t) + bow * sin(t * PI)
		p += Vector3(dice.randf_range(-1, 1), dice.randf_range(-1, 1), dice.randf_range(-1, 1)) * jitter
		points.append(p)
	points.append(b)
	return points


## Ribbons along each of `strands` (lines of points), each `widths[n]` m wide
## (`taper`: narrowing to a point at its end), as one mesh. Each segment is two
## ribbons crossed at right angles round it, so it has width from any side
## (every split-screen view). u runs across a ribbon (0 one edge, 1 the
## other), v along it (0 at its start, 1 at its end): use across() or along().
## Built into packed arrays at once, so it's cheap enough for a physics tick.
## `fade`: each vertex's colour alpha falls from 1 at a strand's start to 0 at
## its end (seen with a material using vertex colour: a trail).
static func ribbons(strands: Array, widths: Array, taper := false, fade := false) -> ArrayMesh:
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for n in strands.size():
		var line: PackedVector3Array = strands[n]
		var width: float = widths[n] if n < widths.size() else widths[-1]
		var last := line.size() - 1
		for i in last:
			var a := line[i]
			var b := line[i + 1]
			var direction := b - a
			if direction.length_squared() < 0.000001:
				continue
			direction = direction.normalized()
			var side := direction.cross(Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT).normalized()
			var wa := width * 0.5 * ((1.0 - float(i) / last) if taper else 1.0)
			var wb := width * 0.5 * ((1.0 - float(i + 1) / last) if taper else 1.0)
			var va := float(i) / last
			var vb := float(i + 1) / last
			for across_dir: Vector3 in [side, direction.cross(side)]:
				points.append_array(PackedVector3Array([a - across_dir * wa, a + across_dir * wa, b + across_dir * wb,
						a - across_dir * wa, b + across_dir * wb, b - across_dir * wb]))
				uvs.append_array(PackedVector2Array([Vector2(0, va), Vector2(1, va), Vector2(1, vb),
						Vector2(0, va), Vector2(1, vb), Vector2(0, vb)]))
				var ca := Color(1, 1, 1, 1.0 - va if fade else 1.0)
				var cb := Color(1, 1, 1, 1.0 - vb if fade else 1.0)
				colors.append_array(PackedColorArray([ca, ca, cb, ca, cb, cb]))
	var mesh := ArrayMesh.new()
	if points.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A lance of light along -z, for a projectile's MultiMesh (scaled by its
## radius, stretched along its flight): a hard bright diamond core from
## `tip` (z, negative) to `back`, `half_width` at its widest; a soft glowing
## sheath round it `sheath` wide; and a trail `trail` long behind, fading.
## Two surfaces: the core in `core_color`, the glow in `glow_color`.
static func lance_mesh(core_color: Color, glow_color: Color, tip: float, back: float, half_width: float, sheath: float, trail: float) -> ArrayMesh:
	var widest := lerpf(tip, back, 0.3)
	var ring := [Vector3(half_width, 0, widest), Vector3(0, half_width, widest), Vector3(-half_width, 0, widest), Vector3(0, -half_width, widest)]
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 4]
		for v: Vector3 in [Vector3(0, 0, tip), a, b, Vector3(0, 0, back), b, a]:
			core.add_vertex(v)
	var mesh := ArrayMesh.new()
	core.commit(mesh)
	var core_material := glow(core_color)
	mesh.surface_set_material(0, core_material)
	var glow_material := glow(glow_color, across())
	glow_material.vertex_color_use_as_albedo = true
	# The sheath from the back to a point at the tip (no hard edge in front).
	var sheath_mesh := ribbons([PackedVector3Array([Vector3(0, 0, back), Vector3(0, 0, widest), Vector3(0, 0, tip)])], [sheath], true)
	var trail_mesh := ribbons([PackedVector3Array([Vector3(0, 0, back * 0.6), Vector3(0, 0, back * 0.6 + trail * 0.5),
			Vector3(0, 0, back * 0.6 + trail)])], [sheath * 0.8], true, true)
	merge_into(mesh, [[sheath_mesh, Transform3D.IDENTITY], [trail_mesh, Transform3D.IDENTITY]], glow_material)
	return mesh


## Joins `parts` ([Mesh, Transform3D] each) into one surface of `mesh` with
## `material`: many little meshes drawn as one.
static func merge_into(mesh: ArrayMesh, parts: Array, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		tool.append_from(part[0], 0, part[1])
	tool.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## A flat square 2 m across in the xz plane (face up), for a band() or dot() disc.
static func disc_mesh() -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	return plane


static func _gradient(stops: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_offset(0, stops[0][0])
	gradient.set_color(0, Color(1, 1, 1, stops[0][1]))
	gradient.set_offset(1, stops[-1][0])
	gradient.set_color(1, Color(1, 1, 1, stops[-1][1]))
	for k in range(1, stops.size() - 1):
		gradient.add_point(stops[k][0], Color(1, 1, 1, stops[k][1]))
	return gradient


static func _radial(stops: Array) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = _gradient(stops)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture
