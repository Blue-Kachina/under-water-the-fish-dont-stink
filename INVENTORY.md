# Inventory — Unnatural

Every playable fish, weapon, tome, powerup and bonus in Unnatural (the survivors mode), with their stats.

- **Last synced with code:** 2026-10-23
- **Values are defaults.** Almost every number here is a tuning-panel setting (`UnnaturalSettings`, `PowerupSettings`), so a preset can change it. If this file and the code disagree, the code is right; fix this file.
- **Sources of truth:**

| What | File |
|---|---|
| Fish (families, hitbox car, skins) | `scripts/fish_character.gd` (`CARS`, `SKINS`) |
| Fish details text (twists, skills) | `scripts/unnatural/fish_details.gd` |
| Weapons (every one a `FishAttack`) | `scripts/unnatural/attacks/*.gd`, `fish_attack.gd` (`FOR_FAMILY`, `INFO`) |
| Weapons (facets, milestones) | `scripts/unnatural/weapons.gd` |
| Tomes | `scripts/unnatural/tomes.gd` |
| Stats (steps, signature stats) | `scripts/unnatural/stat_block.gd` |
| Powerups (name, rarity, blurb) | `scripts/unnatural/powerups/powerup.gd` (`INFO`) |
| Powerup numbers | `scripts/unnatural/powerups/powerup_settings.gd` |
| Run / fish / attack / rarity numbers | `scripts/unnatural/unnatural_settings.gd` |
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

### Player base (every fish is the same here)

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
| `projectile_count` | Projectiles | +1 (rounded up) | flat | only if the attack uses it (Thrust, Bubbles, Spines, Lash) | Schools | Abyssal Engine (+1) |
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

**What the global stats scale on weapons:** Attack Speed → fire/drop/tick rate. Size → every weapon's reach, radius, blast or hit size (all 10 weapons, plus the area powerups such as Electric Eel, Torpedo, Tsunami Heart). Duration → Greek Fire patch life, Depth Charge life, Anglerfish Lure, Ink Sac. Damage → every hit (applied in `UnnaturalRun.hit()`).

---

## 3. Playable fish

Every fish has the same base stats. They differ in their starting weapon, their **signature stat** (+1 step every level, free), a passive **twist**, and a **mobility skill** on the boost button (RB / Shift).

| Fish | Family (hitbox) | Starting weapon | Signature stat (per level) | Passive twist | Mobility skill |
|---|---|---|---|---|---|
| **Clownfish** | OCTANE (Octane) | Anemone Sting | Size +10% | **Nimble:** turns 1.4× as sharply (+40%) | **Wriggle:** 16 m/s burst sideways (where the stick leans, else backwards), 0.3 s untouchable. Cooldown 2.0 s |
| **Shark** | DOMINUS (Dominus) | Ghost Bite | Damage +10% | **Frenzy:** +4% swim speed per kill (max +50%), held 3 s after the last kill, then fades | **Fin Dash:** charges at 45 m/s for 0.45 s, untouchable, batters everything in the way; 90 dmg to each zombie within 3 m. Cooldown 3.0 s |
| **String Ray** | PLANK (Plank) | Shock Lash | Attack Speed +8% | **Glide:** keeps only 30% of the drag when coasting | **Surge:** a 22 m/s stroke forward, no drag for 1.5 s. Cooldown 4.0 s |
| **Swordfish** | BREAKOUT (Breakout) | Bill Thrust | Projectile Speed +10% | **Streamlined:** swims +10% faster | **Dash:** a 14 m/s burst along its nose, 0.3 s untouchable. Cooldown 2.5 s |
| **Butterfly Koi** | HYBRID (Hybrid) | Bubble Volley | Luck +0.1 | **Graceful:** +0.5 s of i-frames after every hit (1.2 s total) | **Leap:** leaps up at 12 m/s; at the top it splashes down for 30 dmg within 7 m. Cooldown 2.5 s |
| **Boxfish** | MERC (Merc) | Spine Burst | Armour +1 | **Armoured:** takes 70% of damage, swims at 88% speed | **Brace:** for 2.5 s takes 25% of damage, swims at 70% speed. Cooldown 8.0 s |
| **Lionfish** | LIONFISH (Octane's box) | Greek Fire Trail | Duration +10% | **Wake:** Greek Fire burns up to +60% harder the nearer it swims to battering speed | **Flare Dash:** dashes at 30 m/s for 0.35 s; 60 dmg to everything within 4 m on the way. Cooldown 3.5 s |
| **Moon Jelly** | MOON_JELLY (Hybrid's box) | Jellyfish Halo | Size +10% | **Many Arms:** +1 jelly in its Halo | **Go Quiet:** switches its stink off for up to 8 s: nothing fires and zombies lose track of it. Being hurt ends it, or press again to end it early. Cooldown 6.0 s |
| **Mantis Shrimp** | MANTIS (Dominus's box) | Depth Charges | Knockback +15% | **Hammer:** the Snap's shockwave hits for 70 dmg within 6 m | **Snap:** lunges at 18 m/s and cracks a shockwave (see Hammer). Cooldown 2.0 s |
| **Baby Whale Shark** | WHALE_SHARK (Plank's box) | Remora Buddy | Pearl Chance +15% | **Escort:** heals 4 HP/s while holding still (under 3 m/s) | **Gulp:** pulls in every zombie in a 14 m cone ahead (25 m/s) and hits each for 25. Cooldown 5.0 s |

- Every fish starts with its own weapon (a `FishAttack`, `FishAttack.FOR_FAMILY`) in slot 1, as the `attack` weapon.
- Skins: each family has several real species or colour morphs (`FishCharacter.SKINS`). They change only the look, never stats.
- The twist switch is `UnnaturalSettings.twists`. Off, every fish swims the same.

---

## 4. Weapons (`weapons.gd`)

Weapons level up from level-up cards (they never come from chests) and go up to Lv 20. Each card raises one or more **facets**, chosen at random (how many depends on rarity, see §1). The steps below are what one common step adds. A fish's starting weapon takes one of its 2 slots.

**Every weapon is a `FishAttack`, and every weapon can be any fish's second weapon.** A fish's own is the `attack` weapon. Held as a second weapon (an `AttackWeapon`), its id is `attack_` + its hit source (`attack_bite`, `attack_greek_fire`...). Level-up cards offer all of §4a and §4b (`Weapons.card_pool`), except the weapon the fish already holds. Leviathan's Coil is boss-only and never appears on a card.

The split below is about how a weapon works, not who can get it. **Fired** weapons (4a) go off on a cooldown and share one set of facets. **Steady** weapons (4b) work all the time on their own timers, and each has its own facets.

### 4a. Fired weapons

Shared facet steps (`PowerupSettings`): Damage +20%, Rate +12%, Size +12%, Knockback +30%, Count +1, Speed +15%.

| Weapon (second-weapon id) | Fish | Base damage | Cooldown | Proc | Base numbers | Facets |
|---|---|---|---|---|---|---|
| **Anemone Sting** (`attack_sting`) | Clownfish | 9 | 0.9 s | 0.6 | A pulse 6.5 m round the fish (always at least 1.4× the bow wave's reach). Hits everything inside. Only fires when a zombie is close. | Damage, Attack rate, Pulse size, Knockback |
| **Ghost Bite** (`attack_bite`) | Shark | 26 | 0.9 s | 1.0 | Jaws 8 m long, 4.5 m half-width (always at least 1.6× the bow wave). Aims at the nearest zombie within 110° of the nose. | Damage, Bite rate, Jaw size, Knockback |
| **Shock Lash** (`attack_lash`) | String Ray | 47 | 0.8 s | 1.0 | Whips the nearest zombie within 14 m. It arcs on to 1 more (+1 per Projectile) within 8 m of the last, each arc doing 70%. | Damage, Lash rate, Lash reach, Arcs (count) |
| **Bill Thrust** (`attack_thrust`) | Swordfish | 34 | 1.0 s | 1.0 | A spear at 45 m/s that flies 40 m with a 0.7 m hit radius and pierces 6. Aims within 60° of the nose. Extra spears fan 8° apart. | Damage, Thrust rate, Spears (count), Spear speed |
| **Bubble Volley** (`attack_bubbles`) | Butterfly Koi | 9 per pop | 1.2 s | 0.6 | 4 homing bubbles (+Projectiles) at 18 m/s, turn rate 6/s, 2.5 s life, 30 m range. Each pops on its first touch with a 2 m splash. | Damage, Volley rate, Bubbles (count), Bubble speed |
| **Spine Burst** (`attack_spines`) | Boxfish | 32 | 1.4 s | 0.4 | 18 spines all round (+4 per Projectile) when a zombie is within 12 m. 30 m/s, pierce 2. | Damage, Burst rate, Spine rings (count), Spine range |

**Milestones (Lv 5 / 10 / 15 / 20):**

| Attack | Lv 5 | Lv 10 | Lv 15 | Lv 20 |
|---|---|---|---|---|
| Anemone Sting | A second, wider pulse follows each sting | Stings slow what they hit | Pulses draw zombies in from further out | A third pulse follows, wider still |
| Ghost Bite | A second set of jaws snaps behind you | Jaws snap at both sides too | Jaws snap above and below you too | Every bite snaps twice |
| Shock Lash | Each lash strikes a second zombie too | Arcs jump twice as far | Each arc jumps on to two more zombies | Each lash strikes a third zombie too |
| Bill Thrust | Spears pierce one more zombie | Spears burst at the end of their flight | Two more spears fan out with each thrust | Spears pierce everything in their way |
| Bubble Volley | Bubbles pop in a wider splash | Every volley ends with one big bubble | Each volley blows twice as many bubbles | Every volley ends with three big bubbles |
| Spine Burst | Spines fly further | A second ring of spines follows each burst | Spines pierce two more zombies | A third, full ring follows the second |

### 4b. Steady weapons

| Weapon (second-weapon id) | Fish | Base numbers | Proc | Facets (common step) |
|---|---|---|---|---|
| **Greek Fire Trail** (`attack_greek_fire`) | Lionfish | Drops a burning patch every 1.6 m swum. Each patch is 1.6 m in radius, lasts 2.0 s (× Duration) and burns for 40 dmg/s. At most 60 patches out. | 0.1 | Burn damage +25%, Patch life +0.4 s, Patch size +10%, Denser trail +12%, Max patches +5 |
| **Jellyfish Halo** (`attack_jellyfish_halo`) | Moon Jelly | 2 jellies orbit 3.2 m out at 0.5 turns/s. Each stings for 35 every 0.25 s on touch (1.2 m radius). | 0.2 | Jellies +1, Sting damage +25%, Orbit size +12%, Orbit speed +15%, Sting rate +15% |
| **Depth Charges** (`attack_depth_charges`) | Mantis Shrimp | Drops a mine every 4 s. It arms after 0.5 s and blows when a zombie comes within 2 m (or after 10 s × Duration): 46 dmg in a 5 m blast. At most 12 mines out. | 0.5 | Blast damage +30%, Blast size +15%, Drop rate +15%, Mines out +3, Arming speed +30% |
| **Remora Buddy** (`attack_remora_buddy`) | Baby Whale Shark | 1 remora nips the nearest zombie within 7 m every 1.5 s for 55. | 0.5 | Remoras +1, Bite damage +25%, Bite rate +15%, Reach +15% |
| **Leviathan's Coil** (`attack_leviathans_coil`) | — (boss only, from the Blood Leviathan; `coil_arrive_level` 5) | 6 coils trail the fish 1.4 m apart. Each hurts what it touches (0.9 m radius) for 55 every 0.25 s. | 0.3 | Coils +3, Coil damage +25%, Coil size +15%, Hit rate +15% |

**Milestones (Lv 5 / 10 / 15 / 20):**

| Weapon | Lv 5 | Lv 10 | Lv 15 | Lv 20 |
|---|---|---|---|---|
| Greek Fire Trail | Zombies that burn to death leave a patch behind | The trail fans out three wide | Patches flare up every few seconds, scorching wider | The flames creep toward the nearest zombie |
| Jellyfish Halo | Each jelly trails a ghost that stings too | The halo swings out wide every few seconds | A second, wider halo circles the other way | Stings jump on to the nearest zombie |
| Depth Charges | A triggered mine pulls zombies in, then blows | Every fourth blast is a cluster bomb | Armed mines drift toward zombies close by | Every blast goes off again a moment later |
| Remora Buddy | Remoras latch on and keep biting | A kill splits a remora in two for a while | Bites tear into the zombies round the one bitten | Remora kills heal you a little |
| Leviathan's Coil | Coils slow the zombies they touch | The coil's head snaps at zombies near it | The tail lashes out in a shock ring | The coil grows twice as long |

**Proc coefficient:** chances to trigger on-hit powerups (Chain Lightning, Torpedo, Sticky Anemone...) are multiplied by the hit's proc. A hit started by a powerup can't start that same powerup again. Other procs: lightning jump 0.3, torpedo 0.5, burn 0.1.

---

## 5. Tomes (`tomes.gd`)

A tome is a global stat that levels up (max Lv 99). One card adds one step of each of its stats × the card's rarity multiplier. **A tome with more than one stat gives each of them 70% of a step** (`tome_multi_share`).

| Tome (id) | Stats | Common card | Legendary card (×5) |
|---|---|---|---|
| **Tome of Teeth** (`teeth`) | Damage | Damage +10% | Damage +50% |
| **Tome of Tides** (`tides`) | Attack Speed | Attack Speed +8% | +40% |
| **Tome of the Reef** (`reef`) | Size | Size +10% | +50% |
| **Tome of Schools** (`schools`) | Projectiles | Projectiles +1 | +5 |
| **Tome of Currents** (`currents`) | Projectile Speed, Knockback | +7%, +10.5% | +35%, +52.5% |
| **Tome of the Kill** (`kill`) | Crit Chance, Crit Damage | +3.5%, +14% | +17.5%, +70% |
| **Tome of Fins** (`fins`) | Swim Speed, Stride Power | +3.5%, +4.2% | +17.5%, +21% |
| **Tome of the Ram** (`ram`) | Battery Damage | +15% | +75% |
| **Tome of the Shell** (`shell`) | Max HP, Armour, Regen | +7, +0.7, +0.28 HP/s | +35, +3.5, +1.4 HP/s |
| **Tome of Pearls** (`pearls`) | XP Gain, Pearl Chance, Pickup Range | +5.6%, +10.5%, +10.5% | +28%, +52.5%, +52.5% |
| **Tome of Fortune** (`fortune`) | Luck | +0.1 | +0.5 |
| **Tome of Ages** (`ages`) | Duration | +10% | +50% |

Tome of Ages only matters for Greek Fire, Depth Charges and Anglerfish Lure (`DURATION_WEAPONS`, `DURATION_ITEMS`; Ink Sac reads Duration too).

---

## 6. Powerups (items) (`powerup.gd`, `powerup_settings.gd`)

Items come from **chests**, never from level-up cards. A chest rolls a rarity with the opener's Luck and offers 3 different items. It starts with that tier, then fills from the tiers below it (nearest first), then the tiers above. Taking an item you already hold adds a **stack**. Unless a row says otherwise, "+X/stack" means **each stack after the first** adds X (base + X × (stacks − 1)). The flat stat items add their full amount every stack.

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
| **Riptide** (`riptide`) | A stride timed at its peak (timing ≥ 0.75) leaves a 10 m current behind you (2.5 m each side) for 3 s. Zombies in it are dragged back at 8 m/s and take 25 dmg/s | +12 dmg/s per stack |
| **Reef Guardian** (`reef_guardian`) | Dropping under 25% HP makes you untouchable for 3 s. Recharges in 60 s | Recharge ×0.85 per extra stack |
| **Bioluminescence** (`bioluminescence`) | Each level-up and each chest you open sends out a flash: 12 m radius (× Size), 10 dmg × team level | +2 m radius, +5 dmg per level per stack |
| **Anglerfish Lure** (`anglerfish_lure`) | Every 10 s it drops a glowing decoy (pull 3: zombies prefer it over a player up to 3× nearer) for 5 s (× Duration). Then it bursts for 80 dmg in 6 m (proc 0.5) | Interval ×0.9 per extra stack, +50 dmg per stack |

### Legendary

| Item (id) | Effect | Stacking |
|---|---|---|
| **Tsunami Heart** (`tsunami_heart`) | Each battery sends a wave along your heading: 6 m wide (× Size), rolling 24 m at 30 m/s. Every zombie it reaches takes 60 dmg and is swept along (proc 1.0). At most one wave per second | +2 m width, +40 dmg per stack |
| **Poseidon's Trident** (`poseidons_trident`) | Every 3rd attack of a fired weapon (every 3 s for a fish with only steady ones) calls lightning down on the biggest zombie within 30 m: 250 dmg within 4 m | +150 dmg per stack |
| **Megalodon Tooth** (`megalodon_tooth`) | Crits finish off zombies under 15% HP (not bosses) | +5%/stack, max 50% |
| **Moon Pearl** (`moon_pearl`) | Take +1 card from each level-up offer | +1 per stack |
| **Abyssal Engine** (`abyssal_engine`) | Projectiles +1, Size +15% | +1 and +15% per stack |

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
| Signature stat | +1 step (`signature_steps`) of the fish's own stat (§3) |
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
| At the start | 10 buried; then 1 more every 60 s, up to 16 unopened |
| Kill drop | 0.2% × (1 + luck), elites ×2, × Treasure Map |
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
| **Drowned Shark** (mini-boss, 5:00) | A chest, 80 XP, 25 pearls |
| **Blood Leviathan** (boss, 10:00) | Leviathan's Coil (boss weapon); the whirlpool exit that completes the stage |

---

## Keeping this up to date

When you add, change, rename or remove a fish, weapon, tome, powerup, stat, drop or default value, update the matching table here in the same change. New ids go in the right section and rarity tier. Facet steps and milestones come from `weapons.gd`, numbers from the settings resources.
