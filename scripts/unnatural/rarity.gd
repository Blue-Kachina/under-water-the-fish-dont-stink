class_name Rarity
## Card rarity in Unnatural (planning_unnatural.md §6): common, uncommon, rare,
## epic, legendary. Each card rolls its own: the tiers' base weights
## (UnnaturalSettings, 60/25/10/4/1 by default), each multiplied by
## (1 + luck * luck_effect) ^ tier, so luck pushes the rolls up the tiers
## (luck 0.5 roughly doubles epic and quintuples legendary). A tier's
## multiplier scales what the card gives.

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const NAMES := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
## Card frames: grey, green, blue, purple, gold.
const COLORS := [Color(0.62, 0.64, 0.66), Color(0.3, 0.8, 0.35), Color(0.25, 0.55, 1.0), Color(0.68, 0.32, 0.95), Color(1.0, 0.76, 0.2)]


static func weights(settings: UnnaturalSettings, luck: float) -> PackedFloat32Array:
	var base := PackedFloat32Array([settings.weight_common, settings.weight_uncommon, settings.weight_rare,
			settings.weight_epic, settings.weight_legendary])
	var lift := maxf(1.0 + luck * settings.luck_effect, 0.0)
	var total := 0.0
	for tier in base.size():
		base[tier] = maxf(base[tier], 0.0) * pow(lift, tier)
		total += base[tier]
	if total <= 0.0:
		base[0] = 1.0
		total = 1.0
	for tier in base.size():
		base[tier] /= total
	return base


## A tier, rolled with `luck`.
static func roll(rng: RandomNumberGenerator, settings: UnnaturalSettings, luck: float) -> int:
	var shares := weights(settings, luck)
	var at := rng.randf()
	for tier in shares.size():
		at -= shares[tier]
		if at < 0.0:
			return tier
	return Tier.COMMON


static func multiplier(settings: UnnaturalSettings, tier: int) -> float:
	return [settings.multiplier_common, settings.multiplier_uncommon, settings.multiplier_rare,
			settings.multiplier_epic, settings.multiplier_legendary][clampi(tier, 0, 4)]
