# Plan: core roadmap — swimming, procedural animation, modular modes

Written 2026-11-16 from a full read of the code at 375eb01 (Rocky terrain), plus one measured run of
`tests/swishy_probe` on the Nature preset. Three deliverables, one roadmap:

1. a movement-system analysis and a short list of isolated, measurable improvements (§1);
2. a procedural animation architecture and one polished prototype creature (§2);
3. a modular game-mode architecture and a migration strategy for one existing mode (§3);
4. the sequence, gates and the decisions only the user can make (§4, §5).

Nothing here is built yet. Every item lists how it is measured, so a later session can build it under the
project's usual loop (plan, develop, headless probes, debug build, hand off for play-testing).

---

## 0. Where the project stands

### 0.1 Facts

| | |
|---|---|
| Engine | Godot 4.7 Forward+, Jolt, 120 Hz physics with interpolation, one GDExtension (`TerrainField`) |
| GDScript | ~107k lines in `scripts/` (core 40k, fish models 8k, Unnatural 29k, What Stinks 20k, Marco Polo 10k), 48k lines of probes in `tests/` (220 scene probes) |
| Modes | 11 in `main.gd::MODES`; 7 of them "match" modes with their own run/match class, settings singleton, HUD and bots |
| Classes | 13 (`FishCharacter.FishClass`), each a Rocket League hitbox + a procedurally lofted model + 1 to 5 species; two hidden (Titan, Monster) |
| Swim core | `fish_controller.gd` (2424 lines), `swishy_swim.gd`, `gait.gd`, `follow_camera.gd` (815), `fish_model.gd` (1044) |
| History | 89 commits since 2026-10-10; 19 planning docs; most features awaiting play-test |

### 0.2 Honest assessment

**The strong part is real.** The stride system is a genuinely good mechanic: one scalar (the envelope of the
previous stride at the moment the next one starts) is both the timing judgement and the reward, flow
compounds it, the gait layer composes on top without changing the controls, and the whole thing is
deterministic, mass-independent and tick-exact (the RocketSim parity harness proves the physics side).
It is also well instrumented: `swishy_probe`, `gait_probe` with a recorded baseline, `physics_parity_probe`.

**Identity.** Everything the game is now agrees on one thing: `FishController` on the Nature preset
(Extra Swishy strides, no boost, open-water drag, the bow wave). Seven of the eleven modes play on it
(`NATURE_MODES`). The Rocket League parity half (surfaces, tyres, suspension, flips) is complete, verified
and almost unused outside Fish Sticks and Replays. Recommendation (D1): name the Nature-tuned stride
swim as the identity, and treat RL parity as a preserved capability the probes keep honest, not a
direction that drives new features.

**Animations are mediocre for a structural reason, not a polish reason.** Fish are animated by inputs and
by time, not by what the body is doing (§2.1). The tail follows the stick, the idle wiggle rate follows
the throttle trigger, fins flutter from a speed scalar, and nothing reads acceleration, turn rate or slip.
The two physics-driven exceptions (the ray's bank and the Titans' power-stroke chain) are the best-looking
swimmers in the game, which is the proof.

**Modes contaminate the core in both directions** (§3.1). `main.gd` and `hud.gd` know every mode by name;
modes write the fish's tuning fields, collision layers and camera fields directly and stash state in 40+
`set_meta` keys. Discarding a mode today touches 8 to 10 core files.

**Debt that matters** (in the order it blocks the three deliverables):

| Debt | Where | Blocks |
|---|---|---|
| Animation state computed in three places with two definitions of "effort" | `fish_controller._process`, `fish_model.react/_swim`, each hunter rig | §2 |
| Mode knowledge in the host, HUD, camera, co-op and audio hooks | `main.gd`, `hud.gd`, `follow_camera.gd`, `local_coop.gd`, `sfx_hooks.gd` | §3 |
| Modes write core fields (`speed_scale`, `collision_layer`, `boost_enabled`, `rl_surface_mechanics`, `camera.set("...")`) | 13 call sites listed in §3.1 | §3 |
| Kits owned by one mode and borrowed by others (School by Nature, Seabed/Terrain/Traversal/steady cam by Unnatural) | `scripts/school.gd`, `scripts/unnatural/{seabed,traversal}.gd`, `UnnaturalRun.steady_camera` | §3 |
| Five parallel animation paths (controller, model, shaders, hunter rigs, bakes) | §2.1 | §2 |
| Seven mode settings singletons + the panel's hard-coded `SECTIONS` | `debug_panel.gd:42` | §3 |

None of this needs a rewrite. The host and HUD need a registry and slots; the fish needs a modifier stack
and a play-state instead of pokes; the animation needs one shared state struct and one rig.

---

## 1. Movement system analysis

### 1.1 How a tick works today

`FishController._integrate_forces` runs at 120 Hz and edits velocities directly (every tuning value is an
acceleration, speed or rate). In order:

1. cap last step's speed and spin (RL post-tick order), emit `physics_tick` (the parity probe's hook);
2. `_sample_input`: RL deadzone/sensitivity on the raw stick, then `_detect_strokes` → `SwishySwim.sample`
   (stride detection: a sweep past `stride_threshold` that reverses by `stride_reversal` after crossing the
   middle starts a stride; timing = the previous stride's envelope right then; flow += gain·(2·timing−1));
3. surface detection (RL wheels), then off a surface: `_apply_thrust` (throttle to `max_speed`),
   `SwishySwim.apply` (push along the gait's axis × `stride_force` × power × strength × reach × room),
   `_apply_water` (overspeed drag while swimming, linear drag × gait coast drag while not, lateral slip
   removed at `lateral_drag`, buoyancy);
4. jump/dodge (RL flips), auto-roll;
5. rotation: RL air control torque (default) unless locked, or car steering when `rl_air_control` is off;
   Extra Swishy steers by `swishy.steer`, the stick smoothed over `stride_steer_smoothing`;
6. telemetry (`speed`, `forward_speed`, `drift_angle`, `angular_speed`, `bow_amount`).

`_process` (render rate) then poses the tail and fin pivots from inputs and stride state, and calls
`FishModel.react` (bend, squash, class specials). The chase camera reads the interpolated transform and
follows the **nose**, not the velocity.

Input latency is already minimal: the stick is read inside the physics step that uses it (no frame of lag),
and the model reads stride state the same frame. There is nothing to win on latency; the wins are in
coupling and readability.

### 1.2 What to keep, untouched

- Velocity-editing physics with the parity harness; `physics_tick` as the test seam.
- The stride envelope and flow as the one timing judgement; `Gait` as the per-class shaping layer.
- The direction lock on the boost button in Nature.
- Live tuning for everything (`@export_range` → panel), presets, and the recorded `gait_baseline.json`
  guarding "zero change" refactors. Every change below must keep that baseline green with its toggle off.

### 1.3 Measured baseline (Nature preset, `swishy_probe`, 4 s runs from a standstill, 2026-11-16)

| Scenario | Speed at end | Peak | Flow | Strides | Travelled | Off line | Turned |
|---|---|---|---|---|---|---|---|
| throttle only | 9.1 | 9.1 | 0 | 0 | 26.9 m | 0.0 m | 0° |
| side to side at the peak, stick **held** to each side | 23.3 | 26.6 | 1.90 | 12 | **16.0 m** | 2.1 m | 27° |
| sweep and **let go**, at the peak | 32.5 | 34.0 | 1.90 | 12 | **88.4 m** | 73.4 m | 80° |
| at the peak, direction lock held | 32.8 | 34.1 | 1.90 | 12 | **92.1 m** | 0.0 m | 0° |
| early (half the peak) | 10.0 | 10.2 | 0.02 | 23 | 23.1 m | 23.1 m | 164° |
| late (peak + ¾ fade) | 7.6 | 9.3 | 0 | 7 | 3.1 m | 2.7 m | 139° |
| mashing (60 ms) | 8.9 | 8.9 | 0 | 67 | 25.4 m | 16.1 m | 84° |
| up and down at the peak | 19.8 | 23.1 | 1.90 | 12 | 7.2 m | 6.7 m | **170°** |
| diagonal at the peak | 31.9 | 33.5 | 1.90 | 12 | 77.1 m | 72.3 m | 157° |

What the numbers say:

- **The ceiling is 3.6× throttle** (32.8 vs 9.1 m/s). Good: rhythm is the game.
- **Held sweeps lose five sixths of the distance** (16 m vs 92 m). In the Nature preset
  `stride_steer_smoothing` is 0, so the stick steers directly while it also strokes: a sweep held to the
  side yaws the fish through its whole stride, and an up/down sweep pitches it into a loop (170°).
  Releasing after the sweep, or holding the lock, avoids it. This is the biggest mastery wall in the
  system: the natural way to hold a controller stick ("push the tail over") is the worst way to swim, and
  nothing tells the player why. It is also why the camera wobbles in Nature (§1.4 F6).
- **The reward is a cliff, not a slope.** Early (timing 0.5) and late (timing ≈ 0.25) both collapse to
  throttle speed (10.0 and 7.6 m/s), because flow gain is `0.3·(2·timing − 1)`: a stride timed at 0.5
  gains nothing, below it loses. There is no visible partial credit between "perfect" and "nothing", so a
  learner gets no gradient to climb. The perfect window (power ≥ 0.85, the gold colour) is about 150 ms
  wide (0.25 s to 0.40 s after the stride starts), which is a fair target for a human, but the slope either
  side of it is what teaches.
- **Mashing is handled** (67 strides, 8.9 m/s). Keep.

### 1.4 Findings

**F1 Steering is welded to the stroke** (measured above). The game's answer is the lock, but the lock
costs a button, hides the weave (which is the look of the thing) and is off by default in the controls'
mental model. There is a cleaner rule available: *a sweep is a stroke until its stride fades; holding past
the fade is steering*. See M1.

**F2 Flow gain has no shape control.** One constant (`stride_flow_gain`) and a linear `2t−1`. The reward
curve should be a tunable curve so the slope can be play-tested. See M2.

**F3 Turning in water does not depend on speed.** With `rl_air_control` on (the default and the Nature
preset), full stick drives spin to the 5.5 rad/s cap at any speed: a 33 m/s fish turns on a 6 m circle,
a 5 m/s fish on 1 m. Lateral drag 1.0 then swings the velocity round over about a second, so there *is*
an emergent drift (`drift_angle` reaches tens of degrees in a hard turn at speed), but nothing in the
game expresses it: `drift_angle` is read by one HUD debug line and nothing else (fx, sound, animation,
scoring all ignore it). Speed-dependent turning plus visible carving is the single largest untapped
expressiveness lever, and it is also the thing that makes a fast fish feel fast. See M3. It changes feel,
so it ships behind a toggle and waits for play-test.

**F4 Animation reads inputs, not motion.** `_swim_phase += delta * lerp(4, 18, input_forward)`: a fish
coasting at 30 m/s idles its tail; a fish pinned against a wall with the trigger down thrashes at full
rate. `FishModel._swim` uses a second, different effort (`speed / 23`). Fin flare on powerslide reads
`input_stick.x`. Part of §2, but the fix starts in the controller: one `SwimState` computed per tick
(M5).

**F5 Coast is short.** `linear_drag` 0.85 halves speed in 0.8 s; `overspeed_drag` 0.59 bleeds the stride
surplus while swimming. Momentum cannot be banked, so the mechanic is "keep the chain going", which is
fine for Nature and bad for anything that wants a glide (Unnatural gives Gliders `drag_scale` for exactly
this). Not a bug; listed so that M3's carving (speed scrub in a turn) is designed against the same drag
numbers and not tuned twice.

**F6 The Nature/Hunt camera follows the nose, so it swings with every stride.** Unnatural solved this
with the settle style (smoothed signed yaw rate, catch-up delay, max off-angle) and the user liked it
(settle-cam memory), but it only exists as `steady_heading` set through `camera.set("...")` strings from
`UnnaturalRun.steady_camera`. It should be a core camera style every swim mode can pick. See M4.

**F7 Stride cue placement.** The timing cue is drawn on the tail (fill root to tip, gold at the sweet
spot), which the chase camera sees from behind at a glancing angle. The bubble stream colour and the HUD
stride meter help. Not a code change; a candidate for the animation prototype: let the body's wave
amplitude show the envelope too (§2.3), so the cue is the whole fish.

**F8 Two steering models and three roll models coexist** (`rl_air_control` / `car_steering` /
torque-damping, `rl_roll_timing` / `roll_torque`). They are preserved RL-parity branches. Keep them, but
new water handling (M3) goes in one new place and does not add a fourth branch.

### 1.5 Isolated, measurable improvements

Five items plus the harness that measures them. Each is behind its own toggle (default off until
play-tested, except M0 and M5 which change nothing by design), each has a probe assertion, and each keeps
`gait_baseline.json` green with the toggle off.

**M0 Swim metrics harness** (first; no feel change).
Extend `swishy_probe` into `tests/swim_metrics_probe` that runs a fixed scenario set and writes
`tests/fixtures/swim_metrics.json`: the §1.3 table plus a timing sweep (10 offsets from 0.5× peak to
peak + fade → end speed), a turn-radius sweep (full stick at 5 / 15 / 30 m/s → radius, drift angle, speed
lost per 90°), a held-vs-released distance ratio, and the camera's yaw oscillation amplitude over a locked
stride chain (`FollowCamera` basis sampled per frame). `--record` writes the fixture; a normal run diffs
against it with tolerances and prints the deltas. Every M below is accepted by this probe's numbers.

**M1 Stroke/steer decoupling** (`stride_steer_cancel`, 0..1, Nature default to be chosen in play-test).
In `SwishySwim.sample`, while a stride is active, subtract from the steering stick the component along the
stride's own sweep direction, scaled by the stride's power: `steer = stick − _dir · max(stick·_dir, 0) ·
power · cancel`. While the stride builds and peaks, a held stick is a stroke; as it fades, the same hold
turns into steering. Up/down sweeps stop pitching the fish into loops for the same reason. The lock keeps
working as now.
Measure: held / released distance ratio from 0.18 to ≥ 0.8; heading drift over a symmetric held pair
< 3°; the locked run and every unlocked `swishy_probe` check unchanged.

**M2 Timing reward curve** (`stride_timing_curve`, a `Curve` resource on the fish, plus
`stride_partial_credit` 0..1).
Flow gain becomes `gain · curve(timing)` with the curve defaulting to today's `2t − 1`; strength's
`lerp(fresh, 1, timing)` gets the same curve. A second, gentler default is shipped as a preset for
play-test ("a 70 %-timed stride earns 60 % of a perfect one's speed").
Measure: the timing sweep is monotonic; the 0.7-timed run reaches ≥ 60 % of the perfect run's end speed
on the gentle curve; the perfect run itself is unchanged on both.

**M3 Water carving** (`water_turning`: off / speed-scaled).
A single new path in `_apply_rotation` for water (not a fourth branch of the RL ones): the spin cap and
torque scale by a `water_turn_curve` of forward speed (tight at a crawl, wide at speed, like
`RL_TURN_CURVATURE` but tuned for water), and `_apply_water` adds a slip-dependent drag term
(`carve_drag · sin(drift)`) so a hard turn at speed scrubs speed and the fish visibly slides. `drift_angle`
and the slip vector go into `SwimState` (M5) for the rig, FX and sound.
Measure: turn radius at 5 / 15 / 30 m/s rises monotonically; speed lost per 90° at 30 m/s is a tunable
target (start at 25 %); off, every metric equals the fixture. Ships to play-test as a preset toggle; the
user decides (D3).

**M4 Settle camera as a core style.**
Move the settle/hold/free parameters out of `UnnaturalSettings` into `FollowCamera`'s own tuning (a
`CameraStyle` resource: chase, settle, hold, free, ball), with `push_style` / `pop_style` for modes, and
make settle the Nature preset's style. `UnnaturalRun.steady_camera` becomes a one-line push. Unnatural,
the Obstacle Course and Marco Polo's camera requests are unchanged in behaviour (survivor_cam_probe,
camera_probe stay green).
Measure: camera yaw oscillation over a locked stride chain from today's value to < 2° peak to peak in
Nature; 90° turn catch-up time within 10 % of Unnatural's today.

**M5 One `SwimState` per tick** (no feel change; the bridge to §2).
`FishController` fills a `SwimState` (RefCounted, reused) at the end of `_integrate_forces`: `speed`,
`speed_frac` (of the class's top), `effort` (throttle ∨ boost ∨ stride power, one definition),
`accel` (body frame, smoothed over 60 ms), `spin` (body frame pitch/yaw/roll rates), `slip` (velocity
minus forward component, body frame) and `drift_angle`, `stride` (phase, power, dir, timing, flow,
sweetness), `grounded`, `surface_normal`, `bell_lean`, `gait`. `_process` and `FishModel.react` read it
and nothing else: the two "effort"s become one, `input_forward` and `input_stick` leave the animation
code. Puppets (`set_net_state`), replays (`ReplayCar`) and school fish synthesise the same struct from
velocity history, so one rig can animate every fish. The 19-float `replay_fx` vector stays as the wire
format and is derived from the struct.
Measure: `physics_parity_probe` and `gait_baseline` unchanged; `grep input_forward|input_stick` returns
nothing in `fish_model.gd` or `_process`; the parity probe's tick cost does not rise more than 5 %.

Suggested order: M0 → M5 → M4 → M1 → M2 → (play-test) → M3.

---

## 2. Procedural animation architecture

### 2.1 The five animation paths today

| Path | Where | Drives | Reads |
|---|---|---|---|
| Controller pose | `fish_controller._process` (≈75 lines) | tail pivot yaw/pitch/scale, fin pivots (slide flare, flutter, flap), bubbles | `input_forward`, `input_stick`, `is_powersliding`, `swishy`, `_swim_phase` (time) |
| Model react | `fish_model.react / _swim / _bank_ray / _beat_wings / _bend_whip / _titan_swim / _pulse_bell` (≈470 lines) | body bend from the tail pivot, squash (off: `squash_strength` 0 everywhere), ray bank + wing springs + whip chain, Titan power/recovery chain with wave delay, head counter, surge, bank; bell pulse; sea hare flaps | `velocity`, own frame deltas, `stride_swing/power`, `tail.rotation`, time |
| Shaders | `fish_bend.gdshaderinc` (1 arc, or the Titans' 3-arc chain + head + surge), `fin_membrane` flutter, skins' ripple, `spine_bend.gdshaderinc` for long bodies | vertex offsets | `phase`, `effort`, `TIME` (fins), instance bend uniforms |
| Hunter and boss rigs | `what_stinks/forms/*_rig.gd` (shark, king, lamprey, angel, gulper, whalefall, lantern, octopus; ≈4.5k lines), `unnatural/bosses/*` | spine trails, wave clocks, stiffness, jaws, exaggeration | each re-estimates speed, turn, its own `_wave_clock` |
| Bakes | `school_look.gd` (3 tail poses, flipbook), horde looks | MultiMesh pose index | school phase |

Diagnosis: there is no shared notion of *what the body is doing*. The pieces that look alive (ray bank,
Titan chain, jelly bell) are the ones that read motion, and each was hand-built. The pieces that look
mediocre (every ordinary fish's tail, every fin) read inputs and time. There is also no turn deformation
(the body only bends from the tail swing, never from yaw rate), no banking except the ray and Titans, no
acceleration response (squash is switched off on the realistic models), and no reaction to slip.

### 2.2 Target: SwimState → Rig layers → Deformers

**(a) SwimState** (M5) is the only input. Fish with a controller fill it from physics; puppets, replays
and school fish from velocity history. Rigs never read inputs, never read `TIME`, never write physics.

**(b) SwimRig** (a Node on the model, GDScript, per rendered frame): an ordered set of *layers*, each a
small pure-ish object with `evaluate(state, dt, pose)` that adds into a shared `Pose`. All constants are
`Gait` fields or rig settings with wide ranges in the panel (the project's "flexible tuning" rule).

| Layer | What it adds | Driven by |
|---|---|---|
| Undulation | a travelling wave down the spine: amplitude ∝ effort, frequency from speed (Strouhal-style `f = St·U/A`, clamped), wavelength ∝ body length; phase advanced by the rig's own clock | `speed`, `effort`, class length |
| TailDrive | the stride swing (`SwishySwim.tail_swing`) overrides the wave's tail segment and is carried forward as a bend that travels down the body with lag (the Titan `bend_lag` idea, for everyone) | `stride` |
| Accel | the tail trails acceleration (a critically damped spring on the last segments, sign-correct: speeding up lags the tail back, braking folds it forward), the head leads; fins fold back on acceleration and flare on braking; replaces squash | `accel` |
| Turn | the spine bends into the turn with curvature `spin / max(speed, v0)`, the body banks (rolls into the turn) by a per-class `turn_bank`, the inside fin tucks and the outside fin extends | `spin`, `speed` |
| Drift | the body aligns part-way to the flow: the rear segments bend toward the velocity vector by `slip`, fins flare as brakes at high drift, the dorsal stiffens with speed | `slip`, `drift_angle`, `speed` |
| FinStabilizer | pectorals counter roll and pitch rates (ailerons), trim with vertical velocity, flutter amplitude ∝ speed; the tail's own fin flutters with power | `spin`, `slip.y`, `speed` |
| Idle | low-amplitude hover: pectoral sculling, slow tail sway, gill beat; weight `1 − effort`, zero above a speed | `speed`, `effort` |
| Gait | selects and weights the layers for the class (lateral, fluke, flap, bell, radial) and supplies the per-class numbers | `gait` |

**Pose** is a plain struct of channels: spine joints (N = 3 by default, each a yaw/pitch rotation vector,
matching `fish_bend`'s chain), head counter-bend, surge, body bank (roll), tail pivot (yaw, pitch,
scale), fin pivots L/R (sweep, roll, flare), and shader scalars (wave phase, effort, flutter, stride cue).
Layers add into channels; a per-channel critically damped `SpringChannel` helper smooths the sum (the
codebase has five hand-rolled springs today: ray bank, wing beat, whip links, squash, Titan fluke; one
helper replaces them). Blending is additive with state-driven weights, so there is no animation graph to
author and no transitions to tune.

**(c) Deformers** carry the Pose to meshes and already mostly exist:

- the 3-segment chain in `fish_bend.gdshaderinc` (the Titan branch: `bend_turn2/3`, `bend_head`, the
  surge) becomes the standard path for every class, with `Gait.bend_segments` defaulting to 3 (it is 1
  for everyone but Titans today). `FishModel.apply_bend` already writes it;
- the tail and fin pivots (exist);
- `spine_bend` for long bodies keeps its trail, fed by a `TrailAdapter` from the same Pose (phase 2.4);
- bakes sample the Pose at 3 to 5 wave phases (`SchoolLook.POSES` becomes a Pose sample, not a constant).

Rules: rigs read SwimState only; no `TIME` in a rig; every number is tunable; per class only parameters
differ (code paths only for a real morphology difference, which `Gait.Visual` already enumerates); the
rig owns nothing that gameplay reads (hit tests, mouths, bite points read the Pose through `bend_point`,
as today).

Cost budget: ≤ 0.05 ms per fish per frame for the layers in GDScript at 3 joints (measure in a 50-fish
bench), and no new per-frame allocations (Pose and SpringChannels are preallocated). Schools and the
horde are untouched (bakes).

### 2.3 Prototype: the Hunter class shark (great white)

Why the shark: a single lofted body with the bend shader, stiff airfoil fins (`shark_fin`), a strong
silhouette that shows banking and turn bend clearly, a carangiform swimmer (the classic "wave grows toward
the tail") and the same model serves Nature/Hunt/Unnatural *and* the What Stinks Drowned Shark hunter
form, so one prototype pays off in four modes. (The clownfish is the default class but its body is short
and the fins do most of the talking, which hides the spine work. D4.)

Steps and acceptance:

- **P1** M5 landed; `gait_baseline` green; `swim_metrics` fixture recorded.
- **P2** `SwimRig` node with Pose, SpringChannel and the Gait layer, attached to the shark only behind a
  `procedural_rig` toggle (per class in the GAITS section). Every other class untouched. With the toggle
  on and all layers at zero weight, the shark poses exactly as today (the old `_process` pose expressed as
  a layer), so there is a zero-change state to diff against.
- **P3** Layers in this order, each a separate commit-sized step with its own probe check: Undulation →
  TailDrive → Turn (bend + bank) → Accel → Drift → FinStabilizer → Idle.
- **P4** `tests/swim_rig_probe` (headless): the pose is zero at rest; wave phase rate rises monotonically
  with speed; the tail lags with the correct sign on acceleration and braking; the bank and bend have the
  turn's sign; drift bends toward the velocity; no NaN over a 60 s random-input soak; the stride cue still
  fills root to tip; `gait_baseline` unchanged with the toggle off.
  `tests/shark_rig_shots` (needs a window): contact sheets at 0 / 5 / 15 / 30 m/s straight, a full-lock
  turn at 15 and 30 m/s, a brake from 30, a stride chain, and a drift; side and three-quarter views; each
  sheet with the toggle on and off. Reviewed by the user (shader and pose work cannot be judged headless).
- **P5** The Drowned Shark hunter form rides the same rig (its `_swim_look` speed estimate and wave clock
  go), then the other ten classes as *parameter sets* on the same layers, one per session, with the gait
  probe guarding each.

Polish list for the shark specifically (what "polished" means here): the wave's amplitude envelope grows
from the pectorals back (not from the nose); the caudal fin's own flutter leads the stroke by a few
degrees (the tail fin bends before the stalk); pectorals bank *first* in a turn and the body follows; the
dorsal does not bend with the spine's first segment (sharks' dorsals are stiff); the stride cue rides the
wave amplitude as well as the fill, so the timing reads on the whole body (F7).

### 2.4 After the prototype

- Hunter and boss rigs converge on the Pose through a `TrailAdapter` (Pose → spine points), removing
  eight private speed estimates and wave clocks; `AttackExaggerate` stays a separate, additive layer on top.
- The jelly's `BellPulse` and the sea hare's flaps become layers under `Gait.Visual`.
- School bakes sample the rig at five phases, so schools wag with the same wave the hero fish does.

---

## 3. Modular game-mode architecture

### 3.1 Coupling today, measured

Core files that know modes by name (mentions of unnatural / marco / stinks / hunt / nature / course):

| File | Lines | Mentions | What it does with them |
|---|---|---|---|
| `main.gd` | 1273 | 84 / 83 / 65 / 32 / 87 / 33 | per-mode `_start_*`, `host_*`, `guest_*`, `solo_*`, an `_end_match` with a branch per mode, `_playing_mode` if-chain, six tables (`MODES`, `MATCH_MODES`, `NATURE_MODES`, `MODE_ENVIRONMENTS`, `MODE_TILES`, `ENVIRONMENTS`), eight mode signals |
| `hud.gd` | 1146 | 2 / 1 / 0 / 47 / 52 / 28 | holds `match_1v1`, `nature_run`, `hunt_match`, `survivor_cam`, `plate_filter`; per-mode boards, splashes, feeds, hints |
| `follow_camera.gd` | 815 | 1 / 6 / 0 / 0 / 1 / 8 | `course`, `ball`, `pose_override` (Marco), `hold_opens_wheel` (Nature), `button_taken` (Marco), `steady_heading` + 17 settle/free fields set by `camera.set("...")` from `UnnaturalRun.steady_camera`, a `MarcoArena.CUTAWAY_GROUP` lookup |
| `local_coop.gd` | 475 | 17 / 3 / 0 / 0 / 12 / 0 | `if run is UnnaturalRun` / `as NatureRun` wiring; `no_split_screen` for Marco and What Stinks |
| `sfx_hooks.gd` | | | `node is Match1v1 or HuntMatch / NatureRun / UnnaturalRun` type switch |
| `debug_panel.gd` | 2164 | 9 / 4 / 5 / 5 / 10 / 0 | `SECTIONS` lists each mode's settings singleton |
| `fish_controller.gd` | 2424 | 4 / 1 / 2 / 2 / 5 / 0 | `nature_batter_speed` (a Nature group), `ignore_jump` (What Stinks), `set_model_visible` (Unnatural i-frames), `body_scale`/`hitbox_scale`/`bow_scale` (Marco), `speed/stride/turn/drag/top_speed/accel/boost/rl_turn_scale` (Unnatural, Marco, What Stinks) |

Modes writing core state directly (the reverse direction): `fish.speed_scale` (8 sites), `collision_layer`
and `collision_mask` (7 each), `boost_enabled` (5), `rl_surface_mechanics` (7), `buoyancy`, `freeze`,
`controls_locked` (17), `revive` (7), plus `set_meta` as a side channel with 40+ keys (`ws_*`, `mp_*`,
`hunter_jaw`, `coop_index`, `surface_before`, `boost_before`, `survivor_mode` on the camera).

Kits owned by one mode and borrowed by others: `School` (Nature; used by What Stinks and the Horde),
`Seabed` + `Terrain` (Unnatural; used by Hunt and What Stinks floors), `Traversal` (Unnatural; used by the
Obstacle Course via `CourseSkill`), the settle camera (Unnatural; Course), `UnnaturalSettings` (read by
the Course and the Free Swim terrain stream). Shared kits that are already clean: `Battery`,
`StylePoints`, `MatchStats`, `GoalRecorder` / `GoalReplay`, `HunterBot` (base of `SurvivorBot`),
`FishInput` / `PlayerInput`, `FxKit`, `ChompKit`.

Cost of discarding a mode today (What Stinks as the example): `main.gd` (start/host/guest/solo, end
branch, three tables, a signal pair, card text), `hud.gd` (`plate_filter`), `follow_camera.gd` (`target`),
`local_coop.gd` (`no_split_screen`), `fish_controller.gd` (`ignore_jump`, `rl_turn_scale`),
`fish_character.gd` (the Monster class), `fish_model.gd` (`HunterFormModel` branch), `debug_panel.gd`,
`mode_setups.gd`, `role_characters.gd`, `setting_docs.gd`, `sound_catalog.gd`, `school.gd` (the joined-
players section), `net_session.gd` wiring, plus `scripts/what_stinks/` and `scripts/net/what_stinks_net.gd`.
That is the contamination the user is asking to stop.

### 3.2 Target boundaries

```
scripts/core/     fish_controller, swishy_swim, gait, swim_rig (§2), follow_camera, hud host, controls,
                  player_input, local_coop, net_session, sfx, console, ui/*, main (the ModeHost)
scripts/kits/     school, seabed + terrain, traversal (mobility), battery, style_points, match_stats,
                  recorder + replay, bots (fish_bot, hunter_bot), fx_kit, chomp_kit, scenery/*, water_look
scripts/modes/<id>/   the mode: its GameMode, settings, hud, bots, net, attacks, looks, probes' fixtures
```

Rule: modes import core and kits; core and kits never import a mode. A mode is one folder plus one line
in the registry. Enforced by `tests/mode_boundary_probe` (greps `preload("res://scripts/modes` and mode
class names outside `scripts/modes/`; jcodemunch's layer-violation query can double-check).

**GameMode** (a Node, one subclass per mode) replaces the per-mode functions in `main.gd`:

```
static func descriptor() -> Dictionary
    id, title, pitch, short, icon, colors            (today's MODE_TILES entry)
    environment: String | Callable                   (MODE_ENVIRONMENTS; Marco's arena picker)
    play: [solo, split, online]
    tuning_preset: String                            (NATURE_PRESET or "")
    settings: Object                                 (the panel section, instead of SECTIONS)
    setup_rows: Callable                             (today's ModeSetups.build branch)
    roles: Array                                     (RoleCharacters)
    hud: GDScript                                    (a ModeHud per player view)
    sfx: GDScript                                    (the SfxHooks attachment)
    split_screen: bool, one_screen: bool
func enter(world: ModeWorld) -> void                 (environment ready, players known)
func start() -> void                                 (Play on the card / Dive in)
func end() -> void
func add_player(slot: PlayerSlot) / remove_player(slot)
func reset() -> void                                 (R)
func playing() -> bool
signal teleported(fish), over(result: Dictionary), stat(event: Dictionary), phase_changed(phase)
```

**ModeRegistry**: an ordered list of GameMode scripts. `main.gd` becomes `ModeHost`: it owns the
environment, the first slot, the panel, the home screen and the pause menu, and asks the registry for
everything mode-specific. `MODES`, `MATCH_MODES`, `NATURE_MODES`, `MODE_ENVIRONMENTS`, `MODE_TILES`, the
eight mode signals, `_playing_mode`, `_start_match`, `_end_match` and the host/guest/solo trios all go.
`NetSession.coop` gets a generic `host_mode(id)` / `join_mode(id)` through the same contract.

**ModeWorld** is what a mode receives instead of reaching into main: `environment`, `slots`
(players), `camera_service`, `hud_host`, `tuning` (push/pop preset), `audio`, `net`, `console`.

Core services with explicit APIs replace the field pokes:

- `FishController.modifiers`: a named multiplicative stack (`push("unnatural.size", {speed: 1.2,
  stride: 1.3})`, `pop("unnatural.size")`) over speed, accel, turn, rl_turn, drag, top speed, boost,
  stride, bow, body, hitbox. The eight loose `*_scale` fields become its read-out. Nothing outside
  core assigns them.
- `FishController.play_state`: `LIVE`, `HELD` (controls locked), `OUT` (battered: hidden, no collisions,
  frozen), `PUPPET`, with the collision-layer save/restore inside. Replaces `controls_locked`, `batter`,
  `revive`'s half of it, `freeze` and the seven `collision_layer` writes.
- `FishController.capabilities`: a save/restore set (`boost`, `jump`, `surface`, `strokes`) with
  `push`/`pop`, replacing `boost_enabled = false` + `set_meta("boost_before")`,
  `rl_surface_mechanics = …` + `"surface_before"`, `ignore_jump`.
- `nature_batter_speed` leaves the fish: it is the `Battery` kit's setting (`BatterySettings`), read by
  Nature, Hunt, 1v1 and Unnatural's ram.
- `FollowCamera`: `CameraStyle` resources (M4) with `push_style`/`pop_style`, `focus` (ball, opponent,
  hoop, school) as a request, `pose_override` and `button_taken` folded into a `CameraClaim` a mode
  pushes and pops. No `camera.set("…")`.
- HUD: `HudHost` (core) with slots (scorebug, clock, countdown, splash, feed, board, plates, hint
  line, meters) and one `ModeHud` (a mode's node, per player view) that fills them through the slot API.
  `hud.gd` keeps the fish readouts, the stride meter, the boost gauge and the replay overlay (shared
  kits) and forgets `match_1v1`, `nature_run`, `hunt_match`, `survivor_cam`, `plate_filter`.
- `LocalCoop` calls `mode.add_player(slot)` / `remove_player` and builds `slot.mode_hud` from the
  descriptor; the `is UnnaturalRun` branches go.
- `SfxHooks` attaches the descriptor's `sfx` script to the mode node; the type switch keeps only core
  types.
- The tuning panel builds a section per registered mode's `settings` object; `SECTIONS` lists core only.
- Meta tags: a mode may tag *its own* nodes; tagging a core node is a boundary-probe failure (a
  `ModeData` dictionary on `PlayerSlot`, keyed by mode id, replaces `coop_index`, `ws_*`, `mp_*`).

### 3.3 Migration strategy: Hunt first

Why Hunt: 435 lines, solo only (no net), and it exercises every seam at once: an environment (the Ocean
with a boundary), a bot, the Battery / StylePoints / recorder / replay kits, HUD scorebug + splash + feed +
board, audio hooks that type-switch on it, a camera claim (ball cam on the opponent), a tuning preset,
an optional seabed, and a settings leak (`hunt_floor*` in `NatureSettings`). It also already has a probe
(`tests/hunt_probe`).

| Step | Work | Gate |
|---|---|---|
| H0 | Characterise: extend `hunt_probe` to drive a scripted match (kickoff, battery, Fish Fry, time-up on points, overtime battery) and record `tests/fixtures/hunt_baseline.json` (phases, scores, clock, events). | fixture recorded |
| H1 | `GameMode`, `ModeRegistry`, `ModeWorld` in core with **Hunt as the only registered mode**; the host falls through to today's code for unregistered ids. `_start_hunt`, the Hunt branch of `_end_match`, `_playing_mode`'s Hunt case and the Hunt rows of the six tables move into `modes/hunt/hunt_mode.gd::descriptor()`. | `hunt_probe` matches the fixture; every other probe green; `mode_setup_probe` green |
| H2 | `HudHost` slots + `modes/hunt/hunt_hud.gd`: the 47 Hunt lines leave `hud.gd` (scorebug, BATTERED splash, feed, board, hint line). `Match1v1` keeps calling the same slots unchanged. | HUD shots of a battery unchanged (`battery_replay_shots`) |
| H3 | Camera claim: `ball cam on the opponent` → `world.camera.claim(Focus.node(opponent))`. | `camera_probe`, `hunter_cam_wiggle_probe` green |
| H4 | Audio: `BatteredSounds` / `MatchSounds` attach via the descriptor; the `is HuntMatch` checks go (Match1v1 still attaches the same two). | `audio_hooks_probe` green |
| H5 | Fish: `player.team_color`, `controls_locked`, `revive`, `batter` → `play_state`; `nature_batter_speed` → `BatterySettings`. | `swishy_probe`, `nature_probe`, `gait_baseline` green |
| H6 | Settings: `hunt_floor`, `hunt_floor_depth` → `HuntSettings` (panel section from the descriptor). | panel shows a Hunt section; `setting_docs` regenerated |
| H7 | Files to `scripts/modes/hunt/` (plain moves, user commits; see the "no git mv" note); `mode_boundary_probe` green. **Discard test:** comment out the registry line, run the whole suite, put it back. | suite green both ways |

Then, in this order, each one a session with the same H0 to H7 shape:

1. **Nature** (the identity mode): `School` to kits first, `TargetWheel` + `hold_opens_wheel` to a camera
   claim, split-screen wiring through `add_player`. Biggest HUD extraction (52 lines).
2. **1v1 / Free Play** (share the match kits with Hunt; the Aquarium arena stays an environment).
3. **Unnatural** (largest): `Seabed` + `Terrain`, `Traversal`, settle camera (already M4) to kits first;
   then the run, horde, cards, bosses move as a folder. `UnnaturalSettings` splits into kit settings
   (terrain, camera) and the mode's own.
4. **Obstacle Course** (becomes tiny once Traversal and the settle cam are kits).
5. **Marco Polo** and **What Stinks** last: newest, most `set_meta` use, both online. The Monster class and
   `HunterFormModel` branch in `fish_model.gd` become a mode-registered model provider (a hook the
   registry exposes: `FishModel.providers[class]`).

Main after the migration: a ~300-line `ModeHost`. The two tables that remain in core are the environment
list and the registry.

---

## 4. Roadmap

| Phase | Builds | Gates (headless) | Hand-off |
|---|---|---|---|
| 0 Measure | M0 swim metrics probe + fixture; `mode_boundary_probe` (reporting only); M5 SwimState | parity, gait baseline, metrics fixture recorded; no feel change | none (a build anyway, per the workflow) |
| 1 Swim | M4 settle cam as core style; M1 stroke/steer decoupling; M2 reward curve (two presets) | metrics deltas as specified; survivor_cam / camera probes | play-test build: held vs flick, the gentle curve vs today's |
| 2 Rig | P1 to P4 on the shark | swim_rig_probe; gait baseline off; bench ≤ 0.05 ms/fish | shark_rig_shots contact sheets for review |
| 3 Modes | Hunt H0 to H7 | hunt baseline, boundary probe, discard test | play-test Hunt (also closes its pending play-test) |
| 4 Carve + rollout | M3 water carving behind its toggle; P5 the Drowned Shark and two more classes on the rig; Nature migration | metrics sweep; gait baseline per class | play-test carving on/off; shots |
| 5 onward | remaining classes; Unnatural, Course, Marco, What Stinks migrations; hunter rig convergence (§2.4) | per step | per step |

Phases 1 to 3 are independent of each other after phase 0 and can run in parallel sessions (one file
owner per file, as the project's worker plans do): the swim items touch `swishy_swim.gd`,
`fish_controller.gd` and `follow_camera.gd`; the rig touches `fish_model.gd`, the shark model and new
files; the Hunt migration touches `main.gd`, `hud.gd`, `hunt_match.gd` and new files. The one overlap is
`fish_controller.gd` (M5 and H5), so M5 lands first.

---

## 5. Decisions for the user

- **D1 Identity.** Nature-tuned stride swimming is the core; RL parity stays as a verified capability
  (Fish Sticks, Replays) and stops driving new features. Recommended yes.
- **D2 Held sweeps (M1).** Decouple stroke from steer by the fade rule, or keep "flick or lock" as the
  intended skill? Recommended: build it behind the toggle and decide on the play-test.
- **D3 Carving (M3).** Do you want speed-dependent turning and speed scrub in water at all? It is the
  biggest feel change in the list and the one with the most upside for expressiveness.
- **D4 Prototype creature.** Shark (recommended) or the default clownfish?
- **D5 Migration order.** Hunt first (recommended), or Nature first because it is the identity mode?
- **D6 File moves.** The folder move in H7 is plain file moves for you to commit (the probe-running
  memory says no `git mv` from a session). Alternatively keep files where they are and enforce the
  boundary by the probe only; the folder move is cosmetic until the user wants it.
- **D7 What to discard now.** Candidates, with what keeping them costs under the new boundary:
  Free Swim (nothing: it is Nature's environment with no run), Obstacle Course (nearly nothing once
  Traversal and the settle cam are kits), Replays (its converter and `replay/` are self-contained; keep
  if RL parity stays), Test Tank (a flag on Unnatural). Nothing needs discarding to do this plan.

## 6. Risks and open items

- Shader and pose work cannot be judged headless; every rig step ends in shots for review, and the
  memory notes that windowed probes can segfault at match end (light unpair): shots scenes should quit
  before the match ends.
- M3 interacts with Unnatural's `turn_scale` / `drag_scale` twists and Marco's whale scales; the modifier
  stack (§3.2) is the clean place for them, so M3's tuning should wait for H5's stack if both are in
  flight.
- `fish_bend`'s 3-segment chain costs three instance uniforms more per bent mesh; fine for hero fish,
  irrelevant for bakes. Instance-uniform index pinning (the include's note) must be kept.
- The jcodemunch index is behind HEAD (b77cc2b vs 375eb01); re-index before using it to check the
  boundary.
- `two_stage_bite_probe` is noted as broken and not bisected; unrelated, but it will show up in any
  "whole suite green" gate and should be fixed or marked first.
- Nothing in this plan changes the network protocol; `replay_fx` stays the wire format for looks.

## Progress log
- 2026-11-16: plan written from the code read and one measured `swishy_probe` run. Nothing built.
