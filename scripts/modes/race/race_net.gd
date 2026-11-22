class_name RaceNet
extends ModeNet
## Online Fin-ish Line (planning_race.md §11): CoopSession's child "Race" (the same
## path everywhere, so its RPCs meet). CoopSession still does the session, the
## roster, the players' fish (each machine runs its own and sends it) and the
## tuning (RaceSettings travels with the host's sections).
##
## The host (RaceMatch.authority) judges everything: progress, checkpoints,
## positions, rescues, the countdown and the finish clock. It sends:
## - reliable: the phase and its clocks, restarts, laps, finishes, rescues (the fade to
##   everyone, the put-back to the one peer whose fish is moved), the results, and the bots
##   (there are none on a guest: puppets of the host's, named by negative ids);
## - unreliable, STANDINGS_RATE times a second: every racer's lap, distance, progress, place
##   and gate (the HUD's positions and the minimap), and the bots' states, SEND_RATE a second.
## A guest sends its fish (CoopSession) and its rescue button; it judges nobody.

## Standings per second.
const STANDINGS_RATE := 10.0
## Bot states per second.
const SEND_RATE := 30.0

var game: RaceMatch
## The match last hooked (puppets leave it after unhook()).
var _last_game: RaceMatch

## Host: bot fish -> its id (negative). Guest: id -> NetFish of the host's bot.
var _bot_ids := {}
var _bot_nets := {}
var _standings_left := 0.0
var _send_left := 0.0
## The last standings a guest applied (for the probe): the rows as received.
var last_standings: Array = []
## Host: the bot list last sent (to notice a bot giving its seat to a person).
var _bots_sent: Array = []


func _ready() -> void:
	name = "Race"
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return game != null and game.authority


func puppet_added(fish: FishController) -> void:
	if is_instance_valid(_last_game):
		_last_game.add_player(fish)


func puppet_removed(fish: FishController) -> void:
	if is_instance_valid(_last_game):
		_last_game.remove_player(fish)


func puppet_parent() -> Node:
	return _last_game


## Wires `mode_game` up: what it does goes out.
func hook(mode_game: GameMode) -> void:
	unhook()
	game = mode_game as RaceMatch
	_last_game = game
	last_standings = []
	_bots_sent = []
	if game.authority:
		_number_bots()
		game.phase_changed.connect(_on_phase_changed)
		game.lap_completed.connect(_on_lap_completed)
		game.racer_finished.connect(_on_finished)
		game.rescued.connect(_on_rescued)
		game.put_back.connect(_on_put_back)
		game.race_over.connect(_on_race_over)
	else:
		game.local_rescue_requested.connect(_on_local_rescue_requested)
	game.fish_teleported.connect(coop.note_teleport)


func unhook() -> void:
	if game and is_instance_valid(game):
		for connection in get_incoming_connections():
			var sig: Signal = connection.signal
			if sig.get_object() == game:
				sig.disconnect(connection.callable)
	for net: NetFish in _bot_nets.values():
		if is_instance_valid(net.fish):
			net.fish.queue_free()
	_bot_nets.clear()
	_bot_ids.clear()
	game = null


## The race as it is now, for a guest joining (CoopSession's _welcome).
func world() -> Dictionary:
	var keys := {}
	for r in game.racers:
		if r.human:
			keys[id_of(r.fish)] = key_of(r.fish)
	return {"mode": RaceSettings.KEY, "bots": _bot_list(), "keys": keys, "phase": int(game.phase), "count_left": game.count_left,
			"race_time": game.race_time, "clock_left": game.clock_left, "standings": _standing_rows()}


## A guest: the host's race as it was when we joined.
func apply_world(state: Dictionary) -> void:
	_apply_bots(state.get("bots", []))
	var keys: Dictionary = state.get("keys", {})
	for id: Variant in keys:
		var fish := fish_by_id(int(id))
		if fish:
			game.apply_net_roster_key(fish, str(keys[id]))
	game.apply_net_phase(int(state.phase), float(state.count_left), float(state.race_time), float(state.clock_left))
	_apply_standings(state.get("standings", []))


# --- Ids -------------------------------------------------------------------

## A fish's id on the network: its player id (CoopSession), or a bot's negative id.
func id_of(fish: FishController) -> int:
	if fish == null:
		return 0
	if is_host():
		if _bot_ids.has(fish):
			return int(_bot_ids[fish])
	else:
		for id: int in _bot_nets:
			if (_bot_nets[id] as NetFish).fish == fish:
				return id
	return coop.pid_of(fish)


func fish_by_id(id: int) -> FishController:
	if id == 0:
		return null
	if id < 0:
		if is_host():
			for fish: FishController in _bot_ids:
				if int(_bot_ids[fish]) == id:
					return fish
			return null
		var net: NetFish = _bot_nets.get(id)
		return net.fish if net and is_instance_valid(net.fish) else null
	return coop.fish_of(id)


## The roster entry key `fish` wears (what a guest dresses its puppet as).
func key_of(fish: FishController) -> String:
	var r: RaceMatch.Racer = game.racer_of(fish)
	return str(r.entry.get("key", "")) if r != null else ""


## The peer whose player `fish` is (0: none, a bot or ours).
func _peer_of(fish: FishController) -> int:
	var pid := coop.pid_of(fish)
	return pid / 100 if pid >= 0 and fish.puppet else 0


## The fish this machine simulates for a person (not puppets, not bots).
func local_players() -> Array[FishController]:
	var out: Array[FishController] = []
	for r in game.racers:
		if r.human and is_instance_valid(r.fish) and not r.fish.puppet:
			out.append(r.fish)
	return out


func local_fish() -> FishController:
	var mine := local_players()
	return mine[0] if not mine.is_empty() else null


func _number_bots() -> void:
	_bot_ids.clear()
	var next := -1
	for r in game.racers:
		if not r.human and is_instance_valid(r.fish):
			_bot_ids[r.fish] = next
			next -= 1


func _bot_list() -> Array:
	var out := []
	for fish: FishController in _bot_ids:
		if is_instance_valid(fish):
			out.append([int(_bot_ids[fish]), key_of(fish), fish.display_name])
	return out


## A guest: puppets of the host's bots to match `list` ([id, roster key, name]).
func _apply_bots(list: Array) -> void:
	var wanted := {}
	for entry: Array in list:
		wanted[int(entry[0])] = entry
	for id: int in _bot_nets.keys():
		if not wanted.has(id):
			var gone: NetFish = _bot_nets[id]
			_bot_nets.erase(id)
			if is_instance_valid(gone.fish):
				game.remove_player(gone.fish)
				gone.fish.queue_free()
	for id: int in wanted:
		if _bot_nets.has(id):
			continue
		var entry: Array = wanted[id]
		var net := NetFish.new()
		net.fish = game.spawn_net_bot(id, str(entry[1]), str(entry[2]))
		net.fish.visible = false  # until its first snapshot
		_bot_nets[id] = net


# --- Each tick -------------------------------------------------------------

## The puppets follow their players, ours goes out, then the bots and the standings.
func tick(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	coop.follow_puppets(func(_fish: FishController) -> bool: return true)
	coop.send_own_fish(delta, local_players())
	for net: NetFish in _bot_nets.values():
		if net.has_state() and is_instance_valid(net.fish):
			net.fish.visible = true
			net.apply()
	if not is_host():
		return
	_notice_bot_changes()
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left += 1.0 / SEND_RATE
		var states := []
		for fish: FishController in _bot_ids:
			if is_instance_valid(fish):
				states.append([int(_bot_ids[fish]), fish.global_position, fish.global_basis.get_rotation_quaternion(), fish.linear_velocity,
						fish.replay_fx(), coop._teleports.get(fish, 0)])
		if not states.is_empty():
			coop.send_from(self, 0, "_race_bot_states", [CoopSession._now(), states], false)
	_standings_left -= delta
	if _standings_left <= 0.0:
		_standings_left += 1.0 / STANDINGS_RATE
		coop.send_from(self, 0, "_race_standings", [_standing_rows(), game.race_time, game.clock_left], false)


## A bot gave its seat to a person (RaceMatch.add_player): the guests drop its puppet.
func _notice_bot_changes() -> void:
	var seats := []
	for r in game.racers:
		if not r.human and is_instance_valid(r.fish):
			seats.append(r.fish.get_instance_id())
	if seats != _bots_sent:
		_bots_sent = seats
		_number_bots()
		coop.send_from(self, 0, "_race_bots", [_bot_list()], true)


## The host's standings as wire rows:
## [id, laps, d, progress, place, next_cp, started, finished, best_lap (-1: none), finish_time, rescue_stage].
func _standing_rows() -> Array:
	var rows := []
	for r in game.racers:
		if is_instance_valid(r.fish):
			rows.append([id_of(r.fish), r.laps, r.d, r.progress, r.place, r.next_cp, r.started, r.finished,
					r.best_lap if not is_inf(r.best_lap) else -1.0, r.finish_time, r.rescue_stage])
	return rows


## A guest: the rows turned back into fish and handed to the match for its HUD and minimap.
func _apply_standings(rows: Array) -> void:
	last_standings = rows
	var out: Array[Dictionary] = []
	for row: Array in rows:
		var fish := fish_by_id(int(row[0]))
		if fish:
			out.append({"fish": fish, "laps": int(row[1]), "d": float(row[2]), "progress": float(row[3]), "place": int(row[4]),
					"next_cp": int(row[5]), "started": bool(row[6]), "finished": bool(row[7]),
					"best_lap": float(row[8]) if float(row[8]) >= 0.0 else INF, "finish_time": float(row[9]), "rescue_stage": int(row[10])})
	game.apply_net_standings(out)


# --- Host: match -> session --------------------------------------------------

## A new race (back to the grid) is a restart on the guests; the other phases carry their clocks.
func _on_phase_changed(new_phase: int) -> void:
	if new_phase == RaceMatch.Phase.COUNTDOWN:
		_notice_bot_changes()
		coop.send_from(self, 0, "_race_restart", [game.count_left], true)
	else:
		coop.send_from(self, 0, "_race_phase", [new_phase, game.count_left, game.race_time, game.clock_left], true)


func _on_lap_completed(fish: FishController, laps_done: int, lap_time: float) -> void:
	coop.send_from(self, 0, "_race_lap", [id_of(fish), laps_done, lap_time], true)


func _on_finished(fish: FishController, place: int, time: float) -> void:
	var r: RaceMatch.Racer = game.racer_of(fish)
	coop.send_from(self, 0, "_race_finish", [id_of(fish), place, time, r.best_lap if r and not is_inf(r.best_lap) else -1.0], true)


## A rescue began: everyone sees the fade and the banner.
func _on_rescued(fish: FishController, reason: String) -> void:
	coop.send_from(self, 0, "_race_rescue_begin", [id_of(fish), reason], true)


## The fade-out is over: a guest's own fish is moved on its own machine (it is ours to move there).
func _on_put_back(fish: FishController, at: Transform3D, push: Vector3) -> void:
	var peer := _peer_of(fish)
	if peer != 0:
		coop._teleports[fish] = coop._teleports.get(fish, 0) + 1
		coop.send_from(self, peer, "_race_put_back", [coop.pid_of(fish), at, push], true)


func _on_race_over(results: Array) -> void:
	var out := []
	for row: Dictionary in results:
		out.append([id_of(row.fish), int(row.place), float(row.time), float(row.best_lap) if not is_inf(float(row.best_lap)) else -1.0,
				bool(row.finished), int(row.laps)])
	coop.send_from(self, 0, "_race_results", [out], true)


# --- Guest: our player -> the host --------------------------------------------

func _on_local_rescue_requested() -> void:
	coop.send_from(self, 1, "_race_rescue_request", [coop.pid_of(local_fish())], true)


# --- RPCs: host side -------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _race_rescue_request(pid: int) -> void:
	var fish := fish_by_id(pid)
	if is_host() and fish and pid / 100 == multiplayer.get_remote_sender_id():
		game.rescue(fish, "button")


# --- RPCs: guest side ------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _race_bots(list: Array) -> void:
	if game and not is_host():
		_apply_bots(list)


@rpc("authority", "call_remote", "unreliable")
func _race_bot_states(time: float, states: Array) -> void:
	if game == null or is_host():
		return
	coop._host_clock.note_time(time)
	for state: Array in states:
		var net: NetFish = _bot_nets.get(int(state[0]))
		if net:
			net.push(time, state[1], state[2], state[3], state[4], int(state[5]))


@rpc("authority", "call_remote", "unreliable")
func _race_standings(rows: Array, race_time: float, clock_left: float) -> void:
	if game == null or is_host():
		return
	game.apply_net_clock(race_time, clock_left)
	_apply_standings(rows)


@rpc("authority", "call_remote", "reliable")
func _race_phase(new_phase: int, count_left: float, race_time: float, clock_left: float) -> void:
	if game and not is_host():
		game.apply_net_phase(new_phase, count_left, race_time, clock_left)


@rpc("authority", "call_remote", "reliable")
func _race_restart(count_left: float) -> void:
	if game and not is_host():
		game.apply_net_restart(count_left)


@rpc("authority", "call_remote", "reliable")
func _race_lap(id: int, laps_done: int, lap_time: float) -> void:
	var fish := fish_by_id(id)
	if game and not is_host() and fish:
		game.apply_net_lap(fish, laps_done, lap_time)


@rpc("authority", "call_remote", "reliable")
func _race_finish(id: int, place: int, time: float, best_lap: float) -> void:
	var fish := fish_by_id(id)
	if game and not is_host() and fish:
		game.apply_net_finish(fish, place, time, best_lap if best_lap >= 0.0 else INF)


## Anyone's rescue began (the fade and the banner).
@rpc("authority", "call_remote", "reliable")
func _race_rescue_begin(id: int, reason: String) -> void:
	var fish := fish_by_id(id)
	if game and not is_host() and fish:
		game.apply_net_rescue_begin(fish, reason)


## Our own fish was put back on the host: move it (it is ours, so the host cannot).
@rpc("authority", "call_remote", "reliable")
func _race_put_back(pid: int, at: Transform3D, push: Vector3) -> void:
	var mine := local_fish() if game else null
	if mine == null or is_host() or pid != coop.pid_of(mine):
		return
	game.apply_net_put_back(mine, at, push)


@rpc("authority", "call_remote", "reliable")
func _race_results(rows: Array) -> void:
	if game == null or is_host():
		return
	var out: Array[Dictionary] = []
	for row: Array in rows:
		var fish := fish_by_id(int(row[0]))
		if fish:
			var r: RaceMatch.Racer = game.racer_of(fish)
			out.append({"fish": fish, "name": r.name if r else fish.display_name, "place": int(row[1]), "time": float(row[2]),
					"best_lap": float(row[3]) if float(row[3]) >= 0.0 else INF, "finished": bool(row[4]), "human": r.human if r else false,
					"laps": int(row[5]), "entry": str(r.entry.get("label", "")) if r else ""})
	game.apply_net_results(out)
