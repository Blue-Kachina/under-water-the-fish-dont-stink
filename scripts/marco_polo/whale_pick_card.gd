extends CanvasLayer
## The whale pick card (planning_marco_whales.md §1a, D9). While a person's whale
## waits (the seeker's hide_time, a caught hider's join cooldown) a card shows over
## the waiting view: the whale turning on a stand, its name and skin. Left / right
## (stick, D-pad, A / D) cycles the species, up / down (W / S) the skins, A /
## Enter locks it in ("LOCKED"). Run out of time unlocked and the whale on show is
## the one they get. The card borrows the match card's look and the home screen's
## turntable: the model is a real FishModel, so what you see is what you swim.
## Until the Titans' own models exist the Breacher calves stand in.
##
## Loaded by path (MarcoPoloHud / the match), no class_name. The match side is A's:
## whale_pick_of(fish) -> {species, skin, locked}, whale_pick_window_left(fish) -> s,
## request_whale_pick(species, skin, locked). Missing methods are skipped, so the
## card also works against a stub.

const TITAN_MODEL := "res://scripts/fish_models/titan_model.gd"
## MarcoPoloMatch.Role.SEEKER, Phase.COUNTDOWN.
const SEEKER := 1
const COUNTDOWN := 0
const SPECIES := 5

var match_node: Node
var settings: Resource
var species := 0
var skin := 0
var locked := false
## Whether the card is up now.
var shown := false

var _view := SubViewport.new()
var _pivot := Node3D.new()
var _camera := Camera3D.new()
var _model: FishModel
var _model_key := ""
var _spin := 2.3
var _time := 0.0
var _reach := 4.0
var _card := Card.new()
var _tex := TextureRect.new()
var _was_shown := false
## Stand-in for tests and stubs: the seconds the card says are left (-1: ask the match).
var window_override := -1.0


func _ready() -> void:
	layer = 7
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.size = Vector2i(640, 400)
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.78, 0.86)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	_view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.7, 0.0)
	key.light_energy = 1.3
	_view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, -2.6, 0.0)
	rim.light_color = Color(0.4, 0.95, 0.9)
	rim.light_energy = 0.9
	_view.add_child(rim)
	_view.add_child(_pivot)
	_camera.fov = 32.0
	_view.add_child(_camera)
	_card.card = self
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_card)
	_tex.texture = _view.get_texture()
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.add_child(_tex)
	visible = false


## Hooks the card to a MarcoPoloMatch (typed as Node so this parses on its own).
func bind(mp_match: Node) -> void:
	match_node = mp_match
	var from_match: Variant = mp_match.get("settings")
	settings = from_match as Resource if from_match is Resource else MarcoPoloSettings.shared()


func _setting(setting: String, fallback: Variant) -> Variant:
	var value: Variant = settings.get(setting) if settings else null
	return fallback if value == null else value


func _call(method: String, args: Array, fallback: Variant) -> Variant:
	if not is_instance_valid(match_node) or not match_node.has_method(method):
		return fallback
	return match_node.callv(method, args)


func _local() -> Node:
	return _call("local_fish", [], null) as Node


## Seconds left to pick: the match's window for the local fish, else the countdown.
func window_left() -> float:
	if window_override >= 0.0:
		return window_override
	var me := _local()
	if me == null:
		return 0.0
	if is_instance_valid(match_node) and match_node.has_method("whale_pick_window_left"):
		return float(match_node.call("whale_pick_window_left", me))
	if int(match_node.get("phase")) == COUNTDOWN:
		return maxf(float(match_node.get("phase_left")), 0.0)
	return 0.0


## Whether the card should be up: a person's whale-to-be, still inside its window.
func wanted() -> bool:
	if not is_instance_valid(match_node) or not bool(_setting("whale_seeker", false)):
		return false
	var me := _local()
	if me == null or bool(_call("is_spectating", [], false)):
		return false
	if bool(me.get("puppet")):
		return false
	var is_whale_to_be := int(_call("role_of", [me], 0)) == SEEKER or window_override >= 0.0
	return is_whale_to_be and window_left() > 0.0


func _process(delta: float) -> void:
	shown = wanted()
	visible = shown
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if not shown:
		_was_shown = false
		return
	if not _was_shown:
		_was_shown = true
		_open()
	_time += delta
	_spin += delta * deg_to_rad(float(_setting("pick_card_spin", 28.0)))
	_read_input()
	_show_model()
	_pivot.rotation.y = _spin
	_pivot.position.y = sin(_time * 1.3) * 0.04 * _reach * 0.1
	if _model:
		_model.react(delta, _model.global_basis * Vector3(0.0, 0.0, -3.0))
	var view := get_viewport().get_visible_rect().size
	_layout(view)
	_card.queue_redraw()


## Opens on the last pick (or what the match already holds for us).
func _open() -> void:
	locked = false
	var me := _local()
	var held: Variant = _call("whale_pick_of", [me], null) if me else null
	if held is Dictionary and (held as Dictionary).has("species"):
		species = clampi(int((held as Dictionary).species), 0, SPECIES - 1)
		skin = maxi(int((held as Dictionary).get("skin", 0)), 0)
		locked = bool((held as Dictionary).get("locked", false))
	else:
		species = clampi(int(_setting("whale_last_pick", -1)), 0, SPECIES - 1)
		skin = maxi(int(_setting("whale_last_skin", 0)), 0)
	skin = skin % skins()


func skins() -> int:
	var count: Variant = match_node.get("WHALE_SKINS") if is_instance_valid(match_node) else null
	return maxi(int(count) if count != null else 3, 1)


func _read_input() -> void:
	var edges := {}
	for key: int in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_ENTER, KEY_KP_ENTER]:
		var down := Input.is_physical_key_pressed(key as Key)
		edges[key] = down and not _held.get(key, false)
		_held[key] = down
	if locked:
		return
	var step := 0
	var skin_step := 0
	if Input.is_action_just_pressed(&"ui_right") or edges[KEY_D]:
		step = 1
	elif Input.is_action_just_pressed(&"ui_left") or edges[KEY_A]:
		step = -1
	if Input.is_action_just_pressed(&"ui_down") or edges[KEY_S]:
		skin_step = 1
	elif Input.is_action_just_pressed(&"ui_up") or edges[KEY_W]:
		skin_step = -1
	if step != 0:
		species = posmod(species + step, SPECIES)
		skin = 0
		changed()
	if skin_step != 0:
		skin = posmod(skin + skin_step, skins())
		changed()
	if Input.is_action_just_pressed(&"ui_accept") or edges[KEY_ENTER] or edges[KEY_KP_ENTER]:
		lock()


var _held := {}


## A pick changed: tell the match (it tells the host and remembers it).
func changed() -> void:
	_sound("mp/pick_cycle")
	_send()


func lock() -> void:
	locked = true
	_sound("mp/pick_lock")
	_send()


## A flat cue through the Sfx autoload (absent in a bare probe).
func _sound(id: String) -> void:
	var sfx: Node = get_tree().root.get_node_or_null("Sfx") if is_inside_tree() else null
	if sfx and sfx.has_method("play"):
		sfx.call("play", id)


func _send() -> void:
	if is_instance_valid(match_node) and match_node.has_method("request_whale_pick"):
		match_node.call("request_whale_pick", species, skin, locked)
	elif settings:
		settings.set("whale_last_pick", species)
		settings.set("whale_last_skin", skin)


## The model for the pick on show: the Titans' when they exist, else the calf of the same species.
func _show_model() -> void:
	var key := "%d:%d" % [species, skin]
	if key == _model_key and _model:
		return
	_model_key = key
	if _model:
		_model.queue_free()
	var titan_class: int = int(FishCharacter.FishClass.get("TITAN", -1))
	if titan_class >= 0 and ResourceLoader.exists(TITAN_MODEL):
		_model = FishModel.build(titan_class as FishCharacter.FishClass, species, skin)
	else:
		_model = FishModel.build(FishCharacter.FishClass.BREACHER, species % FishCharacter.species_count(FishCharacter.FishClass.BREACHER), skin)
	_pivot.add_child(_model)
	var box := _bounds(_model)
	_reach = maxf(box.size.length() * 0.95, 0.5)
	_pivot.position = Vector3.ZERO
	_model.position = -box.get_center()
	_camera.position = Vector3(-0.55, 0.32, -1.0).normalized() * _reach * 1.1
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.far = maxf(_reach * 8.0, 100.0)


static func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local := model.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		return AABB(Vector3(-1.0, -0.5, -2.0), Vector3(2.0, 1.0, 4.0))
	return box


func name_of(index: int) -> String:
	var table: Array = FishCharacter.SPECIES.get(FishCharacter.FishClass.get("TITAN", FishCharacter.FishClass.BREACHER), [])
	if index >= 0 and index < table.size():
		return String((table[index] as Dictionary).name)
	return "Whale"


func _layout(view: Vector2) -> void:
	var s := UITheme.scale_for(get_viewport())
	var height := view.y * float(_setting("pick_card_height", 0.62))
	var width := minf(height * 1.45, view.x * 0.9)
	var rect := Rect2((view - Vector2(width, height)) * Vector2(0.5, 0.46), Vector2(width, height))
	_card.rect_card = rect
	_card.scale_ui = s
	var pic := Rect2(rect.position + Vector2(14.0 * s, 58.0 * s), Vector2(rect.size.x - 28.0 * s, rect.size.y - 58.0 * s - 92.0 * s))
	_tex.position = pic.position
	_tex.size = pic.size


## The card's panel and its text.
class Card extends Control:
	var card: Node
	var rect_card := Rect2()
	var scale_ui := 1.0

	func _draw() -> void:
		if card == null or not card.get("shown"):
			return
		var s := scale_ui
		var r := rect_card
		UITheme.draw_box(self, r, Color(UITheme.HUD_FILL, 0.94), 18.0 * s, Color(UITheme.AQUA, 0.55), 1.5 * s)
		var locked: bool = card.locked
		var left := ceili(card.window_left())
		UITheme.draw_text(self, Rect2(r.position + Vector2(18.0 * s, 10.0 * s), Vector2(r.size.x * 0.6, 40.0 * s)),
				String(card.name_of(card.species)).to_upper(), UITheme.display(700), roundi(30.0 * s), UITheme.INK, HORIZONTAL_ALIGNMENT_LEFT)
		UITheme.draw_text(self, Rect2(r.position + Vector2(r.size.x * 0.6, 12.0 * s), Vector2(r.size.x * 0.4 - 18.0 * s, 34.0 * s)),
				"LOCKED" if locked else "%d s" % left, UITheme.condensed(800), roundi(24.0 * s),
				UITheme.AQUA if locked else (UITheme.CORAL if left <= 3 else UITheme.MUTED), HORIZONTAL_ALIGNMENT_RIGHT)
		# Species pips and the skin.
		var base := r.position + Vector2(18.0 * s, r.size.y - 80.0 * s)
		for i in card.SPECIES:
			var c := base + Vector2((12.0 + i * 26.0) * s, 12.0 * s)
			draw_circle(c, 7.0 * s, UITheme.AQUA if i == card.species else Color(UITheme.MUTED, 0.35))
		UITheme.draw_text(self, Rect2(base + Vector2(150.0 * s, 0.0), Vector2(r.size.x - 190.0 * s, 24.0 * s)),
				"SKIN  %d / %d" % [card.skin + 1, card.skins()], UITheme.condensed(700), roundi(18.0 * s), UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		var hint := "The whale on show is the one you get when the round goes live." if not locked else "Ready. Hold on."
		UITheme.draw_text(self, Rect2(r.position + Vector2(18.0 * s, r.size.y - 44.0 * s), Vector2(r.size.x - 36.0 * s, 20.0 * s)),
				hint, UITheme.condensed(600), roundi(14.0 * s), UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		UITheme.draw_text(self, Rect2(r.position + Vector2(18.0 * s, r.size.y - 24.0 * s), Vector2(r.size.x - 36.0 * s, 20.0 * s)),
				"◀ ▶  whale     ▲ ▼  skin     A / ENTER  lock in", UITheme.condensed(700), roundi(15.0 * s), UITheme.AQUA, HORIZONTAL_ALIGNMENT_LEFT)
