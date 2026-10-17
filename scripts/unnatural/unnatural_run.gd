class_name UnnaturalRun
extends Node
## Unnatural mode in the Ocean (planning_unnatural.md): there's a blood moon
## tonight and every fish in the sea has turned, except the players. The
## zombies (a Horde) come after them; they survive, level up and (later) dig up
## treasure and beat the stage's boss.
##
## The arena is a disc arena_radius round the ocean's spawn, between
## arena_floor (the Seabed) and arena_ceiling, under the BloodMoon. Its edge
## pushes the fish back in (edge_push), and the ocean's fog thickens toward it.
## The EvilDirector sends packs of zombies from out of view as time goes on,
## more when the players have it easy and a breather when they're struggling;
## one that strays past the leash from every player is moved back near them.
## A Bloated Boxfish bursts on death into a cloud (BurstCloud) that hurts.
##
## Each player has health (FishHealth): touching a zombie hurts, then i-frames.
## Their fish attacks on its own (FishAttack: each fish its own, or the
## panel's fish_attack for every fish), and swims with its own twist
## (Traversal). Ramming a zombie at nature_batter_speed or faster batters it, the
## bow wave counting: damage that grows with speed, and i-frames for the hit,
## so ramming is rewarded rather than punished. Killed zombies drop XP pearls
## (Pearl, drawn in from pickup_range) for the team's one shared level
## (Levels); each level raises everyone's max hp and heals them by as much,
## gives each their fish's signature stat (StatBlock.SIGNATURE), and offers
## each local player card_choices cards (cards_offered), each a different stat
## at its own rarity (Rarity, which luck pushes up), to pick() one. Solo, the
## game pauses while the cards are up; in co-op (D3) nobody else waits, and
## the picker can't be hurt or seen by the zombies until they've picked. Each
## player's stats (StatBlock) feed their attack, damage, crits, batteries, swim,
## armour, regen, pickup range and XP.
##
## Chests (TreasureChest) lie buried round the arena, chest_count at the
## start and one more every chest_interval. Batter one, or hold still beside
## it for chest_open_time (untouchable and unseen meanwhile, D3), and it
## offers chest_choices powerups (chest_offered) to pick_card() one. Each
## player's powerups (Powerups) hook every hit (hit() carries a proc
## coefficient and the chain of powerups that led to it), kill, battery,
## tick and stride.
## The stage's timeline (StageTimeline) brings a closing ring, the Drowned
## Shark (mini-boss: its chest and XP when beaten), a stampede, a tide and the
## Blood Leviathan (the boss), the director holding its packs before each.
## Bosses are nodes (Boss) whose bodies are Horde proxies: hit() hands their
## damage over. Beating the Leviathan completes the stage (stage_completed);
## left too long it enrages and the director escalates (D5).
## When every player is down the run is over (the results board); R starts it
## again.
##
## With `test_tank` set (before adding it) it's the Test Tank instead
## (TestTank): no director, immortal dummies, the DPS log, panel overrides.
##
## Co-op (planning_unnatural.md §9): `players` are all of them (split-screen
## fish, and online puppets), and `authority` runs the world: the director,
## the timeline, relocation, bosses, chests and the team's level. Online, a
## guest's run (authority off) shows its own hits at once and claims them
## (hit_claimed), its zombies never dying until the host says (Horde.kill), its
## XP pearls claimed (pearl_claimed), its chests claimed (chest_claimed), its
## bosses puppets of the host's. UnnaturalNet carries it all.
##
## Lives under the Ocean (setup() before adding it). end() hands the players'
## fish back.

## A start (or restart) has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
## A zombie killed (where, its kind, by whom, with what: "bite", "battery"...).
signal zombie_killed(at: Vector3, kind: EnemyKind, by: FishController, source: String)
## A player hurt by `amount`.
signal player_hurt(fish: FishController, amount: float)
signal player_down(fish: FishController)
## A downed player is up again (a teammate revived them).
signal player_revived(fish: FishController)
## The team reached `level`.
signal leveled_up(level: int)
## Cards up for `fish` to pick from (pick()): a level's (each {"stat",
## "tier", "amount"}) or a chest's (each {"powerup", "stacks"}), with a heading
## and a line under it. Then the card they took.
signal cards_offered(fish: FishController, cards: Array, heading: String, line: String)
signal card_picked(fish: FishController, card: Dictionary)
## A chest opened by `fish`.
signal chest_opened(chest: TreasureChest, fish: FishController)
## Every player is down.
signal run_over
signal restarted
## A stage event is coming (StageTimeline's id), or has come.
signal stage_warned(event: String)
signal stage_event(event: String)
## A boss came, was beaten, or enraged.
signal boss_arrived(boss: Boss)
signal boss_defeated(boss: Boss, by: FishController)
signal boss_enraged(boss: Boss)
## The Leviathan's beaten: the stage is complete (the run's over, won).
signal stage_completed
## Online, a guest's: a hit on zombie `net_id` for the host to apply; an XP
## pearl a local player took (worth `xp`, gains applied); a chest opened here.
signal hit_claimed(net_id: int, amount: float, source: String, by: FishController)
signal pearl_claimed(id: int, by: FishController, xp: float)
signal chest_claimed(index: int, by: FishController)
## The host's: an XP pearl taken (so the guests' copies go), a chest buried.
signal pearl_taken(id: int)
signal chest_buried(chest: TreasureChest)

## Players spawn side by side, this far apart (m).
const SPAWN_SPACING := 3.0
## A zombie this near a player's middle (m, plus its own radius) touches it.
const PLAYER_RADIUS := 0.75
## How often strays are moved back near the players (s).
const RELOCATE_INTERVAL := 1.0
## New packs turn up outside this cone ahead of every player (cosine of its half-angle).
const SPAWN_HIDDEN := 0.3
## The i-frame flicker (per second).
const FLICKER_RATE := 16.0
## An elite's XP pearl is worth this many times its kind's.
const ELITE_XP := 5.0
## A beaten boss's XP pearl's id: this minus the boss's (zombies' are their net ids).
const BOSS_PEARL := 2000000000

var ocean: Ocean
## Every player's fish; the first is `player`.
var players: Array[FishController] = []
var player: FishController
## This machine runs the world (offline, or the online host). Set before adding.
var authority := true
## The Test Tank (set before adding): `tank` runs it.
var test_tank := false
var tank: TestTank
var powerup_settings := PowerupSettings.shared()
## The chests buried now (opened ones stay, empty).
var chests: Array[TreasureChest] = []
var settings := UnnaturalSettings.shared()
## The world's dice (spawn points, packs).
var rng := RandomNumberGenerator.new()
var horde: Horde
var director: EvilDirector
var timeline: StageTimeline
## The bosses out now.
var bosses: Array[Boss] = []
## The stage is won (the Leviathan beaten), or the Leviathan enraged.
var stage_complete := false
var enraged := false
var _next_boss_id := 1
var levels: Levels
var seabed: Seabed
var blood_moon: BloodMoon
## Seconds since the run started (stops when it's over).
var elapsed := 0.0
var is_over := false
## Zombies killed by the team this run.
var kills := 0
var pearls_out: Array[Pearl] = []
## The arena's middle (the ocean's spawn).
var centre := Vector3.ZERO

var _health := {}
var _attacks := {}
var _twists := {}
var _stats := {}
## Per player: their StatBlock and Powerups, level picks and chest picks
## still to make, the cards up now and which kind they are ("level", "chest"),
## and the chest they're opening by holding still.
var _blocks := {}
var _powerups := {}
var _pending := {}
var _chest_pending := {}
var _offers := {}
var _offer_kind := {}
var _opening := {}
var _stride_hooks := {}
## Downed local players' revive so far (0..1).
var _revive := {}
var _chest_left := 0.0
var _paused_for_cards := false
var _pearl_settings := NatureSettings.new()
var _clouds: Array[BurstCloud] = []
var _relocate_left := 0.0


func setup(run_ocean: Ocean, player_fish: FishController) -> void:
	ocean = run_ocean
	player = player_fish
	players = [player_fish]


func _ready() -> void:
	if authority:
		rng.randomize()
	centre = ocean.spawn_transform().origin
	horde = Horde.new()
	horde.name = "Horde"
	horde.arena_centre = centre
	add_child(horde)
	var kinds := EnemyKind.defaults()
	if test_tank:
		kinds.append(TestTank.dummy())
	horde.setup(settings, kinds, settings.max_enemies, rng.randi() & 0x7fffffff)
	horde.immortal = not authority  # a guest's die when the host says (Horde.kill)
	horde.killed.connect(_on_killed)
	if test_tank:
		tank = TestTank.new(self)
		horde.would_kill.connect(func(_index: int, _kind: int, source: String, _by: Object) -> void: tank.log_kill(source))
	director = EvilDirector.new(settings, horde, rng)
	director.spawn_point = spawn_point
	timeline = StageTimeline.new(settings)
	timeline.warned.connect(func(event: String) -> void: stage_warned.emit(event))
	timeline.started.connect(_start_event)
	levels = Levels.new(settings)
	levels.leveled_up.connect(_on_leveled_up)
	seabed = Seabed.new()
	seabed.name = "Seabed"
	seabed.position = centre + Vector3.UP * settings.arena_floor
	add_child(seabed)
	seabed.setup(settings.arena_radius, settings.seabed_rocks, settings.seabed_kelp)
	blood_moon = BloodMoon.new()
	blood_moon.name = "BloodMoon"
	blood_moon.ocean = ocean
	blood_moon.centre = centre
	blood_moon.radius = settings.arena_radius
	blood_moon.surface_height = centre.y + settings.arena_ceiling + 6.0
	blood_moon.strength = settings.blood_moon
	add_child(blood_moon)
	ocean.boundary_center = centre
	ocean.boundary_radius = settings.arena_radius
	for fish in players:
		_join(fish)
	start()


## Everyone back at the start: the horde gone, level 1, full health.
func start() -> void:
	if authority:
		restarted.emit()
	elapsed = 0.0
	is_over = false
	kills = 0
	_relocate_left = RELOCATE_INTERVAL
	_hold_for_cards(false)
	_offers.clear()
	_offer_kind.clear()
	_pending.clear()
	_chest_pending.clear()
	_opening.clear()
	_revive.clear()
	_bury_chests()
	_clear_bosses()
	horde.clear()
	director.reset()
	timeline.reset()
	stage_complete = false
	enraged = false
	levels.reset()
	for cloud in _clouds:
		if is_instance_valid(cloud):
			cloud.queue_free()
	_clouds.clear()
	for pearl in pearls_out:
		if is_instance_valid(pearl):
			pearl.queue_free()
	pearls_out.clear()
	if tank:
		tank.start()
	var spawn: Transform3D = ocean.spawn_transform()
	var moved: Array = []
	for fish in players:
		_reset_player(fish)
		if not fish.puppet:
			fish.revive(spawn_for(fish, spawn))
			moved.append(fish)
	_announce_teleport(moved)


## Where `fish` starts: beside the others, in its co-op place (meta
## "coop_index", else its place in `players`).
func spawn_for(fish: FishController, spawn: Transform3D) -> Transform3D:
	var index: int = fish.get_meta("coop_index", maxi(players.find(fish), 0))
	var side := 0.0 if index == 0 else SPAWN_SPACING * ceilf(index / 2.0) * (1.0 if index % 2 == 1 else -1.0)
	return Transform3D(spawn.basis, spawn.origin + spawn.basis.x * side)


## Hands the players' fish back. Call before freeing the run.
func end() -> void:
	set_physics_process(false)
	horde.set_physics_process(false)
	_hold_for_cards(false)
	for fish in players.duplicate():
		_leave(fish)
		if is_instance_valid(fish) and not fish.puppet:
			fish.controls_locked = false
			fish.set_model_visible(true)
			fish.speed_scale = 1.0
			fish.stride_scale = 1.0
			fish.bow_scale = 1.0
			fish.turn_scale = 1.0
			fish.drag_scale = 1.0
			if fish.battered:
				fish.revive(fish.global_transform)
	ocean.boundary_radius = 0.0


## Another player joins (their fish already in the tree).
func add_player(fish: FishController) -> void:
	if fish in players:
		return
	players.append(fish)
	_join(fish)
	_reset_player(fish)
	if not fish.puppet:
		var spawn: Transform3D = player.global_transform if is_instance_valid(player) else ocean.spawn_transform()
		fish.revive(spawn_for(fish, Transform3D(spawn.basis.orthonormalized(), spawn.origin)))
		_announce_teleport([fish])


func remove_player(fish: FishController) -> void:
	if fish not in players or fish == player:
		return
	_leave(fish)
	players.erase(fish)


## Puts the survivor cam (UnnaturalSettings' Camera group) on `camera` (a
## FollowCamera), or takes it off (`on` false: the usual chase view). Called
## every frame, live from the panel: camera_mode only sets the follow or free
## cam when it's put on, or when the setting changes, so the camera's own swap
## button sticks in between.
static func steady_camera(camera: Node, on: bool, from: UnnaturalSettings) -> void:
	if not is_instance_valid(camera):
		return
	var steady := on and from.steady_camera
	if not steady:
		camera.remove_meta("survivor_mode")
	elif camera.get_meta("survivor_mode", -1) != from.camera_mode:
		camera.set_meta("survivor_mode", from.camera_mode)
		camera.set("free_cam", from.camera_mode == 1)
	camera.set("hold_on_throttle", from.camera_hold_on_throttle)
	camera.set("free_turn_speed", deg_to_rad(from.free_cam_speed))
	camera.set("free_pitch_limit", deg_to_rad(from.free_cam_pitch))
	camera.set("free_follow_rate", from.free_cam_follow)
	camera.set("steady_heading", steady)
	camera.set("heading_rate", from.camera_turn_rate)
	camera.set("heading_climb", from.camera_climb)
	camera.set("extra_distance", from.camera_distance if steady else 0.0)
	camera.set("extra_height", from.camera_height if steady else 0.0)
	camera.set("extra_angle", from.camera_tilt if steady else 0.0)


## A player's health.
func health_of(fish: FishController) -> FishHealth:
	return _health.get(fish)


## `fish`'s auto-attack.
func attack_of(fish: FishController) -> FishAttack:
	return _attacks.get(fish)


## `fish`'s Ghost Bite, if that's its attack (else null).
func bite_of(fish: FishController) -> GhostBite:
	return _attacks.get(fish) as GhostBite


## `fish`'s traversal twist.
func twist_of(fish: FishController) -> Traversal:
	return _twists.get(fish)


## A player's run so far: kills, damage (and by source: "bite", "battery"),
## battered fish, pearls, damage taken, top speed (m/s).
func stats_of(fish: FishController) -> Dictionary:
	if not _stats.has(fish):
		_stats[fish] = _fresh_stats()
	return _stats[fish]


## Max hp at the team's level now (before anyone's own Max HP cards).
func max_hp() -> float:
	return settings.base_hp + settings.hp_per_level * (levels.level - 1)


## `fish`'s max hp: the team's level's, plus their Max HP cards.
func max_hp_of(fish: FishController) -> float:
	return max_hp() + block_of(fish).value("max_hp")


## `fish`'s stats (StatBlock).
func block_of(fish: FishController) -> StatBlock:
	if not _blocks.has(fish):
		_blocks[fish] = StatBlock.new()
	return _blocks[fish]


## `fish`'s powerups.
func powerups_of(fish: FishController) -> Powerups:
	if not _powerups.has(fish):
		_powerups[fish] = Powerups.new(self, fish)
	return _powerups[fish]


## `fish` has cards up, or is opening a chest (and can't be hurt or seen meanwhile).
func is_picking(fish: FishController) -> bool:
	return _offers.has(fish) or _opening.has(fish)


## The cards `fish` has up now (empty: none).
func offer_of(fish: FishController) -> Array:
	return _offers.get(fish, [])


## Whether the cards pause the game now (solo, cards_pause on, offline).
func cards_pause_game() -> bool:
	return settings.cards_pause and players.size() == 1 and not NetSession.is_online()


func local_players() -> Array[FishController]:
	var local: Array[FishController] = []
	for fish in players:
		if is_instance_valid(fish) and not fish.puppet:
			local.append(fish)
	return local


## Whether `fish` is up (in play: not down, not battered).
func is_up(fish: FishController) -> bool:
	var health: FishHealth = _health.get(fish)
	return is_instance_valid(fish) and not fish.battered and health != null and not health.down


func _join(fish: FishController) -> void:
	var health := FishHealth.new()
	health.reset(settings.base_hp)
	_health[fish] = health
	_make_attack(fish)
	if not fish.puppet and not _twists.has(fish):
		_twists[fish] = Traversal.new(self, fish)
	stats_of(fish)
	powerups_of(fish)
	if not _stride_hooks.has(fish):
		var hook := func(timing: float, _flow: float) -> void:
			if _powerups.has(fish) and is_up(fish):
				powerups_of(fish).on_stride(timing)
		_stride_hooks[fish] = hook
		fish.strode.connect(hook)
	for other in players:
		if other != fish and is_instance_valid(other):
			fish.add_collision_exception_with(other)  # co-op fish pass through each other
			other.add_collision_exception_with(fish)


func _leave(fish: FishController) -> void:
	var attack: FishAttack = _attacks.get(fish)
	if is_instance_valid(attack):
		attack.queue_free()
	_attacks.erase(fish)
	if _twists.has(fish):
		(_twists[fish] as Traversal).clear()
		_twists.erase(fish)
	_health.erase(fish)
	_offers.erase(fish)
	_offer_kind.erase(fish)
	_pending.erase(fish)
	_chest_pending.erase(fish)
	_opening.erase(fish)
	_revive.erase(fish)
	_blocks.erase(fish)
	if _powerups.has(fish):
		(_powerups[fish] as Powerups).clear()
		_powerups.erase(fish)
	var hook: Variant = _stride_hooks.get(fish)
	_stride_hooks.erase(fish)
	if not is_instance_valid(fish):
		return
	if hook != null and fish.strode.is_connected(hook):
		fish.strode.disconnect(hook)
	for other in players:
		if other != fish and is_instance_valid(other):
			fish.remove_collision_exception_with(other)
			other.remove_collision_exception_with(fish)


func _reset_player(fish: FishController) -> void:
	block_of(fish).reset()
	powerups_of(fish).clear()
	powerups_of(fish).refresh()
	_offers.erase(fish)
	_offer_kind.erase(fish)
	_pending.erase(fish)
	_chest_pending.erase(fish)
	_opening.erase(fish)
	var health: FishHealth = _health.get(fish)
	if health:
		health.reset(max_hp_of(fish))
	var attack: FishAttack = _attacks.get(fish)
	if attack:
		attack.cooldown_left = 0.0
	if _twists.has(fish):
		(_twists[fish] as Traversal).reset()
	_stats[fish] = _fresh_stats()
	if is_instance_valid(fish) and not fish.puppet:
		fish.controls_locked = false
		fish.set_model_visible(true)
	_apply_stats(fish)


## `fish`'s swim speed: its Swim Speed stat, times its twist's (frenzy, armour).
func _swim_scale(fish: FishController) -> float:
	var twist: Traversal = _twists.get(fish)
	return (1.0 + block_of(fish).value("swim_speed")) * (twist.speed_factor() if twist else 1.0)


static func _fresh_stats() -> Dictionary:
	return {"kills": 0, "damage": 0.0, "by_source": {}, "battered": 0, "pearls": 0, "taken": 0.0, "top_speed": 0.0, "crits": 0,
			"chests": 0}


## `fish`'s attack: its own (or the panel's fish_attack), built anew if that changed.
func _make_attack(fish: FishController) -> FishAttack:
	var kind := FishAttack.kind_for(fish.character, settings.fish_attack as FishAttack.Kind)
	var attack: FishAttack = _attacks.get(fish)
	if is_instance_valid(attack) and attack.kind == kind:
		return attack
	if is_instance_valid(attack):
		attack.queue_free()
	attack = FishAttack.make(kind)
	attack.fish = fish
	attack.horde = horde
	attack.settings = settings
	attack.on_hit = hit
	add_child(attack)
	_attacks[fish] = attack
	_apply_stats(fish)
	return attack


## `fish`'s stats on its attack, its swimming and its max hp.
func _apply_stats(fish: FishController) -> void:
	var block := block_of(fish)
	var attack: FishAttack = _attacks.get(fish)
	if attack:
		attack.attack_speed = 1.0 + block.value("attack_speed")
		attack.area_scale = 1.0 + block.value("area")
		attack.extra_projectiles = roundi(block.value("projectile_count"))
		attack.projectile_speed = 1.0 + block.value("projectile_speed")
	if is_instance_valid(fish) and not fish.puppet:
		fish.speed_scale = _swim_scale(fish)
		fish.stride_scale = 1.0 + block.value("stride_power")
	var health: FishHealth = _health.get(fish)
	if health:
		health.set_max(max_hp_of(fish))


func _physics_process(delta: float) -> void:
	if not is_over:
		elapsed += delta
	_update_targets()
	if not tank and not is_over:
		timeline.update(elapsed)  # a guest's only announces (the host's elapsed corrects ours)
	if tank:
		tank.update(delta)
	elif authority and not is_over:
		var around := PackedVector3Array()
		for fish in players:
			if is_up(fish):
				around.append(fish.global_position)
		director.elapsed = elapsed
		director.players = maxi(around.size(), 1)
		director.hushed = timeline.hushed(elapsed)
		director.escalation = settings.enrage_scale if enraged else 1.0
		director.update(delta, around)
		_relocate_strays(delta)
	for fish in local_players():
		var health: FishHealth = _health.get(fish)
		if health == null:
			continue
		_keep_in_arena(fish, delta)
		health.update(delta, settings.regen + block_of(fish).value("regen"))
		if is_picking(fish):
			health.shield(0.2)  # D3: untouchable while choosing
		fish.set_model_visible(health.down or health.iframes_left <= 0.0 or fmod(health.iframes_left * FLICKER_RATE, 1.0) < 0.5)
		var stats := stats_of(fish)
		stats.top_speed = maxf(stats.top_speed, fish.speed)
		var attack := _make_attack(fish)
		attack.update(delta, is_up(fish) and not is_over)
		var twist: Traversal = _twists.get(fish)
		if twist:
			twist.update(delta)
			fish.speed_scale = _swim_scale(fish)
		var powerups := powerups_of(fish)
		powerups.refresh()  # the testing override, live
		if health.down and not is_over:
			_try_revive(fish, health, delta)
		if not is_up(fish) or is_over:
			continue
		powerups.on_tick(delta)
		_open_chests(fish, delta)
		_batter_zombies(fish)
		if not tank or settings.tank_contact:
			_touch_zombies(fish)
			_touch_clouds(fish)
	_sync_pearls()


## The horde chases every player who's up.
func _update_targets() -> void:
	var at := PackedVector3Array()
	var moving := PackedVector3Array()
	var chaseable := PackedByteArray()
	at.resize(players.size())
	moving.resize(players.size())
	chaseable.resize(players.size())
	for i in players.size():
		var fish := players[i]
		if is_instance_valid(fish):
			at[i] = fish.global_position
			moving[i] = fish.swim_velocity()
			chaseable[i] = 1 if is_up(fish) and not is_over and not is_picking(fish) else 0
	horde.targets = at
	horde.target_velocities = moving
	horde.chaseable = chaseable


## Hurts zombie `index` by `amount` from `source`, credited to `by`: every
## damage source comes through here, and `by`'s powerups hear of it. `proc` is
## the hit's proc coefficient (1 for an attack or battery); `chain` lists the
## powerups that led to it, which it can't start again.
func hit(index: int, amount: float, by: FishController, source: String, push := Vector3.ZERO, proc := 1.0, chain: Array = []) -> void:
	if not horde.is_alive(index):
		return
	if by:
		var block := block_of(by)
		amount *= 1.0 + block.value("damage")
		var stats := stats_of(by)
		if block.value("crit_chance") > 0.0 and rng.randf() < block.value("crit_chance"):
			amount *= 1.5 + block.value("crit_damage")
			stats.crits += 1
		push *= 1.0 + block.value("knockback")
		stats.damage += amount
		stats.by_source[source] = stats.by_source.get(source, 0.0) + amount
	if tank:
		tank.log_hit(source, amount)
	var boss := boss_at(index)
	if boss:
		boss.take(amount, by, source)
	else:
		horde.damage(index, amount, source, by, push)
	if not authority and by and not by.puppet:
		hit_claimed.emit(horde.net_id_of(index), amount, source, by)
	if by and _powerups.has(by):
		(_powerups[by] as Powerups).on_hit(index, amount, source, proc, chain)


## A guest's hit on zombie `index`, claimed to us (the host): its damage
## (their stats already in it), credited to their puppet `by`.
func apply_claimed_hit(index: int, amount: float, by: FishController, source: String) -> void:
	if not horde.is_alive(index) or amount <= 0.0:
		return
	if by:
		var stats := stats_of(by)
		stats.damage += amount
		stats.by_source[source] = stats.by_source.get(source, 0.0) + amount
	var boss := boss_at(index)
	if boss:
		boss.take(amount, by, source)
	else:
		horde.damage(index, amount, source, by)


## Every zombie `fish`'s front touches at its battering speed or faster (the
## bow wave counting) is battered: damage growing with speed, a moment's
## i-frames, and a big one slows the fish.
func _batter_zombies(fish: FishController) -> void:
	var batter_speed := fish.nature_batter_speed * powerups_of(fish).batter_speed_share()
	if fish.speed < batter_speed or settings.battery_damage <= 0.0:
		return
	var hitbox := (fish.get_node("Collision") as Node3D).global_transform.orthonormalized()
	var half := Vector3(fish.hitbox_width, fish.hitbox_height, fish.hitbox_length) * 0.5 + Vector3.ONE * Battery.REACH
	var front := half
	if fish.bow_amount > 0.0:
		front = front.max(fish.bow_size())
	var nose := -hitbox.basis.z
	var to_local := hitbox.basis.transposed()
	var health: FishHealth = _health[fish]
	var damage := settings.battery_damage * pow(fish.speed / maxf(fish.nature_batter_speed, 0.1), settings.battery_speed_power) \
			* (1.0 + block_of(fish).value("battery_damage"))
	for i in horde.query_sphere(hitbox.origin, maxf(front.x, maxf(front.y, front.z))):
		if horde.cooldown(i) > 0.0:
			continue
		var offset := horde.enemy_position(i) - hitbox.origin
		var r := horde.enemy_radius(i)
		var local := to_local * offset
		# Ahead: the bow wave's ellipsoid; behind the middle: the hitbox's.
		var extent := front if local.z < 0.0 else half
		var q := Vector3(local.x / (extent.x + r), local.y / (extent.y + r), local.z / (extent.z + r))
		if q.length_squared() > 1.0:
			continue
		if offset.length() > r and offset.normalized().dot(nose) < Battery.FRONT:
			continue
		horde.set_cooldown(i, settings.battery_repeat)
		health.shield(settings.battery_iframes)
		if horde.enemy_size(i) >= 1.5:
			_slow(fish, settings.big_enemy_slow)
		hit(i, damage, fish, "battery", nose)
		powerups_of(fish).on_battery(i)


## A zombie touching `fish` (not one it's battering) hurts it, then i-frames.
func _touch_zombies(fish: FishController) -> void:
	var health: FishHealth = _health[fish]
	if health.iframes_left > 0.0 or settings.enemy_damage_scale <= 0.0:
		return
	var at := fish.global_position
	var battering := fish.speed >= fish.nature_batter_speed
	var nose := -fish.global_basis.z
	for i in horde.query_sphere(at, PLAYER_RADIUS):
		var offset := horde.enemy_position(i) - at
		if battering and offset.length_squared() > 0.0001 and offset.normalized().dot(nose) >= Battery.FRONT:
			continue  # it's being battered, not biting
		var kind := horde.enemy_kind(i)
		var amount := kind.contact_damage * settings.enemy_damage_scale * (2.0 if horde.is_elite(i) else 1.0)
		var boss := boss_at(i)
		if boss:
			amount = boss.contact()
		if not hurt(fish, amount):
			return
		var away := offset.normalized() if offset.length_squared() > 0.0001 else -nose
		horde.damage(i, 0.0, "contact", null, away)  # knocked back off the fish
		return


## A boxfish's burst cloud `fish` is in hurts it.
func _touch_clouds(fish: FishController) -> void:
	for cloud in _clouds:
		if is_instance_valid(cloud) and cloud.contains(fish.global_position, PLAYER_RADIUS):
			hurt(fish, settings.burst_damage * settings.enemy_damage_scale)
			return


## `fish` takes `amount` (unless in i-frames), then i-frames. Returns whether it hurt.
func hurt(fish: FishController, amount: float) -> bool:
	if amount <= 0.0:
		return false
	var twist: Traversal = _twists.get(fish)
	if twist:
		amount *= twist.taken_factor()
	amount = maxf(amount - block_of(fish).value("armour"), 1.0)
	var health: FishHealth = _health.get(fish)
	if health == null or not health.take(amount, settings.iframes, settings.god_mode):
		return false
	stats_of(fish).taken += amount
	director.on_damage(amount / maxf(health.max_hp, 1.0))
	player_hurt.emit(fish, amount)
	if health.down:
		_on_down(fish)
	return true


func _on_down(fish: FishController) -> void:
	fish.controls_locked = true
	fish.set_model_visible(true)
	_revive[fish] = 0.0
	player_down.emit(fish)
	check_all_down()


## Every player down: the run's over (solo, the first time).
func check_all_down() -> void:
	if is_over:
		return
	for other in players:
		if is_up(other):
			return  # co-op: the others carry on, and can revive (D7)
	is_over = true
	run_over.emit()


## How far `fish` is through being revived (0..1; 0 when it isn't down).
func revive_progress(fish: FishController) -> float:
	return _revive.get(fish, 0.0)


## A teammate who's up within revive_range of downed `fish` revives it over revive_time.
func _try_revive(fish: FishController, health: FishHealth, delta: float) -> void:
	var helped := false
	for other in players:
		if other != fish and is_up(other) and other.global_position.distance_to(fish.global_position) <= settings.revive_range:
			helped = true
			break
	var progress: float = _revive.get(fish, 0.0)
	progress = minf(progress + delta / maxf(settings.revive_time, 0.01), 1.0) if helped else maxf(progress - delta * 0.5, 0.0)
	_revive[fish] = progress
	if progress >= 1.0:
		revive(fish)


## `fish` is up again with revive_hp of its max hp.
func revive(fish: FishController) -> void:
	var health: FishHealth = _health.get(fish)
	if health == null or not health.down:
		return
	health.revive(settings.revive_hp)
	_revive.erase(fish)
	if not fish.puppet:
		fish.controls_locked = false
	player_revived.emit(fish)


## A remote player's down state, as their own machine says (online).
func set_remote_down(fish: FishController, is_down: bool) -> void:
	var health: FishHealth = _health.get(fish)
	if health == null or health.down == is_down:
		return
	if is_down:
		health.hp = 0.0
		health.down = true
		player_down.emit(fish)
		check_all_down()
	else:
		health.revive(settings.revive_hp)
		player_revived.emit(fish)


## Takes `share` of `fish`'s speed.
func _slow(fish: FishController, share: float) -> void:
	if share <= 0.0:
		return
	fish.apply_push(-fish.linear_velocity * clampf(share, 0.0, 1.0))


## The arena's edge and depth band push a fish back in, harder the further out.
func _keep_in_arena(fish: FishController, delta: float) -> void:
	if settings.edge_push <= 0.0:
		return
	var offset := fish.global_position - centre
	var velocity := fish.linear_velocity
	var change := Vector3.ZERO
	var flat := Vector2(offset.x, offset.z)
	var out := flat.length()
	if out > settings.arena_radius and out > 0.001:
		var outward := Vector3(flat.x, 0.0, flat.y) / out
		change -= outward * settings.edge_push * (1.0 + out - settings.arena_radius) * delta
		var leaving := velocity.dot(outward)
		if leaving > 0.0:
			change -= outward * leaving * minf(4.0 * delta, 1.0)
	var floor_y := settings.arena_floor + 1.5
	if offset.y < floor_y:
		change.y += settings.edge_push * (1.0 + floor_y - offset.y) * delta
		if velocity.y < 0.0:
			change.y -= velocity.y * minf(8.0 * delta, 1.0)
	elif offset.y > settings.arena_ceiling:
		change.y -= settings.edge_push * (1.0 + offset.y - settings.arena_ceiling) * delta
		if velocity.y > 0.0:
			change.y -= velocity.y * minf(4.0 * delta, 1.0)
	if change != Vector3.ZERO:
		fish.apply_push(change)


## A point spawn_distance from `around`, out of every player's view, inside the arena.
func spawn_point(around: Vector3) -> Vector3:
	var point := around
	var reach := settings.arena_radius - 3.0
	for attempt in 16:
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 0.35), rng.randf_range(-1.0, 1.0)).normalized()
		var distance := rng.randf_range(settings.spawn_distance_min, maxf(settings.spawn_distance_min, settings.spawn_distance_max))
		point = around + direction * distance
		var flat := Vector2(point.x - centre.x, point.z - centre.z)
		if flat.length() > reach:
			flat = flat.normalized() * reach
			point = Vector3(centre.x + flat.x, point.y, centre.z + flat.y)
		point.y = clampf(point.y, centre.y + settings.arena_floor + 2.0, centre.y + settings.arena_ceiling - 1.0)
		var hidden := true
		for fish in players:
			if not is_instance_valid(fish):
				continue
			var offset := point - fish.global_position
			if offset.length() > 0.001 and offset.normalized().dot(-fish.global_basis.z) >= SPAWN_HIDDEN:
				hidden = false
				break
		if hidden:
			break
	return point


## Zombies past the leash from every player who's up move to a spawn point near one.
func _relocate_strays(delta: float) -> void:
	_relocate_left -= delta
	if _relocate_left > 0.0:
		return
	_relocate_left = RELOCATE_INTERVAL
	var up := PackedVector3Array()
	for fish in players:
		if is_up(fish):
			up.append(fish.global_position)
	if up.is_empty():
		return
	var leash := settings.leash * settings.leash
	for i in horde.alive:
		if horde.is_proxy(i):
			continue
		var at := horde.enemy_position(i)
		var near := false
		for p in up:
			if p.distance_squared_to(at) < leash:
				near = true
				break
		if not near:
			horde.relocate(i, spawn_point(up[rng.randi_range(0, up.size() - 1)]))


func _on_killed(index: int, kind_index: int, at: Vector3, source: String, by: Object) -> void:
	kills += 1
	director.on_kill()
	var kind := horde.kinds[kind_index]
	if kind.behaviour == EnemyKind.Behaviour.TANK and settings.burst_radius > 0.0 and settings.burst_time > 0.0:
		_burst(at, settings.burst_radius * horde.enemy_size(index) / kind.size)
	var fish := by as FishController
	if fish:
		var stats := stats_of(fish)
		stats.kills += 1
		if source == "battery":
			stats.battered += 1
		if _twists.has(fish):
			(_twists[fish] as Traversal).on_kill()
		if _powerups.has(fish):
			(_powerups[fish] as Powerups).on_kill(at, source)
	if tank:
		zombie_killed.emit(at, kind, fish, source)
		return  # no XP in the Test Tank: the level is the panel's
	drop_pearl(at, kind.xp * (ELITE_XP if horde.is_elite(index) else 1.0), horde.net_id_of(index))
	zombie_killed.emit(at, kind, fish, source)


## The boss whose body zombie slot `index` is (null: an ordinary zombie).
func boss_at(index: int) -> Boss:
	if bosses.is_empty() or not horde.is_proxy(index):
		return null
	for boss in bosses:
		if is_instance_valid(boss) and boss.owns(index):
			return boss
	return null


## A stage event starts (StageTimeline): a swarm or a boss.
func _start_event(event: String) -> void:
	stage_event.emit(event)
	if not authority:
		return  # the host makes it happen; its zombies and bosses come over the network
	var around := PackedVector3Array()
	for fish in players:
		if is_up(fish):
			around.append(fish.global_position)
	if around.is_empty():
		return
	var crowd := 1.0 + settings.coop_scale * maxi(around.size() - 1, 0)
	match event:
		"ring":
			for at in around:
				_ring(at, roundi(settings.ring_count * crowd / around.size()), settings.ring_radius)
		"stampede":
			var p := around[0]
			var from := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
			horde.spawn_pack(0, roundi(settings.stampede_count * crowd), p + from * 45.0, 6.0, -from, 0.0)
		"tide":
			var p := around[0]
			var from := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
			var across := Vector3.UP.cross(from)
			var count := roundi(settings.tide_count * crowd)
			for n in count:
				var along := (float(n) / maxf(count - 1, 1) - 0.5) * 70.0
				var at := p + from * 40.0 + across * along + Vector3.UP * rng.randf_range(-5.0, 5.0)
				horde.spawn(director.pick_kind(), at, -from, rng.randf() < director.elite_chance())
		"miniboss":
			_add_boss(DrownedShark.new(), spawn_point(around[0]), settings.shark_hp * crowd)
		"boss":
			_clean_up(around)
			_add_boss(BloodLeviathan.new(), spawn_point(around[0]), settings.leviathan_hp * crowd)


## `count` zombies in a ring `radius` m round `at`, facing in.
func _ring(at: Vector3, count: int, radius: float) -> void:
	for n in count:
		var angle := TAU * n / maxf(count, 1)
		var spot := at + Vector3(cos(angle), rng.randf_range(-0.25, 0.25), sin(angle)) * radius
		horde.spawn(director.pick_kind(), spot, (at - spot).normalized(), rng.randf() < director.elite_chance())


## Clears away the zombies further than boss_cleanup from every player in `around`.
func _clean_up(around: PackedVector3Array) -> void:
	if settings.boss_cleanup <= 0.0:
		return
	var reach := settings.boss_cleanup * settings.boss_cleanup
	for i in horde.alive.duplicate():
		if horde.is_proxy(i):
			continue
		var at := horde.enemy_position(i)
		var near := false
		for p in around:
			if p.distance_squared_to(at) < reach:
				near = true
				break
		if not near:
			horde.remove(i)


func _add_boss(boss: Boss, at: Vector3, boss_hp: float, id := 0) -> void:
	boss.run = self
	if id <= 0:
		id = _next_boss_id
	_next_boss_id = maxi(_next_boss_id, id + 1)
	boss.boss_id = id
	boss.max_hp = boss_hp
	boss.hp = boss_hp
	boss.position = at
	add_child(boss)
	bosses.append(boss)
	boss.defeated.connect(_on_boss_defeated)
	if boss is BloodLeviathan:
		(boss as BloodLeviathan).enraged_now.connect(func() -> void:
			enraged = true
			boss_enraged.emit(boss))
	boss_arrived.emit(boss)


## A guest's puppet of the host's boss `id` (`kind`: "miniboss", "boss"), its
## body the host's proxies `part_ids`.
func add_puppet_boss(kind: String, id: int, part_ids: PackedInt32Array, boss_hp: float, boss_max: float, at: Vector3) -> Boss:
	var boss: Boss = DrownedShark.new() if kind == "miniboss" else BloodLeviathan.new()
	boss.puppet = true
	boss.part_ids = part_ids
	_add_boss(boss, at, boss_max, id)
	boss.hp = boss_hp
	return boss


func boss_by_id(id: int) -> Boss:
	for boss in bosses:
		if is_instance_valid(boss) and boss.boss_id == id:
			return boss
	return null


## The boss shown on the HUD: the last one to come still fighting (null: none).
func current_boss() -> Boss:
	for b in range(bosses.size() - 1, -1, -1):
		if is_instance_valid(bosses[b]) and not bosses[b].dying:
			return bosses[b]
	return null


func _on_boss_defeated(boss: Boss, by: FishController) -> void:
	bosses.erase(boss)
	kills += 1
	if is_instance_valid(by):
		stats_of(by).kills += 1
		stats_of(by)["bosses"] = stats_of(by).get("bosses", 0) + 1
	boss_defeated.emit(boss, by)
	if boss is DrownedShark:
		var chest := TreasureChest.new()
		chest.name = "SharkChest"
		chest.position = boss.global_position
		add_child(chest)
		chests.append(chest)
		drop_pearl(boss.global_position, settings.shark_xp, BOSS_PEARL - boss.boss_id)
	elif boss is BloodLeviathan:
		stage_complete = true
		is_over = true
		_hold_for_cards(false)
		stage_completed.emit()


## Every boss gone at once (a new start).
func _clear_bosses() -> void:
	for boss in bosses:
		if is_instance_valid(boss):
			boss.parts.clear()
			boss.queue_free()
	bosses.clear()


## A boxfish's cloud at `at`, `radius` m round.
func _burst(at: Vector3, radius: float) -> void:
	var cloud := BurstCloud.new()
	cloud.name = "BurstCloud"
	cloud.radius = radius
	cloud.lifetime = settings.burst_time
	cloud.position = at
	add_child(cloud)
	cloud.tree_exiting.connect(func() -> void: _clouds.erase(cloud))
	_clouds.append(cloud)


## An XP pearl worth `value` at `at` (past max_pearls, the oldest takes its XP instead).
func drop_pearl(at: Vector3, value: float, id := -1) -> void:
	if value <= 0.0:
		return
	if pearls_out.size() >= settings.max_pearls and is_instance_valid(pearls_out[0]):
		pearls_out[0].value += value
		return
	_sync_pearls()
	var pearl := Pearl.new(_pearl_settings)
	pearl.name = "XpPearl"
	pearl.value = value
	pearl.id = id
	pearl.collectors.assign(local_players())  # online, each machine's own players pick up
	pearl.position = at
	add_child(pearl)
	pearl.set_light(settings.pearl_lights)
	pearl.reset_physics_interpolation()
	pearl.collected.connect(_on_pearl_collected)
	pearl.tree_exiting.connect(func() -> void: pearls_out.erase(pearl))
	pearls_out.append(pearl)


func _on_pearl_collected(pearl: Pearl, by: FishController) -> void:
	var gain := 1.0
	if is_instance_valid(by):
		stats_of(by).pearls += 1
		gain += block_of(by).value("xp_gain")
	if authority:
		levels.add(pearl.value * gain)
		pearl_taken.emit(pearl.id)
	else:
		pearl_claimed.emit(pearl.id, by, pearl.value * gain)  # the host adds it (once)


## The XP pearl `id` here, if it's still out.
func pearl_by_id(id: int) -> Pearl:
	if id < 0:
		return null
	for pearl in pearls_out:
		if is_instance_valid(pearl) and pearl.id == id:
			return pearl
	return null


## A guest's pearl claim (we're the host): the XP, once; returns whether it counted.
func confirm_pearl(id: int, by: FishController, xp: float) -> bool:
	var pearl := pearl_by_id(id)
	if pearl == null:
		return false  # gone already (someone else got it)
	pearl.queue_free()
	if is_instance_valid(by):
		stats_of(by).pearls += 1
	levels.add(xp)
	pearl_taken.emit(id)
	return true


## The XP pearls' look and pull from UnnaturalSettings.
func _sync_pearls() -> void:
	var reach := 0.0
	for key: Variant in _blocks:
		reach = maxf(reach, (_blocks[key] as StatBlock).value("pickup_range"))
	_pearl_settings.magnet_radius = settings.pickup_range * (1.0 + reach)
	_pearl_settings.magnet_strength = settings.pickup_pull
	_pearl_settings.pearl_lifetime = settings.pearl_lifetime
	_pearl_settings.pearl_size = settings.pearl_size
	_pearl_settings.absorb_radius = 1.2


## Everyone's max hp rises with the team's level, healing by as much; each
## gets their signature stat, and each local player a pick of cards.
func _on_leveled_up(level: int) -> void:
	for fish: FishController in _health:
		if not is_instance_valid(fish):
			continue
		var signature := StatBlock.signature(fish.character)
		block_of(fish).add(signature, StatBlock.amount(signature, settings.signature_steps))
		_apply_stats(fish)
	leveled_up.emit(level)
	if settings.card_choices <= 0:
		return
	for fish in local_players():
		_pending[fish] = _pending.get(fish, 0) + 1
		if not _offers.has(fish):
			_offer_next(fish)


## `fish`'s next pick, if any: a chest's first, then a level's. Otherwise
## back to play.
func _offer_next(fish: FishController) -> void:
	if not is_instance_valid(fish):
		return
	if _chest_pending.get(fish, 0) > 0:
		_offer_chest(fish)
	elif _pending.get(fish, 0) > 0:
		_offer_level(fish)
	else:
		_pending.erase(fish)
		_chest_pending.erase(fish)
		if _offers.is_empty():
			_hold_for_cards(false)


## card_choices different stats, each with its own rarity.
func _offer_level(fish: FishController) -> void:
	var left: int = _pending.get(fish, 0)
	var pool := StatBlock.pool(attack_of(fish))
	var luck := block_of(fish).value("luck")
	var cards := []
	for n in mini(settings.card_choices, pool.size()):
		var at := rng.randi_range(0, pool.size() - 1)
		var stat: String = pool[at]
		pool.remove_at(at)
		var tier := Rarity.roll(rng, settings, luck)
		cards.append({"stat": stat, "tier": tier, "amount": StatBlock.amount(stat, Rarity.multiplier(settings, tier))})
	_offers[fish] = cards
	_offer_kind[fish] = "level"
	var signature := StatBlock.signature(fish.character)
	var gave := "+%d MAX HP    ·    %s (SIGNATURE)" % [roundi(settings.hp_per_level),
			StatBlock.describe(signature, StatBlock.amount(signature, settings.signature_steps)).to_upper()]
	if cards_pause_game():
		_hold_for_cards(true)
	cards_offered.emit(fish, cards, "LEVEL %d" % (levels.level - left + 1), gave)


## chest_choices different powerups.
func _offer_chest(fish: FishController) -> void:
	var pool := Powerup.ids()
	var cards := []
	for n in mini(settings.chest_choices, pool.size()):
		var at := rng.randi_range(0, pool.size() - 1)
		var id: String = pool[at]
		pool.remove_at(at)
		cards.append({"powerup": id, "stacks": powerups_of(fish).stacks(id) + 1})
	_offers[fish] = cards
	_offer_kind[fish] = "chest"
	if cards_pause_game():
		_hold_for_cards(true)
	cards_offered.emit(fish, cards, "TREASURE!", "PICK A POWERUP  ·  THE SAME ONE AGAIN STACKS")


## `fish` takes card `index` of those up: a level's stat goes up, or a chest's
## powerup is theirs (another stack); then their next pick, or back to play.
func pick(fish: FishController, index: int) -> void:
	var cards: Array = _offers.get(fish, [])
	if cards.is_empty():
		return
	var card: Dictionary = cards[clampi(index, 0, cards.size() - 1)]
	if _offer_kind.get(fish, "level") == "chest":
		powerups_of(fish).add(card.powerup)
		_chest_pending[fish] = _chest_pending.get(fish, 1) - 1
	else:
		block_of(fish).add(card.stat, card.amount)
		_apply_stats(fish)
		_pending[fish] = _pending.get(fish, 1) - 1
	_offers.erase(fish)
	_offer_kind.erase(fish)
	card_picked.emit(fish, card)
	_offer_next(fish)


## Chests round the arena: chest_count now, on the seabed.
func _bury_chests() -> void:
	for chest in chests:
		if is_instance_valid(chest):
			chest.queue_free()
	chests.clear()
	_chest_left = settings.chest_interval
	if test_tank or not authority:
		return  # a guest's come from the host
	for n in settings.chest_count:
		_bury_chest()


func _bury_chest() -> void:
	var spot := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf_range(0.02, 1.0)) * settings.arena_radius * 0.9
	var chest := add_chest(centre + Vector3(spot.x, settings.arena_floor - TreasureChest.SIZE.y * 0.3, spot.y), rng.randf() * TAU)
	chest_buried.emit(chest)


## A chest at `at`, turned `turn` (radians).
func add_chest(at: Vector3, turn: float) -> TreasureChest:
	var chest := TreasureChest.new()
	chest.name = "Chest"
	chest.position = at
	chest.rotation.y = turn
	add_child(chest)
	chests.append(chest)
	return chest


## The chests still shut.
func shut_chests() -> Array[TreasureChest]:
	var shut: Array[TreasureChest] = []
	for chest in chests:
		if is_instance_valid(chest) and not chest.opened:
			shut.append(chest)
	return shut


## `fish` opens a chest by battering it, or by holding still beside it for
## chest_open_time (untouchable meanwhile); one more is uncovered now and then.
func _open_chests(fish: FishController, delta: float) -> void:
	if authority and fish == local_players()[0] and not test_tank and settings.chest_interval > 0.0:
		_chest_left -= delta
		if _chest_left <= 0.0:
			_chest_left = settings.chest_interval
			if shut_chests().size() < settings.chest_max:
				_bury_chest()
	if _offers.has(fish):
		return
	var at := fish.global_position
	var nose := -fish.global_basis.z
	var battering := fish.speed >= fish.nature_batter_speed * powerups_of(fish).batter_speed_share()
	var still := fish.speed <= settings.chest_still_speed
	var holding: TreasureChest = null
	for chest in shut_chests():
		var middle := chest.global_position + Vector3.UP * TreasureChest.SIZE.y * 0.5
		var offset := middle - at
		var gap := offset.length()
		if gap > settings.chest_reach + GhostBite.bow_reach(fish):
			continue
		if battering and gap > 0.001 and offset.normalized().dot(nose) >= Battery.FRONT:
			open_chest(chest, fish)
			return
		if still and gap <= settings.chest_reach:
			holding = chest
	if holding:
		_opening[fish] = holding
		holding.progress = minf(holding.progress + delta / maxf(settings.chest_open_time, 0.01), 1.0)
		if holding.progress >= 1.0:
			open_chest(holding, fish)
	else:
		var was: TreasureChest = _opening.get(fish)
		_opening.erase(fish)
		if is_instance_valid(was) and not was.opened:
			was.progress = 0.0


## Opens `chest` for `fish`: a powerup pick for them.
func open_chest(chest: TreasureChest, fish: FishController) -> void:
	if chest.opened:
		return
	chest.open()
	_opening.erase(fish)
	stats_of(fish)["chests"] = stats_of(fish).get("chests", 0) + 1
	chest_opened.emit(chest, fish)
	if not authority:
		chest_claimed.emit(chests.find(chest), fish)
	_chest_pending[fish] = _chest_pending.get(fish, 0) + 1
	if not _offers.has(fish):
		_offer_next(fish)


## Chest `index` opened by someone elsewhere (online): shut no more, no pick here.
func apply_chest_opened(index: int) -> void:
	if index >= 0 and index < chests.size() and is_instance_valid(chests[index]) and not chests[index].opened:
		chests[index].open()


## Pauses the game for the cards (solo), or lets it go again.
func _hold_for_cards(on: bool) -> void:
	if on:
		_paused_for_cards = true
		get_tree().paused = true
	elif _paused_for_cards:
		_paused_for_cards = false
		if is_inside_tree():
			get_tree().paused = false


func _announce_teleport(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)
