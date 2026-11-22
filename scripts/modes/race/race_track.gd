class_name RaceTrack
extends RefCounted
## The race course as data (planning_race.md section 4): a closed loop of centreline points, smoothed, with a width,
## height, bank and racing-line offset at every point, ordered checkpoints, grid slots and bubble stream spans.
## Built from a plain Dictionary (RaceTrack.build) so a track script (tracks/*.gd, `static func data()`) is just data:
##   {"name": String,
##    "points": [{"at": Vector3, "width": m, "height": m, "bank": degrees, "line": m, "tag": String}, ...],
##    "streams": [{"d0": m, "d1": m, "offset": Vector2 (right, up), "radius": m}, ...],
##    "roofs": [{"d0": m, "d1": m}, ...],
##    "solids": [{"d0": m, "d1": m}, ...],
##    "grid": {"columns": 2, "spacing": 7.0, "stagger": 3.5}}   (grid, streams, roofs and solids optional)
## `solids` are spans where rock stands in the middle of the channel (the split's pillar): the centreline is blocked
## there (racers pass either side on the racing line), so no checkpoint is placed in or within 10 m of one. `roofs` are the spans where the channel is roofed (a tunnel, an overhang): everywhere else it's an open-topped canyon
## (d1 < d0 wraps over the start line). `line` is the racing line's sideways offset from the centreline at that point (+ right, m). `tag` marks a feature
## ("start", "bend", "arch", "tunnel", "dive", "climb", "split", "stream", ...): the first point is the start line and
## each tagged point gets a checkpoint. Everything is in the world's space; d wraps at lap_length.
##
## Distances are along the centreline in metres. The frame at d: position, forward (unit), right and up (unit, banked).
## The track is sampled every STEP m into arrays, so sample() and nearest() are cheap.

## One fix on the track: a frame at distance `d`, plus where a world point sits against it (nearest() only).
class Fix extends RefCounted:
	var d := 0.0
	var pos := Vector3.ZERO
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	var up := Vector3.UP
	var width := 20.0
	var height := 15.0
	var tag := ""
	## nearest() only: the point's sideways offset from the centreline (+ right, m), its offset along the frame's up
	## (m) and its straight distance to the centreline point (m).
	var lateral := 0.0
	var vertical := 0.0
	var distance := 0.0

	## True while the point is inside the channel's elliptical cross-section (width x height), scaled by `margin`.
	func inside(margin := 1.0) -> bool:
		var a := width * 0.5 * margin
		var b := height * 0.5 * margin
		return (lateral * lateral) / (a * a) + (vertical * vertical) / (b * b) <= 1.0


## Distance between samples (m).
const STEP := 1.0
## Checkpoint spacing along the lap (m), besides one at every tagged point.
const CHECKPOINT_SPACING := 25.0
## nearest()'s default search window each side of the hint (m).
const WINDOW := 40.0

var track_name := ""
## The authored points (see the file header).
var points: Array[Dictionary] = []
## Total centreline length (m): one lap (a whole number of STEPs, so the loop closes exactly).
var lap_length := 0.0
## Checkpoints in order: {"d", "pos", "forward", "right", "up", "width", "height", "tag"}. Index 0 is the start line.
var checkpoints: Array[Dictionary] = []
## Bubble stream spans: {"d0", "d1", "offset": Vector2, "radius"}; d1 < d0 wraps over the start line.
var streams: Array[Dictionary] = []
## Roofed spans: {"d0", "d1"}. Outside them the channel is open to the sky above its middle.
var roofs: Array[Dictionary] = []
## Spans where rock fills the channel's middle: {"d0", "d1"}. No checkpoints inside them.
var solids: Array[Dictionary] = []
var grid_columns := 2
var grid_spacing := 7.0
var grid_stagger := 3.5

var _pos := PackedVector3Array()
var _fwd := PackedVector3Array()
var _right := PackedVector3Array()
var _up := PackedVector3Array()
var _width := PackedFloat32Array()
var _height := PackedFloat32Array()
var _line := PackedFloat32Array()
var _tags: Array[String] = []


## The track for `data` (the shape in the file header). Null when it has under 4 points.
static func build(data: Dictionary) -> RaceTrack:
	var track := RaceTrack.new()
	return track if track._build(data) else null


## The number of samples round the loop.
func count() -> int:
	return _pos.size()


## The frame at distance `d` (wraps, interpolated between samples).
func sample(d: float) -> Fix:
	var n := _pos.size()
	var f := fposmod(d, lap_length) / STEP
	var i := int(f) % n
	var j := (i + 1) % n
	var t := f - floorf(f)
	var fix := Fix.new()
	fix.d = fposmod(d, lap_length)
	fix.pos = _pos[i].lerp(_pos[j], t)
	fix.forward = _fwd[i].lerp(_fwd[j], t).normalized()
	fix.right = _right[i].lerp(_right[j], t).normalized()
	fix.up = _up[i].lerp(_up[j], t).normalized()
	fix.width = lerpf(_width[i], _width[j], t)
	fix.height = lerpf(_height[i], _height[j], t)
	fix.tag = _tags[i]
	return fix


## Where `p` is on the track: searches `window` m each side of `hint_d` (so progress stays monotonic and the loop
## never snaps across itself); a negative `hint_d` searches the whole loop. The Fix carries lateral and vertical.
func nearest(p: Vector3, hint_d := -1.0, window := WINDOW) -> Fix:
	var n := _pos.size()
	var first := 0
	var last := n - 1
	if hint_d >= 0.0:
		var c := int(fposmod(hint_d, lap_length) / STEP)
		first = c - int(window / STEP)
		last = c + int(window / STEP)
	var best := 0
	var best_d2 := INF
	for k in range(first, last + 1):
		var i := posmod(k, n)
		var d2 := p.distance_squared_to(_pos[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	var along := (p - _pos[best]).dot(_fwd[best])  # refine along the tangent
	var fix := sample(float(best) * STEP + clampf(along, -STEP, STEP))
	var rel := p - fix.pos
	fix.lateral = rel.dot(fix.right)
	fix.vertical = rel.dot(fix.up)
	fix.distance = rel.length()
	return fix


## The racing line's world position at `d` (the centreline plus the line offset along the frame's right).
func racing_line(d: float) -> Vector3:
	var fix := sample(d)
	return fix.pos + fix.right * line_offset(d)


## The sideways racing-line offset at `d` (+ right, m).
func line_offset(d: float) -> float:
	var f := fposmod(d, lap_length) / STEP
	var i := int(f) % _pos.size()
	return lerpf(_line[i], _line[(i + 1) % _pos.size()], f - floorf(f))


## Signed progress from `from_d` to `to_d` the short way round (m): + when `to_d` is ahead.
func delta(from_d: float, to_d: float) -> float:
	return wrapf(to_d - from_d, -lap_length * 0.5, lap_length * 0.5)


## The grid: `count` start slots as {"xform": Transform3D (facing along the track), "d", "lateral"}, in rows behind the
## start line (d = 0). Slot 0 is the pole (front row), 1 the other side of it, then the next row, staggered.
func grid_slots(slots: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in slots:
		var row := s / grid_columns
		var col := s % grid_columns
		var d := -(float(row) * grid_spacing + (grid_stagger if col % 2 == 1 else 0.0)) - 2.0
		var fix := sample(d)
		var side := (float(col) - (grid_columns - 1) * 0.5) * minf(fix.width / maxf(grid_columns + 1, 1), 7.0)
		var at := fix.pos + fix.right * side
		out.append({"xform": Transform3D(Basis(fix.right, fix.up, -fix.forward), at), "d": fix.d, "lateral": side})
	return out


## Whether the channel is roofed at distance `d` (a tunnel or an overhang).
func roofed(d: float) -> bool:
	return _in_spans(roofs, d)


func _in_spans(spans: Array[Dictionary], d: float) -> bool:
	var dd := fposmod(d, lap_length)
	for r in spans:
		var d0 := float(r["d0"])
		var d1 := float(r["d1"])
		if (d0 <= d1 and dd >= d0 and dd <= d1) or (d0 > d1 and (dd >= d0 or dd <= d1)):
			return true
	return false


## Whether rock stands on the centreline at distance `d` (the split's pillar).
func solid_at(d: float) -> bool:
	return _in_spans(solids, d)


## Whether the nearest() fix `fix` is inside the channel's reach (`margin` scales it): within the width, and in the
## channel's height below the middle and, under a roof, above it too. An open canyon has no top.
func in_reach(fix: Fix, margin := 1.0) -> bool:
	if fix.vertical > 0.0 and not roofed(fix.d):
		return absf(fix.lateral) <= fix.width * 0.5 * margin
	return fix.inside(margin)


## The bubble streams covering distance `d` (indexes into `streams`).
func streams_at(d: float) -> Array[int]:
	var out: Array[int] = []
	var dd := fposmod(d, lap_length)
	for i in streams.size():
		var d0 := float(streams[i]["d0"])
		var d1 := float(streams[i]["d1"])
		if (d0 <= d1 and dd >= d0 and dd <= d1) or (d0 > d1 and (dd >= d0 or dd <= d1)):
			out.append(i)
	return out


## The index of the last checkpoint at or before distance `d`.
func checkpoint_before(d: float) -> int:
	var dd := fposmod(d, lap_length)
	var idx := 0
	for i in checkpoints.size():
		if float(checkpoints[i]["d"]) <= dd:
			idx = i
	return idx


## Lap (0-based) and distance `d` as one monotonic number (m).
func progress(lap: int, d: float) -> float:
	return float(lap) * lap_length + d


func _build(data: Dictionary) -> bool:
	track_name = str(data.get("name", ""))
	for p: Dictionary in data.get("points", []):
		points.append(p)
	if points.size() < 4:
		return false
	var grid: Dictionary = data.get("grid", {})
	grid_columns = maxi(int(grid.get("columns", 2)), 1)
	grid_spacing = float(grid.get("spacing", 7.0))
	grid_stagger = float(grid.get("stagger", 3.5))
	for s: Dictionary in data.get("streams", []):
		streams.append(s)
	for r: Dictionary in data.get("roofs", []):
		roofs.append(r)
	for r: Dictionary in data.get("solids", []):
		solids.append(r)
	_smooth()
	_checkpoints()
	return true


## Catmull-Rom through the points (closed), resampled every STEP m by arc length, with the per-point values eased
## between neighbours, frames from a rotation-minimising up plus the bank.
func _smooth() -> void:
	var m := points.size()
	var sub := 24
	var dense := PackedVector3Array()
	var dense_i := PackedFloat32Array()  # the fractional point index each dense sample came from
	for a in m:
		var p0: Vector3 = points[(a - 1 + m) % m]["at"]
		var p1: Vector3 = points[a]["at"]
		var p2: Vector3 = points[(a + 1) % m]["at"]
		var p3: Vector3 = points[(a + 2) % m]["at"]
		for s in sub:
			var t := float(s) / sub
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
			dense_i.append(float(a) + t)
	var dn := dense.size()
	var cum := PackedFloat32Array()
	cum.append(0.0)
	var total := 0.0
	for k in dn:
		total += dense[k].distance_to(dense[(k + 1) % dn])
		cum.append(total)
	var n := maxi(int(round(total / STEP)), 8)
	lap_length = float(n) * STEP
	var k := 0
	for i in n:
		var target := total * float(i) / n
		while k < dn - 1 and cum[k + 1] < target:
			k += 1
		var span := maxf(cum[k + 1] - cum[k], 0.0001)
		var t := clampf((target - cum[k]) / span, 0.0, 1.0)
		_pos.append(dense[k].lerp(dense[(k + 1) % dn], t))
		var next_i := dense_i[k + 1] if k + 1 < dn else float(m)
		var pi := lerpf(dense_i[k], next_i, t)
		var a := int(floorf(pi)) % m
		var b := (a + 1) % m
		var u := pi - floorf(pi)
		u = u * u * (3.0 - 2.0 * u)
		_width.append(lerpf(float(points[a].get("width", 24.0)), float(points[b].get("width", 24.0)), u))
		_height.append(lerpf(float(points[a].get("height", 16.0)), float(points[b].get("height", 16.0)), u))
		_line.append(lerpf(float(points[a].get("line", 0.0)), float(points[b].get("line", 0.0)), u))
		_tags.append("")
	var up := Vector3.UP
	for i in n:
		var f := (_pos[(i + 1) % n] - _pos[(i - 1 + n) % n]).normalized()
		_fwd.append(f)
		up = up - f * up.dot(f)
		if up.length() < 0.2:
			up = Vector3.BACK if absf(f.y) > 0.99 else Vector3.UP - f * f.y
		up = up.normalized()
		var pi2 := float(i) * m / n
		var a2 := int(floorf(pi2)) % m
		var b2 := (a2 + 1) % m
		var bank := deg_to_rad(lerpf(float(points[a2].get("bank", 0.0)), float(points[b2].get("bank", 0.0)), pi2 - floorf(pi2)))
		var banked := up.rotated(f, bank)
		_up.append(banked)
		_right.append(f.cross(banked).normalized())
	for a in m:  # a tag sits on the sample nearest its point
		var tag := str(points[a].get("tag", ""))
		if tag == "":
			continue
		var at: Vector3 = points[a]["at"]
		var best := 0
		var best_d := INF
		for i in n:
			var d2 := at.distance_squared_to(_pos[i])
			if d2 < best_d:
				best_d = d2
				best = i
		_tags[best] = tag


func _checkpoints() -> void:
	var fixed: Array[float] = [0.0]  # the line and every tagged point always get one
	for i in _tags.size():
		if _tags[i] != "" and _tags[i] != "start":
			fixed.append(float(i) * STEP)
	var marks: Array[float] = fixed.duplicate()
	var d := CHECKPOINT_SPACING
	while d < lap_length - CHECKPOINT_SPACING * 0.5:
		var near := false
		for f in fixed:  # a regular one within 8 m of a fixed one is dropped
			if absf(f - d) <= 8.0:
				near = true
		if not near and not solid_at(d) and not solid_at(d - 10.0) and not solid_at(d + 10.0):
			marks.append(d)
		d += CHECKPOINT_SPACING
	marks.sort()
	var kept: Array[float] = []
	for mark in marks:  # a near duplicate (under 8 m) is dropped
		if kept.is_empty() or mark - kept[-1] > 8.0:
			kept.append(mark)
	for mark in kept:
		var fix := sample(mark)
		checkpoints.append({"d": fix.d, "pos": fix.pos, "forward": fix.forward, "right": fix.right, "up": fix.up,
				"width": fix.width, "height": fix.height, "tag": fix.tag})
