# Plan: Going Co-op (Nature mode, together)

> **Revised 2026-10-16** after `expanding_on_nature.md` was built: schools (hundreds of fish),
> multis and sprees, pearls and the school wheel. New or changed parts are marked **[schools]**.
> The terminology now follows the game's: fish ramming fish is **battering** / a **battery**
> (never "demo").

## Implementation status (2026-10-16)
**Phases 0–3 are built and pass their probes. Phase 4 (Steam) is written but untested. Phase 5
(Epic) isn't started.** Awaiting manual testing.

**New files:**
- `scripts/player_input.gd` (`PlayerInput`): one player's controls (one controller and/or the
  keyboard), with the same actions and deadzones as `Input`. `everyone()` behaves exactly like
  `Input`, so single player is unchanged.
- `scripts/coop_rules.gd` (`CoopRules`): the team's counts, each player's share, shared batteries.
- `scripts/player_slot.gd`, `scripts/split_screen.gd`, `scripts/local_coop.gd`: split-screen
  (§4 Phases 1–2).
- `scripts/net/net_session.gd` (autoload `NetSession`): transports (ENet; Steam through
  GodotSteam if installed) and the simulated lag. `scripts/net/coop_session.gd`
  (`CoopSession`): the game protocol. `scripts/net/net_fish.gd` (`NetFish`): the interpolation
  buffer. `scripts/coop_menu.gd`: the pause menu's **Co-op online**.
- Probes: `tests/coop_local_probe`, `tests/school_sync_probe` (Spike C), `tests/coop_net_peer`
  with `tests/coop_net.sh` (host, laggy guest, late joiner as three processes). Window tool:
  `tests/split_shots`.

**Changed:**
- `nature_run.gd`:
  - `players`, the `authority` flag and the claim/confirm flow (also offline, so one code path);
  - per-player score, focus and battery speed;
  - seeded spawns, and the `*_claimed` / `*_confirmed` / `school_*` / `target_state` /
    `restarted` signals;
  - `apply_*` methods, `respawn_local()`.
- `school.gd`: seeded `rng`, `follower` mode (`set_net_state`/`net_state`), alive masks, and
  detail fish for several cameras (`view_cameras`).
- `fish_controller.gd`: `input_source`, puppet mode (`make_puppet`, `set_net_state`,
  `swim_velocity()`).
- `follow_camera.gd` and `target_wheel.gd`: `input` per player. The camera also keeps a 16:9
  vertical view in wide split-screen views.
- `hud.gd`: team and own counts, teammates' awards in the feed, and the join hint.
- `main.gd`: `LocalCoop`, `host_/guest_/solo_nature_run()`, the online pause, and the guest
  reset.
- `debug_panel.gd`: `tuning_changed`, `set_sections_locked()`.
- `pause_menu.gd`: `pauses`, the opened/closed signals, **Co-op online**.
- `broadcast_ui.gd`: text shrinks to fit (for the BATTERED FISH column).
- `pearl.gd`: `id`.
- `project.godot`: the `NetSession` autoload.

**Naming.** "Batteries" (the count) is now **Battered Fish** everywhere: UI (BATTERED FISH
columns, "Battered fish" HUD line) and code (`battered_fish`, `batter_schools`,
`nature_battered_fish_probe`). A single hit is still "a battery".

**Measured:**
- **Spike B:** two and three headless Godots over ENet on localhost work (`coop_net.sh`).
- **Spike C** (`school_sync_probe`, 100 ms lag, 30 ms jitter, 5% loss, 50 fish, one minute):
  - a fish is on average **0.35 m** from its twin on the other machine, and at most **1.0 m**;
  - the leaders end 0.15 m apart, and a battery takes the same fish on both.

  This needed a quicker catch-up than first written (position 8/s, heading 10/s). At 3/s the
  average was 0.53 m.
- **Online** (`coop_net.sh`, guest at 60 ms ± 20 ms with 2% loss):
  - the host's fish shows on the guest within **0.12 m** (mean) of where it really was 100 ms
    earlier;
  - the host's school matches within **0.4 m** per fish.
- **Split-screen** (`split_shots`, 1600×900, Nature defaults): 1, 2, 3 and 4 players all hold
  **60 fps** (vsync-capped, 16.7 ms median). Draw calls: 75 → 423 → 672 → 1,055.

**Where the build differs from the plan:**
- **Lag simulation** is in `CoopSession`'s send queue (it delays and drops our own messages on
  the way out), not a `MultiplayerPeerExtension`. Simpler, and it covers everything the game
  sends.
- **The share window** (two claims on one fish) is 0.3 s by arrival at the host, not by claim
  ticks. Two local players on one fish in the same tick share it too.
- **The host trusts claims.** There's no "was the attacker near?" check: it's co-op.
- **Pearls:** the host decides for puppets from its own view (a pearl drawn into a guest's puppet
  there counts for that guest). A guest's own absorbs are claimed. Either way it counts once.
- **Joining split-screen** works only during a run (not on the card). Joined players get the
  next unused fish. A joined player's character is changed with D-pad left/right (online too:
  everyone sees it).
- **2-player split** is one view above the other. Views wider than 16:9 keep the 16:9 vertical
  view, so the fish isn't cropped.
- **A guest's R** puts only their own fish back. The host's restart restarts everyone.
- **Leaving Nature** (or changing mode) as host ends the session. As a guest, it leaves.
- **Steam (Phase 4, Spike A):**
  - GodotSteam **4.20** supports Godot 4.7, and its MultiplayerPeer is now part of the main
    addon.
  - The backend (`NetSession.host_steam`/`join_steam`/`invite_friends`, lobby callbacks, rich
    presence) calls it by name, so the game runs without it, and the Steam buttons only show
    once it's there.
  - **Installed (2026-10-16):** GodotSteam GDExtension **4.23** (Steamworks 1.65), from
    Codeberg, in `addons/godotsteam/`. Its editor updater plugin is left off.
    - The export copies `libgodotsteam…dll` and `steam_api64.dll` next to the game.
    - **Switched off for now (2026-10-16, the user's call):** `NetSession.STEAM_ENABLED = false`.
      The addon stays installed but Steam never starts, and the Co-op menu shows only Host / Join
      by address. Turn it back on once the game has its own App ID with Steam Input off by
      default. While on:
    - Steam starts only when it's used: **Host on Steam**, joining a lobby, or a launch from an
      invite. It uses App ID 480 (Spacewar) until `steam/initialization/app_data/app_id` is set,
      and never starts headless or with `--no-steam`. It used to start with the game, but then
      Steam applies the app's **Steam Input** controller layout, and Spacewar's takes the
      controller over: the game stopped seeing it (2026-10-16). In a Steam session this can still
      happen until the game has its own App ID with Steam Input off; meanwhile, turn off Steam →
      Settings → Controller → *Enable Steam Input for Xbox controllers*.
    - A `+connect_lobby` launch (accepting an invite with the game closed) joins that lobby.
    - Rich presence sets `connect`, so with the game running a friend can use **Join Game** in
      the friends list.
    - The overlay invite only works when Steam launched the game. The Co-op menu also shows
      the lobby number with **Copy**, and a friend pastes it into **Lobby** and presses **Join**.
  - **Tested:** hosting (`tests/steam_check`, needs a window and Steam running) makes a
    friends-only lobby and hosts over `SteamMultiplayerPeer`. Joining needs a second Steam
    account, so it isn't tested yet.

**Open items:**
- Test joining over Steam with a friend: invite from the overlay, join from the friends list.
- Look at how another player's strides look online. If quick flicks look soft, add the
  stride-started event (§6).
- Name entry is the pause menu Co-op panel's **Name** (the same setting as Settings → UI).
- A host leaving ends the session (no host migration).
- `school_probe` is flaky on its own (about 1 run in 10 fails a random check, before and after
  this work).

## Context
Nature is free play in the Ocean. You stride Extra Swishy among **schools** of NPC fish (3
schools of 50 by default, with up to 1,000+ fish measured), plus an optional lone target fish
(`NatureRun`, `School`, `WanderBot`).
- Ramming fish nose first at `nature_batter_speed` or faster **batters** them.
- Quick hits chain into **multis**, and fast runs build **sprees** (`NatureScore`).
- Battered fish may drop **pearls**, which are pulled towards nearby fish (`Pearl`).
- **Y** targets a school, and holding Y opens a wheel to pick one (`TargetWheel`).

The goal is a **co-op Nature**: 2–4 people in the same Ocean, couch and online, hunting the same
schools. It should feel as good as solo Nature from the first build that ships it.

This document covers:
1. how co-op games are usually built, including how they talk to Steam, Epic and so on;
2. what in our code helps or gets in the way;
3. the architecture and why;
4. the phases;
5. the decisions (settled);
6. the risks.

---

## 1. How successful co-op games do it

Shipped games almost always split networking into **separate layers**:

| Layer | What it does | Who usually builds it |
|---|---|---|
| **Gameplay netcode** | Who simulates what, what gets sent each tick, prediction, interpolation, hiding lag | The game itself, on top of the engine's networking (Godot: `MultiplayerAPI`, RPCs, `MultiplayerSynchronizer`/`Spawner`) |
| **Transport** | Moving packets between machines, getting through home routers (NAT), relays | The engine (ENet/UDP) or the platform (Steam Datagram Relay, EOS P2P) |
| **Platform services** | Accounts, friends, invites, lobbies, "Join game" from the friends list, matchmaking | Steamworks, Epic Online Services (EOS), console SDKs |

The gameplay layer should **never know which platform it's on**. It talks to an abstract
connection, and a small adapter plugs in Steam, EOS or plain IP. The same game code then runs on
Steam, Epic, LAN and in our headless tests.

### What the platforms give you
- **Steam (Steamworks)**: lobbies, friend invites, rich presence, and **Steam Datagram Relay**,
  which connects players without port forwarding and hides their IPs. In Godot this is the
  community **GodotSteam** extension. It includes a `SteamMultiplayerPeer`, so Godot's own
  multiplayer API runs straight over Steam. You need a Steamworks partner account and an App ID
  (US$100 per app). For development you can use the shared test App ID 480 ("Spacewar").
- **Epic Online Services (EOS)**: free, works on any store (including Steam), and has lobbies,
  P2P relay and cross-platform accounts. Godot has a community plugin (EOSG). This is the usual
  choice for **crossplay between Steam and Epic**.
- **Steam Remote Play Together**: Steam streams one PC's game to friends, and their controllers
  act as local controllers on the host. **A game with local split-screen co-op gets online co-op
  on Steam with no netcode at all.**
- **Plain IP / LAN (ENet)**: built into Godot, needs no account, and is ideal for development and
  automated tests.

### How Rocket League does it (the closest model to our physics)
Rocket League runs a **server-authoritative** simulation at a fixed 120 Hz. Clients **predict**
their own car and **roll back and re-simulate** when the server disagrees. (See Jared Cone's GDC
2018 talk, "It IS Rocket Science! The Physics of Rocket League Detailed".) It's needed because the
game is competitive and players crash into each other and the ball every second. **Co-op Nature
doesn't need it.** Nobody cheats against a teammate, NPC fish don't fight back, and players
don't bump each other (D3).

---

## 2. What our code gives us, and what's in the way

### Helps
- **`FishInput`** (`scripts/fish_input.gd`): a fish can be driven by something other than the
  local controller (`FishController.controls`). A second local player and test scripts plug in
  here.
- **`FishController.replay_fx()`** plus **`ReplayData.FX_*`**: a compact float array of how a fish
  looks (tail, cue, bow wave, bubbles, flow). That's the visual state a remote fish needs.
- **`ReplayCar`**: draws a fish from recorded state plus FX with no physics, and offers the fields
  the follow camera and HUD read. A remote player's fish is a **"live replay car"**.
- **`GoalRecorder`**: already samples every fish every tick, which is the same work a snapshot
  sender does.
- A **fixed 120 Hz physics tick**, with input sampled in `_integrate_forces`.
- **[schools]** **`School` is data, not nodes**, stepped at its own `sim_rate` (30 Hz) and drawn
  interpolated. It already behaves like a networked object: a small state that's stepped, plus
  smooth drawing between steps.
- **[schools]** **Threats and collectors are already lists.** `School.threats` and
  `Pearl.collectors` are `Array[FishController]`. Schools already react to the nearest threat,
  and pearls are already drawn to the nearest collector.
- **[schools]** **`NatureSettings.shared()`**: every Nature number in one resource. Sending the
  host's tuning means sending this resource plus the fish tuning.
- **[schools]** **Scoring is event-shaped.** `NatureScore.on_battery()` returns points and emits
  `awarded(event)` dictionaries, which can be sent over the network as they are.
- **[schools]** **No slow-mo** while the school wheel is open, which was already decided with
  co-op in mind.

### In the way
1. **"The player" is a singleton.** `NatureRun.player` is used throughout:
   - spawning schools and the lone target around it;
   - `LEASH`, and the hidden spawn direction (outside *its* view);
   - the hitbox pool near it;
   - `_slow_player`;
   - `score.update(…, player.speed, …)`;
   - `focus` / `pick_focus()`.

   The HUD, follow camera, `ArcadeFx`, `TargetWheel`, pause menu, `main.gd` and the debug panel
   all assume one local fish too. **[schools]** The schools plan (§9) meant to build `NatureRun`
   with a list of players, but the code still has a single `player`, so this work is still ahead
   and has grown.
2. **Input is global.** With no `controls`, `FishController` reads `Input` actions directly. The
   same goes for Y / the wheel and the right-stick wheel steering. Two local pads can't be told
   apart yet.
3. **Physics isn't deterministic across machines** (Jolt `RigidBody3D`). That rules out lockstep
   and rollback.
4. **[schools]** **School randomness comes from the global RNG.** `School` and `NatureRun` use
   `randf()` / `pick_random()` (route spots, wander phases, slots, names, characters, spawn
   points, pearl drops). Two machines can't build the same school from a seed until each school
   has its own seeded `RandomNumberGenerator`.
5. **[schools]** **Schools react to *local* threat positions.** The bait ball, swerve and
   `_away_from_threats` use each threat's position and velocity. On each machine, remote players
   are drawn ~100 ms in the past, so two machines running the same school will drift apart unless
   one of them leads.
6. **[schools]** **Detail fish follow one camera.** `School._choose_details` uses
   `get_viewport().get_camera_3d()`. With split-screen there are 2–4 cameras.
7. **Game rules are decided on one machine's view**: battered fish, respawns, pearl drops and
   collection.
8. **Tuning changes live** (debug panel, presets, the NATURE section, "Respawn schools").
9. **Pause** stops the world.

---

## 3. Architecture

### 3.1 Authority
- **One peer is the host** (a listen server, one of the players). It owns the **world**:
  - school routes and alarm, populations, spawns and respawns;
  - the lone target, its `WanderBot` and its respawns;
  - pearl drops and their ids;
  - shared counts, the session and tuning.
- **Each player's machine owns that player's fish.** It's simulated locally with full physics and
  that player's own input, so there's **no added input lag**. It sends state plus FX about 30–60
  times a second.
- **Remote player fish are drawn, not simulated:** interpolated `ReplayCar`-style puppets, kept
  ~100 ms behind in a small buffer.
- **The lone target** is simulated on the host and interpolated on clients, like a remote fish.

### 3.2 [schools] Schools: host leads, everyone simulates the followers
Sending every school fish isn't an option. 1,000 fish × 30 Hz × ~30 bytes is ~900 KB/s. Instead,
**every machine runs the school simulation itself, and the host steers it**:
- **Spawn:** the host sends `school_spawned(id, seed, kind, at, heading, settings_rev)`. Each
  machine builds the school from the same seed, so it has the same slots, wander phases, name and
  look. That needs a seeded per-school RNG (§2.4).
- **Leader and mood, from the host at ~10 Hz:** the leader's position, heading and spot, the
  alarm (bait ball), and the "away" vector. Clients don't decide reactions themselves. They ease
  their copy of the leader towards the host's, and use the host's alarm and away vector. Only the
  host runs `_update_alarm` / `_away_from_threats`, using all players' fish.
- **Followers are local.** Each machine steers the fish to their slots, with separation and
  noise, from that leader. Fish positions can differ by centimetres between machines. You can't
  see that, and battering favours the attacker (§3.3), so it doesn't matter.
- **Bursts and deaths are events.** `fish_battered(school_id, index)` makes every machine run
  `School.batter(index)` locally (hide the fish, burst its neighbours, small explosion).
- **Cost:** ~40 bytes per school at 10 Hz, **whatever the fish count.** 1,000 fish cost the
  same as 50.
- **Later, if needed:** the GDExtension or compute-shader port planned in the schools doc (§9b)
  doesn't affect this. The data layout and the seeded RNG carry over.

### 3.3 Battered fish: the attacker's view decides, the host confirms, ties are shared
On a client, remote things are drawn slightly in the past, so the **attacker's own machine**
detects hits against what its player sees:
1. **Lone target:** `Battery.hits(fish, target, nature_batter_speed)`. **School fish:** the hitbox
   pool plus `Battery.areas_touched`, run around **each local fish** (not "the player").
2. On a hit it plays the hit at once: explosion, `_slow_player` speed cost, multi callout and
   ArcadeFx. Then it sends `claim_battery(target_ref, tick, speed, chain_step)`. `target_ref` is the
   lone fish, or `(school_id, fish_index)`.
3. **The host accepts if plausible:** the fish is still alive, and the attacker was near where
   the host saw it. It then broadcasts `battery_confirmed(target_ref, attackers)`.
4. **[schools] Ties are shared, not rejected.** If a second claim on the same fish arrives within
   a short window (~150 ms), it's added to that battery and **both players get the credit**. So
   nobody's hit is ever taken back, which was the one case that would have looked broken. It also
   gives us a free **tandem moment** (D4) to celebrate later.
5. A claim on a fish the host already saw battered long before (lag spike, or a stale view) is
   dropped silently. The attacker already saw their explosion, and the fish was dead anyway.

### 3.4 [schools] Scoring: personal chains, shared total
- **Multis and sprees are personal.** Each player has their own `NatureScore` on **their own
  machine**, driven by their own predicted battered fish and their own speed. UT-style callouts have
  to be instant, and a chain is one player's skill. Awards (`awarded` events) go to the host and
  out to everyone for the feed ("P2 TRIPLE FRY +200").
- **The shared count** (D4) is the host's: battered fish and pearls, team total and per player. The
  HUD shows the team number large and each player's own number small.
- **Points** can stay personal now. Team bonuses (tandem, school formation) go into
  `CoopRules` later (§5.1).

### 3.5 [schools] Pearls
- **Drops are the host's.** A confirmed battery carries the attacker's `chain_step`, so the host
  rolls `pearl_chance` plus the per-step bonus with its own RNG and broadcasts
  `pearl_spawned(id, at)`.
- **The magnet runs everywhere.** Every machine pulls each pearl towards the nearest collector,
  remote puppets included. You see a pearl fly to your friend.
- **Collection is claimed**, just like a battery: the collector's owner absorbs it, then sends
  `claim_pearl(id)`. The host gives it to the first claim and broadcasts `pearl_collected(id, by)`.
  If two players' magnets both win it, the later one sees it stream to the winner instead.

### 3.6 Targeting and the camera
- **`focus`, ball cam and the wheel become per local player**: one per camera and pad. The
  wheel's slices are placed by direction from *that player's* camera.
- **[schools]** **Detail fish** follow the nearest **local** cameras (all split-screen views), with
  `detail_fish` shared between them, not one camera.

### 3.7 Fish against fish (D3)
Co-op fish **pass through each other** at first. They still trigger each other's bait balls
and see each other's bow waves and bubbles.

### 3.8 Transport behind one interface (D5)
A `NetSession` autoload is the only thing that knows about transports:
- `host()`, `join(address_or_lobby)`, `leave()`, `peers`, and signals `peer_joined` /
  `peer_left` / `session_failed`.
- **Backends**, each a Godot `MultiplayerPeer`:
  - **ENet** (dev, LAN, probes);
  - **Steam** (GodotSteam plus Steam lobbies and invites);
  - **EOS** later if wanted;
  - a **lag simulator** (`MultiplayerPeerExtension`) that wraps another peer and adds delay,
    jitter and loss for probes.
- Gameplay code uses only Godot's `multiplayer` API, never Steam calls.

### 3.9 What goes over the wire
| Message | Direction | Rate | Contents |
|---|---|---|---|
| Fish snapshot | owner → host → others | 30–60 Hz, unreliable | tick, position, compressed rotation, velocities, quantised `replay_fx()`, flags (battered, teleported) |
| Lone target snapshot | host → all | 30 Hz, unreliable | same |
| **[schools]** School state | host → all | ~10 Hz, unreliable | id, leader position, heading and spot, alarm, away vector |
| **[schools]** School / pearl lifecycle | host → all | on change, reliable | `school_spawned` (with seed), `school_removed`, `pearl_spawned`, `pearl_collected` |
| Claims | owner → host | on hit, reliable | `claim_battery`, `claim_pearl` |
| Confirmations and awards | host → all | on change, reliable | `battery_confirmed` (one or more attackers), `awarded`, shared counts |
| Tuning | host → all | on join and on change, reliable | fish tuning plus `NatureSettings`, with a revision number |
| Session setup | host → joiner | once, reliable | characters, names, current world: schools (seeds plus current state, which fish are alive), pearls, the lone target, counts |

Rough cost with 4 players and 3 schools: 4 fish × ~100 bytes × 60 Hz + 3 schools × ~40 bytes ×
10 Hz ≈ **25 KB/s**, flat as fish counts grow.

### 3.10 Clock
Every message carries the sender's physics tick. Each peer keeps a smoothed estimate of the host
tick (ping/pong) and draws remote things at `host_tick − interp_delay`. Physics stays at 120 Hz
and schools at their `sim_rate`.

---

## 4. Phases

Every phase ends with headless probes, a build, and then your manual test.

### Phase 0: Spikes
- **Spike A:** GodotSteam with Godot 4.7: does a current release match our engine version, and
  does `SteamMultiplayerPeer` connect two machines with App ID 480? Report results only.
- **Spike B:** two headless Godot instances on localhost over ENet, exchanging a fish snapshot.
  This proves the probe harness can run two or more processes.
- **[schools] Spike C:** two copies of one `School`, built from the same seed, fed the same
  leader and alarm at 10 Hz. Measure how far apart their fish drift over 60 s. That checks §3.2
  before we build on it.

### Phase 1: Many local fish (no networking yet)
- **`PlayerSlot`s (up to 4):** index, input device, fish, camera, HUD, `NatureScore`, focus and
  wheel, character and team colour. `main.gd` holds a list of slots.
- **Per-device input**, including Y / the wheel and the right stick. Player 1 on the keyboard
  works exactly as today.
- **[schools] `NatureRun` takes `players`:**
  - spawns hidden from **every** player's view;
  - `LEASH` / the farthest school measured from the **nearest** player;
  - hitbox pools around each player, and `_slow_player` per player;
  - `School.threats` and `Pearl.collectors` set to all players;
  - the lone target's `WanderBot.threat` becomes the nearest player.
- **[schools] Seeded RNG:** each school gets its own `RandomNumberGenerator` from a spawn seed.
  `NatureRun` gets a run RNG for spawns, names, kinds and pearl rolls. No global `randf()` in
  Nature world code.
- **[schools]** Detail fish chosen across all local cameras.
- **`CoopRules`** node with the shared battery and pearl counts (§5.1).
- **Probe:** 4 scripted fish in one Nature run, with schools:
  - every player can batter and collect;
  - each player's multis are their own;
  - the shared counts are right;
  - two players hitting the same fish in the same tick both get credit.
  The existing Nature probes still pass with one slot (`nature_probe`, `nature_schools_probe`,
  `nature_battered_fish_probe`, `nature_score_probe`, `target_wheel_probe`, `swishy_probe`,
  `hunt_probe`).

### Phase 2: Local split-screen (2-, 3- and 4-way)
- `SubViewport`s with one camera, HUD and wheel each. Join with a button press on a spare pad.
- **[schools] Performance:** run `school_bench` in 2- and 4-way split. Split-screen draws the
  Ocean and every school's MultiMesh once per view. If that's too slow, add a split-screen quality
  setting (detail fish per view, the LOD distance, school counts).
- This alone gives online co-op through Steam Remote Play Together once we're on Steam.
- **Probe:** split-screen screenshot frames, like `school_shots`.

### Phase 3: Online over ENet
- `NetSession` with the ENet and lag-sim backends, and a Host / Join (IP) menu.
- `NetFish` puppet (from `ReplayCar`) with interpolation and teleport snaps. It has to answer
  what `School` threats and `Pearl` collectors read: `global_position`, `linear_velocity` and
  `battered`.
- Owner-run fish. **[schools]** Host-led schools (§3.2), claims for battered fish and pearls with shared
  ties (§3.3, §3.5), personal scoring and shared totals (§3.4).
- Host tuning (D6): sent on join and on every change, fish tuning plus `NatureSettings`.
  Clients' panels are read-only, and **"Respawn schools" is host-only**.
- **Late join:** the full world snapshot, including school seeds plus which fish are alive.
  **Leave:** the fish fades out and the session carries on. **Host quits:** a clean end.
- No pausing online: the pause menu becomes an overlay.
- **Probes** (4 peers, with lag-sim at 0, 100 and 200 ms and 5% loss):
  - `coop_sync_probe`: remote fish within X cm of the truth.
  - **[schools]** `coop_schools_probe`: every peer's copy of each school stays within Y m of the
    host's (centre and per fish). A battery's burst plays everywhere, and the same fish are dead
    on every peer.
  - `coop_battery_probe`: two peers hit the same fish in the same tick. One battery, both
    credited, one pearl roll.
  - **[schools]** `coop_pearl_probe`: two collectors race for one pearl. It's counted once.
  - Join, late-join and leave, and host-quit probes.
- **Manual test:** two copies of the game on one PC, then over LAN.

### Phase 4: Steam
- Steam backend in `NetSession`: lobbies (max 4), invites, join from the friends list, rich
  presence ("Hunting schools in the Ocean"), relayed through Steam Datagram Relay.
- Needs a Steamworks App ID before release. App ID 480 works until then.
- Remote Play Together flagged on.

### Phase 5 (optional): Epic / crossplay
- EOS backend. No gameplay code changes, which is the test that §3.8 was done right.

### Later, not in this plan
- Tandem bonuses and school-formation perks (§5.1)
- co-op Hunt
- PvP netcode
- replays in online sessions
- voice chat
- dedicated servers

---

## 5. Decisions (settled 2026-10-16)

| # | Question | Decision |
|---|---|---|
| D1 | Couch, online, or both? | **Both.** Couch (split-screen) first, then online. |
| D2 | How many players? | **2 to 4**, local and online. Split-screen has 2-, 3- and 4-way layouts. |
| D3 | Do co-op fish collide? | **Not at first.** They pass through each other. |
| D4 | Co-op goal | **A shared battery count to start** (pearls counted the same way). Tandem bonuses and school-formation perks come later (§5.1). |
| D5 | Platform | **Steam for now**, behind `NetSession` (§3.8), so EOS or others can be added later. |
| D6 | Tuning | **Only the host can tune**, live, during the session. The host's changes (fish tuning and `NatureSettings`) go out to every peer. Clients' panels are read-only. |
| D7 | Characters | **Each player picks their own fish.** It's sent in session setup and shown to everyone. |

### 5.1 Building now for the later co-op ideas
- **Co-op rules live in their own node.** A `CoopRules` node, separate from `NatureRun` and the
  netcode, listens to game events and awards team score and perks:
  - confirmed battered fish, with their attackers;
  - awards, pearls, strides, flow and positions.

  The first version counts battered fish and pearls.
- **The host judges anything that involves more than one player** (tandem, formation), from its
  own view of everyone's snapshots, so all players get the same result. A tandem uses the claim
  ticks (§3.3), not when messages arrive, so it stays fair at any ping. **[schools]** Shared-credit
  battered fish (two players, one fish) are the first tandem moment, and they come free.
- **Snapshots include what formation needs:** position, heading, velocity and flow (`FX_FLOW`).
- **Perks travel as data:** reliable "perk on/off" events with a value, applied by the owning
  machine to its own fish, so they feel instant.
- **[schools]** **Schools as a formation reference:** "swimming in school formation" could also
  mean players joining an NPC school's slots. `School` already has slots and a leader frame, so
  `CoopRules` can measure against either.

---

## 6. Risks
- **Phase 1 is big.** It reaches `NatureRun`, the HUD, the camera, `TargetWheel`, `main.gd`, the
  debug panel and now scoring and pearls. Mitigation: slot 0 behaves exactly as today, and the
  existing Nature probes guard it.
- **[schools] Split-screen rendering cost** with hundreds of school fish drawn per view. Measure
  it in Phase 2 with `school_bench`.
- **[schools] School drift between machines** (§3.2). Spike C measures it. The fallback is
  sending a per-school position and velocity correction more often (still cheap), or a sparse
  per-fish correction for the fish near each player.
- **GodotSteam / Godot 4.7 version match.** Spike A checks it.
- **Puppets in typed arrays:** `School.threats` and `Pearl.collectors` are
  `Array[FishController]`. Remote puppets aren't `FishController`s, so either the arrays become a
  small shared interface (or `Node3D` duck typing), or puppets get a thin `FishController`-shaped
  type. Same for `Battery.hits` with a puppet as the victim (the lone target).
- **How remote strides look:** a remote player's tail and bubbles are interpolated from FX
  snapshots and may look softer than live. If they do, send a stride-started event so the remote
  side can play the stride locally.
