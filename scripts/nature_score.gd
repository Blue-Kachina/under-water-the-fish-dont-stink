class_name NatureScore
extends RefCounted
## Nature's points, Unreal Tournament style: every fish battered scores, and
## battered fish in quick succession chain into multis, each louder than the last,
## while a run of them without slowing down is a spree.
##
## - **Multi:** a battery within multi_window (s) of the last one adds to the
##   chain: Battered, Double Dip, Triple Fry, Fish Supper, Feeding Frenzy, then
##   Monster Catch. Each step past the first scores multi_bonus x (chain + 1).
## - **Spree:** battered fish since the player was last under the battering speed for
##   more than spree_grace (s). Every spree_step of them is a milestone (Spring
##   Roll, Riptide, Apex Predator, Unstoppable, Poseidon), worth spree_bonus x
##   the milestone.
##
## Values come from NatureSettings, live. The run calls on_battery() for each
## fish battered, update() every physics tick and on_strode() for each stride.
## For a player on another machine (online co-op) there's none of that here:
## their relayed events go to add_remote(), which keeps the scoreboard's numbers.

signal awarded(event: Dictionary)

const BATTERY := "battery"
const MULTI := "multi"
const SPREE := "spree"
## The multi's name by chain length (1 is a plain battery; past the end, the last).
const MULTI_TITLES := ["BATTERED", "BATTERED", "DOUBLE DIP", "TRIPLE FRY", "FISH SUPPER", "FEEDING FRENZY", "MONSTER CATCH"]
## The spree's name by milestone (1 is the first, spree_step battered fish in).
const SPREE_TITLES := ["", "SPRING ROLL", "RIPTIDE", "APEX PREDATOR", "UNSTOPPABLE", "POSEIDON"]

var settings: NatureSettings
var points := 0
## The current chain and spree.
var chain := 0
var spree := 0
## The best of each this run.
var best_chain := 0
var best_spree := 0
## Seconds left to extend the chain (0: none going).
var chain_left := 0.0
## For the scoreboard: perfect strides and the top speed (m/s) this run.
var perfect := 0
var top_speed := 0.0
var _slow_for := 0.0


func _init(score_settings: NatureSettings) -> void:
	settings = score_settings


## Starts afresh (a new run).
func reset() -> void:
	points = 0
	chain = 0
	spree = 0
	best_chain = 0
	best_spree = 0
	chain_left = 0.0
	perfect = 0
	top_speed = 0.0
	_slow_for = 0.0


static func multi_title(length: int) -> String:
	return MULTI_TITLES[mini(length, MULTI_TITLES.size() - 1)]


static func spree_title(milestone: int) -> String:
	return SPREE_TITLES[mini(milestone, SPREE_TITLES.size() - 1)]


## The chain counts down; slow too long and the spree ends.
func update(delta: float, speed: float, batter_speed: float) -> void:
	top_speed = maxf(top_speed, speed)
	if chain_left > 0.0:
		chain_left = maxf(chain_left - delta, 0.0)
		if chain_left == 0.0:
			chain = 0
	if speed < batter_speed:
		_slow_for += delta
		if _slow_for > settings.spree_grace:
			spree = 0
	else:
		_slow_for = 0.0


## A fish battered: scores it, extends the chain and the spree, and announces
## what that makes (awarded). Returns the chain it's part of.
func on_battery() -> int:
	chain = chain + 1 if chain_left > 0.0 else 1
	chain_left = settings.multi_window
	spree += 1
	_slow_for = 0.0
	best_chain = maxi(best_chain, chain)
	best_spree = maxi(best_spree, spree)
	var scale := settings.points_scale
	var earned := roundi(settings.battery_points * scale)
	var event := {"type": BATTERY, "title": multi_title(chain), "chain": chain, "spree": spree, "points": earned}
	if chain >= 2:
		var bonus := roundi(settings.multi_bonus * (chain + 1) * scale)
		earned += bonus
		event.type = MULTI
		event.points = earned
		event.bonus = bonus
	points += earned
	awarded.emit(event)
	if settings.spree_step > 0 and spree % settings.spree_step == 0:
		var milestone := spree / settings.spree_step
		var bonus := roundi(settings.spree_bonus * milestone * scale)
		points += bonus
		awarded.emit({"type": SPREE, "title": spree_title(milestone), "milestone": milestone, "spree": spree, "points": bonus})
	return chain


## A stride (FishController.strode): perfect ones count.
func on_strode(timing: float) -> void:
	if timing >= SwishySwim.SWEET_SPOT:
		perfect += 1


## Another machine's player's event (relayed): its points, and the best chain,
## spree, perfect strides and top speed it carries (see stats()).
func add_remote(event: Dictionary) -> void:
	points += int(event.get("points", 0))
	if event.get("type") != SPREE:
		best_chain = maxi(best_chain, int(event.get("chain", 0)))
	best_spree = maxi(best_spree, int(event.get("spree", 0)))
	perfect = maxi(perfect, int(event.get("perfect", 0)))
	top_speed = maxf(top_speed, float(event.get("top_speed", 0.0)))


## The scoreboard's running numbers, to send along with an event.
func stats() -> Dictionary:
	return {"perfect": perfect, "top_speed": top_speed}


## Everything, for a guest joining late.
func save() -> Dictionary:
	return {"points": points, "chain": best_chain, "spree": best_spree, "perfect": perfect, "top_speed": top_speed}


## save()'s numbers, here.
func restore(saved: Dictionary) -> void:
	points = int(saved.get("points", 0))
	best_chain = int(saved.get("chain", 0))
	best_spree = int(saved.get("spree", 0))
	perfect = int(saved.get("perfect", 0))
	top_speed = float(saved.get("top_speed", 0.0))
