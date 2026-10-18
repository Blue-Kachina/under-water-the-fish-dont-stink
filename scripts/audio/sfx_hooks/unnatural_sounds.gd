class_name UnnaturalSounds
extends Node
## Unnatural's sounds (planning_audio.md §3.7): the seabed and blood moon beds,
## the horde (a moan that swells with how many are near, spawns, lunges, hits
## and deaths gathered per frame), your hits by attack and powerup, you and
## your team (hurt, down, revive, the heartbeat), XP, level-ups and cards,
## pickups, chests, pearls, stage events and the bosses' arrivals. SfxHooks
## adds one to every UnnaturalRun. Everything comes off the run's signals,
## which fire on every machine of an online run. The powerups' own sounds are
## played by the powerups (pw/), a boss's moves by BossSounds.
##
## Mass events are gathered per frame: forty zombies dying in one frame make one
## sound, louder (the @ layers) the more there were.

## This many gathered events is a full-strength sound.
const FULL_COUNT := 10.0
## Zombies this close (m) to a local player are the moan.
const MOAN_RANGE := 35.0
const MOAN_FULL := 30.0
## Lunges and spawns further than this from every local player (m) are not played.
const EARSHOT := 50.0
## Under this share of max hp, the heartbeat.
const LOW_HP := 0.25
## Loops are looked after this often (s).
const LOOP_INTERVAL := 0.2
## Kills (XP) and pearls this soon (s) after the last one climb the scale.
const STREAK_WINDOW := 1.0
const MAX_STEP := 11
## The rarest card shows its reveal this long (s) after the cards fan out.
const REVEAL_DELAY := 0.3
## The magnet's pull, heard this long (s).
const MAGNET_TIME := 2.0

## A powerup's hit source -> the sound for its hits.
const HIT_SOUNDS := {
	"greek_fire": "pw/greek_fire_burn",
	"remora_buddy": "pw/remora_nip",
	"jellyfish_halo": "pw/jelly_sting",
	"leviathans_coil": "pw/coil_hit",
}
const PICKUPS := ["heart", "magnet", "hourglass"]
## An attack's hit source -> the sound for its hits (cheaper than building it per hit).
const ATTACK_HITS := {
	"sting": "unnatural/sting_hit", "bite": "unnatural/bite_hit", "lash": "unnatural/lash_hit",
	"thrust": "unnatural/thrust_hit", "bubbles": "unnatural/bubbles_hit", "spines": "unnatural/spines_hit",
}
## A zombie behaviour (EnemyKind.Behaviour) -> the sound for its death.
const DEATHS := [
	"unnatural/zombie_die_chase", "unnatural/zombie_die_swarm", "unnatural/zombie_die_tank",
	"unnatural/zombie_die_lunge", "unnatural/zombie_die_glide",
]

var run: UnnaturalRun

## Gathered this frame: sound id -> {"count", "at" (sum of places), "local"}.
var _gathered := {}
var _kills_by_local := false
var _beds: Array[int] = []
var _moan := 0
var _heartbeat := 0
var _revive := 0
var _magnet := 0
var _magnet_left := 0.0
var _since_loops := 0.0
var _xp_streak := 0
var _xp_left := 0.0
var _pearl_streak := 0
var _pearl_left := 0.0


func _ready() -> void:
	run = get_parent() as UnnaturalRun
	process_mode = Node.PROCESS_MODE_ALWAYS  # the cards pause the game; their sounds don't
	run.zombie_hit.connect(_on_zombie_hit)
	run.zombie_killed.connect(_on_zombie_killed)
	run.player_hurt.connect(_on_player_hurt)
	run.player_down.connect(func(_fish: FishController) -> void: Sfx.play("unnatural/downed"))
	run.player_revived.connect(func(_fish: FishController) -> void: Sfx.play("unnatural/revived"))
	run.leveled_up.connect(func(_level: int) -> void:
		Sfx.play("unnatural/level_up")
		Sfx.play("voice/level_up"))
	run.cards_offered.connect(_on_cards_offered)
	run.card_picked.connect(_on_card_picked)
	run.drop_taken.connect(_on_drop_taken)
	run.pearl_collected.connect(_on_pearl_collected)
	run.chest_buried.connect(func(chest: TreasureChest) -> void: Sfx.play_at("unnatural/chest_buried", chest.global_position))
	run.chest_opened.connect(func(chest: TreasureChest, _fish: FishController) -> void: Sfx.play_at("unnatural/chest_open", chest.global_position))
	run.powerup_lost.connect(func(_fish: FishController, _id: String) -> void: Sfx.play("unnatural/powerup_lost"))
	run.stage_warned.connect(_on_stage_warned)
	run.stage_event.connect(_on_stage_event)
	run.boss_arrived.connect(_on_boss_arrived)
	run.boss_enraged.connect(func(_boss: Boss) -> void: Sfx.play("boss/enraged"))
	run.boss_defeated.connect(func(_boss: Boss, _by: FishController) -> void: Sfx.play("boss/defeated"))
	run.stage_completed.connect(func() -> void:
		Sfx.play("stage/complete")
		Sfx.play("voice/win"))
	run.run_over.connect(func() -> void:
		if not run.stage_complete:
			Sfx.play("stage/run_over")
			Sfx.play("voice/lose"))
	run.restarted.connect(_start_beds)
	run.horde.spawned.connect(_on_zombie_spawned)
	run.horde.lunge_stage.connect(_on_lunge_stage)
	if is_instance_valid(run.blood_moon):
		Sfx.water_surface = run.blood_moon.surface_height  # the water's top, overhead
	_start_beds()


func _exit_tree() -> void:
	Sfx.water_surface = INF
	_stop_beds()
	for handle: int in [_moan, _heartbeat, _revive, _magnet]:
		Sfx.stop_loop(handle)


## The beds under the whole run: the seabed, and the blood moon over it.
func _start_beds() -> void:
	_stop_beds()
	_beds.append(Sfx.start_loop("amb/seabed_loop"))
	_beds.append(Sfx.start_loop("stage/blood_moon_loop"))
	Sfx.play("stage/blood_moon")


func _stop_beds() -> void:
	for handle in _beds:
		Sfx.stop_loop(handle, 0.5)
	_beds.clear()


func _process(delta: float) -> void:
	_xp_left = maxf(_xp_left - delta, 0.0)
	_pearl_left = maxf(_pearl_left - delta, 0.0)
	_magnet_left = maxf(_magnet_left - delta, 0.0)
	_flush()
	_since_loops += delta
	if _since_loops >= LOOP_INTERVAL:
		_since_loops = 0.0
		_update_loops()


# --- Hits, deaths and spawns, gathered per frame -----------------------------------

func _on_zombie_hit(index: int, _amount: float, by: FishController, source: String, chain: Array) -> void:
	var boss := run.boss_at(index)
	if boss != null:
		_gather("boss/hit", boss.global_position)
	elif source == "chain_lightning":
		Sfx.play_pitched("pw/chain_zap", mini(maxi(chain.size() - 1, 0), MAX_STEP), run.horde.enemy_position(index))
	elif ATTACK_HITS.has(source):
		_gather(ATTACK_HITS[source], run.horde.enemy_position(index))
	elif source == "battery":
		_gather("battered/battery", run.horde.enemy_position(index))
	else:
		_gather(HIT_SOUNDS.get(source, "unnatural/zombie_hit"), run.horde.enemy_position(index))


func _on_zombie_killed(at: Vector3, kind: EnemyKind, by: FishController, _source: String) -> void:
	_gather(DEATHS[kind.behaviour], at)
	_kills_by_local = _kills_by_local or (is_instance_valid(by) and not by.puppet)


func _on_zombie_spawned(index: int) -> void:
	var at := run.horde.enemy_position(index)
	if _near_player(at, EARSHOT):
		_gather("unnatural/zombie_spawn", at)


func _on_lunge_stage(index: int, stage: int) -> void:
	var at := run.horde.enemy_position(index)
	if not _near_player(at, EARSHOT):
		return
	Sfx.play_at("unnatural/lunge_telegraph" if stage == Horde.Lunge.TELEGRAPH else "unnatural/lunge", at)


func _gather(id: String, at: Vector3) -> void:
	var entry: Dictionary = _gathered.get(id, {"count": 0, "at": Vector3.ZERO})
	entry.count += 1
	entry.at += at
	_gathered[id] = entry


## One sound for each kind gathered this frame, at their middle, harder the more.
func _flush() -> void:
	for id: String in _gathered:
		var entry: Dictionary = _gathered[id]
		var count: int = entry.count
		Sfx.play_at(id, entry.at / count, clampf(count / FULL_COUNT, 0.1, 1.0))
	_gathered.clear()
	if _kills_by_local:
		_kills_by_local = false
		_xp_streak = _xp_streak + 1 if _xp_left > 0.0 else 0
		_xp_left = STREAK_WINDOW
		Sfx.play_pitched("unnatural/xp", mini(_xp_streak, MAX_STEP))


func _near_player(point: Vector3, reach: float) -> bool:
	for fish in run.local_players():
		if fish.global_position.distance_to(point) <= reach:
			return true
	return false


# --- You and your team -------------------------------------------------------------

func _on_player_hurt(fish: FishController, _amount: float) -> void:
	if not fish.puppet:
		Sfx.play("unnatural/hurt")


func _on_cards_offered(fish: FishController, cards: Array, _heading: String, _line: String) -> void:
	if fish.puppet:
		return
	Sfx.play("unnatural/cards_offered")
	var best := -1
	for card: Dictionary in cards:
		best = maxi(best, int(card.get("tier", -1)))
	if best >= 0 and best < Rarity.NAMES.size():
		var reveal := "unnatural/card_reveal_" + String(Rarity.NAMES[best]).to_lower()
		get_tree().create_timer(REVEAL_DELAY).timeout.connect(Sfx.play.bind(reveal))


func _on_card_picked(fish: FishController, card: Dictionary) -> void:
	if fish.puppet:
		return
	Sfx.play("unnatural/card_picked")
	if int(card.get("tier", -1)) == Rarity.Tier.CURSED:
		Sfx.play("pw/cursed_take")


func _on_drop_taken(kind: int, _by: FishController) -> void:
	if kind >= 0 and kind < PICKUPS.size():
		Sfx.play("unnatural/pickup_" + PICKUPS[kind])
	if kind == Pickup.Kind.MAGNET:
		_magnet_left = MAGNET_TIME


## A pearl: climbs the scale on a streak, the Nature pearl's sound.
func _on_pearl_collected(by: FishController) -> void:
	if is_instance_valid(by) and by.puppet:
		return
	_pearl_streak = _pearl_streak + 1 if _pearl_left > 0.0 else 0
	_pearl_left = STREAK_WINDOW
	Sfx.play_pitched("unnatural/pearl", mini(_pearl_streak, 7))


# --- The stage ---------------------------------------------------------------------

func _on_stage_warned(event: String) -> void:
	_play_if("stage/%s_warn" % event)
	_play_if("voice/%s_warn" % event)


func _on_stage_event(event: String) -> void:
	_play_if("stage/" + event)


func _on_boss_arrived(boss: Boss) -> void:
	Sfx.play("boss/shark_arrive" if boss is DrownedShark else "boss/leviathan_arrive")
	Sfx.play("voice/boss_arrive")


func _play_if(id: String) -> void:
	if SoundCatalog.has(id):
		Sfx.play(id)


# --- Loops -------------------------------------------------------------------------

func _update_loops() -> void:
	var crowd := 0
	var weakest := 1.0
	var revived := 0.0
	for fish in run.local_players():
		if run.horde:
			crowd = maxi(crowd, run.horde.query_sphere(fish.global_position, MOAN_RANGE).size())
		var health := run.health_of(fish)
		if health and not health.down:
			weakest = minf(weakest, health.hp / maxf(health.max_hp, 1.0))
		revived = maxf(revived, run.revive_progress(fish))
	_moan = _loop(_moan, "unnatural/zombie_moan_loop", crowd > 0, clampf(crowd / MOAN_FULL, 0.15, 1.0))
	_heartbeat = _loop(_heartbeat, "unnatural/low_hp_loop", weakest < LOW_HP, 1.0 - weakest / LOW_HP, lerpf(1.0, 1.4, 1.0 - weakest / LOW_HP))
	_revive = _loop(_revive, "unnatural/revive_loop", revived > 0.0, 0.4 + 0.6 * revived, 0.9 + 0.4 * revived)
	_magnet = _loop(_magnet, "unnatural/magnet_pull_loop", _magnet_left > 0.0, 1.0)


## Keeps loop `handle` going (or not) as `on` says, and tuned.
func _loop(handle: int, id: String, on: bool, volume: float, pitch := 1.0) -> int:
	if on and handle == 0:
		handle = Sfx.start_loop(id)
	elif not on and handle != 0:
		Sfx.stop_loop(handle, 0.4)
		return 0
	if handle != 0:
		Sfx.set_loop(handle, volume, pitch)
	return handle
