# Brainstorm: playability (Unnatural first, some for every mode)

2026-10-18. Ideas only: nothing here is decided or built. Each idea has a short **why**. Tick,
strike or comment on any of them and they'll go into a plan. The big one is §1 (item categories
and limits); the rest is grouped by theme.

---

## 1. Item categories: Weapons, Tomes and Items

### 1.1 Where we are now
Unnatural has two ways to get stronger, and neither has a ceiling:
- **Level-up cards** add to one of 18 stats (`StatBlock`), with a rarity roll. You can keep taking
  the same stat for ever.
- **Chests** give one of 23 powerups (`Powerup`), and every one stacks with no limit. Some are
  really weapons (Greek Fire, Jellyfish Halo, Depth Charges, Remora Buddy), some are on-hit procs
  (Chain Lightning, Torpedo Launcher), some are plain stats (Barnacle Plating, Fizzy Soda), and
  some trigger off batteries (Electric Eel, Tsunami Heart).

You're right about Greek Fire. It deals its own damage on its own rhythm whatever else you do,
which is what a Megabonk *weapon* does (Megabonk's Flamewalker is close to the same idea). RoR2
items, by contrast, mostly change *how your existing hits behave*.

**The risk with no limits.** Damage is multiplied together: damage stat × attack speed ×
projectiles × crit × proc chances × proc chains × weapon stacks. Each of those keeps growing, so
power climbs much faster than the difficulty curve (+30% hp a level). Around minute 8 you either
melt everything or you've been spread too thin and die. We also pay in frames: each stack adds
patches, torpedoes or bolts (see the torpedo bench's 23 ms spikes).

### 1.2 The proposal: three kinds, two with slots
Megabonk itself has all three (weapons, tomes, and items from chests), so this is "Megabonk's
shape, with RoR2's items on top".

| Kind | What it is | Where it comes from | Limit |
|---|---|---|---|
| **Weapon** | Does damage by itself, on its own timer | Level-up cards | **4 slots** (your fish's own attack is slot 1) |
| **Tome** | A global stat that levels up (damage, area, cooldown...) | Level-up cards | **4 slots** |
| **Item** | Changes how things behave: procs, on-hurt, on-battery, utility | Chests (and bosses, cursed chests) | No slots, but rare, and stacking flattens out (§1.6) |

**What the level-up cards then offer** (three cards as now, each rolled from):
1. upgrade a weapon you have (most common);
2. upgrade a tome you have;
3. a new weapon, only while you have a free weapon slot;
4. a new tome, only while you have a free tome slot.

Once all 8 slots are full, every card is an upgrade to something you already chose. That's the
moment the build "locks in", and later levels make it deeper instead of wider.

**Slot numbers are settings** (`weapon_slots`, `tome_slots`, panel settings like every other
gameplay value) with wide ranges, so you can feel 3 vs 4 vs 6 in the Test Tank. Unlocking a 5th slot could be a rare reward
(a boss chest, or a meta-progression unlock; see §5).

### 1.3 Where each existing powerup would go
A first draft. The ones marked **?** could go either way and are listed in §1.9.

| Today | Becomes | Note |
|---|---|---|
| Fish attack (Ghost Bite, Sting, Lash, Thrust, Bubbles, Spines) | **Weapon**, slot 1, can't be removed | Upgradable like the rest, so picking your fish matters more |
| Greek Fire | **Weapon** | |
| Jellyfish Halo | **Weapon** | |
| Depth Charges | **Weapon** | |
| Remora Buddy | **Weapon** | |
| Leviathan's Coil (boss) | **Weapon** (boss weapon) | Takes a slot, but arrives at a high level |
| Torpedo Launcher | **?** Item (on-hit proc, like RoR2's missiles) or Weapon (fires on a timer) | |
| Chain Lightning | Item | RoR2's Ukulele; procs off weapons, so items and weapons work together |
| Electric Eel, Tsunami Heart | Item | Battery triggers: these keep batteries worth doing |
| Pufferfish Spines, Bubble Wrap | Item | Defensive |
| Anglerfish Lure | **?** Item or Weapon | It's utility more than damage |
| Bow Grow Bow | Item | Signature to our game; must stay easy to get |
| Barnacle Plating, Hermit Shell, Fizzy Soda, Speedy Seahorse | Item (stays) | RoR2 whites are stats too; small and stackable |
| Drowned Fin (boss) | **?** Item, or the first **Equipment** (§7c) | It's already pressed on purpose |
| Blood Moon Shard, Glass Coral, Siren's Song, Abyssal Hunger, Sunken Idol | Cursed items (stay) | |

### 1.4 Tomes: the 18 stats folded into about 10
Fewer, broader tomes make each pick feel bigger and keep the slot choice meaningful.

| Tome | Covers today's stats |
|---|---|
| Tome of Teeth | damage |
| Tome of Tides | attack speed (cooldown) |
| Tome of the Reef | area |
| Tome of Schools | projectile count |
| Tome of Currents | projectile speed, knockback |
| Tome of the Kill | crit chance, crit damage |
| Tome of Fins | swim speed, stride power |
| Tome of the Ram | battery damage (and maybe battery speed threshold) |
| Tome of the Shell | max hp, armour, regen |
| Tome of Pearls | pickup range, XP gain |
| Tome of Fortune | luck |
| Tome of Ages | duration |

Each fish's **signature stat** (+1 every level) stays as it is: free, and doesn't use a slot.

### 1.5 Partial weapon upgrades (the Megabonk part)
Each weapon gets 4 to 6 **facets** it can improve. A card for that weapon rolls which facets
it improves, and its rarity decides **how many facets and by how much**:

| Card rarity | Facets improved | Size of each |
|---|---|---|
| Common | 1 | ×1 |
| Uncommon | 1 | ×1.5 |
| Rare | 2 | ×1.5 |
| Epic | 2 | ×2 |
| Legendary | 3 | ×2.5 |

The card shows exactly what you get, e.g. *"Greek Fire Lv 4 → 5: +20% burn damage, +1.5 s patch
life"*.

**Facets per weapon** (first drafts):

| Weapon | Facets |
|---|---|
| Greek Fire | burn damage, patch life, patch radius, patch spacing (denser trail), max patches |
| Jellyfish Halo | jelly count, sting damage, orbit radius, orbit speed, sting rate |
| Depth Charges | blast damage, blast radius, drop rate, mines out at once, arm time |
| Remora Buddy | remora count, bite damage, bite rate, reach |
| Torpedo (if a weapon) | torpedoes per volley, blast damage, blast radius, fire rate, homing turn rate |
| Ghost Bite | damage, jaw size (reach), bite rate, knockback, bleed |
| (one row per fish attack) | ... |

**Milestones**, so it *feels* noticeably stronger, not just bigger numbers. At Lv 5 and Lv 10
each weapon gains a new behaviour. Examples:
- Greek Fire 5: patches spread to the next patch if a burning zombie touches one. 10: the trail
  burns in a wide fan behind you.
- Jellyfish Halo 5: jellies leave a short sting trail. 10: they pulse outward every few seconds.
- Depth Charges 5: blasts pull zombies in before they go off. 10: one big charge in four is a
  cluster bomb.
- Ghost Bite 5: a second set of jaws snaps behind you. 10: jaws on both sides.

**A level cap** per weapon (`weapon_max_level`, e.g. 10) is the hard ceiling. Past it, that
weapon's cards stop showing, so the cards go to the weapons and tomes still growing.

### 1.6 Other limiters, to mix and match
Pick several; each one is a setting so it can be switched off.
- **Diminishing returns.** Chances (crit, procs, block) go hyperbolic: `1 - 1/(1 + k·stacks)`, never
  100%. Cooldowns have a floor (`min_cooldown`). Area has a soft cap past which it grows slower.
- **Item stacking curves.** The first stack is strong, later ones add less (e.g. 100%, 60%, 40%...).
  Different items flatten at different rates.
- **Effect caps** we already have for performance (`torpedo_max`, `lightning_max_rate`). Make them
  the visible design rule: "at most N in the water at once". It caps power and frames together.
- **Proc coefficients** (already in): keep them, and lower them for weapons that hit very often
  (Greek Fire ticks 4 times a second, so its proc coefficient should be low or 0).
- **Chests cost something.** RoR2's real limiter is that chests cost gold and the price rises over
  the run. We could add **Doubloons** dropped by zombies (or pearls over the level bar) and a
  rising chest price. That turns "open every chest" into "which chest is worth it".
- **Rarer chests later.** Chest drop chance and buried-chest count go down with stage time.
- **Weapon card frequency drops** as your weapons level, so tomes and new weapons get a turn.
- **Choice tools** (Megabonk and other survivors games have these): a few **rerolls**, **skips** and
  **banishes** per run. Banishing a weapon or item takes it out of the pool for the rest of the
  run. It gives agency without extra power.

### 1.7 Evolutions (optional, later)
Vampire Survivors style: a max-level weapon plus a specific tome (or item) can **evolve** into a
stronger version from a boss chest. Examples:
- Greek Fire 10 + Tome of Ages → **Sea of Flame** (patches merge into a burning lane);
- Jellyfish Halo 10 + Tome of the Reef → **Man o' War** (one huge jelly, long tentacles);
- Depth Charges 10 + Tome of Schools → **Minefield**;
- Remora Buddy 10 + Tome of Teeth → **Lamprey Pack** (they latch on and drain).

It gives a goal to build toward, and a big moment late in a run.

### 1.8 What it means for the code (rough)
Not a plan, just to show it's doable without a rewrite:
- `Powerup` gains a `kind` (WEAPON, ITEM) and weapons gain `level` and `facets`.
- A `Tome` maps to `StatBlock` entries, so the stat code keeps working.
- `LevelUpCards` offers four card types instead of one; the card's draw shows the facet lines.
- `PowerupSettings` keeps every number; facet steps become settings too.
- The HUD shows two slot rows (weapons, tomes) and an item strip, with levels on the slots.
- Probes: a new one for slot limits, card pools by slot state, facet rolls and evolutions.

### 1.9 Questions for you on §1
1. Slots: 4 weapons and 4 tomes to start, with the fish attack in weapon slot 1?
2. Torpedo Launcher: an on-hit item (as now) or a timed weapon?
3. Anglerfish Lure: item or weapon?
4. Drowned Fin: keep as an item, or make it the first Equipment?
5. Fold the 18 stats into about 12 tomes, or keep each stat as its own tome?
6. Doubloons and chest prices: worth trying, or keep chests free?
7. Rerolls, skips and banishes: how many of each, and should luck add more?
8. Evolutions: now, later, or not at all?

### 1.10 Answers (interview, 2026-10-18)
1. **Slots: 2 weapons + 2 tomes to start.** The fish attack takes weapon slot 1, so there's one
   free weapon slot. More slots come from meta-progression (§5). Still panel settings.
2. **Torpedo Launcher: item** (on-hit proc, as now).
3. **Anglerfish Lure: item.**
4. **Drowned Fin: stays an item** for now; revisit with Equipment (§7c).
5. **About 12 broad tomes**, as in the §1.4 table, except Tome of Pearls (see 6).
6. **Doubloons: try it as a setting, but with no extra pickups on the map.** Instead:
   - **XP is given on kill**, with no XP pearls to pick up. In co-op it feeds the **shared team level**.
   - **Pearls become the currency** (in place of Doubloons). They **drop by chance**, not on every kill.
   - Chest prices rise over the run (setting; free chests stay as an option to compare).
   - **Tome of Pearls** becomes **XP gain + pearl drop chance**, with magnet range folded in.
   - **Unnatural only.** Nature's pearls stay as they are (a per-mode setting).
7. **Rerolls, skips and banishes: none at the start, all unlocked** through meta-progression.
8. **Evolutions: later.** Design the weapon data so they can be added afterwards.

**Meta-progression unlocks:** a mix of Shells and challenges. Rerolls and skips are bought with
Shells. Extra slots and banish are unlocked by challenges (e.g. "Reach Lv 20", "Beat the Leviathan").

**Sections wanted in the plan:** all of §2 to §9. **Build order:** keep the suggested order at
the end of this doc (meta-progression stays late; until then, use the Test Tank slot settings).

---

## 2. Feel and readability
Aiming and reading the fight in 3D water is the hardest part of the mode.
- **Damage numbers** (already in phase 9), with crits bigger and coloured, and an option to show
  only big hits so the screen stays clean with 2,000 zombies.
- **A target marker** on whatever the auto-attack is aiming at, so you can see why it chose it.
- **Depth assist.** The horde tends to drift toward the player's depth, and auto-aim weights
  zombies near your depth. It makes the 40 m band feel more like a 2.5D arena without locking it.
  A setting (`depth_assist`), off to strong.
- **Hit flash and kill pop.** A one-frame white flash on a hit zombie and a little burst on a kill.
  Cheap on a MultiMesh (an instance uniform), and it's most of the "juice".
- **Threat arrows** at the screen edge for elites and bosses out of view, and a boss health bar.
- **Telegraphs.** Lunges and boss attacks wind up with a glow first, so dodging is a skill and
  damage taken feels fair.
- **Hurt feedback.** A red vignette pulse and a short low thud; low hp adds a heartbeat.
- **Pickup clarity.** Each drop has its own silhouette and colour, readable through the murk.
- **Camera.** Pull out a bit as the horde gets denser or as area grows, so big builds still fit.

## 3. Pacing and reasons to move
Right now the main reason to swim around is pearls and chests.
- **Sunken shrines** (RoR2 and Megabonk both have these). Examples:
  - *Shrine of the Tide*: stay inside its ring for 10 s while the horde comes; reward: a chest.
  - *Shrine of Chance*: pay Doubloons for a chance at an item.
  - *Shrine of the Deep*: makes the stage harder (more elites), but bosses drop two chests.
  - *Shrine of Pearls*: a magnet burst for the whole team.
- **Elite zombies** with RoR2-style modifiers: Burning (leaves fire), Electric (shocks on death),
  Frozen (slows on hit), Bloated (bursts into small ones). Elites drop chests more often.
- **Stage objectives** that end a stage: beat the boss, then a **next stage** with a new seabed
  and harder zombies, or stay for endless. This also answers the open question about the
  Leviathan's Coil having no drop: beating the Leviathan opens a boss chest and the way on.
- **Quiet moments.** A few seconds between waves so you can grab chests and breathe. The director
  already knows when a swarm ends.
- **Run length options:** a short run (10 min), a standard run, and endless.

## 4. Build agency and information
- **The card tells you what you have**: "Greek Fire Lv 3 → 4", "Tome slots 3/4".
- **A logbook** of every weapon, tome and item with its real numbers, found ones only.
- **Item tooltips on pause**, with stacks and what each stack is adding right now.
- **A damage meter** per source on the scoreboard (Greek Fire 34%, Ghost Bite 28%...). Players
  learn what works, and so do we.
- **A trader** (RoR2's printer and scrapper): a rare hermit crab who swaps one item for another
  of the same tier.
- **Starting choice:** pick one of two starter items or tomes before a run (later, via unlocks).

## 5. Meta-progression (between runs)
- **Shells**: a currency earned per run (time, kills, bosses), spent on unlocks.
- **Unlock by challenge** (Megabonk and RoR2 both do this): "Batter 500 zombies in one run" unlocks
  Electric Eel; "Win with the Boxfish" unlocks a tome. A smaller starting pool also makes early
  runs easier to learn, and keeps the card pool from getting diluted.
- **Fish unlocks and fish passives.** Each fish gets a small passive besides its attack and twist.
- **Difficulty tiers** (RoR2's Drizzle, Rainstorm, Monsoon): our Calm, Swell, Storm, Blood Tide.
  Higher tiers unlock as you win, and scale the difficulty curve and the director.
- **Small permanent upgrades** (Megabonk-style), kept small so skill still matters most.

## 6. Co-op
- **A ping** (a stick click or the D-pad): marks a chest, a drop or a zombie for the team.
- **Team items**: auras that help nearby teammates (a Cleaner Wrasse that heals whoever's close,
  a Pilot Fish that gives speed). Rewards staying together.
- **Revive juice**: the revive ring fills visibly; a revived player gets a second of
  untouchability and a shock ring.
- **Downed players still matter**: they can steer a little ghost that collects pearls, so nobody
  is just waiting.
- **Card-pick slow-mo for the picker** (D3, still a phase 8 leftover).

## 7. Batteries: keeping our signature central
The risk is that auto-attacks make batteries pointless.
- More items that fire **on battery** (we have Electric Eel and Tsunami Heart); a battery could
  also refund part of every weapon's cooldown.
- **Fish Fry** (multis) gives a short power spike, e.g. a few seconds of double fire rate.
- A **Tome of the Ram** (§1.4) so a battering build is a real choice.
- Battered Fish count on the HUD in Unnatural too, with streak rewards.

## 8. Balance tooling (so we can tune with numbers, not guesses)
Fits the usual workflow: headless probes, then your play-test.
- **A run simulator probe**: a bot plays with random (or greedy) picks and logs, per minute, its
  damage per second, time to kill an average zombie, damage taken, and when it dies. Run it 50
  times and we get a power curve against the difficulty curve.
- **A target curve**: e.g. time-to-kill of an average zombie stays between 0.3 and 1 s through
  the run. If a build goes outside it, that's a balance bug.
- **Run logs** written at the end of each real run (picks, damage by source, cause of death), so
  your play-tests come back with data too.
- **Test Tank presets**: one button to load "all slots full, Lv 10" builds for benchmarking power
  and frames.

## 9. Other modes (quick ideas)
- **Hunt / Nature**: the same damage meter and logbook ideas; Fish Fry as a power spike.
- **Everywhere**: a short "how to play" card per mode on first start, and a controls reminder
  when the pause menu opens.

---

## Suggested order, if you like most of this
1. §1.2 to §1.5: slots, tomes, partial weapon upgrades, with the current powerups sorted (§1.3).
   It's the biggest change to how runs feel, so it comes before more content.
2. §8's run simulator, so the new system's numbers can be checked before your play-test.
3. §2's hit flash, damage numbers and target marker (mostly phase 9 already).
4. §1.6's choice tools (reroll, skip, banish) and stacking curves.
5. §3: shrines, elites, and a next stage.
6. §1.7 evolutions, §5 meta-progression, §6 co-op extras.
