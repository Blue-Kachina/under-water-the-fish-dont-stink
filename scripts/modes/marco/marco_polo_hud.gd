class_name MarcoPoloHud
extends CanvasLayer
## Marco Polo's HUD (planning_marco_polo.md §4, §6), drawn for the one local
## player in the HUD redesign's style (UITheme):
## - everyone: the round clock and round count (top middle), the role banner
##   under it (SEEKER / HIDER / SPECTATING), the catch feed (top right: tags and
##   fish out of water, never "seen"), the big banners (TAGGED!, FOOLED!, FISH
##   OUT OF WATER!, the round's start, MARCO! for hiders), the ROUND_OVER card
##   and the match's end card;
## - hiders (bottom left): the layer pip (five icons lit to the layer the
##   seekers see them at), the noise meter, the eye pip while they're in a
##   seeker's sight, the Fake Fish charge, the Out of Water gauge while in
##   a porthole, and the Jump prompt by a free one; parked, who they watch;
## - seekers (bottom left): the "Marco!" cooldown ring, their tags this round
##   and the hiders left; while counting, the view blacked out.
## No live round scores, for anyone (§6): the points shown during a round are
## the totals from the rounds before (and seekers see only their own).

## MarcoPoloMatch's enums (Role { HIDER, SEEKER }, Phase { COUNTDOWN, LIVE, ROUND_OVER, OVER }).
const HIDER := 0
const SEEKER := 1
const COUNTDOWN := 0
const LIVE := 1
const ROUND_OVER := 2
const OVER := 3
const FEED_LIFE := 6.0
const FEED_LINES := 5
const BANNER_LIFE := 2.2
const TAG_COLOR := Color(1.0, 0.42, 0.3)
const SEEKER_COLOR := Color(0.4, 1.0, 0.7)
const WATER_COLOR := Color(0.35, 0.75, 1.0)

var match_node: Node
var _view := View.new()
## {text, color, age}, newest last.
var _feed: Array[Dictionary] = []
var _banner := ""
var _banner_sub := ""
var _banner_color := Color.WHITE
var _banner_age := INF
var _round_results := {}
var _winner: Node
var _tags := 0


func _ready() -> void:
	layer = 6
	_view.hud = self
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)


## Hooks the HUD to a MarcoPoloMatch (typed as Node so this parses on its own).
func bind(mp_match: Node) -> void:
	match_node = mp_match
	var hooks := {
		"caught": _on_caught, "round_started": _on_round_started, "round_over": _on_round_over, "fooled": _on_fooled,
		"marco_called": _on_marco, "match_over": _on_match_over, "spectate_target_changed": _on_spectate,
	}
	for signal_name: String in hooks:
		if mp_match.has_signal(signal_name):
			mp_match.connect(signal_name, hooks[signal_name])


func _process(delta: float) -> void:
	_banner_age += delta
	for line in _feed:
		line.age = float(line.age) + delta
	while not _feed.is_empty() and float(_feed[0].age) > FEED_LIFE:
		_feed.pop_front()
	_view.queue_redraw()


# --- What the match says -------------------------------------------------------

func banner(text: String, sub: String, color: Color) -> void:
	_banner = text
	_banner_sub = sub
	_banner_color = color
	_banner_age = 0.0


func feed(text: String, color: Color) -> void:
	_feed.append({"text": text, "color": color, "age": 0.0})
	while _feed.size() > FEED_LINES:
		_feed.pop_front()


func _on_caught(hider: Node, how: String, by: Node) -> void:
	var me := local_fish()
	var joined := _variant_converts()
	if how == "out_of_water":
		feed("%s  ·  FISH OUT OF WATER" % name_of(hider), WATER_COLOR)
		if hider == me:
			banner("FISH OUT OF WATER!", "you're a seeker now" if joined else "you're out: spectating", WATER_COLOR)
		return
	feed("%s  TAGGED  %s" % [name_of(by), name_of(hider)], TAG_COLOR)
	if hider == me:
		banner("TAGGED!", ("by %s  ·  you're a seeker now" if joined else "by %s  ·  you're out: spectating") % name_of(by), TAG_COLOR)
	elif by == me:
		_tags += 1
		banner("TAGGED!", name_of(hider), SEEKER_COLOR)


func _on_round_started(index: int, _seeker: Node) -> void:
	_round_results = {}
	_tags = 0
	_feed.clear()
	var rounds := int(_call("rounds_in_match", [], 0))
	var of := " OF %d" % rounds if rounds > 0 else ""
	if role_of(local_fish()) == SEEKER:
		banner("ROUND %d%s" % [index + 1, of], "you're the seeker  ·  count to %d" % roundi(_setting("hide_time", 10.0)), SEEKER_COLOR)
	else:
		banner("ROUND %d%s" % [index + 1, of], "you're hiding  ·  swim off, keep quiet", UITheme.AQUA)


func _on_round_over(results: Dictionary) -> void:
	_round_results = results
	_banner_age = INF


func _on_fooled(seeker: Node, fake: Node) -> void:
	var me := local_fish()
	if seeker == me:
		banner("FOOLED!", "that was a Fake Fish", UITheme.GOLD)
	elif _call("decoy_owner", [fake], null) == me:
		banner("FOOLED!", "your Fake Fish took the tag", UITheme.GOLD)


func _on_marco(seeker: Node) -> void:
	if seeker != local_fish() and role_of(local_fish()) != SEEKER:
		banner("MARCO!", "POLO!  ·  everyone answered", SEEKER_COLOR)


func _on_match_over(winner: Node) -> void:
	_winner = winner


func _on_spectate(fish: Node) -> void:
	if fish:
		feed("WATCHING  %s" % name_of(fish), UITheme.MUTED)


# --- Reading the match ---------------------------------------------------------

func _call(method: String, args: Array, fallback: Variant) -> Variant:
	if not is_instance_valid(match_node) or not match_node.has_method(method):
		return fallback
	return match_node.callv(method, args)


func _get_value(property: String, fallback: Variant) -> Variant:
	if not is_instance_valid(match_node):
		return fallback
	var value: Variant = match_node.get(property)
	return fallback if value == null else value


func _setting(setting: String, fallback: Variant) -> Variant:
	var settings: Variant = _get_value("settings", null)
	if settings is Resource:
		var value: Variant = (settings as Resource).get(setting)
		if value != null:
			return value
	return fallback


func _variant_converts() -> bool:
	return int(_setting("variant", 0)) == MarcoPoloSettings.Variant.CONVERSION


func local_fish() -> Node:
	return _call("local_fish", [], null) as Node


func role_of(fish: Node) -> int:
	return int(_call("role_of", [fish], HIDER)) if fish else HIDER


func phase() -> int:
	return int(_get_value("phase", COUNTDOWN))


## {left, interval} (s) of `seeker`'s automatic Marco! beat, or {} when it has the
## manual button. Reads the match's auto_marco_left(seeker) when it has one, else its
## own timer table (planning_marco_whales.md §4).
func auto_beat(seeker: Node) -> Dictionary:
	if not bool(_call("uses_auto_marco", [seeker], false)):
		return {}
	var interval := float(_setting("marco_auto_interval", 3.0))
	var left := -1.0
	if is_instance_valid(match_node) and match_node.has_method("auto_marco_left"):
		left = float(match_node.call("auto_marco_left", seeker))
	else:
		var table: Variant = _get_value("_auto_left", null)
		if table is Dictionary and (table as Dictionary).has(seeker):
			left = float((table as Dictionary)[seeker])
	if left < 0.0:
		return {}
	return {"left": left, "interval": interval}


func spectating() -> bool:
	return bool(_call("is_spectating", [], false))


static func name_of(fish: Node) -> String:
	if fish == null or not is_instance_valid(fish):
		return "?"
	var shown: Variant = fish.get("display_name")
	return String(shown) if shown is String and String(shown) != "" else String(fish.name)


static func clock(seconds: float) -> String:
	var whole := maxi(ceili(seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]


## Everything is drawn here, over the whole view.
class View extends Control:
	var hud: MarcoPoloHud

	func _draw() -> void:
		if hud == null or not is_instance_valid(hud.match_node):
			return
		var s := UITheme.scale_for(get_viewport())
		var view := size
		var me := hud.local_fish()
		var phase := hud.phase()
		var seeker := hud.role_of(me) == MarcoPoloHud.SEEKER and not hud.spectating()
		if phase == MarcoPoloHud.COUNTDOWN and seeker:
			_draw_blackout(s, view)
		if phase == MarcoPoloHud.LIVE or phase == MarcoPoloHud.COUNTDOWN:
			_draw_clock(s, view, phase, seeker)
			if seeker:
				_draw_seeker(s, view, me)
			elif not hud.spectating() and is_instance_valid(me):
				_draw_hider(s, view, me)
			_draw_totals(s, view, me, seeker)
		_draw_feed(s, view)
		_draw_banner(s, view)
		if phase == MarcoPoloHud.ROUND_OVER and not hud._round_results.is_empty():
			_draw_round_card(s, view)
		elif phase == MarcoPoloHud.OVER:
			_draw_over_card(s, view)

	## The seeker counting to ten: the view blacked out.
	func _draw_blackout(s: float, view: Vector2) -> void:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.0, 0.01, 0.02, 0.97))
		var left := float(hud._get_value("phase_left", 0.0))
		UITheme.draw_text(self, Rect2(0.0, view.y * 0.38, view.x, 80.0 * s), str(maxi(ceili(left), 0)), UITheme.display(700),
				roundi(78.0 * s), MarcoPoloHud.SEEKER_COLOR)
		UITheme.draw_text(self, Rect2(0.0, view.y * 0.38 + 84.0 * s, view.x, 30.0 * s), "COUNTING  ·  THE HIDERS ARE HIDING",
				UITheme.condensed(700), roundi(22.0 * s), UITheme.INK_SOFT)

	## The round clock, round count and role banner, top middle.
	func _draw_clock(s: float, view: Vector2, phase: int, seeker: bool) -> void:
		var counting := phase == MarcoPoloHud.COUNTDOWN
		var seconds := float(hud._get_value("phase_left" if counting else "time_left", 0.0))
		var rect := Rect2(view.x * 0.5 - 70.0 * s, 12.0 * s, 140.0 * s, 46.0 * s)
		UITheme.draw_box(self, rect, UITheme.HUD_FILL, 12.0 * s, RoundMap.PANEL_RIM, 1.0)
		var tint := UITheme.INK
		if counting:
			tint = MarcoPoloHud.SEEKER_COLOR if seeker else UITheme.AQUA
		elif phase == MarcoPoloHud.LIVE and seconds < 20.0:
			tint = UITheme.CORAL
		UITheme.draw_text(self, rect, MarcoPoloHud.clock(seconds), UITheme.display(600),
				roundi(30.0 * s), tint)
		var rounds := int(hud._call("rounds_in_match", [], 0))
		var index := int(hud._get_value("round_index", 0))
		var under := Rect2(rect.position.x - 60.0 * s, rect.end.y + 4.0 * s, rect.size.x + 120.0 * s, 24.0 * s)
		var role_text := "HIDER"
		var role_tint := UITheme.AQUA
		if hud.spectating():
			var watched: Node = hud._call("spectate_target", [], null)
			role_text = "SPECTATING  %s   ◀ ▶" % MarcoPoloHud.name_of(watched) if watched else "SPECTATING"
			role_tint = UITheme.MUTED
		elif bool(hud._call("is_parked", [], false)):
			var watched: Node = hud._call("spectate_target", [], null)
			role_text = "PARKED  ·  WATCHING  %s   ◀ ▶  ·  Y: BACK" % MarcoPoloHud.name_of(watched)
			role_tint = UITheme.GOLD
		elif seeker:
			role_text = "SEEKER"
			role_tint = MarcoPoloHud.SEEKER_COLOR
		if counting and not seeker and not hud.spectating() and not bool(hud._call("is_parked", [], false)):
			role_text = "HIDE!"
		var round_text := "ROUND %d/%d  ·  " % [index + 1, rounds] if rounds > 0 else ""
		UITheme.draw_text(self, under, round_text + role_text, UITheme.condensed(700), roundi(17.0 * s), role_tint)

	func _draw_hider(s: float, view: Vector2, me: Node) -> void:
		var settings: Variant = hud._get_value("settings", null)
		var exposure := float(hud._call("max_exposure", [me], 0.0))
		var lit := (settings as MarcoPoloSettings).layer_for(exposure) if settings is MarcoPoloSettings else 0
		var origin := Vector2(24.0 * s, view.y - 132.0 * s)
		var panel := Rect2(origin, Vector2(250.0 * s, 108.0 * s))
		UITheme.draw_box(self, panel, UITheme.HUD_FILL, 12.0 * s, RoundMap.PANEL_RIM, 1.0)
		# The layer pip: what the seekers can see of you.
		var icon := 34.0 * s
		for n in 5:
			var centre := origin + Vector2(26.0 * s + n * (icon + 8.0 * s), 28.0 * s)
			HudIcons.draw_layer(self, n + 1, centre, icon, n + 1 <= lit)
		# The noise meter, with the sonar's threshold marked.
		var noise := clampf(float(hud._call("noise", [me], 0.0)), 0.0, 1.0)
		var bar := Rect2(origin + Vector2(12.0 * s, 56.0 * s), Vector2(196.0 * s, 9.0 * s))
		UITheme.draw_box(self, bar, Color(UITheme.DEEP, 0.9), 4.5 * s)
		var fill := Rect2(bar.position, Vector2(bar.size.x * noise, bar.size.y))
		var loud := Color(0.4, 0.9, 0.6).lerp(UITheme.CORAL, noise)
		if fill.size.x > 1.0:
			UITheme.draw_box(self, fill, loud, 4.5 * s)
		var threshold := float(hud._setting("blip_threshold", 0.3))
		var tick := bar.position.x + bar.size.x * threshold
		draw_line(Vector2(tick, bar.position.y - 2.0 * s), Vector2(tick, bar.end.y + 2.0 * s), Color(1, 1, 1, 0.7), 1.5)
		UITheme.draw_text(self, Rect2(origin + Vector2(12.0 * s, 68.0 * s), Vector2(120.0 * s, 16.0 * s)), "NOISE", UITheme.condensed(700),
				roundi(13.0 * s), UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		# The eye pip: in a seeker's sight (and scoring) now.
		if bool(hud._call("is_seen_now", [me], false)):
			_draw_eye(origin + Vector2(230.0 * s, 60.0 * s), 13.0 * s)
		# The Fake Fish charge.
		var charges := int(hud._call("fake_charges", [me], 0))
		var chip := Rect2(origin + Vector2(12.0 * s, 84.0 * s), Vector2(120.0 * s, 18.0 * s))
		var text := "FAKE FISH  ×%d" % charges if charges > 0 else "FAKE FISH  USED"
		UITheme.draw_text(self, chip, text, UITheme.condensed(700), roundi(14.0 * s), UITheme.GOLD if charges > 0 else UITheme.MUTED,
				HORIZONTAL_ALIGNMENT_LEFT)
		# Out of Water, while in a porthole (and draining after).
		var holes: Variant = hud._get_value("porthole_system", null)
		if holes is Node and is_instance_valid(holes) and (holes as Node).has_method("gauge"):
			var gauge := clampf(float((holes as Node).call("gauge", me)), 0.0, 1.0)
			if gauge > 0.001:
				_draw_out_of_water(s, view, gauge)
			# Jump: in, by a free porthole; out, inside one.
			var prompt := ""
			if (holes as Node).call("porthole_of", me) != null:
				prompt = "JUMP  ·  OUT OF THE PORTHOLE"
			elif (holes as Node).has_method("jump_porthole") and (holes as Node).call("jump_porthole", me) != null \
					and not bool(hud._call("is_parked", [], false)):
				prompt = "JUMP  ·  INTO THE PORTHOLE"
			if prompt != "":
				var tip := Rect2(view.x * 0.5 - 150.0 * s, view.y - 140.0 * s, 300.0 * s, 32.0 * s)
				UITheme.draw_box(self, tip, UITheme.HUD_FILL, 10.0 * s, Color(MarcoPoloHud.WATER_COLOR, 0.6), 1.0)
				UITheme.draw_text(self, tip, prompt, UITheme.condensed(800), roundi(16.0 * s), MarcoPoloHud.WATER_COLOR)

	func _draw_eye(centre: Vector2, r: float) -> void:
		var points := PackedVector2Array()
		for n in 16:
			var t := TAU * n / 16.0
			points.append(centre + Vector2(cos(t) * r, sin(t) * r * 0.55))
		draw_colored_polygon(points, UITheme.INK)
		draw_circle(centre, r * 0.42, Color(0.12, 0.5, 0.45), true, -1.0, true)
		draw_circle(centre, r * 0.2, UITheme.DEEP, true, -1.0, true)

	## A drying fish over a gauge, bottom middle.
	func _draw_out_of_water(s: float, view: Vector2, gauge: float) -> void:
		var rect := Rect2(view.x * 0.5 - 130.0 * s, view.y - 96.0 * s, 260.0 * s, 54.0 * s)
		UITheme.draw_box(self, rect, UITheme.HUD_FILL, 12.0 * s, RoundMap.PANEL_RIM, 1.0)
		var bar := Rect2(rect.position + Vector2(52.0 * s, 30.0 * s), Vector2(192.0 * s, 12.0 * s))
		UITheme.draw_box(self, bar, Color(MarcoPoloHud.WATER_COLOR, 0.25), 6.0 * s)
		var dry := Color(MarcoPoloHud.WATER_COLOR).lerp(UITheme.CORAL, gauge)
		UITheme.draw_box(self, Rect2(bar.position, Vector2(bar.size.x * gauge, bar.size.y)), dry, 6.0 * s)
		UITheme.draw_text(self, Rect2(bar.position.x, rect.position.y + 6.0 * s, bar.size.x, 20.0 * s), "OUT OF WATER", UITheme.condensed(700),
				roundi(15.0 * s), dry, HORIZONTAL_ALIGNMENT_LEFT)
		# The fish, gasping faster as it dries.
		var gasp := 0.5 + 0.5 * sin(Time.get_ticks_msec() / lerpf(220.0, 70.0, gauge))
		var c := rect.position + Vector2(28.0 * s, 27.0 * s)
		var body := PackedVector2Array()
		for n in 14:
			var t := TAU * n / 14.0
			body.append(c + Vector2(cos(t) * 13.0 * s, sin(t) * 7.0 * s))
		draw_colored_polygon(body, dry)
		draw_colored_polygon(PackedVector2Array([c + Vector2(11.0 * s, 0.0), c + Vector2(20.0 * s, -7.0 * s), c + Vector2(20.0 * s, 7.0 * s)]), dry)
		draw_circle(c + Vector2(-7.0 * s, -2.0 * s), 1.8 * s, UITheme.DEEP)
		draw_arc(c + Vector2(-13.0 * s, 1.0 * s), (1.5 + gasp * 2.0) * s, 0.0, TAU, 10, UITheme.DEEP, 1.5 * s)

	func _draw_seeker(s: float, view: Vector2, me: Node) -> void:
		var origin := Vector2(24.0 * s, view.y - 132.0 * s)
		var panel := Rect2(origin, Vector2(230.0 * s, 108.0 * s))
		UITheme.draw_box(self, panel, UITheme.HUD_FILL, 12.0 * s, RoundMap.PANEL_RIM, 1.0)
		# "Marco!": its cooldown ring.
		var ready := clampf(float(hud._call("marco_ready", [me], 1.0)), 0.0, 1.0)
		var centre := origin + Vector2(54.0 * s, 54.0 * s)
		var r := 36.0 * s
		var auto_beat := hud.auto_beat(me)
		if not auto_beat.is_empty():
			_draw_beat_pip(s, centre, r, auto_beat)
			_draw_seeker_counts(s, origin)
			return
		draw_arc(centre, r, 0.0, TAU, 48, Color(UITheme.DEEP, 0.9), 7.0 * s, true)
		var tint := MarcoPoloHud.SEEKER_COLOR if ready >= 1.0 else UITheme.MUTED
		if ready > 0.0:
			draw_arc(centre, r, -PI * 0.5, -PI * 0.5 + TAU * ready, 48, tint, 7.0 * s, true)
		if ready >= 1.0:
			var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
			draw_arc(centre, r + 6.0 * s * beat, 0.0, TAU, 48, Color(tint, 0.35 * (1.0 - beat)), 2.0 * s, true)
		UITheme.draw_text(self, Rect2(centre - Vector2(r, 12.0 * s), Vector2(r * 2.0, 24.0 * s)), "MARCO!", UITheme.condensed(800),
				roundi(17.0 * s), tint)
		var left := float(hud._setting("marco_cooldown", 20.0)) * (1.0 - ready)
		if ready < 1.0:
			UITheme.draw_text(self, Rect2(centre + Vector2(-r, 10.0 * s), Vector2(r * 2.0, 18.0 * s)), "%ds" % ceili(left),
					UITheme.condensed(600), roundi(13.0 * s), UITheme.MUTED)
		_draw_seeker_counts(s, origin)

	func _draw_seeker_counts(s: float, origin: Vector2) -> void:
		var hiders: Array = hud._call("live_hiders", [], [])
		var text_x := origin.x + 104.0 * s
		UITheme.draw_text(self, Rect2(text_x, origin.y + 18.0 * s, 120.0 * s, 34.0 * s), str(hiders.size()), UITheme.display(700),
				roundi(32.0 * s), UITheme.INK, HORIZONTAL_ALIGNMENT_LEFT)
		UITheme.draw_text(self, Rect2(text_x, origin.y + 52.0 * s, 120.0 * s, 18.0 * s), "HIDER LEFT" if hiders.size() == 1 else "HIDERS LEFT",
				UITheme.condensed(700), roundi(14.0 * s), UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		UITheme.draw_text(self, Rect2(text_x, origin.y + 74.0 * s, 120.0 * s, 18.0 * s), "TAGS  %d" % hud._tags, UITheme.condensed(700),
				roundi(15.0 * s), MarcoPoloHud.SEEKER_COLOR, HORIZONTAL_ALIGNMENT_LEFT)

	## A whale's beat pip (the manual Marco! button is retired): a ring that fills
	## toward the next automatic call and flashes when it goes out. `beat` is
	## {left, interval} (s); a tell, when the match has one, makes it pulse.
	func _draw_beat_pip(s: float, centre: Vector2, r: float, beat: Dictionary) -> void:
		var interval := maxf(float(beat.interval), 0.05)
		var left := clampf(float(beat.left), 0.0, interval)
		var fill := 1.0 - left / interval
		var flash_time := float(hud._setting("beat_pip_flash", 0.35))
		var flash := clampf((left - (interval - flash_time)) / maxf(flash_time, 0.01), 0.0, 1.0)
		var tint := MarcoPoloHud.SEEKER_COLOR.lerp(Color.WHITE, flash)
		draw_arc(centre, r, 0.0, TAU, 48, Color(UITheme.DEEP, 0.9), 7.0 * s, true)
		if fill > 0.0:
			draw_arc(centre, r, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, Color(tint, 0.85), 7.0 * s, true)
		if flash > 0.0:
			draw_arc(centre, r + 10.0 * s * (1.0 - flash), 0.0, TAU, 48, Color(tint, 0.6 * flash), 2.5 * s, true)
		# Dots round the ring for the beat: a pip that lights as the call nears.
		var tip := -PI * 0.5 + TAU * fill
		draw_circle(centre + Vector2(cos(tip), sin(tip)) * r, (4.0 + 3.0 * flash) * s, tint)
		UITheme.draw_text(self, Rect2(centre - Vector2(r, 12.0 * s), Vector2(r * 2.0, 24.0 * s)), "MARCO!", UITheme.condensed(800),
				roundi(17.0 * s), tint)
		UITheme.draw_text(self, Rect2(centre + Vector2(-r, 10.0 * s), Vector2(r * 2.0, 18.0 * s)), "%.1fs" % left,
				UITheme.condensed(600), roundi(13.0 * s), UITheme.MUTED)

	## The totals from the rounds before (they don't move during a round): a
	## hider sees everyone's, a seeker only their own.
	func _draw_totals(s: float, view: Vector2, me: Node, seeker: bool) -> void:
		var totals: Dictionary = hud._call("totals", [], {})
		var rows: Array = []
		for fish: Variant in totals:
			if is_instance_valid(fish) and (not seeker or fish == me):
				rows.append([fish, float(totals[fish])])
		if rows.is_empty():
			return
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
		var origin := Vector2(18.0 * s, 16.0 * s)
		var line := 20.0 * s
		var rect := Rect2(origin, Vector2(190.0 * s, 26.0 * s + line * mini(rows.size(), 6)))
		UITheme.draw_box(self, rect, UITheme.HUD_FILL, 10.0 * s, RoundMap.PANEL_RIM, 1.0)
		UITheme.draw_text(self, Rect2(origin + Vector2(10.0 * s, 4.0 * s), Vector2(170.0 * s, 18.0 * s)), "TOTALS (BEFORE THIS ROUND)",
				UITheme.condensed(700), roundi(12.0 * s), UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		for i in mini(rows.size(), 6):
			var fish: Node = rows[i][0]
			var y := origin.y + 24.0 * s + i * line
			var tint := UITheme.CORAL if fish == me else UITheme.INK_SOFT
			UITheme.draw_text(self, Rect2(origin.x + 10.0 * s, y, 120.0 * s, line), MarcoPoloHud.name_of(fish), UITheme.condensed(600),
					roundi(15.0 * s), tint, HORIZONTAL_ALIGNMENT_LEFT)
			UITheme.draw_text(self, Rect2(origin.x + 120.0 * s, y, 60.0 * s, line), str(roundi(float(rows[i][1]))), UITheme.condensed(700),
					roundi(15.0 * s), tint, HORIZONTAL_ALIGNMENT_RIGHT)

	func _draw_feed(s: float, view: Vector2) -> void:
		var y := 16.0 * s
		var phase := hud.phase()
		if phase == MarcoPoloHud.COUNTDOWN or phase == MarcoPoloHud.LIVE:
			y = SonarMap.place(view).end.y + 14.0 * s  # under the sonar map, which takes the top right in a round
		for line: Dictionary in hud._feed:
			var age := float(line.age)
			var fade := clampf((MarcoPoloHud.FEED_LIFE - age) / 1.0, 0.0, 1.0)
			var text := String(line.text)
			var font := UITheme.condensed(700)
			var px := roundi(16.0 * s)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 20.0 * s
			var rect := Rect2(view.x - width - 18.0 * s, y, width, 26.0 * s)
			UITheme.draw_box(self, rect, Color(UITheme.HUD_FILL, UITheme.HUD_FILL.a * fade), 8.0 * s)
			UITheme.draw_text(self, rect, text, font, px, Color(line.color as Color, fade))
			y += 30.0 * s

	func _draw_banner(s: float, view: Vector2) -> void:
		var age := hud._banner_age
		if age > MarcoPoloHud.BANNER_LIFE or hud._banner == "":
			return
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - age / 0.18)
		var fade := clampf((MarcoPoloHud.BANNER_LIFE - age) / 0.4, 0.0, 1.0)
		var y := view.y * 0.3
		UITheme.draw_text(self, Rect2(0.0, y, view.x, 70.0 * s), hud._banner, UITheme.display(700), roundi(58.0 * s * pop),
				Color(hud._banner_color, fade))
		if hud._banner_sub != "":
			UITheme.draw_text(self, Rect2(0.0, y + 70.0 * s, view.x, 28.0 * s), hud._banner_sub.to_upper(), UITheme.condensed(700),
					roundi(20.0 * s), Color(UITheme.INK_SOFT, fade))

	## The round's points, now it's over (the first time anyone sees them).
	func _draw_round_card(s: float, view: Vector2) -> void:
		var results := hud._round_results
		var points: Dictionary = results.get("points", {})
		var totals: Dictionary = results.get("totals", {})
		var seekers: Array = results.get("seekers", [])
		var rows: Array = []
		for fish: Variant in points:
			if is_instance_valid(fish):
				rows.append(fish)
		rows.sort_custom(func(a: Node, b: Node) -> bool: return float(points[a]) > float(points[b]))
		var line := 28.0 * s
		var width := 440.0 * s
		var height := 110.0 * s + line * rows.size()
		var rect := Rect2((view - Vector2(width, height)) * 0.5, Vector2(width, height))
		UITheme.draw_box(self, rect, Color(UITheme.GROUND, 0.94), 16.0 * s, RoundMap.PANEL_RIM, 1.5)
		var title := "ROUND %d OVER" % (int(results.get("round", 0)) + 1)
		UITheme.draw_text(self, Rect2(rect.position + Vector2(0.0, 12.0 * s), Vector2(width, 36.0 * s)), title, UITheme.display(700),
				roundi(30.0 * s), UITheme.INK)
		var sub := "EVERYONE CAUGHT  ·  %s LEFT" % MarcoPoloHud.clock(float(results.get("time_left", 0.0))) if bool(results.get("cleared", false)) \
				else "TIME!  ·  %d SURVIVED" % (results.get("survivors", []) as Array).size()
		UITheme.draw_text(self, Rect2(rect.position + Vector2(0.0, 48.0 * s), Vector2(width, 22.0 * s)), sub, UITheme.condensed(700),
				roundi(16.0 * s), UITheme.MUTED)
		var head_y := rect.position.y + 76.0 * s
		var font := UITheme.condensed(700)
		UITheme.draw_text(self, Rect2(rect.position.x + 250.0 * s, head_y, 80.0 * s, 20.0 * s), "ROUND", font, roundi(13.0 * s), UITheme.MUTED,
				HORIZONTAL_ALIGNMENT_RIGHT)
		UITheme.draw_text(self, Rect2(rect.position.x + 340.0 * s, head_y, 80.0 * s, 20.0 * s), "TOTAL", font, roundi(13.0 * s), UITheme.MUTED,
				HORIZONTAL_ALIGNMENT_RIGHT)
		var me := hud.local_fish()
		for i in rows.size():
			var fish: Node = rows[i]
			var y := head_y + 22.0 * s + i * line
			var tint := UITheme.CORAL if fish == me else UITheme.INK_SOFT
			var label := MarcoPoloHud.name_of(fish) + ("  (SEEKER)" if seekers.has(fish) else "")
			UITheme.draw_text(self, Rect2(rect.position.x + 24.0 * s, y, 220.0 * s, line), label, UITheme.condensed(600), roundi(18.0 * s),
					tint, HORIZONTAL_ALIGNMENT_LEFT)
			UITheme.draw_text(self, Rect2(rect.position.x + 250.0 * s, y, 80.0 * s, line), "+%d" % roundi(float(points[fish])), font,
					roundi(18.0 * s), tint, HORIZONTAL_ALIGNMENT_RIGHT)
			UITheme.draw_text(self, Rect2(rect.position.x + 340.0 * s, y, 80.0 * s, line), str(roundi(float(totals.get(fish, 0.0)))), font,
					roundi(18.0 * s), tint, HORIZONTAL_ALIGNMENT_RIGHT)

	func _draw_over_card(s: float, view: Vector2) -> void:
		var totals: Dictionary = hud._call("totals", [], {})
		var rows: Array = []
		for fish: Variant in totals:
			if is_instance_valid(fish):
				rows.append(fish)
		rows.sort_custom(func(a: Node, b: Node) -> bool: return float(totals[a]) > float(totals[b]))
		var line := 28.0 * s
		var width := 420.0 * s
		var height := 96.0 * s + line * rows.size()
		var rect := Rect2((view - Vector2(width, height)) * 0.5, Vector2(width, height))
		UITheme.draw_box(self, rect, Color(UITheme.GROUND, 0.94), 16.0 * s, RoundMap.PANEL_RIM, 1.5)
		var winner: Node = hud._winner if is_instance_valid(hud._winner) else (rows[0] as Node if not rows.is_empty() else null)
		UITheme.draw_text(self, Rect2(rect.position + Vector2(0.0, 12.0 * s), Vector2(width, 40.0 * s)),
				"%s WINS" % MarcoPoloHud.name_of(winner).to_upper() if winner else "MATCH OVER", UITheme.display(700), roundi(32.0 * s), UITheme.GOLD)
		var me := hud.local_fish()
		for i in rows.size():
			var fish: Node = rows[i]
			var y := rect.position.y + 66.0 * s + i * line
			var tint := UITheme.CORAL if fish == me else UITheme.INK_SOFT
			UITheme.draw_text(self, Rect2(rect.position.x + 24.0 * s, y, 260.0 * s, line), "%d.  %s" % [i + 1, MarcoPoloHud.name_of(fish)],
					UITheme.condensed(600), roundi(18.0 * s), tint, HORIZONTAL_ALIGNMENT_LEFT)
			UITheme.draw_text(self, Rect2(rect.position.x + 300.0 * s, y, 96.0 * s, line), str(roundi(float(totals[fish]))), UITheme.condensed(700),
					roundi(18.0 * s), tint, HORIZONTAL_ALIGNMENT_RIGHT)
