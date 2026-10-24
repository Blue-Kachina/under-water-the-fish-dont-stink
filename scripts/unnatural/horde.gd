class_name Horde
extends Node3D
## Unnatural's zombie fish at scale (planning_unnatural.md §2): a sibling of
## School, minus the formation. Thousands of enemies, so no node per enemy: the
## zombies are a struct of arrays, pre-sized to `capacity` and reused (dead
## slots go on a free list), stepped at settings.sim_rate and drawn between
## the last two steps every frame through one MultiMesh per kind per tail pose
## (SchoolLook's baked looks), with a rot overlay (zombie_overlay.gdshader)
## whose per-instance data carries the hit flash, the death fade and the elite
## glow.
##
## Each step every zombie seeks its target (the nearest chaseable player in
## `targets`, re-picked every RETARGET_STEPS steps) its kind's way
## (EnemyKind.Behaviour): swarmers weave as they come, rays glide wide and cut
## across the player's path (leading them), swordfish stalk to lunge_range,
## telegraph (a red glow, slowing), lunge in a straight line and rest; the
## rest chase. Each pushes apart from the
## others in its grid bucket (HordeGrid, rebuilt each step) so the horde
## spreads into a wall, drifts a little (wander) and stays in the arena's
## disc and depth band. Zombies far from every player (far_distance) steer only
## every far_update_divisor-th step. The grid also answers the attacks' and
## contact damage's queries (query_sphere(), nearest_in_cone()).
##
## The murk (planning_murk.md, apply_murk()): a zombie behind every camera
## (murk_frustum) or further than cull_distance from the cameras isn't drawn,
## and one between glint_near and glint_far shows a pair of red eyes (one
## MultiMesh, zombie_glint.gdshader). Zombies past far_reach steer less often.
##
## Detail (the second perf pass): each look comes in BANDS of detail
## (SchoolLook.detail_meshes(), by distance: settings.lod_*), since one
## MultiMesh over the whole arena never gets Godot's own LOD. In split-screen
## (settings.per_view_horde, cameras on their players' render layers) every
## view has its own set of looks and eyes on its own layer, holding only the
## zombies that view's camera sees.
##
## damage() hurts one; at 0 hp it dies (killed), fades over DYING_TIME and its
## slot is freed. Immortal zombies (all of them with `immortal`, or one
## spawned so: the Test Tank's dummies) take hits but never die: a hit that
## would have killed one says so (would_kill) and its hp starts again.
##
## Proxies (spawn_proxy()) are a boss's body parts: undying, unsteered and
## undrawn slots their boss moves (place()), so every attack, battery and
## powerup finds the boss through the grid like any zombie. UnnaturalRun.hit()
## hands their damage to the boss.
##
## Online (planning_unnatural.md §9) every zombie has a net id, the same on
## every machine (the host's spawn() picks it, guests are told it):
## index_of_net(), net_id_of(). spawned and removed tell the host's
## UnnaturalNet what to send; kill() and correct() apply what a guest is told.
##
## Feel (the Playability pass, P3): a hit's flash scales with hit_flash and a
## lunge's glow with telegraph_glow; a dying zombie swells (kill_swell) before
## it shrinks; `telegraphing` lists the lungers winding up. Depth assist
## (depth_assist) draws each toward its target's depth, and auto-aim's nearest
## (nearest_in_cone(), aim_gap()) favours zombies at the aimer's depth.
##
## Written to port straight to the GDExtension (a HordeSim on the same packed
## arrays) once GDScript is the limit.

## A zombie died: its slot, kind (index into `kinds`), where, and what killed it.
signal killed(index: int, kind: int, at: Vector3, source: String, by: Object)
## An immortal zombie took a hit that would have killed it.
signal would_kill(index: int, kind: int, source: String, by: Object)
## A zombie came (any way: packs, events, a boss's call), or was taken away quietly.
signal spawned(index: int)
signal removed(index: int)
## A lunger entered a stage (Lunge.TELEGRAPH: it winds up; Lunge.LUNGE: it strikes).
signal lunge_stage(index: int, stage: int)

enum State { FREE, ALIVE, DYING }
## A lunging zombie's stages.
enum Lunge { STALK, TELEGRAPH, LUNGE, REST }

const OVERLAY_SHADER := preload("res://shaders/zombie_overlay.gdshader")
const GLINT_SHADER := preload("res://shaders/zombie_glint.gdshader")
## The eyes' quads: each this far either side of the middle (in eye sizes).
const GLINT_APART := 1.6
## The eyes grow with distance (1 + d / GLINT_GROW, d in m) so they stay a few pixels.
const GLINT_GROW := 25.0
## Never more than this many steps in one physics tick (after a hitch).
const MAX_STEPS := 4
## Each zombie picks its target again every this many steps (staggered).
const RETARGET_STEPS := 30
## Separation looks at no more than this many others in its bucket, a
## different few each step (so a crowded bucket still spreads out).
const MAX_NEIGHBOURS := 8
## How quickly a zombie turns to face the way it swims (1/s).
const FACE_RATE := 7.0
## A dead zombie shrinks away over this long (s).
const DYING_TIME := 0.25
## How quickly the hit flash fades (1/s).
const FLASH_FADE := 7.0
## Elites: this much bigger, this many times the hp.
const ELITE_HP := 5.0
## Elite modifiers (P5, RoR2 style): Burning leaves fire, Electric shocks as it
## dies, Frozen's touch slows, Bloated bursts into sardines. UnnaturalRun does
## what each does; the horde rolls them (roll_affix()) and tints them.
enum Affix { NONE, BURNING, ELECTRIC, FROZEN, BLOATED }
const AFFIX_NAMES := ["", "Burning", "Electric", "Frozen", "Bloated"]
## Floats per instance in a look's buffer: a 3x4 transform, then custom data.
const STRIDE := 16
## Detail bands per look (near, mid, far: settings.lod_*).
const BANDS := 3
## Depth assist (settings.depth_assist, P3): at 1 a zombie climbs or dives
## toward its target's depth at DEPTH_DRIFT of its speed on top of its chase
## (easing in within DEPTH_SOFT m of it), and auto-aim counts each metre of
## height between DEPTH_AIM metres further off.
const DEPTH_DRIFT := 0.5
const DEPTH_SOFT := 3.0
const DEPTH_AIM := 1.5

var settings: UnnaturalSettings
var kinds: Array[EnemyKind] = []
var capacity := 0
## Take hits but never die (the Test Tank's dummies).
var immortal := false
## Where the players are now (set every tick), how they're moving, and which
## may be chased (1; 0: down, or invisible while picking a card or opening a chest).
var targets := PackedVector3Array()
var target_velocities := PackedVector3Array()
## Each target's pull (1 if missing): a zombie picks the target nearest by
## distance / pull, so a decoy (Anglerfish Lure) with pull 3 wins over a
## player up to 3 times nearer.
var target_pull := PackedFloat32Array()
var chaseable := PackedByteArray()
## The arena: zombies stay within arena_radius of this, in the depth band.
var arena_centre := Vector3.ZERO
var bounded := true
var grid := HordeGrid.new()
## The live zombies as of the last step (indices).
var alive := PackedInt32Array()
## The live lungers winding up (Lunge.TELEGRAPH) as of the last step, for
## their warning lanes (Telegraphs) and the threat arrows.
var telegraphing := PackedInt32Array()
## The difficulty level new zombies spawn at (UnnaturalRun sets it from the
## clock): more hp, damage and speed, and bigger (UnnaturalSettings' Difficulty).
var difficulty := 0.0
## Every new zombie's hp times this (the stage: UnnaturalSettings.stage_hp_scale per stage after the first).
var stage_hp := 1.0
## The Hourglass: every zombie (not a boss's body) stops dead for this long (s).
## They can still be hit, but don't swim, lunge or hurt.
var frozen_left := 0.0
## Everything random about them (wander phases, tail beats).
var rng := RandomNumberGenerator.new()
## The murk (apply_murk()): not drawn past cull_distance (m) from every camera;
## red eyes from glint_near to glint_far; steering less often past far_reach
## from every player (-1: settings.far_distance).
var cull_distance := INF
var glint_near := INF
var glint_far := 0.0
var far_reach := -1.0
## How many zombies, and how many pairs of eyes, the last frame drew (in any
## view), and how many fish all the views drew between them.
var drawn_count := 0
var glint_count := 0
var drawn_instances := 0
## The last frame's view sets (1: one set every view sees).
var view_sets := 0
## The minimap's survey (survey()): zombies per cell of a square grid over the
## arena (survey_cells across, survey_cell m each, from survey_origin's x and
## z), elites not counted; where the elites are; and survey()'s count, so maps
## can tell when it's new.
var survey_counts := PackedFloat32Array()
var survey_cells := 0
var survey_cell := 4.0
var survey_origin := Vector3.ZERO
var survey_elites := PackedVector3Array()
var survey_version := 0
var _survey_at := -1000000

var _state := PackedByteArray()
var _kind := PackedInt32Array()
var _position := PackedVector3Array()
var _last_position := PackedVector3Array()
var _velocity := PackedVector3Array()
## Their facing, as basis columns (x right, y up, z back: the nose is -z).
var _axis_x := PackedVector3Array()
var _axis_y := PackedVector3Array()
var _axis_z := PackedVector3Array()
var _hp := PackedFloat32Array()
var _max_hp := PackedFloat32Array()
var _size := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _flash := PackedFloat32Array()
var _dying := PackedFloat32Array()
var _tail := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _target := PackedInt32Array()
var _elite := PackedByteArray()
## Each elite's modifier (Affix, P5; NONE for a plain one or a non-elite).
var _affix := PackedByteArray()
var _immortal := PackedByteArray()
var _proxy := PackedByteArray()
var _proxy_count := 0
var _net := PackedInt32Array()
## The difficulty level each was spawned at, and the speed it gives.
var _level := PackedFloat32Array()
var _speed_scale := PackedFloat32Array()
## Per zombie: a slow (its share of speed taken, 1: held still) until a time
## (Sticky Anemone, Cold Seep, Kraken's Grasp, Ink Sac), and a mark until a
## time (Sonar Pinger: hits on it do more).
var _slow_share := PackedFloat32Array()
var _slow_until := PackedFloat32Array()
var _mark_until := PackedFloat32Array()
## The frozen look's strength (eases in and out).
var _ice := 0.0
## Net id -> slot, for the live and dying.
var _by_net := {}
## The next net id spawn() gives (the host's).
var next_net_id := 1
## Seconds until it can be battered again (Batteries' repeat guard).
var _cooldown := PackedFloat32Array()
## Its behaviour's stage (Lunge) and time left in it, and a lunge's direction.
var _mode := PackedByteArray()
var _mode_left := PackedFloat32Array()
var _lunge := PackedVector3Array()
var _free := PackedInt32Array()
## Slots below this have been used (FREE, ALIVE or DYING); above, never.
var _high := 0
var _alive_count := 0
var _max_radius := 1.0
var _kind_speed := PackedFloat32Array()
var _kind_accel := PackedFloat32Array()
var _kind_behaviour := PackedInt32Array()
var _since_step := 0.0
var _steps := 0
var _time := 0.0
## Per look (set * _per_set + (kind * 3 + pose) * BANDS + band): its
## MultiMesh, and the buffer drawn into it. A set per view (split-screen), or one.
var _looks: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
var _per_set := 0
var _overlays: Array[ShaderMaterial] = []
var _shadows := false
## Each set's eyes, and their buffers.
var _glints: Array[MultiMeshInstance3D] = []
var _glint_buffers: Array[PackedFloat32Array] = []
var _glint_material := ShaderMaterial.new()
## The render layer each set is drawn on (1: every view's).
var _set_layers := PackedInt32Array()
## The lod errors the looks' meshes were cut at (near, mid, far).
var _lod_errors := Vector3(-1.0, -1.0, -1.0)
var _used := PackedInt32Array()
var _grown := PackedByteArray()
## The cameras this frame: where, which way, the cosine of the view's
## half-diagonal, and its player's render layer (0: none of its own).
var _eyes := PackedVector3Array()
var _forwards := PackedVector3Array()
var _cosines := PackedFloat32Array()
var _view_layers := PackedInt32Array()


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # drawn every frame


## Ready for up to `max_enemies` zombies of `horde_kinds`. Call once it's in the tree.
func setup(horde_settings: UnnaturalSettings, horde_kinds: Array[EnemyKind], max_enemies: int, rng_seed := -1) -> void:
	settings = horde_settings
	kinds = horde_kinds
	capacity = maxi(max_enemies, 1)
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_kind.resize(capacity)
	_target.resize(capacity)
	_position.resize(capacity)
	_last_position.resize(capacity)
	_velocity.resize(capacity)
	_axis_x.resize(capacity)
	_axis_y.resize(capacity)
	_axis_z.resize(capacity)
	_hp.resize(capacity)
	_max_hp.resize(capacity)
	_size.resize(capacity)
	_radius.resize(capacity)
	_flash.resize(capacity)
	_dying.resize(capacity)
	_tail.resize(capacity)
	_phase.resize(capacity)
	_cooldown.resize(capacity)
	_state.resize(capacity)
	_elite.resize(capacity)
	_affix.resize(capacity)
	_immortal.resize(capacity)
	_proxy.resize(capacity)
	_net.resize(capacity)
	_level.resize(capacity)
	_speed_scale.resize(capacity)
	_slow_share.resize(capacity)
	_slow_until.resize(capacity)
	_mark_until.resize(capacity)
	_mode.resize(capacity)
	_mode_left.resize(capacity)
	_lunge.resize(capacity)
	grid = HordeGrid.new(2.0, 4096, capacity)
	_kind_speed.resize(kinds.size())
	_kind_accel.resize(kinds.size())
	_kind_behaviour.resize(kinds.size())
	_max_radius = 0.5
	for k in kinds.size():
		_max_radius = maxf(_max_radius, kinds[k].radius() * elite_scale())
	clear()
	_build_looks()


## The murk at fog `density` (0: none), from settings: the cull distance, the
## eyes' band and where steering slows. UnnaturalRun calls it every frame.
func apply_murk(density: float) -> void:
	if density <= 0.0:
		cull_distance = INF
		glint_near = INF
		glint_far = 0.0
		far_reach = -1.0
		return
	cull_distance = UnnaturalSettings.fog_reach(settings.murk_cull, density) + settings.murk_cull_margin
	glint_near = UnnaturalSettings.fog_reach(settings.glint_from, density)
	glint_far = settings.glint_distance
	far_reach = UnnaturalSettings.fog_reach(settings.murk_far, density) if settings.murk_far > 0.0 else -1.0


## Counts the zombies into the minimap's grid (cells about `cell` m) and
## lists the elites, at most once every `every` seconds: every player's map
## shares it.
func survey(cell: float, every: float) -> void:
	var now := Time.get_ticks_msec()
	if survey_cells > 0 and now - _survey_at < roundi(every * 1000.0):
		return
	_survey_at = now
	survey_version += 1
	var half := settings.arena_radius + 10.0
	var cells := clampi(ceili(half * 2.0 / maxf(cell, 0.5)), 1, 512)
	survey_cell = half * 2.0 / cells
	survey_origin = arena_centre - Vector3(half, 0.0, half)
	if cells != survey_cells:
		survey_cells = cells
		survey_counts.resize(cells * cells)
	survey_counts.fill(0.0)
	survey_elites.clear()
	var scale := 1.0 / survey_cell
	for i in alive:
		if _proxy[i] == 1:
			continue
		var at := _position[i]
		if _elite[i] == 1:
			survey_elites.append(at)
			continue
		var x := int((at.x - survey_origin.x) * scale)
		var z := int((at.z - survey_origin.z) * scale)
		if x >= 0 and z >= 0 and x < cells and z < cells:
			survey_counts[z * cells + x] += 1.0


## Every zombie gone at once (no deaths).
func clear() -> void:
	_state.fill(State.FREE)
	_free.clear()
	_high = 0
	_alive_count = 0
	_proxy_count = 0
	frozen_left = 0.0
	_by_net.clear()
	alive.clear()
	telegraphing.clear()
	grid.build(_position, alive)


## A new zombie of kind `kind` at `at`, heading along `heading`. Returns its
## slot, or -1 with the horde full.
## `level`: its difficulty level (-1: the horde's `difficulty` now).
func spawn(kind: int, at: Vector3, heading := Vector3.ZERO, elite := false, undying := false, net_id := 0, level := -1.0,
		affix := -1) -> int:
	var i := -1
	if not _free.is_empty():
		i = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
	elif _high < capacity:
		i = _high
		_high += 1
	if i < 0:
		return -1
	var info := kinds[kind]
	_state[i] = State.ALIVE
	_kind[i] = kind
	_position[i] = at
	_last_position[i] = at
	var facing := heading.normalized() if heading.length_squared() > 0.0001 else Vector3.FORWARD
	_velocity[i] = facing * info.speed * 0.5
	_set_facing(i, facing)
	if level < 0.0:
		level = difficulty
	_level[i] = level
	_speed_scale[i] = 1.0 + settings.difficulty_speed * level
	_slow_share[i] = 0.0
	_slow_until[i] = 0.0
	_mark_until[i] = 0.0
	var grow := minf(1.0 + settings.difficulty_size * level, maxf(settings.difficulty_size_max, 1.0))
	var hp := info.hp * settings.enemy_hp_scale * (ELITE_HP if elite else 1.0) * settings.hp_growth(level) * stage_hp
	_hp[i] = maxf(hp, 1.0)
	_max_hp[i] = _hp[i]
	_size[i] = info.size * (elite_scale() if elite else 1.0) * grow
	_radius[i] = info.radius() * (elite_scale() if elite else 1.0) * grow
	_max_radius = maxf(_max_radius, _radius[i])
	_elite[i] = 1 if elite else 0
	_affix[i] = (roll_affix() if affix < 0 else affix) if elite else Affix.NONE
	_immortal[i] = 1 if undying else 0
	_proxy[i] = 0
	if net_id <= 0:
		net_id = next_net_id
		next_net_id += 1
	_by_net.erase(_net[i])
	_net[i] = net_id
	_by_net[net_id] = i
	_flash[i] = 0.0
	_dying[i] = 0.0
	_cooldown[i] = 0.0
	_tail[i] = rng.randf() * TAU
	_phase[i] = rng.randf() * TAU
	_target[i] = -1
	_mode[i] = Lunge.STALK
	_mode_left[i] = 0.0
	_alive_count += 1
	spawned.emit(i)
	return i


## `count` zombies of kind `kind` in a loose ball `spread` m round `at`, each
## elite by `elite_chance`. Returns how many there was room for.
func spawn_pack(kind: int, count: int, at: Vector3, spread: float, heading := Vector3.ZERO, elite_chance := 0.0) -> int:
	var made := 0
	for n in count:
		var offset := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5), rng.randf_range(-1.0, 1.0)) * spread
		if spawn(kind, at + offset, heading, rng.randf() < elite_chance) < 0:
			break
		made += 1
	return made


## A boss's body part: an undying slot `radius` m round at `at` that nothing
## steers or draws (move it with place()). Returns its slot, or -1.
func spawn_proxy(at: Vector3, radius: float, net_id := 0) -> int:
	var i := spawn(0, at, Vector3.ZERO, false, true, net_id, 0.0)
	if i < 0:
		return -1
	_proxy[i] = 1
	_proxy_count += 1
	_radius[i] = radius
	_size[i] = radius * 2.0
	_hp[i] = 1.0e9
	_max_hp[i] = 1.0e9
	_velocity[i] = Vector3.ZERO
	_max_radius = maxf(_max_radius, radius)
	return i


## Moves proxy `index` to `at`, facing `forward` (if given).
func place(index: int, at: Vector3, forward := Vector3.ZERO) -> void:
	_position[index] = at
	_last_position[index] = at
	if forward.length_squared() > 0.0001:
		_set_facing(index, forward.normalized())


## The slot of the zombie with net id `net_id` (-1: none here).
func index_of_net(net_id: int) -> int:
	return _by_net.get(net_id, -1)


func net_id_of(index: int) -> int:
	return _net[index] if index >= 0 and index < _high else 0


## Kills zombie `index` now, immortal or not (a guest told of the host's kill).
func kill(index: int, source: String, by: Object = null) -> void:
	if not is_alive(index):
		return
	_hp[index] = 0.0
	_state[index] = State.DYING
	_dying[index] = DYING_TIME
	_alive_count -= 1
	killed.emit(index, _kind[index], enemy_position(index), source, by)


## Moves zombie `index` toward where the host has it: snapped if it's more
## than `snap` m off, else a `blend` share of the way; and its velocity.
func correct(index: int, at: Vector3, velocity: Vector3, blend := 0.3, snap := 4.0) -> void:
	if not is_alive(index) or _proxy[index] == 1:
		return
	var off := at - _position[index]
	if off.length_squared() > snap * snap:
		_position[index] = at
		_last_position[index] = at
	else:
		_position[index] += off * blend
	_velocity[index] = velocity


func is_proxy(index: int) -> bool:
	return index >= 0 and index < _high and _proxy[index] == 1


## Live zombies, not counting proxies.
func alive_count() -> int:
	return _alive_count - _proxy_count


func is_alive(index: int) -> bool:
	return index >= 0 and index < _high and _state[index] == State.ALIVE


## Where zombie `index` is now (m), between steps.
func enemy_position(index: int) -> Vector3:
	return _position[index] + _velocity[index] * _since_step


func enemy_velocity(index: int) -> Vector3:
	return _velocity[index]


func enemy_radius(index: int) -> float:
	return _radius[index]


func enemy_size(index: int) -> float:
	return _size[index]


func enemy_kind(index: int) -> EnemyKind:
	return kinds[_kind[index]]


func enemy_kind_index(index: int) -> int:
	return _kind[index]


func enemy_hp(index: int) -> float:
	return _hp[index]


func enemy_max_hp(index: int) -> float:
	return _max_hp[index]


## Zombie `index`'s difficulty level (what it was spawned at).
func enemy_level(index: int) -> float:
	return _level[index]


## Its contact damage's multiplier from its difficulty level.
func damage_scale(index: int) -> float:
	return 1.0 + settings.difficulty_damage * _level[index]


## Every zombie stops dead for `seconds` (the Hourglass; a longer one already
## going isn't cut short).
func freeze(seconds: float) -> void:
	frozen_left = maxf(frozen_left, seconds)


func is_frozen() -> bool:
	return frozen_left > 0.0


## Zombie `index` loses `share` of its speed (1: held still) for `seconds`; a
## stronger or longer slow already on it isn't cut short. Bosses' bodies
## (proxies) shrug it off.
func slow(index: int, share: float, seconds: float) -> void:
	if not is_alive(index) or is_proxy(index) or share <= 0.0 or seconds <= 0.0:
		return
	var current := slow_share(index)
	_slow_share[index] = maxf(current, clampf(share, 0.0, 1.0))
	_slow_until[index] = maxf(_slow_until[index] if current > 0.0 else 0.0, _time + seconds)
	if share >= 1.0:
		_velocity[index] = Vector3.ZERO


## The share of its speed zombie `index` has lost now (0: none).
func slow_share(index: int) -> float:
	return _slow_share[index] if _time < _slow_until[index] else 0.0


## Zombie `index` is marked for `seconds` (Sonar Pinger): hits on it do more.
func mark(index: int, seconds: float) -> void:
	if is_alive(index):
		_mark_until[index] = maxf(_mark_until[index], _time + seconds)


func is_marked(index: int) -> bool:
	return _time < _mark_until[index]


func is_elite(index: int) -> bool:
	return _elite[index] == 1


## How much bigger an elite is than the rest of its kind (UnnaturalSettings.elite_size).
func elite_scale() -> float:
	return maxf(settings.elite_size, 1.0) if settings else 1.6


## Its elite modifier (Affix.NONE: none).
func affix_of(index: int) -> int:
	return _affix[index]


## 0: not elite; 1: a plain elite; 2 on: an elite with modifier (code - 1). The
## shader's elite channel, and what the net sends.
func elite_code(index: int) -> int:
	return 0 if _elite[index] == 0 else 1 + _affix[index]


## A modifier for a new elite: elite_modifier_chance of one of those switched on (P5).
func roll_affix() -> int:
	if settings == null or rng.randf() >= settings.elite_modifier_chance:
		return Affix.NONE
	var on: Array[int] = []
	for affix: int in [Affix.BURNING, Affix.ELECTRIC, Affix.FROZEN, Affix.BLOATED]:
		if settings.get(AFFIX_NAMES[affix].to_lower()):
			on.append(affix)
	return Affix.NONE if on.is_empty() else on[rng.randi_range(0, on.size() - 1)]


func is_immortal(index: int) -> bool:
	return immortal or _immortal[index] == 1


## Its behaviour's stage (Lunge; STALK for kinds that don't lunge).
func enemy_mode(index: int) -> int:
	return _mode[index]


## Which player (index into `targets`) zombie `index` is after (-1: none).
func enemy_target(index: int) -> int:
	return _target[index]


## The way a lunger winding up (or lunging) will go (unit).
func lunge_aim(index: int) -> Vector3:
	return _lunge[index]


## How far a lunger is through winding up (0 to 1; 0 when it isn't).
func telegraph_progress(index: int) -> float:
	if _mode[index] != Lunge.TELEGRAPH or settings.lunge_telegraph <= 0.0:
		return 0.0
	return clampf(1.0 - _mode_left[index] / settings.lunge_telegraph, 0.0, 1.0)


## How far off zombie `index` counts for auto-aim from `from`: its distance,
## plus its height off `from` weighted by depth assist (so with the assist on
## a zombie at your depth wins over a nearer one far above or below).
func aim_gap(from: Vector3, index: int) -> float:
	var offset := enemy_position(index) - from
	return offset.length() + absf(offset.y) * settings.depth_assist * DEPTH_AIM


## The biggest zombie's hit radius (m): queries reach this much further.
func max_radius() -> float:
	return _max_radius


func cooldown(index: int) -> float:
	return _cooldown[index] - _time


func set_cooldown(index: int, seconds: float) -> void:
	_cooldown[index] = _time + seconds


## Hurts zombie `index` by `amount` from `source` (e.g. "bite", "battery"),
## knocked back along `push` (unit, or zero). Returns whether that killed it.
## Zombie `index`'s velocity changed by `change` (a pull, a fling), unhurt.
func shove(index: int, change: Vector3) -> void:
	if is_alive(index) and not is_proxy(index):
		_velocity[index] += change


func damage(index: int, amount: float, source: String, by: Object = null, push := Vector3.ZERO) -> bool:
	if not is_alive(index):
		return false
	_flash[index] = 1.0
	if push != Vector3.ZERO and settings.knockback > 0.0:
		_velocity[index] += push * settings.knockback / maxf(_size[index], 0.3)
	_hp[index] -= amount
	if _hp[index] > 0.0:
		return false
	if immortal or _immortal[index] == 1:
		_hp[index] = _max_hp[index]
		would_kill.emit(index, _kind[index], source, by)
		return false
	_state[index] = State.DYING
	_dying[index] = DYING_TIME
	_alive_count -= 1
	killed.emit(index, _kind[index], enemy_position(index), source, by)
	return true


## Takes zombie `index` away quietly (no death).
func remove(index: int) -> void:
	if index < 0 or index >= _high or _state[index] == State.FREE:
		return
	if _state[index] == State.ALIVE:
		_alive_count -= 1
		if _proxy[index] == 1:
			_proxy_count -= 1
	_proxy[index] = 0
	_state[index] = State.FREE
	_by_net.erase(_net[index])
	removed.emit(index)
	_free.append(index)


## Moves zombie `index` to `at` (the leash: ahead of the players, not killed).
func relocate(index: int, at: Vector3) -> void:
	_position[index] = at
	_last_position[index] = at
	_velocity[index] = Vector3.ZERO
	_target[index] = -1
	_mode[index] = Lunge.STALK


## The live zombies whose hit spheres reach within `reach` of `centre`.
func query_sphere(centre: Vector3, reach: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var starts := grid.starts
	var entries := grid.entries
	for b in grid.buckets_near(centre, reach + _max_radius):
		for e in range(starts[b], starts[b + 1]):
			var j := entries[e]
			if _state[j] != State.ALIVE:
				continue
			var within := reach + _radius[j]
			if _position[j].distance_squared_to(centre) <= within * within:
				found.append(j)
	return found


## The live zombie nearest `origin` within `reach`, no more than acos(min_cos)
## off `forward` (unit), or -1. Nearest as auto-aim counts it (aim_gap(): depth
## assist favours zombies at origin's depth).
func nearest_in_cone(origin: Vector3, forward: Vector3, reach: float, min_cos: float) -> int:
	var best := -1
	var best_gap := INF
	var depth := settings.depth_assist * DEPTH_AIM
	for j in query_sphere(origin, reach):
		var offset := enemy_position(j) - origin
		var gap := offset.length()
		if gap > 0.001 and offset.dot(forward) / gap < min_cos:
			continue
		gap += absf(offset.y) * depth
		if gap < best_gap:
			best_gap = gap
			best = j
	return best


func _physics_process(delta: float) -> void:
	if settings == null:
		return
	var step := 1.0 / maxf(settings.sim_rate, 1.0)
	_since_step += delta
	var steps := 0
	while _since_step >= step and steps < MAX_STEPS:
		_since_step -= step
		step_once(step)
		steps += 1
	_since_step = minf(_since_step, step)


func _process(delta: float) -> void:
	if settings == null:
		return
	_draw_horde(delta)


## One step of every zombie: steer, move, then the live list and grid again.
func step_once(delta: float) -> void:
	_time += delta
	_steps += 1
	_last_position = _position.duplicate()
	for k in kinds.size():
		_kind_speed[k] = kinds[k].speed * settings.enemy_speed_scale
		_kind_accel[k] = kinds[k].accel * maxf(settings.enemy_speed_scale, 0.2)
		_kind_behaviour[k] = kinds[k].behaviour
	if frozen_left > 0.0:
		frozen_left = maxf(frozen_left - delta, 0.0)
		for i in alive:
			if _proxy[i] == 0:
				_velocity[i] = Vector3.ZERO
	else:
		_steer(delta)
	# The dying finish, and their slots free up.
	for i in _high:
		if _state[i] == State.DYING:
			_dying[i] -= delta
			if _dying[i] <= 0.0:
				_state[i] = State.FREE
				_by_net.erase(_net[i])
				_free.append(i)
	alive.resize(_alive_count)
	telegraphing.clear()
	var n := 0
	for i in _high:
		if _state[i] == State.ALIVE:
			alive[n] = i
			n += 1
			if _mode[i] == Lunge.TELEGRAPH and _proxy[i] == 0:
				telegraphing.append(i)
	alive.resize(n)
	grid.build(_position, alive)


func _steer(delta: float) -> void:
	var count := targets.size()
	var far_gap := far_reach if far_reach > 0.0 else settings.far_distance
	var far_squared := far_gap * far_gap
	var divisor := maxi(settings.far_update_divisor, 1)
	var separation := settings.separation
	var strength := settings.separation_strength
	var wander := settings.wander
	var starts := grid.starts
	var entries := grid.entries
	var buckets := grid.bucket_of
	var radius := settings.arena_radius
	var floor_y := arena_centre.y + settings.arena_floor + 1.0
	var ceiling_y := arena_centre.y + settings.arena_ceiling
	var turn := 1.0 - exp(-FACE_RATE * delta)
	var assist := settings.depth_assist * DEPTH_DRIFT
	for i in alive:
		if _proxy[i] == 1:
			continue  # its boss moves it
		var at := _position[i]
		var velocity := _velocity[i]
		# Its target: the nearest chaseable player, every so often (or when it's gone).
		var target := _target[i]
		if target < 0 or target >= count or chaseable[target] == 0 or (_steps + i) % RETARGET_STEPS == 0:
			target = _nearest_target(at)
			_target[i] = target
		var toward := Vector3.ZERO
		var gap_squared := INF
		if target >= 0:
			toward = targets[target] - at
			gap_squared = toward.length_squared()
		var far := gap_squared > far_squared
		if not far or (_steps + i) % divisor == 0:
			var dt := delta * divisor if far else delta
			var kind := _kind[i]
			var speed := _kind_speed[kind] * _speed_scale[i]
			var accel := _kind_accel[kind] * _speed_scale[i]
			if _time < _slow_until[i]:
				speed *= 1.0 - _slow_share[i]
				if _slow_share[i] >= 1.0:
					_velocity[i] = Vector3.ZERO  # held still
					continue
			if speed <= 0.0:
				# A kind that doesn't swim (the Test Tank's dummies): it drifts back to rest.
				_velocity[i] = velocity.move_toward(Vector3.ZERO, maxf(accel, 6.0) * dt)
				_position[i] = at + _velocity[i] * delta
				continue
			var wanted: Vector3
			var phase := _phase[i] + _time * 0.8
			if target >= 0 and gap_squared > 0.0001:
				var gap := sqrt(gap_squared)
				var ahead := toward / gap
				match _kind_behaviour[kind]:
					EnemyKind.Behaviour.SWARM:
						# Weaving in as they come.
						var side := Vector3.UP.cross(ahead)
						wanted = (ahead + side * sin(_time * 3.0 + _phase[i]) * 0.45).normalized() * speed
					EnemyKind.Behaviour.GLIDE:
						# Wide arcs across where the player's going.
						var lead := toward
						if target < target_velocities.size():
							lead += target_velocities[target] * settings.glide_lead
						var across := Vector3.UP.cross(ahead)
						lead += across * sin(_time * 0.5 + _phase[i]) * settings.glide_sweep * clampf(gap / 30.0, 0.2, 1.0)
						wanted = lead.normalized() * speed
						accel *= 0.6
					EnemyKind.Behaviour.LUNGE:
						wanted = _lunge_step(i, ahead, gap, speed, dt)
						if _mode[i] == Lunge.LUNGE:
							accel = 200.0
					_:
						wanted = ahead * speed
				if assist > 0.0 and _mode[i] != Lunge.LUNGE:
					# Depth assist: toward its target's depth sooner than the chase alone.
					wanted.y += clampf(toward.y / DEPTH_SOFT, -1.0, 1.0) * speed * assist
			else:
				wanted = -_axis_z[i] * speed * 0.35  # nobody to chase: mill about
				_mode[i] = Lunge.STALK
			wanted += Vector3(sin(phase), 0.5 * sin(phase * 1.3), cos(phase * 0.9)) * wander
			var push := Vector3.ZERO
			if separation > 0.0 and strength > 0.0:
				var b := buckets[i]
				var first := starts[b]
				var in_bucket := starts[b + 1] - first
				var own := _radius[i] + separation
				var looks := mini(in_bucket, MAX_NEIGHBOURS)
				var offset := (i * 7 + _steps * 13) % maxi(in_bucket, 1)
				for n in looks:
					var j := entries[first + (offset + n) % in_bucket]
					if j == i:
						continue
					var apart := at - _position[j]
					var reach := own + _radius[j]
					var d_squared := apart.length_squared()
					if d_squared < reach * reach:
						if d_squared < 0.000001:
							apart = Vector3(sin(_phase[i]), 0.3, cos(_phase[i]))  # on top of each other: any way out
							d_squared = 0.0001
						var d := sqrt(d_squared)
						push += apart / d * (1.0 - d / reach) * (float(in_bucket) / looks if in_bucket > looks else 1.0)
			velocity = velocity.move_toward(wanted, accel * dt) + push * strength * dt
			if bounded:
				var flat := Vector2(at.x - arena_centre.x, at.z - arena_centre.z)
				var out := flat.length()
				if out > radius and out > 0.001:
					var inward := -flat / out * minf(out - radius, 10.0) * 4.0 * dt
					velocity += Vector3(inward.x, 0.0, inward.y)
				if at.y < floor_y:
					velocity.y += minf(floor_y - at.y, 5.0) * 6.0 * dt
				elif at.y > ceiling_y:
					velocity.y -= minf(at.y - ceiling_y, 5.0) * 6.0 * dt
			var top := speed * 1.5 + 2.0 if _mode[i] != Lunge.LUNGE else settings.lunge_speed * 1.1
			if velocity.length_squared() > top * top:
				velocity = velocity.normalized() * top
			_velocity[i] = velocity
			if velocity.length_squared() > 0.04:
				var back := _axis_z[i].lerp(-velocity.normalized(), turn).normalized()
				_set_back(i, back)
		_position[i] = at + velocity * delta


## A lunging zombie's stages, toward its target (`ahead`, unit, `gap` m off):
## the velocity it wants now.
func _lunge_step(i: int, ahead: Vector3, gap: float, speed: float, dt: float) -> Vector3:
	_mode_left[i] -= dt
	match _mode[i]:
		Lunge.STALK:
			if gap < settings.lunge_range and settings.lunge_speed > 0.0:
				_mode[i] = Lunge.TELEGRAPH
				_mode_left[i] = settings.lunge_telegraph
				lunge_stage.emit(i, Lunge.TELEGRAPH)
			return ahead * speed * 0.8
		Lunge.TELEGRAPH:
			_lunge[i] = ahead  # still aiming
			if _mode_left[i] <= 0.0:
				_mode[i] = Lunge.LUNGE
				_mode_left[i] = settings.lunge_time
				_velocity[i] = ahead * settings.lunge_speed
				lunge_stage.emit(i, Lunge.LUNGE)
			return ahead * 0.5
		Lunge.LUNGE:
			if _mode_left[i] <= 0.0:
				_mode[i] = Lunge.REST
				_mode_left[i] = settings.lunge_rest
			return _lunge[i] * settings.lunge_speed
		_:
			if _mode_left[i] <= 0.0:
				_mode[i] = Lunge.STALK
			return ahead * speed * 0.3


## The nearest chaseable target to `at` (-1: none).
func _nearest_target(at: Vector3) -> int:
	var best := -1
	var best_gap := INF
	for t in targets.size():
		if t < chaseable.size() and chaseable[t] == 0:
			continue
		var gap := targets[t].distance_squared_to(at)
		if t < target_pull.size() and target_pull[t] > 0.0:
			gap /= target_pull[t] * target_pull[t]
		if gap < best_gap:
			best_gap = gap
			best = t
	return best


func _set_facing(index: int, forward: Vector3) -> void:
	_set_back(index, -forward)


## Its facing from its back axis (z; the nose is -z), kept upright.
func _set_back(index: int, back: Vector3) -> void:
	var up := Vector3.UP if absf(back.y) < 0.98 else Vector3.BACK
	var x := up.cross(back).normalized()
	_axis_x[index] = x
	_axis_y[index] = back.cross(x)
	_axis_z[index] = back


## Draws every zombie where it is now, between the last two steps: into each
## view's set (split-screen) or the one set, in its detail band.
func _draw_horde(delta: float) -> void:
	if settings.enemy_shadows != _shadows:
		_shadows = settings.enemy_shadows
		for look in _looks:
			look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ice = move_toward(_ice, 1.0 if frozen_left > 0.0 else 0.0, delta * 3.0)
	for overlay in _overlays:
		overlay.set_shader_parameter("rot", settings.rot)
		overlay.set_shader_parameter("eye_glow", settings.eye_glow)
		overlay.set_shader_parameter("frozen", _ice)
	_fit_detail()
	var step := 1.0 / maxf(settings.sim_rate, 1.0)
	var blend := clampf(_since_step / step, 0.0, 1.0)
	var fade := delta * FLASH_FADE
	_find_views()
	var views := _eyes.size()
	var per_view := _per_view()
	var sets := views if per_view else 1
	_fit_sets(sets, per_view)
	_used.resize(_looks.size())
	_used.fill(0)
	_grown.resize(_looks.size())
	_grown.fill(0)
	var glint_used := PackedInt32Array()
	glint_used.resize(sets)
	var frustum := settings.murk_frustum
	var cull_squared := cull_distance * cull_distance
	var glints := glint_far > 0.0 and glint_near < glint_far and views > 0
	var glint_near_squared := glint_near * glint_near
	var glint_far_squared := glint_far * glint_far
	var glint_fade := maxf(glint_far * 0.25, 1.0)
	var glint_size := settings.glint_size
	var glint_strength := settings.glint_strength
	var mid_squared := settings.lod_mid_distance * settings.lod_mid_distance
	var far_squared := settings.lod_far_distance * settings.lod_far_distance
	var warning := (0.6 + 0.4 * sin(_time * 30.0)) * settings.telegraph_glow
	var flash_scale := settings.hit_flash
	var swell := settings.kill_swell
	drawn_count = 0
	drawn_instances = 0
	for i in _high:
		var state := _state[i]
		if state == State.FREE or _proxy[i] == 1:
			continue
		var at := _last_position[i].lerp(_position[i], blend)
		var flash := maxf(_flash[i] - fade, 0.0)
		_flash[i] = flash
		var size := _size[i]
		var dead := 0.0
		var drawn_size := size
		if state == State.DYING:
			dead = 1.0 - clampf(_dying[i] / DYING_TIME, 0.0, 1.0)
			# It swells (the kill's pop), then shrinks away.
			drawn_size *= (1.0 + swell * sin(clampf(dead * 1.6, 0.0, 1.0) * PI)) * (1.0 - dead * 0.85)
		var slack := size * 1.5 + 1.0
		var slack_squared := slack * slack
		var reach_squared := size * size
		# Worked out once, the first time a view draws it.
		var counted := false
		var base := 0
		var x := Vector3.ZERO
		var y := Vector3.ZERO
		var z := Vector3.ZERO
		var elite := 0.0
		var warn := 0.0
		for s in sets:
			# Its distance from the nearest of this set's cameras that can see it (INF: none can).
			var gap_squared := 0.0 if views == 0 else INF
			var first := s if per_view else 0
			var last := s + 1 if per_view else views
			for v in range(first, last):
				var off := at - _eyes[v]
				var d_squared := off.length_squared()
				if d_squared >= gap_squared:
					continue
				if frustum:
					if d_squared > slack_squared and off.dot(_forwards[v]) + slack < sqrt(d_squared) * _cosines[v]:
						continue  # behind this camera, or off to its side
				gap_squared = d_squared
			if glints and state == State.ALIVE and gap_squared > glint_near_squared and gap_squared < glint_far_squared:
				var gap := sqrt(gap_squared)
				var glow := glint_strength * clampf((gap - glint_near) / 6.0, 0.0, 1.0) * clampf((glint_far - gap) / glint_fade, 0.0, 1.0)
				if glow > 0.01:
					var e := glint_used[s] * STRIDE
					glint_used[s] += 1
					var eyes := _glint_buffers[s]
					if e + STRIDE > eyes.size():
						eyes.resize(maxi(eyes.size() * 2, STRIDE * 256))
						_glint_buffers[s] = eyes
					var scale := size * glint_size * (1.0 + gap / GLINT_GROW) * (1.6 if _elite[i] == 1 else 1.0)
					var head := at - _axis_z[i] * size * 0.45
					eyes[e] = scale
					eyes[e + 1] = 0.0
					eyes[e + 2] = 0.0
					eyes[e + 3] = head.x
					eyes[e + 4] = 0.0
					eyes[e + 5] = scale
					eyes[e + 6] = 0.0
					eyes[e + 7] = head.y
					eyes[e + 8] = 0.0
					eyes[e + 9] = 0.0
					eyes[e + 10] = scale
					eyes[e + 11] = head.z
					eyes[e + 12] = glow
					eyes[e + 13] = 0.0
					eyes[e + 14] = 0.0
					eyes[e + 15] = 0.0
			if gap_squared == INF or gap_squared > cull_squared:
				continue  # behind this set's cameras, or lost in the murk
			if not counted:
				counted = true
				drawn_count += 1
				# The tail beats on (once a frame, however many views draw it).
				var tail := _tail[i]
				if frozen_left <= 0.0:
					var effort := clampf(_velocity[i].length() / 10.0, 0.0, 1.0)
					tail = fmod(tail + delta * lerpf(5.0, 15.0, effort), TAU)
					_tail[i] = tail
				# SchoolLook.pose_for(), inline: centre, right, centre, left.
				var quarter := int(fposmod(tail, TAU) / (TAU / 4.0))
				var pose := SchoolLook.CENTRE if quarter % 2 == 0 else (SchoolLook.RIGHT if quarter == 1 else SchoolLook.LEFT)
				base = (_kind[i] * 3 + pose) * BANDS
				x = _axis_x[i] * drawn_size
				y = _axis_y[i] * drawn_size
				z = _axis_z[i] * drawn_size
				elite = float(elite_code(i))
				warn = warning if _mode[i] == Lunge.TELEGRAPH else 0.0
			drawn_instances += 1
			var band := 0 if gap_squared < mid_squared * reach_squared else (1 if gap_squared < far_squared * reach_squared else 2)
			var look := s * _per_set + base + band
			var k := _used[look] * STRIDE
			_used[look] += 1
			var buffer := _buffers[look]
			if k + STRIDE > buffer.size():
				buffer.resize(maxi(buffer.size() * 2, STRIDE * 64))
				_buffers[look] = buffer
				_grown[look] = 1
			buffer[k] = x.x
			buffer[k + 1] = y.x
			buffer[k + 2] = z.x
			buffer[k + 3] = at.x
			buffer[k + 4] = x.y
			buffer[k + 5] = y.y
			buffer[k + 6] = z.y
			buffer[k + 7] = at.y
			buffer[k + 8] = x.z
			buffer[k + 9] = y.z
			buffer[k + 10] = z.z
			buffer[k + 11] = at.z
			buffer[k + 12] = flash * flash_scale
			buffer[k + 13] = dead
			buffer[k + 14] = elite
			buffer[k + 15] = warn
	for look in _looks.size():
		var instance := _looks[look]
		var count := _used[look]
		if instance.visible != (count > 0):
			instance.visible = count > 0
		if count == 0:
			continue
		var multimesh := instance.multimesh
		var buffer := _buffers[look]
		if _grown[look] == 1 or multimesh.instance_count * STRIDE != buffer.size():
			multimesh.instance_count = buffer.size() / STRIDE
		multimesh.visible_instance_count = count
		multimesh.buffer = buffer
	glint_count = 0
	for s in _glints.size():
		var g := glint_used[s] if s < sets else 0
		glint_count += g
		if _glints[s].visible != (g > 0):
			_glints[s].visible = g > 0
		if g == 0:
			continue
		var eyes := _glints[s].multimesh
		var buffer := _glint_buffers[s]
		if eyes.instance_count * STRIDE != buffer.size():
			eyes.instance_count = buffer.size() / STRIDE
		eyes.visible_instance_count = g
		eyes.buffer = buffer
	view_sets = sets


## The cameras to draw for: every split-screen view (School.view_cameras), or
## the viewport's own. None (a bare headless run): everything's drawn.
func _find_views() -> void:
	_eyes.clear()
	_forwards.clear()
	_cosines.clear()
	_view_layers.clear()
	var cameras: Array[Camera3D] = []
	for camera in School.view_cameras:
		if is_instance_valid(camera) and camera.is_inside_tree():
			cameras.append(camera)
	if cameras.is_empty() and is_inside_tree() and get_viewport().get_camera_3d():
		cameras.append(get_viewport().get_camera_3d())
	for camera in cameras:
		_eyes.append(camera.global_position)
		_forwards.append(-camera.global_basis.z)
		var view := camera.get_viewport().get_visible_rect().size
		var aspect := view.x / maxf(view.y, 1.0)
		var across := tan(deg_to_rad(camera.fov) * 0.5)  # along the fov's own axis
		var other := across * (aspect if camera.keep_aspect == Camera3D.KEEP_HEIGHT else 1.0 / maxf(aspect, 0.01))
		var half := atan(sqrt(across * across + other * other))
		_cosines.append(cos(minf(half + 0.05, PI * 0.5)))
		var own := camera.cull_mask & TreasureChest.PLAYER_LAYERS
		_view_layers.append(own if own != 0 and own & (own - 1) == 0 else 0)


## A set per view: more than one view, each on its own player's layer.
func _per_view() -> bool:
	if not settings.per_view_horde or _eyes.size() < 2:
		return false
	var seen := 0
	for layer in _view_layers:
		if layer == 0 or seen & layer != 0:
			return false
		seen |= layer
	return true


## `sets` sets of looks built, each on its layer (its view's, or every view's).
func _fit_sets(sets: int, per_view: bool) -> void:
	while _glints.size() < sets:
		_add_set()
	for s in sets:
		var layer := _view_layers[s] if per_view else 1
		if _set_layers[s] == layer:
			continue
		_set_layers[s] = layer
		for look in _per_set:
			_looks[s * _per_set + look].layers = layer
		_glints[s].layers = layer


## Every look's meshes at the detail settings.lod_* ask for (when they change).
func _fit_detail() -> void:
	var errors := Vector3(settings.lod_near_error, settings.lod_mid_error, settings.lod_far_error)
	if errors == _lod_errors:
		return
	_lod_errors = errors
	for look in _looks.size():
		var at := look % _per_set
		var kind := at / (3 * BANDS)
		var pose := (at / BANDS) % 3
		_looks[look].multimesh.mesh = SchoolLook.detail_meshes(kinds[kind].family, errors[at % BANDS])[pose]


## The rot overlays, and the first set of looks.
func _build_looks() -> void:
	for look in _looks:
		look.queue_free()
	for eyes in _glints:
		eyes.queue_free()
	_looks.clear()
	_buffers.clear()
	_glints.clear()
	_glint_buffers.clear()
	_set_layers.clear()
	_overlays.clear()
	_per_set = kinds.size() * 3 * BANDS
	for k in kinds.size():
		var overlay := ShaderMaterial.new()
		overlay.shader = OVERLAY_SHADER
		overlay.set_shader_parameter("rot_color", kinds[k].tint)
		_overlays.append(overlay)
	_glint_material.shader = GLINT_SHADER
	_add_set()


## One more set of looks (a MultiMesh per kind per tail pose per band, with
## the rot overlay) and eyes; the arena's size as bounds.
func _add_set() -> void:
	var s := _glints.size()
	var bounds := AABB(arena_centre - Vector3(1.0, 1.0, 1.0) * (settings.arena_radius + 50.0),
			Vector3(2.0, 2.0, 2.0) * (settings.arena_radius + 50.0))
	_lod_errors = Vector3(settings.lod_near_error, settings.lod_mid_error, settings.lod_far_error)
	for k in kinds.size():
		var meshes: Array[Array] = []
		for band in BANDS:
			meshes.append(SchoolLook.detail_meshes(kinds[k].family, _lod_errors[band]))
		for pose in 3:
			for band in BANDS:
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.use_custom_data = true
				multimesh.mesh = meshes[band][pose]
				var buffer := PackedFloat32Array()
				buffer.resize(STRIDE * 64)
				multimesh.instance_count = 64
				multimesh.visible_instance_count = 0
				var look := MultiMeshInstance3D.new()
				look.name = "%s%d%s%s" % [kinds[k].id.capitalize(), pose, "NMF"[band], "" if s == 0 else str(s)]
				look.multimesh = multimesh
				look.material_overlay = _overlays[k]
				look.custom_aabb = bounds
				look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				look.visible = false
				add_child(look)
				_looks.append(look)
				_buffers.append(buffer)
	var eyes := MultiMesh.new()
	eyes.transform_format = MultiMesh.TRANSFORM_3D
	eyes.use_custom_data = true
	eyes.mesh = _eyes_mesh()
	eyes.instance_count = 256
	eyes.visible_instance_count = 0
	var glints := MultiMeshInstance3D.new()
	glints.name = "Glints" if s == 0 else "Glints%d" % s
	glints.multimesh = eyes
	glints.material_override = _glint_material
	glints.custom_aabb = bounds
	glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glints.visible = false
	add_child(glints)
	_glints.append(glints)
	var buffer := PackedFloat32Array()
	buffer.resize(STRIDE * 256)
	_glint_buffers.append(buffer)
	_set_layers.append(1)


## Two unit quads side by side (the eyes), GLINT_APART either side of the middle.
static func _eyes_mesh() -> ArrayMesh:
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for side: float in [-GLINT_APART, GLINT_APART]:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(Vector3(side + corner.x, corner.y, 0.0))
			uvs.append(corner * 0.5 + Vector2(0.5, 0.5))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
