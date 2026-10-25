class_name CourseSkill
extends Node
## Unnatural's traversal on the Obstacle Course (main.gd adds one while the
## course is played): the fish's passive twist and its mobility skill on the
## boost button (Traversal, with no run: the skills move the fish and show
## their effects, with nothing to hit), and the skill's button at the bottom of
## the screen, as in Unnatural's HUD (UnnaturalHud.SkillButton).

var fish: FishController
var twist: Traversal
var _button := UnnaturalHud.SkillButton.new()
var _layer := CanvasLayer.new()


func _ready() -> void:
	twist = Traversal.new(null, fish, get_parent())
	fish.respawning.connect(twist.reset)
	_layer.layer = 2  # with the HUD
	add_child(_layer)
	_button.twist = twist
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.anchor_top = 1.0
	_button.anchor_bottom = 1.0
	_button.offset_left = -UnnaturalHud.SkillButton.SIZE.x * 0.5
	_button.offset_right = UnnaturalHud.SkillButton.SIZE.x * 0.5
	_place_button()  # before its first draw: no zero-height text
	_layer.add_child(_button)


func _exit_tree() -> void:
	if fish and fish.respawning.is_connected(twist.reset):
		fish.respawning.disconnect(twist.reset)
	twist.clear()
	if is_instance_valid(fish):
		fish.speed_scale = 1.0


func _physics_process(delta: float) -> void:
	twist.update(delta)
	fish.speed_scale = twist.speed_factor()


func _process(_delta: float) -> void:
	_place_button()


## The skill's button: its name, shown if the fish has a skill, over the
## stroke rhythm meter when that's showing (as in Unnatural's HUD).
func _place_button() -> void:
	var title := Traversal.skill_title(fish.character)
	_button.visible = title != "" and twist.settings.twists
	if not _button.visible:
		return
	_button.title = title.to_upper()
	var meter := fish.swim_strokes and fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY
	_button.offset_bottom = -118.0 if meter else -28.0
	_button.offset_top = _button.offset_bottom - UnnaturalHud.SkillButton.SIZE.y
