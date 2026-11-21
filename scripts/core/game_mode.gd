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
## (String), after (the id of the mode listed before it in the picker order),
## split_screen (true: local players can join, see attach_player()), sfx (the
## sound scripts attached to the mode's node), settings (its tuning script).
## More keys, all optional: card_choices (Callable(card, host) adding the match card's
## choices), one_screen (true: no split-screen; one_screen_note names it on the card),
## settings_key / settings_after / extra_settings (the tuning panel's section id, where
## it goes, and more [key, title, script] sections), models ({FishClass: Callable(FishModel)}
## a mode-built body, see ModeRegistry.model_provider), net (a ModeNet subclass) with net_key,
## environments ({name: script}: arenas the mode builds, merged into the host's list).
## "environment" may be a Callable of the host returning the name (a card's arena pick);
## "reset_label" a Callable of the mode's node; "card_fill" (Callable(host, MatchCard): the
## card's pickers and note); "join" (Callable(host, args): an online guest's prep, see
## Main.join_mode).
## Setup screen (ModeSetups), one of: "setup_rows" (Callable(ModeSetup, row maker): plain
## option rows), "setup" (a script with static rows/current_role/use_role/apply_form/...,
## see WhatStinksSetup) or "role_rows" (Callable(host, ModeSetup) -> the role it starts on)
## with "current_role" (Callable(host) -> role), "role_pool" (Callable(role) -> {"entry",
## "label"} or {}: a role's own character pick), "character_picked_by_mode" (Callable(role)
## -> bool) and "apply_pick" (Callable(host)).
## Providers the core asks for without naming a mode (ModeRegistry.provided, the first
## registered one wins): "panel_tabs" ({section id: Callable(group) -> tab title}: the tuning
## panel's tab rule for a mode's section), "form_preview" (a Node3D script with setup(key),
## fish, focus(), camera_heading(): the home screen's Hunter form showcase), "class_details"
## (Callable(FishClass) -> Dictionary, FishDetails.details' keys: the Class details panel) and
## "class_growth" (Callable(FishClass) -> String: the stat the class grows by).

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


## Whether R restarts it here (an online guest's can't).
func can_reset() -> bool:
	return true


## A local player (a PlayerSlot) is in the mode: claim their own camera and HUD
## (a split-screen player's views are theirs). Called for every slot when the mode
## starts, and for each player joining later (descriptor "split_screen").
func attach_player(_slot: PlayerSlot) -> void:
	pass


## Undoes attach_player() (the mode ending, or the player leaving).
func detach_player(_slot: PlayerSlot) -> void:
	pass


## True while a match is in progress.
func playing() -> bool:
	return true
