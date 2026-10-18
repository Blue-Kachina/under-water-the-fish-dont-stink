extends Node
## Not a probe: screenshots of Unnatural's weapon and powerup effects (the
## arsenal pass), each staged beside the parked fish and held mid-way, for
## checking by eye. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/fx_tour.tscn -- --out=DIR [--size=1600x900]
## Shots: fx_pops (ring, shock, flash, spikes, pop), fx_projectiles (spears,
## spines, bubbles), fx_bite, fx_sting, fx_lash, fx_lingering (mines, lure,
## jellies, coil), fx_explosion.

var out_dir := "user://fx_tour"
var main: Node
var fish: FishController
var run: UnnaturalRun
var camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var window_size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = window_size
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


## A spot in view: `x` right, `y` up and `d` ahead of the camera (m).
func at(x: float, y: float, d: float) -> Vector3:
	return camera.global_position + camera.global_basis.x * x + camera.global_basis.y * y - camera.global_basis.z * d


func _run() -> void:
	UnnaturalSettings.shared().spawning = false
	main.start_mode(main.UNNATURAL)
	await _frames(30)
	run = main.unnatural_run
	fish.freeze = true
	await _seconds(0.5)
	camera = get_viewport().get_camera_3d()

	# The pops.
	var up := camera.global_basis.y.lerp(-camera.global_basis.z, 0.5).normalized()  # rings seen at a slant
	PowerupFx.ring(run, at(-4.5, 1.5, 12.0), 2.5, Powerup.color("drowned_fin"), up, 10.0)
	PowerupFx.shock(run, at(4.5, 1.5, 12.0), 3.0, Powerup.color("electric_eel"), up, 10.0)
	PowerupFx.flash(run, at(-3.0, -1.5, 8.0), 0.6, Powerup.color("remora_buddy"), 10.0)
	PowerupFx.spikes(run, at(0.0, 2.5, 10.0), 2.5, Powerup.color("pufferfish_spines"), 10.0)
	PowerupFx.pop(run, at(3.0, -1.5, 8.0), 1.0, Powerup.color("bubble_wrap"), 10.0)
	await _seconds(1.5)
	await _shot("fx_pops")
	_clear(PowerupFx)

	# Projectiles, side-on, held still.
	var swarms: Array[ProjectileSwarm] = []
	for row: Array in [[FishAttack.Kind.THRUST, 2.0, "spears"], [FishAttack.Kind.SPINES, 0.0, "spines"], [FishAttack.Kind.BUBBLES, -2.0, "bubbles"]]:
		var attack := FishAttack.make(row[0])
		attack.fish = fish
		attack.horde = run.horde
		attack.settings = UnnaturalSettings.shared()
		run.add_child(attack)
		var swarm: ProjectileSwarm = attack.get(row[2])
		var size: float = {"spears": attack.settings.thrust_size, "spines": attack.settings.spine_size, "bubbles": attack.settings.bubble_size}[row[2]]
		for n in 3:
			swarm.fire(at(-3.0 + n * 2.5, row[1], 9.0 + n), camera.global_basis.x * 20.0, 0.0, size, 100.0)
		swarms.append(swarm)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for swarm in swarms:
		swarm.set_physics_process(false)
	PowerupFx.pop(run, at(4.5, -2.0, 9.0), 0.8, BubbleVolley.COLOR, 10.0)
	await _seconds(0.3)
	await _shot("fx_projectiles")
	for swarm in swarms:
		swarm.get_parent().queue_free()
	_clear(PowerupFx)

	# The Shark's jaws, side-on, wide open.
	var bite: GhostBite = FishAttack.make(FishAttack.Kind.BITE)
	bite.fish = fish
	bite.horde = run.horde
	bite.settings = UnnaturalSettings.shared()
	run.add_child(bite)
	bite.start(camera.global_basis.x)
	bite._animate(0.07)
	await _seconds(0.3)
	await _shot("fx_bite")
	bite.queue_free()

	# The Clownfish's sting, at its fullest.
	var sting: AnemoneSting = FishAttack.make(FishAttack.Kind.STING)
	sting.fish = fish
	sting.horde = run.horde
	sting.settings = UnnaturalSettings.shared()
	run.add_child(sting)
	sting._age = AnemoneSting.GROW_TIME
	sting.visible = true
	sting._place(sting._age)
	await _seconds(0.3)
	await _shot("fx_sting")
	sting.queue_free()

	# The String Ray's lash, held.
	var whip := ShockLash.Whip.new()
	var tail := fish.global_position + fish.global_basis.z * fish.hitbox_length * 0.5
	whip.path = PackedVector3Array([tail, at(-3.5, 0.5, 11.0), at(-5.0, -1.0, 13.0), at(-3.5, 1.5, 15.0)])
	whip.bend = Vector3.UP
	run.add_child(whip)
	whip.set_process(false)
	await _seconds(0.3)
	await _shot("fx_lash")
	whip.queue_free()

	# The lingering ones: mines, a lure, the jellies and the coil.
	var held := run.powerups_of(fish)
	for id: String in ["depth_charges", "anglerfish_lure", "jellyfish_halo", "leviathans_coil"]:
		held.add(id)
	await _frames(5)
	var charges: DepthCharges = held.held["depth_charges"]
	for n in 3:
		charges.drop()
	for n in charges.mines.size():
		charges.mines[n].global_position = at(-4.0 + n * 1.5, -1.5 + n * 0.4, 7.0 + n * 2.0)
		charges.mines[n].age = 0.0 if n == 0 else 10.0
	var lure_powerup: AnglerfishLure = held.held["anglerfish_lure"]
	lure_powerup.drop()
	lure_powerup.lures[-1].global_position = at(4.0, 1.0, 10.0)
	var coil: LeviathansCoil = held.held["leviathans_coil"]
	var trail := PackedVector3Array([fish.global_position])
	for k in coil.count():
		trail.append(fish.global_position + camera.global_basis.x * (1.5 + k * 1.2) + Vector3.UP * sin(k * 0.8) * 1.2 + camera.global_basis.z * k * 0.4)
	coil.trail = trail
	coil._draw()
	await _seconds(0.6)
	await _shot("fx_lingering")
	for id: String in ["depth_charges", "anglerfish_lure", "leviathans_coil"]:
		held.remove_stack(id)
	await _frames(3)

	# An explosion (a torpedo's) and a small pop, a moment in.
	Explosion.spawn(run.ocean, at(-2.0, 0.5, 14.0), Powerup.color("torpedo"), 4.0, 0.0, 1.0)
	Explosion.spawn(run.ocean, at(4.0, -1.0, 10.0), Powerup.color("depth_charges"), 2.5, 0.0, 0.3)
	await _seconds(0.15)
	await _shot("fx_explosion")
	print("fx_tour: saved to %s" % out_dir)
	get_tree().quit()


func _clear(type: Variant) -> void:
	for child in run.get_children():
		if is_instance_of(child, type):
			child.queue_free()


func _shot(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, true).timeout
