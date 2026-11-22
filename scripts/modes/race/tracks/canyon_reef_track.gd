class_name CanyonReefTrack
extends RefCounted
## The Canyon Reef Circuit (planning_race.md section 4, phase 2): a figure-eight of about 740 m with two lobes of three
## 30 m bends, laid out as a turtle path (straights and arcs) and then dressed from keyframe curves along the lap:
##   the start straight (40 m wide), a ridge climb that crosses OVER the tunnel (the figure's crossing), a right lobe with
##   an arch on its first leg and a split round a rock pillar on its second, the tunnel through the mesa (16 m wide,
##   roofed) that the ridge passes over, a left lobe with an overhang dive under a shelf of rock and a narrow neck.
## It returns the dictionary shape RaceTrack.build() takes (see race_track.gd's header). Distances are from the start line.
## Plan view: x east, z south, the start line at (-65, 0) heading east; the two crossings meet at the origin.

const NAME := "Canyon Reef Circuit"
## The bends' centreline radius (m): at race speed the tightest turn wants 12-15 m or more (race_phase0.md).
const BEND := 30.0
## The straights between the bends (m): the start straight and ridge, the arch leg, the split leg, the tunnel leg
## before and after the crossing, the overhang leg and the neck.
const RUN_A := 130.0
const RUN_ARCH := 35.0
const RUN_SPLIT := 35.0
const RUN_B1 := 65.0
const RUN_B2 := 60.0
const RUN_OVERHANG := 70.0
const RUN_NECK := 30.0
const RUN_EXIT := 35.0
## Control points: a straight is cut into pieces of about this length, an arc into steps of this many degrees.
const STRAIGHT_STEP := 11.0
const ARC_STEP := 15.0
## The channel's centre height on the canyon floor and the rock's top (m, local y).
const LEVEL := 28.0
const RIM := 52.0

## Keyframes (distance, value) for the lap, eased between and wrapping at the lap length.
const CENTRE_Y := [[0.0, 28.0], [35.0, 28.0], [65.0, 44.0], [100.0, 28.0], [346.0, 28.0], [366.0, 14.0], [446.0, 14.0],
		[466.0, 28.0], [520.0, 28.0], [540.0, 17.0], [558.0, 17.0], [580.0, 28.0]]
const WIDTH := [[0.0, 40.0], [28.0, 40.0], [52.0, 26.0], [240.0, 26.0], [262.0, 38.0], [292.0, 38.0], [312.0, 26.0],
		[350.0, 26.0], [366.0, 16.0], [446.0, 16.0], [466.0, 26.0], [515.0, 26.0], [530.0, 20.0], [560.0, 20.0],
		[575.0, 26.0], [620.0, 26.0], [632.0, 16.0], [658.0, 16.0], [672.0, 26.0], [705.0, 26.0], [715.0, 40.0]]
const HEIGHT := [[0.0, 22.0], [50.0, 22.0], [62.0, 16.0], [78.0, 16.0], [92.0, 22.0], [350.0, 22.0], [366.0, 13.0],
		[446.0, 13.0], [466.0, 22.0], [520.0, 22.0], [532.0, 12.0], [558.0, 12.0], [572.0, 22.0]]
## The split's pillar: it fills the channel's middle for this long (m), centred on the split leg.
const PILLAR_SPAN := 24.0
## The roofed spans: the tunnel and the overhang.
const ROOFS := [[368.0, 444.0], [534.0, 556.0]]
## Streams: [d0, d1, sideways offset (+ right), height offset, radius].
const STREAMS := [[8.0, 48.0, -6.0, 0.0, 4.5], [30.0, 70.0, 0.0, 1.0, 4.0], [446.0, 484.0, 0.0, 0.0, 4.0],
		[264.0, 290.0, -11.0, 0.0, 4.0]]
## The split: the racing line takes the right lane, from this span, this far from the middle (m).
const SPLIT_SPAN := [245.0, 305.0]
const SPLIT_LANE := 11.0
## Racing line offset into the bends (m): the inside of each, eased in and out.
const BEND_LINE := 5.0


static func data() -> Dictionary:
	return _make()["data"]


## The feature distances (lap, m) for tools and the layout: {name: d} (a repeated tag keeps its first).
static func features() -> Dictionary:
	return _make()["features"]


## The track dictionary and the feature distances. The layout is authored in plan distance along the turtle's path (the
## tables above), but the track's own distance is the 3D length (climbs and dives add some), so every authored span is
## converted to the track's distance through where each control point really lands on it.
static func _make() -> Dictionary:
	var path := _path()
	var lap: float = path["length"]
	var marks: Dictionary = path["marks"]
	var pts: Array[Dictionary] = []
	var tags := _tags(marks)
	var tagged := {}
	for tag: Array in tags:  # each tag lands on the control point nearest its distance
		var best := 0
		var best_gap := INF
		for i in path["d"].size():
			var gap := absf(float(path["d"][i]) - float(tag[0]))
			if gap < best_gap:
				best_gap = gap
				best = i
		tagged[best] = tag[1]
	for i in path["d"].size():
		var d: float = path["d"][i]
		var xz: Vector2 = path["xz"][i]
		var line := float(path["bend"][i]) * BEND_LINE
		var span := _hump(d, SPLIT_SPAN[0], SPLIT_SPAN[1], 14.0)
		line = lerpf(line, SPLIT_LANE, span)
		pts.append({"at": Vector3(xz.x, _curve(CENTRE_Y, d, lap), xz.y), "width": _curve(WIDTH, d, lap),
				"height": _curve(HEIGHT, d, lap), "bank": 0.0, "line": line, "tag": tagged.get(i, "")})
	var probe := RaceTrack.build({"name": NAME, "points": pts})
	var track_d := PackedFloat64Array()
	var prev := 0.0
	for i in pts.size():
		var here := 0.0 if i == 0 else maxf(probe.nearest(pts[i]["at"]).d, prev)
		track_d.append(here)
		prev = here
	var conv := func(plan_d: float) -> float:
		var dd := clampf(plan_d, 0.0, lap)
		var list: Array = path["d"]
		var k := 0
		while k + 1 < list.size() and float(list[k + 1]) <= dd:
			k += 1
		var d0 := float(list[k])
		var d1 := float(list[k + 1]) if k + 1 < list.size() else lap
		var t0 := track_d[k]
		var t1 := track_d[k + 1] if k + 1 < list.size() else probe.lap_length
		return lerpf(t0, t1, clampf((dd - d0) / maxf(d1 - d0, 0.001), 0.0, 1.0))
	var streams: Array[Dictionary] = []
	for s: Array in STREAMS:
		streams.append({"d0": conv.call(float(s[0])), "d1": conv.call(float(s[1])), "offset": Vector2(s[2], s[3]), "radius": s[4]})
	var roofs: Array[Dictionary] = []
	for r: Array in ROOFS:
		roofs.append({"d0": conv.call(float(r[0])), "d1": conv.call(float(r[1]))})
	var mid := (float(marks["h_start"]) + float(marks["h_end"])) * 0.5
	var solids: Array[Dictionary] = [{"d0": conv.call(mid - PILLAR_SPAN * 0.5), "d1": conv.call(mid + PILLAR_SPAN * 0.5)}]
	var features := {}
	for tag: Array in tags:
		if not features.has(tag[1]):
			features[tag[1]] = conv.call(float(tag[0]))
	var data := {"name": NAME, "points": pts, "streams": streams, "roofs": roofs, "solids": solids,
			"grid": {"columns": 3, "spacing": 7.0, "stagger": 3.5}}
	return {"data": data, "features": features}


## [distance, tag] for every tagged control point (a tag may repeat: "bend", "stream").
static func _tags(marks: Dictionary) -> Array:
	var o_a := 65.0  # the ridge crest, over the tunnel
	var o_b: float = marks["B1_end"]
	return [[0.0, "start"], [20.0, "stream"], [45.0, "climb"], [o_a, "crest"], [marks["bend1_mid"], "bend"],
			[(float(marks["g_start"]) + float(marks["g_end"])) * 0.5, "arch"], [marks["bend2_mid"], "bend"],
			[(float(marks["h_start"]) + float(marks["h_end"])) * 0.5 - PILLAR_SPAN * 0.5 - 6.0, "split"], [marks["bend3_mid"], "bend"],
			[o_b - 30.0, "tunnel"], [o_b, "tunnel"], [o_b + 30.0, "tunnel"], [marks["bendL1_mid"], "bend"],
			[540.0, "dive"], [marks["bendL2_mid"], "bend"], [645.0, "neck"], [marks["bendL3_mid"], "bend"]]


## The turtle: a pen that walks straights and arcs from the start line, recording a control point at every step.
class Turtle extends RefCounted:
	var d_list: Array[float] = []
	var xz_list: Array[Vector2] = []
	var bend_list: Array[float] = []
	var marks := {}
	var pos := Vector2(-65.0, 0.0)
	var heading := 0.0  # radians, (cos, sin) in (x, z): z is south, so + turns right
	var d := 0.0

	func straight(length: float) -> void:
		var pieces := maxi(roundi(length / STRAIGHT_STEP), 1)
		var dir := Vector2.from_angle(heading)
		for i in pieces:
			d_list.append(d + length * i / pieces)
			xz_list.append(pos + dir * (length * i / pieces))
			bend_list.append(0.0)
		pos += dir * length
		d += length

	func arc(turn_deg: float, name: String) -> void:
		var sign_turn := signf(turn_deg)
		var normal := Vector2.from_angle(heading + sign_turn * PI * 0.5)  # toward the centre
		var centre := pos + normal * BEND
		var steps := maxi(roundi(absf(turn_deg) / ARC_STEP), 1)
		var from_angle := (pos - centre).angle()
		var sweep := deg_to_rad(absf(turn_deg))
		var length := sweep * BEND
		for i in steps:
			var t := float(i) / steps
			d_list.append(d + length * t)
			xz_list.append(centre + Vector2.from_angle(from_angle + sign_turn * sweep * t) * BEND)
			bend_list.append(sign_turn * sin(PI * t))
		marks[name + "_mid"] = d + length * 0.5
		pos = centre + Vector2.from_angle(from_angle + sign_turn * sweep) * BEND
		heading += sign_turn * sweep
		d += length


## The path from the start line: parallel arrays of distance, plan position (x, z) and bend weight (-1..1: the racing
## line's lean, + into a right-hander), plus the lap length and named distances.
static func _path() -> Dictionary:
	var t := Turtle.new()
	t.straight(RUN_A)
	t.arc(90.0, "bend1")
	t.marks["g_start"] = t.d
	t.straight(RUN_ARCH)
	t.marks["g_end"] = t.d
	t.arc(90.0, "bend2")
	t.marks["h_start"] = t.d
	t.straight(RUN_SPLIT)
	t.marks["h_end"] = t.d
	t.arc(90.0, "bend3")
	t.straight(RUN_B1)
	t.marks["B1_end"] = t.d  # the crossing under the ridge
	t.straight(RUN_B2)
	t.arc(-90.0, "bendL1")
	t.straight(RUN_OVERHANG)
	t.arc(-90.0, "bendL2")
	t.straight(RUN_NECK)
	t.arc(-90.0, "bendL3")
	t.straight(RUN_EXIT)
	return {"d": t.d_list, "xz": t.xz_list, "bend": t.bend_list, "marks": t.marks, "length": t.d, "end": t.pos}


## A keyframe curve at `d` (smoothstep between keys, wrapping at `lap`).
static func _curve(keys: Array, d: float, lap: float) -> float:
	var dd := fposmod(d, lap)
	var n := keys.size()
	var first: Array = keys[0]
	var last: Array = keys[n - 1]
	if dd < float(first[0]):
		return _ease_between(last, first, dd + lap, lap)
	if dd >= float(last[0]):
		return _ease_between(last, first, dd, lap)
	for i in n - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if dd >= float(a[0]) and dd < float(b[0]):
			return _ease_between(a, b, dd, lap)
	return float(last[1])


static func _ease_between(a: Array, b: Array, d: float, lap: float) -> float:
	var d0 := float(a[0])
	var d1 := float(b[0])
	if d1 <= d0:
		d1 += lap
	var t := clampf((d - d0) / maxf(d1 - d0, 0.001), 0.0, 1.0)
	return lerpf(float(a[1]), float(b[1]), t * t * (3.0 - 2.0 * t))


## 1 inside [d0, d1], easing to 0 over `fade` m outside it.
static func _hump(d: float, d0: float, d1: float, fade: float) -> float:
	if d >= d0 and d <= d1:
		return 1.0
	var gap := d0 - d if d < d0 else d - d1
	return clampf(1.0 - gap / fade, 0.0, 1.0)
