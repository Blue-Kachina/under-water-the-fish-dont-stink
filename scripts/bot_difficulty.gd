class_name BotDifficulty
extends Resource
## How well a HunterBot plays (Hunt mode). The bot swims with the same inputs a
## player has; these only set how sharp its reactions, timing and aim are.
## basic() is the first opponent; harder ones are just other values.

## How long it takes to notice what the other fish is doing (s): it acts on
## where it saw it this long ago.
@export_range(0.0, 2.0, 0.01) var reaction_time := 0.45
## Spread of its stride reversals around each stride's peak (s, one standard deviation).
@export_range(0.0, 0.5, 0.005) var timing_error := 0.12
## Chance a reversal lands right on the peak anyway (a perfect stride).
@export_range(0.0, 1.0, 0.01) var perfect_chance := 0.25
## Random error on its heading when it goes for you (degrees), re-rolled every so often.
@export_range(0.0, 45.0, 0.5) var aim_error := 8.0
## How much it leads you (0: swims at where you are, 1: at where you'll be).
@export_range(0.0, 1.0, 0.01) var lead_skill := 0.3
## Chance it reacts at all when you come at it fast.
@export_range(0.0, 1.0, 0.01) var evade_chance := 0.35
## Chance an evasion uses a dodge (jump, then jump with the stick) instead of
## only turning away. A dodge breaks its stride chain, as it does yours.
@export_range(0.0, 1.0, 0.01) var dodge_chance := 0.25
## How far over the batter speed it wants to be before it goes in close (m/s).
@export_range(0.0, 15.0, 0.1) var commit_speed_margin := 3.0


## The first opponent: slow to react, loose timing, rarely gets out of the way.
static func basic() -> BotDifficulty:
	return BotDifficulty.new()
