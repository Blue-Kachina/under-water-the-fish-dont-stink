# Bosses, chomps, red eyes and class survival (planning)

Written 2026-10-31. This plan covers five requests:

1. The red eyes should be subtle. Right now a small zombie far away is easier to see than one up close.
2. Each boss gets its own drop.
3. Boss tuning. The Fallen Angel's pressure is the target, and the other bosses should be as aggressive.
4. Chomps should look real, land on a better beat and hit hard.
5. An in-depth survival analysis for each class with only its main weapon upgraded. It uses conditions taken from our own run logs.

Work order: **§5 first**, because it is mostly sims and runs in the background while the other work happens. Then §1, then §4 (chomps, since §3 builds on them), then §3, then §2. Each phase follows the usual loop: build, headless probes, export, then hand off to the user for testing.

As always, every new number is a settings value with a wide range, not a const ([flexible tuning]). Rams stay "Battered", and "demo" is used only for Rocket League things.

---

## 1. Red eyes: subtle far away, readable up close

### What's there now
- **Far zombies:** `horde.gd` `_draw_horde` (≈ line 1108–1180) draws the glints. These are a MultiMesh pair of red dots using `shaders/zombie_glint.gdshader`. A zombie gets them when it is between `glint_near` and `glint_far`. `glint_near` is where the fog is `glint_from` = 0.8 thick, and `glint_far` = `glint_distance` = 170 m.
  - The dots **grow with distance**: the scale is `size * glint_size * (1 + gap / GLINT_GROW)`, with `GLINT_GROW` = 25. At 150 m that makes each eye 7× its base size.
  - Their brightness ramps up to the full `glint_strength` (1.0) within 6 m of `glint_near` and stays there almost to 170 m. So a far zombie is a pair of bright, fairly big red beacons.
- **Near zombies:** `shaders/zombie_overlay.gdshader` has no actual eyes. `eye_glow` (2.0) lights a smeared region over the front third of the head (`head * 0.8 + rim * 0.25`). Up close it reads as a reddish face, not as eyes. That is why near zombies lose the "eyes" the player learned to look for.

### Plan
- **1a. Far glints become a hint, not a beacon.**
  - `glint_strength` default goes from 1.0 to about 0.35.
  - New `glint_grow` setting (replaces the `GLINT_GROW` const). Its default stops the eyes outgrowing a couple of pixels: aim for a constant ~2 px on screen, not 7× size.
  - New `glint_fade_far` setting. Brightness falls off over the far half of the band (a smooth ramp), not only over the last 25%.
  - `glint_distance` default 170 → about 110 m, so the eyes only hint at the next wave instead of the whole sea.
- **1b. Near zombies get real eyes.**
  - Two small emissive eye spots in `zombie_overlay.gdshader`, placed per species. Either give the SchoolLook mesh's eye positions as a per-species uniform or bake them into a vertex colour channel. Investigate which is cheaper; the horde is GPU-bound per fish drawn (see the murk plan bench).
  - Keep a faint head glow (lower `eye_glow` weight on `head`) so the rot look survives.
  - New `near_eye_strength` setting. Its default must make an eye at 10 m clearly brighter on screen than a glint at 80 m.
- **1c. A hand-off band.** In the last few metres before `glint_near`, crossfade from the glint to the mesh eyes, so the eyes never vanish as a zombie closes in.
- **1d. Elites** keep their 1.6× glint size, but scaled by the same new rules.

### Check
- `tests/murk_shots` gets a "distance ladder" shot: the same zombie at 8, 20, 40, 80 and 140 m, in one screenshot per distance. Pass criterion: perceived eye brightness *falls* with distance.
- `murk_probe` keeps passing, plus a new check that the glint scale at 100 m is ≤ the scale at 20 m × the projected size ratio.
- Re-run `horde_bench` before and after, so 1b doesn't cost frames at 3k+ zombies.

---

## 2. Boss drops

### What's there now
In `UnnaturalRun._on_boss_defeated` (`unnatural_run.gd` ≈ 1759):
- The **Drowned Shark** drops a `TreasureChest.Kind.BOSS` chest with a generic legendary pick, plus shark XP and pearls.
- **Every final boss**, whether King, Gulper, Whale Fall, Lamprey or Angel (all `BloodLeviathan` subclasses), drops the same chest with `attack_leviathans_coil`.
- The weapon arrives at `coil_arrive_level` through `UnnaturalRun` boss-weapon handling (≈ 2208), with the Coil's swap offer when slots are full.

### Decided (user, 2026-10-31)
- The themes below are approved.
- **Final boss drops are a boss tier of power-up, not weapons.** This is like Risk of Rain 2's boss items. They never take a weapon slot.

### The boss tier
`Rarity.Tier.BOSS` already exists. Today it holds only the Coil, which is wired up as a weapon. This pass turns it into a proper power-up tier:
- **Boss chests only.** Boss-tier power-ups are never in level-up, chest or shrine pools. Each final boss's chest holds its own power-up (no pick screen).
- **No weapon slot.** They go into the power-up list like any item, and they stack. A second copy (from beating that boss again in a later stage, or in co-op) adds a stack, and each stack strengthens it (the "facet step" pattern the Coil already has).
- **Outside the item limits.** If P4's item limiters cap power-ups, boss-tier ones don't count toward that cap, so a boss drop never has to be refused or swapped.
- **Its own look:**
  - The hex power-up card shape, in a new boss material (a gold or crimson trim, distinct from legendary). It goes through the card materials pass's shared material code.
  - A boss-tier badge colour in the HUD loadout and the RunSummary.
  - A distinct chest-opening FX and sound (`chest/boss_item`).
- **Balance:** a boss item is meant to be run-defining, like RoR2's. It's checked in whole-run sims, not only on the crowd bench.

### The drops

| Boss | Boss-tier power-up (working name) | What it does (first draft; a stack makes it stronger) |
|---|---|---|
| King of Herrings | **Leviathan's Coil** | Glowing coils trail behind you and hurt what they touch. **Converted from a weapon into a boss power-up.** The settings stay; `coil_arrive_level` becomes the starting stacks, and the swap offer goes away. |
| Gulper Mother | **Gulper's Maw** | Every few seconds a vortex in front of you sucks zombies in, then spits them out as a damaging volley. Stacks: more swallowed, shorter cooldown. |
| Whale Fall | **Hagfish Brood** | Tethered hagfish (2, +1 per stack) lunge out, bite and knot onto zombies (crowd control), and slime them (slow) on release. |
| Lamprey Queen | **Queen's Disc** | A lamprey latches onto the toughest zombie or boss near you, corkscrews and drains it, and heals you a little per tick. It re-latches on a kill. Stacks: more drain and more heal. |
| Fallen Angel | **Angel's Crown** | Every few seconds a crown of tentacles bursts from your head and lashes a cone ahead several times. Each zombie it eats heals you. Stacks: more lashes, wider cone. |
| Drowned Shark (mini-boss) | **Drowned Jaws** (a *legendary* item, since the Shark isn't a final boss) | Every N seconds your next Bite becomes a chomp: a big single hit with the §4 impact. Stacks lower N. |

- **The Coil conversion:**
  - Remove the boss-weapon path (`unnatural_run.gd` ≈ 2225, the swap offer, `coil_arrive_level`) once nothing uses it.
  - `test_tank.gd` grants the Coil as an item.
  - Older run logs that list `attack_leviathans_coil` under weapons still load. `logview` and the new report count it as the item.
- **The Shark** still gives its usual legendary pick as well, so its drop isn't a downgrade.
- `_deep_chests` (Shrine of the Deep) keeps giving generic legendary picks.
- **Each drop needs:**
  - an entry in `powerup.gd`'s table with `Rarity.Tier.BOSS`, and its settings in `powerup_settings.gd` (a stacks override for testing, like `coil_stacks`)
  - an icon in `hex_badge.gd`
  - FX through FxKit, and catalog sound ids (the user records them later)
  - **INVENTORY.md rows**, including a new Boss tier section ([keep INVENTORY.md updated])
- **Test Tank:** a way to grant each boss item at N stacks.

### Question for the user before building
- **Q2.** Does a boss-tier power-up from the boss's chest go to every player in co-op (each gets a copy, as RoR2's boss drops do per player), or to whoever opens the chest?

### Check
- `final_boss_probe` gets checks per boss:
  - Beaten, it drops its own chest, and opening it adds its boss item.
  - The weapon slots are unchanged.
  - A second copy adds a stack.
- A new `boss_items_probe` checks that boss items never appear in level-up, chest or shrine offers, and don't count toward item limits.
- Whole-run sims with and without each boss item, from the boss's usual minute on. Each one should be a clear power spike without making the rest of the run trivial.

---

## 3. Boss aggression: bring the rest up to the Fallen Angel

### Why the Angel works (from its settings and states)
- It **locks on and stays on you.** It holds `angel_lock_gap × angel_lash_reach` metres off, matches your moves and orbits. You can never get out of its threat range by just swimming.
- **Short downtime:** `angel_rest` is 2.5 s between flurries. Each flurry is 3–4 lashes in 2 s.
- **Clear telegraph:** the crown opening and the halo closing. You know a hit is coming and have a real dodge window (`angel_dodge`).
- **The threat scales in phases** (more lashes and a faster crown in fury), but it is dangerous **from the first second**.

### How the others compare
- **Drowned Shark:** a charge every 6 s and a chomp every 2.5 s, but only when you're ahead of it within 14 m. Fine for a mini-boss; leave mostly alone.
- **King of Herrings:** chomps every 3 s within 18 m ahead, and coils **only in fury**. Otherwise it swims its course, so the player can keep away.
- **Gulper Mother:** sucks up zombies every 7 s (heals itself, not a threat to you). Its sucking of the *player* is **fury only**.
- **Lamprey Queen:** broods and blood clouds are indirect. Her lunge and latch are **fury only**.
- **Whale Fall:** the hagfish only reach 30 m from the carcass until fury. The player can just stay out of range.

### Plan
- **3a. Measure first.** A new `tests/boss_pressure_bench` puts a SurvivorBot (mortal, with a fixed mid-run build) against each final boss for 90 s, × 5 seeds. It records:
  - attacks started per minute and attacks landed per minute
  - damage to the player per minute
  - % of time inside any of its threat ranges
  - the longest gap with no threat
  - time to its first attack, and grabs per minute
  
  The Angel's numbers become the **target profile**.
- **3b. Stalking.** One shared mode on `BloodLeviathan`: when its target is farther than `boss_stalk_range`, it turns and closes at `boss_stalk_speed` instead of keeping its patrol or course. Every final boss gets this, so none of them can be out-swum indefinitely. The Whale Fall's carcass stays put, but its hagfish get the same reach-out rule (below).
- **3c. Signature moves before fury.** Each boss gets its signature attack from the first phase at a lower cadence. Fury speeds it up instead of unlocking it.
  - **King:** coil from 2/3 hp (`coil_from_phase`).
  - **Gulper:** player suck in every phase, with `gulper_suck` scaled by phase.
  - **Lamprey:** lunge in every phase, with `lamprey_lunge_every` per phase.
  - **Whale Fall:** one hagfish tears free at 2/3 hp and hunts, then all of them in fury. `hagfish_reach` grows per phase.
- **3d. A shared `boss_aggression` scale** (settings, default 1.0) that multiplies cadence and divides rest times on every boss. Plus per-boss overrides, so the user can tune them from the panel without touching code.
- **3e. Keep it fair.** Every new or more frequent attack keeps a telegraph at least as readable as the Angel's (glow, lane or halo), and a dodge window.

### Check
- Re-run `boss_pressure_bench`. Each final boss should land within about ±25% of the Angel on damage per minute and threat uptime, and its longest no-threat gap should be ≤ 1.5× the Angel's.
- `boss_moves_probe` keeps passing. Watch out: probe hits re-derive phase from hp, so set hp along with phase.
- Hand-off to the user with `tank_boss` for each boss.

---

## 4. Chomps that land like an impact

### What's there now (`drowned_shark.gd` `_update_chomp` / `_snap`; the King's is the same shape)
- **Wind-up:** the jaw opens **linearly** (`move_toward`) over `shark_chomp_wind` (0.45 s), with a velocity surge forward at the start.
- **Snap:** the jaw closes at 12/s (~0.08 s), and damage applies **on the first frame of the snap**, before the jaw is visually shut.
- **Feedback:** only the `boss/chomp` sound and the damage. No head motion, no camera punch, no knockback, no particles, nothing on a miss.

The same applies to the King's chomp, the hagfish bite, the Gulper's swallow snap and the Lamprey's latch.

### What a real bite looks like (shark reference)
1. **Anticipation:** the head pulls back slightly and the snout lifts.
2. **Gape:** the lower jaw drops fast, then *holds* wide. This is the readable telegraph.
3. **Strike:** the body lunges and the upper jaw protrudes forward. The jaws slam shut in under 0.1 s, at the same moment the head arrives.
4. **Bite and shake:** a short side-to-side head shake (sharks saw), then recovery.

### Plan: a shared `ChompKit` used by every jawed boss
- **4a. Animation curve.** Replace the linear jaw with phased timing, all settings (`chomp_anticipate`, `chomp_gape`, `chomp_hold`, `chomp_strike`, `chomp_shake`, `chomp_recover`):
  - Anticipation pull-back: ~0.12 s.
  - Gape with an ease-out curve: ~0.2 s.
  - Hold: ~0.2 s.
  - Strike: the forward lunge (distance as a setting), plus jaw shut with an ease-in over ~0.07 s.
  - Shake: ~0.3 s, using `SpineRig.twist` / yaw wobble.
  - Recovery.
  - The existing `spine_hinge` (boss_oarfish) and the DrownedShark jaw rig take the jaw value. The head pitch and lunge go through the spine / root.
- **4b. Damage on contact frame.** Damage applies when the jaw reaches ~90% shut, not when the snap starts. Reach is tested from the mouth point *at that moment*, so the lunge matters and side-steps during the hold work.
- **4c. Impact on a hit:**
  - **Camera punch:** a short, sharp shake scaled by damage, plus a kick toward the boss. It goes through the existing camera pull or shake path, per view in split-screen.
  - **Hit-stop feel without a global time scale** (networked game): freeze the *boss's* animation and the victim's input response for ~70 ms, and briefly squash the player fish.
  - **Knockback impulse** on the player, away from the mouth.
  - **Red vignette pulse:** reuse the P3 vignette, but stronger.
  - **Gamepad rumble** (strong, short), if the input path supports it.
  - **FX through FxKit:** a blood cloud, a bubble burst from the jaws and a few tooth sparks.
  - **Sound:** a layered `boss/chomp` (crunch) plus a new `boss/chomp_thud` (low impact).
  - **The damage number** uses the big style.
- **4d. Impact on a miss:** the jaws still clack shut, with a smaller shake for players within ~2× reach, a bubble puff and a `boss/chomp_miss` sound. Even a dodged chomp should feel heavy.
- **4e. Apply to:** Drowned Shark, King of Herrings, hagfish bite (Whale Fall), Gulper snap (swallowing a player), Lamprey latch (disc slam instead of jaws), and the Drowned Jaws item from §2.
- **4f. Zombie lunges get a lighter impact** (user approved, as long as it costs little). Zombies are MultiMesh, so there's no jaw animation. The feedback is all on the *victim's* side, so its cost doesn't grow with the size of the horde:
  - **Trigger:** the existing lunge-hit path in the horde, which already hurts the player, calls `ChompKit.light_impact(fish, from)` once.
  - **What plays:**
    - a small camera tick (about 25% of a boss chomp's shake)
    - a short red rim flash on the vignette
    - a light knockback (a setting, default small)
    - a light rumble
    - one pooled bubble-puff FX at the contact point
  - **No hit-stop and no damage-number change.**
  - **Throttle:** at most one light impact per player per `lunge_impact_every` (about 0.15 s). With 1,000+ zombies around you, a swarm reads as a steady rattle, not a constant shake, and the FX and sound count stays flat. Shake from impacts inside the same window is merged (the strongest wins).
  - **Settings:** `lunge_impact` on/off, plus shake, knockback, flash and throttle.
  - **Check:** compare `horde_bench` and `split_bench` (3 players) with `lunge_impact` on and off. The goal is under 1% fps difference. A probe confirms the throttle caps it at 1 impact per window under a 200-zombie swarm.
- **Networking:** the shark's `_net_mode` already sends wind/snap bits. Add the phase index so puppets play the same curve.

### Check
- `boss_moves_probe`: damage lands only after the jaw is ≥ 0.9 shut, and a player who leaves reach during the hold takes none.
- `boss_moves_shots --only=chomp`: a frame strip through one chomp, to eyeball the curve.
- The user test is the real judge. All timings are panel settings so they can be tuned live.

---

## 5. Class survival analysis: main weapon only

### Goal
For each of the 11 classes (Skirmisher, Hunter, Glider, Lancer, Charmer, Bulwark, Scorcher, Drifter, Brawler, Breacher, Alchemist): how well does it survive, and how much does it output, with **only its main weapon** levelled (no other weapons, tomes or items)? The test conditions match what real runs look like when the main weapon reaches Lv 5, 10, 15 and 20.

### 5a. Conditions from our run logs (already pulled)
- **Source:** 51 logs in `user://run_logs/`, from 2026-10-19 to 2026-10-28. For each run, the first time player 0's `attack Lv N` pick crossed 5, 10, 15 and 20, then the minute sample at that time.
- **Data used:** only runs from 2026-10-23 onward, to match the current balance.
- **Values in the table:** medians. `alive` is the zombies out at that moment, `target` is the director's target, and `diff` is the director's difficulty.

| Main weapon | Runs | Minute (median, range) | Player level | Director target | Alive | Difficulty | Avg zombie hp |
|---|---|---|---|---|---|---|---|
| Lv 5 | 23 | 2.3 (1.0–6.5) | 8 | 125 | 262 | 1.0 | 25.5 |
| Lv 10 | 13 | 4.8 (2.6–15.8) | 16 | 395 | 273 | 2.5 | 59.3 |
| Lv 15 | 9 | 8.0 (4.4–19.0) | 29 | 896 | 615 | 4.0 | 92.4 |
| Lv 20 | 8 | 10.1 (6.5–21.1) | 34.5 | 1205 | 408 | 5.0 | 150.8 |

Notes:
- Many runs end before Lv 15/20, which is a survivorship bias in itself. Short runs are mostly early downs: Hunter, Skirmisher, Breacher, Brawler, Charmer, Mantis and Whale Shark. That alone is a signal for this analysis.
- `alive` is often under `target` because good builds clear faster than the director spawns. The sim uses the **director's target** for the minute, so every class faces the same pressure.
- The legacy RL-hitbox names in older logs (DOMINUS, MERC, OCTANE, PLANK…) map onto the current classes through `FishCharacter` aliases. The extraction script will normalise them.
- The extraction script is `milestones.py` / `medians.py` in the session scratchpad. It will be moved to `tools/` with a stable CLI so the numbers can be refreshed after more play.

### 5b. A scenario mode for the sim
Add `--scenario` to `tests/run_sim` (or a sibling `tests/class_survival_sim` if it gets too tangled):
- `--at=<minute>`: jump the run clock and director to that minute, so difficulty, zombie hp, roster rotation and stage damage all follow. Skip bosses and events whose time has passed, and keep the rift closed.
- `--weapon_level=<L>`: give the class's main weapon (`attack`) at level L, with its milestones applied.
- `--player_level=<n>`: set the XP level to the median above, so anything keyed to player level matches.
- **Main weapon only:** a new `SurvivorBot.Picks.MAIN_ONLY` skips every card (rerolls and banishes off), so the weapon stays at L for the whole minute and nothing else is ever taken. Pearls and chests are ignored.
- `--prefill`: spawn the director's target count at once, in its normal spawn ring, so the minute starts at full pressure instead of ramping.
- `--minutes=1`.
- Two passes per cell:
  - **Mortal:** does it survive, and how long.
  - **`--god`:** a full minute of offence numbers, not cut short by a down.

**Matrix:** 11 classes × 4 levels × 2 passes × 5 seeds = 440 one-minute runs. At ~3× real time per process with 4 side by side, that's about 45 min. It runs in the background while §1 is built.

### 5c. What gets recorded per run (a CSV row per run, and the JSON log)
- **Survival:**
  - survived (y/n), time to down
  - hp lost per second, and the lowest hp
  - damage taken by source (contact, lunge, elite effects, ranged)
  - times Battered and batteries dealt
  - % of time with a zombie in contact range
- **Offence:**
  - total damage, dps, kills, kills per minute
  - ttk (avg zombie hp ÷ dps), overkill share
  - hits landed, hits per second, damage per hit
  - average and max zombies alive, fill (alive ÷ target)
  - **clear ratio** = kills per minute ÷ the director's spawn rate at that minute. Above 1 keeps up; below 1 gets swarmed.
- **Weapon sheet at L:** dumped once per class × level from the attack's own stat derivation:
  - damage, cooldown or attack speed, area or Size, Quantity, pierce, crit, knockback, range, duration
  - which milestones are active
  - theoretical single-target dps and crowd dps

  This is the same numbers `weapon_bench` reads, so the two can be cross-checked.
- **Class base stats:** hp, armour or regen, speed, hitbox size. With these we can separate "dies because fragile" from "dies because it can't clear".

### 5d. The report
`tools/survival_report.py` (run through uv) reads the CSVs and writes `analysis_class_survival.md`. It has:
- One table per weapon level with every class: survival %, median time to down, dps, kills/min, clear ratio, hp lost/s. Classes are sorted by survival, then clear ratio.
- One weapon-sheet table per class across Lv 5/10/15/20, showing how each stat scales.
- **Flags:**
  - a class whose survival or clear ratio is more than 1 σ below the median at any level
  - a class whose dps scales much slower or faster from Lv 5 → 20 than the others
  - a class that "out-offences" but still dies (a defence problem), or survives but can't clear (an offence problem)
- **Conclusions and proposed retunes,** per class. These are value changes only, as panel settings ([keep game features on]). Then the matrix is re-run after the retunes to confirm the gap closed.
- A cross-check against the real logs: do the classes the sim flags match the ones that went down early in the user's runs?

### Known confounds (stated in the report)
- SurvivorBot's skill isn't equal across movement styles. Glider and Breacher may be helped or hurt by the bot rather than their kit.
  - A stand-still control pass (the bot only aims, never moves) would isolate the weapon from the bot. **It's left out of the first run** to keep testing time down (user, 2026-10-31).
  - If the report's flags look like bot artefacts (for example, a class that does well in god mode but dies in mortal runs with low damage taken from contact), it's the first follow-up to add.
- "Main weapon only" is not how anyone plays. The report frames results as the baseline floor each class stands on, not as overall class strength.
- The bot is safer than a human (balance pass 1 lesson). Survival numbers are relative between classes, not absolute.

---

## Phases and hand-offs

| Phase | Work | Probes / tools | Hand-off to user |
|---|---|---|---|
| A | §5b scenario mode, §5c recording, start the matrix in the background | `run_log_probe`, a quick 2-run smoke test | (none yet) |
| B | §1 red eyes | `murk_probe`, `murk_shots` distance ladder, `horde_bench` | Build: check eyes near and far |
| C | §5d report and conclusions | `survival_report.py` | `analysis_class_survival.md` to review, *then* retunes |
| D | §4 ChompKit, applied to all jawed bosses, plus the light zombie-lunge impact (4f) | `boss_moves_probe`, `boss_moves_shots`, `horde_bench` / `split_bench` on/off | Build: feel the chomps in `tank_boss`, and swarm lunges in a live run |
| E | §3 boss pressure bench, stalking, signature moves earlier, `boss_aggression` | `boss_pressure_bench`, `final_boss_probe` | Build: fight each boss |
| F | §2 boss tier of power-ups, the Coil conversion, Drowned Jaws, INVENTORY.md | `final_boss_probe`, `boss_items_probe`, whole-run sims | Build: boss items in Test Tank and live runs |
| G | Class retunes from §5 (after the user reviews C), then re-run the matrix | the §5 matrix again | Build: play the flagged classes |

## Decisions (2026-10-31)
- The drop themes are approved.
- Final boss drops are a boss tier of power-up (RoR2-style). They take no weapon slot, and the Coil is converted to one.
- The Drowned Shark's Drowned Jaws stays a legendary item.
- Zombie lunges get the lighter impact, if the cost stays under ~1% fps.
- The first survival run has no stand-still pass.

## Open questions
- **Q2.** In co-op, does each player get the boss item, or only whoever opens the chest? (§2)
