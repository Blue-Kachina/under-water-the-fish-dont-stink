# Plan: Expanding on Nature (schools, multis, pearls)

## Context
Nature free play is one fish, the player's, striding Extra Swishy after **one** calm target
(`NatureRun` + `WanderBot`). Ramming it nose first at `nature_batter_speed` or faster batters it,
and a new one turns up 30–50 m away after 1.5 s.

The problem: hitting one small moving target is very hard, especially at speed, and speed is what
we want to encourage. So:

1. **Schools.** Spawn many harmless NPC fish in **groups**, each group swimming together in a
   school (mostly in unison). A tight cluster is much easier to hit at speed than a lone fish.
2. **Multis.** Hitting several fish in quick succession pays more, and each successive hit is
   louder and more exciting, as with Unreal Tournament's Double Kill → Multi Kill → Monster Kill.
3. **School targeting.** Ball cam (Y) locks onto a **school**, not a single fish. With several
   schools around, **long-press Y** opens a wheel that lists them, to pick which one to target.
4. **Pearl drops.** A battered fish may leave a glowing **pearl** with an aura and a magnetic
   pull. Swimming over it collects it, and so does passing close by: it gets drawn in and absorbed
   ("osmosis"). For this phase we only count how many get collected. Real power-ups come later.

Out of scope: Hunt (still a 1v1 with no schools; schools may come to it in a later phase), the
power-up effects themselves, and networking (but see "Co-op" below: the design shouldn't block it).

Every number in this plan is a **setting**, not a code constant, with wide ranges (see §10 and
Decisions).

**Naming:** the rename to **Battered** has landed across the whole game, code included: `Battery`
(`scripts/battery.gd`), `batter()`, `battered`, `nature_batter_speed`, a count of battered fish. Only
Rocket League itself (its replays and data) still says demo / demolition.

## Implementation status
**All phases (1–5) and the performance pass (§9b) are done (2026-10-16), awaiting manual test.**
Phase 1 was tested by hand first. Its tuning (3 schools of 50, fish scale 1.0, speed 5.5, turn
30°/s, spread 2.5) is now Nature's default, both in `presets/nature.cfg` and in
`NatureSettings`.

**New files:**
- **Settings:** `scripts/nature_settings.gd`, `NatureSettings.shared()`, which is the panel's
  NATURE section. Every number in this plan lives there.
- **Schools:**
  - `scripts/school.gd`: the fish as data, plus the drawing;
  - `scripts/school_look.gd`: the baked meshes, one per tail pose, with LODs;
  - `scripts/school_fish.gd`: a full model for a near fish.
- **Scoring and pearls:** `scripts/nature_score.gd` (multis and sprees), `scripts/pearl.gd` and
  `shaders/pearl_aura.gdshader`.
- **Targeting:** `scripts/target_wheel.gd`, the school wheel and the edge arrows.
- **Probes:** `school_probe`, `nature_schools_probe`, `nature_battered_fish_probe`,
  `nature_score_probe` and `target_wheel_probe`.
- **Tools that need a window:** `school_shots` (screenshots) and `school_bench` (frame time, draw
  calls and triangles, e.g. `-- --schools=10 --fish=50`).

**Changed:**
- `nature_run.gd`:
  - schools and their population, `focus` / `focus_changed` / `set_focus` / `targets()`;
  - the school-fish hitbox pool and battered fish;
  - the score, pearls and the speed cost.
- `main.gd`:
  - ball cam follows `focus`;
  - hold-Y opens the wheel, a tap picks the nearest target;
  - Nature's tuning is kept between visits;
  - big multis punch the view (`ArcadeFx.punch`).
- `follow_camera.gd`:
  - `hold_opens_wheel`, `wheel_open`;
  - `set_ball_cam()` and the `ball_cam_toggled`, `wheel_opened` and `wheel_closed` signals;
  - the right stick doesn't look around while the wheel is open.
- `battery.gd`: `attack_shapes()` and `areas_touched()`. `touching()` uses them, so Hunt and the 1v1
  are unchanged.
- `explosion.gd`: a `particles` share, and a sparks-only pop below 1.
- `hud.gd`:
  - Battered fish / Points / Pearls;
  - the multi and spree splash, hotter each step;
  - the feed lines and the chain bar.
- `arcade_fx.gd`: `punch()`.
- `debug_panel.gd`: int-range sliders, and `or_greater` / `or_less`.
- `fish_controller.gd`: wider ranges on Thrust/Water drag, Extra Swishy, Bow Wave and Nature.
- `presets/nature.cfg` and `README.md`.

**Performance** (`school_bench`, 1920×1080, RTX 4070 Ti SUPER):

| Fish | Before (phase 1) | Now |
|---|---|---|
| 150 | 4.7 ms | 1.5 ms |
| 500 | 73 ms | 1.9 ms |
| 1,000 | not run | 2.6 ms (386 fps, 571 draw calls, 0.55 M triangles) |

The school step for 500 fish takes 0.8 ms at 30 Hz, about 24 ms per second of CPU.

**Where the build differs from the plan above:**
- **The lone fish stays** (*Lone Target*, on). It batters, scores and drops pearls like a school
  fish. Switch it off in the panel if schools are enough.
- **Points:** a battery is +100. A multi's bonus is `multi_bonus × (chain + 1)`, which gives +150,
  +200, +250 and so on. That's a single setting rather than the table in §5, which went +150,
  +200, +300, +400, +500. A spree milestone is `spree_bonus × milestone` (+250, +500, …).
- **Multi names:** chains of 6 or more stay MONSTER CATCH, and spree milestones past the fifth stay
  POSEIDON.
- **School fish explosions are a small pop:** sparks and a flash, with no shockwave shell or
  bubble cloud (`fish_explosion` 1.2 m, `fish_explosion_particles` 0.3). Full explosions filled the
  screen, because the chase camera swims straight through them right after the hit.
- **The bait ball and swerve** trigger when the player is within `bait_range` of the school and
  closing at `bait_speed` or more. The alarm rises and falls at `bait_rate`.
- **Burst:** the survivors within `burst_radius` get a push away from the battered fish, and their
  slots pull them back together.
- **Ball cam inside a school:** the school's `centre` turns to look ahead of the player while it's
  in or beside the school, and eases back over 20 m once it's out. It turns the direction rather
  than sliding the point, so the view never flips. The fastest turn measured swimming through a
  school is about 200°/s.
- **The wheel:**
  - releasing it with the stick left alone stays on the current target;
  - the game doesn't slow down while it's open;
  - outside Nature, Y toggles at once, as before.
- **Kept tuning lasts until the game closes.** It isn't saved to disk.
- **Pearls collected** show as a feed line and a count, nothing more.

**Open items for tuning:**
- school speed and reactions, the burst, the multi window and points;
- pearl chance and magnet;
- detail fish count and distance;
- the lone fish's place now that there are schools.

## Existing pieces to reuse
- **`NatureRun`** (`scripts/nature_run.gd`): `setup(ocean, player)`, `start()`/`end()`,
  `_announce_teleport`, `LEASH`, `RESPAWN_DISTANCE`, `Explosion.spawn`, the `battered` signal the
  HUD listens to. It becomes the owner of schools instead of the single `target`.
- **`WanderBot`** (`scripts/wander_bot.gd`): `pick_spot()` around `home` (`ROAM_RADIUS`,
  `ROAM_HEIGHT`, `ARRIVED`), the `skittish` spook test, and `_steer_to`. Its route-picking is what a
  school's leader needs.
- **`Battery`** (`scripts/battery.gd`): `hits()` / `touching()`. The player's hitbox, grown
  by `REACH`, plus the bow wave (`bow_points()`), as the attacking shape. The `FRONT` cone test.
- **`FishModel` / `FishCharacter`** (`scripts/fish_model.gd`, `fish_character.gd`): the koi-style
  lofted models and skins (shark, swordfish, clownfish, koi, ray, boxfish). Small, scaled-down
  copies can be school fish.
- **Follow camera** (`scripts/follow_camera.gd`): `ball` is any `Node3D`, and `_focus()` returns it
  while it's visible. A moving "school centre" node can be the ball with no camera changes beyond
  the edge cases noted below. The `ball_cam` toggle is `Input.is_action_just_pressed("ball_cam")`
  in `_process`, which has to change for long-press (see §4).
- **`controls.gd`**: `ball_cam` is `JOY_BUTTON_Y` / `KEY_Y`. The right stick (`camera_*`, IJKL on
  keyboard) is free to steer a wheel while it's open.
- **`StylePoints`** (`scripts/style_points.gd`): the pattern for a tally that emits `awarded`
  events and has a `TITLES` table the HUD feed reads. It's Hunt's two-fish system, so Nature gets
  its own small scorer, but with the same event shape so the HUD feed can show both.
- **HUD** (`scripts/hud.gd`): `set_nature`, `_on_battered`, the points feed and splash from
  Hunt, ArcadeFx (zoom, gold vignette, punch).
- **`Explosion.spawn(parent, at, color, reach, blast_speed)`**.

## Design

### 1. School fish: light, not full `FishController`s
A `FishController` is a `RigidBody3D` with the full swim model, Swishy strides, bow wave, tail
and bubbles. Forty of them would be expensive and pointless: school fish don't need RL physics.

**`SchoolFish`** (new, `scripts/school_fish.gd`): a `Node3D` with
- a small `FishModel` (one character + skin per school, scaled to about 0.4–0.6 of the player's),
  with a simple tail-wag driven by speed;
- an `Area3D` with a box or capsule `CollisionShape3D` on its own physics layer (so the player
  doesn't bump into them physically: they're hit, not collided with);
- `velocity`, a `slot` (its place in the formation) and `battered` state.

All of a school's motion is computed by its `School` node in one loop. The fish themselves have
no `_physics_process`.

### 2. Schools (`scripts/school.gd`, new)
A `School` owns 6–12 `SchoolFish` and a moving **centre** (`Node3D`, the camera's target).

**Leader route.** An invisible leader roams like `WanderBot`: it picks spots around `home`
(about 25 m across, ±8 m up/down) and turns towards them at a limited rate, cruising at a calm
speed well under the player's (about 5–7 m/s, against `nature_batter_speed`).

**"Mostly in unison": formation slots, plus a little boids.** Pure boids drifts apart and looks
mushy. Instead each fish has a slot in a loose ellipsoid around the leader, in the leader's frame
(so the whole school turns together), and steers to it with:
- **seek slot** (strong): the school moves as one;
- **separation** (weak, only under about 0.8 m): no overlaps;
- **per-fish noise** (slow, small): a phase offset on the wag and a few cm of wander, so it looks
  alive rather than rigid;
- **turn lag by slot**: fish further back respond a little later, so turns ripple through the
  school like a real one.

**Tightness** is the main tuning knob (`spread`, the slot ellipsoid's size). Tight schools are the
whole point: they're what makes high-speed multis possible.

**Reactions to the player** (the real fish behaviour, and it helps gameplay):
- **Bait ball.** When the player is close and coming in fast (like `WanderBot.skittish`'s spook
  test), the school **tightens** (`spread` shrinks) and swerves a little away. Real sardines do
  this, and it makes a fast run *more* rewarding, not less.
- **Burst after a hit.** When a fish in the school gets battered, the nearest survivors burst
  outward briefly, then regroup over a second or two. That leaves a short window for a follow-up
  hit as they re-form. How much they scatter decides how hard triples and beyond are, so it's
  a tuning knob (`burst_strength`, 0 = no scatter).

**Centre:** the mean position of the school's live fish, smoothed. Its `visible` is false when the
school is empty, so `_focus()` falls back cleanly.

### 3. Population (`NatureRun` changes)
- Keep **3 schools** alive (export, try 2–4), each of **8 fish** (export, try 6–12).
- The first school waits ahead of the player at the start (as `FIRST_DISTANCE` does now). The
  others spawn 40–70 m off in random directions, out in the fog.
- A school that's **wiped out**, or further than `LEASH` from the player, is replaced by a new one
  after `RESPAWN_TIME` (spawned out of sight, never popping in on screen).
- A partly eaten school stays as it is. Optionally, a school with only 1–2 fish left could join the
  nearest other school (open question).
- Each school gets a random character and skin from the fish models and its own name ("the
  Sardine Steves", reusing the `TARGET_NAMES` joke) for the wheel.
- `battered_fish` and `last_battery_speed` stay. New: `pearls`, `best_multi`, `best_spree`.

### 4. Hitting school fish
`Battery.hits` takes two `FishController`s and builds new shapes on every call. With 24+ fish,
calling it once per fish per tick is wasteful. Instead:

- **One query per tick.** Build the player's attacking shape (hitbox + `REACH`, and the bow wave
  if it's out) **once**, and run a single `intersect_shape` against the school-fish layer with
  `collide_with_areas = true` and a result cap of ~16.
- Every school fish returned that's in the `FRONT` cone, with the player at `nature_batter_speed` or
  faster, is battered **that tick**. Two fish hit in the same tick are a genuine double.
- Refactor `Battery` so the attacking-shape builder is shared (`attack_shapes(attacker)`), and
  `hits()` keeps working for the 1v1 and Hunt as it does now.
- A battered `SchoolFish` gets a small `Explosion` (reach ~2–3 m instead of 6, or 40 school
  explosions would white out the screen) in the school's colour, and is freed or hidden.
- **Speed cost per hit** (`hit_speed_cost`, a setting): each battered fish takes this fraction of
  the player's speed. The default is small (about 3%), so ploughing through a whole school isn't
  quite free. The range runs from 0 (none) up to 1, which stops you dead, for exaggerated play.
  A second setting, `hit_speed_cost_min_speed`, can stop the cost from ever dropping the player
  below the battering speed mid-run (on by default, so one hit never ends a chain by itself).

### 5. Multis and sprees (Unreal Tournament style)
UT had two separate ladders, and they map nicely onto this:

**Multi (quick succession).** Each hit within `MULTI_WINDOW` (about 2.5 s, UT99 used ~3 s) of the
last one extends the chain. Each step has a bigger callout, a bigger splash and more points:

Fish puns are confirmed. The names below are a first draft, easy to change (they're a table in
`NatureScore`).

| Chain | UT name | Ours (fish puns) | Points (starting values) |
|---|---|---|---|
| 1 | — | BATTERED | 100 |
| 2 | Double Kill | DOUBLE DIP | +150 |
| 3 | Multi Kill | TRIPLE FRY | +200 |
| 4 | Mega Kill | FISH SUPPER | +300 |
| 5 | Ultra Kill | FEEDING FRENZY | +400 |
| 6+ | Monster Kill | SHOAL SLAYER / MONSTER CATCH | +500 each |

The window is shown as a draining ring or bar under the callout, so the player knows how long
they have to keep the chain going.

**Spree (without slowing down).** A running count of hits that only resets when the player drops
below `nature_batter_speed` for more than about 1 s (or stops striding). It's the "travel fast"
reward, and pays off a long run from school to school:

| Spree | UT name | Ours (fish puns) |
|---|---|---|
| 5 | Killing Spree | SPRING ROLL |
| 10 | Rampage | RIPTIDE |
| 15 | Dominating | APEX PREDATOR |
| 20 | Unstoppable | UNSTOPPABLE |
| 25 | Godlike | POSEIDON |

Escalation is the important part, more than the exact names:
- each step gets a bigger, longer splash and a stronger ArcadeFx punch (zoom-in, gold vignette,
  brief hit-stop on Mega and above, as `GoalReplay.arcade` already does);
- an announcer-voice line per step (UT's big thing). We have no voice audio yet, so the plan
  leaves a hook (`callout(step)` signal) for later sound work;
- the HUD feed lists each award like Hunt's ("DOUBLE DIP +150").

**Scorer:** `NatureScore` (new, `scripts/nature_score.gd`), a `RefCounted` like `StylePoints`, with
`on_hit(fish, time)`, `update(delta)` and an `awarded(type, points, extra)` signal. Nature gets a
points tally on the HUD next to the battered count.

### 6. Targeting schools (Y)
- **Tap Y:** ball cam on/off, as now. The target is a **school's centre**, not a fish.
  - Default target: the nearest school ahead of the player (weighted by angle off the nose, so it
    doesn't pick one behind you).
  - When the target school is wiped out, switch to the next nearest automatically.
- **Hold Y (about 0.3 s):** opens the **school wheel**.
  - One slice per school, placed by its **direction from the camera** (so the wheel doubles as a
    radar), each showing its name, fish left, distance and character icon/colour.
  - Right stick (IJKL on keyboard) picks a slice. Releasing Y confirms and turns ball cam on for
    it. Releasing with the stick centred cancels.
  - The world keeps running while the wheel is open. **No slow-mo** (decided): co-op is coming,
    and time can't slow for one player.
- **Camera change:** the toggle moves from `is_action_just_pressed` to "released before the hold
  time". The camera only toggles on a *short* press. The hold logic lives in a small
  `TargetWheel` HUD node, which sets `_camera.ball` and `ball_cam`.
  - The obstacle course's ring cam and the Aquarium's ball cam keep the tap behaviour. Holding Y
    there does nothing (or toggles, as now).
- **Camera edge case:** when the player is inside or right next to the target school, the centre
  is under or beside the fish and the ball-cam aim swings wildly. Within about the school's radius,
  aim at the centre's position pushed out along the school's heading, or blend back to the normal
  chase view until the player is clear. Needs a probe (below).

### 7. Pearls (`scripts/pearl.gd`, new)
- **Drop:** each battered fish has `pearl_chance` (about 20%) to leave one, and the chance **rises
  with the multi step**: `pearl_chance_per_step` (about +15% per step) is added for each step past
  the first, so by a Fish Supper (step 4) a drop is likely, and a Feeding Frenzy all but certain.
  Both are settings, and the result is capped at 100%.
- **Look:** a small, bright, iridescent sphere (emissive, with a fresnel rim), an additive aura
  shell or billboard glow that pulses slowly, and a dim `OmniLight3D` so it lights the water around
  it. Visible from far off through the fog. It drifts gently where the fish died, bobbing.
- **Magnetic pull:**
  - within `MAGNET_RADIUS` (about 6 m) of the player, it accelerates towards the player's fish,
    faster the closer it gets (so a near pass still bags it at speed);
  - within `ABSORB_RADIUS` (the hitbox, about 1 m) it's absorbed: it shrinks and streams into the
    fish as a short trail of glowing motes, with a soft pulse on the fish (tail glow, a chime hook);
  - the pull speed has to beat the player's top speed near the end, or a fast fish outruns its own
    pearls. Tune by probe.
- **Lifetime:** about 20 s, then it flickers for its last 3 s and fades, so pearls don't pile up.
- **Count:** `NatureRun.pearls`, shown on the HUD as a pearl icon and number, with a "+1" pop.
  Nothing else uses it yet.

### 8. HUD
- Top: battered count, **points**, **pearls**.
- Centre: the multi/spree callouts with the window bar, escalating per step.
- Feed: the award lines.
- Off-screen indicators: a small arrow at the screen edge towards the targeted school (and maybe
  faint ones for the others), so schools are findable without the wheel.
- The school wheel (§6).
- `set_nature` stays the entry point. It also connects the scorer and the pearl signals.

### 9. Co-op
`going_coop.md` Phase 1 makes `NatureRun` take a **list** of player fish. Build this with a list
from the start (`players: Array[FishController]`, scores, chains and pearls per player, targeting
per player's camera), even though only one player exists, so Phase 1 doesn't have to redo it.
Schools are world state, which the co-op plan has the host own. Keep the school simulation in one
place (`School`) so it can be host-run and synced later as leader positions plus a seed.

### 9b. Performance: lots of fish on screen (added 2026-10-16)
**Why.** After phase 1, the tuning you settled on is 3 schools of 50 fish at full size, and you
want many more fish on screen eventually. Phase 1 drew every school fish as a full `FishModel`
(its own nodes) with an `Area3D`, all moved by GDScript every physics tick (120 Hz).

**Measured** (`tests/school_bench`, 1920×1080, RTX 4070 Ti SUPER):

| Fish | Frame | Draw calls | Triangles | School loop per tick |
|---|---|---|---|---|
| 150 | 4.7 ms | 1,138 | 5.3 M | 1.6 ms |
| 300 | 16 ms | 3,609 | 16.7 M | 3.4 ms |
| 500 | 73 ms | 7,535 | 31 M | 5.6 ms |

**Where the time goes:**
- **Each fish model is heavy:** about 50k triangles, 11–20 draw calls, plus shadows.
- **Building one takes about 10 ms**, so a new school of 50 is a 0.5 s hitch.
- **Shadows:** turning them off alone cut 300 fish from 3,609 to 1,061 draw calls, and from
  16.7 M to 3.4 M triangles.
- **Separation:** the all-pairs check is about 75% of the school loop.

**Design:**
1. **Schools are data, not nodes.** Positions, velocities, facings and slots live in arrays on
   the `School`, with no node per fish.
2. **One MultiMesh draw per school per tail pose.** Each kind of fish is baked once, the first
   time it's needed (`SchoolLook`):
   - its model's parts are merged into one mesh;
   - it has automatic LODs (`ImporterMesh.generate_lods`);
   - there are three tail poses: centre, left and right.

   Each school draws its fish through one `MultiMeshInstance3D` per pose. A fish shows the pose
   for where its tail is in its beat, a flipbook wag, so draw calls no longer grow with the fish
   count. The whole school picks its LOD by distance.
3. **Detail fish.** The few fish nearest the camera (`detail_fish` per school, within
   `detail_distance`) are drawn as real `FishModel`s, so they get the smooth tail and skin ripple.
   Those models are built at most one per frame, so nothing hitches, and reused as the near fish
   change.
4. **No shadows** on school fish (`fish_shadows`, off by default).
5. **Simulate slower, draw smoothly.** Schools steer at `sim_rate` (30 Hz by default), not the
   physics rate, and each frame draws positions and facings interpolated between the last two
   steps.
6. **Separation from cached neighbours.** Each fish keeps a short list of nearby fish, rebuilt
   every few steps, instead of checking every pair each step.
7. **Hitboxes on demand (phase 2).** Instead of an `Area3D` per fish, a small pool of hitboxes is
   placed each tick on the fish near the player, using their extrapolated positions. That's the
   only place battered fish need them.

**Later, if GDScript becomes the limit** (thousands of fish): move the school step into the
project's GDExtension (C++), or into a compute shader. The data layout above is meant to make
that a straight port.

### 10. Settings: everything tunable, with wide ranges
You want to be able to try both a light touch and exaggerated values, so this feature gets
**no gameplay constants**. Everything goes on a `NatureSettings` resource
(`scripts/nature_settings.gd`, like `BallSettings`), which the tuning panel shows as its own
section. Its values save in presets, so `presets/nature.cfg` gets a `[nature]` section.

- **Groups** (`@export_group`, collapsible in the panel): Schools, School reactions, Hitting,
  Multis & sprees, Pearls, Targeting.
- **Wide ranges.** Each range covers far more than the sensible value, both ways: 0 turns a
  feature off, and the top end is several times the default. For example:
  - school count 0–20 and fish per school 1–60;
  - school speed 0–40 m/s;
  - spread 0.2–20 m;
  - burst strength 0–10×;
  - multi window 0.2–10 s;
  - pearl magnet 0–50 m.
- Where a slider can't hold the extremes, add the `or_greater` hint, so a typed or preset value can
  go past the slider's end. Check that `debug_panel.gd`'s sliders honour it (`allow_greater`);
  fix the panel if not.
- **Points and names tables.** The multi and spree points become arrays on `NatureSettings`, with
  a multiplier (`points_scale`) on top. The names stay in code.
- **Live changes.** Changes apply live where it makes sense, for example school spread and speed,
  and the magnet. The ones that need a respawn (count, size) apply on the next respawn, or
  through a "Respawn schools" button.
- **Leaving Nature** currently discards tuning changes made in it (an open item from the first
  pass). Since this section adds many more settings, fix that in the same phase: write Nature's
  changes back to the active Nature tuning instead of dropping them.

**The wider "make variables more flexible" pass.** Your note was about most of our variables, not
just this feature's, so this plan includes a small sweep, done at the start of Phase 1:
- Widen the existing Nature and Extra Swishy `@export_range`s (the `stride_*` exports,
  `nature_batter_speed`, the bow wave and ArcadeFx) the same way.
- Note any code constants that should be settings. Hunt's `BotDifficulty`, `StylePoints` and
  kickoff/arena constants are the obvious ones. Turning those into settings is a follow-up, not
  part of this plan, unless you want it folded in.

## Files
- **New:**
  - `scripts/nature_settings.gd` (every setting in this plan)
  - `scripts/school_fish.gd`, `scripts/school.gd`
  - `scripts/nature_score.gd` (multis, sprees, points)
  - `scripts/pearl.gd` (+ a shader for the aura/rim, `shaders/pearl.gdshader`)
  - `scripts/target_wheel.gd` (HUD wheel + hold-Y logic)
  - `tests/school_probe`, `tests/school_hits_probe`, `tests/nature_score_probe`,
    `tests/pearl_probe`, `tests/target_wheel_probe`, and `tests/school_shots` (needs a window)
- **Modify:**
  - `scripts/nature_run.gd` (schools instead of one target, population, hit query, pearls, lists)
  - `scripts/battery.gd` (shared attacking shapes)
  - `scripts/follow_camera.gd` (tap vs. hold on `ball_cam`, the near-centre aim case)
  - `scripts/hud.gd` (points, pearls, callouts, edge arrows, wheel)
  - `scripts/main.gd` (`_start_nature` wiring for the camera target)
  - `scripts/debug_panel.gd` (the `NatureSettings` section, `or_greater`, a Respawn schools
    button)
  - `scripts/fish_controller.gd` (wider ranges on the Nature and Swishy exports)
  - `presets/nature.cfg` (a `[nature]` section)
  - `tests/nature_probe.gd` (it checks `camera.ball == run.target`, which changes)
  - `README.md` (Nature section)

## Phases
Usual workflow per phase: plan → develop → headless probes → build → hand off for manual testing.

1. **Settings, then schools swimming.**
   - `NatureSettings` in the panel and presets.
   - Wider ranges on the existing exports.
   - Keep tuning changes when leaving Nature.
   - `SchoolFish` and `School`: leader route, slots, separation, noise, ripple turns.
   - Population in `NatureRun`, camera on the nearest school's centre.
   - No hitting yet.
   Hand off early: how a school *looks* swimming is the riskiest feel item.
2. **Hitting schools.** The single shape query, battering school fish, small explosions, the
   burst reaction, the bait ball, respawning wiped-out schools.
3. **Multis, sprees and points.** `NatureScore`, HUD callouts with the window bar, ArcadeFx
   escalation, the feed.
4. **Pearls.** Drops, look, magnet, absorb, the count on the HUD.
5. **Target wheel.** Tap vs. hold on Y, the wheel, auto-retargeting, edge arrows, the
   near-centre camera fix.
6. **Build and manual testing.** Expect tuning loops on school tightness, school speed, burst
   strength, the multi window, pearl chance and magnet radius.

## Verification (headless probes)
**`school_probe`:** a school alone.
- After 10 s of roaming, every fish is within `spread` × 1.5 of its slot, and no two fish are
  closer than the separation distance.
- Fish headings agree (mean dot with the leader's above ~0.9): "mostly in unison".
- A threat rushing in shrinks the school's extent (bait ball). It re-forms after a hit within
  ~2 s.
- 4 schools of 12 run for 60 s within a frame-time budget (measure the `School` loop, target well
  under 1 ms total).

**`school_hits_probe`:** the player scripted through a school.
- A straight run above `nature_batter_speed` through a tight school batters ≥2 fish, and two fish in
  the same tick both count.
- Below the speed: no hits. From the side or tail (outside `FRONT`): no hits.
- The bow wave counts as the front, as in `Battery`.
- Hunt and the 1v1 still batter exactly as before (`hunt_probe`, `match_probe`).
- `hit_speed_cost = 0` leaves speed untouched. 0.5 halves it per hit. With the minimum-speed
  guard on, a hit never takes the player under the battering speed.

**Settings:** every `NatureSettings` export appears in the panel, round-trips through a preset,
and a value past the slider's end (`or_greater`) loads and applies. Changing a setting in Nature
and leaving keeps the change.

**`nature_score_probe`:** hits fed in at chosen times.
- Hits 2 s apart chain to DOUBLE DIP, TRIPLE FRY…; a 3 s gap starts a new chain.
- Points per step match the table.
- The spree survives a gap between schools while fast, and resets after 1 s under the batter speed.

**`pearl_probe`:**
- With `pearl_chance = 1`, every battered fish drops one. With 0 and a per-step bonus of 0, none
  drop.
- With chance 0 and a per-step bonus of 0.5, single hits drop nothing, and the third hit of a
  chain always drops one.
- A fish passing 4 m away at top speed collects it (the magnet wins). One passing 10 m away
  doesn't.
- A pearl left alone expires after its lifetime. `pearls` counts each one once.

**`target_wheel_probe`:**
- A tap toggles ball cam; a hold doesn't, it opens the wheel.
- With 3 schools, the stick towards one and releasing Y targets that school.
- Wiping out the target school retargets to the nearest remaining one.
- Inside a school, the camera's turn rate stays within its normal limits (no whip-around).

**Regression:** all existing probes, especially `nature_probe` (updated), `swishy_probe`,
`hunt_probe`, `modes_probe`, `match_probe` and `aquarium_probe` (ball cam toggle).

## Decisions (user, 2026-10-16)
These replace the earlier open questions. Where a section above differs, these win.
1. **Naming:** **Battered** across the whole game, Nature free play included (the rename has
   landed; see Naming above).
2. **Multi and spree names:** fish puns (the tables in §5 are the first draft).
3. **School reactions:** schools **tighten** (bait ball) when rushed and **burst briefly** after a
   hit, then regroup.
4. **Speed cost per hit:** a setting (`hit_speed_cost`). Default it to a small amount, with a range
   wide enough for exaggerated play. More broadly, **make most variables much more flexible**:
   settings rather than constants, with wide ranges (§10).
5. **Population:** start at 3 schools of 8 fish.
6. **Schools in Hunt:** maybe in a later phase. Not part of this plan.
7. **Pearl chance rises with the multi step** (`pearl_chance_per_step`, §7).
8. **No slow-mo** while the school wheel is open.
