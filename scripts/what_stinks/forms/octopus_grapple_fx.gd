class_name OctopusGrappleFx
extends OctopusWhipFx
## The look and sound of the Ember Octopus' grapple (GrappleAttack, planning_hunter_refine.md C). Pure presentation, as the lash's
## OctopusWhipFx (whose pools it reuses: flashes, rings, sparks, the reticle quads and the arm streaks):
##
##   flare()       the press: a burst of embers at the beak and the hold's hum (the lash's)
##   latch()       an arm closes on a fish: a hot spark, a flash and a small ring facing along the arm
##   snap_off()    an arm loses its fish (it got too far, or was eaten by something else): a violet fleck
##   torn()        a prey tore the arm off (a dash or a counter-steer): a bigger violet flash and ring
##   morsel()      a catch rides the reeling arm's tip back to the beak (a glowing bead); morsel_off() hides it
##   beak()        the beak snaps on everything reeled in: a flash, a ring and sparks that grow with the count
##   whiff()       a tap with nothing grabbed: the arm flicks at nothing
##   say()         a beat's sound (GRAPPLE_SOUNDS; stand-ins in SoundCatalog.FALLBACKS), or sound_log(beat, id) in a probe

const GRAPPLE_SOUNDS := {
	&"flare": "octopus/flare", &"grab": "octopus/grab", &"snap_off": "octopus/snap_off", &"torn": "octopus/torn",
	&"yank": "octopus/yank", &"beak": "octopus/beak", &"whiff": "octopus/whiff",
}

var latches := 0
var beaks := 0
var tears := 0


func latch(at: Vector3, dir: Vector3) -> void:
	_build()
	latches += 1
	_spark(at, 0.55, HOT)
	_flash(at, 1.0, 0.16, EMBER)
	_ring(at, dir, 0.6, 0.3, HOT)


func snap_off(at: Vector3) -> void:
	_build()
	_spark(at, 0.35, VIOLET)
	_flash(at, 0.6, 0.12, VIOLET)


func torn(at: Vector3, dir: Vector3) -> void:
	_build()
	tears += 1
	_spark(at, 0.8, VIOLET)
	_flash(at, 1.4, 0.2, VIOLET)
	_ring(at, dir, 1.0, 0.4, VIOLET)


## The catch on arm `arm`'s tip at `at` (world), `glow` 0..1.
func morsel(arm: int, at: Vector3, glow: float) -> void:
	if not _built:
		_build()
	var r := _reticles[arm]
	r.visible = true
	r.global_position = at
	r.scale = Vector3.ONE * lerpf(0.35, 0.7, clampf(glow, 0.0, 1.0))
	(r.material_override as StandardMaterial3D).albedo_color = HOT


func morsel_off(arm: int) -> void:
	if _built and _reticles[arm].visible:
		_reticles[arm].visible = false


func beak(at: Vector3, dir: Vector3, count: int) -> void:
	_build()
	beaks += 1
	var power := clampf(0.8 + 0.12 * float(count), 0.8, 1.8)
	_flash(at, 1.6 * power, 0.16, HOT)
	_ring(at, dir, 1.2 * power, 0.4, EMBER)
	_spark(at, power, HOT)


func whiff(at: Vector3) -> void:
	_build()
	_spark(at, 0.3, EMBER)


func say(beat: StringName, at: Vector3, step := 0) -> void:
	var id: String = GRAPPLE_SOUNDS.get(beat, "")
	if id == "":
		return
	if sound_log.is_valid():
		sound_log.call(String(beat), id)
		return
	if not is_inside_tree():
		return
	if beat == &"grab":
		Sfx.play_pitched(id, mini(step, 12), at, 0.8)
	else:
		Sfx.play_at(id, at, 1.0)


## Stops the hold's hum (the flare started it).
func hum_off() -> void:
	_stop_loop()
	_aura_want = 0.0


## Ids this FX plays (for the sound catalog registration).
static func grapple_sound_ids() -> Array[String]:
	var out: Array[String] = ["octopus/charge"]
	for id: String in GRAPPLE_SOUNDS.values():
		if not out.has(id):
			out.append(id)
	return out
