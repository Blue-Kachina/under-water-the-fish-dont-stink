class_name UnnaturalHud
extends CanvasLayer
## Unnatural's HUD (planning_unnatural.md §11; restyled by the HUD redesign,
## 2026-10-25, in Barlow), over the player's view:
## - a health bar under their fish (it flashes red when hurt);
## - the top row: the team's level, its XP bar and count, and your pearls
##   (Bars), with the compass strip (CompassStrip) under it;
## - the stage clock (counting up) under that, with the kills under it;
## - your loadout top-left, see-through: weapons, tomes and powerups, thin
##   rims in their colours;
## - the mobility skill's button at the bottom (SkillButton), over the stroke
##   rhythm meter (the main HUD's StrideMeter); no controls line;
## - a splash for each level-up, and when the run's over;
## - the results (RunSummary): the scoreboard held on D-pad up / B; once
##   everyone's down it stays up by itself, with a summary side panel (a
##   player's loadout, stats and damage contribution; scrolls; in co-op the
##   right stick flicks between players). R starts again.
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

const HP_COLOR := Color(1.0, 84 / 255.0, 104 / 255.0)
const XP_COLOR := Color(70 / 255.0, 214 / 255.0, 1.0)
## The level's gold, and the thin pale rim round the HUD's panels.
const LEVEL_COLOR := Color(1.0, 201 / 255.0, 74 / 255.0)
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
var _compass := CompassStrip.new()
var _clock := Label.new()
var _kills := Label.new()
var _skill := SkillButton.new()
var _director := Label.new()
var _splash := BroadcastUI.Splash.new()
var _summary := RunSummary.new()
var _hurt := ColorRect.new()
## The Lightning Bolt's white-gold flash.
var _shock := ColorRect.new()
var _cards := LevelUpCards.new()
var _dps := DpsPanel.new()
var _break := BreakFree.new()
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
	_compass.hud = self
	add_child(_compass)
	for label: Label in [_clock, _kills, _director]:
		label.anchor_left = 0.5
		label.anchor_right = 0.5
		label.offset_left = -300.0
		label.offset_right = 300.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", UITheme.condensed(700))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_clock.offset_top = CompassStrip.BASE
	_clock.add_theme_font_size_override("font_size", 42)
	_kills.offset_top = CompassStrip.BASE + 48.0
	_kills.add_theme_font_size_override("font_size", 20)
	_kills.add_theme_color_override("font_color", Color(1.0, 0.78, 0.74))
	_skill.hud = self
	_skill.anchor_left = 0.5
	_skill.anchor_right = 0.5
	_skill.anchor_top = 1.0
	_skill.anchor_bottom = 1.0
	_skill.offset_left = -SkillButton.SIZE.x * 0.5
	_skill.offset_right = SkillButton.SIZE.x * 0.5
	add_child(_skill)
	_break.anchor_left = 0.5
	_break.anchor_right = 0.5
	_break.anchor_top = 0.66
	_break.anchor_bottom = 0.66
	_break.offset_left = -BreakFree.SIZE.x * 0.5
	_break.offset_right = BreakFree.SIZE.x * 0.5
	_break.offset_top = -BreakFree.SIZE.y * 0.5
	_break.offset_bottom = BreakFree.SIZE.y * 0.5
	add_child(_break)
	_director.offset_top = CompassStrip.BASE + 76.0
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
	_cam_note.add_theme_font_override("font", UITheme.condensed(700))
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
	add_child(_cards)
	_summary.hud = self
	_summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary.visible = false
	add_child(_summary)
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
		run.rift_woken.connect(func(by: FishController) -> void:
			var who := "YOU" if by == fish else (by.display_name.to_upper() if is_instance_valid(by) and by.display_name else "SOMEONE")
			_note("%s WENT DOWN THE CREVICE  ·  SOMETHING WAKES" % who, Minimap.RIFT_COLOR))
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
				_splash.play("DROWNED SHARK BEATEN", "MINI-BOSS DOWN", "%s  ·  %s" % [by.display_name.to_upper() if is_instance_valid(by) and by.display_name else "SURVIVORS",
						"IT COMES BACK SOON" if run.tank else "IT DROPPED A BOSS CHEST"],
						TreasureChest.STEEL, 2.4))
		run.boss_arrived.connect(func(boss: Boss) -> void:
			var final := boss as BloodLeviathan
			if final == null:
				return
			_final_title = final.title
			_splash.play(final.title, "FINAL BOSS", final.boss_line(), HP_COLOR, 3.0)
			final.held_changed.connect(func(held: FishController, on: bool) -> void:
				if held == fish and on:
					_cam_note.modulate.a = 0.0))  # the break-free panel says it
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


## Whether the cards are up (their heading takes the top of the view).
func cards_up() -> bool:
	return _cards.is_open()


## How far the compass strip pushes down what sits under the XP bar (px).
func top_push() -> float:
	return _compass.push()


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
	elif is_instance_valid(fish) and run.rift_near(fish):
		_note("A CREVICE  ·  IT GOES DOWN A LONG WAY  ·  RED LIGHT BELOW  ·  DIVE IN TO WAKE THE FINAL BOSS", Minimap.RIFT_COLOR)  # held while you're near
	_break.show_for(run.holder_of(fish) if is_instance_valid(fish) else null, delta)
	if _break.visible:
		_cam_note.modulate.a = 0.0
	_clock.text = _time_text(run.elapsed) if run.stage <= 1 else "STAGE %d  ·  %s" % [run.stage, _time_text(run.stage_time())]
	_kills.text = "%d KILLS" % run.kills
	_clock.visible = not _cards.is_open() and not _summary.visible  # the cards' heading is there; the summary covers it
	var push := top_push()
	_clock.offset_top = CompassStrip.BASE + push
	_kills.offset_top = CompassStrip.BASE + 48.0 + push
	_director.offset_top = CompassStrip.BASE + 76.0 + push
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


## The results: the scoreboard alone while show_scoreboard's held; once the
## run's over (after its splash) it stays up, with the summary side panel.
func _update_board() -> void:
	var input: PlayerInput = fish.input_source if fish and fish.input_source else PlayerInput.everyone()
	var over := _over_age >= OVER_SPLASH
	var shown := (input.pressed("show_scoreboard") or over) and is_instance_valid(fish)
	if shown and (not _summary.visible or _summary.summary_shown() != over):
		_summary.open(input, over)
	elif not shown and _summary.visible:
		_summary.visible = false


## Damage by any fish's auto-attack (a player may have had more than one, via the panel).
static func _attack_damage(by: Dictionary) -> float:
	var total := 0.0
	for source in FishAttack.sources():
		total += by.get(source, 0.0)
	return total


static func _time_text(seconds: float) -> String:
	var whole := floori(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## `value` with its thousands split by commas ("24,000").
static func thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## A big number as the results show it: 950, 12.4k, 1.20M.
static func compact(value: float) -> String:
	if value >= 1.0e6:
		return "%.2fM" % (value / 1.0e6)
	if value >= 1.0e3:
		return "%.1fk" % (value / 1.0e3)
	return str(roundi(value))


## HUD text (Barlow Condensed, 600 or 700) with a soft dark outline, so it
## reads over the water; vertically centred in `rect`, shrunk to fit its width.
static func hud_text(canvas: CanvasItem, rect: Rect2, value: String, px: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, weight := 700) -> void:
	var font := UITheme.condensed(700 if weight >= 700 else 600)
	while px > 6 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > rect.size.x:
		px -= 1
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(px) - font.get_descent(px)) / 2.0
	var at := Vector2(rect.position.x, baseline)
	canvas.draw_string_outline(font, at, value, align, rect.size.x, px, maxi(roundi(px / 5.0), 2), Color(0.0, 0.03, 0.06, 0.55 * color.a))
	canvas.draw_string(font, at, value, align, rect.size.x, px, color)


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


## The top row (the team's level, its XP bar and count, your pearls); the
## health bar under the fish; your loadout down the left; a ping on each shut
## chest within chest_sense_range (at the screen's edge if it's off screen),
## and a ring filling round the fish while it opens one by holding still.
## Sizes are at the 1280×720 design's scale, times k().
class Bars extends Control:
	## The top row's middle (px from the top) and its side margin.
	const ROW_MIDDLE := 26.0
	const MARGIN := 21.0
	const XP_HEIGHT := 9.0
	const HP_WIDTH := 96.0
	const HP_HEIGHT := 7.0
	## The loadout panel: its top, padding, the label column's width, and each
	## kind of badge's size (HexBadge's 100-unit box: a diamond spans all of it,
	## a square 78%, a hexagon 80% across).
	const PANEL_TOP := 56.0
	const PANEL_PAD := 11.0
	const LABEL_WIDTH := 50.0
	const WEAPON_SIZE := 36.0
	const TOME_SIZE := 44.0
	const ITEM_SIZE := 36.0
	const ITEM_GAP := 3.0
	const ITEMS_PER_ROW := 6
	const LABEL := Color(169 / 255.0, 195 / 255.0, 211 / 255.0)
	const RIM := Color(150 / 255.0, 215 / 255.0, 1.0, 0.22)
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

	## How much bigger than the 1280×720 design this view shows the HUD.
	func k() -> float:
		return maxf(minf(size.x / UITheme.REF_SIZE.x, size.y / UITheme.REF_SIZE.y), 0.75)

	func _draw() -> void:
		var run := hud.run
		if not is_instance_valid(run):
			return
		var fish := hud.fish
		_draw_top_row(run, fish)
		_draw_boss(run)
		_draw_downed(run)
		if is_instance_valid(fish):
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
		var r := HP_HEIGHT * 0.5
		UITheme.draw_box(self, rect.grow(1.5), Color(UITheme.DEEP, 0.75), r + 1.5)
		if _shown_hp > 0.0:
			UITheme.draw_box(self, Rect2(rect.position, Vector2(maxf(rect.size.x * _shown_hp, HP_HEIGHT), rect.size.y)), Color(1.0, 0.85, 0.8, 0.55), r)
		if health.share() > 0.0:
			UITheme.draw_box(self, Rect2(rect.position, Vector2(maxf(rect.size.x * health.share(), HP_HEIGHT), rect.size.y)), HP_COLOR, r)
		UnnaturalHud.hud_text(self, Rect2(rect.position.x - 20.0, rect.end.y + 2.0, rect.size.x + 40.0, 16.0),
				"%d / %d" % [ceili(health.hp), roundi(health.max_hp)], 13, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER, 600)

	## One row across the top: LV and the level (gold), the XP bar, the XP so
	## far and needed, a divider, then a pearl and your purse.
	func _draw_top_row(run: UnnaturalRun, fish: FishController) -> void:
		var s := k()
		var y := ROW_MIDDLE * s
		var x := MARGIN * s
		var bold := UITheme.condensed(700)
		var semi := UITheme.condensed(600)
		var small := roundi(12.0 * s)
		var big := roundi(28.0 * s)
		var level := str(run.levels.level)
		var base := y + (bold.get_ascent(big) - bold.get_descent(big)) * 0.5
		_outlined(semi, Vector2(x, base), "LV", small, LABEL)
		x += semi.get_string_size("LV", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 4.0 * s
		_outlined(bold, Vector2(x, base), level, big, LEVEL_COLOR)
		x += bold.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + 12.0 * s
		var right := size.x - MARGIN * s
		if is_instance_valid(fish):
			var purse := UnnaturalHud.thousands(run.purse_of(fish))
			var px := roundi(21.0 * s)
			var width := bold.get_string_size(purse, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			_outlined(bold, Vector2(right - width, y + (bold.get_ascent(px) - bold.get_descent(px)) * 0.5), purse, px, UITheme.INK)
			HudIcons.draw_pearl(self, Vector2(right - width - 5.0 * s - 10.0 * s, y), 22.0 * s)
			right -= width + 5.0 * s + 20.0 * s + 11.0 * s
			draw_line(Vector2(right, y - 9.0 * s), Vector2(right, y + 9.0 * s), RIM, 1.0)
			right -= 11.0 * s
		# The XP so far and needed, then "XP".
		var need := run.levels.xp_to_next()
		var count := "%s / %s" % [UnnaturalHud.thousands(floori(run.levels.xp)), UnnaturalHud.thousands(roundi(need))]
		var count_px := roundi(14.0 * s)
		var unit_px := roundi(11.0 * s)
		var unit_width := semi.get_string_size("XP", HORIZONTAL_ALIGNMENT_LEFT, -1, unit_px).x
		var count_width := semi.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px).x
		var count_base := y + (semi.get_ascent(count_px) - semi.get_descent(count_px)) * 0.5
		_outlined(semi, Vector2(right - unit_width, count_base), "XP", unit_px, LABEL)
		_outlined(semi, Vector2(right - unit_width - 4.0 * s - count_width, count_base), count, count_px, UITheme.INK_SOFT)
		right -= unit_width + 4.0 * s + count_width + 10.0 * s
		# The bar.
		var bar := Rect2(x, y - XP_HEIGHT * s * 0.5, maxf(right - x, 20.0), XP_HEIGHT * s)
		var r := bar.size.y * 0.5
		UITheme.draw_box(self, bar, Color(UITheme.DEEP, 0.6), r, RIM, 1.0)
		var filled := bar.size.x * run.levels.progress()
		if filled > 0.5:
			var fill := Rect2(bar.position, Vector2(maxf(filled, bar.size.y), bar.size.y))
			UITheme.draw_box(self, fill.grow(2.0 * s), Color(XP_COLOR, 0.22), r + 2.0 * s)
			UITheme.draw_box(self, fill, XP_COLOR, r)

	## Text with a soft dark outline (the top row's), its baseline at `at`.
	func _outlined(font: Font, at: Vector2, value: String, px: int, color: Color) -> void:
		draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(roundi(px / 5.0), 2), Color(0.0, 0.03, 0.06, 0.5))
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

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
				UnnaturalHud.hud_text(self, Rect2(0.0, size.y * 0.62, size.x, 30.0), "YOU'RE DOWN  ·  A TEAMMATE CAN REVIVE YOU", 24, HP_COLOR)
			var at := player.global_position + Vector3.UP * 1.4
			if camera.is_position_behind(at):
				continue
			var spot := camera.unproject_position(at)
			draw_circle(spot, 20.0, Color(UITheme.DEEP, 0.7))
			draw_arc(spot, 20.0, -PI / 2.0, -PI / 2.0 + TAU * run.revive_progress(player), 32, Color(0.5, 1.0, 0.6), 4.0)
			UnnaturalHud.hud_text(self, Rect2(spot.x - 60.0, spot.y - 9.0, 120.0, 18.0), "DOWN", 14, UITheme.INK)

	## The boss out now: its name and health across the top, under the clock.
	func _draw_boss(run: UnnaturalRun) -> void:
		var boss := run.current_boss()
		if boss == null:
			return
		var width := minf(size.x * 0.5, 720.0)
		var bar := Rect2((size.x - width) * 0.5, 128.0 + hud.top_push(), width, 12.0)
		var r := bar.size.y * 0.5
		UITheme.draw_box(self, bar.grow(2.0), Color(UITheme.DEEP, 0.8), r + 2.0, RIM, 1.0)
		# What the last hits took, trailing behind (P3), then the hp left.
		if boss != _boss_shown:
			_boss_shown = boss
			_boss_trail = boss.share()
		_boss_trail = maxf(move_toward(_boss_trail, boss.share(), get_process_delta_time() * 0.25), boss.share())
		if _boss_trail > 0.0:
			UITheme.draw_box(self, Rect2(bar.position, Vector2(maxf(bar.size.x * _boss_trail, bar.size.y), bar.size.y)), Color(1.0, 0.9, 0.8, 0.55), r)
		if boss.share() > 0.0:
			var share := Rect2(bar.position, Vector2(maxf(bar.size.x * boss.share(), bar.size.y), bar.size.y))
			UITheme.draw_box(self, share, Color(1.0, 0.4, 0.2) if boss.enraged else HudIcons.BOSS, r)
			if boss.flash > 0.0:
				UITheme.draw_box(self, share, Color(1.0, 1.0, 1.0, boss.flash * 0.35), r)
		var name_line := boss.title + ("  ·  ENRAGED" if boss.enraged else "")
		var title_rect := Rect2(bar.position.x, bar.position.y - 26.0, bar.size.x, 24.0)
		if boss is BloodLeviathan:
			HudIcons.draw_boss(self, Vector2(bar.position.x - 18.0, bar.get_center().y), 26.0, false)
		UnnaturalHud.hud_text(self, title_rect, name_line, 19, UITheme.INK)

	## Top-left (the Playability pass, P1f; see-through since the HUD
	## redesign): a faint panel holding the weapon slots (diamonds), then the
	## tome slots (squares), each with its level on a chip and each free slot
	## an empty outline; then the items (hexagons) in the order they were
	## picked up, rimmed in their rarity's colour, with a stack chip once one
	## has 2 or more. The items wrap onto more rows when the view's narrow.
	func _draw_powerups(run: UnnaturalRun, fish: FishController) -> void:
		var s := k()
		var loadout := run.loadout_of(fish)
		var attack := run.attack_of(fish)
		var kind := attack.kind if attack else FishAttack.Kind.BITE
		var items := run.powerups_of(fish).items()
		var weapon_slots := maxi(run.settings.weapon_slots, loadout.weapons.size())
		var tome_slots := maxi(run.settings.tome_slots, loadout.tomes.size())
		var pad := PANEL_PAD * s
		var item_w := ITEM_SIZE * 0.8 * s
		var item_h := ITEM_SIZE * 0.92 * s
		var gap := ITEM_GAP * s
		var per_row := clampi(floori((size.x * 0.3 - pad * 2.0 + gap) / (item_w + gap)), 1, ITEMS_PER_ROW)
		var slot_step := WEAPON_SIZE * s + 14.0 * s
		var row_h := WEAPON_SIZE * s + 2.0 * s
		var inner := maxf(LABEL_WIDTH * s + slot_step * maxi(weapon_slots, tome_slots), per_row * (item_w + gap) - gap)
		var height := pad * 2.0 + row_h * (2 if tome_slots > 0 else 1)
		var item_rows := ceili(items.size() / float(per_row))
		if item_rows > 0:
			height += 4.0 * s + 14.0 * s + 4.0 * s + item_rows * (item_h + gap) - gap
		var panel := Rect2(MARGIN * s, PANEL_TOP * s, inner + pad * 2.0, height)
		UITheme.draw_box(self, panel, Color(UITheme.DEEP, 0.3), 9.0 * s, Color(RIM, 0.12), 1.0)
		var y := panel.position.y + pad + row_h * 0.5
		var left := panel.position.x + pad
		# Weapons: gold diamonds (a boss's keeps its colour).
		_section_label(Rect2(left, y - row_h * 0.5, LABEL_WIDTH * s, row_h), "WEAPONS", "%d/%d" % [loadout.weapons.size(), run.settings.weapon_slots], s)
		for n in weapon_slots:
			var centre := Vector2(left + LABEL_WIDTH * s + slot_step * (n + 0.5), y)
			if n < loadout.weapons.size():
				var id := loadout.weapons[n]
				var tint := UITheme.rarity(Rarity.Tier.BOSS) if id in Weapons.BOSS_ONLY else LEVEL_COLOR
				UnnaturalHud.draw_slot(self, HexBadge.Shape.DIAMOND, centre, WEAPON_SIZE * s, Weapons.glyph(id, kind), tint, s)
				UnnaturalHud.draw_chip(self, centre + Vector2(WEAPON_SIZE * 0.36, WEAPON_SIZE * 0.4) * s, str(loadout.level(id)), tint, s)
			else:
				HexBadge.draw_shape(self, HexBadge.Shape.DIAMOND, centre, WEAPON_SIZE * s, Color(UITheme.DEEP, 0.25), SLOT_EMPTY, 1.0)
		# Tomes: squares in each tome's colour.
		if tome_slots > 0:
			y += row_h
			_section_label(Rect2(left, y - row_h * 0.5, LABEL_WIDTH * s, row_h), "TOMES", "%d/%d" % [loadout.tomes.size(), run.settings.tome_slots], s)
			for n in tome_slots:
				var centre := Vector2(left + LABEL_WIDTH * s + slot_step * (n + 0.5), y)
				if n < loadout.tomes.size():
					var id := loadout.tomes[n]
					UnnaturalHud.draw_slot(self, HexBadge.Shape.SQUARE, centre, TOME_SIZE * s, Tomes.glyph(id), Tomes.color(id), s)
					UnnaturalHud.draw_chip(self, centre + Vector2(TOME_SIZE * 0.39, TOME_SIZE * 0.4) * s, str(loadout.tome_level(id)), Tomes.color(id), s)
				else:
					HexBadge.draw_shape(self, HexBadge.Shape.SQUARE, centre, TOME_SIZE * s, Color(UITheme.DEEP, 0.25), SLOT_EMPTY, 1.0)
		if items.is_empty():
			return
		# Powerups: hexagons in their rarity's colour.
		var top := y + row_h * 0.5 + 4.0 * s
		UnnaturalHud.hud_text(self, Rect2(left, top, inner, 14.0 * s), "POWERUPS", roundi(10.0 * s), LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
		top += 18.0 * s
		for n in items.size():
			var entry: Array = items[n]
			var id: String = entry[0]
			var stacks: int = entry[1]
			var centre := Vector2(left + (n % per_row) * (item_w + gap) + item_w * 0.5, top + (n / per_row) * (item_h + gap) + item_h * 0.5)
			var tint := UITheme.rarity(Powerup.tier(id))
			UnnaturalHud.draw_slot(self, HexBadge.Shape.HEX, centre, ITEM_SIZE * s, id, tint, s)
			if stacks >= 2:
				UnnaturalHud.draw_chip(self, centre + Vector2(ITEM_SIZE * 0.34, ITEM_SIZE * 0.36) * s, str(stacks), tint, s * 0.85)

	## A section's caps label with its count under it ("WEAPONS" / "2/2").
	func _section_label(rect: Rect2, title: String, count: String, s: float) -> void:
		var half := rect.size.y * 0.5
		UnnaturalHud.hud_text(self, Rect2(rect.position.x, rect.position.y + half - 13.0 * s, rect.size.x, 13.0 * s), title, roundi(10.0 * s), LABEL,
				HORIZONTAL_ALIGNMENT_LEFT, 600)
		UnnaturalHud.hud_text(self, Rect2(rect.position.x, rect.position.y + half, rect.size.x, 13.0 * s), count, roundi(11.0 * s), UITheme.INK_SOFT,
				HORIZONTAL_ALIGNMENT_LEFT, 600)

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
			var tint := chest.tint()
			draw_circle(spot, 13.0 + 2.0 * pulse, Color(tint, 0.15 + 0.15 * pulse), true, -1.0, true)
			HudIcons.draw_chest(self, spot, 20.0, tint)
			# The distance, then the price beside a pearl (red when you can't afford it).
			var price := run.chest_price(chest, fish)
			var afford := run.can_afford(fish, chest)
			var font := UITheme.condensed(700)
			var distance := "%d m" % roundi(gap)
			var text_w := font.get_string_size(distance, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var price_w := 0.0
			if price > 0:
				price_w = 6.0 + 14.0 + 3.0 + font.get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var x := spot.x - (text_w + price_w) * 0.5
			UnnaturalHud.hud_text(self, Rect2(x, spot.y + 13.0, text_w, 18.0), distance, 14, tint, HORIZONTAL_ALIGNMENT_LEFT)
			if price > 0:
				var pearl_at := Vector2(x + text_w + 6.0 + 7.0, spot.y + 22.0)
				HudIcons.draw_pearl(self, pearl_at, 15.0)
				UnnaturalHud.hud_text(self, Rect2(pearl_at.x + 10.0, spot.y + 13.0, price_w, 18.0), str(price), 14,
						UITheme.INK if afford else Color(1.0, 0.45, 0.4), HORIZONTAL_ALIGNMENT_LEFT)
			if chest.progress_of(fish) > 0.0 and inside:
				draw_arc(spot, 22.0, -PI / 2.0, -PI / 2.0 + TAU * chest.progress_of(fish), 32, tint, 4.0)


## A loadout slot (the HUD redesign): `shape` faintly filled, a thin rim in
## `rim`, and glyph `id` in soft white. `size` is the shape's 100-unit box (px).
static func draw_slot(canvas: CanvasItem, shape: HexBadge.Shape, centre: Vector2, size: float, id: String, rim: Color, s: float) -> void:
	HexBadge.draw_shape(canvas, shape, centre, size, Color(UITheme.DEEP, 0.5), rim, maxf(1.0 * s, 1.0))
	HexBadge.draw_glyph(canvas, id, centre, size * HexBadge.glyph_share(shape) * (1.15 if shape == HexBadge.Shape.DIAMOND else 1.0),
			Color(UITheme.INK, 0.92), 1.6)


## A small number chip (a slot's level or stacks) centred on `centre`: dark,
## rimmed in `tint`, the number in it.
static func draw_chip(canvas: CanvasItem, centre: Vector2, value: String, tint: Color, s: float) -> void:
	var px := roundi(10.0 * s)
	var font := UITheme.condensed(700)
	var height := 12.0 * s
	var width := maxf(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 7.0 * s, height)
	var rect := Rect2(centre - Vector2(width, height) * 0.5, Vector2(width, height))
	UITheme.draw_box(canvas, rect, Color(UITheme.DEEP, 0.88), height * 0.5, Color(tint, 0.65), 1.0)
	UITheme.draw_text(canvas, rect, value, font, px, tint.lerp(Color.WHITE, 0.35))


## The mobility skill's button at the bottom of the view (SkillButton): over
## the stroke rhythm meter when it's showing, else lower down.
func _update_skill() -> void:
	var twist: Traversal = run.twist_of(fish) if is_instance_valid(fish) else null
	_skill.visible = twist != null and run.settings.twists and not _cards.is_open() and Traversal.skill_title(fish.character) != ""
	if not _skill.visible:
		return
	_skill.twist = twist
	_skill.title = Traversal.skill_title(fish.character).to_upper()
	var meter := fish.swim_strokes and fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY
	_skill.offset_bottom = -118.0 if meter else -28.0  # over the meter and its PERFECT / EARLY / LATE
	_skill.offset_top = _skill.offset_bottom - SkillButton.SIZE.y


## The prompt while a final boss holds you: a dark long-hexagon plate with a
## red rim, what has you ("SWALLOWED  ·  THE GULPER MOTHER"), STRIDE TO BREAK
## FREE with a stick flicking side to side beside it, a diamond for each stride
## needed (lit as you make them, each popping), and the hold's time running
## down under them. It pops in when you're caught, shakes with each stride and
## pulses red with each drain.
class BreakFree extends Control:
	const SIZE := Vector2(600.0, 150.0)
	const RIM := Color(1.0, 84 / 255.0, 104 / 255.0)
	const FILL := Color(14 / 255.0, 6 / 255.0, 12 / 255.0, 0.9)

	## What has you, how far you are, and how long it holds on yet (1 to 0).
	var verb := "HELD"
	var who := ""
	var strides := 0
	var needed := 3
	var left := 1.0

	var _shown := 0.0
	var _pops: Array[float] = []
	var _shake := 0.0
	var _age := 0.0
	var _hp := -1.0
	var _drained := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	## Shown while `holder` holds the HUD's fish (null: hidden), eased in and out.
	func show_for(holder: BloodLeviathan, delta: float) -> void:
		var on := holder != null
		if on:
			if not visible or _shown <= 0.0:
				_pops.clear()
				strides = 0
				_hp = -1.0
			verb = holder.hold_verb()
			who = holder.title
			needed = maxi(holder.settings.final_hold_strides, 1)
			left = holder.hold_share_left()
			var now := mini(holder.hold_strides, needed)
			while strides < now:
				strides += 1
				_shake = 1.0
			var health := holder.run.health_of(holder.held)
			if health:
				if _hp >= 0.0 and health.hp < _hp - 0.01:
					_drained = 1.0
				_hp = health.hp
		_pops.resize(needed)
		for n in needed:
			_pops[n] = move_toward(_pops[n], 1.0 if n < strides else 0.0, delta * 5.0)
		_shown = move_toward(_shown, 1.0 if on else 0.0, delta * (7.0 if on else 4.0))
		_shake = maxf(_shake - delta * 4.0, 0.0)
		_drained = maxf(_drained - delta * 3.0, 0.0)
		_age += delta
		visible = _shown > 0.0
		if visible:
			queue_redraw()

	func _draw() -> void:
		var ease_in := 1.0 - pow(1.0 - _shown, 3.0)
		var grow := lerpf(0.86, 1.0, ease_in)
		var jolt := sin(_age * 70.0) * 9.0 * _shake * _shake
		var centre := size * 0.5 + Vector2(jolt, 0.0)
		draw_set_transform(centre, 0.0, Vector2.ONE * grow)
		var half := SIZE * 0.5
		var box := Rect2(-half, SIZE)
		var notch := 34.0
		var alpha := ease_in
		var beat := 0.5 + 0.5 * sin(_age * 7.0)
		# Glow round it: steady, flaring with each drain.
		for n in 4:
			var spread := 4.0 + n * 5.0 + 6.0 * _drained
			draw_colored_polygon(_shape(box.grow(spread), notch + spread * 0.6), Color(RIM, (0.08 + 0.05 * beat + 0.12 * _drained) * (1.0 - n * 0.22) * alpha))
		draw_colored_polygon(_shape(box, notch), Color(RIM, alpha))
		draw_colored_polygon(_shape(box.grow(-2.0), notch - 1.0), Color(FILL.lerp(Color(0.3, 0.02, 0.06, 0.92), _drained * 0.6), FILL.a * alpha))
		# Hazard ticks along the top edge.
		for n in 9:
			var x := lerpf(-half.x + notch + 10.0, half.x - notch - 10.0, n / 8.0)
			draw_line(Vector2(x - 5.0, -half.y + 2.0), Vector2(x + 5.0, -half.y + 9.0), Color(RIM, 0.35 * alpha), 2.0, true)
		# What has you.
		var small := UITheme.caps(15, 700, 0.22)
		UITheme.draw_text(self, Rect2(-half.x + 60.0, -half.y + 14.0, SIZE.x - 120.0, 20.0), "%s  ·  %s" % [verb, who], small, 15, Color(RIM, alpha))
		# The stick flicking side to side, and the call.
		var big := UITheme.display(700)
		var line := "STRIDE TO BREAK FREE"
		var px := 34
		var text_w := big.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var glyph_w := 64.0
		var x0 := -(text_w + glyph_w + 16.0) * 0.5
		var mid := -half.y + 62.0
		_stick(Vector2(x0 + glyph_w * 0.5, mid), alpha)
		var baseline := mid + (big.get_ascent(px) - big.get_descent(px)) * 0.5
		draw_string(big, Vector2(x0 + glyph_w + 16.0, baseline), line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UITheme.INK, alpha))
		# A diamond for each stride needed.
		var gap := 34.0
		var y := mid + 40.0
		for n in needed:
			var at := Vector2((n - (needed - 1) * 0.5) * gap, y)
			var pop: float = _pops[n] if n < _pops.size() else 0.0
			var lit := n < strides
			var r := 9.0 + (4.0 * sin(pop * PI) if lit else 0.0)
			var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
			if lit:
				draw_colored_polygon(diamond, Color(RIM, alpha))
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r * 0.45), at + Vector2(r * 0.45, 0), at + Vector2(0, r * 0.45), at + Vector2(-r * 0.45, 0)]),
						Color(1.0, 0.85, 0.88, alpha))
			else:
				var ring := diamond.duplicate()
				ring.append(diamond[0])
				draw_polyline(ring, Color(RIM, 0.6 * alpha), 2.0, true)
		# The hold running out.
		var bar := Rect2(-half.x + notch + 30.0, half.y - 16.0, SIZE.x - (notch + 30.0) * 2.0, 4.0)
		draw_rect(bar, Color(RIM, 0.2 * alpha))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Color(RIM, 0.85 * alpha))
		draw_set_transform(Vector2.ZERO)

	## A thumbstick flicked left and right (a stride), with chevrons either side.
	func _stick(at: Vector2, alpha: float) -> void:
		var swing := sin(_age * 9.0)
		draw_arc(at, 20.0, 0.0, TAU, 32, Color(UITheme.INK, 0.35 * alpha), 2.0, true)
		draw_circle(at + Vector2(swing * 10.0, 0.0), 9.0, Color(UITheme.INK, alpha))
		for side: float in [-1.0, 1.0]:
			var lit := 0.35 + 0.65 * maxf(swing * side, 0.0)
			var tip := at + Vector2(side * 30.0, 0.0)
			draw_polyline(PackedVector2Array([tip + Vector2(-side * 5.0, -6.0), tip, tip + Vector2(-side * 5.0, 6.0)]), Color(RIM, lit * alpha), 2.5, true)

	## A long hexagon filling `rect`, its ends pointed by `notch` px.
	static func _shape(rect: Rect2, notch: float) -> PackedVector2Array:
		var mid := rect.get_center().y
		return PackedVector2Array([Vector2(rect.position.x + notch, rect.position.y), Vector2(rect.end.x - notch, rect.position.y),
				Vector2(rect.end.x, mid), Vector2(rect.end.x - notch, rect.end.y), Vector2(rect.position.x + notch, rect.end.y),
				Vector2(rect.position.x, mid)])


## The mobility skill as a game button (the HUD redesign): a long hexagon
## with a chevron and the skill's name. Lit and glowing when it's ready;
## filled while it's on (Go Quiet: until pressed again); greyed while it
## cools down, a fill sweeping across as it comes back.
class SkillButton extends Control:
	const SIZE := Vector2(176.0, 44.0)
	const READY := Color(70 / 255.0, 214 / 255.0, 1.0)
	const INNER := Color(6 / 255.0, 42 / 255.0, 61 / 255.0)
	const COOL_RIM := Color(150 / 255.0, 170 / 255.0, 185 / 255.0, 0.35)
	const COOL_INNER := Color(18 / 255.0, 27 / 255.0, 35 / 255.0, 0.92)
	const COOL_TEXT := Color(135 / 255.0, 150 / 255.0, 161 / 255.0)

	var hud: UnnaturalHud
	var twist: Traversal
	var title := "DASH"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	## Ready, on, or cooling (for the probes).
	func state() -> String:
		if twist == null:
			return ""
		if twist.quiet or twist.skill_active():
			return "on"
		return "ready" if twist.skill_wait() <= 0.0 else "cooling"

	func _draw() -> void:
		if twist == null:
			return
		var now := state()
		var notch := size.y * 0.32
		var outer := _shape(Rect2(Vector2.ZERO, size), notch)
		var inner := _shape(Rect2(Vector2.ZERO, size).grow(-2.0), notch - 1.0)
		var lit := now != "cooling"
		if lit:
			for n in 3:
				draw_colored_polygon(_shape(Rect2(Vector2.ZERO, size).grow(3.0 + n * 3.0), notch + 2.0 + n * 2.0), Color(READY, 0.1 - n * 0.03))
		draw_colored_polygon(outer, READY if lit else COOL_RIM)
		draw_colored_polygon(inner, INNER if now == "ready" else (READY.darkened(0.35) if now == "on" else COOL_INNER))
		if now == "cooling":
			# The way back: the inner fills from the left as the cooldown runs out.
			var fill := twist.skill_fill()
			var clip := Rect2(Vector2(2.0, 2.0), Vector2((size.x - 4.0) * fill, size.y - 4.0))
			var sweep := Geometry2D.intersect_polygons(inner, _rect_points(clip))
			for part: PackedVector2Array in sweep:
				draw_colored_polygon(part, Color(COOL_RIM, 0.45))
		var text_color := Color(0.92, 0.98, 1.0) if lit else COOL_TEXT
		var chevron := READY if now == "ready" else (Color.WHITE if now == "on" else Color(0.49, 0.55, 0.59))
		var font := UITheme.caps(roundi(size.y * 0.5), 700, 0.16)
		var px := roundi(size.y * 0.5)
		var word := title + ("  ·  ON" if now == "on" else "")
		var text_w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var chevron_w := size.y * 0.42
		var x := (size.x - text_w - chevron_w - 8.0) * 0.5
		var mid := size.y * 0.5
		var h := size.y * 0.17
		for n in 2:
			var cx := x + n * chevron_w * 0.48
			draw_polyline(PackedVector2Array([Vector2(cx, mid - h), Vector2(cx + h, mid), Vector2(cx, mid + h)]), chevron, 2.2, true)
		var baseline := mid + (font.get_ascent(px) - font.get_descent(px)) * 0.5
		draw_string(font, Vector2(x + chevron_w + 8.0, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, text_color)

	## A long hexagon filling `rect`, its ends pointed by `notch` px.
	static func _shape(rect: Rect2, notch: float) -> PackedVector2Array:
		var mid := rect.get_center().y
		return PackedVector2Array([Vector2(rect.position.x + notch, rect.position.y), Vector2(rect.end.x - notch, rect.position.y),
				Vector2(rect.end.x, mid), Vector2(rect.end.x - notch, rect.end.y), Vector2(rect.position.x + notch, rect.end.y),
				Vector2(rect.position.x, mid)])

	static func _rect_points(rect: Rect2) -> PackedVector2Array:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
