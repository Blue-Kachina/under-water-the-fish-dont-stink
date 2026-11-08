class_name HunterAttack
extends RefCounted
## A Hunter form's attack style (two-stage-attack.md section 2c): the rules of one held bite,
## one small object per style (attacks/<style>_attack.gd) instead of one class per form.
## HunterBite owns the press, hold and release; the style answers the questions the form
## changes. This base is the plain bite: always opens, a frustum, nothing extra. The form
## sheet names its style (`attack`); a style not built yet plays as the chomp.
##
## Hooks (all take the HunterBite):
##   can_open            on a press: whether the jaws may open (the Angel's range gate)
##   on_denied           the press was refused by can_open (a beat, no cooldown)
##   on_open, on_hold    the press accepted; each tick held
##   reach_mult_at,
##   capacity_mult_at    what a release at a charge buys on the bite (the chomp's)
##   catch_rule          at the contact tick: {point, capacity, inside, only, extra, frustum} for
##                       WhatStinksMatch._judge_bite; `frustum` says the lock-on bite may sit on top
##   net_catch_rule      the same for a guest's bite the host judges, from what the guest reported
##   net_extra           what a guest sends with its landing besides the mouth, heading and charge
##   on_close            after the bite was judged (`taken` is WhatStinksField.eat_at's result)
##   on_tick             every physics tick, held or not (a style that carries things in its mouth)
##   on_landed           after the contact tick, judged or not (a style lets go of what it still holds)
##   crunch_delay        seconds after the first crunch that the `i`th fish's crunch plays (the lash travels)
##   suppresses_ram      the body ram is held off now (a dash that takes its own count)
##   on_cancel           the held bite was called off, or the Hunter went (let go of everything)
##   ring_count          the number the HUD's ring shows while held (the capacity a release takes now)
##   bot_plan            the bot's button this tick: {"press": open now, "hold": keep it down}

## Style key -> script, for make(). Loaded on use so a style file can extend this one.
const STYLES := {
	"chomp": "res://scripts/what_stinks/attacks/chomp_attack.gd",
	"engulf": "res://scripts/what_stinks/attacks/engulf_attack.gd",
	"coil": "res://scripts/what_stinks/attacks/coil_attack.gd",
	"drill": "res://scripts/what_stinks/attacks/drill_attack.gd",
	"lock": "res://scripts/what_stinks/attacks/lock_attack.gd",
	"suction": "res://scripts/what_stinks/attacks/suction_attack.gd",
	"whip": "res://scripts/what_stinks/attacks/whip_attack.gd",
	"lure": "res://scripts/what_stinks/attacks/lure_attack.gd",
	"grapple": "res://scripts/what_stinks/attacks/grapple_attack.gd",
}

var key := "chomp"


## The style for `style_key` (the chomp for a style that is not built).
static func make(style_key: String) -> HunterAttack:
	var path: String = STYLES.get(style_key, STYLES["chomp"])
	var attack := (load(path) as GDScript).new() as HunterAttack
	return attack


func can_open(_bite: HunterBite) -> bool:
	return true


func on_open(_bite: HunterBite) -> void:
	pass


func on_denied(_bite: HunterBite) -> void:
	pass


func crunch_delay(_bite: HunterBite, i: int) -> float:
	return HunterBiteFx.CRUNCH_GAP * i


func on_hold(_bite: HunterBite, _delta: float) -> void:
	pass


func reach_mult_at(_bite: HunterBite, _charge: float) -> float:
	return 1.0


func capacity_mult_at(_bite: HunterBite, _charge: float) -> float:
	return 1.0


## The plain frustum along the nose from `mouth`, at `charge`.
func frustum_rule(bite: HunterBite, mouth: Vector3, forward: Vector3, charge: float) -> Dictionary:
	var reach := bite.reach_at(charge)
	var radius := bite.radius()
	return {
		"point": mouth + forward * reach * 0.5, "capacity": bite.capacity_at(charge), "only": null, "extra": [], "frustum": true,
		"inside": func(at: Vector3) -> bool: return HunterBite.in_frustum(mouth, forward, reach, radius, at),
	}


func catch_rule(bite: HunterBite) -> Dictionary:
	return frustum_rule(bite, bite.mouth_point(), -bite.fish.global_basis.z.normalized(), bite.strike_charge())


func net_catch_rule(bite: HunterBite, mouth: Vector3, forward: Vector3, charge: float, _extra: Dictionary) -> Dictionary:
	return frustum_rule(bite, mouth, forward, charge)


func net_extra(_bite: HunterBite) -> Dictionary:
	return {}


func on_close(_bite: HunterBite, _taken: Dictionary) -> void:
	pass


func on_tick(_bite: HunterBite, _delta: float) -> void:
	pass


func on_landed(_bite: HunterBite) -> void:
	pass


## Whether the body ram (WhatStinksMatch._ram_step) is held off now (the drill's dash takes its own count).
func suppresses_ram(_bite: HunterBite) -> bool:
	return false


func on_cancel(_bite: HunterBite) -> void:
	pass


func ring_count(bite: HunterBite) -> int:
	return bite.capacity()


func bot_plan(_bot: WhatStinksBot, _bite: HunterBite) -> Dictionary:
	return {"press": false, "hold": false}
