class_name CanyonReefArena
extends RaceArena
## The Canyon Reef Circuit's arena (planning_race.md phases 2-3): open water with the circuit carved into a block of
## rock. RaceMatch loads it through the descriptor's `environments` map like any RaceArena and reads `track`. The rock is
## built from the track by RaceLayout through the terrain's fixed-layout seam, inside a Seabed (so the reef flora grows on
## its walls and floor), at the world's origin: the track's coordinates are world coordinates. The water look is an
## Ocean's (shafts, caustics, marine snow), borrowed as a child.
##
## RaceMatch owns the racing rules (stream pushes, slipstream, rescues); the arena owns the course: the rock, the soft
## ceiling (ceiling_accel), and the dressing (RaceCues, the streams' bubbles, SlipstreamFx).

## Terrain seed for the dressing (the rock itself is fixed).
const SEED := 7
## The Seabed's flora counts for this course are TerrainSettings' own; its open-floor scenery is switched off here.

var layout: RaceLayout
var terrain: Terrain
var seabed: Seabed
var streams: Array[BubbleStream] = []
var cues: RaceCues
var slipstream_fx: SlipstreamFx
var _ocean: Ocean
var _race: RaceSettings


func track_data() -> Dictionary:
	return CanyonReefTrack.data()


func _build_world() -> void:
	_race = RaceSettings.shared()
	_ocean = Ocean.new()
	_ocean.name = "Water"
	add_child(_ocean)
	var settings := TerrainSettings.shared().duplicate() as TerrainSettings
	settings.terrain_enabled = true
	layout = RaceLayout.for_track(track, settings)
	# The Seabed's other scenery lives on the open floor, which this course doesn't have: only the rock's growth stays.
	settings.arena_radius = layout.bounds.size.length() * 0.5
	settings.edge_rocks = 0
	settings.ruin_clusters = 0
	settings.ruin_rubble = 0
	settings.seabed_rocks = 0
	settings.seabed_kelp = 0
	settings.seagrass = 0
	settings.corals = 0
	settings.sponges = 0
	settings.anemones = 0
	settings.small_life = 0
	settings.terrain_schools = 0
	settings.terrain_kelp = 40  # blades are look only, but a forest in the channel hides the line
	seabed = Seabed.new()
	seabed.name = "Seabed"
	seabed.edge_glow = false
	seabed.fixed_layout = layout
	add_child(seabed)
	seabed.setup(settings, SEED, (layout.params["size"] as Vector3).y + 4.0)
	seabed.set_murk(_ocean.fog_density())
	terrain = seabed.terrain
	for i in track.streams.size():
		var stream := BubbleStream.make(track, i, _race)
		add_child(stream)
		streams.append(stream)
	cues = RaceCues.new()
	cues.name = "Cues"
	add_child(cues)
	cues.build(track)
	slipstream_fx = SlipstreamFx.new()
	slipstream_fx.name = "Slipstream"
	slipstream_fx.settings = _race
	add_child(slipstream_fx)


## The y of the rim: the rock's top (with its swell), above which the soft ceiling takes over.
func rim_y() -> float:
	return RaceLayout.RIM + RaceLayout.RIM_AMP


## The soft ceiling's push (m/s^2) on a racer at `pos`: nothing below the rim plus `ceiling_margin`, then a downward
## current that grows with height, so the open water over the rock isn't a way across the map.
func ceiling_accel(pos: Vector3) -> Vector3:
	var over := pos.y - (rim_y() + _race.ceiling_margin)
	if over <= 0.0:
		return Vector3.ZERO
	return Vector3.DOWN * _race.ceiling_push * (1.0 + over / maxf(_race.ceiling_margin, 1.0))


## Whether `pos` is out of the course's reach (see RaceTrack.in_reach), searched near `hint_d` (negative: the whole lap).
func is_out_of_bounds(pos: Vector3, hint_d := -1.0, margin := 1.1) -> bool:
	return not track.in_reach(track.nearest(pos, hint_d, 60.0), margin)


# --- The environment interface: the water look is the Ocean's --------------------------------------------

func configure_environment(env: Environment) -> void:
	_env = env
	for property: String in ["background_mode", "background_color", "sky", "fog_enabled", "fog_light_color", "fog_density",
			"fog_sky_affect", "ambient_light_source", "ambient_light_color", "ambient_light_energy"]:
		_saved[property] = env.get(property)
	_ocean.configure_environment(env)
