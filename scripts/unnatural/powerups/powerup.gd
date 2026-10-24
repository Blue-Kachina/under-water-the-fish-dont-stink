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
## - on_hurt(amount, from), blocks_hit(amount): the fish hurt, or about to be
## - stat_bonus(): stats it adds (Powerups puts them on the StatBlock)
## - on_stacks_changed(): stacks went up (or the testing override changed).
## INFO has each one's name, colour and short tag; create() makes one by id.

## Id -> [name, colour, tag, what it does, rarity (Rarity.Tier)]. A chest
## rolls a rarity with the opener's luck and offers powerups of it. What it
## does: one effect a line ("\n" between), the stat first then its change; a
## line starting "!" is a curse's downside. A weapon's rarity isn't used (its
## cards roll their own).
const INFO := {
	"kelp_wrap": ["Kelp Wrap", Color(0.35, 0.75, 0.35), "KW", "Regen +0.5 HP/s", Rarity.Tier.COMMON],
	"sea_salt": ["Sea Salt", Color(0.95, 0.95, 1.0), "SA", "Crit Chance +5%", Rarity.Tier.COMMON],
	"coral_knuckles": ["Coral Knuckles", Color(1.0, 0.5, 0.45), "CK", "Battery Damage +20%", Rarity.Tier.COMMON],
	"divers_goggles": ["Diver's Goggles", Color(0.3, 0.75, 0.95), "DG", "Pickup Range +25%", Rarity.Tier.COMMON],
	"lucky_sand_dollar": ["Lucky Sand Dollar", Color(0.95, 0.88, 0.7), "LD", "Luck +0.1", Rarity.Tier.COMMON],
	"sticky_anemone": ["Sticky Anemone", Color(1.0, 0.55, 0.8), "AN", "Hits: 10% chance to slow a zombie 40% for 2 s", Rarity.Tier.COMMON],
	"ink_sac": ["Ink Sac", Color(0.45, 0.35, 0.6), "IS", "When hurt: an ink cloud blinds zombies near you for 2 s", Rarity.Tier.COMMON],
	"lamprey": ["Lamprey", Color(0.55, 0.5, 0.6), "LP", "Heal per kill +1 HP", Rarity.Tier.UNCOMMON],
	"clam_shield": ["Clam Shield", Color(0.9, 0.8, 0.85), "CS", "Blocks a hit every 12 s", Rarity.Tier.UNCOMMON],
	"momentum_fin": ["Momentum Fin", Color(0.7, 0.95, 0.6), "MF", "Damage +10% per 10 m/s you swim", Rarity.Tier.UNCOMMON],
	"treasure_map": ["Treasure Map", Color(0.85, 0.7, 0.4), "TM", "Chest Drops +30%\nChest Ping Range +10 m", Rarity.Tier.UNCOMMON],
	"sonar_pinger": ["Sonar Pinger", Color(0.4, 0.95, 0.85), "SP", "Every 6 s a pulse marks the zombies near you\nDamage to marked zombies +25%", Rarity.Tier.UNCOMMON],
	"cold_seep": ["Cold Seep", Color(0.65, 0.9, 1.0), "CO", "Hits: 8% chance to freeze a zombie for 1.5 s", Rarity.Tier.UNCOMMON],
	"whirlpool_charm": ["Whirlpool Charm", Color(0.35, 0.7, 0.95), "WC", "Kills: 6% chance to open a whirlpool that pulls zombies in and grinds them", Rarity.Tier.UNCOMMON],
	"attack_greek_fire": ["Greek Fire Trail", Color(1.0, 0.45, 0.1), "GF", "Burning patches behind you burn the zombies in them.", Rarity.Tier.UNCOMMON],
	"chain_lightning": ["Chain Lightning", Color(0.45, 0.8, 1.0), "CL", "Hits may start lightning that jumps between zombies.", Rarity.Tier.UNCOMMON],
	"torpedo": ["Torpedo Launcher", Color(0.9, 0.85, 0.3), "TL", "Hits may fire heat-seeking torpedoes that explode.", Rarity.Tier.RARE],
	"krakens_grasp": ["Kraken's Grasp", Color(0.7, 0.3, 0.55), "KG", "Hits: 5% chance a tentacle slams the area\nZombies it hits are held still", Rarity.Tier.RARE],
	"ghost_swordfish": ["Ghost Swordfish", Color(0.75, 0.85, 1.0), "GS", "Every 3 s a phantom swordfish dashes through a line of zombies", Rarity.Tier.RARE],
	"ammonite_spiral": ["Ammonite Spiral", Color(0.9, 0.75, 0.55), "AS", "Projectile hits split into 3 shards", Rarity.Tier.RARE],
	"riptide": ["Riptide", Color(0.3, 0.55, 0.9), "RT", "Perfectly timed strides leave a current behind you\nZombies in it are dragged back and hurt", Rarity.Tier.RARE],
	"reef_guardian": ["Reef Guardian", Color(1.0, 0.5, 0.4), "RG", "Under 25% HP: untouchable for 3 s\nRecharges in 60 s", Rarity.Tier.RARE],
	"bioluminescence": ["Bioluminescence", Color(0.5, 1.0, 0.7), "BL", "Level-ups and chests send out a flash\nFlash damage grows with your level", Rarity.Tier.RARE],
	"bow_grow_bow": ["Bow Grow Bow", Color(1.0, 0.3, 0.55), "BB", "Bow Wave: much bigger, to batter with", Rarity.Tier.COMMON],
	"barnacle_plating": ["Barnacle Plating", Color(0.8, 0.75, 0.62), "BP", "Armour +2", Rarity.Tier.COMMON],
	"hermit_shell": ["Hermit Shell", Color(0.95, 0.6, 0.45), "HS", "Max HP +15", Rarity.Tier.COMMON],
	"fizzy_soda": ["Fizzy Soda", Color(0.55, 1.0, 0.75), "FS", "Attack Speed +8%", Rarity.Tier.COMMON],
	"speedy_seahorse": ["Speedy Seahorse", Color(1.0, 0.8, 0.3), "SH", "Swim Speed +6%", Rarity.Tier.COMMON],
	"attack_remora_buddy": ["Remora Buddy", Color(0.62, 0.68, 0.8), "RB", "A remora rides along, nipping the nearest zombie. More: more remoras.", Rarity.Tier.COMMON],
	"bubble_wrap": ["Bubble Wrap", Color(0.7, 0.9, 1.0), "BW", "Blocks the next hit after 8 s untouched", Rarity.Tier.COMMON],
	"pufferfish_spines": ["Pufferfish Spines", Color(0.95, 0.85, 0.4), "PS", "Zombies that touch you take damage back\nSpines burst out when you're touched", Rarity.Tier.UNCOMMON],
	"attack_jellyfish_halo": ["Jellyfish Halo", Color(0.85, 0.5, 1.0), "JH", "Jellies orbit you, stinging what they touch.", Rarity.Tier.UNCOMMON],
	"electric_eel": ["Electric Eel", Color(0.4, 1.0, 0.9), "EE", "Batteries send out a shock ring", Rarity.Tier.UNCOMMON],
	"attack_depth_charges": ["Depth Charges", Color(0.6, 0.66, 0.55), "DC", "Drops mines behind you that blow up the zombies that follow.", Rarity.Tier.RARE],
	"anglerfish_lure": ["Anglerfish Lure", Color(0.6, 1.0, 0.5), "AL", "Drops a glowing decoy the zombies chase\nIt bursts after a while", Rarity.Tier.RARE],
	"tsunami_heart": ["Tsunami Heart", Color(0.3, 0.6, 1.0), "TH", "Batteries send a wave rolling along your heading", Rarity.Tier.LEGENDARY],
	"poseidons_trident": ["Poseidon's Trident", Color(0.4, 0.75, 1.0), "PT", "Every 3rd attack calls lightning down on the biggest zombie near", Rarity.Tier.LEGENDARY],
	"megalodon_tooth": ["Megalodon Tooth", Color(0.95, 0.92, 0.85), "MT", "Crits finish off zombies under 15% HP (not bosses)", Rarity.Tier.LEGENDARY],
	"moon_pearl": ["Moon Pearl", Color(0.85, 0.88, 1.0), "MP", "Level-Up Picks +1", Rarity.Tier.LEGENDARY],
	"abyssal_engine": ["Abyssal Engine", Color(0.5, 0.25, 0.75), "AE", "Projectiles +1\nSize +15%", Rarity.Tier.LEGENDARY],
	"attack_leviathans_coil": ["Leviathan's Coil", Color(0.85, 0.15, 0.2), "LC", "A trail of coils behind you hurts whatever they touch.", Rarity.Tier.BOSS],
	"attack_sting": ["Anemone Sting", Color(1.0, 0.55, 0.3), "ST", "A stinging pulse all round you hits everything inside.", Rarity.Tier.COMMON],
	"attack_bite": ["Ghost Bite", Color(0.7, 0.85, 1.0), "GB", "Huge spectral jaws snap shut on the zombies ahead.", Rarity.Tier.COMMON],
	"attack_lash": ["Shock Lash", Color(0.5, 0.8, 1.0), "SL", "Your tail whips the nearest zombie, and the shock arcs on.", Rarity.Tier.COMMON],
	"attack_thrust": ["Bill Thrust", Color(0.95, 0.9, 0.6), "BT", "Spears of light fly ahead, piercing a line of zombies.", Rarity.Tier.COMMON],
	"attack_bubbles": ["Bubble Volley", Color(0.6, 0.9, 1.0), "BV", "Homing bubbles pop on the nearest zombies.", Rarity.Tier.COMMON],
	"attack_spines": ["Spine Burst", Color(0.95, 0.8, 0.45), "SB", "Spines burst out every way when zombies come close.", Rarity.Tier.COMMON],
	"blood_moon_shard": ["Blood Moon Shard", Color(0.9, 0.1, 0.15), "BM", "Damage +100%\n!Damage Taken +50%", Rarity.Tier.CURSED],
	"glass_coral": ["Glass Coral", Color(1.0, 0.55, 0.65), "GC", "Damage +100%\n!Max HP -50%", Rarity.Tier.CURSED],
	"sirens_song": ["Siren's Song", Color(0.75, 0.45, 0.95), "SS", "XP Gain +100%\n!Zombies +50%", Rarity.Tier.CURSED],
	"abyssal_hunger": ["Abyssal Hunger", Color(0.45, 0.1, 0.25), "AH", "Kills heal you\n!HP -2% a second", Rarity.Tier.CURSED],
	"sunken_idol": ["Sunken Idol", Color(0.75, 0.6, 0.3), "SI", "Chest Picks +1\n!Each stage event takes a powerup", Rarity.Tier.CURSED],
}

var id := ""
var stacks := 0
var run: UnnaturalRun
var fish: FishController
var settings: PowerupSettings
## It doesn't hear hits, or add to hits on a zombie (bonus_on): set by the base
## hooks the first time they run (an item that overrides them never sets them),
## so Powerups stops calling them on every hit (the perf pass).
var deaf := false
var no_bonus := false
## Its look on the fish (make_worn()), while held.
var _worn: Node3D


static func create(powerup_id: String) -> Powerup:
	var made: Powerup
	match powerup_id:
		"chain_lightning":
			made = ChainLightning.new()
		"torpedo":
			made = TorpedoLauncher.new()
		"bow_grow_bow":
			made = BowGrowBow.new()
		"barnacle_plating", "hermit_shell", "fizzy_soda", "speedy_seahorse", "kelp_wrap", "sea_salt", "coral_knuckles", "divers_goggles", "lucky_sand_dollar":
			made = StatPowerup.new()
		"lamprey":
			made = Lamprey.new()
		"clam_shield":
			made = ClamShield.new()
		"momentum_fin":
			made = MomentumFin.new()
		"treasure_map":
			made = TreasureMap.new()
		"bubble_wrap":
			made = BubbleWrap.new()
		"pufferfish_spines":
			made = PufferfishSpines.new()
		"electric_eel":
			made = ElectricEel.new()
		"anglerfish_lure":
			made = AnglerfishLure.new()
		"tsunami_heart":
			made = TsunamiHeart.new()
		"blood_moon_shard", "glass_coral", "sirens_song", "abyssal_hunger", "sunken_idol":
			made = CursedPowerup.new()
		_ when Weapons.ATTACK_WEAPONS.has(powerup_id):
			made = AttackWeapon.new()
		"sticky_anemone", "cold_seep", "krakens_grasp":
			made = HitProc.new()
		"ink_sac":
			made = InkSac.new()
		"sonar_pinger":
			made = SonarPinger.new()
		"whirlpool_charm":
			made = WhirlpoolCharm.new()
		"ghost_swordfish":
			made = GhostSwordfish.new()
		"ammonite_spiral":
			made = AmmoniteSpiral.new()
		"riptide":
			made = Riptide.new()
		"reef_guardian":
			made = ReefGuardian.new()
		"bioluminescence":
			made = Bioluminescence.new()
		"poseidons_trident":
			made = PoseidonsTrident.new()
		"megalodon_tooth", "moon_pearl", "abyssal_engine":
			made = LegendaryPassive.new()
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


## What it does, as one line (its effects joined).
static func blurb(powerup_id: String) -> String:
	return ". ".join(blurb_lines(powerup_id) + curse_lines(powerup_id))


## Its upsides, one effect a line.
static func blurb_lines(powerup_id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in _lines(powerup_id):
		if not line.begins_with("!"):
			lines.append(line)
	var cap := cap_line(powerup_id)
	if cap != "" and not is_weapon(powerup_id):
		lines.append(cap)
	return lines


## A curse's downsides, one a line.
static func curse_lines(powerup_id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in _lines(powerup_id):
		if line.begins_with("!"):
			lines.append(line.substr(1))
	return lines


static func _lines(powerup_id: String) -> PackedStringArray:
	return (INFO[powerup_id][3] as String).split("\n", false) if INFO.has(powerup_id) else PackedStringArray()


static func tier(powerup_id: String) -> int:
	return INFO[powerup_id][4] if INFO.has(powerup_id) else Rarity.Tier.COMMON


## Up to `count` different powerups for a chest of rarity `rolled`: its own
## first, then the tiers below it (nearest first), then above, each tier's in
## a random order. Items only: weapons come from level-up cards. `left_out`:
## ids not to offer (banished, P4, or already showing).
static func pick_for_chest(rng: RandomNumberGenerator, rolled: int, count: int, left_out: Array = []) -> Array[String]:
	var order: Array[int] = [rolled]
	for t in range(rolled - 1, -1, -1):
		order.append(t)
	for t in range(rolled + 1, Rarity.Tier.LEGENDARY + 1):
		order.append(t)
	var picked: Array[String] = []
	for t in order:
		for id in pick_from_tier(rng, t, count - picked.size(), left_out):
			picked.append(id)
	return picked


## Up to `count` different powerups of tier `wanted`, in a random order.
static func pick_from_tier(rng: RandomNumberGenerator, wanted: int, count: int, left_out: Array = []) -> Array[String]:
	var pool: Array[String] = []
	for id in ids():
		if tier(id) == wanted and not is_weapon(id) and id not in left_out:
			pool.append(id)
	var picked: Array[String] = []
	while not pool.is_empty() and picked.size() < count:
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## Whether `powerup_id` is a weapon (Weapons): it levels up from cards, and
## chests don't offer it.
static func is_weapon(powerup_id: String) -> bool:
	return powerup_id in Weapons.POWERUPS


## Rolls `chance` (0..1).
func roll(chance: float) -> bool:
	return chance > 0.0 and run.rng.randf() < chance


## The most power a capped proc (torpedoes in flight, lightning and slams a
## second) keeps for its next one, so a long cap can't build one absurd hit.
const BANK_MAX := 25.0


## A proc's roll that keeps what's past certain (the perf pass): 0 if it
## failed, 1 if it went off, or `chance` itself when that's over 1 (an area
## hit's few rolls each stand for many zombies). Callers make the proc that
## much stronger, so power isn't lost when work is saved.
func proc_power(chance: float) -> float:
	if chance >= 1.0:
		return chance
	return 1.0 if roll(chance) else 0.0


## Plain stat items, which flatten slower (stack_falloff_stats).
const STAT_ITEMS: Array[String] = ["barnacle_plating", "hermit_shell", "fizzy_soda", "speedy_seahorse", "kelp_wrap", "sea_salt",
		"coral_knuckles", "divers_goggles", "lucky_sand_dollar"]


## How fast `powerup_id`'s stacks flatten out (P4's stacking curves; Limits.stack_value).
static func falloff_for(powerup_id: String, from: UnnaturalSettings) -> float:
	if from == null or not from.limits or tier(powerup_id) == Rarity.Tier.CURSED or is_weapon(powerup_id):
		return 0.0
	if powerup_id in STAT_ITEMS:
		return from.stack_falloff_stats
	if tier(powerup_id) == Rarity.Tier.LEGENDARY:
		return from.stack_falloff_legendary
	return from.stack_falloff


## What its stacks are worth (P4): the first 1, later ones less and less
## (Limits.stack_value, falloff_for()). Items read this, not `stacks`.
func eff() -> float:
	return Limits.stack_value(stacks, falloff_for(id, run.settings if run else UnnaturalSettings.shared()))


## What its stacks past the first are worth (eff() - 1): the "+ per stack" part.
func extra() -> float:
	return maxf(eff() - 1.0, 0.0)


## A proc chance as play uses it: bent short of 100% (Limits.chance) with the
## limits on, else as it is.
func soft_chance(raw: float) -> float:
	var from := run.settings if run else UnnaturalSettings.shared()
	return Limits.chance(raw, from.chance_softness) if from.limits else raw


## Its effect cap, the visible rule ("At most 48 torpedoes out"; "": none).
static func cap_line(powerup_id: String) -> String:
	var p := PowerupSettings.shared()
	match powerup_id:
		"torpedo":
			return "At most %d torpedoes in the water" % p.torpedo_max
		"chain_lightning":
			return "At most %d strikes a second" % roundi(p.lightning_max_rate)
		"krakens_grasp":
			return "At most %s slams a second" % _num(p.kraken_max_rate)
		"whirlpool_charm":
			return "At most %d whirlpools out" % p.charm_max
		"ammonite_spiral":
			return "At most %d splits a second" % roundi(p.ammonite_max_rate)
		"anglerfish_lure":
			return "At most %d lures out" % p.lure_max
		"riptide":
			return "At most %d currents out" % p.riptide_max
		"electric_eel":
			return "At most one ring every %s s" % _num(p.eel_cooldown)
		"tsunami_heart":
			return "At most one wave every %s s" % _num(p.tsunami_cooldown)
		"megalodon_tooth":
			return "Up to %d%% HP" % roundi(p.tooth_execute_max * 100.0)
		"attack_greek_fire":
			return "At most %d patches out (+ upgrades)" % p.fire_max_patches
		"attack_depth_charges":
			return "At most %d mines out (+ upgrades)" % p.charge_max
	return ""


static func _num(x: float) -> String:
	return str(roundi(x)) if absf(x - roundf(x)) < 0.05 else "%.1f" % x


## A weapon's facet `facet_id` (its total from upgrades, Loadout.facet).
func facet(facet_id: String) -> float:
	return run.loadout_of(fish).facet(id, facet_id) if run and is_instance_valid(fish) else 0.0


## A weapon's whole-number facet (a count).
func facet_count(facet_id: String) -> int:
	return roundi(facet(facet_id))


## Whether a weapon has reached milestone `n` (1 to 4: Lv milestone_first to milestone_fourth).
func milestone(n: int) -> bool:
	if run == null or n <= 0:
		return false
	var at := run.settings.milestone_level(n)
	return at > 0 and stacks >= at


## 1 + the player's Duration (Tome of Ages): how much longer timed effects last.
func duration_scale() -> float:
	return 1.0 + run.block_of(fish).value("duration") if run and is_instance_valid(fish) else 1.0


## 1 + the player's Attack Speed (Tome of Tides): how much faster timed weapons fire/drop/tick.
func rate_scale() -> float:
	return maxf(1.0 + run.block_of(fish).value("attack_speed"), 0.1) if run and is_instance_valid(fish) else 1.0


## 1 + the player's Size (Tome of the Reef): how much bigger weapons' reach and blasts are.
func size_scale() -> float:
	return maxf(1.0 + run.block_of(fish).value("size"), 0.1) if run and is_instance_valid(fish) else 1.0


## A hit by the fish (UnnaturalRun.hit(), or once for each of a few of an area
## hit's zombies: `proc` is then bigger, and past certain it's the proc's
## strength, proc_power()). An override must not call this one: it marks the
## item deaf, and it's never called again.
func on_hit(_index: int, _damage: float, _source: String, _proc: float, _chain: Array) -> void:
	deaf = true


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


## The fish was hurt by `amount`, by zombie `from` (-1: not a zombie's touch).
func on_hurt(_amount: float, _from: int) -> void:
	pass


## Whether it takes this hit instead of the fish (Bubble Wrap).
func blocks_hit(_amount: float) -> bool:
	return false


## What it adds to the player's stats (stat id -> amount, as StatBlock's), at
## its stacks now.
func stat_bonus() -> Dictionary:
	return {}


## Multiplies the damage the fish takes (Blood Moon Shard), its max hp (Glass
## Coral) and how many zombies come (Siren's Song).
func taken_factor() -> float:
	return 1.0


func max_hp_factor() -> float:
	return 1.0


func horde_factor() -> float:
	return 1.0


## Multiplies the damage this player deals right now (Momentum Fin), how often
## their kills drop chests (Treasure Map), and how far chests are pinged (m, added).
func damage_factor() -> float:
	return 1.0


func chest_drop_factor() -> float:
	return 1.0


func chest_ping_bonus() -> float:
	return 0.0


## How much more its hits do to zombie `index` (Sonar Pinger's marks: 0.25 = +25%).
func bonus_on(_index: int) -> float:
	no_bonus = true  # (an override never gets here: see `deaf`)
	return 0.0


## The share of its hp under which a crit finishes a zombie (Megalodon Tooth; 0: none).
func execute_share() -> float:
	return 0.0


## More cards to take from each level-up's offer (Moon Pearl).
func extra_level_picks() -> int:
	return 0


## A stage event started (a swarm, a boss).
func on_stage_event(_event: String) -> void:
	pass


## Going away (the run's ending or restarting): undo anything on the fish.
func on_removed() -> void:
	pass


## Its look on the fish, built fresh (null: none): every powerup is worn, and
## grows a little with each stack (Powerups puts it on, wear()).
func make_worn() -> Node3D:
	return null


## Puts its look on the fish (once), sized by its stacks.
func wear() -> void:
	if not is_instance_valid(fish):
		return
	if _worn == null or not is_instance_valid(_worn):
		_worn = make_worn()
		if _worn == null:
			return
		fish.add_child(_worn)
	_worn.scale = Vector3.ONE * minf(1.0 + 0.15 * (stacks - 1), 2.0)


## Takes its look off the fish.
func take_off() -> void:
	if _worn and is_instance_valid(_worn):
		if _worn.get_parent():
			_worn.get_parent().remove_child(_worn)  # off now, not at the frame's end
		_worn.queue_free()
	_worn = null


## A glowing material in this powerup's colour, for its look.
func worn_material(glow := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color(id)
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = color(id)
	material.emission_energy_multiplier = glow
	return material


static func worn_mesh(mesh: Mesh, material: Material, at: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = turn
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part
