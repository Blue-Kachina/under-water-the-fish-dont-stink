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
## so ramming is rewarded rather than punished. A kill's XP goes straight to
## the team's one shared level (Levels; D22, credit_xp()), and now and then
## the kill drops a pearl (D23, _roll_pearl()): the currency, drawn in from
## pickup_range into the taker's purse. Each level raises everyone's max hp
## and heals them by as much, gives each their fish's signature stat
## (StatBlock.SIGNATURE), and offers each local player card_choices cards
## (cards_offered, CardDeck): weapon and tome upgrades, and new ones while
## their slots (Loadout) are free, each at its own rarity (Rarity, which luck
## pushes up), to pick() one. Solo, the game pauses while the cards are up;
## in co-op (D3) nobody else waits, and the picker can't be hurt or seen by
## the zombies until they've picked. Each player's stats (StatBlock, which
## tomes add to) feed their attack, damage, crits, batteries, swim, armour,
## regen, pickup range, XP and pearls.
##
## Chests (TreasureChest) lie buried round the arena, chest_count at the
## start and one more every chest_interval. They cost pearls (chest_price(),
## rising through the run). Batter one, or hold still beside it for
## chest_open_time (untouchable and unseen meanwhile, D3), and it offers
## chest_choices items (chest_offered) to pick_card() one. Each
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
## The final boss fell: its whirlpool is open (the run goes on until someone enters it).
signal whirlpool_opened(at: Vector3)
## `fish` entered the whirlpool (the host's call online; everyone then sees the stage complete).
signal whirlpool_entered(fish: FishController)
## A guest's player asks the host to let them in.
signal whirlpool_claimed(fish: FishController)
signal boss_enraged(boss: Boss)
## The Leviathan's beaten: the stage is complete (the run's over, won).
signal stage_completed
## Online, a guest's: a hit on zombie `net_id` for the host to apply; a pearl
## a local player took; XP a local player's kill earned (gains applied, for
## the host to add to the team's); a chest opened here.
signal hit_claimed(net_id: int, amount: float, source: String, by: FishController)
signal pearl_claimed(id: int, by: FishController)
signal xp_claimed(xp: float)
signal chest_claimed(index: int, by: FishController)
## `fish` backed out of a chest (cancel_offer): shut for them again. A guest says so to the host (chest_unclaimed).
## `fish` held still beside `chest` long enough: it's unlocked, and waits for their Jump.
signal chest_unlocked(chest: TreasureChest, fish: FishController)
signal chest_reshut(chest: TreasureChest, fish: FishController)
signal chest_unclaimed(index: int, by: FishController)
## `fish` cancelled the chest it was choosing from (the HUD closes the cards).
signal offer_cancelled(fish: FishController)
## The host's: a pearl dropped (worth `value`), or taken (so the guests'
## copies go); a chest buried.
signal pearl_dropped(id: int, at: Vector3, value: int)
signal pearl_taken(id: int)
## Drops (Pickup), online: one dropped here (the host's), one taken here (the
## host's word: everyone applies it), and one a guest's player touched (to the host).
signal pickup_dropped(pickup: Pickup)
signal pickup_taken(id: int, kind: int, by: FishController)
signal pickup_claimed(id: int, by: FishController)
signal chest_buried(chest: TreasureChest)
## A drop took effect (for the HUD's note).
signal drop_taken(kind: int, by: FishController)
## The Sunken Idol took a stack of powerup `id` from `fish` (a stage event).
signal powerup_lost(fish: FishController, id: String)
## A zombie (or a boss's body) was hurt, by whatever source (the hits' one door,
## hit(), and a guest's claimed hits): its slot, the damage, who, with what, and
## the powerups that led to it (a chain). last_hit_crit says whether it crit.
signal zombie_hit(index: int, amount: float, by: FishController, source: String, chain: Array)
## A local player took a pearl (the currency).
signal pearl_collected(by: FishController)
## The next stage began (P5: the whirlpool, in a run with more stages).
signal stage_began(stage: int)
## Shrines (P5): one placed (the host's, for the guests); a guest's player used
## one only the host can set off (Tide, Deep, Pearls); one set off (on every
## machine); and what came of a local player's use ("won", "lost", "short",
## "tide", "deep", "pearls", "tide_won").
signal shrine_placed(shrine: Shrine)
signal shrine_claimed(index: int, by: FishController)
signal shrine_activated(shrine: Shrine, by: FishController)
signal shrine_used(shrine: Shrine, by: FishController, result: String)
## A player's rerolls, skips or banishes changed (P4).
signal choices_changed(fish: FishController)

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
## An elite's XP is this many times its kind's.
const ELITE_XP := 5.0
## An elite's kill is this many times likelier to drop a chest or a pickup.
const ELITE_CHEST := 5.0
## How often the crowd round each player is counted for the camera's pull (s).
const CROWD_EVERY := 0.25
## An area hit (hit_area()) has its powerups hear this many of its zombies at most.
const AREA_PROC_ROLLS := 3

## The perf pass's switch, for A/B benches: off, an area hit is a hit() apiece
## and every powerup hears every hit, as before it.
static var batch_hits := true
## The hit path's cost (benches read and reset these): microseconds inside the
## outermost hit() / hit_area() calls (what they set off included), and how
## many zombies were hit.
static var hit_usec := 0
static var hits_counted := 0
static var _hit_depth := 0
static var _hit_started := 0
## The hit source of the Lightning Bolt drop's arena-wide shock.
const LIGHTNING_SOURCE := "lightning"
## A beaten boss's pearls' ids: this minus the boss's x 1000, minus the pearl's
## number (zombies' are their net ids).
const BOSS_PEARL := 2000000000
## A boss's pearls spill this far round it (m).
const BOSS_PEARL_SPREAD := 3.0

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
## The way out, once the final boss is down (null before). Entering it ends the run in a win.
var whirlpool: Whirlpool
## Run seconds since the final boss fell (-1: not yet).
var cleared_at := -1.0
## The swarm event on ({} none): {"id", "left" (s), "next" (s to its next wave), "wave"}.
var swarm := {}
const SWARM_EVENTS: Array[String] = ["ring", "stampede", "tide"]
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
## Hearts, magnets and hourglasses out (Pickup).
var pickups: Array[Pickup] = []
## Decoys the horde chases as well as the players (Anglerfish Lure's lures,
## each with a `pull`, see Horde.target_pull). Freed ones drop out.
var decoys: Array[Node3D] = []
var _next_pickup_id := 1
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
## Per player: their weapons and tomes (Loadout), their pearl purse, and the
## attack level last put on their attack.
var _loadouts := {}
var _purses := {}
var _attack_levels := {}
## Online, the host's: each remote player's Pearl Chance, as their machine says.
var _remote_pearl_chance := {}
var _pending := {}
var _chest_pending := {}
## Each player's chest being chosen from: {chest, price, committed} (until their first pick: cancel_offer).
var _chest_offer := {}
## The cards rolled for a chest, per player: chest -> {fish -> {cards, heading, line}}, so putting it back and
## opening it again can't reroll them.
var _chest_rolls := {}
## Sunken Idol's extra picks left from the chest `fish` has up, and Moon
## Pearl's from the level's cards they have up.
var _extra_picks := {}
var _level_extra := {}
var _offers := {}
var _offer_kind := {}
var _opening := {}
## The chest each player last put back (fish -> chest): no battering it open again until they swim clear.
var _backed_out := {}
var _stride_hooks := {}
## Downed local players' revive so far (0..1).
var _revive := {}
var _chest_left := 0.0
var _paused_for_cards := false
var _pearl_settings := NatureSettings.new()
var _clouds: Array[BurstCloud] = []
var _relocate_left := 0.0
## The run's log (null in the Test Tank): saved when the run ends.
var run_log: RunLog
## Whether the hit zombie_hit is telling of now was a crit (read it while the
## signal's going out: the damage numbers do), and how much of it landed (no
## more than the hp it had: a killing blow's overkill left off).
var last_hit_crit := false
var last_hit_dealt := 0.0
## Feel (P3): the kill bursts and the warning lanes, in the world.
var kill_pops: KillPops
var telegraphs: Telegraphs
## Each local player's survivor cam pull-back now (m: the crowd and their Size,
## camera_pull_of()), eased.
var _camera_pull := {}
## Each local player's crowd (zombies within camera_crowd_range), counted every CROWD_EVERY s.
var _crowd := {}
var _crowd_left := 0.0
## When (run s) the last drop came, and the last of each kind (Pickup.Kind -> s):
## drops are timed (heart_every..., drop_gap).
var _last_drop := -INF
var _last_drop_of := {}

## Stages (P5): which one this is (from 1), and the run time it began at
## (stage_time() counts from there: the timeline, the director, difficulty).
var stage := 1
var stage_started := 0.0
## Shrines of the Deep set off this stage, and the stage's shrines.
var deep := 0
var shrines: Array[Shrine] = []
## A beaten shrine's pearls' ids: this minus stage x 1000, shrine x 50, the pearl's number.
const SHRINE_PEARL := 1900000000
## A chest's `item` that makes it free (a Tide won).
const FREE_CHEST := "free"
## The seabed's seed is this plus the stage.
const SEABED_SEED := 11
## Per player (P4): rerolls, skips and banishes left ({"rerolls", "skips",
## "banishes"}), and what they've banished (weapon, tome and item ids).
var _choices := {}
var _banished := {}
## Local players chilled by a Frozen elite's touch: seconds left.
var _chill := {}
## Seconds to the next round of Burning elites' fire patches.
var _burn_left := 0.0
var _seabed_seed := SEABED_SEED


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
	_seabed_seed = -1
	_build_seabed()
	blood_moon = BloodMoon.new()
	blood_moon.name = "BloodMoon"
	blood_moon.ocean = ocean
	blood_moon.centre = centre
	blood_moon.radius = settings.arena_radius
	blood_moon.surface_height = centre.y + settings.arena_ceiling + 6.0
	blood_moon.strength = settings.blood_moon
	blood_moon.settings = settings
	add_child(blood_moon)
	kill_pops = KillPops.new()
	kill_pops.name = "KillPops"
	kill_pops.settings = settings
	add_child(kill_pops)
	telegraphs = Telegraphs.new()
	telegraphs.name = "Telegraphs"
	telegraphs.run = self
	add_child(telegraphs)
	ocean.boundary_center = centre
	ocean.boundary_radius = settings.arena_radius
	if not test_tank:
		run_log = RunLog.new(self)
		add_child(run_log)
		run_over.connect(func() -> void: run_log.finish("down"))
		stage_completed.connect(func() -> void: run_log.finish("won"))
	for fish in players:
		_join(fish)
	start()


## Everyone back at the start: the horde gone, level 1, full health.
func start() -> void:
	_log_quit()
	if authority:
		restarted.emit()
	elapsed = 0.0
	is_over = false
	kills = 0
	_last_drop = -INF
	_last_drop_of.clear()
	_relocate_left = RELOCATE_INTERVAL
	_hold_for_cards(false)
	_offers.clear()
	_offer_kind.clear()
	_pending.clear()
	_chest_pending.clear()
	_chest_offer.clear()
	_chest_rolls.clear()
	_extra_picks.clear()
	_level_extra.clear()
	_opening.clear()
	_backed_out.clear()
	_revive.clear()
	_chill.clear()
	stage = 1
	stage_started = 0.0
	deep = 0
	horde.stage_hp = 1.0
	_burn_left = 0.0
	_build_seabed()
	_bury_chests()
	_place_shrines()
	_clear_bosses()
	if is_instance_valid(whirlpool):
		whirlpool.queue_free()
	whirlpool = null
	cleared_at = -1.0
	swarm = {}
	horde.clear()
	if kill_pops:
		kill_pops.clear()
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
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
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
	if run_log:
		run_log.begin()


## A run left before it ended (restarted, or the mode changed): its log, as
## quit, if it got anywhere.
func _log_quit() -> void:
	if run_log and run_log.ending.is_empty() and elapsed >= 10.0:
		run_log.finish("quit")


## Where `fish` starts: beside the others, in its co-op place (meta
## "coop_index", else its place in `players`).
func spawn_for(fish: FishController, spawn: Transform3D) -> Transform3D:
	var index: int = fish.get_meta("coop_index", maxi(players.find(fish), 0))
	var side := 0.0 if index == 0 else SPAWN_SPACING * ceilf(index / 2.0) * (1.0 if index % 2 == 1 else -1.0)
	return Transform3D(spawn.basis, spawn.origin + spawn.basis.x * side)


## Hands the players' fish back. Call before freeing the run.
func end() -> void:
	_log_quit()
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
## button sticks in between. `pull`: m further back on top (camera_pull_of()).
static func steady_camera(camera: Node, on: bool, from: UnnaturalSettings, pull := 0.0) -> void:
	if not is_instance_valid(camera):
		return
	var steady := on and from.steady_camera
	if not steady:
		camera.remove_meta("survivor_mode")
	elif camera.get_meta("survivor_mode", -1) != from.camera_mode:
		camera.set_meta("survivor_mode", from.camera_mode)
		camera.set("free_cam", from.camera_mode == 1)
	camera.set("hold_on_throttle", from.camera_hold_on_throttle)
	camera.set("swing_rate", from.camera_swing_rate)
	camera.set("free_turn_speed", deg_to_rad(from.free_cam_speed))
	camera.set("free_pitch_limit", deg_to_rad(from.free_cam_pitch))
	camera.set("free_follow_rate", from.free_cam_follow)
	camera.set("free_invert_y", from.free_cam_invert_y)
	camera.set("steady_heading", steady)
	camera.set("heading_rate", from.camera_turn_rate)
	camera.set("heading_climb", from.camera_climb)
	camera.set("extra_distance", from.camera_distance + pull if steady else 0.0)
	camera.set("extra_height", from.camera_height + pull * 0.3 if steady else 0.0)
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


## Whether `fish` has its stink off (the Moon Jelly's Go Quiet): it fires nothing, and zombies lose it.
func is_quiet(fish: FishController) -> bool:
	var twist: Traversal = _twists.get(fish)
	return twist != null and twist.quiet


## `fish's traversal twist and mobility skill.
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
	var scale: float = (_powerups[fish] as Powerups).max_hp_scale() if _powerups.has(fish) else 1.0  # Glass Coral
	return maxf((max_hp() + block_of(fish).value("max_hp")) * scale, 1.0)


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


## `fish`'s weapons and tomes.
func loadout_of(fish: FishController) -> Loadout:
	if not _loadouts.has(fish):
		_loadouts[fish] = Loadout.new()
	return _loadouts[fish]


## `fish`'s pearls to spend.
func purse_of(fish: FishController) -> int:
	return _purses.get(fish, 0)


func add_pearls(fish: FishController, amount: int) -> void:
	if is_instance_valid(fish):
		_purses[fish] = maxi(purse_of(fish) + amount, 0)


## `fish`'s Pearl Chance: their own stat here, or (a remote player's, online)
## what their machine said.
func pearl_chance_of(fish: FishController) -> float:
	if not is_instance_valid(fish):
		return 0.0
	if fish.puppet:
		return _remote_pearl_chance.get(fish, 0.0)
	return block_of(fish).value("pearl_chance")


## A remote player's Pearl Chance, from their machine (the host's, online).
func set_remote_pearl_chance(fish: FishController, value: float) -> void:
	if is_instance_valid(fish):
		_remote_pearl_chance[fish] = value


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
	if not fish.puppet and fish.controls == null and not _twists.has(fish):
		_twists[fish] = Traversal.new(self, fish)
		fish.set_meta("boost_before", fish.boost_enabled)
		fish.boost_enabled = false  # the boost button is the fish's mobility skill here
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
		if is_instance_valid(fish) and fish.has_meta("boost_before"):
			fish.boost_enabled = fish.get_meta("boost_before")
			fish.remove_meta("boost_before")
		_twists.erase(fish)
	_health.erase(fish)
	_offers.erase(fish)
	_offer_kind.erase(fish)
	_pending.erase(fish)
	_chest_pending.erase(fish)
	_chest_offer.erase(fish)
	_opening.erase(fish)
	_backed_out.erase(fish)
	_revive.erase(fish)
	_level_extra.erase(fish)
	_blocks.erase(fish)
	_loadouts.erase(fish)
	_choices.erase(fish)
	_banished.erase(fish)
	_chill.erase(fish)
	_purses.erase(fish)
	_attack_levels.erase(fish)
	_remote_pearl_chance.erase(fish)
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
	loadout_of(fish).reset()
	_choices[fish] = {"rerolls": settings.start_rerolls, "skips": settings.start_skips, "banishes": settings.start_banishes}
	_banished[fish] = []
	_chill.erase(fish)
	_purses.erase(fish)
	_attack_levels.erase(fish)
	powerups_of(fish).clear()
	powerups_of(fish).refresh()
	_offers.erase(fish)
	_offer_kind.erase(fish)
	_pending.erase(fish)
	_chest_pending.erase(fish)
	_chest_offer.erase(fish)
	_opening.erase(fish)
	_backed_out.erase(fish)
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
	var chill := (1.0 - clampf(settings.frozen_slow, 0.0, 0.95)) if _chill.get(fish, 0.0) > 0.0 else 1.0  # a Frozen elite's touch
	return (1.0 + block_of(fish).value("swim_speed")) * (twist.speed_factor() if twist else 1.0) * chill


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
	attack.run = self
	attack.powers = powerup_settings
	attack.on_hit = hit
	add_child(attack)
	_attacks[fish] = attack
	_apply_stats(fish)
	return attack


## `fish`'s stats on its attack (with the attack's own weapon facets and
## milestones), its swimming and its max hp.
func _apply_stats(fish: FishController) -> void:
	var block := block_of(fish)
	var attack: FishAttack = _attacks.get(fish)
	if attack:
		var loadout := loadout_of(fish)
		loadout.attack_kind = attack.kind
		var level := loadout.level(Weapons.ATTACK)
		attack.configure(block, loadout.facets_of(Weapons.ATTACK), level)
		_attack_levels[fish] = level
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
	if is_instance_valid(blood_moon):
		horde.apply_murk(blood_moon.fog_density() if settings.murky() else 0.0)
		if is_instance_valid(seabed):
			seabed.set_murk(settings.murk_density)
	if not tank and not is_over:
		timeline.update(stage_time())  # a guest's only announces (the host's elapsed corrects ours)
		_update_swarm(delta)
		_update_shrines(delta)
		_update_affixes(delta)
	if tank:
		tank.update(delta)
	elif authority and not is_over:
		var around := PackedVector3Array()
		for fish in players:
			if is_up(fish):
				around.append(fish.global_position)
		director.elapsed = stage_time()
		director.players = maxi(around.size(), 1)
		director.hushed = timeline.hushed(stage_time())
		director.escalation = (settings.enrage_scale if enraged else 1.0) * horde_scale()
		director.cleared = cleared_at >= 0.0
		director.stage_scale = 1.0 + settings.stage_alive * (stage - 1)
		director.elite_bonus = settings.stage_elite_chance * (stage - 1)
		director.elite_scale = 1.0 + settings.shrine_deep_elites * deep
		director.update(delta, around)
		horde.difficulty = difficulty()
		_relocate_strays(delta)
	for fish: FishController in _chill.keys():
		_chill[fish] = _chill[fish] - delta
		if _chill[fish] <= 0.0:
			_chill.erase(fish)
	_crowd_left -= delta
	var count_crowd := _crowd_left <= 0.0
	if count_crowd:
		_crowd_left = CROWD_EVERY
	for fish in local_players():
		var health: FishHealth = _health.get(fish)
		if health == null:
			continue
		_pull_camera(fish, delta, count_crowd)
		_keep_in_arena(fish, delta)
		health.update(delta, settings.regen + block_of(fish).value("regen"))
		if is_picking(fish):
			health.shield(0.2)  # D3: untouchable while choosing
		fish.set_model_visible(health.down or health.iframes_left <= 0.0 or fmod(health.iframes_left * FLICKER_RATE, 1.0) < 0.5)
		var stats := stats_of(fish)
		stats.top_speed = maxf(stats.top_speed, fish.speed)
		var attack := _make_attack(fish)
		if _attack_levels.get(fish, -1) != loadout_of(fish).level(Weapons.ATTACK):
			_apply_stats(fish)  # the attack's level override, live
		attack.update(delta, is_up(fish) and not is_over and not is_quiet(fish))
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
		_try_whirlpool(fish)
		_try_shrine(fish)
		_batter_zombies(fish)
		if not tank or settings.tank_contact:
			_touch_zombies(fish)
			_touch_clouds(fish)
	_sync_pearls()


## How much further back `fish`'s survivor cam sits now (m), for the crowd
## round it and its Size stat (camera_crowd_pull, camera_size_pull).
func camera_pull_of(fish: FishController) -> float:
	return _camera_pull.get(fish, 0.0)


## Eases `fish`'s camera pull toward what the crowd (counted again when
## `count`) and its Size ask for.
func _pull_camera(fish: FishController, delta: float, count: bool) -> void:
	if count:
		_crowd[fish] = horde.query_sphere(fish.global_position, settings.camera_crowd_range).size() if settings.camera_crowd_pull > 0.0 else 0
	var crowd := clampf(float(_crowd.get(fish, 0)) / maxf(settings.camera_crowd_full, 1.0), 0.0, 1.0)
	var goal := settings.camera_crowd_pull * crowd + settings.camera_size_pull * maxf(block_of(fish).value("size"), 0.0)
	var now: float = _camera_pull.get(fish, 0.0)
	_camera_pull[fish] = lerpf(now, goal, 1.0 - exp(-settings.camera_pull_rate * delta))


## How many more zombies the players' curses call (Siren's Song): 1 without.
func horde_scale() -> float:
	var scale := 1.0
	for fish: FishController in _powerups:
		if is_instance_valid(fish):
			scale *= (_powerups[fish] as Powerups).horde_scale()
	return scale


## The difficulty level zombies spawn at now: difficulty_per_minute a minute
## into the stage, plus stage_difficulty for each stage before this one (P5).
func difficulty() -> float:
	return maxf(stage_time() / 60.0 * settings.difficulty_per_minute, 0.0) + settings.stage_difficulty * (stage - 1)


## Seconds into this stage (P5; the whole run's `elapsed` in its first).
func stage_time() -> float:
	return maxf(elapsed - stage_started, 0.0)


## Whether this is the run's last stage (its whirlpool wins), by run_length.
func is_last_stage() -> bool:
	var stages := settings.stages_in_run()
	return stages > 0 and stage >= stages


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
			chaseable[i] = 1 if is_up(fish) and not is_over and not is_picking(fish) and not is_quiet(fish) else 0
	var pull := PackedFloat32Array()
	pull.resize(players.size())
	pull.fill(1.0)
	for k in range(decoys.size() - 1, -1, -1):
		if not is_instance_valid(decoys[k]):
			decoys.remove_at(k)
	for decoy in decoys:
		at.append(decoy.global_position)
		moving.append(Vector3.ZERO)
		chaseable.append(0 if is_over else 1)
		pull.append(decoy.get("pull"))
	horde.targets = at
	horde.target_velocities = moving
	horde.chaseable = chaseable
	horde.target_pull = pull


## Hurts zombie `index` by `amount` from `source`, credited to `by`: every
## damage source comes through here, and `by`'s powerups hear of it. `proc` is
## the hit's proc coefficient (1 for an attack or battery); `chain` lists the
## powerups that led to it, which it can't start again.
func hit(index: int, amount: float, by: FishController, source: String, push := Vector3.ZERO, proc := 1.0, chain: Array = []) -> void:
	_enter_hit()
	_hit(index, amount, by, source, push, proc, chain)
	_leave_hit(1)


## The hit path's timing (hit_usec): only the outermost call counts the clock.
static func _enter_hit() -> void:
	if _hit_depth == 0:
		_hit_started = Time.get_ticks_usec()
	_hit_depth += 1


static func _leave_hit(zombies: int) -> void:
	_hit_depth -= 1
	hits_counted += zombies
	if _hit_depth == 0:
		hit_usec += Time.get_ticks_usec() - _hit_started


func _hit(index: int, amount: float, by: FishController, source: String, push: Vector3, proc: float, chain: Array) -> void:
	if not horde.is_alive(index):
		return
	last_hit_crit = false
	if by:
		var block := block_of(by)
		amount *= 1.0 + block.value("damage")
		var twist: Traversal = _twists.get(by)
		if twist:
			amount *= twist.damage_factor(source)
		var powerups: Powerups = _powerups.get(by)
		if powerups:
			amount *= powerups.damage_scale() * (1.0 + powerups.bonus_on(index))  # Momentum Fin, Sonar Pinger's marks
		var stats := stats_of(by)
		if block.value("crit_chance") > 0.0 and rng.randf() < block.value("crit_chance"):
			amount *= 1.5 + block.value("crit_damage")
			stats.crits += 1
			last_hit_crit = true
			# Megalodon Tooth: a crit that leaves it under the share finishes it (not a boss).
			var execute := powerups.execute_share() if powerups else 0.0
			if execute > 0.0 and not boss_at(index) and horde.enemy_hp(index) - amount < horde.enemy_max_hp(index) * execute:
				amount = maxf(amount, horde.enemy_hp(index) + 1.0)
		push *= 1.0 + block.value("knockback")
		stats.damage += amount
		stats.by_source[source] = stats.by_source.get(source, 0.0) + amount
	if tank:
		tank.log_hit(source, amount)
	var boss := boss_at(index)
	last_hit_dealt = amount if horde.is_immortal(index) and not boss else minf(amount, boss.hp if boss else horde.enemy_hp(index))
	if boss:
		boss.take_part(index, amount, by, source)
	else:
		horde.damage(index, amount, source, by, push)
	zombie_hit.emit(index, amount, by, source, chain)
	if not authority and by and not by.puppet:
		hit_claimed.emit(horde.net_id_of(index), amount, source, by)
	if by and _powerups.has(by):
		(_powerups[by] as Powerups).on_hit(index, amount, source, proc, chain)


## Hurts every zombie in `targets` by `amount` from `source` at once (an area
## hit: a blast, a tick of fire, a lightning chain), credited to `by` (the perf
## pass). Each is hurt as hit() would (its own crit roll, marks, Megalodon
## Tooth, the same signals), but the player's numbers are worked out once, the
## stats written once, and the powerups hear only AREA_PROC_ROLLS of them, each
## with the proc coefficient times targets / AREA_PROC_ROLLS: as many procs on
## average as a hit apiece would start, and past certain each one stronger
## (Powerup.proc_power()). Knockback: `pushes` (one per target), or away from
## `centre` times `push` (centre Vector3.INF, or push 0: none).
func hit_area(targets: PackedInt32Array, amount: float, by: FishController, source: String, centre := Vector3.INF, push := 1.0,
		proc := 1.0, chain: Array = [], pushes := PackedVector3Array()) -> void:
	_enter_hit()
	if batch_hits:
		_hit_area(targets, amount, by, source, centre, push, proc, chain, pushes)
	else:
		for n in targets.size():
			var shove := pushes[n] if n < pushes.size() else Vector3.ZERO
			if pushes.is_empty() and centre != Vector3.INF and push != 0.0 and horde.is_alive(targets[n]):
				var away := horde.enemy_position(targets[n]) - centre
				shove = (away.normalized() if away.length_squared() > 0.0001 else Vector3.UP) * push
			_hit(targets[n], amount, by, source, shove, proc, chain)
	_leave_hit(targets.size())


func _hit_area(targets: PackedInt32Array, amount: float, by: FishController, source: String, centre: Vector3, push: float,
		proc: float, chain: Array, pushes: PackedVector3Array) -> void:
	var alive := PackedInt32Array()
	var own_pushes := not pushes.is_empty()
	var kept_pushes := PackedVector3Array()
	for n in targets.size():
		if horde.is_alive(targets[n]):
			alive.append(targets[n])
			if own_pushes:
				kept_pushes.append(pushes[n] if n < pushes.size() else Vector3.ZERO)
	if alive.is_empty():
		return
	var scale := 1.0
	var crit_chance := 0.0
	var crit_scale := 1.5
	var knock := 1.0
	var execute := 0.0
	var block: StatBlock = null
	var powerups: Powerups = _powerups.get(by) if by else null
	var stats: Dictionary = {}
	if by:
		block = block_of(by)
		scale *= 1.0 + block.value("damage")
		var twist: Traversal = _twists.get(by)
		if twist:
			scale *= twist.damage_factor(source)
		if powerups:
			scale *= powerups.damage_scale()
			execute = powerups.execute_share()
		crit_chance = block.value("crit_chance")
		crit_scale = 1.5 + block.value("crit_damage")
		knock = 1.0 + block.value("knockback")
		stats = stats_of(by)
	var claim := not authority and by and not by.puppet
	var total := 0.0
	var crits := 0
	for n in alive.size():
		var index := alive[n]
		if not horde.is_alive(index):
			continue  # killed by an earlier one's knock-on (a burst cloud, a powerup)
		var dealt := amount * scale
		if powerups:
			dealt *= 1.0 + powerups.bonus_on(index)  # Sonar Pinger's marks
		last_hit_crit = false
		var boss := boss_at(index)
		if crit_chance > 0.0 and rng.randf() < crit_chance:
			dealt *= crit_scale
			crits += 1
			last_hit_crit = true
			if execute > 0.0 and not boss and horde.enemy_hp(index) - dealt < horde.enemy_max_hp(index) * execute:
				dealt = maxf(dealt, horde.enemy_hp(index) + 1.0)
		total += dealt
		if tank:
			tank.log_hit(source, dealt)
		var shove := Vector3.ZERO
		if own_pushes:
			shove = kept_pushes[n] * knock
		elif push != 0.0 and centre != Vector3.INF:
			var away := horde.enemy_position(index) - centre
			shove = (away.normalized() if away.length_squared() > 0.0001 else Vector3.UP) * push * knock
		last_hit_dealt = dealt if horde.is_immortal(index) and not boss else minf(dealt, boss.hp if boss else horde.enemy_hp(index))
		if boss:
			boss.take_part(index, dealt, by, source)
		else:
			horde.damage(index, dealt, source, by, shove)
		zombie_hit.emit(index, dealt, by, source, chain)
		if claim:
			hit_claimed.emit(horde.net_id_of(index), dealt, source, by)
	if by:
		stats.damage += total
		stats.by_source[source] = stats.by_source.get(source, 0.0) + total
		stats.crits += crits
	# The powerups hear a few, each standing for its share of the rest.
	if powerups and powerups.hears_hits():
		var rolls := mini(alive.size(), AREA_PROC_ROLLS)
		var each := proc * float(alive.size()) / rolls
		for n in rolls:
			powerups.on_hit(alive[n], amount * scale, source, each, chain)


## A guest's hit on zombie `index`, claimed to us (the host): its damage
## (their stats already in it), credited to their puppet `by`.
func apply_claimed_hit(index: int, amount: float, by: FishController, source: String) -> void:
	if not horde.is_alive(index) or amount <= 0.0:
		return
	last_hit_crit = false
	if by:
		var stats := stats_of(by)
		stats.damage += amount
		stats.by_source[source] = stats.by_source.get(source, 0.0) + amount
	var boss := boss_at(index)
	last_hit_dealt = amount if horde.is_immortal(index) and not boss else minf(amount, boss.hp if boss else horde.enemy_hp(index))
	if boss:
		boss.take_part(index, amount, by, source)
	else:
		horde.damage(index, amount, source, by)
	zombie_hit.emit(index, amount, by, source, [])


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
		hit(i, damage, fish, "battery", nose * maxf(fish.speed / maxf(fish.nature_batter_speed, 0.1), 1.0))  # faster rams knock harder
		powerups_of(fish).on_battery(i)


## A zombie touching `fish` (not one it's battering, or swimming into: rammed()) hurts it, then i-frames.
func _touch_zombies(fish: FishController) -> void:
	var health: FishHealth = _health[fish]
	if health.iframes_left > 0.0 or settings.enemy_damage_scale <= 0.0:
		return
	var frozen := horde.is_frozen()  # the Hourglass: the frozen don't bite (bosses still do)
	var at := fish.global_position
	var battering := fish.speed >= fish.nature_batter_speed
	var nose := -fish.global_basis.z
	for i in horde.query_sphere(at, PLAYER_RADIUS):
		var offset := horde.enemy_position(i) - at
		if battering and offset.length_squared() > 0.0001 and offset.normalized().dot(nose) >= Battery.FRONT:
			continue  # it's being battered, not biting
		if rammed(fish, i):
			continue  # we swam into it: our charge, not its bite
		var kind := horde.enemy_kind(i)
		var amount := kind.contact_damage * settings.enemy_damage_scale * (2.0 if horde.is_elite(i) else 1.0) * horde.damage_scale(i) \
				* stage_damage()
		var boss := boss_at(i)
		if boss:
			amount = boss.contact()
		elif frozen:
			continue
		if not hurt(fish, amount, i):
			return
		if horde.affix_of(i) == Horde.Affix.FROZEN and settings.frozen_time > 0.0:
			_chill[fish] = settings.frozen_time  # its touch slows (P5)
			fish.speed_scale = _swim_scale(fish)
		var away := offset.normalized() if offset.length_squared() > 0.0001 else -nose
		horde.damage(i, 0.0, "contact", null, away)  # knocked back off the fish
		return


## Whether `fish` is swimming into zombie `index` rather than being bitten by
## it (safe_ramming): it's within safe_ram_cone of the way the fish swims and
## the fish is the faster of the two, say mid-stride with accelerate let go;
## or, with the bow wave up, it's anywhere ahead of the fish's middle while
## the fish swims forward. A boss's body always bites.
func rammed(fish: FishController, index: int) -> bool:
	if not settings.safe_ramming or boss_at(index):
		return false
	var velocity := fish.swim_velocity()
	var speed := velocity.length()
	var offset := horde.enemy_position(index) - fish.global_position
	if speed < 0.5 or offset.length_squared() < 0.0001:
		return false
	var toward := offset.normalized()
	var nose := -fish.global_basis.z
	if fish.bow_amount > 0.0 and toward.dot(nose) > 0.0 and velocity.dot(nose) > 0.5:
		return true
	if toward.dot(velocity / speed) < cos(deg_to_rad(settings.safe_ram_cone)):
		return false
	return speed > horde.enemy_velocity(index).length()


## A boxfish's burst cloud `fish` is in hurts it.
func _touch_clouds(fish: FishController) -> void:
	for cloud in _clouds:
		if is_instance_valid(cloud) and cloud.contains(fish.global_position, PLAYER_RADIUS):
			if cloud.slows:
				_chill[fish] = maxf(_chill.get(fish, 0.0), 1.2)  # slime: it slows as well as stings
				fish.speed_scale = _swim_scale(fish)
			var amount := settings.burst_damage if cloud.damage < 0.0 else cloud.damage
			hurt(fish, amount * settings.enemy_damage_scale * stage_damage(), -1, cloud.cause)
			return


## Zombies' contact damage times this for the stage (P5: stage_damage_scale per stage after the first).
func stage_damage() -> float:
	return pow(settings.stage_damage_scale, stage - 1)


## `fish` takes `amount` (unless in i-frames), then i-frames. Returns whether
## it hurt. `from`: the zombie whose touch it was (-1: something else), for
## powerups that answer it (Pufferfish Spines). A powerup may take the hit
## instead (Bubble Wrap): then it's i-frames, and no hurt. `cause`: what it
## was, for the run log (a zombie's touch names its kind).
func hurt(fish: FishController, amount: float, from := -1, cause := "") -> bool:
	if amount <= 0.0 or (tank and not settings.tank_contact):
		return false  # the Test Tank's unhurt practice (its bosses' bolts and holds too)
	var twist: Traversal = _twists.get(fish)
	if twist:
		amount *= twist.taken_factor()
	var powerups: Powerups = _powerups.get(fish)
	if powerups:
		amount *= powerups.taken_scale()  # Blood Moon Shard
	amount = maxf(amount - block_of(fish).value("armour"), 1.0)
	var health: FishHealth = _health.get(fish)
	if health == null or health.down or health.iframes_left > 0.0:
		return false
	if powerups and powerups.blocks_hit(amount):
		health.shield(settings.iframes)
		stats_of(fish)["blocked"] = stats_of(fish).get("blocked", 0) + 1
		return false
	if not health.take(amount, settings.iframes + (twist.iframe_bonus() if twist else 0.0), settings.god_mode):
		return false
	if powerups:
		powerups.on_hurt(amount, from)
	if twist:
		twist.on_hurt()
	stats_of(fish).taken += amount
	if run_log:
		run_log.hurt_by(fish, cause if cause != "" else _cause_of(from))
	director.on_damage(amount / maxf(health.max_hp, 1.0))
	player_hurt.emit(fish, amount)
	if health.down:
		_on_down(fish)
	return true


## What zombie slot `from`'s touch is, for the run log: a boss's title, or the
## kind's name (an elite's marked).
func _cause_of(from: int) -> String:
	if from < 0:
		return "something else"
	var boss := boss_at(from)
	if boss:
		return boss.title.capitalize()
	var kind := horde.enemy_kind(from)
	var name_of := kind.display_name if kind and kind.display_name != "" else (kind.id if kind else "a zombie")
	return ("elite " if horde.is_elite(from) else "") + name_of


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


## A point spawn_distance from `around`, inside the arena: out of every
## player's view, or (murk_spawn_anywhere) anywhere round them, in the murk.
func spawn_point(around: Vector3) -> Vector3:
	var anywhere := settings.murky() and settings.murk_spawn_anywhere
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
		if anywhere:
			break  # the murk hides it
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
	_affix_death(index, at)
	if kill_pops and not horde.is_proxy(index):
		kill_pops.pop(at, horde.enemy_size(index), kind.tint, horde.is_elite(index))
	var fish := by as FishController
	if fish:
		var stats := stats_of(fish)
		stats.kills += 1
		if source == "battery":
			stats.battered += 1
		if _twists.has(fish):
			(_twists[fish] as Traversal).on_kill()
		var own: FishAttack = _attacks.get(fish)
		if is_instance_valid(own):
			own.on_kill(at, source)
		if _powerups.has(fish):
			(_powerups[fish] as Powerups).on_kill(at, source)
	if tank:
		zombie_killed.emit(at, kind, fish, source)
		return  # no XP in the Test Tank: the level is the panel's
	var elite := horde.is_elite(index)
	credit_xp(kind.xp * (ELITE_XP if elite else 1.0), fish)
	if authority:
		_roll_pearl(at, fish, elite, horde.net_id_of(index))
		if source != LIGHTNING_SOURCE:  # a bolt's kills drop no chests or drops (no chain of bolts)
			if _rolls_chest(fish, elite, horde.affix_of(index) != Horde.Affix.NONE):
				drop_chest(at)
			_roll_drop(at, fish, elite)
	zombie_killed.emit(at, kind, fish, source)


## A kill's `xp` for the team, earned by `by` (D22: no pickup), with their XP
## Gain. It counts where the killer is played: offline or the host's own
## players, straight to the team's level; a guest's own players, claimed to
## the host (xp_claimed). A remote player's kill is skipped (their own machine
## claims it); nobody's kill counts on the host, without a gain.
func credit_xp(xp: float, by: FishController) -> void:
	if xp <= 0.0:
		return
	if is_instance_valid(by) and by.puppet:
		return  # their own machine claims it (or, on a guest, the host has it)
	var gain := 1.0 + (block_of(by).value("xp_gain") if is_instance_valid(by) else 0.0)
	if authority:
		levels.add(xp * gain)
	elif is_instance_valid(by):
		xp_claimed.emit(xp * gain)


## Maybe a pearl where `by`'s kill was (the host rolls, D23): an elite's by
## pearl_elite_chance (worth pearl_elite_value), anyone else's by pearl_drop_chance, x (1 +
## the killer's Pearl Chance). `id`: the zombie's net id (every machine's
## pearl the same).
func _roll_pearl(at: Vector3, by: FishController, elite: bool, id: int) -> void:
	var chance := (settings.pearl_elite_chance if elite else settings.pearl_drop_chance) * (1.0 + pearl_chance_of(by))
	if chance > 0.0 and rng.randf() < chance:
		drop_pearl(at, settings.pearl_elite_value if elite else 1, id)


## The boss whose body zombie slot `index` is (null: an ordinary zombie).
func boss_at(index: int) -> Boss:
	if bosses.is_empty() or not horde.is_proxy(index):
		return null
	for boss in bosses:
		if is_instance_valid(boss) and boss.owns(index):
			return boss
	return null


## A stage event starts (StageTimeline): a swarm or a boss. A swarm (the ring,
## stampede, tide) lasts swarm_event_time, its first wave now and the rest in
## _update_swarm().
func _start_event(event: String) -> void:
	stage_event.emit(event)
	for fish in local_players():
		if _powerups.has(fish):
			(_powerups[fish] as Powerups).on_stage_event(event)
	if event in SWARM_EVENTS:
		swarm = {"id": event, "left": settings.swarm_event_time, "next": settings.swarm_wave_every, "wave": 0}
	if not authority:
		return  # the host makes it happen; its zombies and bosses come over the network
	var around := PackedVector3Array()
	for fish in players:
		if is_up(fish):
			around.append(fish.global_position)
	if around.is_empty():
		return
	var crowd := (1.0 + settings.coop_scale * maxi(around.size() - 1, 0)) * pow(settings.stage_hp_scale, stage - 1)  # bosses grow by stage too
	match event:
		"ring", "stampede", "tide":
			_swarm_wave(event, 0, around)
		"miniboss":
			_add_boss(DrownedShark.new(), spawn_point(around[0]), settings.shark_hp * crowd)
		"boss":
			_clean_up(around)
			_add_boss(make_final_boss(pick_final_boss()), spawn_point(around[0]), settings.leviathan_hp * crowd)


## Swarm event `event`'s wave `wave` round the players up (`around`): each
## swarm_wave_ramp bigger than the first. A ring closes round each player; a
## bait ball charges from a fresh side; a wall comes from a fresh side.
func _swarm_wave(event: String, wave: int, around: PackedVector3Array) -> void:
	var crowd := (1.0 + settings.coop_scale * maxi(around.size() - 1, 0)) * (1.0 + settings.swarm_wave_ramp * wave)
	var p := around[rng.randi_range(0, around.size() - 1)]
	var from := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
	match event:
		"ring":
			for at in around:
				_ring(at, roundi(settings.ring_count * crowd / around.size()), settings.ring_radius)
		"stampede":
			horde.spawn_pack(0, roundi(settings.stampede_count * crowd), p + from * 45.0, 6.0, -from, 0.0)
		"tide":
			var across := Vector3.UP.cross(from)
			var count := roundi(settings.tide_count * crowd)
			for n in count:
				var along := (float(n) / maxf(count - 1, 1) - 0.5) * 70.0
				var at := p + from * 40.0 + across * along + Vector3.UP * rng.randf_range(-5.0, 5.0)
				horde.spawn(director.pick_kind(), at, -from, rng.randf() < director.elite_chance())


## The swarm event on (if any): its time left, and its next wave when due (the host's).
func _update_swarm(delta: float) -> void:
	if swarm.is_empty():
		return
	swarm.left -= delta
	if swarm.left <= 0.0:
		swarm = {}
		director.quiet(settings.quiet_moment)  # a quiet moment after it (P5)
		return
	swarm.next -= delta
	if swarm.next > 0.0:
		return
	swarm.next += settings.swarm_wave_every
	swarm.wave += 1
	if not authority:
		return
	var around := PackedVector3Array()
	for fish in players:
		if is_up(fish):
			around.append(fish.global_position)
	if not around.is_empty():
		_swarm_wave(swarm.id, swarm.wave, around)


## Seconds left of the swarm event on (0: none).
func swarm_left() -> float:
	return maxf(swarm.get("left", 0.0), 0.0)


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


## Which final boss comes this stage ("boss": the King of Herrings, or an
## alternate by alternate_boss_chance; final_boss picks one for testing).
func pick_final_boss() -> String:
	var picked := ["", "boss", "gulper", "whale", "lamprey"]
	if settings.final_boss > 0 and settings.final_boss < picked.size():
		return picked[settings.final_boss]
	if rng.randf() < settings.alternate_boss_chance:
		return ["gulper", "whale", "lamprey"][rng.randi_range(0, 2)]
	return "boss"


## A final boss of `kind` ("boss" or "king": the King of Herrings; "gulper",
## "whale", "lamprey": its alternates), not yet added.
static func make_final_boss(kind: String) -> BloodLeviathan:
	match kind:
		"gulper":
			return GulperBoss.new()
		"whale":
			return WhaleFallBoss.new()
		"lamprey":
			return LampreyBoss.new()
	return BloodLeviathan.new()


## A guest's puppet of the host's boss `id` (`kind`: "miniboss", "boss"), its
## body the host's proxies `part_ids`.
func add_puppet_boss(kind: String, id: int, part_ids: PackedInt32Array, boss_hp: float, boss_max: float, at: Vector3) -> Boss:
	var boss: Boss = DrownedShark.new() if kind == "miniboss" else make_final_boss(kind)
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
	if tank:
		tank.boss_beaten(boss)  # no loot or whirlpool there: it comes back instead
		return
	if boss is DrownedShark:
		# On every machine (each sees the boss beaten), so not sent as a drop.
		var chest := add_chest(boss.global_position, 0.0, centre.y + settings.arena_floor - TreasureChest.SIZE.y * 0.3,
				TreasureChest.Kind.BOSS)  # a legendary pick (the dash is the Shark's own skill now)
		chest.name = "SharkChest"
		director.quiet(settings.quiet_moment)
		_deep_chests(boss.global_position)
		if authority:
			levels.add(settings.shark_xp)
		# Its pearls, the same on every machine (each sees the boss beaten).
		for n in settings.boss_pearls:
			var spill := Vector3(sin(n * 2.4), 0.3 * sin(n * 1.3), cos(n * 2.4)) * BOSS_PEARL_SPREAD * sqrt((n + 1.0) / maxf(settings.boss_pearls, 1.0))
			drop_pearl(boss.global_position + spill, 1, BOSS_PEARL - boss.boss_id * 1000 - n, false)
	elif boss is BloodLeviathan:
		# The run goes on: swim, batter and loot as long as you like. Entering the whirlpool wins.
		_open_whirlpool(boss.global_position)
		# And its loot: the Coil, in a chest beside the whirlpool (on every machine, like the shark's).
		var loot := add_chest(boss.global_position + Vector3(9.0, 0.0, 0.0), 0.0, centre.y + settings.arena_floor - TreasureChest.SIZE.y * 0.3,
				TreasureChest.Kind.BOSS, "attack_leviathans_coil")
		loot.name = "LeviathanChest"
		_deep_chests(boss.global_position)


## The Shrine of the Deep's reward (P5): shrine_deep_chests more boss chests
## (legendary picks) round a beaten boss for each Deep set off this stage (on
## every machine, like the boss's own).
func _deep_chests(at: Vector3) -> void:
	var count := deep * settings.shrine_deep_chests
	for n in count:
		var spot := at + Vector3(cos(TAU * n / maxf(count, 1)), 0.0, sin(TAU * n / maxf(count, 1))) * 6.0
		var chest := add_chest(spot, 0.0, centre.y + settings.arena_floor - TreasureChest.SIZE.y * 0.3, TreasureChest.Kind.BOSS)
		chest.name = "DeepChest"


## Opens the way out at `at` (on every machine: each sees the boss beaten).
func _open_whirlpool(at: Vector3) -> void:
	if is_instance_valid(whirlpool):
		return
	cleared_at = elapsed
	whirlpool = Whirlpool.new()
	whirlpool.height = settings.arena_ceiling - settings.arena_floor
	whirlpool.position = Vector3(at.x, settings.arena_floor, at.z)  # a column, seabed to surface
	add_child(whirlpool)
	whirlpool_opened.emit(at)


## Whether `fish` is close enough to the whirlpool to enter it.
func near_whirlpool(fish: FishController) -> bool:
	if not (is_instance_valid(whirlpool) and is_instance_valid(fish)) or is_over or not is_up(fish):
		return false
	var offset := fish.global_position - whirlpool.global_position  # the column runs the whole height
	return Vector2(offset.x, offset.z).length() <= settings.whirlpool_range


## `fish` enters the whirlpool: on the run's last stage (is_last_stage()) the
## stage is complete and the run is won; otherwise everyone goes on to the next
## stage (P5). Online, the host's call (whirlpool_entered tells the guests,
## whose own copies then do the same).
func enter_whirlpool(fish: FishController) -> void:
	if is_over or not is_instance_valid(whirlpool):
		return
	if not is_last_stage():
		whirlpool_entered.emit(fish)
		next_stage()
		return
	stage_complete = true
	is_over = true
	_hold_for_cards(false)
	whirlpool_entered.emit(fish)
	stage_completed.emit()


## Each local player within range presses Jump/interact to enter the whirlpool
## (a guest asks the host, who completes it for everyone).
func _try_whirlpool(fish: FishController) -> void:
	if not near_whirlpool(fish) or is_picking(fish):
		return
	var input: PlayerInput = fish.input_source if fish.input_source else PlayerInput.everyone()
	if not input.just_pressed("jump"):
		return
	if authority:
		enter_whirlpool(fish)
	else:
		whirlpool_claimed.emit(fish)


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
	Sfx.play_at("fx/burst_cloud", at)


## A pearl worth `value` at `at` (past max_pearls, the nearest takes its worth
## instead, and grows). A guest's drops merge the same way as the host's: the
## pearls out are the same on both, and so is the pick. `announce`: the
## host's own roll, sent to the guests (pearl_dropped).
func drop_pearl(at: Vector3, value: int, id := -1, announce := true) -> void:
	if value <= 0:
		return
	if announce and authority:
		pearl_dropped.emit(id, at, value)
	if run_log:
		run_log.pearls_dropped += value
	if pearls_out.size() >= settings.max_pearls:
		var nearest := _nearest_pearl(at)
		if nearest:
			nearest.value += value
			nearest.bulk = clampf(pow(nearest.value / maxf(nearest.get_meta("first_value", 1.0), 0.01), 1.0 / 3.0), 1.0, 3.0)
			return
	_sync_pearls()
	var pearl := Pearl.new(_pearl_settings)
	pearl.name = "Pearl"
	pearl.value = value
	pearl.id = id
	pearl.set_meta("first_value", value)
	pearl.collectors.assign(local_players())  # online, each machine's own players pick up
	pearl.position = at
	add_child(pearl)
	pearl.set_light(settings.pearl_lights)
	pearl.reset_physics_interpolation()
	pearl.collected.connect(_on_pearl_collected)
	pearl.tree_exiting.connect(func() -> void: pearls_out.erase(pearl))
	pearls_out.append(pearl)


## A local player took a pearl: its worth goes in their purse at once (a guest
## tells the host, so every copy goes).
func _on_pearl_collected(pearl: Pearl, by: FishController) -> void:
	var worth := roundi(pearl.value)
	if is_instance_valid(by):
		stats_of(by).pearls += worth
		add_pearls(by, worth)
		pearl_collected.emit(by)
	if authority:
		pearl_taken.emit(pearl.id)
	else:
		pearl_claimed.emit(pearl.id, by)


## The pearl out nearest `at` that isn't being taken (null: none).
func _nearest_pearl(at: Vector3) -> Pearl:
	var best: Pearl = null
	var gap := INF
	for pearl in pearls_out:
		if is_instance_valid(pearl) and pearl.absorbing == null:
			var d := pearl.global_position.distance_squared_to(at)
			if d < gap:
				gap = d
				best = pearl
	return best


## The pearl `id` here, if it's still out.
func pearl_by_id(id: int) -> Pearl:
	if id < 0:
		return null
	for pearl in pearls_out:
		if is_instance_valid(pearl) and pearl.id == id:
			return pearl
	return null


## A guest's pearl claim (we're the host): it goes from everyone's sea, and
## counts on their board once; returns whether it counted. (The guest's purse
## took it already, on their machine.)
func confirm_pearl(id: int, by: FishController) -> bool:
	var pearl := pearl_by_id(id)
	if pearl == null:
		return false  # gone already (someone else got it)
	pearl.queue_free()
	if is_instance_valid(by):
		stats_of(by).pearls += roundi(pearl.value)
	pearl_taken.emit(id)
	return true


## A guest's XP claim (we're the host): to the team's level.
func confirm_xp(xp: float) -> void:
	if authority and xp > 0.0:
		levels.add(xp)


## The pearls' look and pull from UnnaturalSettings.
func _sync_pearls() -> void:
	var reach := 0.0
	for key: Variant in _blocks:
		reach = maxf(reach, (_blocks[key] as StatBlock).value("pickup_range"))
	_pearl_settings.magnet_radius = settings.pickup_range * (1.0 + reach)
	_pearl_settings.magnet_strength = settings.pickup_pull
	_pearl_settings.pearl_lifetime = INF  # Unnatural's never fade
	_pearl_settings.pearl_size = settings.pearl_size
	_pearl_settings.absorb_radius = 1.2


## Everyone's max hp rises with the team's level, healing by as much; each
## gets their signature stat, and each local player a pick of cards.
func _on_leveled_up(level: int) -> void:
	for fish: FishController in _health:
		if not is_instance_valid(fish):
			continue
		var signature := StatBlock.signature(fish.character)
		block_of(fish).add(signature, StatBlock.signature_amount(fish.character, settings.signature_steps, settings))
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
	if not (_chest_pending.get(fish, []) as Array).is_empty():
		_offer_chest(fish)
	elif _pending.get(fish, 0) > 0:
		_offer_level(fish)
	else:
		_pending.erase(fish)
		_chest_pending.erase(fish)
		if _offers.is_empty():
			_hold_for_cards(false)


## card_choices different cards (CardDeck): weapon and tome upgrades, new ones
## while slots are free, each with its own rarity.
func _offer_level(fish: FishController) -> void:
	var left: int = _pending.get(fish, 0)
	var cards := CardDeck.deal(self, fish, settings.card_choices)
	if cards.is_empty():
		_pending[fish] = 0
		_offer_next(fish)
		return
	_offers[fish] = cards
	_offer_kind[fish] = "level"
	_level_extra[fish] = powerups_of(fish).extra_level_picks()
	var signature := StatBlock.signature(fish.character)
	var gave := "MAX HP +%d  ·  %s (SIGNATURE)  ·  %s" % [roundi(settings.hp_per_level),
			StatBlock.describe(signature, StatBlock.signature_amount(fish.character, settings.signature_steps, settings)).to_upper(), CardDeck.slot_line(self, fish)]
	if cards_pause_game():
		_hold_for_cards(true)
	cards_offered.emit(fish, cards, "LEVEL %d" % (levels.level - left + 1), gave)


## `fish`'s next chest's pick. A treasure chest rolls a rarity with the
## opener's luck and offers chest_choices powerups of it (filling up from the
## tiers below); a cursed chest offers cursed powerups (luck doesn't help); a
## boss chest offers its boss's own. Sunken Idol: one more pick from the same
## chest a stack.
func _offer_chest(fish: FishController) -> void:
	var queue: Array = _chest_pending.get(fish, [])
	var spec: Array = queue.pop_front() if not queue.is_empty() else [TreasureChest.Kind.TREASURE, ""]
	var chest: TreasureChest = spec[2] if spec.size() > 2 else null
	var price: int = spec[3] if spec.size() > 3 else 0
	var rolled_before: Dictionary = (_chest_rolls.get(chest, {}) as Dictionary).get(fish, {}) if chest else {}
	var cards := []
	var heading := ""
	var line := "PICK A POWERUP  ·  THE SAME ONE AGAIN STACKS"
	if not rolled_before.is_empty():
		# Put back and opened again: the same cards (their stacks as they are now).
		cards = (rolled_before.cards as Array).duplicate(true)
		for card: Dictionary in cards:
			card.stacks = powerups_of(fish).stacks(card.powerup) + 1
		heading = rolled_before.heading
		line = rolled_before.line
		spec = [-1]  # nothing to roll
	match spec[0]:
		-1:
			pass
		TreasureChest.Kind.CURSED:
			for id in Powerup.pick_from_tier(rng, Rarity.Tier.CURSED, settings.chest_choices, banished_of(fish)):
				cards.append(_powerup_card(fish, id))
			heading = "CURSED TREASURE"
			line = "STRONG, WITH A CATCH  ·  CHOOSE CAREFULLY"
		TreasureChest.Kind.BOSS:
			var item: String = spec[1]
			if item == "":
				for id in Powerup.pick_for_chest(rng, Rarity.Tier.LEGENDARY, settings.chest_choices):
					cards.append(_powerup_card(fish, id))
			elif Powerup.INFO.has(item):
				cards.append(_powerup_card(fish, item))
			heading = "BOSS TREASURE!"
			line = "%s'S PRIZE" % Powerup.title(item).to_upper() if item != "" else "THE SHARK'S PRIZE  ·  A LEGENDARY PICK"
		_:
			var rolled := Rarity.roll(rng, settings, block_of(fish).value("luck"))
			for id in Powerup.pick_for_chest(rng, rolled, settings.chest_choices, banished_of(fish)):
				cards.append(_powerup_card(fish, id))
			heading = "%s TREASURE!" % Rarity.NAMES[rolled]
	if cards.is_empty():
		_offer_next(fish)
		return
	_extra_picks[fish] = mini(powerups_of(fish).stacks("sunken_idol"), cards.size() - 1)
	if chest:
		if not _chest_rolls.has(chest):
			_chest_rolls[chest] = {}
		(_chest_rolls[chest] as Dictionary)[fish] = {"cards": cards.duplicate(true), "heading": heading, "line": line}
		_chest_offer[fish] = {"chest": chest, "price": price, "committed": false}
	if _extra_picks[fish] > 0:
		line = "PICK %d  ·  THE SUNKEN IDOL'S GIFT" % (_extra_picks[fish] + 1)
	_offers[fish] = cards
	_offer_kind[fish] = "chest"
	if cards_pause_game():
		_hold_for_cards(true)
	cards_offered.emit(fish, cards, heading, line)


func _powerup_card(fish: FishController, id: String) -> Dictionary:
	return {"powerup": id, "stacks": powerups_of(fish).stacks(id) + 1, "tier": Powerup.tier(id)}


## `fish` takes card `index` of those up: a level's weapon or tome goes up (or
## comes), or a chest's powerup is theirs (another stack; a boss weapon takes
## a slot, or asks which weapon it replaces); then their next pick, or back to
## play.
func pick(fish: FishController, index: int) -> void:
	var cards: Array = _offers.get(fish, [])
	if cards.is_empty():
		return
	var card: Dictionary = cards[clampi(index, 0, cards.size() - 1)]
	var offer_kind: String = _offer_kind.get(fish, "level")
	if offer_kind == "chest":
		_commit_chest(fish)
	if offer_kind == "swap":
		if card.kind == "swap":
			_take_boss_weapon(fish, card.incoming, card.weapon)
	elif offer_kind == "chest" and Powerup.is_weapon(card.powerup):
		var loadout := loadout_of(fish)
		if loadout.has_weapon(card.powerup) or loadout.weapons.size() < settings.weapon_slots:
			_take_boss_weapon(fish, card.powerup, "")
		else:
			_offer_swap(fish, card.powerup)
			card_picked.emit(fish, card)
			return
	elif offer_kind == "chest":
		powerups_of(fish).add(card.powerup)
		if _extra_picks.get(fish, 0) > 0 and cards.size() > 1:
			# Sunken Idol: another pick from what's left of the same chest.
			_extra_picks[fish] -= 1
			var rest := cards.duplicate()
			rest.remove_at(clampi(index, 0, cards.size() - 1))
			for other: Dictionary in rest:
				other.stacks = powerups_of(fish).stacks(other.powerup) + 1
			_offers[fish] = rest
			card_picked.emit(fish, card)
			cards_offered.emit(fish, rest, "ANOTHER PICK", "THE SUNKEN IDOL'S GIFT")
			return
		_extra_picks.erase(fish)
	else:
		take_card(fish, card)
		if offer_kind == "level" and _level_extra.get(fish, 0) > 0:
			# Moon Pearl: another card from what's left of the same level's offer
			# (a new weapon or tome only while a slot's still free).
			_level_extra[fish] -= 1
			var loadout := loadout_of(fish)
			var rest := []
			for n in cards.size():
				var other: Dictionary = cards[n]
				if n == clampi(index, 0, cards.size() - 1) or other.get("kind", "") == "fallback":
					continue
				if other.kind == "new_weapon" and (loadout.weapons.size() >= settings.weapon_slots or loadout.has_weapon(other.weapon)):
					continue
				if other.kind == "new_tome" and (loadout.tomes.size() >= settings.tome_slots or loadout.has_tome(other.tome)):
					continue
				rest.append(other)
			if not rest.is_empty():
				_offers[fish] = rest
				card_picked.emit(fish, card)
				cards_offered.emit(fish, rest, "ANOTHER PICK", "THE MOON PEARL'S GIFT")
				return
		_level_extra.erase(fish)
		_pending[fish] = _pending.get(fish, 1) - 1
	_offers.erase(fish)
	_offer_kind.erase(fish)
	card_picked.emit(fish, card)
	_offer_next(fish)


## `fish` took a card from its chest: that's final (no more cancelling), and the
## chest can go now.
func _commit_chest(fish: FishController) -> void:
	var info: Dictionary = _chest_offer.get(fish, {})
	if info.is_empty() or info.committed:
		return
	info.committed = true
	_chest_offer.erase(fish)
	if _chest_rolls.has(info.chest):
		(_chest_rolls[info.chest] as Dictionary).erase(fish)
	_clear_chest(info.chest)


## What a level's card does for `fish` (CardDeck's kinds).
func take_card(fish: FishController, card: Dictionary) -> void:
	var loadout := loadout_of(fish)
	match card.get("kind", ""):
		"weapon", "new_weapon":
			var id: String = card.weapon
			if loadout.has_weapon(id):
				loadout.upgrade_weapon(id, card.gains)
			else:
				loadout.add_weapon(id, 1, card.get("gains", {}))
			if id != Weapons.ATTACK:
				powerups_of(fish).refresh()
		"tome", "new_tome":
			loadout.add_tome(card.tome)
			var gives: Dictionary = card.gives
			for stat: String in gives:
				block_of(fish).add(stat, gives[stat])
		"fallback":
			if card.what == "pearls":
				add_pearls(fish, card.amount)
			else:
				for player in local_players():
					var health: FishHealth = _health.get(player)
					if health and not health.down:
						health.heal(health.max_hp * float(card.amount))
	_apply_stats(fish)


## Boss weapon `id` is `fish`'s (at coil_arrive_level), in place of `replacing`
## ("": a free slot, or it's held already: a level up).
func _take_boss_weapon(fish: FishController, id: String, replacing: String) -> void:
	var loadout := loadout_of(fish)
	if loadout.has_weapon(id):
		loadout.upgrade_weapon(id, Weapons.roll(rng, id, loadout.attack_kind, Rarity.Tier.RARE, settings, powerup_settings))
	else:
		if replacing != "":
			loadout.remove_weapon(replacing)
		loadout.add_weapon(id, maxi(powerup_settings.coil_arrive_level, 1))
	powerups_of(fish).refresh()
	_apply_stats(fish)


## Every weapon slot's full: which weapon does boss weapon `incoming` replace?
## Each held one (not the fish's own attack) as a card, and a card to keep them all.
func _offer_swap(fish: FishController, incoming: String) -> void:
	var loadout := loadout_of(fish)
	var cards := []
	for id in loadout.weapons:
		if id != Weapons.ATTACK:
			cards.append({"kind": "swap", "weapon": id, "incoming": incoming, "tier": Powerup.tier(incoming),
					"level": loadout.earned_level(id)})
	cards.append({"kind": "keep", "weapon": incoming, "tier": Rarity.Tier.COMMON})
	_offers[fish] = cards
	_offer_kind[fish] = "swap"
	cards_offered.emit(fish, cards, "%s: NO FREE SLOT" % Powerup.title(incoming).to_upper(), "SWAP A WEAPON FOR IT, OR KEEP YOURS")


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
	# Now and then a cursed one (luck doesn't help).
	var kind := TreasureChest.Kind.CURSED if rng.randf() < settings.cursed_chest_chance else TreasureChest.Kind.TREASURE
	var chest := add_chest(centre + Vector3(spot.x, settings.arena_floor - TreasureChest.SIZE.y * 0.3, spot.y), rng.randf() * TAU,
			-INF, kind)
	chest_buried.emit(chest)


## A chest at `at`, turned `turn` (radians); `sink_to`: a dropped one sinks to
## that height (-INF: it stays put).
func add_chest(at: Vector3, turn: float, sink_to := -INF, kind := TreasureChest.Kind.TREASURE, item := "") -> TreasureChest:
	var chest := TreasureChest.new()
	chest.name = "Chest"
	chest.kind = kind
	chest.item = item
	chest.position = at
	chest.rotation.y = turn
	chest.sink_to = sink_to
	add_child(chest)
	chests.append(chest)
	return chest


## Maybe a drop where `by`'s kill was (the host rolls): a heart, a magnet, an
## hourglass or a lightning bolt, each by its chance (elite: x ELITE_CHEST),
## raised by their luck.
func _roll_drop(at: Vector3, by: FishController, elite := false) -> void:
	if elapsed - _last_drop < settings.drop_gap:
		return  # too soon after the last drop of any kind
	var luck := block_of(by).value("luck") if is_instance_valid(by) and _blocks.has(by) else 0.0
	var lift := maxf(1.0 + luck * settings.chest_drop_luck, 0.0) * (ELITE_CHEST if elite else 1.0)
	var roll := rng.randf()
	var chances := [settings.heart_chance, settings.magnet_chance, settings.hourglass_chance, settings.lightning_chance]
	var waits := [settings.heart_every, settings.magnet_every, settings.hourglass_every, settings.lightning_every]
	for kind in [Pickup.Kind.HEART, Pickup.Kind.MAGNET, Pickup.Kind.HOURGLASS, Pickup.Kind.LIGHTNING]:
		if elapsed - float(_last_drop_of.get(kind, -INF)) < waits[kind]:
			continue  # this kind dropped too recently
		var chance := chances[kind] as float * lift
		if roll < chance:
			_last_drop = elapsed
			_last_drop_of[kind] = elapsed
			drop_pickup(kind, at)
			return
		roll -= chance


## A drop of `kind` at `at` (`id` -1: the next of ours; online, the host's id).
func drop_pickup(kind: int, at: Vector3, id := -1) -> Pickup:
	var pickup := Pickup.new()
	pickup.name = Pickup.NAMES[kind].capitalize()
	pickup.kind = kind as Pickup.Kind
	if id < 0:
		id = _next_pickup_id
	_next_pickup_id = maxi(_next_pickup_id, id + 1)
	pickup.id = id
	pickup.collectors.assign(local_players())
	pickup.position = at
	add_child(pickup)
	pickup.taken.connect(_on_pickup_taken)
	pickup.tree_exiting.connect(func() -> void: pickups.erase(pickup))
	pickups.append(pickup)
	if authority:
		pickup_dropped.emit(pickup)
	return pickup


func pickup_by_id(id: int) -> Pickup:
	for pickup in pickups:
		if is_instance_valid(pickup) and pickup.id == id:
			return pickup
	return null


func _on_pickup_taken(pickup: Pickup, by: FishController) -> void:
	if authority:
		apply_pickup(pickup.kind, by)
		pickup_taken.emit(pickup.id, pickup.kind, by)
	else:
		pickup_claimed.emit(pickup.id, by)  # the host says, then it happens


## A guest's claim on drop `id` (we're the host): the first claim gets it.
func confirm_pickup(id: int, by: FishController) -> bool:
	var pickup := pickup_by_id(id)
	if pickup == null:
		return false
	var kind := pickup.kind
	pickup.vanish()
	apply_pickup(kind, by)
	pickup_taken.emit(id, kind, by)
	return true


## What a drop does, for `by` (on every machine: each heals only its own
## players). A heart heals the whole team (D12): every player who's up.
func apply_pickup(kind: int, by: FishController) -> void:
	if is_instance_valid(by):
		stats_of(by)["drops"] = stats_of(by).get("drops", 0) + 1
	match kind:
		Pickup.Kind.HEART:
			for fish in local_players():
				var health: FishHealth = _health.get(fish)
				if health and not health.down:
					health.heal(health.max_hp * settings.heart_heal)
		Pickup.Kind.MAGNET:
			for pearl in pearls_out:
				if is_instance_valid(pearl):
					pearl.drawn_by = by
		Pickup.Kind.HOURGLASS:
			horde.freeze(settings.hourglass_time)
		Pickup.Kind.LIGHTNING:
			if authority:  # the host kills; guests hear of each kill
				lightning_strike(by)
	drop_taken.emit(kind, by)


## The Lightning Bolt: a shock across the whole arena kills every zombie,
## credited to `by`. Bosses (and their body parts) and undying ones are spared.
## Returns how many died.
func lightning_strike(by: FishController) -> int:
	var struck := 0
	for i in horde.capacity:
		if horde.is_alive(i) and not horde.is_proxy(i) and not horde.is_immortal(i) and boss_at(i) == null:
			horde.kill(i, LIGHTNING_SOURCE, by)
			struck += 1
	return struck


## A chest dropped by a kill at `at`, sinking to the seabed.
func drop_chest(at: Vector3) -> TreasureChest:
	var chest := add_chest(at, rng.randf() * TAU, centre.y + settings.arena_floor - TreasureChest.SIZE.y * 0.3)
	if run_log:
		run_log.chests_dropped += 1
	chest_buried.emit(chest)
	return chest


## The chests still shut for someone.
func shut_chests() -> Array[TreasureChest]:
	var shut: Array[TreasureChest] = []
	for chest in chests:
		if is_instance_valid(chest) and not chest.open_for_all(players):
			shut.append(chest)
	return shut


## The chests `fish` hasn't opened yet.
func shut_chests_for(fish: FishController) -> Array[TreasureChest]:
	var shut: Array[TreasureChest] = []
	for chest in chests:
		if is_instance_valid(chest) and not chest.is_open_for(fish) and not chest.is_queued_for_deletion():
			shut.append(chest)
	return shut


## `fish`'s render layer (TreasureChest.player_layer), if it's played here (0: a puppet).
func layer_of(fish: FishController) -> int:
	if not is_instance_valid(fish) or fish.puppet:
		return 0
	return TreasureChest.player_layer(fish.get_meta("coop_index", maxi(players.find(fish), 0)))


## `fish` opens a chest by battering it, or by holding still beside it for
## chest_open_time (untouchable meanwhile); one more is uncovered now and then.
func _open_chests(fish: FishController, delta: float) -> void:
	if authority and fish == local_players()[0] and not test_tank and settings.chest_interval > 0.0:
		_chest_left -= delta
		if _chest_left <= 0.0:
			# Further apart as the stage goes on (P4).
			_chest_left = settings.chest_interval * (1.0 + (settings.chest_bury_fade * stage_time() / 60.0 if settings.limits else 0.0))
			if shut_chests().size() < settings.chest_max:
				_bury_chest()
	if _offers.has(fish):
		return
	var at := fish.global_position
	var nose := -fish.global_basis.z
	var battering := fish.speed >= fish.nature_batter_speed * powerups_of(fish).batter_speed_share()
	var still := fish.speed <= settings.chest_still_speed
	var holding: TreasureChest = null
	var backed_out: TreasureChest = _backed_out.get(fish)
	for chest in shut_chests_for(fish):
		var middle := chest.global_position + Vector3.UP * TreasureChest.SIZE.y * 0.5
		var offset := middle - at
		var gap := offset.length()
		if gap > settings.chest_reach + GhostBite.bow_reach(fish):
			if chest == backed_out:
				_backed_out.erase(fish)  # swum clear of it: it's fair game again
			continue
		if not can_afford(fish, chest):
			continue  # short of pearls: it stays shut (the HUD shows its price)
		if chest == backed_out:
			continue  # just put back: not by battering through it again
		if battering and gap > 0.001 and offset.normalized().dot(nose) >= Battery.FRONT:
			open_chest(chest, fish)
			return
		if still and gap <= settings.chest_reach and not chest.is_unlocked_for(fish):
			holding = chest
	if holding:
		_opening[fish] = holding
		holding.set_progress(fish, minf(holding.progress_of(fish) + delta / maxf(settings.chest_open_time, 0.01), 1.0))
		if holding.is_unlocked_for(fish):
			_opening.erase(fish)  # free to swim: it waits for a Jump
			chest_unlocked.emit(holding, fish)
	else:
		var was: TreasureChest = _opening.get(fish)
		_opening.erase(fish)
		if is_instance_valid(was) and not was.is_unlocked_for(fish):
			was.set_progress(fish, 0.0)
	var input: PlayerInput = fish.input_source if fish.input_source else PlayerInput.everyone()
	if input.just_pressed("jump"):
		open_unlocked(fish)


## `fish` opens the nearest chest they've unlocked (by holding still beside it)
## and are within reach of, if they can afford it: Jump/interact. Whether it did.
func open_unlocked(fish: FishController) -> bool:
	if _offers.has(fish):
		return false
	var best: TreasureChest = null
	var best_gap := settings.chest_reach + GhostBite.bow_reach(fish)
	for chest in shut_chests_for(fish):
		var gap := (chest.global_position + Vector3.UP * TreasureChest.SIZE.y * 0.5).distance_to(fish.global_position)
		if gap <= best_gap and chest.is_unlocked_for(fish) and can_afford(fish, chest):
			best = chest
			best_gap = gap
	if best == null:
		return false
	open_chest(best, fish)
	return true


## The chest `fish` is within reach of that's unlocked for them and waiting for
## Jump (for the HUD prompt), if any.
func unlocked_chest_near(fish: FishController) -> TreasureChest:
	if not is_instance_valid(fish) or _offers.has(fish) or is_over:
		return null
	for chest in shut_chests_for(fish):
		var gap := (chest.global_position + Vector3.UP * TreasureChest.SIZE.y * 0.5).distance_to(fish.global_position)
		if gap <= settings.chest_reach + GhostBite.bow_reach(fish) and chest.is_unlocked_for(fish) and can_afford(fish, chest):
			return chest
	return null


## Opens `chest` for `fish` (each player opens each chest for themselves): a
## powerup pick for them, and it's gone from their view.
func open_chest(chest: TreasureChest, fish: FishController) -> void:
	var price := chest_price(chest, fish)
	if not chest.open_for(fish, layer_of(fish)):
		return
	add_pearls(fish, -price)
	if price > 0:
		stats_of(fish)["paid_chests"] = stats_of(fish).get("paid_chests", 0) + 1
	_opening.erase(fish)
	_backed_out.erase(fish)
	stats_of(fish)["chests"] = stats_of(fish).get("chests", 0) + 1
	chest_opened.emit(chest, fish)
	if not authority:
		chest_claimed.emit(chests.find(chest), fish)
	if not _chest_pending.has(fish):
		_chest_pending[fish] = []
	(_chest_pending[fish] as Array).append([chest.kind, chest.item, chest, price])
	if not _offers.has(fish):
		_offer_next(fish)
	_clear_chest(chest)  # (not while its pick can still be cancelled)


## Whether `fish` can back out of the chest it's choosing from: before they take
## a card (the Sunken Idol's extra picks and a weapon swap can't), and while
## the chest is still there to put back.
func can_cancel(fish: FishController) -> bool:
	var info: Dictionary = _chest_offer.get(fish, {})
	return not info.is_empty() and _offer_kind.get(fish, "") == "chest" and not info.committed \
			and is_instance_valid(info.chest) and not (info.chest as TreasureChest).is_queued_for_deletion()


## `fish` backs out of the chest: the pearls come back and the chest is shut
## for them again. Their cards stay rolled (_chest_rolls), so opening it
## again offers the same ones: no free rerolls.
func cancel_offer(fish: FishController) -> void:
	if not can_cancel(fish):
		return
	var info: Dictionary = _chest_offer[fish]
	var chest: TreasureChest = info.chest
	chest.reshut_for(fish, layer_of(fish))
	_backed_out[fish] = chest
	add_pearls(fish, info.price)
	var stats := stats_of(fish)
	stats["chests"] = maxi(stats.get("chests", 0) - 1, 0)
	if info.price > 0:
		stats["paid_chests"] = maxi(stats.get("paid_chests", 0) - 1, 0)
	_chest_offer.erase(fish)
	_offers.erase(fish)
	_offer_kind.erase(fish)
	_extra_picks.erase(fish)
	chest_reshut.emit(chest, fish)
	if not authority:
		chest_unclaimed.emit(chests.find(chest), fish)
	offer_cancelled.emit(fish)
	_offer_next(fish)


## `fish`, a player elsewhere (online), put chest `index` back.
func apply_chest_reshut(index: int, fish: FishController) -> void:
	if index < 0 or index >= chests.size() or not is_instance_valid(chests[index]) or fish == null:
		return
	if chests[index].reshut_for(fish, layer_of(fish)):
		var stats := stats_of(fish)
		stats["chests"] = maxi(stats.get("chests", 0) - 1, 0)


## A chest everyone's opened goes, unless someone's still choosing from it
## and may put it back.
func _chest_in_use(chest: TreasureChest) -> bool:
	for info: Dictionary in _chest_offer.values():
		if info.chest == chest and not info.committed:
			return true
	return false


## What `chest` costs to open now, in pearls (D23): chest_price_base, growing
## with the run's minutes (chest_price_growth), and for `fish` with each chest
## they've paid for (chest_price_step each); a cursed one's chest_cursed_price
## times that; a boss's free, and every one free with chest_cost off or in the
## Test Tank.
func chest_price(chest: TreasureChest, fish: FishController = null) -> int:
	if not settings.chest_cost or tank or test_tank or chest.kind == TreasureChest.Kind.BOSS or chest.item == FREE_CHEST:
		return 0
	var price := settings.chest_price_base * (1.0 + settings.chest_price_growth * stage_time() / 60.0)
	if is_instance_valid(fish):
		price *= 1.0 + settings.chest_price_step * float(stats_of(fish).get("paid_chests", 0))
	if chest.kind == TreasureChest.Kind.CURSED:
		price *= settings.chest_cursed_price
	return roundi(price)


## How many more metres `fish` pings chests from (Treasure Map).
func chest_ping_bonus_of(fish: FishController) -> float:
	return (_powerups[fish] as Powerups).chest_ping_bonus() if _powerups.has(fish) else 0.0


## Whether `fish` has the pearls to open `chest`.
func can_afford(fish: FishController, chest: TreasureChest) -> bool:
	return purse_of(fish) >= chest_price(chest, fish)


## Chest `index` opened by `fish`, a player elsewhere (online): it's still
## shut for everyone else, and there's no pick here.
func apply_chest_opened(index: int, fish: FishController) -> void:
	if index < 0 or index >= chests.size() or not is_instance_valid(chests[index]) or fish == null:
		return
	if chests[index].open_for(fish, layer_of(fish)):
		stats_of(fish)["chests"] = stats_of(fish).get("chests", 0) + 1
	_clear_chest(chests[index])


## A chest everyone's opened goes (its place in `chests` stays, for online's indices).
func _clear_chest(chest: TreasureChest) -> void:
	if is_instance_valid(chest) and chest.open_for_all(players) and not chest.is_queued_for_deletion() and not _chest_in_use(chest):
		chest.vanish()


## Whether a kill by `by` drops a chest: chest_drop_chance (elite: x
## elite_chest_scale), raised by their luck.
func _rolls_chest(by: FishController, elite: bool, modified := false) -> bool:
	var luck := block_of(by).value("luck") if is_instance_valid(by) and _blocks.has(by) else 0.0
	var chance := settings.chest_drop_chance * (settings.elite_chest_scale if elite else 1.0) * maxf(1.0 + luck * settings.chest_drop_luck, 0.0)
	if modified:
		chance *= settings.modifier_chest_scale  # an elite with a modifier (P5)
	if settings.limits:
		chance /= 1.0 + settings.chest_drop_fade * stage_time() / 60.0  # rarer as the stage goes on (P4)
	if is_instance_valid(by) and _powerups.has(by):
		chance *= (_powerups[by] as Powerups).chest_drop_scale()
	return chance > 0.0 and rng.randf() < chance


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


# --- Stages (P5) ----------------------------------------------------------

## On to the next stage (the whirlpool, in a run with more stages): a new
## seabed and timeline, harder zombies (stage_hp_scale, stage_damage_scale,
## stage_difficulty...), new chests and shrines, everyone back at the start and
## healed. Weapons, tomes, items, the level and purses carry on.
func next_stage() -> void:
	stage += 1
	stage_started = elapsed
	deep = 0
	horde.stage_hp = pow(settings.stage_hp_scale, stage - 1)
	_hold_for_cards(false)
	_clear_bosses()
	if is_instance_valid(whirlpool):
		whirlpool.queue_free()
	whirlpool = null
	cleared_at = -1.0
	swarm = {}
	enraged = false
	stage_complete = false
	horde.clear()
	if kill_pops:
		kill_pops.clear()
	for cloud in _clouds:
		if is_instance_valid(cloud):
			cloud.queue_free()
	_clouds.clear()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
	_chill.clear()
	director.reset()
	timeline.reset()
	_build_seabed()
	_bury_chests()
	_place_shrines()
	if is_instance_valid(blood_moon):
		blood_moon.strength = settings.blood_moon * (1.0 + 0.15 * (stage - 1))
	var spawn: Transform3D = ocean.spawn_transform()
	var moved: Array = []
	for fish in players:
		var health: FishHealth = _health.get(fish)
		if health:
			if health.down:
				revive(fish)
			health.heal(health.max_hp)
		if is_instance_valid(fish) and not fish.puppet:
			fish.revive(spawn_for(fish, spawn))
			moved.append(fish)
	_announce_teleport(moved)
	if run_log:
		run_log.stage_reached(stage)
	stage_began.emit(stage)


## The stage's seabed: rocks and kelp laid out from SEABED_SEED and the stage,
## so each stage's looks different (and every machine's the same).
func _build_seabed() -> void:
	var seed_now := SEABED_SEED + (stage - 1) * 7
	if not is_instance_valid(seabed) or seed_now == _seabed_seed:
		return
	_seabed_seed = seed_now
	seabed.setup(settings.arena_radius, settings.seabed_rocks, settings.seabed_kelp, seed_now, settings.edge_rocks, settings.edge_kelp,
			settings.arena_ceiling - settings.arena_floor + 5.0)


# --- Shrines (P5) ---------------------------------------------------------

## The stage's shrines: shrine_count of them, the kinds in turn, on the seabed at
## least shrine_spacing apart and away from the start (the host's; guests get
## them sent, shrine_placed).
func _place_shrines() -> void:
	for shrine in shrines:
		if is_instance_valid(shrine):
			shrine.queue_free()
	shrines.clear()
	if test_tank or not authority:
		return
	var placed := PackedVector2Array()
	for n in settings.shrine_count:
		var spot := Vector2.ZERO
		for attempt in 24:
			spot = Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf_range(0.08, 1.0)) * settings.arena_radius * 0.8
			var clear := spot.length() > 25.0
			for other in placed:
				if other.distance_to(spot) < settings.shrine_spacing:
					clear = false
					break
			if clear:
				break
		placed.append(spot)
		add_shrine(n % Shrine.Kind.size(), centre + Vector3(spot.x, settings.arena_floor, spot.y))


## A shrine of `kind` at `at` (on every machine: the host's own, or one it sent).
func add_shrine(kind: int, at: Vector3) -> Shrine:
	var shrine := Shrine.new()
	shrine.name = "Shrine"
	shrine.kind = kind as Shrine.Kind
	shrine.index = shrines.size()
	shrine.ring_radius = settings.shrine_tide_radius
	shrine.position = at
	add_child(shrine)
	shrines.append(shrine)
	if authority:
		shrine_placed.emit(shrine)
	return shrine


## The shrine `fish` is over and can use now (null: none).
func shrine_near(fish: FishController) -> Shrine:
	if not is_instance_valid(fish) or is_over or not is_up(fish) or _offers.has(fish):
		return null
	for shrine in shrines:
		if is_instance_valid(shrine) and shrine.is_over(fish.global_position, settings.shrine_reach) and can_use_shrine(shrine, fish):
			return shrine
	return null


## Whether `fish` may use `shrine`: not spent, not running, and (Chance) with tries left.
func can_use_shrine(shrine: Shrine, fish: FishController) -> bool:
	if shrine.spent or shrine.tide_active:
		return false
	if shrine.kind == Shrine.Kind.CHANCE:
		return int(shrine.tries.get(fish, 0)) < settings.shrine_chance_uses
	return true


## What a Shrine of Chance costs `fish` now (pearls): shrine_chance_price,
## growing with the stage's minutes as chests do, x shrine_chance_step a try.
func shrine_price(shrine: Shrine, fish: FishController) -> int:
	var price := settings.shrine_chance_price * (1.0 + settings.chest_price_growth * stage_time() / 60.0)
	return roundi(price * pow(settings.shrine_chance_step, int(shrine.tries.get(fish, 0))))


## Each local player over a shrine presses Jump to use it.
func _try_shrine(fish: FishController) -> void:
	if is_picking(fish) or near_whirlpool(fish) or unlocked_chest_near(fish):
		return
	var shrine := shrine_near(fish)
	if shrine == null:
		return
	var input: PlayerInput = fish.input_source if fish.input_source else PlayerInput.everyone()
	if input.just_pressed("jump"):
		use_shrine(shrine, fish)


## `fish` uses `shrine`. A Chance is theirs alone (their purse, their item),
## done here; the rest change the stage for everyone, so the host sets them
## off (a guest asks: shrine_claimed).
func use_shrine(shrine: Shrine, fish: FishController) -> void:
	if not can_use_shrine(shrine, fish):
		return
	if shrine.kind == Shrine.Kind.CHANCE:
		var price := shrine_price(shrine, fish)
		if purse_of(fish) < price:
			shrine_used.emit(shrine, fish, "short")
			return
		add_pearls(fish, -price)
		shrine.tries[fish] = int(shrine.tries.get(fish, 0)) + 1
		stats_of(fish)["shrines"] = stats_of(fish).get("shrines", 0) + 1
		if rng.randf() < settings.shrine_chance_odds:
			if not _chest_pending.has(fish):
				_chest_pending[fish] = []
			(_chest_pending[fish] as Array).append([TreasureChest.Kind.TREASURE, "", null, 0])
			shrine_used.emit(shrine, fish, "won")
			if not _offers.has(fish):
				_offer_next(fish)
		else:
			shrine_used.emit(shrine, fish, "lost")
		return
	if authority:
		activate_shrine(shrine, fish)
	else:
		shrine_claimed.emit(shrine.index, fish)


## `shrine` (a Tide, Deep or Pearls) set off by `fish`: on every machine (the
## host's call; shrine_activated tells the guests).
func activate_shrine(shrine: Shrine, fish: FishController) -> void:
	if not is_instance_valid(shrine) or shrine.spent or shrine.tide_active:
		return
	if is_instance_valid(fish):
		stats_of(fish)["shrines"] = stats_of(fish).get("shrines", 0) + 1
	match shrine.kind:
		Shrine.Kind.TIDE:
			shrine.tide_active = true
			shrine.tide_held = 0.0
			shrine.tide_wave_left = 0.0  # the first wave now
		Shrine.Kind.DEEP:
			shrine.spent = true
			deep += 1
		Shrine.Kind.PEARLS:
			shrine.spent = true
			if authority:
				for n in settings.shrine_pearls_bonus:
					var spill := Vector3(sin(n * 2.4), 0.6 + 0.3 * sin(n * 1.3), cos(n * 2.4)) * 2.5
					drop_pearl(shrine.global_position + Vector3.UP * 2.0 + spill, 1, SHRINE_PEARL - stage * 1000 - shrine.index * 50 - n)
			_draw_pearls_to_team()
	if authority:
		shrine_activated.emit(shrine, fish)
	shrine_used.emit(shrine, fish, ["tide", "", "deep", "pearls"][shrine.kind])


## Every pearl out flies to the nearest player who's up (the Shrine of Pearls).
func _draw_pearls_to_team() -> void:
	for pearl in pearls_out:
		if not is_instance_valid(pearl):
			continue
		var best: FishController = null
		var gap := INF
		for fish in players:
			if is_up(fish):
				var d := fish.global_position.distance_squared_to(pearl.global_position)
				if d < gap:
					gap = d
					best = fish
		if best:
			pearl.drawn_by = best


## Running Tides: held while anyone who's up is in the ring (draining back at
## half speed while nobody is), a ring of zombies round it every
## shrine_tide_wave s (the host's), and won at shrine_tide_time: a free chest.
func _update_shrines(delta: float) -> void:
	for shrine in shrines:
		if not is_instance_valid(shrine) or not shrine.tide_active:
			continue
		var holder: FishController = null
		for fish in players:
			if is_up(fish) and shrine.is_over(fish.global_position, settings.shrine_tide_radius):
				holder = fish
				break
		shrine.tide_held = clampf(shrine.tide_held + (delta if holder else -delta * 0.5), 0.0, settings.shrine_tide_time)
		if authority and holder:
			shrine.tide_wave_left -= delta
			if shrine.tide_wave_left <= 0.0:
				shrine.tide_wave_left = settings.shrine_tide_wave
				var middle := Vector3(shrine.global_position.x, holder.global_position.y, shrine.global_position.z)
				var crowd := 1.0 + settings.coop_scale * maxi(players.size() - 1, 0)
				_ring(middle, roundi(settings.shrine_tide_count * crowd), settings.shrine_tide_radius * 2.5)
		if shrine.tide_held >= settings.shrine_tide_time:
			shrine.tide_active = false
			shrine.spent = true
			if authority:
				var chest := add_chest(shrine.global_position + Vector3(0.0, 4.0, 4.0), rng.randf() * TAU,
						centre.y + settings.arena_floor - TreasureChest.SIZE.y * 0.3, TreasureChest.Kind.TREASURE, FREE_CHEST)
				chest_buried.emit(chest)
			for fish in local_players():
				shrine_used.emit(shrine, fish, "tide_won")


## A Shrine of the Tide's progress (0..1), for the HUD.
func tide_progress(shrine: Shrine) -> float:
	return shrine.tide_held / maxf(settings.shrine_tide_time, 0.01)


## The running Tide (null: none).
func running_tide() -> Shrine:
	for shrine in shrines:
		if is_instance_valid(shrine) and shrine.tide_active:
			return shrine
	return null


# --- Elite modifiers (P5) -------------------------------------------------

## Burning elites leave a patch of fire every burning_every s (on every machine:
## the patches hurt only the players played there).
func _update_affixes(delta: float) -> void:
	if not settings.burning:
		return
	_burn_left -= delta
	if _burn_left > 0.0:
		return
	_burn_left = settings.burning_every
	var out := 0
	for cloud in _clouds:
		if is_instance_valid(cloud) and cloud.cause == BURN_CAUSE:
			out += 1
	for i in horde.alive:
		if out >= settings.burning_max:
			return
		if horde.affix_of(i) == Horde.Affix.BURNING and not horde.is_proxy(i):
			_hazard(horde.enemy_position(i), settings.burning_radius, settings.burning_time, settings.burning_damage,
					Color(1.0, 0.45, 0.08, 0.35), BURN_CAUSE)
			out += 1


## What a burning elite's fire is called (the run log's cause).
const BURN_CAUSE := "a burning elite's fire"


## What an elite's modifier does as it dies: Electric shocks round it after
## electric_delay; Bloated bursts into bloated_count sardines (the host's).
func _affix_death(index: int, at: Vector3) -> void:
	match horde.affix_of(index):
		Horde.Affix.ELECTRIC:
			if settings.electric:
				var shock := _hazard(at, settings.electric_radius, 0.3, settings.electric_damage, Color(0.45, 0.8, 1.0, 0.4),
						"an electric elite's shock")
				shock.delay = settings.electric_delay
		Horde.Affix.BLOATED:
			if settings.bloated and authority:
				horde.spawn_pack(0, settings.bloated_count, at, 1.5, Vector3.ZERO, 0.0)


## A cloud that hurts the players in it (BurstCloud): a fire patch or a shock.
func _hazard(at: Vector3, radius: float, lifetime: float, damage: float, color: Color, cause: String, slows := false) -> BurstCloud:
	var cloud := BurstCloud.new()
	cloud.name = "Hazard"
	cloud.radius = radius
	cloud.lifetime = lifetime
	cloud.damage = damage
	cloud.color = color
	cloud.slows = slows
	cloud.cause = cause
	cloud.position = at
	add_child(cloud)
	cloud.tree_exiting.connect(func() -> void: _clouds.erase(cloud))
	_clouds.append(cloud)
	return cloud


# --- Choices (P4) ---------------------------------------------------------

## `fish`'s rerolls, skips or banishes left (`what`: "rerolls", "skips", "banishes").
func choices_of(fish: FishController, what: String) -> int:
	return int((_choices.get(fish, {}) as Dictionary).get(what, 0))


func add_choices(fish: FishController, what: String, amount: int) -> void:
	if not _choices.has(fish):
		_choices[fish] = {"rerolls": 0, "skips": 0, "banishes": 0}
	_choices[fish][what] = maxi(choices_of(fish, what) + amount, 0)
	choices_changed.emit(fish)


## What `fish` has banished for the rest of the run (weapon, tome and item ids).
func banished_of(fish: FishController) -> Array:
	return _banished.get(fish, [])


## Whether the cards `fish` has up allow `what` now: a level's all three (a
## Moon Pearl's extra pick, no skip); a treasure or cursed chest's reroll and
## banish (before its first pick); a boss chest's or a swap's, none.
func can_choose(fish: FishController, what: String) -> bool:
	if not _offers.has(fish) or choices_of(fish, what) <= 0:
		return false
	var cards: Array = _offers[fish]
	match _offer_kind.get(fish, ""):
		"level":
			return what != "skips" or _level_extra.get(fish, 0) == powerups_of(fish).extra_level_picks()
		"chest":
			var info: Dictionary = _chest_offer.get(fish, {})
			if what == "skips" or info.is_empty() or info.committed or cards.is_empty():
				return false
			var chest: TreasureChest = info.chest
			return is_instance_valid(chest) and chest.kind != TreasureChest.Kind.BOSS \
					and _extra_picks.get(fish, 0) == mini(powerups_of(fish).stacks("sunken_idol"), cards.size() - 1)
	return false


## New cards for `fish`'s offer (a reroll): a level's dealt again; a chest's
## rolled again at a new rarity (the same kind of chest).
func reroll(fish: FishController) -> void:
	if not can_choose(fish, "rerolls"):
		return
	var cards: Array
	if _offer_kind[fish] == "level":
		cards = CardDeck.deal(self, fish, settings.card_choices)
	else:
		var chest: TreasureChest = (_chest_offer[fish] as Dictionary).chest
		cards = _chest_cards(fish, chest.kind, [])
		_remember_chest_cards(fish, cards)
	if cards.is_empty():
		return
	add_choices(fish, "rerolls", -1)
	_offers[fish] = cards
	stats_of(fish)["rerolls"] = stats_of(fish).get("rerolls", 0) + 1
	cards_offered.emit(fish, cards, "REROLLED", _choice_line(fish))


## `fish` takes nothing from this level (a skip).
func skip(fish: FishController) -> void:
	if not can_choose(fish, "skips"):
		return
	add_choices(fish, "skips", -1)
	stats_of(fish)["skips"] = stats_of(fish).get("skips", 0) + 1
	_level_extra.erase(fish)
	_pending[fish] = _pending.get(fish, 1) - 1
	_offers.erase(fish)
	_offer_kind.erase(fish)
	card_picked.emit(fish, {"kind": "skip", "tier": Rarity.Tier.COMMON})
	_offer_next(fish)


## Card `index`'s weapon, tome or item is gone from `fish`'s pool for the rest
## of the run (a banish), and a fresh card takes its place (or none, if
## nothing's left but fallbacks and others remain).
func banish(fish: FishController, index: int) -> void:
	if not can_choose(fish, "banishes"):
		return
	var cards: Array = (_offers[fish] as Array).duplicate()
	if index < 0 or index >= cards.size():
		return
	var card: Dictionary = cards[index]
	var id := _card_id(card)
	if id == "":
		return
	add_choices(fish, "banishes", -1)
	if not _banished.has(fish):
		_banished[fish] = []
	(_banished[fish] as Array).append(id)
	stats_of(fish)["banished"] = banished_of(fish).duplicate()
	var shown: Array = []
	for other: Dictionary in cards:
		shown.append(_card_id(other))
	var fresh: Array
	if _offer_kind[fish] == "level":
		fresh = CardDeck.deal(self, fish, 1, shown)
	else:
		var chest: TreasureChest = (_chest_offer[fish] as Dictionary).chest
		fresh = _chest_cards(fish, chest.kind, shown, 1)
	if fresh.is_empty() or (fresh[0].get("kind", "") == "fallback" and cards.size() > 1):
		cards.remove_at(index)
	else:
		cards[index] = fresh[0]
	if _offer_kind[fish] == "chest":
		_remember_chest_cards(fish, cards)
	if cards.is_empty():
		# Nothing left to offer: a level's goes by; a chest's is put back.
		if _offer_kind[fish] == "chest":
			cancel_offer(fish)
		else:
			skip_free(fish)
		return
	_offers[fish] = cards
	cards_offered.emit(fish, cards, "BANISHED: %s" % _card_title(fish, card).to_upper(), _choice_line(fish))


## A level's offer goes by with nothing taken (and no skip spent).
func skip_free(fish: FishController) -> void:
	_level_extra.erase(fish)
	_pending[fish] = _pending.get(fish, 1) - 1
	_offers.erase(fish)
	_offer_kind.erase(fish)
	card_picked.emit(fish, {"kind": "skip", "tier": Rarity.Tier.COMMON})
	_offer_next(fish)


## A chest's cards as rerolled or banished, so putting it back and opening it
## again offers these (no free rerolls).
func _remember_chest_cards(fish: FishController, cards: Array) -> void:
	var chest: TreasureChest = (_chest_offer.get(fish, {}) as Dictionary).get("chest")
	if is_instance_valid(chest) and _chest_rolls.has(chest) and (_chest_rolls[chest] as Dictionary).has(fish):
		((_chest_rolls[chest] as Dictionary)[fish] as Dictionary).cards = cards.duplicate(true)


## What a card offers (a weapon, tome or item id; "" for a fallback or a swap).
static func _card_id(card: Dictionary) -> String:
	if card.has("powerup"):
		return card.powerup
	match card.get("kind", ""):
		"weapon", "new_weapon":
			return card.weapon
		"tome", "new_tome":
			return card.tome
	return ""


func _card_title(fish: FishController, card: Dictionary) -> String:
	if card.has("powerup"):
		return Powerup.title(card.powerup)
	if card.has("tome"):
		return Tomes.title(card.tome)
	if card.has("weapon"):
		return Weapons.title(card.weapon, loadout_of(fish).attack_kind)
	return ""


## The line under a rerolled or banished offer: what's left.
func _choice_line(fish: FishController) -> String:
	return "REROLLS %d  ·  SKIPS %d  ·  BANISHES %d" % [choices_of(fish, "rerolls"), choices_of(fish, "skips"), choices_of(fish, "banishes")]


## A treasure or cursed chest's cards for `fish`, rolled fresh (`count`:
## chest_choices), leaving out what they've banished and `shown`.
func _chest_cards(fish: FishController, kind: int, shown: Array, count := -1) -> Array:
	var want := settings.chest_choices if count < 0 else count
	var left_out: Array = banished_of(fish) + shown
	var cards := []
	if kind == TreasureChest.Kind.CURSED:
		for id in Powerup.pick_from_tier(rng, Rarity.Tier.CURSED, want, left_out):
			cards.append(_powerup_card(fish, id))
	else:
		var rolled := Rarity.roll(rng, settings, block_of(fish).value("luck"))
		for id in Powerup.pick_for_chest(rng, rolled, want, left_out):
			cards.append(_powerup_card(fish, id))
	return cards
