class_name FishDetails
extends RefCounted
## What the home screen's Class details panel says about a fish: its starting
## attack, the stat it grows by itself every level, its passive twist and its
## mobility skill (a passive nobody would otherwise find). Built from the live
## tables and settings (FishAttack, StatBlock, Traversal, UnnaturalSettings), so
## tweaking a twist's numbers changes what's shown here (refining_weaponry.md §2.15).
## The headline numbers are kept out of the sentences (the panel shows them big).

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
	FishAttack.Kind.HAZE: "Ink bombs lob at the thickest pack near you and burst into purple clouds that hurt and slow everything inside. A near miss still pays: the pack drifts in.",
	FishAttack.Kind.REMORA: "Remoras ride along and nip the nearest zombie in turn. Steady, safe damage.",
	FishAttack.Kind.PUNCH: "A boxing glove knocks back the zombie in front, then the bubble it leaves collapses and hits again round it.",
}
## Each attack's two short tags (the chips under its blurb).
const TAGS := {
	FishAttack.Kind.STING: ["Hits all in range", "Close range"],
	FishAttack.Kind.BITE: ["Single target", "Hits hard"],
	FishAttack.Kind.LASH: ["Chains on", "Fast"],
	FishAttack.Kind.THRUST: ["Pierces", "Aims ahead"],
	FishAttack.Kind.BUBBLES: ["Homing", "Splash"],
	FishAttack.Kind.SPINES: ["All round", "Pierces two"],
	FishAttack.Kind.FIRE: ["Burning trail", "Faster burns more"],
	FishAttack.Kind.HALO: ["Orbits you", "Steady"],
	FishAttack.Kind.HAZE: ["Lobbed", "Slows"],
	FishAttack.Kind.REMORA: ["Companions", "Safe"],
	FishAttack.Kind.PUNCH: ["Knockback", "Short range"],
}


## The panel's facts for `fish_class`, live from the settings:
## weapon_id (its glyph), weapon, blurb, tags; signature_id, signature,
## signature_amount ("+10%"); passive, passive_text,
## passive_stat ([value, label], or [] for none); skill, skill_text,
## skill_stats ([[value, label], ...]); hp, iframes.
static func details(fish_class: FishCharacter.FishClass) -> Dictionary:
	var s := UnnaturalSettings.shared()
	var attack_kind := FishAttack.kind_for(fish_class)
	var signature := StatBlock.signature(fish_class)
	var passive_info := passive(fish_class, s)
	var skill_info := skill(fish_class, s)
	return {
		"weapon_id": FishAttack.weapon_id_of(attack_kind),
		"weapon": FishAttack.title(attack_kind),
		"blurb": BLURBS.get(attack_kind, ""),
		"tags": TAGS.get(attack_kind, []),
		"signature_id": signature,
		"signature": StatBlock.title(signature),
		"signature_amount": StatBlock.amount_text(signature, StatBlock.signature_amount(fish_class, s.signature_steps, s)),
		"passive": Traversal.title(fish_class),
		"passive_text": passive_info[0],
		"passive_stat": passive_info[1],
		"skill": Traversal.skill_title(fish_class),
		"skill_text": skill_info[0],
		"skill_stats": skill_info[1],
		"hp": roundi(s.base_hp),
		"iframes": s.iframes,
	}


## What `fish_class`'s twist does: [sentence, [headline value, its label] or []].
static func passive(fish_class: FishCharacter.FishClass, s: UnnaturalSettings) -> Array:
	match fish_class:
		FishCharacter.FishClass.SKIRMISHER:
			return ["Turns faster than the others, so it slips between zombies.", [_pct(s.nimble_turn - 1.0, true), "turn speed"]]
		FishCharacter.FishClass.HUNTER:
			return ["Every kill adds swim speed (up to %s), held for %.0f s after the last kill, then it fades. Keep killing to keep it." % [
					_pct(s.frenzy_max, true), s.frenzy_time], [_pct(s.frenzy_per_kill, true), "speed a kill"]]
		FishCharacter.FishClass.GLIDER:
			return ["Coasting keeps only part of the usual drag, so one stroke carries it much further.", [_pct(s.glide_drag), "drag coasting"]]
		FishCharacter.FishClass.LANCER:
			return ["Swims faster than the others.", [_pct(s.streamline_speed, true), "swim speed"]]
		FishCharacter.FishClass.CHARMER:
			return ["More untouchable time after every hit.", ["+%.1f s" % s.graceful_iframes, "i-frames"]]
		FishCharacter.FishClass.BULWARK:
			return ["Takes far less damage, but swims %s slower." % _pct(1.0 - s.armour_speed), [_pct(s.armour_taken), "damage taken"]]
		FishCharacter.FishClass.SCORCHER:
			return ["Greek Fire burns harder the closer you swim to battering speed.", [_pct(s.wake_damage, true), "fire, at most"]]
		FishCharacter.FishClass.DRIFTER:
			return ["More jellies orbit in its Halo.", ["+%d" % s.arms_extra, "jelly" if s.arms_extra == 1 else "jellies"]]
		FishCharacter.FishClass.BRAWLER:
			return ["A zombie your punches knock back flies into the others, hurting up to %d of them." % s.heavy_max, [_pct(s.heavy_share), "of the punch"]]
		FishCharacter.FishClass.BREACHER:
			return ["Holding still, it heals.", ["%.1f" % s.escort_regen, "HP a second"]]
		FishCharacter.FishClass.ALCHEMIST:
			return ["A zombie that touches you is coated for %.0f s: slowed %s, and Purple Haze hurts it more." % [s.coat_time, _pct(s.coat_slow)],
					[_pct(s.coat_bonus, true), "Haze damage"]]
	return ["", []]


## What `fish_class`'s mobility skill (the boost button: RB, Shift) does:
## [sentence, [[value, label], ...]].
static func skill(fish_class: FishCharacter.FishClass, s: UnnaturalSettings) -> Array:
	var cooldown := func(seconds: float) -> Array: return ["%.1f s" % seconds, "cooldown"]
	match fish_class:
		FishCharacter.FishClass.SKIRMISHER:
			return ["A burst sideways, the way you lean the stick (else backwards).",
					[_speed(s.wriggle_speed, "burst"), ["%.1f s" % s.wriggle_iframes, "untouchable"], cooldown.call(s.wriggle_cooldown)]]
		FishCharacter.FishClass.HUNTER:
			return ["Charges ahead for %.2f s, untouchable, battering everything in the way." % s.fin_dash_time,
					[_speed(s.fin_dash_speed, "charge"), ["%.0f" % s.fin_damage, "damage each"], cooldown.call(s.fin_cooldown)]]
		FishCharacter.FishClass.GLIDER:
			return ["A stroke forward, then no drag at all for %.1f s." % s.surge_time,
					[_speed(s.surge_speed, "stroke"), cooldown.call(s.surge_cooldown)]]
		FishCharacter.FishClass.LANCER:
			return ["A burst along its nose.",
					[_speed(s.dash_speed, "burst"), ["%.1f s" % s.dash_iframes, "untouchable"], cooldown.call(s.dash_cooldown)]]
		FishCharacter.FishClass.CHARMER:
			return ["Leaps upward; at the top it splashes down on every zombie within %.0f m." % s.leap_radius,
					[_speed(s.leap_impulse, "leap"), ["%.0f" % s.leap_damage, "splash damage"], cooldown.call(s.leap_cooldown)]]
		FishCharacter.FishClass.BULWARK:
			return ["Braces for a hit: takes far less damage, and swims %s slower meanwhile." % _pct(1.0 - s.brace_speed),
					[[_pct(s.brace_taken), "damage taken"], ["%.1f s" % s.brace_time, "lasts"], cooldown.call(s.brace_cooldown)]]
		FishCharacter.FishClass.SCORCHER:
			return ["Dashes for %.2f s with its spines flared, hurting everything within %.0f m on the way." % [s.flare_time, s.flare_radius],
					[_speed(s.flare_speed, "dash"), ["%.0f" % s.flare_damage, "damage"], cooldown.call(s.flare_cooldown)]]
		FishCharacter.FishClass.DRIFTER:
			return ["Switches its stink off: nothing fires, and zombies lose track of it. Hits end it; press again to end it early.",
					[["%.0f s" % s.quiet_time, "at most"], cooldown.call(s.quiet_cooldown)]]
		FishCharacter.FishClass.BRAWLER:
			return ["A full Cavitation Punch one way; the recoil throws you the other, the way you lean the stick (else backwards).",
					[_speed(s.recoil_speed, "recoil"), ["%.1f s" % s.recoil_iframes, "untouchable"], cooldown.call(s.recoil_cooldown)]]
		FishCharacter.FishClass.BREACHER:
			return ["Sucks in every zombie in a cone ahead, hurting each.",
					[["%.0f m" % s.gulp_range, "reach"], ["%.0f" % s.gulp_damage, "damage each"], cooldown.call(s.gulp_cooldown)]]
		FishCharacter.FishClass.ALCHEMIST:
			return ["Big flaps carry you up and forward over the pack, and a Purple Haze cloud bursts where you took off.",
					[["%d" % s.flutter_flaps, "flaps"], cooldown.call(s.flutter_cooldown)]]
	return ["", []]


## `fraction` as a whole percentage ("40%", or "+40%" with `signed`).
static func _pct(fraction: float, signed := false) -> String:
	return ("+" if signed else "") + "%d%%" % roundi(fraction * 100.0)


static func _speed(metres_a_second: float, label: String) -> Array:
	return ["%.0f m/s" % metres_a_second, label]
