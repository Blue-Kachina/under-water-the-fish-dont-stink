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
	"boss": "Bosses", "hunter": "Hunters", "whale": "Hunter whales", "angel": "Hunter Fallen Angel", "gulper": "Hunter Gulper Mother", "king": "Hunter King of Herrings", "lamprey": "Hunter Lamprey Queen", "mp": "Marco Polo", "fx": "Shared effects", "amb": "Ambience", "voice": "Callouts", "music": "Music",
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
	["fish/teleport", 2, "3d", "Teleported (reserved: nothing moves a fish mid-play yet; kickoffs and resets have their own sounds)."],

	# Ball and arena.
	["ball/hit", 1, "3d layers voices=3", "A fish hits the ball, soft to smash. The most-heard sound in Free Play and 1v1."],
	["ball/bounce", 1, "3d layers voices=3 cd=0.05", "The ball bounces off the floor, a wall or the ceiling."],
	["ball/reset", 2, "3d", "The ball respawns."],
	["arena/hoop_rim", 2, "3d cd=0.2", "Clipping a hoop's rim (obstacle course)."],
	["arena/hoop_through", 2, "3d", "Swimming through the next hoop (obstacle course)."],
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
	["hunt/target_spotted", 2, "", "Hunt: the hunter locks on and comes at you."],
	["hunt/caught", 2, "", "Hunt: the hunter batters you."],
	["hunt/escaped", 2, "", "Hunt: you got away (a close call or a dodge)."],

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
	["unnatural/attack_own_fire", 1, "3d voices=3", "Any attack fires (every attack falls back to this one, so a single recording covers them all)."],
	["unnatural/attack_own_hit", 1, "3d voices=3 cd=0.03", "Any attack lands (every attack falls back to this one)."],
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
	["unnatural/punch_fire", 1, "3d voices=3", "Cavitation Punch throws a glove."],
	["unnatural/punch_hit", 1, "3d voices=3 cd=0.03", "Cavitation Punch lands (the glove, then the bubble collapsing)."],
	# Unnatural: zombies.
	["unnatural/zombie_spawn", 3, "3d voices=2 cd=0.2", "A zombie rises from the seabed (heavily rate-limited)."],
	["unnatural/zombie_moan_loop", 2, "loop voices=1", "The horde's moan: one loop, louder the more are near."],
	["unnatural/zombie_hit", 1, "3d layers voices=3 cd=0.04", "Zombies take damage from something with no sound of its own (a blast, a ring). Gathered per frame: more hits, harder layer."],
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
	["unnatural/xp", 1, "pitched voices=3 cd=0.03", "XP from your kills: once a frame a kill lands, climbing the scale while the kills keep coming."],
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
	["unnatural/pickup_lightning", 1, "", "Lightning bolt pickup: a big arena-wide electric crack."],
	["unnatural/magnet_pull_loop", 3, "loop voices=1", "The magnet hoovering up XP."],
	["unnatural/chest_buried", 2, "3d", "A treasure chest appears."],
	["unnatural/chest_open", 1, "3d", "A chest opens."],
	["unnatural/chest_boss_item", 1, "3d", "A boss's chest opens on its boss item: bigger, deeper, triumphant."],
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
	["pw/haze_scatter", 1, "3d voices=2", "Purple Haze lobs its bombs."],
	["pw/haze_burst", 1, "3d voices=4 cd=0.05", "A Purple Haze bomb bursts into a cloud."],
	["pw/depth_charge_arm", 2, "3d", "A depth charge arms."],
	["pw/lure_drop", 2, "3d", "The Anglerfish Lure drops."],
	["pw/lure_loop", 2, "3d loop voices=2", "The lure glowing."],
	["pw/lure_burst", 2, "3d", "The lure bursts."],
	["pw/tsunami_wave", 1, "3d", "Tsunami Heart's wave."],
	["pw/drowned_fin_charge_loop", 1, "loop voices=1", "Drowned Fin charging."],
	["pw/drowned_fin_dash", 1, "3d", "Drowned Fin's dash."],
	["pw/coil_loop", 2, "3d loop voices=1", "Leviathan's Coil trailing."],
	["pw/coil_hit", 2, "3d voices=3 cd=0.05", "A coil hurts something."],
	["pw/maw_suck", 2, "3d voices=2", "Gulper's Maw opens and starts sucking zombies in."],
	["pw/maw_spit", 2, "3d voices=2", "Gulper's Maw gulps shut and spits its volley."],
	["pw/brood_bite", 2, "3d voices=3 cd=0.05", "A Hagfish Brood hagfish bites and knots on."],
	["pw/disc_latch", 2, "3d voices=2", "Queen's Disc latches on (a wet suck)."],
	["pw/disc_drain", 3, "voices=1 cd=0.2", "Queen's Disc drains a sip of life back to you."],
	["pw/crown_burst", 2, "3d voices=2", "Angel's Crown bursts open on your head."],
	["pw/crown_lash", 2, "3d voices=3 cd=0.05", "One of Angel's Crown's lashes."],
	["pw/jaws_ready", 2, "voices=1", "Drowned Jaws are ready: your next attack chomps."],
	["pw/cursed_take", 2, "", "Taking a cursed powerup."],

	# Stage events.
	["stage/ring_warn", 1, "", "Warning: the ring is about to close."],
	["stage/ring", 1, "", "THE RING CLOSES."],
	["stage/miniboss_warn", 1, "", "Warning: THE DROWNED SHARK RISES."],
	["stage/boss_warn", 1, "", "Warning: THE BLOOD LEVIATHAN WAKES."],
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
	["boss/shark_bite_wind", 2, "3d voices=2", "The Drowned Shark draws back to chomp: a low creak and a growl building (about a tenth of a second)."],
	["boss/shark_jaw_open", 2, "3d voices=2", "Its jaw cracks open: a wet, bony pop, then the hold that follows is silence you can hear."],
	["boss/shark_snap", 2, "3d voices=2", "The lunge, just before the jaws land: a short heavy whoosh. The crunch itself is boss/chomp."],
	["boss/leviathan_arrive", 1, "", "The Blood Leviathan arrives."],
	["boss/leviathan_phase", 1, "", "The Blood Leviathan changes phase (circle, spit, fury)."],
	["boss/leviathan_spit", 2, "3d voices=3", "The Blood Leviathan spits."],
	["boss/chomp", 1, "3d voices=2", "A boss's jaws snap shut (the Drowned Shark, the King of Herrings)."],
	["boss/chomp_thud", 1, "3d voices=2", "A chomp lands: the low impact under the crunch (a boss's bite or grab, Drowned Jaws)."],
	["boss/chomp_miss", 1, "3d voices=2", "A chomp misses: the jaws clack shut on nothing."],
	["boss/grab", 1, "3d", "A final boss grabs a player: swallowed, coiled, latched on, knotted or crowned."],
	["boss/break_free", 1, "", "A held player strides free of a final boss."],
	["boss/gulper_suck", 2, "3d", "The Gulper Mother starts sucking a player in."],
	["boss/angel_lock", 2, "3d", "The Fallen Angel locks on to a player."],
	["boss/enraged", 1, "", "A boss is enraged."],
	["boss/hit", 1, "3d layers voices=2 cd=0.05", "A boss takes damage."],
	["boss/defeated", 1, "", "A boss is defeated."],

	# What Stinks? Hunters' held bite (two-stage-attack.md section 6). Stand-ins: FALLBACKS, until recorded.
	["hunter/jaw_open", 1, "3d voices=2", "A Hunter's jaws open on the press: a creak or a whoosh at the mouth (the Drowned Shark's; short, it answers the button on the same frame)."],
	["hunter/jaw_hold", 2, "loop 3d voices=2", "A Hunter's jaws held open: a growl whose pitch and loudness rise with the charge."],
	["hunter/charged", 2, "3d voices=2", "The held bite reaches full charge: a click or a ping."],
	["hunter/strain", 3, "3d voices=2", "A whale's mouth is full and strains against its limit."],
	["hunter/strike", 2, "3d voices=2", "The release: a swoosh as the jaws (or cones, coil, disc) lunge."],
	["hunter/chomp", 1, "3d voices=2", "A Hunter's bite lands on fish: the crunch."],
	["hunter/crunch", 2, "3d pitched voices=4 cd=0.03", "One more fish in the bite: a short crunch, climbing the scale through the chain."],
	["hunter/miss", 2, "3d voices=2", "A Hunter's jaws shut on nothing."],
	["whale/gape_open", 2, "3d voices=2", "A whale's huge mouth drops open: a deep groan and the rush of water in."],
	["whale/engulf", 2, "3d pitched voices=4 cd=0.05", "A fish swims into a whale's open mouth: a small pop, climbing with each."],
	["whale/gulp", 1, "3d voices=2", "The whale's mouth slams shut on everything in it: a deep gulp."],
	["whale/spray", 3, "3d voices=2", "Water pushed out of the whale's closing mouth."],
	["angel/cones_open", 2, "3d voices=2", "The Fallen Angel's buccal cones splay open."],
	["angel/lock", 2, "loop 3d voices=2", "The Fallen Angel is locked on to its target: a tightening hum."],
	["angel/lock_lost", 2, "3d", "The lock snaps (the target got away)."],
	["angel/lash", 1, "3d voices=2", "The cones lash out."],
	["angel/denied", 2, "3d", "A press with nothing in range: the crown flickers and refuses."],
	["gulper/suck", 2, "loop 3d voices=2", "The Gulper Mother's pouch sucks fish in: a rising draw."],
	["gulper/snap", 1, "3d voices=2", "The pouch snaps shut on what it caught."],
	["king/coil", 2, "loop 3d voices=2", "The King of Herrings coils tighter: a creak that rises."],
	["king/whip", 1, "3d voices=2", "The King's whip-sweep."],
	["lamprey/rasp", 2, "loop 3d voices=2", "The Lamprey Queen's teeth spin up: a rasp that speeds up."],
	["lamprey/drill", 1, "3d voices=2", "The Lamprey Queen's corkscrew dash through a school."],

	# Marco Polo.
	["mp/marco", 1, "3d", "The seeker calls \"Marco!\" (heard by everyone, from the seeker)."],
	["mp/polo", 1, "3d voices=6", "A hider (or a Fake Fish) answers \"Polo!\"."],
	["mp/tag", 1, "", "A seeker tags a hider: TAGGED!"],
	["mp/eliminated", 1, "", "A tagged hider is out (Last Fish Swimming): belly-up and floating away."],
	["mp/ping", 2, "voices=3 cd=0.05", "A blip lands on the seeker's sonar scope (seeker only)."],
	["mp/seen", 2, "voices=1 cd=0.4", "A soft tick while you're in the seeker's sight and scoring (only on the hider's own machine)."],
	["mp/heartbeat", 3, "3d voices=2 cd=0.3", "Optional: the seeker hears a faint heartbeat from a hider at the cardiovascular layer."],
	["mp/aura", 2, "3d voices=2 cd=0.3", "A hider flares into the aura layer (a big blunder)."],
	["mp/count", 1, "pitched", "The seeker's count while the hiders scatter (climbs)."],
	["mp/bump", 1, "3d layers voices=3 cd=0.08", "Two fish bump, or a fish knocks off a porthole's rim: a soft fleshy thud with a scale scrape, harder at speed."],
	["mp/round_over", 1, "", "The round ends: the ROUND_OVER card."],
	["mp/fake_throw", 3, "", "Throwing a Fake Fish (only the thrower hears it; it makes no noise in the game)."],
	["mp/fake_pop", 1, "3d", "A Fake Fish bursts into bubbles (end of its life, or tagged)."],
	["mp/fooled", 1, "", "The seeker tagged a Fake Fish: FOOLED!"],
	["mp/porthole_in", 2, "3d", "Slipping into a porthole."],
	["mp/porthole_out", 1, "3d", "Jumping out of a porthole: a loud whoosh."],
	["mp/gasp", 2, "voices=1 cd=0.6", "Gasping while the Out of Water gauge fills (the hider in the porthole)."],
	["mp/fish_out_of_water", 1, "3d", "The gauge fills: FISH OUT OF WATER! The fish flops out gasping."],
	["mp/airstone", 2, "3d loop voices=6", "An aquarium airstone / bubble curtain fizzing."],
	["mp/chest_burp", 2, "3d voices=2", "The aquarium's treasure chest pops open and burps bubbles."],
	# The Titan (adult whale) seeker.
	["mp/whomp", 1, "3d voices=4 cd=0.2", "A Titan's fluke power stroke: a deep whomp, louder with stride strength."],
	["mp/whomp_boost", 1, "3d voices=3 cd=0.15", "A Titan's hard boost beat."],
	["mp/voice_humpback", 1, "3d", "A humpback Titan's auto Marco! call: a short sung phrase."],
	["mp/voice_blue", 1, "3d", "A blue whale Titan's auto Marco! call: a low moan."],
	["mp/voice_orca", 1, "3d", "An orca Titan's auto Marco! call: a click train."],
	["mp/voice_beluga", 1, "3d", "A beluga Titan's auto Marco! call: chirps and clicks."],
	["mp/voice_sperm", 1, "3d", "A sperm whale Titan's auto Marco! call: slow, heavy clicks."],
	["mp/marco_tell", 2, "3d", "Blowhole bubbles just before a Titan's call (marco_tell_time)."],
	["mp/whale_grow", 1, "3d", "A caught hider grows into a Titan."],
	["mp/pick_cycle", 3, "voices=1 cd=0.05", "The whale pick card: species or skin changes."],
	["mp/pick_lock", 2, "", "The whale pick card: the pick locks in."],
	["mp/wake_swirl", 3, "3d voices=2 cd=0.3", "Optional: a Titan's vortex ring passes close."],

	# Shared effects.
	["fx/explosion", 1, "3d layers voices=4 cd=0.03", "An explosion (torpedoes, depth charges, the lure)."],
	["fx/burst_cloud", 2, "3d voices=3", "A burst cloud."],
	["fx/shock", 3, "3d voices=3", "Generic shock effect (a powerup without its own sound)."],
	["fx/ring", 3, "3d voices=3", "Generic ring effect."],
	["fx/flash", 3, "3d voices=3", "Generic flash effect."],
	["fx/spikes", 3, "3d voices=3", "Generic spikes effect."],
	["fx/pop", 3, "3d voices=3", "Generic pop effect."],

	# Ambience.
	["amb/arena_loop", 2, "loop voices=1", "The obstacle course's bed."],
	["amb/aquarium_loop", 2, "loop voices=1", "The aquarium arena's bed (Free Play, 1v1)."],
	["amb/ocean_loop", 2, "loop voices=1", "Open water (Free Swim, Nature, Hunt)."],
	["amb/seabed_loop", 2, "loop voices=1", "Unnatural's seabed (and the Test Tank's)."],
	["amb/murk_loop", 3, "loop voices=1", "Crossfades in as the water thickens (Unnatural's murk, an arena's edge)."],
	["amb/surface_loop", 3, "loop voices=1", "Above the waterline (the camera out of the water)."],

	# Callouts (optional, the Voice bus).
	["voice/go", 3, "", "Callout: go!"],
	["voice/goal", 3, "", "Callout: goal!"],
	["voice/fish_fry", 3, "", "Callout: Fish Fry!"],
	["voice/win", 3, "", "Callout: you win."],
	["voice/lose", 3, "", "Callout: you lose."],
	["voice/level_up", 3, "", "Callout: level up."],
	["voice/ring_warn", 3, "", "Callout: the ring closes."],
	["voice/miniboss_warn", 3, "", "Callout: the Drowned Shark rises."],
	["voice/boss_warn", 3, "", "Callout: the Blood Leviathan wakes."],
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
	"unnatural/sting_fire": "unnatural/attack_own_fire",
	"unnatural/bite_fire": "unnatural/attack_own_fire",
	"unnatural/lash_fire": "unnatural/attack_own_fire",
	"unnatural/thrust_fire": "unnatural/attack_own_fire",
	"unnatural/bubbles_fire": "unnatural/attack_own_fire",
	"unnatural/spines_fire": "unnatural/attack_own_fire",
	"unnatural/punch_fire": "unnatural/attack_own_fire",
	"unnatural/sting_hit": "unnatural/attack_own_hit",
	"unnatural/bite_hit": "unnatural/attack_own_hit",
	"unnatural/lash_hit": "unnatural/attack_own_hit",
	"unnatural/thrust_hit": "unnatural/attack_own_hit",
	"unnatural/bubbles_hit": "unnatural/attack_own_hit",
	"unnatural/spines_hit": "unnatural/attack_own_hit",
	"unnatural/punch_hit": "unnatural/attack_own_hit",
	"pw/haze_scatter": "pw/depth_charge_drop",
	"pw/haze_burst": "fx/explosion",
	"mp/bump": "fish/bump",
	"mp/fake_pop": "fx/pop",
	"mp/count": "match/countdown",
	"mp/airstone": "arena/bubble_column_loop",
	"hunter/jaw_open": "boss/shark_jaw_open",
	"hunter/jaw_hold": "boss/leviathan_arrive",
	"hunter/charged": "ui/select",
	"hunter/strain": "boss/chomp_miss",
	"hunter/strike": "boss/shark_snap",
	"hunter/chomp": "boss/chomp",
	"hunter/crunch": "boss/chomp_thud",
	"hunter/miss": "boss/chomp_miss",
	"whale/gape_open": "boss/gulper_suck",
	"whale/engulf": "boss/gulper_suck",
	"whale/gulp": "pw/maw_spit",
	"whale/spray": "boss/leviathan_spit",
	"angel/cones_open": "boss/angel_lock",
	"angel/lock": "boss/angel_lock",
	"angel/lock_lost": "boss/chomp_miss",
	"angel/lash": "boss/grab",
	"angel/denied": "ui/denied",
	"gulper/suck": "boss/gulper_suck",
	"gulper/snap": "pw/maw_spit",
	"king/coil": "boss/leviathan_arrive",
	"king/whip": "boss/chomp",
	"lamprey/rasp": "boss/grab",
	"lamprey/drill": "boss/grab",
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
