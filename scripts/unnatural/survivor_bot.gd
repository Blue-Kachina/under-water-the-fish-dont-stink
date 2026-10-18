class_name SurvivorBot
extends HunterBot
## A bot that plays Unnatural, for the run simulator (planning_unnatural.md,
## "Playability pass" P2): it swims with HunterBot's strides (FishInput only,
## like a player), and its fish's own auto-attacks do the killing. It:
## - hunts: with few zombies close, it swims at the nearest (its attacks reach
##   from close by), steering off them so it doesn't touch;
## - kites: crowded, it circles the arena's middle, steering away from the
##   zombies close by (the nearer, the harder), and swings back in near the edge;
## - batters: fast enough, it rams a lone zombie close ahead;
## - collects: swims over pearls close by;
## - opens chests: one it can afford, near and with the horde not on top of
##   it, it swims through at battering speed (or, slow, stops by it);
## - picks cards: at random, or greedily (new weapons first, then the rarest
##   upgrades, milestones and useful tomes; it skips cursed items).

enum Picks { RANDOM, GREEDY }

## How far it looks for zombies to steer away from, pearls and chests (m).
const DANGER_RANGE := 22.0
const PEARL_RANGE := 25.0
const CHEST_RANGE := 70.0
## Zombies this close to a chest (or to it) and it leaves the chest be.
const CHEST_CROWD := 6.0
## The circle it kites round, as a share of the arena's radius.
const KITE_RADIUS := 0.45
## It hunts while fewer than CROWD zombies are within CROWD_RANGE (m), going
## for the nearest within HUNT_RANGE.
const CROWD := 6
const CROWD_RANGE := 10.0
const HUNT_RANGE := 80.0
## A ram: a zombie within this (m), this close to dead ahead (cos), with no
## other zombie within RAM_CROWD of it.
const RAM_RANGE := 12.0
const RAM_CONE := 0.85
const RAM_CROWD := 4.0
## Seconds between card picks (the game waits for it anyway).
const PICK_DELAY := 0.05

var run: UnnaturalRun
var picks := Picks.GREEDY
## Cards picked, by kind ("weapon", "tome", "item", ...), for the report.
var picked := {}

var _goal := Vector3.ZERO
var _kite_sign := 1.0
var _holding := false


func _ready() -> void:
	super()
	target = fish  # HunterBot remembers a target; it has none, so its own fish
	_kite_sign = 1.0 if rng.randf() < 0.5 else -1.0
	run.cards_offered.connect(_on_cards_offered)


func _physics_process(delta: float) -> void:
	if _holding and is_instance_valid(fish) and not fish.controls_locked:
		input.clear()
		_goal = _choose_goal()  # still wants to stay?
		if _holding:
			return
	super(delta)


## Always swimming to the goal it picks (HunterBot's HUNT, no commits or evades).
func _think(_delta: float) -> void:
	mode = Mode.HUNT
	_goal = _choose_goal()


func _destination() -> Vector3:
	return _goal


func _choose_goal() -> Vector3:
	_holding = false
	var me := fish.global_position
	var away := Vector3.ZERO
	var closest := INF
	var crowd := 0
	for i in run.horde.query_sphere(me, DANGER_RANGE):
		var offset := me - run.horde.enemy_position(i)
		var gap := maxf(offset.length() - run.horde.enemy_radius(i), 0.5)
		closest = minf(closest, gap)
		crowd += 1 if gap < CROWD_RANGE else 0
		away += offset.normalized() / (gap * gap)
	var goal := _chest_goal(me, closest)
	if goal == Vector3.INF:
		goal = _ram_goal(me)
	if goal == Vector3.INF:
		goal = _pearl_goal(me, closest)
	if goal == Vector3.INF and crowd < CROWD:
		goal = _hunt_goal(me)
	if goal == Vector3.INF:
		goal = _kite_goal(me)
	if goal != me and away.length() > 0.0:
		# The zombies close by push the goal away from them, harder the nearer.
		var push := clampf(away.length() * 8.0, 0.0, 1.0)
		var line := (goal - me).normalized()
		goal = me + (line * (1.0 - push) + away.normalized() * push).normalized() * maxf(me.distance_to(goal), 15.0)
	return _keep_in(goal)


## The nearest chest it can afford, if it's worth going for: open, by
## swimming through it (or, slow, stopping by it).
func _chest_goal(me: Vector3, closest: float) -> Vector3:
	if closest < CHEST_CROWD * 0.5:
		return Vector3.INF
	var best: TreasureChest = null
	var best_gap := CHEST_RANGE
	for chest in run.shut_chests_for(fish):
		if not run.can_afford(fish, chest):
			continue
		var gap := me.distance_to(chest.global_position)
		if gap < best_gap and run.horde.query_sphere(chest.global_position, CHEST_CROWD).size() <= 2:
			best = chest
			best_gap = gap
	if best == null:
		return Vector3.INF
	var middle := best.global_position + Vector3.UP * TreasureChest.SIZE.y * 0.5
	var fast := fish.speed >= fish.nature_batter_speed * run.powerups_of(fish).batter_speed_share()
	if best_gap < run.settings.chest_reach - 1.0 and not fast:
		_holding = true  # slow and beside it: hold still until it opens
		return me
	return middle


## A lone zombie close ahead, while it's fast enough to batter.
func _ram_goal(me: Vector3) -> Vector3:
	if fish.speed < fish.nature_batter_speed * run.powerups_of(fish).batter_speed_share() * 1.1:
		return Vector3.INF
	var nose := -fish.global_basis.z
	var index := run.horde.nearest_in_cone(me, nose, RAM_RANGE, RAM_CONE)
	if index < 0 or run.boss_at(index) != null:
		return Vector3.INF
	var kind := run.horde.enemy_kind(index)
	if kind and kind.behaviour == EnemyKind.Behaviour.TANK:
		return Vector3.INF  # a boxfish bursts into a cloud that hurts: not point blank
	var at := run.horde.enemy_position(index)
	if run.horde.query_sphere(at, RAM_CROWD).size() > 2:
		return Vector3.INF
	return at


func _pearl_goal(me: Vector3, closest: float) -> Vector3:
	if closest < 3.0:
		return Vector3.INF
	var best := Vector3.INF
	var best_gap := PEARL_RANGE
	for pearl in run.pearls_out:
		if not is_instance_valid(pearl):
			continue
		var gap := me.distance_to(pearl.global_position)
		if gap < best_gap:
			best = pearl.global_position
			best_gap = gap
	return best


## The nearest zombie within HUNT_RANGE (bosses too: its attacks are what beat them).
func _hunt_goal(me: Vector3) -> Vector3:
	var index := run.horde.nearest_in_cone(me, Vector3.FORWARD, HUNT_RANGE, -1.0)
	return run.horde.enemy_position(index) if index >= 0 else Vector3.INF


## Round the middle at KITE_RADIUS of the arena, a little ahead along the circle.
func _kite_goal(me: Vector3) -> Vector3:
	var radius := run.settings.arena_radius * KITE_RADIUS
	var flat := Vector3(me.x - run.centre.x, 0.0, me.z - run.centre.z)
	if flat.length() < 1.0:
		flat = Vector3.FORWARD
	var angle := atan2(flat.z, flat.x) + _kite_sign * 0.35
	var height := run.centre.y + (run.settings.arena_floor + run.settings.arena_ceiling) * 0.5
	return Vector3(run.centre.x + cos(angle) * radius, height, run.centre.z + sin(angle) * radius)


## Inside the arena and its depth band.
func _keep_in(goal: Vector3) -> Vector3:
	var flat := Vector3(goal.x - run.centre.x, 0.0, goal.z - run.centre.z)
	var limit := run.settings.arena_radius * 0.85
	if flat.length() > limit:
		flat = flat.normalized() * limit
	var floor_y := run.centre.y + run.settings.arena_floor + 3.0
	var top_y := run.centre.y + run.settings.arena_ceiling - 3.0
	return Vector3(run.centre.x + flat.x, clampf(goal.y, floor_y, top_y), run.centre.z + flat.z)


func _on_cards_offered(for_fish: FishController, cards: Array, _heading: String, _line: String) -> void:
	if for_fish != fish or cards.is_empty():
		return
	var index := _choose_card(cards)
	var card: Dictionary = cards[index]
	var kind: String = card.get("kind", "item" if card.has("powerup") else "?")
	picked[kind] = picked.get(kind, 0) + 1
	# Deferred: the run is still emitting the offer.
	(func() -> void:
		if is_instance_valid(run) and run.offer_of(fish) == cards:
			run.pick(fish, index)).call_deferred()


func _choose_card(cards: Array) -> int:
	if picks == Picks.RANDOM:
		return rng.randi() % cards.size()
	var best := 0
	var best_score := -INF
	for n in cards.size():
		var score := _score(cards[n]) + rng.randf() * 0.5  # ties broken at random
		if score > best_score:
			best = n
			best_score = score
	return best


## How much the greedy pick wants `card`.
func _score(card: Dictionary) -> float:
	var tier := float(card.get("tier", 0))
	match card.get("kind", ""):
		"new_weapon":
			return 100.0
		"weapon":
			var level := int(card.get("level", 1))
			return 50.0 + tier * 10.0 + (15.0 if level == 5 or level == 10 else 0.0)
		"new_tome":
			return 75.0 if card.tome in ["teeth", "tides", "shell", "reef"] else 65.0  # a slot filled, as a player would
		"tome":
			return 45.0 + tier * 10.0
		"fallback":
			var health := run.health_of(fish)
			return 60.0 if card.what == "heal" and health and health.share() < 0.5 else 1.0
		"swap":
			return 80.0 - float(card.get("level", 1)) * 5.0  # swap out the weakest
		"keep":
			return 30.0
	if card.has("powerup"):
		if int(card.tier) == Rarity.Tier.CURSED:
			return 2.0
		return 10.0 + tier * 10.0 + (5.0 if int(card.get("stacks", 1)) == 1 else 0.0)
	return 0.0
