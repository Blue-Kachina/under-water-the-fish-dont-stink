class_name RaceHandling
extends RefCounted
## Same speed, different handling (planning_race.md section 3): the per-class and per-family table of what differs
## between racers once top speed, acceleration and stride push are shared (RaceSettings.shared_modifiers). Every
## value is a factor around 1.0 and a first guess, not tuned (play-test before changing them; flexible-tuning: the
## panel can override a class's row through RaceSettings later, this table is only the defaults).
##   turn_scale     the fish's "turn" and "rl_turn" modifiers: how sharp it turns (clownfish sharp, whales wide)
##   coast          speed kept off throttle: the "drag" modifier is 1 / coast (Ray glides, Boxfish drops off)
##   weight         bump mass (relative): heavier bodies push lighter ones aside (D4); kept at true size, not the cap's
##   stream_grip    how much a bubble stream speeds it up (x RaceSettings.stream_push)
##   slip_gain      how much it gains in a slipstream (x RaceSettings.slip_gain)
##   skill_cooldown a factor on its mobility skill's own cooldown (x RaceSettings.skill_cooldown_scale)
## The classes start from their Traversal twists (Nimble, Glide, Streamlined ...) so they play the way players know.

## Row per FishCharacter.FishClass (fish, and the class a Hunter form or Titan wears when it has none of its own).
const CLASS := {
	FishCharacter.FishClass.SKIRMISHER: {"turn_scale": 1.15, "coast": 0.95, "weight": 0.8, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.HUNTER: {"turn_scale": 0.95, "coast": 1.05, "weight": 1.1, "stream_grip": 1.0, "slip_gain": 1.1, "skill_cooldown": 1.0},
	FishCharacter.FishClass.GLIDER: {"turn_scale": 0.9, "coast": 1.3, "weight": 0.9, "stream_grip": 1.2, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.LANCER: {"turn_scale": 0.85, "coast": 1.1, "weight": 1.0, "stream_grip": 0.9, "slip_gain": 1.2, "skill_cooldown": 1.0},
	FishCharacter.FishClass.CHARMER: {"turn_scale": 1.05, "coast": 1.0, "weight": 0.9, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.BULWARK: {"turn_scale": 0.9, "coast": 0.8, "weight": 1.3, "stream_grip": 0.9, "slip_gain": 0.9, "skill_cooldown": 1.0},
	FishCharacter.FishClass.SCORCHER: {"turn_scale": 1.0, "coast": 1.0, "weight": 0.95, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.DRIFTER: {"turn_scale": 0.8, "coast": 1.15, "weight": 0.85, "stream_grip": 1.3, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.BRAWLER: {"turn_scale": 1.1, "coast": 0.9, "weight": 1.0, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.BREACHER: {"turn_scale": 0.9, "coast": 1.1, "weight": 1.4, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
	FishCharacter.FishClass.ALCHEMIST: {"turn_scale": 0.95, "coast": 1.0, "weight": 1.0, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
}
## Family multipliers on top of the class row (Hunter forms and Titans have no mobility skill of their own: they
## borrow the SKIRMISHER's twist unless the entry names another; see RaceRoster.entry "skill_class").
const FAMILY := {
	RaceRoster.FISH: {"turn_scale": 1.0, "coast": 1.0, "weight": 1.0, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0},
	RaceRoster.HUNTER: {"turn_scale": 0.85, "coast": 1.1, "weight": 2.0, "stream_grip": 1.0, "slip_gain": 1.2, "skill_cooldown": 1.3},
	RaceRoster.TITAN: {"turn_scale": 0.7, "coast": 1.2, "weight": 3.5, "stream_grip": 1.1, "slip_gain": 1.5, "skill_cooldown": 1.6},
}
## Per Titan species (index = species) factors on `weight`: the bigger whale is the heavier.
const TITAN_WEIGHT := [1.0, 0.85, 0.6, 1.1, 1.6]
## Neutral row (an unknown class or family).
const NEUTRAL := {"turn_scale": 1.0, "coast": 1.0, "weight": 1.0, "stream_grip": 1.0, "slip_gain": 1.0, "skill_cooldown": 1.0}


## The handling row for a RaceRoster entry: class row x family row (x the Titan species' weight).
static func of(entry: Dictionary) -> Dictionary:
	var row: Dictionary = (CLASS.get(int(entry.get("skill_class", entry.get("class", -1))), NEUTRAL) as Dictionary).duplicate()
	var fam: Dictionary = FAMILY.get(str(entry.get("family", RaceRoster.FISH)), NEUTRAL)
	for key: String in row:
		row[key] = float(row[key]) * float(fam[key])
	if str(entry.get("family", "")) == RaceRoster.TITAN:
		row["weight"] = float(row["weight"]) * float(TITAN_WEIGHT[clampi(int(entry.get("species", 0)), 0, TITAN_WEIGHT.size() - 1)])
	return row


## The FishModifiers set (push under RaceMatch.MODS_HANDLING) for a handling row: turn, rl_turn and drag.
static func modifiers(row: Dictionary) -> Dictionary:
	var turn := float(row["turn_scale"])
	return {"turn": turn, "rl_turn": turn, "drag": 1.0 / maxf(float(row["coast"]), 0.1)}
