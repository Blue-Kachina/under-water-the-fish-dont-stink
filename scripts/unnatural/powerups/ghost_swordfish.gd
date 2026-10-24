class_name GhostSwordfish
extends Powerup
## Ghost Swordfish (planning_unnatural.md §7b, rare): phantom swordfish escort
## the fish. Every ghost_every s (sooner with attack speed) each of them (one
## a stack) dashes ghost_length m from the fish through a zombie within
## ghost_range m (a different one each, nearest first), ghost_damage to every
## zombie within ghost_width m of its path.

## Dashes made, for the probes.
var dashes := 0
var _left := 0.0


func on_tick(delta: float) -> void:
	_left -= delta
	if _left > 0.0 or not is_instance_valid(fish):
		return
	_left = settings.ghost_every / rate_scale()
	var horde := run.horde
	var from := fish.global_position
	var near := horde.query_sphere(from, settings.ghost_range)
	if near.is_empty():
		_left = 0.25  # nothing to dash at: look again soon
		return
	var order := Array(near)
	order.sort_custom(func(a: int, b: int) -> bool:
		return horde.enemy_position(a).distance_squared_to(from) < horde.enemy_position(b).distance_squared_to(from))
	for n in mini(stacks, order.size()):
		dash(from, horde.enemy_position(order[n]))


## One phantom's dash from `from` through `through`.
func dash(from: Vector3, through: Vector3) -> void:
	var way := (through - from).normalized() if through.distance_squared_to(from) > 0.0001 else -fish.global_basis.z
	var to := from + way * settings.ghost_length
	var width := settings.ghost_width * size_scale()
	var middle := (from + to) * 0.5
	for i in run.horde.query_sphere(middle, settings.ghost_length * 0.5 + width):
		var at := run.horde.enemy_position(i)
		var along := clampf((at - from).dot(way), 0.0, settings.ghost_length)
		if at.distance_to(from + way * along) <= width + run.horde.enemy_radius(i):
			run.hit(i, settings.ghost_damage, fish, id, way, 1.0, [id])
	dashes += 1
	streak(run, from, to, color(id), 0.9, 0.35)
	Sfx.play("pw/drowned_fin_dash")


## A faint phantom swordfish shape riding beside the fish.
func make_worn() -> Node3D:
	var ghost := Node3D.new()
	ghost.name = "GhostSwordfish"
	ghost.position = Vector3(fish.hitbox_width * 0.9, fish.hitbox_height * 0.3, 0.0)
	var skin := FxKit.glow(color(id))
	skin.albedo_color.a = 0.45
	var body := CapsuleMesh.new()
	body.radius = 0.07
	body.height = 0.5
	body.radial_segments = 8
	body.rings = 3
	ghost.add_child(worn_mesh(body, skin, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0)))
	var bill := CylinderMesh.new()
	bill.top_radius = 0.0
	bill.bottom_radius = 0.02
	bill.height = 0.3
	bill.radial_segments = 5
	ghost.add_child(worn_mesh(bill, skin, Vector3(0.0, 0.0, -0.38), Vector3(-PI * 0.5, 0.0, 0.0)))
	return ghost


## Streaks shown now (at most STREAKS_MAX).
const STREAKS_MAX := 60
static var _streaks := 0


## A glowing streak from `from` to `to`, `width` m wide, there `seconds`, then
## faded (a phantom's dash, a shard's flight, a current).
static func streak(parent: Node, from: Vector3, to: Vector3, tint: Color, width: float, seconds: float) -> void:
	if _streaks >= STREAKS_MAX or not is_instance_valid(parent) or not parent.is_inside_tree() or from.distance_squared_to(to) < 0.0001:
		return
	var shown := Streak.new()
	shown.life = seconds
	shown.glow_material = FxKit.glow(tint, FxKit.across())
	shown.mesh = FxKit.ribbons([PackedVector3Array([from, from.lerp(to, 0.5), to])], [width], true)
	if shown.mesh.get_surface_count() > 0:
		shown.mesh.surface_set_material(0, shown.glow_material)
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks += 1
	shown.tree_exited.connect(func() -> void: _streaks -= 1)
	parent.add_child(shown)


## streak()'s mesh, fading out over its life.
class Streak extends MeshInstance3D:
	var life := 0.3
	var glow_material: StandardMaterial3D
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		glow_material.albedo_color.a = 1.0 - _age / life
