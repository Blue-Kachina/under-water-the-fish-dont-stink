class_name Powerup
extends RefCounted
## One powerup a player holds in Unnatural (planning_unnatural.md §7), with
## its stacks: the same one again makes it stronger. Subclasses override the
## hooks they need; Powerups calls them:
## - on_hit(index, damage, source, proc, chain): a zombie hit by this player
##   (any source). `proc` is the hit's proc coefficient (chances scale with
##   it); `chain` lists the powerups that led to the hit (one can't start
##   itself again).
## - on_kill(at, source), on_battery(index), on_tick(delta), on_stride(timing)
## - on_stacks_changed(): stacks went up (or the testing override changed).
## INFO has each one's name, colour and short tag; create() makes one by id.

## Id -> [name, colour, tag, what it does].
const INFO := {
	"greek_fire": ["Greek Fire Trail", Color(1.0, 0.45, 0.1), "GF", "Burning patches behind you burn the zombies in them."],
	"chain_lightning": ["Chain Lightning", Color(0.45, 0.8, 1.0), "CL", "Hits may start lightning that jumps between zombies."],
	"torpedo": ["Torpedo Launcher", Color(0.9, 0.85, 0.3), "TL", "Hits may fire heat-seeking torpedoes that explode."],
	"bow_grow_bow": ["Bow Grow Bow", Color(1.0, 0.3, 0.55), "BB", "Wear the bow: a much bigger bow wave to batter with."],
}

var id := ""
var stacks := 0
var run: UnnaturalRun
var fish: FishController
var settings: PowerupSettings


static func create(powerup_id: String) -> Powerup:
	var made: Powerup
	match powerup_id:
		"greek_fire":
			made = GreekFire.new()
		"chain_lightning":
			made = ChainLightning.new()
		"torpedo":
			made = TorpedoLauncher.new()
		"bow_grow_bow":
			made = BowGrowBow.new()
		_:
			made = Powerup.new()
	made.id = powerup_id
	return made


static func ids() -> Array[String]:
	var all: Array[String] = []
	for key: String in INFO:
		all.append(key)
	return all


static func title(powerup_id: String) -> String:
	return INFO[powerup_id][0] if INFO.has(powerup_id) else powerup_id


static func color(powerup_id: String) -> Color:
	return INFO[powerup_id][1] if INFO.has(powerup_id) else Color.WHITE


static func tag(powerup_id: String) -> String:
	return INFO[powerup_id][2] if INFO.has(powerup_id) else "?"


static func blurb(powerup_id: String) -> String:
	return INFO[powerup_id][3] if INFO.has(powerup_id) else ""


## Rolls `chance` (0..1).
func roll(chance: float) -> bool:
	return chance > 0.0 and run.rng.randf() < chance


func on_hit(_index: int, _damage: float, _source: String, _proc: float, _chain: Array) -> void:
	pass


func on_kill(_at: Vector3, _source: String) -> void:
	pass


func on_battery(_index: int) -> void:
	pass


func on_tick(_delta: float) -> void:
	pass


func on_stride(_timing: float) -> void:
	pass


func on_stacks_changed() -> void:
	pass


## Going away (the run's ending or restarting): undo anything on the fish.
func on_removed() -> void:
	pass
