class_name Limits
## Unnatural's limiters (planning_unnatural.md, "Playability pass" P4, §1.6 of
## the brainstorm): the curves that keep stacking from multiplying past the
## difficulty curve. Each is switched by UnnaturalSettings' Limits group
## (limits off: everything adds up in a line, as before P4).
## - stack_value(): an item's later stacks add less (100%, 60%, 43%... at a
##   falloff of 0.67);
## - chance(): a chance that only nears 100% (crit, procs, Megalodon's share);
## - soft_cap(): past a cap a stat grows at a share of its rate (Size).
## The cooldown floor (min_cooldown) is FishAttack's.


## How many stacks `stacks` are worth: the first counts 1, the k-th (from 0)
## 1 / (1 + falloff x k). A falloff of 0 is a straight line (n stacks, n).
static func stack_value(stacks: int, falloff: float) -> float:
	if stacks <= 0:
		return 0.0
	if falloff <= 0.0:
		return float(stacks)
	var total := 0.0
	for k in stacks:
		total += 1.0 / (1.0 + falloff * k)
	return total


## A chance of `raw` (what its stacks and stats add up to) bent so it never
## reaches 1: raw / (1 + raw ^ p) ^ (1 / p), p `softness`. Near 0 it's `raw`;
## at raw 1 it's 1 / 2 ^ (1 / p) (0.71 at p 2). The higher p, the longer it
## stays straight before it bends. `softness` 0: raw, capped at 1.
static func chance(raw: float, softness: float) -> float:
	if raw <= 0.0:
		return 0.0
	if softness <= 0.0:
		return minf(raw, 1.0)
	return raw / pow(1.0 + pow(raw, softness), 1.0 / softness)


## `value` up to `cap`, and past it `rate` of the rest (rate 1, or cap 0: no cap).
static func soft_cap(value: float, cap: float, rate: float) -> float:
	if cap <= 0.0 or value <= cap:
		return value
	return cap + (value - cap) * rate


## A stat's value as play uses it (StatBlock.value()): Crit Chance bent by
## chance(), Size soft-capped. The rest as they are.
static func stat(id: String, raw: float, settings: UnnaturalSettings) -> float:
	if settings == null or not settings.limits:
		return raw
	match id:
		"crit_chance":
			return chance(raw, settings.chance_softness)
		"size":
			return soft_cap(raw, settings.size_soft_cap, settings.size_soft_rate)
	return raw
