# Plan: Race (lap racing on a canyon circuit)

## Context
A new match mode: a lap race, **3 laps** of one track, against a mix of humans and bots.
- **Any playable model can race:** every fish class and skin, every Hunter form, the adult whales
  and the Titans. A model is picked on the join-time character screen, the same way as in the
  other modes.
- **Same speed, different handling.** Every racer has the same top speed and acceleration. What
  differs is turning, how they coast, how heavy they are in a bump, and their mobility skill. Any
  pick can win.
- **One track to start:** the **Canyon Reef Circuit**, about the size of a kart-racer track
  (a clean lap takes about 40-50 s). It's built on the procedural terrain: canyon walls, an arch,
  a tunnel bored through a mesa, a dive under an overhang, a climb over a ridge and one split.
- **Racers swim freely in 3D.** Nothing holds them to the floor, but the **terrain shows the
  way**: the course is a carved channel with tall walls, and a soft ceiling stops racers from
  cutting across the top of the map.
- **No items, weapons or boost pickups.** The track has two tools of its own:
  **bubble streams** (currents along the line that speed up a racer) and **slipstream** (speed
  gained swimming in another racer's wake). Items, boost pickups and weapons may come in a later
  phase (§12).
- Play is **Solo + bots**, **split-screen** and **online**, with bots filling the empty seats.

It builds on Nature's swimming (the `presets/nature.cfg` tuning: Extra Swishy strides, no boost),
the GameMode registry (`planning_core_roadmap.md`), the native terrain
(`planning_procedural_world.md`) and the per-class Traversal twists and mobility skills
(`CourseSkill`, Unnatural's Traversal).

**Terminology.**
- A **racer** is anyone in the race, human or bot. The **grid** is the start line-up.
- The **track** is the course as data (`RaceTrack`): its **centreline**, its width and height at
  each point, and its **racing line** (the line bots follow). The **channel** is the water the
  track carves into the rock.
- **Checkpoints** are invisible gates in order along the track. A lap counts only if every one
  was passed in order. **Progress** is laps + distance along the centreline, and it gives the
  **positions** (1st, 2nd ...).
- **Rescue:** putting a racer back on the track at their last checkpoint (out of bounds, stuck,
  or going the wrong way too long).
- **Bubble stream** (`BubbleStream`, built on `bubble_column.gd`): a current along the track.
  **Slipstream:** the wake behind a racer.
- **Size cap:** the largest body length allowed in a race. A bigger model is scaled down to it.

## Decisions (user, 2026-11-21)
- **Roster:** everything playable. Fish classes and skins, Hunter forms, adult whales, Titans.
- **Balance:** same top speed and acceleration for everyone. Classes differ in handling.
- **Items:** none for now. Bubble streams and slipstream only. Items, boost pickups and weapons
  are considered after the racing and the track are done.
- **First track:** Canyon Reef Circuit, on the procedural terrain.
- **Laps:** 3. **Track size:** like a kart-racer track.
- **The terrain guides the racer.** Free 3D swimming, but the walls make the line clear.

## Open decisions (my recommendation first)
- **D1 Mode name.** Working id `race`, title "Race". Pun options: **"Fin-ish Line"**,
  "Current Affairs", "Reef Rally". Rec: Fin-ish Line.
- **D2 Field size.** Rec: **8 racers** (humans + bots), set on the card from 2 to 12.
- **D3 Size cap.** Rec: a cap of about **2x a Skirmisher's length**. Whales and Titans are scaled
  down to it, with their hitboxes scaled to match, so they can't wall off the channel. They keep
  their weight in bumps (§3). The other choice is true scale with a much wider track. Rec: cap.
- **D4 Bumping.** Rec: racers **bump with weight** (heavy bodies push light ones aside) but
  there's no damage and no spin-out. Contact during the countdown is off.
- **D5 Mobility skill.** Rec: **on**, each class's own CourseSkill on the skill button, with a
  cooldown set for racing. It's a big part of "different handling". The other choice is off for a
  pure race.
- **D6 Start.** Rec: a 3-2-1 countdown. A stride timed on "GO" gets a small **start surge**
  (the Extra Swishy rhythm, like a rocket start). Strides before "GO" give nothing and aren't
  punished.
- **D7 Catch-up.** Rec: **none for humans.** Bots get a mild, panel-tunable rubber band
  (on by default at Easy, off at Hard).
- **D8 Finish.** Rec: when the first human finishes, the rest get a **30 s** finish clock.
  Anyone who hasn't finished is placed by progress. With bots only left, the race ends at once and
  their places are projected.
- **D9 How the track is authored.** Rec: hand-placed centreline points in a script
  (`canyon_reef_track.gd`: position, width, height, bank, feature tag), plus a tool that renders a
  top-down map and checks the channel. The other choice is a Path3D edited in the Godot editor.
  Rec: script, because probes and tools can read it and diffs stay readable.

## §1 The mode
- Folder `scripts/modes/race/`. `RaceMatch extends GameMode`, plus one line in
  `ModeRegistry.scripts()`.
- Descriptor: `play` ["Solo", "Split", "Online"], `match` true (played from a card),
  `split_screen` true, `tuning_preset` `res://presets/nature.cfg` with race overrides (§3),
  `environment` "Canyon Reef Circuit", `environments` {track name: script}, `settings`
  RaceSettings, `net` RaceNet.
- **Match card:** track (one entry for now), laps (1-9, default 3), field size, bot difficulty,
  slipstream on/off and mobility skills on/off.
- **Setup screen:** the join-time character screen with the whole roster (§2). Players are
  grouped by family (Fish / Hunters / Whales / Titans), then skin. Each player's pick is saved for
  the race on its own (per-role saves, like the other modes).
- **Flow:** card → setup → grid + countdown → race → finish clock → results (place, total time,
  best lap) → Rematch / Change Character / Leave. R restarts from the grid.
- Stays inside the mode boundary: core/kits name no mode (`mode_boundary_probe --strict` green).

## §2 Roster: every playable model
- `RaceRoster.entries()` lists every model: `{family, key, label, build: Callable, skin}` for
  each FishClass and skin, each `HunterForms.FORMS` entry, each adult whale species and each Titan.
  It reads the existing lists and keeps no copy, so a new model shows up in the race by itself.
- Each entry builds through the path its own mode uses (FishModel / the mode `models` providers),
  so a racer looks the same as it does elsewhere.
- **Size cap (D3):** body and hitbox are scaled so the length is at most `race_size_cap`.
  Small fish keep their own size.
- **Phase 0 audit:** check how Hunter forms, whales and Titans are driven (FishController +
  SwimRig, or their own movers). Every racer must go through one FishController with
  `fish.modifiers`, so §3 works the same for all of them. Any that don't get a thin adapter.

## §3 Same speed, different handling
- **Shared:** top speed, acceleration and stride gain come from RaceSettings and are applied as
  FishModifiers on top of the Nature preset, the same for every racer.
- **Per family/class handling** (a `RaceHandling` table, settings with wide ranges, see
  flexible-tuning):
  - `turn_scale`: how sharp it turns at speed (Clownfish sharp, whales wide).
  - `coast`: how much speed it keeps off throttle (Ray glides, Boxfish drops off).
  - `weight`: bump mass (Titan/whale heavy, Clownfish light).
  - `stream_grip`: how much a bubble stream speeds it up.
  - `slip_gain`: how much it gains in a slipstream.
  - Mobility skill + cooldown (D5).
- These start from the Traversal twists (Nimble, Glide, Streamlined ...), so each class plays the
  way players already know.
- **Balance check:** a bot sim laps every entry on the racing line (§9). The target is a lap-time
  spread of about 3% or less on a clean lap. Per play-test-before-tuning, the numbers are reported
  as open items and nothing is retuned before a play-test.
- These handling values go into INVENTORY.md as a Race column (keep-inventory-updated).

## §4 The track as data
- `RaceTrack` (RefCounted): a closed loop of centreline points
  `{at: Vector3, width, height, bank, tag}`, smoothed into a Curve3D. It provides:
  - `sample(d)` → position, forward, right and up at distance `d`.
  - `nearest(p, hint_d)` → distance along the track, searching a window around the last known
    value. This keeps progress monotonic and stops the loop from snapping across.
  - `checkpoints` (every ~25 m plus one at each feature), the `racing_line` (an offset from the
    centreline per point), `grid` slots, and the bubble stream spans.
- **Sizing:** lap length = race top speed × 45 s. With Nature's ~12-14 m/s that's about
  **550-650 m**. Phase 0 sets the number from the measured race speed. Channel width is about
  **20-28 m** (3-4 capped whales side by side), down to ~14 m in the tunnel and chicane and up to
  40 m on the main straight. Height is 12-25 m.
- **Footprint:** the loop winds and crosses over itself once (over the tunnel), so it fits in
  about 300 x 300 m with a depth band of about 70 m.

## §5 Carving the channel (native terrain)
- New TerrainField feature: **`channel`** records. Each is a capsule segment
  (`ax ay az bx by bz width height`) with an elliptical cross-section, joined end to end along the
  centreline.
- **Field rule:** inside the track's bounds, everything is rock *except* the channel, plus the
  layout's own features for looks. In the SDF that's `max(rock_fill, -channel)`, smoothed with
  `blend`. Floor relief, warp, erosion and strata stay on, so the walls get the same rock look as
  the other modes.
- **Open sky vs roof:** most of the channel is **open-topped** (a canyon). The rock fill goes up
  to a **rim height** above the channel's top, and the tunnel and overhang sections are roofed.
  Above the rim is the **soft ceiling** (§6).
- **Navigability:** the existing nav pass (`clearance`, `lip`) runs over the channel too. A
  probe walks the centreline and the racing line with the size cap's radius (`Terrain.line_clear`,
  `is_open`).
- **Cost:** the current stage is 349 x 61 x 349 cells (~0.65 s). The track is about 300 x 70 x
  300 at 1 m, which is similar. If the bench says otherwise, the cell gets coarser on the far side
  or TerrainStream tiles it.
- The track is fixed, not rolled: the same seed every time, and the layout comes from RaceTrack,
  not TerrainLayout's rules. A `RaceLayout` builds the configure() dictionary: channel records,
  the arch and tunnel features at their tagged points, and no random mesas inside the course.

## §6 Keeping racers on the track
- **Walls first:** walls 15-30 m tall on the open canyon sections. On the inside of each bend the
  wall rises to block corner cutting, except where a shortcut is intended.
- **Soft ceiling:** above the rim + a margin, a downward current grows with height and turns the
  racer back down. With murk above the rim the high ground also looks like the edge of the map.
- **Out of bounds:** a racer beyond the channel's reach for `race_oob_time` s is rescued (§7).
- **Cues on the line:**
  - Glow coral and lantern buoys along the racing line.
  - Arrow glyphs on the walls before each bend.
  - Darker sand in the channel with a lighter racing-line stripe.
  - Bubble streams show the fast line.
  - Particles drifting the race direction in the current.
- **Wrong way:** facing against the track for over 1.5 s shows a WRONG WAY banner and an arrow.
  After `race_wrong_way_time` s they're rescued.

## §7 Race logic
- **Countdown:** racers are held on the grid, with steering but no movement. 3-2-1-GO with the
  start surge (D6).
- **Progress:** each frame, `nearest()` from each racer's last hint gives lap + distance. A
  checkpoint is passed when the racer crosses its gate plane inside the channel. A lap counts only
  when every checkpoint was passed in order, so going backwards or skipping doesn't count.
- **Positions** are sorted by progress, updated every frame and shown on the HUD.
- **Laps:** lap times, best lap, a "FINAL LAP" banner, the finish line, then the finish clock
  (D8).
- **Rescue:** the racer fades out, then back in at the last checkpoint's centre facing along the
  track, with ~1.5 s of no collision and the speed they had at the checkpoint. Triggered by out of
  bounds, wrong way, stuck (low speed for 4 s) or a button press (cooldown).
- **Results:** places, total times and best laps. Personal best per track is saved (UISettings).

## §8 Bubble streams and slipstream
- **Bubble stream:** a span of the track (from d0 to d1, an offset and a radius) with a current
  along it. The push is `stream_push × stream_grip`, strongest at the stream's core. It's built on
  `bubble_column.gd` (its bubbles laid along the span) and uses a Nature current as the force.
  The first track has 3-4: the main straight's inside, the ridge climb, the tunnel exit and the
  high route of the split.
- **Slipstream:** a cone behind each racer (length scales with body size, so a whale's wake is
  long). A racer inside it for 0.5 s gets `slip_gain` extra top speed, fading out once they leave.
  It shows as streaks (Marco's wake streaks). This lets the pack catch up without rubber-banding.

## §9 Bots
- `RaceBot`: drives a FishController through `controls`, like FishBot and WanderBot.
  - Steers at a lookahead point on the racing line, further ahead the faster it goes.
  - Brakes for a bend (by curvature × its class's turn_scale).
  - Takes bubble streams and uses slipstream when there's one ahead.
  - Overtakes by moving its line sideways inside the channel's width when a racer is ahead.
    Avoids the walls with `Terrain.sdf`.
  - Uses its mobility skill on straights or to recover.
- **Difficulty** (BotDifficulty): steering noise, how closely it holds the line, braking margin,
  skill use and the rubber band (D7).
- **Sim:** `race_sim` runs races headless with only bots: lap times per entry, positions, rescues
  per lap, time in streams and slipstream. `race_roster_bench` laps each entry alone on the
  racing line. Both are short passes (feedback-limit-analysis).

## §10 Camera, HUD and audio
- **Camera:** a race chase cam (CameraClaim). The follow cam with a lookahead along the track's
  forward, so a bend shows before you reach it. The distance scales with body size. A short
  wide view of the grid at the start.
- **HUD (ModeHud):**
  - Position ("3rd / 8"), lap ("Lap 2/3"), current and best lap times.
  - A track minimap (the centreline from above, with racer dots and the leader marked).
  - Countdown, FINAL LAP, WRONG WAY and FINISHED banners, and the results panel.
  - Split-screen: one HUD per view.
- **Audio** (planning_audio.md profiles): countdown beeps + GO, a lap chime, final lap, finish,
  a stream whoosh, slipstream wind and a rescue. Add these to the SFX list.

## §11 Split-screen and online
- **Split:** `attach_player` gives each local player their own camera and HUD (up to 4).
- **Online:** RaceNet (ModeNet). The host owns the progress, checkpoints, positions, rescue and
  the countdown clock. Guests send input as in co-op. Positions and laps are synced each tick,
  and finishes are events. Bots run on the host.

## §12 Later (not in this plan)
- Items, boost pickups and weapons (Unnatural's FishAttacks may fit).
- More tracks (Sunken ruins, Kelp + wreck), mirror mode, time trial with a ghost (the replay
  kit), a race cup over several tracks.

## Phases
- **Phase 0 — Audit + measurements.**
  - Race top speed in Nature tuning, which gives the lap length.
  - The length of every roster entry before and after the cap.
  - How each family is driven (§2).
  - A terrain bench at track size with a test channel.
  - Answers to D1-D9.
- **Phase 1 — Mode skeleton on a test loop.**
  - RaceMatch, card, setup with RaceRoster, size cap, shared speed + RaceHandling.
  - RaceTrack on a flat **grey-box loop** (no carving yet, rings for walls).
  - Countdown, checkpoints, laps, positions, rescue, finish, results, HUD basics.
  - Solo + bots driving a plain RaceBot.
- **Phase 2 — The Canyon Reef Circuit.**
  - Native `channel` records, RaceLayout and the canyon_reef_track points.
  - The arch, tunnel, overhang dive, ridge climb and split.
  - Soft ceiling, out of bounds and wrong way.
  - `race_track_shots` tool (a top-down map plus shots at every feature).
- **Phase 3 — Look and guidance.**
  - Abyssal/reef dressing along the channel, lights in the tunnel.
  - Cues on the line (§6), bubble streams, slipstream.
- **Phase 4 — Bots + balance data.**
  - Full RaceBot (overtakes, streams, slipstream, skills, difficulty).
  - race_sim and race_roster_bench, with the numbers reported as open items.
- **Phase 5 — Split-screen + online** (RaceNet, guest join, sync).
- **Phase 6 — Polish.** Audio, results, personal bests, race camera tuning, setting_docs regen,
  INVENTORY.md.

Each phase ends with the regression probes plus a debug build, then a hand-off for play-test.

## Probes
- `race_track_probe`
  - The loop is closed.
  - Width and height stay within limits everywhere.
  - A size-cap ball clears the centreline and the racing line (`line_clear`).
  - No rock in the channel, and checkpoints are in order.
- `race_lap_probe`: a bot finishes 3 laps. Checkpoints are passed in order, and a skipped
  checkpoint or a backwards lap doesn't count.
- `race_rules_probe`: wrong way → banner → rescue, out of bounds → rescue, stuck → rescue, the
  finish clock and places by progress.
- `race_roster_probe`: every entry builds, is capped, and swims at the shared top speed
  (within 2%).
- `race_split_probe` (2-4 local players, 1080p window) and `race_net_probe` (host + guest:
  positions agree).
- Still green: `mode_boundary_probe --strict` and the existing mode baselines.
