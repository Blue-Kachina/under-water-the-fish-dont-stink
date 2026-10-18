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

### Handoff (fourth 2026-10-17 session): start here
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
