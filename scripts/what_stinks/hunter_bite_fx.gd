class_name HunterBiteFx
extends Node
## What a Hunter's bite looks, feels and sounds like beyond the pose (two-stage-attack.md section 3):
## a child of HunterBite, driven only by the ChompKit.Bite's cues (rest, anticipate, gape, hold,
## strike, shake, recover), its `charged` signal and HunterBite.landed, so every effect fires on the
## tick the pose moves, on a puppet too (the host's beats). Nothing here times its own effect; the
## held beat's loop and rumble just follow the charge each tick.
##
##   gape      the press: the creak, a short tick on the pad, bubbles at the mouth
##   hold      the loop starts (pitch and volume rise with the charge); a low rumble that rises; a puff
##             of bubbles now and then; a prey player near the mouth hears it louder and feels a heartbeat
##   charged   full charge: a click and a crisp pulse and a spark of teeth
##   strike    the release: a swoosh, the loop stops
##   landed    contact: chomp / miss, a crunch per fish rising through the chain, the camera's punch
##             scaled by the charge and the fish taken, a hard pulse, a local hit-stop on the Hunter
##             (its controls only: never the global time scale), blood, bubbles and tooth sparks
##
## Prey get it too: prey_caught() is the camera punch, pulse and red flush of a player the bite caught
## (the match calls it). Rumble is WhatStinksRumble (own pad, none for bots). A form's sheet may name
## its own sounds (`sound_<beat>`: sound_chomp, sound_miss ...); the rest come from the style's table.

## Style key -> beat -> sound id (the ids of SoundCatalog's Hunter rows; the stand-ins are its FALLBACKS).
const SOUNDS := {
	"chomp": {"open": "hunter/jaw_open", "hold": "hunter/jaw_hold", "strike": "hunter/strike", "chomp": "hunter/chomp"},
	"engulf": {"open": "whale/gape_open", "hold": "hunter/jaw_hold", "strike": "hunter/strike", "chomp": "whale/gulp", "crunch": "whale/engulf", "engulf": "whale/engulf", "spray": "whale/spray"},
	"lock": {"open": "angel/cones_open", "hold": "angel/lock", "strike": "angel/lash", "chomp": "angel/lash", "denied": "angel/denied", "lost": "angel/lock_lost"},
	"suction": {"open": "gulper/suck", "hold": "gulper/suck", "strike": "hunter/strike", "chomp": "gulper/snap"},
	"coil": {"open": "king/coil", "hold": "king/coil", "strike": "king/whip", "chomp": "king/whip"},
	"drill": {"open": "lamprey/rasp", "hold": "lamprey/rasp", "strike": "lamprey/drill", "chomp": "lamprey/drill"},
	"lash": {"open": "hunter/jaw_open", "hold": "hunter/jaw_hold", "strike": "hunter/strike", "chomp": "hunter/chomp"},
}
## Beats every style shares.
const COMMON := {"charged": "hunter/charged", "strain": "hunter/strain", "crunch": "hunter/crunch", "miss": "hunter/miss"}
## Most crunches layered on one landing (the rest of a big catch is one thick sound).
const MAX_CRUNCH := 6
const CRUNCH_GAP := 0.05
## The WhatStinksHud group (it joins on bind), to find a player's own view.
const HUDS := &"what_stinks_huds"

## Probes: called as (beat, sound id) instead of playing a sound (the beats are listed above).
var sound_log: Callable
## () -> the live prey players (the match's), for the warning to those near an open mouth.
var prey_source: Callable
## () -> whether the match still wants the Hunter free when its hit-stop ends (not after the round ended or it hurled);
## unset: always.
var may_unlock: Callable

var hb: HunterBite
var settings := WhatStinksSettings.shared()
var _loop := 0
var _opened := false
var _fx: ChompKit.Fx
var _puff_t := 0.0
var _rumble_t := 0.0
var _beat_t := 0.0
var _hitstop := 0
var _strain_until := 0


func attach(with: HunterBite) -> void:
	hb = with
	settings = hb.settings
	hb.bite.cue.connect(_on_cue)
	hb.bite.charged.connect(_on_charged)
	hb.landed.connect(_on_landed)
	hb.aborted.connect(_stop_loop)


func _exit_tree() -> void:
	_stop_loop()


## The sound id for `beat`: the form's sheet (`sound_<beat>`), else the style's, else the shared one.
func sound_for(beat: String) -> String:
	var own := str(hb.form.get("sound_" + beat, ""))
	if own != "":
		return own
	var style: Dictionary = SOUNDS.get(str(hb.form.get("attack", "chomp")), SOUNDS["chomp"])
	return str(style.get(beat, COMMON.get(beat, "")))


func _play(beat: String, at: Vector3, intensity := 1.0, step := -1) -> void:
	var id := sound_for(beat)
	if id == "":
		return
	if sound_log.is_valid():
		sound_log.call(beat, id)
		return
	if step >= 0:
		Sfx.play_pitched(id, step, at, intensity)
	else:
		Sfx.play_at(id, at, intensity)


func _on_cue(cue_name: StringName) -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	var held := hb.bite.held_open
	match cue_name:
		&"anticipate", &"gape":
			if held and not _opened:
				_opened = true
				_play("open", hb.mouth_point())
				WhatStinksRumble.pulse(hb.fish, settings.rumble_open, 0.08)
				_bubbles(0.8)
		&"hold":
			if held:
				_start_loop()
		&"strike":
			_stop_loop()
			_play("strike", hb.mouth_point())
		&"rest":
			_opened = false
			_stop_loop()


func _on_charged() -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_play("charged", hb.mouth_point())
	WhatStinksRumble.pulse(hb.fish, settings.rumble_open * 1.6, 0.06)
	var fx := _kit()
	fx.burst(fx.teeth, hb.mouth_point(), 0.6 * settings.bite_fx_mult)  # a rim flash at the lips


## Whether the mouth strained a moment ago (the HUD's ring flashes red).
func straining() -> bool:
	return Time.get_ticks_msec() < _strain_until


## The Angel's press was refused (nothing in range ahead): the denied sound and a short tick on the pad.
func denied() -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_play("denied", hb.mouth_point())
	WhatStinksRumble.pulse(hb.fish, settings.rumble_open * 0.6, 0.05)


## The Angel's lock snapped at `at`: the lost sound, a stutter on the pad and a burst where the ring was.
func lost(at: Vector3) -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_play("lost", hb.mouth_point())
	WhatStinksRumble.pulse(hb.fish, settings.rumble_hold * 1.5, 0.1)
	var kit := _kit()
	kit.burst(kit.bubbles, at, 1.0 * settings.bite_fx_mult)


## A whale's mouth is full (engulf): the strain cue and a stutter on the pad.
func strain() -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_strain_until = Time.get_ticks_msec() + 400
	_play("strain", hb.mouth_point())
	WhatStinksRumble.pulse(hb.fish, settings.rumble_hold * 2.0, 0.05)


## A fish went into a whale's mouth (engulf): a small pop pitched up with the count, a tick on the pad, a puff of bubbles.
func engulf(count: int, at: Vector3) -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_play("engulf", at, 0.7, mini(count, 12))
	WhatStinksRumble.pulse(hb.fish, settings.rumble_hold * 0.7, 0.04)
	_kit().puff(at)


## The Queen's disc took fish on the drill's run (drill): a crunch pitched up with the run's count, a tick on the pad, a puff of blood.
func drilled(count: int, at: Vector3) -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_play("crunch", at, 0.9, mini(count, 12))
	WhatStinksRumble.pulse(hb.fish, settings.rumble_contact * 0.5, 0.05)
	var kit := _kit()
	kit.burst(kit.blood, at, 0.5 * settings.bite_fx_mult)


## A whale's mouth slammed shut: water pushed out of its sides.
func spray() -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_play("spray", hb.mouth_point(), 0.8)
	var kit := _kit()
	kit.burst(kit.bubbles, hb.mouth_point(), 1.6 * settings.bite_fx_mult)


func _on_landed(taken: int) -> void:
	if hb == null or not is_instance_valid(hb.fish):
		return
	_opened = false
	var fish := hb.fish
	var at := hb.mouth_point()
	var charge := hb.strike_charge()
	var caught := taken != 0  # unknown (-1) reads as a catch: its visuals are the same
	var count := clampi(taken, 1, MAX_CRUNCH) if taken > 0 else 1
	var share := clampf(float(count) / MAX_CRUNCH, 0.0, 1.0)
	var chomp_shake := UnnaturalSettings.shared().chomp_cam_shake * hb.shake
	if caught:
		_play("chomp", at)
		if not sound_log.is_valid():
			for i in range(1, count):
				get_tree().create_timer(hb.attack.crunch_delay(hb, i)).timeout.connect(func() -> void:
					if is_instance_valid(hb) and is_instance_valid(hb.fish):
						Sfx.play_pitched(sound_for("crunch"), i, at, 0.8))
		_play("crunch", at, 1.0, 0)
		if not fish.puppet:
			_punch(chomp_shake * (0.7 + 0.6 * charge) * (1.0 + 0.7 * share))
			_stop(lerpf(0.6, 1.0, charge))
		WhatStinksRumble.pulse(fish, settings.rumble_contact * (0.5 + 0.5 * share), 0.12 + 0.1 * share)
		var kit := _kit()
		var size := (0.6 + 0.8 * share) * settings.bite_fx_mult
		if size > 0.0:
			kit.burst(kit.blood, at, size)
			kit.burst(kit.bubbles, at, size)
			kit.burst(kit.teeth, at, minf(size, 1.5))
	else:
		_play("miss", at)
		if not fish.puppet:
			_punch(chomp_shake * 0.35)
		WhatStinksRumble.pulse(fish, settings.rumble_contact * 0.3, 0.06)
		_kit().burst(_kit().bubbles, at, 0.6 * settings.bite_fx_mult)


## A prey player the bite caught (spat out or eaten) feels it on its own view: the camera's punch from
## the mouth, a hard pulse and a red flush (prey_impact x a boss chomp's).
func prey_caught(prey: Array, from: Vector3) -> void:
	var power: float = settings.prey_impact
	if power <= 0.0:
		return
	for victim: Variant in prey:
		var fish := victim as FishController
		if fish == null or not is_instance_valid(fish) or fish.puppet:
			continue
		var camera := ChompKit.view_camera(fish)
		if camera:
			var toward := from - fish.global_position
			camera.call("punch", UnnaturalSettings.shared().chomp_cam_shake * power, toward.normalized() * UnnaturalSettings.shared().chomp_cam_kick * power if toward.length_squared() > 0.01 else Vector3.ZERO)
		WhatStinksRumble.pulse(fish, settings.rumble_contact * 1.5 * power, 0.25)
		flash_hud(fish, 0.6 * power)


## The red flush on `fish`'s own HUD, if it has one here (the local player's).
static func flash_hud(fish: FishController, amount: float) -> void:
	if not fish.is_inside_tree():
		return
	for hud in fish.get_tree().get_nodes_in_group(HUDS):
		var game: Variant = hud.get("game")
		if game != null and game.has_method("local_fish") and game.call("local_fish") == fish and hud.has_method("flash"):
			hud.call("flash", amount)


func _physics_process(delta: float) -> void:
	if hb == null or not is_instance_valid(hb.fish) or not hb.holding() or hb.bite.phase != ChompKit.Phase.HOLD:
		return
	var charge := hb.charge()
	var at := hb.mouth_point()
	var near := _prey_near(at)
	if _loop != 0:
		Sfx.set_loop(_loop, clampf(lerpf(0.55, 0.95, charge) + (0.3 if near else 0.0), 0.0, 1.0), lerpf(0.85, 1.5, charge))
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		_rumble_t = 0.1
		WhatStinksRumble.pulse(hb.fish, settings.rumble_hold * (0.3 + 0.7 * charge), 0.12)
	_puff_t -= delta
	if _puff_t <= 0.0:
		_puff_t = lerpf(0.3, 0.12, charge)
		_kit().puff(at)
	if near != null:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = 1.0 / lerpf(1.2, 3.0, charge)  # the heartbeat quickens as it charges
			WhatStinksRumble.pulse(near, settings.prey_warn_rumble * settings.rumble_hold * 2.0, 0.09)
			get_tree().create_timer(0.14).timeout.connect(func() -> void: WhatStinksRumble.pulse(near, settings.prey_warn_rumble * settings.rumble_hold * 1.2, 0.07))


## The first local prey player within prey_warn_range reaches of the open mouth, or null.
func _prey_near(at: Vector3) -> FishController:
	if settings.prey_warn_range <= 0.0 or not prey_source.is_valid():
		return null
	var within := hb.reach() * settings.prey_warn_range
	for victim: Variant in prey_source.call():
		var fish := victim as FishController
		if fish != null and is_instance_valid(fish) and not fish.puppet and fish.controls == null and fish.global_position.distance_to(at) <= within:
			return fish
	return null


func _start_loop() -> void:
	_stop_loop()
	_rumble_t = 0.0
	_beat_t = 0.0
	var id := sound_for("hold")
	if id == "":
		return
	if sound_log.is_valid():
		sound_log.call("hold", id)
		return
	_loop = Sfx.start_loop(id, hb.fish)


func _stop_loop() -> void:
	if _loop != 0:
		Sfx.stop_loop(_loop, 0.12)
		_loop = 0


func _punch(shake: float) -> void:
	var camera := ChompKit.view_camera(hb.fish)
	if camera:
		camera.call("punch", shake, Vector3.ZERO)


func _bubbles(size: float) -> void:
	if settings.bite_fx_mult > 0.0:
		_kit().burst(_kit().bubbles, hb.mouth_point(), size * 0.5 * settings.bite_fx_mult)


## The Hunter's own moment of hit-stop: its controls don't answer for `share` of hitstop_ms (never the
## global time scale, the game is networked). Skipped if its controls are locked already.
func _stop(share: float) -> void:
	var seconds := settings.hitstop_ms * 0.001 * share
	var fish := hb.fish
	if seconds <= 0.0 or fish.controls_locked:
		return
	fish.controls_locked = true
	_hitstop += 1
	var mine := _hitstop
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(fish) and mine == _hitstop and (not may_unlock.is_valid() or may_unlock.call()):
			fish.controls_locked = false)


## The pooled sparks (made the first time).
func _kit() -> ChompKit.Fx:
	if _fx == null:
		_fx = ChompKit.Fx.new()
		_fx.name = "BiteFx"
		add_child(_fx)
	return _fx
