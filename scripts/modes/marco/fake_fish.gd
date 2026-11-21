class_name FakeFish
extends Node3D
## A hider's decoy (planning_marco_polo.md §9): a copy of their fish, same class
## and species, that swims off along their facing on its own and makes a racket
## to pull the seekers the wrong way. A MarcoPoloBot in decoy mode pilots it:
## straight on at fake_speed, turning away from walls and furniture, striding
## badly on purpose with a flip or two, so its own NoiseMeter (register_decoy)
## pings and builds up the layers like a real hider's.
##
## It lasts fake_life, then bursts into a puff of bubbles with a loud last ping;
## a seeker's tag (MarcoPoloMatch._fool) pops it the same way. It can't enter a
## porthole (PortholeSystem only takes live hiders) and scores nothing. Throwing
## it makes no noise; the thrower alone hears mp/fake_throw.
##
## MarcoPoloMatch.throw_fake spends the charge and calls throw(match, hider).

## How far ahead of the hider it appears (m, plus half each fish's length).
const SPAWN_AHEAD := 0.6
## How long the bubble puff stays before it's freed (s).
const PUFF_TIME := 2.5

var game: MarcoPoloMatch
## The hider who threw it.
var thrower: FishController
## The decoy's fish (what the match registers, tags and draws).
var fish: FishController
var pilot: MarcoPoloBot
var life_left := 0.0
var popped := false


## A Fake Fish from `hider`, added to `match_node`. Returns it.
static func throw(match_node: MarcoPoloMatch, hider: FishController) -> FakeFish:
	var fake := FakeFish.new()
	fake.name = "FakeFish"
	fake.game = match_node
	fake.thrower = hider
	match_node.add_child(fake)
	return fake


func _ready() -> void:
	var settings := game.settings
	life_left = settings.fake_life
	fish = MarcoPoloMatch.FISH_SCENE.instantiate()
	fish.name = "Fake%s" % thrower.name
	fish.display_name = thrower.display_name
	add_child(fish)
	Match1v1.copy_tuning(thrower, fish)
	fish.set_look(thrower.character, thrower.species)
	fish.team = thrower.team
	fish.team_color = thrower.team_color
	fish.buoyancy = settings.hider_buoyancy
	fish.speed_scale = thrower.speed_scale
	fish.boost_enabled = false
	fish.bow_scale = 1.0
	fish.add_collision_exception_with(thrower)
	thrower.add_collision_exception_with(fish)
	var facing := -thrower.global_basis.z.normalized()
	var at := thrower.global_position + facing * (thrower.hitbox_length * 0.5 + fish.hitbox_length * 0.5 + SPAWN_AHEAD)
	fish.set_spawn(Transform3D(thrower.global_basis.orthonormalized(), at))
	fish.linear_velocity = thrower.linear_velocity + facing * game.settings.fake_speed * 0.5
	pilot = MarcoPoloBot.new()
	pilot.name = "Pilot"
	pilot.fish = fish
	pilot.decoy = true
	add_child(pilot)
	pilot.bind(game)
	game.register_decoy(fish, thrower)
	if thrower == game.local_fish():
		Sfx.play("mp/fake_throw")


func _physics_process(delta: float) -> void:
	if popped:
		return
	if not is_instance_valid(fish) or not game.decoys().has(fish):
		queue_free()  # a new round cleared the decoys
		return
	if game.phase != MarcoPoloMatch.Phase.LIVE:
		pop()
		return
	life_left -= delta
	if life_left <= 0.0:
		pop()


## The end: a puff of bubbles and a loud last ping, then gone. Tagged
## (MarcoPoloMatch._fool) or out of life, it's the same pop.
func pop() -> void:
	if popped:
		return
	popped = true
	var at := fish.global_position if is_instance_valid(fish) else global_position
	if is_instance_valid(fish):
		game.add_noise(fish, 1.0)
		game.unregister_decoy(fish)
		if is_instance_valid(thrower):
			thrower.remove_collision_exception_with(fish)
		fish.queue_free()
	if is_instance_valid(pilot):
		pilot.queue_free()
	Sfx.play_at("mp/fake_pop", at)
	_puff(at)
	get_tree().create_timer(PUFF_TIME, false).timeout.connect(queue_free)


func _puff(at: Vector3) -> void:
	var bubbles := CPUParticles3D.new()
	bubbles.name = "Puff"
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 8
	sphere.rings = 4
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = look
	bubbles.mesh = sphere
	bubbles.amount = 70
	bubbles.one_shot = true
	bubbles.explosiveness = 0.9
	bubbles.lifetime = 1.8
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.7
	bubbles.direction = Vector3.UP
	bubbles.spread = 70.0
	bubbles.initial_velocity_min = 1.0
	bubbles.initial_velocity_max = 3.5
	bubbles.gravity = Vector3(0.0, 2.5, 0.0)
	bubbles.damping_min = 1.0
	bubbles.damping_max = 2.0
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	add_child(bubbles)
	bubbles.global_position = at
	bubbles.emitting = true
