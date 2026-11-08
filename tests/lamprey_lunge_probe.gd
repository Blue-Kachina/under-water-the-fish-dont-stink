## A3 (planning_new_hunters.md): the Lamprey Queen's lunge travels about 55 percent of what it did.
## A full-charge release is measured from the release to the end of the dash (the lunge itself; the coast after it is the swim speed she already had, not the impulse), once at the old
## strength (lamprey_lunge_impulse 1.0) and once at the default; the new travel must be 45 to 65 percent of the old, the setting
## must scale it, and 0 must not lunge. Prints the metres.
##   Godot_console.exe --headless --path . res://tests/lamprey_lunge_probe.tscn
extends Node

const KEY := "lamprey_queen"

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120


func _ready() -> void:
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.HOLD
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _set_impulse(settings: WhatStinksSettings, v: float) -> void:
	if settings.get("lamprey_lunge_impulse") != null:
		settings.set("lamprey_lunge_impulse", v)
	else:
		settings.set_meta("lamprey_lunge_impulse", v)  # until the setting is registered


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	main.set_environment("Ocean")
	await _frames(5)
	var form := HunterForm.sheet(KEY)
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	var settings := WhatStinksSettings.shared()
	var bite := HunterBite.new()
	bite.name = "HunterBite"
	fish.add_child(bite)
	bite.setup(fish, form)
	var attack := bite.attack as DrillAttack
	_check(attack != null, "the Queen wears the drill")
	_check(is_equal_approx(DrillAttack.LUNGE_IMPULSE_DEFAULT, 0.55), "default lunge impulse is 0.55")

	_set_impulse(settings, 1.0)
	var old_m := await _lunge(bite, attack)
	_set_impulse(settings, DrillAttack.LUNGE_IMPULSE_DEFAULT)
	var new_m := await _lunge(bite, attack)
	_set_impulse(settings, 0.0)
	var none_m := await _lunge(bite, attack)
	_set_impulse(settings, 1.5)
	var big_m := await _lunge(bite, attack)
	var ratio := new_m / maxf(old_m, 0.001)
	print("      travel: old %.1f m, new %.1f m (%.0f%%), 0 -> %.1f m, 1.5 -> %.1f m" % [old_m, new_m, ratio * 100.0, none_m, big_m])
	_check(old_m > 3.0, "the old lunge goes somewhere (%.1f m)" % old_m)
	_check(ratio > 0.45 and ratio < 0.65, "the new lunge is about 55%% of the old (%.0f%%)" % (ratio * 100.0))
	_check(big_m > old_m, "the setting scales it: 1.5 goes further than 1.0 (%.1f > %.1f)" % [big_m, old_m])
	_check(none_m < new_m * 0.3, "0 does not lunge (%.1f m)" % none_m)
	print("lamprey_lunge_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## Metres along her heading from the release to 1.5 s after it, from a standstill, holding to full charge.
func _lunge(bite: HunterBite, attack: DrillAttack) -> float:
	var n := 0
	while bite.busy() and n < tps * 6:
		await get_tree().physics_frame
		n += 1
	await _frames(tps)
	bite.cooldown = 0.0
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	fish.global_transform = Transform3D(Basis.IDENTITY, fish.global_position)
	bite.try_open()
	await _frames(int(tps * 1.5))
	fish.linear_velocity = Vector3.ZERO
	var forward := -fish.global_basis.z.normalized()
	var start := fish.global_position
	bite.try_close()
	var t := 0
	while t < tps * 3 and not attack.active():
		await get_tree().physics_frame
		t += 1
	while attack.active() and t < tps * 6:
		await get_tree().physics_frame
		t += 1
	var at_end := (fish.global_position - start).dot(forward)
	return at_end
