class_name WhatStinksModeHud
extends ModeHud
## What Stinks?'s part of the core HUD (hud.gd): the name plates. The Hunter reads the crowd,
## not the names, so it sees none of the prey's (WhatStinksMatch.shows_plate). Everything else
## the mode draws is its own HUD layer (WhatStinksHud); the hint line keeps the usual words.

var game: WhatStinksMatch


func _init(match_node: WhatStinksMatch) -> void:
	game = match_node
	filters_plates = true


func live() -> bool:
	return is_instance_valid(game)


func shows_plate(fish: FishController) -> bool:
	return game.shows_plate(fish)
