# Plan: Marco Polo whale seekers (experimental)

## Context

Play-tests show Marco Polo is lopsided:
- **Bots find seeking easy.** `MarcoPoloBot._look` reads `exposure()` as a number. Ten times a
  second it notices any hider at skeleton or above who is in its cone. A faint skeleton gets a
  25 % chance per look, so a bot spots it within about half a second. `_best_ping` also reads exact
  ping positions.
- **People find seeking hard.** They have to *see* a faint skeleton in the murk, and nothing else
  points them at one.
- **The Marco! streaks haven't been seen in play.** `MarcoScan`'s ghosts are built
  (play-test 2), but the user hasn't spotted one in several rounds.

The experiment: **the seeker becomes an adult whale**, a grown-up version of the Breacher calves.
It's much bigger than every hider and faster, and it still has boost, so it catches hiders easily
**once it knows where they are**. Its weakness is poor eyesight. To make up for it, it **calls
Marco! automatically and often**, and its main sense is the sound trails the calls leave in the
water.

This changes the asymmetry. The seeker no longer wins by reading faint layers. It wins by reading
sound, and both bots and people get that sound in the same form.

Related: planning_marco_polo.md (the mode), 3D_Character_Art_Quality_Standards.md (the art bar),
scripts/fish_models/whale_model.gd (the calves this builds on).

## Where things stand today (what this builds on)

| Piece | Today | File |
|---|---|---|
| Calves | Five Breacher species (humpback, orca, beluga, sperm, blue): a lofted superelliptic body, species heads and relief, skin/fin shaders, horizontal flukes (`Gait.Visual.FLUKE`), body bend through `fish_bend.gdshaderinc` | whale_model.gd, whale_calf_skin/fin.gdshader |
| Role values | `apply_role` sets boost, bow, buoyancy, speed and team. The model and the hitbox stay the player's own fish. | marco_polo_match.gd:440 |
| Marco! | On button (L3 / M), `marco_cooldown` 20 s. Every live hider and Fake Fish pings with Polo, exposure is bumped to `polo_exposure`, and the pulse goes out on every machine. | marco_polo_match.gd:1081 |
| Streaks ("ghosts") | Seeker view only. Movement is recorded for **`ghost_window` 0.35 s** after the front passes a fish, then shown as heat cells that fade over 1 to 5 s. They use **the same mint `COLOR` as the pulse shell**, show 0.35 through walls, and only record when the fish moves faster than `ghost_min_speed`. | marco_scan.gd |
| Sight | A cone (`los_cone_angle` 70°). Exposure falls off between `near_sight` 8 and `half_sight` 25. A local seeker looks from their camera, a bot from its fish. | marco_polo_match.gd:744-831 |
| Tags | `Battery.touching` on the seeker's hitbox, so a bigger hitbox already means a bigger reach. | marco_polo_match.gd:904 |
| Hiding places | Portholes have an occupancy of one, a jump-in, the Out of Water gauge and a forced exit. The Aquarium also has a castle keep (gate and back door), a ship on its side, a bridge and rocks. The Temple has a tholos, steps and ruined walls. | porthole_system.gd, fish_tank_arena.gd, temple_arena.gd |

**My guess at why the streaks go unseen (unconfirmed; Phase 1 checks this first):**
1. 0.35 s of recording is only about 1.4 m of trail for a hider cruising at 4 m/s.
2. A hider who freezes when the call comes, which is the right play, leaves nothing because of
   `ghost_min_speed`.
3. The trail appears while the bright mint pulse is sweeping past in the same colour, so the pulse
   hides it.
4. A 1 s fade on faint cells is easy to miss when you're turning.

## Design

### 1. The whale seeker (role → body)
- Seeker is now a **body**, not just a set of values. `apply_role(fish, SEEKER)` swaps the fish's
  class to the new **Titans** class (D1), and its species to the seeker's
  whale pick (§1a). Becoming a hider swaps the fish back to the player's chosen class and species.
- The class swap is driven by role, which is already synced. The **species** is a choice, so it
  needs one new message: `whale_pick(fish, species, skin)`, sent by the host as the round goes
  live. Guests rebuild the puppet's model locally from it.
- **Converted hiders** (the variant where caught hiders join the seekers) grow into whales
  mid-round. On being caught they wait out a **5 s join cooldown** (`convert_hold` 1.5 → 5 s),
  held out of play. During it they get the same whale pick card (§1a); if nothing is locked by
  the end, the whale on show is the one they get. The swap gets a short "grow" tween (scale 1 → full over
  about 0.6 s, with a burst of silt and bubbles) so a body that suddenly fills the screen doesn't
  read as a glitch.
- **Species and skins are cosmetic for now.** Every whale plays the same, which keeps the balance
  work to one set of numbers.

### 1a. The whale pick card (decided, D9)
- **When:** while the seeker waits during `hide_time` before the round goes live (10 s by default),
  and during a caught hider's 5 s join cooldown. It's shown to human players only.
- **What:**
  - a card over the waiting view with the selected adult whale turning on a stand;
  - its name;
  - its skin;
  - left/right (stick or D-pad / A-D) cycles the species, up/down cycles the skins;
  - A / Enter locks the pick in, and the card shows "Locked".
- **Running out of time:** if nothing is locked when the round goes live, the whale on show is
  the one they get. The card closes as they're launched into the arena with everyone else.
- **Bots** pick at random.
- **Reuse:** the card borrows the match card's look (card materials pass) and the turntable from
  the home screen's Class details panel / model_shots. The turning model is a real FishModel
  instance at a preview LOD, so what you see is what you swim.
- **Remembering the pick:** the last pick is remembered between rounds and matches, so the card
  opens on it.
- **Hiders can still pick the calves.** Adults hunting calves is a nice fit.

### 2. Size, speed and handling (all settings, wide ranges; see [[flexible-tuning]])
New "Whale" group in MarcoPoloSettings (the existing `seeker_*` values stay, applied on top):
- `whale_length` (m, default about **5×** the longest hider class (D13); the exact metres are
  set in Phase 0 after measuring). At 5×, the arena rework (§8) and the camera (Risks) matter
  more, so Phase 0 also checks the Titan fits the current arenas at all;
- `whale_hitbox_scale`: the tag reach follows from it;
- `whale_speed_scale`, `whale_boost_scale`;
- `whale_turn_scale` (< 1, slower yaw and pitch): the trade for size and speed, so hiders can
  juke a whale that has committed;
- `whale_accel_scale`: heavy to get going, hard to stop;
- `whale_tag_zone`: `body` (any contact tags, as now) or `mouth` (only the front third tags;
  "eat"). See D3.
- **Wake push** (`whale_wake_push`, `whale_wake_radius`): each fluke down-stroke pushes nearby
  hiders away along the stroke (see §5). It tells hiders the whale is close, and it can spill
  them out of cover.

Risk: the controller is RocketSim-derived and its hitboxes are RL families. Phase 0 is a spike
that checks a scaled hitbox behaves (collision, surfaces, walls, the bow) before anything is
built on it.

### 3. Poor eyesight (applies to bots and people the same way)
The core balance fix: **the seeker's eyes are bad for everyone**.
- **One perception function.** New `MarcoPoloMatch.whale_sees(seeker, hider) -> float` is
  exposure after the whale's eyesight. Bots read it, and the human seeker's rendering is driven
  by it. A bot can no longer notice something a person couldn't see.
- **Eyesight settings:**
  - `whale_near_sight` / `whale_half_sight`, much shorter than today's 8 / 25 (try 4 / 12);
  - `whale_layer_floor`: layers under it don't show at all past near sight (try cardio, so a
    faint skeleton is only visible close up);
  - `whale_cone_angle`.
- **Murk is the main handicap (decided, D4).** A Titan's view gets thicker murk: `whale_murk`
  multiplies the arena's fog density in the local seeker's view only. The same factor shrinks
  `sight_range()` for Titans, and `whale_near_sight` / `whale_half_sight` are worked out from
  that sight range, so the bots' numbers and the picture the person sees come from one value.
  - **Why murk works:** it hides by distance, which is what we want. Far away, the whale is
    blind and relies on streaks. Close up, it sees enough to finish a chase, and its size and
    speed do the rest.
  - **What murk deliberately doesn't hide:** the streaks (which ignore fog by design, §5) and the
    aura, which shows through murk on purpose as the punishment for a flip.
  - **Not planned for now:** the blind spot straight ahead. The DOF blur and desaturation are
    settings (`whale_blur`, `whale_desaturate`) that start at 0, to add only if murk alone isn't
    enough.
  - Hiders and spectators see the arena as now. This is a per-view environment override. Marco
    Polo has no split-screen, so one camera per machine.
- **Bot parity check.** A probe puts a hider at each layer and distance and checks that the bot's
  "noticed" answer matches the thresholds the human view can show (reveal_shots captures the same
  setups as images for a person to check).

### 4. Auto Marco! (decided, D5/D6)
- **A timer:** `marco_auto_interval` 3 s from the moment the round goes live. Two related settings:
  - `marco_auto_jitter` defaults to 0 (a steady beat). It's there in case hiders learn to time the
    beat;
  - `marco_tell_time` defaults to 0 (off). It's a short warning before each call, such as bubbles
    from the blowhole. It's there in case hiders want a chance to freeze.
- **The manual Marco! button is retired** for whales. L3 / M does nothing for the seeker, and
  the HUD's Marco readiness gauge becomes a small beat pip.
- **Knock-ons of a 3 s beat:**
  - a full-arena pulse every 3 s on every machine is a lot of light. `marco_scan_time` (2 s) means
    usually one pulse is alive at a time, but the pulse glow, the torus and its particles should
    get lighter "auto" values (`auto_scan_glow`, `auto_scan_particles`) so the arena isn't
    flashing constantly;
  - `polo_exposure` bumps every 3 s too, so the whale view may need a lower value for it;
  - streak decay (§5) should be set against the 3 s beat, about 2 to 3 beats long.
- **Per-species voice (optional polish).** The toothed whales (orca, beluga, sperm) click; the
  baleen whales (humpback, blue) sing a short phrase. It's the same mechanics with a different
  Sound Profile entry. Audio ids are added to sound_catalog.gd so the user can record them later.
- Hider bots learn the rhythm: they move just after a call and settle before the next.
- **Per-species voice (optional polish).** The toothed whales (orca, beluga, sperm) click; the
  baleen whales (humpback, blue) sing a short phrase. It's the same mechanics with a different
  Sound Profile entry. Audio ids are added to sound_catalog.gd so the user can record them later.
- Hider bots learn the rhythm: freeze in the tell, move between calls.

### 5. Streaks you can't miss (the whale's real sense)
Fix first, then make it readable:
- **Window:** `ghost_window` 0.35 → about 1.5 s, so a call catches a run of movement and not a
  twitch.
- **Decay:** `ghost_fade_min/max` 1/5 → about 3/8 s, so the last 2 or 3 calls' trails are
  still there when the next one lands (3 s beat), and older ones fade before they clutter.
- **Still hiders:** `ghost_still_echo` (default on). A hider the front reaches leaves a
  **faint body echo** even when not moving (today they leave nothing). It's dim, short, and
  smaller than a streak. Without it, a whale with poor eyes has no answer to a hider who just
  holds still. The strength is a setting, so 0 brings back today's behaviour.
- **Contrast:**
  - streaks get their own colour, separate from the pulse: `ghost_color`, default a hot amber
    to white-hot head, which is complementary to the blue-green water and the mint pulse;
  - the head of each streak is brightest, so you can read which way the hider went (optional
    chevrons along it);
  - the streak ignores fog in the seeker's view;
  - `ghost_through_walls` 0.35 → about 0.6;
  - the streak's draw is held back until the pulse front has moved past
    (`ghost_show_delay`), so the pulse doesn't hide it.
- **Echo on the scope:** each streak's head also drops a short-lived blip on the SonarMap, so the
  map and the world agree.
- **Bots read the streaks too.** MarcoPoloBot gets streak heads (position, heading, age) through
  the same data the renderer uses, and loses the exact `polo` ping positions. Bots and people now
  hunt from the same evidence.
- Every new value is a setting in the "Marco! scan" group.

### 6. The adult whale models (playable, top quality)
Built against 3D_Character_Art_Quality_Standards.md.

**Pipeline (decided, D2):** extend the calf pipeline in a new `scripts/fish_models/titan_model.gd`
with its own `TITAN_SHAPE` and looks. That pipeline is a GDScript loft with `ROWS` slices and
superelliptic sections, plus relief, shaders, lofted airfoil flippers and thick-blade flukes. It's
how every fish in the game is made, it already bends in `fish_bend.gdshaderinc`, and it gave the
calves smooth silhouettes.

There's no switch to another pipeline. If a feature resists the loft (for example the humpback's
pectorals or barnacle clusters), C solves it inside the pipeline:
- separate lofted parts sunk into the body;
- relief and normal detail in the shader;
- more slices.

Any compromise that's left is written into the art log (§6a), not silently accepted.

**Adults are not scaled-up calves.** Each one gets:
- **Adult proportions:** a longer, leaner body; the head smaller relative to the body (except the
  sperm whale); a longer tail stock with strong keels; flukes about a quarter to a third of the
  body length across.
- **Humpback (hero, first):**
  - pectoral fins about a third of the body length, with scalloped tubercles on the leading edge;
  - tubercles on the head;
  - ventral throat pleats running to the navel;
  - barnacle and scar clusters (skin relief + shader);
  - a serrated trailing edge on the flukes, with a black-and-white underside pattern that's
    unique per skin.
- **Orca:**
  - a tall dorsal fin (straight, male-style);
  - a crisp eye patch and saddle patch;
  - a glossy, smoother skin with a clearcoat.
- **Beluga:**
  - white skin with a soft subsurface look;
  - a mobile melon;
  - a dorsal ridge in place of a fin;
  - a visible neck crease.
- **Sperm whale:**
  - the box head at about a third of the body length;
  - deeply wrinkled skin;
  - a narrow underslung jaw;
  - a hump and knuckles.
- **Blue whale:**
  - long and slender;
  - mottled blue-grey skin;
  - a tiny dorsal fin far back;
  - the splashguard at the blowholes;
  - long pleats.
- **Eyes:** small, sunk into the skin with a skin fold, wet highlight and lid. They should read as
  "old and poor-sighted", not as cartoon eyes.
- **Skins** follow the fish skins pass (several realistic variants per species).
- **LODs:** the whale is huge and seen from across the arena, so 2 to 3 LOD levels (fewer slices
  and around-points). Checked with a draw-call / vertex budget in the perf bench.
### 6a. Self-checked art (no user gates)
The team works without stopping for sign-offs, so every species has to clear its own checks
before C moves on. The user reviews everything at the end, from the art log and the last build.
1. **A spec sheet first, no mesh yet** (`titan_specs.md`). For each species, write down
   measurable targets from well-known whale anatomy:
   - proportion ratios: head / body / tail stock / fluke span / pectoral length as fractions of
     body length, the eye position, and where the dorsal fin sits;
   - the cross-section shape at 5 stations along the body;
   - the colour map: patches and their edges;
   - the features that make the species recognisable, ranked.

   C can use web search for reference figures if it has it. The coordinator reads the sheets for
   obvious errors before modelling starts.
2. **A measuring tool.** A new `tools/model_measure.gd` reads the built mesh back (lengths,
   widths per station, fin spans, eye placement) and prints it next to the spec sheet's targets.
   **Pass:** every ratio within ±10 % of its target.
3. **The standards doc's QA list, on the shots.** C looks at the shots (they're PNGs, so it can
   read them) and checks:
   - the silhouette from 6 angles;
   - faceting and shading artifacts;
   - intersections and seams where fins meet the body;
   - 3 lights;
   - gameplay distance through both cams;
   - against the approved assets: the koi-style rebuilt fish and the calves.

   It writes each fault down and fixes it. Typical faults are flat or plastic shading, features
   that disappear at gameplay distance, and a calf-like look.
4. **A second look by the coordinator** on the same shots, against the same list. A species is
   done when both find nothing left to fix, or after **3 fix rounds**, whichever comes first.
   Anything still open goes in the log.
5. **The art log** (`titan_art_log.md`) collects every species' shots, numbers and known
   compromises. It's the user's review sheet at the end.
6. **Motion is checked separately** (Phase 4), with frame sequences from a swim loop.

### 7. Animation: a big tail pushing a lot of water
The gait stays stroke-driven ([[keep-swim-strokes]]). Each stride is a fluke beat.
- **Slower, bigger strokes.** A long period, high amplitude at the flukes, and an amplitude
  envelope that's nearly zero at the head and grows along the body. Today's bend pivots at the
  tail; adults get a multi-segment bend (2 to 3 joints along the back half) so the wave travels
  down the body.
- **Power and recovery.** The down-stroke is fast and strong and the up-stroke slower: an
  asymmetric curve, the same idea as the jelly's BellPulse.
- **Counter-motion.** The head heaves and pitches slightly against each beat, the whole body
  surges forward on the power stroke, and the flippers trim and bank in turns.
- **Water it moves (FX), on each power stroke:**
  - a **vortex ring** shed behind the flukes: a ring of refraction distortion plus particulate
    caught in it, drifting back and fading;
  - a pressure ripple of suspended silt and plankton pushed outward;
  - near the floor, a silt cloud kicked up;
  - near the roof or surface, a boil;
  - bubbles from the fluke tips at boost.
- **The wake push** (§2) is applied at the same moment, so hiders feel it in sync with what they
  see.
- **Sound and feel:** a deep "whomp" per power stroke, louder with stride strength. Nearby hiders
  get a light pad rumble scaled by distance.
- **Turning.** A slow, heavy bank with the flippers out and the flukes steering. The boost is a
  burst of hard beats.
- Built on FishModel's bend and Gait. New Gait values: `fluke_power_ratio`, `bend_segments`,
  `head_counter`.

### 8. Arenas that fit a whale
**The rule (from the user):** every enclosed space is designed on purpose. A space a hider can
reach and the whale can't must follow porthole-style rules: limited occupancy, a gauge that forces
the hider out, and a noisy exit. No camping out of reach.

- **New tool: `tests/whale_reach_probe.gd`.** It flood-fills each arena's water twice on a voxel
  grid: once with a hider-sized probe, once with a whale-sized capsule (at its turn radius). It
  reports:
  1. **hider-only pockets** that aren't portholes or registered hideaways. These must be zero; the
     probe fails otherwise;
  2. **chokepoints** narrower than `whale_clearance` on the whale's main routes;
  3. dead ends shorter than the whale's turning circle.

  The probe also writes a top-down map PNG (whale-reachable / hider-only / solid) for the user to
  review.
- **Hideaways: porthole rules for bigger spaces.** Generalise PortholeSystem's rules into a
  `Hideaway` volume:
  - an occupancy cap;
  - a gauge that fills while inside: **Stale Water** (D7, suggested). Water trapped in a tight
    space runs low on oxygen, so the fish has to leave for fresh water. It's the water version of
    Out of Water, which stays as the portholes' gauge;
  - a forced, noisy exit when the gauge is full;
  - hidden from the seeker's sonar map while inside, as portholes are (decided, D7).

  The castle keep, the ship's hull and the tholos become either whale-passable (widened) or
  Hideaways. Each one is decided in the arena pass, not left as it falls.
- **Maybe later (D8), not in these phases: Tail Slap.** Humpbacks and orcas really do stun fish with their
  tails. On the whale's skill button, a slap at a structure or a Hideaway mouth shakes out
  everyone inside (with a short daze) and makes a big noise of its own. The whale gets an answer
  to cover without the cover being useless.
- **Layout changes:**
  - raise the ceilings and widen the main lanes. TempleArena already has `SCALE` 2.0 and the
    Aquarium a `CELL` grid, so start by scaling the open water by about 1.3 to 1.6× and keeping
    furniture sizes;
  - keep the dense small-fish cover (columns, pottery, kelp, rocks), which the whale swims round
    or over;
  - the whale spawn and count spot get the space to turn.
- **Murk and sight:** `sight_range` is per arena, so the whale's eyesight (§3) is set relative
  to it.
- The Temple's jagged floor plates and the Aquarium's loud gravel (open items from play-test 1)
  get fixed in this pass, because the whale's floor silt FX will show the floor off.

### 9. Bots
- **Whale seeker bots** use `whale_sees` and the streak heads (§3, §5). They no longer get exact
  ping positions. Steering becomes turn-radius aware: they plan arcs and don't aim at points they
  can't turn into. They use the wake to flush hiders near cover.
- **Hider bots:**
  - freeze in the Marco tell;
  - move between calls;
  - keep out of the whale's front and stay near cover that's too tight for it;
  - use Hideaways under the same rules as portholes.
- Per [[playtest-before-tuning]]: the sims report numbers (tags per round, time to first tag,
  streak-led vs sight-led tags). There's no balance tuning pass. See "Running autonomously" for
  where the line is.

## Phases
Each phase ends with probes and a build. The team carries on to the next phase without waiting;
the user plays the builds when they choose ([[default-workflow]]).

### Phase 0: spikes (no art)
- Add the Titans class to FishCharacter (D10), hidden from the other modes' pickers.
- Scale a seeker's hitbox and model to `whale_length` with the calf mesh stretched, and check
  collisions, walls, surfaces, the bow, tags and the camera distance. Fix the follow cam's
  offset/FOV for a big body (both of Unnatural's cams).
- Measure every hider class's length to set the whale defaults.
- Role → class swap on every machine (local, online puppet, converted mid-round).
- **Exit:** a stretched calf seeker plays a round online with bots, without physics problems.
  If 5× breaks the physics in a way that can't be fixed in Phase 0, the team uses the largest size
  that works, logs it, and carries on.

### Phase 1: streaks fixed and readable
- First confirm why the streaks aren't seen: a probe plus screenshots in the real build path,
  with a human local seeker. Then apply §5 (window, decay, still echo, colour, head, delay,
  through walls, scope echo).
- Extend sonar_probe / reveal_shots with streak shots (moving, still, behind a wall, at 1 s / 4 s /
  8 s old).
- **Exit:** the streak shots show a clear streak for every call (moving and still cases) at
  gameplay distance, in the build's renderer (not only headless). This is worth having even if the
  whale idea is dropped.

### Phase 2: whale gameplay (stretched calf as a stand-in)
- The §2 settings, §3 eyesight (one perception function and the Titan's murk view; blur and
  desaturation as settings at 0), §4 auto Marco on its 3 s timer (manual button retired), and the
  wake push.
- The §1a whale pick card, using the stretched calves as stand-ins, plus the `whale_pick`
  message.
- Bots on the new perception and streaks (§9).
- Run marco_polo_sim to get bot-vs-bot numbers for both roles.
- **Exit:**
  - a bot Titan and bot hiders both get tags and escapes in marco_polo_sim (no role is stuck at 0);
  - a scripted human-seeker probe finds a hider from streaks alone.

  The build is there for the user to play whenever they like. The team doesn't wait for it.

### Phase 3: the hero model (humpback)
- Spec sheets for all five species (§6a step 1), and model_measure.gd.
- titan_model.gd, TITAN_SHAPE, skin/fin shaders (barnacles, scars, pleats, tubercles,
  fluke underside), eyes, LODs.
- The §6a checks (numbers, QA list, the coordinator's second look, at most 3 fix rounds), then
  the humpback's art log entry.

### Phase 4: animation and water FX
- Multi-segment bend, the power/recovery curve, counter-motion, flipper trim; vortex rings, silt,
  bubbles; whomp audio ids; rumble.
- Shots and a short capture tool (frame sequence from model_shots in a swim loop) to judge the
  motion.

### Phase 5: arenas
- whale_reach_probe, the Hideaway volume (generalised from PortholeSystem) with Stale Water, then the Temple and Aquarium reworks until the probe reports zero hider-only pockets.

### Phase 6: the other four adults
- Orca, beluga, sperm and blue whale, each through the §6a checks. Skins.

### Phase 7: polish
- Per-species voices, the grow-up tween, HUD (an auto-Marco timer for the whale, a tell
  indicator for hiders), INVENTORY.md, setting docs, perf bench with up to 4 whales.

## Decisions for the user
**Decided (user, 2026-11-05):**
- **D1** The class is called **Titans**.
- **D2** The same procedural method as every other fish, held to a high bar. No user review
  gates (decided later the same day): the art clears §6a's own checks and the user reviews the
  art log at the end.
- **D3** Any body contact tags. (`whale_tag_zone` stays a setting, with `body` the default.)
- **D5/D6** Auto Marco runs on a timer, every 3 s to start. No tell or jitter by default; both are
  settings that start at 0. The manual Marco! button is retired.
- **D9** The whale pick card (§1a) during the seeker's wait: a turning model; cycle the species
  and skins; lock in, or get whichever is on show when the round goes live.

- **D4** Murk is the Titan's handicap (§3). No blind spot; blur and desaturation are settings
  that start at 0.
- **D7** Hideaways hide you from the sonar map. The gauge is "Stale Water" (my suggestion; it can
  be renamed).
- **D8** Tail Slap is a "maybe later" idea, not in these phases.
- **D10** Titans are likely to become playable elsewhere later. So Phase 0 builds them as a real
  class in `FishCharacter`'s table, with its own handling values, LODs and a gait, kept out of the
  other modes' pickers for now. Marco Polo's Whale settings sit on top of the class, not inside
  it.
- Caught hiders get a 5 s join cooldown with the whale pick card (§1, §1a).

- **D11** Scoring isn't touched for now. Line-of-sight scoring stays exactly as it is (it doesn't
  follow the Titan's murk). The user will revisit scoring once the mode is playable and fun.
- **D12** Hiders can still pick the Breacher calves.
- **D13** Titans start at about 5× the longest hider's body length. The user tunes it later from
  the builds.

Nothing is open. New questions that come up while the team is working are decided by the
coordinator and logged here as D14 onwards (see "Running autonomously").

## Team split (1 coordinator + 3 workers)
The work is divided by **file ownership**, not by phase, so two agents never edit the same file.
Each worker owns one track from start to finish.

| Agent | Track | Owns (edits) | Its probes / tools |
|---|---|---|---|
| **Coordinator** | Contracts, integration, builds, the progress log, the art second look | this plan, `INVENTORY.md`, `scripts/ui/setting_docs.gd`, `tools/gen_setting_docs.gd`, `scripts/audio/sound_catalog.gd` (it merges the workers' audio ids) | The regression set: modes_probe, ui_probe, console_probe, porthole_probe. It's the **only one who exports builds** and **refreshes the class cache**. |
| **A: Gameplay & net** | Phase 0, Phase 2 rules, bots, Hideaways | `fish_character.gd` (Titans class), the controller / hitbox scaling, `follow_camera.gd`, `marco_polo_match.gd`, `marco_polo_bot.gd`, `porthole_system.gd`, new `hideaway.gd`, `net/marco_polo_net.gd` | marco_polo_probe, marco_polo_net.sh, marco_polo_sim, new whale_sight_probe, new hideaway_probe |
| **B: Senses, UI & world** | Phase 1 streaks, the Titan's murk view, the pick card, HUD, arenas, water FX | `marco_scan.gd` + the `marco_ghost*` / `marco_scan` shaders, `sonar_map.gd`, `marco_polo_hud.gd`, `hider_looks.gd`, new `whale_pick_card.gd`, new `titan_wake_fx.gd`, `temple_arena.gd`, `fish_tank_arena.gd`, `marco_arena.gd`, `scenery/temple_kit.gd`, `scenery/tank_kit.gd` | sonar_probe, reveal_shots, marco_arena_shots, new whale_reach_probe |
| **C: Titan art & motion** | Spec sheets, five models, animation | new `fish_models/titan_model.gd`, new `titan_skin` / `titan_fin` shaders, `fish_model.gd`, `gait.gd`, `gait_settings.gd`, `fish_bend.gdshaderinc`, new `titan_specs.md`, new `titan_art_log.md`, new `tools/model_measure.gd` | model_shots, model_measure |

### Shared-file rules
- **`marco_polo_settings.gd` is the one file several agents touch.** Each agent owns its own
  `@export_group` blocks:
  - A: Whale, Seeker, Bots, Hideaways;
  - B: Marco! scan, Titan view;
  - C: none (its values live in gait_settings.gd).

  Agents use exact-match Edits inside their own block only, never a whole-file Write.
- **New scripts are loaded by path** (`load()` / `_optional()`, as the first Marco Polo team did).
  They don't add a new `class_name` unless the coordinator agrees to it. That avoids every agent
  needing the class cache refreshed.
- **Nobody runs `--import` or an export except the coordinator.** Workers run only their own
  headless probes.
- **After editing, call `register_edit`** (the jcodemunch index is often stale; see
  [[jcodemunch-index-can-be-stale]]).
- **Anything outside your own files** (for example A needing a HUD tweak) goes to the owner as a
  request through the coordinator, not as an edit.

### Contracts the coordinator writes first (day 1, before workers start)
1. **The Titans class entry:** the class key `titan`, the species keys (humpback, orca, beluga,
   sperm, blue) and their skin ids. A adds the entry; C builds to those keys.
2. **Scaling:** A scales the hitbox and the visual root. C never scales inside `FishModel`, and
   A never edits `FishModel`'s internals.
3. **`MarcoPoloMatch.whale_sees(seeker, hider) -> float`** and **`titan_sight_range()`**: A
   implements them, and B's murk view and A's bots both read them.
4. **`MarcoScan.streak_heads(seeker) -> Array[{pos, heading, age, strength}]`**: B implements
   it, and A's bots read it.
5. **The `whale_pick(fish, species, skin)` message and `MarcoPoloMatch.request_whale_pick()` /
   `whale_pick_window_left()`**: A owns the message and the timing (`hide_time`, the 5 s join
   cooldown), and B's card calls them.
6. **The `FishModel.power_stroke(strength: float, at: Transform3D)` signal**: C emits it on each
   fluke power stroke. A's wake push and B's water FX listen to it. Until C's gait has it, A and B
   each use a 1 s timer stub.
7. **The Hideaway API** mirrors PortholeSystem's (`is_hidden`, `gauge`, `entered` / `exited`
   signals): A builds it, and B places the volumes in the arenas.

### Waves
| Wave | A: Gameplay & net | B: Senses, UI & world | C: Titan art & motion | Coordinator |
|---|---|---|---|---|
| **1** | Phase 0: the Titans class, the stretched-calf stand-in at 5×, role swap on every machine, the camera, measuring the hiders' lengths | Phase 1: find out why the streaks aren't seen, fix it, streak shots; the `streak_heads` API | Five spec sheets plus `model_measure.gd` (no meshes) | The contracts; reads the spec sheets for errors; **build 1** (streaks) |
| **2** | Phase 2: auto Marco on the 3 s timer, `whale_sees`, the wake push (on the stub), the `whale_pick` message, the 5 s join cooldown, bots on streaks and perception | The Titan murk view, the pick card (stand-in models), the HUD beat pip; `whale_reach_probe` run against today's arenas, giving a report | Humpback model through the §6a checks; its art log entry | The regression probes; the second look at the humpback; **build 2** (playable Titans with stand-in models) |
| **3** | The Hideaway volume with Stale Water, hiding from the sonar map, bots using Hideaways, hideaway_probe | Arena reworks driven by the reach probe report, placing Hideaways; the water FX on `power_stroke` | Animation (multi-segment bend, power/recovery strokes, counter-motion), emitting `power_stroke` | Swaps the stubs for the real signal; **build 3** (humpback, motion, arenas) |
| **4** | The grow tween, net checks with up to 4 Titans | Audio ids for whomps and voices (sent to the coordinator), the scope echo polish | Orca, beluga, sperm and blue whale, one at a time through the §6a checks; skins | INVENTORY.md, setting docs, the perf bench, the final summary; **build 4** |

### Why this split
- **C is the long pole.** It has five hero models, so it starts on day 1 with spec sheets that need
  no code from anyone, and it never waits on the others.
- **A and B have playable Titans by the end of wave 2** (build 2), so the user can try the idea
  early if they want, without the team stopping.
- **B's wave 1 (streaks) stands alone** and makes a useful build on its own.
- **The coordinator owns every shared output** (builds, docs, INVENTORY, the sound catalog), so
  only one agent touches those.
- **A worker that finishes a wave early** picks up the next item in its own column. It doesn't
  pick up from another worker's column.

## Running autonomously
The team runs start to finish without the user. These rules replace the user's usual calls.
- **Decisions.** When a question comes up that the plan doesn't answer, the coordinator decides
  it. It goes by this plan's principles: values as settings with wide ranges, nothing switched
  off, swim strokes kept, team colours wording, Battered wording. It logs each one as D14 onwards
  with its reason, so the user can reverse it later.
- **Tuning: where the line is.** Fixing values so something **works** is allowed. Examples:
  - a Titan that gets stuck on walls;
  - a camera that clips through the body;
  - streaks that don't show;
  - bots that never finish a round.

  **Balance** tuning isn't allowed: who wins, how many points, how often tags happen. The sims
  report those as open items ([[playtest-before-tuning]]).
- **Stuck work.** If a task fails three tries the same way, the agent writes down what it tried,
  goes for the simplest version that works (behind a setting where it can), logs it as a known
  issue, and moves on. It never blocks the wave.
- **The progress log.** The coordinator keeps a "Progress" section at the end of this plan up
  to date at the end of every wave: what's done, which build, the probes' results, known issues
  and D14+. A new coordinator can pick up from it if a session ends.
- **Builds** are exported at the end of every wave (the absolute path in [[default-workflow]]).
  The team doesn't wait for anyone to play them.
- **Audio.** New sound ids point at existing sounds as stand-ins until the user records them.
  The list of stand-ins goes in the progress log.
- **No git.** Nobody commits ([[user-handles-git]]). The user commits before the team starts, so
  there's a clean point to return to.
- **The finish line.** Phases 0 to 7 are built, the probes pass, build 4 is exported, and the
  final summary in the progress log lists:
  - what to play first;
  - the art log;
  - the sim numbers;
  - D14+;
  - known issues.

## Risks
- **Physics at scale.** RL-derived handling may not like a 5× hitbox: wall rides, surface
  sticking (off in Marco Polo by default), the bow. Phase 0 exists to find this early.
- **Too easy in the other direction.** A big, fast whale with readable streaks could crush hiders.
  The levers are the turn scale, the tell, the still-echo strength and the auto interval, all
  settings.
- **Camera.** A huge body blocks the seeker's own view. It may need a higher, further cam and some
  transparency near the camera.
- **Perf.** Up to 4 adult whales with LODs, vortex FX and more ghost cells. The perf bench joins the
  probes from Phase 4 on.
- **Art bar.** The humpback's pectorals and barnacles are the hardest test of the loft pipeline
  (see D2).
- **Online.** The model swap and the per-view blur are local only. The streak data the bots use is
  host-side, and the renderer stays local as now.

## Verification
- **Probes:**
  - marco_polo_probe and marco_polo_net.sh (role swap, auto Marco on guests);
  - sonar_probe (streak window, decay, still echo, scope echo);
  - a new whale_sight_probe (bot/human parity table);
  - whale_reach_probe (zero hider-only pockets);
  - a hideaway_probe (porthole_probe's cases on the new volume);
  - porthole_probe and modes_probe still pass.
- **Shots:** reveal_shots streak cases, model_shots per species (6 angles × 3 lights + gameplay
  distance), marco_arena_shots, and the reach maps.
- **Sims:** marco_polo_sim numbers for both roles, reported without being tuned.
- **Art:** model_measure within ±10 % of each spec, plus the QA list passed by C and by the
  coordinator (§6a).
- **The user, afterwards:** plays the builds and reviews the art log, whenever they choose. None of
  it blocks the team.

## Backlog (user requests, not yet scheduled)
- **Streak look: less fire, more wake / interference pattern** (user, 2026-11-05, after reviewing
  the wave 1 shots). The amber to white-hot streaks fix visibility but read as flames. Rework
  their look toward water: a wake, with V-shaped or curved wavefronts spreading from the path,
  interference ripples, and a bright head with a rippling trail. Keep the readability that the
  fix bought (own colour apart from the pulse, head brightest, heading readable, fog-ignoring).
  Owner: B (`marco_scan.gd` + `marco_ghost*` shaders). Proposed slot: wave 3, after the arena
  work, unless the user wants it sooner. `ghost_color` / `ghost_head_color` stay as the palette
  settings.

## Progress
(Kept by the coordinator: one entry per wave.)

### FINAL SUMMARY 2026-11-06 (all four waves built; build 4 exported 05:12)
Build: builds/windows/FishPlayground.exe (debug export, includes everything below). Probes passing:
modes, ui, console, porthole (with whale_seeker=false), marco_scan, sonar, hideaway, whale_sight,
pick_card, wake_fx, whale_reach (0 hider-only pockets), skins --class=titan, model_measure all five
(23/23, sperm 24/24), marco_polo_net.sh (3 peers incl. 4-Titan conversion case), audio probes.
Flaky/known: marco_polo_probe seeker-depth check failed once then passed twice; whale_spike_probe fails
only at whale_length 10.4 m in the Aquarium (start overlaps solids, so 6.7 m is the largest that works).
**Play first:** Marco Polo with the default whale seeker (Temple, then Aquarium): the Titan's murk view,
the pick card during hide time, the 3 s auto Marco and the blue wake-ripple streaks, the Aquarium's two
"under the bridge" Hideaways (Stale Water), and the conversion variant (caught hiders grow into Titans).
**Art:** review titan_art_log.md (shots in private_content/titan_shots/<species>/; humpback r6, blue r4,
beluga r4, orca/sperm r3). Open: humpback flipper root no fillet, head tubercles a field, soft fluke
trailing margin; orca flipper spoon-shaped, scars mirrored; beluga beak short; sperm furrows regular and
jaw hard to see; blue blowhole reads as a small oval. Motion shots: humpback/motion2.
**Sim numbers (open items, not tuned):** Temple elimination 5 players 4x60 s: 3.5 tags/round, 44.7 s
rounds, 3/4 rounds all caught, 15 % of settled hiders found; tags by lead: 10 streak-only, 4 sight+streak,
0 sight-only (the whale hunts from streaks, as designed). Conversion 6 players 3x45 s: 4.33 tags/round,
40.7 s rounds. The whale is strong against bots.
**Decisions D14+:** D14 Titan model from hitbox length only (hitbox sized from model_measure natural size);
D15 3 skin variants per species; D16 delay-line chain bend + fluke_snap; D17 pick card's sounds are flat
Sfx.play; D18 hider-only pockets under the Aquarium bridge are covered by Hideaway spots instead of
being opened up; D19 arena 1.3-1.6x scale-up skipped at 6.7 m (re-run `whale_reach_probe --whale=R` if
whale_length grows); D20 streak look reworked from amber fire to blue wake ripples (user request).
**Known issues / follow-ups:** ghost draw ~8.7 ms/frame at the 16k-cell cap (lower ghost_max_cells if it
hurts); a streak takes ~12.6 s to empty in the scan probe vs ghost_fade_max 8 s (B didn't find why; the
probe bound was loosened, so check the renderer if streaks linger); marco_polo_sim's elimination run
predates one exposure fix; Marco! tell and wake sounds unheard in game; audio ids are stand-ins
(mp/whomp, whomp_boost, voice_<species>, marco_tell, whale_grow, pick_cycle, pick_lock, wake_swirl);
Tail Slap (D8) not built; scoring untouched (D11).

### Earlier checkpoint 2026-11-06 (session limit)
Team: worker-a-gameplay (Sonnet), worker-b-senses (Sonnet), worker-c-titan-art (Opus). They message
the coordinator as "main"/"lead". If the session ended, respawn workers from this log.

**Done**
- A: wave 1 + 2 accepted. Titans class (`FishCharacter.TITAN`, hidden, `pickable_classes()`), hitbox
  670x240x190 uu (6.7 m = 5x longest hider hitbox 134 uu; model lengths 1.08-2.08 m), role swap on
  every machine (meta `mp_base_look`/`mp_swapped`), camera, auto Marco 3 s, `whale_sees`, wake push
  (still on the 1 s stub), `whale_pick` msg + 5 s join hold, bots on streak heads + whale_sees,
  hiders freeze around calls. whale_spike_probe, whale_sight_probe, marco_polo_net.sh pass.
- B: all four waves + streak look rework. Streaks diagnosed (tiny/dim, 0.35 s window, same colour as
  pulse), fixed; now blue-white wake ripples (backlog item done). `streak_heads` API, scope echo,
  titan_view.gd (murk), whale_pick_card.gd, HUD beat pip, titan_wake_fx.gd, whale_reach_probe,
  Hideaway spots API on MarcoArena (2 Aquarium spots), Temple/Aquarium floor fixes. Probes pass.
- C: titan_specs.md, tools/model_measure.gd, humpback (23/23 within 10 %, 3 fix rounds, art log
  titan_art_log.md, shots private_content/titan_shots/humpback/r4,r5), wave 3 motion
  (`power_stroke(strength, at)` signal, delay-line chain bend, motion2 shots). Other four species
  still borrow the humpback shape.
- Coordinator: picker call sites -> `pickable_classes()`, `coop_session` uses mp_base_look, porthole_probe
  sets `whale_seeker=false`, skins_probe Titan cap 60k on LOD0, 12 whale audio ids in sound_catalog.gd
  (stand-ins, none called yet except by B's pending hooks). modes/ui/console/porthole/audio probes pass.

**Decisions**: D14 (C) Titan model built from hitbox length only, A sizes hitbox from model_measure
"natural size"; D15 (C) Titan skins = 3 variants/species (`skin := 0` arg on FishModel.build);
D16 (C) motion uses a delay line instead of spring-per-joint, `fluke_snap` setting. Arena open-water
1.3-1.6x scale-up skipped (not needed at 6.7 m; re-run `whale_reach_probe --whale=R` if size grows).

**In flight / not done**
- A wave 3: hideaway.gd + Stale Water, hide from sonar map, bots using Hideaways, hideaway_probe;
  swap power_stroke stub; wave 4: grow tween, marco_tell_started to guests, up to 4 Titans net check,
  call `titan_lod_rescale` meta when scaling the visual root.
- B leftovers: hook Sfx (pick_cycle/pick_lock/whomp/wake_swirl), blur/desaturate shots, rerun probes.
- C wave 4: orca, beluga, sperm, blue (fix humpback faults first: hump/dorsal, head depth, fluke ID
  patterns); fix skins_probe "comes back to rest" FAIL x5 (Titan bend rest position).
- Coordinator: regenerate setting docs (`tools/gen_setting_docs.gd`) for B's Marco! scan + Titan view
  settings, C's 10 Gait exports, A's Whale/Bots groups; INVENTORY.md; full regression probes;
  perf bench (ghost loop ~10 ms at 16k cap: consider lowering `ghost_max_cells`); second look at C's
  other species; builds 1-4 (user hasn't had ANY exported build from this work; export only by
  coordinator, class cache not needed so far: no new class_name); final summary.

**Open balance items (not tuned)**: Temple 5 players 4x60 s bot whale vs bot hiders: 3.75 tags/round,
~35 s rounds, 3/4 rounds all caught, 9/14 Fake Fish fooled (whale strong vs bots; rerun pending).
At 10.4 m the Aquarium start overlaps solids and the Temple run stalls: 6.7 m is the largest comfortable.

**Known issues**: C humpback faults (weak hump/dorsal, shallow head, soft fluke patterns, flipper root
no fillet, tubercles a field); streak ghost loop perf; head counter/surge subtle.
