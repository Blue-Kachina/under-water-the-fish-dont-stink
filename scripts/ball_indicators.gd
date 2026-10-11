class_name BallIndicators
extends Node3D
## Rocket League's ball indicator: a ring the size of the ball projected onto
## each surface near it (floor, walls, ceiling, goal nets), fading with
## distance and pulsing when the ball touches that surface. Helps line up hits
## and carries. One ring per world axis, so a ball near an edge shows two.

const DIRECTIONS := [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
const COLOR := Color(0.85, 0.97, 1.0)
const PULSE_TIME := 0.45
## A ring counts the ball as touching its surface within this gap (m).
const TOUCH_GAP := 0.15
## Rendering layer for the ball, which the rings don't paint onto.
const BALL_LAYER := 1 << 1

var ball: Ball

var _decals: Array[Decal] = []
var _pulse: Array[float] = []
var _touching: Array[bool] = []


func _ready() -> void:
	var texture := _ring_texture()
	for i in DIRECTIONS.size():
		var decal := Decal.new()
		decal.top_level = true
		decal.texture_albedo = texture
		decal.texture_emission = texture
		decal.modulate = COLOR
		decal.cull_mask = 0xFFFFF & ~BALL_LAYER
		decal.visible = false
		add_child(decal)
		_decals.append(decal)
		_pulse.append(0.0)
		_touching.append(false)


## Called by the ball each physics tick.
func update(delta: float) -> void:
	var settings := ball.settings
	var show := settings.surface_indicator and not ball.popped
	var space := ball.get_world_3d().direct_space_state
	var origin := ball.global_position
	var radius := settings.radius
	for i in DIRECTIONS.size():
		var decal := _decals[i]
		_pulse[i] = maxf(_pulse[i] - delta / PULSE_TIME, 0.0)
		var hit := {}
		if show:
			var query := PhysicsRayQueryParameters3D.create(origin, origin + DIRECTIONS[i] * (settings.indicator_range + radius))
			query.exclude = [ball.get_rid()]
			hit = space.intersect_ray(query)
		# Only the arena's own surfaces, not fish passing between ball and wall.
		if hit.is_empty() or not (hit.collider is StaticBody3D):
			decal.visible = false
			_touching[i] = false
			continue

		var gap: float = (hit.position - origin).length() - radius
		var touching := gap <= TOUCH_GAP
		if touching and not _touching[i]:
			_pulse[i] = 1.0
		_touching[i] = touching

		var near := 1.0 - clampf(gap / settings.indicator_range, 0.0, 1.0)
		var pulse := _pulse[i]
		var size := radius * 2.0 * (1.0 + 0.35 * pulse)
		var was_visible := decal.visible
		decal.size = Vector3(size, 1.0, size)  # 1 m deep: enough to wrap the tank's rounded corners
		decal.global_transform = Transform3D(_basis_facing(hit.normal), hit.position)
		decal.albedo_mix = clampf(0.25 + 0.6 * near * near + 0.4 * pulse, 0.0, 1.0)
		decal.emission_energy = 0.3 + 2.5 * pulse
		decal.visible = true
		if not was_visible:
			decal.reset_physics_interpolation()


## Decals project along their local -Y, so +Y points out of the surface.
func _basis_facing(normal: Vector3) -> Basis:
	var side := Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := normal.cross(side).normalized()
	return Basis(x, normal, x.cross(normal))


## A crisp ring with a faint fill, white on transparent.
func _ring_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := (size - 1) / 2.0
	for y in size:
		for x in size:
			var r := Vector2(x - centre, y - centre).length() / centre
			var ring := clampf(1.0 - absf(r - 0.9) / 0.07, 0.0, 1.0)
			var fill := 0.12 if r < 0.9 else 0.0
			image.set_pixel(x, y, Color(1, 1, 1, maxf(ring, fill)))
	return ImageTexture.create_from_image(image)
