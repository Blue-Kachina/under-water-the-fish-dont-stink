# Plan: Unnatural (blood moon survivors mode)

## Context
There's a blood moon tonight, and every fish in the sea has turned at once, except us and our
co-op partners. The zombie fish come after us. We survive, level up, dig up treasure, and beat
the stage's boss to complete it.

Unnatural plays like **Megabonk** (and Vampire Survivors before it):
- **A fixed-size arena.** One stage at a time, and its boss ends it.
- **Few enemies at first, thousands later.** No fixed number of schools or fish per school. An
  **EvilDirector** decides how many enemies there are, how big the swarms are and what kinds come,
  mainly by time elapsed.
- **An auto-attack per fish**, so the slow opening isn't dull. Later, each fish is unique in how
  it swims and in its basic attack.
- **Levels.** Max health grows with level. Each level-up gives +1 to the fish's own signature
  stat, plus a pick of **three distinct stat upgrades**, each with a random **rarity** (common →
  legendary) that **luck** pushes up.
- **Buried treasure chests** around the arena. Each gives a **powerup**. Powerups **stack**: the
  same one again makes it stronger.
- **Timed events:** a mini-boss, a boss and a few set swarms at fixed times.
- **The same co-op as Nature:** split-screen and online, 1–4 players, never hard-coded to 2.

Out of scope for this plan: more stages and stage variety, meta-progression between runs
(unlocks, a shop), sound, and the full powerup list (it's still being worked out; §7 builds the
system and the first four).

**Naming** follows the house rules. Ramming is a **battery** and fish are **battered**. Two at once
is a **Fish Fry**. Teams are team colours / team 0, 1. "Demo" is only for Rocket League.

## Status
**Phases 0 to 8 are built (2026-10-17), and so is the second play-test's round of changes (Round 2
below). Phase 9 isn't started.** Pick **Unnatural** or **Test Tank** in the mode list.
**The Playability pass's P3 (feel and readability) is built (2026-10-23): see "P3 as built".**
Next is P4.

### Handoff (2026-10-18, balance pass 1): start here
**State:** the defaults are rebalanced from 10 rounds of sims and the user's own logs (see
"Balance pass 1" below). The build is in `builds/windows/FishPlayground.exe` (16:08). Final round:
5 of 8 greedy runs beat the Leviathan at Lv 27–30, with purses of 10–77 pearls at minute 9 (they
were 300–1,300). Halo builds lose most (3 of the 5 losses): a candidate for the next pass.

**Results** (round 6, all six fish, greedy and random picks, with the defaults):
- 9 of 12 runs beat the Leviathan at about 10 minutes, at Lv 17–30. The horde fills (0.8–1.0)
  until about minute 8, and items are 6–20 by the boss.
- Dominus was then fixed (round 9): greedy picks won 3 of 3, at Lv 27–34.
- Random picks still lose. They often never take a second weapon.

**Open:**
- **The user's own run logs.** They now save as the run goes. Compare a human's fill, level and
  damage taken with the bot's.
- **The bot.** It is safer than a player at range: the horde rarely kills it once it's ahead.
  Tune `enemy_damage_scale` and `difficulty_damage` from human logs, not from the bot.
- **The bench's crowd** overrates area and front-cone weapons (Bite, Greek Fire). Use whole-run sims
  for the final call.
- **Greek Fire** is still about 2–3× the others at Lv 15–20 on the bench.
- **Next:** P3 (feel and readability), then P4 (stacking curves).

### Handoff (2026-10-18, playability pass P2)
**State:** P2 is built and probed (see "P2 as built"). The build is in
`builds/windows/FishPlayground.exe` (10:46, with the Lv 15 and 20 milestones and the visible remoras). Nothing is half-done.
1. **The first full sim** (6 runs: Dominus, Octane and Merc, greedy and random picks). The reports
   are in `user://run_logs/sim/sim_p2_*.json`.
   - Every run **beat the Leviathan** at about 10 minutes. No run ended with the bot down.
   - Octane and Dominus snowball. They're at Lv 60 by 10:00, with 2,500+ kills a minute and
     30,000 dps. ttk is under 0.3 s from minute 2 and near 0 from minute 5.
   - Merc is closer: ttk sits inside the target until minute 6, then falls to 0.09 s.
   - The bot takes almost no damage (often under 20 a minute).
   - The economy snowballs with the kills. By minute 10 it's 300 to 800 pearls a minute, the purse
     is over 1,400, and 50+ chests have been opened. Even at 0.05 and 0.002, the drop chances don't
     hold back a build killing thousands a minute.
   - Levers to discuss with the user (none changed yet):
     - XP per level (the level curve);
     - `difficulty_hp` and its growth;
     - elites always dropping 3 pearls;
     - chest price growth;
     - the boss timing;
     - whether the bot is too safe compared with a player.
2. **Fixed along the way:** Greek Fire and Depth Charges threw a script error when the oldest
   patch or mine had already burnt out or gone off. They read it into a typed variable; it's
   untyped now.
3. **Next: P3** (feel and readability), after the user's call on the balance levers.

### Handoff (2026-10-18, playability pass P1)
**State:** P1 of the Playability pass is built and probed, and the build is in
`builds/windows/FishPlayground.exe` (08:23). Nothing is half-done. The user does all the git.

1. **Awaiting the user's play-test of P1.** Expect tuning on:
   - the card weights (`card_weight_*`), and how fast 2 + 2 slots fill (D17);
   - the facet steps (POWERUPS > Weapons) and the rarity table (`facets_*`, `facet_size_*`);
   - the economy: `pearl_drop_chance` (0.12), `chest_price_base` (8) and `chest_price_growth`
     (0.25 a minute);
   - the milestones' feel (Lv 5 and 10). Try them in the Test Tank: a weapon's `*_stacks`
     setting and `attack_level` are level overrides.
2. **For the user to confirm:** three defaults (see "P1 as built"):
   - the Coil's swap offer;
   - per-player purses (not the team's);
   - Sunken Idol takes items only.
3. **Next: P2**, the run simulator (`tests/run_sim.tscn`), run logs and Test Tank presets. Then
   P3 (feel, which takes in phase 9's juice), P4 (choice tools and limiters), P5 (pacing, incl.
   the Leviathan's chest and a next stage), P6 (meta), P7 (co-op, batteries, every mode).
4. **Known gaps:**
   - Leviathan's Coil can't be earned yet (the Leviathan ends the run; P5).
   - Online, a pearl two players take at once can land in both purses.
   - Rerolls, skips and banishes wait for P4 and P6.
5. **Probe notes:**
   - Probes that aren't about prices set `chest_cost = false`.
   - `unnatural_net_peer` sets `card_choices = 0`. Kills now level the team at once, and a
     player picking cards hides from the zombies.
   - New probes: `slots_probe` and `pearl_currency_probe`.
   - The online test runs with `tests/unnatural_net.sh <godot> <port>`.
   - Regression on 2026-10-18: every probe passed except `school_probe` (Nature, untouched by P1). It failed twice in the full run, each time on a different random check ("near the camera the nearest get full models", then "still schools at a 10 Hz step"), then passed 3 of 3 re-runs. That fits its known flakiness, but two failures in a row is more than usual, so keep an eye on it.
     A separate re-run in the first session failed it again, on another check ("still schools at
     a 10 Hz step"), probably under load from other Godot runs. It's Nature-only, and P1 didn't
     touch it.

### Handoff (fourth 2026-10-17 session)
**State:** the answers to the open questions (D9 to D16) are built and probed. So are the first
batch of powerups (D14) and the Boss and Cursed tiers (D13). See "The first powerup batch" and "Boss
and Cursed powerups" below. Nothing is half-done. The user does all the git.

1. **Awaiting the user's play-test** of Round 2 and of this session's work. Expect tuning on:
   - the follow cam's swing (`camera_swing_rate`);
   - drop and chest chances;
   - the difficulty curve;
   - the edge's look;
   - the 12 new powerups' numbers (POWERUPS section of the panel);
   - the Boss and Cursed ones, and how often a chest is cursed (`cursed_chest_chance`).
2. **Open question for the user:** beating the Blood Leviathan ends the run, so its Leviathan's
   Coil can't be used yet (only through its testing override). Should a beaten Leviathan drop its
   chest and let the run go on (endless, or a next stage)?
3. **Phase 9** (polish: juice, damage numbers, the full scoreboard, more perf). About 23 ms
   worst-case spikes are left in `torpedo_bench` with 16 torpedo stacks, 8 lightning stacks and
   1000 zombies. A real profiler is the next step there.
4. **Equipment** (D13): after phase 9. See §7c.
5. Phase 8 leftovers: D3's slow-mo for the picker; teammates' small health bars.
6. **Perf pass 2 (split-screen) is built**; see the next section. Awaiting the user's 3-player test.
7. **The playability pass: P1 is built (2026-10-18); P2 to P7 aren't.** P1 is weapon and tome
   slots, facets and milestones, XP on kill, pearls as currency and chest prices. See
   "Playability pass" before "Existing pieces to reuse" (its "P1 as built" note), and D17 to D27.
   It takes in phase 9's juice and damage numbers (its phase P3). Awaiting the user's play-test of
   P1 before P2.

### Perf pass 2: split-screen (fifth 2026-10-17 session, built)
The user found 3-player split-screen "extremely laggy". Measured with the new
`tests/split_bench.tscn` (a window bench, not a probe: `--players --count --apart --spread
--pearls --powers --profile`). The cause was the horde's GPU cost.
- **Every zombie was a ~50,000-triangle model.** The 9 eye and mouth spheres are about 4,200
  triangles each; the body is about 3,000. Each zombie was drawn twice (with the rot overlay) and
  had about 15 surfaces. Godot's LODs never kicked in, because a MultiMesh's LOD is picked from its
  bounds, which are the whole arena, so the camera is always inside them.
  - Fix: `SchoolLook.detail_meshes(family, error)` cuts fixed-detail meshes from the bake's own
    LODs. It also merges parts with equal materials, taking a fish from 17 surfaces to 6–8.
  - The Horde draws three distance bands (near, mid, far). They are panel settings under
    UNNATURAL > Performance: `lod_near_error` 0.004, `lod_mid_distance` 12 m, `lod_mid_error` 0.02,
    `lod_far_distance` 30 m, `lod_far_error` 0.1. The distances scale with the zombie's size.
  - A fish is now about 1.3k–4.7k triangles. Side-by-side shots at 2.5–45 m look the same as
    full detail.
- **Every view drew the union of what all the cameras saw.** Now, in split-screen
  (`per_view_horde`, on by default), each view has its own set of looks and eyes. Each set sits
  on its player's render layer (the chests' layers 17–20) and holds only what that camera sees.
- **Empty looks are hidden.** A MultiMesh with 0 instances still cost draw calls.
- **Draw loop:** the pose, transform and telegraph are worked out once per zombie, not once per
  view. `SchoolLook.pose_for()` is inlined, since it built an array on every call.

| 1920x1080, `split_bench` | Before | After |
|---|---|---|
| 1 player, 2,000 zombies | 7.9 ms (127 fps), GPU 7.6 ms | 1.6 ms, GPU 1.3 ms |
| 3 players, 2,000 zombies | 24.9 ms (40 fps), GPU 24.5 ms | 8.4 ms (119 fps), GPU 2.6 ms |
| 3 players, 3,000 zombies, bunched | — | 11.8 ms (85 fps) |
| 3 players, 800 zombies, powerups at 4 stacks | — | 8.1 ms (124 fps) |

At 3 players it's now CPU-bound:
- the GDScript draw loop: 2.9 ms at 2,000 zombies and 3 views;
- the render thread: about 1.8 ms;
- the horde step: 1.3 ms per 30 Hz step.

Scripts (the run, pearls, cameras, HUDs) are under 1 ms between them. Next levers if it's needed:
- port `_draw_horde` and `step_once` to the GDExtension (`native/` is still just the template);
- or rewrite far-band zombies at half rate.

Probes: `murk_probe` checks the per-view sets, their layers, the bands and the cut meshes.
Nature's schools still use the full bakes through `SchoolLook.meshes()`; `detail_meshes()` could
serve them too if Nature split-screen needs it.

### The first powerup batch (fourth 2026-10-17 session, built)
The answers (D9 to D16), as built:
- **D9.** Boost counts as accelerate for the follow cam's hold (`FollowCamera._throttle_held`).
- **D11.** `free_cam_invert_y` (UNNATURAL > Camera), on by default: down on the stick looks up.
- **D12.** A heart heals every player who's up, wherever they are. Online, each machine heals its
  own players. The HUD says "FOR THE TEAM" in co-op.
- **D15.** Bow Grow Bow was already common in `Powerup.INFO`; the §7b table now says so.

The 12 powerups (D14), each with its own POWERUPS group and a `*_stacks` testing override
(`PowerupSettings.STACKS` maps each id to its override):

| Powerup | Tier | Built as |
|---|---|---|
| Barnacle Plating, Hermit Shell, Fizzy Soda, Speedy Seahorse | common | `StatPowerup`: `stat_bonus()` goes on the player's `StatBlock.bonus`, so it works like level-up cards |
| Remora Buddy | common | remoras take turns nipping the nearest zombie; one worn per remora |
| Bubble Wrap | common | ready after `bubble_ready` s untouched (shows the bubble), then takes a hit (`UnnaturalRun.hurt` asks `blocks_hit`) |
| Pufferfish Spines | uncommon | on hurt: reflects a share at the toucher, and a spine burst |
| Jellyfish Halo | uncommon | jellies orbit in the world (one node), stinging each tick |
| Electric Eel | uncommon | a battery sends a shock ring (with a cooldown) |
| Depth Charges | rare | mines drop behind, arm, and blow on proximity or at the end of their life |
| Anglerfish Lure | rare | a decoy in `UnnaturalRun.decoys`, which the horde chases (`Horde.target_pull`), then it bursts |
| Tsunami Heart | legendary | a battery sends a wave along the heading that hits each zombie once (with a cooldown) |

New plumbing:
- `Powerup` hooks `on_hurt(amount, from)`, `blocks_hit(amount)` and `stat_bonus()`;
- `UnnaturalRun.hurt(fish, amount, from)` (from: the zombie whose touch it was);
- `PowerupFx` (a short ring or flash, at most 40 at once).

Known limits:
- Online, an Anglerfish decoy draws only the zombies on the machine that dropped it.
- Another player's powerup effects (mines, jellies, lures, waves) are local, like Greek Fire's.

Probes: the new `powerup_batch_probe` covers all 12. `drops_probe` gained the team heart and
now checks chest pools by tier, and `survivor_cam_probe` gained boost and invert-Y.

**Probes at hand-off:**
- The full suite passed. One timing check failed while other Godot runs were going at the same
  time, and passed on its own.
- `attack_probe` and `unnatural_combat_probe` now pin `difficulty_per_minute = 0`: they compare
  hp with each kind's base hp. Any new probe that does the same should pin it too.
- New this session:
  - `drops_probe` (Round 2);
  - `survivor_cam_probe` (both cameras, and the follow cam's swing);
  - `tests/unnatural_net.sh` with `unnatural_net_peer` (online: host, a laggy guest, a late joiner);
  - `tests/torpedo_bench.tscn` (a window bench, not a probe);
  - `tests/round2_shots.tscn` (screenshots to check by eye).
- Probe lessons:
  - A press from a timer callback is missed: press at the start of a frame.
  - `CoopSession._host_clock` means nothing in Unnatural.
  - Player ids are 64-bit: never put them in PackedInt32Array.

**Another session** asked to pick up the plan's remaining work after this one. It's working on
`planning_murk.md` and `tests/horde_bench.gd`.

### Boss and Cursed powerups (fourth 2026-10-17 session, built)
D13's two tiers. `Rarity.Tier` gained BOSS and CURSED. Level-up cards never roll them, and
neither do treasure chests (`pick_for_chest` stops at legendary).

**Chests** now have a kind (`TreasureChest.Kind`):
- treasure (gold);
- cursed (blood red);
- boss (steel blue, holding its boss's `item`).

A buried chest is cursed with `cursed_chest_chance` (10%; luck doesn't change it). The Drowned
Shark drops a boss chest with its Drowned Fin; it used to drop a treasure chest. The HUD's ping and
the minimap show each chest in its colour. Online, a chest's kind and item go with it, both when it
appears and in a late joiner's world.

A player's opened chests wait in a queue (`_chest_pending`: [kind, item] each). The chest's kind
decides its cards.

| Powerup | Tier | Does |
|---|---|---|
| Drowned Fin | boss (the Drowned Shark) | press boost when ready: a dash at `fin_dash_speed`, untouchable, each zombie passed takes `fin_damage` once; then `fin_cooldown` |
| Leviathan's Coil | boss (the Blood Leviathan) | `coil_segments` glowing coils trail the fish and hurt what they touch |
| Blood Moon Shard | cursed | +100% damage; +50% damage taken |
| Glass Coral | cursed | +100% damage; max hp halved |
| Siren's Song | cursed | +100% XP gain; the director's target x1.5 (`UnnaturalRun.horde_scale`) |
| Abyssal Hunger | cursed | a kill heals 3% of max hp; lose 2% a second (stops at 1 hp unless `hunger_can_kill`) |
| Sunken Idol | cursed | one more pick from every chest (the cards left re-offered); each stage event takes a stack of a random other powerup you earned (the HUD says which) |

Each has a POWERUPS group and a testing override, like the rest. Every number is a setting.

Known limits:
- The Leviathan's Coil has no drop yet (see the open question in the Handoff).
- Online, the host's director counts only the host's own Siren's Song, since a guest's powerups
  aren't sent.

Probes: the new `boss_cursed_probe` covers all of it. `unnatural_net` now checks chest kinds, and
`powerup_batch_probe` counts 23 powerups.

### Round 2: the second play-test (2026-10-17, built)
The user tried the two cameras: "an improvement". Their list, and how each gets built:

1. **Follow cam.**
   - The feedback: "still seems to favour a particular direction". After accelerate or reverse is
     let go, it should swing round into place behind the fish.
   - Found:
     - It eased toward the way the fish *moves* (its velocity), not where it *faces*. A coasting
       fish that has turned keeps its old velocity, so the camera settled off to one side.
     - Swinging round from dead behind always went the same way round (a fixed nudge).
   - Build:
     - Let go, it turns its yaw behind the fish's facing, the shorter way round. From dead behind
       it goes the way the fish is turning.
     - It turns at its own rate (`camera_swing_rate`), on top of `camera_turn_rate` while swimming.
     - Its climb still follows `camera_climb`.
2. **Pearls.**
   - They never expire (`pearl_lifetime` is gone from Unnatural).
   - Every kill already drops one. Past the cap, a new drop merges into the *nearest* pearl (which
     grows), not the oldest, so you can see where your kills' XP went.
   - Pearls stay shared, one pickup each (user: "everybody gets XP anyway").
3. **Chests, each player's own.**
   - Every chest is there for every player. Each player opens it for themselves and gets their own
     pick. Once you've opened it, it's gone from *your* view, and still there for the others.
   - Split-screen: each player's camera has its own render layer (cull mask), and a chest shows
     only on the layers of the players who haven't opened it.
   - Online: a chest remembers who has opened it (by player id). Opening it no longer opens it for
     everyone.
4. **Chests from kills.**
   - Each kill has `chest_drop_chance` of dropping a chest, raised by the killer's luck
     (`chest_drop_luck`). The host rolls it and sends it over.
   - The chest sinks to the seabed where the zombie died.
5. **Luck and chests.**
   - A chest's powerup rolls a rarity with the opener's luck (as the level-up cards do).
   - Powerups get a rarity each: Bow Grow Bow is common; Greek Fire and Chain Lightning uncommon;
     Torpedo Launcher rare.
   - A chest offers powerups of its rolled rarity. With fewer than 3 of that rarity, it fills up
     from the tiers below.
6. **Drops from kills** (shared, one pickup, each a glowing token):
   - **Heart** (rare, `heart_chance`): +50% of the picker's max hp (`heart_heal`).
   - **Magnet** (rarer, `magnet_chance`): every pearl out flies to the picker.
   - **Hourglass** (rare, `hourglass_chance`): every zombie stops dead for `hourglass_time` (15 s),
     tinted icy. They can still be hit. Bosses go on (`hourglass_bosses` off).
   - Online: the host rolls and sends drops. A guest claims a pickup the way it claims a pearl,
     and the effect plays on every machine.
7. **Arena edge.**
   - A ring of tall rock outcrops and thick kelp forest on `arena_radius`, plus a faint red wall
     of light, so the edge reads from far off. The edge push stays as it is.
   - Settings: `edge_rocks`, `edge_kelp`, `edge_height`.
8. **Every powerup is worn**, as the Bow is, and grows with its stacks:
   - Greek Fire: a lantern on the tail.
   - Chain Lightning: a crackling coil antenna.
   - Torpedo Launcher: twin tubes on the flanks.
9. **Difficulty over time.**
   - A difficulty level grows with the minutes (`difficulty_per_minute`). Each zombie keeps the
     level it was spawned at.
   - Per level: hp +`difficulty_hp`, damage +`difficulty_damage`, speed +`difficulty_speed`, and
     size +`difficulty_size`, up to `difficulty_size_max`.
   - The director line shows the level. Online, each spawn carries its level.
10. **Performance with a big Torpedo Launcher.**
    - Measure first: a bench in the Test Tank with high torpedo stacks.
    - Likely costs:
      - one node, mesh and material per torpedo;
      - sorting every zombie within 40 m on each launch;
      - an `Explosion` per blast;
      - proc chains: blasts start lightning.
    - Fix with:
      - pooled torpedoes drawn by one MultiMesh;
      - a capped number in flight;
      - a cheap nearest pick;
      - blasts batched per frame.
11. **Your stats on the scoreboard.** Beside the board: your fish, attack, level, max hp, every stat
    that isn't 0 (from StatBlock), and your powerups with their stacks.
12. **Powerups.** The brainstorm is below (§7b); the user picks which to build later.

How it went, and where the build differs from the list above:
- **Follow cam:** as planned (`FollowCamera._turn_behind`, `camera_swing_rate`).
- **Pearls:** as planned. Also:
  - pearls share one mesh and material (the aura's strength is an instance uniform);
  - a pearl with no fish near rests between looks (`Pearl.SLEEP_TICKS`);
  - `max_pearls` went up to 600.
- **Chests:**
  - Chests sink at 8 m/s.
  - Each kill's chest chance is `chest_drop_chance` (0.006), and the drops' chances use
    `chest_drop_luck` too.
  - A chest everyone has opened vanishes, but keeps its place in `chests` (online indices).
- **The online probe found a bug**, now fixed: player ids (peer x 100 + slot) don't fit
  PackedInt32Array, so the chest openers in a late joiner's world are sent as plain ints.
  - Also: chest opens whose player's puppet hadn't arrived yet now wait for it
    (`UnnaturalNet._unresolved`).
- **Drops:** the heart's chance is 0.004, the magnet's 0.0015, the hourglass's 0.002 (an elite's x5).
  - While frozen, zombies don't steer, lunge or bite, and their tails stop.
  - The HUD notes each drop that's taken.
- **The arena's edge:** 90 outcrops (3 rocks each) and 900 kelp blades on the rim, plus a red
  glow rising from the seabed (its shader works from the mesh's height).
- **Worn powerups:** the `Powerup.make_worn()` / `wear()` / `take_off()` base. Taking a look off
  detaches it at once. That also fixed `powerup_probe`'s flaky "bow off" check: `queue_free` only
  frees at the frame's end, and a busy headless run steps several ticks in one frame.
- **Difficulty:** the defaults are 0.5 levels a minute. Per level: +30% hp, +15% damage, +4% speed
  and +8% size, up to 2x the size. At 10 minutes that's 2.5x the hp and 1.4x the size.
- **Performance**, measured with `tests/torpedo_bench.tscn` (1920x1080, 1000 zombies, 16 torpedo
  stacks, 8 lightning stacks):

  | | Before | After |
  |---|---|---|
  | Physics per frame | 50 ms | 10 ms |
  | Worst frame | 125–167 ms | about 23 ms |

  With no powerups, the worst frame is 9.4 ms.
  - The torpedoes:
    - became one pooled MultiMesh swarm (`TorpedoSwarm`), at most `torpedo_max` (48) flying;
    - re-target near themselves, now and then;
    - take a nearest-k pick at launch instead of a sort;
    - show at most `torpedo_fx_rate` (10) blasts a second.
  - Chain Lightning:
    - is capped at `lightning_max_rate` (30) strikes a second;
    - each jump looks close first and widens only when it finds nothing;
    - shows at most 40 bolts at once.
  - Left over: about 23 ms worst-case spikes in that extreme case. A real profiler would find
    the rest.
- **Also fixed:** Greek Fire's "erase a freed object from a TypedArray" error spam.
- **The controls hint** says "Y: follow/free cam" in Unnatural.

### Phase 7: the stage
- **StageTimeline** (UNNATURAL > Stage): the ring at 2:30, the Drowned Shark at 5:00, the stampede
  at 7:30, the tide at 9:30 and the Blood Leviathan at 10:00 (0 skips an event).
  - Each is warned `event_warning` s ahead with a splash, and the director is hushed for
    `event_hush` s before it.
  - The HUD shows the next event under the kills.
- **Bosses** are nodes (`bosses/boss.gd`), and their bodies are **Horde proxies**
  (`Horde.spawn_proxy`: undying, unsteered, undrawn). So every attack, battery and powerup hits a
  boss with no new code, and `UnnaturalRun.hit()` hands the damage to `Boss.take()`. A boss's
  contact damage is its own.
- **Drowned Shark** (UNNATURAL > Drowned Shark): the Shark model x5, rotten, with red eyes.
  - It hunts the nearest player, glows red, then charges. Every so often it calls a ring of
    sardines.
  - Beaten, it drops a chest and a big XP pearl.
- **Blood Leviathan** (UNNATURAL > Blood Leviathan): a serpent of segments trailing the head.
  - Phases: CIRCLE (coils round you, dives through), SPIT (from 2/3 hp: fans of blood bolts) and
    FURY (under 1/3 hp: charges again and again).
  - When it comes, it clears the zombies further than `boss_cleanup` from every player.
  - Left `leviathan_enrage` s, it enrages, and the director escalates (`enrage_scale` on its
    target).
  - Beaten: STAGE COMPLETE, and the run's over (won).
- The boss bar sits under the XP bar (name, hp, ENRAGED).

### Phase 8: co-op
- **Split-screen works.** LocalCoop takes an UnnaturalRun too. Each player gets their own survivor
  cam and UnnaturalHud (`PlayerSlot.mode_hud`), plus their own attack, twist, stats and cards. One
  team level; cards don't pause in co-op.
- **Down and revive (D7):** a teammate staying within `revive_range` for `revive_time` revives you
  at `revive_hp`. The HUD shows DOWN markers with revive rings. The run's over when everyone's
  down.
- **Online:** built and probed (`tests/unnatural_net.sh`). Where it differs from §9: spawns go out
  as each frame's batch of zombies (net id, kind, where), not pack seeds. That's simpler and still
  small. A guest's zombie copies never die until the host says.
- Not done: D3's slow-mo for the picker (they're untouchable and unseen, but not slowed);
  teammates' small health bars on their name plates.

The same session as the plan added the Hunt-style scoreboard to Nature (§12). That change is done,
separate from this plan, and awaiting manual test.

### Phase 0: the bench (`tests/horde_bench.tscn`)
GDScript Horde (struct of arrays, hash grid, MultiMesh per kind per tail pose), all zombies chasing a
parked player, in a 1920x1080 window on the dev machine:

| Zombies | Frame | Horde step (one 30 Hz step) | Horde draw (per frame) |
|---|---|---|---|
| 500 | 4.0 ms (250 fps) | 0.62 ms | 0.32 ms |
| 1,000 | 7.0 ms (144 fps) | 1.16 ms | 0.63 ms |
| 2,000 | 12.8 ms (78 fps) | 2.29 ms | 1.27 ms |
| 5,000 | 30.0 ms (33 fps) | 5.88 ms | 3.12 ms |

**Decision: no C++ port yet.** The 2,000-at-60-fps target is met in GDScript. At 5,000 the script
is about 6 ms of the 30 ms; the rest is rendering (about 480 draw calls: every baked look has a
surface per model part, times 15 looks, times the overlay pass). The stretch goal needs fewer
surfaces per look (merge by material) or simpler far looks before it needs C++.

### Phase 1: the bones
Files (all new unless marked):
- `scripts/unnatural/`: `unnatural_run.gd` (UnnaturalRun), `unnatural_settings.gd`
  (panel section UNNATURAL), `horde.gd`, `horde_grid.gd`, `enemy_kind.gd` (the five kinds, as
  data), `evil_director.gd` (the time curve only), `fish_health.gd`, `levels.gd`,
  `attacks/ghost_bite.gd`, `blood_moon.gd`, `seabed.gd`, `unnatural_hud.gd`
- `shaders/zombie_overlay.gdshader` (rot, red head glow, hit flash, death fade, elite glow),
  `shaders/kelp.gdshader`
- Changed: `main.gd` (the mode), `debug_panel.gd` (the section), `ocean.gd` (fog base helpers),
  `pearl.gd` (`value`, `set_light()`), `fish_controller.gd` (`set_model_visible()`)
- Probes: `horde_probe`, `unnatural_combat_probe`; `horde_bench`, `unnatural_shots` (by eye)

Where the build differs from the plan, or goes beyond phase 1:
- **Every fish uses the Shark's ghost bite** until phase 6 gives the others theirs.
- **The XP bar is across the top**, not the bottom: the controls hint and the stride meter have the
  bottom.
- **The director already runs its time curve** (target alive, pack size, kind mix by unlock
  minute) so the run has pressure. Intensity, relief, elites and the timeline are still phase 2.
- **Relocation (the leash) is in**, at 1 Hz. The far-LOD step is in too.
- **Separation** checks a rotating sample of up to 8 others in the zombie's own grid bucket per
  step, not the 27 neighbouring cells; it was the cheap way to stop the horde piling into one
  point. Tune `separation` / `separation_strength` if crowds look too tight.
- **Red eyes** are a red glow over the front third of each zombie plus a red rim, not a true eye
  mask. Per-instance tinting rides on `INSTANCE_CUSTOM`.
- **Damage numbers and multis/sprees → bonus XP (D6)** aren't in yet (phase 9 / with the stat
  block).
- **Co-op isn't wired yet** (phase 8): split-screen joining isn't offered in Unnatural. The run is
  written for `players` 1–4, with an `authority`. A downed co-op player just stays down (no revive
  yet). The run ends when everyone's down.
- **XP pearls** reuse `Pearl` with their lights off by default (`pearl_lights`); past
  `max_pearls`, a new drop adds its XP to the oldest pearl. Pearls don't merge by distance yet.

Open for the manual test:
- the red: fog, ambient and sky strength (`blood_moon`), and the rot / eye glow (`rot`, `eye_glow`);
- the bite's size, damage and cooldown (GHOST BITE group);
- whether contact damage and i-frames feel fair while ramming (BATTERIES group);
- the director's ramp (`alive_per_minute`, `alive_curve`, `spawn_interval`);
- the arena size (D1) and the edge push.

### After the first test (2026-10-17): the survivor cam
The user found the camera "fixed and awkward". The chase camera turned with the fish's facing, so
every stride sweep swung the view, and it sat 2.7 m behind. Unnatural now steadies it
(`FollowCamera.steady_heading`): it follows the way the fish swims, smoothed, with the climb damped,
4.5 m further back, 2 m higher and tilted 10 degrees further down. It's all in UNNATURAL > Camera
(`steady_camera` off gives the old view back). The tuning panel's own camera values are untouched.

### Phase 2: scale and the director
- **Behaviours** (Horde): sardines weave in, rays lead the player and sweep across their path,
  swordfish stalk to `lunge_range`, telegraph (a pulsing red glow), lunge and rest, boxfish are slow
  tanks that **burst into a hurting cloud** (`BurstCloud`) when they die.
- **Elites**: `elite_chance + elite_per_minute * minutes` per zombie (bigger, 5x hp, glowing, a 5x XP
  pearl, double contact damage).
- **The director** (`EvilDirector`): pressure (x0.75 to x1.6 on the target) from the kill rate over
  10 s and intensity; intensity is the share of max hp lost recently, and reaching
  `relief_intensity` gives a breather of `relief_time` with no new packs. `show_director` shows
  it all on the HUD. Sardine packs come twice as big.
- No C++ port (phase 0's call).

### Phase 3: level-ups
- `StatBlock` (18 stats; the card pool leaves out projectile count, projectile speed and duration
  until something uses them), signature stats per fish, `Rarity` (weights x (1 + luck) ^ tier), and
  `LevelUpCards` (stick / A / keys 1-3 / mouse).
- Solo, the cards pause the game (`cards_pause`); in co-op the picker is untouchable and unseen
  instead (D3). Several levels at once queue their picks.
- Swim speed and stride power work through `FishController.speed_scale` / `stride_scale`, not the
  tuning, so presets never pick up a run's upgrades.
- **The plan's luck example was relative to common**: luck 0.5 multiplies epic by 3.4 and legendary
  by 5.1 against common. After normalising the shares, epic goes from 4% to 10% and legendary from
  1% to 3.5%.

### Phase 4: the Test Tank
- A mode (`TEST_TANK`): 55 immortal dummies (a cluster 22 m ahead, lines at 10, 20, 40 m), a DPS
  readout per source (damage, DPS over 5 s and overall, hits, would-be kills), R resets.
- UNNATURAL > Test Tank: dummy hp, slow walkers, `tank_horde` (chasers kept out; the in-game perf
  bench), contact damage on/off, the level, and every stat.

### Phase 5: chests and powerups
- `TreasureChest`: 10 buried at the start, one more each minute (up to 16), glow, bubbles, HUD pings
  within 35 m (at the screen edge if off screen). Opened by battering, or holding still within 3 m
  for 2 s (a ring fills; untouchable and unseen meanwhile, D3). It offers 3 different powerups;
  picking one adds a stack. Picks queue with level cards; solo, they pause too.
- `Powerups` per player, `Powerup` hooks (on_hit, on_kill, on_battery, on_tick, on_stride), proc
  coefficients and chains in `UnnaturalRun.hit()`.
- Greek Fire Trail, Chain Lightning, Torpedo Launcher, Bow Grow Bow, as §7 says, all numbers in the
  panel's new **POWERUPS** section, each with a `stacks` override for testing. Bow Grow Bow works
  through `FishController.bow_scale`; the bite grows with it.
- Icons with stacks down the left of the HUD.

Probes added: `evil_director_probe` (the replay director already had `director_probe`),
`levels_probe`, `test_tank_probe`, `powerup_probe`; `horde_probe` and `unnatural_combat_probe`
grew behaviours and burst clouds.

Open for the next test:
- the survivor cam's distance, height, tilt and turn rate;
- the director's pressure and breathers (turn on `show_director`);
- elite rate, lunges (telegraph long enough to dodge?), burst clouds;
- the card pool and rarity weights; whether solo cards should pause;
- chest count and placement, open time, and each powerup's numbers (Test Tank + POWERUPS).

### Phase 6: every fish unique
Every fish fires its own auto-attack (`attacks/`, all on a `FishAttack` base) and swims with its own
twist (`Traversal`):

| Fish | Attack (source) | How it plays | Twist |
|---|---|---|---|
| Clownfish | Anemone Sting (`sting`) | a pulse all round, `sting_radius` (never under `sting_over_bow` x the bow wave), hits everything in it | Nimble: turns `nimble_turn` x as sharply |
| Shark | Ghost Bite (`bite`) | unchanged | Frenzy: +`frenzy_per_kill` swim speed per kill, up to `frenzy_max`, held `frenzy_time` s, then fades |
| String Ray | Shock Lash (`lash`) | whips the nearest zombie any way round within `lash_range`, arcs on `lash_arcs` (+1 per Projectiles) | Glide: keeps `glide_drag` of the water's drag |
| Swordfish | Bill Thrust (`thrust`) | a piercing spear at the nearest zombie ahead (+1 spear per Projectiles, fanned) | Dash: a dodge adds `dash_speed`, untouchable for `dash_iframes` |
| Butterfly Koi | Bubble Volley (`bubbles`) | `bubble_count` homing bubbles (+Projectiles) that pop on the first zombie | Leap: a jump also leaps up; it splashes down (`leap_damage` in `leap_radius`, source `splash`) as it tops out |
| Boxfish | Spine Burst (`spines`) | `spine_count` spines (+4 per Projectiles), most round its level, the rest all round | Armoured: takes `armour_taken` of damage, swims at `armour_speed` |

- **Panel:** UNNATURAL > Attacks has `fish_attack` (give every fish one attack, live: for testing),
  one group per attack, and Twists (`twists` off: every fish swims the same).
- **Stats:** Area scales every attack's size; Attack Speed its cooldown. **Projectiles** and
  **Projectile Speed** now do something, and their cards are offered only to fish whose attack uses
  them (`FishAttack.uses_stat`): the Ray (count), the Swordfish, Koi and Boxfish (both). The
  Swordfish's signature stat (Projectile Speed) now counts.
- **Proc coefficients:** attacks that hit many at once start powerups less often: sting and bubbles
  0.6, spines 0.4, a lash's arcs 0.5 (bite, thrust and the lash's first hit 1.0).
- **Projectiles** (`ProjectileSwarm`): arrays drawn with one MultiMesh per attack, no node each.
- **FishController** gained `turn_scale` and `drag_scale` (like `speed_scale`: not tuning, never
  saved).
- The scoreboard's BITE column is now **ATTACK** (any fish's attack).
- **The Koi's leap doesn't breach a real surface:** the Ocean has no water surface physics, so it's a
  jump-triggered leap up with a splash as it tops out. A true breach would need surface physics.
- Probe: `attack_probe` (every attack, the override, projectile cards, every twist). The bite's
  probes pin `fish_attack` to Ghost Bite and turn twists off.

Open for the next test:
- each attack's feel and numbers (Test Tank, UNNATURAL > each attack's group);
- the visuals: the sting's ring, the lash's crack, spears, bubbles, spines (all placeholders, additive);
- the twists' strength, especially Glide (drag) and Frenzy;
- whether the Koi's leap should be on a jump or a double jump.

## Playability pass (planned 2026-10-18, not built)
This comes from `brainstorm_playability.md`, with the user's answers in its §1.10 (D17 to D27
below). **The goal:** today every powerup and stat stacks without a ceiling, so power multiplies
far past the difficulty curve and costs frames. Runs should instead **lock in** a build that then
grows deeper, not wider. Every number below is a panel setting with a wide range ([flexible
tuning]). Naming follows the house rules: batteries, Battered Fish, Fish Fry.

The phases run in the brainstorm's order (D27). Each one ends with probes passing, a build and the
user's play-test.

### P1. Weapons, Tomes and Items, XP on kill, pearls as currency
**P1a. The three kinds.**

| Kind | What it is | From | Limit |
|---|---|---|---|
| **Weapon** | Does damage by itself, on its own timer | Level-up cards | `weapon_slots` **2**; the fish's attack is one of them (D17) |
| **Tome** | A global stat that levels up | Level-up cards | `tome_slots` **2** (D17) |
| **Item** | Procs, on-hurt, on-battery, utility, small stats | Chests (also boss and cursed chests) | No slots; stacking flattens out in P4 |

More slots come from meta-progression (P6). Until then, the Test Tank and the panel set them
(range 1 to 8 each).

**Where today's powerups go** (D18 to D20):
- **Weapons:** the fish's attack (it fills a slot from the start and can't be removed), Greek Fire,
  Jellyfish Halo, Depth Charges, Remora Buddy, and Leviathan's Coil (a boss weapon; see question 1).
- **Items:** everything else. That's Torpedo Launcher, Chain Lightning, Electric Eel, Tsunami
  Heart, Pufferfish Spines, Bubble Wrap, Anglerfish Lure and Bow Grow Bow. It's also Barnacle
  Plating, Hermit Shell, Fizzy Soda, Speedy Seahorse, Drowned Fin and the five cursed items.
- Chests offer **items only**. Weapons only come from cards, except the boss weapon.

**Tomes** (D21): the 18 stats fold into 12 tomes. A tome card adds one step of each of its stats,
multiplied by the card's rarity, as stat cards do now.

| Tome | Stats |
|---|---|
| Tome of Teeth | damage |
| Tome of Tides | attack speed |
| Tome of the Reef | area |
| Tome of Schools | projectile count |
| Tome of Currents | projectile speed, knockback |
| Tome of the Kill | crit chance, crit damage |
| Tome of Fins | swim speed, stride power |
| Tome of the Ram | battery damage |
| Tome of the Shell | max hp, armour, regen |
| Tome of Pearls | XP gain, pearl drop chance (new stat `pearl_chance`), pickup range (D22) |
| Tome of Fortune | luck |
| Tome of Ages | duration |

The fish's **signature stat** keeps its free +1 per level and needs no slot. The tomes sit on top
of `StatBlock`, so every stat read stays as it is.

**P1b. Level-up cards.** There are still three cards. Each one is drawn from:
1. upgrade a weapon you have (weight 40);
2. upgrade a tome you have (30);
3. a new weapon, only while a weapon slot is free (15);
4. a new tome, only while a tome slot is free (15).

The weights are settings. Once the slots are full, every card is an upgrade. With 2 + 2 slots that
happens within the first few levels, which is the point (D17). When a weapon or tome reaches its
cap (`weapon_max_level` and `tome_max_level`, 20 and 99 since the P1 play-test), its cards stop showing. If fewer than three
real options are left, the rest are **fallback cards**: a pearl purse or a team heal.

**The card says what you get and what you have** (§4 of the brainstorm). For example: *"Greek Fire
Lv 4 → 5: +20% burn damage, +1.5 s patch life"*, with "Weapons 2/2 · Tomes 1/2" underneath.

**P1c. Partial weapon upgrades (facets).** Each weapon has 4 or 5 facets. A card rolls which facets
it improves. Its rarity decides how many facets and by how much: Common 1 ×1, Uncommon 1 ×1.5,
Rare 2 ×1.5, Epic 2 ×2, Legendary 3 ×2.5 (a settings table). Each facet's base and step are in
`PowerupSettings`, next to that weapon's other numbers.

| Weapon | Facets |
|---|---|
| Greek Fire | burn damage, patch life, patch radius, patch spacing, max patches |
| Jellyfish Halo | jelly count, sting damage, orbit radius, orbit speed, sting rate |
| Depth Charges | blast damage, blast radius, drop rate, mines out at once, arm time |
| Remora Buddy | remora count, bite damage, bite rate, reach |
| Leviathan's Coil | segment count, segment damage, segment size, hit rate |
| Ghost Bite (Shark) | damage, jaw size, bite rate, knockback, bleed |
| Anemone Sting (Clownfish) | damage, pulse radius, pulse rate, slow on hit |
| Shock Lash (Ray) | damage, lash reach, lash rate, arc jumps |
| Bill Thrust (Swordfish) | damage, spear speed, thrust rate, pierce count |
| Bubble Volley (Koi) | damage, bubbles per volley, volley rate, homing turn rate |
| Spine Burst (Boxfish) | damage, spine count, burst rate, spine range |

Weapons lose their "stacks". The panel's stacks override becomes a **level** override plus a
per-facet override, for the Test Tank.

**P1d. Milestones.** At Lv 5 and Lv 10 each weapon gains a new behaviour, so it feels stronger,
not just bigger. First drafts:
- Greek Fire: 5, a burning zombie spreads fire to the patches it touches; 10, the trail fans out wide.
- Jellyfish Halo: 5, jellies leave a short sting trail; 10, they pulse outward every few seconds.
- Depth Charges: 5, blasts pull zombies in before they go off; 10, one charge in four is a cluster
  bomb.
- Remora Buddy: 5, remoras latch on for a moment; 10, a kill splits a remora into two for a few
  seconds.
- Ghost Bite: 5, a second set of jaws snaps behind you; 10, jaws on both sides.
- The other five fish attacks get theirs while P1 is being built, and go to the user with the build.

**P1e. XP on kill; pearls become the currency** (D22, D23). This applies to **Unnatural only**.
Nature's pearls don't change: `UnnaturalSettings` gets its own pearl group, and Nature keeps
`NatureSettings`.
- **XP is credited on the kill**, with no pickup. In co-op it goes to the shared team level, and the
  authority credits it when it confirms the kill (as now, but without the pearl step). The XP sizes
  stay: the kind's `xp`, ×`ELITE_XP` for elites, `shark_xp` for bosses.
- **Pearls are the currency.** They drop **by chance**: `pearl_drop_chance` 0.12 for a zombie, ×
  `pearl_chance`. Elites always drop one, worth 3. A boss drops 25. That keeps the map clear (the
  user doesn't want more pickups around it).
  - `drop_pearl` and the net claims (`pearl_claimed` and `pearl_taken`) carry a pearl's value as
    currency, not XP.
  - `max_pearls` merging stays.
  - The Magnet pickup pulls them in.
- **Chests cost pearls** (`chest_cost_on`, on by default; off gives free chests to compare). The
  price is `chest_price_base` (8) × (1 + `chest_price_growth` (0.25) × minutes). A cursed chest
  costs ×1.5; a boss chest is free.
  - Opening works as now (battering, or holding still). Short of pearls, the chest shows its price
    and stays shut.
  - The price shows over every chest in range, and the purse sits next to the level on the HUD.
- **The scoreboard's PEARLS column** becomes pearls collected; it no longer counts XP.

**P1f. HUD.** Two slot rows (weapons and tomes), each with level pips and empty slots outlined. An
item strip with stack counts (the current powerup icons) sits under them. The pearl purse goes by
the XP bar.

**P1g. Code (rough).**
- `Powerup` gains a `kind` (WEAPON or ITEM). Weapons gain `level` and `facets`. A new
  `powerups/weapon.gd` base holds the facet rolls and milestones.
- The fish attacks (`attacks/fish_attack.gd`) read their numbers from facets.
- A new `tome.gd` maps tomes to `StatBlock` ids. `StatBlock.pool()` gives way to the four card
  types.
- `LevelUpCards` draws the facet lines and the slot line.
- `Powerup.pick_for_chest` filters to items.
- `UnnaturalSettings` gets the slots, caps, card weights, rarity facet table and pearl and chest
  prices.
- `unnatural_run.gd` gets XP on kill, the purse and chest prices. `treasure_chest.gd` gets the price.
- `coop_session.gd` carries the purse, weapon levels and tomes in the world snapshot.

### P2. The run simulator and balance tooling (§8)
- **`tests/run_sim.tscn`:** a bot fish that steers away from the horde, batters when it can and
  picks cards (random or greedy). Every minute it logs:
  - its damage per second;
  - the time to kill an average zombie;
  - damage taken;
  - its level, slots and pearls;
  - when it dies.
  It runs headless at speed. `--runs 50` gives a power curve to set against the difficulty curve.
- **A target curve:** the time to kill an average zombie stays between 0.3 and 1 s all run
  (settings). A build outside it is reported as a balance bug.
- **Run logs** at the end of every real run, in `user://run_logs/`: picks, damage by source (the
  existing `by_source`), pearls, chests and the cause of death. That way play-tests come back with
  data.
- **Test Tank presets:** one button for "all slots full, Lv 10" and one for "all slots full, Lv 5",
  for power and frame benchmarks.

### P3. Feel and readability (§2; takes in phase 9's juice) (built 2026-10-23: "P3 as built")
- **Damage numbers** at scale (phase 9's plan). Crits are bigger and coloured, and a
  `damage_numbers_min` setting shows only big hits.
- **Hit flash and kill pop:** a one-frame white flash through a MultiMesh instance uniform, and a
  small burst on a kill.
- **A target marker** on what each auto-attack is aiming at.
- **Threat arrows** at the screen edge for elites and bosses out of view, and the boss health bar.
- **Telegraphs:** lunges and boss attacks glow before they land.
- **Hurt feedback:** a red vignette pulse and a low thud. Low hp adds a heartbeat.
- **Pickup clarity:** each drop has its own silhouette and colour, readable through the murk.
- **Camera:** it pulls out a little as the horde thickens or area grows (`camera_crowd_pull`).
- **Depth assist** (`depth_assist`, from 0 = off to strong): the horde drifts toward the player's
  depth, and auto-aim favours zombies near it.

### P4. Choice tools and limiters (§1.6)
- **Item stacking curves:** the first stack is strong, and later ones add less (per item, e.g.
  100%, 60%, 40%...). Chances (crit, procs, blocks) go hyperbolic. Cooldowns get a floor
  (`min_cooldown`), and area gets a soft cap.
- **Effect caps as the visible rule:** "at most N in the water at once" (`torpedo_max`,
  `lightning_max_rate`, and the like for every weapon).
- **Proc coefficients for weapons:** low for weapons that hit often. Greek Fire's ticks start at 0.
- **Rarer chests later:** the chest drop chance and the buried count fall with stage time.
- **Weapon card frequency** drops as weapons level, so tomes get a turn.
- **Rerolls, skips and banishes** are built here, but a run starts with **0 of each** (D25). They
  come from meta (P6); until then the panel can give them. A banished weapon, tome or item leaves
  the pool for the rest of the run.

### P5. Pacing (§3)
- **Sunken shrines:** a few per stage. They're fixed spots on the seabed, not pickups.
  - *Tide:* hold its ring for 10 s while the horde comes, and win a chest.
  - *Chance:* pay pearls for a chance at an item.
  - *Deep:* the stage gets harder (more elites), but bosses drop two chests.
  - *Pearls:* a magnet burst that pulls every pearl to the team.
- **Elite modifiers** (RoR2 style):
  - Burning: leaves fire behind.
  - Electric: shocks on death.
  - Frozen: slows you on hit.
  - Bloated: bursts into small ones.
  Elites drop chests more often.
- **Stage objectives and a next stage.** A beaten Blood Leviathan drops its boss chest (so
  Leviathan's Coil can be earned) and opens the way on. The way on leads to a next stage, with a new
  seabed and harder zombies, or you can stay for endless. This answers the Handoff's open question
  (item 2).
- **Quiet moments:** a few seconds between waves, from the director's swarm ends.
- **Run lengths:** short (10 min), standard and endless, picked before the run.

### P6. Agency and meta-progression (§4, §5)
**In a run:**
- **A logbook:** every weapon, tome and item you've found, with its real numbers.
- **Pause tooltips:** each item's stacks and what it's adding right now.
- **A damage meter** per source on the scoreboard (Greek Fire 34%, Ghost Bite 28%...).
- **The hermit crab trader:** a rare visitor who swaps one item for another of the same tier.
- **A starting choice:** pick one of two starter items or tomes (once unlocked).

**Between runs** (a save in `user://unnatural_meta.cfg`):
- **Shells:** earned per run (time, kills, bosses).
- **The shop (Shells):** rerolls, skips, and small permanent upgrades, kept small so skill still
  matters most (D26).
- **Challenges:** they unlock the 3rd and 4th weapon and tome slots, banishes, and items. Examples:
  "Reach Lv 20", "Beat the Leviathan", "Batter 500 zombies in one run" (D26). A smaller starting
  item pool keeps early runs easy to learn.
- **Fish passives:** a small one for each fish, besides its attack and twist.
- **Difficulty tiers:** Calm, Swell, Storm and Blood Tide. Higher ones unlock as you win, and they
  scale the difficulty curve and the director.

### P7. Co-op extras, batteries, and every mode (§6, §7, §9)
**Co-op:**
- **A ping** (a stick click or the D-pad): marks a chest, a drop or a zombie for the team.
- **Team items:** a Cleaner Wrasse that heals whoever's close, and a Pilot Fish that gives speed.
- **Revive juice:** the revive ring fills visibly. A revived player gets a second of being
  untouchable, and a shock ring.
- **Downed players** steer a small ghost that collects **pearls** (now the currency).
- **The picker's slow-mo** (D3, a phase 8 leftover), and teammates' small health bars.

**Batteries:**
- More items that fire on battery.
- A battery refunds part of every weapon's cooldown (`battery_cooldown_refund`).
- **Fish Fry** gives a short power spike: a few seconds of double fire rate.
- **The Battered Fish count** on Unnatural's HUD, with streak rewards.

**Every mode (§9):**
- Hunt and Nature get the damage meter and logbook ideas, and Fish Fry as a power spike.
- A short "how to play" card per mode, shown on first start.
- A controls reminder when the pause menu opens.

### Later
- **Evolutions** (D24): a max-level weapon plus a set tome evolves into a stronger weapon from a
  boss chest. Examples: Greek Fire + Tome of Ages → Sea of Flame; Halo + Reef → Man o' War; Depth
  Charges + Schools → Minefield; Remora + Teeth → Lamprey Pack.
  - P1's weapon data keeps a slot for an `evolves_with` and an `evolved_id`, so they can be added
    without a rework.
- **Equipment** (§7c), with Drowned Fin a likely first candidate (D20).

### Probes
- **`slots_probe`** (P1):
  - the card pools follow the slot state (no new weapon with full slots, capped ones gone, fallback
    cards when needed);
  - facet rolls match the rarity table over 10,000 rolls;
  - milestones switch on at Lv 5 and 10;
  - tomes add the right `StatBlock` steps;
  - chests give items only.
- **`pearl_currency_probe`** (P1):
  - XP lands on the kill, with no pearl;
  - the pearl drop rate matches `pearl_drop_chance` × `pearl_chance`;
  - chest prices follow the formula, and a chest won't open short of pearls;
  - Nature's pearls are unchanged.
- **`coop_net_peer`** additions (P1): the purse, weapon levels and tomes agree between host and
  guest, and a late joiner gets them.
- **`run_sim`** (P2): reported, not pass/fail. It becomes the gate for the numbers of every later
  phase.
- **`limits_probe`** (P4):
  - stacking curves and hyperbolic chances never pass their caps;
  - banished entries never show;
  - rerolls and skips start at 0.
- **`stage_probe`** additions (P5): a beaten Leviathan drops its chest and opens the next stage;
  shrines pay out.
- **`meta_probe`** (P6): Shells add up, unlocks persist across a save and load, and challenges fire.

### P1 as built (2026-10-18)
The open questions were built with defaults, for the user to confirm or change:
1. **Leviathan's Coil with full weapon slots:** the swap is offered (a card per held weapon, and
   "Keep yours"). It arrives at `coil_arrive_level` (5). It can't drop yet: the Leviathan still
   ends the run (P5 changes that).
2. **The pearl purse: one per player**, not the team's. Each player already opens each chest for
   themselves, and their own purse needs no round trip to the host. A pearl two players reach at
   once online can land in both purses (rare; the board counts it once).
3. **Sunken Idol** takes items only: weapons and tomes aren't chest stacks any more.

What's in it, by file:
- **New:** `weapons.gd` (facet tables, rolls, milestone lines), `tomes.gd`, `loadout.gd` (per
  player), `card_deck.gd` (the four card kinds and fallbacks).
- **Weapons:** Greek Fire, the Halo, Depth Charges, Remoras and the Coil read facets. Each has its
  two milestones. `Horde.shove()` is new (for the pull and the slow). The six fish attacks take
  facets through `_apply_stats` (damage, rate, size, knockback, count, speed) and each has two
  milestones (echo jaws and pulses, a second lash, pierce and burst spears, a big bubble, a
  second spine ring).
- **Settings:** UNNATURAL > Survivor gets "Weapons and Tomes" and "Pearls"; POWERUPS gets a
  Weapons tab (facet steps; the `*_stacks` overrides are level overrides; `attack_level` for the
  attack). The per-stack settings Greek Fire and Depth Charges no longer use are gone.
- **HUD:** weapon and tome slot rows with levels and empty slots, items under them, the purse
  under the XP bar's right end, and each chest ping showing its price (red when you're short).
  The results panel lists weapons and tomes.
- **Online:** guests claim their kills' XP; the host rolls pearls and sends them in batches;
  guests send their Pearl Chance; late joiners get the pearls out. Each machine runs its own
  players' loadouts, so nothing more needs sending (the planned snapshot additions weren't
  needed).
- **Probes:** new `slots_probe` and `pearl_currency_probe`. levels, drops, powerup,
  powerup_batch, combat, stage and `unnatural_net_peer` were updated for the new rules.

**After the P1 play-test (2026-10-18):** the slots' fill speed is fine and the milestones are
liked. The three defaults above are accepted. Pearls and chests dropped too often:
`pearl_drop_chance` 0.12 → **0.05**, `chest_drop_chance` 0.006 → **0.002**. The level caps went up:
`weapon_max_level` 10 → **20** and `tome_max_level` 10 → **99**. Past 20 pips, a card shows one
level bar (`LevelUpCards.MAX_PIPS`).

**Milestones at Lv 15 and 20** (`milestone_third` and `milestone_fourth`, as the user asked). The
lines are in `Weapons.MILESTONES`:

| Weapon | Lv 15 | Lv 20 |
|---|---|---|
| Greek Fire | patches flare wide every 3 s | patches creep toward the nearest zombie |
| Jellyfish Halo | a second, wider ring circles the other way | stings jump on to the nearest zombie |
| Depth Charges | armed mines drift toward zombies | every blast goes off again 0.4 s later |
| Remora Buddy | bites tear into the zombies round the target | remora kills heal 1% |
| Leviathan's Coil | the tail end lashes a shock ring every 2 s | twice as long |
| Sting | pulses draw zombies in | the echo has its own echo (a third pulse) |
| Bite | jaws above and below too (5 echo jaws) | every bite snaps twice |
| Lash | arcs jump to 2 more zombies | a third zombie lashed |
| Thrust | 2 more spears | spears pierce everything |
| Bubbles | twice the bubbles | three big bubbles |
| Spines | they pierce 2 more | a third, full ring |

The new `milestones_probe` runs every weapon at Lv 20 in the Test Tank and checks each effect.
- A gap: online, a remote player's Remora heal happens on the host's copy, not on their machine.
- **The remoras are visible now** (the user had never seen them). They had been 30 cm grey
  capsules flat under the belly, hidden from the follow cam. They're now about twice the size,
  low on the flanks, pale with a faint glow. Each bite's flash grew from 0.45 m to 0.8 m.

### P2 as built (2026-10-18)
- **`RunLog`** (`scripts/unnatural/run_log.gd`): every Unnatural run has one; the Test Tank doesn't.
  - Each minute it takes a sample: level, kills, team dps, ttk, average zombie hp, zombies alive,
    difficulty, damage taken, pearls and chests dropped, pearls taken, the purse, chests opened,
    and each player's build (weapons and tomes with levels, items with stacks).
  - It logs every card picked, with its rarity.
  - The ending records the outcome (down, won, quit or time), the cause of death, and each
    player's totals and `by_source`. The cause comes from the new `cause` argument of `hurt()`:
    a zombie's kind (elites marked), a boss's title, a burst cloud, the Leviathan's bolt or a curse.
  - It saves to `user://run_logs/run_<date>.json` and keeps the newest `run_logs_keep` (50).
    The settings are under UNNATURAL > Run Logs.
- **ttk** = the average max hp of the zombies out now ÷ the team's dps that minute: how long the
  whole build takes to chew through one average zombie. The target is `ttk_target_min` (0.3) to
  `ttk_target_max` (1.0).
- **`SurvivorBot`** (`scripts/unnatural/survivor_bot.gd`, extends HunterBot for its strides):
  - It hunts the nearest zombie while fewer than 6 are within 10 m, and kites round the middle
    when crowded. It steers off close zombies in both cases.
  - At speed, it rams a lone zombie close ahead.
  - It collects pearls nearby, and swims through (or stops by) a chest it can afford.
  - It picks cards greedily or at random.
- **`tests/run_sim.tscn`:**
  `Godot_console.exe --headless --fixed-fps 120 --path . res://tests/run_sim.tscn -- --runs 6`.
  - Options: `--minutes` (20), `--fish` (a family or `all`), `--picks` (greedy, random or mixed),
    `--god`, `--seed` and `--out`.
  - It prints a per-minute table (averages over the runs still going) and flags the minutes
    outside the ttk target. It also prints outcomes, down times and causes, and the cards picked
    by kind.
  - It saves JSON and CSV to `user://run_logs/sim/`.
  - It runs at about 3x real time per process, so run several processes side by side.
- **Test Tank presets:** UNNATURAL > Test Tank > `tank_preset` (Off, or Full slots Lv 5, 10 or 20).
  - It sets the weapons' level overrides: the attack, then Greek Fire, Halo, Depth Charges, Remora
    and the Coil, up to `weapon_slots`.
  - It sets the tank's stats as that many common tome cards: Teeth, Tides, Reef, Shell... up to
    `tome_slots`.
  - Off clears what it set.
- **Probe:** new `run_log_probe` (samples, picks, cause, saving and pruning, restart, the tank
  presets).

### Balance pass 1 (2026-10-18, from the sim; the user was AFK)
**No log from the user's play.** The log only saved when a run ended, and closing the game
mid-run skipped that. The probes were also writing (and pruning to 3) in the real
`user://run_logs/`. Both are fixed:
- RunLog saves after every minute's sample (`in_progress`) and on close or quit.
- Only the main scene saves; probes need `RunLog.save_anywhere`.
- `run_log_probe` uses `user://run_logs_probe`.

**What the sims showed:**
- The director refills the horde whenever it's short. A strong build kills as fast as the director
  spawns (about 2,500 a minute by minute 10), so its XP, and with it its level, is set by the
  director's spawn volume: Lv 36–60 at the boss.
- The weapons were very far apart. Bite and Sting were 9× Lash and Spines at Lv 1, and Greek Fire
  grew ×1,000 from Lv 1 to 20.
- Luck × `chest_drop_luck` plus elite chests made chests snowball: up to 66 chests and 172 items by
  10:00.
- The ttk target (0.3–1 s) can't work against the director's volume. **Fill** replaces it as the
  sim's flag: zombies out ÷ `director.target_alive()`. Under `fill_target_min` (0.25), the build
  wipes each pack as it comes.

**New tools:**
- `tests/weapon_bench.tscn`: each weapon's dps on the Test Tank crowd at Lv 1, 5, 10, 15 and 20.
- run_sim's `--set K=V,...` and fish lists.
- Settings: `difficulty_hp_curve`, `elite_chest_scale`, `chest_price_step`, `fill_target_min`.
- The bot takes tomes (as a player would) and doesn't ram boxfish.

**Changed defaults** (each config was picked from 4 rounds of 3 parallel sims, 4 fish each):

| Setting | Was | Now |
|---|---|---|
| `xp_curve` | 1.35 | 1.9 (xp_base 5 kept: `xp_base` 8–10 starved the early game, with deaths at 3–5 min) |
| `difficulty_hp_curve` | (linear) | 1.55 |
| `pearl_elite_value` | 3 | 1 |
| `elite_chest_scale` | 5 | 2 |
| `chest_drop_luck` | 2 | 1 |
| `chest_price_step` | – | 0.15 a chest paid for |
| bite / sting / lash / thrust / bubble / spine damage | 30 / 16 / 26 / 34 / 12 / 14 | 26 / 9 / 47 / 34 / 9 / 32 |
| bite_cooldown / bite_aim_cone | 1.1 s / 75° | 0.9 s / 110° (the crowd bench overrates the bite; in play, kiting, the jaws pointed away and Dominus died at 4–6 min) |
| fire_dps / charge / jelly / remora / coil damage | 12 / 120 / 10 / 14 / 16 | 40 / 46 / 35 / 55 / 55 |
| jelly_count / jelly_radius | 1 / 1.0 | 2 / 1.2 (one small jelly barely covered anything) |
| burst_damage / burst_radius | 12 / 3.5 | 8 / 3.0 (boxfish clouds were the top killer: melee kills them point blank) |

**The user's own logs** (saved by the new autosave; 6 short runs on the 11:17 build, and a full 10
min Octane run at 15:00 on the new defaults):
- The full run went Sting and Greek Fire, then 7 Tome of Tides. It reached Lv 30 at 10:00, about
  like the bot. Damage taken was low (0–80 a minute).
- The horde's fill fell to 0.18–0.33 by minutes 9–10.
- **Bug found:** 76% of the damage was credited to "bite". The Sting's echo pulses were never given
  their kind, so they kept the default (Bite). Fixed; `milestones_probe` checks it.
  - The weapon bench had mixed those echoes into its "bite" row, which inflated the Bite and
    deflated the Sting.
  - Re-benched: the Sting is mid-pack (2,600 at Lv 20). The Bite (8,200 at Lv 20) is overrated by
    the bench's crowd, but in whole-run sims Dominus is on par with the others.
- **Pearls were worthless:** 1,294 in the purse and 4 chests opened in 10 minutes, at 365 pearls a
  minute by the end. Most came from elites, which always dropped one, and by minute 10 about 9% of
  spawns are elite. Now:
  - an elite drops one by `pearl_elite_chance` (0.3);
  - `chest_price_growth` 0.25 → 0.4 a minute (about 40 pearls a chest at 10:00, before the
    per-chest step).

Greek Fire also changed:
- `fire_life_per_stack` 1 → 0.4, `fire_radius_step` 0.15 → 0.1, `fire_density_step` 0.2 → 0.12.
- `fire_patches_step` 10 → 5 and `fire_max_patches` 80 → 60.
- The flare is 0.5 s of burn at ×1.4 reach; the creep is 1 m/s within 5 m.

### P3 as built (2026-10-23)
Every item of P3 is in. The numbers are panel settings in two new groups, **Feel** and
**Assist**, on a new **Feel** tab of the UNNATURAL section. The Leviathan's two warnings are in
its own group.

| P3 item | What it does | Where |
|---|---|---|
| Damage numbers | One per hit over the zombie; hits on the same zombie within `damage_number_merge` (0.3 s) add up and bump it; crits are gold, `crit_number_scale` bigger, with a "!"; a killing blow shows what it took, not its overkill (`UnnaturalRun.last_hit_dealt`); smaller further off; `damage_numbers_min` hides small ones; at most `damage_numbers_max` (48), the oldest go first; teammates' only with `damage_numbers_team` | `damage_numbers.gd` (in each player's HUD); `UnnaturalRun.last_hit_crit` / `last_hit_dealt` |
| Hit flash and kill pop | The flash already existed; now `hit_flash` scales it (above 1: a brighter glow). Each kill pops a burst (white core, a ring, sparks) in its rot colour warmed to blood-orange, hotter for an elite: one MultiMesh, at most `kill_pop_max` (96), `kill_pop_size`. The dying zombie swells by `kill_swell` before it shrinks | `kill_pops.gd`, `shaders/kill_pop.gdshader`, `horde.gd` `_draw_horde` |
| Target marker | Turning brackets round the zombie each aimed weapon will go for next, in its colour, nested when two share one. `FishAttack.aim_target()` is what the weapon really fires at (the bite, the thrust, the lash and the bubbles now call it). The area and steady weapons don't aim, so they get none | `combat_markers.gd`, `fish_attack.gd`, `ghost_bite.gd`, `bill_thrust.gd`, `shock_lash.gd`, `bubble_volley.gd` |
| Threat arrows, boss bar | Arrows at the view's edge, out of view only: bosses (with their distance), lungers winding up at you ("!"), elites within `threat_range`; nearest first, at most `threat_arrows_max`; kept off the minimap. The boss bar now trails what the last hits took and flashes when hit | `combat_markers.gd`, `unnatural_hud.gd` |
| Telegraphs | Lunges' glow scales with `telegraph_glow`. A red lane (`telegraph_lines`) lies along the path of each winding-up lunge and the Drowned Shark's charge, filling from its start to its end as the wind-up runs out; it ignores the fog. The Leviathan now winds up each dive (`leviathan_dive_telegraph` 1 s: slower, glowing, its lane) and glows before it spits (`leviathan_spit_telegraph` 0.6 s). Online, its net mode carries the wind-up (+8) | `telegraphs.gd`, `shaders/telegraph.gdshader`, `Boss.telegraph()`, `drowned_shark.gd`, `blood_leviathan.gd`, `Horde.telegraphing` |
| Hurt feedback | A ragged red vignette flushes when you're hit (stronger for a bigger share of max hp); under `low_hp_share` (0.25) a lub-dub heartbeat pulses it, quicker the lower you are. The heartbeat sound now starts at the same `low_hp_share`. The thud is the existing `unnatural/hurt` | `shaders/hurt_vignette.gdshader`, `unnatural_hud.gd` `_update_hurt`, `unnatural_sounds.gd` |
| Pickup clarity | The four drops already had their own shapes; the magnet was the heart's red and is now violet. The halo ignores the fog, and a beam of the drop's colour (`pickup_beam` 6 m) stands up through the murk. Drops within `pickup_sense_range` (45 m) ping: at the edge when out of view, in view past 12 m | `pickup.gd`, `shaders/pickup_beam.gdshader`, `combat_markers.gd` |
| Camera | The survivor cam sits up to `camera_crowd_pull` (3 m) further back once `camera_crowd_full` (40) zombies are within `camera_crowd_range` (15 m), plus `camera_size_pull` (2 m) per +100% Size, eased at `camera_pull_rate`. The crowd is counted 4 times a second (a 15 m grid query visits every bucket) | `UnnaturalRun.camera_pull_of()` / `_pull_camera`, `steady_camera(..., pull)`, `main.gd` |
| Depth assist | `depth_assist` (default 0.4; 0 off): zombies climb or dive toward their target's depth on top of their chase (`Horde.DEPTH_DRIFT`), and auto-aim counts each metre of height as 1.5 × `depth_assist` m further (`Horde.aim_gap()`, used by `nearest_in_cone()` and the bubbles' sort) | `horde.gd` |

**Checks:** `tests/feel_probe` (headless) covers all of it. `tests/feel_shots` (windowed, `--
--out=DIR`) takes screenshots of the numbers and pops, the lanes, the threats and drops, and the
low-hp vignette.

**After the user's play-test (2026-10-23, build 21:16):**
- Too many swordfish for a lane each: lunges' lanes are off by default (`lunge_lanes`); bosses keep
  theirs, and swordfish keep their glow.
- Drops came far too often: late runs kill thousands a minute, so a flat chance per kill rained
  magnets, hourglasses and bolts (the 16-min log had 62,678 kills). Drops are timed now: each kind
  waits `heart_every` 45 s / `magnet_every` 90 / `hourglass_every` 120 / `lightning_every` 150
  after its last, and any drop holds every kind back `drop_gap` 20 s. `drops_probe` checks it.
- Performance with Torpedoes and Chain Lightning together: see "Perf pass 3" below (the user
  picked ideas 2, 3 and 4 of the brainstorm).

### Perf pass 3: the hit path (2026-10-23)
Late runs lagged with Torpedoes and Chain Lightning. Every hit ran the whole path on its own:
crit roll, stats, the hit signal, and a call to every held powerup's `on_hit`. A torpedo blast on
30 zombies did all of that 30 times, and each of those hits could start more.
- **Only listeners hear hits (2).** `Powerup.on_hit` / `bonus_on` mark an item `deaf` /
  `no_bonus` the first time the base no-op runs; `Powerups` keeps lists of the rest
  (`_hearing`, `_bonusing`), rebuilt as new arrays (a hit's procs can hit again mid-loop).
  `damage_scale()` is cached once a physics tick. Rule: an `on_hit` override must not call super.
- **Area hits (3).** `UnnaturalRun.hit_area()`: each zombie is hurt as `hit()` would (own crit
  roll, marks, Megalodon, the same `zombie_hit` / `hit_claimed` signals), but the player's numbers
  are worked out once, the stats written once, and the powerups hear at most
  `AREA_PROC_ROLLS` (3) of its zombies, each with the proc coefficient × targets ÷ 3. Average procs
  are unchanged. `FishAttack.strike_area()` is the weapons' way in. Converted: torpedo blasts,
  lightning chains, Kraken slams, Eel, Bioluminescence, Trident, Lure, Pufferfish burst, Riptide,
  Whirlpool Charm, Tsunami, Ghost Swordfish; Greek Fire (all patches in one hit a tick), bite,
  sting, depth charges, halo, coil, remora tears, thrust bursts. Projectiles and the dash moves
  still hit one at a time.
- **Overflow becomes power (4).** `Powerup.proc_power()`: a proc chance past 1 is the proc's
  strength. Torpedoes carry a power (blast damage ×, the blast a little wider); a launch with no
  room under `torpedo_max` folds into the torpedoes flying. Lightning and Kraken bank the strikes
  their rate caps hold back into the next one. Both are capped at `Powerup.BANK_MAX` (25).
- **Measuring.** `UnnaturalRun.hit_usec` / `hits_counted` time the outermost hit calls.
  `UnnaturalRun.batch_hits = false` brings back the old path for A/B. `tests/torpedo_bench` has
  `--old`, `--build` (the user's 16-minute build), `--build=id,id` and `--set=name=value`.
  Probe: `tests/perf_pass_probe`.

Bench, 16 torpedo stacks + 8 lightning, 1,000 zombies, RTX 4070 Ti SUPER:

| | hit path (ms per s) | frame |
|---|---|---|
| bite only, old / new | 15.3 / 11.5 | 5.3 / 5.3 ms |
| + the user's late build, old / new | 72.6 / 31.8 | 18.3 / 17.2 ms |

**What's left:** with the late build the frame is still about 17 ms, and the hit path isn't most
of it any more: about 15 ms of process time and about 1,600 draw calls (from about 650). The
suspects are effects made as nodes per event (`PowerupFx` rings, shocks and spikes, Kraken slams,
Ghost Swordfish streaks, lightning bolt meshes) and the worn models. Each item alone measured only
about 4 ms frames; Kraken's Grasp was the costliest on the hit path (14.8 ms/s for 148 hits/s, its
slam's effects and slows inside the hit). Next: pool the effects (idea 6) and find the draw calls.

**Open for the user's play-test:**
- Is the depth assist's default (0.4) too much or too little? It changes how the horde moves, so
  the sims will shift a little.
- The damage numbers' size and the merge window. Do teammates' numbers belong on by default in
  split-screen?
- The kill pops' colour (rot warmed to blood-orange) and size. In a big wipe only the newest 96 show.
- Should the camera pull be stronger, or follow Size more?
- The thud is still the existing `unnatural/hurt` sound. The new things have no sounds of their
  own yet (a crit, a lane, a threat).

## Existing pieces to reuse
| Piece | Where | Use in Unnatural |
|---|---|---|
| Schools as data, MultiMesh per tail pose, detail fish, 30 Hz sim with interpolation | `School`, `SchoolLook` | The Horde's layout and drawing (§2). It's the same trick, minus the formation. |
| Hitbox pool placed on nearby fish each tick | `NatureRun._place_hitboxes`, `Battery.areas_touched` | Batteries on zombies. Attack queries use a spatial grid instead (§2). |
| Co-op run plumbing: `players`, `authority`, claim → confirm, shared credit | `NatureRun`, `CoopRules`, `CoopSession` | The same pattern for damage, kills, chests and XP (§9) |
| Pearls: glow, magnet pull, absorb, claim/confirm | `Pearl` | **XP pearls.** The magnet radius becomes the *pickup range* stat. |
| Arena edge with fog shift | `Ocean.boundary_radius` (Hunt) | The arena's edge. Add a hard push-back wall (§1). |
| Per-player points, multis, sprees | `NatureScore` | Kept: multis and sprees still announce, and become kill streaks |
| Splash, feed, StatsBoard, scorebug, chain bar | `BroadcastUI`, `hud.gd` | Boss splash, kill feed and the end-of-run board |
| Settings resource + tuning panel + presets | `NatureSettings`, `debug_panel`, `presets/` | `UnnaturalSettings`, `PowerupSettings` (§10) |
| Mode / environment / match card | `main.gd` (`MODES`, `MATCH_MODES`, `NATURE_MODES`) | Unnatural is a new match mode in the Ocean, on Nature's swim tuning |
| C++ GDExtension | `native/under-water-the-fish-dont-stinkExt` | Where the Horde's step goes once GDScript is the limit (§2) |

## Design

### 1. The arena and the blood moon
- **Arena.** A disc in the Ocean, with `arena_radius` (a setting) as its radius, plus a depth band
  (`arena_floor`, `arena_ceiling`). There's a seabed (sand, rocks, kelp: Nature's open "ocean
  dressing" item), so there's somewhere to bury chests and a sense of place. The water's surface
  is overhead with the moon visible through it.
- **Size (D1).** The default is `arena_radius = 150 m` (300 m across) and a 40 m depth band.
  That's roughly 25 s to cross at Nature's cruising speed. It's a setting with a wide range, tuned
  by feel.
- **Edge.** `Ocean.boundary_radius` already darkens the water near the edge. Add a soft wall: past
  the edge, the fish is pushed back in, and the camera is kept inside. Enemies spawn inside the
  edge too.
- **Blood moon look.** Red-tinted fog and ambient light, a large red moon disc above the surface,
  red god-rays through the water and red eyes on the zombies (an emission mask on the baked
  `SchoolLook` mesh, tinted per instance). One `BloodMoon` node owns all of it, so its intensity can
  pulse with events (it brightens when the boss arrives).

### 2. The Horde: zombie fish at scale
Thousands of enemies means **no node per enemy**, as with schools (Nature §9b). It's a new
`Horde` class, a sibling of `School`:

- **Struct of arrays.** Per enemy: position, velocity, facing, hp, kind, state (spawning / chasing /
  stunned / dying), the target player, a hit-flash timer and the time it last touched each player.
  Arrays are pre-sized to `max_enemies` and reused, so spawning never allocates. Dead slots go on a
  free list.
- **Steering.** Each enemy seeks its target player: the nearest player, re-picked every second.
  It adds separation from neighbours so the horde spreads into a wall instead of a single point, a
  little wander, and per-kind behaviour (§3). No formation slots: zombies don't school.
- **Spatial hash grid.** A uniform grid, cell size about 2 m, rebuilt each sim step. It's shared
  by separation (neighbours in adjacent cells, never all pairs), attack queries ("every enemy
  within r of p", "nearest k enemies") and contact damage. This replaces the Area3D hitbox pool for
  enemies. Batteries query the grid with the fish's front and bow-wave shape, and the projectiles
  check against it.
- **Sim at `sim_rate`** (30 Hz, as schools do), drawn interpolated every frame. Far enemies (more
  than about 60 m from every player) update at a quarter of that rate.
- **Drawing.** One MultiMesh per enemy kind per tail pose, as `SchoolLook` does. Per-instance
  custom data carries the hit flash, a dissolve on death, the eye glow and a size scale (for elites).
  There are no detail models: zombies are seen in a crowd. Bosses are real models.
- **Leash and relocation.** An enemy too far from every player (behind the group) is moved to a
  spawn point ahead of them, instead of being killed and respawned. That keeps the pressure where
  the players are.
- **Budget.** The target is **2,000 enemies at 60 fps on the dev machine**, with 5,000 as a stretch.
  Phase 0 measures how far GDScript gets. Schools did 500 fish at 0.8 ms per 30 Hz step, but
  zombies also need grid queries and contact checks. **The step is written to port straight into
  the GDExtension** (`HordeSim` in C++, working on PackedArrays the GDScript side also reads). Do
  the port as soon as the bench says GDScript can't reach the target, not at the end.

### 3. Enemies
Zombie versions of the fish we already have, so the models and baked looks are reused. Each kind
is an `EnemyKind` resource: hp, speed, turn rate, contact damage, size, XP value and behaviour.

| Kind | From | Behaviour |
|---|---|---|
| Rotten sardines | small school fish | Swarmers: fast, frail, come in big packs (most of the count) |
| Ghoul clownfish | Clownfish | Plain chasers |
| Bloated boxfish | Boxfish | Slow tank. Bursts on death into a cloud that hurts (avoid battering it at point blank) |
| Lunging swordfish | Swordfish | Stalks, telegraphs (red flash), then lunges in a straight line |
| Grave ray | String Ray | Glides wide arcs, cuts across your path |

- **Elites.** Any kind can roll elite: bigger, more hp, a glow, and a guaranteed big XP pearl.
- **Mini-boss** (default at 5:00): the **Drowned Shark**, a huge zombie shark. It charges, and
  every so often calls a ring of sardines. Killing it drops a chest's worth of powerup.
- **Boss** (default at 10:00): the **Blood Leviathan**, a giant eel or serpent. It has several
  segments, phases and a health bar at the top of the screen. **Beating it completes the stage.**
  If it isn't beaten, it **enrages** and the run goes on: enemies keep escalating until the players
  win or are all down (D5). There's no hard time limit.
- **Timed swarms** (defaults: 2:30, 7:30 and a final one at 9:30): a closing **ring** around the
  players, a **stampede** (a bait ball of sardines sweeping across the arena) and a **tide** from
  one side.

Bosses and the mini-boss are full nodes with their own scripts. There's only ever a few of them.

### 4. The EvilDirector
`EvilDirector` (a node on the authority only) decides what spawns and when. It works like the
Left 4 Dead AI Director, applied to a survivors game: a time-driven baseline, bent by how the
players are doing.

**Inputs, every second:**
- time elapsed;
- player count;
- players' levels and a rough power score (DPS from their stats and powerups);
- enemies alive;
- the kill rate over the last 10 s;
- damage the players took recently (intensity).

**Outputs:**
- **The target number alive.** `base_alive + alive_per_minute * minutes ^ alive_curve`, times a
  per-player factor (`coop_scale`, e.g. +60% per extra player). If the players are mowing through
  the horde too easily (a high kill rate at low intensity), the target rises. If intensity has been
  high for a while, it holds the target for a breather (`relief_time`). That gives peaks and
  valleys, not a flat ramp.
- **Swarm size and spawn rate.** Enemies come in packs of `swarm_size(t)` from points off-screen,
  in a ring around the players inside the arena, never in anyone's view (`NatureRun._hidden_point`
  already does this).
- **The mix.** Kind weights change over time (only sardines and clownfish at first, then boxfish,
  then swordfish and rays), and the elite chance rises.
- **Scripted events** from a **stage timeline** (`StageTimeline` resource, a list of time → event):
  the mini-boss, the boss and the timed swarms. The director suppresses normal spawns for a moment
  before each one and cleans up stragglers when the boss arrives.

**The start.** A couple of slow enemies, so the first minute is about learning your fish's attack
and the stride. That's why the auto-attack matters.

Every curve parameter is a setting (§10). The panel shows the director's live numbers (target
alive, intensity, next event) when `show_director` is on.

### 5. Player combat: health, auto-attack, batteries
- **Health.** `max_hp = base_hp + hp_per_level * (level - 1)` (+ stat upgrades). Contact damage
  from enemies, then brief i-frames (the fish flickers). Regen is a stat. At 0 hp, solo, the run
  ends (the results board). In co-op, the fish is **downed** (D7): a teammate stays close for a
  few seconds to revive it. The run ends when everyone is down.
- **Auto-attack.** Each fish fires its own basic attack on a cooldown, aimed automatically (at the
  nearest enemy, or the densest direction, per attack). All six below are kept as the plan, and
  the **Shark's comes first** (D8).

  **Melee attacks must be hugely exaggerated.** Aiming is hard in 3D water, so anything melee-ish
  reaches far past the fish, and always **further than the bow wave**. Otherwise there's no point:
  ramming the enemy would do the same. The Shark's bite is **huge ghost shark teeth**: spectral
  jaws, several times the fish's size, that snap shut on the zone in front. Their reach is a
  setting, kept above the current bow wave's size (Bow Grow Bow included, so they scale together).

  First drafts, per fish:

  | Fish | Basic attack | Traversal twist (later phase) |
  |---|---|---|
  | Clownfish | **Anemone sting:** a short-range pulse around it, hits everything | Nimble: sharper turns |
  | Shark | **Ghost bite:** huge spectral jaws snap on a wide zone in front, big damage | Frenzy: faster after each kill |
  | String Ray | **Shock lash:** a whip from the tail at the nearest enemy, arcs to a second | Glide: coasts without losing speed |
  | Swordfish | **Bill thrust:** a piercing spear projectile forward | Dash: a quick burst on the dodge input |
  | Butterfly Koi | **Bubble volley:** homing bubbles at the nearest enemies | Leap: breaches the surface and lands with a splash |
  | Boxfish | **Spine burst:** spikes in all directions | Armoured: less damage taken, slower |

- **Batteries stay.** Ramming a zombie at battering speed hits hard and scales with speed. That's
  our game's signature, and it pairs with the stride flow. It's a damage source like any attack,
  so powerups can trigger on it (§7). Battering a big enemy slows you (as `hit_speed_cost`); small
  ones you plough through.
- **Multis and sprees** carry over from Nature as kill streaks (NatureScore). They give bonus XP
  (D6), not just points.
- **Damage numbers** pop over enemies (pooled labels, or one MultiMesh of digit quads at scale).
  They can be turned off.

### 6. XP, levels and level-up picks
*The playability pass (D17 to D23) replaces XP pearls with XP on kill, and replaces stat cards
with weapon and tome cards. This section describes what's built today.*
- **XP pearls.** Killed enemies drop XP pearls (`Pearl`, reused), sized and coloured by value. The
  *pickup range* stat is the magnet radius. Pearls merge when many lie close, to keep the count
  down.
- **Curve.** `xp_to_next = xp_base * level ^ xp_curve` (settings).
- **On level-up:**
  1. max hp goes up, and the fish heals by the same amount;
  2. **+1 to the fish's signature stat** (for example the Shark's is damage, the Clownfish's is
     area, the Swordfish's is projectile speed, the Koi's is luck, the Boxfish's is armour, the Ray's
     is attack speed);
  3. **three cards** appear, each a **different stat**, each with its own rarity roll. Pick one.
- **Stats** (the pool the cards draw from): max hp, regen, armour, damage, attack speed (cooldown),
  area, projectile count, projectile speed, crit chance, crit damage, swim speed, stride power,
  battery damage, knockback, duration, pickup range, XP gain, luck.
- **Rarity.** It's rolled per card. Base weights are a setting: common 60, uncommon 25, rare 10,
  epic 4, legendary 1. Luck shifts weight up the tiers: each tier's weight is multiplied by
  `(1 + luck) ^ tier_index`, then normalised, so luck 0.5 roughly doubles epic and quintuples
  legendary. Each rarity has a value multiplier (1, 1.5, 2, 3, 5, settings) on the stat's base step.
  Card frames are coloured by rarity (grey, green, blue, purple, gold), and higher tiers get more
  fanfare.
- **Pausing.** Solo, the game pauses while the cards are up (as Megabonk does). In co-op (D3),
  nobody else is interrupted. While picking, the picker is in slow-mo, **invulnerable and
  invisible to enemies**: the horde loses them and goes for someone else or mills about.
- **Co-op levels (D2).** XP is shared: **one team level**, so everyone levels together. Each player
  still gets their own fish's +1 signature stat and their own three cards.

### 7. Buried treasure and powerups
- **Chests** are buried in the seabed at random spots across the arena, about 8–12 per stage
  (a setting), with a few more uncovered over time. They're found by a faint glow, bubbles rising
  from the sand and a ping on the HUD when one is within `chest_sense_range`. **Opening** means
  **either** battering it (a satisfying fit with our controls) **or** holding still beside it for
  about 2 s (D4). While opening one, and while picking its powerup, the opener gets the same
  protection as a level-up pick: invulnerable and invisible to enemies (D3).
- **Powerups.** A `PowerupDef` resource has an id, a name, an icon, stack scaling and hooks. The
  `Powerups` component on each fish holds the stacks and fires the hooks:
  - `on_hit(source, enemy, damage)`
  - `on_kill`
  - `on_battery`
  - `on_tick(delta)`
  - `on_stride(timing)`

  Stacking is per powerup: more chance, more damage, more count or more size, each with its own
  curve and diminishing returns where needed.
- **Proc chains** (chain lightning starting a torpedo, which starts chain lightning...). Every hit
  carries a **proc coefficient** (as Risk of Rain does): an auto-attack is 1.0, a chain-lightning
  bounce 0.3, a torpedo 0.5. Proc chances are multiplied by it, and a hit started by a proc can't
  start the same powerup again. That keeps the fun and avoids runaway loops.
- **The first four** (from the brief):

  | Powerup | Effect | Per stack |
  |---|---|---|
  | **Greek Fire Trail** | Burning patches left behind as you swim. Enemies in them burn (damage over time). | Longer trail life, more burn damage |
  | **Chain Lightning** | Any hit (basic attack, battery, powerup) has a chance to start lightning that jumps between enemies | More chance, more jumps |
  | **Torpedo Launcher** | Any hit has a chance to fire a heat-seeking torpedo that explodes on impact | More chance, more torpedoes per launch, bigger blast |
  | **Bow Grow Bow** | Wearing the bow (a ribbon on the fish) makes your **bow wave** much bigger. The bow wave already counts as hitbox for batteries, so you batter far wider. | Bigger bow wave, bow wave damage even below battering speed at high stacks |

- **More to plan** (suggestions only, for you to accept or replace):
  - Ink Cloud (a blinding cloud when hit);
  - Remora Buddies (orbiting little fish that bite);
  - Whirlpool (pulls enemies in, then flings them out);
  - Sonar Ping (shows chests, stuns briefly);
  - Barnacle Armour (thorns damage);
  - Anglerfish Lure (pulls enemies off teammates);
  - Pressure Wave (a shockwave on every perfect stride);
  - Jellyfish Familiar (a follower that stings).
- **Settings.** Each powerup has its own section (§10), and each has a "stacks" slider for testing.

### 7b. Powerup ideas (brainstorm, 2026-10-17: the user picks)
Risk of Rain 2's shape: lots of small items that stack, and procs that chain off each other (with
proc coefficients, as Torpedo and Lightning already have). Every one is worn on the fish and grows
with its stacks.

**Rarities.** A chest rolls one with the opener's luck:
- Common, Uncommon, Rare and Legendary are the RoR2 tiers.
- **Boss** items drop only from bosses.
- **Cursed** items (RoR2's lunar) have a real downside. They come from a rarer blood-red chest,
  and luck doesn't help with them.

Stacking is linear unless noted; "hyperbolic" means `1 - 1/(1 + k·stacks)`, so it never reaches 100%.

**Common** (white; simple stats and small procs)
| Name | Worn | Does (per stack) |
|---|---|---|
| Bow Grow Bow | the bow (built) | a far bigger bow wave (moved to common, D15) |
| Barnacle Plating | barnacles on the back | +2 armour |
| Hermit Shell | a shell on the back | +15 max hp |
| Kelp Wrap | kelp ribbons trailing | +0.5 hp/s regen |
| Sea Salt | glittering crystals | +5% crit chance |
| Fizzy Soda | bubbles fizzing off the gills | +8% attack speed |
| Speedy Seahorse | a seahorse riding along | +6% swim speed |
| Coral Knuckles | coral on the nose | +20% battery damage |
| Diver's Goggles | goggles | +25% pickup range |
| Lucky Sand Dollar | a coin on the forehead | +0.1 luck |
| Sticky Anemone | an anemone tuft | 10% chance on hit to slow 40% for 2 s |
| Ink Sac | a dark sac | hurt: an ink cloud, nearby zombies lose you for 2 s (+0.5 s) |
| Bubble Wrap | a bubble shell | blocks the first hit after 8 s untouched (−1 s cooldown) |
| Remora Buddy | a remora stuck on | nips the nearest zombie every 1.5 s (+1 remora) |

**Uncommon** (green; procs and companions)
| Name | Worn | Does |
|---|---|---|
| Greek Fire Trail | a lantern (built) | burning patches behind you |
| Chain Lightning | a coil (built) | lightning jumps between zombies |
| Pufferfish Spines | spines out | 50% of contact damage back at the toucher, and a spine burst |
| Lamprey | a lamprey trailing | +1 hp per kill |
| Sonar Pinger | a dish on the head | every 6 s a pulse marks zombies: +25% damage taken |
| Cold Seep | frosted fins | 8% chance on hit to freeze 1.5 s (bosses: slow) |
| Jellyfish Halo | orbiting jellies | +1 orbiting jelly that stings what it touches |
| Treasure Map | a rolled map | +30% chest drop chance, chests pinged further |
| Momentum Fin | streamers | +damage with speed (+10% per 10 m/s) |
| Clam Shield | a clam | blocks one hit every 12 s (−2 s) |
| Electric Eel | an eel coiled on | batteries send out a shock ring |
| Whirlpool Charm | a spiral shell | 6% chance on kill to open a whirlpool that pulls in and grinds |

**Rare** (blue; build-defining)
| Name | Worn | Does |
|---|---|---|
| Torpedo Launcher | twin tubes (built) | seeking torpedoes on hit |
| Depth Charges | a mine rack | drops a mine every 4 s (−10%); a big blast |
| Kraken's Grasp | a tentacle | 5% chance on hit: a tentacle slams an area and holds what's in it |
| Ghost Swordfish | a phantom swordfish escort | dashes through lines of zombies every 3 s (+1 swordfish) |
| Anglerfish Lure | a lantern on a stalk | a decoy zombies chase; it bursts after 5 s |
| Ammonite Spiral | a spiral shell | projectiles split into 3 on hit (+1 split) |
| Riptide | swirling water | perfect strides leave a current that drags zombies back and hurts |
| Reef Guardian | a coral crown | under 25% hp: 3 s untouchable (cooldown 60 s, −15%) |
| Bioluminescence | glowing spots | level-ups and chests send out a flash that hurts with your level |

**Legendary** (gold; rare and loud)
| Name | Worn | Does |
|---|---|---|
| Poseidon's Trident | a trident | every 3rd attack calls lightning down on the biggest zombie near |
| Tsunami Heart | a glowing heart | batteries send a wave along your heading (+width) |
| Megalodon Tooth | a huge tooth | crits finish zombies under 15% hp (+5%, hyperbolic); not bosses |
| Moon Pearl | a pearl on a chain | +1 extra card pick every level-up (+1) |
| Abyssal Engine | a churning engine | +1 projectile and +15% area to every attack |

**Boss** (dropped by bosses, one each)
| Name | From | Does |
|---|---|---|
| Drowned Fin | the Drowned Shark | a charge: hold boost to dash, battering everything in the way |
| Leviathan's Coil | the Blood Leviathan | trailing segments behind you hurt whatever they touch |

**Cursed** (lunar: strong, with a catch)
| Name | Does |
|---|---|
| Blood Moon Shard | +100% damage; +50% damage taken |
| Glass Coral | +100% damage; max hp halved |
| Siren's Song | XP x2; 50% more zombies |
| Abyssal Hunger | big heal on kill; lose 2% hp a second |
| Sunken Idol | every chest offers 1 more pick; you lose a random powerup each stage event |

Picked (2026-10-17): see D13 to D16 in Decisions.

### 7c. Equipment (D13: planned now, built after phase 9)
RoR2's equipment: one item a player triggers when they choose, with a fairly long cooldown.
- **One slot.** A new one replaces the old one, and the old one drops where you are, so a
  teammate can take it.
- **The button.** Every input is taken now. Two candidates:
  - a long press on the ball cam button (Y), which swaps the survivor cams;
  - a stick click.
  The user picks when it's built.
- **Where they come from.** An equipment chest: rarer than the others, and a different colour.
- **The HUD.** The item's icon next to the powerups, with a cooldown sweep.
- **Ideas** (to pick from later):
  - Ink Bomb: blinds the zombies round you for a few seconds;
  - Whale Call: a whale sweeps through the arena;
  - Bubble Net: traps everything in a radius for a moment;
  - Tide Turner: every zombie near is flung away;
  - Sunken Bell: calls every pearl to you.
- **Settings.** One cooldown each, plus a global cooldown scale.

### 8. The Test Tank (shooting range)
A practice environment, picked like the other modes (`TEST_TANK`):
- **Immortal, stationary dummy targets** in a school-shaped cluster, plus a few lines at
  different distances. Optionally, a "slow walkers" toggle so they drift towards you.
- **A DPS readout** per damage source (basic attack, battery, each powerup), with total, hits, procs
  and kills it would have scored. There's a reset button.
- **The panel** sets your fish, your level, any stat, and any powerup's stacks directly. A
  "spawn horde N" button (for example 2,000 chasing zombies with no contact damage) doubles as the
  perf bench.
- It reuses everything (Horde, Powerups, attacks); the dummies are just a Horde with `immortal` and
  speed 0.

### 9. Co-op
The same model as Nature (`going_coop.md`): one authority (offline: this machine; online: the
host).
- **The authority** runs the EvilDirector, the Horde's population (spawns, deaths, relocation),
  the bosses, chests and the timeline.
- **The horde over the network** is the hard part: thousands of enemies can't each be sent. The
  plan:
  1. Spawns go out as packs, as `(seed, kind, count, point, time)`. Every machine builds the same
     enemies from the seed, as schools are built from a seed now.
  2. Every machine runs the same chase steering locally.
  3. The authority sends **corrections** at a low rate, only for enemies near each guest's players
     (a few hundred, quantised), and periodic hp and death lists.

  Drift far away doesn't matter, because nobody can see it clearly.
- **Damage and kills.** As batteries now: the attacker's machine shows the hit at once (claim), and
  the authority confirms it and the kill (which credits the XP and the drop). Enemy contact damage
  on a player is judged by **that player's** machine, so the player is never hit by something they
  dodged on their own screen.
- **XP (D2):** one shared team level. Any player's XP pearls count for the team. The authority
  keeps the total and announces each level-up, and every player then picks from their own cards.
- **Chests** are claimed and confirmed like pearls, and the opener gets the powerup.

### 10. Settings: everything tunable, with wide ranges
Following [flexible tuning], every number is on a resource the panel shows and presets save.
`0` turns a feature off, and the ranges reach several times the default.
- **`UnnaturalSettings`** (panel section UNNATURAL), grouped as Arena, Director, Enemies, Player,
  Levels, Rarity, Chests and Performance:
  - arena_radius, the depth band;
  - every director curve parameter, coop_scale, relief_time;
  - enemy hp, speed and damage scales, elite chance;
  - base_hp, hp_per_level, i-frames;
  - xp_base, xp_curve;
  - the rarity weights and multipliers;
  - the luck effect;
  - the chest count and sense range;
  - max_enemies, sim_rate, far_update_divisor, damage_numbers.
- **`StageTimeline`**: event times, so the mini-boss can come at 1:00 while testing.
- **`PowerupSettings`**, one group per powerup: its base numbers, per-stack scaling and a
  **stacks** override for testing.
- **Per-fish attack settings**: damage, cooldown, range and count, per fish.

### 11. HUD
- **Health bar** under the fish (and teammates' small bars on their name plates).
- **XP bar** across the bottom, with the level.
- **The stage clock**, top centre (counting up), with the next event's warning ("THE DROWNED SHARK
  RISES" splash).
- **Kill count.**
- **Boss health bar** across the top while a boss is out.
- **Powerup icons** with stack counts, along the left.
- **Level-up cards** (three, coloured by rarity), picked with the stick or D-pad and A.
- **Damage numbers** and the kill feed (multis and streaks).
- **The scoreboard** (held, and at the end):
  - per player: kills, damage dealt, damage by source, level, battered fish, best streak,
    powerups;
  - the run's time and the stage result.

### 12. Done in this session: Nature's scoreboard
Hold **D-pad up / B** in Nature to see Hunt's scoreboard, with Nature's own columns:
- **POINTS**;
- **BATTERED FISH**;
- **PEARLS**;
- **BEST MULTI** (its longest chain, x3 = a Triple Fry);
- **BEST SPREE**;
- **PERFECT** (strides);
- **TOP KM/H**.

It lists every player in the run, most points first, with the team's battered fish on the plate
and the run time, pearls and shared batteries underneath. Each split-screen player holds up their
own. Online, other players' numbers ride along with their award events, and a late joiner gets
everyone's so far.

Files: `hud.gd` (`_update_nature_board`), `nature_score.gd` (`perfect`, `top_speed`,
`add_remote`, `save` / `restore`), `nature_run.gd` (`elapsed`, the stride hook,
`relay_award`), `net/coop_session.gd` (stats ride along, `scores` in the world snapshot), plus
checks in `nature_score_probe`, `coop_net_peer` and a shot in `hud_shots`.

## Files (planned)
**New:**
- **Run and director:** `scripts/unnatural/unnatural_run.gd`, `evil_director.gd`,
  `stage_timeline.gd`, `unnatural_settings.gd`
- **The horde:** `horde.gd`, `horde_grid.gd`, `enemy_kind.gd`, `horde_look.gd` (or an extended
  `SchoolLook`)
- **Bosses:** `bosses/drowned_shark.gd`, `bosses/blood_leviathan.gd`
- **Combat:** `fish_health.gd`, `attacks/` (one per fish: `anemone_sting.gd`, `bite.gd`, ...),
  `projectile_pool.gd`
- **Levels and powerups:** `levels.gd`, `stat_block.gd`, `rarity.gd`, `level_up_cards.gd` (HUD),
  `powerups/powerup_def.gd`, `powerups/powerups.gd`, one file per powerup
- **Arena and practice:** `treasure_chest.gd`, `blood_moon.gd`, `seabed.gd`, `test_tank.gd`
- **Later:** `native/.../src/horde_sim.{h,cpp}` (the C++ port)

**Changed:**
- `main.gd`: the Unnatural and Test Tank modes
- `hud.gd`: health, XP, cards, boss bar, icons
- `ocean.gd`: the hard edge, the blood moon hook
- `pearl.gd`: XP value, merging
- `coop_session.gd`: horde packs and corrections, damage claims
- `debug_panel.gd`: the new sections

## Phases
Each phase ends with probes passing, a build and your manual test, per the usual workflow.
- **Phase 0: Bench spike.** A `horde_bench` with N chasing zombies (GDScript Horde, grid,
  MultiMesh) at 500, 1,000, 2,000 and 5,000. It decides when to port the step to C++.
- **Phase 1: The bones:**
  - the Unnatural mode and arena (edge, seabed, blood moon look);
  - health and contact damage;
  - a few chasers;
  - the Shark's auto-attack (ghost teeth, reaching past the bow wave);
  - batteries damage zombies;
  - XP pearls and levels with plain +hp;
  - death and the results board.
- **Phase 2: Scale and the director:**
  - the full Horde (grid, relocation, far LOD);
  - the EvilDirector's time curve and intensity;
  - the enemy kinds and elites;
  - the C++ port if phase 0 said so.
- **Phase 3: Level-ups:** the stat block, signature stats, the three cards, rarity and luck,
  pausing (solo).
- **Phase 4: The Test Tank:** dummies, the DPS readout, panel overrides.
- **Phase 5: Chests and powerups:**
  - buried chests;
  - the powerup system with proc coefficients;
  - Greek Fire, Chain Lightning, Torpedoes, Bow Grow Bow;
  - icons.
- **Phase 6: Every fish unique:** the other five auto-attacks, then the traversal twists.
- **Phase 7: The stage:** the timeline, timed swarms, the Drowned Shark, the Blood Leviathan,
  stage complete.
- **Phase 8: Co-op:**
  - split-screen first (all local, so it's easy);
  - then online (horde packs and corrections, damage claims, downed and revive);
  - co-op level-up pausing per D3.
- **Phase 9: Polish:** juice, damage numbers at scale, the scoreboard, a perf pass.

## Verification (headless probes)
- **`horde_bench`:** frame and step time at each count (not pass/fail; reported).
- **`horde_probe`:**
  - enemies chase the nearest player and spread out (no two closer than separation for long);
  - relocation keeps them near;
  - the grid query matches brute force;
  - kills free their slots.
- **`director_probe`:**
  - the target alive count follows the curve over a simulated 10 minutes;
  - it scales with players;
  - it eases off after high intensity;
  - the timeline events fire on time.
- **`unnatural_combat_probe`:**
  - contact damage and i-frames;
  - each auto-attack hits what it should;
  - battery damage scales with speed;
  - death ends a solo run.
- **`levels_probe`:**
  - the XP curve;
  - max hp on level-up;
  - the signature stat +1;
  - three distinct stats per pick;
  - rarity frequencies over 10,000 rolls match the weights, and shift with luck as the formula
    says.
- **`powerup_probe`:**
  - stacking scales each powerup;
  - proc coefficients stop loops;
  - Greek Fire burns;
  - chain lightning jumps N times;
  - torpedoes seek;
  - Bow Grow Bow widens the battery.
- **`test_tank_probe`:** dummies never die, and DPS per source adds up.
- **`coop_net` additions:**
  - a guest sees the same enemies near them as the host (mean error under a bound);
  - kills and XP agree;
  - a late joiner gets the horde.

## Decisions (user, 2026-10-17)
These replace the earlier open questions. Where a section above differs, these win.
1. **D1: Arena.** 300 m across (`arena_radius` 150 m), with a 40 m depth band, as a tunable setting.
2. **D2: Co-op XP.** Shared: one team level, everyone levels together, and each picks their own
   card.
3. **D3: Co-op level-ups.** Slow-mo for the picker, who is **invulnerable and invisible to
   enemies** while choosing. **The same applies while opening a chest.**
4. **D4: Chests.** Open them either by battering them or by holding still beside them.
5. **D5: Stage.** Mini-boss at 5:00, boss at 10:00, swarms at 2:30, 7:30 and 9:30 (timeline
   settings). An unbeaten boss enrages and the run goes on; there's no hard limit.
6. **D6: Multis and sprees** carry over, and give bonus XP.
7. **D7: Co-op deaths.** The player is downed, and a teammate stays close to revive them. The run
   ends when everyone is down.
8. **D8: Attacks.** Keep all six fish's attack ideas, and start with the **Shark**. Melee attacks
   are **greatly exaggerated** because aiming in 3D water is hard: the Shark's are **huge ghost
   shark teeth**, and every melee reach must be **bigger than the bow wave**, or ramming would do
   the same job.

9. **D9: Follow cam.** Boost counts as accelerate for the cam's hold.
10. **D10: Chest reach.** `chest_reach` stays at 8 m.
11. **D11: Free cam Y.** Becomes an invert-Y setting, **defaulting to inverted** (down on the stick
    looks up).
12. **D12: Hearts.** Drops stay shared (first touch takes it), but a heart heals the **whole team**,
    wherever they are.
13. **D13: Tiers.** Boss and Cursed tiers are wanted, built **after** the first batch. An
    **Equipment** tier (triggered on demand, with a fairly long cooldown) is wanted too: plan it now,
    build it after phase 9, once a button is freed up.
14. **D14: First batch** (the balanced mix, 12 items):
    - Common: Barnacle Plating, Hermit Shell, Fizzy Soda, Speedy Seahorse, Remora Buddy, Bubble Wrap;
    - Uncommon: Pufferfish Spines, Jellyfish Halo, Electric Eel;
    - Rare: Depth Charges, Anglerfish Lure;
    - Legendary: Tsunami Heart.
15. **D15: Bow Grow Bow** moves to **Common**.
16. **D16: Actives** come only as the Equipment tier (D13), later.

**2026-10-18, playability interview** (`brainstorm_playability.md` §1.10). These are built in the
"Playability pass" section above.

17. **D17: Slots.** There are 2 weapon slots and 2 tome slots to start. The fish's attack counts
    as one weapon. More slots come from meta-progression. Both are panel settings.
18. **D18: Torpedo Launcher** stays an item (an on-hit proc).
19. **D19: Anglerfish Lure** is an item.
20. **D20: Drowned Fin** stays an item for now. Revisit it with Equipment.
21. **D21: Tomes.** There are about 12 broad tomes (the table in the playability pass).
22. **D22: XP on kill.** There are no XP pearls in Unnatural, and the XP feeds the shared team
    level. Tome of Pearls becomes XP gain + pearl drop chance (with pickup range). This is
    Unnatural only; Nature's pearls stay as they are.
23. **D23: Pearls are the currency.** They drop by chance, not from every kill, so there are no
    extra pickups on the map. Chests cost pearls at a price that rises over the run. It's a
    setting, so free chests stay an option.
24. **D24: Evolutions** come later. The weapon data leaves room for them.
25. **D25: Rerolls, skips and banishes.** A run starts with none of them. All of them are
    unlocked through meta-progression.
26. **D26: Meta unlocks** mix Shells and challenges. Shells buy rerolls and skips. Challenges
    unlock the extra slots and banishes.
27. **D27: Order.** All of the brainstorm's §2 to §9 are in. They're built in its suggested order:
    slots, then the simulator, feel, choice tools, pacing, meta, and co-op/batteries.

## Risks
- **Scale over the network.** Thousands of enemies on guests is the riskiest part. The pack-seed
  plus local-steering plus near-only corrections approach keeps bandwidth small, but needs
  measuring early (a spike before phase 8, not during it).
- **GDScript performance.** Likely fine to about 1,000, likely not at 5,000. The data layout is
  meant to port straight to C++; phase 0 decides the timing.
- **Readability in a crowd.** Red-eyed zombies in red water can turn to mush. Keep the player's
  fish and pearls high-contrast, and test with 2,000 on screen early.
- **Batteries vs. contact damage.** Ramming into enemies is our core verb, but enemies hurt on
  contact. Rule: a battery at speed gives i-frames for the hit, so ramming is rewarded, not
  punished. Slow bumps still hurt.
