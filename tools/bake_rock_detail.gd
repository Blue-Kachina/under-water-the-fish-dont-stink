extends SceneTree
## Bakes textures/rock_detail.png (planning_abyssal_look.md, phase 7): one tileable 1024x1024 detail map the stone shader reads
## triplanar. R = height (4 octaves of periodic value noise), G = its slope along x (0.5 = flat), B = mottle (a separate, softer
## noise for colour breakup), A = a thin-crack mask. Run once; the PNG is the asset:
##   Godot_console.exe --headless --path . -s res://tools/bake_rock_detail.gd
## Technique after abyssal-garden's rock detail map (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md; the noise here is our own.

const SIZE := 1024


func _h(ix: int, iy: int, period: int, seed_v: int) -> float:
	var x := posmod(ix, period)
	var y := posmod(iy, period)
	var n := (x * 374761393 + y * 668265263 + seed_v * 2147483647) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


func _noise(u: float, v: float, period: int, seed_v: int) -> float:
	var x := u * period
	var y := v * period
	var ix := int(floor(x))
	var iy := int(floor(y))
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_h(ix, iy, period, seed_v), _h(ix + 1, iy, period, seed_v), fx)
	var b := lerpf(_h(ix, iy + 1, period, seed_v), _h(ix + 1, iy + 1, period, seed_v), fx)
	return lerpf(a, b, fy)


func _fbm(u: float, v: float, base: int, octaves: int, seed_v: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var norm := 0.0
	var period := base
	for o in octaves:
		sum += _noise(u, v, period, seed_v + o) * amp
		norm += amp
		amp *= 0.5
		period *= 2
	return sum / norm


func _initialize() -> void:
	var height := PackedFloat32Array()
	height.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			# Domain-warped so it reads as weathered rock, not value-noise blobs.
			var wu := u + (_fbm(u, v, 4, 2, 90) - 0.5) * 0.08
			var wv := v + (_fbm(u, v, 4, 2, 95) - 0.5) * 0.08
			height[y * SIZE + x] = _fbm(wu, wv, 6, 4, 11)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var h := height[y * SIZE + x]
			var hx := height[y * SIZE + posmod(x + 1, SIZE)]
			var slope := clampf(0.5 + (hx - h) * 40.0, 0.0, 1.0)
			var mottle := _fbm(u, v, 3, 3, 40)
			var crack := 1.0 - smoothstep(0.0, 0.025, absf(_fbm(u, v, 5, 3, 70) - 0.5))
			img.set_pixel(x, y, Color(h, slope, mottle, crack))
	DirAccess.make_dir_recursive_absolute("res://textures")
	var err := img.save_png("res://textures/rock_detail.png")
	print("bake_rock_detail: saved textures/rock_detail.png (err ", err, ")")
	quit(0 if err == OK else 1)
