class_name CardDeck
## Unnatural's level-up cards (planning_unnatural.md, "Playability pass" P1b):
## each card is drawn from four kinds, by UnnaturalSettings' weights:
## - "weapon": upgrade a weapon you hold (below weapon_max_level), raising the
##   facets its rarity rolls (Weapons.roll);
## - "tome": upgrade a tome you hold (below tome_max_level);
## - "new_weapon": a weapon you don't hold, only while a weapon slot is free;
## - "new_tome": likewise a tome, only while a tome slot is free.
## A level's cards are all different. When fewer real ones are left than
## card_choices, the rest are "fallback" cards: a pearl purse, or a team heal.
##
## Each card: {"kind", "tier", ...}: a weapon's has "weapon", "level" (what it
## becomes) and "gains" (facet id -> amount); a tome's has "tome", "level" and
## "gives" (stat -> amount); a fallback's has "what" ("pearls", "heal") and
## "amount".


## `count` cards for `fish` at the team's level now.
static func deal(run: UnnaturalRun, fish: FishController, count: int) -> Array:
	var settings := run.settings
	var loadout := run.loadout_of(fish)
	var attack := run.attack_of(fish)
	if attack:
		loadout.attack_kind = attack.kind
	var luck := run.block_of(fish).value("luck")
	# What each kind could offer.
	var pools := {
		"weapon": loadout.upgradable_weapons(settings.weapon_max_level),
		"tome": loadout.upgradable_tomes(settings.tome_max_level),
		"new_weapon": [] as Array[String],
		"new_tome": [] as Array[String],
	}
	if loadout.weapons.size() < settings.weapon_slots:
		for id in Weapons.card_pool(attack.kind if attack else FishAttack.Kind.NONE):
			if not loadout.has_weapon(id):
				pools.new_weapon.append(id)
	if loadout.tomes.size() < settings.tome_slots:
		for id in Tomes.ids():
			if not loadout.has_tome(id) and tome_useful(run, fish, id):
				pools.new_tome.append(id)
	var weights := {
		"weapon": settings.card_weight_weapon,
		"tome": settings.card_weight_tome,
		"new_weapon": settings.card_weight_new_weapon,
		"new_tome": settings.card_weight_new_tome,
	}
	var cards := []
	while cards.size() < count:
		var kind := _pick_kind(run.rng, pools, weights)
		if kind == "":
			break
		var pool: Array = pools[kind]
		var id: String = pool.pop_at(run.rng.randi_range(0, pool.size() - 1))
		var tier := Rarity.roll(run.rng, settings, luck)
		match kind:
			"weapon":
				cards.append({"kind": "weapon", "weapon": id, "tier": tier, "level": loadout.earned_level(id) + 1,
						"gains": Weapons.roll(run.rng, id, loadout.attack_kind, tier, settings, run.powerup_settings)})
			"new_weapon":
				# No fixed rarity: it rolls one like any card, and arrives with that rarity's facets raised.
				cards.append({"kind": "new_weapon", "weapon": id, "tier": tier, "level": 1,
						"gains": Weapons.roll(run.rng, id, loadout.attack_kind, tier, settings, run.powerup_settings)})
			"tome", "new_tome":
				cards.append({"kind": kind, "tome": id, "tier": tier, "level": loadout.tome_level(id) + 1,
						"gives": Tomes.gives(id, Rarity.multiplier(settings, tier), settings)})
	var fallbacks := ["pearls", "heal"]
	while cards.size() < count and not fallbacks.is_empty():
		var what: String = fallbacks.pop_front()
		if what == "pearls" and settings.fallback_pearls > 0:
			cards.append({"kind": "fallback", "what": "pearls", "tier": Rarity.Tier.COMMON,
					"amount": roundi(settings.fallback_pearls * (1.0 + run.levels.level / 10.0))})
		elif what == "heal" and settings.fallback_heal > 0.0:
			cards.append({"kind": "fallback", "what": "heal", "tier": Rarity.Tier.COMMON, "amount": settings.fallback_heal})
	return cards


## Whether tome `id` would do anything for `fish`: Schools only if their attack
## fires projectiles; Ages only if they hold something that lasts.
static func tome_useful(run: UnnaturalRun, fish: FishController, id: String) -> bool:
	match id:
		"schools":
			var attack := run.attack_of(fish)
			if attack != null and attack.uses_stat("projectile_count"):
				return true
			for held: String in run.loadout_of(fish).weapons:
				if FishAttack.kind_uses_stat(Weapons.attack_kind_of(held), "projectile_count"):
					return true
			return false
		"ages":
			var loadout := run.loadout_of(fish)
			var powerups := run.powerups_of(fish)
			for user in Tomes.DURATION_USERS:
				if loadout.has_weapon(user) or powerups.stacks(user) > 0:
					return true
			return false
	return true


## A kind with something left, by weight ("" if none has).
static func _pick_kind(rng: RandomNumberGenerator, pools: Dictionary, weights: Dictionary) -> String:
	var total := 0.0
	for kind: String in pools:
		if not (pools[kind] as Array).is_empty():
			total += maxf(weights[kind], 0.0)
	if total <= 0.0:
		# Every weight left is 0: take whatever has something.
		for kind: String in pools:
			if not (pools[kind] as Array).is_empty():
				return kind
		return ""
	var roll := rng.randf() * total
	for kind: String in pools:
		if (pools[kind] as Array).is_empty():
			continue
		roll -= maxf(weights[kind], 0.0)
		if roll < 0.0:
			return kind
	return ""


## The line under a level's heading: what slots are full.
static func slot_line(run: UnnaturalRun, fish: FishController) -> String:
	var loadout := run.loadout_of(fish)
	return "WEAPONS %d/%d  ·  TOMES %d/%d" % [loadout.weapons.size(), run.settings.weapon_slots, loadout.tomes.size(),
			run.settings.tome_slots]
