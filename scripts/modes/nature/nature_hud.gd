class_name NatureHud
extends ModeHud
## Nature's HUD for one local player (a ModeHud given to that player's hud.set_mode_hud):
## the BATTERED! banner, the points feed with pearls, the splash for a multi or
## a spree, the battered fish / points / pearls line with the chain bar, and the
## held scoreboard, all through hud.gd's slots.

## Nature's multis get hotter each step: Battered, Double Dip, Triple Fry,
## Fish Supper, Feeding Frenzy, Monster Catch (and sprees, the hottest).
const HEAT := [Color(0.95, 0.95, 0.9), Color(1.0, 0.82, 0.3), Color(1.0, 0.6, 0.2),
		Color(1.0, 0.38, 0.18), Color(0.95, 0.2, 0.35), Color(0.85, 0.25, 0.95)]
## Nature's scoreboard columns: BEST MULTI is the longest chain (x3: a Triple
## Fry), BEST SPREE the most battered fish without slowing.
const HEADINGS := ["POINTS", "BATTERED FISH", "PEARLS", "BEST MULTI", "BEST SPREE", "PERFECT", "TOP KM/H"]
## Nature's scoreboard panel colour (there are no teams: everyone's on one).
const BOARD_COLOR := Color(0.15, 0.55, 0.62)

var run: NatureRun
var _hud: Node


func _init(nature_run: NatureRun) -> void:
	run = nature_run
	restart_hint = "reset"
	camera_word = "fish"
	has_board = true
	joined_hint = "D-pad left/right: change class    D-pad down: species    Hold D-pad up: scoreboard    Hold Back/View: leave"
	join_hint = "Back/View on another controller: join    "


func attach(hud: Node) -> void:
	_hud = hud
	run.battered.connect(_on_battered)
	run.school_fish_battered.connect(func(attacker: FishController, _school: School, _at: Vector3) -> void:
		_on_battered(attacker, null))
	run.awarded.connect(_on_award)
	run.pearl_collected.connect(func(by: FishController) -> void:
		var own: bool = by == _hud.fish or not is_instance_valid(by)
		_hud.feed_add("PEARL  +1" if own else "%s:  PEARL  +1" % _hud.name_of(by).to_upper(), Pearl.GLOW))


func live() -> bool:
	return is_instance_valid(run)


## Battered fish, points and pearls (the team's, then your own, in co-op), and the chain bar.
func update_slots(hud: Node) -> void:
	var fish: FishController = hud.fish
	var score := run.score_of(fish)
	if run.players.size() > 1:
		hud.course_text = "Team  %d fish  %d pearls    ·    You  %d fish  %d pts" % [run.battered_fish, run.pearls,
				run.rules.battered_by(fish), score.points]
	else:
		hud.course_text = "Battered fish  %d    Points  %d    Pearls  %d" % [run.battered_fish, score.points, run.pearls]
	hud.chain_bar.show_chain(score.chain_left / maxf(score.settings.multi_window, 0.01), score.chain,
			HEAT[clampi(score.chain - 1, 0, HEAT.size() - 1)])


## The banner on your own batteries (and your being battered).
func _on_battered(attacker: FishController, victim: FishController) -> void:
	var fish: FishController = _hud.fish
	if victim == fish:
		_hud.show_banner("BATTERED!  Respawning...")
	elif attacker == fish:
		_hud.show_banner("BATTERED!  %s" % _hud.speed_text(run.last_battery_speed_of(fish)))


## Nature's points: a feed line for each, and the splash for a multi (from a
## Double Dip up, hotter each step) or a spree milestone.
func _on_award(event: Dictionary) -> void:
	var color: Color = HEAT[clampi(event.get("chain", 1) - 1, 0, HEAT.size() - 1)]
	var by: Variant = event.get("by")
	if is_instance_valid(by) and by != _hud.fish:
		# A teammate's: a feed line with their name, the splash is theirs.
		_hud.feed_add("%s:  %s  +%d" % [_hud.name_of(by).to_upper(), event.title, event.points], Color(color, 0.85))
		return
	match event.type:
		NatureScore.MULTI:
			_hud.splash.play("%s!" % event.title, "x%d" % event.chain, "+%d" % event.points, color, 1.2 + 0.15 * event.chain)
		NatureScore.SPREE:
			color = HEAT[-1]
			_hud.splash.play("%s!" % event.title, "%d battered fish without slowing" % event.spree, "+%d" % event.points, color, 2.2)
	_hud.feed_add("%s  +%d" % [event.title, event.points], color)


## Nature's scoreboard, held up like the others: every player in the run (most
## points first), the team's battered fish on the plate, and the run's time,
## pearls and shared batteries underneath. Each player holds their own.
func update_board(hud: Node) -> void:
	var fish: FishController = hud.fish
	var board: Node = hud.board
	var input: PlayerInput = fish.input_source if fish and fish.input_source else PlayerInput.everyone()
	board.shown = not is_instance_valid(hud.replay) and input.pressed("show_scoreboard")
	if not board.shown:
		return
	board.headings = HEADINGS
	board.title = "RUN STATS"
	board.bars = []
	var whole := floori(run.elapsed)
	var footer := "TIME  %d:%02d    ·    PEARLS  %d" % [whole / 60, whole % 60, run.pearls]
	if run.players.size() > 1:
		footer += "    ·    SHARED BATTERIES  %d" % run.rules.shared_batteries
	board.footer = footer
	var rows := []
	for player: FishController in run.players:
		if not is_instance_valid(player):
			continue
		var score := run.score_of(player)
		rows.append({"name": hud.name_of(player), "focus": player == fish, "values": [
			score.points, run.rules.battered_by(player), run.rules.pearls_of(player),
			"x%d" % score.best_chain if score.best_chain > 0 else "-", score.best_spree, score.perfect,
			roundi(score.top_speed * 3.6)]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.values[0] > b.values[0])
	board.teams = [{
		"name": "Team" if rows.size() > 1 else "This run",
		"score": run.battered_fish,
		"color": BOARD_COLOR,
		"rows": rows,
	}]
