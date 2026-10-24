class_name UnnaturalHud
extends CanvasLayer
## Unnatural's HUD (planning_unnatural.md §11), over the player's view:
## - a health bar under their fish (it flashes red when hurt);
## - the team's XP bar across the top (the controls hint and stride meter
##   have the bottom), with the level;
## - the stage clock (counting up) under it, with the kills under that;
## - a splash for each level-up, and when the run's over;
## - the results board (BroadcastUI.StatsBoard): held on D-pad up / B, and up
##   by itself once everyone's down. R starts again. Under each name, that
##   player's powerups as badges in their rarity's colour. Beside it, your own
##   fish: its attack, level and hp, and every stat it has (StatsPanel).
## - the minimap (Minimap) in the bottom-right.
## With show_director on, the director's live numbers sit under the clock. In
## the Test Tank a DPS readout (TestTank's numbers) sits on the right.
## - the stage: each event's warning splash, the next one under the kills,
##   and a boss's health bar under the XP bar while it's out (what the last
##   hits took trailing behind); beating the Leviathan puts up STAGE COMPLETE,
##   then the board.
## - feel (the Playability pass, P3): damage numbers (DamageNumbers), target
##   brackets, threat arrows and drop pings (CombatMarkers), and the hurt
##   vignette: a red flush when hit and a heartbeat under low_hp_share of hp.

const HP_COLOR := Color(0.9, 0.18, 0.2)
const XP_COLOR := Color(0.55, 0.85, 1.0)
const BOARD_COLOR := Color(0.55, 0.08, 0.1)
const HEADINGS := ["KILLS", "DAMAGE", "ATTACK", "BATTERY", "BATTERED FISH", "PEARLS", "TOP KM/H"]
## How long the run-over splash shows before the board comes up (s).
const OVER_SPLASH := 2.5
const HURT_SHADER := preload("res://shaders/hurt_vignette.gdshader")
## A hit's flush starts at least this strong, more for a bigger share of max hp
## (HURT_PER_SHARE per whole max hp), and fades this fast (1/s).
const HURT_MIN := 0.45
const HURT_PER_SHARE := 3.0
const HURT_FADE := 1.6

var run: UnnaturalRun
var fish: FishController
## The player's camera (a FollowCamera): swapping its survivor cam shows
## FOLLOW CAM or FREE CAM.
var player_camera: Camera3D:
	set(value):
		if is_instance_valid(player_camera) and player_camera.is_connected("survivor_cam_swapped", _show_cam_mode):
			player_camera.disconnect("survivor_cam_swapped", _show_cam_mode)
		player_camera = value
		if is_instance_valid(player_camera) and player_camera.has_signal("survivor_cam_swapped"):
			player_camera.connect("survivor_cam_swapped", _show_cam_mode)

## Feel (P3): the damage numbers and the target, threat and drop marks over the view.
var numbers := DamageNumbers.new()
var markers := CombatMarkers.new()
## The hurt vignette now: the hit's flush (1 fading to 0), the heartbeat's
## thump (0..1) and how low the hp is (0 above low_hp_share, 1 at none).
var hurt_level := 0.0
var beat_level := 0.0
var low_level := 0.0

var _bars := Bars.new()
var _minimap := Minimap.new()
var _clock := Label.new()
var _kills := Label.new()
var _skill := Label.new()
var _director := Label.new()
var _splash := BroadcastUI.Splash.new()
var _board := BroadcastUI.StatsBoard.new()
var _hurt := ColorRect.new()
## The Lightning Bolt's white-gold flash.
var _shock := ColorRect.new()
var _cards := LevelUpCards.new()
var _dps := DpsPanel.new()
var _stats := StatsPanel.new()
var _over_age := -1.0
var _cam_note := Label.new()
var _hurt_material := ShaderMaterial.new()
## The final boss's name, for the splash when it falls.
var _final_title := "THE FINAL BOSS"
var _beat_phase := 0.0


func _ready() -> void:
	layer = 2
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_material.shader = HURT_SHADER
	_hurt.material = _hurt_material
	_hurt.visible = false
	add_child(_hurt)
	_shock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shock.color = Color(1.0, 0.95, 0.7, 0.0)
	add_child(_shock)
	numbers.hud = self
	add_child(numbers)
	markers.hud = self
	add_child(markers)
	_bars.hud = self
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bars)
	_minimap.hud = self
	add_child(_minimap)
	for label: Label in [_clock, _kills, _director, _skill]:
		label.anchor_left = 0.5
		label.anchor_right = 0.5
		label.offset_left = -300.0
		label.offset_right = 300.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", BroadcastUI.font(800))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_clock.offset_top = 22.0
	_clock.add_theme_font_size_override("font_size", 40)
	_kills.offset_top = 70.0
	_kills.add_theme_font_size_override("font_size", 20)
	_kills.add_theme_color_override("font_color", Color(1.0, 0.75, 0.7))
	_skill.anchor_top = 0.9
	_skill.anchor_bottom = 0.9
	_skill.offset_top = -24.0
	_skill.offset_bottom = 24.0
	_skill.add_theme_font_size_override("font_size", 22)
	_director.offset_top = 98.0
	_director.add_theme_font_size_override("font_size", 14)
	_director.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_cam_note.anchor_left = 0.5
	_cam_note.anchor_right = 0.5
	_cam_note.anchor_top = 0.62
	_cam_note.anchor_bottom = 0.62
	_cam_note.offset_left = -300.0
	_cam_note.offset_right = 300.0
	_cam_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cam_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam_note.add_theme_font_override("font", BroadcastUI.font(800))
	_cam_note.add_theme_font_size_override("font_size", 26)
	_cam_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_cam_note.add_theme_constant_override("outline_size", 6)
	_cam_note.modulate.a = 0.0
	add_child(_cam_note)
	_splash.visible = false
	add_child(_splash)
	_dps.hud = self
	_dps.anchor_left = 1.0
	_dps.anchor_right = 1.0
	_dps.offset_left = -DpsPanel.WIDTH - 16.0
	_dps.offset_right = -16.0
	_dps.offset_top = 140.0
	_dps.offset_bottom = 520.0
	add_child(_dps)
	_stats.hud = self
	_stats.anchor_left = 1.0
	_stats.anchor_right = 1.0
	_stats.offset_left = -StatsPanel.WIDTH - 16.0
	_stats.offset_right = -16.0
	_stats.offset_top = 120.0
	_stats.offset_bottom = 900.0
	_stats.visible = false
	add_child(_stats)
	add_child(_cards)
	add_child(_board)
	_board.headings = HEADINGS
	if run:
		run.leveled_up.connect(func(level: int) -> void:
			if run.settings.card_choices <= 0:
				_splash.play("LEVEL UP", "LEVEL %d" % level, "MAX HP +%d" % roundi(run.settings.hp_per_level), XP_COLOR, 1.8))
		run.cards_offered.connect(func(for_fish: FishController, cards: Array, heading: String, line: String) -> void:
			if for_fish == fish:
				_cards.pauses = run.cards_pause_game()
				var attack := run.attack_of(fish)
				_cards.attack_kind = attack.kind if attack else FishAttack.Kind.BITE
				_cards.max_levels = Vector2i(run.settings.weapon_max_level, run.settings.tome_max_level)
				_cards.cancelable = run.can_cancel(fish)  # a chest, before the first pick
				_cards.rerolls = run.choices_of(fish, "rerolls") if run.can_choose(fish, "rerolls") else 0
				_cards.skips = run.choices_of(fish, "skips") if run.can_choose(fish, "skips") else 0
				_cards.banishes = run.choices_of(fish, "banishes") if run.can_choose(fish, "banishes") else 0
				_cards.open(cards, heading, line, fish.input_source))
		_cards.picked.connect(func(index: int) -> void: run.pick(fish, index))
		_cards.cancelled.connect(func() -> void: run.cancel_offer(fish))
		_cards.rerolled.connect(func() -> void: run.reroll(fish))
		_cards.skipped.connect(func() -> void: run.skip(fish))
		_cards.banished.connect(func(index: int) -> void: run.banish(fish, index))
		run.stage_began.connect(func(stage: int) -> void:
			var stages := run.settings.stages_in_run()
			_splash.play("STAGE %d" % stage, "DEEPER INTO THE NIGHT", ("THE LAST STAGE" if stages > 0 and stage >= stages else "THE DEAD COME HARDER"),
					TreasureChest.GOLD, 2.8))
		run.shrine_used.connect(_show_shrine)
		run.offer_cancelled.connect(func(for_fish: FishController) -> void:
			if for_fish == fish and not run.is_picking(fish):
				_cards.close())
		run.card_picked.connect(func(for_fish: FishController, _card: Dictionary) -> void:
			if for_fish == fish and not run.is_picking(fish):
				_cards.close())
		run.player_hurt.connect(func(hurt_fish: FishController, amount: float) -> void:
			if hurt_fish == fish:
				var health := run.health_of(fish)
				var share := amount / maxf(health.max_hp if health else 100.0, 1.0)
				hurt_level = maxf(hurt_level, clampf(HURT_MIN + share * HURT_PER_SHARE, HURT_MIN, 1.0)))
		run.run_over.connect(func() -> void:
			_over_age = 0.0
			_splash.play("THE BLOOD MOON WINS", "OVERRUN", "SURVIVED %s  ·  %d KILLS" % [_time_text(run.elapsed), run.kills],
					HP_COLOR, OVER_SPLASH))
		run.stage_warned.connect(func(event: String) -> void:
			_splash.play(StageTimeline.headline(event), "WARNING", StageTimeline.line(event), HP_COLOR, 2.4))
		run.boss_defeated.connect(func(boss: Boss, by: FishController) -> void:
			if boss is DrownedShark:
				_splash.play("DROWNED SHARK BEATEN", "MINI-BOSS DOWN", "%s  ·  IT DROPPED A BOSS CHEST" % (by.display_name.to_upper() if is_instance_valid(by) and by.display_name else "SURVIVORS"),
						TreasureChest.STEEL, 2.4))
		run.boss_arrived.connect(func(boss: Boss) -> void:
			var final := boss as BloodLeviathan
			if final == null:
				return
			_final_title = final.title
			_splash.play(final.title, "FINAL BOSS", final.boss_line(), HP_COLOR, 3.0)
			final.held_changed.connect(func(held: FishController, on: bool) -> void:
				if held == fish:
					if on:
						_note("STRIDE  ·  STRIDE  ·  STRIDE TO BREAK FREE", HP_COLOR)
					else:
						_cam_note.modulate.a = 0.0))
		run.boss_enraged.connect(func(boss: Boss) -> void:
			_splash.play("%s ENRAGES" % boss.title.trim_prefix("THE "), "NO TIME LIMIT", "AND THE DEAD KEEP COMING", HP_COLOR, 2.4))
		run.whirlpool_opened.connect(func(_at: Vector3) -> void:
			_splash.play("%s FALLS" % _final_title, "A WHIRLPOOL OPENS", ("FISH ON  ·  ENTER IT WHEN YOU'RE READY" if run.is_last_stage() else "ENTER IT FOR STAGE %d" % (run.stage + 1)),
					TreasureChest.GOLD, 3.0))
		run.stage_completed.connect(func() -> void:
			_over_age = 0.0
			_splash.play("STAGE COMPLETE", "THE NIGHT IS OVER", "%s  ·  %d KILLS" % [_time_text(run.elapsed), run.kills], TreasureChest.GOLD, OVER_SPLASH))
		run.drop_taken.connect(_show_drop)
		run.powerup_lost.connect(func(whose: FishController, id: String) -> void:
			if whose == fish:
				_note("THE SUNKEN IDOL TAKES YOUR %s" % Powerup.title(id).to_upper(), TreasureChest.BLOOD))
		run.restarted.connect(func() -> void:
			_over_age = -1.0
			_cards.close()
			_splash.hide_now())


## Where the minimap sits on the view (an empty rect when it's hidden), so
## the edge marks keep off it.
func minimap_rect() -> Rect2:
	return _minimap.get_rect() if _minimap.visible else Rect2()


func _show_cam_mode(free: bool) -> void:
	_note(("FREE CAM  ·  RIGHT STICK AIMS" if free else "FOLLOW CAM") + "  ·  Y SWAPS", Color.WHITE)


## A short note in the middle of the view that holds a moment, then fades.
func _note(text: String, color: Color) -> void:
	_cam_note.text = text
	_cam_note.add_theme_color_override("font_color", color)
	_cam_note.modulate.a = 1.6


## What Jump does over `shrine` (held while you're over it).
func _shrine_prompt(shrine: Shrine) -> String:
	var name_text := Shrine.title(shrine.kind).to_upper()
	match shrine.kind:
		Shrine.Kind.TIDE:
			return "JUMP  ·  %s  ·  HOLD ITS RING %d S FOR A CHEST" % [name_text, roundi(run.settings.shrine_tide_time)]
		Shrine.Kind.CHANCE:
			return "JUMP  ·  %s  ·  %d PEARLS FOR A %d%% CHANCE AT AN ITEM  ·  %d LEFT" % [name_text, run.shrine_price(shrine, fish),
					roundi(run.settings.shrine_chance_odds * 100.0), run.settings.shrine_chance_uses - int(shrine.tries.get(fish, 0))]
		Shrine.Kind.DEEP:
			return "JUMP  ·  %s  ·  MORE ELITES, MORE BOSS CHESTS" % name_text
	return "JUMP  ·  %s  ·  EVERY PEARL TO THE TEAM" % name_text


## What came of a shrine (`result`: UnnaturalRun.shrine_used's).
func _show_shrine(shrine: Shrine, by: FishController, result: String) -> void:
	if by != fish and result in ["won", "lost", "short", "tide_won"]:
		return  # theirs alone
	var color := shrine.tint()
	match result:
		"won":
			_note("THE SHRINE ANSWERS  ·  AN ITEM", color)
		"lost":
			_note("THE SHRINE IS SILENT", Color(0.7, 0.7, 0.75))
		"short":
			_note("NOT ENOUGH PEARLS  ·  %d NEEDED" % run.shrine_price(shrine, fish), TreasureChest.BLOOD)
		"tide":
			_splash.play("SHRINE OF THE TIDE", "HOLD THE RING", "STAY INSIDE FOR %d S" % roundi(run.settings.shrine_tide_time), color, 2.2)
		"tide_won":
			_note("THE TIDE IS HELD  ·  A CHEST RISES", color)
		"deep":
			_splash.play("SHRINE OF THE DEEP", "THE DEEP STIRS", "MORE ELITES  ·  BOSSES DROP MORE CHESTS", color, 2.4)
		"pearls":
			_note("SHRINE OF PEARLS  ·  EVERY PEARL TO THE TEAM", color)


## A drop taken: what it did (a heart heals the whole team).
func _show_drop(kind: int, by: FishController) -> void:
	var color: Color = Pickup.COLORS[kind]
	match kind:
		Pickup.Kind.HEART:
			_note("HEART  ·  +%d%% HP%s" % [roundi(run.settings.heart_heal * 100.0), "" if run.players.size() <= 1 else " FOR THE TEAM"], color)
		Pickup.Kind.MAGNET:
			_note("MAGNET  ·  EVERY PEARL TO %s" % ("YOU" if by == fish else (by.display_name.to_upper() if is_instance_valid(by) and by.display_name else "A FRIEND")), color)
		Pickup.Kind.HOURGLASS:
			_note("HOURGLASS  ·  THE DEAD STAND STILL  ·  %d S" % roundi(run.settings.hourglass_time), color)
		Pickup.Kind.LIGHTNING:
			_note("LIGHTNING  ·  THE WHOLE ARENA SHOCKED", color)
			_shock.color.a = 0.75


func _process(delta: float) -> void:
	if not is_instance_valid(run):
		return
	_update_hurt(delta)
	_shock.color.a = move_toward(_shock.color.a, 0.0, delta * 1.2)
	_cam_note.modulate.a = move_toward(_cam_note.modulate.a, 0.0, delta * 0.8)
	if is_instance_valid(fish) and run.near_whirlpool(fish):
		_note("JUMP  ·  ENTER THE WHIRLPOOL AND FINISH THE RUN" if run.is_last_stage() else "JUMP  ·  ENTER THE WHIRLPOOL  ·  ON TO STAGE %d" % (run.stage + 1),
				TreasureChest.GOLD)  # held while you're near
	elif is_instance_valid(fish) and run.unlocked_chest_near(fish):
		_note("JUMP  ·  OPEN THE CHEST", TreasureChest.GOLD)  # held while it waits
	elif is_instance_valid(fish) and run.shrine_near(fish):
		var shrine := run.shrine_near(fish)
		_note(_shrine_prompt(shrine), shrine.tint())
	var holder := run.current_boss() as BloodLeviathan
	if holder and holder.held == fish:
		_note("STRIDE  ·  STRIDE  ·  STRIDE TO BREAK FREE", HP_COLOR)  # held while it holds you
	_clock.text = _time_text(run.elapsed) if run.stage <= 1 else "STAGE %d  ·  %s" % [run.stage, _time_text(run.stage_time())]
	_kills.text = "%d KILLS" % run.kills
	_clock.visible = not _cards.is_open()  # the cards' heading is there
	_kills.visible = _clock.visible
	_update_skill()
	var next := run.timeline.next_event() if run.timeline and not run.tank else {}
	var tide := run.running_tide()
	if tide and not run.is_over:
		_kills.text += "    ·    HOLD THE TIDE  ·  %d%%" % roundi(run.tide_progress(tide) * 100.0)
	elif run.swarm_left() > 0.0 and not run.is_over:
		_kills.text += "    ·    %s  ·  SURVIVE %s" % [StageTimeline.headline(run.swarm.id).trim_prefix("THE "), _time_text(run.swarm_left())]
	elif not next.is_empty() and not run.is_over:
		_kills.text += "    ·    %s IN %s" % [StageTimeline.headline(next.id).trim_prefix("THE "), _time_text(maxf(next.time - run.stage_time(), 0.0))]
	_director.visible = run.settings.show_director and _clock.visible
	if _director.visible:
		var director := run.director
		_director.text = "DIRECTOR  alive %d / %d  ·  pressure x%.2f  ·  intensity %.2f%s  ·  kills/s %.1f  ·  pack %d  ·  elite %d%%  ·  difficulty %.1f" % [
				run.horde.alive_count(), director.target_alive(), director.pressure, director.intensity,
				"  ·  BREATHER %.0f s" % director.relief_left if director.in_relief() else "", director.kill_rate(),
				director.swarm_size(), roundi(director.elite_chance() * 100.0), run.difficulty()]
	if _over_age >= 0.0:
		_over_age += delta
	_update_board()


## The hurt vignette: the last hit's flush fading, and under low_hp_share of
## max hp a heartbeat (lub-dub, quicker the lower you are) over a faint red.
func _update_hurt(delta: float) -> void:
	var settings := run.settings
	hurt_level = move_toward(hurt_level, 0.0, delta * HURT_FADE)
	var health := run.health_of(fish) if is_instance_valid(fish) else null
	var low := maxf(settings.low_hp_share, 0.001)
	low_level = 0.0
	if health and not health.down and not run.is_over and health.share() < low:
		low_level = 1.0 - health.share() / low
	beat_level = 0.0
	if low_level > 0.0:
		var period := lerpf(1.1, 0.6, low_level)
		_beat_phase = fmod(_beat_phase + delta / period, 1.0)
		var lub := exp(-pow((_beat_phase - 0.05) / 0.05, 2.0))
		var dub := exp(-pow((_beat_phase - 0.28) / 0.06, 2.0)) * 0.7
		beat_level = maxf(lub, dub) * (0.5 + 0.5 * low_level)
	else:
		_beat_phase = 0.0
	var hurt := hurt_level * settings.hurt_vignette
	var beat := beat_level * settings.heartbeat_vignette
	var standing := low_level * settings.heartbeat_vignette
	_hurt.visible = hurt + beat + standing > 0.001
	if _hurt.visible:
		var view := _hurt.size
		_hurt_material.set_shader_parameter("hurt", hurt)
		_hurt_material.set_shader_parameter("beat", beat)
		_hurt_material.set_shader_parameter("low", standing)
		_hurt_material.set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))


func _update_board() -> void:
	var input: PlayerInput = fish.input_source if fish and fish.input_source else PlayerInput.everyone()
	_board.shown = input.pressed("show_scoreboard") or _over_age >= OVER_SPLASH
	_stats.visible = _board.shown and is_instance_valid(fish)
	if not _board.shown:
		return
	_stats.queue_redraw()
	_board.title = ("STAGE COMPLETE" if run.stage_complete else "RUN OVER") if run.is_over else "RUN STATS"
	var footer := "TIME  %s    ·    LEVEL  %d" % [_time_text(run.elapsed), run.levels.level]
	if run.stage > 1 or run.settings.stages_in_run() != 1:
		footer += "    ·    STAGE  %d%s" % [run.stage, "" if run.settings.stages_in_run() <= 0 else " / %d" % run.settings.stages_in_run()]
	if run.is_over:
		footer += "    ·    R: TRY AGAIN"
	_board.footer = footer
	var rows := []
	for player: FishController in run.players:
		if not is_instance_valid(player):
			continue
		var stats := run.stats_of(player)
		var by: Dictionary = stats.by_source
		var badges := []
		var attack := run.attack_of(player)
		var kind := attack.kind if attack else FishAttack.Kind.BITE
		for entry: Array in run.powerups_of(player).list():
			var id: String = entry[0]
			if Powerup.is_weapon(id):
				# As on the HUD: a diamond, gold (a boss's keeps its colour).
				var tint := UITheme.rarity(Rarity.Tier.BOSS) if id in Weapons.BOSS_ONLY else UITheme.GOLD
				badges.append([Weapons.glyph(id, kind), tint, HexBadge.Shape.DIAMOND])
			else:
				badges.append([id, UITheme.rarity(Powerup.tier(id)), HexBadge.Shape.HEX])
		rows.append({"name": player.display_name if player.display_name else "Player", "focus": player == fish, "values": [
			stats.kills, roundi(stats.damage), roundi(_attack_damage(by)), roundi(by.get("battery", 0.0)), stats.battered,
			stats.pearls, roundi(stats.top_speed * 3.6)], "badges": badges})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.values[0] > b.values[0])
	_board.teams = [{"name": "Survivors" if rows.size() > 1 else "Survivor", "score": run.kills, "color": BOARD_COLOR, "rows": rows}]


## Damage by any fish's auto-attack (a player may have had more than one, via the panel).
static func _attack_damage(by: Dictionary) -> float:
	var total := 0.0
	for source in FishAttack.sources():
		total += by.get(source, 0.0)
	return total


static func _time_text(seconds: float) -> String:
	var whole := floori(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## The Test Tank's DPS readout: each damage source's damage, DPS (recent
## and overall), hits and the kills it would have scored.
class DpsPanel extends Control:
	const WIDTH := 430.0
	const ROW := 26.0
	const COLUMNS := [["SOURCE", 110.0], ["DAMAGE", 70.0], ["DPS 5S", 66.0], ["DPS", 60.0], ["HITS", 56.0], ["KILLS", 56.0]]

	var hud: UnnaturalHud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		visible = is_instance_valid(hud.run) and hud.run.tank != null
		if visible:
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(hud.run) or hud.run.tank == null:
			return
		var tank := hud.run.tank
		var rows := tank.sources()
		var height := ROW * (rows.size() + 2)
		draw_rect(Rect2(0.0, 0.0, WIDTH, height), Color(BroadcastUI.INK, 0.8))
		BroadcastUI.text(self, Rect2(10.0, 0.0, WIDTH - 20.0, ROW), "TEST TANK  ·  %s  ·  LV %d  ·  R: RESET" % [UnnaturalHud._time_text(tank.elapsed), hud.run.levels.level],
				14, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 800)
		_row(ROW, COLUMNS.map(func(c: Array) -> String: return c[0]), Color(1, 1, 1, 0.6), 12)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var total: bool = r.source == "total"
			_row(ROW * (i + 2), [str(r.source).to_upper(), str(roundi(r.damage)), "%.0f" % r.dps, "%.0f" % r.overall, str(r.hits), str(r.kills)],
					BroadcastUI.GOLD if total else Color.WHITE, 15)

	func _row(y: float, cells: Array, color: Color, size_px: int) -> void:
		var x := 10.0
		for c in cells.size():
			var width: float = COLUMNS[c][1]
			BroadcastUI.text(self, Rect2(x, y, width, ROW), cells[c], size_px, color,
					HORIZONTAL_ALIGNMENT_LEFT if c == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 700)
			x += width


## Your own fish beside the results board: your fish and its attack, your
## level and hp, and every stat you have (the signature marked). The
## powerups are badges under each name on the board.
class StatsPanel extends Control:
	const WIDTH := 360.0
	const ROW := 22.0

	var hud: UnnaturalHud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var run := hud.run
		var fish := hud.fish
		if not is_instance_valid(run) or not is_instance_valid(fish) or run.health_of(fish) == null:
			return
		var lines := []  # [text, colour, size]
		var attack := run.attack_of(fish)
		lines.append(["%s  ·  %s" % [FishCharacter.display_name(fish.character).to_upper(),
				FishAttack.title(attack.kind).to_upper() if attack else "?"], BroadcastUI.GOLD, 16])
		var health := run.health_of(fish)
		lines.append(["LEVEL %d    ·    HP %d / %d    ·    %d PEARLS" % [run.levels.level, roundi(health.hp), roundi(health.max_hp),
				run.purse_of(fish)], Color.WHITE, 15])
		lines.append(["", Color.WHITE, 8])
		var loadout := run.loadout_of(fish)
		var kind := attack.kind if attack else FishAttack.Kind.BITE
		lines.append(["WEAPONS %d / %d" % [loadout.weapons.size(), run.settings.weapon_slots], Color(1, 1, 1, 0.6), 12])
		for id in loadout.weapons:
			lines.append(["%s  ·  LV %d" % [Weapons.title(id, kind), loadout.level(id)], Color.WHITE, 14])
		lines.append(["TOMES %d / %d" % [loadout.tomes.size(), run.settings.tome_slots], Color(1, 1, 1, 0.6), 12])
		for id in loadout.tomes:
			lines.append(["%s  ·  LV %d" % [Tomes.title(id), loadout.tome_level(id)], Tomes.color(id), 14])
		lines.append(["", Color.WHITE, 8])
		lines.append(["STATS", Color(1, 1, 1, 0.6), 12])
		var block := run.block_of(fish)
		var signature := StatBlock.signature(fish.character)
		var any := false
		for id: String in StatBlock.STATS:
			var value := block.value(id)
			if absf(value) < 0.0001:
				continue
			any = true
			lines.append([StatBlock.describe(id, value) + ("   (SIGNATURE)" if id == signature else ""),
					BroadcastUI.GOLD if id == signature else Color.WHITE, 14])
		if not any:
			lines.append(["none yet", Color(1, 1, 1, 0.5), 14])
		UnnaturalHud._add_damage_lines(lines, run.stats_of(fish))
		var height := 0.0
		for line: Array in lines:
			height += ROW if line[2] > 8 else 8.0
		draw_rect(Rect2(0.0, 0.0, WIDTH, height + 20.0), Color(BroadcastUI.INK, 0.85))
		draw_rect(Rect2(0.0, 0.0, 4.0, height + 20.0), BroadcastUI.GOLD)
		var y := 10.0
		for line: Array in lines:
			var tall: float = ROW if line[2] > 8 else 8.0
			if line[0] != "":
				BroadcastUI.text(self, Rect2(16.0, y, WIDTH - 28.0, tall), line[0], line[2], line[1], HORIZONTAL_ALIGNMENT_LEFT, 700)
			y += tall


## What a hit's `source` is called on the results: an attack, a powerup, ramming...
static func source_title(source: String) -> String:
	for kind: FishAttack.Kind in FishAttack.INFO:
		if FishAttack.INFO[kind][1] == source:
			return FishAttack.INFO[kind][0]
	match source:
		"battery":
			return "Battered (ramming)"
		"fin_dash":
			return "Fin Dash"
		"flare":
			return "Flare Dash"
		"gulp":
			return "Gulp"
		"snap":
			return "Mantis snap"
		"splash":
			return "Koi splashdown"
		"contact":
			return "Contact"
	return Powerup.title(source) if Powerup.ids().has(source) else source.capitalize()


## The DAMAGE block: each source's damage, its share of the total and a bar,
## biggest first (win or lose: how much each way of hurting them did).
static func _add_damage_lines(lines: Array, stats: Dictionary) -> void:
	var by: Dictionary = stats.by_source
	var rows := []
	var total := 0.0
	for source: String in by:
		rows.append([source, float(by[source])])
		total += float(by[source])
	if rows.is_empty():
		return
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	lines.append(["", Color.WHITE, 8])
	lines.append(["DAMAGE  ·  %s TOTAL" % _compact(total), Color(1, 1, 1, 0.6), 12])
	for k in mini(rows.size(), 10):
		var share: float = float(rows[k][1]) / maxf(total, 1.0)
		lines.append(["%s  ·  %s  ·  %d%%  %s" % [source_title(rows[k][0]), _compact(rows[k][1]), roundi(share * 100.0),
				"|".repeat(maxi(roundi(share * 16.0), 1))], Powerup.color(rows[k][0]) if Powerup.ids().has(rows[k][0]) else Color.WHITE, 14])


static func _compact(value: float) -> String:
	return "%.1fk" % (value / 1000.0) if value >= 10000.0 else str(roundi(value))


## The health bar under the fish and the XP bar along the top; the player's
## powerups (with their stacks) down the left; a ping on each shut chest
## within chest_sense_range (at the screen's edge if it's off screen), and a
## ring filling round the fish while it opens one by holding still.
class Bars extends Control:
	## A held powerup's badge and the gap between them, at the 1280×720 design's scale.
	const BADGE := 30.0
	const BADGE_GAP := 5.0
	## The badges' ×N chips were drawn for 56 px badges; they shrink with them.
	const CHIP_SCALE := BADGE / 56.0 * 1.15
	const HP_WIDTH := 96.0
	const HP_HEIGHT := 9.0
	const XP_HEIGHT := 10.0
	const PEARL_COLOR := Color(0.85, 0.92, 1.0)
	const SLOT_EMPTY := Color(1, 1, 1, 0.22)

	var hud: UnnaturalHud
	var _shown_hp := 1.0
	## The boss on the bar, and its trailing share.
	var _boss_shown: Boss
	var _boss_trail := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var run := hud.run
		if not is_instance_valid(run):
			return
		# XP: across the top, the level at its left.
		var bar := Rect2(110.0, 10.0, size.x - 140.0, XP_HEIGHT)
		draw_rect(bar.grow(2.0), Color(BroadcastUI.INK, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * run.levels.progress(), bar.size.y)), XP_COLOR)
		BroadcastUI.text(self, Rect2(bar.position.x - 90.0, bar.position.y - 8.0, 80.0, 26.0), "LV %d" % run.levels.level, 20,
				BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 800)
		_draw_boss(run)
		_draw_downed(run)
		var fish := hud.fish
		if is_instance_valid(fish):
			# The pearl purse, under the XP bar's right end (D23).
			BroadcastUI.text(self, Rect2(bar.end.x - 180.0, bar.position.y + 14.0, 180.0, 22.0), "%d PEARLS" % run.purse_of(fish), 17,
					PEARL_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, 800)
			_draw_powerups(run, fish)
			_draw_chests(run, fish)
		# Health: under the fish, where the camera sees it.
		var health := run.health_of(fish) if is_instance_valid(fish) else null
		var camera := get_viewport().get_camera_3d()
		if health == null or camera == null or camera.is_position_behind(fish.global_position):
			return
		var at := camera.unproject_position(fish.global_position - camera.global_basis.y * 0.9)
		var rect := Rect2(at.x - HP_WIDTH * 0.5, at.y + 18.0, HP_WIDTH, HP_HEIGHT)
		_shown_hp = move_toward(_shown_hp, health.share(), get_process_delta_time() * 0.6)
		draw_rect(rect.grow(2.0), Color(BroadcastUI.INK, 0.8))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * _shown_hp, rect.size.y)), Color(1.0, 0.85, 0.8, 0.6))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * health.share(), rect.size.y)), HP_COLOR)
		BroadcastUI.text(self, Rect2(rect.position.x, rect.end.y + 2.0, rect.size.x, 16.0),
				"%d / %d" % [ceili(health.hp), roundi(health.max_hp)], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)

	## Co-op (D7): a marker over each downed player, its revive filling; and
	## a line for this player while they're down.
	func _draw_downed(run: UnnaturalRun) -> void:
		var camera := get_viewport().get_camera_3d()
		if camera == null or run.players.size() < 2:
			return
		for player in run.players:
			var health := run.health_of(player)
			if not is_instance_valid(player) or health == null or not health.down:
				continue
			if player == hud.fish:
				BroadcastUI.text(self, Rect2(0.0, size.y * 0.62, size.x, 30.0), "YOU'RE DOWN  ·  A TEAMMATE CAN REVIVE YOU", 22, HP_COLOR,
						HORIZONTAL_ALIGNMENT_CENTER, 800)
			var at := player.global_position + Vector3.UP * 1.4
			if camera.is_position_behind(at):
				continue
			var spot := camera.unproject_position(at)
			draw_circle(spot, 20.0, Color(BroadcastUI.INK, 0.7))
			draw_arc(spot, 20.0, -PI / 2.0, -PI / 2.0 + TAU * run.revive_progress(player), 32, Color(0.5, 1.0, 0.6), 4.0)
			BroadcastUI.text(self, Rect2(spot.x - 60.0, spot.y - 9.0, 120.0, 18.0), "DOWN", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)

	## The boss out now: its name and health across the top, under the XP bar.
	func _draw_boss(run: UnnaturalRun) -> void:
		var boss := run.current_boss()
		if boss == null:
			return
		var width := minf(size.x * 0.5, 720.0)
		var bar := Rect2((size.x - width) * 0.5, 128.0, width, 14.0)
		draw_rect(bar.grow(3.0), Color(BroadcastUI.INK, 0.85))
		# What the last hits took, trailing behind (P3), then the hp left.
		if boss != _boss_shown:
			_boss_shown = boss
			_boss_trail = boss.share()
		_boss_trail = maxf(move_toward(_boss_trail, boss.share(), get_process_delta_time() * 0.25), boss.share())
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_trail, bar.size.y)), Color(1.0, 0.9, 0.8, 0.55))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * boss.share(), bar.size.y)), Color(1.0, 0.4, 0.2) if boss.enraged else HP_COLOR)
		if boss.flash > 0.0:
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * boss.share(), bar.size.y)), Color(1.0, 1.0, 1.0, boss.flash * 0.35))
		var name_line := boss.title + ("  ·  ENRAGED" if boss.enraged else "")
		BroadcastUI.text(self, Rect2(bar.position.x, bar.position.y - 26.0, bar.size.x, 24.0), name_line, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)

	## Top-left under the XP bar (the Playability pass, P1f): the weapon slots,
	## then the tome slots, each badge (HexBadge) with its level on a chip and
	## each free slot an empty outline; then the items in the order they were
	## picked up, each rimmed in its rarity's colour, with a ×N chip once it has
	## 2 or more stacks. The items wrap onto more rows when the view's narrow
	## (split-screen).
	func _draw_powerups(run: UnnaturalRun, fish: FishController) -> void:
		var k := minf(size.x / UITheme.REF_SIZE.x, size.y / UITheme.REF_SIZE.y)
		var badge := BADGE * k
		var gap := BADGE_GAP * k
		var per_row := maxi(floori((size.x * 0.3 + gap) / (badge + gap)), 1)  # clear of the clock and kills
		var loadout := run.loadout_of(fish)
		var attack := run.attack_of(fish)
		var kind := attack.kind if attack else FishAttack.Kind.BITE
		var row := 0
		# Weapons.
		var slots := maxi(run.settings.weapon_slots, loadout.weapons.size())
		for n in slots:
			var centre := _slot_at(n, row, badge, gap)
			if n < loadout.weapons.size():
				var id := loadout.weapons[n]
				# Weapons have no rarity of their own (a boss's keeps its colour).
				var tint := UITheme.rarity(Rarity.Tier.BOSS) if id in Weapons.BOSS_ONLY else UITheme.GOLD
				HexBadge.draw_badge(self, centre, badge, Weapons.glyph(id, kind), tint, true, UITheme.HUD_FILL, HexBadge.Shape.DIAMOND)
				_level_chip(centre, badge, loadout.level(id), k)
			else:
				HexBadge.draw_shape(self, HexBadge.Shape.DIAMOND, centre, badge, Color(UITheme.HUD_FILL, 0.35), SLOT_EMPTY, 2.0 * k)
		# Tomes.
		if run.settings.tome_slots > 0 or not loadout.tomes.is_empty():
			row += 1
			for n in maxi(run.settings.tome_slots, loadout.tomes.size()):
				var centre := _slot_at(n, row, badge, gap)
				if n < loadout.tomes.size():
					var id := loadout.tomes[n]
					HexBadge.draw_badge(self, centre, badge, Tomes.glyph(id), Tomes.color(id), true, UITheme.HUD_FILL, HexBadge.Shape.SQUARE)
					_level_chip(centre, badge, loadout.tome_level(id), k)
				else:
					HexBadge.draw_shape(self, HexBadge.Shape.SQUARE, centre, badge, Color(UITheme.HUD_FILL, 0.35), SLOT_EMPTY, 2.0 * k)
		# Items.
		row += 1
		var n := 0
		for entry: Array in run.powerups_of(fish).items():
			var id: String = entry[0]
			var stacks: int = entry[1]
			var centre := _slot_at(n % per_row, row + n / per_row, badge, gap)
			HexBadge.draw_badge(self, centre, badge, id, UITheme.rarity(Powerup.tier(id)), true, UITheme.HUD_FILL)
			if stacks >= 2:
				HexBadge.draw_stack_chip(self, centre, badge, stacks, k * CHIP_SCALE)
			n += 1

	func _slot_at(column: int, row: int, badge: float, gap: float) -> Vector2:
		return Vector2(16.0 + badge * 0.5 + column * (badge + gap), 40.0 + badge * 0.5 + row * (badge + gap))

	## A small level number on a slot's bottom-right.
	func _level_chip(centre: Vector2, badge: float, level: int, k: float) -> void:
		var px := roundi(11.0 * k)
		var rect := Rect2(centre + Vector2(badge * 0.5 - 15.0 * k, badge * 0.5 - 13.0 * k), Vector2(17.0 * k, 14.0 * k))
		UITheme.draw_box(self, rect, UITheme.INK, 7.0 * k)
		UITheme.draw_text(self, rect, str(level), UITheme.condensed(700), px, UITheme.GROUND)

	func _draw_chests(run: UnnaturalRun, fish: FishController) -> void:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var view := Rect2(Vector2.ZERO, size).grow(-40.0)
		for chest in run.shut_chests_for(fish):
			var at := chest.global_position + Vector3.UP
			var gap := at.distance_to(fish.global_position)
			if gap > run.settings.chest_sense_range + run.chest_ping_bonus_of(fish):
				continue
			var spot: Vector2
			var behind := camera.is_position_behind(at)
			spot = camera.unproject_position(at)
			if behind:
				spot = size - spot  # mirrored: it's behind
			var inside := view.has_point(spot) and not behind
			if not inside:
				var middle := size * 0.5
				var direction := (spot - middle).normalized()
				var reach := minf(absf(view.size.x * 0.5 / direction.x) if absf(direction.x) > 0.001 else INF,
						absf(view.size.y * 0.5 / direction.y) if absf(direction.y) > 0.001 else INF)
				spot = middle + direction * reach
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
			var diamond := PackedVector2Array([spot + Vector2(0, -12), spot + Vector2(10, 0), spot + Vector2(0, 12), spot + Vector2(-10, 0)])
			var tint := chest.tint()
			draw_colored_polygon(diamond, Color(tint, 0.5 + 0.4 * pulse))
			var price := run.chest_price(chest, fish)
			var label := "%d M" % roundi(gap)
			if price > 0:
				label += "  ·  %d PEARLS" % price
			var afford := run.can_afford(fish, chest)
			BroadcastUI.text(self, Rect2(spot.x - 60.0, spot.y + 12.0, 120.0, 18.0), label, 13, tint if afford else Color(1.0, 0.45, 0.4),
					HORIZONTAL_ALIGNMENT_CENTER, 700)
			if chest.progress_of(fish) > 0.0 and inside:
				draw_arc(spot, 22.0, -PI / 2.0, -PI / 2.0 + TAU * chest.progress_of(fish), 32, tint, 4.0)


## The mobility skill's readout at the bottom of the view: RB, its name, and
## READY, ON, or the seconds left on its cooldown.
func _update_skill() -> void:
	var twist: Traversal = run.twist_of(fish) if is_instance_valid(fish) else null
	_skill.visible = twist != null and run.settings.twists and not _cards.is_open() and Traversal.skill_title(fish.character) != ""
	if not _skill.visible:
		return
	var state := "ON  ·  PRESS TO END" if twist.quiet else ("ON" if twist.skill_active() else ("READY" if twist.skill_wait() <= 0.0 else "%.1f" % twist.skill_wait()))
	_skill.text = "RB  ·  %s  ·  %s" % [Traversal.skill_title(fish.character).to_upper(), state]
	_skill.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8) if twist.skill_wait() <= 0.0 else Color(1.0, 1.0, 1.0, 0.6))
