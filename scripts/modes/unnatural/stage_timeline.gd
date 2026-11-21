class_name StageTimeline
extends RefCounted
## The stage's scripted events in Unnatural (planning_unnatural.md §3-4, D5):
## a closing ring of zombies, the Drowned Shark (mini-boss), a stampede, a
## tide and the Blood Leviathan (the boss), each at its time in the Stage
## settings (0 skips it). Each is announced event_warning seconds ahead
## (warned), and the director holds its packs for event_hush seconds before it
## (hushed()). Times are the stage's (UnnaturalRun.stage_time(): each stage
## starts its own), scaled for a Short run. UnnaturalRun hears started and makes it happen. Times are read
## again on reset(), so the panel's changes apply from the next run.

signal warned(event: String)
signal started(event: String)

## Event id -> [setting with its time, warning headline, line under it].
const EVENTS := {
	"ring": ["ring_time", "THE RING CLOSES", "THEY'RE ALL AROUND YOU"],
	"miniboss": ["miniboss_time", "THE DROWNED SHARK RISES", "MINI-BOSS"],
	"stampede": ["stampede_time", "STAMPEDE", "A BAIT BALL OF THE DEAD"],
	"tide": ["tide_time", "THE TIDE TURNS", "A WALL OF ZOMBIES"],
	"boss": ["boss_time", "SOMETHING VAST RISES", "THE FINAL BOSS  ·  BEAT IT TO END THE NIGHT"],
}

var settings: UnnaturalSettings
## The events still to come, soonest first: each {"id", "time", "warned"}.
var pending: Array[Dictionary] = []
## Events that have started so far (ids, in order).
var fired: Array[String] = []


func _init(timeline_settings: UnnaturalSettings) -> void:
	settings = timeline_settings
	reset()


func reset() -> void:
	pending.clear()
	fired.clear()
	if not settings.stage_events:
		return
	for id: String in EVENTS:
		var time: float = settings.get(EVENTS[id][0]) * settings.event_time_scale()  # a Short run's come sooner (P5)
		if time > 0.0:
			pending.append({"id": id, "time": time, "warned": false})
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)


static func headline(id: String) -> String:
	return EVENTS[id][1] if EVENTS.has(id) else id.to_upper()


static func line(id: String) -> String:
	return EVENTS[id][2] if EVENTS.has(id) else ""


## The next event to come ({} if none).
func next_event() -> Dictionary:
	return pending[0] if not pending.is_empty() else {}


## Whether the director should hold its packs at `elapsed` (an event soon).
func hushed(elapsed: float) -> bool:
	for event in pending:
		if event.time - elapsed <= settings.event_hush:
			return true
	return false


## Whether event `id` is still to come.
func is_pending(id: String) -> bool:
	for event in pending:
		if event.id == id:
			return true
	return false


## Event `id` starts now, ahead of its time (the boss rift), with no warning.
## False if it isn't still to come.
func trigger(id: String) -> bool:
	if not drop(id):
		return false
	fired.append(id)
	started.emit(id)
	return true


## Event `id` won't come (it already has, early, on the host). False if it
## wasn't still to come.
func drop(id: String) -> bool:
	for n in pending.size():
		if pending[n].id == id:
			pending.remove_at(n)
			return true
	return false


## Announces and starts what's due at `elapsed`.
func update(elapsed: float) -> void:
	while not pending.is_empty():
		var event: Dictionary = pending[0]
		if not event.warned and event.time - elapsed <= settings.event_warning:
			event.warned = true
			warned.emit(event.id)
		if elapsed < event.time:
			return
		pending.pop_front()
		fired.append(event.id)
		started.emit(event.id)
