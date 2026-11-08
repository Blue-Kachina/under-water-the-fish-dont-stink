# Inventory — Unnatural

Every playable class, weapon, tome, powerup and bonus in Unnatural (the survivors mode), with their stats.

- **Last synced with code:** 2026-11-07 (late: two-stage attacks, all styles, bots)
- **Values are defaults.** Almost every number here is a tuning-panel setting (`UnnaturalSettings`, `PowerupSettings`), so a preset can change it. If this file and the code disagree, the code is right; fix this file.
- **Sources of truth:**

| What | File |
|---|---|
| Classes (role names, RL hitbox, species) | `scripts/fish_character.gd` (`CLASSES`, `SPECIES`) |
| Class details text (twists, skills) | `scripts/unnatural/fish_details.gd` |
| Weapons (every one a `FishAttack`) | `scripts/unnatural/attacks/*.gd`, `fish_attack.gd` (`FOR_CLASS`, `INFO`) |
| Weapons (facets, milestones) | `scripts/unnatural/weapons.gd` |
| Tomes | `scripts/unnatural/tomes.gd` |
| Stats (steps, signature stats) | `scripts/unnatural/stat_block.gd` |
| Powerups (name, rarity, blurb) | `scripts/unnatural/powerups/powerup.gd` (`INFO`) |
| Powerup numbers | `scripts/unnatural/powerups/powerup_settings.gd` |
| Run / class / attack / rarity numbers | `scripts/unnatural/unnatural_settings.gd` |
| Rarity | `scripts/unnatural/rarity.gd` |

---

## 1. Core rules

### Loadout

| Rule | Value |
|---|---|
| Weapon slots | 2 (the fish's own starting weapon takes one) |
| Tome slots | 2 |
| Weapon max level | 20 |
| Tome max level | 99 |
| Cards per level-up | 3 (Moon Pearl lets you pick more than one) |
| Card type weights | Upgrade a held weapon 40, upgrade a held tome 30, new weapon 15 (needs a free slot), new tome 15 (needs a free slot) |
| Weapon milestones | Lv 5, 10, 15, 20: each one unlocks a new behaviour (see the weapon tables) |
| Nothing left to offer | A pearl purse of 10 × (1 + level/10), or a team heal of 30% max HP |
| Weapon card fade (P4) | Upgrade-a-weapon weight ÷ (1 + 0.04 × (average weapon level − 1)): Lv 10 weapons come up at 74% |
| Rerolls, skips, banishes (P4) | 0 each at the start (from meta later). RB rerolls a level's or chest's cards; LB skips a level; Y banishes the focused weapon, tome or item for the rest of the run |

### Limits (P4, `limits.gd`; all off with `limits` false)

| Rule | Value |
|---|---|
| Item stacking curve | The k-th stack (from 0) adds 1 / (1 + falloff × k) of the first. Procs and effects falloff 0.5 (100%, 67%, 50%, 40%...); plain stat items 0.25; legendaries 1.0; cursed items stay in a line |
| Chances | Crit Chance and every item's proc chance bend short of 100%: raw / (1 + raw²)^½ (5% stays 5%, 50% → 45%, 100% → 71%) |
| Cooldown floor | No auto-attack fires more than once every 0.12 s |
| Size soft cap | Past +100%, Size grows at half its rate |
| Effect caps | Shown on each item's card ("At most 48 torpedoes in the water") |

### Rarity (`rarity.gd`)

Each card rolls its own rarity. Weight = base × (1 + luck × 1.0)^tier, so Luck pushes rolls up the tiers.

| Tier | Base weight | Tome/stat multiplier | Weapon facets raised | Facet step size |
|---|---|---|---|---|
| Common | 60 | ×1.0 | 1 | ×1.0 |
| Uncommon | 25 | ×1.5 | 1 | ×1.5 |
| Rare | 10 | ×2.0 | 2 | ×1.5 |
| Epic | 4 | ×3.0 | 2 | ×2.0 |
| Legendary | 1 | ×5.0 | 3 | ×2.5 |
| Boss | — | powerups only (a boss's own drop) | — | — |
| Cursed | — | powerups only (blood-red chests) | — | — |

**Weapon facet steps:** "pct" and "add" facets gain step × size. "count" facets gain max(round(step × size), 1).

### Player base (every class is the same here)

| Stat | Value |
|---|---|
| Max HP | 100 + 10 per level after the 1st |
| I-frames after a hit | 0.7 s |
| Regen | 0 HP/s |
| Revive (co-op) | Stay within 8 m (the same as the chest-opening reach) of a downed teammate for 3 s; they get up with 50% HP |
| XP to next level | 5 × level^1.9 |

---

## 2. Stats (`stat_block.gd`)

Every stat starts at 0 and is a bonus. Percent stats are shares (0.1 = +10%); the others are flat. The **step** is what one common card gives.

| Stat id | Name | Step (common) | Type | In every card pool? | Tome | Powerups that add to it |
|---|---|---|---|---|---|---|
| `max_hp` | Max HP | +10 | flat | yes | Shell | Hermit Shell (+15); Glass Coral (×0.5) |
| `regen` | Regen | +0.4 HP/s | flat | yes | Shell | Kelp Wrap (+0.5) |
| `armour` | Armour | +1 | flat (each hit is reduced by this, min 1) | yes | Shell | Barnacle Plating (+2) |
| `damage` | Damage | +10% | % | yes | Teeth | Blood Moon Shard, Glass Coral (+100%) |
| `attack_speed` | Attack Speed | +8% | % | yes | Tides | Fizzy Soda (+8%) |
| `size` | Size | +10% | % | yes | Reef | Abyssal Engine (+15%) |
| `quantity` | Quantity | +1 (rounded up) | flat; a real number (the Drifters' signature adds +0.33 a level): what spawns, and what's shown, is its floor | only if a weapon held uses it (Thrust, Bubbles, Spines, Lash, Punch, Purple Haze, Halo) | Schools | Abyssal Engine (+1) |
| `projectile_speed` | Projectile Speed | +10% | % | only if the attack uses it (Thrust, Bubbles, Spines) | Currents | — |
| `crit_chance` | Crit Chance | +5% | % | yes | Kill | Sea Salt (+5%) |
| `crit_damage` | Crit Damage | +20% | % | yes | Kill | — |
| `swim_speed` | Swim Speed | +5% | % | yes | Fins | Speedy Seahorse (+6%) |
| `stride_power` | Stride Power | +6% | % | yes | Fins | — |
| `battery_damage` | Battery Damage | +15% | % | yes | Ram | Coral Knuckles (+20%) |
| `knockback` | Knockback | +15% | % | yes | Currents | — |
| `duration` | Duration | +10% | % | no (only once something uses it) | Ages | — |
| `pickup_range` | Pickup Range | +15% | % | yes | Pearls | Diver's Goggles (+25%) |
| `xp_gain` | XP Gain | +8% | % | yes | Pearls | Siren's Song (+100%) |
| `pearl_chance` | Pearl Chance | +15% | % | yes | Pearls | — |
| `luck` | Luck | +0.1 | flat | yes | Fortune | Lucky Sand Dollar (+0.1) |

**What the global stats scale on weapons:** Attack Speed → fire/drop/tick rate (2× for Purple Haze's scatter rate, `haze_speed_weight`). Quantity → spears, bubbles, spine rings, lash arcs, punch follow-up gloves, haze bombs per scatter, Halo jellies. Size → every weapon's reach, radius, blast or hit size (every weapon, plus the area powerups such as Electric Eel, Torpedo, Tsunami Heart; Anemone Sting and Shock Lash get only half of the bonus, `sting_size_weight` / `lash_size_weight` 0.5). Duration → Greek Fire patch life, Purple Haze cloud life, Anglerfish Lure, Ink Sac. Damage → every hit (applied in `UnnaturalRun.hit()`).

---

## 3. Playable classes

A **class** is a group of fish that play the same way; its **species** change only the look. Every class has the same base stats. They differ in their starting weapon, their **signature stat** (+1 step every level, free), a passive **twist**, and a **mobility skill** on the boost button (RB / Shift).

| Class (enum, RL hitbox) | Species | Starting weapon | Signature stat (per level) | Passive twist | Mobility skill |
|---|---|---|---|---|---|
| **Skirmishers** (SKIRMISHER, Octane) | Clownfish: Ocellaris, Black Percula, Tomato, Gold-stripe Maroon | Anemone Sting | Size +10% | **Nimble:** turns 1.4× as sharply (+40%) | **Wriggle:** 16 m/s burst sideways (where the stick leans, else backwards), 0.3 s untouchable. Cooldown 2.0 s |
| **Hunters** (HUNTER, Dominus) | Sharks: Great White, Shortfin Mako, Blacktip Reef, Tiger, Hammerhead | Ghost Bite | Damage +10% | **Frenzy:** +4% swim speed per kill (max +50%), held 3 s after the last kill, then fades | **Fin Dash:** charges at 45 m/s for 0.45 s, untouchable, batters everything in the way; 90 dmg to each zombie within 3 m. Cooldown 3.0 s |
| **Gliders** (GLIDER, Plank) | Rays: Manta, Spotted Eagle Ray, Southern Stingray, Blue-spotted Ribbontail | Shock Lash | Attack Speed +8% | **Glide:** keeps only 30% of the drag when coasting | **Surge:** a 22 m/s stroke forward, no drag for 1.5 s. Cooldown 4.0 s |
| **Lancers** (LANCER, Breakout) | Billfish: Broadbill Swordfish, Blue Marlin, Sailfish, Striped Marlin | Bill Thrust | Projectile Speed +10% | **Streamlined:** swims +10% faster | **Dash:** a 14 m/s burst along its nose, 0.3 s untouchable. Cooldown 2.5 s |
| **Charmers** (CHARMER, Hybrid) | Butterfly koi: Kohaku, Showa, Yamabuki Ogon, Asagi | Bubble Volley | Luck +0.1 | **Graceful:** +0.5 s of i-frames after every hit (1.2 s total) | **Leap:** leaps up at 12 m/s; at the top it splashes down for 30 dmg within 7 m. Cooldown 2.5 s |
| **Bulwarks** (BULWARK, Merc) | Boxfish: Yellow Boxfish, Longhorn Cowfish, Spotted Boxfish, Scrawled Cowfish | Spine Burst | Armour +1 | **Armoured:** takes 70% of damage, swims at 88% speed | **Brace:** for 2.5 s takes 25% of damage, swims at 70% speed. Cooldown 8.0 s |
| **Scorchers** (SCORCHER, Octane) | Lionfish: Red, Clearfin, Fuzzy Dwarf, Spotfin | Greek Fire Trail | Duration +10% | **Wake:** Greek Fire burns up to +60% harder the nearer it swims to battering speed | **Flare Dash:** dashes at 30 m/s for 0.35 s; 60 dmg to everything within 4 m on the way. Cooldown 3.5 s |
| **Drifters** (DRIFTER, Hybrid) | Jellies: Moon Jelly, Pacific Sea Nettle, Lion's Mane, Purple-striped Jelly (tilt and pulse: upright at rest, leaning bell-first as they swim) | Jellyfish Halo | Quantity +0.33 (`signature_quantity`; the floor counts) | **Many Arms:** +1 jelly in its Halo | **Go Quiet:** switches its stink off for up to 8 s: nothing fires and zombies lose track of it. Being hurt ends it, or press again to end it early. Cooldown 6.0 s |
| **Brawlers** (BRAWLER, Dominus) | Mantis shrimp: Peacock, Zebra, Purple-spot, Pink-eared | Cavitation Punch | Knockback +15% | **Heavy Hitter:** a zombie its punches knock back flies as a missile for 0.35 s; each other zombie it hits (up to 3) takes 50% of the punch, knocked on. At most 24 missiles at once | **Recoil Dash:** throws a full Cavitation Punch one way and is thrown the other at 20 m/s, no drag for 0.25 s, untouchable 0.2 s. It goes the way the stick leans, else backwards (so the punch goes ahead). Cooldown 2.0 s |
| **Breachers** (BREACHER, Plank) | Baby whales: Humpback Calf, Orca Calf, Beluga Calf, Sperm Whale Calf, Blue Whale Calf (up-and-down fluke strokes) | Remora Buddy | Pearl Chance +15% | **Escort:** heals 4 HP/s while holding still (under 3 m/s) | **Gulp:** pulls in every zombie in a 14 m cone ahead (25 m/s) and hits each for 25. Cooldown 5.0 s |
| **Alchemists** (ALCHEMIST, Merc) | Sea hares (California, Spotted, Ragged) and a nudibranch (Tinctoria) | Purple Haze | Regen +0.4 HP/s | **Unpalatable:** a zombie that touches it is coated for 2 s: slowed 30%, and takes +20% from Purple Haze | **Flutter:** 3 big flaps 0.25 s apart, each a 9 m/s push forward and up (60% up), carrying it up over the pack; a Purple Haze cloud bursts where it took off. Cooldown 4.0 s |

- Every class starts with its own weapon (a `FishAttack`, `FishAttack.FOR_CLASS`) in slot 1, as the `attack` weapon.
- Species: each class has several real species or colour morphs (`FishCharacter.SPECIES`). They change only the look, never stats.
- The RL hitbox is the Rocket League box the class uses (RL replays name it; later classes share one of the first six). Saves and clips from before classes still load: the old keys (`octane`, `mantis`, `whale_shark`...) are aliases.
- The twist switch is `UnnaturalSettings.twists`. Off, every class swims the same.
- Gaits (`GaitSettings`, the GAITS tuning section) change how a class's strides move and look, not the controls. Breachers: vertical fluke strokes (any sweep counts; a sideways one alternates up and down), same pace as the Gliders. Drifters: each stride is a short squeeze along the bell (stroke time ×0.8, power ×0.8), then a draggy coast (×1.8 drag, sinking 2 m/s²); the bell leans up to 75° toward the nose as it swims. Alchemists: flap. `in_fish_sticks` off gives every class the plain fish gait in Fish Sticks.
- **Titans** (TITAN, `titan`; hidden: not in any picker, `FishCharacter.pickable_classes()` leaves it out). Adult whales: Humpback, Orca, Beluga, Sperm, Blue, 3 skins each (`titan_model.gd`; specs in `titan_specs.md`, art log in `titan_art_log.md`). Hitbox 670 × 240 × 190 uu (6.7 m, 5× the longest hider's). Only **Marco Polo** uses them, as the seeker (`MarcoPoloSettings` Whale group; the player's own look is kept in meta `mp_base_look` while swapped). No weapon, stat or skill here: they aren't playable in Unnatural. Gait: vertical fluke strokes with a power/recovery beat, a chained bend, head counter and flipper trim (Titan-only Gait exports: `fluke_amplitude`, `fluke_power_ratio`, `fluke_snap`, `bend_segments`, `bend_lag`, `head_counter`, `body_surge`, `flipper_trim`, `turn_bank`, `power_stroke_speed`); each power stroke emits `FishModel.power_stroke`.

---

## 4. Weapons (`weapons.gd`)

Weapons level up from level-up cards (they never come from chests) and go up to Lv 20. Each card raises one or more **facets**, chosen at random (how many depends on rarity, see §1). The steps below are what one common step adds. A fish's starting weapon takes one of its 2 slots.

**Every weapon is a `FishAttack`, and every weapon can be any class's second weapon.** A class's own is the `attack` weapon. Held as a second weapon (an `AttackWeapon`), its id is `attack_` + its hit source (`attack_bite`, `attack_greek_fire`...). Level-up cards offer all of §4a and §4b (`Weapons.card_pool`), except the weapon the fish already holds. (Leviathan's Coil is a boss item now, §6 Boss tier; old `attack_leviathans_coil` ids map to `leviathans_coil`.)

The split below is about how a weapon works, not who can get it. **Fired** weapons (4a) go off on a cooldown and share one set of facets. **Steady** weapons (4b) work all the time on their own timers, and each has its own facets.

### 4a. Fired weapons

Shared facet steps (`PowerupSettings`): Damage +20%, Rate +12%, Size +12%, Knockback +30%, Count +1, Speed +15%.

| Weapon (second-weapon id) | Class | Base damage | Cooldown | Proc | Base numbers | Facets |
|---|---|---|---|---|---|---|
| **Anemone Sting** (`attack_sting`) | Skirmishers | 9 | 0.9 s | 0.6 | A pulse 6.5 m round the fish (always at least 1.4× the bow wave's reach). Hits everything inside. Only fires when a zombie is close. Its pull milestone draws zombies from 1.4× the pulse (`sting_pull_reach`) at 3 m/s (`sting_pull_speed`), stopping 3 hitbox lengths short of the fish (`sting_pull_stop`). | Damage, Attack rate, Pulse size, Knockback |
| **Ghost Bite** (`attack_bite`) | Hunters | 26 | 0.9 s | 1.0 | Jaws 8 m long, 4.5 m half-width (always at least 1.6× the bow wave). Aims at the nearest zombie within 110° of the nose. | Damage, Bite rate, Jaw size, Knockback |
| **Shock Lash** (`attack_lash`) | Gliders | 47 | 0.8 s | 1.0 | Whips the nearest zombie within 14 m. It arcs on to 1 more (+1 per Quantity) within 8 m of the last, each arc doing 70%. | Damage, Lash rate, Lash reach, Arcs (count) |
| **Bill Thrust** (`attack_thrust`) | Lancers | 40 | 1.0 s | 1.0 | A spear at 45 m/s that flies 40 m with a 0.7 m hit radius and pierces 6. Aims within 60° of the nose. Extra spears fan 8° apart. | Damage, Thrust rate, Spears (count), Spear speed |
| **Bubble Volley** (`attack_bubbles`) | Charmers | 9 per pop | 1.2 s | 0.6 | 4 homing bubbles (+Quantity) at 18 m/s, turn rate 6/s, 2.5 s life, 30 m range. Each pops on its first touch with a 2 m splash. | Damage, Volley rate, Bubbles (count), Bubble speed |
| **Spine Burst** (`attack_spines`) | Bulwarks | 32 | 1.4 s | 0.4 | 18 spines all round (+4 per Quantity) when a zombie is within 12 m. 30 m/s, pierce 2. | Damage, Burst rate, Spine rings (count), Spine range |
| **Cavitation Punch** (`attack_punch`) | Brawlers | 40 + 15 | 0.35 s | 1.0 (collapse 0.5) | A boxing glove at 30 m/s that flies 10 m (always at least 1.2× the bow wave's reach) with a 0.8 m hit radius, fading out over the last 40%. Aims at the nearest zombie within 60° of the nose (else straight on, if one is within reach ahead). It strikes the first zombie it touches (knockback 1×; `punch_knock_max` can cap how fast it flies off, 0 = off), then 0.08 s later the bubble collapses there: 50% of the strike to every zombie within 2 m. Each Quantity throws one more glove from the other claw, 0.1 s apart. | Damage, Punch rate, Glove size, Knockback |

**Milestones (Lv 5 / 10 / 15 / 20):**

| Attack | Lv 5 | Lv 10 | Lv 15 | Lv 20 |
|---|---|---|---|---|
| Anemone Sting | A second, wider pulse follows each sting | Stings slow what they hit | Pulses draw zombies in from further out | A third pulse follows, wider still |
| Ghost Bite | A second set of jaws snaps behind you | Jaws snap at both sides too | Jaws snap above and below you too | Every bite snaps twice |
| Shock Lash | Each lash strikes a second zombie too | Arcs jump twice as far | Each arc jumps on to two more zombies | Each lash strikes a third zombie too |
| Bill Thrust | Spears pierce one more zombie | Spears burst at the end of their flight | Two more spears fan out with each thrust | Spears pierce everything in their way |
| Bubble Volley | Bubbles pop in a wider splash | Every volley ends with one big bubble | Each volley blows twice as many bubbles | Every volley ends with three big bubbles |
| Spine Burst | Spines fly further | A second ring of spines follows each burst | Spines pierce two more zombies | A third, full ring follows the second |
| Cavitation Punch | The bubble collapses in a ring 1.5× as wide | Collapses stun what they hit for 0.5 s (not Heavy Hitter's missiles) | Gloves pierce one zombie, collapsing at each hit | Every third punch is a Haymaker: 2× the glove, and its collapse hits for 100% |

### 4b. Steady weapons

| Weapon (second-weapon id) | Class | Base numbers | Proc | Facets (common step) |
|---|---|---|---|---|
| **Greek Fire Trail** (`attack_greek_fire`) | Scorchers | Drops a burning patch every 1.6 m swum. Each patch is 1.6 m in radius, lasts 2.0 s (× Duration) and burns for 40 dmg/s. At most 60 patches out. | 0 | Burn damage +25%, Patch life +0.4 s, Patch size +10%, Denser trail +12%, Max patches +5 |
| **Jellyfish Halo** (`attack_jellyfish_halo`) | Drifters | 4 jellies orbit 3.2 m out at 0.5 turns/s. Each stings for 45 every 0.25 s on touch (1.2 m radius). | 0.1 | Jellies +1, Sting damage +25%, Orbit size +12%, Orbit speed +15%, Sting rate +15% |
| **Purple Haze** (`attack_purple_haze`) | Alchemists | Every 3.5 s it scatters 3 bombs (+1 per Bombs per scatter, +1 per Quantity) over 0.4 s, each lobbed over 0.45 s at the densest pack within 12 m (× Size) in any direction, led by the pack's velocity; the next go to other packs apart from it, the rest along the best pack's path. It holds the scatter while no zombie is within reach. Each bursts as it lands into a cloud 4 m round (× Size) that lasts 5 s (× Duration): 12 dmg every 0.5 s to each zombie inside, and they're hazed (slowed 50%). Attack Speed counts 2× toward its scatter rate. At most 12 clouds (the oldest go). Merged clouds (its Lv 10 milestone) keep the summed damage of the clouds they swallowed, up to 0.5× a full scatter's (`haze_merge_damage_cap`), and grow to at most 2.5× (`haze_merge_max`). Replaced Depth Charges (Phase 3): old `attack_depth_charges` ids map to it. | 0.15 | Cloud damage +25%, Cloud size +12%, Cloud life +0.8 s, Bombs per scatter +1, Scatter rate +15% |
| **Remora Buddy** (`attack_remora_buddy`) | Breachers | 1 remora nips the nearest zombie within 9 m every 1.5 s for 70. A nip that kills gives back the unused share of its damage as a shorter wait (`remora_kill_refund` 1.0). The tear milestone hits zombies within 2.5 m for 25% (`remora_tear_reach`, `remora_tear_share`). | 0.5 | Remoras +1, Bite damage +15%, Bite rate +15%, Reach +15% |

**Milestones (Lv 5 / 10 / 15 / 20):**

| Weapon | Lv 5 | Lv 10 | Lv 15 | Lv 20 |
|---|---|---|---|---|
| Greek Fire Trail | Zombies that burn to death leave a patch behind | The trail fans out three wide | Patches flare up every few seconds, scorching wider | The flames creep toward the nearest zombie |
| Jellyfish Halo | Each jelly trails a ghost that stings too | The halo swings out wide every few seconds | A second, wider halo circles the other way | Stings jump on to the nearest zombie |
| Purple Haze | Opaline: zombies stay slowed 30% for 2 s after leaving a cloud | Clouds that touch merge into one bigger cloud | Zombies that die hazed burst into a small cloud | Clouds creep toward the nearest zombie |
| Remora Buddy | Remoras latch on and keep biting | A kill splits a remora in two for a while | Bites tear into the zombies round the one bitten | Remora kills heal you a little |

**Proc coefficient:** chances to trigger on-hit powerups (Chain Lightning, Torpedo, Sticky Anemone...) are multiplied by the hit's proc. A hit started by a powerup can't start that same powerup again. Other procs: lightning jump 0.3, torpedo 0.5, burn 0 (P4: weapons that hit very often start nothing).

---

## 5. Tomes (`tomes.gd`)

A tome is a global stat that levels up (max Lv 99). One card adds one step of each of its stats × the card's rarity multiplier. **A tome with more than one stat gives each of them 70% of a step** (`tome_multi_share`).

| Tome (id) | Stats | Common card | Legendary card (×5) |
|---|---|---|---|
| **Tome of Teeth** (`teeth`) | Damage | Damage +10% | Damage +50% |
| **Tome of Tides** (`tides`) | Attack Speed | Attack Speed +8% | +40% |
| **Tome of the Reef** (`reef`) | Size | Size +10% | +50% |
| **Tome of Schools** (`schools`) | Quantity | Quantity +1 | +5 |
| **Tome of Currents** (`currents`) | Projectile Speed, Knockback | +7%, +10.5% | +35%, +52.5% |
| **Tome of the Kill** (`kill`) | Crit Chance, Crit Damage | +3.5%, +14% | +17.5%, +70% |
| **Tome of Fins** (`fins`) | Swim Speed, Stride Power | +3.5%, +4.2% | +17.5%, +21% |
| **Tome of the Ram** (`ram`) | Battery Damage | +15% | +75% |
| **Tome of the Shell** (`shell`) | Max HP, Armour, Regen | +7, +0.7, +0.28 HP/s | +35, +3.5, +1.4 HP/s |
| **Tome of Pearls** (`pearls`) | XP Gain, Pearl Chance, Pickup Range | +5.6%, +10.5%, +10.5% | +28%, +52.5%, +52.5% |
| **Tome of Fortune** (`fortune`) | Luck | +0.1 | +0.5 |
| **Tome of Ages** (`ages`) | Duration | +10% | +50% |

Tome of Ages only matters for Greek Fire, Purple Haze and Anglerfish Lure (`DURATION_WEAPONS`, `DURATION_ITEMS`; Ink Sac reads Duration too).

---

## 6. Powerups (items) (`powerup.gd`, `powerup_settings.gd`)

Items come from **chests**, never from level-up cards. A chest rolls a rarity with the opener's Luck and offers 3 different items. It starts with that tier, then fills from the tiers below it (nearest first), then the tiers above. Taking an item you already hold adds a **stack**. Unless a row says otherwise, "+X/stack" means **each stack after the first** adds X (base + X × (stacks − 1)) before P4's stacking curve: later stacks count for less (see Limits in §1). The flat stat items add their amount for each stack, on the gentler stat-item curve.

### Common

| Item (id) | Effect | Stacking |
|---|---|---|
| **Kelp Wrap** (`kelp_wrap`) | Regen +0.5 HP/s | +0.5 HP/s per stack |
| **Sea Salt** (`sea_salt`) | Crit Chance +5% | +5% per stack |
| **Coral Knuckles** (`coral_knuckles`) | Battery Damage +20% | +20% per stack |
| **Diver's Goggles** (`divers_goggles`) | Pickup Range +25% | +25% per stack |
| **Lucky Sand Dollar** (`lucky_sand_dollar`) | Luck +0.1 | +0.1 per stack |
| **Barnacle Plating** (`barnacle_plating`) | Armour +2 | +2 per stack |
| **Hermit Shell** (`hermit_shell`) | Max HP +15 | +15 per stack |
| **Fizzy Soda** (`fizzy_soda`) | Attack Speed +8% | +8% per stack |
| **Speedy Seahorse** (`speedy_seahorse`) | Swim Speed +6% | +6% per stack |
| **Sticky Anemone** (`sticky_anemone`) | Hits: 10% chance (× proc) to slow a zombie 40% for 2 s | +5% chance/stack |
| **Ink Sac** (`ink_sac`) | When hurt: an ink cloud of 6 m blinds zombies (they lose you and keep only 10% of their speed) for 2 s (× Duration) and pushes them off. At most once every 3 s | +0.5 s/stack |
| **Bubble Wrap** (`bubble_wrap`) | Blocks the next hit after 8 s untouched, then pops | Ready time −1 s/stack (min 2 s) |
| **Bow Grow Bow** (`bow_grow_bow`) | Bow wave length and girth ×(1 + 0.5 × stacks), so you batter wider | From 3 stacks it also batters at as little as 50% of battering speed |

### Uncommon

| Item (id) | Effect | Stacking |
|---|---|---|
| **Lamprey** (`lamprey`) | Each kill heals 1 HP (at most once every 0.1 s) | +1 HP per stack |
| **Clam Shield** (`clam_shield`) | Blocks a hit every 12 s. Recharges whether or not you're hurt | Ready time −2 s/stack (min 3 s) |
| **Momentum Fin** (`momentum_fin`) | Damage +10% per 10 m/s you're swimming | +10% per 10 m/s per stack |
| **Treasure Map** (`treasure_map`) | Chest drops +30%, chest ping range +10 m | +30% and +10 m per stack |
| **Sonar Pinger** (`sonar_pinger`) | Every 6 s a pulse marks every zombie within 25 m. Your hits on marked zombies do +25% | +10%/stack |
| **Cold Seep** (`cold_seep`) | Hits: 8% chance (× proc) to freeze a zombie for 1.5 s. Bosses are immune | +4% chance/stack |
| **Whirlpool Charm** (`whirlpool_charm`) | Kills: 6% chance to open a whirlpool for 3 s: 6 m radius, pulls zombies in at 12 m/s, 30 dmg/s. At most 4 out | +3% chance, +15 dmg/s per stack |
| **Chain Lightning** (`chain_lightning`) | Hits: 15% chance (× proc) to start lightning that jumps 3 times, up to 8 m per jump, 22 dmg per jump. At most 30 strikes/s | +8% chance, +1 jump per stack |
| **Pufferfish Spines** (`pufferfish_spines`) | A zombie that touches you takes back 50% of what it did. A spine burst then hits everything within 4 m for 25 (proc 0.5) | +25% reflect, +15 burst dmg per stack |
| **Electric Eel** (`electric_eel`) | Each battery sends out a 5 m shock ring (× Size) for 30 dmg (proc 0.5). At most once every 0.3 s | +1 m radius, +20 dmg per stack |

### Rare

| Item (id) | Effect | Stacking |
|---|---|---|
| **Torpedo Launcher** (`torpedo`) | Hits: 8% chance (× proc) to fire heat-seeking torpedoes (18 m/s, 3 s life) that explode for 40 in 3 m (× Size). At most 48 flying | +5% chance, +0.6 m blast per stack; +1 torpedo every 2 stacks |
| **Kraken's Grasp** (`krakens_grasp`) | Hits: 5% chance (× proc) that a tentacle slams the zombie: 120 dmg within 4.5 m, and the zombies hit are held still for 1.5 s. At most 2 slams/s | +2.5% chance, +60 dmg per stack |
| **Ghost Swordfish** (`ghost_swordfish`) | Every 3 s a phantom swordfish dashes 18 m through the nearest line of zombies within 20 m: 60 dmg to each within 1.5 m of its path | +1 swordfish per stack |
| **Ammonite Spiral** (`ammonite_spiral`) | Projectile hits (spears, bubbles, spines, torpedoes) split into 3 shards. Each shard goes to another zombie within 8 m for 35% of the hit. At most 20 splits/s | +1 shard per stack |
| **Riptide** (`riptide`) | A stride timed at its peak (timing ≥ 0.75) leaves a 10 m current behind you (2.5 m each side) for 3 s. Zombies in it are dragged back at 8 m/s and take 25 dmg/s. At most 6 currents out (a new one replaces the oldest) | +12 dmg/s per stack |
| **Reef Guardian** (`reef_guardian`) | Dropping under 25% HP makes you untouchable for 3 s. Recharges in 60 s | Recharge ×0.85 per extra stack |
| **Bioluminescence** (`bioluminescence`) | Each level-up and each chest you open sends out a flash: 12 m radius (× Size), 10 dmg × team level | +2 m radius, +5 dmg per level per stack |
| **Anglerfish Lure** (`anglerfish_lure`) | Every 10 s it drops a glowing decoy (pull 3: zombies prefer it over a player up to 3× nearer) for 5 s (× Duration). Then it bursts for 80 dmg in 6 m (proc 0.5). At most 3 lures out | Interval ×0.9 per extra stack, +50 dmg per stack |

### Legendary

| Item (id) | Effect | Stacking |
|---|---|---|
| **Tsunami Heart** (`tsunami_heart`) | Each battery sends a wave along your heading: 6 m wide (× Size), rolling 24 m at 30 m/s. Every zombie it reaches takes 60 dmg and is swept along (proc 1.0). At most one wave per second | +2 m width, +40 dmg per stack |
| **Poseidon's Trident** (`poseidons_trident`) | Every 3rd attack of a fired weapon (every 3 s for a fish with only steady ones) calls lightning down on the biggest zombie within 30 m: 250 dmg within 4 m | +150 dmg per stack |
| **Megalodon Tooth** (`megalodon_tooth`) | Crits finish off zombies under 15% HP (not bosses) | +5%/stack, max 50% |
| **Moon Pearl** (`moon_pearl`) | Take +1 card from each level-up offer | +1 per stack |
| **Abyssal Engine** (`abyssal_engine`) | Quantity +1, Size +15% | +1 and +15% per stack |
| **Drowned Jaws** (`drowned_jaws`) | **The Drowned Shark's own drop** (its JawsChest, beside its legendary pick; never in a chest's, shrine's or card's pool). Every 6 s (× attack speed) your next attack (a fired weapon's; at once with only steady ones) is a chomp too: 400 dmg on the zombie or boss nearest straight ahead within 7 m (× Size) and 45°, with a chomp's impact at half a boss chomp's (`jaws_impact` 0.5): the big number, blood and teeth, a camera punch | Every 6 s ÷ (1 + 0.3 per extra stack), +100 dmg per stack; outside the limits (no falloff) |

### Boss (final bosses' chests only)

**Boss items** (planning_bosses_and_survival.md §2): each final boss's chest holds its own, with no pick screen. They take **no weapon slot**, **stack** (a second copy, from that boss again or in co-op, adds a stack) and are **outside the item limits**: no stack falloff, never refused. Never offered by level-up cards, treasure or cursed chests, shrines or the Shark's legendary pick. Their card is a hexagon in the boss material (dark crimson glass, a gold trim); their HUD and summary colour is the boss tier's steel blue. Co-op: every player gets their own copy from the chest (`boss_item_every_player` on); off, the first to take it takes it for everyone. Bosses aren't pulled, held or slowed by them, only hurt.

| Item (id) | Boss | Effect (1 stack) | Each stack after the first |
|---|---|---|---|
| **Leviathan's Coil** (`leviathans_coil`) | King of Herrings | Was a boss weapon. Works as a Lv 10 Coil (`coil_arrive_level`): 6 coils trail the fish 1.4 m apart, each hurting what it touches (0.9 m radius) for 75 every 0.25 s (proc 0.15), with a facet step for each level below its own, in turn (Coils +3, Coil damage +25%, Coil size +15%, Hit rate +15%). Milestones by its level: Lv 5 coils slow what they touch; Lv 10 its head snaps at zombies near it; Lv 15 its tail lashes out in a shock ring; Lv 20 it grows twice as long | +3 levels (`coil_levels_per_stack`): Lv 13, 16, 19... |
| **Gulper's Maw** (`gulpers_maw`) | Gulper Mother | Every 6 s (× attack speed) a maw opens 6 m ahead and sucks in the zombies within 9 m (× Size) for 1.2 s, then swallows up to 8 within 3.5 m, chews each for 40 and spits them out in a fan, each with a volley bolt 20 m long, 1.4 m wide (× Size): 90 dmg to every zombie it passes (proc 0.5) | +4 swallowed, +30 bolt dmg, cooldown ÷ (1 + 0.2 per extra stack) |
| **Hagfish Brood** (`hagfish_brood`) | Whale Fall | 2 hagfish on tethers. Each, every 1.6 s (× attack speed), lunges at a zombie within 10 m (a different one each), bites it for 50 (proc 0.4) and knots on, holding it still for 1.2 s (× Duration); let go, it's slimed: 50% slower for 3 s (× Duration) | +1 hagfish, +15 bite dmg |
| **Queen's Disc** (`queens_disc`) | Lamprey Queen | A lamprey latches onto the toughest zombie (or boss) within 14 m and corkscrews in: every 0.5 s it drains 45 (proc 0.2) and heals you 1.5 HP. It lets go past 24 m, and re-latches 0.3 s after its host dies | +20 drain, +1 HP heal per drain |
| **Angel's Crown** (`angels_crown`) | Fallen Angel | Every 5 s (× attack speed) a crown of tentacles bursts from your head and lashes the cone ahead 3 times, 0.18 s apart: each lash 70 dmg (proc 0.4) to every zombie within 10 m (× Size) and 50° of straight ahead. Each zombie it kills heals you 1 HP | +1 lash, +10° (max 180°), +20 dmg, +0.5 HP per kill, cooldown ÷ (1 + 0.1 per extra stack) |

The Test Tank gives any of them (or all, with Drowned Jaws) at N stacks: `tank_boss_item`, `tank_boss_item_stacks`. Each also has a stacks override for testing (`coil_stacks`, `maw_stacks`, `brood_stacks`, `disc_stacks`, `crown_stacks`, `jaws_stacks`).

### Cursed (blood-red chests only)

Each one is strong but has a catch (the second column). Luck doesn't change the cursed-chest chance.

| Item (id) | Upside | Downside | Stacking |
|---|---|---|---|
| **Blood Moon Shard** (`blood_moon_shard`) | Damage +100% | Damage taken +50% | Both per stack |
| **Glass Coral** (`glass_coral`) | Damage +100% | Max HP ×0.5 | Both per stack |
| **Siren's Song** (`sirens_song`) | XP Gain +100% | Zombies +50% | Both per stack |
| **Abyssal Hunger** (`abyssal_hunger`) | Kills heal 3% of max HP | Lose 2% of max HP per second. The drain can't kill: it stops at 1 HP (`hunger_can_kill` off) | Per stack |
| **Sunken Idol** (`sunken_idol`) | +1 pick from every chest | Each stage event takes a stack of a random other powerup | Per stack |

---

## 7. Bonuses, drops and other rewards

### Per level-up

| Bonus | Value |
|---|---|
| Max HP | +10 |
| Signature stat | +1 step (`signature_steps`) of the fish's own stat (§3); the Drifters' Quantity is +0.33 (`signature_quantity`) |
| Cards | Pick 1 of 3 (+ Moon Pearl) |
| Bioluminescence | A flash, if held |

### Kill drops (`pickup.gd`): the first player to touch one takes it. Elites have 5× the chance

Drops are timed as well as rolled: after a drop of a kind, that kind waits its "at most every" time, and after any drop nothing drops for 20 s (`drop_gap`). Once the wait's up, kills roll the chance again.

| Drop | Chance per kill | At most every | Effect |
|---|---|---|---|
| **Heart** | 0.15% | 45 s | Heals the whole team for 50% of max HP |
| **Magnet** | 0.15% | 90 s | Every XP pearl out flies to the taker |
| **Hourglass** | 0.15% | 120 s | Every zombie stops dead for 15 s (bosses don't) |
| **Lightning Bolt** | 0.15% | 150 s | A shock across the whole arena kills every zombie (bosses are spared). Its kills drop no chests or other drops |

### Pearls (currency)

| Source | Value |
|---|---|
| Kill | 5% chance × (1 + Pearl Chance) |
| Elite kill | 30% chance × (1 + Pearl Chance), worth 1 |
| Mini-boss (Drowned Shark) | 25 pearls |
| Pickup range | 10 m (× (1 + Pickup Range)), pulled in at 12 m/s |

### Chests (`treasure_chest.gd`)

| Rule | Value |
|---|---|
| At the start | 10 buried; then 1 more every 60 s × (1 + 0.1 × minutes into the stage), up to 16 unopened. A won Shrine of the Tide raises a free one |
| Kill drop | 0.2% × (1 + luck), elites ×2, × Treasure Map, elites with a modifier ×1.5 more; ÷ (1 + 0.06 × minutes into the stage) (P4) |
| Cursed chance | 10% of buried chests (blood red, offers cursed items) |
| Opening | Batter it, or hold still (< 3 m/s) within 8 m for 2 s. You can't be hurt or seen while you pick |
| Choices | 3 items |
| Price | 8 pearls, +25% of the base for each chest you've already bought on this map. Cursed chests cost 1.5×; boss chests are free |
| HUD ping range | 35 m (+ Treasure Map) |

### Batteries (ramming)

| Rule | Value |
|---|---|
| Damage | 60 at battering speed × (speed ÷ battering speed)^1.5, × (1 + Battery Damage) |
| I-frames | 0.3 s per battery |
| Same-zombie repeat | 0.35 s |
| Big zombie (size ≥ 1.5) | Takes 20% of your speed |
| Safe ramming | Swimming into a zombie within 60° of your heading while faster than it doesn't hurt you (bosses still do) |
| Triggers | Electric Eel, Tsunami Heart |

### Bosses

| Boss | Reward |
|---|---|
| **Drowned Shark** (mini-boss, 5:00) | A chest (a legendary pick) and a second chest with Drowned Jaws (§6, Legendary), 80 XP, 25 pearls. Its chomp: a player within 14 m ahead makes its jaw drop open (0.75 s) and snap shut, 24 to everyone within 6 m of its mouth (every 3.5 s); touching it costs 15. It charges every 9 s and calls 10 sardines round its target every 16 s; charging, its jaws hang open and snap on the first player they reach |
| **Final boss** (10:00): the King of Herrings, or one of its alternates (40%: each equally likely) | Its own boss item in its chest (§6 Boss tier): the King Leviathan's Coil, the Gulper Gulper's Maw, the Whale Fall Hagfish Brood, the Lamprey Queen's Disc, the Angel Angel's Crown. Its chest opens with a bigger burst and its own sound. The whirlpool: the next stage, or on the run's last stage the win |
| Shrine of the Deep (each, this stage) | One more boss chest (legendary pick) from every boss beaten |

### Final bosses (`scripts/unnatural/bosses/`): all share the Blood Leviathan settings (hp 90,000 × co-op, speed 15, enrage at 2 min), circle then spit (from 2/3 hp) then fury (under 1/3)

| Boss | Body | Its own moves |
|---|---|---|
| **The King of Herrings** (default) | A 109 m rotting giant oarfish: torn silver ribbon, peeling skin and flayed wounds, a crimson dorsal fin its whole length, a crest of blood-red filaments, milky eyes, a gaping toothed jaw, lampreys feeding on it | Spits shards of its rotting scales. Chomps in any phase: a player within 18 m ahead makes its jaw gape (0.55 s) and snap, 30 within 7 m of its mouth (every 3 s). In fury it coils round a player it reaches: up to 2 loops, 11 m round them tightening to 5 m, its squeeze draining up to 2× as it tightens; each stride (and each 1% of its hp a friend knocks off) loosens it |
| **The Gulper Mother** | A 92 m gulper eel: a pouch of a mouth on thin jaws, needle teeth, a stretched glowing belly showing the zombies it swallowed, a whip tail with a glowing lure | Every 7 s gulps the zombies within 20 m of its mouth (up to 40), each healing 0.3% of its hp; spits bile and vomits 12 zombies; in fury it sucks a player in front of its mouth (within 26 m) in at up to 14 m/s; one it reaches is swallowed as its jaws snap shut: hidden, a lump sliding into its belly and back up with each stride, coughed out the front |
| **The Whale Fall** | A 45 m dead blue whale on its side, chest torn open to the ribs, with 5 giant hagfish (22 m) coming out of its eye sockets, chest, a wound and its blowhole | Each hagfish lunges (3.5 s) at a player within reach; one that reaches them bites and holds on, reeling them in toward its hole while it ties itself in a knot (1.1 s) that slides to its head, and slimes them when it lets go; spitting, they spray slime (5 a touch, slows); they hold 60% of its hp, each dying on its own; the carcass takes 25% damage while any lives; in fury they tear loose and hunt, catching up at up to 2.4× (`hagfish_fury_hunt`) when more than 12 m off their prey (full from 20 m, `hagfish_fury_catchup`), normal speed up close |
| **The Lamprey Queen** | An 88 m sea lamprey: a disc of hooked teeth in five rings round a rasping tongue, seven gill holes a side, her brood clamped to her flanks | Every 8 s one of her brood drops off as 6 zombies; spitting, her gills pulse out blood clouds (8 a touch); her gills take 2× damage; in fury she lunges every 3 s (`lamprey_lunge_fury`) at a player within 30 m ahead (disc flaring 0.6 s, lane showing, then 2.6× her speed), latches onto one her disc reaches, and corkscrews (5 rad/s) while she drains them |
| **The Fallen Angel** | A 40 m zombie sea angel hanging upright: a glass-clear hooded body with its orange head and gut glowing through, two torn wings at its shoulders, two horns, a long tail with an orange tip, and a crown of six tentacles folded in its head | Rests 19 m off its prey on wingbeats (1.1 s), then locks on: it shadows a player 11 m off them, matching their moves and circling them (0.7 rad/s), a halo round them and a tether to them filling; after 2.25 s locked on it opens its crown over 1.2 s (0.8 s in fury; its lane shows), then tumbles in for 2 s, lashing 3 times (4 in fury) at everything within 12 m and 55° of the lash: a lash grabs a player unless they strode within 0.4 s before it, and eats the zombies it catches (+0.2% hp each). Rests 2.5 s. Its head and gut take 2× damage (3× with the crown open). From 2/3 hp it sheds 14 Sea Butterflies every 8 s instead of spitting, and when hurt half its flurries go for them (+0.4% hp each). In fury its lashes take turns between the two nearest players |
| Grabbed (King in fury, Gulper, Lamprey, a Whale Fall hagfish, Fallen Angel) | | Drawn in over 0.3 s, held (coiled, swallowed, latched on, knotted, crowned) for up to 3 s, drained 10 every 0.75 s; 3 strides break free. Your camera pulls 26 m back, and the break-free panel shows what has you, a diamond per stride and the hold running out |

### Shrines (P5, `shrine.gd`): 4 per stage, one of each, Jump over one to use it

| Shrine | What it does |
|---|---|
| **Tide** | Hold its 8 m ring for 10 s (draining back at half speed while you're out) while 40 zombies ring it every 3.5 s: a free chest |
| **Chance** | Pay 6 pearls (growing as chests do, ×1.5 a try) for a 50% chance at an item (a chest's pick). 3 tries per player |
| **Deep** | More elites for the rest of the stage (×2 chance), and every boss drops one more chest |
| **Pearls** | Every pearl out flies to the nearest player, and 10 more spill out |

### Zombies (`enemy_kind.gd`): one per class, plus the sardines. Each stage plays a rotation of `stage_kinds` (6) of them: the sardines, one from minute 0, then others by chance (favouring ones the last stage didn't have). 0 plays them all at once

| Zombie (id) | Model | Size | HP | Speed | Touch | XP | From minute | Behaviour |
|---|---|---|---|---|---|---|---|---|
| Rotten Sardine (`sardine`) | its own (sardine) | 0.55 | 8 | 7.0 | 6 | 1 | 0 | Swarm: weaves in. In every rotation |
| Ghoul Clownfish (`clownfish`) | Skirmishers | 1.0 | 22 | 5.0 | 10 | 2 | 0 | Chase |
| Bloated Boxfish (`boxfish`) | Bulwarks | 1.6 | 90 | 3.0 | 18 | 6 | 2 | Tank: bursts into a 3 m cloud on death |
| Lunging Swordfish (`swordfish`) | Lancers | 1.2 | 45 | 6.5 | 16 | 5 | 4 | Lunge: 0.7 s wind-up, 24 m/s |
| Grave Ray (`ray`) | Gliders | 1.4 | 55 | 7.5 | 14 | 5 | 6 | Glide: cuts across where you're going |
| Drowned Koi (`koi`) | Charmers | 1.0 | 28 | 6.5 | 10 | 3 | 0 | School: closes to a 9 m ring, circles 3 s, darts in 1.2 s |
| Cinder Lionfish (`lionfish`) | Scorchers | 1.0 | 35 | 5.5 | 12 | 4 | 3 | Chase, dropping fire every 0.9 s (1.2 m, 2 s, 4 dmg; at most 30 out) |
| Grave Jelly (`jelly`) | Drifters | 1.1 | 40 | 3.5 | 8 | 3 | 0 | Drift: surges to 2.6× speed every 1.6 s; its sting slows you (`frozen_slow`) for 1.5 s |
| Rotten Mantis (`mantis`) | Brawlers | 1.0 | 50 | 5.5 | 18 | 5 | 4 | Punch: stops at 4.5 m, 0.6 s wind-up, punches 6 m ahead (45° cone) for its touch damage, knocks you back 12 m/s, rests 1.2 s |
| Bloated Whale Calf (`whale`) | Breachers | 1.5 | 120 | 2.8 | 18 | 8 | 5 | Tank that bobs; on death bursts (as the boxfish) and spills 4 sardines |
| Sour Sea Hare (`sea_hare`) | Alchemists | 1.0 | 40 | 4.0 | 10 | 4 | 2 | Chase; dying leaves a 3.5 m cloud for 3 s that slows you |
| Ghoul Shark (`shark`) | Hunters | 1.2 | 60 | 7.5 | 18 | 6 | 7 | Lunge: wind-up ×0.6, lunge speed ×1.3 |
| Sea Butterfly (`butterfly`) | its own (a shelled sea snail) | 0.45 | 6 | 6.5 | 4 | 0.5 | — | Swarm. Only the Fallen Angel sheds them (never in a rotation) |

### Elites: 2.2× the size of their kind, 5× hp, 2× contact damage. Elite modifiers (P5): 60% of elites have one, and drop chests ×1.5 more often

| Modifier | Glow | What it does |
|---|---|---|
| **Burning** | Orange, flickering | Leaves a 1.6 m fire patch every 0.6 s (3 s, 6 dmg a touch; at most 40 out) |
| **Electric** | Blue, crackling | Dying, it crackles 0.6 s (a ring shows where), then shocks everything within 5 m for 14 |
| **Frozen** | Ice blue | Its touch takes 45% of your speed for 2 s |
| **Bloated** | Sickly green | Dying, it bursts into 6 rotten sardines |

### Stages and run length (P5)

| Rule | Value |
|---|---|
| Run length | Picked before the run: Short (1 stage, events at 0.6× their times: the boss at 6:00), Standard (3 stages), Endless |
| Each stage after the first | A new seabed; zombies ×1.8 hp and ×1.3 contact damage per stage (compounding), +3 difficulty levels, +40% zombies out, +2% elites; bosses ×1.8 hp. Weapons, tomes, items, level and purse carry on; everyone's healed and back at the start |
| Quiet moments | 8 s with no packs after a swarm event ends, and after the mini-boss |

---

## 8. What Stinks? (`scripts/what_stinks/`, `what_stinks.md`; Phase 4: Upset Stomach)

One Hunter (a monster form, played by a person or a bot) against prey in an Ocean full of fish schools. Panel sections WHAT STINKS? (`WhatStinksSettings`) and HUNTER SIZE (`HunterSize`). In the picker's MORE row, shown with the hidden modes (SELECT) while it's in development.

- **Hidden class MONSTER** (`FishClass.MONSTER`, species `drowned_shark`): the Drowned Shark as a Hunter form (`HunterForm.SHARK`, 7 m, red eyes, jaw rig). The Humpback (a Titan) and the five boss forms are the others. The player's own look is kept in meta `ws_base_look` while swapped.
- **Bite** (`HunterBite`, press of jump): (Bite group setting `bite_mode`: `hold`, the default, is two-stage: the press opens the jaws, they stay open and charge (full at the form's `charge_s` 1.2 s) while the button is down, and the release slams them shut; a tap, released before they are fully open, strikes at once from at least `tap_open_min` 0.6 open. The chomp style's charge scales reach x`hold_reach_mult` 1.5 and capacity x`hold_capacity_mult` 2.5. Holding costs swim speed x`hold_speed_mult` 0.8, turn x`hold_turn_mult` 0.7, school alarm x`hold_alarm_mult` 1.5 and cooldown `bite_every` + `hold_cooldown_per_s` 0.5 x seconds held, to `hold_cooldown_max` 6 s; there is no max hold. A Hunter's fish ignores jump and dodge. The bite is felt as well as seen (HunterBiteFx): a pad tick on the press (`rumble_open` 0.3), a rumble rising with the charge (`rumble_hold` 0.25), a click and pulse at full charge, a hard pulse on the landing (`rumble_contact` 0.7, scaled by the fish taken), a camera punch, a `hitstop_ms` 80 freeze of the Hunter's own controls (never the global time scale) and blood, bubbles and sparks (`bite_fx_mult` 1); bots and puppets feel no rumble; a prey player within `prey_warn_range` 1.5 reaches of an open mouth hears the hold louder and feels a heartbeat (`prey_warn_rumble` 1.5), and one a bite catches gets a punch, pulse and red flush (`prey_impact` 1). `tap` is the old snap: the chomp is instant on the press, no wind-up and no lunge) eats the `capacity` fish nearest the bite point inside its frustum (reach 3.5 m, radius 1.6 m, capacity 4 at size 1; x size, x size^1.5 for capacity), school fish and prey players alike (`bite_takes_players`). `School.eat()`: survivors panic (alarm 1, burst x `eat_burst_mult` 2.5 over x `eat_radius_mult` 2.5), scatter along `eat_groups` 3 headings and reform over `reform_time` 7 s.
- **Hunter size** (`HunterSize.size_mult` 0.25..30, default 1): model, hitbox, speed (exp 0.5), accel (0.5), turn (-0.5), bite reach (1.0), capacity (1.5), camera framing, school alarm (1.0), murk sight (0.5); a fish meta `size_mult` multiplies on top.
- **Hunter forms** (`HunterForms` registry, `scripts/what_stinks/forms/<key>.gd`, sheets in `hunter_forms.md`): 13 keys in card order. Ready (on the match card): Drowned Shark, Humpback, Orca, Beluga, Sperm, Blue, King of Herrings, Gulper Mother, Lamprey Queen, Fallen Angel, Ember Octopus, Lantern Angler (Whale Fall is disabled: `ready()` false, its lash is not built; the four non-Humpback whales are first-guess sheets, ready since 2026-11-07 phase 2); a pick that is not ready plays as the Shark. All five whales use the **engulf** attack style (`attacks/engulf_attack.gd`, `WhaleJaw` hinged jaw on the Titan model: press opens the mouth, fish swimming into the mouth box are held via `School.hold`, release eats them; Upset Stomach spits prey players; settings group Engulf: `whale_gape_deg`, `whale_smear`, `engulf_swell`, `engulf_max_mult`, `engulf_box_len`, `engulf_box_width`, `engulf_pull_s`, `engulf_per_s`, `engulf_squeeze_s`, `engulf_bump`). Match size is locked at 0.5x (`HunterSize.MATCH_SIZE`); the panel's `size_mult` still moves it. The schools' alarm range follows the biggest Hunter's size (`alarm_exp`).
  - **Coil** style (King of Herrings, `attacks/coil_attack.gd`): the press starts the body coiling, the hold tightens it (the rig curls through `coil_curl_deg` 300 and the head is cocked aside), the release whips the head round a pivot `coil_pivot` 0.45 reaches behind the mouth. The catch is a flat sector from that pivot, `coil_arc_min` 45 degrees wide at no charge to `coil_arc_max` 160 at full, a reach beyond the mouth long and `coil_thick` 0.5 reaches thick; contact is the head crossing the arc's middle. The charge also lifts capacity to x`coil_capacity_mult` 1.5; the reach stays. **Drill** style (Lamprey Queen, `attacks/drill_attack.gd`): the hold winds her body back and speeds the rasp; the release is a corkscrew dash at `drill_dash` 2 x her top speed x the charge for `drill_time` 0.6 s (a hold under `drill_min_charge` 0.2 does not dash), rolling at `lamprey_spin`, taking what her disc passes through (a tube `drill_radius_mult` 1.5 x the bite radius across) up to capacity x`drill_capacity_mult` 6 at full charge (x the charge); the body ram is held off during it. At full charge the first prey player met latches her (`drill_latch`): the dash ends and she rolls on it. Settings groups Coil and Drill.
  - **Exaggeration and tuning added by the new-hunters pass** (see `hunter_forms.md`, "Attack exaggeration"): `AttackExaggerate` (`attack_exaggerate.gd`) plus settings `hunter_exaggeration` 1 (0-4), `hunter_hit_stop_frames` 2.5 (0-12), `hunter_camera_punch` 0.5 (0-5), `hunter_exaggerate_squash` 1 (0-3), `hunter_exaggerate_smear` 0.05 (0-0.5), `hunter_exaggerate_max_scale` 3.5 (1-8). Shark: `shark_jaw_gape` 1, `shark_head_thrust` 0.10, `shark_body_stretch` 0.12, `shark_teeth_gain` 1, `shark_eye_flare` 1. Whales: `whale_gape_max_deg` 135 (20-180+), `whale_rebound_deg` 16, `whale_body_pulse` 1, `whale_throat_balloon` 1, `whale_tooth_pop` 1. King: `king_whip_stretch` 1.5, `king_coil_tighten` 1.55, `king_whip_lag` 0.45, `coil_press_floor` 0.4. Lamprey: `lamprey_lunge_impulse` 0.55 (0-3, next to the `drill_*` settings), `lamprey_disc_flare` 1.35, `lamprey_teeth_spin` 7, `lamprey_telescope_max` 1.9, `lamprey_dash_stretch` 1.3, `lamprey_dash_flare` 1.7, `lamprey_dash_spin` 14. `body_stiffness` 0.4 (0-1; King and Lamprey bodies). Preview (`HunterPreview`, the card's swimming showcase): `preview_throttle` 0.75, `preview_speed` 1, `preview_wander` 1.
  - **Lock** style (Fallen Angel, `attacks/lock_attack.gd`): the press only opens with a prey fish inside `angel_lock_range` 2 reaches and `angel_lock_cone` 40 degrees (else a denied beat); the hold locks the nearest fish and the Angel matches its pace, closes at `angel_close_speed` 14 to a stand-off of `angel_standoff` 0.7 reaches, auto-faces it (`angel_face_rate` 6) and the stick orbits (`angel_orbit_speed` 1.6); a ring, line and "xN" preview show on the target. The release lashes a line through it (`angel_lash_speed` 40) taking capacity x`angel_count_mult` 3 x the facing share (how squarely it faces the mass of the school; `angel_charge_weight` 0.3 from the charge), at least the target, with the camera lock-on bite on top. It breaks past `angel_break_range` 3.5 (`angel_break_cooldown` 1 s). **Suction** style (Gulper Mother, `attacks/suction_attack.gd`, `School.pull`): the hold draws school fish in the cone (`suck_cone` 35, `suck_strength` 16) toward the mouth and pushes prey players (`suck_prey_push` 12), reach and pull rising with the charge (`suck_reach_mult` 2.5, `suck_reach_min` 0.4, `suck_charge_min` 0.35); the release catches a sphere of `gulper_mouth_r` 0.7 bite radii and a belly lump slides down (`suck_lump_s` 3, `suck_lump_size` 0.5). Settings groups Lock and Suction.
  - New-hunters pass wrap-up 2026-11-08 11:57: 12 forms ready, about 121 new settings (Exaggeration, Shark, Whales, King and Lamprey bodies, Preview, Octopus lash, Octopus body, Lantern Angler groups); build 11:57; awaiting play-test (see planning_new_hunters.md).
  - **Ember Octopus** (`ember_octopus`, 12th form, ready 2026-11-08; `forms/ember_octopus.gd`, `octopus_rig.gd`, `octopus_model.gd`, `shaders/octopus_skin.gdshader`, `octopus_contract.md`, `octopus_whip_fx.gd`; style **whip** = Tendril Lash, `attacks/whip_attack.gd`; probes `octopus_model_probe`, `octopus_form_probe`, `octopus_gait_probe`, `octopus_roll_probe`, `octopus_whip_probe`, `octopus_match_probe`; shot tools `octopus_model_shots`, `octopus_gait_shots`, `octopus_whip_shots`). A 6 m glowing copper-to-violet octopus: one skinned mesh (118 bones, 8 arms x 14 segments, instanced suckers with LOD, emissive veins). Gait: siphon-vectored jet pulses in open water (real thrust and torque in the fish's physics tick), cruise scull, dash jet with the arms bundled, arm crawl near a floor; a frozen body (card preview, countdown) runs the jet clock on the frame. The press rears the arms into a crown and locks up to `whip_arms` prey (one arm each); hold coils the arms tighter with the charge; the release lashes them out on homing curves 30-60 ms apart, each arm judged on arrival (host only, like the Lamprey's drill), the first arm supplying the bite's contact tick; recoil pushes the octopus back per arm. `WhipAttack.attach_model` wires a model under an `OctopusRig` so the rig runs `blend_pose` after its gait and the arms reel in to `OctopusRig.gait_joints`. HUD ring shows the locks ("N of whip_arms arms"); bot: `WhipAttack.bot_plan` (press with prey in range and cone, release at 4 locks or when they drift). Net: puppets and guests run the same lock and timeline for visuals from the synced bite beats; no extra lock list is sent. Settings groups **Octopus lash** (`whip_*`: arms 8, range 1.15, cone 75, cone_slack 1.2, range_slack 1.25, angle_weight 0.6, refill_s 0.25, homing 0.8, fly_s 0.14, stagger_min/max 0.03/0.06, per_arm 1, charge_capacity 2, charge_reach 1.4, tap_share 0.5, hit_radius 0.55, recoil 2.2, miss_recoil 0.35, recoil_cap 7, flare 75, sweep_min/max 140/290, stretch 1.6, wave 0.07, flare_s 0.2, retract_s 0.4, miss_retract_s 0.22, whiff_arms 4, stall_max 0.45, lunge 0, aura 1) and **Octopus body** (`octopus_*`: jet_period 1.1, jet_power 0.3, jet_accel 14, dash_mult 1.8, jet_vector 0.6, jet_torque 0.5, flare_torque 0.5, arm_lag 0.55, arm_stiffness 26, arm_damping 0.8, inertia 0.9, drag_bend 0.8, scull_amp 1, scull_hz 1.3, idle_sway 1, droop 0.35, tip_curl 0.3, crawl_range 0.8, crawl_step_time 0.42, crawl_step_len 0.3, crawl_lift 0.4, crawl_blend_rate 2.5, crawl_height 0.3, crawl_pull 2.5, glow 1, sucker_hi_range 3, sucker_range 7). Sounds (stand-ins, `octopus/*`): flare, charge (loop), lock, lock_lost, lash, crack, hit, miss, jet, foot. The lash's cracks, reticles and aura are `OctopusWhipFx`; `hunter_exaggeration` drives its mantle squash and camera punch through `AttackExaggerate`.
  - **Lantern Angler** (`lantern_angler`, 13th form, ready 2026-11-08; `forms/lantern_angler.gd`, `lantern_rig.gd`, `angler_model.gd`, `shaders/angler_skin.gdshader`, `angler_contract.md`; style **lure** = the Lure, `attacks/lure_attack.gd` + `lure_field.gd` (`LureField`); probes `angler_model_probe`, `angler_form_probe`, `angler_roll_probe`, `lure_pull_probe`, `angler_match_probe`; shot tool `angler_shots`). A 6 m globe-headed ambusher (speed 1.1, accel 0.55, turn 0.5, reach 3.2 m, radius 2.2 m, wind 0.9 s, every 2.6 s, capacity 5, cam 1.0/1.2) with a hinged needle-tooth jaw and a spring-chain lure stalk ending in a glowing esca. Gait: stiff body, slow pectoral scull, tail snap on a burst of acceleration. **Lure**: the press flares the esca (`lure_flare` 2.6), gapes the jaw (`lure_gape` 1.35) and starts a `LureField` source; the hold ramps (`lure_ramp_s` 2) a drift on prey inside `lure_radius` 42 m and `lure_cone` 75 degrees toward the esca and then the mouth (`lure_pull` 7 m/s^2, `lure_cap` 11, eased off within `lure_fade_m` 1.5 of the target); a person cancels `lure_resist` 0.9 of it by swimming away, a bot `lure_bot_resist` 0.35 (bots also bend their swim target toward the light, `lure_bot_bias` 0.8, in `WhatStinksPreyBot`), a dash cancels `lure_dash_cancel` and grants `lure_break_s` 1.2 s immunity; school fish are pulled `lure_school_pull` 1. The esca flickers `lure_flicker_min` 2.5 to `lure_flicker_max` 14 Hz as prey close in. The release snaps shut like the chomp, with `lure_cooldown` 1.5 s extra rest. The local prey gets an amber captivated vignette in the HUD (`LureField.captivated`); the Hunter's ring shows "N drawn". Body settings (Lantern Angler group): `angler_stalk_stiffness` 38, `angler_stalk_damping` 5.5, `angler_stalk_sway` 0.5, `angler_esca_light_cap` 6, `angler_body_stiffness` 0.85, `angler_sway_deg` 9, `angler_tail_snap_deg` 40, `angler_tail_hz` 1.6, `angler_tail_zeta` 0.3, `angler_burst_accel` 9, `angler_pectoral_hz` 0.8, `angler_pectoral_deg` 28. Online: puppets run the same lure from the synced bite beats and move only the prey they own; the host pulls its own; no esca state is sent. `LureField.reset()` at round start and end.
  - Boss forms ride the hidden MONSTER class (the shark's box, species 0) and `dress` hides the shark's parts and adds a rig built from the boss's own look at the hitbox length: Gulper (`gulper_*`), King (`king_*`), Whale Fall (`whalefall_*`), Lamprey (`lamprey_*`), Angel (`angel_*`). Each has its own bite shape through the sheet (reach / far half width / capacity / wind-up / rest, size 1): Shark chomp 3.5 / 1.6 / 4 / 0.75 s / 2.0 s; Humpback tail slap 2.2 / 2.6 / 6 / 0.95 / 2.4; King coil sweep 5.5 / 4.5 / 7 / 1.0 / 2.8; Gulper swallow 6.0 / 4.0 / 8 / 1.0 / 2.5; Whale Fall hagfish knot 4.5 / 3.6 / 6 / 0.9 / 2.6; Lamprey corkscrew latch 3.2 / 1.0 / 1 / 0.8 / 3.0; Angel lock-on 6.5 / 1.3 / 2 / 1.2 / 2.2. Lengths at size 1: Shark 7 m, Gulper 9, Angel 10, Whale Fall 12, Lamprey 14, King 16. The hitbox is still the shark's box scaled, not a form-shaped one. `FishController.rl_turn_scale` (default 1) scales the RL air torque and spin cap; `HunterSize` sets it (the old `turn_scale` does nothing off a surface under `rl_air_control`).
- **Match** (`WhatStinksSettings`): variant Clean Sweep or Upset Stomach (see Stomach), rounds 0 (one per person + `bot_hunter_rounds` 1), `hunters_per_round` 1, `min_players` 5, `hide_time` 12 s, `round_time` 180 s, `round_over_time` 7 s.
- **Schools and arena**: `school_count` 14 placed once per round (`school_min` 20 .. `school_max` 60 fish, roam 45 m, speed 5.5), `arena_radius` 220 m (the Ocean's murk wall, pushes back: stiffness 2, outward 2, max 40), prey spawn 25%..70% of the radius.
- **Scoring**: Hunter `tag_points` 100 per prey eaten + up to `time_bonus` 150 by clock left; prey `survive_points` 2/s, `last_fish_bonus` 100, `survivor_bonus` 150.
- **Bots**: the prey bot (`WhatStinksPreyBot`) rushes to the school nearest its home (the join system takes it in; it wanders like a WanderBot, `prey_bot_pace` 0.5, only with no school to go to), then, joined, leaves and heads for a school far from the Hunter once a Hunter has read it at least `prey_bot_exposure` 0.45 for `prey_bot_patience` 2.5 s (0: never; never while baiting in Upset Stomach). The Hunter bot (`WhatStinksBot`) heads for the biggest school then the nearest fish, boosts beyond 25 m, and lets its bite's style press and release (`HunterAttack.bot_plan`: open at `hunter_bot_open_gap` 1.6 reaches, release at `hunter_bot_charge` 0.5, engulf/suction when the mouth is full or the school has passed, the Angel's lash at `hunter_bot_lock_align` 0.6). It reads the echo like a person: in Clean Sweep a prey with exposure at least `hunter_bot_read_exposure` 0.25 counts as half as far and an unseen loner is no target, it Clicks when the Click is ready and nothing is readable (`hunter_bot_click`), and it sniffs `hunter_bot_sniff_s` 4 s per school it works (Clean Sweep only).
- **Joining** (`WhatStinksJoin`, panel tab Join & Spook): a prey fish within `join_radius` 4 m of a school fish of its own class (`join_any_class` off) presses Jump to join: it takes a real school fish's place (`School.claim`), eases in over `join_ease` 0.6 s, then the school writes its transform (lockstep, frozen, model hidden, no collisions). The stick leans the place `join_lean` 1.2 m. Boost leaves (dash out at `leave_speed` 14, loud `leave_noise` 0.7, echo reset, `rejoin_cooldown` 3 s); Powerslide spooks (`spook_charges` 1 per round: the school bolts at `spook_strength` 2.5 over `spook_groups` 3 headings and re-forms in `spook_reform` 4 s, every echo in it reset). Buttons are settings. `ally_markers` show joined prey to the other prey (never the Hunter, who also sees no prey name plates). `school_prey_share` 0.7 of the schools are made of the classes the prey play. `bots_join`: prey bots join a school in reach. A joined prey is eaten with its place.
- **Echo** (`WhatStinksEcho`, panel tab Echo; `WhatStinksShadows`, `WhatStinksLooks`): the Hunter sees a prey at `exposure = max(noise, echo)` through Marco Polo's reveal layers (nothing below the skeleton band, bones, heart, muscle, skin, aura; `hunter_blind` off draws everyone). Noise is a NoiseMeter per prey (Marco's noise settings), seen out to `noise_sight` 60 m (x size^`echo_size_exp` 0.5), a joined player is silent, a loud Leave adds `leave_noise`. Echo builds per Hunter while the prey is in the cone (`echo_cone_deg` 35 half angle, `echo_range` 60 m, full within `echo_near` 10 m, falling linearly): `echo_build` 0.13/s (still loner at point-blank: skin layer in 5 s), slowed by speed to `smear_floor` 0.25 at `smear_speed` 8 m/s (`smear_curve` 3: middle speed ~15 s), x`blend_echo_mult` 0.1 for a school member (~10x slower, its faint skeleton the tell), x`shadow_mult` 0.2 in an echo shadow (`shadow_count` 10 kelp stands and rock arches of `shadow_radius` 9 m). It fades at `echo_decay` 0.1/s outside the cone and in a shadow. Click (`click_cooldown` 3 s, `click_auto` on, else `click_button` air_roll): `click_gain` 0.4 to every prey in the cone (x blend, x shadow). Sniff (hold `sniff_button` powerslide): cone x`sniff_cone_mult` 0.4, echo x`sniff_mult` 2, speed x`sniff_speed` 0.5. Prey HUD: map (schools, allies, you, Hunter arrow, shadows) with a noise ring and an echo ring; Hunter HUD: Click and Sniff rings.

- **Stomach** (Upset Stomach variant, panel tab Stomach; `WhatStinksMatch.satiation/queasy/_spit/_hurl`): the Hunter's belly starts at `satiation_start` 0.25 of `satiation_max` 100, drains `satiation_decay` 0.5/s, and a school fish adds `satiation_per_fish` 4 x its mass (body length / `satiation_ref_length` 0.8 m, ^`satiation_size_exp` 1, x `fish_scale` when `satiation_uses_fish_scale`). A prey player in the bite is spat out, not eaten: flung `spit_speed` 22 m/s from the mouth, dazed `spit_daze` 4 s (no boost, no joining), the Hunter loses `spit_satiation_loss` 15 satiation, gains `queasy_per_spit` 1 of `queasy_max` 3 (settles `queasy_decay` 0.01/s) and can't bite for `spit_cooldown` 3 s. Full belly: the Hunter wins; queasy at max: it hurls (held for the round; the prey win when every Hunter has); clock out below full: the prey win. Schools respawn steadily (`respawn_every` 6 s, 0 off: each school below its first size gains `respawn_batch` 3; a wiped school is replaced after `respawn_school_delay` 10 s at least `respawn_school_gap` 80 m from the Hunters). Scoring: Hunter `satiation_points` 1 per satiation earned (+ the early `time_bonus` on a win); prey `spit_points` 60 per spit they caused + `survive_points` + `survivor_bonus` when they win. Bots: the Hunter bot ignores a prey it can read (exposure >= `hunter_bot_avoid_exposure` 0.3) and holds its bite while one is in the frustum; prey bots wait at the schools nearest the Hunter's start (`prey_bot_baits`). HUD: Belly and queasy bars under the headline (everyone sees them), "Prey spat out" count, round cards by reason.
- **Camera** (`WhatStinksCam`, panel tab Camera): Unnatural's follow cam (`UnnaturalRun.steady_camera`, Settle style, from the Unnatural panel) for every role, with the form framing (`HunterSize.frame`) on top; without it the FollowCamera held still in open water. While a round is live, the ball cam button locks on a school (Nature's ball cam and `TargetWheel`): a tap toggles it and looks at the school nearest and ahead (cost = distance x (`lock_behind_cost` 1.5 - how far ahead), within `lock_range` 0 = any), holding `wheel_hold_time` 0.3 s opens the school wheel (live schools only, name, fish left, edge arrows `school_arrows` on), stick + release locks one, `lock_swing` 1.2 is the swing speed. `lock_on` on; `lock_on_prey` on gives prey the same (not the school they joined). A wiped-out school moves it on. Countdown, round over and eaten (spectating): follow cam only.

## Keeping this up to date

When you add, change, rename or remove a fish, weapon, tome, powerup, stat, drop or default value, update the matching table here in the same change. New ids go in the right section and rarity tier. Facet steps and milestones come from `weapons.gd`, numbers from the settings resources.
