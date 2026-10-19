class_name FishDetails
extends RefCounted
## What the fish picker's Details panel says about a fish: its starting attack,
## the stat it grows by itself every level, and its traversal twist (a passive
## nobody would otherwise find). Built from the live tables and settings
## (FishAttack, StatBlock, Traversal, UnnaturalSettings), so tweaking a twist's
## numbers changes what's shown here (refining_weaponry.md §2.15).

## Each attack's one-line description (its numbers are in the Weapons tables).
const BLURBS := {
	FishAttack.Kind.STING: "A pulse round the fish, hurting every zombie in range. Only fires when something is close.",
	FishAttack.Kind.BITE: "Spectral jaws snap shut on the zombie ahead of you. Hits hard, one target at a time.",
	FishAttack.Kind.LASH: "A tail whip at the nearest zombie that arcs on to others. Fast, and the best single-target damage.",
	FishAttack.Kind.THRUST: "A spear at the nearest zombie in front that pierces through the ones behind it.",
	FishAttack.Kind.BUBBLES: "A volley of homing bubbles that pop in a splash. Gentle, and hard to dodge.",
	FishAttack.Kind.SPINES: "A ring of spines fired out all round when zombies crowd in. Pierces two.",
}


## The panel's text for `family`: an Array of [heading, body] pairs.
static func sections(family: FishCharacter.Family) -> Array:
	var s := UnnaturalSettings.shared()
	var attack_kind := FishAttack.kind_for(family)
	var signature := StatBlock.signature(family)
	var out := []
	out.append(["Starting weapon  ·  %s" % FishAttack.title(attack_kind), BLURBS.get(attack_kind, "")])
	out.append(["Grows by itself  ·  %s" % StatBlock.title(signature),
			"Every level up gives %s, on top of the cards you pick." % StatBlock.describe(signature, StatBlock.amount(signature))])
	out.append(["Twist  ·  %s" % Traversal.title(family), twist_text(family, s)])
	out.append(["Base", "%d HP  ·  %.1f s of i-frames after a hit. Every fish starts with the same base stats; the weapon, the signature stat and the twist set them apart." % [roundi(s.base_hp), s.iframes]])
	return out


## What `family`'s twist does, with the numbers live from `s`.
static func twist_text(family: FishCharacter.Family, s: UnnaturalSettings) -> String:
	match family:
		FishCharacter.Family.OCTANE:
			return "Nimble: turns %d%% faster than the others, so it slips between zombies." % roundi((s.nimble_turn - 1.0) * 100.0)
		FishCharacter.Family.DOMINUS:
			return "Frenzy: every kill adds +%d%% swim speed (up to +%d%%), held for %.0f s after the last kill, then it fades. Keep killing to keep it." % [
					roundi(s.frenzy_per_kill * 100.0), roundi(s.frenzy_max * 100.0), s.frenzy_time]
		FishCharacter.Family.PLANK:
			return "Glide: coasting keeps only %d%% of the usual drag, so one stroke carries it much further." % roundi(s.glide_drag * 100.0)
		FishCharacter.Family.BREAKOUT:
			return "Dash: a dodge launches it %.0f m/s along the dodge and makes it untouchable for %.1f s." % [s.dash_speed, s.dash_iframes]
		FishCharacter.Family.HYBRID:
			return "Leap: a jump also leaps %.0f m/s upward; at the top it splashes down for %.0f damage to every zombie within %.0f m. Ready again after %.1f s." % [
					s.leap_impulse, s.leap_damage, s.leap_radius, s.leap_cooldown]
		FishCharacter.Family.MERC:
			return "Armoured: takes only %d%% of the damage, but swims %d%% slower." % [roundi(s.armour_taken * 100.0), roundi((1.0 - s.armour_speed) * 100.0)]
	return ""
