class_name UnnaturalNet
extends Node
## Online co-op in Unnatural (planning_unnatural.md §9): CoopSession's child
## "Unnatural" (the same path everywhere, so its RPCs meet), carrying what's
## Unnatural's own. CoopSession still does the session, the roster, the
## players' fish, the tuning and restarts.
##
## The host (UnnaturalRun.authority) runs the world, and sends:
## - every zombie that comes, each frame's in one batch ([net id, kind, where,
##   heading, elite]), and every one killed ([net id, source, killer]) or taken
##   away; each machine steers its copies itself;
## - CORRECT_RATE times a second, where the zombies near any guest's players
##   are (the nearest MAX_CORRECT, within NEAR), with the run's clock and the
##   team's level and XP;
## - chests buried and opened, bosses coming (with their proxies' net ids),
##   their state BOSS_RATE times a second, the Leviathan's bolts, and their end;
## - XP pearls taken (so every copy goes).
## A guest sends its players' hits (each frame's in one batch: the host
## applies them; its own copies never die until the host says), the XP pearls
## they take (the host counts each once), and the chests they open. Each
## machine says when its own players go down or are revived; contact damage is
## always judged by the hurt player's own machine.

const CORRECT_RATE := 10.0
const BOSS_RATE := 15.0
const NEAR := 45.0
const MAX_CORRECT := 400

var coop: CoopSession
var run: UnnaturalRun

var _out_spawns := []
var _out_deaths := []
var _out_removes := PackedInt32Array()
var _out_hits := []
var _correct_left := 0.0
var _boss_left := 0.0


func _ready() -> void:
	name = "Unnatural"
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return run != null and run.authority


## Wires `game_run` up: what it does goes out.
func hook(game_run: UnnaturalRun) -> void:
	unhook()
	run = game_run
	_out_spawns.clear()
	_out_deaths.clear()
	_out_removes.clear()
	_out_hits.clear()
	if run.authority:
		run.horde.spawned.connect(_on_spawned)
		run.horde.killed.connect(_on_killed)
		run.horde.removed.connect(_on_removed)
		run.pearl_taken.connect(_on_pearl_taken)
		run.chest_buried.connect(_on_chest_buried)
		run.chest_opened.connect(_on_chest_opened)
		run.boss_arrived.connect(_on_boss_arrived)
		run.boss_defeated.connect(_on_boss_defeated)
	else:
		run.hit_claimed.connect(_on_hit_claimed)
		run.pearl_claimed.connect(_on_pearl_claimed)
		run.chest_claimed.connect(_on_chest_claimed)
	run.player_down.connect(_on_down.bind(true))
	run.player_revived.connect(_on_down.bind(false))


func unhook() -> void:
	if run == null or not is_instance_valid(run):
		run = null
		return
	for source: Object in [run, run.horde]:
		for info in source.get_signal_list():
			for connection in source.get_signal_connection_list(info.name):
				if (connection.callable as Callable).get_object() == self:
					source.disconnect(info.name, connection.callable)
	run = null  # (a boss's bolts hook goes with the boss)


func _send_all(method: StringName, args: Array, reliable: bool) -> void:
	coop.send_from(self, 0, method, args, reliable)


func _send_host(method: StringName, args: Array, reliable: bool) -> void:
	coop.send_from(self, 1, method, args, reliable)


func _pid(fish: Object) -> int:
	return coop.pid_of(fish) if is_instance_valid(fish) else -1


## Each physics tick (CoopSession's): the batches out, and the host's corrections.
func tick(delta: float) -> void:
	if run == null or not is_instance_valid(run):
		return
	if not _out_spawns.is_empty():
		_send_all("_spawns", [_out_spawns], true)
		_out_spawns = []
	if not _out_deaths.is_empty():
		_send_all("_deaths", [_out_deaths], true)
		_out_deaths = []
	if not _out_removes.is_empty():
		_send_all("_removes", [_out_removes], true)
		_out_removes = PackedInt32Array()
	if not _out_hits.is_empty():
		_send_host("_claim_hits", [_out_hits], true)
		_out_hits = []
	if not run.authority:
		return
	_correct_left -= delta
	if _correct_left <= 0.0:
		_correct_left += 1.0 / CORRECT_RATE
		_send_corrections()
	_boss_left -= delta
	if _boss_left <= 0.0 and not run.bosses.is_empty():
		_boss_left += 1.0 / BOSS_RATE
		for boss in run.bosses:
			if is_instance_valid(boss) and not boss.dying:
				_send_all("_boss_state", [boss.boss_id, boss.net_state()], false)


## The zombies near the guests' players, nearest first.
func _send_corrections() -> void:
	var near := PackedVector3Array()
	for fish in run.players:
		if is_instance_valid(fish) and fish.puppet:
			near.append(fish.global_position)
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	if not near.is_empty():
		var picked := {}
		for at in near:
			for i in run.horde.query_sphere(at, NEAR):
				if not run.horde.is_proxy(i):
					picked[i] = minf(picked.get(i, INF), run.horde.enemy_position(i).distance_squared_to(at))
		var order := picked.keys()
		if order.size() > MAX_CORRECT:
			order.sort_custom(func(a: int, b: int) -> bool: return picked[a] < picked[b])
			order.resize(MAX_CORRECT)
		for i: int in order:
			ids.append(run.horde.net_id_of(i))
			positions.append(run.horde.enemy_position(i))
			velocities.append(run.horde.enemy_velocity(i))
	_send_all("_correct", [run.elapsed, run.levels.level, run.levels.xp, run.kills, ids, positions, velocities], false)


# --- Host: the run -> the guests ------------------------------------------

func _on_spawned(index: int) -> void:
	if run.horde.is_proxy(index):
		return  # a boss's: sent with the boss
	_out_spawns.append([run.horde.net_id_of(index), run.horde.enemy_kind_index(index), run.horde.enemy_position(index),
			run.horde.enemy_velocity(index), run.horde.is_elite(index)])


func _on_killed(index: int, _kind: int, _at: Vector3, source: String, by: Object) -> void:
	_out_deaths.append([run.horde.net_id_of(index), source, _pid(by)])


func _on_removed(index: int) -> void:
	_out_removes.append(run.horde.net_id_of(index))


func _on_pearl_taken(id: int) -> void:
	_send_all("_pearl_taken", [id], true)


func _on_chest_buried(chest: TreasureChest) -> void:
	_send_all("_chest", [chest.position, chest.rotation.y], true)


func _on_chest_opened(chest: TreasureChest, _fish: FishController) -> void:
	_send_all("_chest_opened", [run.chests.find(chest)], true)


func _on_boss_arrived(boss: Boss) -> void:
	var parts := PackedInt32Array()
	for index in boss.parts:
		parts.append(run.horde.net_id_of(index))
	var kind := "miniboss" if boss is DrownedShark else "boss"
	_send_all("_boss_new", [kind, boss.boss_id, parts, boss.hp, boss.max_hp, boss.global_position], true)
	if boss.has_signal(&"spat"):
		boss.connect(&"spat", func(from: Vector3, directions: PackedVector3Array) -> void:
			_send_all("_boss_bolts", [boss.boss_id, from, directions], true))


func _on_boss_defeated(boss: Boss, by: FishController) -> void:
	_send_all("_boss_dead", [boss.boss_id, _pid(by)], true)


func _on_down(fish: FishController, is_down: bool) -> void:
	if is_instance_valid(fish) and not fish.puppet:
		_send_all("_down", [_pid(fish), is_down], true)


# --- Guest: the run -> the host -------------------------------------------

func _on_hit_claimed(net_id: int, amount: float, source: String, by: FishController) -> void:
	_out_hits.append([net_id, amount, source, _pid(by)])


func _on_pearl_claimed(id: int, by: FishController, xp: float) -> void:
	_send_host("_claim_pearl", [id, _pid(by), xp], true)


func _on_chest_claimed(index: int, by: FishController) -> void:
	_send_host("_claim_chest", [index, _pid(by)], true)


# --- Joining ---------------------------------------------------------------

## The world as it is now, for a guest joining (the host's).
func world() -> Dictionary:
	var zombies := []
	for i in run.horde.alive:
		if not run.horde.is_proxy(i):
			zombies.append([run.horde.net_id_of(i), run.horde.enemy_kind_index(i), run.horde.enemy_position(i),
					run.horde.enemy_velocity(i), run.horde.is_elite(i)])
	var chests := []
	for chest in run.chests:
		chests.append([chest.position, chest.rotation.y, chest.opened] if is_instance_valid(chest) else [Vector3.ZERO, 0.0, true])
	var bosses := []
	for boss in run.bosses:
		if is_instance_valid(boss) and not boss.dying:
			var parts := PackedInt32Array()
			for index in boss.parts:
				parts.append(run.horde.net_id_of(index))
			bosses.append(["miniboss" if boss is DrownedShark else "boss", boss.boss_id, parts, boss.hp, boss.max_hp,
					boss.global_position, boss.net_state()])
	return {"mode": "unnatural", "zombies": zombies, "chests": chests, "bosses": bosses, "elapsed": run.elapsed,
			"level": run.levels.level, "xp": run.levels.xp, "kills": run.kills, "over": run.is_over, "won": run.stage_complete}


## A guest's run takes the host's world.
func apply_world(state: Dictionary) -> void:
	run.horde.clear()
	_spawn_all(state.zombies)
	for entry: Array in state.chests:
		var chest := run.add_chest(entry[0], entry[1])
		if entry[2]:
			chest.open()
	for entry: Array in state.bosses:
		var boss := run.add_puppet_boss(entry[0], entry[1], entry[2], entry[3], entry[4], entry[5])
		boss.set_net_state(entry[6], coop.rtt / 2.0)
	run.elapsed = state.elapsed
	run.levels.set_state(state.level, state.xp)
	run.kills = state.kills
	run.is_over = state.over
	run.stage_complete = state.won


func _spawn_all(entries: Array) -> void:
	for entry: Array in entries:
		if run.horde.index_of_net(entry[0]) < 0:
			run.horde.spawn(entry[1], entry[2], entry[3], entry[4], false, entry[0])


# --- Guest side ------------------------------------------------------------

func _guest_run() -> UnnaturalRun:
	return run if run and is_instance_valid(run) and not run.authority else null


@rpc("authority", "call_remote", "reliable")
func _spawns(entries: Array) -> void:
	if _guest_run():
		_spawn_all(entries)


@rpc("authority", "call_remote", "reliable")
func _deaths(entries: Array) -> void:
	if not _guest_run():
		return
	for entry: Array in entries:
		var index := run.horde.index_of_net(entry[0])
		if index >= 0:
			run.horde.kill(index, entry[1], coop.fish_of(entry[2]))


@rpc("authority", "call_remote", "reliable")
func _removes(ids: PackedInt32Array) -> void:
	if not _guest_run():
		return
	for id in ids:
		var index := run.horde.index_of_net(id)
		if index >= 0 and not run.horde.is_proxy(index):
			run.horde.remove(index)


@rpc("authority", "call_remote", "unreliable")
func _correct(elapsed: float, level: int, xp: float, kills: int, ids: PackedInt32Array, positions: PackedVector3Array,
		velocities: PackedVector3Array) -> void:
	if not _guest_run():
		return
	var ahead := coop.rtt / 2.0
	run.elapsed = elapsed + ahead
	run.kills = maxi(run.kills, kills)
	if level >= run.levels.level:
		run.levels.set_state(level, xp)
	for n in ids.size():
		var index := run.horde.index_of_net(ids[n])
		if index >= 0:
			run.horde.correct(index, positions[n] + velocities[n] * ahead, velocities[n])


@rpc("authority", "call_remote", "reliable")
func _pearl_taken(id: int) -> void:
	if _guest_run():
		var pearl := run.pearl_by_id(id)
		if pearl:
			pearl.queue_free()


@rpc("authority", "call_remote", "reliable")
func _chest(at: Vector3, turn: float) -> void:
	if _guest_run():
		run.add_chest(at, turn)


@rpc("authority", "call_remote", "reliable")
func _chest_opened(index: int) -> void:
	if _guest_run():
		run.apply_chest_opened(index)


@rpc("authority", "call_remote", "reliable")
func _boss_new(kind: String, id: int, parts: PackedInt32Array, hp: float, max_hp: float, at: Vector3) -> void:
	if _guest_run() and run.boss_by_id(id) == null:
		run.add_puppet_boss(kind, id, parts, hp, max_hp, at)


@rpc("authority", "call_remote", "unreliable")
func _boss_state(id: int, state: Array) -> void:
	if not _guest_run():
		return
	var boss := run.boss_by_id(id)
	if boss and not boss.dying:
		boss.set_net_state(state, coop.rtt / 2.0)


@rpc("authority", "call_remote", "reliable")
func _boss_bolts(id: int, from: Vector3, directions: PackedVector3Array) -> void:
	if not _guest_run():
		return
	var boss := run.boss_by_id(id) as BloodLeviathan
	if boss:
		boss.add_bolts(from, directions)


@rpc("authority", "call_remote", "reliable")
func _boss_dead(id: int, pid: int) -> void:
	if not _guest_run():
		return
	var boss := run.boss_by_id(id)
	if boss:
		boss.defeat(coop.fish_of(pid))


# --- Host side -------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _claim_hits(entries: Array) -> void:
	if not is_host():
		return
	for entry: Array in entries:
		var index := run.horde.index_of_net(entry[0])
		if index >= 0:
			run.apply_claimed_hit(index, entry[1], coop.fish_of(entry[3]), entry[2])


@rpc("any_peer", "call_remote", "reliable")
func _claim_pearl(id: int, pid: int, xp: float) -> void:
	if is_host():
		run.confirm_pearl(id, coop.fish_of(pid), xp)


@rpc("any_peer", "call_remote", "reliable")
func _claim_chest(index: int, pid: int) -> void:
	if not is_host() or index < 0 or index >= run.chests.size():
		return
	var chest := run.chests[index]
	if is_instance_valid(chest) and not chest.opened:
		chest.open()
		var fish := coop.fish_of(pid)
		if fish:
			run.stats_of(fish)["chests"] = run.stats_of(fish).get("chests", 0) + 1
	_send_all("_chest_opened", [index], true)


# --- Everyone --------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _down(pid: int, is_down: bool) -> void:
	if run == null or not is_instance_valid(run):
		return
	var fish := coop.fish_of(pid)
	if fish and fish.puppet:
		run.set_remote_down(fish, is_down)
