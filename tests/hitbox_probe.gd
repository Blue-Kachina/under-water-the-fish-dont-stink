## The fish's box hitbox: it settles flat on the aquarium floor (with sinking
## buoyancy) at half its height, and a Surface ball dropped on its back rests
## on the flat top.
## Run headless: Godot_console.exe --headless --path . res://tests/hitbox_probe.tscn
extends Node

var main: Node
var fish: FishController
var aquarium: AquariumArena
var t := 0.0
var events := {}

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	aquarium = main._environment
	var shape: BoxShape3D = fish.get_node("Collision").shape
	print("hitbox %s (length %.2f, width %.2f, height %.2f), buoyancy %.1f" % [shape.size, fish.hitbox_length, fish.hitbox_width, fish.hitbox_height, fish.buoyancy])

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func _physics_process(delta: float) -> void:
	t += delta
	if once("drop", 0.2):
		# Slightly tilted, so settling flat is the box's doing.
		fish.set_spawn(Transform3D(Basis.from_euler(Vector3(0.2, 0.0, 0.15)), Vector3(0, 4, 30)))
	if once("rest", 3.0):
		print("fish on floor: centre y %.3f (half height %.3f), up . world up %.4f, speed %.2f" % [
			fish.global_position.y, fish.hitbox_height / 2.0, fish.global_basis.y.dot(Vector3.UP), fish.speed])
		aquarium.ball.respawn(fish.global_position + Vector3(0, 6, 0))
	if once("carry", 6.0):
		var ball := aquarium.ball
		var top := fish.global_position.y + fish.hitbox_height / 2.0
		print("ball on fish: ball y %.3f, fish top + radius %.3f, horizontal offset %.3f, ball speed %.2f" % [
			ball.global_position.y, top + ball.settings.radius, Vector2(ball.global_position.x - fish.global_position.x, ball.global_position.z - fish.global_position.z).length(), ball.speed])
		ball.settings.bounciness = 0.3
		ball.respawn(fish.global_position + Vector3(0, 6, 0))
	if once("carry low bounce", 10.0):
		var ball := aquarium.ball
		var top := fish.global_position.y + fish.hitbox_height / 2.0
		print("bounciness 0.3: ball y %.3f, fish top + radius %.3f, horizontal offset %.3f, ball speed %.2f" % [
			ball.global_position.y, top + ball.settings.radius, Vector2(ball.global_position.x - fish.global_position.x, ball.global_position.z - fish.global_position.z).length(), ball.speed])
		fish.show_hitbox = true
		fish.hitbox_height = 0.46
		print("hitbox resized live: shape %s, debug box visible %s" % [(fish.get_node("Collision").shape as BoxShape3D).size, fish._hitbox_view.visible])
		get_tree().quit()
