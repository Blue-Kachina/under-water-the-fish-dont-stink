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
		# The calf's rig: cetaceans beat up and down (rig_wave_axis 1), slowly and heavily, the wave starting far
		# forward and growing to the flukes, the head nodding against it, the flippers steering and banking.
		_rig_defaults(gait, {
			"rig_wave_axis": 1.0, "rig_amplitude": 0.5, "rig_wave_lag": 1.1, "rig_strouhal": 0.03, "rig_freq_min": 0.4,
			"rig_freq_max": 1.8, "rig_envelope": 1.2, "rig_head_sway": 0.2, "rig_caudal_flex": 0.7, "rig_caudal_lead": 12.0,
			"rig_head_span": 0.15, "rig_stride_swing": 0.5, "rig_turn_bend": 3.5, "rig_turn_max": 0.5, "rig_bank": 0.4,
			"rig_fin_bank": 0.35, "rig_accel_tail": 0.25, "rig_accel_surge": 0.02, "rig_fin_flutter": 0.06,
			"rig_idle_scull": 0.1, "rig_idle_sway": 0.05, "rig_idle_hz": 0.35,
		})
	elif fish_class == FishCharacter.FishClass.TITAN:
		# The adult whales (planning_marco_whales.md §7): the calves' up-and-down
		# flukes, slower (a long, heavy beat), with the Titan-only motion values
		# at their defaults (multi-joint wave, power/recovery strokes, the head's
		# counter-pitch, surge, flipper trim, bank).
		gait.stroke_axis = Gait.StrokeAxis.VERTICAL
		gait.visual = Gait.Visual.FLUKE
		gait.stroke_time = 1.4
	elif fish_class == FishCharacter.FishClass.HUNTER or fish_class == FishCharacter.FishClass.MONSTER:
		# The shark's procedural rig (SwimRig) is built but off (procedural_rig): when it is switched on the
		# layers run at full weight and the controller's own tail pose gives way to them. The Drowned Shark
		# (the Hunter form, class MONSTER) wears the same shark model, so it takes the shark's numbers.
		_rig_defaults(gait, {})
	elif fish_class == FishCharacter.FishClass.SKIRMISHER:
		# The clownfish: a short, deep body that waves from the rear half with a quick, busy tail, rows itself
		# with its pectorals (more flutter, a fuller scull at rest), and turns tighter and flatter than a shark.
		_rig_defaults(gait, {
			"rig_amplitude": 0.9, "rig_wave_lag": 1.3, "rig_strouhal": 0.05, "rig_freq_min": 0.8, "rig_freq_max": 5.0,
			"rig_head_sway": 0.4, "rig_caudal_flex": 0.7, "rig_head_span": 0.2, "rig_stride_swing": 0.8,
			"rig_turn_bend": 5.0, "rig_turn_max": 1.0, "rig_bank": 0.25, "rig_fin_bank": 0.35,
			"rig_accel_tail": 0.4, "rig_accel_surge": 0.02, "rig_fin_flutter": 0.14, "rig_fin_flutter_hz": 9.0,
			"rig_idle_scull": 0.4, "rig_idle_sway": 0.18, "rig_idle_hz": 1.1,
		})
	elif fish_class == FishCharacter.FishClass.LANCER:
		# The swordfish: a stiff, tuna-shaped swimmer. The bill and head stay rigid, the wave is small, fast
		# and held at the tail (the stalk and the lunate fin do the work), and it banks little.
		_rig_defaults(gait, {
			"rig_amplitude": 0.4, "rig_wave_lag": 0.8, "rig_strouhal": 0.05, "rig_freq_min": 0.6, "rig_freq_max": 3.0,
			"rig_envelope": 1.4, "rig_head_sway": 0.1, "rig_caudal_flex": 0.9, "rig_head_span": 0.1,
			"rig_stride_swing": 0.45, "rig_turn_bend": 3.0, "rig_turn_max": 0.5, "rig_bank": 0.3, "rig_fin_bank": 0.3,
			"rig_accel_tail": 0.3, "rig_accel_head": 0.1, "rig_accel_surge": 0.02, "rig_fin_flutter": 0.04,
			"rig_idle_scull": 0.15, "rig_idle_sway": 0.08, "rig_idle_hz": 0.5,
		})
	elif fish_class == FishCharacter.FishClass.CHARMER:
		# The koi: a carp's easy sub-carangiform swim. A supple body that waves from mid-body back with a small
		# head sway, a broad caudal that follows the stalk, and long pectorals that bank and scull at rest.
		_rig_defaults(gait, {
			"rig_amplitude": 0.75, "rig_wave_lag": 1.1, "rig_strouhal": 0.05, "rig_freq_min": 0.5, "rig_freq_max": 3.0,
			"rig_head_sway": 0.3, "rig_caudal_flex": 0.6, "rig_head_span": 0.2, "rig_stride_swing": 0.6,
			"rig_turn_bend": 5.0, "rig_turn_max": 0.9, "rig_bank": 0.3, "rig_fin_bank": 0.45,
			"rig_accel_tail": 0.4, "rig_accel_surge": 0.02, "rig_fin_flutter": 0.1, "rig_fin_flutter_hz": 7.0,
			"rig_idle_scull": 0.3, "rig_idle_sway": 0.15, "rig_idle_hz": 0.8,
		})
	elif fish_class == FishCharacter.FishClass.BULWARK:
		# The boxfish: a rigid shell that cannot bend (ostraciiform swimming). Only the short tail stalk swings, as one
		# piece and fast, the fan flapping past it; the head never sways and it hardly banks. The pectorals row hard.
		_rig_defaults(gait, {
			"rig_amplitude": 0.7, "rig_wave_lag": 0.5, "rig_strouhal": 0.08, "rig_freq_min": 1.0, "rig_freq_max": 4.5,
			"rig_envelope": 1.6, "rig_head_sway": 0.0, "rig_caudal_flex": 1.2, "rig_caudal_lead": 15.0, "rig_head_span": 0.0,
			"rig_stride_swing": 0.5, "rig_turn_bend": 1.5, "rig_turn_max": 0.3, "rig_bank": 0.15, "rig_fin_bank": 0.5,
			"rig_accel_tail": 0.2, "rig_accel_head": 0.0, "rig_accel_surge": 0.0, "rig_fin_flutter": 0.25, "rig_fin_flutter_hz": 12.0,
			"rig_idle_scull": 0.5, "rig_idle_sway": 0.03, "rig_idle_hz": 1.6,
		})
	elif fish_class == FishCharacter.FishClass.SCORCHER:
		# The lionfish: a slow, hovering ambusher. The wave is small and held in the rear of the body, the head quiet,
		# the big pectoral fans lazily fluttering, and a gentle scull at rest.
		_rig_defaults(gait, {
			"rig_amplitude": 0.45, "rig_wave_lag": 0.9, "rig_strouhal": 0.04, "rig_freq_min": 0.5, "rig_freq_max": 2.5,
			"rig_envelope": 1.2, "rig_head_sway": 0.15, "rig_caudal_flex": 0.7, "rig_head_span": 0.1, "rig_stride_swing": 0.5,
			"rig_turn_bend": 4.0, "rig_turn_max": 0.7, "rig_bank": 0.2, "rig_fin_bank": 0.3,
			"rig_accel_tail": 0.25, "rig_accel_surge": 0.015, "rig_fin_flutter": 0.12, "rig_fin_flutter_hz": 5.0,
			"rig_idle_scull": 0.35, "rig_idle_sway": 0.1, "rig_idle_hz": 0.6,
		})
	elif fish_class == FishCharacter.FishClass.GLIDER:
		# The ray: its body doesn't bend (no spine chain); the wings and the whip carry the motion. The wave's joints sum
		# onto the tail pivot, so they lash the whip (a slow, small wave, no head); the Wing beat layer flaps the wings on
		# the same wave and beats them with strides (the old _beat_wings), and the Turn layer banks it hard, like a bird.
		_rig_defaults(gait, {
			"rig_amplitude": 0.35, "rig_wave_lag": 0.9, "rig_strouhal": 0.03, "rig_freq_min": 0.4, "rig_freq_max": 2.0,
			"rig_envelope": 0.6, "rig_head_sway": 0.0, "rig_caudal_flex": 0.5, "rig_head_span": 0.0, "rig_stride_swing": 0.5,
			"rig_turn_bend": 2.0, "rig_turn_max": 0.4, "rig_bank": 0.45, "rig_fin_bank": 0.1, "rig_fin_tuck": 0.05,
			"rig_accel_tail": 0.3, "rig_accel_head": 0.0, "rig_accel_fins": 0.25, "rig_accel_surge": 0.0,
			"rig_drift_bend": 0.6, "rig_drift_fins": 0.3, "rig_fin_flutter": 0.05, "rig_fin_flutter_hz": 3.0,
			"rig_idle_scull": 0.12, "rig_idle_sway": 0.1, "rig_idle_hz": 0.5, "rig_wing_beat": 1.0,
		})
	elif fish_class == FishCharacter.FishClass.BRAWLER:
		# The mantis shrimp: an armoured body whose abdomen flexes up and down (rig_wave_axis 1) as its swimmerets beat,
		# quick and small, the head and carapace nearly still; the raptorial claws on the fin pivots barely move (no
		# flutter, a small tuck in turns and a twitch at rest).
		_rig_defaults(gait, {
			"rig_wave_axis": 1.0, "rig_amplitude": 0.4, "rig_wave_lag": 0.8, "rig_strouhal": 0.05, "rig_freq_min": 0.8,
			"rig_freq_max": 4.0, "rig_head_sway": 0.1, "rig_caudal_flex": 0.8, "rig_head_span": 0.1, "rig_stride_swing": 0.5,
			"rig_turn_bend": 3.0, "rig_turn_max": 0.5, "rig_bank": 0.2, "rig_fin_bank": 0.15, "rig_fin_tuck": 0.15,
			"rig_accel_tail": 0.35, "rig_accel_head": 0.05, "rig_accel_fins": 0.15, "rig_accel_surge": 0.01,
			"rig_drift_fins": 0.2, "rig_fin_flutter": 0.0, "rig_idle_scull": 0.08, "rig_idle_sway": 0.06, "rig_idle_hz": 0.9,
		})
	return gait


## `gait`'s rig set up for a class: every layer at full weight, the controller's own tail pose given up, and the class's
## own numbers (`own`: Gait field -> value) over the shark's defaults. procedural_rig stays off.
static func _rig_defaults(gait: Gait, own: Dictionary) -> void:
	gait.rig_legacy_tail = 0.0
	for layer in ["rig_undulation", "rig_tail_drive", "rig_turn", "rig_accel", "rig_drift", "rig_fin_stabilizer", "rig_idle"]:
		gait.set(layer, 1.0)
	for field: String in own:
		gait.set(field, own[field])


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
