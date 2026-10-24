# Big Changes — development roadmap

Started 2026-10-24. Covers seven requests:

1. Fish groups become **Classes** (a role name, e.g. "Brawlers") made up of **Species**.
2. The Baby Whale Sharks are replaced by **baby whales** that swim with an up-and-down stroke.
3. A new final boss: the **Sea Angel**.
4. The Mantis Shrimp stops dropping bombs. It gets a **Cavitation Punch** and a **Recoil Dash**.
5. A new class led by the **Sea Hare**, with **Purple Haze** bombs.
6. More **variety in how species swim** (jellies, bottom dwellers, octopus).
7. Why some playable fish never spawn as zombies in Unnatural (answered in §8, and fixed in Phase 6).

Everything follows the usual loop: plan → build → headless probes → debug build → you test by hand → adjust. Each phase ends with a build you can test. Numbers below are starting values. They go into `UnnaturalSettings` / `PowerupSettings` with wide ranges, not into consts. `INVENTORY.md` is updated in the same phase as each change.

Decisions are marked **D1, D2...** and listed together in §10. **All twelve were answered on 2026-10-24.** Where an answer changed the plan (D6, D8, D11), §10 says how; the phase sections above still show the options as first written.

---

## 0. What the code looks like today (the starting point)

| Thing | Where | Notes |
|---|---|---|
| Fish groups | `FishCharacter.Family` enum: `OCTANE, DOMINUS, PLANK, BREAKOUT, HYBRID, MERC, LIONFISH, MOON_JELLY, MANTIS, WHALE_SHARK` | Named after RL hitboxes (first six) or after the first fish. `CARS[f]["fish"]` is the name the picker shows ("Clownfish") |
| Variants | `FishCharacter.SKINS`: 4–5 per family | Look only, never stats. Keyed by string (`"great_white"`) for saves and replays |
| Hitbox | `CARS[f]` (RocketSim CarConfig) | The later four reuse a box from the first six (Lionfish→Octane, Jelly→Hybrid, Mantis→Dominus, Whale Shark→Plank) |
| Family keys in data | `CARS[f]["key"]` (`"octane"`, `"whale_shark"`) | Replays (`hitbox_family`), saves and skin picks use these. **The enum's numeric order goes over the network**, so new entries must go at the end and existing ones can't be reordered |
| Twists, skills | `scripts/unnatural/traversal.gd` (`NAMES`, `SKILLS`, `mobility()`, `_snap`, `_gulp`...) | |
| Starting weapons | `FishAttack.FOR_FAMILY`, `scripts/unnatural/attacks/*.gd` | Mantis → `depth_charges.gd`, Whale Shark → `remora_buddy.gd` |
| Strides | `scripts/swishy_swim.gd` | A stride is a **stick sweep** in any direction. Reversing the sweep near the peak chains strides and builds flow. The push is mostly along the nose, plus a small kick away from the sweep (`stride_side_angle`). It isn't applied while on a surface |
| Zombies | `EnemyKind.defaults()` in `scripts/unnatural/enemy_kind.gd` | Five kinds, hard-coded (see §8) |
| Zombie looks | `Horde._add_set()` → `SchoolLook.detail_meshes(family, …)` | One MultiMesh per **kind × 3 tail poses × 3 LOD bands**, per split-screen view set |
| Bosses | `scripts/unnatural/bosses/` (`boss.gd`, `spine_rig.gd`, `boss_mesh.gd`, four final bosses) | All share the Blood Leviathan settings. Phases: circle → spit (below 2/3 hp) → fury (below 1/3) |

About 56 scripts reference `Family.`. The rename in Phase 0 is wide but mechanical.

---

## 1. Classes and Species (Phase 0)

### The model

- **Class** = the group that plays the same way: hitbox, starting weapon, signature stat, twist, mobility skill, gait (§6). The class has a **role name**, not the name of its first fish.
- **Species** = a real animal in that class. Species replace today's skins and, like skins, change only the look (see **D2** for whether that should change).
- The picker becomes **Class → Species**. The card shows the class's role name, with the species underneath: "**Brawlers** · Peacock Mantis".

### Proposed class names

| Today (enum) | Today's name | Proposed class | Alternatives | Why |
|---|---|---|---|---|
| `OCTANE` | Clownfish | **Skirmishers** | Tricksters, Anemone Kin | Nimble wriggle and a close-range sting pulse |
| `DOMINUS` | Shark | **Hunters** | Predators, Apex | Frenzy grows with each kill. Ghost Bite |
| `PLANK` | String Ray | **Gliders** | Wings | The Glide twist. Coasting with little drag |
| `BREAKOUT` | Swordfish | **Lancers** | Billfish, Spears | Bill Thrust spears |
| `HYBRID` | Butterfly Koi | **Charmers** | Fortunes, Graces | Luck signature stat, Graceful i-frames |
| `MERC` | Boxfish | **Bulwarks** | Tanks, Shells | Armoured, Brace |
| `LIONFISH` | Lionfish | **Scorchers** | Firebrands, Venoms | Greek Fire Trail, Flare Dash |
| `MOON_JELLY` | Moon Jelly | **Drifters** | Bells, Pulsers | Pulse gait (§6), Go Quiet |
| `MANTIS` | Mantis Shrimp | **Brawlers** (yours) | — | Cavitation Punch (§4) |
| `WHALE_SHARK` → whales | Baby Whale Shark | **Breachers** | Calves, Gentle Giants | Up-and-down gait (§2) |
| new | Sea Hare | **Alchemists** | Inkers, Hazers | Chemical bombs, ink and sticky secretions (§5) |

**D1: answered 2026-10-24:** the proposed column.

### Code shape

- Rename `FishCharacter.Family` → `FishCharacter.FishClass`. (`class` is a GDScript keyword, so the plain word can't be used for variables. `FishClass` / `fish_class` reads cleanly.) Rename `SKINS` → `SPECIES`, and the `skin_*` helpers → `species_*`.
- Enum values get role names: `SKIRMISHER, HUNTER, GLIDER, LANCER, CHARMER, BULWARK, SCORCHER, DRIFTER, BRAWLER, BREACHER`. Then `ALCHEMIST` is **added at the end**. The order stays the same, so network ints and anything stored by index keep working.
- ~~Each `CARS` entry already names its hitbox (`"car": "Octane"`). Keep that.~~ **Changed 2026-10-24:** there are no cars in this game, so `CARS` is now `CLASSES` and nothing outside the Rocket League layer says "car". Each class keeps a reference to its RL hitbox (`"rl_hitbox": "octane"`), which RL replays use. RocketSim/physics comments and the replay system (`ReplayCar`, RL replays' `cars`) still say car, since those are Rocket League's own.
- **Data keys stay stable.** Old keys (`"octane"`, `"whale_shark"`, skin keys) are kept as aliases in `from_key` / `species_from_key`, so old replays and saved picks still load. New keys are the class ids (`"brawler"`).
- Player-facing text everywhere says Class / Species: the picker, fish details, HUD, run log, setting docs, `INVENTORY.md` (§3 becomes "Playable classes"). Internal comments follow in the same pass.
- Battered / Fish Fry wording is not affected.

**Probes:** a new `class_species_probe` checks: every class has ≥ 3 species; the old keys resolve; a replay saved with `hitbox_family: "octane"` loads. The current `skins_probe` and `new_fish_probe` are run again on the renamed API.

**Size:** M (wide, mechanical). It goes first, so every later phase lands on the new names.

**Built 2026-10-24.** As planned, plus: each class entry has `name` (role name), `rl_hitbox`, and `aliases` (its pre-class key). Our goal clips write `fish_class` and the RL `hitbox_family`; `FishCharacter.class_of()` reads either. Saved species are `playground/species_<class key>`, with the old `skin_<old key>` read as a fallback. `FishCharacter.full_name()` gives "Brawlers  ·  Peacock Mantis". `ALCHEMIST` is not in the enum yet: it is added in Phase 3 with its data. The run log's `fish` field and `run_sim --fish` now use the new enum names (`BRAWLER`, not `MANTIS`).

---

## 2. Baby whales replace the Baby Whale Shark (Phase 4)

### Species (the Breachers)

| Species | Look |
|---|---|
| **Humpback Calf** | Dark grey-black, white-mottled belly and very long white-edged flippers, knobbly head |
| **Orca Calf** | Black and white. Calves' white patches are peachy-orange, which is a nice true detail |
| **Beluga Calf** | Calves are grey (they whiten with age), rounded melon head, no dorsal fin |
| **Sperm Whale Calf** | Boxy forehead, wrinkled dark-grey skin, small underslung jaw |
| (optional) **Blue Whale Calf** | Mottled blue-grey, small dorsal fin set far back |

### The up-and-down stroke

Whales and other mammals swim with **horizontal tail flukes that beat up and down**, while fish tails sweep side to side. So the change you asked for is also the biologically correct one, and the players who notice will appreciate it.

- **Model:** a new `whale_model.gd`, lofted the way the koi is, with the species as its skins. The body bends in its **vertical** plane (`fish_model.gd` currently bends the tail sideways). Bend axis becomes a model setting.
- **Gait:** the `vertical` stroke axis from §6. The stride's side kick and the body's bob go up and down. When cruising, the whale rises and falls slightly with each stroke, and the camera smooths most of that out.
- **Controls:** **D3**. (a) Any sweep still counts as a stride, and only the motion and the look are vertical. This keeps the controls the same for every class. Recommended. (b) Only up/down sweeps count fully, and side sweeps count for half. More flavour, but it is the only class with different controls.
- Hitbox stays Plank (long and flat suits a whale).

### Kit

Keep it as it is, since it still fits: **Remora Buddy** (remoras ride whales too), **Pearl Chance** signature stat, **Escort** (a calf resting by its mother heals). **D4:** keep **Gulp**, or replace it with **Whale Song**: a sound ring that pushes zombies out and stuns them for 1 s. Gulp still works as a calf's lunge. Whale Song is more whale-like but is a new skill to build. Recommended: keep Gulp for now and revisit after testing.

**Probes:** `model_shots` for every species, from the side and the top. A gait probe checks the vertical bob amplitude at cruise speed and that net forward speed matches today's Plank fish within ±5%.

**Size:** M (a new model plus the vertical stroke). Depends on Phase 1 (gait layer).

---

## 3. New final boss: the Sea Angel (Phase 7)

Reference: `private_content/sea_angel_vs_sea_butterfly_first_4_5s.gif` (45 frames, 4.5 s).

### What the clip shows

1. **Cruising (0–0.8 s):** the sea angel hangs **upright**: head up, a long, clear, tapering tail hanging below it with an orange tip. Two small wings at the "shoulders" beat, and it bobs up and down with them. Two little horns sit on top of the head. The orange head and gut glow through the glass-clear body. The sea butterfly (brown shell, its own little flapping wings) flutters a body-length away.
2. **The crown (≈1.2 s):** before it touches the prey, the head **bursts open into six long, pale tentacles (the buccal cones) splayed out like a starburst**. This is the clearest wind-up in the clip.
3. **The tumble (1.2–2.8 s):** it doesn't dart in a straight line. It **rolls and tumbles around the prey**, its body **curling into a C or hook** and the tentacles lashing out in different directions. It **misses several times**, and the butterfly drifts in and out of reach while the angel keeps turning after it.
4. **The catch (3.0–4.5 s):** the tentacles, now orange, **wrap round the shell and pull it up to the mouth**. The body stays curled around the prey and the tail flicks.

### Boss moves

| From the clip | Boss |
|---|---|
| Upright hover, bobbing on small wingbeats | **Movement.** It travels upright, not nose-first like the serpent bosses. Each wingbeat lifts it and it sinks a little between beats. It moves by **leaning** toward where it's going (the same idea as the jelly's tilt in §6). It turns on the spot. Its hitbox is a tall capsule, not a long chain |
| The crown bursts open before the strike | **Lock-on telegraph.** It picks a player and turns to face them. Over ~1.2 s the head **splits into the six-tentacle crown** (pale, then flushing orange), and a ring marks the target. The crown is how players read "it's coming for me" |
| It tumbles and curls round the prey, missing more than once | **Tumbling grab.** Instead of one straight dart, it closes in with a **2 s flurry**: it rolls, the body curls, and the tentacles sweep through a ~12 m sphere round its head in **3 lashes**, each a grab check along that tentacle. Each lash can be dodged with a well-timed stride, the way the butterfly slips away in the clip. Zombies caught by a lash are pulled in and eaten (healing it a little) |
| The tentacles wrap the shell and pull it to the mouth | **Held.** A player caught by a lash is **Grabbed** (the same rules as Gulper/Lamprey: held at the mouth for up to 3 s, drained, 3 strides break free). The orange tentacles stay wrapped round them, and the body stays curled |
| Glass-clear body, orange gut and head glowing through | **Weak spot:** the glowing orange head and gut take 2× damage, like the Lamprey's gills, and they are most exposed while the crown is open (a reward for standing your ground). Swallowed zombies show through the body, like the Gulper's belly |
| It feeds on **sea butterflies** (*Limacina*), and the butterfly flutters, dodging | **Spit phase:** it sheds swarms of **Sea Butterflies** (a new tiny shelled, fluttering swarm zombie that only this boss spawns) and later turns its tumbling grab on them to heal. Killing the butterflies denies it the heal. The players are in the butterfly's place in the clip, so the fight *is* the clip |
| — | **Fury:** a faster beat, a shorter crown wind-up (~0.8 s), 4 lashes per flurry, and the crown can hold 2 targets (two players in co-op) |

### Body

About 40 m from the horns to the tail tip, built **upright**, so its silhouette is unlike the serpent bosses:
- A glass-clear hooded body and two small wings at the shoulders, torn and rotting at the edges.
- Two short horns, and a glowing orange head and gut.
- A long, tapering tail with an orange tip that curls into a hook when it strikes.
- Six crown tentacles folded inside the head until it feeds. They are pale when splayed and orange once wrapped.

It is built on `boss_mesh.gd`, with `spine_rig.gd` for the body and tail curl (the spine is short and vertical). The two wing meshes and six tentacle chains are driven by their own clocks: wingbeat, crown open, lash.

- **D5:** name: "The Sea Angel" or "The Fallen Angel" (a fallen/zombie pun to match the King of Herrings and the Whale Fall).
- It joins the alternates pool (40% alternates → each of the four is equally likely), using the shared Blood Leviathan settings.
- Reward: Leviathan's Coil, like every final boss for now.
- Test: `tank_boss` puts it in the Test Tank, and `boss_shots` renders it.

**Size:** L (a new upright mesh with wings and tentacle chains, a new movement style, the crown telegraph, the tumbling grab hooked into the existing Grabbed code, and a new zombie kind).

---

## 4. Mantis Shrimp → Brawlers: Cavitation Punch and Recoil Dash (Phase 2)

### What's real

A smashing mantis shrimp's club accelerates so fast that the water behind it boils into a cavitation bubble. When the bubble collapses, it hits a second time (with a flash of light and heat). **Two impacts per punch** is the core of this weapon.

### Cavitation Punch (new fired `FishAttack`, replaces Depth Charges as the Mantis's own weapon)

| Base | Start value |
|---|---|
| Aim | The nearest zombie within 60° of the nose, else straight ahead |
| Glove | A boxing-glove projectile, 30 m/s, 7 m range, 0.8 m hit radius. **It fades out over the last 40% of its flight** and is gone at max range. It hits the first zombie it touches (pierce 0) |
| Hit 1, the strike | 30 dmg + heavy knockback |
| Hit 2, the collapse | 0.08 s later at the impact point: a bubble flash and ring, 50% of the strike's damage within 2 m (proc 0.5). This can hit zombies the glove didn't touch |
| Cooldown | 0.7 s |
| Quantity | Each +1 adds a follow-up glove from the other claw (a one-two), 0.1 s apart |
| Facets | Damage, Punch rate, Glove size (Size), Knockback |

**Milestones:** Lv 5 the collapse ring grows 50%; Lv 10 collapses stun for 0.5 s; Lv 15 the glove pierces one zombie and its collapse goes off at each zombie hit; Lv 20 every third punch is a **Haymaker** (2× glove size, the collapse hits at 100%).

Because the glove is short-ranged and has to land, this reads as melee even though it's technically a projectile. The fade-out makes the range limit visible.

### Recoil Dash (new mobility skill, replaces Snap)

The Snap's shockwave already used the cavitation idea, so the skill changes to a movement trick: **the shrimp punches the water one way and the recoil throws it the other way.**

- Press boost: the shrimp throws a full Cavitation Punch **opposite to where it travels**. It travels the way the stick leans, or **backwards** if the stick is neutral. So the default use is "punch the zombie in front of you and shoot back out of the crowd."
- Recoil: 20 m/s for 0.25 s, untouchable for 0.2 s. Cooldown 2.0 s.
- The punch counts as an attack hit (it starts on-hit powerups).

### Twist (replaces Hammer, which was tied to the Snap)

**D6:** (a) **Keen Eyes**: +10% crit chance, and crits from punches stun for 0.4 s (mantis shrimp eyes are famous for this). Recommended. (b) **Heavy Hitter**: knockback from punches also hurts zombies that are knocked into each other.

Signature stat stays **Knockback +15%**.

### What happens to Depth Charges? (D7: answered)

**Depth Charges is retired and becomes Purple Haze** (§5). The bombs are still hard to use, so this change is meant to fix that, and Purple Haze starts from the Depth Charges code. `attack_depth_charges` leaves the card pool. Old saves and run logs that name it map to `attack_purple_haze`.

**Probes:** `attack_probe` (two hits per punch, fade timing, Quantity follow-ups), `weapon_bench` DPS against the other fired weapons, a recoil probe (direction with the stick neutral and the stick held).

**Size:** M.

**Built 2026-10-24 (Phase 2).** `CavitationPunch` (`scripts/unnatural/attacks/cavitation_punch.gd`, `FishAttack.Kind.PUNCH`, added at the end of the enum; second-weapon id `attack_punch`, source `punch`) with the numbers above as `punch_*` settings (new **Cavitation Punch** group under Attacks). As planned, plus: the glove's range is never less than 1.2× the bow wave's reach (`punch_over_bow`, like the other melee attacks); with nothing in the 60° cone it punches straight on only if a zombie is within reach ahead, otherwise it waits; the knockback is `punch_knock` (2×) the usual. Zombies' speed cap clamps a knocked zombie to about 1.5× its swim speed, so knockback reads strongest on slow kinds. The Lv 10 stun skips zombies that are Heavy Hitter missiles (a stun zeroes their velocity). **Recoil Dash** (`recoil_*` in Mobility): the stick's lean is right/left and pitch up/down, relative to the fish; a single push to 20 m/s, then no water drag for `recoil_time` (as Surge does), rather than holding the speed. It throws the fish's own punch, else a held `attack_punch`, else a spare punch at the fish's stats (when the panel's `fish_attack` gave it another attack). **Heavy Hitter** (D6, `heavy_*` in Twists): `Traversal.fling()` keeps up to `heavy_flings` (24) missiles; each checks one sphere query a tick while it's moving faster than 1 m/s, and hits up to `heavy_max` (3) others for `heavy_share` (50%) of the punch, source `heavy_hitter`, proc 0.3. Missiles don't chain. Snap, Hammer and the `snap_*` settings are gone. Probes: new `brawler_probe`; `attack_probe`, `new_fish_probe`, `milestones_probe` and `weapon_bench` know the punch.

---

## 5. New class: Sea Hare (the Alchemists) (Phase 3)

### About the reference image

`private_content/sea_hare.jpg` gets the palette and the wavy, mantle-like **parapodia** (the wing flaps) right. But the face looks generated: real sea hares have no whiskers or nostrils. A sea hare's head has two ear-like **rhinophores** on top (they're why it's called a "hare") and two flat **oral tentacles** at the front. I'll use the image for colour and the flap shape, and take the head from the real animal. Say so if you want the image's face instead.

### Species

| Species | Look |
|---|---|
| **California Sea Hare** (*Aplysia californica*), the standard one | Broad winglike parapodia. Reddish, brown, green and purple mottling |
| **Spotted Sea Hare** (*Aplysia dactylomela*) | Cream, tan or olive body with prominent dark rings |
| **Ragged Sea Hare** (*Bursatella leachii*) | Covered in small branching, hairlike projections (fin-strip "fuzz", like the Fuzzy Dwarf lionfish). Brownish, with bright blue spots |

### Purple Haze (new steady `FishAttack`, the class's starting weapon)

Sea hares defend themselves with purple **ink** and a sticky white secretion called **opaline**, which clogs a predator's senses. The weapon uses both. It replaces Depth Charges (D7) and **starts from its code**. Instead of mines that wait and blow, it scatters bombs that burst on landing into **big, lingering clouds**. The design leans on control (blinding and slowing) more than on raw damage, so it doesn't overlap with Greek Fire (a trail of small hot patches).

#### Why Depth Charges is hard to use, and what Purple Haze changes

| Depth Charges today | Why it's hard | Purple Haze |
|---|---|---|
| Lobbed only toward zombies near the **tail**, within 6 m, else fanned behind | A survivor is usually swimming away, so the bombs fall where the zombies *were*. You have to circle back to use them | Aims at the **densest pack within 12 m in any direction**, and **leads it** by the pack's velocity over the lob time |
| A mine **arms** (0.5 s), then waits for a zombie to come **within 3 m** | Damage depends on zombies walking onto a small trigger. Many mines sit unused or time out | **No arming and no trigger.** Each bomb bursts the moment it lands. The damage comes from the cloud, not from a hit |
| A 5 m blast, once | A miss is a total miss | A 4 m cloud that **lasts 5 s** and **holds** what's in it (hazed zombies drift at 50% and lose their target). A near miss still pays off, because the pack drifts into the cloud |
| Milestones: implosion, cluster, drifting mines, double blast | Each one fixes the targeting a little, but you have to level the weapon to get them | The core works at Lv 1. Milestones add strength, not usability |

**Kept from Depth Charges:** the lob arc and its timing, choosing targets from the horde grid, the "at most N out, oldest go" cap, the Quantity and Attack Speed wiring (including the 2× weight on drop rate, which becomes scatter rate), and the bomb mesh and FX as a starting look (recoloured purple).
**Dropped:** arming, proximity triggers, the 10 s fuse, drifting mines, cluster bombs.

**Success test:** `weapon_bench` gets a **"bombs that did damage"** metric. Depth Charges' current share is measured first as the baseline. The target for Purple Haze is **≥ 90%** of bombs damaging something, and zombie-seconds spent hazed is reported too. `run_sim` checks this with a bot that only swims away (the case where Depth Charges fails).

| Base | Start value |
|---|---|
| Scatter | Every 3.5 s, lobs 3 bombs (+1 per Quantity) over 0.4 s at the densest pack within 12 m (any direction, led by its velocity), else in a fan around the fish |
| Cloud | Each bomb bursts into a purple cloud 4 m in radius (× Size) that lasts 5 s (× Duration) |
| In the cloud | 12 dmg every 0.5 s. Zombies inside are **hazed**: they lose track of their target and drift at 50% speed (the Ink Sac's blind, weaker) |
| Cap | At most 12 clouds (the oldest go) |
| Proc | 0.15 |
| Facets | Cloud damage +25%, Cloud size +12%, Cloud life +0.8 s, Bombs per scatter +1, Scatter rate +15% |

**Milestones:** Lv 5 **Opaline**: clouds leave a sticky film that slows zombies 30% for 2 s after they leave; Lv 10 clouds that touch merge into one bigger cloud; Lv 15 zombies that die hazed burst into a small cloud; Lv 20 clouds slowly creep toward the nearest zombie.

### Kit

| Slot | Proposal |
|---|---|
| Hitbox | Merc (bulky and tall, like the boxfish) |
| Signature stat | **D8:** Duration (shared with Scorchers) or **Size** (shared with Skirmishers and Drifters). Recommended: Duration, which feeds the weapon directly |
| Twist | **Unpalatable:** a zombie that touches the sea hare gets coated (slowed 30% for 2 s, and takes +20% from Purple Haze) |
| Mobility | **Flutter:** three big parapodia flaps carry it ~15 m up and forward over the pack (real *Aplysia* do swim this way). It drops one Haze bomb where it took off. Cooldown 4.0 s |
| Gait | `flap` (§6): wingbeat strides, slow top speed, good hover |

**Probes:** `new_fish_probe` gains the class; `attack_probe` covers clouds, haze and the cap; `weapon_bench` checks DPS, plus a "time zombies spend hazed" metric. `model_shots` covers all three species.

**Size:** L (a new model with three species, a new weapon, twist, skill and gait).

---

## 6. Traversal variety: gaits (Phase 1 is the layer; later phases use it)

### The principle

Strides stay in for every class. What changes per class is **how a stride moves the body and how it looks**. The controls stay the same everywhere: sweep the stick, chain at the peak. That keeps the skill transferable between classes and keeps every class playable in split-screen and with bots.

### A `Gait` resource per class

These settings sit on top of the stride values that already exist (`stride_force`, `stride_peak_time`, `stride_fade_time`, `stride_side_angle`...):

| Setting | Values | What it does |
|---|---|---|
| `stroke_axis` | lateral / vertical / radial / flap | Which way the side kick and the body bend go |
| `push_axis` | nose / bell / stick | What a stride pushes along: the nose (fish), the bell axis (jelly), or the stick direction (strafe swimmers, later) |
| cadence | the existing peak/fade times | Fast flicks (Skirmishers) vs slow, heavy strokes (Breachers) |
| `coast_drag` | × drag between strides | Jellies coast and slow down; rays glide |
| `buoyancy` | m/s² up/down while not striding | Jellies sink slowly between pulses; sea hares sink faster |
| `surface_mode` | none / crawl | Whether a stride on a surface is ignored (today) or becomes a step (bottom dwellers, later) |
| visual | tail bend / flap / bell pulse / arms | Which animation the model plays per stride |

Phase 1 builds the resource, the debug-panel entries and the default `lateral` gait, with **zero change** to today's fish (probe-checked). Later phases add each new gait as its class needs it.

### Jellyfish (Drifters): recommendation

You asked whether the jelly should turn vertical and use strides to wiggle forward. My recommendation is close to that, with one change: **tilt and pulse.**

- At rest or drifting, the bell **points up** and the jelly slowly sinks (`buoyancy`). That reads instantly as a jelly.
- When you steer, the bell **leans toward where you're going**: the lean grows with speed, up to ~75° at full pace. A swimming jelly moves bell-first and almost level, and a hovering one stands upright. That's how real jellies steer: they tilt the bell and jet along its axis.
- Each stride is a **pulse**: the bell contracts and pushes hard and briefly along its axis. Then there's a longer coast with more drag. The peak timing still matters, so good rhythm becomes the classic jelly bob-bob-bob.
- Physics stay put: the hitbox doesn't rotate, only the model does, plus the push direction. The mismatch between a tilted bell and the flat box is small at the jelly's size.

Why not a fully vertical jelly that wiggles forward: the stride would then push *up* while you want to go *across*, and the camera and auto-aim (which work off the nose) would fight it. Tilting gets the look without that.

### Bottom dwellers and the octopus

The fish are RocketSim cars, so **they already have wheels and can touch surfaces**, including RL-style wall driving. Today strides are just skipped on a surface. That gives a natural hook for bottom dwellers:

- `surface_mode: crawl`: on the seabed (or a wall), a stride becomes a **step** (an arm or leg reach). Well-timed steps crawl faster, and the class grips the surface (doesn't slide, isn't knocked off easily). Off the surface it swims with its own gait.
- **Octopus** ("Grapplers"):
  - **On a surface:** crawls with arms, and can stick to walls and the seabed. Each stride is an arm-step.
  - **In open water:** strides become **siphon jets**. The push goes mantle-first with the arms trailing, which makes it fast but slow to turn. An octopus jetting backwards from a fight is exactly how they escape.
  - **Weapon idea:** "Eight Arms": arms lash out at up to 8 nearby zombies, then slam the ones they hold.
  - **Skill ideas:** **Anchor** (grip the seabed: you can't be knocked back, and you take −50% damage while the arms flail) or **Mimic** (copy the look of the nearest zombie kind, and zombies ignore you briefly). Ink is already used by the Ink Sac item and the Sea Hare, so it isn't the octopus's skill.
- Risk: Unnatural is open 3D water and zombies come from every side. A class that *needs* the floor would play worse there. So bottom dwellers should **always be able to swim**, and the floor gives them a bonus rather than being required.

### More ideas for the list (not scheduled)

| Animal | Gait idea |
|---|---|
| Squid | Jet only, tail-first. It can flip its facing instantly (a reverse jet) |
| Cuttlefish | `push_axis: stick`: fin ripples let it **strafe** sideways without turning |
| Seahorse | Upright and slow, but each stride is a big tail-curl hop. It can anchor to kelp |
| Eel | Long, low-power strides that **never fade**: steady flow, low peak |
| Sea turtle | Few, strong flipper strokes (long peak time) and a very good glide |
| Crab | Crawl-first, walks **sideways** on the floor, and its strides are jumps when it's off it |

**D9:** should a bottom-dweller class (octopus first) be scheduled after this roadmap, or stay a brainstorm for now?

**Size:** Phase 1 S–M (the layer, no new behaviour). Each new gait is S, plus whatever its model needs.

**Built 2026-10-24 (Phase 1).** `Gait` (`scripts/gait.gd`) holds `stroke_axis`, `push_axis`, `stroke_time` (× the fish's stride peak and fade times; the plan's "cadence"), `stroke_power` (× stride force), `coast_drag` (× linear drag between strides), `coast_buoyancy` (m/s² between strides), `surface_mode` and `visual`. Each enum lists only what's built (today's `LATERAL` / `NOSE` / `NONE` / `TAIL_BEND`), and later phases add values at the end. `GaitSettings.shared()` keeps one Gait per class and is the new **GAITS** tuning section (after Fish): a heading per class, options named `<class key>_<export>` (e.g. `drifter_coast_drag`). It is saved in presets (`[gaits]`), sent by the co-op host, and described from gait.gd's comments (`gen_setting_docs`). An enum only shows in the panel once it has a second value. `FishController.gait` is its class's Gait. `SwishySwim.peak_time()` / `fade_time()` / `push_direction()` read it, and `_apply_water` uses the coast values. The camera follows the body, so bob or tilt on the model never moves it. `gait_probe` checks that every class swims **bit-for-bit** as before against `tests/fixtures/gait_baseline.json` (recorded on the pre-gait code; `-- --record` re-records it), and checks each number, the panel/preset/co-op wiring and the camera.

---

## 7. Phase plan

| Phase | Content | Needs | Size |
|---|---|---|---|
| **0** | Classes and Species rename (§1). **Built 2026-10-24** | ~~D1~~ (D2 can wait) | M |
| **1** | Gait layer, lateral default, no visible change (§6). **Built 2026-10-24** | — | S–M |
| **2** | Brawlers: Cavitation Punch, Recoil Dash, new twist (§4). Depth Charges stays in the card pool, ownerless, until Phase 3 replaces it. **Built 2026-10-24** | ~~D6~~ | M |
| **3** | Alchemists: Sea Hare model + 3 species, Purple Haze (built from Depth Charges, which is then retired), Unpalatable, Flutter, flap gait (§5) (Regen signature; Drifters → Quantity, D8) | ~~D8~~ | L |
| **4** | Breachers: whale model + species, vertical gait; remove the Whale Shark (§2) | ~~D3, D4~~ | M |
| **5** | Drifters: tilt-and-pulse gait for the jellies (§6) | — | S–M |
| **6** | Zombie roster: every class appears as a zombie (§8) | ~~D10~~ | M–L |
| **7** | The Fallen Angel (Sea Angel) boss + Sea Butterfly zombies (§3) | ~~D5, D12~~ | L |

Phases 2, 3 and 4 don't depend on each other once 0 and 1 are in, so they can be done in whatever order you want to test them. Phase 6 goes after 3 and 4 so it includes the Sea Hares and the whales. Phase 7 goes last because it's the biggest single piece and benefits from the new zombie kinds.

Each phase ends with: probes passing, `INVENTORY.md` updated, a debug build at `builds/windows/FishPlayground.exe`, and a short list of open items for you to close.

---

## 8. Why some playable fish never spawn as zombies

**The zombie roster is a fixed list of five kinds, and it was never extended when new fish were added.** `EnemyKind.defaults()` (`scripts/unnatural/enemy_kind.gd:41`) builds:

| Zombie | Body it borrows | Behaviour |
|---|---|---|
| Rotten Sardine | Clownfish (small; there's no sardine model) | Swarm |
| Ghoul Clownfish | Clownfish | Chase |
| Bloated Boxfish | Boxfish | Tank |
| Lunging Swordfish | Swordfish | Lunge |
| Grave Ray | String Ray | Glide |

So the **Shark** only appears as the Drowned Shark mini-boss. The **Koi, Lionfish, Moon Jelly, Mantis Shrimp and Baby Whale Shark** never appear as zombies at all. It isn't spawn weights or a bug in the director. They were simply never added as kinds.

Adding a kind has a real cost: `Horde._add_set()` builds **9 MultiMeshes per kind** (3 tail poses × 3 LOD bands) **per split-screen view set**. That's draw calls, which perf passes 2 and 3 worked hard to keep down. Also, the jelly and mantis don't have a tail to bend for the swim poses.

### Phase 6 plan

- One zombie kind per class, each with its own **behaviour**, so a new kind is a new threat and not just a reskin:

| Zombie (draft) | Behaviour idea |
|---|---|
| Drowned Koi | **School:** comes in tight rings that circle before closing in |
| Cinder Lionfish | **Trail:** leaves short-lived fire patches behind it (weaker than a Burning elite) |
| Grave Jelly | **Drift:** slow; pulses toward you; contact stings and slows |
| Rotten Mantis | **Puncher:** stops at ~4 m and throws a telegraphed punch |
| Bloated Whale Calf | **Tank** that bobs up and down; on death it spills sardines (like Bloated elites) |
| Sour Sea Hare | **Haze:** on death it leaves a small cloud that slows players |
| Ghoul Shark | **Lunge** variant: faster, shorter wind-up, appears later in a stage |

- **Draw-call budget:** each stage picks a **rotation** of ~6 kinds out of the full roster (sardines always in), so the number of MultiMeshes stays about where it is now. Later stages bring in the tougher kinds. **D10:** rotation per stage (recommended) or all kinds at once (more variety in one stage, more draw calls).
- Kinds with no tail (jelly, mantis, sea hare) get their 3 "poses" from their own animation (a bell squeeze, a leg shuffle, a flap) instead of a tail bend.
- Also fixes an old shortcut: give the sardine its own small model instead of a shrunken clownfish.
- Bench: `split_bench` at 3P has to stay within 10% of the current fps.

---

## 9. Risks and what to watch

- **Network and replay compatibility:** the enum order must stay fixed, new classes are added at the end, and old keys keep working as aliases (Phase 0 probe).
- **Removing the Whale Shark:** saved species picks for it fall back to the first whale species. Old replays with a Whale Shark show the new whale model (same Plank hitbox, so playback is unchanged).
- **Weapon balance:** a new weapon goes through `weapon_bench` and `run_sim` before it reaches a build, as done for the Refining Weaponry pass.
- **Camera with vertical and tilted gaits:** the follow camera should follow the *travel* direction, not the model's bob or tilt. This is part of the gait layer in Phase 1.
- **Bots:** `survivor_bot` and `hunter_bot` time strides off the stride code. The gaits keep the same stride timing API, so they keep working. Each new gait is still checked in `run_sim`.
- **Other modes:** Soccer, Nature and Hunt use the same classes. Recoil Dash and Flutter are Unnatural skills (as today's are), and gaits apply to every mode. **D11:** should gaits apply in Soccer too, or only outside it? Recommended: everywhere, since the RL hitbox physics underneath don't change.

---

## 10. Decisions

| # | Question | Recommended |
|---|---|---|
| D1 | ~~Class names (§1 table)~~ **Answered 2026-10-24:** the proposed column (built in Phase 0) | — |
| D2 | ~~Are species looks only, or may they get small differences later?~~ **Answered 2026-10-24:** looks only for now | — |
| D3 | ~~Whales: any sweep strides, or only up/down sweeps count fully?~~ **Answered 2026-10-24:** any sweep | — |
| D4 | ~~Whales keep Gulp, or get Whale Song?~~ **Answered 2026-10-24:** keep Gulp for now | — |
| D5 | ~~Boss name~~ **Answered 2026-10-24:** "The Fallen Angel" | — |
| D6 | ~~Brawler twist: Keen Eyes or Heavy Hitter?~~ **Answered 2026-10-24:** Heavy Hitter (zombies knocked back by punches hurt the ones they hit; watch the cost of the extra collision checks in big hordes) | — |
| D7 | ~~Depth Charges: stays or is retired?~~ **Answered 2026-10-24:** retired; Purple Haze is built from its code and must be easier to use (§5) | — |
| D8 | ~~Sea Hare signature stat: Duration or Size?~~ **Answered 2026-10-24:** neither: **Regen** (no other class has it). Also: **Drifters' signature changes from Size to Quantity**, and Quantity becomes a real number: the Drifters' signature adds **+0.33 per level** (a starting value, tunable). Anything that spawns uses the **floor** of the total, and the display shows the floor. The weapons' `roundi(quantity)` becomes `floori`, and the Jelly Halo starts reading the Quantity stat (it only had its count facet). Cards still give +1. `INVENTORY.md` §3 changes when this is built | — |
| D9 | ~~Schedule a bottom-dweller class (octopus) after this roadmap?~~ **Answered 2026-10-24:** brainstorm for now, decide after Phase 5 | — |
| D10 | ~~Zombie roster: a rotation of ~6 kinds per stage, or all at once?~~ **Answered 2026-10-24:** rotation | — |
| D11 | ~~Gaits in Soccer mode too?~~ **Answered 2026-10-24:** everywhere, with a setting to switch gaits off in Fish Sticks (on by default) | — |
| D12 | ~~Sea Angel lashes: can a single well-timed stride dodge a lash?~~ **Answered 2026-10-24:** a timed stride dodges | — |
