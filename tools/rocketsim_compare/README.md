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
