class_name HunterForms
extends RefCounted
## The registry of Hunter forms (what_stinks.md section 2): the five Titans and
## the six bosses. One entry per form, each its own file in forms/<key>.gd so
## the form workers each own exactly one file and never touch this one.
##
## A form file is a RefCounted with static functions:
##   ready() -> bool                    true once the form is playable end to end (it is only offered then)
##   sheet() -> Dictionary              the form sheet (HunterForm's keys; missing keys take DEFAULTS)
##   dress(fish, sheet) -> void         optional: extras on the Hunter's fish after its look and size are
##                                      set (a model swap, a rig, ...). Called every round the form is
##                                      worn, so it must be safe to call twice on the same model.
## The form sheets document themselves in hunter_forms.md (the template).

## Every form, in the order the match card lists them.
const KEYS: Array[String] = [
	"drowned_shark", "humpback", "orca", "beluga", "sperm", "blue",
	"king_of_herrings", "gulper_mother", "whale_fall", "lamprey_queen", "fallen_angel",
]

const FORMS := {
	"drowned_shark": preload("res://scripts/what_stinks/forms/drowned_shark.gd"),
	"humpback": preload("res://scripts/what_stinks/forms/humpback.gd"),
	"orca": preload("res://scripts/what_stinks/forms/orca.gd"),
	"beluga": preload("res://scripts/what_stinks/forms/beluga.gd"),
	"sperm": preload("res://scripts/what_stinks/forms/sperm.gd"),
	"blue": preload("res://scripts/what_stinks/forms/blue.gd"),
	"king_of_herrings": preload("res://scripts/what_stinks/forms/king_of_herrings.gd"),
	"gulper_mother": preload("res://scripts/what_stinks/forms/gulper_mother.gd"),
	"whale_fall": preload("res://scripts/what_stinks/forms/whale_fall.gd"),
	"lamprey_queen": preload("res://scripts/what_stinks/forms/lamprey_queen.gd"),
	"fallen_angel": preload("res://scripts/what_stinks/forms/fallen_angel.gd"),
}

## What a sheet takes when its form file leaves a key out (the Drowned Shark's numbers).
const DEFAULTS := {
	"name": "Hunter", "class": FishCharacter.FishClass.MONSTER, "species": 0,
	"length_m": 7.0, "speed": 1.3, "accel": 0.7, "turn": 0.55,
	"bite_reach_m": 3.5, "bite_radius_m": 1.6, "bite_wind": 0.75, "bite_every": 2.0,
	"capacity": 4.0, "cam": Vector2(1.0, 1.0),
	"attack": "chomp", "open_s": 0.12, "charge_s": 1.2,
}

## The form a Hunter falls back to when the one picked is not ready.
const FALLBACK := "drowned_shark"


static func has(key: String) -> bool:
	return FORMS.has(key)


## Whether `key` is a registered form that reports ready.
static func is_ready(key: String) -> bool:
	return FORMS.has(key) and bool((FORMS[key] as GDScript).call("ready"))


## The registered forms that report ready, in card order.
static func ready_keys() -> Array[String]:
	var out: Array[String] = []
	for key in KEYS:
		if is_ready(key):
			out.append(key)
	return out


## `key` if it can be played, else the fallback form.
static func playable(key: String) -> String:
	return key if is_ready(key) else FALLBACK


## The sheet for `key` with every key filled in, plus "key" and "ready". An unknown key gives the fallback's.
static func sheet(key: String) -> Dictionary:
	if not FORMS.has(key):
		key = FALLBACK
	var out := DEFAULTS.duplicate()
	out.merge((FORMS[key] as GDScript).call("sheet") as Dictionary, true)
	out["key"] = key
	out["ready"] = is_ready(key)
	return out


## The form's name as the card shows it.
static func name_of(key: String) -> String:
	return str(sheet(key)["name"])


## Runs the form's dress hook on `fish` (a Hunter whose look and size are set).
static func dress(fish: FishController, key: String) -> void:
	if FORMS.has(key):
		(FORMS[key] as GDScript).call("dress", fish, sheet(key))
