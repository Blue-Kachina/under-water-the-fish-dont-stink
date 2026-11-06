# Plan: Marco Polo (hide-and-seek by sound)

## Context
A new match mode built on Nature's swimming. Each round, one player is the **seeker** and everyone
else is a **hider**.
- Hiders swim as normal. They **score while they're in the seeker's line of sight**, and more the
  more of them the seeker can see. So the game is to be bold near the seeker without getting caught.
- The seeker can't see hiders properly. A hider who keeps still is fully invisible. As a hider makes
  noise, the seeker sees them **build up in layers: skeleton → cardiovascular → muscular → skin →
  aura**. Flips are loud, swimming fast is loud, and badly timed strides are louder still.
- Hiders sink a little (slightly negative buoyancy), so staying high in the water costs strides,
  and strides make noise.
- Once per round, each hider can throw out a **Fake Fish**: a noisy decoy that draws the seeker off.
- The arenas are furnished and walled. The walls have **portholes** a hider can duck into to
  vanish for a while. Portholes are small and hard to get into. Stay in too long and it's **fish
  out of water**, which counts as being caught.
- The seeker's minimap shows no players. It's a **sonar display**: blips show where sound was
  heard. A "Marco!" button on a cooldown makes every hider answer "Polo!" on it.
- The seeker has boost and a big bow wave, which is their reach. Hiders have no boost.
- A seeker **tags** a hider by touching them. What happens next depends on the **variant**,
  picked on the match card (§1a):
  - **Last Fish Swimming:** the tagged hider is **eliminated** for the rest of the round and
    **spectates** from another hider's view.
  - **Join the Seekers:** the tagged hider **becomes a seeker** for the rest of the round and helps
    find the others.
- A round ends when every hider is caught or the round clock runs down. Everyone takes a turn as
  the starting seeker, and the most points at the end wins.
- Fish bump into each other, with a sound of their own.
- There are two arenas to start: **Sunken Temple** (ancient Greek architecture) and **Aquarium**
  (a home fish tank, with noisy bubbles, a castle and the usual furnishings). Both are murky.

The mode is made for several humans **online**, so it builds on co-op's networking
(`going_coop.md`). It has **no split-screen**: one shared screen would give hiders away. Bots fill
the empty seats, are what a solo player plays against, and are what the probes and sims drive.

**Terminology.**
- A catch is a **tag** (`tagged`, `tag()`), not a battery. Batteries stay Nature's and Hunt's.
- A hider out of the round is **eliminated**, and from then on they **spectate**.
- The roles are `SEEKER` and `HIDER`.
- A hider's noise is **noise**, and how far up the layers the seeker sees them is **exposure**. The
  layers are **skeleton, cardiovascular, muscular, skin, aura**.
- The decoy is the **Fake Fish** (`FakeFish`).
- A porthole's timer is **Out of Water** (`out_of_water`).

## Decisions (user, 2026-11-01)
- **Scoring:** **hiders** score while they're in the seeker's direct line of sight, **even when the
  seeker can't see them** (exposure 0). The rate grows with the layer the seeker sees. The seeker
  doesn't score for seeing (§6).
- **The sight cone is a setting** to tune in play. A debug setting draws it (§6).
- **Nothing on screen may give hiders away:** the seeker's scoreboard doesn't update live (§6).
- **Two variants** (§1a): **Last Fish Swimming** (caught = eliminated, then spectate) and
  **Join the Seekers** (caught = becomes a seeker). Fish out of water counts as caught in both.
  Hiders never swap roles with the seeker.
- **Portholes are small and hard to get into.** Inside, the fish is turned to face out
  automatically, and **jump** exits. The bow **can't** reach in (§11).
- **The Fake Fish** is fire-and-forget along the hider's facing.
- **The arena** is picked on the match card.
- **Seeker points:** per tag, plus a bonus for clearing the round early.
- **Rounds per match:** deferred. One per human for now.
- **No split-screen** for Marco Polo, for now: it's online plus bots only (§8).
- **Several seekers (Join the Seekers):** a hider scores **once per seeker** who has them in sight.
- **Variant names:** "Last Fish Swimming" and "Join the Seekers" for now. The user will revisit them.
- **"Marco!"** is a seeker button with a cooldown.
- **No boost for hiders.**
- **Seeker reach comes from a big bow wave** (`seeker_bow_scale`). The body hitbox stays normal.
- **Hiders see the seeker fully**, normal model and on their map.
- **Murky water** in every Marco Polo arena, the Aquarium included.
- **One seeker per round**, to start. `seekers` is a setting with a default of 1.
- **Fish bump into each other**, with their own distinct sound.
- **The visibility layers** are skeleton, cardiovascular, muscular, skin and aura, in that order (§3).

## Where things stand today
- **Modes** (`scripts/main.gd`). `MODES`, `MATCH_MODES`, `NATURE_MODES`, `MODE_ENVIRONMENTS`
  (+ `ENVIRONMENTS`), `MODE_TILES` and `_match_card_text` list the modes. `_start_hunt` /
  `_end_match` show how a match node is set up and torn down. Nature's tuning comes on through
  `_use_nature_tuning`.
- **Hunt** (`scripts/hunt_match.gd`). This is the closest model: a match node with phases
  (countdown, live, over), kickoffs, a clock, an arena radius with a soft boundary
  (`_keep_in_arena`), and a contact check each tick (`_check_battered_fish`).
- **Contact** (`scripts/battery.gd`). `Battery.touching(attacker, victim)` tests the hitbox (grown by
  `REACH`) plus the bow wave's convex shape. A tag is `touching` with no speed rule, and the seeker's
  bow is grown through `bow_scale` (`fish_controller.gd:581`, read by `bow_size()`).
- **Noise sources already signalled** (`FishController`):
  - `strode(timing, flow)` gives each stride's timing quality;
  - `dodged(direction)` is a flip;
  - `jumped` / `double_jumped`;
  - `stroke_beat(quality, missed)`;
  - `speed`, `bow_amount` can be read every tick.
- **Buoyancy** (`fish_controller.gd:218`, `buoyancy`, m/s² upward; `Gait.coast_buoyancy` adds lift
  between strides). Nature's preset sets `buoyancy = 0.0` (neutral). A per-role value is just a
  property write.
- **Fish models** (`fish_model.gd`). Bodies are **lofted** along the spine from a `profile(along)`
  callable that gives each slice's half width and height (`_loft_mesh`). A spine bend carries the
  parts riding the body (`_bend_span`). That means the inner layers can be **generated** from the
  same profile and will bend with the fish. The non-lofted classes (jelly, sea hare, ray, boxfish)
  need their own (§3).
- **Scenery** (`scripts/scenery/`).
  - `GreekKit` has fluted columns, capitals, blocks, round steps, pots, draped statues and a
    brazier, cached `MeshKit`s with LODs, and marble and bronze shaders.
  - `RuinCluster`, `Shrine` and `ReefKit` are built on it.
  - `AquariumArena` is the RL-style pitch, so it is **not** the Aquarium arena here, though its glass
    shader can be reused.
- **Players.**
  - `LocalCoop` handles split-screen (up to 4, `PlayerSlot`s, one camera and HUD each).
  - `CoopSession` handles online play (ENet, host-run world, `NetFish` puppets, a roster).
  - Both are wired only to `NatureRun` and `UnnaturalRun` today. Marco Polo uses `CoopSession` only,
    and turns `LocalCoop` joining off. Co-op runs without fish-to-fish
    collision.
- **Minimap** (`scripts/unnatural/minimap.gd`). Unnatural only: a round map with a compass bezel,
  `to_map` / `from_map`, shared static painters, and a `Marks` layer.
- **X-ray outline** (`xray_outline.gd`): a next-pass material that outlines a mesh where it's hidden.
  It's **off** for hiders in a seeker's view, except as the aura layer's see-through glow (§3).
- **Bots.** `FishBot`, `WanderBot` and `HunterBot` (stride timing in `_time_stride`, plus the
  stick-flick steering lessons).
- **Audio.** `Sfx` plus the per-fish hooks (`sfx_hooks/fish_sounds.gd`). Sounds are positional.

## Design

### 1. MarcoPoloMatch (new `scripts/marco_polo/marco_polo_match.gd`)
A match node like `HuntMatch`, set up in one of the Marco Polo arenas (§12).
- **A match** is one round per player, so everyone is seeker once. With bots filling seats, only the
  humans are guaranteed a seeker turn; that's `rounds = humans` by default and a setting.
- **A round** goes `COUNTDOWN → LIVE → ROUND_OVER`, and after the last round `OVER`.
  - **COUNTDOWN:** the seeker is held at their start with their view blacked out ("counting to ten")
    while the hiders scatter. The hide time is a setting (default 10 s).
  - **LIVE:** it ends when every hider is eliminated or the round clock (`round_time`, default
    3 min) runs out.
  - **ROUND_OVER:** a short card with the round's points, then the next seeker.
- **Roster:** `players: Array[FishController]`, `role: Dictionary` (fish → `SEEKER` / `HIDER`),
  `eliminated: Dictionary`. It never assumes 2 players. Bots join it the same way people do.
- **Role values come with the role:** boost, bow scale, buoyancy (§10), the Fake Fish charge (§9) and
  the map. They're applied by one `apply_role(fish, role)` at each round's start.
- **The host judges everything:** roles, noise, sight, tags, portholes, decoys and the score. Online
  guests show what the host sends (§8).

### 1a. Variants (`MarcoPoloSettings.variant`, picked on the match card)
Both share everything else (noise, layers, sonar, portholes, Fake Fish, arenas). Only what a catch
does is different, so the match calls one `_on_caught(hider, how)` for both a tag and fish out of
water, and the variant decides.

| | **Last Fish Swimming** (`ELIMINATION`) | **Join the Seekers** (`CONVERSION`) |
|---|---|---|
| A caught hider | is eliminated: floats up belly-up and spectates (§5a) | becomes a seeker straight away |
| Seekers in a round | always 1 | 1 at the start, then growing |
| The round ends | when no hiders are left, or on the clock | the same; the last hider caught is "Last Fish" |
| Fish out of water | eliminated | joins the seekers |
| What the caught player does | watches and roots for someone | hunts, and scores per tag |

**Join the Seekers in detail:**
- **Becoming a seeker** goes through `apply_role(fish, SEEKER)`: boost, the big bow, neutral
  buoyancy, the sonar map and their own Marco cooldown. Their Fake Fish charge goes. It starts
  with a short `convert_hold` (1.5 s) while their view switches to the scope and the hiders around
  them dissolve. That also stops an instant tag of a hider swimming next to them.
- **Seekers can't tag seekers.** They see each other normally, and on the scope as arrows.
- **Pings go to every seeker's scope.** Each seeker's blur is worked out from their own distance.
- **Exposure and the layers are per seeker view** (§3): the same hider can be skin to a seeker up
  close and nothing to one far away.
- **Scoring with several seekers** (decided): a hider scores **once per seeker** who has them in
  sight, each at the layer that seeker sees. Two seekers looking at you pay double, which is fair:
  it's twice the danger.
- **Tags:** every seeker earns `tag_points` for their own tags. Converted seekers keep the points
  they earned as a hider.
- **Last Fish:** the last hider standing (if they survive the clock) gets `survive_bonus × 2`.

### 2. Noise (new `scripts/marco_polo/noise_meter.gd`, one per hider)
`noise` runs from 0 to 1 and decays toward 0. Loudness comes in two kinds:
- **Steady**, every tick: a rate from speed above `quiet_speed`, scaled up to `loud_speed`. It counts
  **horizontal and upward speed only**. Sinking (§10) and settling on the floor are silent. It is
  applied as `noise = max(noise, steady)`, so cruising holds a level instead of piling up.
- **Bursts**, on signals (each added once):
  - `dodged` (flip): `flip_noise`;
  - `jumped` / `double_jumped`: `jump_noise`;
  - `strode(timing, flow)`: `stride_noise × (1 − timing)^stride_timing_curve`. A perfect stride is
    nearly silent and a mistimed one is loud;
  - `stroke_beat(_, missed = true)`: `missed_beat_noise`;
  - bumping another fish (§5) or hitting scenery hard: `bump_noise`.
- **Masking** (the Aquarium's bubbles, §12): inside a bubble curtain, a hider's noise is scaled by
  `bubble_mask` (default 0.4). The bubbles show up on the scope as clutter of their own.

Each burst over `blip_threshold` also sends a **sonar ping** to the seeker (§4). Steady noise pings
every `steady_ping_interval` seconds while it stays over the threshold.

**Exposure** is what the seeker sees, worked out **per seeker view**:
- `exposure = curve(noise) × distance_falloff`, with exposure 0 whenever the hider is slower than
  `still_speed` (horizontal). That's the "stationary = invisible" rule.
- **Rising** is instant. **Falling** happens at `exposure_fade` per second (default 0.2), so the layers
  visibly peel away rather than vanishing in a frame.
- **Distance falloff:** 1 within `near_sight` (8 m), 0.5 at 25 m, 0 at the murk's sight distance
  (`los_range`, from the arena's fog). The aura doesn't fall off past 0.5 (§3).

Every number is a setting with a wide range ([[flexible-tuning]]): a `MarcoPoloSettings` resource
with panel groups for Noise, Exposure, Layers, Sonar, Seeker, Hider, Scoring, Fake Fish, Portholes
and Match, and a preset in `presets/`.

### 3. The layers: how a hider builds up
In a seeker's view, a hider doesn't fade in. They build up from the inside out, one layer over the
last. The **recommended thresholds** below are matched to what a hider does, so each layer means
something:

| Exposure | Layer | What the seeker sees | What gets a hider there (near, no masking) |
|---|---|---|---|
| 0 to 0.08 | none | Nothing. The dead zone, so drift and tiny corrections never show. | Holding still, sinking, a perfect slow stride. |
| 0.08 to 0.25 | **skeleton** | Pale bones, faint. The spine first, then the ribs grow out to their tips, then the skull and fin rays. | Cruising with well-timed strides. |
| 0.25 to 0.45 | **cardiovascular** | A red **heart** beating at the fish's stride tempo, with arteries tracing along the spine, out to the gills and into the fins. It's the first layer that **moves**, so it's what catches the eye in murk. | Steady swimming with average timing, or a sharp turn. |
| 0.45 to 0.65 | **muscular** | The body swells out over the bones as muscle: W-shaped muscle blocks (myomeres), raw red, with the heart and vessels showing through. Fins fill in as thin membranes. | Swimming fast, or sloppy strides, a missed beat, a jump. |
| 0.65 to 0.85 | **skin** | The real skin, scales and colours wash in over the muscle. The fish looks normal. | A bump, a double jump, a run of bad strides. |
| 0.85 to 1 | **aura** | A pulsing glow round the whole fish that shows **through murk and furniture** (the x-ray outline, in the seeker's colour). It's the punishment for a big blunder. | A flip, or a flip straight after loud swimming. |

Why these numbers:
- **The dead zone (0.08)** stops the seeker reading a hider who is "basically still".
- **Skeleton is cheap to reach on purpose.** Swimming well should still leave a trace. A ghostly
  skeleton in murk is hard to spot, but it's there.
- **Cardiovascular is the pivot.** Its pulse is what draws the eye, so where it starts (0.25)
  decides how hard the seeker's job is. It's the first threshold to tune in play tests.
- **Muscle and skin are where a hider is clearly visible.** By 0.65 they're a normal fish, so
  noisy play is clearly punished.
- **The aura is reserved for flips** (`flip_noise` 0.9 by default), so a flip is a real cost: for
  about a second the seeker sees you through a wall. Flips are still the best way to dodge a tag,
  so it's a trade.
- **How long layers last:** with `exposure_fade` 0.2/s, a flip's aura drops to skin in about 0.3 s,
  to muscle in about 1.3 s, to the skeleton in about 3.5 s, and to nothing in about 4.5 s. A hider
  who just made a mistake stays traceable for a few seconds, then vanishes again.
- **Every band edge is a setting** (`layer_skeleton = 0.08`, `layer_cardio = 0.25`,
  `layer_muscle = 0.45`, `layer_skin = 0.65`, `layer_aura = 0.85`).

As exposure falls the layers peel back in reverse: the aura dims, the skin goes, the muscle shrinks
onto the bones, the heart fades to a flicker, and the bones fade last.

**How it's built:**
- **Inner layers** (new `scripts/marco_polo/fish_anatomy.gd`):
  - **Lofted fish** (most classes) get theirs generated from their own `profile`:
    - **skeleton:** a tapered spine tube along the loft, ribs at every *n*-th slice sized to the
      slice's half width and height, a skull shell from the nose slices, and fin rays fanned along
      each fin's edge;
    - **cardiovascular:** a heart (a small two-lobed mesh just behind the gills) and vessel tubes
      along the spine, branching to the gills and each fin. A shader pulses them, driven by the
      stride tempo from `Gait`;
    - **muscular:** the body mesh itself (below).

    Each is built once per class/species and cached, like `GreekKit.cached`. They ride the spine
    bend through the same `_bend_span` path the model's plain parts use, so the bones swim with the
    fish.
  - **The non-lofted classes** get hand-made ones:
    - **jellies** have no bones: a glowing nerve ring for the skeleton and the radial canals for
      the vessels;
    - **ray:** a cartilage fan;
    - **boxfish:** its armour plates as a lattice;
    - **sea hare:** a soft inner shell.
- **Muscle and skin are the fish's real body mesh, drawn in a reveal material**
  (`shaders/marco_reveal.gdshader`):
  - **the vertex stage** pulls each vertex toward the spine's centreline by `(1 − grow)`, so the body
    swells out over the bones as `grow` rises through the muscular band;
  - **the fragment stage** draws myomere stripes in raw red, then blends to the skin's own textures
    by `skin`;
  - fins use `skin` as membrane coverage, dithered so the edge creeps out from the rays;
  - thin parts that would fold under the swell (fins, whiskers, the swordfish's bill) use dithered
    coverage instead.

  Dithering keeps everything in the opaque pass, which avoids transparent sorting problems.
- **Aura:** the `XrayOutline` next-pass on the reveal copy, in the seeker's team colour, at a strength
  set by how far into the aura band the hider is, plus a soft rim glow when it's in plain view.

**Seeing per machine (no split-screen):** Marco Polo has one player per machine (decided), so
every machine draws exactly one view, and which look a hider gets depends only on the **local
player's role**.
- **The local player is a hider or a spectator:** every fish shows its real model.
- **The local player is a seeker:** each hider's real model (and its FX: stride tails, bubbles, bow
  wave mesh, stride stream) is hidden. Its **reveal copy** (anatomy + reveal-material body, sharing
  the real `Mesh` resources) is shown instead. The copy's exposure is an instance uniform set from
  the local seeker's own exposure value for that hider.
- **Several seekers (Join the Seekers):** each seeker's machine works out exposure from its own
  seeker. There's still one reveal copy per hider per machine, so there are no render layers to
  juggle.
- **Turned off for hiders in a seeker's view:** the normal x-ray outline, name tags, the player
  arrows and the target wheel.
- **Sound gives the game away on purpose.** Hiders' positional SFX stay audible to the seeker. A
  setting can make well-timed strides silent.
- A small `HiderLooks` helper swaps real ↔ reveal for every hider whenever the local role changes:
  a new round, a conversion, an elimination, or a spectator target change.

### 4. The sonar display (new `scripts/marco_polo/sonar_map.gd`)
The seeker's map. The parts that don't depend on Unnatural come out of `Minimap` into a base class
(`RoundMap`: `to_map`, `from_map`, the bezel, `draw_arrow`), shared by both maps. The arena's walls
and big furniture are drawn on it as faint outlines.
- **Seeker:** a dark green scope with a sweep line. Blips appear where pings came from, sized and
  brightened by loudness, then fade over `blip_life` seconds.
  - Pings are **blurred**: a blip lands within `blip_fuzz × distance` of the real spot, so far
    noises are rough and near ones are exact.
  - A Fake Fish's pings look exactly like a hider's.
  - The Aquarium's airstones show as a steady fizz of small blips.
  - Eliminated hiders aren't on it.
- **Hider:** a plain map with themself, the other live hiders, the seeker and the portholes (taken
  or free). Their own noise is a ring that grows round their arrow, so they learn what's loud.
- **Spectator:** the hider map of whoever they're watching.
- **HUD:**
  - **Hiders** get:
    - a **layer pip**: five little icons (bone, heart, muscle, scales, glow) lit up to how far the
      seeker sees them, plus the noise meter;
    - a small **eye pip** while they're in the seeker's sight and scoring (see §6, "Not giving
      hiders away");
    - the Fake Fish charge;
    - the Out of Water gauge while in a porthole.
  - **Seekers** get the "Marco!" cooldown ring and the hiders-left count.
  - **Everyone** gets the round clock, the role banner and the catch feed. The feed shows "tagged"
    and "fish out of water", never "seen".

### 5. Tags, elimination and bumping
- **Tag check:** the host runs it each tick, seeker against every live hider:
  `Battery.touching(seeker, hider)` with no speed minimum. The seeker's reach is the big bow wave
  (`seeker_bow_scale`, default 2.0, about a "high-level bow"). The bow only comes out at speed
  (`bow_start_speed`), so a seeker has to be moving to tag. Tags only run in LIVE.
- **Tagged:** a hit-stop and a "TAGGED!" banner (`mp_tag`), then `_on_caught` and the variant (§1a):
  - **Last Fish Swimming:** the hider is **eliminated**. The fish floats up **belly-up**, drifting
    toward the surface and fading out (`eliminated_float`, about 2 s). Dead fish float; it's a nice
    beat after a round of sinking. Their slot becomes a **spectator** (§5a).
  - **Join the Seekers:** the hider becomes a seeker (`convert_hold`, then the hunt).
  - Either way, their points so far stay theirs.
- **When the round ends:** with no hiders left, ROUND_OVER starts straight away.
- **Bumping** (decided): Marco Polo turns on fish-to-fish collision. The fish's collision mask gets
  the player layer while the match is on.
  - A hider bumping a hider is a `bump_noise` burst plus a sonar ping.
  - A seeker touching a hider is a tag (the bow reaches first).
  - The `mp_bump` SFX is a soft, fleshy thud with a scale scrape, scaled by the closing speed. It's
    distinct from scenery knocks and from a battery's crunch.

### 5a. Spectating (Last Fish Swimming only)
- An eliminated player watches **a live hider's view**: that hider's camera angle on their own
  follow cam, seeing the world as a hider does (everyone normal, the seeker fully). They get the
  hider's map.
- **The bumpers** (or D-pad left/right) cycle through the live hiders. The pick starts on the hider
  nearest to where they were tagged.
- **When the watched hider is eliminated,** the view moves to the next one after a beat.
- The camera retargets (`FollowCamera.fish`) to that hider's fish, or online to its `NetFish`.
- Spectators can't act: no input reaches the fish, which is gone anyway. They don't see round
  points either, since they could pass them on.
- **If no hiders are left**, there's nothing to watch: the round is over.

### 6. Scoring (decided: hiders score while in the seeker's line of sight, visible or not)
- **In sight:** a live hider scores per second while they're in a seeker's **direct line of sight**,
  **whether or not the seeker can see them**. That means all four of:
  - **in the cone:** inside the seeker's **sight cone** (below);
  - **in reach:** closer than `los_range` (the murk's sight distance);
  - **not blocked:** a ray from the seeker's eye to the hider's body (and its nose and tail, any one
    counts) hits no wall or furniture;
  - **not hidden:** not in a porthole.
- **The rate grows with the layer the seeker sees** (decided), so boldness pays, and sitting
  invisible right in front of the seeker still pays a little:

  | Layer | Points/s |
  |---|---|
  | none (invisible, in sight) | 1 |
  | skeleton | 2 |
  | cardiovascular | 3 |
  | muscular | 4 |
  | skin | 5 |
  | aura | 5 |

  "None" pays the base rate: holding your nerve, still and invisible, in plain view of the seeker.
  The aura earns no more than skin, so flipping in front of the seeker isn't a points trick. Every
  rate is a setting (`seen_points_none` … `seen_points_aura`).
- **The sight cone** (`MarcoPoloSettings`, Scoring group):
  - `los_cone_angle`: the cone's full angle, default 70°, range 10° to 180°. It's measured round the
    **seeker camera's forward**, since that's where the seeker is looking.
  - `los_cone_vertical`: an optional separate vertical angle (default the same; 0 = use the full
    angle).
  - `los_range`: the cone's length. It defaults to the arena's murk sight distance and can be
    overridden.
  - `los_falloff`: off by default. When on, the rate tapers toward the cone's edge and its far end
    (dead-centre close up pays the most).
- **Debug: show the sight cone** (`debug_show_los_cone`, off by default; in the settings panel and the
  console as `mp_cone`):
  - draws the cone as a faint wireframe from the seeker's eye, on every machine;
  - draws each hider's sight ray: green when it counts, red when blocked, grey when outside the
    cone or range;
  - puts a small floating "+n/s" over each scoring hider.

  That makes tuning the angle quick in a solo game against bots (spectate a bot seeker) or online.
- **Surviving:** a hider still in at the round's end gets `survive_bonus` (default 15).
- **Seekers** score `tag_points` per tag (default 20). The starting seeker also gets a `clear_bonus`
  for catching everyone before the clock: `clear_bonus_max × time_left / round_time`, default up to
  30.
- **Fish out of water** gives no seeker points. It's the hider's own mistake.
- **Winner:** the most points after every round.
- **Who counts:** Fake Fish never score, and only the host's rays count.

**Not giving hiders away.** Points come from being in the seeker's sight, so live scores would be a
radar: a seeker who sees a rival's score tick knows someone is in front of them. So:
- **No live scoreboard during a round**, for anyone. Points go into a hidden round tally and are
  shown on the ROUND_OVER card. The between-rounds totals are what the HUD shows during the next
  round.
- **The seeker's HUD** shows no hider scores at all, no "someone's in sight" cue, and no score sounds.
  It does show the seeker's own tag points; those come from tags they already know about.
- **The hider's eye pip** is the only live cue, and it's small, on the hider's own HUD (only on
  their own screen, since there's no split-screen).
- **Audio:** `mp_seen` (a soft tick while scoring) plays only on the hider's own machine.
- **Online:** the host sends each guest only their own hider's tally. Other players' round points
  aren't sent until ROUND_OVER, so a modified client learns nothing either.
- **The debug cone** gives everything away, so it's tagged DEBUG in the panel and off in normal
  play.

`MatchStats` gets `TAG`, `SEEN` (points earned while seen, per layer), `CLOSE_CALL` (seen at
  muscular or above within 5 m and not tagged), `SURVIVED`, `FOOLED` and `OUT_OF_WATER`, for the
  end card.

### 7. The seeker's view
- **Murk** (decided): each arena sets its own fog, which also sets `los_range`. The Temple is murky
  green-blue; the Aquarium is a dirty algae-green tank lit from the hood.
- **Camera:** the follow cam, with no ball cam.
- **"Marco!"** (decided): a seeker button on a cooldown (`marco_cooldown`, default 20 s).
  - **Hiders:** every live hider pings ("Polo!") on the scope with a big blur and gets a small
    exposure bump (`polo_exposure`, default 0.3, so a heart flicker).
  - **Portholes:** hiders in them don't answer.
  - **Fake Fish:** they do answer, which helps the trick.
  - **The cost:** calling gives away the seeker's own position. The hiders see a ring round the
    seeker for a moment.

### 8. Players: online and bots (no split-screen)
- **No split-screen** (decided). Sharing a screen gives away too much: everyone sees every view, and
  the room shares the speakers.
  - `LocalCoop.can_join()` returns false while a Marco Polo match is on.
  - Starting Marco Polo with extra local players drops them (`LocalCoop.drop_extras`), with a note on
    the match card.
  - The one local player's HUD, map and camera follow their role (hider, seeker, spectator).
- **Playing alone** means you against bots.
- **Playing with other people** is online only.
- **Joining online mid-round** makes you a spectator until the next round.
- **CoopSession:** a `_hook_marco_polo` sends these:
  - **reliable:** roles, rounds, tags, eliminations and conversions, porthole in/out, Fake Fish
    spawns, and scores (each guest's own tally only, during a round; §6);
  - **unreliable (about 10 Hz):** pings and each hider's exposure.

  Guests run no noise of their own: their reveal copies read the host's values. Online is the only
  way to play with other people, so it moves up to phase 4, right after the sonar.
- **Bots** (new `MarcoPoloBot`, on top of `FishBot` with HunterBot's steering):
  - **Hider bot:** a hiding spot (behind furniture, low, in a bubble curtain, or a free porthole);
    well-timed strides when the seeker is away; settles on the floor when the seeker comes close.
    It **dares**: it edges into the seeker's view at a low layer to score, and backs off when the seeker
    turns toward it. It throws its Fake Fish when the seeker closes in, and leaves a porthole before
    the gauge runs out. Its stride timing and boldness are difficulty settings.
  - **Seeker bot:** sees **only what the scope and its own view show**, never real positions. It
    chases the newest loud blip, sweeps the area, uses Marco when it's been quiet, and waits
    outside a porthole now and then.
  - **Join the Seekers:** converted bots become seeker bots. Seeker bots split up, spreading
    toward different blips rather than all chasing the same one.
  - **Porthole entry** is a careful line-up for bots too (slow, nose first, within the angle). They
    can miss it and knock, like people.
  - Bots fill the match up to `min_players` (default 4) so one person can play. Bot rounds as seeker
    are optional (`bot_seeker_rounds`).

### 9. The Fake Fish (once per round, hiders only)
A decoy that looks and sounds like the hider who threw it, to pull the seeker the wrong way.
- **Use:** the skill button (`CourseSkill`'s binding). One charge per round.
- **What it does (decided: fire-and-forget):** a `FakeFish` spawns at the hider, a copy of their
  fish (same class and species). It swims off along the hider's facing and is then on its own;
  the hider doesn't steer it. It turns away from walls and furniture by itself. It strides
  **badly on purpose**: loud mistimed strides and a flip or two, at `fake_speed`. It makes real pings
  and builds up through the layers in the seeker's view like a real hider. It lasts `fake_life`
  (default 6 s).
- **When it ends:** at the end of its life it bursts into a puff of bubbles (a loud last ping). If
  the seeker tags it, it pops just the same, with a "FOOLED!" sting and a small `fooled_hold` stun
  (0.5 s) for the seeker.
- **The hider:** throwing it makes **no** noise, so they can slip off under the decoy's racket.
- **What it never does:** it can't enter a porthole, scores nothing, and isn't on the hiders' map
  as a hider (a "decoy" icon).
- **Bots** treat it like a hider (the seeker bot can be fooled; that's the point).

### 10. Hiders sink (slightly negative buoyancy)
- Hiders get `hider_buoyancy` (default -0.8 m/s², range -5 to 0) in place of Nature's 0. The seeker
  keeps `seeker_buoyancy` (default 0, neutral).
- **The result:** a hider can't hang at the top of the arena for free. Staying up costs strides,
  and strides make noise. Sinking is silent (§2), so the cheap places to hide are low: the floor,
  under furniture, in the gravel.
- **The floor:** hiders that settle there are still (exposure 0). They can push off silently with
  a slow, well-timed stride.
- **The coast:** `Gait.coast_buoyancy` stays as it is. Hider buoyancy is added on top.

### 11. Portholes (temporary hiding, with Out of Water)
Small round openings set in the arena walls, dressed per arena (§12). A hider who gets into one
vanishes, but getting in is hard.
- **Getting in (decided: small and hard):**
  - The opening is only a little wider than a hider's hitbox (`porthole_radius`, default the
    hitbox's half width × 1.25, scaled per class so big fish have a harder time).
  - A hider must arrive **nose first, lined up** (within `porthole_entry_angle`, default 20°, of the
    porthole's axis), **slowly** (under `porthole_entry_speed`, default 4 m/s), and not mid-flip.
  - Anything else bumps off the rim with a knock (`bump_noise`, an `mp_bump` thud). A missed
    entry by a seeker is a giveaway.
  - Lining up costs time and small, careful strides, and that's the point.
  - There's no assist beyond the entry check (no magnet). Online, it's checked on the host.
  - One fish per porthole. Seekers can't enter.
- **Inside:**
  - the fish slides in and is **turned round automatically to face out** (`porthole_turn_time`,
    0.4 s), its head just inside the opening;
  - the camera sits behind it, looking out through the porthole, so the hider can watch the arena;
  - the hider is gone from every seeker's view and scope, and silent;
  - they don't answer Marco and don't score (not in line of sight);
  - **the bow can't reach in** (decided). Inside, a hider is safe from tags until the gauge runs out.
    A seeker can only wait outside.
- **Getting out:** press **jump** (decided). The fish shoots straight out along the porthole's axis
  (`porthole_exit_speed`) with a loud `porthole_exit_noise` burst. Nothing else gets you out:
  steering and strides do nothing inside.
- **Out of Water:** a gauge fills while the hider is inside (`porthole_time`, default 8 s), shown as a
  drying, gasping fish. The fish's gills flap faster and its skin dulls as it fills.
  - **After leaving,** the gauge drains at `porthole_recovery` (1/3 the fill rate), so hopping
    straight into another porthole gets little time.
  - **Full gauge:** **fish out of water**. The hider flops out gasping, with a "FISH OUT OF WATER!"
    banner, and counts as caught: eliminated in Last Fish Swimming, a seeker in Join the Seekers.
- **Camping:** since the bow can't reach in, a seeker can wait outside a porthole. The hider
  watches them through the opening and picks the moment, and the gauge makes waiting cost the
  hider. The seeker can only guess which porthole is taken (the scope shows nothing from inside),
  and waiting costs them time on everyone else.
- **Per arena:** 6 to 10 portholes, spread so none is far from another and none sits by the seeker's
  start.

### 12. The arenas (furnished, walled, murky)
Both are new `Environment`s (alongside `Ocean`, `AquariumArena` and the Obstacle Course in
`main.gd`'s `ENVIRONMENTS`). Marco Polo picks one on its match card (decided). Each one:
- is enclosed by walls, a floor and a ceiling or surface (real walls, not a radius push);
- is furnished with real collision, since furniture blocks sight and gives places to hide;
- sets its own murk and lighting;
- marks hider spawns, the seeker's start and portholes (`Marker3D`s in groups);
- gives the sonar map its outlines (`map_outlines() -> Array[PackedVector2Array]`).

**Sunken Temple** (new `scripts/marco_polo/temple_arena.gd`), built from `GreekKit`, `RuinCluster`
and `Shrine`:
- **The space:** a walled sanctuary about 90 × 70 m and 30 m deep, on a marble floor with cracked
  slabs and sand drifts.
- **The walls:** ashlar block walls with **portholes as arched windows / wall niches**, some with
  a draped statue's plinth beside them.
- **The furniture:** a temple front (a colonnade with a pediment, some columns fallen), a round
  tholos in the middle, an altar with a bronze brazier, toppled statues, amphorae and pots in rows,
  and broken steps. It's all low enough to settle behind.
- **The look:** murky green-blue, shafts of light through the roofline, kelp in the corners. No
  sound masking.

**Aquarium** (new `scripts/marco_polo/fish_tank_arena.gd`). A home fish tank seen at fish scale.
It's not the RL pitch, though it borrows `glass.gdshader`.
- **The space:** about 80 m long, 40 m deep and 45 m tall. Glass sides look out onto a blurred living
  room, and a hood light sits on top.
- **The furniture:**
  - **a castle** (towers, a gate, crenellations) whose windows and doors are swim-throughs;
  - a sunken pirate ship;
  - a treasure chest that opens and closes on a timer, burping bubbles;
  - a diver in a helmet;
  - plastic plants, a ceramic skull, a bridge, coloured gravel with a few big rocks;
  - the filter's intake tube.
- **Noisy bubbles:** airstone curtains along the back, a bubble wand along the floor, the chest's
  burps and the diver's helmet trickle.
  - Every one is loud (positional fizz plus scope clutter) and **masks** hiders inside it
    (`bubble_mask`).
  - Some curtains pulse on a timer, so a spot that's safe now isn't in 10 s.
- **The portholes:** round **holes in the back panel** (the filter box) and the castle's arrow slits.
  Inside a hole is an air gap, so "fish out of water" is literal there.
- **The look:** a murky, algae-green tank lit from the hood. The furniture, the murk and the bubble
  curtains do the hiding together.

The **Ocean** stays available as a plain test arena (no portholes; radius push like Hunt) for the
early phases and probes.

### 13. Mode wiring
- `main.gd`:
  - add `MARCO_POLO := "Marco Polo"` to `MODES`, `MATCH_MODES` and `NATURE_MODES`;
  - add the two arenas to `ENVIRONMENTS`;
  - add a `MODE_TILES` entry (icon `mode_marco_polo`, a sonar ring);
  - add `_start_marco_polo`, and handle it in `_end_match` and `_match_card_text`. The card gets an
    arena picker.
- Mode picker, settings panel groups, and `setting_docs.gd` entries for every setting.
- Console commands for testing: `mp_role`, `mp_noise`, `mp_expose <0..1>`, `mp_tag`,
  `mp_eliminate`, `mp_round`, `mp_fake`, `mp_porthole`.
- Audio (`planning_audio.md`), added to the catalogue so sound profiles can record them:
  - `mp_marco`, `mp_polo`, `mp_tag`, `mp_eliminated`, `mp_ping`, `mp_seen` (the scoring tick);
  - `mp_heartbeat` (the seeker hears a faint one for hiders at cardiovascular, optional);
  - `mp_aura`, `mp_count`, `mp_bump`, `mp_round_over`;
  - `mp_fake_throw`, `mp_fake_pop`, `mp_fooled`;
  - `mp_porthole_in`, `mp_porthole_out`, `mp_gasp`, `mp_fish_out_of_water`;
  - `mp_airstone` (loop), `mp_chest_burp`.

## Phases
### Phase 0: rounds with no hiding
`MarcoPoloMatch` in the plain Ocean, with:
- mode wiring, settings and both variants;
- rounds and seeker rotation;
- `apply_role` (seeker-only boost, big seeker bow, hider buoyancy);
- the tag check, elimination + spectating, and conversion;
- fish-to-fish bumping;
- line of sight scoring with the sight cone (at the base rate while there's no exposure yet), the
  hidden round tally, and the debug cone;
- bots as dumb wanderers.

Solo against bots (no split-screen). Everyone visible.
Probe `tests/marco_polo_probe`:
- **Last Fish Swimming:** a tag eliminates, and the spectator view moves to a live hider and on when
  that one is out.
- **Join the Seekers:** a tag converts. Seekers can't tag seekers. Once `convert_hold` ends, the new
  seeker can tag.
- **Rounds:** a round ends when all are caught or the clock runs down, and the seeker rotates.
- **Buoyancy:** hiders sink at `hider_buoyancy`.
- **Line of sight:**
  - scores while invisible;
  - a blocking wall stops it, and so does being outside the cone or range;
  - `los_cone_angle` changes what counts;
  - with several seekers, a hider scores once per seeker in sight.
- **Hidden tallies:** no score reaches any HUD or the network during a round, until ROUND_OVER.
- **Bumping:** a bump makes noise and `mp_bump`.
- **No split-screen:** `LocalCoop` joining is off during a match, and extra local players are dropped
  at the start.

### Phase 1: noise and exposure
`NoiseMeter`, distance falloff, fade, and the layer pip on the hiders' HUD.
Probe:
- still → 0, and sinking is silent;
- a flip reaches the aura, and a good cruise stays at the skeleton;
- a bad stride > a good one;
- the fade times from §3;
- bubble masking (with a test curtain);
- points per layer.

### Phase 2: the layers and seeing per view
- `FishAnatomy` (skeleton + heart and vessels from the loft profile, then the four hand-made classes);
- `marco_reveal.gdshader` (muscle swell, myomeres, skin);
- the aura (`XrayOutline` + rim glow);
- `HiderLooks` (real ↔ reveal by local role), and the x-ray/name/arrow kill list.

Tool `tests/reveal_shots`: every class at each layer's middle (0.04, 0.16, 0.35, 0.55, 0.75, 0.92)
plus a swimming strip, so the anatomy can be checked against the models (like `model_shots`).
Probe:
- as seeker, a still hider is not drawn;
- after a role change to hider or spectator, it is drawn normally.

A bench run checks fps with 12 fish, all in reveal.

### Phase 3: the sonar display
`RoundMap` split out of `Minimap` (Unnatural must look the same: `murk_shots` before/after),
`SonarMap`, pings, blur, Marco/Polo.

### Phase 4: online
Online is the only way to play with other people, so it comes before the content phases:
- the `CoopSession` hook;
- guest-side reveal copies from the host's exposure;
- spectating over the network;
- each guest's own tally only during a round.

`tests/coop_net.sh` runs with a Marco Polo match (host + 2 guests + bots). Probe: a guest's packets
carry no other player's round points.

### Phase 5: the arenas and portholes
Sunken Temple first (the kit exists), then the Aquarium (new furniture meshes, airstones, masking
zones). Portholes: the entry check (size, angle, speed), the auto turn to face out, the camera, jump to exit,
Out of Water, caught, and exit noise.
Tool `tests/arena_shots` for overviews and hiding spots. Probe:
- **Entry:** a lined-up slow approach gets in; a fast, angled or flipping one knocks off the rim.
- **Inside:** the fish ends up facing out. Only jump gets it out. The bow can't tag it.
- **Hidden:** portholes hide a hider from the scope and every seeker's view, and stop scoring.
- **The gauge:** it fills and recovers. A full gauge is caught, in both variants.

### Phase 6: Fake Fish and real bots
- `FakeFish`: spawn, bad strides, layers, pop, FOOLED;
- hider bots (with daring) and seeker bots.

Sim `tests/marco_polo_sim` (headless, bots only, both arenas):
- tags per round and how long rounds last;
- points by layer;
- how often a settled hider is found, and how often the seeker finds a hider "blind" (should be
  about never);
- how often the Fake Fish fools;
- how often hiders run out of water.

The sim runs are kept short ([[feedback-limit-analysis]]), and the results tune the defaults and the
layer thresholds.

### Phase 7: polish
End card, audio hooks, the mode tile icon, living-room backdrop details for the Aquarium, a tag
replay (optional, through `GoalRecorder`).

## Decisions still open (user)
- **D16. Layer thresholds:** 0.08 / 0.25 / 0.45 / 0.65 / 0.85 are in for now (§3), tuned after play
  tests.
- **D23. Rounds per match:** deferred. One per human for now.
- **D25. Variant names:** "Last Fish Swimming" and "Join the Seekers" for now. The user will revisit
  them later.

Settled since the last revision: **D24**, once per seeker (§1a). **D26** went away with
split-screen.

## Risks
- **The reveal copy** costs extra draw calls per hider: the anatomy meshes on top of the body. With
  one view per machine it's one copy per hider at most. Check with the phase 2 bench.
- **Solo play is only as good as the bots.** Without split-screen, playing alone means bots, so
  the hider and seeker bots (phase 6) matter more. Dumb wanderers are enough to test with until
  then.
- **Invisible scoring** could be farmed: a still hider parked dead centre in the seeker's cone, out
  in the open. It pays only the base rate, and they're one bump away from a tag. If it's too strong,
  lower `seen_points_none` or turn on `los_falloff`.
- **Leaking scores:** anything that changes during a round because of sight (scores, sounds, a
  spectator's screen) is a radar. §6's rules close it. The probe checks no tally
  leaves the host early.
- **Portholes too hard:** if hiders can't get in under pressure, widen `porthole_radius` /
  `porthole_entry_angle` or raise `porthole_entry_speed`. It's all settings.
- **Anatomy for 11+ classes:** the generated loft skeleton and vessels cover most. The hand-made four
  are the expensive part, and `reveal_shots` keeps them honest. A class can ship without its inner
  layers (it goes from nothing straight to muscle) as a stopgap.
- **The muscle swell** can fold thin parts. Those use dithered coverage instead.
- **Daring is too easy or too hard:** the points-per-layer table and the cardiovascular threshold
  are the levers. The sim measures points by layer.
- **Stillness is too strong:** a settled hider scores nothing, so stillness only survives (the
  `survive_bonus`). If they still win too often, lower the bonus.
- **Portholes are too strong:** chaining them. Recovery at 1/3 the fill rate and the exit noise are
  the levers.
- **Sound gives too much away:** positional stride sounds may beat the scope. A setting turns
  hiders' SFX down in the seeker's view.
- **Splitting `Minimap`** touches Unnatural. Keep the painters' signatures and check with
  `murk_shots`.
- **Two new arenas** are the biggest content cost. The Temple reuses `GreekKit`; the Aquarium needs
  new meshes (castle, wreck, diver, chest, plants). Build the Temple first and the Aquarium to the
  same environment interface.

## Verification
Each phase has headless probes and shots (`marco_polo_probe`, `reveal_shots`, `arena_shots`,
`marco_polo_sim`), plus the regression probes and an export to
`builds/windows/FishPlayground.exe` once a phase passes. Then a hand-off: solo against bots, and
online with a second machine once phase 4 is in.
