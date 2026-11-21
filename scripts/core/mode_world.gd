class_name ModeWorld
extends RefCounted
## What a GameMode is handed instead of reaching into main.gd: the environment
## it plays in, the local player's fish (slot 0), and the core services it may
## claim (camera, HUD). Built by main.gd (the mode host) when a match starts.

## The environment node the mode's own node lives under.
var environment: Node3D
## The local player's fish (slot 0).
var fish: FishController
## The FollowCamera (core). Modes claim and release it; they do not assign its fields.
var camera: Node
## The HUD (core). A mode fills it through its slot API.
var hud: Node
## The host, for the few services with no API yet (snapping a camera, settings).
var host: Node


func _init(host_node: Node, world_environment: Node3D, local_fish: FishController, follow_camera: Node, hud_node: Node) -> void:
	host = host_node
	environment = world_environment
	fish = local_fish
	camera = follow_camera
	hud = hud_node
