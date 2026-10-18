extends Node
## Sound effects, phase 3 (planning_audio.md §4): Unnatural. The run's beds,
## your attack firing and landing (a real bite), deaths and XP gathered per
## frame, hits by source, lunges, you and your team, level-ups and cards,
## pickups, pearls, chests, stage events and the bosses, the loops that follow
## the horde and your hp, and the powerups' own sounds. Listens to
## Sfx.requested, so it works whatever profile is picked.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/audio_hooks3_probe.tscn

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var run: UnnaturalRun
var horde: Horde
var settings := UnnaturalSettings.shared()
var failures := 0
var heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.requested.connect(func(id: String) -> void: heard.append(id))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 30.0
	settings.enemy_damage_scale = 0.0
	main.set_mode(main.UNNATURAL)
	await _seconds(0.05)
	heard.clear()
	main._match_card.play_requested.emit()
	await _seconds(0.1)
	run = main.unnatural_run
	horde = run.horde
	print("the run:")
	check(run.get_node_or_null("Sounds") is UnnaturalSounds, "the run has its UnnaturalSounds")
	check(heard.has("amb/seabed_loop") and heard.has("stage/blood_moon_loop") and heard.has("stage/blood_moon"), "the seabed and the blood moon: beds and rise")

	await _combat()
	await _team()
	await _stage()
	await _loops()
	await _powerups()
	print("audio_hooks3_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _combat() -> void:
	print("combat:")
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3.ZERO))
	await _seconds(0.05)
	fish.freeze = true
	var ahead := horde.spawn(1, Vector3(1.5, 0.0, -6.5))
	heard.clear()
	await _seconds(0.8)
	check(heard.has("unnatural/bite_fire"), "a bite fires")
	check(heard.has("unnatural/bite_hit"), "and lands")
	check(heard.any(func(id: String) -> bool: return id.begins_with("unnatural/zombie_die_")), "the zombie dies")
	check(heard.has("unnatural/xp"), "and its XP sounds")
	check(not horde.is_alive(ahead), "(it is dead)")
	check(SoundCatalog.has("unnatural/bite_fire") and SoundCatalog.FALLBACKS.get("unnatural/bite_fire") == "unnatural/attack_own_fire", "every attack falls back to the generic one")

	var a := horde.spawn(0, Vector3(0.0, 0.0, -30.0))
	var b := horde.spawn(0, Vector3(1.0, 0.0, -30.0))
	var c := horde.spawn(0, Vector3(2.0, 0.0, -30.0))
	await _seconds(0.05)
	heard.clear()
	for index in [a, b, c]:
		run.zombie_hit.emit(index, 1.0, fish, "torpedo", [])
	await _seconds(0.05)
	check(heard.count("unnatural/zombie_hit") == 1, "three blasts in one frame: one zombie_hit (%d)" % heard.count("unnatural/zombie_hit"))
	heard.clear()
	run.zombie_hit.emit(a, 1.0, fish, "greek_fire", [])
	run.zombie_hit.emit(a, 1.0, fish, "remora_buddy", [])
	run.zombie_hit.emit(a, 1.0, fish, "jellyfish_halo", [])
	run.zombie_hit.emit(a, 1.0, fish, "leviathans_coil", [])
	run.zombie_hit.emit(a, 1.0, fish, "battery", [])
	run.zombie_hit.emit(a, 1.0, fish, "chain_lightning", ["chain_lightning", "chain_lightning"])
	await _seconds(0.05)
	for id in ["pw/greek_fire_burn", "pw/remora_nip", "pw/jelly_sting", "pw/coil_hit", "battered/battery", "pw/chain_zap"]:
		check(heard.has(id), "a hit by that source: " + id)
	check(not heard.has("unnatural/zombie_hit"), "and none of them the generic one")
	heard.clear()
	horde.lunge_stage.emit(a, Horde.Lunge.TELEGRAPH)
	horde.lunge_stage.emit(a, Horde.Lunge.LUNGE)
	check(heard.has("unnatural/lunge_telegraph") and heard.has("unnatural/lunge"), "a lunger winds up, then strikes")
	heard.clear()
	horde.spawn(0, Vector3(5.0, 0.0, 5.0))
	horde.spawn(0, Vector3(6.0, 0.0, 5.0))
	await _seconds(0.05)
	check(heard.count("unnatural/zombie_spawn") == 1, "spawns nearby: one sound (%d)" % heard.count("unnatural/zombie_spawn"))
	horde.clear()


func _team() -> void:
	print("you and your team:")
	heard.clear()
	run.player_hurt.emit(fish, 4.0)
	run.player_down.emit(fish)
	run.player_revived.emit(fish)
	check(heard.has("unnatural/hurt") and heard.has("unnatural/downed") and heard.has("unnatural/revived"), "hurt, down, revived")
	heard.clear()
	run.leveled_up.emit(2)
	check(heard.has("unnatural/level_up") and heard.has("voice/level_up"), "a level-up")
	heard.clear()
	run.cards_offered.emit(fish, [{"tier": 0}, {"tier": Rarity.Tier.LEGENDARY}, {"tier": 1}], "LEVEL 2", "")
	check(heard.has("unnatural/cards_offered") and not heard.has("unnatural/card_reveal_legendary"), "cards fan out")
	await _seconds(UnnaturalSounds.REVEAL_DELAY + 0.1)
	check(heard.has("unnatural/card_reveal_legendary"), "and the rarest shows (legendary)")
	heard.clear()
	run.card_picked.emit(fish, {"tier": Rarity.Tier.CURSED})
	check(heard.has("unnatural/card_picked") and heard.has("pw/cursed_take"), "a cursed pick")
	heard.clear()
	for kind in 3:
		run.drop_taken.emit(kind, fish)
	check(heard.has("unnatural/pickup_heart") and heard.has("unnatural/pickup_magnet") and heard.has("unnatural/pickup_hourglass"), "the three pickups")
	await _seconds(0.4)
	check(Sfx.is_looping((run.get_node("Sounds") as UnnaturalSounds)._magnet), "and the magnet pulls")
	heard.clear()
	run.pearl_collected.emit(fish)
	run.pearl_collected.emit(fish)
	check(heard.count("unnatural/pearl") == 2, "pearls")
	var chest := TreasureChest.new()
	add_child(chest)
	heard.clear()
	run.chest_buried.emit(chest)
	run.chest_opened.emit(chest, fish)
	run.powerup_lost.emit(fish, "bow_grow_bow")
	check(heard.has("unnatural/chest_buried") and heard.has("unnatural/chest_open") and heard.has("unnatural/powerup_lost"), "a chest buried and opened, a powerup lost")
	chest.queue_free()


func _stage() -> void:
	print("stage and bosses:")
	heard.clear()
	for event in ["ring", "miniboss", "stampede", "tide", "boss"]:
		run.stage_warned.emit(event)
	check(heard.has("stage/ring_warn") and heard.has("stage/miniboss_warn") and heard.has("stage/stampede_warn")
			and heard.has("stage/tide_warn") and heard.has("stage/boss_warn"), "every event's warning")
	check(heard.has("voice/ring_warn") and heard.has("voice/tide_warn"), "and the callout where there is one")
	heard.clear()
	run.stage_event.emit("ring")
	run.stage_event.emit("tide")
	check(heard.has("stage/ring") and heard.has("stage/tide"), "the events themselves")
	heard.clear()
	run._start_event("miniboss")
	await _seconds(0.1)
	var shark: DrownedShark = run.bosses[0]
	check(heard.has("boss/shark_arrive") and heard.has("voice/boss_arrive"), "the Drowned Shark arrives")
	check(shark.get_node_or_null("Sounds") is BossSounds, "and has its BossSounds")
	heard.clear()
	shark._mode_left = 5.0
	shark.mode = DrownedShark.Mode.TELEGRAPH
	await _seconds(0.05)
	shark.mode = DrownedShark.Mode.CHARGE
	await _seconds(0.05)
	check(heard.has("boss/shark_telegraph") and heard.has("boss/shark_charge"), "it winds up and charges")
	heard.clear()
	var part: int = shark.parts[0]
	run.zombie_hit.emit(part, 1.0, fish, "bite", [])
	await _seconds(0.05)
	check(heard.has("boss/hit") and not heard.has("unnatural/bite_hit"), "a hit on the boss's body is a boss hit")
	heard.clear()
	run.boss_defeated.emit(shark, fish)
	check(heard.has("boss/defeated"), "defeated")
	shark.queue_free()
	run.bosses.clear()
	heard.clear()
	run._start_event("boss")
	await _seconds(0.1)
	var leviathan: BloodLeviathan = run.bosses[0]
	check(heard.has("boss/leviathan_arrive"), "the Blood Leviathan arrives")
	heard.clear()
	leviathan.phase_changed.emit(1)
	leviathan.spat.emit(Vector3.ZERO, PackedVector3Array())
	run.boss_enraged.emit(leviathan)
	check(heard.has("boss/leviathan_phase") and heard.has("boss/leviathan_spit") and heard.has("boss/enraged"), "its phase, its spit, its rage")
	heard.clear()
	run.stage_completed.emit()
	run.stage_complete = true
	run.run_over.emit()
	check(heard.has("stage/complete") and not heard.has("stage/run_over"), "the stage complete (a won run isn't 'run over')")
	run.stage_complete = false
	heard.clear()
	run.run_over.emit()
	check(heard.has("stage/run_over") and heard.has("voice/lose"), "a lost run")
	leviathan.queue_free()
	run.bosses.clear()


func _loops() -> void:
	print("loops:")
	horde.clear()
	for n in 6:
		horde.spawn(0, fish.global_position + Vector3(4.0 + n, 0.0, 3.0))
	heard.clear()
	await _seconds(0.5)
	var sounds: UnnaturalSounds = run.get_node("Sounds")
	check(Sfx.is_looping(sounds._moan), "the horde near: the moan")
	horde.clear()
	var health := run.health_of(fish)
	health.hp = health.max_hp * 0.1
	heard.clear()
	await _seconds(0.5)
	check(Sfx.is_looping(sounds._heartbeat) and not Sfx.is_looping(sounds._moan), "under a quarter of your hp: the heartbeat")
	health.hp = health.max_hp
	run._revive[fish] = 0.5
	heard.clear()
	await _seconds(0.5)
	check(Sfx.is_looping(sounds._revive) and not Sfx.is_looping(sounds._heartbeat), "being revived")
	run._revive[fish] = 0.0


func _powerups() -> void:
	print("powerups:")
	var powers := run.powerups_of(fish)
	heard.clear()
	for id in ["depth_charges", "anglerfish_lure", "torpedo", "electric_eel", "tsunami_heart", "drowned_fin", "bubble_wrap",
			"pufferfish_spines", "greek_fire", "jellyfish_halo", "leviathans_coil"]:
		powers.add(id)
	await _seconds(0.2)
	var worn_loops := heard.duplicate()
	var held: Dictionary = powers.held
	heard.clear()
	var charges: DepthCharges = held["depth_charges"]
	charges.drop()
	charges.on_tick(charges.arm_time() + 0.1)
	charges.explode(fish.global_position + Vector3(0, 5, 0))
	check(heard.has("pw/depth_charge_drop") and heard.has("pw/depth_charge_arm") and heard.has("fx/explosion"), "depth charges: drop, arm, blast")
	heard.clear()
	var lure: AnglerfishLure = held["anglerfish_lure"]
	lure.drop()
	lure.pop(fish.global_position + Vector3(0, 5, 0))
	check(heard.has("pw/lure_drop") and heard.has("pw/lure_loop") and heard.has("pw/lure_burst"), "the lure: drop, glow, burst")
	heard.clear()
	var torpedoes: TorpedoLauncher = held["torpedo"]
	torpedoes.launch([])
	torpedoes.on_tick(0.01)
	torpedoes.explode(fish.global_position + Vector3(0, 5, 0), [])
	check(heard.has("pw/torpedo_launch") and heard.has("pw/torpedo_loop") and heard.has("fx/explosion"), "torpedoes: launch, running, blast")
	heard.clear()
	(held["electric_eel"] as ElectricEel).on_battery(0)
	(held["tsunami_heart"] as TsunamiHeart).send(Vector3.FORWARD)
	(held["pufferfish_spines"] as PufferfishSpines).on_hurt(1.0, -1)
	check(heard.has("pw/eel_shock_ring") and heard.has("pw/tsunami_wave") and heard.has("pw/puffer_spines"), "the eel's ring, the wave, the spines")
	heard.clear()
	(held["drowned_fin"] as DrownedFin).dash()
	check(heard.has("pw/drowned_fin_dash") and heard.has("pw/drowned_fin_charge_loop"), "the Drowned Fin's dash")
	heard.clear()
	var wrap: BubbleWrap = held["bubble_wrap"]
	wrap.on_tick(wrap.ready_time() + 1.0)
	check(heard.has("pw/bubble_wrap_ready"), "the bubble is up")
	check(wrap.blocks_hit(1.0) and heard.has("pw/bubble_wrap_pop"), "and pops")
	heard.clear()
	(held["greek_fire"] as GreekFire)._drop(fish.global_position + Vector3(0, -2, 0))
	check(heard.has("pw/greek_fire_loop") and worn_loops.has("pw/jelly_halo_loop") and worn_loops.has("pw/coil_loop"), "the fire patch, the halo and the coil loop")
	powers.clear()
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.3)


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
