class_name GameMode
extends Node
## One game mode (see planning_core_roadmap.md 3.2). A subclass is a Node that
## lives under the environment while the mode is played, plus a static
## descriptor() that the host reads for everything mode-specific: the picker
## tile, environment, tuning preset, card text and reset label. A mode is one
## folder plus one line in ModeRegistry.
##
## Descriptor keys: id, title, icon, colors, pitch, short, play (Array of
## "Solo", "Split", "Online"), environment (String), match (true: played from a
## card), tuning_preset (res:// path of the tuning preset, "" for none),
## card_text (Callable returning the match card's message), reset_label
## (String), after (the id of the mode listed before it in the picker order).

## A teleport moved `fish` (the host snaps cameras following it).
signal teleported(fish: FishController)
## The mode finished: a result Dictionary.
signal over(result: Dictionary)

## Overridden by each mode.
static func descriptor() -> Dictionary:
	return {}


## The environment is ready and the players are known; called before the node
## joins the tree.
func enter(_world: ModeWorld) -> void:
	pass


## Play was pressed: the node is in the tree. Claim the camera and fill the HUD.
func start() -> void:
	pass


## The mode is being left: hand every player's fish back. The node is freed
## right after release().
func end() -> void:
	pass


## After end(): drop the claims on core services (camera, HUD).
func release() -> void:
	pass


## R: restart.
func reset() -> void:
	pass


## True while a match is in progress.
func playing() -> bool:
	return true
