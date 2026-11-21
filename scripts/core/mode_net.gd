class_name ModeNet
extends Node
## What an online mode gives CoopSession (planning_core_roadmap.md 3.2: a generic
## host_mode / join_mode contract). A mode's descriptor says `"net": <ModeNet
## subclass>` and `"net_key": "<id on the wire>"`. CoopSession makes one adapter
## per such mode when it starts (the same node path on every machine, so its RPCs
## meet; subclasses set `name` in _ready), and for the mode being played it:
##  - hosts: main.host_mode(id), hook(game), then tick() every physics frame;
##  - joins (a guest's welcome carries world()["mode"] == net_key): main.guest_mode(id),
##    hook(game), apply_world(world);
##  - tells it about puppets (other machines' players' fish) as they come and go;
##  - leaves: unhook(), and a guest goes back to main.solo_mode(id).
## CoopSession still does the session, the roster, players' fish and tuning.

var coop: CoopSession


## True on the machine that runs the world.
func is_host() -> bool:
	return false


## Wire `mode_game` up (the host sends what it does, a guest sends requests).
func hook(_mode_game: GameMode) -> void:
	pass


func unhook() -> void:
	pass


## Per physics frame while hooked: puppets follow their players, our fish goes out.
func tick(_delta: float) -> void:
	pass


## The world as it is now, for a guest joining ("mode" is the wire key).
func world() -> Dictionary:
	return {}


## A guest took the host's world.
func apply_world(_state: Dictionary) -> void:
	pass


## A puppet (another machine's player) joined the game / left it.
func puppet_added(_fish: FishController) -> void:
	pass


func puppet_removed(_fish: FishController) -> void:
	pass


## The node the puppets should live under (the game's, by default).
func puppet_parent() -> Node:
	return null
