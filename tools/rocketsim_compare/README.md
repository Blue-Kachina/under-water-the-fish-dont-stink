# RocketSim parity harness

Runs the same scripted inputs through [RocketSim](https://github.com/ZealanL/RocketSim) (a validated
re-implementation of Rocket League's physics) and through the game's physics, tick for tick, and
diffs the two.

```
cd tools/rocketsim_compare
uv run run.py                         # every runnable scenario (about 50 s)
uv run run.py front_flip ball_hit_centre
uv run run.py --godot PATH/TO/Godot_console.exe   # or set GODOT
```

`uv` creates `.venv` and installs `rocketsim` and `numpy` from `pyproject.toml` the first time.
Results go to `out/`:
- `report.txt`: the summary also printed to the console.
- `rocketsim.json` and `game.json`: per-tick states from each side.
- `scenarios.json`: the inputs and start states that were run.

`uv run timeline.py NAME [step_seconds]` prints one scenario from the last run side by side:
height, speed, how upright the car is, which way it faces, and surface contact.
`uv run turnline.py NAME [step_seconds]` does the same for turns and powerslides: speed, yaw
rate, heading and slip angle (between the nose and the direction of travel).

## How it works
- **`scenarios.py`** defines each scenario: a start state, then controls as segments of RL inputs
  (throttle, steer, pitch, yaw, roll, jump, boost, handbrake). Everything is in RL units and axes.
- **`run.py`**:
  1. Steps RocketSim and records the state before each tick.
  2. Writes `scenarios.json`.
  3. Runs `res://tests/physics_parity_probe.tscn` headless.
  4. Compares the results.
- **The probe** hooks `FishController.physics_tick`, which fires at the start of the fish's physics
  tick before input is sampled. That's the same point RocketSim records a state and takes controls,
  so there's no tick of lag between the two. It drives the fish through the normal input actions
  and reports states converted back to RL units.
- **Inputs are kept to one stick axis at a time.** The game reads the stick through
  `Input.get_vector`, which normalises diagonals, while RL's pitch and yaw are independent.
- **Rocket League-only rules are switched off for the run:** no boost refill, no swim strokes.

## Real Rocket League: replay segments
RocketSim is a re-implementation; replays are the real thing. `replay_segments.py` mines short
segments from converted replays, and `run.py --replays` runs RocketSim and the game from each
segment's first recorded state with its recorded inputs, scoring both against the replay.

```
cd tools/rl_replay
uv run convert_many.py "%USERPROFILE%/Documents/My Games/Rocket League/TAGame/Demos" ../../private_content/replays/converted/own
cd ../rocketsim_compare
uv run replay_segments.py                       # -> out/replay_scenarios.json
uv run run.py --replays out/replay_scenarios.json --steady --label NAME
uv run run.py --replays out/replay_scenarios.json wall_climb --sample 400 --seed 3 --label NAME
```

- **Segments:** one car alone, live play. No car within 5 m, ball 4.5 m away, no touches, no boost
  pickups (the game has no pads yet), no jumps or dodges, no teleports. Two kinds:
  - `floor_drive`: one second on the flat floor. The control group, since RocketSim and the game agree there.
  - `wall_climb`: from the floor up onto a standard Soccar side or back wall. A segment is kept
    only if the car ends flush on that wall, so non-standard arenas drop out.
- **Inputs:** replays record throttle, steer, boost and powerslide about 30 times a second. They're
  held between samples, so a segment whose inputs change carries timing error. `--steady` keeps
  only segments whose inputs never change; that's where the comparison is sharpest. On steady
  floor drives RocketSim stays within about 8 cm of real RL after a second.
- **Output:** `out/replay_report_NAME.txt` holds p50/p75/p90 errors per kind (centre of mass, velocity,
  orientation) and the segments where the game is furthest off. `out/replay_report_NAME.json`
  holds the medians and each segment's 1 s error, with which wall it ends on.
- **Data:** converted replays and the mined segments stay under `private_content/` and `out/`. They
  contain gameplay from real matches; never commit them.

## Columns
| Column | Meaning |
|---|---|
| `path` | Difference in centre-of-mass displacement: the translational dynamics. |
| `hitbox` | Difference between the visible hitbox centres. Also includes where each body's centre of mass sits, since rotation pivots about it. |
| `vel` | Velocity difference. |
| `rot` | Orientation difference. |
| `w` | Angular velocity difference. |
| `ball` / `ballv` | Ball position and velocity difference. |

## Arenas
- **`void`** scenarios use RocketSim's THE_VOID (no floor or walls) and the game's Ocean (no colliders).
- **`soccar`** scenarios (driving, jumping off the floor) need RocketSim's collision meshes. These are
  dumped from an installed copy of Rocket League and are Psyonix assets, so never commit them.
  - To enable them, put the meshes in `collision_meshes/` (gitignored) or set `RS_COLLISION_MESHES`.
  - Without them, these scenarios are skipped.
  - On the game side they run in the Aquarium Arena, which is built to RL's Soccar dimensions.

### Collision meshes (done on this machine 2026-10-10)
- **How they were extracted.**
  1. Build [RLArenaCollisionDumper](https://github.com/ZealanL/RLArenaCollisionDumper) from source.
  2. Start Rocket League **without Easy Anti-Cheat**: run `...\rocketleague\Binaries\Win64\RocketLeague.exe` directly, or use the store's "launch without anti-cheat" option. This is offline only.
  3. Go into Free Play and run the dumper from this folder with `-custommap`.
- **Why `-custommap`.** The current RL build has 10 Soccar meshes, which the tool doesn't recognise as Soccar. That flag saves them anyway, to `collision_meshes/custom_map/`. Copy them to `collision_meshes/soccar/`.
- Re-dump after RL patches that change the arena. Never commit the meshes.
- **Boost pads.** RocketSim's Soccar arena has them. Scenarios that cross them pick up boost the game doesn't, so compare speeds, not the meter.
