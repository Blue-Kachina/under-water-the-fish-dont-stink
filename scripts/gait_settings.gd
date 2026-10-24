class_name GaitSettings
extends Resource
## Every class's Gait, shown in the tuning panel's GAITS section (a heading per
## class) and saved with presets ([gaits]). One shared copy (shared()) is what
## the panel edits and every fish reads, live: a FishController holds its
## class's Gait, so a change takes effect on the next tick.
##
## The options are each Gait export once per class, named "<class key>_<gait
## export>" (e.g. "drifter_coast_drag"), made here rather than written out
## (_get_property_list). Their descriptions come from gait.gd's comments
## (tools/gen_setting_docs.gd).

static var _shared: GaitSettings
static var _field_names: Array[String] = []
## Whether a Fish Sticks mode (Free Play, 1v1) is being played now: main.gd
## sets it as the mode changes. With in_fish_sticks off, every class swims with
## the plain lateral gait while it's set.
static var fish_sticks_now := false
static var _plain: Gait

## Whether the classes' gaits apply in Fish Sticks too. Off: every class swims
## there with the plain lateral fish gait, as before gaits (the other modes
## keep theirs).
@export var in_fish_sticks := true

## FishCharacter.FishClass -> its Gait.
var gaits := {}


## The copy the panel edits and the fish read.
static func shared() -> GaitSettings:
	if _shared == null:
		_shared = GaitSettings.new()
	return _shared


func _init() -> void:
	for fish_class: FishCharacter.FishClass in FishCharacter.FishClass.values():
		gaits[fish_class] = default_for(fish_class)


## `fish_class`'s gait.
func for_class(fish_class: FishCharacter.FishClass) -> Gait:
	return gaits[fish_class]


## The gait `fish_class` swims with now: its own, or the plain lateral one in
## Fish Sticks with in_fish_sticks off.
func active_for(fish_class: FishCharacter.FishClass) -> Gait:
	if fish_sticks_now and not in_fish_sticks:
		if _plain == null:
			_plain = Gait.new()
		return _plain
	return gaits[fish_class]


## A class's gait before any tuning. Every class has today's lateral gait
## until its phase gives it its own (big_changes.md §7).
static func default_for(fish_class: FishCharacter.FishClass) -> Gait:
	var gait := Gait.new()
	if fish_class == FishCharacter.FishClass.ALCHEMIST:
		# The sea hare's flap: slow, heavy wingbeats that lift, and it hangs
		# where it stops (a lot of drag between beats, sinking a little).
		gait.stroke_axis = Gait.StrokeAxis.FLAP
		gait.visual = Gait.Visual.FLAP
		gait.stroke_time = 1.35
		gait.stroke_power = 0.85
		gait.coast_drag = 1.8
		gait.coast_buoyancy = -1.0
	elif fish_class == FishCharacter.FishClass.DRIFTER:
		# The jellies' tilt and pulse: the bell hangs upright and sinks slowly
		# at rest, leans bell-first as it swims, and each stride is a short,
		# hard squeeze along it followed by a draggy coast (big_changes.md §6).
		gait.stroke_axis = Gait.StrokeAxis.RADIAL
		gait.push_axis = Gait.PushAxis.BELL
		gait.visual = Gait.Visual.BELL_PULSE
		gait.stroke_time = 0.8
		gait.stroke_power = 0.8
		gait.coast_drag = 1.8
		gait.coast_buoyancy = -2.0
	elif fish_class == FishCharacter.FishClass.BREACHER:
		# The whales' flukes: up-and-down strokes at a fish's timing and push, so
		# they keep the Gliders' pace on the same hitbox (any sweep counts, D3).
		# A slower stroke_time cost ~15% of the distance in gait_probe.
		gait.stroke_axis = Gait.StrokeAxis.VERTICAL
		gait.visual = Gait.Visual.FLUKE
	return gait


## The Gait exports the panel shows: ranges and bools, and enums with more than
## one value (an enum with one is nothing to choose yet).
static func gait_properties() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for property in Gait.new().get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_EDITOR):
			continue
		if property.hint == PROPERTY_HINT_ENUM and property.hint_string.split(",").size() < 2:
			continue
		result.append(property)
	return result


## The option for `fish_class`'s gait export `field`.
static func option_name(fish_class: FishCharacter.FishClass, field: String) -> String:
	return "%s_%s" % [FishCharacter.CLASSES[fish_class]["key"], field]


## The panel's title for option `prop`: the gait export's, without the class
## (its heading names the class).
func option_title(prop: String) -> String:
	var split := _split(prop)
	return String(split[1]).capitalize() if split else prop.capitalize()


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var fields := gait_properties()
	for fish_class: FishCharacter.FishClass in FishCharacter.FishClass.values():
		list.append({"name": FishCharacter.CLASSES[fish_class]["name"], "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		for field in fields:
			var entry: Dictionary = field.duplicate()
			entry["name"] = option_name(fish_class, field.name)
			entry["usage"] = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			list.append(entry)
	return list


func _get(property: StringName) -> Variant:
	var split := _split(property)
	return gaits[split[0]].get(split[1]) if split else null


func _set(property: StringName, value: Variant) -> bool:
	var split := _split(property)
	if split.is_empty():
		return false
	gaits[split[0]].set(split[1], value)
	return true


## Every Gait export's name.
static func _fields() -> Array[String]:
	if _field_names.is_empty():
		for property in Gait.new().get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_field_names.append(property.name)
	return _field_names


## Option `prop` as [class, gait export], or [] if it isn't one.
func _split(prop: String) -> Array:
	for fish_class: FishCharacter.FishClass in gaits:
		var prefix: String = FishCharacter.CLASSES[fish_class]["key"] + "_"
		if prop.begins_with(prefix):
			var field := prop.substr(prefix.length())
			if field in _fields():
				return [fish_class, field]
	return []
