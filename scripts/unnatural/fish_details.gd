class_name FishDetails
extends RefCounted
## What the fish picker's Details panel says about a fish: its starting attack,
## the stat it grows by itself every level, its passive twist and its mobility skill (a passive
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
	FishAttack.Kind.FIRE: "Swimming leaves a trail of burning patches that scorch every zombie that crosses them. The faster you swim, the more you burn.",
	FishAttack.Kind.HALO: "Jellyfish orbit you and sting whatever comes close. A slow, steady shield of damage.",
	FishAttack.Kind.HAZE: "Ink bombs lob at the thickest pack near you, wherever it is, and burst into purple clouds that hurt and slow everything inside for a few seconds. A near miss still pays: the pack drifts in.",
	FishAttack.Kind.REMORA: "Remoras ride along and nip the nearest zombie in turn. Steady, safe damage.",
	FishAttack.Kind.PUNCH: "A boxing glove punches the zombie in front, hard enough to knock it back, then the bubble it leaves collapses and hits again round it. Short range: get close.",
}


## The panel's text for `fish_class`: an Array of [heading, body] pairs.
static func sections(fish_class: FishCharacter.FishClass) -> Array:
	var s := UnnaturalSettings.shared()
	var attack_kind := FishAttack.kind_for(fish_class)
	var signature := StatBlock.signature(fish_class)
	var out := []
	out.append(["Starting weapon  ·  %s" % FishAttack.title(attack_kind), BLURBS.get(attack_kind, "")])
	out.append(["Grows by itself  ·  %s" % StatBlock.title(signature),
			"Every level up gives %s, on top of the cards you pick." % StatBlock.describe(signature, StatBlock.signature_amount(fish_class, s.signature_steps, s))])
	out.append(["Passive  ·  %s" % Traversal.title(fish_class), twist_text(fish_class, s)])
	out.append(["Mobility (RB)  ·  %s" % Traversal.skill_title(fish_class), skill_text(fish_class, s)])
	out.append(["Base", "%d HP  ·  %.1f s of i-frames after a hit. Every class starts with the same base stats; the weapon, the signature stat and the twist set them apart." % [roundi(s.base_hp), s.iframes]])
	return out


## What `fish_class`'s twist does, with the numbers live from `s`.
static func twist_text(fish_class: FishCharacter.FishClass, s: UnnaturalSettings) -> String:
	match fish_class:
		FishCharacter.FishClass.SKIRMISHER:
			return "Nimble: turns %d%% faster than the others, so it slips between zombies." % roundi((s.nimble_turn - 1.0) * 100.0)
		FishCharacter.FishClass.HUNTER:
			return "Frenzy: every kill adds +%d%% swim speed (up to +%d%%), held for %.0f s after the last kill, then it fades. Keep killing to keep it." % [
					roundi(s.frenzy_per_kill * 100.0), roundi(s.frenzy_max * 100.0), s.frenzy_time]
		FishCharacter.FishClass.GLIDER:
			return "Glide: coasting keeps only %d%% of the usual drag, so one stroke carries it much further." % roundi(s.glide_drag * 100.0)
		FishCharacter.FishClass.LANCER:
			return "Streamlined: swims %d%% faster than the others." % roundi(s.streamline_speed * 100.0)
		FishCharacter.FishClass.CHARMER:
			return "Graceful: %.1f s more of untouchable time after every hit." % s.graceful_iframes
		FishCharacter.FishClass.BULWARK:
			return "Armoured: takes only %d%% of the damage, but swims %d%% slower." % [roundi(s.armour_taken * 100.0), roundi((1.0 - s.armour_speed) * 100.0)]
		FishCharacter.FishClass.SCORCHER:
			return "Wake: Greek Fire burns up to +%d%% harder the closer you swim to battering speed." % roundi(s.wake_damage * 100.0)
		FishCharacter.FishClass.DRIFTER:
			return "Many Arms: %d more jelly%s in its Halo." % [s.arms_extra, "" if s.arms_extra == 1 else "s"]
		FishCharacter.FishClass.BRAWLER:
			return "Heavy Hitter: a zombie your punches knock back flies into the others, hurting up to %d of them for %d%% of the punch." % [s.heavy_max, roundi(s.heavy_share * 100.0)]
		FishCharacter.FishClass.BREACHER:
			return "Escort: holding still, it heals %.1f HP a second." % s.escort_regen
		FishCharacter.FishClass.ALCHEMIST:
			return "Unpalatable: a zombie that touches you is coated for %.0f s: slowed %d%%, and Purple Haze hurts it %d%% more." % [s.coat_time, roundi(s.coat_slow * 100.0), roundi(s.coat_bonus * 100.0)]
	return ""


## What `fish_class`'s mobility skill (the boost button: RB, Shift) does, live from `s`.
static func skill_text(fish_class: FishCharacter.FishClass, s: UnnaturalSettings) -> String:
	match fish_class:
		FishCharacter.FishClass.SKIRMISHER:
			return "Wriggle: a burst of %.0f m/s sideways (the way you lean the stick, else backwards), untouchable for %.1f s. Ready again after %.1f s." % [s.wriggle_speed, s.wriggle_iframes, s.wriggle_cooldown]
		FishCharacter.FishClass.HUNTER:
			return "Fin Dash: charges ahead at %.0f m/s for %.2f s, untouchable, battering everything in the way for %.0f damage each. Ready again after %.1f s." % [s.fin_dash_speed, s.fin_dash_time, s.fin_damage, s.fin_cooldown]
		FishCharacter.FishClass.GLIDER:
			return "Surge: a stroke of %.0f m/s forward, and no drag at all for %.1f s. Ready again after %.1f s." % [s.surge_speed, s.surge_time, s.surge_cooldown]
		FishCharacter.FishClass.LANCER:
			return "Dash: a burst of %.0f m/s along its nose, untouchable for %.1f s. Ready again after %.1f s." % [s.dash_speed, s.dash_iframes, s.dash_cooldown]
		FishCharacter.FishClass.CHARMER:
			return "Leap: leaps %.0f m/s upward; at the top it splashes down for %.0f damage to every zombie within %.0f m. Ready again after %.1f s." % [s.leap_impulse, s.leap_damage, s.leap_radius, s.leap_cooldown]
		FishCharacter.FishClass.BULWARK:
			return "Brace: for %.1f s it takes only %d%% of the damage (and swims %d%% slower). Ready again after %.1f s." % [s.brace_time, roundi(s.brace_taken * 100.0), roundi((1.0 - s.brace_speed) * 100.0), s.brace_cooldown]
		FishCharacter.FishClass.SCORCHER:
			return "Flare Dash: dashes %.0f m/s for %.2f s with its spines flared, %.0f damage to everything within %.0f m on the way. Ready again after %.1f s." % [s.flare_speed, s.flare_time, s.flare_damage, s.flare_radius, s.flare_cooldown]
		FishCharacter.FishClass.DRIFTER:
			return "Go Quiet: switches its stink off for up to %.0f s. Nothing fires, and zombies lose track of it. Hits end it; press again to end it early. Then %.1f s before the next." % [s.quiet_time, s.quiet_cooldown]
		FishCharacter.FishClass.BRAWLER:
			return "Recoil Dash: throws a full Cavitation Punch one way and the recoil throws you %.0f m/s the other, untouchable for %.1f s. You go the way you lean the stick (else backwards), so by default it punches what's ahead and shoots you back out of the crowd. Ready again after %.1f s." % [s.recoil_speed, s.recoil_iframes, s.recoil_cooldown]
		FishCharacter.FishClass.BREACHER:
			return "Gulp: sucks every zombie in a %.0f m cone ahead in, hurting each for %.0f. Ready again after %.1f s." % [s.gulp_range, s.gulp_damage, s.gulp_cooldown]
		FishCharacter.FishClass.ALCHEMIST:
			return "Flutter: %d big flaps carry you up and forward over the pack, and a Purple Haze cloud bursts where you took off. Ready again after %.1f s." % [s.flutter_flaps, s.flutter_cooldown]
	return ""
