extends Node3D
## The ray's swimming (FishModel) on its own. Its whip tail (_bend_whip): a
## swing at the root should reach the tip late and overshoot before settling,
## the whip should trail behind a turn and stream back from a sideways slide,
## and nothing should blow up when the body jumps (a respawn). It banks into
## turns, but not on a surface (_bank_ray), and its wings beat with a stride:
## down as it builds, the wing away from the push harder, then back up past
## level (_beat_wings).
##   Godot_console.exe --headless --path . res://tests/ray_probe.tscn

const DT := 1.0 / 60.0

var failures := 0
var model: FishModel


func _ready() -> void:
	model = FishModel.build(FishCharacter.FishClass.GLIDER)
	add_child(model)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


## The whip's tip bend off the body (yaw, pitch): the root's share and its links'.
func tip_bend() -> Vector2:
	return model._whip_root + model._whip_bend_at(1.0)


func settle(seconds: float, velocity := Vector3(0.0, 0.0, -15.0)) -> void:
	for i in roundi(seconds / DT):
		model.react(DT, velocity)


func _run() -> void:
	print("Ray whip:")
	settle(1.0)
	check(tip_bend().length() < 0.02, "swimming straight, it lies straight (tip %s)" % tip_bend())

	# A stride's swing: the pivot turns 0.6 rad at once.
	model.tail.rotation.y = 0.6
	var early := 0.0
	var most := 0.0
	var most_at := 0.0
	for i in 90:
		model.react(DT, Vector3(0.0, 0.0, -15.0))
		if i == 2:
			early = tip_bend().x
		if tip_bend().x > most:
			most = tip_bend().x
			most_at = (i + 1) * DT
	var final := tip_bend().x
	print("    tip after 50 ms %.3f, most %.3f at %.2f s, after 1.5 s %.3f" % [early, most, most_at, final])
	check(early < 0.3 * 0.6 + 0.08, "the tip lags the root (%.3f at 50 ms)" % early)
	check(most > final + 0.03, "it whips past and comes back (overshoot %.3f)" % (most - final))
	check(absf(final - 0.6) < 0.05, "it settles at the full swing (%.3f)" % final)
	var tip := model.tail.transform * model.tail_tip()
	var heading := atan2(tip.x - model.tail.position.x, tip.z - model.tail.position.z)
	# The root turns half the swing and the bend the rest, so the tip lies between.
	check(heading > 0.3 and heading < 0.65, "tail_tip() follows the bend (%.2f rad off straight back)" % heading)

	# A turn to the left (yaw +) while swimming straight: the tip trails right (-X).
	model.tail.rotation.y = 0.0
	settle(1.0)
	var trail := 0.0
	for i in 30:
		model.rotate_y(2.5 * DT)
		model.react(DT, model._body_frame() * Vector3(0.0, 0.0, -15.0))
		trail = minf(trail, tip_bend().x)
	check(trail < -0.1, "turning left, the tip trails out to the right (%.3f)" % trail)
	check(model.rotation.z > 0.2, "turning left, it banks left wing down (%.2f rad)" % model.rotation.z)
	var bias: float = model._skin.get_shader_parameter("ripple_bias")
	check(bias > 0.1, "turning left, the outside (right) wing's wave runs deeper (bias %.2f)" % bias)
	model.grounded = true
	for i in 60:
		model.rotate_y(2.5 * DT)
		model.react(DT, model._body_frame() * Vector3(0.0, 0.0, -15.0))
	check(absf(model.rotation.z) < 0.05, "turning on a surface, it stays level (%.3f rad)" % model.rotation.z)
	model.grounded = false

	# Sliding sideways to the right: the whip streams back to the left.
	model.rotation = Vector3.ZERO
	settle(0.5)
	settle(1.0, Vector3(8.0, 0.0, -12.0))
	check(tip_bend().x < -0.15, "sliding right, it streams back to the left (%.3f)" % tip_bend().x)
	settle(1.0, Vector3(0.0, 6.0, -12.0))
	check(tip_bend().y > 0.15, "rising, it streams back down (pitch %.3f)" % tip_bend().y)

	# A stride pushing left (the tail swings left): its power builds over 0.35 s
	# and fades over 0.35 s, as SwishySwim's envelope.
	settle(1.0)
	var deepest := Vector2.ZERO
	var highest := -INF
	var bank_most := 0.0
	for i in 90:
		var t := (i + 1) * DT
		model.stride_swing = Vector2(-1.0, 0.0)
		model.stride_power = smoothstep(0.0, 0.35, t) if t < 0.35 else clampf(1.0 - (t - 0.35) / 0.35, 0.0, 1.0)
		model.react(DT, Vector3(0.0, 0.0, -15.0))
		deepest = deepest.min(model._beat)
		bank_most = maxf(bank_most, model.rotation.z)
		if t > 0.5:
			highest = maxf(highest, model._beat.y)
	print("    wing beat: deepest (left %.2f, right %.2f), back up to %.2f, bank %.2f" % [deepest.x, deepest.y, highest, bank_most])
	check(deepest.y < -0.4 and deepest.x < -0.05, "the stride beats both wings down")
	check(deepest.y < deepest.x * 2.0, "the right wing (away from the push) beats harder")
	check(highest > 0.15, "then they lift back up past level (the recovery)")
	check(bank_most > 0.08, "and it banks toward the push (%.2f rad)" % bank_most)
	model.stride_power = 0.0
	model.stride_swing = Vector2.ZERO
	settle(1.5)
	check(model._beat.length() < 0.02 and absf(model.rotation.z) < 0.02, "it settles level after")
	model.stride_swing = Vector2(-1.0, 0.0)
	model.stride_power = 1.0
	model.grounded = true
	settle(1.0)
	check(model._beat.x > -0.151 and model._beat.y > -0.151,"on a surface the wingtips stay out of the floor (%s)" % model._beat)
	model.grounded = false
	model.stride_power = 0.0
	model.stride_swing = Vector2.ZERO

	# A respawn spins the body round in one frame: not a turn.
	settle(1.0)
	model.rotate_y(PI)
	settle(0.1)
	var ok := true
	for link in model._whip_links:
		ok = ok and is_finite(link.x) and is_finite(link.y) and link.length() < 0.3
	check(ok, "a respawn's jump doesn't whip it (%s)" % [model._whip_links])

	print("%s (%d failed)" % ["ALL PASS" if failures == 0 else "FAILURES", failures])
	get_tree().quit(1 if failures else 0)
