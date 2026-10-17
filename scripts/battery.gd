class_name Battery
## A battery: one fish battering another, our Rocket League demolition (RL's
## "demo"; those words are only for Rocket League itself, e.g. its replays).
## Shared by the 1v1 (Match1v1), Nature (NatureRun) and Hunt (HuntMatch): a
## fish fast enough that rams another with its front batters it.
## The front includes its bow wave (FishController.bow_wave), if it has one out.

## The hitboxes must come within this (m).
const REACH := 0.1
## The victim must be at least this far ahead of the attacker (cosine of the
## angle off its nose): a battery takes the front of the fish, as a demo takes RL's bumper.
const FRONT := 0.3


## Whether `attacker` batters `victim` now: at least `min_speed` (m/s), with
## `victim` ahead of its nose and its hitbox touching.
static func hits(attacker: FishController, victim: FishController, min_speed := FishController.SUPERSONIC_SPEED) -> bool:
	if attacker.battered or victim.battered or attacker.speed < min_speed:
		return false
	var ahead := (victim.global_position - attacker.global_position).normalized()
	return ahead.dot(-attacker.global_basis.z) >= FRONT and touching(attacker, victim)


## Whether `attacker`'s hitbox (grown by REACH), or its bow wave, overlaps `victim`.
static func touching(attacker: FishController, victim: FishController) -> bool:
	var shapes := attack_shapes(attacker)
	var at := (attacker.get_node("Collision") as CollisionShape3D).global_transform
	for shape: Shape3D in shapes:
		if _overlaps(attacker, victim, shape, at):
			return true
	return false


## What `attacker` hits with, placed at its hitbox (CollisionShape3D "Collision"):
## its hitbox grown by REACH, and its bow wave if it has one out.
static func attack_shapes(attacker: FishController) -> Array[Shape3D]:
	var hitbox := attacker.get_node("Collision") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = (hitbox.shape as BoxShape3D).size + Vector3.ONE * REACH * 2.0
	var shapes: Array[Shape3D] = [box]
	if attacker.bow_amount > 0.0:
		var bow := ConvexPolygonShape3D.new()
		bow.points = attacker.bow_points()
		shapes.append(bow)
	return shapes


## Every area on `mask` that `attacker`'s front (attack_shapes) overlaps now,
## at most `most` of them: e.g. school fish (SchoolFish.LAYER).
static func areas_touched(attacker: FishController, mask: int, most := 32) -> Array[Area3D]:
	var touched: Array[Area3D] = []
	var at := (attacker.get_node("Collision") as CollisionShape3D).global_transform
	var space := attacker.get_world_3d().direct_space_state
	for shape: Shape3D in attack_shapes(attacker):
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = at
		query.collision_mask = mask
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for hit in space.intersect_shape(query, most):
			var area := hit.collider as Area3D
			if area and area not in touched:
				touched.append(area)
	return touched


static func _overlaps(attacker: FishController, victim: FishController, shape: Shape3D, at: Transform3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = at
	query.exclude = [attacker.get_rid()]
	for hit in attacker.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider == victim:
			return true
	return false
