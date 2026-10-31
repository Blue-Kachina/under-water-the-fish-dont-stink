extends Node
## The boss items (planning_bosses_and_survival.md §2): never offered by a
## level-up card, a treasure or cursed chest, a shrine's chest or the Shark's
## legendary pick; outside the item limits (every stack counts in full);
## no weapon slot; each has a glyph, a stacks override and its sounds; the old
## Coil weapon id maps to the item; the Test Tank gives them at N stacks;
## boss_item_every_player off lets the first opener take it from everyone; and
## each one works: the Coil at its level, Gulper's Maw swallows and spits,
## Hagfish Brood bites, knots and slimes, Queen's Disc drains the toughest and
## heals, Angel's Crown lashes the cone and heals on kills, Drowned Jaws chomps.
##   Godot_console.exe --headless --path . res://tests/boss_items_probe.tscn
## In a window, -- --shots=DIR also saves a screenshot of each item at work.

const ITEMS: Array[String] = ["leviathans_coil", "gulpers_maw", "hagfish_brood", "queens_disc", "angels_crown", "drowned_jaws"]

var failures := 0
var main: Node
var fish: FishController
var run: UnnaturalRun
var horde: Horde
var settings := UnnaturalSettings.shared()
var powers := PowerupSettings.shared()
var shots_dir := ""


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # chest picks pause the game
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	settings.spawning = false
	settings.chest_cost = false
	settings.chest_count = 0
	settings.shrine_count = 0
	settings.stage_events = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 3
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 0.0
	settings.enemy_damage_scale = 0.0
	settings.base_hp = 1000.0
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("never offered:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var leaked := {}
	for n in 400:
		for rolled in Rarity.Tier.LEGENDARY + 1:
			for id in Powerup.pick_for_chest(rng, rolled, 3):
				if Powerup.is_boss_drop(id):
					leaked[id] = true
		for id in Powerup.pick_from_tier(rng, Rarity.Tier.CURSED, 3):
			if Powerup.is_boss_drop(id):
				leaked[id] = true
	check(leaked.is_empty(), "no chest pool, any tier, cursed or the Shark's and the Deep's legendary picks (%s)" % [leaked.keys()])
	var in_chests := {}
	for n in 300:
		for kind: int in [TreasureChest.Kind.TREASURE, TreasureChest.Kind.CURSED]:
			for card: Dictionary in run._chest_cards(fish, kind, []):
				if Powerup.is_boss_drop(card.powerup):
					in_chests[card.powerup] = true
	check(in_chests.is_empty(), "nor a treasure or cursed chest's cards, rerolls too (%s)" % [in_chests.keys()])
	var on_cards := {}
	for n in 300:
		for card: Dictionary in CardDeck.deal(run, fish, 3):
			for key: String in ["weapon", "powerup"]:
				if card.has(key) and (Powerup.is_boss_drop(card[key]) or card[key] == "attack_leviathans_coil"):
					on_cards[card[key]] = true
	check(on_cards.is_empty(), "nor a level-up card (%s)" % [on_cards.keys()])
	settings.card_choices = 0  # (the items' kills level up: no pause for the cards from here)
	check("attack_leviathans_coil" not in Weapons.POWERUPS and not Powerup.is_weapon("leviathans_coil"), "the Coil is no weapon now")

	print("outside the limits:")
	settings.limits = true
	var straight := true
	for id in ITEMS:
		straight = straight and Powerup.falloff_for(id, settings) == 0.0
	check(straight and Powerup.falloff_for("megalodon_tooth", settings) > 0.0, "boss items' stacks never flatten (a legendary's do)")
	powers.maw_stacks = 3
	run.powerups_of(fish).refresh()
	check(is_equal_approx((run.powerups_of(fish).held["gulpers_maw"] as Powerup).eff(), 3.0), "3 stacks count as 3, limits on")
	powers.maw_stacks = 0
	run.powerups_of(fish).refresh()

	print("each one's parts:")
	var whole := true
	for id in ITEMS:
		var ok: bool = Powerup.INFO.has(id) and HexBadge.has_glyph(id) and PowerupSettings.STACKS.has(id) and Powerup.create(id).get_script() != Powerup \
				and HexBadge.shape_of(id) == HexBadge.Shape.HEX
		if not ok:
			print("    missing a part: ", id)
		whole = whole and ok
		whole = whole and (Powerup.tier(id) == Rarity.Tier.BOSS) == (id != "drowned_jaws")
	check(whole, "each has its INFO row, glyph (a hexagon), stacks override and class; all boss tier but Drowned Jaws (legendary)")
	var sounds := true
	for sound in ["unnatural/chest_boss_item", "pw/maw_suck", "pw/maw_spit", "pw/brood_bite", "pw/disc_latch", "pw/disc_drain",
			"pw/crown_burst", "pw/crown_lash", "pw/jaws_ready", "pw/coil_hit"]:
		sounds = sounds and SoundCatalog.has(sound)
	check(sounds, "their sounds are in the catalog")
	run.powerups_of(fish).add("attack_leviathans_coil")
	check(run.powerups_of(fish).stacks("leviathans_coil") == 1 and Powerup.title("attack_leviathans_coil") == "Leviathan's Coil",
			"the old Coil weapon id (old logs) is the item")
	run.powerups_of(fish).clear()

	print("test tank:")
	TestTank.apply_boss_items(TestTank.BOSS_ITEMS.size() + 1, 3)
	var all_three := true
	for id in ITEMS:
		all_three = all_three and powers.stacks_override(id) == 3
	check(all_three, "All at 3 stacks sets every one's override")
	TestTank.apply_boss_items(2, 2)
	check(powers.stacks_override("gulpers_maw") == 2 and powers.stacks_override("leviathans_coil") == 0, "one picked: that one alone")
	TestTank.apply_boss_items(0, 1)
	var none := true
	for id in ITEMS:
		none = none and powers.stacks_override(id) == 0
	check(none, "None clears them")

	print("co-op chest:")
	# A second player, there only for the chest's count (out of the tree, so
	# taken out again before the next frame).
	var other := FishController.new()
	for every: bool in [true, false]:
		powers.boss_item_every_player = every
		var chest := run.add_chest(fish.global_position + Vector3(4.0, 0.0, 0.0), 0.0, -INF, TreasureChest.Kind.BOSS, "angels_crown")
		run.players.append(other)
		run.open_chest(chest, fish)
		run.pick(fish, 0)
		run.players.erase(other)
		var gone: bool = chest._vanished
		check(gone != every, "boss_item_every_player %s: the chest %s for the other player" % [every, "stays" if every else "is gone"])
		run.powerups_of(fish).clear()
		chest.vanish()
		await _frames(2)
	other.free()
	powers.boss_item_every_player = true

	print("leviathan's coil:")
	powers.coil_stacks = 1
	run.powerups_of(fish).refresh()
	var coil := run.powerups_of(fish).held["leviathans_coil"] as LeviathansCoilItem
	await _ticks(2)
	check(coil.attack_level() == powers.coil_arrive_level and coil.attack.level == powers.coil_arrive_level and coil.attack.milestones == 1,
			"1 stack: a Lv %d Coil, its first milestone on" % powers.coil_arrive_level)
	check(coil.attack.count() == powers.coil_segments + powers.coil_segments_per_stack, "its facets spread over its levels (%d coils)" % coil.attack.count())
	powers.coil_stacks = 2
	run.powerups_of(fish).refresh()
	await _ticks(2)
	check(coil.attack.level == powers.coil_arrive_level + powers.coil_levels_per_stack, "2 stacks: Lv %d" % coil.attack.level)
	check(run.loadout_of(fish).weapons.size() == 1 and run.loadout_of(fish).weapons[0] == Weapons.ATTACK, "and no weapon slot")
	powers.coil_stacks = 0
	run.powerups_of(fish).refresh()

	await _gulper()
	await _brood()
	await _disc()
	await _crown()
	await _jaws()
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _gulper() -> void:
	print("gulper's maw:")
	horde.clear()
	_still()
	powers.maw_stacks = 1
	powers.maw_every = 1.0
	run.powerups_of(fish).refresh()
	var maw := run.powerups_of(fish).held["gulpers_maw"] as GulpersMaw
	var mouth := maw.mouth()
	for n in 6:
		horde.spawn(1, mouth + Vector3(cos(n), 0.3 * sin(n * 2.0), sin(n)) * 1.2)
	for n in 4:
		horde.spawn(1, mouth + Vector3(cos(n * 1.6), 0.0, sin(n * 1.6)) * 7.0)  # out of its mouth: sucked in
	var far_before := 0.0
	for i in horde.query_sphere(mouth, 9.0):
		far_before = maxf(far_before, horde.enemy_position(i).distance_to(mouth))
	await _seconds(0.9)
	await _shot("gulpers_maw")
	await _seconds(1.7)
	check(maw.gulps >= 1 and maw.swallowed >= 1 and maw.bolts == maw.swallowed, "it gulps, swallows (%d) and spits a bolt each (%d)" % [maw.swallowed, maw.bolts])
	check(run.stats_of(fish).by_source.get("gulpers_maw", 0.0) > 0.0, "its chewing and volley hurt (%.0f)" % run.stats_of(fish).by_source.get("gulpers_maw", 0.0))
	powers.maw_every = 6.0
	powers.maw_stacks = 0
	run.powerups_of(fish).refresh()


func _brood() -> void:
	print("hagfish brood:")
	horde.clear()
	_still()
	powers.brood_stacks = 2
	run.powerups_of(fish).refresh()
	var brood := run.powerups_of(fish).held["hagfish_brood"] as HagfishBrood
	check(brood.count() == powers.brood_count + powers.brood_count_per_stack, "2 stacks: %d hagfish" % brood.count())
	for n in 5:
		horde.spawn(2, fish.global_position + Vector3(cos(n * 1.3), 0.2, sin(n * 1.3)) * 6.0)  # boxfish: they live through a bite
	var held_still := false
	for t in 360:
		if t == 120:
			await _shot("hagfish_brood")
		await get_tree().physics_frame
		for i in brood.held():
			held_still = held_still or horde.slow_share(i) >= 1.0
	check(brood.bites >= 3 and brood.knots >= 1 and held_still, "they bite (%d) and knot on, holding zombies still" % brood.bites)
	check(brood.slimed >= 1, "and let go slimed (%d)" % brood.slimed)
	check(run.find_children("*Hagfish*", "", false, false).size() == brood.count(), "a hagfish each, on the run")
	powers.brood_stacks = 0
	run.powerups_of(fish).refresh()
	await _ticks(2)
	await _frames(1)
	check(run.find_children("*Hagfish*", "", false, false).is_empty(), "and gone with the item")


func _disc() -> void:
	print("queen's disc:")
	horde.clear()
	_still()
	var tough := horde.spawn(2, fish.global_position + Vector3(5.0, 0.0, 0.0))
	horde.spawn(0, fish.global_position + Vector3(-4.0, 0.0, 0.0))
	var health := run.health_of(fish)
	health.hp = health.max_hp * 0.5
	powers.disc_stacks = 1
	run.powerups_of(fish).refresh()
	var disc := run.powerups_of(fish).held["queens_disc"] as QueensDisc
	await _seconds(0.6)
	await _shot("queens_disc")
	await _seconds(1.0)
	check(disc.host == tough or not horde.is_alive(tough), "it latches onto the toughest near (%d)" % disc.host)
	check(disc.drains >= 2 and disc.healed > 0.0, "drains it (%d) and heals the fish (%.1f hp)" % [disc.drains, disc.healed])
	powers.disc_stacks = 0
	run.powerups_of(fish).refresh()


func _crown() -> void:
	print("angel's crown:")
	horde.clear()
	_still()
	var health := run.health_of(fish)
	health.hp = health.max_hp * 0.5
	var ahead := -fish.global_basis.z
	for n in 6:
		horde.spawn(0, fish.global_position + ahead * (3.0 + n) + fish.global_basis.x * (n % 3 - 1))
	var behind := horde.spawn(1, fish.global_position - ahead * 5.0)
	powers.crown_stacks = 1
	powers.crown_every = 0.5
	run.powerups_of(fish).refresh()
	var crown := run.powerups_of(fish).held["angels_crown"] as AngelsCrown
	await _seconds(0.62)
	await _shot("angels_crown")
	await _seconds(0.88)
	check(crown.bursts >= 1 and crown.lashes >= powers.crown_lashes, "it bursts and lashes (%d bursts, %d lashes)" % [crown.bursts, crown.lashes])
	check(run.stats_of(fish).by_source.get("angels_crown", 0.0) > 0.0 and horde.is_alive(behind) and horde.enemy_hp(behind) >= horde.enemy_max_hp(behind),
			"the cone ahead takes it, not behind")
	check(crown.healed > 0.0, "its kills heal (%.1f hp)" % crown.healed)
	powers.crown_every = 5.0
	powers.crown_stacks = 0
	run.powerups_of(fish).refresh()


func _jaws() -> void:
	print("drowned jaws:")
	horde.clear()
	_still()
	for n in 3:
		horde.spawn(1, fish.global_position - fish.global_basis.z * (2.5 + n))
	settings.bite_damage = 1.0  # (a bite of 0 never fires)
	powers.jaws_stacks = 1
	powers.jaws_every = 0.5
	run.powerups_of(fish).refresh()
	var jaws := run.powerups_of(fish).held["drowned_jaws"] as DrownedJaws
	await _seconds(3.0)
	check(jaws.chomps >= 1 and run.stats_of(fish).by_source.get("drowned_jaws", 0.0) > 0.0, "ready, the next attack chomps (%d)" % jaws.chomps)
	settings.bite_damage = 0.0
	powers.jaws_every = 6.0
	powers.jaws_stacks = 0
	run.powerups_of(fish).refresh()


## The fish held still at the arena's middle, facing forward.
func _still() -> void:
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), run.centre + Vector3(0.0, 4.0, 0.0)))
	fish.linear_velocity = Vector3.ZERO
	fish.freeze = true


## A screenshot `shot_name`.png in shots_dir (with --shots only).
func _shot(shot_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(shot_name + ".png"))


func _seconds(s: float) -> void:
	await _ticks(roundi(s * Engine.physics_ticks_per_second))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
