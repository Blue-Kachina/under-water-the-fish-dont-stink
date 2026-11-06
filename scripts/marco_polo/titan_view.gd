extends Node
## The Titan's view (planning_marco_whales.md §3): a whale seeker's eyes are bad,
## and murk is the handicap. Only on the local whale seeker's machine, the arena's
## fog is whale_murk times as thick (and a little darker), eased in and out; the
## same factor shrinks the whale's sight range (MarcoPoloMatch's whale_sees and
## titan_sight_range), so what a person sees and what a bot notices agree.
## Hiders and spectators see the arena as it is. whale_blur (depth of field) and
## whale_desaturate (grey-out) are extras that start at 0.
##
## Loaded by path (HiderLooks), like the rest of the Marco Polo extras.

## MarcoPoloMatch.Role.SEEKER.
const SEEKER := 1

var match_node: Node
var settings: Resource
## 0 the arena's own view .. 1 the full Titan view.
var amount := 0.0
var _env: Environment
var _before := {}  # property -> value, from before the first override
var _attributes_before: CameraAttributes
var _attributes_mine: CameraAttributesPractical
var _camera: Camera3D


func bind(mp_match: Node) -> void:
	match_node = mp_match
	var from_match: Variant = mp_match.get("settings")
	settings = from_match as Resource if from_match is Resource else MarcoPoloSettings.shared()


func _setting(setting: String, fallback: Variant) -> Variant:
	var value: Variant = settings.get(setting) if settings else null
	return fallback if value == null else value


## Whether the local player is looking through a whale's eyes now.
func active() -> bool:
	if not is_instance_valid(match_node):
		return false
	if not bool(_setting("whale_seeker", false)):
		return false
	if int(match_node.get("phase")) not in [0, 1]:  # COUNTDOWN, LIVE
		return false
	if match_node.has_method("is_spectating") and bool(match_node.call("is_spectating")):
		return false
	return int(match_node.call("local_view_role")) == SEEKER if match_node.has_method("local_view_role") else false


## The fog density the Titan view uses for an arena density of `density`.
func titan_density(density: float) -> float:
	return density * maxf(float(_setting("whale_murk", 2.5)), 1.0)


func _process(delta: float) -> void:
	var fade := maxf(float(_setting("titan_view_fade", 0.6)), 0.01)
	var target := 1.0 if active() else 0.0
	amount = move_toward(amount, target, delta / fade)
	if amount <= 0.0 and _before.is_empty():
		return
	_apply()
	if amount <= 0.0:
		_restore()


func _arena_environment() -> Environment:
	var arena: Variant = match_node.get("arena") if is_instance_valid(match_node) else null
	if arena is Node and is_instance_valid(arena) and (arena as Node).has_method("environment"):
		return (arena as Node).call("environment") as Environment
	return null


func _apply() -> void:
	var env := _arena_environment()
	if env == null:
		return
	if _before.is_empty():
		_env = env
		for property: String in ["fog_light_color", "fog_density", "adjustment_enabled", "adjustment_saturation"]:
			_before[property] = env.get(property)
	var base_density: float = _before.fog_density
	var base_color: Color = _before.fog_light_color
	env.fog_density = lerpf(base_density, titan_density(base_density), amount)
	env.fog_light_color = base_color.lerp(_setting("titan_view_color", base_color) as Color, float(_setting("titan_view_color_mix", 0.35)) * amount)
	var grey := float(_setting("whale_desaturate", 0.0))
	if grey > 0.0:
		env.adjustment_enabled = true
		env.adjustment_saturation = lerpf(float(_before.adjustment_saturation), 1.0 - grey, amount)
	_apply_blur()


## Depth-of-field far blur on the current camera, only while whale_blur is above 0.
func _apply_blur() -> void:
	var blur := float(_setting("whale_blur", 0.0))
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if blur <= 0.0 or camera == null:
		_remove_blur()
		return
	if _camera != camera:
		_remove_blur()
		_camera = camera
		_attributes_before = camera.attributes
		_attributes_mine = CameraAttributesPractical.new()
		_attributes_mine.dof_blur_far_enabled = true
		camera.attributes = _attributes_mine
	var reach := float(match_node.call("sight_range")) / maxf(float(_setting("whale_murk", 2.5)), 1.0) if match_node.has_method("sight_range") else 20.0
	_attributes_mine.dof_blur_far_distance = maxf(reach * float(_setting("titan_view_blur_start", 0.5)), 0.5)
	_attributes_mine.dof_blur_far_transition = maxf(reach * float(_setting("titan_view_blur_span", 1.0)), 0.5)
	_attributes_mine.dof_blur_amount = blur * 0.3 * amount


func _remove_blur() -> void:
	if is_instance_valid(_camera) and _camera.attributes == _attributes_mine:
		_camera.attributes = _attributes_before
	_camera = null
	_attributes_mine = null
	_attributes_before = null


func _restore() -> void:
	if _env:
		for property: String in _before:
			_env.set(property, _before[property])
	_before.clear()
	_env = null
	_remove_blur()


func _exit_tree() -> void:
	_restore()
