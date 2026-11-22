class_name GreyboxTrack
extends RefCounted
## The Phase 1 placeholder course (planning_race.md phase 1): a stadium loop of about 723 m with a gentle dive and
## climb and two bubble streams, no carving (rings for walls). It has the same data shape the Canyon Reef Circuit
## (canyon_reef_track.gd) will use (see RaceTrack's header), so everything coded against RaceTrack works on both.
## RaceTrack.build(GreyboxTrack.data()) makes the track.

const NAME := "Grey Box"
## Straight length and bend radius (m): 2 x 220 + 2 pi 45 = about 723 m, the Phase 0 lap length.
const STRAIGHT := 220.0
const RADIUS := 45.0


static func data() -> Dictionary:
	var half := STRAIGHT * 0.5
	var pts: Array[Dictionary] = []
	# The right-hand straight (x = +RADIUS), heading -z, the start line at z = 0.
	pts.append(_pt(Vector3(RADIUS, 0.0, 0.0), 28.0, 18.0, 0.0, 0.0, "start"))
	pts.append(_pt(Vector3(RADIUS, 0.0, -half * 0.5), 34.0, 18.0, 0.0, 0.0, "stream"))
	# The far bend, centred at (0, -half): angle 0 to 180.
	for a in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0]:
		var r := deg_to_rad(a)
		pts.append(_pt(Vector3(cos(r) * RADIUS, 0.0, -half - sin(r) * RADIUS), 24.0, 18.0, 10.0, -4.0 if a > 0.0 else 0.0,
				"bend" if a == 90.0 else ""))
	# The left straight, heading +z.
	pts.append(_pt(Vector3(-RADIUS, 0.0, -half), 28.0, 18.0, 0.0, 0.0, ""))
	pts.append(_pt(Vector3(-RADIUS, 0.0, -half * 0.5), 28.0, 18.0, 0.0, 0.0, "climb"))
	pts.append(_pt(Vector3(-RADIUS, 0.0, 0.0), 28.0, 18.0, 0.0, 0.0, ""))
	pts.append(_pt(Vector3(-RADIUS, 0.0, half * 0.5), 28.0, 18.0, 0.0, 0.0, ""))
	# The near bend, centred at (0, +half): angle 180 to 360.
	for a in [180.0, 210.0, 240.0, 270.0, 300.0, 330.0]:
		var r2 := deg_to_rad(a)
		pts.append(_pt(Vector3(cos(r2) * RADIUS, 0.0, half - sin(r2) * RADIUS), 24.0, 18.0, 10.0, -4.0 if a > 180.0 else 0.0,
				"bend" if a == 270.0 else ""))
	pts.append(_pt(Vector3(RADIUS, 0.0, half * 0.5), 28.0, 18.0, 0.0, 0.0, ""))
	for i in pts.size():  # a gentle dive and climb round the lap
		var at: Vector3 = pts[i]["at"]
		at.y = -5.0 * sin(TAU * float(i) / pts.size())
		pts[i]["at"] = at
	var lap := 2.0 * STRAIGHT + TAU * RADIUS
	return {
		"name": NAME,
		"points": pts,
		"streams": [
			{"d0": lap * 0.05, "d1": lap * 0.17, "offset": Vector2(-4.0, 0.0), "radius": 4.0},
			{"d0": lap * 0.55, "d1": lap * 0.67, "offset": Vector2(4.0, 1.0), "radius": 4.0},
		],
		"grid": {"columns": 2, "spacing": 7.0, "stagger": 3.5},
	}


static func _pt(at: Vector3, width: float, height: float, bank: float, line: float, tag: String) -> Dictionary:
	return {"at": at, "width": width, "height": height, "bank": bank, "line": line, "tag": tag}
