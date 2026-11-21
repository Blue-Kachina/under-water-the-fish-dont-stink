class_name TerrainLight
extends RefCounted
## Light that rock blocks (planning_procedural_world.md, phase 5, D7 a+b). Bakes, once per terrain build, the two
## textures shaders/water_openness.gdshaderinc reads, and sets them as global shader uniforms (world space):
##   terrain_vol     RG8 ImageTexture3D (terrain_light_cell m): R openness (distance to rock / terrain_open_reach),
##                   G skylight swept down from the top with a 1-2-1 blur, wholly absorbed by rock.
##   terrain_shadow  RH 2D (terrain_shadow_cell m): the height of the first rock along the sun's line through each
##                   (x, z) of the terrain's base plane; a point is shadowed when that rock is above it.
## The rock, sand, reef, stone, flora, caustics, light shafts and the fog's in-scatter all read them. clear() (or no
## terrain) puts terrain_light.w back to 0, and every shader then behaves as before.

## The textures the globals point at (kept here so they live as long as the globals use them).
static var _volume: ImageTexture3D
static var _shadow: ImageTexture
## The terrain whose bake the globals hold.
static var _owner: Terrain
## Whether the owner's bake has a sun shadow (the strength stays 0 without one).
static var _shadow_ready := false


## Bakes `terrain`'s volume and shadow and points the globals at them. Returns timings (ms) for stats.
static func bake(terrain: Terrain, settings: TerrainSettings) -> Dictionary:
	var out := {}
	if terrain == null or terrain.field == null or not settings.terrain_light_enabled:
		clear()
		return out
	var t0 := Time.get_ticks_usec()
	var base := terrain.global_position
	var vol: Dictionary = terrain.field.bake_openness(maxf(settings.terrain_light_cell, 0.25), maxf(settings.terrain_open_reach, 0.5),
			settings.terrain_sky_absorb)
	if vol.is_empty():
		clear()
		return out
	var size: Vector3i = vol["size"]
	var cell: float = vol["cell"]
	var data: PackedByteArray = vol["data"]
	var slice := size.x * size.y * 2
	var images: Array[Image] = []
	for k in size.z:
		images.append(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, data.slice(k * slice, (k + 1) * slice)))
	if _volume == null:
		_volume = ImageTexture3D.new()
	_volume.create(Image.FORMAT_RG8, size.x, size.y, size.z, false, images)
	var origin: Vector3 = vol["origin"]
	var t1 := Time.get_ticks_usec()
	out["ms_volume"] = (t1 - t0) / 1000.0

	var rs := RenderingServer
	rs.global_shader_parameter_set("terrain_vol", _volume)
	# Texel i's centre is sample i: shift by half a cell and span the whole texel count.
	var vol_origin := base + origin - Vector3.ONE * cell * 0.5
	rs.global_shader_parameter_set("terrain_vol_origin", Vector4(vol_origin.x, vol_origin.y, vol_origin.z, 0.0))
	rs.global_shader_parameter_set("terrain_vol_size", Vector4(size.x * cell, size.y * cell, size.z * cell, 0.0))

	var lit_on := settings.terrain_sun_shadow > 0.0
	if lit_on:
		var to_sun := WaterLook.sun_dir.normalized()
		if to_sun.y < 0.1:
			to_sun = Vector3(to_sun.x, 0.1, to_sun.z).normalized()
		var sh: Dictionary = terrain.field.bake_sun_shadow(to_sun, maxf(settings.terrain_shadow_cell, 0.25))
		if sh.is_empty():
			lit_on = false
		else:
			var ssize: Vector2i = sh["size"]
			var scell: float = sh["cell"]
			var heights: PackedFloat32Array = sh["data"]
			var floor_miss := origin.y - 1.0  # no rock on the line: below the grid's bottom (keeps the filtering sane)
			for i in heights.size():
				if heights[i] < -1000.0:
					heights[i] = floor_miss
			var image := Image.create_from_data(ssize.x, ssize.y, false, Image.FORMAT_RF, heights.to_byte_array())
			image.convert(Image.FORMAT_RH)
			if _shadow == null:
				_shadow = ImageTexture.create_from_image(image)
			else:
				_shadow.set_image(image)
			var rect_origin: Vector2 = sh["origin"]
			rs.global_shader_parameter_set("terrain_shadow", _shadow)
			rs.global_shader_parameter_set("terrain_shadow_rect", Vector4(base.x + rect_origin.x - scell * 0.5, base.z + rect_origin.y - scell * 0.5,
					ssize.x * scell, ssize.y * scell))
			var bake_dir: Vector3 = sh["to_sun"]
			rs.global_shader_parameter_set("terrain_shadow_sun", Vector4(bake_dir.x, bake_dir.y, bake_dir.z, base.y))
	out["ms_shadow"] = (Time.get_ticks_usec() - t1) / 1000.0
	_owner = terrain
	_shadow_ready = lit_on
	push(settings)
	return out


## The live strengths (the panel's values) into the globals (the sun's shadow only once one is baked).
static func push(settings: TerrainSettings) -> void:
	var shadow_baked := _shadow_ready
	var on := 1.0 if settings.terrain_light_enabled else 0.0
	RenderingServer.global_shader_parameter_set("terrain_light", Vector4(settings.terrain_skylight,
			settings.terrain_sun_shadow if shadow_baked else 0.0, settings.terrain_grotto_dark, on))
	RenderingServer.global_shader_parameter_set("terrain_light2", Vector4(settings.terrain_shadow_soft, settings.terrain_open_ao,
			settings.terrain_fog_dark, settings.terrain_shaft_cut))


## No terrain: every shader reads "open and lit" again.
static func clear(only_for: Terrain = null) -> void:
	if only_for != null and only_for != _owner:
		return
	_owner = null
	RenderingServer.global_shader_parameter_set("terrain_light", Vector4.ZERO)


static func owner() -> Terrain:
	return _owner
