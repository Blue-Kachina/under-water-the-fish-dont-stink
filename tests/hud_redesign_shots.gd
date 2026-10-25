extends Node
## Not a probe: screenshots of Unnatural's HUD after the HUD redesign
## (2026-10-25) for checking it by eye: the live HUD (top row, compass strip,
## loadout, dash button, stroke rhythm meter, minimap), the dash cooling, the
## run summary and its scoreboard, and a sheet of the marker icons (HudIcons).
## Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/hud_redesign_shots.tscn -- --out=DIR

var out_dir := "user://hud_redesign_shots"
var main: Node
var fish: FishController
var run: UnnaturalRun


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.stage_events = false
	settings.card_choices = 0
	settings.god_mode = true
	settings.chest_sense_range = 200.0
	settings.shrine_reveal_range = 0.0
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	run = main.unnatural_run
	run.start()
	await _frames(20)
	fish.freeze = true
	fish.swim_strokes = true
	fish.swim_style = FishController.SwimStyle.EXTRA_SWISHY
	# A late run's loadout.
	run.levels.level = 48
	run.levels.xp = run.levels.xp_to_next() * 0.78
	run._purses[fish] = 2050
	var loadout := run.loadout_of(fish)
	loadout.add_weapon(Weapons.ATTACK, 20)
	loadout.add_weapon("attack_leviathans_coil", 14)
	for n in 18:
		loadout.add_tome("tides")
	for n in 19:
		loadout.add_tome("shell")
	var powers := run.powerups_of(fish)
	for id in ["kelp_wrap", "kelp_wrap", "kelp_wrap", "hermit_shell", "hermit_shell", "clam_shield", "whirlpool_charm", "chain_lightning",
			"speedy_seahorse", "torpedo", "anglerfish_lure", "sea_salt", "sea_salt", "tsunami_heart"]:
		powers.add(id)
	var block := run.block_of(fish)
	var gains := {"damage": 4.7, "attack_speed": 2.064, "regen": 7.5, "armour": 23.6, "swim_speed": 0.06, "crit_chance": 0.09, "luck": 0.1}
	for stat: String in gains:
		block.add(stat, gains[stat])
	var stats := run.stats_of(fish)
	stats.by_source = {"bite": 1204000.0, "torpedo": 248900.0, "leviathans_coil": 187900.0, "whirlpool_charm": 157800.0,
			"anglerfish_lure": 126600.0, "chain_lightning": 65400.0, "tsunami_heart": 15900.0, "battery": 27500.0, "fin_dash": 9100.0}
	stats.kills = 18422
	stats.battered = 312
	stats.pearls = 1874
	stats.damage = 2043100.0
	for shrine in run.shrines:
		shrine.discovered = true
	# A stride most of the way to its peak, the last one well timed.
	var swim := fish.swishy
	swim.strides = 3
	swim.last_timing = 0.95
	swim.phase = swim.peak_time() * 0.72
	swim.power = swim.envelope(swim.phase)
	await _seconds(0.6)
	swim.phase = swim.peak_time() * 0.72
	await _shot("1_live")
	var twist := run.twist_of(fish)
	if twist:
		twist._cool = 3.0
		twist._cool_total = 6.0
	swim.phase = -1.0
	await _seconds(0.2)
	await _shot("2_dash_cooling")
	Input.action_press("show_scoreboard")
	await _seconds(0.3)
	await _shot("3_summary")
	main._unnatural_hud._summary.flip(1)
	await _seconds(0.2)
	await _shot("4_scoreboard")
	Input.action_release("show_scoreboard")
	await _seconds(0.2)
	var sheet := IconSheet.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(sheet)
	add_child(layer)
	await _seconds(0.2)
	await _shot("5_icons")
	get_tree().quit()


## The marker icons, large and small, on the HUD's ground.
class IconSheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.GROUND)
		for n in 2:
			var s := 64.0 if n == 0 else 22.0
			var y := 120.0 + n * 160.0
			HudIcons.draw_boss(self, Vector2(120, y), s)
			Minimap.draw_rift(self, Vector2(240, y), s * 0.35)
			HudIcons.draw_shrine(self, Vector2(360, y), s, Shrine.COLORS[0])
			HudIcons.draw_shrine(self, Vector2(480, y), s, Shrine.COLORS[2])
			HudIcons.draw_shrine(self, Vector2(600, y), s, Shrine.COLORS[1], true)
			HudIcons.draw_chest(self, Vector2(720, y), s, TreasureChest.GOLD)
			HudIcons.draw_chest(self, Vector2(840, y), s, TreasureChest.BLOOD)
			HudIcons.draw_mate(self, Vector2(960, y), s * 0.6, Color(1.0, 0.6, 0.24))
			HudIcons.draw_pearl(self, Vector2(1080, y), s)
			HudIcons.draw_heart(self, Vector2(1200, y), s, UnnaturalHud.HP_COLOR)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("shot ", shot_name)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
