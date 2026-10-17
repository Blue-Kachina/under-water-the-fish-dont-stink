class_name ArcadeFx
extends CanvasLayer
## Extra Swishy's arcade feel, while the player swims it: as flow builds, the
## camera closes in a little (FollowCamera arcade_zoom) and a vignette darkens
## and narrows the screen's edges, warming to gold near full flow, with speed
## streaks when you're fast. A perfect stride punches the view in and flashes
## the rim. Off (view as normal) in every other swim style.

## How quickly the effects follow the flow (per second).
const RESPONSE := 4.0
## How quickly a perfect stride's punch and flash die away (per second).
const PUNCH_DECAY := 6.0
const SHADER := preload("res://shaders/arcade_vignette.gdshader")

var fish: FishController
var camera: Camera3D

var _rect := ColorRect.new()
var _material := ShaderMaterial.new()
var _level := 0.0  # the flow's share of its most, smoothed
var _punch := 0.0


func _ready() -> void:
	layer = 0  # under the HUD
	_material.shader = SHADER
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	fish.strode.connect(func(timing: float, _flow: float) -> void:
		if timing >= SwishySwim.SWEET_SPOT:
			_punch = 1.0)


## Punches the view in and flashes the rim, as a perfect stride does: e.g. a
## big multi in Nature (amount 0..1+).
func punch(amount := 1.0) -> void:
	_punch = maxf(_punch, amount)


func _process(delta: float) -> void:
	var active := fish.swim_strokes and fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY \
			and fish.is_visible_in_tree() and camera.current
	var flow_share := fish.swishy.flow / maxf(fish.stride_flow_max, 0.01) if active else 0.0
	_level = move_toward(_level, flow_share, RESPONSE * delta)
	_punch = maxf(_punch - PUNCH_DECAY * delta, 0.0) if active else 0.0
	camera.zoom = 1.0 - camera.arcade_zoom * _level - camera.arcade_punch * _punch
	_rect.visible = _level > 0.001 or _punch > 0.0
	if not _rect.visible:
		return
	var size := _rect.get_viewport_rect().size
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_material.set_shader_parameter("strength", _level)
	_material.set_shader_parameter("heat", smoothstep(0.5, 1.0, _level))
	_material.set_shader_parameter("streaks", smoothstep(0.3, 1.0, clampf(fish.speed / 35.0, 0.0, 1.0)) * _level)
	_material.set_shader_parameter("flash", _punch)
