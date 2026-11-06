class_name HiderLooks
extends Node
## Swaps every hider between its real model and its reveal copy by the local
## player's role (planning_marco_polo.md §3, "Seeing per machine"). Marco Polo
## draws one view per machine, so which look a hider gets depends only on
## whether the local player is a seeker:
## - a hider or a spectator: every fish shows its real model;
## - a seeker: each live hider (and each Fake Fish) hides its real model and
##   its FX (bow wave, stride stream, bubbles) and shows its Reveal instead,
##   built up through the layers by the local seeker's exposure of it
##   (match.local_exposure). Below the skeleton band nothing is drawn at all.
## - and the local hider's own fish (settings.self_view) the way the seekers
##   see it (match.max_exposure), with a dashed outline (marco_sketch.gdshader)
##   once it's less than fully visible, so they never lose sight of themselves.
## Other HUD bits that would give a hider away (name tags, arrows, the target
## wheel) ask concealed(fish).

const REVEAL_SHADER := preload("res://shaders/marco_reveal.gdshader")
const AURA_SHADER := preload("res://shaders/marco_aura.gdshader")
const SKETCH_SHADER := preload("res://shaders/marco_sketch.gdshader")
## MarcoPoloMatch.Role.SEEKER (Role { HIDER, SEEKER }).
const SEEKER := 1
## Copied once from a real material onto its reveal one, when the real has them.
const STILL_PARAMS := ["rays", "flutter", "waves", "tempo", "bell_apex", "bell_depth", "bell_squeeze", "bell_flatten",
		"hinge", "span", "rest_flap", "ripple", "wave", "wave_from", "wave_to"]
## And every frame (the swim, the bell, the wings).
const MOVING_PARAMS := ["phase", "effort", "bell_crown", "bell_margin", "bell_ripple", "bell_ripple_phase",
		"flap_left", "flap_right", "sweep_left", "sweep_right", "ripple_bias"]

var match_node: Node
var settings: MarcoPoloSettings
## Whether this machine draws a seeker's view now.
var seeker_view := false
## The local hider's own fish, drawn as the seekers see it (self_view), or null.
var self_fish: FishController
var _looks := {}  # FishController -> Reveal
## The "Marco!" scan pulse and its ghosts (made in bind).
var scan: MarcoScan


## Hooks the looks to a MarcoPoloMatch (typed as Node so this parses on its own).
func bind(mp_match: Node) -> void:
	match_node = mp_match
	var from_match: Variant = mp_match.get("settings")
	settings = from_match as MarcoPoloSettings if from_match is MarcoPoloSettings else MarcoPoloSettings.shared()
	if scan == null:
		scan = MarcoScan.new()
		add_child(scan)
	scan.bind(mp_match)
	# Polled every frame too; the signals just make a swap land on the frame it happens.
	for entry: Dictionary in mp_match.get_signal_list():
		if entry.name in ["local_role_changed", "role_changed", "round_started", "spectate_target_changed", "eliminated_fish"]:
			mp_match.connect(entry.name, _on_roles_changed.unbind((entry.args as Array).size()))


## Whether `fish` is drawn as a reveal here (a hider in this seeker's view).
func concealed(fish: Node) -> bool:
	return _looks.has(fish)


## The reveal `fish` shows here, or null.
func reveal_of(fish: Node) -> Reveal:
	return _looks.get(fish) as Reveal


func _exit_tree() -> void:
	for reveal: Reveal in _looks.values():
		reveal.restore()
	_looks.clear()


func _on_roles_changed() -> void:
	_refresh(0.0)


func _process(delta: float) -> void:
	_refresh(delta)


func _refresh(delta: float) -> void:
	if not is_instance_valid(match_node):
		return
	var from_match: Variant = match_node.get("settings")
	if from_match is MarcoPoloSettings:
		settings = from_match
	seeker_view = int(match_node.call("local_view_role")) == SEEKER
	var wanted: Array[FishController] = []
	if seeker_view:
		# Untyped: a popped Fake Fish can already be freed, and a typed loop variable won't take it.
		for fish: Variant in match_node.get("players"):
			if is_instance_valid(fish) and fish is FishController and bool(match_node.call("is_live_hider", fish)):
				wanted.append(fish)
		if match_node.has_method("decoys"):
			for fake: Variant in match_node.call("decoys"):
				if is_instance_valid(fake) and fake is FishController:
					wanted.append(fake)
	self_fish = null
	if not seeker_view and settings.self_view:
		var me: Variant = match_node.call("local_fish")
		if is_instance_valid(me) and me is FishController and bool(match_node.call("is_live_hider", me)):
			self_fish = me
			wanted.append(me)
	for key: Variant in _looks.keys():
		if not is_instance_valid(key) or not wanted.has(key):
			(_looks[key] as Reveal).restore()
			_looks.erase(key)
	var aura_color := _seeker_color()
	for fish in wanted:
		var own := fish == self_fish
		var reveal := _looks.get(fish) as Reveal
		if reveal == null or reveal.model != fish._visual or reveal.self_look != own:
			if reveal:
				reveal.restore()
			reveal = Reveal.new(fish._visual, fish, own)
			_looks[fish] = reveal
		var seen := float(match_node.call("max_exposure" if own else "local_exposure", fish))
		reveal.update(delta, seen, settings, aura_color)


## The local seeker's team colour (the aura's; for a hider's self view, a seeker's).
func _seeker_color() -> Color:
	var me: Variant = match_node.call("local_fish") if match_node.has_method("local_fish") else null
	if not seeker_view and match_node.has_method("seekers"):
		var seekers: Array = match_node.call("seekers")
		me = seekers[0] if not seekers.is_empty() else null
	if me is FishController and is_instance_valid(me):
		var color := (me as FishController).body_color()
		return Color(color, 1.0)
	return Color(1.0, 0.85, 0.3)


## A hider's look in a seeker's view: copies of its model's meshes (sharing the
## real Mesh resources, each beside its real one so it rides the same pivots and
## bend) drawn with marco_reveal.gdshader, plus its anatomy (FishAnatomy) and an
## aura copy of the body. update() builds it up through the layers. A self look
## (the local hider's own) adds a sketch copy of the body: the dashed outline.
class Reveal:
	var model: FishModel
	var fish: FishController
	var self_look := false
	## The sketch outline now (0..1; it eases in and out).
	var sketch := 0.0
	var anatomy := {}
	## The layers now (bones, cardio, grow, skin, each 0..1 through its band) and the aura (0..1).
	var layers := Vector4.ZERO
	var aura := 0.0
	var exposure := 0.0
	var _copies: Array[MeshInstance3D] = []  # the model's meshes, then bones, vessels, heart
	var _heart: MeshInstance3D
	var _aura: MeshInstance3D
	var _aura_material: ShaderMaterial
	var _sketch: MeshInstance3D
	var _sketch_material: ShaderMaterial
	var _real: Array[GeometryInstance3D] = []
	var _real_layers := PackedInt32Array()
	var _real_shadows := PackedInt32Array()
	var _fx: Array[GeometryInstance3D] = []
	var _fx_layers := PackedInt32Array()
	var _synced: Array = []  # [real material, reveal material] pairs
	var _materials := {}  # [real material, kind] -> reveal material
	var _reveal_materials: Array[ShaderMaterial] = []  # every one this reveal draws with
	var _real_shown := true
	var _copies_shown := false
	var _beat_age := 9.0
	var _strode := false
	var _uniform_cache := {}  # Shader -> {name: true}

	func _init(for_model: FishModel, for_fish: FishController = null, own := false) -> void:
		model = for_model
		fish = for_fish
		self_look = own
		_build()
		if fish and not fish.strode.is_connected(_on_strode):
			fish.strode.connect(_on_strode)

	func _on_strode(_timing: float, _flow: float) -> void:
		_strode = true

	func _build() -> void:
		if model == null:
			return
		anatomy = FishAnatomy.of(model)
		var body := FishAnatomy.body_of(model)
		var body_real: Material = _real_material(body) if body else null
		for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
			if node.has_meta("marco_reveal"):
				continue
			var part := node as GeometryInstance3D
			_real.append(part)
			_real_layers.append(part.layers)
			_real_shadows.append(part.cast_shadow)
			var mesh_part := part as MeshInstance3D
			if mesh_part == null or mesh_part.mesh == null or String(mesh_part.name).begins_with("Eye"):
				continue
			var copy := _copy_beside(mesh_part, mesh_part.mesh, _reveal_material(mesh_part, body))
			if model.is_bent(mesh_part):
				model.bend_part(copy)
		if fish:
			for fx: Variant in [fish._bow_view, fish._stream, fish._bubbles]:
				if fx is GeometryInstance3D:
					_fx.append(fx)
					_fx_layers.append((fx as GeometryInstance3D).layers)
		if body == null or anatomy.is_empty():
			return
		var bent := model.is_bent(body)
		for key: String in ["bones", "vessels"]:
			var mesh: Mesh = anatomy[key]
			if mesh == null:
				continue
			var material := _anatomy_material(3 if key == "bones" else 4, body_real)
			var part := _copy_beside(body, mesh, material)
			if bent:
				model.bend_part(part)
		var heart_mesh: Mesh = anatomy.heart
		if heart_mesh:
			_heart = _copy_beside(body, heart_mesh, _anatomy_material(5, null))
			_heart.position = body.transform * (anatomy.heart_at as Vector3)
			_heart.basis = body.transform.basis
		_aura_material = ShaderMaterial.new()
		_aura_material.shader = AURA_SHADER
		_aura_material.set_shader_parameter("inflate", float(anatomy.depth) * 0.06)
		_aura = _copy_beside(body, body.mesh, _aura_material)
		if bent:
			model.bend_part(_aura)
		_copies.erase(_aura)
		if self_look:
			_sketch_material = ShaderMaterial.new()
			_sketch_material.shader = HiderLooks.SKETCH_SHADER
			_sketch_material.set_shader_parameter("inflate", float(anatomy.depth) * 0.04)
			_sketch = _copy_beside(body, body.mesh, _sketch_material)
			if bent:
				model.bend_part(_sketch)
			_copies.erase(_sketch)

	## A reveal part beside `real` (same parent and transform) showing `mesh`.
	func _copy_beside(real: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
		var copy := MeshInstance3D.new()
		copy.name = "Reveal" + String(real.name)
		copy.set_meta("marco_reveal", true)
		copy.mesh = mesh
		copy.material_override = material
		copy.transform = real.transform
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.extra_cull_margin = maxf((real as GeometryInstance3D).extra_cull_margin, 0.3) if real is GeometryInstance3D else 0.3
		copy.visible = false
		real.get_parent().add_child(copy)
		_copies.append(copy)
		return copy

	static func _real_material(part: GeometryInstance3D) -> Material:
		if part.material_override:
			return part.material_override
		var mesh_part := part as MeshInstance3D
		if mesh_part and mesh_part.mesh and mesh_part.mesh.get_surface_count() > 0:
			return mesh_part.get_active_material(0)
		return null

	func _has_uniform(material: Material, uniform: String) -> bool:
		var shader_material := material as ShaderMaterial
		if shader_material == null or shader_material.shader == null:
			return false
		var shader := shader_material.shader
		if not _uniform_cache.has(shader):
			var names := {}
			for entry: Dictionary in shader.get_shader_uniform_list(true):
				names[entry.name] = true
			_uniform_cache[shader] = names
		return (_uniform_cache[shader] as Dictionary).has(uniform)

	func _value_of(material: ShaderMaterial, uniform: String) -> Variant:
		var value: Variant = material.get_shader_parameter(uniform)
		if value == null:
			value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), uniform)
		return value

	func _reveal_material(part: MeshInstance3D, body: MeshInstance3D) -> ShaderMaterial:
		var real := _real_material(part)
		var kind := 2
		if part == body:
			kind = 0
		elif _has_uniform(real, "rays") or String(part.name) == "Fin":
			kind = 1
		var key: Variant = [real, kind] if real else kind
		if _materials.has(key):
			return _materials[key]
		var material := _base_material(kind)
		if kind == 0:
			_set_profile(material)
		_copy_from(real, material, kind == 0)
		if kind == 1 and not _has_uniform(real, "rays"):
			material.set_shader_parameter("rays", 10.0)
		_materials[key] = material
		return material

	func _anatomy_material(kind: int, body_real: Material) -> ShaderMaterial:
		var material := _base_material(kind)
		_set_profile(material)
		_copy_from(body_real, material, true)
		return material

	func _base_material(kind: int) -> ShaderMaterial:
		var material := ShaderMaterial.new()
		material.shader = HiderLooks.REVEAL_SHADER
		material.set_shader_parameter("kind", kind)
		_reveal_materials.append(material)
		match model.fish_class:
			FishCharacter.FishClass.DRIFTER:
				material.set_shader_parameter("bone_color", Color(0.75, 0.95, 1.0))
				material.set_shader_parameter("bone_glow", 0.9)
			FishCharacter.FishClass.ALCHEMIST:
				material.set_shader_parameter("bone_color", Color(0.9, 0.78, 0.55))
			FishCharacter.FishClass.HUNTER, FishCharacter.FishClass.GLIDER:
				material.set_shader_parameter("bone_color", Color(0.82, 0.88, 0.9))  # cartilage
		return material

	func _set_profile(material: ShaderMaterial) -> void:
		if anatomy.is_empty():
			return
		material.set_shader_parameter("profile", anatomy.profile)
		material.set_shader_parameter("profile_z", anatomy.z)
		material.set_shader_parameter("myomeres", 16.0)

	## Copies the swim's uniforms from `real` (still ones now, moving ones each
	## frame), and whether it pulses like a bell or bends like a ray's wings.
	func _copy_from(real: Material, material: ShaderMaterial, shape: bool) -> void:
		var real_shader := real as ShaderMaterial
		if real_shader == null or real_shader.shader == null:
			return
		for uniform: String in HiderLooks.STILL_PARAMS:
			if _has_uniform(real, uniform):
				var value: Variant = _value_of(real_shader, uniform)
				if value != null:
					material.set_shader_parameter(uniform, value)
		if shape:
			if _has_uniform(real, "bell_apex"):
				material.set_shader_parameter("jelly", true)
			if real_shader.shader == FishModel.RAY_SKIN and _value_of(real_shader, "tail_mode") != true:
				material.set_shader_parameter("ray_wing", true)
		var moving := false
		for uniform: String in HiderLooks.MOVING_PARAMS:
			if _has_uniform(real, uniform):
				moving = true
		if moving:
			_synced.append([real_shader, material])

	## Builds the look up for `with_exposure` (the local seeker's, 0..1) through
	## `settings`' layer bands, the aura in `aura_color`.
	func update(delta: float, with_exposure: float, settings: MarcoPoloSettings, aura_color: Color) -> void:
		exposure = with_exposure
		layers = Vector4(_band(exposure, settings.layer_skeleton, settings.layer_cardio),
				_band(exposure, settings.layer_cardio, settings.layer_muscle),
				_band(exposure, settings.layer_muscle, settings.layer_skin),
				_band(exposure, settings.layer_skin, settings.layer_aura))
		aura = _band(exposure, settings.layer_aura, 1.0) if exposure >= settings.layer_aura else 0.0
		var any := exposure >= settings.layer_skeleton
		_show_real(any and layers.w > 0.0)
		_show_copies(any and layers.w < 1.0)
		for i in _fx.size():
			_fx[i].layers = 0
		if is_instance_valid(_aura):
			_aura.visible = exposure >= settings.layer_aura
			if _aura.visible:
				_aura_material.set_shader_parameter("color", aura_color)
				_aura_material.set_shader_parameter("strength", 0.45 + 0.55 * aura)
		if is_instance_valid(_sketch):
			# In as soon as any of the fish is lost to the seekers, out once it's all back.
			var lost := settings.self_outline > 0.0 and layers.w < 1.0
			sketch = move_toward(sketch, 1.0 if lost else 0.0, delta * 5.0)
			_sketch.visible = sketch > 0.0
			if _sketch.visible:
				_sketch_material.set_shader_parameter("strength", sketch * settings.self_outline)
				_sketch_material.set_shader_parameter("dashes", settings.self_outline_dashes)
				_sketch_material.set_shader_parameter("march", settings.self_outline_march)
				_sketch_material.set_shader_parameter("width", settings.self_outline_width)
		if not _copies_shown:
			return
		# The heart: a beat on each stride, and a resting beat between.
		_beat_age += delta
		if _strode or _beat_age > 0.9:
			_beat_age = 0.0
			_strode = false
		var beat := exp(-_beat_age * 9.0)
		if is_instance_valid(_heart):
			_heart.visible = layers.y > 0.0
			_heart.scale = Vector3.ONE * (1.0 + 0.28 * beat)
		var see_through := float(anatomy.get("depth", 0.0)) * 1.1 * clampf(layers.z * 3.0, 0.0, 1.0) * (1.0 - layers.w)
		var pulse := Vector4(beat, _beat_age, see_through, 0.0)
		for material in _reveal_materials:
			material.set_shader_parameter("layers", layers)
			material.set_shader_parameter("pulse", pulse)
		for pair: Array in _synced:
			var real: ShaderMaterial = pair[0]
			var material: ShaderMaterial = pair[1]
			for uniform: String in HiderLooks.MOVING_PARAMS:
				var value: Variant = real.get_shader_parameter(uniform)
				if value != null:
					material.set_shader_parameter(uniform, value)

	static func _band(value: float, from: float, to: float) -> float:
		return clampf((value - from) / maxf(to - from, 0.0001), 0.0, 1.0)

	func _show_real(on: bool) -> void:
		if on == _real_shown:
			return
		_real_shown = on
		for i in _real.size():
			if is_instance_valid(_real[i]):
				_real[i].layers = _real_layers[i] if on else 0
				_real[i].cast_shadow = _real_shadows[i] if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _show_copies(on: bool) -> void:
		if on == _copies_shown:
			return
		_copies_shown = on
		for copy in _copies:
			if is_instance_valid(copy):
				copy.visible = on and copy != _heart

	## Back to the real model, with the reveal parts gone.
	func restore() -> void:
		_show_real(true)
		for i in _fx.size():
			if is_instance_valid(_fx[i]):
				_fx[i].layers = _fx_layers[i]
		for copy in _copies:
			if is_instance_valid(copy):
				_unbend(copy)
				copy.queue_free()
		if is_instance_valid(_aura):
			_unbend(_aura)
			_aura.queue_free()
		if is_instance_valid(_sketch):
			_unbend(_sketch)
			_sketch.queue_free()
		_copies.clear()
		if fish and is_instance_valid(fish) and fish.strode.is_connected(_on_strode):
			fish.strode.disconnect(_on_strode)

	func _unbend(part: GeometryInstance3D) -> void:
		if is_instance_valid(model):
			model._bent.erase(part)
