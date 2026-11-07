class_name ChompKit
extends RefCounted
## Chomps that land like an impact (planning_bosses_and_survival.md §4), shared
## by every jawed boss and anything else that bites hard (the Drowned Jaws item).
##
## A Bite is one chomp's timing, a real bite's beats (settings' Chomps group):
## 1. ANTICIPATE: the head pulls back, the snout lifts (chomp_anticipate);
## 2. GAPE: the jaw drops open, fast then slowing (ease-out, chomp_gape);
## 3. HOLD: held wide, the readable telegraph (chomp_hold);
## 4. STRIKE: the head lunges as the jaws slam shut (ease-in, chomp_strike); the
##    bite lands on the tick they're chomp_contact shut, from where the mouth
##    is then, so a side-step during the hold dodges it;
## 5. SHAKE: shut, the head saws side to side (chomp_shake);
## 6. RECOVER: back to rest (chomp_recover).
## The wind-up's three beats are scaled together to the boss's own chomp wind
## (shark_chomp_wind, king_chomp_wind). A Bite's phase index goes over the
## network so a guest's puppet plays the same curve.
##
## The impact (static, on the victim's own machine only):
## - bite_player(): the bite's damage, then impact();
## - impact(): the victim's camera punches (its own view in split-screen), the
##   boss and the victim freeze for a moment (a local hit-stop: never the
##   global time scale, the game is networked), the fish squashes, is knocked
##   back from the mouth, the red vignette flushes, the pad rumbles, blood,
##   bubbles and tooth sparks burst at the mouth, boss/chomp_thud plays and the
##   damage shows in the big style;
## - miss(): jaws clacking on nothing still feel heavy: a smaller shake for
##   players near, a bubble puff, boss/chomp_miss;
## - light_impact(): a zombie's lunge landing (lunge_impact): a camera tick, a
##   rim flash, a light knock and rumble and one bubble puff, at most one per
##   player per lunge_impact_every s (a bigger one in the same window only
##   raises the shake), so a swarm reads as a rattle and costs the same as one;
## - chomp_zombie(): a player's chomp on a zombie or a boss (Drowned Jaws).

enum Phase { IDLE, ANTICIPATE, GAPE, HOLD, STRIKE, SHAKE, RECOVER }
## Each phase's cue (Bite.cue), in Phase's order; "contact" also fires on the landing tick.
const CUES: Array[StringName] = [&"rest", &"anticipate", &"gape", &"hold", &"strike", &"shake", &"recover"]
## The head's scale (width, height, length) at the chomp's key poses: drawn back and swollen,
## stretched tall as the jaw drops, wrung out long as it lunges, slammed flat on impact.
const POSE_WIND := Vector3(1.04, 1.06, 0.93)
const POSE_WIDE := Vector3(0.94, 1.14, 1.05)
const POSE_LUNGE := Vector3(0.86, 0.88, 1.3)
const POSE_IMPACT := Vector3(1.18, 1.14, 0.78)

const BLOOD := Color(0.75, 0.04, 0.05, 0.55)
const BUBBLE := Color(0.75, 0.9, 1.0, 0.5)
const TOOTH := Color(1.0, 0.95, 0.8, 0.9)
## The groups FollowCamera and UnnaturalHud join, to find a player's own view.
const CAMERAS := &"follow_cameras"
const HUDS := &"unnatural_huds"

## Light impacts played, and the ones the throttle merged (probes count them).
static var light_impacts := 0
static var light_merged := 0
## Set while chomp_zombie() hits, so its damage number shows in the big style.
static var big_hit := false
## Each player's last light impact (s of physics ticks) and its views, found once.
static var _light_at := {}
static var _views := {}


## One chomp's timing (see the class note). update() each tick; it returns
## true on the tick the bite lands (the contact frame).
class Bite:
	## A beat of the chomp, for whatever should sync to it (sounds, rumble, flashes): `name` is
	## one of CUES, fired as the Bite enters that beat (so on a puppet too, as it plays the
	## host's beats), and `contact` on the tick the jaws land.
	signal cue(name: StringName)

	var settings: UnnaturalSettings
	var phase := Phase.IDLE
	## Seconds into the phase.
	var t := 0.0
	## The wind-up's length (s): its beats scaled to fit it.
	var wind := 0.5
	## How open the jaw is (0 shut, 1 gaping), how clamped it is after the
	## strike (1 shut tight, easing to 0), the snout's lift (0 to 1), the head's
	## saw (-1 to 1) and how far it moved forward this tick (m, back is negative).
	var open := 0.0
	var clamp_shut := 0.0
	var lift := 0.0
	var saw := 0.0
	var step := 0.0
	## The stylised pose (Battletoads' squash and stretch): the head's scale (width, height,
	## length: ONE at rest) and how far past wide the jaw swings (0 at rest, jaws' worth).
	var smear := Vector3.ONE
	var over := 0.0
	## The bite's reach (m): its pull-back and lunge are shares of it.
	var reach := 6.0
	## Whether this bite has landed (its contact frame passed).
	var landed := false
	var _from_open := 0.0
	var _offset := 0.0
	var _net_phase := -1

	func _init(from: UnnaturalSettings) -> void:
		settings = from

	## Starts a chomp, its wind-up `wind_s` s, biting `bite_reach` m round the mouth.
	func start(wind_s: float, bite_reach: float) -> void:
		wind = maxf(wind_s, 0.02)
		reach = bite_reach
		_enter(Phase.ANTICIPATE)

	## Straight to the strike (jaws already wide: a charging shark's).
	func strike_now(bite_reach: float) -> void:
		reach = bite_reach
		_enter(Phase.STRIKE)

	## Called off (it's grabbing instead, or charging).
	func cancel() -> void:
		_enter(Phase.IDLE)
		_offset = 0.0

	func busy() -> bool:
		return phase != Phase.IDLE

	## Winding up: pulling back, gaping or holding.
	func winding() -> bool:
		return phase == Phase.ANTICIPATE or phase == Phase.GAPE or phase == Phase.HOLD

	## Its phase as a number (0 idle), for the network.
	func index() -> int:
		return phase

	## A puppet: the host's phase index, played from its start when it changes.
	func sync(net_phase: int) -> void:
		if net_phase == _net_phase:
			return
		_net_phase = net_phase
		if net_phase != phase and net_phase >= 0 and net_phase <= Phase.RECOVER:
			if net_phase == Phase.ANTICIPATE or net_phase == Phase.STRIKE:
				_offset = 0.0
			_enter(net_phase as Phase)

	func duration(of: Phase) -> float:
		var shape := maxf(settings.chomp_anticipate + settings.chomp_gape + settings.chomp_hold, 0.001)
		var scale := wind / shape
		match of:
			Phase.ANTICIPATE:
				return settings.chomp_anticipate * scale
			Phase.GAPE:
				return settings.chomp_gape * scale
			Phase.HOLD:
				return settings.chomp_hold * scale
			Phase.STRIKE:
				return settings.chomp_strike
			Phase.SHAKE:
				return settings.chomp_shake
			Phase.RECOVER:
				return settings.chomp_recover
		return 0.0

	func _enter(next: Phase) -> void:
		phase = next
		t = 0.0
		_from_open = open
		if next == Phase.STRIKE:
			landed = false
		cue.emit(CUES[next])

	## A tick: returns true on the tick it lands (the jaws chomp_contact shut).
	func update(delta: float) -> bool:
		step = 0.0
		if phase == Phase.IDLE:
			open = move_toward(open, 0.0, delta * 4.0)
			clamp_shut = 0.0
			lift = move_toward(lift, 0.0, delta * 4.0)
			saw = 0.0
			over = 0.0
			smear = smear.lerp(Vector3.ONE, minf(delta * 12.0, 1.0))
			return false
		t += delta
		var length := duration(phase)
		var s := clampf(t / maxf(length, 0.0001), 0.0, 1.0)
		var back := settings.chomp_pull * reach
		var lunge := settings.chomp_lunge * reach
		var contact := false
		match phase:
			Phase.ANTICIPATE:
				open = lerpf(_from_open, 0.12, s)
				lift = smoothstep(0.0, 1.0, s)
				_move_to(-back * smoothstep(0.0, 1.0, s))
				smear = Vector3.ONE.lerp(POSE_WIND, smoothstep(0.0, 1.0, s))  # drawn back, swelling
			Phase.GAPE:
				open = lerpf(maxf(_from_open, 0.12), 1.0, 1.0 - pow(1.0 - s, 3.0))
				lift = 1.0
				smear = POSE_WIND.lerp(POSE_WIDE, 1.0 - pow(1.0 - s, 3.0))  # stretched tall as it drops
				over = 0.28 * sin(s * PI)  # the jaw flings past wide, then settles
			Phase.HOLD:
				open = 1.0
				lift = lerpf(1.0, 0.7, s)
				var tremble := sin(t * 70.0) * 0.012 * (0.5 + s)  # quivering, ready to go
				smear = POSE_WIDE + Vector3(-tremble, tremble, tremble * 0.5)
				over = absf(tremble) * 3.0
			Phase.STRIKE:
				open = _from_open * (1.0 - s * s)
				lift = lerpf(0.7, -0.3, s)
				_move_to(lerpf(-back, lunge, s))
				smear = POSE_WIDE.lerp(POSE_LUNGE, s * s)  # wrung out long
				over = 0.0
				if not landed and open <= 1.0 - settings.chomp_contact:
					landed = true
					contact = true
			Phase.SHAKE:
				open = 0.0
				clamp_shut = 1.0
				lift = lerpf(-0.3, 0.0, s)
				saw = sin(s * TAU * 2.5) * (1.0 - s)
				# Slammed flat, then a damped wobble back out.
				var spring := exp(-4.5 * s) * cos(s * 16.0)
				smear = Vector3.ONE + (POSE_IMPACT - Vector3.ONE) * spring
				over = 0.0
			Phase.RECOVER:
				open = 0.0
				clamp_shut = 1.0 - smoothstep(0.0, 1.0, s)
				saw = 0.0
				lift = 0.0
				smear = smear.lerp(Vector3.ONE, minf(delta * 14.0, 1.0))
				over = 0.0
		if contact and t < length:
			cue.emit(&"contact")
		if t >= length:
			if phase == Phase.STRIKE and not landed:
				open = 0.0
				landed = true
				contact = true
			if contact:
				cue.emit(&"contact")  # before the next beat's cue
			_enter(Phase.IDLE if phase == Phase.RECOVER else (phase + 1) as Phase)
			if phase == Phase.IDLE:
				_offset = 0.0
		return contact

	## The head where `offset` m along says (forward positive), as this tick's step.
	func _move_to(offset: float) -> void:
		step = offset - _offset
		_offset = offset


# --- The impact ---------------------------------------------------------------

## A bite of `damage` (already scaled) on player `fish` from a mouth at `mouth`:
## hurt, then the impact if it did (power: 1 a boss's chomp). Returns whether it hurt.
static func bite_player(run: UnnaturalRun, fish: FishController, mouth: Vector3, damage: float, cause: String, boss: Boss = null,
		power := 1.0) -> bool:
	if not run.hurt(fish, damage, -1, cause):
		return false
	impact(run, fish, mouth, power, boss, damage)
	return true


## A chomp's impact on player `fish` from `from` (the mouth), `power` times a
## boss's chomp; `boss` freezes with them; `amount`: its damage (0: none shown).
static func impact(run: UnnaturalRun, fish: FishController, from: Vector3, power := 1.0, boss: Boss = null, amount := 0.0) -> void:
	if not is_instance_valid(fish) or fish.puppet:
		return
	var settings := run.settings
	var scale := power * clampf(amount / maxf(settings.chomp_damage_ref, 1.0), 0.6, 2.0) if amount > 0.0 else power
	var toward := from - fish.global_position
	var camera := _camera_of(fish)
	if camera:
		camera.call("punch", settings.chomp_cam_shake * scale, toward.normalized() * settings.chomp_cam_kick * power if toward.length_squared() > 0.01 else Vector3.ZERO)
	if settings.chomp_hit_stop > 0.0:
		if is_instance_valid(boss):
			boss.hit_stop = maxf(boss.hit_stop, settings.chomp_hit_stop)
		_freeze(run, fish, settings.chomp_hit_stop)
	_squash(run, fish, settings.chomp_squash * minf(power, 1.5))
	if settings.chomp_knockback > 0.0 and run.holder_of(fish) == null:
		var away := -toward.normalized() if toward.length_squared() > 0.01 else fish.global_basis.z
		fish.apply_push(away * settings.chomp_knockback * power)
	var hud := _hud_of(fish)
	if hud:
		hud.hurt_level = maxf(hud.hurt_level, settings.chomp_vignette * power)
		if amount > 0.0:
			hud.numbers.add_big(fish.global_position + Vector3.UP * 1.2, amount)
	_rumble(fish, settings.chomp_rumble * power, settings.chomp_rumble_time)
	var fx := _fx(run)
	var at := fish.global_position.lerp(from, 0.35)
	fx.burst(fx.blood, at, maxf(power, 0.5))
	fx.burst(fx.bubbles, from, maxf(power, 0.5))
	fx.burst(fx.teeth, from, 1.0)
	Sfx.play_at("boss/chomp_thud", at, clampf(power, 0.3, 1.5))


## Jaws (`reach` m) clacking shut on nothing at `mouth`: a smaller shake for
## local players within chomp_miss_range times the reach, a bubble puff and boss/chomp_miss.
static func miss(run: UnnaturalRun, mouth: Vector3, reach: float, power := 1.0) -> void:
	var settings := run.settings
	var near := reach * settings.chomp_miss_range
	for fish in run.local_players():
		if not run.is_up(fish):
			continue
		var gap := fish.global_position.distance_to(mouth)
		if gap > near:
			continue
		var camera := _camera_of(fish)
		if camera:
			var fall := 1.0 - 0.5 * gap / maxf(near, 0.01)
			camera.call("punch", settings.chomp_cam_shake * settings.chomp_miss_shake * power * fall, Vector3.ZERO)
		_rumble(fish, settings.chomp_rumble * settings.chomp_miss_shake * power, settings.chomp_rumble_time * 0.6)
	var fx := _fx(run)
	fx.burst(fx.bubbles, mouth, 0.6 * power)
	Sfx.play_at("boss/chomp_miss", mouth, clampf(power, 0.3, 1.5))


## A rumble of `strength` for `seconds` on every local player within `reach` m of `at`
## (fading with distance): a chomp's beats, as opposed to its landing (impact).
static func rumble_near(run: UnnaturalRun, at: Vector3, reach: float, strength: float, seconds: float) -> void:
	if strength <= 0.0 or seconds <= 0.0:
		return
	for fish in run.local_players():
		if not run.is_up(fish):
			continue
		var gap := fish.global_position.distance_to(at)
		if gap <= reach:
			_rumble(fish, strength * (1.0 - 0.6 * gap / maxf(reach, 0.01)), seconds)


## A zombie's lunge landing on player `fish` from `from` (lunge_impact): a
## light, throttled impact. Returns whether it played (false: off, merged or remote).
static func light_impact(run: UnnaturalRun, fish: FishController, from: Vector3) -> bool:
	var settings := run.settings
	if not settings.lunge_impact or not is_instance_valid(fish) or fish.puppet:
		return false
	var shake := settings.chomp_cam_shake * settings.lunge_impact_shake
	var camera := _camera_of(fish)
	var now := float(Engine.get_physics_frames()) / maxf(Engine.physics_ticks_per_second, 1.0)  # game time, not the wall clock
	var last: float = _light_at.get(fish, -INF)
	if now - last < settings.lunge_impact_every:
		light_merged += 1
		if camera:
			camera.call("punch", shake, Vector3.ZERO)  # merged: the strongest shake wins
		return false
	_light_at[fish] = now
	light_impacts += 1
	var toward := from - fish.global_position
	if camera:
		camera.call("punch", shake, toward.normalized() * settings.chomp_cam_kick * settings.lunge_impact_shake if toward.length_squared() > 0.01 else Vector3.ZERO)
	if settings.lunge_impact_knock > 0.0 and toward.length_squared() > 0.01 and run.holder_of(fish) == null:
		fish.apply_push(-toward.normalized() * settings.lunge_impact_knock)
	var hud := _hud_of(fish)
	if hud:
		hud.hurt_level = maxf(hud.hurt_level, settings.lunge_impact_flash)
	_rumble(fish, settings.lunge_impact_rumble, 0.1)
	var fx := _fx(run)
	fx.puff(fish.global_position.lerp(from, 0.5))
	return true


## A player's chomp (Drowned Jaws): `damage` to zombie (or boss proxy) `index`
## through UnnaturalRun.hit (the boss takes it as any hit), its number in the
## big style, a boss hit freezing a moment, blood and teeth there, and `by`'s
## camera punching (power: 1 a boss chomp's shake on them).
static func chomp_zombie(run: UnnaturalRun, index: int, damage: float, by: FishController, source: String, power := 0.5) -> void:
	if not run.horde.is_alive(index):
		return
	var at := run.horde.enemy_position(index)
	var push := Vector3.ZERO
	if is_instance_valid(by):
		push = (at - by.global_position).normalized() * 2.0
	big_hit = true
	run.hit(index, damage, by, source, push)
	big_hit = false
	var boss := run.boss_at(index)
	if boss and run.settings.chomp_hit_stop > 0.0:
		boss.hit_stop = maxf(boss.hit_stop, run.settings.chomp_hit_stop)
	if is_instance_valid(by) and not by.puppet:
		var camera := _camera_of(by)
		if camera:
			camera.call("punch", run.settings.chomp_cam_shake * power, Vector3.ZERO)
		_rumble(by, run.settings.chomp_rumble * power, run.settings.chomp_rumble_time * 0.6)
	var fx := _fx(run)
	fx.burst(fx.blood, at, maxf(power, 0.5))
	fx.burst(fx.teeth, at, 1.0)
	Sfx.play_at("boss/chomp_thud", at, clampf(power, 0.3, 1.5))


## Forgets every player's throttle and views (a new run).
static func reset() -> void:
	_light_at.clear()
	_views.clear()
	light_impacts = 0
	light_merged = 0


# --- Finding a player's view, and the feel on them ----------------------------

## `fish`'s own FollowCamera (null: none).
static func _camera_of(fish: FishController) -> Camera3D:
	var views: Array = _views.get(fish, [])
	if views.is_empty() or not is_instance_valid(views[0]):
		_find_views(fish)
		views = _views.get(fish, [null, null])
	return views[0] as Camera3D if is_instance_valid(views[0]) else null


## `fish`'s own UnnaturalHud (null: none).
static func _hud_of(fish: FishController) -> UnnaturalHud:
	var views: Array = _views.get(fish, [])
	if views.is_empty() or not is_instance_valid(views[1]):
		_find_views(fish)
		views = _views.get(fish, [null, null])
	return views[1] as UnnaturalHud if is_instance_valid(views[1]) else null


static func _find_views(fish: FishController) -> void:
	var camera: Camera3D = null
	var hud: UnnaturalHud = null
	if fish.is_inside_tree():
		var tree := fish.get_tree()
		for node in tree.get_nodes_in_group(CAMERAS):
			if node.get("fish") == fish and node.has_method("punch"):
				camera = node as Camera3D
		for node in tree.get_nodes_in_group(HUDS):
			if node is UnnaturalHud and (node as UnnaturalHud).fish == fish:
				hud = node as UnnaturalHud
	_views[fish] = [camera, hud]


## The victim's moment of hit-stop: its controls don't answer for `seconds`.
static func _freeze(run: UnnaturalRun, fish: FishController, seconds: float) -> void:
	if fish.controls_locked:
		return
	fish.controls_locked = true
	run.get_tree().create_timer(seconds, true, true).timeout.connect(func() -> void:
		if is_instance_valid(fish) and is_instance_valid(run) and run.is_up(fish):
			fish.controls_locked = false)


## The victim's model squashed by `amount` (0.3: 30% flatter), springing back.
static func _squash(run: UnnaturalRun, fish: FishController, amount: float) -> void:
	var model: Node3D = fish.get("_visual")
	if amount <= 0.0 or not is_instance_valid(model) or model.has_meta("chomp_squash"):
		return
	var rest := model.scale
	model.set_meta("chomp_squash", true)
	model.scale = rest * Vector3(1.0 + amount * 0.7, 1.0 - amount, 1.0 + amount * 0.4)
	var tween := run.create_tween()
	tween.tween_property(model, "scale", rest, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(model):
			model.remove_meta("chomp_squash"))


## The pad of the player playing `fish` (every pad, solo) rumbles `strength` (0 to 1+) for `seconds`.
static func _rumble(fish: FishController, strength: float, seconds: float) -> void:
	if strength <= 0.0 or seconds <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var input: PlayerInput = fish.input_source
	var pads: Array[int] = []
	if input and input.device >= 0:
		pads.append(input.device)
	else:
		pads = Input.get_connected_joypads()
	for pad in pads:
		Input.start_joy_vibration(pad, clampf(strength * 0.6, 0.0, 1.0), clampf(strength, 0.0, 1.0), seconds)


# --- The FX -------------------------------------------------------------------

## The run's pooled chomp FX (made the first time).
static func _fx(run: UnnaturalRun) -> Fx:
	var fx := run.get_node_or_null("ChompFx") as Fx
	if fx == null:
		fx = Fx.new()
		fx.name = "ChompFx"
		run.add_child(fx)
	return fx


## Pooled bursts: a boss chomp's blood cloud, bubble burst and tooth sparks
## (one each, restarted), and a few bubble puffs for zombie lunges (taken in turn).
class Fx:
	extends Node3D

	const PUFFS := 6

	var blood: CPUParticles3D
	var bubbles: CPUParticles3D
	var teeth: CPUParticles3D
	var puffs: Array[CPUParticles3D] = []
	var _next_puff := 0

	func _ready() -> void:
		top_level = true
		blood = _make(24, 0.9, 0.5, 3.5, 0.9, ChompKit.BLOOD, 0.0, 2.2)
		bubbles = _make(32, 0.7, 1.5, 9.0, 0.35, ChompKit.BUBBLE, 2.5, 1.0)
		teeth = _make(10, 0.35, 4.0, 14.0, 0.12, ChompKit.TOOTH, 0.0, 0.6)
		for n in PUFFS:
			puffs.append(_make(8, 0.45, 0.8, 3.5, 0.22, ChompKit.BUBBLE, 2.0, 1.0))

	## `particles` bursting at `at`, `size` times bigger.
	func burst(particles: CPUParticles3D, at: Vector3, size := 1.0) -> void:
		particles.global_position = at
		particles.scale_amount_min = 0.7 * size
		particles.scale_amount_max = 1.3 * size
		particles.restart()

	## One bubble puff at `at` (the oldest reused).
	func puff(at: Vector3) -> void:
		var particles := puffs[_next_puff]
		_next_puff = (_next_puff + 1) % puffs.size()
		particles.global_position = at
		particles.restart()

	func _make(amount: int, life: float, speed_min: float, speed_max: float, size: float, color: Color, rise: float, grow: float) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = amount
		p.lifetime = life
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = speed_min
		p.initial_velocity_max = speed_max
		p.damping_min = speed_max * 1.2
		p.damping_max = speed_max * 2.0
		p.gravity = Vector3.UP * rise
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(0.2, 1.0))
		curve.add_point(Vector2(1.0, grow))
		p.scale_amount_curve = curve
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		var look := FxKit.glow(color, FxKit.dot(), true)
		look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		look.vertex_color_use_as_albedo = true
		quad.material = look
		p.mesh = quad
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		p.color_ramp = fade
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		return p
