class_name PlayerSlot
extends RefCounted
## One local player in Nature's split-screen co-op: their controller
## (PlayerInput), fish, chase camera, HUD, arcade looks and school wheel, all
## drawn in their own part of the window (SplitScreen.view()). Slot 0 is the
## first player's: main's own fish, camera and HUD, which move into the first
## view while the screen is split and back to the whole window after.

var index := 0
## Never reused on this machine (index changes as players leave): with the
## machine's peer id it names the player online (CoopSession).
var uid := 0
var input: PlayerInput
var fish: FishController
var camera: Camera3D
var hud: CanvasLayer
var arcade: ArcadeFx
var wheel: TargetWheel
## How long (s) the leave button's been held (players past the first leave by holding it).
var leave_held := 0.0


## The nodes drawn in the slot's view.
func view_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for node: Node in [camera, hud, arcade, wheel]:
		if is_instance_valid(node):
			nodes.append(node)
	return nodes
