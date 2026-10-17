# Plan: Going Co-op (Nature mode, together)

## Context
Nature is a single-player free play: one fish strides Extra Swishy through the Ocean after a calm
target fish (`NatureRun` + `WanderBot`), and ramming it fast enough batters it. Hunt
(`HuntMatch`) is the 1v1 version against a bot.

The goal is a **co-op Nature**: two or more people swim the same Ocean together, hunting the
same target fish, from the first build that ships it, and it should feel as good as solo Nature.

This document covers:
1. how co-op games are usually built, including how they talk to Steam, Epic and so on;
2. what in our code helps or gets in the way;
3. the architecture we recommend and why;
4. a phased plan where every phase can be tested;
5. the decisions you need to make.

---

## 1. How successful co-op games do it

The short answer to "do they have their own scaffolding, and does it talk to the platforms?" is
**yes, but in two separate layers.** Shipped games almost always keep them apart:

| Layer | What it does | Who usually builds it |
|---|---|---|
| **Gameplay netcode** | Who simulates what, what gets sent each tick, prediction, interpolation, hiding lag | The game itself, on top of the engine's networking (Godot: `MultiplayerAPI`, RPCs, `MultiplayerSynchronizer`/`Spawner`) |
| **Transport** | Moving packets between machines, getting through home routers (NAT), relays | The engine (ENet/UDP) or the platform (Steam Datagram Relay, EOS P2P) |
| **Platform services** | Accounts, friends, invites, lobbies, "Join game" from the friends list, matchmaking | Steamworks, Epic Online Services (EOS), console SDKs |

The gameplay layer should **never know which platform it's on**. It talks to an abstract
connection, and a small adapter plugs in Steam, EOS or plain IP. That way the same game code runs
on Steam, Epic, LAN and in our headless tests.

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
  on Steam with no netcode at all.** Lots of indie co-op games ship this way first.
- **Plain IP / LAN (ENet)**: built into Godot, needs no account, and is ideal for development and
  automated tests. It's not friendly for players (port forwarding), so it's for dev and LAN only.

### How Rocket League does it (the closest model to our physics)
Rocket League runs a **server-authoritative** simulation at a fixed 120 Hz. Clients **predict**
their own car and **roll back and re-simulate** when the server disagrees. Physics is
deterministic enough to replay from inputs. (See Jared Cone's GDC 2018 talk, "It IS Rocket
Science! The Physics of Rocket League Detailed".) It takes a lot of work, and it's needed because
it's competitive and players crash into each other and the ball every second.

**Co-op Nature doesn't need all of that.** Nobody is cheating against a teammate, the targets
are calm, and players rarely touch each other. That lets us choose a much simpler model that
still makes your own fish feel perfect (see §3).

---

## 2. What our code already gives us, and what's in the way

### Helps
- **`FishInput`** (`scripts/fish_input.gd`): a fish can already be driven by something other
  than the local controller (`FishController.controls`), which is how bots work. A remote
  player's fish, a second local player and a test script can all plug in here.
- **`FishController.replay_fx()`** plus **`ReplayData.FX_*`**: a compact float array of
  everything a fish *looks like* (tail swing and growth, timing cue, bow wave, stride bubbles,
  flow). That is almost exactly the "visual state" a remote fish needs on the network.
- **`ReplayCar`** (`scripts/replay/replay_car.gd`): draws a fish from recorded state plus FX with
  no physics, and offers the fields the follow camera and HUD read. A remote player's fish is a
  **"live replay car"** fed from the network instead of a clip.
- **`GoalRecorder`**: already samples every fish every tick. Its sampling is the same work a
  snapshot sender does.
- **`Match1v1.copy_tuning`** and `presets/nature.cfg`: a way to give every fish the same tuning.
- **`_announce_teleport` / `fish_teleported`**: we already tell cameras when a fish jumps. On
  the network, a teleport must be marked so remote views snap instead of smoothing.
- A **fixed 120 Hz physics tick** with input sampled in `_integrate_forces`, so there's a clean,
  numbered tick to hang networking on.

### In the way
1. **"The player" is a singleton everywhere.** `NatureRun` has one `player`. The HUD, the follow
   camera, `ArcadeFx`, the stride meter, the pause menu, `main.gd` and the debug panel all assume
   one local fish. **This is the biggest piece of work, and it's needed for any form of co-op,
   local or online.**
2. **Input is global.** With no `controls` set, `FishController` reads `Input.get_action_strength`
   directly, and `Controls` (autoload) rebinds the global actions per profile. Two local players
   on two pads can't be told apart yet.
3. **Physics isn't deterministic across machines.** Fish are Jolt `RigidBody3D`s with custom
   `_integrate_forces`. Floating-point results can differ between machines and builds, and Godot
   doesn't easily let us re-step one body for rollback. So **lockstep or rollback netcode is the
   wrong fit** without a very large rewrite.
4. **Game logic decides on one machine's view.** `NatureRun._physics_process` checks
   `Battery.hits(player, target, …)` and respawns with `randf_range`. In co-op exactly one
   machine must decide each battery and respawn, and everyone else must be told.
5. **Tuning changes live** (debug panel, presets). In co-op tuning must be the same for
   everyone, set by the host, and locked during a session.
6. **Pause** stops the world. Online, it can't.

---

## 3. Recommended architecture

### 3.1 Authority: host runs the world, each player owns their own fish
- **One peer is the host** (listen server, so one of the players). It owns the **world**: target
  fish and their `WanderBot`s, respawns, random numbers, score, the session clock, tuning.
- **Each player's machine owns that player's fish.** It simulates it locally with full physics
  and its own input, with **zero added input lag**. Extra Swishy is all about rhythm and feel, so
  this matters most. It sends its fish's state plus FX to the host about 30–60 times a second,
  and the host relays it to the others.
- **Remote fish are drawn, not simulated**: interpolated `ReplayCar`-style puppets, kept about
  100 ms behind in a small buffer so movement stays smooth through jitter and lost packets.
- **Target fish** are simulated on the host and interpolated the same way on clients.

This is "client-authoritative movement, host-authoritative game rules". It's the standard choice
for co-op games without competitive stakes, and it avoids determinism completely. Hunt or any
future PvP would need something stricter. That's a separate project, and nothing here blocks it.

### 3.2 Batteries: favour the attacker, host confirms
On a client, the target fish is drawn about 100 ms in the past. If only the host checked hits, a
client would ram the fish on screen and nothing would happen. So:
1. The **attacker's own machine** runs `Battery.hits` against the target **as it sees it**.
2. On a hit, it shows the hit at once (explosion, hit-stop and sound, predicted) and sends
   `claim_battery(target_id, tick, speed)` to the host.
3. The host **accepts the first plausible claim** (target alive, attacker near where the host
   saw the target recently, speed over `nature_batter_speed`). It then broadcasts
   `battery_confirmed(target, attacker)` and schedules the respawn.
4. If the claim is rejected (rare: two players hit it at once), the loser's prediction is quietly
   undone (the target reappears). With calm targets this almost never shows.

### 3.3 Fish against fish
Remote fish are puppets, so a real physics collision between two players would be one-sided.
For the first version, **co-op fish pass through each other** (or get a soft separating push
added on each side by its owner). They still show each other's bow wave and bubbles.
*Decision D3 below.*

### 3.4 Transport behind one interface
A `NetSession` autoload is the only thing that knows about transports:
- `host()`, `join(address_or_lobby)`, `leave()`, `peers`, signals `peer_joined` / `peer_left` /
  `session_failed`.
- Backends, each just a different Godot `MultiplayerPeer`:
  - **ENet** (direct IP / LAN, development and probes): first.
  - **Steam** (GodotSteam `SteamMultiplayerPeer` plus Steam lobbies and invites): when we go to
    Steam.
  - **EOS** (only if we want an Epic release or Steam–Epic crossplay).
  - **Lag simulator**: a `MultiplayerPeerExtension` that wraps another peer and adds set delay,
    jitter and loss. This makes bad networks repeatable in headless probes.
- Gameplay code uses only Godot's `multiplayer` API (RPCs, authority), never Steam calls.

### 3.5 What goes over the wire
| Message | Direction | Rate | Contents |
|---|---|---|---|
| Fish snapshot | owner → host → others | 30–60 Hz, unreliable | tick, position, rotation (compressed quaternion), linear and angular velocity, `replay_fx()` (quantised), flags (battered, teleported) |
| Target snapshot | host → all | 30 Hz, unreliable | same, per target |
| Events | any → host, host → all | on change, reliable | battery claim/confirm, respawn, teleport, score, session start/end |
| Session setup | host → joiner | once, reliable | tuning (the `nature.cfg` values), characters, names, team colours, seed, current world state |

Rough cost: about 100 bytes per fish snapshot × 60 Hz × 4 fish ≈ 24 KB/s. That's fine.

### 3.6 Clock
Every message carries the sender's physics tick. Each peer keeps a smoothed estimate of the
host's tick (NTP-style ping/pong) and draws remote things at `host_tick − interp_delay`. All
physics stays at 120 Hz. Only the send rate is lower.

---

## 4. Phased plan

Every phase ends with headless probes (`tests/…`), a build, and then your manual test, as usual.

### Phase 0: Spikes and decisions (short)
- Settle the decisions in §5.
- **Spike A:** GodotSteam with Godot 4.7: does a current release match our engine version, and
  does `SteamMultiplayerPeer` connect two machines with App ID 480? Report results only. Nothing
  is merged.
- **Spike B:** two headless Godot instances on localhost over ENet, exchanging a fish snapshot.
  This proves the probe harness can run two processes.

### Phase 1: Many local fish (no networking yet)
Remove the singleton-player assumption. This is needed whatever we choose next.
- A **`PlayerSlot`** idea: index, input source, fish, camera, HUD, character and team colour.
  `main.gd` holds a list of slots instead of one `fish`.
- **Per-device input:** `Controls` gains device-aware reading (pad index, or keyboard). A slot's
  fish reads through a `FishInput` filled from its own device, instead of global `Input`
  actions. Player 1 on the keyboard keeps working exactly as today.
- `NatureRun` takes a list of fish, and any of them can batter the target, with per-player
  and shared battery counts. Respawns go around the group (centroid, or the nearest player).
  `LEASH` is measured from the nearest player.
- HUD, follow camera, `ArcadeFx` and the stride cue become per-slot.
- **Probe:** two scripted `FishInput`s in one Nature run. Both can batter, the counts are
  right, and solo Nature is unchanged (the existing swishy and hunt probes still pass).

### Phase 2: Local split-screen co-op Nature (first playable co-op)
- Two `SubViewport`s (side-by-side or stacked), one camera and HUD each. Join with a button
  press on a second pad, on the mode card.
- Performance check: the Ocean rendered twice. Add a lower-quality split-screen setting if
  needed.
- **This alone gives online co-op through Steam Remote Play Together** once we're on Steam.
- **Probe:** split-screen screenshot frames (like `tests/stride_shots`).

### Phase 3: Online co-op over ENet (the real netcode)
- `NetSession` with the ENet and lag-simulator backends. A simple Host / Join (IP) menu.
- `NetFish` puppet (built on `ReplayCar`) with a snapshot buffer and interpolation. Snap on
  teleport.
- Owner-authoritative fish sync, host-authoritative targets, events, attacker-favoured batteries (§3.2).
- Session setup: the host's tuning is sent on join, and every tuning change after that is sent
  to everyone (D6). The debug panel is read-only for clients.
- Late join (get the full world state) and leave (the fish fades out, and the session carries
  on). If the host leaves, the session ends cleanly and everyone goes back to the menu.
- No pausing online: the pause menu becomes an overlay.
- **Probes:**
  - `tests/coop_sync_probe`: host and client headless with scripted strides. The client's
    view of the host fish is within X cm of the truth at 0, 100 and 200 ms simulated latency
    with 5% loss.
  - `tests/coop_battery_probe`: both clients ram the same target in the same tick. Exactly one
    battery is confirmed and the respawn is seen by both.
  - Join/leave and host-quit probes.
- **Manual test:** two copies of the game on your PC (Godot's "run multiple instances" or two
  builds), then over LAN.

### Phase 4: Steam
- Steam backend in `NetSession` (GodotSteam): create a lobby, invite friends, join through the
  friends list or overlay, rich presence ("Hunting in the Ocean"). Relay through Steam Datagram
  Relay, so no IPs and no port forwarding.
- Needs a Steamworks App ID before release. App ID 480 works until then.
- Remote Play Together flagged on, for split-screen.

### Phase 5 (optional): Epic / crossplay
- EOS backend through EOSG, only if we release on Epic or want Steam–Epic crossplay. The
  gameplay code shouldn't change. That's the test that §3.4 was done right.

### Later, not in this plan
- Co-op variants of Hunt (players vs bots), PvP netcode, replays in online sessions, voice chat
  (Steam and Discord already do it), dedicated servers.

---

## 5. Decisions (settled 2026-10-16)

| # | Question | Decision |
|---|---|---|
| D1 | Couch, online, or both? | **Both.** Couch (split-screen) first, then online. |
| D2 | How many players? | **2 to 4**, both local and online. Split-screen has 2-, 3- and 4-way layouts. |
| D3 | Do co-op fish collide? | **Not at first.** They pass through each other. |
| D4 | Co-op goal | **A shared battery count to start.** Tandem bonuses and perks for swimming in school formation come later (§5.1). |
| D5 | Platform | **Steam for now**, behind the `NetSession` layer (§3.4) so EOS or others can be added later without changing gameplay code. |
| D6 | Tuning | **Only the host can tune**, live, during the session. The host's changes go out to every peer. Clients' tuning panels are read-only. |
| D7 | Characters | **Each player picks their own fish.** It's sent in session setup and shown to everyone. |

### 5.1 Building now for the later co-op ideas
Tandem bonuses and school formation aren't in the first release. These choices keep them easy
to add:
- **Co-op rules live in their own node.** A `CoopRules` node, kept separate from `NatureRun`,
  listens to game events (battery confirmed, stride, flow, position) and awards score and perks.
  The first version only counts batteries. Tandem and school rules are added to it later without
  touching the netcode.
- **The host judges every rule that involves more than one player.** For a tandem bonus or a
  formation, it uses its own view of everyone's snapshots, so all players get the same result.
  Players see the perk when the host's event arrives, about one round trip later. For ongoing
  perks like formation that delay doesn't show. A one-off moment like a tandem battery uses the
  battery-claim ticks in §3.2, not the time messages arrive, so it stays fair at any ping.
- **Snapshots include the data formation needs.** Each fish snapshot already carries position,
  heading, velocity and flow (`FX_FLOW`). Fish without a perk ignore the extra fields.
- **Perks travel as data.** Perks such as more speed or a bigger bow wave are sent as reliable
  "perk on/off" events with a value. The owning machine applies them to its own fish, so they
  feel instant.

### 5.2 How these decisions change the phases
- **Phase 1:** up to 4 `PlayerSlot`s. The probe uses 4 scripted fish, not 2.
- **Phase 2:** 2-, 3- and 4-way split-screen layouts, and a performance check at 4.
- **Phase 3:** live host tuning: changes are sent as reliable "tuning changed" events, and
  clients apply them to their own fish. `CoopRules` starts with the shared count only. The probes
  run with 4 peers.
- **Phase 4:** Steam lobbies limited to 4.

## 6. Risks
- **The Phase 1 refactor touches a lot of code** (HUD, camera, main, debug panel). Mitigation:
  slot 0 must behave exactly as today, and existing probes guard it.
- **Split-screen rendering cost** of the Ocean (fog, bubbles, shaders) twice per frame.
- **GodotSteam / Godot 4.7 version match.** Spike A checks it before we commit.
- **Physics callbacks on puppets:** anything that reads `PhysicsDirectBodyState3D` or calls
  `physics_tick` on "a fish" must handle a puppet (`ReplayCar` has no physics body).
  `Battery.hits` must accept a puppet as the victim.
- **Frame-perfect feel** for the remote view of another player's strides: their tail and
  bubbles come from FX snapshots and are interpolated, so quick flicks may look softer. If that
  shows, send a stride-started event so the remote side can play the stride locally.
