# Plan: Competitive Nature (1v1 in the Ocean)

## Context
Nature currently has one mode, a free play: the player strides Extra Swishy after a calm target fish (`NatureRun` + `WanderBot`), and ramming it fast enough demolishes it.

Next is a **1v1 Nature match** against a **hostile** fish:
- The opponent has the same mechanics as the player by default: the same Nature tuning, Extra Swishy strides, bow wave and no boost. It gets no shortcuts.
- The first opponent is a **basic** difficulty bot.
- A match lasts **5 minutes**.
- **A demolition counts as a goal.**
- **Points** are awarded for **close calls**, **dodges** and **perfect rhythm**.
- After a demo, both fish go back to their starting positions, as at a kickoff.

Mode name: **Hunt** (see Decisions).

## Implementation status (2026-10-16)
All phases are implemented and pass headless probes. A build is ready for manual testing.

**Files:**
- **New scripts:**
  - `scripts/hunt_match.gd` (`HuntMatch`)
  - `scripts/hunter_bot.gd` (`HunterBot`)
  - `scripts/bot_difficulty.gd` (`BotDifficulty.basic()`)
  - `scripts/style_points.gd` (`StylePoints`)
- **New probes:** `tests/hunt_probe`, `tests/hunter_bot_probe`, `tests/style_points_probe`.
- **Changed:**
  - `main.gd`: the `HUNT` mode and `NATURE_MODES`. Switching straight from Nature to Hunt ends the run and shows Hunt's card.
  - `hud.gd`: scorebug, points feed, demo splash, scoreboard and replay overlay.
  - `broadcast_ui.gd`: StatsBoard headings and replay overlay labels can now be set.
  - `goal_replay.gd`: demolition replays (`victim`, `in_arena`, `explosion_radius`, an impact camera).
  - `ocean.gd`: `boundary_radius` fog shift.
  - `README.md`.

**Where the build differs from the plan above:**
- **Kickoff lanes are parallel.** Each fish faces straight down its own lane (the other team's way), offset sideways or diagonally. They don't face the centre, which would aim both at the same point and make every kickoff a head-on joust.
- **The match node is `HuntMatch`**, not `NatureDuel`.
- **How the bot strides and steers.** It flicks the stick across for 3 physics ticks per stride (one neutral tick, then two across) and lets it spring back, rather than holding each sweep. Nature's `stride_steer_smoothing = 0` means held sweeps steer the fish as hard as they push, and a held sweep swung the bot ±45° off its line. Between flicks the stick steers:
  - with turn-rate damping;
  - aimed off for the bot's own sideways drift;
  - using the full stick wherever that can't start a stride.
- **The bot has a fourth state, *commit*.** When it's fast and close, it lets go of the throttle (so nothing strides) and lines up the ram with the full stick.
- **The bot notices threats from 20 m** (the plan didn't fix a range). When it evades, it keeps striding while it turns.
- **Dodges count if pressed up to 0.6 s before a threat starts**, not only during it.
- **Results.** The scoreboard (held, or up by itself at the end) shows POINTS, DEMOS, CLOSE, DODGES, PERFECT, BEST RUN and TOP KM/H. There's no separate results card.

**Open items for tuning:**
- Basic's numbers (`BotDifficulty`).
- Point values and thresholds (`StylePoints` consts).
- `KICKOFF_DISTANCE` / `KICKOFF_LAYOUTS`, `ARENA_RADIUS`, and the boundary push.
- These are code constants, not tuning panel exports, for now.

## Existing pieces to reuse
- **`NatureRun`** (`scripts/nature_run.gd`) is the template for an Ocean match node:
  - `setup(ocean, player)`;
  - spawning a second fish from `FISH_SCENE`;
  - `Match1v1.copy_tuning(player, other)`;
  - `_announce_teleport` so cameras snap;
  - `Explosion.spawn`;
  - `demolish()` / `revive()`;
  - the `LEASH` idea.
- **`Demolition.hits(attacker, victim, min_speed)`** (`scripts/demolition.gd`): the demo test. The bow wave already counts as the front, so it works in both directions as is.
- **`Match1v1`** (`scripts/match_1v1.gd`):
  - `MATCH_TIME = 300` and the clock, overtime and `_time_up` / `_finish_match`;
  - the countdown (`COUNTDOWN_TIME`, `GO_TIME`, `controls_locked`);
  - `kickoff()`;
  - the `stat_event` / `_announce` pattern, which the HUD feed and stats read;
  - the `match_over` signal.
- **`main.gd`**:
  - `MODES`, `MATCH_MODES`, `MODE_ENVIRONMENTS`;
  - the match card (`_match_card_text`);
  - `_start_match` dispatch;
  - `_use_nature_tuning`, which currently checks `current_mode == NATURE` and must also cover the new mode;
  - `reset_play` / `_reset_label`;
  - `set_character`;
  - `_end_match`.
- **`SwishySwim`** (`scripts/swishy_swim.gd`):
  - `last_timing`, `last_early`, `flow`, `strides`;
  - `SWEET_SPOT` (0.85);
  - the `strode(timing, flow)` signal on the fish.
  - `StrideStream.color_for` already treats `timing >= SWEET_SPOT` as "perfect" (gold), so perfect rhythm uses the same threshold.
- **`WanderBot._steer_to`**: the 3D steering math (yaw/pitch from a local target, roll back upright) for a bot driving a `FishInput`.
- **HUD**:
  - `set_nature` / `set_match` (typed `NatureRun` / `Match1v1`);
  - `_on_demolished`;
  - the broadcast scoreboard and clock from the broadcast UI pass;
  - ArcadeFx (zoom, vignette, punch on a perfect stride).
- **Camera**: `_camera.ball = <opponent>` with `ball_cam = true`, as in Nature. The opponent is the fish to watch.

`FishBot` (`scripts/fish_bot.gd`) does **not** fit: it drives on a surface toward a ball. The opponent needs a new bot.

## Design

### 1. Mode and flow (`main.gd`)
- Add `HUNT := "Hunt"` to `MODES` and `MATCH_MODES`, and set `MODE_ENVIRONMENTS[HUNT] = "Ocean"`.
- Nature tuning (`presets/nature.cfg`) applies to both Nature modes. `_use_nature_tuning(current_mode in [NATURE, HUNT])`.
- Card text, e.g.: "1v1 in open water: 5 minutes. Demolish your opponent to score; they're out to demolish you too. Close calls, dodges and perfect strides earn points."
- `_start_match` dispatches to a new `_start_hunt()`. It creates a `NatureDuel`, points the camera's ball cam at the opponent, and calls `_hud.set_nature_duel(...)`.
- `reset_play` restarts the match. Its label is "Restart match", since a kickoff reset mid-match would be a free escape.
- `set_character` returns to a kickoff, as in the 1v1.

### 2. `NatureDuel` (`scripts/nature_duel.gd`, new)
It lives under the Ocean and has the same shape as `NatureRun`.

**Signals:** `fish_teleported`, `demolished(attacker, victim)`, `stat_event(event)`, `match_over(winner)`.

**Phases:** COUNTDOWN → PLAY → DEMOED (a short pause) → COUNTDOWN … → OVER. Overtime starts if the score is tied at 0:00.

**Setup:**
- Spawn the opponent fish on team 1. The player is team 0. Use team colours, never blue/orange naming.
- A random character and skin each match, from the fish models.
- `copy_tuning(player, opponent)`, so it gets exactly the player's mechanics. Unlike Nature's target, keep `swim_strokes` and the Extra Swishy style on.
- Attach a `HunterBot` (section 3).

**Kickoff (`kickoff()`):**
- Both fish `revive()` at their start transforms.
- The two fish lose their flow and stride state (`SwishySwim.reset()`) and their velocity.
- `controls_locked` is on for `COUNTDOWN_TIME` (3 s), then "GO".
- The clock is paused during the countdown, as it is after a goal in RL.
- Start positions: mirrored through the ocean spawn. Each fish is `KICKOFF_DISTANCE` (about 40 m) from the centre, with a small `KICKOFF_OFFSET` sideways (about 6 m), facing the centre.
  - The offset stops kickoffs from always being a pure head-on joust.
  - Pick at random among a few mirrored layouts, as in the 1v1's `KICKOFF_SPOTS`, so kickoffs aren't solved.

**Demo = goal:** checked every physics tick in PLAY:
- `Demolition.hits(player, opponent, demo_speed)` and the reverse.
- Use `player.nature_demo_speed` for both: the opponent has a copy, so it's the same value.
- If only one hits, the attacker's team scores. Then:
  - explosion in the victim's team colour;
  - `victim.demolish()`;
  - announce `{"type": "demo", ...}`;
  - DEMOED pause (about 2 s, so the explosion and banner read);
  - `kickoff()`.
- If both hit on the same tick (a head-on joust), the faster fish wins. An exact speed tie demos both, with no goal.

**Arena bounds:** the open ocean has no walls, so a fish could run away for good.
- Add a **soft boundary sphere** (`ARENA_RADIUS`, about 90 m) around the centre.
- Past it, a gentle steering/velocity nudge back in.
- The visible cue is a fog shift only: the water darkens or tints toward the edge.
- This replaces Nature's `LEASH` teleport, because teleporting during a match would be unfair.

**Clock:** the same rules as `Match1v1`:
- 5:00 counting down;
- the winner is decided at 0:00;
- on a tied score, more style points wins; if the points are tied too, sudden-death overtime: the next demo wins.
- Consider moving the clock and countdown into a small shared helper (`MatchClock`) instead of copying them out of `Match1v1`. Do it only if the copy turns out to be more than about 30 lines.

**End:**
- `match_over(winner)`, then a results card: goals, points, and a breakdown of close calls, dodges and perfect strides.
- Then back to the mode card ("Play again").

### 3. `HunterBot` (`scripts/hunter_bot.gd`, new): a hostile fish
It drives its fish only through `FishController.controls` (a `FishInput`), like `WanderBot`. It never touches the fish's velocity directly. This is the "same mechanics" rule: it has to *swim* with Extra Swishy strides to get fast.

**Striding:**
- Hold throttle (`stride_needs_throttle`) and sweep the stick from one side to the other.
- Time each reversal by reading its own `SwishySwim.phase` / `time_to_peak()`, plus a **timing error** taken from the difficulty settings.
- The sweep axis is left/right by default.
- **Steering while striding:** bias the sweep centre toward the wanted turn. `stride_steer_smoothing` averages the sweeps, so the bias is what steers, which is the same thing a player does.
  - Reuse `WanderBot._steer_to` for the bias direction and roll.

**Behaviour states:**
- **Hunt:** head for the player's predicted position (lead = distance / own speed, scaled by `lead_skill`). Keep striding to build flow, and commit when its speed is at or above the demo speed and it is roughly aimed.
- **Evade:** when the player is within `threat_range`, at or above the demo speed, and closing on it with its nose pointed at it:
  - turn hard across the player's line, perpendicular to it;
  - sometimes use a dodge input (jump & dodge stay on in Nature).
  - `evade_chance` sets how often it reacts at all.
- **Recover:** after a whiff or a slowdown, swing wide and rebuild flow before attacking again, so it doesn't drift at the player at low speed.
- **Kickoff:** a straight build-up of strides toward the centre.

**Difficulty:** a `BotDifficulty` Resource (`scripts/bot_difficulty.gd`), so Medium and Hard are just new resources later. The **Basic** values below are starting guesses, all tunable:

| field | Basic | meaning |
|---|---|---|
| `reaction_time` | 0.45 s | delay before it notices a change of state (a threat, the player turning) |
| `timing_error` | ±0.12 s | random error on each stride reversal relative to the peak |
| `perfect_chance` | 0.25 | chance a given reversal is aimed exactly at the peak |
| `aim_error` | 8° | random offset on its intercept heading |
| `lead_skill` | 0.3 | how much of the intercept lead it uses (0 means it chases the player's current position) |
| `evade_chance` | 0.35 | chance it reacts to a threat at all |
| `commit_speed_margin` | +3 m/s | how far over the demo speed it wants to be before it commits |

### 4. Style points (`scripts/style_points.gd`, new)
Points are a separate tally from goals.
- A per-match node watches both fish and emits `stat_event`s (`"close_call"`, `"dodge"`, `"perfect_rhythm"`). The HUD feed shows each one with a popup, e.g. "CLOSE CALL +25".
- It applies to both fish. The bot can earn points too, which also makes the system easy to probe.
- Values are exports or consts on `StylePoints`, to tune later.
- A demo is also worth +100 points to the attacker, as well as the goal, so the points tally reflects the whole game.

**Threat window:** the shared idea behind close calls and dodges. Fish A threatens fish B when all of these hold:
- A's speed is at least `demo_speed`;
- B is within `threat_range` (about 6 m);
- B is in A's front cone (`dot ≥ Demolition.FRONT`).

A threat window opens when those conditions start and closes when they end. If it closes **without a demo**:

- **Close call (B earns about +25):**
  - the closest approach during the window was under `close_call_distance` (about 2.5 m between hitbox surfaces, or the bow wave tip);
  - B did nothing special, just a near miss.
- **Dodge (B earns about +50, instead of a close call):**
  - the same near miss,
  - and B *acted* during the window: it used a dodge input, or its heading changed by more than `dodge_turn` (about 35°) while it was striding.
  - "You evaded it" is worth more than "it missed you".
- **Cooldown:** a given pair can earn at most one award per `award_cooldown` (about 2 s). This stops a fish circling another from farming points.

**Perfect rhythm:** every stride with `timing >= SwishySwim.SWEET_SPOT` is perfect, the same rule as the gold bubbles. A point for each perfect stride would make rhythm dwarf everything else (around 3 strides a second), so instead award **streaks**:
- +10 at 4 perfect strides in a row;
- +10 more every 4 after that;
- a "PERFECT RHYTHM x8" style callout.
- A non-perfect stride resets the streak.

### 5. HUD
- `set_nature_duel(duel)`:
  - the broadcast scoreboard (team 0 / team 1 goals and the clock);
  - the points tally under each name;
  - the demolition banner (the existing `_on_demolished`);
  - the countdown splash;
  - style point popups from `stat_event`.
- Alternatively, give the HUD a small common interface for "a match with a clock and a score" (`Match1v1` and `NatureDuel` both satisfy it), instead of a third `set_*` path. Decide when implementing, once it's clear how much of `set_match` carries over unchanged.
- An end-of-match results panel.
- Keep the stride cue, tail growth, bubbles and ArcadeFx as in Nature.

## Files
- **New:**
  - `scripts/nature_duel.gd`
  - `scripts/hunter_bot.gd`
  - `scripts/bot_difficulty.gd` (and `presets/bots/basic.tres` or code defaults)
  - `scripts/style_points.gd`
  - `tests/nature_duel_probe.gd/.tscn`
  - `tests/hunter_bot_probe.gd/.tscn`
  - `tests/style_points_probe.gd/.tscn`
- **Modify:**
  - `scripts/main.gd` (mode, card, dispatch, tuning, reset)
  - `scripts/hud.gd` (scoreboard, points, popups, results)
  - possibly `scripts/match_1v1.gd` (only if the clock is moved into a shared helper)
  - `scripts/ocean.gd` (boundary cue)
  - `tests/modes_probe.gd`
  - `README.md` (modes section)

## Phases
Follow the usual workflow for each phase: develop, run headless probes, build, then hand off.

1. **Match skeleton.** Mode, card, `NatureDuel` with kickoff, clock, two-way demos as goals, kickoff after a demo, overtime and results. Use a stand-in opponent (`WanderBot`) so the flow can be tested before the AI exists.
2. **HunterBot (Basic).**
   - Striding and steering through `FishInput`.
   - Hunt, evade and recover.
   - `BotDifficulty`.
3. **Style points.** Threat windows, close calls, dodges and perfect-rhythm streaks, plus HUD popups and the tally.
4. **HUD polish, the boundary and the demo replay.** Scoreboard, results panel, the fog-shift edge cue, and a short replay after each demo (see Decisions 9).
5. **Build and manual testing.** Expect tuning loops on the bot difficulty, the point values and thresholds, the kickoff distance and the arena radius.

## Verification (headless probes)
**`hunter_bot_probe`:** the bot alone, Nature tuning.
- It reaches `nature_demo_speed` within N seconds from a standstill using only its own inputs. This is the key risk, so check it first.
- Its average stride timing sits near the Basic target: worse than perfect, better than mashing.
- It demolishes a stationary player fish within T seconds of a kickoff.
- With evade forced on, it gets out of a scripted straight-line ram at least sometimes, and never when `evade_chance = 0`.
- It never writes velocity: every gain comes from strides. Assert this by checking that speed only rises while a stride has power.

**`nature_duel_probe`:**
- The card shows. Play starts the countdown, and both fish are locked until GO.
- A scripted player ram above the demo speed scores 1–0, explodes the opponent and starts a kickoff that puts both back at their start positions with flow reset.
- A slow bump doesn't score.
- A scripted bot ram scores 0–1.
- The clock is paused during the countdown. At 0:00 a tied score goes to overtime, and the next demo ends it.
- Leaving the mode restores the tuning from before.

**`style_points_probe`:**
- A scripted fast pass at 1.5 m awards a close call to the passed fish. With a sharp turn during the window, it awards a dodge instead.
- A pass at 5 m awards nothing, and a slow pass awards nothing.
- A demo awards no close call.
- The cooldown stops repeat awards.
- 4 perfect strides in a row award a streak, and a late stride resets it.

**Regression:** re-run all existing probes, especially `modes_probe`, `nature_probe`, `swishy_probe` and `match_probe`.

## Decisions (user interview, 2026-10-15)
These replace the earlier open questions. Where a section above differs, these win.
1. **Winner:** goals (demos) decide the match. If the score is tied at 0:00, **more style points wins**. Sudden-death overtime happens only if the points are tied as well.
2. **Head-on jousts:** the faster fish wins. Only an exact speed tie demos both, with no goal.
3. **Dodge:** either one counts: a dodge-button input or a sharp evasive turn (over ~35°) during a threat window. Jump & dodge stay on in Nature.
4. **Point values:**
   - close call +25;
   - dodge +50;
   - perfect-rhythm streak +10 every 4 perfect strides in a row;
   - **a demo is also worth +100 points** (as well as the goal).
5. **Kickoff:** facing each other with a small sideways offset (~40 m out, ~6 m apart), picked at random from a few mirrored layouts.
6. **Arena:** a soft boundary sphere of ~90 m that nudges fish back in. The edge is shown by **a fog shift only**: the water darkens or tints toward the edge. There is no bubble curtain or reef ring.
7. **Mode name: "Hunt".** `HUNT := "Hunt"` is used throughout the plan above. The match node can stay `NatureDuel`, or be renamed `HuntMatch` when implementing.
8. **Opponent fish:** a **random character and skin each match**, chosen from the fish models (shark, swordfish, clownfish, koi…), in team 1's colour.
9. **Demo replay: yes, in v1.** After a demo, show a short replay before the kickoff, like the 1v1's goal replays (`GoalReplay`, `REPLAY_BEFORE` / `REPLAY_AFTER`, the `goal_replays` UI setting, and skip to kickoff). This adds work to phase 4.
   - Check how tied `GoalReplay` is to the aquarium and the ball. It probably needs to accept "no ball" and the Ocean environment, and the camera should follow the attacker into the victim.
   - Add a `hunt_replay_probe` (or extend `nature_duel_probe`): a demo starts the replay, the replay ends at the kickoff, and skipping it works.
   - The DEMOED pause becomes: explosion and banner, then the replay (if enabled), then the kickoff.
