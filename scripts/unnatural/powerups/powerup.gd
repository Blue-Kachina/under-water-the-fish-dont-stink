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
## rolls a rarity with the opener's luck and offers powerups of it.
const INFO := {
	"kelp_wrap": ["Kelp Wrap", Color(0.35, 0.75, 0.35), "KW", "+0.5 HP a second: kelp ribbons mend you as you swim.", Rarity.Tier.COMMON],
	"sea_salt": ["Sea Salt", Color(0.95, 0.95, 1.0), "SA", "+5% crit chance.", Rarity.Tier.COMMON],
	"coral_knuckles": ["Coral Knuckles", Color(1.0, 0.5, 0.45), "CK", "+20% battery damage: coral on the nose.", Rarity.Tier.COMMON],
	"divers_goggles": ["Diver's Goggles", Color(0.3, 0.75, 0.95), "DG", "+25% pickup range: you spot pearls from further.", Rarity.Tier.COMMON],
	"lucky_sand_dollar": ["Lucky Sand Dollar", Color(0.95, 0.88, 0.7), "LD", "+0.1 luck: better cards and chests.", Rarity.Tier.COMMON],
	"lamprey": ["Lamprey", Color(0.55, 0.5, 0.6), "LP", "Every kill heals you 1 HP.", Rarity.Tier.UNCOMMON],
	"clam_shield": ["Clam Shield", Color(0.9, 0.8, 0.85), "CS", "Every 12 s a clam takes the next hit for you.", Rarity.Tier.UNCOMMON],
	"momentum_fin": ["Momentum Fin", Color(0.7, 0.95, 0.6), "MF", "Hit harder the faster you swim: +10% per 10 m/s.", Rarity.Tier.UNCOMMON],
	"treasure_map": ["Treasure Map", Color(0.85, 0.7, 0.4), "TM", "Zombies drop 30% more chests, and chests are pinged further.", Rarity.Tier.UNCOMMON],
	"greek_fire": ["Greek Fire Trail", Color(1.0, 0.45, 0.1), "GF", "Burning patches behind you burn the zombies in them.", Rarity.Tier.UNCOMMON],
	"chain_lightning": ["Chain Lightning", Color(0.45, 0.8, 1.0), "CL", "Hits may start lightning that jumps between zombies.", Rarity.Tier.UNCOMMON],
	"torpedo": ["Torpedo Launcher", Color(0.9, 0.85, 0.3), "TL", "Hits may fire heat-seeking torpedoes that explode.", Rarity.Tier.RARE],
	"bow_grow_bow": ["Bow Grow Bow", Color(1.0, 0.3, 0.55), "BB", "Wear the bow: a much bigger bow wave to batter with.", Rarity.Tier.COMMON],
	"barnacle_plating": ["Barnacle Plating", Color(0.8, 0.75, 0.62), "BP", "+2 armour: every hit you take is smaller.", Rarity.Tier.COMMON],
	"hermit_shell": ["Hermit Shell", Color(0.95, 0.6, 0.45), "HS", "+15 max HP.", Rarity.Tier.COMMON],
	"fizzy_soda": ["Fizzy Soda", Color(0.55, 1.0, 0.75), "FS", "+8% attack speed.", Rarity.Tier.COMMON],
	"speedy_seahorse": ["Speedy Seahorse", Color(1.0, 0.8, 0.3), "SH", "+6% swim speed.", Rarity.Tier.COMMON],
	"remora_buddy": ["Remora Buddy", Color(0.62, 0.68, 0.8), "RB", "A remora rides along, nipping the nearest zombie. More: more remoras.", Rarity.Tier.COMMON],
	"bubble_wrap": ["Bubble Wrap", Color(0.7, 0.9, 1.0), "BW", "After 8 s untouched, a bubble takes the next hit for you.", Rarity.Tier.COMMON],
	"pufferfish_spines": ["Pufferfish Spines", Color(0.95, 0.85, 0.4), "PS", "Zombies that touch you get it back, and spines burst out.", Rarity.Tier.UNCOMMON],
	"jellyfish_halo": ["Jellyfish Halo", Color(0.85, 0.5, 1.0), "JH", "Jellies orbit you, stinging what they touch.", Rarity.Tier.UNCOMMON],
	"electric_eel": ["Electric Eel", Color(0.4, 1.0, 0.9), "EE", "Batteries send out a shock ring.", Rarity.Tier.UNCOMMON],
	"depth_charges": ["Depth Charges", Color(0.6, 0.66, 0.55), "DC", "Drops mines behind you that blow up the zombies that follow.", Rarity.Tier.RARE],
	"anglerfish_lure": ["Anglerfish Lure", Color(0.6, 1.0, 0.5), "AL", "Drops a glowing decoy the zombies chase. Then it bursts.", Rarity.Tier.RARE],
	"tsunami_heart": ["Tsunami Heart", Color(0.3, 0.6, 1.0), "TH", "Batteries send a wave rolling along your heading.", Rarity.Tier.LEGENDARY],
	"leviathans_coil": ["Leviathan's Coil", Color(0.85, 0.15, 0.2), "LC", "A trail of coils behind you hurts whatever they touch.", Rarity.Tier.BOSS],
	"blood_moon_shard": ["Blood Moon Shard", Color(0.9, 0.1, 0.15), "BM", "+100% damage. You take +50% damage.", Rarity.Tier.CURSED],
	"glass_coral": ["Glass Coral", Color(1.0, 0.55, 0.65), "GC", "+100% damage. Your max HP is halved.", Rarity.Tier.CURSED],
	"sirens_song": ["Siren's Song", Color(0.75, 0.45, 0.95), "SS", "Double XP. 50% more zombies come.", Rarity.Tier.CURSED],
	"abyssal_hunger": ["Abyssal Hunger", Color(0.45, 0.1, 0.25), "AH", "Kills heal you. You lose 2% HP a second.", Rarity.Tier.CURSED],
	"sunken_idol": ["Sunken Idol", Color(0.75, 0.6, 0.3), "SI", "One more pick from every chest. Each stage event takes a powerup.", Rarity.Tier.CURSED],
}

var id := ""
var stacks := 0
var run: UnnaturalRun
var fish: FishController
var settings: PowerupSettings
## Its look on the fish (make_worn()), while held.
var _worn: Node3D


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
		"remora_buddy":
			made = RemoraBuddy.new()
		"bubble_wrap":
			made = BubbleWrap.new()
		"pufferfish_spines":
			made = PufferfishSpines.new()
		"jellyfish_halo":
			made = JellyfishHalo.new()
		"electric_eel":
			made = ElectricEel.new()
		"depth_charges":
			made = DepthCharges.new()
		"anglerfish_lure":
			made = AnglerfishLure.new()
		"tsunami_heart":
			made = TsunamiHeart.new()
		"leviathans_coil":
			made = LeviathansCoil.new()
		"blood_moon_shard", "glass_coral", "sirens_song", "abyssal_hunger", "sunken_idol":
			made = CursedPowerup.new()
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


static func tier(powerup_id: String) -> int:
	return INFO[powerup_id][4] if INFO.has(powerup_id) else Rarity.Tier.COMMON


## Up to `count` different powerups for a chest of rarity `rolled`: its own
## first, then the tiers below it (nearest first), then above, each tier's in
## a random order. Items only: weapons come from level-up cards.
static func pick_for_chest(rng: RandomNumberGenerator, rolled: int, count: int) -> Array[String]:
	var order: Array[int] = [rolled]
	for t in range(rolled - 1, -1, -1):
		order.append(t)
	for t in range(rolled + 1, Rarity.Tier.LEGENDARY + 1):
		order.append(t)
	var picked: Array[String] = []
	for t in order:
		for id in pick_from_tier(rng, t, count - picked.size()):
			picked.append(id)
	return picked


## Up to `count` different powerups of tier `wanted`, in a random order.
static func pick_from_tier(rng: RandomNumberGenerator, wanted: int, count: int) -> Array[String]:
	var pool: Array[String] = []
	for id in ids():
		if tier(id) == wanted and not is_weapon(id):
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


## 1 + the player's Area (Tome of the Reef): how much bigger weapons' reach and blasts are.
func area_scale() -> float:
	return maxf(1.0 + run.block_of(fish).value("area"), 0.1) if run and is_instance_valid(fish) else 1.0


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
