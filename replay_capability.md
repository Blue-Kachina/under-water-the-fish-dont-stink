# Rocket League Replay Capability: Research & Plan

> Status: research and design only. Nothing here is implemented yet.
> Compiled 2026-10-10 from three research passes (codebase survey, `.replay` format, RL geometry/physics) and an architecture/planning pass.
> Paths are relative to the repo root.

## Contents
1. [Summary of decisions](#1-summary-of-decisions)
2. [Current codebase snapshot](#2-current-codebase-snapshot-relevant-to-this-work)
3. [Rocket League `.replay` format reference](#3-rocket-league-replay-format-reference)
4. [Rocket League geometry & physics reference](#4-rocket-league-geometry--physics-reference)
5. [Coordinate & scale mapping](#5-coordinate--scale-mapping)
6. [Converter pipeline](#6-converter-pipeline)
7. [Playback runtime](#7-playback-runtime)
8. [Input decoupling, re-simulation & take-over](#8-input-decoupling-re-simulation--take-over)
9. ["Play like Rocket League" preset](#9-play-like-rocket-league-preset)
10. [Phased roadmap](#10-phased-roadmap)
11. [Risks & open questions](#11-risks--open-questions)
12. [Sources](#12-sources)

---

## 1. Summary of decisions

| Topic | Decision |
|---|---|
| Parsing `.replay` | **Don't write a GDScript parser.** Convert offline with **subtr-actor-py** (Python, MIT, v1.4.0, 2026-10-02) into our own versioned intermediate format, `*.rlreplay.json` (schema v1). A godot-rust GDExtension is a later, drop-in option. |
| Intermediate format | Columnar JSON in **RL native units and axes** (uu, left-handed Z-up), with presence and teleport masks, events and segments. A packed float32 binary v2 comes later if size or load time demand it. |
| Units | 1 uu = 1 cm. One `RLSpace` utility converts to Godot: `pos = Vector3(x, z, y) * 0.01 * k`. |
| World scale **k** | **Decided: k = 1, true RL size (1 uu = 1 cm).** Sizes were switched on 2026-10-10 (see §2.1). Speeds and accelerations are still on the old 2× tuning and must come down to RL's (§9) before our physics can match replays. The k machinery stays only as an optional knob. |
| Where replays play | **In the Aquarium Arena itself**, which is now the RL Soccar arena: 81.92 × 20.44 × 102.4 m, 45° corners, RL goals. No separate "RL Stadium" is needed. |
| Ghosts | A lightweight `ReplayCar` (`Node3D` plus a shared fish visual and a hitbox overlay), not a frozen `FishController`. Used for kinematic playback and as the reference when re-simulating. |
| Interpolation | Cubic Hermite on position using replicated velocities, slerp on rotation, no interpolation across teleports. |
| Re-simulation | **Yes, without recorded button presses.** Once our sizes and physics match RL, we recover each player's inputs from the motion itself (inverse dynamics, constrained by the replay's boost/jump/dodge flags and throttle/steer bytes). We then drive our physics with those inputs, plus closed-loop correction and re-syncs at touches and kickoffs. Validation is tiered: RocketSim, then replays, then side-by-side video. See §8. |
| RL feel | A **preset system** in the debug panel, plus an `RLPreset` table that generates every export's RL value at scale k. Missing mechanics (boost pads, supersonic/demos, match flow, multiple players) are added in later phases. |

---

## 2. Current codebase snapshot (relevant to this work)

- **Engine:** Godot 4.7, Jolt Physics, **120 Hz physics** (same as RL), physics interpolation on. GDScript only. `native/` contains an unused C++ godot-cpp GDExtension scaffold.
- **`FishController`** (`scripts/fish_controller.gd`) is a `RigidBody3D` with mass 1 and `gravity_scale` 0. All motion is set directly on `state.linear_velocity` / `angular_velocity` in `_integrate_forces`, so every tunable is mass-independent.
  - **Already RL-faithful (RocketSim values):** air-control torque and damping, max angular velocity 5.5, flip torques (260 side / 224 forward), 0.65 s flip with pitch lock +0.3 s, flip Z-damp, flip cancel, jump minimum hold 0.025 s, dodge deadzone 0.5, and the dodge direction maths.
  - **Surface driving (uncommitted work in progress):** `rl_surface_mechanics`, with a throttle curve, brake, coast, ground boost, sticky force and `RL_STEER_ANGLE_CURVE`. Its values are already RL × 2: `ground_max_speed 28.2` = 14.1 × 2, `surface_stick 13` = 6.5 × 2, `UU_PER_SPEED = 50`.
  - **Water mechanics, not RL:** water drag, buoyancy (−7.5 m/s²), swim strokes, and the air numbers (jump 10.2, hold 51, boost accel 10, max_boost_speed 75).
  - **Input:** stored in public `input_*` fields, but `_sample_input()` is hard-wired to `Input` and overwrites them every tick.
  - **Hitbox:** BoxShape3D 1.07 × 0.7 × 1.5 m (Octane proportions), resizable via exports, with no offset. The nose points along −Z.
- **`Ball`** (`scripts/ball.gd`, `scripts/ball_settings.gd`) is a `RigidBody3D` driven by a `BallSettings` resource.
  - Settings: radius 2.5, mass 0.75, bounciness 0.75, gravity 15, max speed 200.
  - It implements the RL extra hit impulse, with `HIT_CURVE` in m/s = uu/s × 0.02 (i.e. k = 2). Fish–ball restitution is 0, matching RocketSim.
- **Environments** (`main.gd`): Obstacle Course, Ocean, and Aquarium Arena (90 × 50 × 130 m, Blue goal at +Z, goal-line rule, 3 s reset). Each is built procedurally in code. There is no match clock, no kickoff spawns, and only one fish.
- **Config:** `debug_panel.gd` reflects every `@export_range` on fish, camera and BallSettings, and saves/loads a ConfigFile (`[fish] [camera] [ball]`). There are no presets.
  - **Gotcha:** values are applied through `HSlider.value`, which snaps to `step`. For example, 33.33 becomes 33.5. Several RL values at k = 2 also fall outside the current ranges (`buoyancy` −13, `max_reverse_speed` 46).
- **Camera** (`follow_camera.gd`): chase cam and ball cam. `fish` is typed `FishController` (`hud.gd` has the same typing).
- **Tests:** headless probe scenes in `tests/`, run as `Godot_console.exe --headless --path . res://tests/X.tscn`. They drive input via `Input.action_press`.
- **Missing:** no JSON or binary parsing, recording, replay, networking, or multi-player code.

### 2.1 Update 2026-10-10: true Rocket League sizes

**What changed:**
- **Aquarium Arena** (`scripts/aquarium_arena.gd`):
  - Rebuilt to RL Soccar dimensions:
    - walls at x = ±40.96 and z = ±51.2, ceiling at 20.44;
    - 45° vertical corners (`CORNER_PLANE` \|x\|+\|z\| = 80.64);
    - 2.56 m rounded floor and ceiling ramps (`EDGE_RADIUS`).
  - The shell is now swept around the octagonal footprint (`_footprint_ring`, `_wall_profile`).
  - Goals are 17.8551 × 6.42775 × 8.8 m.
  - The fish spawns at RL's back kickoff spot (z = 46.08).
  - New `AquariumArena.distance_outside(p)` helper.
- **Goal** (`scripts/goal.gd`): RL goal size by default. The posts now sit just outside the mouth, so the opening is the full RL width.
- **Ball:** default radius 0.9125 m (`scripts/ball_settings.gd`).
- **Fish:**
  - Hitbox defaults to the Octane: 1.205 × 0.387 × 0.867 m (L × H × W).
  - `Visual` is scaled from `VISUAL_BODY_SIZE` so the fish's body fills whatever the hitbox is (`scripts/fish_controller.gd`, `scenes/fish.tscn`).
- **Probes:** `aquarium_probe` and `surface_probe` were updated for the new geometry.

**Probe results:**
- `hitbox_probe` passes: the fish rests at y = 0.193.
- `surface_probe` passes: the fish drives floor → wall → ceiling and carries the ball.
- `aquarium_probe` keeps the fish inside the shell (0.00 m outside), but its boosted kickoff hit no longer scores.

### 2.2 Update 2026-10-10: Rocket League physics values (roadmap phases 0 and 1)

**What changed:**
- **Fish defaults:** all now RocketSim values at 1×:
  - air throttle 0.67 m/s², air boost 10.58, speed cap 23;
  - boost drain 33.33 %/s (regen 10 %/s stands in for boost pads until they exist);
  - no water drag, gravity −6.5 (`buoyancy`), wall bounce and friction 0.3;
  - jump 2.917 + hold 14.58 m/s², dodge 5.0, double-jump window 1.25 s;
  - ground: 14.1 max, 16 accel, 35 brake, 5.25 coast, boost 9.92, max boost 23, sticky force 6.5.
- **Constants:** `UU_PER_SPEED` 100, `GROUND_WHEELBASE` 0.85, `RL_AUTOFLIP_IMPULSE` 2.0.
- **Ball:** mass 0.167 (1/6 of the fish), bounciness 0.6, friction 0.35, max speed 60, spin cap 6 rad/s, gravity 6.5, no spin drag. `HIT_CURVE` is now in RL m/s (0/5/23/46).
- **Camera:** RL defaults: 2.7 m back, 1.0 m up, aim tilted about 3° down, FOV 110.
- **Presets:** the debug panel has a **Preset** row. "Rocket League (defaults)" restores the defaults. **Water** (`presets/water.cfg`) is the original underwater tuning, applied over the defaults. Applying values no longer snaps to slider steps.
- **Probes:** the movement and momentum probes test underwater mechanics, so they apply the Water preset. The aquarium, surface and hitbox probes were retimed for RL speeds and gravity.

**Measured against RL in the probes:**

| Check | Result |
|---|---|
| Throttle-only top speed | 14.10 m/s (RL 1410 uu/s) |
| Boost top speed | 23.0 m/s |
| 0 → 10 m/s on throttle | 1.00 s |
| Turn rate | 2.05 rad/s at 13.6 m/s (RL curvature table gives about 2.2) |
| Vertical speed 0.25 s after a full-hold jump | 4.18 m/s (hand calculation 4.21) |
| Ball fall after 1 s | 6.35 m/s, height matches drag-adjusted gravity |
| Roll and flip timings, half-flip, flip cancel, Z-damp | identical to the RL reference, tick for tick |
| Back-spot boosted kickoff | reaches the ball after about 3.0 s, scores at 4.29 s |
| Driving | floor → wall works; ball carries on the roof |

**Still approximate:** dodge-impulse speed scaling, the 0.62 jump scale in the first 0.025 s, the lateral-friction curve, boost pads, supersonic, demos. With the Water preset, ground steering and the hit curve now use RL's 1× tables, so the old feel isn't byte-identical.

**Known mismatches from the resize, now resolved:**
- ~~**Speeds still 2× RL**~~ (§2.2)
- ~~**Ball mass and bounciness**~~ (§2.2)
- ~~**The ball keeps rescoring.**~~ **Fixed:** the arena now skips goal checks while `Ball.respawn_pending` is true.
- **Two `aquarium_probe` scenarios still assume the old sizes:** "hit from below" now strikes the top of the smaller, sinking water ball, and the notch-cheek run bounces away. Retune them during the RL-physics pass.
- ~~**Camera distance and height**~~ now RL's defaults (§2.2).


### 2.3 Update 2026-10-10: ride height (belly collider, done by the parallel session)
- **Settings** (Hitbox group in `fish_controller.gd`):
  - `belly_height` 0.184 m: the Octane body rides 18.4 uu off the ground. Setting 0 disables the belly.
  - `belly_length` 1.125 and `belly_width` 0.70: the wheel footprint, about 112 × 70 uu.
- **Collider:** a "Belly" `CollisionShape3D` is created in code under the hitbox box. `show_hitbox` draws it as well.
- **Effect:**
  - The fish now rests with its centre at 0.377 m (0.184 + 0.193), so the hitbox sits at RL's height.
  - Ball-touch heights on the ground now line up with RL's.
- **Probes:** `surface_probe` spawn heights were raised to 0.6 m.

---

## 3. Rocket League `.replay` format reference

### 3.1 Outer layout (little-endian)
```
u32 header_size, u32 header_crc      (CRC-32 poly 0x04C11DB7, XorIn 0x10340DFE, XorOut 0xFFFFFFFF)
header:
  u32 engine/major_version (868), u32 licensee/minor_version
  u32 net_version                    only if major > 865 && minor > 17
  str "TAGame.Replay_Soccar_TA"
  properties: (name, type, u64 size, value)* terminated by "None"
u32 content_size, u32 content_crc
body:
  levels[str], keyframes[(f32 time, i32 frame, i32 bit_pos)],
  network_stream (u32 len + bit-packed bytes),
  debug_info, tick_marks[(desc, frame)], packages[str],
  objects[str], names[str], class_indices[(class, idx)],
  net_cache[(object_ind, parent_id, cache_id, [(object_ind, stream_id)])]
```
- Strings are an i32 length followed by bytes; a negative length means UTF-16.
- Header property types: Bool, Byte, Array, Float, Int, QWord, Name, Str, Struct.
- Useful header properties: `TeamSize`, `Team0Score`, `Team1Score`, `Goals[{frame, PlayerName, PlayerTeam}]`, `PlayerStats`, `NumFrames`, `RecordFPS` (30), `MaxChannels`, `MatchType`, `MapName`, `Id`, `Date`, `BuildVersion`.

### 3.2 Network stream
Each frame:
```
f32 time, f32 delta
while bit == 1:
  actor_id (channel_bits)
  alive bit → if 0: deleted
  else new bit:
    new: [i32 name_id], 1 bit, i32 object_id, initial trajectory (Vector3i loc, i8 rotator)
    updated: while bit == 1: stream_id (per-class bit width) + attribute value (decoder chosen by attribute NAME)
```

### 3.3 Why it's hard to parse yourself
- **Not self-describing.** A `stream_id` only means something via the per-replay `net_cache` tree (walk the parent chain), and bit widths vary per class and per replay.
- **Hard-coded decoders.** Each attribute's value decoder is looked up by attribute name in a hard-coded table (about 650 entries in boxcars). One unknown attribute after a patch makes the rest of the stream unreadable.
- **Frequent breakage.** Patches break parsers several times a year (recent examples: `DodgesRefreshedCounter`, `PickupTimer`, `LanMatchGUID`, S24 honor duels).
- **Compressed values:**
  - **Vector3i:** a size header with bias encoding; Vector3f = Vector3i / 100.
  - **Quaternion (net_version ≥ 7):** "smallest three" encoding with 18 bits each.
  - **Legacy (< 7):** the "quaternion" is really (pitch, yaw, roll) / π.
  - **Scale (< 5):** location × 100, velocity × 10.

### 3.4 Actors and attributes needed for playback
| Purpose | Object / attribute |
|---|---|
| Ball | `Archetypes.Ball.Ball_Default` (others include Puck, BasketBall, CubeBall) |
| Car | `Archetypes.Car.Car_Default` |
| Rigid body | `TAGame.RBActor_TA:ReplicatedRBState` → `{sleeping, location (uu), rotation quat, linear_velocity (uu/s), angular_velocity}`; velocities are null while sleeping |
| Car → player | `Engine.Pawn:PlayerReplicationInfo` (ActiveActor → PRI) |
| Component → car | `TAGame.CarComponent_TA:Vehicle`; components are Boost, Jump, DoubleJump, Dodge, FlipCar |
| Component active | `TAGame.CarComponent_TA:ReplicatedActive`: **odd value = active** |
| Boost | `CarComponent_Boost_TA:ReplicatedBoostAmount` (older) or `ReplicatedBoost{boost_amount}` (newer). Raw 0–255, 85 at kickoff, **updated only on discrete changes**, so drain must be simulated (about 33.3 %/s while active) |
| Inputs (cosmetic) | `Vehicle_TA:ReplicatedThrottle`, `ReplicatedSteer` (bytes, probably 128 = neutral), `bReplicatedHandbrake` |
| Player | `Engine.PlayerReplicationInfo:PlayerName`, `:Team`, `TAGame.PRI_TA:ClientLoadouts` (body product id: 23 Octane, 403 Dominus, …) |
| Game state | `GameEvent_Soccar_TA:SecondsRemaining`, `bOverTime`, `ReplicatedScoredOnTeam`; `GameEvent_TA:ReplicatedStateName` (an index into `names[]`, e.g. `"Countdown"`, `"PostGoalScored"`, `"ReplayPlayback"`), `ReplicatedGameStateTimeRemaining` (kickoff 3-2-1) |
| Events | `Car_TA:ReplicatedDemolish*` (attacker/victim), `Ball_TA:HitTeamNum`, `Engine.TeamInfo:Score`, header `Goals[].frame` |

### 3.5 Existing tools (status checked 2026-10)
| Tool | Lang | License | Status | Output |
|---|---|---|---|---|
| **subtr-actor** | Rust + Python (`subtr-actor-py`) + npm WASM | MIT | **Very active** (v1.4.0, 2026-10-02) | Per-frame normalised and interpolated ball/player rigid bodies, boost (simulated), jump/dodge/powerslide flags, throttle/steer, events (goal/demo/touch/boost pad), metadata frames, NDArray with quaternion column sets, `hitbox_family_for_body_id()` |
| **boxcars** / **rrrocket** | Rust lib / CLI | MIT | Active (v0.12.0 / v0.11.6, 2026-09-28) | Raw JSON of the network stream (`rrrocket -n`); you do your own actor tracking |
| RocketLeagueReplayParser (jjbott) | C# | MIT | Active | JSON |
| rl-web (rl.nickb.dev) | TS + WASM boxcars | MIT | Active | Browser JSON |
| @rlrml/player | three.js | MIT | Active | Reference playback implementation worth reading |
| CPPRP | C++ | MPL-2.0 | Stale (2025-09) | — |
| rattletrap | Haskell | MIT | **Archived** | — |
| carball | Python | Apache-2.0 | **Dead** (2020) | — |
| ballchasing.com API | REST | — | Active | **No frame data**: stats only. Useful for *downloading* `.replay` files (rate limited) |

subtr-actor's JSON `ReplayData` shape:
- `frame_data{ ball_data{frames}, players[(id, {frames})], metadata_frames }`, where `PlayerFrame.Data` = `{rigid_body, boost_amount, boost_active, powerslide_active, jump_active, double_jump_active, dodge_active, player_name, team, camera, input{throttle, steer, dodge_impulse, dodge_torque}}`.
- Plus `goal_events`, `demolish_infos`, `touch_events`, `boost_pad_events`, `replay_tick_marks`.

### 3.6 Data-quality concerns
- **Timing:** about 30 Hz with jittery deltas. Always interpolate on `time`, never on frame index.
- **Sparse updates:** rigid-body updates are sparse and sleeping bodies send no velocities, so hold the last state.
- **Actor ids are reused** after goals, demos and respawns. Key players by PRI or name, never by car actor id.
- **Teleports:** kickoffs and respawns teleport cars. Don't interpolate across a jump faster than about 4600 uu/s.
- **Goal replays:** the in-match goal replays (`ReplayPlayback` state) are embedded in the stream. Strip or flag them.
- **Clocks:** replay time ≠ game time. Drive the clock from `SecondsRemaining`, which updates about once per second.
- **Angular velocity units are uncertain** (rad/s, ×10 or ×100). Verify that the ball's max |ω| ≈ 6 rad/s.

---

## 4. Rocket League geometry & physics reference

Units: **1 uu = 1 cm**. RocketSim values are preferred, being read from the game.

### 4.1 Coordinates
- **Axes:** **+X = left** (seen from blue looking toward orange), **+Y = toward the orange goal** (blue defends −Y), **+Z up**. The frame is **left-handed** (Unreal).
- **Car local frame:** X forward, Y right, Z up.
- **Rotators:** Unreal integer rotators use 65536 = 360°. Yaw 0 points along +X; blue's kickoff yaw is +π/2.
- **Rotation matrix** (cp = cos pitch, etc.):
  - forward = (cp·cy, cp·sy, sp)
  - right = (cy·sp·sr − cr·sy, sy·sp·sr + cr·cy, −cp·sr)
  - up = (−cr·cy·sp − sr·sy, −cr·sy·sp + sr·cy, cp·cr)

### 4.2 Soccar arena
| Item | uu | m (k=1) |
|---|---|---|
| Side walls | x = ±4096 | ±40.96 |
| Back walls / goal line plane | y = ±5120 | ±51.20 |
| Ceiling | 2044 (measured; collision plane 2048) | 20.44 |
| 45° corners | plane \|x\|+\|y\| = 8064 (legs 1152) | 80.64 |
| Wall/floor ramp height | ~256 (exact curve radius unknown) | 2.56 |
| Goal half-width | 892.755 (full 1785.51) | 8.93 (17.86) |
| Goal height | 642.775 | 6.43 |
| Goal depth | 880 (back of net y = ±6000) | 8.80 |
| Goal scored | \|ball.y\| > 5124.25 + 91.25 = 5215.5 | 52.155 |

**Kickoff spawns.** Car z = 17. Orange positions are blue's with x and y negated, and yaw + π.

| Slot | Blue (x, y, yaw) |
|---|---|
| Right corner | (−2048, −2560, ¼π) |
| Left corner | (2048, −2560, ¾π) |
| Back right | (−256, −3840, ½π) |
| Back left | (256, −3840, ½π) |
| Far back | (0, −4608, ½π) |

**Demo respawns:** (±2304, −4608) and (±2688, −4608), yaw ½π, z = 36. Respawn takes 3 s.

**Boost pads:**
- **Big pads:** 6 of them, giving 100 boost, respawning in 10 s, at z = 73: (±3584, 0) and (±3072, ±4096).
- **Small pads:** 28 of them, giving 12 boost, respawning in 4 s, at z = 70: (0, ±4240), (±1792, ±4184), (±940, ±3308), (0, ±2816), (±3584, ±2484), (±1788, ±2300), (±2048, ±1036), (0, ±1024), (±1024, 0).
- **Pickup:** triggered by the car's centre of mass. RocketSim uses a cylinder of radius 208 (big) / 144 (small) and height 95. Sources disagree on the height.

### 4.3 Ball
| Item | Value |
|---|---|
| Radius | 91.25 uu (RLBot's older 92.75); rest height 93.15 |
| Mass | 30 (car 180 → ratio 1:6); inertia 0.4·m·r² |
| Max speed | 6000 uu/s |
| Max angular velocity | 6.0 rad/s |
| Gravity | −650 uu/s² |
| Drag | 0.03 (linear damping; RLU: a = −0.0305·v) |
| Restitution / friction vs world | 0.6 / 0.35 |
| Car-ball contact | restitution 0, friction 2.0, **plus the Psyonix extra impulse** (below) |

```
dv = min(|v_ball - v_car|, 4600)
n  = p_ball - p_car;  n.z *= 0.35;  n = normalize(n)
n  = normalize(n - 0.35 * dot(n, car_fwd) * car_fwd)
v_ball += n * dv * s(dv)       # s: 0→0.65, 500→0.65, 2300→0.55, 4600→0.30 (piecewise linear)
```
The impulse fires at most once per two ticks and is not applied back to the car.

### 4.4 Car hitboxes (RocketSim; all mass 180)
| Preset | L × W × H (uu) | Offset fwd, up (uu) | Example bodies (product id) |
|---|---|---|---|
| Octane | 120.507 × 86.699 × 38.659 | 13.876, 20.755 | Octane 23, Fennec 4284, Takumi 402, Backfire 21 |
| Dominus | 130.427 × 85.780 × 33.8 | 9.0, 15.75 | Dominus 403, Dominus GT 1018, Masamune 1171 |
| Plank | 131.32 × 87.170 × 31.894 | 9.009, 12.094 | Batmobile 803, Paladin 24, Mantis 1691 |
| Breakout | 133.992 × 83.021 × 32.8 | 12.5, 11.75 | Breakout 22, Breakout Type-S 1416, Cyclone 3031 |
| Hybrid | 129.519 × 84.688 × 36.659 | 13.876, 20.755 | Endo 1624, X-Devil 28, Venom 31 |
| Merc | 123.22 × 79.210 × 44.159 | 11.376, 21.505 | Merc 30, Nomad 7336 |

- The offset is the hitbox centre relative to the centre of mass.
- Halfway Dead's spreadsheet values are about 2.5 uu smaller on each axis; use RocketSim's for physics.
- The full body-id → family table is in rlgym-tools `car_bodies.py` and subtr-actor.

### 4.5 Car physics
| Item | Value (uu) |
|---|---|
| Max speed / supersonic | 2300 / 2200 (supersonic holds down to 2100 for ≤ 1 s) |
| Throttle-only max | 1410; acceleration 1600 at 0 → 160 at 1400 → 0 at 1410 |
| Brake / coast | 3500 / 525 |
| Air throttle | 66.667 |
| Boost acceleration | ground 991.667, air 1058.333 |
| Boost use | 33.33 per second (full tank lasts 3 s); spawn amount 33.3; minimum burst 0.1 s |
| Jump | 291.667 instant, then 1458.333 while held for 0.025–0.2 s (×0.62 during the first 0.025 s) |
| Double jump / dodge window | 1.25 s after the jump *ends* |
| Double jump | +291.667 |
| Dodge threshold | dodge if \|pitch\|+\|yaw\|+\|roll\| ≥ 0.5, otherwise double jump |
| Dodge impulse | 500 along (−pitch, yaw + roll). With r = \|fwd speed\|/2300: side × (1 + 0.9r), back × (1 + 1.5r) × 16/15 |
| Dodge torque | side 260, forward 224; lasts 0.65 s; Z-damp × 0.65 per tick from 0.15–0.21 s; pitch lock until 0.95 s |
| Air control | torque (130, 95, 400) × 0.09587 → 12.46 / 9.11 / 38.34 rad/s²; damping (30, 20, 50) × 0.09587; max ω 5.5 rad/s |
| Turn curvature (1/uu) | 0→0.00690, 500→0.00398, 1000→0.00235, 1500→0.00138, 1750→0.00110, 2300→0.00088 |
| Sticky force | −up × 650 × mass × s, where s = 0.5 + (1 − \|up.z\|) when throttling or moving faster than 25 uu/s, else 0.5 |
| Collisions | car-world friction 0.3, restitution 0.3; car-car 0.09 / 0.1 |
| Demolition | attacker supersonic, contact on the bumper (local x > 64.5), opponents only; respawn after 3 s |

### 4.6 Rules and timing
- **Match:** 5:00. At 0:00, play continues until the ball touches the ground. Overtime is unlimited sudden death.
- **Kickoff countdown:** about 3 s (unsourced; measure it from replay metadata).
- **Goal reset:** about 3 s, then a skippable replay.
- **Physics:** 120 Hz.

---

## 5. Coordinate & scale mapping

### 5.1 `RLSpace` (new file: `scripts/rl/rl_space.gd`)
```gdscript
class_name RLSpace
## Rocket League (uu, left-handed, Z up) <-> Godot (m, right-handed, Y up).
static var k := 1.0                                   # world scale; 1.0 == true RL size (decided 2026-10-10)
const M_PER_UU := 0.01
const FISH_FROM_CAR := Basis(Vector3.UP, -PI / 2.0)   # car local +X (forward) -> fish nose (-Z)

static func length(uu: float) -> float:   return uu * M_PER_UU * k
static func pos(v: Vector3) -> Vector3:   return Vector3(v.x, v.z, v.y) * M_PER_UU * k   # also vel/accel
static func quat(q: Quaternion) -> Quaternion: return Quaternion(-q.x, -q.z, -q.y, q.w)
static func ang_vel(w: Vector3) -> Vector3:    return -Vector3(w.x, w.z, w.y)            # pseudovector, no k
static func car_basis(q: Quaternion) -> Basis: return Basis(quat(q))     # car frame: +X fwd, +Y up, +Z right
static func fish_basis(q: Quaternion) -> Basis: return car_basis(q) * FISH_FROM_CAR
# + inverse funcs (to_rl_pos / to_rl_quat) and kickoff_transform(slot, team)
```
- **Why the formulas are right.** Swapping Y and Z is a reflection, which turns RL's left-handed frame into a right-handed one without mirroring the arena. In Godot, when you face +Z, +X is on your left, matching RL. Conjugating a rotation by a reflection maps its axis to −M·a, which gives the quaternion formula above. Angular velocity is a pseudovector, so it also picks up the minus sign. This is the same remap subtr-actor's three.js player uses.
- **Constants:** keep them in `scripts/rl/rl_consts.gd`, all in uu (arena, goals, kickoff table, boost pads, ball, hitbox table).
- **Team orientation:** in RL Stadium, Blue defends **Godot −Z**. That is the opposite of the Aquarium, where Blue's goal is at +Z. Keep `RLSpace` canonical; don't hide a flip in the mapping.
- **Sanity checks:**
  - The blue car at (0, −4608, 17) with yaw ½π maps to `(0, 0.17k, −46.08k)` with its fish nose pointing along +Z.
  - The kickoff ball sits at y ≈ 0.927k.
  - Positive pitch raises the nose.

### 5.2 World scale k
> **Decided 2026-10-10: k = 1.** Arena, ball and hitbox are already true RL size. The remaining job is to bring every speed and acceleration down from the old 2× tuning to RL's: use the **k = 1 column** of §9.2, and replace the hard-coded 2× constants listed below with their RL values. Keeping k as a runtime knob is optional, and is only worth it if a bigger-than-RL mode is ever wanted.

- Optional: add `scripts/world_settings.gd` (`WorldSettings` Resource, `rl_scale` default 1.0). It writes `RLSpace.k` and saves as a new `[world]` debug-panel section.
- **What scales by k:** quantities with length in them (m, m/s, m/s², impulses as Δv).
- **What doesn't scale:** times, angles, angular velocities and accelerations, ratios (bounciness, friction, hit-curve factors), boost amounts, mass ratios.
- **Derive these existing constants from k:**
  - `UU_PER_SPEED → 100 / k`
  - `GROUND_WHEELBASE → 0.85 * k`
  - `Ball.HIT_CURVE`: store it in uu/s and evaluate it on `hit_speed / (0.01 * k)`

  At k = 2 these equal today's values, so behaviour doesn't change.

### 5.3 Why the arena had to become RL's shape (resolved: the Aquarium now is RL's arena)
The question is settled, because the Aquarium has been rebuilt to RL dimensions (§2.1). One convention to keep in mind: the Aquarium has Blue defending **+Z**, but RL's blue defends −Y, which `RLSpace` maps to **Godot −Z**. Replay playback must either rotate the arena's team assignment 180° (swap which goal is Blue) or apply a 180° yaw about Y to everything at load. Pick one and test it with the kickoff sanity check.

For the record, the old 90 × 50 × 130 m Aquarium could not have been used with per-axis remapping (scales x 1.10, y 2.45, z 1.27). That would have:
- **Distort arcs and gravity.** The vertical axis would be stretched 2.45× against about 1.2× horizontally, so balls float and aerials look slow-motion.
- **Break orientation vs velocity.** A non-uniform scale isn't a rotation, so cars flying at angles would visibly slide sideways relative to their nose.
- **Break contacts.** Dribbles, ball-on-roof, and wall play would hover or interpenetrate.
- **Misplace geometry.** The goals (28 × 16 m vs 17.9 × 6.4), the 45° corners, and the 50 m ceiling would all be in the wrong places.

A uniform "preview in Aquarium" (k ≈ 1.1) is acceptable at most as a labelled debug option. The RL Stadium also serves as the arena for the RL preset and for take-over.

---

## 6. Converter pipeline

### 6.1 Layout
```
tools/rl_replay/
  README.md               # venv setup, usage, schema notes, third-party license notices
  requirements.txt        # subtr-actor-py==1.4.0, numpy, jsonschema (dev)
  convert.py              # convert.py IN.replay [-o OUT.rlreplay.json] [--keep-goal-replays] [--anonymize] [--fps native|30|60]
  rlreplay/
    extract.py            # the ONLY module importing subtr-actor (isolates API churn)
    clean.py              # teleport flags, segments, ang-vel unit detection, actor->player merge
    hitboxes.py           # family -> RocketSim hitbox dims/offset (uu)
    schema.py             # build + validate v1 document
  schema/rlreplay_v1.schema.json
  make_fixture.py         # deterministic synthetic fixture (no real replay needed)
  tests/test_schema.py
  samples/.gitignore      # user replays live here; never committed
```
Check the exact subtr-actor Python entry points against the v1.4.0 docs at implementation time. Known so far: `get_replay_frames_data(path)`, and `get_ndarray_with_info_from_replay_filepath(path, global_feature_adders=[…"BallRigidBodyQuaternionVelocities"…], player_feature_adders=[…"PlayerRigidBodyQuaternionVelocities", "PlayerBoost", "PlayerJump"…], fps=…)`. Prefer the *Quaternion* feature sets over the default Euler ones.

### 6.2 Schema v1: columnar JSON in RL native units
```jsonc
{
  "format": "uwfds.rlreplay", "version": 1,
  "units": { "length": "uu", "time": "s", "angle": "rad", "axes": "rl_lh_zup", "quat": "xyzw" },
  "source": { "replay_id": "…", "map": "Stadium_P", "match_type": "Online", "team_size": 3,
              "net_version": 10, "build_version": "…", "converter": "tools/rl_replay 1.0.0",
              "parser": "subtr-actor 1.4.0", "ang_vel_scale_detected": 0.01 },
  "match":  { "record_fps": 30, "num_frames": 9876, "duration": 334.2, "score": [2, 1],
              "overtime": false, "goal_replays_removed": true },
  "players": [ { "index": 0, "name": "Blue 1", "team": 0, "is_bot": false, "body_id": 23,
                 "body_name": "Octane", "hitbox_family": "octane",
                 "hitbox": { "length": 120.507, "width": 86.6994, "height": 38.6591,
                             "offset": [13.8757, 0.0, 20.755] } } ],
  "frames": { "time": [], "game_state": [/* 0 live,1 countdown,2 post_goal,3 goal_replay,4 ended */],
              "seconds_remaining": [], "is_overtime": [], "kickoff_countdown": [] },
  "ball": { "present": [], "pos": [/*3N*/], "vel": [/*3N*/], "rot": [/*4N xyzw*/],
            "ang_vel": [/*3N rad/s*/], "teleport": [] },
  "cars": [ { "player": 0, "present": [], "pos": [], "vel": [], "rot": [], "ang_vel": [],
              "boost": [/*0..100*/], "throttle": [], "steer": [],
              "flags": [/* 1 boost,2 jump,4 double_jump,8 dodge,16 powerslide,32 supersonic,64 demolished */],
              "teleport": [] } ],
  "events": [ { "type": "goal", "time": 61.3, "frame": 1840, "player": 0, "team": 0 },
              { "type": "demo", "time": 90.1, "frame": 2703, "attacker": 2, "victim": 4 },
              { "type": "touch", "time": 12.4, "frame": 372, "player": 1 },
              { "type": "boost_pickup", "time": 20.0, "frame": 600, "player": 3, "big": true, "pad": 5 },
              { "type": "kickoff", "time": 0.0, "frame": 0 } ],
  "segments": [ { "type": "countdown", "start": 0.0, "end": 3.0 },
                { "type": "live", "start": 3.0, "end": 61.3 } ]
}
```
**Why this shape:**
- **Native units** keep the file independent of k and comparable against other tools; the conversion happens exactly once, in `RLSpace`.
- **Columnar arrays** are about 3× smaller than per-frame objects and map directly onto Godot packed arrays.
- **Native sample times:** no resampling, because Hermite interpolation runs in Godot.
- **Presence masks** stand in for NaN, which JSON can't represent.

**Cleaning done in `clean.py`** (keeps the GDScript runtime simple):
- Merge reused actor ids into per-player tracks.
- Set `teleport[i]` when:
  - the implied speed exceeds 4600 uu/s,
  - a kickoff, respawn or goal reset falls between samples, or
  - presence goes 0 → 1.
- Strip `ReplayPlayback` goal-replay segments by default.
- Auto-detect the angular-velocity scale (×1, ×0.1 or ×0.01) from the ball's 99.9th-percentile |ω| ≈ 6, and fail loudly if nothing fits.
- With `--anonymize`, replace names with "Blue 1" etc. Platform ids are never written.

### 6.3 JSON now, binary later
- **v1 JSON:** easy to debug and diff, with no custom readers needed. Estimated size: about 10k frames → roughly 8–12 MB, 2–3 MB gzipped. `JSON.parse_string` plus conversion should take under 2 s.
- **v2 `.rlreplay.bin`:** the same JSON header followed by little-endian float32 blocks, read via `FileAccess.get_buffer().to_float32_array()`. Switch when files exceed about 20 MB or loads exceed about 1 s. `ReplayData` dispatches on the file extension.

### 6.4 Optional: launching from Godot
`scripts/replay/replay_converter.gd` would run `OS.execute` / `OS.create_process` on a thread. The Python path comes from `user://replay.cfg`, defaulting to the venv. It is dev-only, and hidden when Python isn't found. Alternatively, ship a PyInstaller `convert.exe`.

### 6.5 Later: in-engine parsing
The good parsers are Rust, but the existing scaffold is C++. In-engine parsing would therefore mean a separate **godot-rust (gdext)** extension (`native-rs/rl_replay/`) wrapping subtr-actor and emitting the same v1 structure in memory.
- **Pros:** drag-and-drop `.replay` support with no Python.
- **Cons:** per-platform Rust builds, and a game rebuild for every RL patch that breaks the parser.

Defer it until v1 is stable.

---

## 7. Playback runtime

### 7.1 New files (`scripts/replay/`)
| File | Class | Role |
|---|---|---|
| `replay_data.gd` | `ReplayData` (RefCounted) | Load and validate v1. Convert once through `RLSpace` into packed arrays (keep the raw uu so it can re-convert when k changes). API: `sample_ball(t)`, `sample_car(i, t)`, `frame_at(t)` (bsearch), `meta_at(t)`, `events_of(type)`, `segment_at(t)` |
| `replay_player.gd` | `ReplayPlayer` (Node3D) | Timeline: play/pause, speed 0.1–4×, loop, seek, step, prev/next goal, skip goal replays and countdowns, camera target, `take_over(i)`. Signals: `time_changed`, `goal_reached`, `demo`, `segment_changed`. Advances in `_process`, with priority set ahead of the camera |
| `replay_car.gd` | `ReplayCar` (Node3D) | Ghost: shared fish visual, team tint, translucent hitbox box (family size and offset), boost trail from flags, `Label3D` name, demo burst. No physics |
| `replay_ball.gd` | `ReplayBall` (Node3D) | Bubble-shader sphere at `RLSpace.length(91.25)` with a trail |
| `replay_controls.gd` | `ReplayControls` (CanvasLayer) | Transport bar with a scrub slider showing goal and demo ticks, target picker, ball-cam toggle, Take over, Load… |

Also:
- **Extract `Visual` from `scenes/fish.tscn` into `scenes/fish_visual.tscn`.** Keep the child names so `FishController`'s `@onready` paths still work.
- **Move the `_process` animation into `scripts/fish_visual.gd`**, driven by (effort, slide, steer). Ghosts feed it the replay's throttle, steer, boost and powerslide.

### 7.2 Why ghosts are not a frozen `FishController`
A frozen `FishController` would still bring input sampling, a large `_integrate_forces`, a hitbox that collides with the live ball, reset side effects and camera coupling, plus six contact-monitored RigidBodies. A plain `Node3D` is cheap, has no side effects, and scrubs for free.

For "practice against the replay" later, add an optional `AnimatableBody3D` child (`sync_to_physics`) updated in `_physics_process`.

### 7.3 Interpolation
For t in [t0, t1], with dt = t1 − t0 and s = (t − t0) / dt:
- **Hold, don't interpolate,** when `teleport[i1]` is set, `present[i0] == 0`, or `dt > 0.25 s`. As a runtime safety net, also step if the implied speed exceeds `RLSpace.length(4600) × 1.5`.
- **Position:** cubic Hermite using velocities: `p0.bezier_interpolate(p0 + v0*dt/3, p1 - v1*dt/3, p1, s)`.
- **Rotation:** `q0.slerp(q1, s)`; `spherical_cubic_interpolate_in_time` is an optional upgrade.
- **Velocities and ω:** lerp (used for the HUD, trails and take-over).
- **Ghost transform:** `Transform3D(RLSpace.fish_basis(q), p)`. The hitbox child sits at `FISH_FROM_CAR⁻¹ · RLSpace.pos(offset)`.

### 7.4 HUD, segments, demos, camera
- **HUD:** add `HUD.set_replay(player)` to show `BLUE 2 – 1 ORANGE  3:41 (OT +0:32)`.
  - Score counts goal events up to t.
  - The clock comes from `seconds_remaining`, interpolated locally.
  - It shows the followed player's speed (also in uu/s), boost and flags.
  - `hud.gd`'s `fish` field needs to become untyped or nullable.
- **Segments:** goal replays are stripped by default, otherwise skipped or shown with a banner. Countdowns can optionally be skipped. The ball is hidden between a goal and the next kickoff teleport.
- **Demos:** at the demo event, spawn a burst and hide the car. It reappears at the respawn teleport.
- **Camera:** `follow_camera.gd` gets a generic `target: Node3D`, keeping `fish` as an alias so scenes and tests don't change.
  - Call `is_flipping()` only if the target has that method; for ghosts, derive it from the dodge flag.
  - Ball cam works unchanged when pointed at `ReplayBall`.
  - Add a free/broadcast overview mode.

### 7.5 Physics interpolation
- Ghosts and the replay ball are driven in `_process` from the analytic timeline with `physics_interpolation_mode = OFF`. That makes them smooth at any playback speed, with no smearing when scrubbing.
- Verify that the camera's `get_global_transform_interpolated()` returns the plain transform for a non-interpolated node, or branch on the node's mode.
- Physics-side bodies (collidable ghosts, take-over) update at 120 Hz and call `reset_physics_interpolation()` on every teleport, seek or take-over, as `Ball` and `FishController` already do.

### 7.6 Integration
- **`main.gd`:** register `"RL Stadium": preload("res://scripts/rl_stadium.gd")`. Create a `ReplayPlayer` on demand when a replay loads; loading switches to RL Stadium.
- **Debug panel:** a "Replay…" row with Load (`*.rlreplay.json` / `.bin`), Convert (`*.replay`, when Python is available) and a show-controls toggle.
- **`controls.gd`:** keyboard actions `replay_toggle`, `replay_seek_back`, `replay_seek_fwd`, `replay_next_goal`, `replay_cycle_target`.
- **Live fish:** hidden and with input ignored during pure playback.

---

## 8. Input decoupling, re-simulation & take-over

### 8.1 Pluggable input sources (`scripts/input/`)
```gdscript
class_name FishInputFrame extends RefCounted
var forward := 0.0; var reverse := 0.0; var stick := Vector2.ZERO; var roll := 0.0
var air_roll := false; var jump := false; var boost := false; var powerslide := false; var direction_lock := false

class_name FishInputSource extends RefCounted
func sample(fish: FishController, delta: float, out: FishInputFrame) -> void: pass
# HumanInputSource    – today's Input.* calls, verbatim (default)
# ScriptedInputSource – keyframed frames / Callable(t); deterministic probes
# ReplayInputSource   – per-tick inputs inferred from the replay (see 8.2) – drives re-simulation
# NullInputSource     – all released (countdown freeze, ghosts)
# AIInputSource       – later, for bots
```
- `FishController._sample_input` becomes `input_source.sample(self, delta, _frame)`, which then copies into the existing `input_*` fields.
- Jump edge detection and stroke detection stay in the controller, so every source gets identical press semantics.
- **Existing probes keep passing unchanged**, because the default source reads `Input` exactly as before.

### 8.2 Re-simulating replays with our physics (no recorded button presses needed)

> Revised 2026-10-10. An earlier draft said re-simulation was impossible because replays don't record pitch, yaw, roll, jump or boost presses. That was too pessimistic.

With matching sizes and RL-matching physics, the inputs can be **recovered from the motion**. RL's car is a simple, well-documented controller: a few inputs mapped to known accelerations, at 120 Hz. Replays record each car's full rigid-body state (position, rotation, linear and angular velocity) at about 30 Hz. They also record a lot of the controls directly:

| Control | What the replay gives us |
|---|---|
| Throttle | `ReplicatedThrottle` byte |
| Steer | `ReplicatedSteer` byte |
| Handbrake / powerslide | `bReplicatedHandbrake` |
| Boost on/off | boost component `ReplicatedActive` (odd = on) |
| Jump, double jump, dodge timing | jump, double-jump and dodge components `ReplicatedActive` |
| Dodge direction | `DodgeTorque` / `DodgeImpulse` vectors (gives −pitch, yaw + roll at the dodge) |
| Pitch / yaw / roll stick in the air | **not replicated, but it can be solved for** (below) |
| Air roll button vs. yaw | not replicated; folds into the solved roll/yaw (equivalent physics) |

#### Step 1: get the physics to match RL first
Re-simulation is only meaningful once our model *is* RL's model:
- **Sizes:** arena, ball and Octane hitbox. Done (§2.1).
- **Speeds and accelerations:** move every value to RL's (the §9.2 k = 1 column). That covers ground throttle curve, boost, jump, dodge impulses, gravity, ball max speed, drag, restitution, and the hit-impulse curve in uu/s.
- **Car mass ratio:** 6:1 car to ball.
- **Hitbox offset** relative to the centre of mass, and **ride height on wheels**. RL's hitbox floats about 18 uu above the ground on suspension. **Covered by the belly collider** (§2.3); suspension *dynamics* (springs, wheel contact) remain approximate.
- **Ground model:** RL's actual model is RocketSim's raycast wheels, lateral friction curve and sticky force (§9.3).
- **Water-only behaviour off:** drag, buoyancy and swim strokes.

#### Step 2: infer inputs per replay sample (inverse dynamics)
For each player and each replay interval [t_i, t_{i+1}] (about 33 ms, 4 physics ticks), find the inputs u that take state s_i to s_{i+1} under our physics:
- **In the air:** RL air control is linear in the stick, `Δω_local = (T·u − D(u)·ω_local)·scale·dt`, with D depending on |u| for pitch and yaw. So pitch, yaw and roll have a **closed-form solution** from the change in angular velocity (expressed in the car frame), clamped to [−1, 1]. Boost comes from its flag (and is confirmed by the change in velocity along the nose).
- **On a surface:** throttle and steer come straight from the replicated bytes, with handbrake and boost from flags. Verify them against the change in speed and in yaw rate (the steer-angle curve).
- **Jumps, double jumps and dodges:** the timing comes from component flags, refined to the exact tick by the vertical-velocity step. The dodge direction comes from `DodgeTorque`. Jump hold duration (0.025–0.2 s) comes from how long the upward acceleration lasts.
- **Discrete search where needed:** when the closed form is ambiguous (contacts, landings, flip cancels), search the small discrete action set (RLGym-style lookup table, about 90 actions) by simulating each candidate over the interval and picking the best match. This is the approach used by bot-training pipelines that learn from human replays. **rlgym-tools** has replay-to-action inference built on RocketSim; check the current API at implementation time.
- **Output:** a per-tick (120 Hz) input track per player, stored in the intermediate file as `cars[i].inferred_input` (a new schema field) and played back through a `ReplayInputSource`.

#### Step 3: drive our physics, and keep it on track
Small errors compound: car-ball collisions are chaotic, so open-loop playback will drift.
- **Closed-loop tracking.** Feed inferred inputs as feedforward plus a small corrective feedback term (PD on position, velocity and orientation error against the replay). The fish then follows the recorded path using only physically possible inputs.
- **Re-sync points.** At kickoffs, demo respawns, goal resets, and optionally every ball touch, snap the cars and ball to the replay state, then simulate forward again. This bounds drift to one segment.
- **Modes:**
  - **Kinematic:** today's plan, exact.
  - **Ball-only sim:** cars kinematic, the ball fully simulated by our physics from their contacts. This is the cleanest test of ball physics and the hit impulse.
  - **Full re-sim:** cars driven by inferred inputs, the ball simulated.
  - **Take-over:** from any frame, a human drives one car live (§8.3).

#### Step 4: measure the divergence (this is how we tune the physics to match RL)
Use three tiers of reference, from cheapest and most exact to most "real":
1. **RocketSim** (ZealanL; a headless, deterministic C++ reimplementation of RL physics, validated against the game). Drive RocketSim and our game with the *same* scripted inputs and compare state tick by tick. This isolates our physics errors from replay noise. Python bindings exist (`rocketsim` / RLGym v2), which run via `uv`. **This is the main tuning loop.**
2. **Real replays.** Run the inverse-dynamics re-sim and report, per segment: position and rotation error over 0.5 / 1 / 2 s horizons, ball-trajectory error after each touch, touch-outcome error (exit speed and direction), and the fraction of time each car needs feedback correction. These become regression probes.
3. **Side-by-side video.** Record the same replay from RL's replay viewer (fixed or ball cam; optionally BakkesMod for camera control and exact state dumps) next to our playback of the same frames. This catches what numbers miss: visual hitbox alignment, wall and ramp transitions, camera feel, and timing of jumps and flips. Sync the videos on a goal or kickoff event. Video is for qualitative checks; the numbers come from tiers 1–2.

#### Known limits
- **Undetermined stick inputs.** On the ground with wheels down, the air stick has no effect, so its value is unknown. That doesn't matter, because it changes nothing.
- **Replay sampling.** At about 30 Hz with jitter, an input that changes within a 4-tick interval is approximated. Use the 120 Hz tick search for jump and dodge starts.
- **Server vs. client view.** Replays are the server's view, including network corrections, which occasionally show up as teleports.
- **Exact bit-for-bit match isn't the goal.** "Indistinguishable to the eye, with bounded error between re-syncs" is.

### 8.3 Take over from here: `ReplayPlayer.take_over(i)`
1. Pause at t. RL physics must be active; it will be the default once §9 is done.
2. Add a new `FishController.set_state(xform, lin_vel, ang_vel, boost, jump_state, airborne)`, queued and applied in `_integrate_forces` like `_apply_reset`, followed by `reset_physics_interpolation`. Jump state:
   - on the ground → READY
   - airborne with the jump flag and no dodge → SECOND_JUMP (the remaining window is known from the jump time)
   - otherwise → COOLDOWN
3. Add a new `Ball.set_state(pos, vel, spin)`, applied the same way.
4. The other players continue on their **inferred inputs** (full re-sim), or as kinematic ghosts.
5. Switch `input_source` back to `HumanInputSource`. "Rewind" repeats the take-over at t, giving a training loop.

---

## 9. "Play like Rocket League" preset

### 9.1 Preset system
- **`scripts/rl/rl_preset.gd`** (`RLPreset`): a table `{ "section/prop": [rl_value, scales_with_k] }` and `values(k) → {section: {prop: value}}`. It is the tested source of truth for the numbers below.
- **Preset files:** `res://presets/*.cfg` (shipped) and `user://presets/*.cfg` (user-saved), in the same ConfigFile format as `tuning.cfg` (`[fish] [camera] [ball] [world]`) plus an optional `[preset] name/description`.
- **`debug_panel.gd`:**
  - Add a Preset `OptionButton` with Apply and "Save as preset…".
  - Factor out `_apply_config(config)`.
  - **Set values directly** via `target.set()` and `set_value_no_signal`, bypassing `HSlider.value` snapping.
  - Widen ranges and steps where needed:
    - `buoyancy` to −30..10
    - `max_reverse_speed` to 0..60
    - 0.01 steps for accelerations and jump values
    - ball radius step 0.005, ball mass step 0.001
  - Re-apply the RL preset when k changes.

### 9.2 RL values (✓ = current value already matches at k = 2)

**Fish: thrust and boost (air)**
| Export | RL | k=1 | k=2 | Current |
|---|---|---|---|---|
| forward_accel / reverse_accel / brake_accel | air throttle 66.67 | 0.67 | 1.33 | 12.5 / 20 / 31 |
| max_speed, max_reverse_speed, max_boost_speed | 2300 | 23 | 46 | 35 / 6 / 75 |
| boost_accel | air 1058.33 | 10.58 | 21.17 | 10 |
| boost_drain | 33.33 /s | 33.33 | 33.33 | 50 |
| boost_regen | none | 0 | 0 | 25 |
| *(new)* spawn_boost | 33.3 | 33.3 | 33.3 | 100 (hard-coded) |

**Fish: water.** All of these become RL-neutral:
- `linear_drag`, `overspeed_drag`, `lateral_drag`, `angular_drag` → 0
- `buoyancy` → **−6.5k** (it acts as gravity; −13 at k = 2)
- `wall_bounce` / `wall_friction` → 0.3 / 0.3 (verify)

**Fish: rotation.** `rl_roll_timing` and RL air control stay on; they are already RL-faithful.

**Fish: swim strokes.** Stay **on** by default (the user's call, 2026-10-10). They're the game's own mechanic, not something to strip for RL parity. For strict RL comparisons (RocketSim parity, re-simulation), scripted inputs simply don't sweep the stick rhythmically, or the harness turns them off for its run only.

**Fish: jump and dodge**
| Export | RL | k=1 | k=2 | Current |
|---|---|---|---|---|
| jump_impulse (also double jump) | 291.67 | 2.92 | 5.83 | 10.2 |
| jump_hold_accel | 1458.33 | 14.58 | 29.17 | 51 |
| jump_hold_time | 0.2 s | 0.2 | 0.2 | 0.2 ✓ |
| dodge_impulse | 500 | 5 | 10 | 7 |
| double_jump_window | 1.25 s | 1.25 | 1.25 | 1.2 |
| dodge_deadzone, rl_dodge_timing, rl_flip_z_damp, complete_flips | | 0.5 / true / true / false | | ✓ |

**Fish: powerslide.** RL has no single scalar for this; keep the current values and set `powerslide_thrust_scale = 1.0`. This is approximate.

**Fish: surface** (all ✓ at k = 2)
| Export | RL | k=1 | k=2 |
|---|---|---|---|
| ground_max_speed | 1410 | 14.1 | 28.2 |
| ground_accel | 1600 | 16 | 32 |
| ground_brake | 3500 | 35 | 70 |
| ground_coast_decel | 525 | 5.25 | 10.5 |
| ground_boost_accel | 991.67 | 9.92 | 19.83 |
| ground_max_boost_speed | 2300 | 23 | 46 |
| surface_stick | 650 | 6.5 | 13 |

**Fish: hitbox** (Octane default)
| Export | RL | k=1 | k=2 | Current |
|---|---|---|---|---|
| hitbox_length / width / height | 120.5 / 86.7 / 38.7 | 1.21 / 0.87 / 0.39 | 2.41 / 1.73 / 0.77 | 1.5 / 1.07 / 0.7 |
| *(new)* hitbox_offset_forward / up | 13.88 / 20.76 | 0.139 / 0.208 | 0.278 / 0.415 | — |
| *(new)* hitbox_family | octane / dominus / plank / breakout / hybrid / merc | | | — |

**Ball**
| Export | RL | k=1 | k=2 | Current |
|---|---|---|---|---|
| radius | 91.25 | 0.9125 | 1.825 | 2.5 |
| mass (fish = 1) | 30 / 180 | 0.1667 | 0.1667 | 0.75 |
| bounciness / friction | 0.6 / 0.35 | | | 0.75 / 0.2 |
| max_speed | 6000 | 60 | 120 | 200 |
| max_angular_speed | 6 | 6 | 6 | 10 |
| gravity | 650 | 6.5 | 13 | 15 |
| air_drag | 0.03 | | | 0.03 ✓ |
| spin_drag | none (verify) | 0 | 0 | 1.7 |
| hit impulse, up/forward scales, HIT_CURVE | | | | ✓ (HIT_CURVE becomes a uu table × k) |

**Camera:** about `distance 2.7k`, `height 1.0k`, `field_of_view 110`.

**World:** `rl_scale = k`.

### 9.3 Missing or approximate mechanics, in priority order
1. **Surface-driving parity** (refining what's in progress):
   - ~~ride height~~ covered by the belly collider (§2.3); suspension springs are still not modelled
   - lateral-friction and handbrake curves
   - jump refresh only on surface contact (`jump_refresh_needs_surface`)
   - the 0.62 jump-hold scale, and jumping along the surface normal
   - dodge-impulse speed scaling
   - auto-roll and landing behaviour
2. **Boost pads:** 34 pads with RL positions, amounts and respawn timers.
3. **Supersonic and demolitions:** supersonic hysteresis, bumper rule, 3 s respawn, bump-impulse curves.
4. **Match flow:** 5:00 clock, 3 s countdown with `NullInputSource`, the kickoff spawn table, sudden-death overtime, HUD.
5. **Multiple players:** several `FishController`s with per-instance input sources and AI bots. `Ball`'s single-`fish` velocity tracking must be generalised to a per-body dictionary.

---

## 10. Phased roadmap

All existing probes must keep passing after every phase. Probes run as `Godot_console.exe --headless --path . res://tests/<probe>.tscn`.

| Phase | Add / modify | Acceptance probes |
|---|---|---|
| **✓ Sizes (done 2026-10-10)** | Aquarium → RL Soccar arena; RL goals; ball r 0.9125; Octane hitbox with the visual fitted to it (§2.1) | `hitbox_probe` ✓, `surface_probe` ✓, `aquarium_probe` shell containment ✓ (kickoff goal now fails until speeds are RL's) |
| **✓ RL physics values (done 2026-10-10)** | Phase 1 below, apart from `rl_space.gd`/`rl_consts.gd` and the `rl_preset_probe` (§2.2) | All 15 probes run; RL-matching checks listed in §2.2 |
| **0: RL constants + space** | Add `scripts/rl/rl_space.gd` (k = 1) and `rl_consts.gd`. Replace the 2× constants in `fish_controller.gd` (`UU_PER_SPEED` → 100, `GROUND_WHEELBASE` → 0.85) and `ball.gd` (`HIT_CURVE` in uu/s × 0.01) | `rl_space_probe`: position, quaternion and ω round-trips; yaw ½π puts the nose at the correct goal; kickoff transforms |
| **1: RL physics values** | Move every speed and acceleration export to its k = 1 RL value (§9.2); water off; ball mass 1/6 and bounciness 0.6; camera about 2.7 / 1.0 / FOV 110. Also the preset system (`rl_preset.gd`, panel preset row, no-snap setter) so the water tuning stays available as a preset. Fix the goal-rescore race | `rl_preset_probe`: 100 boost lasts 3.0 s; throttle-only top speed 14.1 m/s; ball falls 10 m in 1.754 s; kickoff boost hit scores again in `aquarium_probe` |
| **2: RocketSim parity harness** | `tools/rocketsim_compare/` (Python via `uv`, RocketSim bindings): scripted input sequences giving reference state CSVs. Headless `physics_parity_probe` replays the same inputs through our physics and diffs | Per-scenario error budgets: jump apex, dodge, half-flip, air roll, powerslide turn, wall drive, ball bounce, kickoff hit (e.g. < 2 cm / 1° after 1 s) |
| **3: Converter + loader** | Add `tools/rl_replay/*` (via `uv`), the schema, the fixture and `scripts/replay/replay_data.gd` | Schema tests; `replay_data_probe` (as before); manual real-replay checks (ball \|ω\| ≈ 6, kickoff ball y ≈ 0.93, blue car facing its goal) |
| **4: Kinematic playback** | The `replay_*.gd` files, `fish_visual.tscn`, `follow_camera.gd` target generalisation, HUD, controls | `replay_playback_probe`: ghosts match the conversion; scrubbing is deterministic; ball inside the goal at goal time; demos hidden |
| **5: Input sources** | `scripts/input/*`; `fish_controller.gd` `input_source` | Existing probes unchanged; `scripted_input_probe` matches the `Input.action_press` run |
| **6: Input inference + re-sim** | Converter or runtime step that writes `inferred_input` (closed-form air control, flags, bytes, discrete search). `ReplayInputSource`, tracking controller, re-sync points. Ball-only and full re-sim modes | `resim_probe` on fixture and real replays: per-segment position/rotation error at 0.5 / 1 / 2 s, touch-outcome error, % of ticks needing correction, all within budgets |
| **7: Video comparison** | Workflow doc and helper: record RL replay viewer plus our playback, synced on a kickoff or goal, shown side by side | Qualitative sign-off on hitbox alignment, ramps and walls, flips, camera |
| **8: Take-over** | `set_state` on fish and ball; `take_over`, rewind; other cars on inferred inputs | `takeover_probe` |
| **9: Missing mechanics** | Boost pads, match flow, supersonic and demos, multiple players | `boost_pad_probe`, `kickoff_probe`, `supersonic_probe` |
| **10: Performance and tooling** | v2 binary format, PyInstaller exe, gdext parser | Load-time benchmark |

**Ordering:** 0, then 1, then 2 (the physics must match before replays can be judged). Phases 3–5 can run in parallel with 2. Phase 6 needs 1–5. Phase 7 needs 4 (and 6 for re-sim comparisons). Phase 8 needs 6.

---
## 11. Risks & open questions

| # | Risk / question | Mitigation |
|---|---|---|
| R1 | Units of replay angular velocity are uncertain (×1, ×10 or ×100) | Converter auto-detects against the ball's max ≈ 6 rad/s, records the result, and fails loudly if nothing fits |
| R2 | RL patches break parsers several times a year | Pin `subtr-actor-py`; our schema shields Godot from the change; upgrading is a one-line bump |
| R3 | subtr-actor Python API names are unconfirmed | Isolate all calls in `extract.py` and verify them against the docs |
| R4 | File size: about 8–12 MB of JSON per match | Columnar layout, rounding, optional gzip (`FileAccess.open_compressed`), v2 binary |
| R5 | Boost in replays is coarse; drain is simulated by subtr-actor | Show it as approximate |
| R6 | The body-id → hitbox table goes stale as new cars ship | Fall back to Octane with a warning, and keep `body_id` in the file |
| R7 | Wall/floor ramp radius is unknown; RL collision meshes are Psyonix assets | Build the stadium procedurally from public dimensions. **Never ship dumped RL meshes** |
| R8 | Interplay with physics interpolation, and camera vs. player process order | Interpolation off for ghosts; set `process_priority`; covered by the playback probe |
| R9 | Jolt material combine may not give RL's ball-world bounce of 0.6 | Drop-test probe (apex ≈ 0.36h); tune the stadium collider material |
| R10 | Unverified constants: car-world restitution/friction, ball spin drag, supersonic hysteresis, kickoff ball z | Marked "verify" in `rl_consts.gd`; check against RocketSim before Phase 4 sign-off |
| R11 | Tunnelling: at k = 2 the ball can move 1 m per tick; at k = 1 the hitbox is very small | CCD on the ball (already on) and on the fish; run probes at both k values |
| R12 | Team convention: RL blue maps to Godot −Z, but the Aquarium's Blue defends +Z | Swap goal team assignment for replays, or yaw the replay 180°; check with the kickoff sanity probe |
| R13 | Inverse dynamics is ambiguous at contacts, landings and flip cancels; chaos makes long open-loop re-sims drift | Discrete action search over the interval; closed-loop correction; re-sync at kickoffs, respawns and touches; judge by bounded per-segment error |
| R14 | Sources disagree on several values: ceiling 2044 vs 2048, ball radius 91.25 vs 92.75, boost-pad pickup heights; kickoff and goal-reset durations are unsourced | Use RocketSim values; measure durations from replay metadata |
| L1 | **Licensing / privacy:** subtr-actor and boxcars are MIT; replays contain player names | Keep license notices; never commit third-party replays (`samples/` is gitignored); `--anonymize`; no platform ids; no RL assets (ghosts use our fish visuals) |
| Q1 | ~~Default k~~ | **Resolved: k = 1, true RL size** (2026-10-10) |
| Q2 | ~~Fit the visual to the hitbox?~~ | **Done:** `Visual` scales to fill the hitbox (non-uniformly) |
| Q3 | ~~RL Stadium?~~ | **Resolved:** the Aquarium is the RL arena now |

---

## 12. Sources

**Replay format and parsers**
- boxcars: https://github.com/nickbabcock/boxcars (`src/data.rs`, `src/network/{models,attributes,frame_decoder}.rs`, `src/header.rs`, `src/crc.rs`)
- rrrocket: https://github.com/nickbabcock/rrrocket
- subtr-actor: https://github.com/rlrml/subtr-actor (`src/collector/replay_data.rs`, `src/collector/ndarray/builtins.rs`, `src/util/geometry.rs`, `docs/replay-format-evolution.md`, `js/player/src/player/adapter/coords.ts`). Also PyPI `subtr-actor-py`, and npm `@rlrml/subtr-actor` and `@rlrml/player`
- jjbott's C# parser: https://github.com/jjbott/RocketLeagueReplayParser
- rl-web: https://github.com/nickbabcock/rl-web
- rattletrap (archived): https://github.com/tfausak/rattletrap
- carball (dead): https://github.com/SaltieRL/carball
- ballchasing API: https://ballchasing.com/doc/api
- godot-rust: https://github.com/godot-rust/gdext

**Geometry and physics**
- RocketSim: https://github.com/ZealanL/RocketSim (`src/RLConst.h`, `CarConfig.cpp`, `Car.cpp`, `Ball.cpp`, `Arena.cpp`)
- RLBot wiki, Useful Game Values: https://github.com/RLBot/RLBot/wiki/Useful-Game-Values
- RLUtilities: https://github.com/samuelpmish/RLUtilities
- Sam Mish, "Car–ball interaction" (archived): https://web.archive.org/web/2022/https://samuelpmish.github.io/notes/RocketLeague/car_ball_interaction/
- RLGym game values: https://rlgym.org/Cheatsheets/game_values
- Car body table: https://github.com/RLGym/rlgym-tools/blob/main/rlgym_tools/rocket_league/misc/car_bodies.py

**Not verified during research** (check these at implementation time):
- the modern rrrocket JSON shape
- the throttle/steer byte encoding
- `ReplicatedStateName` strings beyond Countdown, PostGoalScored and ReplayPlayback
- overtime clock behaviour
- the wall-ramp radius and centre-circle radius
- the kickoff countdown and goal-reset durations
