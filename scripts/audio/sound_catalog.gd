class_name SoundCatalog
## Every sound event the game can play (planning_audio.md §3): its id, which is
## also its file's path inside a sound profile (ball/hit -> ball/hit.wav), how
## much it matters, how it plays, and what it's for (the recording sheet and the
## Sound Board show that). Gameplay asks Sfx for an id from here, never a file.
##
## A row is [id, priority, flags, description]. Priority 1 = the game feels
## dead without it, 2 = adds a lot, 3 = polish. Flags, space separated:
##   3d          positioned in the world (record it mono)
##   loop        sustained: started, moved and stopped by the game
##   pitched     climbs the profile's scale (a streak, a count)
##   layers      the game passes how hard (0..1), so @1..@3 files fit it
##   voices=N    at most N playing at once (default DEFAULT_VOICES)
##   cd=S        at least S seconds between two starts (default 0)
## The bus comes from the id's folder (BUSES); anything else is World.

const DEFAULT_VOICES := 4
## The id's folder -> its bus.
const BUSES := {"ui": "UI", "voice": "Voice", "music": "Music", "amb": "Ambience"}
## Folder -> the heading it's listed under (Sound Board, recording sheet), in order.
const CATEGORIES := {
	"ui": "Menus", "fish": "Your fish", "ball": "Ball", "arena": "Arena", "match": "Matches", "hunt": "Hunt",
	"battered": "Battered", "nature": "Nature", "unnatural": "Unnatural", "pw": "Powerups", "stage": "Stage events",
	"boss": "Bosses", "fx": "Shared effects", "amb": "Ambience", "voice": "Callouts", "music": "Music",
}

const ROWS := [
	# Menus.
	["ui/move", 1, "voices=2", "Focus moves between buttons, rows or cards. Very short and quiet; it fires a lot."],
	["ui/select", 1, "", "Confirm / press a button."],
	["ui/back", 1, "", "Back / cancel / close."],
	["ui/denied", 2, "", "Can't do that (locked, not enough pearls)."],
	["ui/toggle_on", 3, "", "A setting switched on."],
	["ui/toggle_off", 3, "", "A setting switched off."],
	["ui/slider", 3, "pitched voices=2", "A slider steps (climbs with the value)."],
	["ui/mode_picker_open", 2, "", "The mode pop-up opens."],
	["ui/mode_picker_close", 2, "", "The mode pop-up closes."],
	["ui/mode_chosen", 2, "", "A mode is picked."],
	["ui/character_change", 2, "", "Cycling through the fish on the home screen."],
	["ui/pause", 2, "", "The game pauses."],
	["ui/unpause", 2, "", "The game carries on."],
	["ui/match_card", 2, "", "A match card appears before Play."],
	["ui/player_join", 2, "", "A co-op player joins."],
	["ui/player_leave", 2, "", "A co-op player leaves."],
	["ui/connect_fail", 3, "", "An online connection fails."],

	# Your fish.
	["fish/stroke", 1, "3d layers voices=4", "Each swim stroke. Intensity is the stroke's quality: a well-timed stroke sounds fuller. The most musical sound in the game."],
	["fish/stride", 1, "3d pitched layers voices=4", "An Extra Swishy stride: climbs while your flow holds, louder with better timing."],
	["fish/stroke_miss", 3, "3d", "A badly timed stroke: a soft flub."],
	["fish/jump", 1, "3d", "First jump."],
	["fish/double_jump", 1, "3d", "Second jump."],
	["fish/dodge", 1, "3d", "Dodge / flip: a swoosh."],
	["fish/boost_start", 1, "3d", "Boost pressed."],
	["fish/boost_loop", 1, "3d loop", "While boosting; its pitch follows your speed."],
	["fish/boost_stop", 2, "3d", "Boost released: the tail."],
	["fish/boost_empty", 3, "3d cd=0.5", "Tried to boost with none left."],
	["fish/supersonic", 2, "3d", "Crossing supersonic speed: a whoomp."],
	["fish/land", 2, "3d layers", "Touching the floor or a wall after the air; harder landings are louder."],
	["fish/scrape_loop", 3, "3d loop", "Sliding along a wall or the floor."],
	["fish/breach", 2, "3d", "Leaving the water through the surface."],
	["fish/splash", 2, "3d layers", "Falling back into the water."],
	["fish/bow_wave_loop", 3, "3d loop", "The bow wave in front of you at speed (louder with Bow Grow Bow)."],
	["fish/bump", 2, "3d layers cd=0.1", "Bumping another fish (not a battery)."],
	["fish/reset", 2, "3d", "Reset / respawn."],
	["fish/teleport", 2, "3d", "Teleported."],

	# Ball and arena.
	["ball/hit", 1, "3d layers voices=3", "A fish hits the ball, soft to smash. The most-heard sound in Free Play and 1v1."],
	["ball/bounce", 1, "3d layers voices=3 cd=0.05", "The ball bounces off the floor, a wall or the ceiling."],
	["ball/hoop_rim", 2, "3d", "The ball clips a hoop."],
	["ball/hoop_through", 2, "3d", "The ball goes through a hoop."],
	["ball/reset", 2, "3d", "The ball respawns."],
	["arena/goal_net", 1, "3d layers", "The ball hits the back of the net."],
	["arena/bubble_column_loop", 2, "3d loop voices=6", "A bubble column."],

	# Matches.
	["match/countdown", 1, "pitched", "3, 2, 1 before kickoff (climbs)."],
	["match/go", 1, "", "Kickoff."],
	["match/goal_horn", 1, "", "A goal. One horn for both teams. An arena can have its own: match/goal_horn_<arena> (e.g. match/goal_horn_aquarium)."],
	["match/goal_horn_aquarium", 3, "", "The aquarium arena's own goal horn (falls back to match/goal_horn)."],
	["match/goal_replay_in", 2, "", "A goal replay starts."],
	["match/goal_replay_out", 2, "", "A goal replay ends."],
	["match/clock_tick", 2, "pitched", "Each of the last 10 seconds (climbs)."],
	["match/time_up", 1, "", "The buzzer."],
	["match/overtime", 2, "", "Overtime starts."],
	["match/win", 1, "", "You won."],
	["match/lose", 1, "", "You lost."],
	["match/draw", 1, "", "A draw."],
	["hunt/target_spotted", 2, "", "Hunt: the quarry is seen."],
	["hunt/caught", 2, "", "Hunt: caught it."],
	["hunt/escaped", 2, "", "Hunt: it got away."],

	# Battered.
	["battered/battery", 1, "3d layers", "You batter something; harder at higher speed."],
	["battered/battered", 1, "3d layers", "You get battered (a different colour from dealing one)."],
	["battered/fish_fry", 1, "", "A double: Fish Fry!"],
	["battered/fish_fry_more", 2, "pitched", "Triple and up: climbs with the count."],
	["battered/out", 2, "3d", "A battered fish is out / respawning."],

	# Nature.
	["nature/school_loop", 2, "3d loop voices=3", "A school nearby: fluttery."],
	["nature/school_scatter", 2, "3d", "A school startles."],
	["nature/target_lock", 1, "", "The target wheel locks a target."],
	["nature/target_cycle", 2, "voices=2", "Cycling targets on the wheel: a quiet tick."],
	["nature/battery", 1, "3d layers", "Battering a school fish."],
	["nature/pearl_drop", 2, "3d", "A pearl appears."],
	["nature/pearl", 1, "pitched", "A pearl collected: climbs the scale on a streak."],
	["nature/style", 2, "layers", "Style points; bigger awards are bigger."],
	["nature/target_respawn", 3, "3d", "A new target is placed."],

	# Unnatural: your attacks.
	["unnatural/attack_own_fire", 1, "3d voices=3", "Your fish's own attack fires."],
	["unnatural/attack_own_hit", 1, "3d voices=3 cd=0.03", "Your fish's own attack lands."],
	["unnatural/sting_fire", 1, "3d voices=3", "Anemone Sting fires."],
	["unnatural/sting_hit", 1, "3d voices=3 cd=0.03", "Anemone Sting lands."],
	["unnatural/bite_fire", 1, "3d voices=3", "Ghost Bite fires."],
	["unnatural/bite_hit", 1, "3d voices=3 cd=0.03", "Ghost Bite lands."],
	["unnatural/lash_fire", 1, "3d voices=3", "Shock Lash fires."],
	["unnatural/lash_hit", 1, "3d voices=3 cd=0.03", "Shock Lash lands."],
	["unnatural/thrust_fire", 1, "3d voices=3", "Bill Thrust fires."],
	["unnatural/thrust_hit", 1, "3d voices=3 cd=0.03", "Bill Thrust lands."],
	["unnatural/bubbles_fire", 1, "3d voices=3", "Bubble Volley fires."],
	["unnatural/bubbles_hit", 1, "3d voices=3 cd=0.03", "Bubble Volley lands."],
	["unnatural/spines_fire", 1, "3d voices=3", "Spine Burst fires."],
	["unnatural/spines_hit", 1, "3d voices=3 cd=0.03", "Spine Burst lands."],
	# Unnatural: zombies.
	["unnatural/zombie_spawn", 3, "3d voices=2 cd=0.2", "A zombie rises from the seabed (heavily rate-limited)."],
	["unnatural/zombie_moan_loop", 2, "loop voices=1", "The horde's moan: one loop, louder the more are near."],
	["unnatural/zombie_hit", 1, "3d layers voices=3 cd=0.04", "Zombies take damage (gathered per frame: more hits, harder layer)."],
	["unnatural/zombie_die", 1, "3d layers voices=4 cd=0.04", "Zombies die (gathered per frame: one big crunch for many)."],
	["unnatural/zombie_die_chase", 3, "3d layers voices=4 cd=0.04", "A chaser dies (falls back to unnatural/zombie_die)."],
	["unnatural/zombie_die_swarm", 3, "3d layers voices=4 cd=0.04", "A swarmer dies (falls back to unnatural/zombie_die)."],
	["unnatural/zombie_die_tank", 3, "3d layers voices=4 cd=0.04", "A tank dies (falls back to unnatural/zombie_die)."],
	["unnatural/zombie_die_lunge", 3, "3d layers voices=4 cd=0.04", "A lunger dies (falls back to unnatural/zombie_die)."],
	["unnatural/zombie_die_glide", 3, "3d layers voices=4 cd=0.04", "A glider dies (falls back to unnatural/zombie_die)."],
	["unnatural/lunge_telegraph", 1, "3d voices=3", "A lunger winds up. A warning: you should hear it coming."],
	["unnatural/lunge", 2, "3d voices=3", "A lunger strikes."],
	# Unnatural: you and your team.
	["unnatural/hurt", 1, "cd=0.15", "You take damage."],
	["unnatural/low_hp_loop", 2, "loop voices=1", "A heartbeat under about a quarter of your HP."],
	["unnatural/downed", 1, "", "You go down."],
	["unnatural/revive_loop", 2, "loop voices=1", "Being revived (co-op)."],
	["unnatural/revived", 1, "", "Back up."],
	["unnatural/xp", 1, "pitched voices=3 cd=0.03", "An XP orb collected: climbs on a streak."],
	["unnatural/level_up", 1, "", "Level up."],
	["unnatural/cards_offered", 1, "", "The level-up cards fan out."],
	["unnatural/card_reveal_common", 2, "", "A common card shows."],
	["unnatural/card_reveal_uncommon", 2, "", "An uncommon card shows."],
	["unnatural/card_reveal_rare", 2, "", "A rare card shows."],
	["unnatural/card_reveal_epic", 2, "", "An epic card shows."],
	["unnatural/card_reveal_legendary", 2, "", "A legendary card shows."],
	["unnatural/card_reveal_boss", 2, "", "A boss card shows."],
	["unnatural/card_reveal_cursed", 2, "", "A cursed card shows. It should feel wrong."],
	["unnatural/card_picked", 1, "", "A card is chosen."],
	["unnatural/pickup_heart", 1, "", "Heart pickup."],
	["unnatural/pickup_magnet", 1, "", "Magnet pickup."],
	["unnatural/pickup_hourglass", 1, "", "Hourglass pickup."],
	["unnatural/magnet_pull_loop", 3, "loop voices=1", "The magnet hoovering up XP."],
	["unnatural/chest_buried", 2, "3d", "A treasure chest appears."],
	["unnatural/chest_open", 1, "3d", "A chest opens."],
	["unnatural/powerup_lost", 2, "", "Sunken Idol takes a powerup."],
	["unnatural/pearl", 2, "pitched cd=0.03", "A pearl (currency): shares the Nature pearl's scale."],

	# Powerups.
	["pw/greek_fire_loop", 2, "3d loop voices=4", "A Greek Fire patch burning."],
	["pw/greek_fire_burn", 2, "3d voices=2 cd=0.1", "Greek Fire burns a zombie."],
	["pw/chain_zap", 1, "3d pitched voices=4", "Chain Lightning jumps (climbs per jump)."],
	["pw/torpedo_launch", 1, "3d", "A torpedo launches."],
	["pw/torpedo_loop", 2, "3d loop voices=4", "A torpedo running."],
	["pw/remora_nip", 2, "3d voices=3 cd=0.05", "Remora Buddy nips a zombie."],
	["pw/bubble_wrap_ready", 1, "", "Bubble Wrap is up."],
	["pw/bubble_wrap_pop", 1, "", "Bubble Wrap takes a hit and pops."],
	["pw/puffer_spines", 2, "3d voices=2", "Pufferfish Spines burst out."],
	["pw/jelly_halo_loop", 2, "3d loop voices=1", "The Jellyfish Halo orbiting."],
	["pw/jelly_sting", 2, "3d voices=3 cd=0.05", "A halo jelly stings."],
	["pw/eel_shock_ring", 1, "3d", "Electric Eel's shock ring."],
	["pw/depth_charge_drop", 1, "3d", "A depth charge drops."],
	["pw/depth_charge_arm", 2, "3d", "A depth charge arms."],
	["pw/lure_drop", 2, "3d", "The Anglerfish Lure drops."],
	["pw/lure_loop", 2, "3d loop voices=2", "The lure glowing."],
	["pw/lure_burst", 2, "3d", "The lure bursts."],
	["pw/tsunami_wave", 1, "3d", "Tsunami Heart's wave."],
	["pw/drowned_fin_charge_loop", 1, "loop voices=1", "Drowned Fin charging."],
	["pw/drowned_fin_dash", 1, "3d", "Drowned Fin's dash."],
	["pw/coil_loop", 2, "3d loop voices=1", "Leviathan's Coil trailing."],
	["pw/coil_hit", 2, "3d voices=3 cd=0.05", "A coil hurts something."],
	["pw/cursed_take", 2, "", "Taking a cursed powerup."],

	# Stage events.
	["stage/ring_warn", 1, "", "Warning: the ring is about to close."],
	["stage/ring", 1, "", "THE RING CLOSES."],
	["stage/miniboss_warn", 1, "", "Warning: THE DROWNED SHARK RISES."],
	["stage/stampede_warn", 1, "", "Warning: a stampede is coming."],
	["stage/stampede", 1, "", "STAMPEDE."],
	["stage/tide_warn", 1, "", "Warning: the tide is turning."],
	["stage/tide", 1, "", "THE TIDE TURNS."],
	["stage/blood_moon", 2, "", "The blood moon rises."],
	["stage/blood_moon_loop", 2, "loop voices=1", "Under the blood moon."],
	["stage/complete", 1, "", "Stage complete."],
	["stage/run_over", 1, "", "The run is over."],

	# Bosses.
	["boss/shark_arrive", 1, "", "The Drowned Shark arrives."],
	["boss/shark_telegraph", 1, "3d", "The Drowned Shark is about to charge. A warning."],
	["boss/shark_charge", 1, "3d", "The Drowned Shark charges."],
	["boss/leviathan_arrive", 1, "", "The Blood Leviathan arrives."],
	["boss/leviathan_phase", 1, "", "The Blood Leviathan changes phase (circle, spit, fury)."],
	["boss/leviathan_spit", 2, "3d voices=3", "The Blood Leviathan spits."],
	["boss/enraged", 1, "", "A boss is enraged."],
	["boss/hit", 1, "3d layers voices=2 cd=0.05", "A boss takes damage."],
	["boss/defeated", 1, "", "A boss is defeated."],

	# Shared effects.
	["fx/explosion", 1, "3d layers voices=4 cd=0.03", "An explosion (torpedoes, depth charges, the lure)."],
	["fx/burst_cloud", 2, "3d voices=3", "A burst cloud."],
	["fx/shock", 3, "3d voices=3", "Generic shock effect (a powerup without its own sound)."],
	["fx/ring", 3, "3d voices=3", "Generic ring effect."],
	["fx/flash", 3, "3d voices=3", "Generic flash effect."],
	["fx/spikes", 3, "3d voices=3", "Generic spikes effect."],
	["fx/pop", 3, "3d voices=3", "Generic pop effect."],

	# Ambience.
	["amb/arena_loop", 2, "loop voices=1", "Free Play / 1v1 arena bed."],
	["amb/aquarium_loop", 2, "loop voices=1", "The aquarium arena's bed."],
	["amb/ocean_loop", 2, "loop voices=1", "Open water (Nature, Free Swim)."],
	["amb/seabed_loop", 2, "loop voices=1", "Unnatural's seabed."],
	["amb/murk_loop", 3, "loop voices=1", "Crossfades in as the murk thickens."],
	["amb/surface_loop", 3, "loop voices=1", "Above the waterline."],

	# Callouts (optional, the Voice bus).
	["voice/go", 3, "", "Callout: go!"],
	["voice/goal", 3, "", "Callout: goal!"],
	["voice/fish_fry", 3, "", "Callout: Fish Fry!"],
	["voice/win", 3, "", "Callout: you win."],
	["voice/lose", 3, "", "Callout: you lose."],
	["voice/level_up", 3, "", "Callout: level up."],
	["voice/ring_warn", 3, "", "Callout: the ring closes."],
	["voice/miniboss_warn", 3, "", "Callout: the Drowned Shark rises."],
	["voice/stampede_warn", 3, "", "Callout: stampede."],
	["voice/tide_warn", 3, "", "Callout: the tide turns."],
	["voice/boss_arrive", 3, "", "Callout: a boss arrives."],

	# Music (picked separately: Settings > Audio > Music).
	["music/menu", 3, "loop voices=1", "Menus."],
	["music/match", 3, "loop voices=1", "Free Play and 1v1."],
	["music/nature", 3, "loop voices=1", "Nature."],
	["music/unnatural", 3, "loop voices=1", "Unnatural."],
	["music/boss", 3, "loop voices=1", "A boss fight."],
	["music/victory", 3, "", "Victory."],
]

## Events that borrow another's sound when a profile lacks theirs: id -> id.
const FALLBACKS := {
	"match/goal_horn_aquarium": "match/goal_horn",
	"unnatural/zombie_die_chase": "unnatural/zombie_die",
	"unnatural/zombie_die_swarm": "unnatural/zombie_die",
	"unnatural/zombie_die_tank": "unnatural/zombie_die",
	"unnatural/zombie_die_lunge": "unnatural/zombie_die",
	"unnatural/zombie_die_glide": "unnatural/zombie_die",
}

static var _events := {}


## Every event: id -> {id, priority, description, bus, is_3d, loop, pitched,
## layers, voices, cooldown, category}. In ROWS order.
static func events() -> Dictionary:
	if _events.is_empty():
		for row: Array in ROWS:
			var info := {"id": row[0], "priority": row[1], "description": row[3], "is_3d": false, "loop": false,
					"pitched": false, "layers": false, "voices": DEFAULT_VOICES, "cooldown": 0.0}
			var folder := String(row[0]).get_slice("/", 0)
			info["bus"] = BUSES.get(folder, "World")
			info["category"] = folder
			for flag: String in String(row[2]).split(" ", false):
				if flag.begins_with("voices="):
					info["voices"] = flag.get_slice("=", 1).to_int()
				elif flag.begins_with("cd="):
					info["cooldown"] = flag.get_slice("=", 1).to_float()
				elif flag == "3d":
					info["is_3d"] = true
				else:
					info[flag] = true
			_events[row[0]] = info
	return _events


static func has(id: String) -> bool:
	return events().has(id)


static func info(id: String) -> Dictionary:
	return events().get(id, {})


## Event ids in `category` (a folder), in order.
static func ids_in(category: String) -> Array[String]:
	var found: Array[String] = []
	for id: String in events():
		if events()[id].category == category:
			found.append(id)
	return found


## The recording sheet (CSV): each event, what it's for, how it plays, and
## whether each of `profiles` has it.
static func sheet(profiles: Array) -> String:
	var header := PackedStringArray(["event", "file (any of .wav .ogg .mp3)", "priority", "heard", "kind", "description"])
	for profile: SoundProfile in profiles:
		header.append(profile.title)
	var lines := PackedStringArray([_csv_line(header)])
	for id: String in events():
		var e: Dictionary = events()[id]
		var kinds := PackedStringArray()
		for flag: String in ["loop", "pitched", "layers"]:
			if e[flag]:
				kinds.append(flag)
		var cells := PackedStringArray([id, id + ".wav", "P%d" % e.priority, "3D (mono)" if e.is_3d else "2D",
				" ".join(kinds), e.description])
		for profile: SoundProfile in profiles:
			cells.append("yes (%d)" % profile.file_count(id) if profile.has(id) else "")
		lines.append(_csv_line(cells))
	return "\n".join(lines) + "\n"


static func _csv_line(cells: PackedStringArray) -> String:
	var quoted := PackedStringArray()
	for cell in cells:
		quoted.append("\"%s\"" % cell.replace("\"", "\"\"") if cell.contains(",") or cell.contains("\"") else cell)
	return ",".join(quoted)
