class_name SplitScreen
extends CanvasLayer
## The window shared between local players (Nature's split-screen co-op): a
## view each (a SubViewport, shown through a SubViewportContainer), laid out
## for 2 (one above the other, as Rocket League does), 3 (one across the top,
## two below) or 4 (a 2x2 grid). Every view sees the same world through its
## own player's camera, with that player's HUD drawn in it: the HUD lays out on
## a canvas as tall as the full window's (900), scaled down to fit the view,
## so it stays legible and in proportion however small the view.
##
## Under the window's own overlays (the pause menu, the tuning panel, cards).

## Gap between views (px), and its colour.
const DIVIDER := 4.0
const DIVIDER_COLOR := Color(0.01, 0.03, 0.05)
## The HUD canvas's height in every view (the full window's).
const HUD_HEIGHT := 900.0

var _root := ColorRect.new()
var _containers: Array[SubViewportContainer] = []
var _views: Array[SubViewport] = []


func _ready() -> void:
	layer = -5
	_root.color = DIVIDER_COLOR
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.resized.connect(_fit_hud_canvases)


## How many views there are.
func count() -> int:
	return _views.size()


## View `index` (made if it isn't there yet, with any before it).
func view(index: int) -> SubViewport:
	while _views.size() <= index:
		_add_view()
	_layout()
	return _views[index]


## Down to `wanted` views: the last ones go, with whatever's in them.
func shrink_to(wanted: int) -> void:
	while _views.size() > wanted:
		var container: SubViewportContainer = _containers.pop_back()
		_views.pop_back()
		container.queue_free()
	_layout()


func _add_view() -> void:
	var container := SubViewportContainer.new()
	container.name = "View%d" % _views.size()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.name = "Viewport"
	view.handle_input_locally = false
	view.msaa_3d = get_viewport().msaa_3d
	view.screen_space_aa = get_viewport().screen_space_aa
	view.audio_listener_enable_3d = _views.is_empty()  # one set of ears: the first player's
	view.size_2d_override_stretch = true
	container.add_child(view)
	_root.add_child(container)
	container.resized.connect(_fit_hud_canvases)
	_containers.append(container)
	_views.append(view)


## Each view's place in the window, by how many there are.
func _layout() -> void:
	var rects: Array[Rect2] = []
	match _views.size():
		1:
			rects = [Rect2(0, 0, 1, 1)]
		2:
			rects = [Rect2(0, 0, 1, 0.5), Rect2(0, 0.5, 1, 0.5)]
		3:
			rects = [Rect2(0, 0, 1, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]
		_:
			rects = [Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]
	for i in _containers.size():
		var container := _containers[i]
		var rect := rects[mini(i, rects.size() - 1)]
		container.anchor_left = rect.position.x
		container.anchor_top = rect.position.y
		container.anchor_right = rect.end.x
		container.anchor_bottom = rect.end.y
		# Half the divider on each inner edge.
		container.offset_left = DIVIDER / 2.0 if rect.position.x > 0.0 else 0.0
		container.offset_top = DIVIDER / 2.0 if rect.position.y > 0.0 else 0.0
		container.offset_right = -DIVIDER / 2.0 if rect.end.x < 1.0 else 0.0
		container.offset_bottom = -DIVIDER / 2.0 if rect.end.y < 1.0 else 0.0
	_fit_hud_canvases.call_deferred()


## Every view's 2D canvas is HUD_HEIGHT tall, as wide as its shape needs.
func _fit_hud_canvases() -> void:
	for i in _views.size():
		var size := _containers[i].size
		if size.y < 1.0:
			continue
		_views[i].size_2d_override = Vector2i(roundi(size.x * HUD_HEIGHT / size.y), roundi(HUD_HEIGHT))
