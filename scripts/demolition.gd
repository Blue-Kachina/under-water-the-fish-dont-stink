class_name Demolition
## Rocket League's demolition test, shared by the 1v1 (Match1v1) and Nature
## (NatureRun): a fish fast enough that rams another with its front demolishes it.
## The front includes its bow wave (FishController.bow_wave), if it has one out.

## The hitboxes must come within this (m).
const REACH := 0.1
## The victim must be at least this far ahead of the attacker (cosine of the
## angle off its nose): a demolition takes the front of the fish, as RL's bumper.
const FRONT := 0.3


## Whether `attacker` demolishes `victim` now: at least `min_speed` (m/s), with
## `victim` ahead of its nose and its hitbox touching.
static func hits(attacker: FishController, victim: FishController, min_speed := FishController.SUPERSONIC_SPEED) -> bool:
	if attacker.demolished or victim.demolished or attacker.speed < min_speed:
		return false
	var ahead := (victim.global_position - attacker.global_position).normalized()
	return ahead.dot(-attacker.global_basis.z) >= FRONT and touching(attacker, victim)


## Whether `attacker`'s hitbox (grown by REACH), or its bow wave, overlaps `victim`.
static func touching(attacker: FishController, victim: FishController) -> bool:
	var hitbox := attacker.get_node("Collision") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = (hitbox.shape as BoxShape3D).size + Vector3.ONE * REACH * 2.0
	if _overlaps(attacker, victim, box, hitbox.global_transform):
		return true
	if attacker.bow_amount <= 0.0:
		return false
	var bow := ConvexPolygonShape3D.new()
	bow.points = attacker.bow_points()
	return _overlaps(attacker, victim, bow, hitbox.global_transform)


static func _overlaps(attacker: FishController, victim: FishController, shape: Shape3D, at: Transform3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = at
	query.exclude = [attacker.get_rid()]
	for hit in attacker.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider == victim:
			return true
	return false
