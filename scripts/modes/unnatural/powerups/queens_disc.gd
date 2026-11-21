class_name QueensDisc
extends Powerup
## Queen's Disc (planning_bosses_and_survival.md §2, boss item: the Lamprey
## Queen's). A lamprey latches onto the toughest zombie (or boss) within
## disc_reach m and corkscrews into it: every disc_tick s it drains drain()
## and heals the fish heal() hp, a red thread running back to it. It lets go
## past disc_leash m, and re-latches disc_relatch s after its host dies.

## How fast it corkscrews (rad/s).
const SPIN := 14.0

## Its host (-1: none), drains so far and hp it healed, for the probes.
var host := -1
var drains := 0
var healed := 0.0
var _tick_left := 0.0
var _relatch_left := 0.0
var _spin := 0.0
var _body: MeshInstance3D
var _line: MeshInstance3D


func drain() -> float:
	return settings.disc_drain + settings.disc_drain_per_stack * extra()


func heal() -> float:
	return settings.disc_heal + settings.disc_heal_per_stack * extra()


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish):
		return
	var horde := run.horde
	if host >= 0 and (not horde.is_alive(host) or horde.enemy_position(host).distance_to(fish.global_position) > settings.disc_leash):
		_relatch_left = settings.disc_relatch if not horde.is_alive(host) else 0.0
		host = -1
	if host < 0:
		_relatch_left -= delta
		if _relatch_left <= 0.0:
			host = toughest()
			if host >= 0:
				_tick_left = settings.disc_tick
				Sfx.play_at("pw/disc_latch", horde.enemy_position(host))
	if host >= 0:
		_tick_left -= delta
		while _tick_left <= 0.0 and host >= 0:
			_tick_left += settings.disc_tick
			_drain()
	_draw(delta)


## The zombie (or boss) with the most hp within disc_reach m of the fish (-1: none).
func toughest() -> int:
	var horde := run.horde
	var best := -1
	var most := -1.0
	for i in horde.query_sphere(fish.global_position, settings.disc_reach):
		var boss := run.boss_at(i)
		var hp := boss.hp if boss else horde.enemy_hp(i)
		if hp > most:
			most = hp
			best = i
	return best


func _drain() -> void:
	run.hit(host, drain(), fish, id, Vector3.ZERO, settings.disc_proc, [id])
	drains += 1
	var health := run.health_of(fish)
	if health and not health.down:
		var before := health.hp
		health.heal(heal())
		healed += health.hp - before
	Sfx.play_at("pw/disc_drain", fish.global_position)
	if not run.horde.is_alive(host):
		host = -1
		_relatch_left = settings.disc_relatch


## The lamprey on its host, corkscrewing, and the red thread back to the fish.
func _draw(delta: float) -> void:
	if not is_instance_valid(_body):
		_body = BossItemFx.creature(run, 0.6, 0.11, color(id), true)
		_body.name = "QueensDisc"
		_line = BossItemFx.tether(run, color(id), 0.04)
	var horde := run.horde
	if host < 0 or not horde.is_alive(host):
		_body.visible = false
		_line.visible = false
		return
	_body.visible = true
	_spin += delta * SPIN
	var target := horde.enemy_position(host)
	var toward := fish.global_position - target
	var facing := -toward.normalized() if toward.length_squared() > 0.0001 else Vector3.FORWARD
	# On the host's skin, on the side facing the fish, nose in.
	var on_skin := target - facing * (horde.enemy_radius(host) + 0.25)
	BossItemFx.place(_body, on_skin, facing, _spin)
	BossItemFx.stretch(_line, on_skin, fish.global_position)


func on_removed() -> void:
	if is_instance_valid(_body):
		_body.queue_free()
	if is_instance_valid(_line):
		_line.queue_free()
	_body = null
	_line = null
	host = -1


## A toothed disc on the fish's side, like the Queen's own mouth.
func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "WornDisc"
	look.position = Vector3(fish.hitbox_width * 0.5, 0.0, 0.0)
	look.add_child(worn_mesh(WornKit.toothed_ring(0.15), worn_material(0.7), Vector3.ZERO, Vector3(0.0, PI / 2.0, 0.0)))
	return look
