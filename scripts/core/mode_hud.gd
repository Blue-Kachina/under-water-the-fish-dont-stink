class_name ModeHud
extends RefCounted
## What a mode puts on the HUD, through the slots hud.gd (the HudHost) exposes:
## the scorebug (hud.scorebug), the countdown text, the splash
## (hud.splash), the points feed (hud.feed_add), the board (hud.board), the
## replay overlay (hud.replay_overlay) and the hint line's wording. The host
## calls the virtuals below once per frame; set with hud.set_mode_hud().

## The hint line's "R: ..." wording.
var restart_hint := "reset"
## The hint line's "Y: ... cam" word.
var camera_word := "fish"
## The mode has a scoreboard held up with the scoreboard button.
var has_board := false
## The scorebug shows while the mode is live.
var shows_scorebug := false
## The hint line for a split-screen player who joined ("" for the usual one).
var joined_hint := ""
## Added to the usual hint line's end ("Back/View ...: join").
var join_hint := ""


## Hooks onto the HUD (connect the mode's signals here).
func attach(_hud: Node) -> void:
	pass


func detach() -> void:
	pass


## False once the mode's node is gone (the HUD falls back to its own).
func live() -> bool:
	return true


## Per frame: fill the scorebug and the course label.
func update_slots(_hud: Node) -> void:
	pass


## The 3-2-1 / GO! text ("" for none).
func countdown_text() -> String:
	return ""


## Per frame while the board slot is wanted: fill hud.board.
func update_board(_hud: Node) -> void:
	pass


## A replay of the mode's own is playing (the HUD hides its live readouts).
func replay_live() -> bool:
	return false


## The replay whose ghosts the HUD lists in the top corners (null for none).
func ghost_replay() -> GoalReplay:
	return null
