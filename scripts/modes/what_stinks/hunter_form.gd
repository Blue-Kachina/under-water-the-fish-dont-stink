class_name HunterForm
extends RefCounted
## A Hunter form's sheet (what_stinks.md section 2; the template for every form):
## what the form is and how big, fast and slow it is at hunter_size 1, and its
## bite's shape. Everything here is a default for a setting, never a rule
## (flexible-tuning): the panel's values (HunterSize) multiply on top.
##
## Keys:
##   name, class, species   the FishCharacter class and species it wears
##   length_m               its length at size 1 (m); the body scale is this over the class's hitbox length
##   speed, accel, turn     multipliers on the tuned swimming at size 1 (as the Titans' whale_* values)
##   bite_reach_m           the bite's reach from the mouth at size 1 (m)
##   bite_radius_m          how wide the bite is at its far end at size 1 (m: its half width)
##   bite_wind, bite_every  the wind-up (s: ChompKit.Bite) and the cooldown between bites (s)
##   capacity               fish a bite takes at size 1 (x size^bite_capacity_exp)
##   cam                    factors on the camera's distance and height, on top of the size framing
##   attack                 the held bite's style (HunterAttack.make: chomp, engulf, lock, suction, coil, drill, lash); a style not built yet plays as chomp
##   open_s, charge_s       how fast the jaws open on the press (s) and how long a hold takes to reach full charge (s)
const SHARK := {
	"name": "Drowned Shark", "class": FishCharacter.FishClass.MONSTER, "species": 0,
	"length_m": 7.0, "speed": 1.3, "accel": 0.7, "turn": 0.55,
	"bite_reach_m": 3.5, "bite_radius_m": 1.6, "bite_wind": 0.75, "bite_every": 2.0,
	"capacity": 4.0, "cam": Vector2(1.0, 1.0),
}

## The Titans (Marco Polo's adult whales) as a form, to check the size dial on them too.
const HUMPBACK := {
	"name": "Humpback", "class": FishCharacter.FishClass.TITAN, "species": 0,
	"length_m": 6.7, "speed": 1.3, "accel": 0.7, "turn": 0.55,
	"bite_reach_m": 3.0, "bite_radius_m": 1.4, "bite_wind": 0.75, "bite_every": 2.0,
	"capacity": 4.0, "cam": Vector2(1.0, 1.0),
}

## The sheet for `key` from the registry (HunterForms; the Drowned Shark's if unknown).
static func sheet(key: String) -> Dictionary:
	return HunterForms.sheet(key)


## Its length over its class's hitbox length: the body scale at size 1.
static func body_scale(form: Dictionary) -> float:
	var fish_class: FishCharacter.FishClass = form["class"]
	return float(form["length_m"]) / FishCharacter.hitbox_size(fish_class).z
