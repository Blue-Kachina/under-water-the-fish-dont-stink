# Fish Movement Game — Development Plan

**Working concept:** A playful 3D swimming game with deep, skill-based movement inspired by Rocket League's car and aerial controls.

**Status:** Initial technical and gameplay plan  
**Primary objective:** Make skills learned in Rocket League transfer naturally to swimming, while developing an original game with its own identity.

## 1. Core vision

Players control a fish with a **meaningful forward-facing direction**, precise three-dimensional orientation, momentum, acceleration, reverse swimming, boost, and expressive directional maneuvers. The fish can point one way while still drifting another way. Controls should be immediately recognizable to experienced Rocket League players, but approachable to newcomers.

### Design pillars

1. **Muscle-memory transfer:** Preserve familiar controller inputs and the feel of responsive, skillful vehicle control.
2. **Orientation matters:** The fish's nose, not the camera, determines primary thrust direction.
3. **Momentum matters:** Facing direction and travel direction can differ; movement is not automatically aligned with the camera.
4. **Arcade feel before realism:** Optimize responsiveness and fun; believable swimming animation comes afterward.
5. **Expressive personality:** Reverse swimming is deliberately awkward and funny — the fish tucks its head in, compresses its body, and flutters its fins.
6. **Original game identity:** Use Rocket League-style skills in a new underwater environment and with original objectives, art, and progression.

## 2. First-pass controls

Start with an Xbox-style controller and offer fully remappable controls.

| Input | Default behavior | Notes |
|---|---|---|
| Right trigger | Forward swimming thrust | Smooth analog acceleration |
| Left trigger | Reverse swimming thrust / brake | Preserve usable backward travel; weaker acceleration than forward by default |
| Left stick horizontal | Yaw left / right | Fish turns about its vertical axis |
| Left stick vertical | Pitch up / down | Preserve familiar Rocket League aerial pitch convention; make invert option available |
| Boost button (e.g., B) | Extra forward thrust | Test finite boost versus cooldown during prototype |
| Jump button (e.g., A) | Tail-flick impulse | Adapt Rocket League-style jump to neutral-buoyancy swimming |
| Directional input + second jump | Directional dash / dodge | Optional advanced mechanic; tune after baseline controls feel good |
| Air-roll modifier (e.g., X or LB) + left stick | Roll / modified orientation | Prototype Rocket League-compatible modifier behavior |
| Optional dedicated roll bindings | Roll left and roll right | Important for players accustomed to directional air roll |
| Right stick | Camera orbit | Camera movement must not redirect propulsion |

**Control fidelity note:** Rocket League's precise ground/air steering and air-roll mappings are state-dependent. We should prototype and playtest how to adapt these underwater rather than claim a perfect one-to-one mapping. Save multiple customizable profiles for players using different Rocket League bindings.

## 3. Movement physics specification

### Required simulation state

- Position and orientation (quaternion)
- Linear and angular velocity
- Forward, reverse, and boost thrust
- Pitch, yaw, roll torque / steering responsiveness
- Linear drag and angular damping
- Optional neutral buoyancy / adjustable gravity
- Collision contacts and impulse response
- Dash/tail-flick states, cooldowns, and optional boost resource

### Initial gameplay rules

- **Forward axis:** Thrust always applies primarily along the fish's local forward vector.
- **Reverse:** Negative local-forward thrust is permitted; use asymmetric acceleration and top speed for comedy and control balance.
- **Momentum:** Turning the fish does not instantly turn its velocity vector.
- **Buoyancy:** Start neutrally buoyant with no net vertical acceleration; optionally experiment with slight drift.
- **Water drag:** Apply modest linear drag and angular damping, tuned for satisfying control rather than physical realism.
- **Rotation:** Pitch, yaw and roll must remain independent of world up as needed for full 3D tricks.
- **Boost:** Add stronger forward force without steering the fish automatically.
- **Dash:** A deliberate directional impulse with a predictable timing window; avoid implementing every Rocket League mechanic at once.
- **Contacts:** Fish should glide, bounce, or recover predictably from rocks, reefs, cave walls, and other objects.

### Important tuning parameters

Expose tunable values in a debug menu or configuration file: forward/reverse acceleration, speed caps, boost force, drag, braking, pitch/yaw/roll sensitivity, torque, angular damping, dash impulse, dash cooldown, collision response, and camera lag. Measure actual behavior with repeatable tests, not only subjective feel.

## 4. Technology decision: RocketSim vs custom controller

### Track A — RocketSim feasibility spike

**Goal:** Determine whether [RocketSim](https://github.com/ZealanL/RocketSim) can be adapted usefully to underwater movement.

- Inspect the current repository, license, build process, update history, and available API.
- Identify assumptions tied to Rocket League arenas, vehicles, wheels, suspension, gravity, and contacts.
- Build a tiny executable and obtain basic simulation output.
- Test a simplified free-swimming movement case if the API allows it without invasive changes.
- Document whether modifications would require maintaining a significant fork.
- Validate licensing and distribution implications before using code in a released game.

**Caution:** RocketSim is a recreation of Rocket League physics, not Psyonix's released original source code. Its existing car/arena abstractions may make full-time swimming more awkward than writing a custom controller.

### Track B — Minimal custom rigid-body swimming controller

**Goal:** Implement the behaviors that actually create Rocket League-like muscle-memory transfer, using a general-purpose rigid-body physics system.

- Make a rigid body with orientation, velocity, thrust and torque.
- Connect the controller inputs listed above.
- Implement forward and reverse swimming, then boost, roll, and dashes.
- Include simple collision and debug visualizations.
- Compare handling against Rocket League-inspired benchmark maneuvers.

### Decision gate

After both spikes, pick the approach with the best balance of **controller feel, arbitrary underwater geometry support, maintainability, performance, and licensing clarity**. A hybrid is possible: use RocketSim as a behavioral reference while implementing the original game's swimming physics separately.

**Initial recommendation:** Expect a **custom rigid-body controller** to be the eventual foundation, with RocketSim serving as a valuable reference or testbed. Do not make the full game dependent on RocketSim until the feasibility spike is complete.

## 5. Prototype architecture

Keep movement independent from rendering, animation, and UI:

```text
Controller input
      |
      v
Input mapper + binding profiles
      |
      v
Movement state machine / physics controller
      |
      +--> Fixed-step physics and collision world
      |
      +--> Camera follow/orbit system
      |
      +--> Fish animation parameters
      |
      +--> Telemetry, debugging and replay capture
      |
      v
3D rendering and game objectives
```

**Engine selection:** Defer the engine choice until a short comparison of Godot, Unreal, Unity and a custom C++ stack. Prefer the path that gets a controller-driven physics prototype running fastest. C++ expertise may favor a native solution, but should not force a custom renderer and editor into the first milestone.

## 6. Animation and visual identity

Animation should **follow gameplay physics**, not drive them.

| State | Visual expression |
|---|---|
| Forward swim | Relaxed rhythmic tail beat; fins stabilize turns |
| Reverse swim | Fish tucks its head awkwardly, compresses its body, flutters fins frantically |
| Hard brake | Fins spread wide, body resists momentum |
| Boost | Faster tail motion and trailing bubbles |
| Sharp pitch/yaw/roll | Stylized body bend and fin reactions |
| Tail-flick dash | Quick anticipation pose, snap, then elastic recovery |
| Collision | Comedic squash/stretch, wobble or startled eyes without loss of control fidelity |

Use a placeholder capsule or primitive fish for early prototypes. Replace it with a rigged fish only after movement passes basic handling tests. Make reverse swimming a memorable character moment while preserving input responsiveness.

## 7. Camera design

- Begin with a third-person follow camera that generally tracks the fish's forward direction.
- Allow right-stick orbit without changing the fish's thrust vector.
- Smooth camera movement independently of simulation motion.
- Test whether roll should affect the camera (default suggestion: limited roll to reduce disorientation).
- Implement collision avoidance so terrain does not block the view.
- Provide settings for camera distance, sensitivity, follow speed and inversion.

## 8. Development milestones

### Milestone 0 — Design and repository setup

**Deliverables:** One-page concept, control reference, engine/physics shortlist, repository structure, licensing checklist.

**Done when:** We can explain the core controls, state what Rocket League skills should transfer, and run a basic empty 3D scene.

### Milestone 1 — Physics spikes

**Deliverables:** RocketSim feasibility notes; working minimal custom swimming controller; comparison matrix.

**Done when:** Both options are assessed fairly and one is selected for the main prototype.

### Milestone 2 — Swimming sandbox

**Deliverables:** Fish-shaped placeholder, gamepad controls, forward/reverse thrust, pitch/yaw/roll, neutral buoyancy, drag, boost, third-person camera.

**Done when:** A Rocket League player can move, stop, reverse, rotate, and recover orientation in a simple underwater test space without fighting the controller.

### Milestone 3 — Skill-expression mechanics

**Deliverables:** Tail-flick, directional dash, roll binding profiles, collision response, adjustable tuning parameters.

**Done when:** A player can deliberately chain maneuvers and repeat them consistently.

### Milestone 4 — Underwater obstacle course

**Deliverables:** Rings, narrow tunnels, reef arches, moving targets or timing gates; checkpoint/restart system.

**Done when:** Levels reward accurate orientation, momentum management, reverse movement and advanced dashes.

### Milestone 5 — Fish character and polish

**Deliverables:** Rigged model, swimming/reverse animations, expressive fins and eyes, particles, sounds, camera polish.

**Done when:** The fish feels lively and funny without losing gameplay responsiveness.

### Milestone 6 — External playtesting and game direction

**Deliverables:** Side-by-side feedback from Rocket League players and newcomers, handling revisions, short list of potential core game modes.

**Done when:** We know which movements transfer intuitively, which controls need customization, and which underwater objective is most compelling.

## 9. Playtest scenarios and success criteria

| Test | What to observe |
|---|---|
| Figure-eight swim | Responsiveness of yaw, speed changes and banking |
| Nose-up climb | Forward thrust follows the fish's own heading |
| Full roll then correction | Predictable orientation control, minimal unwanted auto-leveling |
| Brake and reverse | Smooth transition to genuinely backward swimming; funny animation doesn't delay response |
| Drift-through-ring | Velocity and facing direction can differ usefully |
| Boost and quick turn | Momentum is controllable without feeling like a camera-driven swimmer |
| Tunnel obstacle course | Camera, collision, orientation and recovery work together |
| Dash chain | Maneuvers are repeatable and skill-based rather than random |

Capture frame-by-frame input, position, orientation and velocity for reproducible comparisons. A short controller-feel test with experienced Rocket League players matters more than theoretical fidelity alone.

## 10. Risks and mitigations

| Risk | Mitigation |
|---|---|
| RocketSim assumes car wheels, gravity and Rocket League-style arenas | Time-box the feasibility spike; retain a custom rigid-body fallback |
| Library licensing or redistribution uncertainty | Review exact current licenses and attribution requirements before shipping |
| Full 3D movement causes disorientation | Provide camera options, optional aids and a guided tutorial |
| Physics feels sluggish underwater | Prioritize arcade responsiveness and tune drag deliberately |
| Reverse animation obscures or delays control | Drive animation from physics state; keep movement immediate |
| Copying familiar controls without originality | Develop distinct aquatic objectives, environments, progression and visual identity |
| Multiplayer adds complexity too early | Keep initial milestones single-player and deterministic where practical |

## 11. Out of scope for the first prototype

- Online multiplayer and netcode
- Large open-world ocean streaming
- Complex ecosystems or realistic fish biology
- Elaborate progression/economy
- Highly polished art before mechanics are validated
- Full frame-perfect replication of Rocket League

## 12. Immediate next actions

1. Decide on a prototype engine and target platform (initially Windows + Xbox controller is sensible).
2. Review RocketSim's latest APIs/license and run a minimal simulation.
3. Build the simplest possible fish rigid-body controller with forward thrust, reverse thrust, pitch, yaw, and roll.
4. Create a plain test arena with rings and obstacles.
5. Compare control feel and choose the ongoing physics foundation.
6. Add the goofy reverse-swimming animation only after reverse movement itself feels right.

---

### Open design questions

- What is the game's main objective: racing, obstacle courses, exploration, combat, sports or something else?
- Should boost consume a meter, regenerate, or be unlimited?
- Should the fish automatically level itself when no roll input is applied, or is manual orientation part of the skill ceiling?
- Which Rocket League air-roll profiles should ship as presets?
- Are tail-flicks directional dodges, short bursts of propulsion, or both?
- Should environmental contact enable advanced techniques analogous to wavedashes and flip resets?

**Guiding rule:** First make a placeholder fish feel fantastic to control. Only then build the ocean around it.
