class_name Lamprey
extends Powerup
## Lamprey (planning_unnatural.md §7b, uncommon): a lamprey trailing the fish.
## Each kill heals the fish lamprey_heal hp a stack (at most once every
## lamprey_gap s, so a pop of a crowd isn't a flood).

## Hp healed so far, for the probes.
var healed := 0.0
var _gap_left := 0.0


func on_tick(delta: float) -> void:
	_gap_left = maxf(_gap_left - delta, 0.0)


func on_kill(_at: Vector3, _source: String) -> void:
	if _gap_left > 0.0:
		return
	var health := run.health_of(fish)
	if health == null or health.down:
		return
	_gap_left = settings.lamprey_gap
	var amount := settings.lamprey_heal * eff()
	healed += amount
	health.heal(amount)


## A pale lamprey stuck low on the flank, its mouth to the fish.
func make_worn() -> Node3D:
	var rider := Node3D.new()
	rider.name = "Lamprey"
	var body := CapsuleMesh.new()
	body.radius = 0.05
	body.height = 0.7
	body.radial_segments = 8
	body.rings = 2
	var skin := worn_material(0.3)
	skin.albedo_color = Color(0.5, 0.45, 0.55)
	rider.add_child(worn_mesh(body, skin, Vector3(fish.hitbox_width * 0.5, -fish.hitbox_height * 0.15, fish.hitbox_length * 0.2), Vector3(PI / 2.0, 0.0, 0.2)))
	return rider
