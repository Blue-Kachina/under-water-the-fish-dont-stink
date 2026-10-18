extends Node
## Not a probe: screenshots of the redesigned menus (UI Redesign Handoff) for
## checking them by eye: the home screen, the mode picker and a mode's rules,
## the settings (Game and Fish sections), the pause menu, Unnatural's HUD with
## held powerups as hex badges, and chest cards (treasure and cursed). Needs a
## window (not --headless).
##   Godot_console.exe --path . res://tests/ui_shots.tscn -- --out=DIR [--size=1600x900]

var out_dir := "user://ui_shots"
var main: Node
var fish: FishController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # through the home screen's pause
	var window_size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = window_size
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	main.set_mode(main.UNNATURAL, false)
	await _frames(10)
	var home: HomeScreen = main._home
	home.open()
	await _seconds(1.0)
	await _shot("home")
	home._cycle_fish(1)
	await _seconds(0.6)
	await _shot("home_next_fish")
	home._cycle_fish(-1)
	for i in 2:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _shot("home_dpad_down")
	home._play.grab_focus()
	home.open_picker()
	await _frames(6)
	await _shot("picker")
	home._picker._grid[1].grab_focus()
	await _frames(3)
	await _shot("picker_focus_hunt")
	home._picker._show_rules(main.UNNATURAL)
	await _frames(3)
	await _shot("picker_rules")
	home._picker._hide_rules()
	home._picker._cancel()

	var panel: Node = main._panel
	panel.set_open(true)
	await _frames(4)
	await _shot("settings_game")
	panel._focus_rows("fish")
	await _frames(3)
	var row: Node = panel._rows["fish/max_speed"]
	row.grab_focus()
	await _frames(3)
	await _shot("settings_fish")
	panel._focus_rows("display")
	await _frames(3)
	await _shot("settings_display")
	panel.set_open(false)
	home.close()
	await _frames(3)

	main._pause_menu.open()
	await _frames(4)
	await _shot("pause")
	main._pause_menu.close()

	# Unnatural with powerups held.
	main.start_mode(main.UNNATURAL)
	await _frames(20)
	var run: UnnaturalRun = main.unnatural_run
	UnnaturalSettings.shared().spawning = false
	var held := run.powerups_of(fish)
	for id: String in ["chain_lightning", "chain_lightning", "torpedo", "hermit_shell", "hermit_shell", "hermit_shell",
			"tsunami_heart", "drowned_fin", "blood_moon_shard"]:
		held.add(id)
	# The slots: the attack and Greek Fire at Lv 3 and 5; one tome, one free.
	var loadout := run.loadout_of(fish)
	loadout.add_weapon("greek_fire", 5)
	loadout.upgrade_weapon(Weapons.ATTACK, {"damage": 0.2})
	loadout.upgrade_weapon(Weapons.ATTACK, {"rate": 0.12})
	loadout.add_tome("teeth")
	loadout.add_tome("teeth")
	held.refresh()
	run.add_pearls(fish, 37)
	await _seconds(0.5)
	await _shot("hud_badges")
	Input.action_press("show_scoreboard")
	await _seconds(0.3)
	await _shot("hud_board")
	Input.action_release("show_scoreboard")
	await _seconds(0.3)
	# A Greek Fire trail from the fish back to (and past) the camera.
	# Spaced as fire_spacing drops them; the newest (nearest the fish) not lit yet.
	var camera := get_viewport().get_camera_3d()
	var back := (camera.global_position - fish.global_position).normalized()
	var spacing := PowerupSettings.shared().fire_spacing
	for i in 12:
		var patch := GreekFire.FirePatch.new()
		patch.lifetime = 30.0
		patch.position = fish.global_position + back * (0.8 + spacing * i) + Vector3.DOWN * 0.3
		patch.age = 0.0 if i == 0 else 1.0
		run.add_child(patch)
	# And a stretch off to the side, as the trail looks after a turn.
	var side := camera.global_basis.x
	for i in 6:
		var patch := GreekFire.FirePatch.new()
		patch.lifetime = 30.0
		patch.position = fish.global_position + back * 3.0 + side * (2.0 + spacing * i) + fish.global_basis.z * i * 0.8
		patch.age = 1.0
		run.add_child(patch)
	await _seconds(1.0)
	await _shot("greek_fire")
	for patch in run.get_children():
		if patch is GreekFire.FirePatch:
			patch.queue_free()

	# Torpedoes (at rest, posed) and a lightning bolt (held), beside the fish.
	var right := camera.global_basis.x
	var ahead := -camera.global_basis.z
	var torpedo_mesh := TorpedoLauncher.TorpedoSwarm._torpedo_mesh()
	var near := camera.global_position + ahead * 3.5
	for i in 4:
		var torpedo := MeshInstance3D.new()
		torpedo.mesh = torpedo_mesh
		run.add_child(torpedo)
		var at := near + right * (0.3 + i * 0.25) + camera.global_basis.y * (0.5 - 0.3 * i) + ahead * 0.6 * i
		# Side-on, then turning away from the camera.
		var heading := (right * (1.0 - 0.25 * i) + ahead * 0.35 * i).normalized()
		torpedo.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)
	var bolt := ChainLightning.Bolt.new()
	var start := fish.global_position - right * 3.0 + ahead * 1.0
	bolt.path = PackedVector3Array([start, start - right * 2.0 + ahead * 1.5, start - right * 1.0 + ahead * 4.0 + Vector3.UP,
			start - right * 3.5 + ahead * 5.5])
	run.add_child(bolt)
	bolt.set_process(false)  # held for the shot
	await _seconds(0.3)
	await _shot("torpedo_lightning")
	bolt.queue_free()

	var cards: LevelUpCards = main._unnatural_hud._cards
	cards.open([{"powerup": "chain_lightning", "stacks": 3, "tier": Rarity.Tier.UNCOMMON},
			{"powerup": "torpedo", "stacks": 1, "tier": Rarity.Tier.RARE},
			{"powerup": "tsunami_heart", "stacks": 1, "tier": Rarity.Tier.LEGENDARY}], "RARE TREASURE!",
			"PICK A POWERUP  ·  THE SAME ONE AGAIN STACKS", null)
	await _frames(6)
	await _shot("cards_treasure")
	cards.open([{"powerup": "blood_moon_shard", "stacks": 1, "tier": Rarity.Tier.CURSED},
			{"powerup": "sirens_song", "stacks": 2, "tier": Rarity.Tier.CURSED},
			{"powerup": "sunken_idol", "stacks": 1, "tier": Rarity.Tier.CURSED}], "CURSED TREASURE",
			"STRONG, WITH A CATCH  ·  CHOOSE CAREFULLY", null)
	cards.selected = 1
	await _frames(6)
	await _shot("cards_cursed")
	var settings := UnnaturalSettings.shared()
	cards.attack_kind = run.attack_of(fish).kind
	cards.open([{"kind": "weapon", "weapon": "greek_fire", "tier": Rarity.Tier.EPIC, "level": 5, "gains": {"burn": 0.5, "life": 2.0}},
			{"kind": "new_weapon", "weapon": "jellyfish_halo", "tier": Rarity.Tier.UNCOMMON, "level": 1, "gains": {}},
			{"kind": "tome", "tome": "kill", "tier": Rarity.Tier.LEGENDARY, "level": 3, "gives": Tomes.gives("kill", Rarity.multiplier(settings, Rarity.Tier.LEGENDARY), settings)}],
			"LEVEL 4", "+10 MAX HP  ·  +10% AREA (SIGNATURE)  ·  WEAPONS 2/2  ·  TOMES 1/2", null)
	await _frames(6)
	await _shot("cards_level")
	cards.open([{"kind": "weapon", "weapon": Weapons.ATTACK, "tier": Rarity.Tier.RARE, "level": 3, "gains": {"damage": 0.3, "size": 0.18}},
			{"kind": "new_tome", "tome": "pearls", "tier": Rarity.Tier.COMMON, "level": 1, "gives": Tomes.gives("pearls", 1.0, settings)},
			{"kind": "fallback", "what": "pearls", "tier": Rarity.Tier.COMMON, "amount": 14}], "LEVEL 9",
			"+10 MAX HP  ·  +10% AREA (SIGNATURE)  ·  WEAPONS 2/2  ·  TOMES 2/2", null)
	await _frames(6)
	await _shot("cards_level_2")
	cards.open([{"kind": "swap", "weapon": "greek_fire", "incoming": "leviathans_coil", "tier": Rarity.Tier.BOSS, "level": 5},
			{"kind": "keep", "weapon": "leviathans_coil", "tier": Rarity.Tier.COMMON}], "LEVIATHAN'S COIL: NO FREE SLOT",
			"SWAP A WEAPON FOR IT, OR KEEP YOURS", null)
	await _frames(6)
	await _shot("cards_swap")
	cards.close()
	get_tree().paused = false

	print("ui_shots: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


## A controller button pressed and let go.
func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, true).timeout
