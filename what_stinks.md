# Plan: What Stinks? (one big hunter vs many prey, hiding in schools)

## Context
A new asymmetric mode. One **Hunter** (a Titan or a boss, played by a person) swims an open ocean
full of NPC fish schools. Everyone else is **prey**, and the prey hide **inside the schools**. The
Hunter can see the school but not which fish in it is a player. It's Marco Polo's hide-and-seek
with Nature's schools and camera, and with the bosses and Titans as playable monsters.

It takes from four modes:

| From | What we take |
|---|---|
| **Marco Polo** | Round/roster/role-swap structure, `NoiseMeter`, exposure and the reveal layers (`HiderLooks`, `FishAnatomy`), the Titan class and its murk view, auto Marco / `marco_scan`, Hideaways, pick card, seeker/hider bots, net layer |
| **Nature** | The Ocean arena, `School` (schools as data, MultiMesh looks, alarm, `batter()`), the follow/ball camera and the hold-Y school wheel, split-screen and online plumbing |
| **Unnatural** | The bosses (`Boss`, `BossMesh`, `SpineRig`, ChompKit `Bite`, the boss moves), the Size stat, murk and culling |
| **Hunt** | The one-vs-bot match shape and the HUD pattern for a 1v1 |

Working title **What Stinks?** The pun is the Hunter's job: sniff out which fish in the crowd is the
stinker. Terminology: a fish that is eaten is **eaten** (never "battered"; that word is our rams, see
[[battered-terminology]]). Sizes use "Size".

## Decisions (user, 2026-11-07)
1. One hunter vs many prey (the match must not assume 1; few vs many comes later).
2. Ocean-type arena.
3. The Hunter becomes **a Titan or a boss**: the bosses become playable and need care.
4. The Hunter has a **size variable** (Titans may still be too small). The user will use it to find
   how big they should be, and may make it a power-up later.
5. Variant 1: the Hunter eats every prey player before time runs out.
6. Variant 2: the Hunter has a **satiation bar**; prey players are foul and upset its stomach; it has
   to eat lots of NPC fish and avoid eating players.
7. In both, prey hide among NPC schools.
8. Camera as in Nature.
9. A prey player near a school can **join** it and then swims in lockstep. The Hunter sees the
   school but not that player (cf. whales that work from sound).
10. A prey player who stays out of a school gets more visible over time while still or slow: sonar
    building a clearer picture. The user asked for opinions on all of this.

## Where things stand today (what I checked, 2026-11-07)
- `School` (`scripts/school.gd`) is **data, not nodes**: per-fish position/velocity/heading arrays, a
  leader that picks spots, neighbours, `alarm`/`tightness` when a threat nears, `batter(index)` (the
  fish goes, survivors burst away), `alive_mask`/`apply_alive_mask`, `net_state`/`set_net_state` (host
  leader + followers), `fish_slot_back(index)`, and `_free_slot()` (places in the unit ball). Detail
  models for the nearest fish only (`SchoolFish`). That is the right shape for "a player takes a slot".
- `NatureRun` (`scripts/nature_run.gd`) owns the ocean's schools, hitboxes, focus (ball cam), the
  school wheel `targets()`, and authority/guest signals (`school_spawned`, `school_removed`). It
  respawns schools relative to the players, so it needs a "fixed arena" mode here.
- Marco Polo has `MarcoPoloMatch` (roles, rounds, exposure per seeker view, `in_sight`, `tag`),
  `NoiseMeter`, `HiderLooks` (real model vs reveal copy), `marco_scan`, Hideaways, `TitanView`,
  `WhalePickCard`, `MarcoPoloBot`, `MarcoPoloSettings`, and `marco_polo_net`.
- The **Titan** is a real `FishCharacter` class (`TITAN`, hidden, hitbox 670x240x190 uu = 6.7 m, five
  adult whale models x 3 skins, auto Marco 3 s, `power_stroke`, `titan_lod_rescale` meta when the
  visual root is scaled). `whale_reach_probe` checks that a 6.7 m whale can reach everywhere.
- **Bosses** live in `scripts/unnatural/bosses/`: `boss.gd`, `blood_leviathan.gd` (the King of
  Herrings, and the base of the alternates), `drowned_shark.gd`, `gulper_boss.gd`,
  `lamprey_boss.gd`, `fallen_angel_boss.gd` (`whale_fall_boss.gd` is switched off, see Progress). They are
  AI nodes with spine-bent meshes (`BossMesh`, `SpineRig`) and attacks built on `ChompKit.Bite`
  (`start`, `strike_now`). **Answered by Phase 0:** the AI is welded to `UnnaturalRun`, so the Hunter
  forms reuse the meshes, rigs and bite kit on a normal `FishController` instead (section 2).
- The mode list is the constants `MODES`, `MATCH_MODES`, `NATURE_MODES` in `scripts/main.gd`.

## The core idea, and why it should work
Marco Polo's hardest problem was that hiding was about *not moving*, which is boring to do and
boring to chase. Here hiding is about **moving with the crowd**, which is an active thing. The
Hunter's job becomes reading a crowd, not scanning for blips. Three pressures keep it honest:
1. **Dilution is the cover.** A player in a school of 50 is one of 50. A bite takes several fish at
   once, so the odds are real, not 1 in 50.
2. **Schools get smaller as the Hunter eats them**, so cover erodes by itself and the end of a round
   tightens without a special rule.
3. **Leaving a school is how you move across open water, and it costs you** (below).

## Design

### 1. The match (new `scripts/what_stinks/what_stinks_match.gd`)
Written like `MarcoPoloMatch`: `roster`, `role: Dictionary` (fish -> `HUNTER`/`PREY`), `eaten`
dictionary, one `apply_role(fish, role)` at each round start. The host judges everything; guests
show what the host sends. `Array`-based so few-vs-many works later (`hunters_per_round` setting,
default 1).
- **Round:** `COUNTDOWN -> LIVE -> ROUND_OVER`, `OVER` after the last round. Countdown holds the
  Hunter (view blacked out, as Marco's seeker) while prey scatter and **find a school** (default
  12 s; the Hunter's pick card, see section 2, is shown during it).
- **Rounds per match:** one per human so everyone is Hunter once (as Marco Polo: `rounds = humans`,
  bots fill seats; a setting).
- **Variants** share everything but what a bite does and how the round ends:

| | **Clean Sweep** (`SWEEP`) | **Upset Stomach** (`STOMACH`) |
|---|---|---|
| Hunter wins by | eating every prey player | filling the **satiation bar** to full |
| Prey win by | the clock running out | the clock running out **or** the Hunter's **queasy** bar maxing ("hurls") |
| Eating NPC school fish | no reward (a chew delay only) | fills satiation, by fish size |
| Eating a prey player | prey is **eaten** (out of the round, see 1a) | prey is **spat out** (stays in), satiation drops, queasy rises |
| Schools | do not respawn (cover shrinks) | respawn steadily (the Hunter needs fodder) |
| Satiation also | -- | decays slowly (hunger), so it can't idle |

### 1a. What an eaten prey does (Clean Sweep)
A swallowed player isn't dead weight. Recommended: they go **into the stomach** as a spectator who
can **gut-kick**: tapping a button makes the Hunter's camera judder and shaves its boost a little
(cooldown, tiny effect, so it never decides a round, but it's the "what stinks" joke made playable).
Fallback (cheaper, ship first): spectate with the watch wheel Marco Polo already has.

### 1b. Upset Stomach, in detail
- **Prey want to be mistaken for food**, not avoid being eaten: the whole mode is bluff and tell.
  (This follows from decision 6; please confirm, D3.) An obvious loner swimming at the Hunter's mouth
  gets avoided, so prey still have to blend in and look like fodder.
- **Being eaten is not free for the prey:** a spat-out player is flung away, dazed for `spit_daze`
  seconds (no boost, no join) and the Hunter's bite is on `spit_cooldown`. They don't leave the round.
- **Hunter loses** if queasy reaches max (default 3 strikes' worth) or the clock runs out below full.
- Score: Hunter per `satiation` earned; prey per upset caused (the spit), plus survival time share
  (so a prey who simply hid all round isn't zero).

### 2. Hunters: Titans and bosses
**Playable forms** (a pick card like `WhalePickCard`, shown during countdown, 5 s join hold):

| Form | Source | Signature move (reuse the boss attack as the Hunter's one active ability) |
|---|---|---|
| Humpback / Blue / Orca / Beluga / Sperm | Titans (done) | **Tail Slap** (the unbuilt Marco D8) |
| Drowned Shark | `drowned_shark.gd` | Fast-lunge **chomp** (shark chomp exists) |
| King of Herrings | `blood_leviathan.gd` | **Coil** sweep (King coil exists) |
| Gulper Mother | `gulper_boss.gd` | **Swallow**: a wide vacuum cone that pulls fish in |
| Lamprey Queen | `lamprey_boss.gd` | **Corkscrew** latch on one target |
| Fallen Angel | `fallen_angel_boss.gd` | **Lock-on** on a fish it has watched |

Every form shares: one **Bite** (the core verb), **Click** (echo ping, section 4) and **Sniff**
(section 4b). The move per form is a flavour of Bite, not a second system: it changes the bite's
**shape** (cone angle, reach, capacity, wind-up), because tuning five unrelated abilities is how
this plan would go over budget.

**How they were built playable** (decided and done in Phase 0/5): every non-Titan form is a species of
the hidden class `FishClass.MONSTER` on a normal `FishController`, wearing the boss's mesh/rig (a
`SpineRig` fed from the controller's speed and turn, not the boss AI) and `ChompKit.Bite` as its bite
(`HunterBite`). That keeps online sync, bots, camera and the HUD identical to everything else. The
Titan whales stay `TITAN` species. Each form lives in `scripts/what_stinks/forms/<key>.gd` and is only
offered when its `ready()` is true.

"Bosses need attention to detail" means, per form: model reads right at close range and at the new
size, camera collides sensibly, swim animation is driven by the controller's speed and turn (not the
boss AI's pathing), eyes and murk look, a voice/audio set (stand-ins fine), and a **form sheet** (like
`titan_specs.md`): hitbox, bite shape, speeds, camera offset.

### 3. Size (the variable you asked for): `hunter_size`
One multiplier, `1.0` is the form's natural size, range `0.25..30` ([[flexible-tuning]]). Because
"how big should they be" is an answer you'll find by playing, I'd rather one dial moves everything
that must stay consistent:

| Scales with size `s` | Rule (all settings, so each coupling can be flattened) |
|---|---|
| Model + hitbox | x `s` (use the `titan_lod_rescale` meta; the boss meshes need the same call) |
| Bite reach, bite radius | x `s` |
| Bite **capacity** (fish per bite) | x `s^bite_capacity_exp` (default 1.5; bigger mouths eat more than they reach) |
| Top speed / accel | x `s^speed_exp` (default 0.5: bigger is faster but not proportionally) |
| Turn rate | x `s^-turn_exp` (default 0.5: bigger turns slower) |
| Camera distance / height | x `s` so the monster is always framed the same |
| School alarm radius | x `s` (fish bolt from something huge earlier) |
| Murk sight / `los_range` | x `s^0.5` |
| Arena size | not scaled; instead `arena_radius` is checked against `s` (see Risks) |

Also: `prey_size` (school fish and player fish scale) as a second dial, since the *ratio* is what
matters visually. This is a cheap way to get "the Hunter is bigger" without touching Hunter
geometry (and keeps the 6.7 m Titan that `whale_reach_probe` already proves).

**Later: Size as a power-up.** Reserve it now: size is read from a `size_mult` meta on the fish, so a
pickup (e.g. a "Krill Swarm" that grows the Hunter 25 % for 20 s, or a "Chum" that grows a prey
player so a big prey is in the same sort of danger) is just a timed multiplier. Not built in the
first pass.

### 4. Visibility: the Hunter's picture of a prey player
This is the part you asked me to weigh in on, so here's the reasoning, then the proposal.

**Opinion on "more visible while still or slow" (sonar building up): yes, but don't invert
Marco Polo wholesale.** If stillness is *always* penalised and speed always free, prey will just
cruise fast to avoid detection, which kills the school mechanic (you'd never join a school because
you could just run). If stillness is free, prey will camp on the seabed, which is Marco Polo again.
The cleanest answer is to make the **cost differ by how you hide**:
- In a **school**, what protects you is the crowd. Time in the school is nearly free.
- **Alone**, what protects you is being hard to read: moving at a middle speed with good strides.
  Both stillness (an echo builds) and speed (noise, a wake) cost you.

So there are two independent inputs to what the Hunter sees:

**4a. Noise exposure** (kept from Marco Polo, per Hunter view): `NoiseMeter` unchanged. Loud
swimming, flips, jumps and mistimed strides make a loner visible for a few seconds. That is already
built and tuned in the same shape.

**4b. Echo image** (new; your idea): a per-prey value `echo` in 0..1 held **per Hunter view**.
- It **builds** while the prey is inside the Hunter's *echo cone* (an angle and a range, scaled by
  `s`), at a rate set by the prey's speed: fastest when still, falling to `smear_floor` (default
  0.25 of max) at `smear_speed` or faster (a fast fish is a smeared echo).
- It **decays** outside the cone or in an **echo shadow** (rock overhangs, kelp, Hideaway spots:
  build rate x 0.2). Decay is slow (`echo_decay`, default 0.1/s), so the image lingers.
- Feeds the **same reveal layers** as Marco (skeleton, heart, muscle, skin, aura): `exposure =
  max(noise exposure, echo)`. It needs no new look. The Hunter sees bones, then a heartbeat, then
  muscle and skin emerging from the murk as its sonar "focuses". That fits the whale theme.
- **Defaults:** time to skin (fully seen) for a still loner at point-blank ~5 s; at middle speed ~15 s;
  at fast speed it doesn't build (noise handles it).
- **In a school the echo builds ~10x slower** (`blend_echo_mult` 0.1, "lost in the crowd's
  clutter"), which gives the Hunter the "stare at one school and one fish slowly resolves" read of
  section 5. A school member in view long enough shows as a **faint skeleton in the crowd**: that
  is the tell, and it's why the mode is called What Stinks?
- The **Click** (the Titan's auto-Marco, now on a cooldown) gives an instant `echo` bump of
  `click_gain` (default 0.4) to every non-school prey in the cone, and reveals school members by
  only `click_gain * blend_echo_mult`.

**4c. Sniff** (new, cheap): hold a button to **narrow the cone** and multiply `echo` build by
`sniff_mult` (2x) while it's held, but you swim at `sniff_speed` (0.5x). A positioning trade, not a
second meter.

**Counterplay for prey** (all explicit and few):
- **Join** a school (section 5), the main hide.
- **Leave** (a quick dash out): resets that player's echo to 0 (a fresh start) but is **loud**
  (`leave_noise` = a jump's worth), and there's a `rejoin_cooldown` (3 s) so you can't hop back
  and forth to dodge.
- **Spook** (`spook_charges` 1 per round, prey only): startle the school you're in; every fish in it
  bolts and re-forms, and **every fish's echo in that school resets to 0**. A reset button for the
  school itself, at the cost of the whole school moving (panic).
- **Echo shadows** (kelp, rock arches, trench shelves): worth using as a loner. This is where
  Marco Polo's Hideaways go; reuse `hideaway.gd`.

### 5. Schools, joining and the tell
- **Join:** within `join_radius` (default 4 m) of a school, a prompt appears. A button press
  (default **A**, since the stride/dodge buttons are taken; open, D5) joins it. The player takes a
  free slot (`_free_slot`) nearest their position and **eases in over `join_ease` seconds** (default
  0.6 s) with no snap. Held **in lockstep**: position, velocity and heading are the school's. Input
  now **leans** the player's slot inside the school (slot_lean), and a button **Leave**s.
- **Slot ownership:** the school gets a `claimed` set (by index). A claimed slot is a real school
  fish whose motion the controller *reads* but whose transform the school writes, so there is no
  second authority on the same fish (and net sync stays the school's own `net_state`).
- **Class and look:** the player's fish **adopts the school's look** while joined (a cosmetic swap in
  `HiderLooks` style). To keep it fair and flavourful, schools are made of the **classes the prey are
  playing** (plus filler): `School.setup(..., kind, ...)` already takes a class. A setting
  `join_any_class` (default **off**) means you join only your *own kind*, which spreads the prey
  across schools and makes finding your own kind a minigame. On: join anything.
- **School steering:** NPC school only; the leader chooses spots. Optionally joined players **vote**
  a small bias (`vote_bias` 0 default): off for now, a hook for later (sections Open).
- **Hunter can't see which fish is a player.** They look like the others. Only these tells exist:
  1. the **echo tell** (section 4b): a faint skeleton that builds on the player's slot, slowly;
  2. **count**: the HUD shows `prey left`. As NPCs go, the odds on each fish rise;
  3. **name plates are hidden** from the Hunter (Marco Polo's `plate_filter` pattern).
  There is deliberately **no motion tell** (no lag, no tail difference). Skill should be reading
  the crowd over time, not spotting an animation bug.
- **Other prey see joined players** as ally markers, since prey are co-op and need to
  coordinate (the player arrows system).
- **Bite vs a school:** a bite eats the `bite_capacity` fish **nearest the bite point** (sorted by
  distance; ties random). A joined player is eaten only if their slot is in that set. The School
  needs a new `eat(indices)` (like `batter()`, but the survivors **panic harder** and can **scatter
  off in all directions**, which splits a school into a few groups; schools re-form after
  `reform_time`).

### 6. Scoring (a first pass; all settings)
- **Hunter (Sweep):** `tag_points` per prey eaten, a time bonus for finishing early.
- **Prey (Sweep):** `survive_points` per second alive, a `last_fish_bonus` for the last one standing,
  and a `brave_points` kicker for being within `brave_range` of the Hunter's mouth *while joined* for
  `brave_time` s and not eaten (the school-hider's version of a close call).
- **Hunter (Stomach):** satiation is the score. **Prey (Stomach):** per upset (a spit) + a survival
  share. No live scores during a round (they'd leak who is a player), as in Marco Polo.

### 7. Camera and HUD
- **Camera:** Nature's: Settle-style follow cam (auto follow while accelerating, lags turns, coast
  swing on release), plus ball cam with the hold-Y school wheel. The Hunter's ball cam focuses on
  the nearest school (a stalking read); the wheel picks one. Prey who are joined use Nature's
  normal follow; the school wheel for prey picks the school to head for.
- Camera distance/height scale with `hunter_size` (section 3). Boss forms get a per-form offset
  (a 40 m oarfish isn't framed like a 7 m whale) from the form sheet.
- **Hunter HUD:** satiation bar (Stomach), queasy meter (Stomach), `prey left`, Click and Sniff
  cooldowns, a **Bite** wind-up ring, the murk view (`TitanView`).
- **Prey HUD:** a plain **map** with allies, the Hunter's arrow and school markers (Marco Polo's
  hider map pattern), a small `noise` ring and an **echo ring** that shows how clear the Hunter's
  picture of *them* is. (Prey learn what builds it, like the noise ring taught them in Marco Polo.)
  Plus join/leave prompts.

### 8. The arena: an ocean
- **Nature's Ocean**, circular and bounded by a soft **murk wall** (`arena_radius`, default 220 m,
  to be checked against `hunter_size`; the Hunt mode already has a radius). Not Nature's endless
  respawn: schools are **placed once** at the start (`school_count`, default 14) around the arena,
  each 20 to 60 fish, drifting in loops between waypoints.
- **Cover for loners:** a few **kelp stands** and **rock arches** (echo shadows, section 4b) and a
  seabed shelf. These are the Hideaway pattern, so it's mostly new meshes, not new systems.
- **Murk:** reuse the murk/culling plan (`planning_murk.md`); `TitanView` for the Hunter.
- A smaller **Reef** arena (more cover, fewer schools) is a good second map but not in the first pass.

### 9. Bots
- **Prey bot:** goes to the nearest school of its class (or any, if `join_any_class`), joins, stays
  until the Hunter's cone has had it for a while (it can see its own echo ring), then **leaves and
  moves to another school** (the "relocate" behavior is the whole bot). Loner behaviour: middle speed
  with proper strides, into an echo shadow if one is near.
- **Hunter bot:** picks the school with the most prey (it knows the count), approaches at stalk speed,
  and when a faint skeleton appears it biases the bite there; otherwise bites at random from the
  densest part (so it is beatable, not psychic). Uses Click when it has lost the prey, Sniff on a
  single school. It never reads which fish is a player directly.
- Both write to the same sim log as the other `run_sim`/`marco_polo_sim` tools so we can report
  numbers, and per [[playtest-before-tuning]], **report, don't tune**.

### 10. Settings (a `WhatStinksSettings` resource, panel group "What Stinks?")
Groups, each value with a wide range ([[flexible-tuning]]): **Match** (variant, rounds, hide time,
round time, hunters per round), **Hunter** (form, `hunter_size`, the size couplings, bite shape,
Click, Sniff), **Echo** (build, smear, decay, shadow, blend mult, layers), **Schools** (count, size,
class mix, join radius, join ease, rejoin cooldown, Spook, reform time), **Stomach** (satiation per
fish, decay, queasy cap, spit daze), **Scoring**, **Arena**, **Bots**. A preset per variant in
`presets/`.

### 11. Mode wiring
- A new `WHAT_STINKS` in `MODES` (and `MATCH_MODES` since it's a match), with a mode pop-up card
  with the variant, and the Hunter-form picker. Build on the `MARCO_POLO` wiring (planning_marco_polo
  section 13) and the UI redesign's mode pop-up ([[ui-redesign-built]]).
- New folder `scripts/what_stinks/` and net layer `scripts/net/what_stinks_net.gd`. Tests in `tests/`
  (the names below).
- Update `INVENTORY.md` for the new settings, forms and stats ([[keep-inventory-updated]]).
- Co-op: **online + bots only** (D7). Split-screen players are dropped with a note on the setup screen.
- **As built:** the mode is in `MODES`/`MATCH_MODES`/`NATURE_MODES`, but its picker tile is still in
  the hidden row (hold SELECT) until it is ready for PRIMARY. The variant, "Start as" and Hunter form
  picks live on the shared **mode setup screen** (`ModeSetups`, built for every mode on 2026-11-07),
  not the old match card or pop-up; the Hunter role picks a form instead of a fish, prey wear their
  last prey fish.

## Suggestions to make it fun (the "what do you think" parts)
1. **Make the Hunter's decision the fun**, not its aim. The best moment is staring at one school
   and *deciding* to commit a bite, knowing a skeleton is slowly appearing. The echo build gives
   that. The `prey left` count turns every bite into a bet.
2. **The prey's best moments are the bluffs.** Spook (a controlled panic), joining a school
   *right as the Hunter turns*, leaving at the last second. Keep prey tools few so the bluffing
   stays readable.
3. **Prey should have something to do while eaten.** The stomach gut-kick (1a) is the cheapest
   good answer and it fits the title.
4. **Don't let the Hunter be omniscient or helpless.** The scores to watch in sims are round length
   and the share of rounds where the Hunter wins; a Titan-sized Hunter vs a bot crowd will likely win
   too often at first (Marco's whale did).
5. **A comeback valve:** a late round tide (the murk wall closes `arena_shrink` per 10 s after the
   half-way mark) so schools bunch together and the Hunter has information. Off by default; a
   one-line setting. It's the answer if stalemates show up.
6. **Variants beyond the two** that fall out cheaply: **Few vs Many** (2 Hunters, more rounds),
   **Chum** (a Hunter pick-up that grows the Hunter), **Dinner Bell** (prey get a pick-up that
   makes them worth more when eaten in Stomach).
7. **Audio and sound identity:** a Hunter's heartbeat-like pulse when it's close, the school's
   panic whoosh, the "ptooey" spit. Stand-in ids first (audio list, like `planning_audio`).

## Phases
**Phase 0: spike and form sheets (small, and decides the rest).**
- Prove one boss (the Drowned Shark) can be a `TITAN` species on a `FishController`: model,
  swim animation from controller speed, bite from `ChompKit.Bite`, camera, hitbox. Report whether
  the AI-node path is viable (section 2).
- Decide `hunter_size` plumbing (one `size_mult`), checked on a Titan at 0.5x, 1x, 3x.
- Output: a short section in this file, plus the form sheet template.

**Phase 1: the match with no hiding.** `WhatStinksMatch` (rounds, roles, Sweep only), Hunter role,
a fixed Ocean arena with placed schools (no respawn), the bite and `School.eat()`, prey eaten,
the HUD basics, bots do the simple thing (prey wander, Hunter swims at the nearest fish). Probes
for the match and the bite.

**Phase 2: joining.** Slot claiming, ease-in, lockstep, lean, Leave, the look swap, ally markers,
name-plate hiding, `join_any_class`. `school_join_probe`, school net sync.

**Phase 3: visibility.** `NoiseMeter` reuse, the echo meter, cone, shadows, Click, Sniff, the
reveal layers on a school slot, the prey's echo ring. `echo_probe`, `echo_shots` (like `reveal_shots`).

**Phase 4: Upset Stomach.** Satiation, queasy, spit/daze, school respawn, scoring.

**Phase 5: the forms and size.** All 10 forms (5 whales + 5 bosses; Whale Fall was dropped), the pick
card, per-form bite shape and the form sheets, `hunter_size` fully wired and tested across the range,
the camera offsets. This is the phase most likely to take longest; split it per form so each can ship
alone (a form not done is simply not in the card).

**Phase 6: online.** `what_stinks_net.gd`, schools with claimed slots, size/echo sync, a 3-peer
test (as `marco_polo_net.sh`), 4-hunter conversion-style stress.

**Phase 7: bots and balance report.** Real Hunter and prey bots, `what_stinks_sim` (the numbers in
section 9), then a report for you. **No tuning until you've play-tested.**

**Phase 8 (optional):** gut-kick stomach role, Reef arena, Size power-up, Few vs Many, tide.

## Decisions D1-D10: ANSWERED 2026-11-07 ("go with your recommendations")
D1 variant names Clean Sweep / Upset Stomach. D2 the Drowned Shark is the Phase 0 spike boss.
D3 Upset Stomach prey **want to be eaten** and are spat out (not eliminated). D4 echo defaults as
written (still loner seen in ~5 s, school ~10x slower), **no motion tell**. D5 join on **A**.
D6 free class pick, `join_any_class` off. D7 **online + bots only**, no split-screen. D8 round 3 min,
usual case is one human Hunter or one human prey among bots. D9 **Spook is in the first pass**;
gut-kick is Phase 8 (spectate with the watch wheel first). D10 first playable forms: Drowned Shark,
Humpback, Gulper Mother.

The original questions are kept below for reference.

## Decisions (original questions)
- **D1.** Names: **Clean Sweep** / **Upset Stomach** for the variants OK?
- **D2.** Phase 0 order: OK to start with the Drowned Shark as the spike boss, or another?
- **D3.** In Upset Stomach, prey **want to be eaten** (and are spat out). Confirm. The alternative is
  prey being eliminated by an accidental eat, which makes the Hunter's mistake end a player's round
  and makes prey's incentive match Sweep's.
- **D4.** Echo defaults (a still loner is fully seen in ~5 s, in a school ~10x slower): good as a
  starting point? And do you want a **motion tell** for school fish after all (I recommend none)?
- **D5.** The join button (A, or a hold-to-join on a stride button?).
- **D6.** Prey class: free pick (as Marco's picker), or fixed? And is `join_any_class` off by default
  right (find your own kind)?
- **D7.** Split-screen: **online + bots only** like Marco Polo, or also local? (Nature's perf pass
  exists for views but a 3.5-ton Hunter at 7 m per view needs a camera check.)
- **D8.** Round length (default 3 min?), Hunter win time bonus, and whether a lone Hunter vs
  1 or 2 humans (rest bots) is the usual case.
- **D9.** Whether Spook (1 per round) and the gut-kick stay in the first pass.
- **D10.** Which of the 11 forms should be in the first playable (suggest: shark + humpback +
  Gulper, because their bites differ most).

## Risks
- **Bosses as controller characters** (Phase 0). The single biggest unknown. Mitigation: the spike
  and the fallback of reusing meshes/rigs only.
- **Size breaks things.** At large `hunter_size` the Hunter won't fit or reach everywhere in the
  arena (Marco's D19: 6.7 m is the largest that worked in the Aquarium). Play-test confirmed it feels
  worse the bigger it gets, so matches are now locked at 0.5x (`HunterSize.MATCH_SIZE`). The Ocean is open, but
  `whale_reach_probe` should run with the new `arena_radius`, and the bite and camera need testing at
  extremes. Cap the arena/size ratio with a warning in the panel.
- **Slot ownership across the net.** The school's `net_state` is leader + followers; claimed slots
  must stay deterministic. Mitigation: only the host assigns claims, and everyone applies them with
  `apply_alive_mask`-style messages.
- **Perf at many fish plus a huge model.** Nature runs 1000 fish at about 2.6 ms; Titans at
  LOD0 are heavy (Titan skins cap 60k). Check early with a fixed arena benchmark.
- **The Hunter is too strong or the crowd too safe.** Likely both in different settings. Sims will
  tell us, and every knob above is a setting.
- **Prey can't tell what they've been spotted by.** The echo ring is the answer; if play tests say it
  isn't enough, add a subtle audio cue (a low click rising with `echo`).
- **Stalemate** if the Hunter can't resolve a school. The tide (suggestion 5) and a shrinking-school
  rule are the valves.

## Verification (probes, to follow the repo's headless-probe habit)
`what_stinks_probe` (rounds, roles, win conditions both variants), `school_join_probe` (claim, ease,
lockstep, leave, cooldown), `school_eat_probe` (eat, scatter, reform, alive-mask sync),
`echo_probe` (build/decay/shadow/layers per speed), `hunter_forms_probe` (every form: hitbox, bite,
camera at three sizes; skins via the existing `skins_probe --class=titan`), `hunter_size_probe`,
`what_stinks_net.sh` (3 peers), `what_stinks_sim` (reports, doesn't tune), `echo_shots` (see the
layers on a school slot). Regression: modes, ui, console, marco_polo_probe, nature probes.

## Progress
Status 2026-11-07 late night (details in the log below; the latest FINAL SUMMARY entry is the two-stage run's, and
later entries supersede earlier ones):
- Phase 0 spike: DONE. Phase 1 match: DONE. Phase 2 joining: DONE. Phase 3 visibility (echo): DONE. Phase 4 Upset Stomach: DONE. Phase 6 online: DONE (4-Hunter stress, net bench, prey map and echo/Click/Sniff sync not done).
- Phase 5 forms: registry, size and setup-screen pick DONE. **Ready forms (10 of 11): Drowned Shark, Humpback, Orca, Beluga, Sperm Whale, Blue Whale, King of Herrings, Gulper Mother, Lamprey Queen, Fallen Angel.** The four non-Humpback whales became ready on 2026-11-07 (two-stage phase 2) with first-guess sheets and the shared engulf mouth: they pass their probes but have only been looked at in a few windowed shots (sperm, orca, humpback, blue), never played. **Whale Fall is disabled** (flag, not removed; its two-stage lash is out of scope and not built).
- **Phase 7 (bots and balance report): DONE** (prey bot, echo-reading Hunter bot, `what_stinks_sim`, `what_stinks_report.md`; nothing tuned, the numbers are open items for the play-test). Phase 8 (polish): NOT started.
- **Two-stage attacks (two-stage-attack.md): built 2026-11-07**, every ready form: Hunter press opens, hold charges, release shuts (`bite_mode` hold, tap keeps the old snap); styles chomp, engulf (5 whales), lock (Angel), suction (Gulper), coil (King), drill (Lamprey). See that file's progress log.
- Added since the overnight run, from play-tests: instant chomp, follow cam + school lock-on, lock-on bite, body rams, callouts, size locked at 0.5x, Hunter bodies roll with the fish, Drowned Shark jaw rebuilt, mode setup screen.
- Build: see the FINAL SUMMARY of 2026-11-07 (two-stage wrap-up) for the timestamp. Awaiting user play-test.

**Whale Fall: removed from the mode (2026-11-07).** The form's `ready()` returns false so it is never
on the picker, and the boss is skipped by `UnnaturalRun.DISABLED_BOSSES` (flipped off, not deleted).
Its files (`forms/whale_fall.gd`, `whalefall_*.gd`) stay so it can come back; `hunter_forms.md` still
has a sheet for it. It is not part of any phase or count in this plan.

## Progress log
Newest last. Each worker appends one entry: what was built, files, probes, decisions, open issues, hand-off.

### 2026-11-07_01:38 Phase 0 (spike): DONE, viable, path = titan-species (hidden class)
- **Verdict.** The AI-node path is NOT viable: `Boss` is welded to `UnnaturalRun` (`run.horde` proxies for its body, `run.players`, `run.hurt`, `run.settings`, `_keep_in_arena`), and `DrownedShark._move` is target-seeking AI. Driving it from a controller would mean a fake run. The Drowned Shark is also NOT a BossMesh/SpineRig boss: it is `FishModel.build(HUNTER)` (the Shark class model, a great white) scaled x15, rotted, red eyes, plus a jaw rig added in `_build_jaw`. Only the final bosses (King, Gulper, Lamprey, Angel; Whale Fall was dropped later) use BossMesh/SpineRig (Phase 5 problem, see below). So the shark form is a hidden class on a normal `FishController`, as the Titans are. Everything works end to end.
- **Built (all new in `scripts/what_stinks/`):**
  - `hunter_form_model.gd` `HunterFormModel`: `FishModel.build` hands `FishClass.MONSTER` here. Builds `SharkModel` on the Hunters' box (so the shape is right), tints it rot via `m._tint` (NOT `set_body_color`: the controller calls `reset_body_color` when it has no team colour, which would undo it), red glowing eyes, and the jaw rig (kept in model meta `hunter_jaw`).
  - `hunter_jaw.gd` `HunterJaw`: `DrownedShark._build_jaw`/`_pose_jaw` lifted out (uses `DrownedShark._rim/_plate` statics). `pose(open)`.
  - `hunter_form.gd` `HunterForm`: the **form sheet template** (const dicts: name, class, species, length_m, speed/accel/turn, bite_reach_m, bite_radius_m, bite_wind, bite_every, capacity, cam). `SHARK` (length 7.0 m, bite reach 3.5, radius 1.6, capacity 4) and `HUMPBACK` (Titan, for the size check). `body_scale(form)`.
  - `hunter_size.gd` `HunterSize` (Resource, `shared()`): settings `size_mult` 0.25..30 (default 1), `speed_exp` 0.5, `accel_exp` 0.5, `turn_exp` 0.5, `bite_capacity_exp` 1.5, `bite_reach_exp` 1.0, `cam_frame` 1.0, `alarm_exp` 1.0, `sight_exp` 0.5. `apply(fish, form)` sets body_scale (model+hitbox), top_speed_scale, accel_scale, boost_scale, drag_scale (size-free), turn_scale + `rl_turn_scale`, and calls the `titan_lod_rescale` meta. Also `bite_reach/bite_radius/bite_capacity/alarm_radius/sight_range` and `frame(camera, fish, form)`. A fish meta `size_mult` multiplies on top (the power-up hook). Not yet owned by a `WhatStinksSettings` panel group: Phase 1 should embed/expose `HunterSize.shared()`.
  - `hunter_bite.gd` `HunterBite` (Node, child of the fish): press of `button` (jump default; boost/powerslide/air_roll selectable; read from the fish's `*_held` so people and `FishInput` bots work alike) starts a `ChompKit.Bite` (anticipate/gape/hold/strike/shake/recover), jaw + head lift/saw posed on the model, body lunge via `apply_push`, `chomped(mouth, reach, radius, capacity)` on the contact tick, camera punch, cooldown (`bite_every`). `in_bite(point)` = frustum from the mouth (reach long, radius at far end, a quarter at the mouth). What gets eaten is the mode's call (Phase 1: School.eat of the `capacity` nearest in the frustum).
  - Shared files, small additive edits: `fish_character.gd` (new hidden class `MONSTER` appended at the end of the enum, hitbox 1.205 x 0.56 x 0.40 m, species `drowned_shark`; its box is narrower than the Hunters' fin span, the model is built on the Hunters' box), `fish_model.gd` (a 3-line `MONSTER` case in `build`), `fish_controller.gd` (new `rl_turn_scale := 1.0`, see below), `tests/class_species_probe.gd` (Monsters may have 1 species).
- **Finding that matters to every later phase: `turn_scale` does nothing off a surface.** With the default `rl_air_control=true` (and `rl_roll_timing=true`) in water the turn goes through `_rl_air_control`, which ignores `turn_scale`, and the spin cap is the fixed RL 5.5. So Marco's `whale_turn_scale` 0.55 and Unnatural's Nimble have likely been inert in open water (not changed; flag for the user). For the dial I added `FishController.rl_turn_scale` (default 1.0, no behaviour change for anyone else): scales the RL air pitch/yaw torque and the RL spin cap. `HunterSize.apply` sets it. Also `top_speed_scale` caps only boosting/strokes, and thrust-only speed settles near `max_speed`, so I also set `boost_scale = s^speed_exp` so a big Hunter boosts higher.
- **Probe: `tests/hunter_spike_probe.tscn` (headless, 75 checks, 0 failed).** Shark and Humpback at 0.5/1/3: body_scale/hitbox/collision box exact (shark hitbox 3.5/7.0/21.0 m long), model extent within 5% of hitbox length (fins make it wider than the box: shark 4.8 m across at x1), LOD ranges follow on the Titan, swim, bite (one press = one bite, jaw to 1.0, lands 0.83 s after the press, whole bite 1.4 s, reach/radius/capacity follow the size, 5 frustum point tests, cooldown holds a second press). `--shots=DIR` (needs a window) saves a framing shot per size plus jaw-open front/side shots; I looked at them: the shark reads as a rotten red-eyed great white with a wide gape; framing identical at all sizes.
- **Numbers (report, not tuned):** boosted peak speed (3 s, full boost) 21.2 / 30.0 / 52.0 m/s at x0.5/1/3; turn rate 3.66 / 2.59 / 1.50 rad/s; camera 2.15 / 2.13 / 2.11 body lengths away and the body spans 11% of screen width at every size (Titan 8%). The physics tick is 120 Hz. A 21 m shark (x3) at 52 m/s is 2.5 body lengths/s vs 6 for the x0.5 one.
- **Decisions.** (1) Form length 7.0 m default, close to the Titan's 6.7 m so `whale_reach_probe`'s clearances still hold at x1; the mini-boss is 18 m, reachable with `size_mult` ~2.6. (2) Bite on `jump` by default: it also fires the controller's own jump/dodge (the Hunter has it anyway); `button` is a setting if that feels bad. (3) Camera: `FollowCamera.BODY_ZOOM_POWER` 0.75 would under-frame big bodies, so `HunterSize.frame` sets the camera's `body_follow` so the zoom is in proportion (`cam_frame` 1 = full), no change to the camera script. Must be called by whoever creates the Hunter's view and again if `size_mult` changes. (4) Hunter role name vs `FishClass.HUNTER` (the Shark class) clash: in code the mode's roles should be named differently (e.g. `Role.HUNTER` inside `WhatStinksMatch` is fine, never `FishClass.HUNTER`). (5) `UnnaturalSettings.shared()` is used for the chomp beats and shake (`chomp_*`); acceptable now, a What Stinks copy later if wanted.
- **Open issues / next worker.**
  - Not done and not needed yet: the pick card, net sync of the bite phase (`ChompKit.Bite.index()/sync()` exist for a puppet, `HunterBite` skips bites on `puppet` fish but does not call `sync`; Phase 6), murk view, sounds.
  - Each further form with a different body needs its own hitbox: the hitbox is per class, not per species. Options: another hidden class per shape, or a per-species hitbox in `FishCharacter.hitbox_size`. The 5 final bosses are 40 m-class BossMesh/SpineRig meshes (one mesh bent by a shader from the spine), which a controller cannot drive without a `SpineRig` fed from the fish's velocity/turn: Phase 5, expect it to be the long pole; the fallback is the same hidden-class approach with a model node wrapping the BossMesh.
  - `roster_probe` "every class has a zombie" already failed for Titans before this work (now also lists Monsters); `hider_looks_probe` prints `titan_view.gd:43` "Nonexistent 'int' constructor" (match_node `phase` null in that probe), unrelated. `FishCharacter.CLASSES` now has 13 entries; pickers skip it (hidden).
  - Class cache: `--import` was run; a fresh checkout needs it for the new `class_name`s.

### 2026-11-07_02:03 Phase 1 (the match with no hiding): DONE, probes pass
- **Built.** `WhatStinksMatch` (roles via `Role {PREY, HUNTER}`, `eaten`, rounds COUNTDOWN/LIVE/ROUND_OVER/OVER, one `apply_role` per round, `hunters` list so few-vs-many works, host-judged with an `authority` flag; guests/net are Phase 6), `WhatStinksSettings` (variant switch SWEEP/STOMACH; STOMACH plays as Sweep until Phase 4), `WhatStinksField` (schools placed once per round, own NatureSettings copy per school, waypoint drift, `eat_at` picks the nearest-to-bite-point fish across schools AND live prey players and calls `School.eat`), `School.eat()` (additive in `scripts/school.gd`: alarm 1, harder burst, scatter headings, reform; `_scatter_dir` kept in the resize lists; alive_mask in sync), `WhatStinksHud` (clock, prey left, role line, bite ring, Hunter countdown blackout, round and match cards), `WhatStinksBot` (Hunter bot: biggest school then nearest fish, boost far, bite near; prey bots are `WanderBot` round a school's middle).
- **Wiring.** `main.gd`: `WHAT_STINKS = "What Stinks?"` in MODES/MATCH_MODES/NATURE_MODES/MODE_ENVIRONMENTS (Ocean)/MODE_TILES, card with Variant / Start as / Hunter form pickers, `_start_what_stinks`, `_end_match`, reset, no split-screen (shares Marco's `no_split_screen`/`dropped_for_marco_polo`), signals `what_stinks_started/ended`. `mode_picker.gd`: tile in MORE and HIDDEN (shown with the Konami/SELECT modes) so the existing console_probe "no MORE row" holds; move it to PRIMARY when ready. `hex_badge.gd`: `mode_what_stinks` glyph. `debug_panel.gd`: sections `what_stinks` (tabs Match / Hunter & Bite / Schools & Arena / Scoring / Bots) and `hunter_size` (HunterSize exposed, as Phase 0 asked). `INVENTORY.md` section 8.
- **Files (new):** `scripts/what_stinks/what_stinks_{match,settings,field,hud,bot}.gd`, `tests/what_stinks_probe.{gd,tscn}`, `tests/school_eat_probe.{gd,tscn}`. **Edited:** `scripts/school.gd`, `scripts/main.gd`, `scripts/ui/mode_picker.gd`, `scripts/ui/hex_badge.gd`, `scripts/debug_panel.gd`, `tests/modes_probe.gd` (expects the two new sections).
- **Probes (headless, run after `--import`).** `school_eat_probe` 18/18 (six gone, bad/dead indices ignored, mask and a guest in step, alarm 1, survivors flung 18.9 vs 9.3 m/s for a battery, school splits to 11.7 m from 3.8 m then reforms to 4.6 m). `what_stinks_probe` 56/56 (roles, monster form, countdown hold, placed schools, bite eats a school fish and respects capacity, bite eats a prey player, round end both ways with points, round 2 bot Hunter bites by itself, local fish handed back, spectate, match over, end()). Regression: school_probe, school_sync_probe, console_probe, ui_probe, nature_probe, nature_schools_probe pass; modes_probe passes after its section list was updated. `marco_polo_probe` has 1 failure, "the debug cone draws, with one +n/s (0 surfaces, 0 labels)": not touched by this work (no Marco file edited), not checked against HEAD.
- **Decisions.** (1) Own `WhatStinksField` rather than touching NatureRun (additive-only; NatureRun respawns relative to players). (2) The mode is hidden behind SELECT in the picker (see above). (3) Bite points: bite point = mouth + forward x reach/2; bite frustum comes from `HunterBite.in_bite`; school fish and live prey compete for the capacity by distance. (4) A bot Hunter is the round's second hunter (`bot_hunter_rounds` 1) so a lone person is prey in round 2. (5) Eaten prey: hidden, frozen, collision off, spectate with left/right (no wheel yet). (6) The murk wall is the Ocean's existing `boundary_radius` (fog thickens) plus a push back (settings `wall_*`), as Marco's Ocean does.
- **Open issues / next worker.**
  - The watch wheel (hold Y, Marco's `WatchWheel`) is not wired: eaten prey cycle with left/right only. Gut-kick is Phase 8.
  - A stationary shark's bite recoils: the wind-up pulls the body back ~9 m (lunge_gain 0.35) before the strike lands, so a bite from rest lands short. Moving at speed it nets forward and the bot bites fine; the probe sets `lunge_gain` 0 to aim. Probably wants a retune (report only).
  - `prey_size` dial, murk view (`TitanView` for the Hunter), prey HUD map/arrows, Hunter pick card, sounds, `hideaway` echo shadows: not built (Phases 2/3/5).
  - Hunter-form change on the card applies from the next match start; HunterSize changes apply at each round start (`apply_role`), not live mid-round.
  - Prey bots roam one school's middle for the whole round (Phase 2 will make them join and relocate).
  - Python hung twice on the Store alias in this session (my mistake, `python`/`python3` with no uv): two stray background shells may still be alive; harmless, not killed (python MCP servers share the name).

### 2026-11-07_02:08 Phase 1 VERIFIED
- Re-ran after a fresh --import (no script errors): what_stinks_probe 56/56, school_eat_probe 0 failed, modes_probe, ui_probe, console_probe (ALL PASS), marco_polo_probe PASS (0 failures; the builder's cone-draw failure did not reproduce, so it looks flaky and is not from Phase 1), school_probe and nature_probe pass. No fixes needed. No code review beyond probes; open issues are as the builder listed.

### 2026-11-07_02:24 Phase 2 (joining): DONE, school_join_probe 104/104
- **Built.** Prey join schools by claiming a real school fish. `School` (additive in `scripts/school.gd`): `claim/claim_nearest/nearest_free/claim_of/claimed_by/is_claimed/claimed_count/claim_progress/set_lean/release_claim`, signal `claim_lost(fish)`, `startle(strength, groups, reform)` (Spook). A claim is a dict per fish index; the school strips the claimed offsets before its own sim step and re-applies them after (ease-in offset decaying over `join_ease`, plus lean in the place's frame), so a claim never changes the school's sim (checked against an unclaimed same-seed twin: every other fish identical). The school writes the fish transform + velocity every physics frame from the interpolated place; the controller never writes. A claimed place that dies (eat/batter/alive mask) drops the claim and emits `claim_lost`. `WhatStinksJoin` (new, child of the match as `game.join`): `can_join/joinable_school/eligible/join(fish, school, index)/leave/spook/reset_echo/begin_round/clear/release/prompt_for/claims()`, signals `joined/left/spooked/echo_reset`, ally markers, prey-bot auto join, cooldowns, spook charges. `WhatStinksField`: `prey_kinds` (schools of the classes prey play, `school_prey_share`), `eat_at` skips claimed school fish (the player's fish stands for it) and takes the place with the player. Match: creates `join`, `begin_round` before the schools rebuild, `shows_plate` (Hunter sees no prey plate), `end/remove_player` release. `main.gd` sets/clears `_hud.plate_filter`. HUD shows the join/leave/spook prompt. Settings group "Join" (panel tab "Join & Spook"), INVENTORY.md section 8.
- **Files.** New: `scripts/what_stinks/what_stinks_join.gd`, `tests/school_join_probe.{gd,tscn}`. Edited: `scripts/school.gd`, `what_stinks_{settings,field,match,hud}.gd`, `scripts/main.gd` (2 lines), `scripts/debug_panel.gd` (one tab), `INVENTORY.md`.
- **Probes (headless, after --import).** `school_join_probe` 104/104 (claim, ease-in no snap, lockstep, lean, release, eaten place, startle; mode part: prey-class schools, radius, class rule + join_any_class, frozen/hidden/no collisions, markers, plates, Spook once, Leave dash/loud/echo/cooldown, stick lean 1.20 m, eaten with place, bots join, new round clears). Regression pass: what_stinks_probe 56/56, school_eat_probe, school_probe, school_sync_probe, nature_schools_probe, modes_probe, ui_probe, console_probe, hunter_spike_probe 75/75.
- **Decisions.** (1) The joined player's own model hides and the school fish it stands in for shows (the "look swap"; works for join_any_class without a model swap). (2) Buttons are settings: join Jump (spec's A), leave Boost, spook Powerslide. Joining by Jump also lets the controller queue a jump that fires on leaving (not cleared; cosmetic). (3) Joined fish are `freeze` kinematic + `controls_locked`; lean is read from the PlayerInput stick by the join system, not the controller. (4) Joining allowed in COUNTDOWN and LIVE; Spook LIVE only. (5) Prey bots join as soon as a school is in reach and never leave (Phase 7 does relocate). (6) Echo is only a placeholder (`join.echo`, `echo_reset` signal): Phase 3 owns it; `leave_noise` is only stored/counted (`loud_leaves`, `left(fish, loud)`), Phase 3 should feed NoiseMeter from it. (7) Round-start `join.begin_round` runs before `field.build` so fish are released before the schools are freed.
- **Open / next worker.** Net (Phase 6): the host calls `join(fish, school, index)`; a guest replays `joined`/`left`/`spooked` with the host's index, `join.claims()` snapshots for late joiners; remote players' puppet fish are written by both the school and the net on the host, so a guest/host puppet must skip net transform while joined. School `startle` uses the school rng (host-only; send the event). Ally markers are plain spheres. Prey HUD map / echo ring not built. Name plates for the Hunter are hidden for all prey, loners too (spec).

### 2026-11-07_02:33 Phase 2 VERIFIED
- Fresh --import: no script errors. Re-ran school_join_probe 104/104, what_stinks_probe 56/56, school_eat_probe, hunter_spike_probe 75/75, modes, ui, console, marco_polo (0 failures), school_sync, nature_schools, nature: all pass. school_probe failed once ("a bigger spread loosens it", its known ~1 in 10 flake) and passed on rerun. Read what_stinks_join.gd against spec section 5; no bugs found, no fixes made. Builder's open issues (net skip of puppet transform while joined, spook event to guests, echo/leave_noise for Phase 3) stand.

### 2026-11-07_02:46 Phase 3 (visibility): DONE, echo_probe 91/91
- **Built.** `WhatStinksEcho` (child of the match as `game.echo`): per-prey NoiseMeter (Marco's `MarcoPoloSettings.shared()` noise values), per-Hunter echo dict, cone (half angle, range and near x size^`echo_size_exp`), `build_rate`, smear, blend/shadow/sniff multipliers, decay, Click (auto on cooldown or button), Sniff (scales speed_scale/top_speed_scale/boost_scale, restored on release and at round start), `exposure(hunter, prey) = max(noise, echo)`, `forced` overrides for probes/shots, mirrors into `join.echo`, reacts to `join.echo_reset/left/joined`. `WhatStinksShadows` (kelp stands + rock arches from ReefKit, spots in group `ws_echo_shadow`, seeded, rebuilt each round). `WhatStinksLooks extends HiderLooks` (binds to the match without Marco's scan/murk/wake/card; joined player's model is turned back on in the Hunter's view only so the reveal builds on the claimed slot; `hunter_blind` off disables). Match: `echo/shadows/looks`, `is_live_hider/seekers/local_exposure/max_exposure`, echo.begin_round per round. HUD: prey map + noise/echo rings, Hunter Click/Sniff rings. Settings group "Echo" (+ panel tab), INVENTORY section 8.
- **Files.** New: `scripts/what_stinks/what_stinks_{echo,shadows,looks}.gd`, `tests/echo_probe.{gd,tscn}`, `tests/echo_shots.{gd,tscn}`. Edited: `what_stinks_{settings,match,hud}.gd`, `scripts/debug_panel.gd` (one tab), `INVENTORY.md`.
- **Probes.** `echo_probe` 91/91 (3 consecutive runs; one earlier flake from timing of process frames, fixed in the probe). Regression: what_stinks_probe 56/56, school_join_probe 104/104, school_eat_probe, modes, ui, hunter_spike_probe 75/75, hider_looks_probe (prints the known titan_view `int` constructor errors, passes). marco_polo_probe failed once (1 failure) and passed twice on rerun (known flake). `echo_shots` (needs a window) run: loner, school, shadows and prey_hud sheets looked at; layers, shadows, map and rings read correctly, but the school sheet is wide-framed so the faint skeleton on the slot is hard to pick out (reframe closer if wanted).
- **Time to seen (spec defaults, not tuned).** Still loner at 5 m: skeleton 0.62 s, skin (0.65) 5.01 s, full 7.7 s. Middle speed (4 m/s): skin 14.6 s. Fast (24 m/s, echo alone): 20 s. Loner at 35 m: 10 s. School member at 6 m: skeleton 6.2 s, skin 50 s (10.0x the loner).
- **Decisions.** (1) Spec contradiction: "smear_floor 0.25 at smear_speed" vs "fast speed doesn't build": followed the floor (a fast loner still builds at 0.25, noise also shows it). (2) Middle speed ~15 s needed a curve: `smear_curve` 3 (setting). (3) A joined player counts as still for smear (it moves with the crowd); its only slowdown is blend_echo_mult. (4) Shadow: build x0.2 AND decay applies, so at defaults a loner in a shadow is never revealed by echo (noise and Click x0.2 still can); raise `shadow_mult` above 0.77 to change that. (5) Click is auto by default (Titan auto Marco); button air_roll when auto is off. (6) Sniff is on powerslide, which is also the controller's handbrake, so it slows twice; revisit in play-test. (7) Layer bands are Marco's (`MarcoPoloSettings.shared()` layer_*), not duplicated. (8) Echo/looks are host/local only; no net.
- **Open / next worker.** Net (Phase 6): sync echo/exposure to guests (guest Hunter needs `local_exposure`), click events, sniff state, shadows from the seed, noise bursts from a guest's own fish. Hunter bot does not use echo or Click yet (Phase 7). A prey bot's WanderBot noise is real, so bots show as loners to the Hunter. The Hunter's view of eaten/loners is blind from the first frame (loners invisible until noise/echo); that is the intent but changes how Phase 1 probes see prey. Shadows float (the Ocean has no floor). Ball._fish_contact script error when Main is freed in echo_shots (pre-existing teardown, not from this work).

### 2026-11-07_02:56 Phase 3 VERIFIED
- Fresh --import clean. Re-ran: echo_probe 91/91, what_stinks_probe 56/56, school_join_probe 104/104, school_eat_probe 18/18, hunter_spike_probe 75/75, modes, ui, console (ALL PASS), marco_polo (0 failures this run), nature, nature_schools: all pass. hider_looks_probe exits 0 with only the known titan_view int-constructor errors. No fixes needed; builder's open issues (Sniff on powerslide double slow, shadow never reveals loner by echo alone at defaults, net/bot work for Phases 6/7) stand.

### 2026-11-07_03:05 Phase 4 (Upset Stomach): DONE, stomach_probe 66/66
- **Built.** `WhatStinksMatch` (Upset Stomach, all additive): `satiation`/`queasy` per Hunter, `_feed` (school fish worth `mass x satiation_per_fish`), hunger decay in `_stomach_step`, `_spit` (prey in the bite is flung, dazed: boost off + `join.cooldown`, tally `spit_points`; the Hunter loses satiation, gains queasy, bite cooldown `spit_cooldown`), `_hurl` (held for the round; prey win when every Hunter has), `_end_round(hunters_won, reason)` with reasons `all_eaten/clock/full/hurled/hungry` plus `spat/satiation/queasy` in `last_results`, signals `spat/hurled/fed`, getters `stomach()/satiation_share/queasy_share/is_dazed`. In Stomach nobody is ever eaten, so `_check_round_end` no longer ends on "no prey" there. `WhatStinksField`: `eat_at` returns `"mass"` (new `fish_mass(school)`: hitbox length / `satiation_ref_length` ^ exp, x fish_scale), `steady` respawn (regrow `respawn_batch` per `respawn_every` up to the school's first size, via `fish_per_school`; wiped school replaced after `respawn_school_delay` away from threats; meta `ws_full`). Settings group "Stomach" (+ panel tab), HUD belly/queasy bars (everyone sees the first Hunter's), headline/role line/round card by variant, `WhatStinksBot` (`_is_stinker` by echo exposure >= `hunter_bot_avoid_exposure`: not a target, bite held while one is in the frustum), prey bots wait at the third of schools nearest the Hunter's start (`prey_bot_baits`). The match card's Variant option already existed (Phase 1) and now has an effect. INVENTORY section 8 updated.
- **Files.** Edited: `what_stinks_{match,field,settings,hud,bot}.gd`, `scripts/debug_panel.gd` (one tab), `INVENTORY.md`. New: `tests/stomach_probe.{gd,tscn}`.
- **Probes (headless, after --import).** `stomach_probe` 66/66 (start, decay, fish worth by size, bite feeds, spit on a loner and on a joined prey, daze wears off, hurl, full belly, hungry clock, regrow + replace + distance from Hunter, Sweep unchanged, bots, HUD). Regression all pass: what_stinks 56/56, school_join 104/104, school_eat, echo 91/91, modes, ui, console, hunter_spike 75/75.
- **Decisions.** (1) Spit does not reset echo beyond what leaving a school already does. (2) With several Hunters: a full belly of any Hunter ends the round for the Hunters; hurled Hunters sit out and the prey win only when all have hurled. (3) The Hunter's score is satiation earned (clamped at the bar), spits and hunger don't take it back. (4) The `brave_points` kicker from spec 6 is not built (neither variant). (5) Respawn grows `fish_per_school`, so dead entries accumulate in a school's arrays over a long round (bounded by round length / respawn_every x batch). (6) Prey bots stay joined as in Phase 2; a spat bot just resumes its wander and re-joins after the daze. (7) Daze is host-side only (no net).
- **Numbers (defaults, not tuned).** Belly 100, start 25, decay 0.5/s, a typical fish ~4, so a full belly needs about 50 fish in 3 min if nobody is spat; each spit costs 15 satiation (~4 fish) and a third of the queasy bar. Not simulated against bots yet (Phase 7).
- **Open / next worker.** Net (Phase 6): satiation/queasy/daze/spat/hurled events and the school regrow (`fish_per_school` growth) need to reach guests (guest schools resize from settings, so send the new count or the mask); the daze must also hold on a guest's puppet. Hunter bot still has no echo/Click use (Phase 7). No sounds for the spit/hurl. A spat prey is flung with `linear_velocity` only (a joined fish's detach order was checked by the probe).

### 2026-11-07_03:11 Phase 4 VERIFIED
- Re-ran after --import: stomach_probe 66/66, what_stinks 56/56, school_join 104/104, school_eat, echo 91/91, modes, ui, console (ALL PASS), marco_polo_probe PASS, hunter_spike 75/75, nature_battered_fish. Project loads headless with no script errors.
- Reviewed _spit/_hurl/_feed/_stomach_step/_end_round against spec 1b and 6: matches. No fixes needed. Open items are the builder's (net sync for Phase 6, brave_points not built).

### 2026-11-07_03:58 Phase 6 (online): DONE, what_stinks_net.sh passes (8 of 8 consecutive runs after the last fix)
- **Built.** `WhatStinksNet` (`scripts/net/what_stinks_net.gd`, CoopSession's child "WhatStinks", pattern of MarcoPoloNet). The host judges everything and sends: each round (per guest its own place; the Hunters, ocean seed, the schools as [id, seed, class, count, at, heading]), phase to LIVE, round results, match end, each bite (`bite_result`: school id -> [indices, school rng state] plus the prey players, so a guest eats the same fish and the survivors scatter the same way), spits (fling + daze), hurls, feeding, Clicks, Sniffs, schools added/removed, alive masks (2 Hz, grows a regrown school), school leaders (10 Hz), bots (negative ids, 30 Hz), clocks plus Hunters' satiation/queasy bars (4 Hz), and per guest a view packet (10 Hz): a Hunter gets exposures of live prey and its Click cooldown, a prey only its own exposure, echo and noise. Join/leave/spook events go to PREY peers only (a Hunter guest is never told who joined; it gets only `_ws_startled(school, rng state)`, the same scatter without a name). Guest to host: join/leave/spook requests (host picks/validates the place, assigns the claim), bite start (jaws, relayed to others) and bite landing (mouth + heading; host uses its own reach/radius/capacity for that Hunter and rate-limits), held-button mask (Click/Sniff), noise bursts. Late joiners get `world()` (round state, schools with masks, claims, bars, eaten).
- **Shared-file edits (additive).** `coop_session.gd` (wsm/what_stinks_net, hook/unhook/tick/world/welcome branches, "what_stinks" and "hunter_size" in TUNING_SECTIONS), `main.gd` (host_/guest_/solo_what_stinks), `what_stinks_match.gd` (apply_net_* guest side, judge_net_bite/_judge_bite, signals local_bite/bite_started/bite_result/bite_penalty/spit_applied, `_begin_round` takes net seed + schools, round_places, last_seed, guest clocks/daze), `what_stinks_field.gd` (authority flag so a guest's field only follows, build_list, school_by_id/remove_school, school_added/removed, eat_taken, add_school force_id), `what_stinks_join.gd` (requested signal, join/spook `told` args, spook rng state), `what_stinks_echo.gd` (guest step, net_view/net rings, apply_net_*, add_noise, puppet buttons via meta ws_buttons, freed-fish crash in the meters loop fixed), `hunter_bite.gd` (started signal, net_start, static in_frustum). `what_stinks_match.gd` is CRLF; kept CRLF.
- **Files new.** `scripts/net/what_stinks_net.gd`, `tests/what_stinks_net_peer.{gd,tscn}`, `tests/what_stinks_net.sh` (port 24733).
- **Probes.** `tests/what_stinks_net.sh <godot console exe>`: host + guest a (60 ms lag, jitter, 2% loss) + guest b (30 ms) + 4 host bots, ~50 checks per process: late join world (same schools/ids/alive), round with a hunting on every machine, privacy of the view packets, b joins a school (host-assigned place, lockstep 0.02-0.17 m, the Hunter never told), Spook (host judged, b's charges, Hunter sees the school bolt), Click and Sniff of a guest Hunter, a's bite ate b (joined) and school fish identically on all machines, ROUND_OVER totals/reason, Upset Stomach (a bite spat b: dazed, no boost, unfrozen on b's machine; a's bars), a replacement school and a regrown school appear on the guests, host leaving puts guests in solo What Stinks?. Regression (same suite run): marco_polo_net, coop_net, unnatural_net all pass; what_stinks_probe 56/56, school_join 104/104, school_eat, echo 91/91, hunter_spike 75/75, school_sync, nature_schools, nature, modes, ui, console, marco_polo probes pass.
- **Decisions.** (1) A guest's own fish is its own on its machine and the host holds a puppet of it; a joined puppet is written by the school on both, never by the net (CoopSession tick skips joined puppets). (2) Reported landing, not position: the guest sends mouth and heading, the host checks it is near the puppet and takes capacity/reach/radius from its own form and size. (3) Scatter after an eat or a spook is made the same on every machine by sending the school's rng state with the event; before that, a Spook then a bite made a guest aim at a school that had bolted differently on the host (one flake in ~6 runs, gone after). (4) Hunters get `_ws_startled` (no name), prey the named `_ws_spooked`. (5) The `what_stinks` and `hunter_size` panel sections are host-tuned in a session (locked on guests), size_mult/form/variant also ride in each round message.
- **Open issues / next worker.**
  - `stomach_probe` is flaky on its own: "away from the Hunter (NN m)" (random replacement-school placement, 2 of 9 runs failed it) and once a group of joined-prey-spat checks (bot positions). Not from this work (those code paths unchanged in single player) but not verified against a clean checkout.
  - Not synced: brave_points (not built), the prey's HUD map/ally markers beyond join events, murk view, a guest Hunter's bite uses its own cooldown plus the host's penalty message (a lost reliable message cannot happen, but the penalty arrives a round trip late), host-bot eaten cleanup on the guests relies on the bite message.
  - A guest's bite aim is its own view of the schools; positions differ a little between machines (each runs its own school sim following the host's leader), so bites on fast-moving schools can land a different set; the host's set is the truth.
  - Not run: a 4-Hunter conversion-style stress (the spec's "4-hunter" item; hunters_per_round > 1 is untested online), perf of the net (no bench), Steam backend (off).

### 2026-11-07_04:14 Phase 6 (online): VERIFIED
- Re-ran: what_stinks_net.sh 8 times (7 pass, 1 flake: a's bite took 5 school fish but not b's place; the guest aims at its own view of a moving school, so the host's set differs; known/inherent, test-only), marco_polo_net, coop_net, unnatural_net pass; what_stinks 56/56, school_join 104, echo 91, hunter_spike 75, school_eat, school_sync, nature, nature_schools, modes, ui, console, marco_polo probes pass. `--import` and all probes load with no script errors.
- Fix: stomach_probe "away from the Hunter" failed 2 of 3 runs because the default respawn_school_gap (80 m) cannot be kept in the probe's 90 m arena; the probe now sets respawn_school_gap = 30. 4 of 4 runs pass after.
- Still not done (as the builder said): 4-Hunter online stress, net perf bench, prey map/ally markers online.

### 2026-11-07_04:30 Phase 5 (setup: registry, card, size, sheet template): DONE, hunter_forms_probe 224/224
- **Built.** `HunterForms` registry (`scripts/what_stinks/hunter_forms.gd`): 11 keys in card order (drowned_shark, humpback, orca, beluga, sperm, blue, king_of_herrings, gulper_mother, whale_fall (not ready, dropped), lamprey_queen, fallen_angel), each preloading its own file `scripts/what_stinks/forms/<key>.gd` (static `ready()`, `sheet()`, `dress(fish, sheet)`). API: `ready_keys()`, `is_ready`, `playable(key)` (falls back to the Shark), `sheet(key)` (defaults filled, plus key/ready), `name_of`, `dress`. `HunterForm.sheet` now reads the registry (the `FORMS` const is gone; `SHARK`/`HUMPBACK` stay as consts the two ready form files return). **Each remaining form worker edits only its own forms/<key>.gd and flips `ready()`; nobody edits the registry, settings or card.**
- **Card and settings.** The match card's Hunter pick lists only ready forms (Shark, Humpback today) and a new Size pick (0.5x..10x, `WhatStinksSettings.SIZE_CHOICES`, plus the current value if it is not one of them) sets `HunterSize.size_mult`. `WhatStinksSettings.form` enum lists all 11 keys (panel); `form_sheet()` plays an unready pick as the Shark. `FORM_KEYS` is gone. Online: form/size already ride the round message; both peers share the registry.
- **Size fully wired.** The schools' alarm range now follows the biggest Hunter's size (`WhatStinksField.set_alarm_scale`, replaces the never-called `set_alarm_range`; new/regrown schools take it; `HunterSize.alarm_exp`). Camera: `HunterSize.frame` (size framing + the sheet's `cam` factors) is called when the local Hunter is made each round, as before; probe checks body_follow and the cam factor. `sight_exp` still has no consumer (no Hunter murk view yet; the echo cone uses `echo_size_exp`).
- **Hook.** `HunterForms.dress` is called from `_become_hunter` after `size.apply` and before the bite is made, so a form that swaps the model is picked up by `HunterBite.setup`.
- **Sheet template.** `hunter_forms.md` (keys, registry contract, what size moves, ready checklist, form table). INVENTORY.md section 8 updated.
- **Files.** New: hunter_forms.gd, forms/*.gd (11), hunter_forms.md, tests/hunter_forms_probe.{gd,tscn}. Edited: hunter_form.gd, what_stinks_settings.gd, what_stinks_field.gd, what_stinks_match.gd (3 additive lines each), scripts/main.gd (card), INVENTORY.md.
- **Probes (headless, after --import).** `hunter_forms_probe` 224/224 (registry: 11 keys/files/sheets/species, ready lists, fallback; every ready form at 0.5/1/3 for body, hitbox, model extent, swim, bite, frustum, cooldown, camera; then through a real match per ready form at 0.5 and 3: card lists the ready forms and size, Hunter wears the form's class/species/scale, bite reach/capacity, school alarm scale and range, camera body_follow; a form cam factor moves the camera). Regression: hunter_spike 75/75, what_stinks 56/56, stomach 66/66, modes, ui, school_join, what_stinks_net.sh all pass.
- **Forced-ready check (not left on).** With orca/beluga/sperm/blue temporarily ready the probe passed 548/548: the four other whales already play mechanically as Titan species (the sheet numbers are first guesses: lengths 3.6/2.2/7.7/12.0 m, bite scaled with length). They are left `ready() = false` because nobody has looked at them (shots, camera, bite feel); a worker should check and flip them. Numbers are identical across forms (same speed/accel/turn defaults): 21.2/30.0/52.0 m/s, turn 3.66/2.59/1.50 rad/s at 0.5/1/3x.
- **Decisions.** (1) "Pick card" is the match card's Hunter pick (the existing UI that picks the form); no in-countdown per-Hunter card was built, since a per-fish pick would need net sync of the pick. (2) The match card's picks only survive if set after entering the mode: `set_mode` restores that mode's saved tuning snapshot (`_use_nature_tuning`), which the probe had to respect. (3) Bosses' stub sheets carry only a name (class MONSTER, defaults for the rest); the five need their own hidden class/box or per-species hitbox plus a SpineRig-fed model in `dress` (long pole, unchanged from Phase 0).
- **Open / next worker.** The five boss forms and the four whales: fill the sheet, build the model/rig in `dress`, run `hunter_forms_probe` (it picks up every ready form automatically), look at `--shots=DIR`, flip `ready()`. Per-form bite flavour (cone shape, wind-up) is only the sheet's numbers so far; no signature moves (Tail Slap etc.). No in-round form pick. No sounds per form.

### 2026-11-07_05:20 Phase 5 (the five boss forms and the Humpback sheet): DONE, 7 of 11 forms ready
Logged by the wrap-up worker for the form workers (they could not write the log).
- **Humpback** (`forms/humpback.gd`, own sheet dict, no shared file touched): Tail Slap shape reach 2.2 m, far half width 2.6 m (~100 deg cone), capacity 6, wind-up 0.95 s, rest 2.4 s; speed x1.15, accel x0.6, turn x0.5; cam (1.2, 1.1). No real slap animation (the jaw gape and lunge are shared in HunterBite/HunterJaw); a slap from the tail would need a form-supplied bite origin in HunterBite.
- **Gulper Mother** (registry file is `forms/gulper_mother.gd`; extra `gulper_model/rig/jaw.gd`): `GulperBoss._build_look` rebuilt for a controller, 9 m, 48-segment spine trailing turns, Swallow bite 6.0/4.0/8, 1.0 s, 2.5 s; speed 1.15, accel 0.6, turn 0.5; cam (1.15, 1.1). Not built: the pull of fish toward the mouth (needs a School call), belly lumps. `gulper_form_probe` 79/79.
- **King of Herrings** (`forms/king_of_herrings.gd`, `king_rig.gd`, `king_jaw.gd`): BloodLeviathan mesh rebuilt without the Boss node, 16 m (boss is ~109 m), lies along the trail the head leaves; Coil sweep 5.5/4.5/7 (39 deg half angle), 1.0 s, 2.8 s; cam (0.8, 1.35) by eye only (a speck end-on in the follow shot, needs a play-test). Hitbox is ~5.3 x 7.4 m against a ~2.6 m body. Only `sound_chomp` has a consumer. No coil hold/squeeze. `king_probe` 81/81.
- **Lamprey Queen** (`forms/lamprey_queen.gd`, `lamprey_rig.gd`, `lamprey_jaw.gd`): 14 m, Corkscrew latch reach 3.2 m, radius 1.0 m, capacity 1, wind-up 0.8 s, rest 3.0 s, then a roll at `lamprey_spin` for `latch_s` 1.1 s; cam (0.9, 1.3). The latch is visual only (no pin or drain). Hitbox ~4.7 m wide against a ~1.7 m body. `lamprey_form_probe` 86/86.
- **Fallen Angel** (`forms/fallen_angel.gd`, `angel_model/rig/jaw.gd`): glass body, crown of six tentacles that opens and flushes orange on the wind-up, lock-on ring at the cone's end; 10 m, speed 1.2, accel 0.65, turn 0.7; Lock-on reach 6.5, far half width 1.3 (~11 deg), capacity 2, wind-up 1.2 s, rest 2.2 s; cam (1.1, 1.15). "A fish it has watched" is not built (needs a lock state in HunterBite or the field). `boss/angel_lock` is an invented sound id. The windowed --shots run crashed with a C++ backtrace at exit after printing results (cause not investigated). `angel_form_probe` 88/88.
- **Common to all boss forms**: hidden class MONSTER (the shark's box scaled, not form-shaped), `dress` is safe to run twice, a size change rebuilds the rig, sounds are stand-in ids with no consumer yet, no Hunter murk view (`sight_exp` has no consumer). `hunter_forms_probe` never calls `dress` in its per-form section, so each form has its own probe for the dressed body.
- (A sixth boss form, Whale Fall, was built here and later dropped; see Progress.)
- **Docs.** `hunter_forms.md` has a section per form; `INVENTORY.md` section 8 lists forms and bite shapes; `tools/gen_setting_docs.gd` now includes `what_stinks` and `hunter_size` (regenerated `scripts/ui/setting_docs.gd`, +142 lines).

### 2026-11-07_05:20 FINAL SUMMARY (overnight run, phases 0-4, 6, and 5 as far as it went; superseded where later entries say so: 6 forms are ready now, not 7, and the Size pick is gone)
**Built.** A playable What Stinks? mode: one Hunter (a monster form, person or bot) against prey hiding in an Ocean of fish schools. Phase 0 hidden class MONSTER + `HunterSize`; Phase 1 `WhatStinksMatch` (rounds, roles, Clean Sweep), `HunterBite`, `School.eat`; Phase 2 joining a school (claim, ease-in, lockstep, lean, Leave, Spook, ally markers); Phase 3 echo (cone, noise, shadows, Click, Sniff, reveal layers); Phase 4 Upset Stomach (belly, spit, queasy, hurl, school respawn, scoring); Phase 6 online (`WhatStinksNet`); Phase 5 11-form registry, card with Size pick, 7 forms ready.
**Probes (this wrap-up, fresh --import, no script errors in the new code).** what_stinks 56/56, hunter_spike 75/75, hunter_forms 629/629, echo 91/91, stomach 66/66, school_join 104/104 (failed once on "same velocity (2.84 m/s apart)", passed on two reruns: flake), school_eat, school_sync, hunter_bot, gulper_form 79, king 81, lamprey_form 86, angel_form 88, class_species, skins_probe --class=titan, modes, ui, console, marco_polo (0 failures), nature, nature_schools, nature_battered_fish, nature_score. Net scripts: what_stinks_net.sh, marco_polo_net.sh, coop_net.sh, unnatural_net.sh all passed (what_stinks_net.sh flakes about 1 in 8: a guest's bite on a moving school can take another set of fish; the host's is the truth).
**Failing, not from this work.** roster_probe "every class has a zombie" (missing Titans, and Monsters now too; Titans already failed before). hider_looks_probe prints repeated `titan_view.gd:43` "Nonexistent int constructor" script errors (168 lines) but exits 0; it predates this work.
**Sim/timing numbers.** None: the bot sim and balance report (Phase 7) were not built, so there are no win rates or round times. The settings defaults (round_time 180 s, school_count 14, satiation numbers, echo build 0.13/s) are first guesses, untested against bots or people. Open item, not tuned.
**Judgment calls.** Hunter forms are monsters on a normal FishController (hidden class MONSTER), not AI Boss nodes (Boss is welded to UnnaturalRun). Pick card = the match card's Hunter pick (no in-countdown per-Hunter pick, it would need net sync). Registry file names are the form keys (`gulper_mother.gd`, `lamprey_queen.gd`, `fallen_angel.gd`, `king_of_herrings.gd`). Added `FishController.rl_turn_scale` because `turn_scale` does nothing off a surface under `rl_air_control` (Marco's `whale_turn_scale` and Unnatural's Nimble have likely been inert in open water; not changed). stomach_probe sets `respawn_school_gap` 30 for its small arena. Orca, Beluga, Sperm and Blue left not ready.
**Known issues.** Hitbox is the shark's box for every MONSTER form (fat for King, Lamprey, Angel). Camera factors for the boss forms are by eye from free-camera shots, never play-tested (King looks tiny end-on). Lamprey latch, angel watch and gulper pull have visuals/shapes only, no gameplay effect. No Hunter murk view (`sight_exp` unused), no per-form sounds, no per-form signature moves. Sniff on powerslide also handbrakes (double slow). At shadow_mult 0.2 a loner in a shadow is never revealed by echo alone. Online: echo/Click/Sniff/shadows not synced to guests, guest noise bursts not sent to host, brave_points not built, 4-Hunter stress and net perf bench not done, Steam off. Bot hunter does not use echo or Click.
**Play first.** Build `builds/windows/FishPlayground.exe` (05:09): picker MORE row (hold SELECT to show hidden modes) -> What Stinks?; play the Shark at size 1, then the Humpback and the boss forms from the match card (try Size 0.5x, 3x, 10x), Upset Stomach variant, join a school as prey, watch the echo reveal as prey vs Hunter. Check the camera and hitbox feel on King, Lamprey, Angel first.
**Not done.** Phase 7 (bots, balance report, `what_stinks_sim`), Phase 8 polish; forms Orca, Beluga, Sperm, Blue (need a visual/camera review then flip `ready()`); the items under Known issues.

### 2026-11-07_09:30 Instant chomp (bite_snap): the rigs and probes follow
**Feedback.** The Hunter's bite felt wrong: a press should be an instant big chomp, not a wind-up into a charge. `HunterBite.snap` (setting `bite_snap`, Bite group, default on) goes straight to ChompKit STRIKE with the jaws wide: contact (`chomped`) lands about 0.06 s after the press and the body gets no lunge. `bite_snap` off keeps the old `bite_wind` chomp. Cooldown (`bite_every`) is the only limiter now; no numbers retuned.
**What depended on the wind-up and what changed.** HUD bite ring, bot and net sync did not (bot uses `busy()`/cooldown; net `net_start()` goes through `_begin()`, so guests see the snap too). Rigs did: King and Lamprey skin `warn` pulse only ran while `winding()`, now they also flash 0.22 s when a bite lands. Gulper pouch gape and suction followed the slow open, now the pouch balloons to full and the suction streams 0.3 s on landing (gape held 0.15 s). Lamprey disc flares wide on landing and then clamps. Fallen Angel crown and lock-on ring jump to full on landing (the existing lash). Edits are in each form's own rig file under `scripts/what_stinks/forms/`.
**Tests.** `what_stinks_probe` gained "snap chomp vs wind-up" (snap: lands 0.06 s after press, no lunge; snap off: lands at 0.82 s, lunges). `gulper_form_probe` now names its bite node "HunterBite" like the match (the rig finds it by name). `hunter_forms_probe` takes `--only=KEY` and its jaw shot also fires mid-strike under snap.

### 2026-11-07_09:33 Cameras: follow cam + school lock-on (user play-test: only one fixed camera)
- **Root cause.** The match only ever set `target`, `body_follow` and `extra_*` on the shared FollowCamera. It never turned on the follow cam (`UnnaturalRun.steady_camera`, `steady_heading`) that Marco Polo and Unnatural switch on, so the camera kept the arenas' chase mode, which holds its heading in open water ("RL's hold in the air": `_follows_rotation` is false for a fish that is not on a surface). Measured by what_stinks_camera_probe: the old view turned 0 of 90 degrees when the Hunter turned (90 degrees off its heading after 2.5 s); the new one turns 87 and ends 14 off. No ball cam, wheel or `hold_opens_wheel` was wired for this mode either (Nature wires them in LocalCoop._wire).
- **Built.** `WhatStinksCam` (scripts/what_stinks/what_stinks_cam.gd, child of the match as `lock_cam`): every frame applies the follow cam settings (live from the Unnatural panel, Settle style) and, for the Hunter, `HunterSize.frame` on top. While a round is LIVE and the local fish is not eaten it offers the lock-on: `hold_opens_wheel`, a TargetWheel (one slice per live school), `ball` = the locked school's `centre` (School._aim_point). Tap = toggle + nearest-ahead pick, hold = wheel, stick + release = lock, stick alone = unchanged, wiped-out school = re-pick (or nothing: plain follow cam). It answers targets()/focus_of()/set_focus() like NatureRun. Torn down (wheel freed, signals disconnected, ball/ball_cam/hold flags reset, transition speed restored) on round end, countdown, role swap, eaten, `lock_on` off and `end()` (mode exit, which also removes the follow cam settings). Prey get the same (`lock_on_prey`), minus the school they joined. Eaten-prey spectating untouched.
- **Small additive changes elsewhere.** TargetWheel: `run` and `settings` are untyped Objects (NatureRun/NatureSettings still the defaults). FollowCamera: the survivor-cam branch of the ball cam button now clears the hold counter (a hold a mode ended mid-press toggled ball cam on later; found by the probe). Nature unchanged (target_wheel_probe, nature_probe, nature_schools_probe pass).
- **Settings** (WhatStinksSettings group Camera, panel tab Camera, setting_docs regenerated): lock_on, lock_on_prey, wheel_hold_time 0.3, school_arrows, lock_behind_cost 1.5, lock_range 0, lock_swing 1.2.
- **Controls.** Ball cam button (Y by default): tap = lock-on on/off (looks at the nearest school ahead as it goes on), hold 0.3 s = school wheel, right stick/IJKL picks, release locks on. Y no longer swaps follow/free cam while a round is live (it does in countdown, round over and spectating).
- **Probes/tools.** tests/what_stinks_camera_probe (all pass, incl. body + school in frame for Shark, King, Gulper Mother at 0.5x/1x/3x/10x); tests/what_stinks_cam_shots (windowed: follow, post-turn, lock-on and wheel frames per form/size). Eyeballed: Shark 1x and King 1x read well. At 10x body and school are in frame by projection but sit in the murk and the frame is mostly dark water (framing is HunterSize's, not retuned).
- **Open.** No aim assist toward the locked school (not asked). The controls hint line does not mention lock-on. Online guests use the same code on the host's schools (only what_stinks_net.sh covers it).

### 2026-11-07 (day, reconstructed from commits and the working tree) Lock-on bite, rams, callouts, size lock
Entries below were written afterwards by reading the code, not by the workers; probe counts were not re-run for this update.
- **Lock-on bite** (`lock_bite`, `lock_bite_mult` 3.0, in `WhatStinksMatch._locked_bite`): a bite while locked on a school takes its fish from that school alone, up to capacity x `lock_bite_mult` x the line-up, so a locked, well-aimed bite is a big one. Today's fix: the direction to the school is measured from the Hunter's body, not the mouth. `tests/what_stinks_lock_bite_probe` covers it.
- **Body rams** (`ram`, `ram_speed` 14, `ram_capacity_mult` 1.5, `ram_cooldown` 0.4, `ram_width` 0.5; `_ram_step`): a Hunter at ram speed (x its size's speed) takes what its front touches like a bite, with no chew delay. Uncommitted.
- **Callouts**: each fish taken (bite or ram) feeds a per-Hunter Nature `NatureScore` chain and spree; the new `callout` signal drives the HUD: a splash for the local Hunter from a double up, and a five-line feed ("ATE name", CHOMP / BIG CHOMP / RAMMED, sprees) for everyone. Uncommitted.
- **Size locked at 0.5x** (`HunterSize.MATCH_SIZE`): play-test said every form feels right at 0.5x and worse bigger. The Size pick is removed from the setup screen and the old match card; the panel's `size_mult` still moves it for debugging.
- **Roll and camera** (uncommitted): `SpineRig` gained `head_up`/`head_back` so a boss-form body rolls with the Hunter instead of keeping the world's up (the King and Lamprey rigs were edited to feed them; I did not check the others); form sheets gained `cam_settle` (Angel 0.65) which slows the follow cam's Settle rate so a lively stride doesn't wobble the view. New untracked probes: `hunter_roll_probe`, `hunter_cam_wiggle_probe`.
- **Open.** Not logged by the workers: whether the lock-on bite and ram numbers are good (never simulated, play-test first).

### 2026-11-07_13:37 Mode setup screen (commit b77cc2b, "half-baked")
- Every mode now opens a **setup screen** (rail + two-tier hero, `scripts/ui/mode_setup.gd`, `mode_setups.gd`) from the picker, replacing the variant pop-up and the match card's picks. For What Stinks?: Variant, Start as (Hunter/Prey), and the role's character (a Hunter picks one of the ready forms; prey wear their last prey fish, saved per role in `role_characters.gd`). The pause menu has Change Character; a local joiner gets a pad-only setup screen. `tests/mode_setup_probe` updated for What Stinks?. Open items are listed in the mode-setup notes (role swaps mid-match don't switch to the other role's remembered fish; online guests get no join screen).

### 2026-11-07_15:11 Drowned Shark jaw and chomp, Whale Fall off (commit 3c04b15)
- The Hunter shark and the boss share `HunterJaw`, rebuilt so the lower jaw is the body's own underside swung on a hinge by `shark_skin.gdshader`; `ChompKit.Bite` gained chomp cues, smear and jaw fling; dark red eyes. Sounds: `boss/shark_bite_wind`, `shark_jaw_open`, `shark_snap` (catalog rows; the user records them). The Hunter-form shark does not get the smear yet (the controller owns its scale).
- **Whale Fall disabled** everywhere (boss and Hunter form), see Progress.

### 2026-11-07_23:30 Phase 7 (bots and balance report): DONE, numbers in what_stinks_report.md (nothing tuned)
- **Prey bot** (`WhatStinksPreyBot`, `scripts/what_stinks/what_stinks_prey_bot.gd`, extends `WanderBot`; the match makes it in place of the WanderBot): rushes for the school nearest its home (full throttle, boost beyond 15 m; the join system takes it in), wanders only with no school to go to; joined, it watches `echo.max_exposure` and, once a Hunter has read it at least `prey_bot_exposure` 0.45 for `prey_bot_patience` 2.5 s, leaves (loud, rejoin cooldown) and swims for another school of its class that is far from the Hunter, never rejoining the one it left (`WhatStinksJoin` asks `accepts()`). Not while baiting in Upset Stomach. Settings (Bots group): `prey_bot_exposure`, `prey_bot_patience`.
- **Hunter bot** (`WhatStinksBot`): in Clean Sweep it reads the echo like a person (a prey with exposure at least `hunter_bot_read_exposure` 0.25 counts as half as far; an unseen loner is no target), Clicks when the Click is ready and nothing is readable (`hunter_bot_click`), sniffs while it works a school it found no prey in (`hunter_bot_sniff_s` 4 per school, then another school; Clean Sweep only). Held presses: see the bug in the two-stage log (the bot never held a bite until today). Bite styles' `bot_plan`s per two-stage-attack.md Phase 6.
- **`tests/what_stinks_sim`** (+ `.tscn`): bots only (the player's fish too), per form x variant x bite mode, `--forms --variants --modes --rounds --round_time --players --size --out`; prints fish per bite, fish per minute, hold against tap, win rate and round time, spat/hurls, prey eaten, Clicks, sniff time and relocations, and a `ROW|` JSON line per cell.
- **Probe**: `tests/what_stinks_bots_probe` 27/0 (prey bots join, relocate, stay under patience 0 or bait; the Hunter reads loners and ignores unseen ones; Click, sniff limits, no sniff in Upset Stomach; held bites; Angel lock gate).
- **Report**: `what_stinks_report.md`, 160 rounds (10 forms x 2 variants x hold/tap x 4 rounds) at 1x. Headlines: the Hunter bot won 0 of 80 Clean Sweep rounds; Upset Stomach was won 30 of 40 in hold mode (Beluga 0%, Orca 25%, others 50 to 100%); Beluga weakest, Blue strongest per bite; Lamprey and Angel gain most from the hold; Angel's rams take 45 fish per Sweep round. All listed as open items for the play-test.
- **Also touched**: `what_stinks_join.gd` (the bots' auto-join asks the prey bot `accepts()`), `what_stinks_match.gd` (`_set_bot` makes the prey bot), `lock_attack.gd` (stinker gate), `INVENTORY.md` (Bots line), `setting_docs.gd` (regenerated; only the five new settings were added).
- **Not done**: a `--size=0.5` pass (the match default), Phase 8, the `hunter_forms.md` Signature/Bite updates and the build (the task was Phase 6/7 bots and the report).

### 2026-11-08_00:32 FINAL SUMMARY (two-stage attacks run, wrap-up: supersedes the 05:20 summary and the Progress counts above)
**Built this run (details in two-stage-attack.md's progress log).** Every Hunter attack is now two-stage: press opens, hold charges, release shuts; tap keeps the old snap (`bite_mode`). Core (`ChompKit.Bite` opt-in hold, `HunterBite`, hold costs, no jump/dodge for Hunters, net open/close/land messages), feel (`HunterBiteFx`, `WhatStinksRumble`, hit-stop, prey-side warning, HUD ring as charge meter, sound ids), five styles in `scripts/what_stinks/attacks/` (chomp for the Shark, engulf with `WhaleJaw` + `School.hold` for all five whales, lock for the Angel, suction with `School.pull` for the Gulper, coil for the King, drill for the Lamprey), and Phase 6/7 bots (the Hunter bot now holds bites and reads the echo, a prey bot that joins and relocates, `what_stinks_sim`, `what_stinks_report.md`). Forms: Orca, Beluga, Sperm Whale and Blue Whale are ready (first-guess sheets); 10 of 11 forms are ready. Phase 7 is done. Whale Fall stays disabled and its lash is not built.
**Probes (fresh `--import`, sequential).** All clean except the flakes and pre-existing failures listed in the two-stage log entry of the same date: the full two_stage_bite sweep 586/0, whale_engulf 133/0, angel_lock 71/0, coil_whip 53/0, drill 38/0, gulper_suction 40/0 (flaky bump check), what_stinks 62, bots 27, stomach 66, echo 92, hunter_forms 852, net scripts (what_stinks, marco_polo, coop, unnatural) pass. Pre-existing: whalefall 7 (disabled form), boss_moves 1, whale_spike 2, whale_sight 1. Two probe bugs I introduced earlier were fixed (the sweep's chomp-only checks, the gulper probe's prey joining a school).
**Build.** `builds/windows/FishPlayground.exe` 2026-11-08 00:32. Awaiting user play-test.
**Play first.** Setup screen -> What Stinks? -> Hunter. Hold the bite button: shark (held bite should read bigger than a tap), a whale (the mouth opens, fish swim in and ride there, release eats them), Gulper (hold pulls fish in), Angel (needs a fish ahead; ring and line, orbit with the stick, "xN"), King (coil whips an arc), Lamprey (dash). Try tap mode (`bite_mode` in the Bite group) to compare. Then Upset Stomach with a whale (spit) and bots.
**Open items.** Everything in the two-stage log's play-test list; the bot-sim headlines (Clean Sweep 0 of 80, Beluga weakest, Upset Stomach easy) are report numbers, not tuned. Phase 8 (polish) not started. `hunter_forms.md` and INVENTORY.md are updated; no windowed look at the new bots or any new visual.
