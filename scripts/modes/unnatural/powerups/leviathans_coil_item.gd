class_name LeviathansCoilItem
extends AttackWeapon
## Leviathan's Coil as a boss item (planning_bosses_and_survival.md §2): the
## King of Herrings' drop. The same steady attack it had as a boss weapon
## (LeviathansCoil, a FishAttack), held in no weapon slot. It works at level
## coil_arrive_level with one stack, coil_levels_per_stack more each stack
## after: its milestones by that level, and its facets (Weapons' COIL list)
## spread evenly over the levels below it, one step each, as a weapon given
## at that level would have them.


func kind() -> FishAttack.Kind:
	return FishAttack.Kind.COIL


func attack_level() -> int:
	return maxi(settings.coil_arrive_level + (stacks - 1) * settings.coil_levels_per_stack, 1)


func held_facets() -> Dictionary:
	var list: Array = Weapons.ATTACK_FACETS[FishAttack.Kind.COIL]
	var spread := {}
	for n in maxi(attack_level() - 1, 0):
		var entry: Array = list[n % list.size()]
		spread[entry[0]] = spread.get(entry[0], 0.0) + Weapons.step_amount(entry, 1.0, settings)
	return spread
