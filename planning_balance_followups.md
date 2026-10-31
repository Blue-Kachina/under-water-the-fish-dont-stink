# Balance follow-ups after bosses and survival (planning)

Written 2026-10-31, from the findings of the bosses-and-survival team session (planning_bosses_and_survival.md §1-§5). That session is still integrating, so this plan starts where its reports end. Sources:

- `analysis_class_survival.md`: the 440-run §5 matrix (11 classes x weapon Lv 5/10/15/20 x god/mortal x 5 seeds).
- The **bosses** report: `boss_pressure_bench` before/after, ChompKit, and the new Chomps and Boss Aggression settings groups.
- The **looks-items** report: red eyes, the boss tier of power-ups, Drowned Jaws, and the whole-run boss-item sims.

This plan covers six things:

1. Close out the integration: new probe failures, a Purple Haze script error, setting docs.
2. Fix the Skirmisher's sting pull, the clearest kit problem the matrix found.
3. Decide on the Purple Haze merge milestone, then tune the Alchemist.
4. Raise the offence floor of the "survives but can't clear" classes.
5. Two sim passes that the matrix left out: stand-still (bot artefact or kit?) and events (the Drowned Shark).
6. Boss follow-ups: boss-item strength, the Angel and the regrab cooldown, the bench's contact bias, and co-op gaps.

As always, every new number is a settings value with a wide range, not a const ([flexible tuning]). Battered/Fish Fry naming stays. Every retune goes into INVENTORY.md in the same change.

---

## 0. Integration close-out (the team session is on this; don't duplicate it)

### What's there now
The full probe suite on the combined tree has 8 failures. Against the HEAD baseline:

| Probe | Failing check | On HEAD |
|---|---|---|
| `car_cam_probe`, `survivor_cam_probe`, `compass_probe` | (GDExtension missing from the snapshot copy) | same, environment only |
| `powerup_batch_probe` | power-up and tier counts | failed on HEAD; looks-items updated the counts, so recheck |
| `hunter_bot_probe` | "on strides (8 of them in 5 s)" | **new** |
| `levels_probe` | "attack speed speeds up the bite" | **new** |
| `match_probe` | "the bot scores on an idle player (120 s, 16 touches)" | **new** |
| `stage_probe` | "16 segments, each a proxy" | **new** |

Also: `milestones_probe` passes but prints a SCRIPT ERROR in `PurpleHaze.open_cloud` (`purple_haze.gd:220`, a freed instance via `on_kill`). It wasn't in the HEAD baseline's log.

### Plan
- Rerun the four new failures on their own, with nothing else running (the suite ran two at a time while benches were going). A failure that passes alone goes on the flaky list; one that fails again gets a cause with file and line.
- Likely suspects to check first:
  - `levels_probe` bite speed: Drowned Jaws turns the next fired attack into a chomp, and the Bite path picked up ChompKit hooks.
  - `stage_probe` segments: the Coil's conversion from weapon to boss item, or the King's new net phase bits.
  - `hunter_bot_probe` / `match_probe`: Free Swim / Rocket League side. Neither should be touched by this pass, so a timing flake under load is most likely.
- Purple Haze `:220`: guard `open_cloud` against a cloud freed during `on_kill` (`is_instance_valid`). It belongs with §2 below, since both touch the cloud lifecycle.
- Regenerate `setting_docs.gd` once more after any setting added here.

### Check
The full suite on the combined tree matches the HEAD baseline apart from known environment failures. `milestones_probe` prints no script errors.

---

## 1. Skirmisher: the sting pulls the horde onto the fish

### What's there now
The Skirmisher has the fastest offence scaling (x70 from Lv 5 to 20) and the worst survival: 3/5 at Lv 15, **0/5 at Lv 20**, down at about 26 s. The time a zombie is touching it jumps from 1% at Lv 10 to 10% at Lv 15 and 26% at Lv 20, exactly at the sting's Lv 15 milestone. That milestone pulls every zombie within `radius() * PULL_REACH` toward the fish at `PULL_SPEED` m/s on every pulse (`scripts/unnatural/attacks/anemone_sting.gd:140-144`). Both are consts (`:27-28`, 2.0 and 8.0). Its Size signature (+0.1 a level) grows the pull's reach too. In real runs, 4 of 8 Skirmisher runs went down early.

### Plan
- Make the consts settings in the sting's group of `unnatural_settings.gd`: `sting_pull_reach` (2.0) and `sting_pull_speed` (8.0), wide ranges.
- New defaults to try: `sting_pull_speed` 8 -> 3 and `sting_pull_reach` 2.0 -> 1.4. That keeps the "gather" fantasy without dragging the pack into the fish.
- If contact time is still high, the next lever is `sting_radius` 6.5 -> 7.5, so it hits from further out. Leave its damage alone: its offence is top of the field.
- Optional, if the pull still feels bad: stop the pull short of the fish (a `sting_pull_stop` distance, e.g. 1.5x the hitbox length) so zombies gather in a ring instead of on the hitbox.

### Check
- Re-run the matrix rows for the Skirmisher (`--fish SKIRMISHER --levels 15,20`). Target: contact under 5% at Lv 20, survival at least 4/5, dps within 20% of today's.
- `milestones_probe` still sees the third milestone working.

---

## 2. Alchemist: decide on the Purple Haze merge milestone

### What's there now
Purple Haze is not a stat bug: in the same horde, sim dps goes from 2,156 at weapon Lv 1 to 8,821 at Lv 20. But the Lv 10 milestone merges touching clouds into one (`purple_haze.gd:238-239`, `_merge()` at `:288-308`). The merged radius preserves volume and is capped at `radius() * MERGE_MAX` (2.5, a const at `:34`). So overlapping clouds that each ticked the same zombies become one cloud that ticks them once. `spots()` places the follow-up bombs `PATH_STEP` (0.9, a const at `:29`) cloud radii apart (`:196`), so they touch and merge. On dense packs, the milestone can **lose** damage. weapon_bench drops from 2,401 dps at Lv 5 to 1,580 at Lv 10, exactly where merging starts.

The Alchemist also loses the most hp at Lv 5-10 (0.49 of max a minute) while its Regen signature is still small.

### Options (**Q1: A decided**, see Decisions)
- **A. A merged cloud keeps its parts' damage (chosen).** The merged cloud's tick damage is the sum of the clouds it swallowed, capped by a new `haze_merge_damage_cap` (e.g. 3x one cloud). The milestone then reads as "clouds pool into a big, nastier one", never a loss.
- **B. Raise the size cap.** `MERGE_MAX` becomes `haze_merge_max` and goes up (2.5 -> 4). Simpler, but bigger clouds still tick each zombie once, so on dense packs it can still lose damage.
- **C. Space the follow-ups out.** `PATH_STEP` becomes `haze_path_step` and goes from 0.9 to 2.1, so the follow-ups rarely touch. That sidesteps the merge rather than fixing it.

Whichever is picked, `MERGE_MAX` and `PATH_STEP` become settings.

### Then
- Fix the `open_cloud` freed-instance error (§0) in the same change.
- weapon_bench needs a moving or wider dummy layout for area weapons. Its static, immortal cluster makes every cloud land in the same spot, so Lv 1 already covers it. Add a `--spread` option (dummies spaced over a wider area that slowly drifts).
- Early defence: if the Lv 5-10 hp loss is still top after the merge fix, try the Regen signature's first step (`regen +0.4` a level) at +0.6 rather than a damage change.

### Check
weapon_bench with `--spread` rises steadily from Lv 1 to 20 with no drop at Lv 10. Re-run the Alchemist matrix rows.

---

## 3. Offence floor: Brawler, Breacher, Drifter, Lancer

### What's there now
| Class | Problem | Clear ratio (Lv 5 / 10 / 15 / 20) | Real runs |
|---|---|---|---|
| Brawler | weakest offence; lowest dps at Lv 10-20; slowest scaling (x13) | 0.23 / 0.08 / 0.29 / 0.46 | 2 of 4 early downs |
| Breacher | weakest start, then scales x48 | 0.09 / 0.17 / 0.53 / 0.65 | 3 of 3 early downs, all to the Drowned Shark |
| Drifter | survives but can't clear | 0.19 / 0.26 / 0.42 / 0.38 | no runs |
| Lancer | slow mid-levels | 0.26 / 0.27 / 0.24 / 0.78 | 1 of 1 early down |
| Bulwark | survives but can't clear | 0.20 / 0.19 / 0.24 / 0.36 | the designed tank: **leave it** |

### Plan (the report's proposed values, all existing settings)
- **Brawler:** `punch_damage` 30 -> 40 and `punch_cooldown` 0.7 -> 0.6 (about +55% single-target). Its scaling is the slowest, so if a punch facet step exists, a per-level boost fits better than a flat one. Re-check `punch_range` 7 against the bow reach (`punch_over_bow`).
- **Breacher:** `remora_damage` 55 -> 70 and `remora_range` 7 -> 9, so Lv 5-10 clears. Its late scaling is already high, so a flat base bump, not a facet step. Its signature (Pearl Chance) does nothing for survival or offence; that's a design question for later, not this pass.
- **Drifter:** `jelly_damage` 35 -> 45. If its clear ratio stays under 0.5, `jelly_count` 2 -> 3 is the bigger lever.
- **Lancer:** `thrust_cooldown` 1.0 -> 0.85, for the mid-levels. Its Lv 20 is fine.

**Q5: calibrate first.** These values wait for §4c's calibrated baseline; re-check each against it before applying. Then apply them one class at a time in the panel defaults and re-run that class's matrix rows (three classes per process, about 75 min for all four groups).

### Check
Each class's clear ratio at Lv 10 is at least 0.4 (the median is 0.60) with no survival loss. No class moves past the median at Lv 20, so these lift the floor without making new top picks.

---

## 4. Sim passes the matrix left out

### 4a. Stand-still control pass (Glider, Scorcher, Skirmisher)
The Glider (2/5 at Lv 20, 448 hp from contact) and Scorcher (4/5 at Lv 15-20) out-damage the field but take the most hits. Both are near-melee kits, so the bot swims through the horde to use them. The Glider had no downs in 4 real runs (median 14.5 min), which points at the bot rather than the kit.

- Add `--stand_still` to `class_survival_sim` (via a SurvivorBot mode that aims but never moves; the bot's own throttle/steer go to zero, aim stays on).
- Run the three classes at Lv 10/15/20, mortal + god, 5 seeds.
- Reading:
  - Survival recovers standing still → the bot's pathing is the problem. Look at the bot's approach distance for short-reach kits, not the class.
  - Still dies standing still → the kit. For the Glider, try a small signature-side tweak (i-frames or armour) rather than nerfing the lash.
  - The Skirmisher should look much better after §1 either way; this confirms it.

### 4b. Events pass at Lv 10 (the Drowned Shark)
9 of the 15 real downs were to the Drowned Shark, at about minute 5, which is exactly when the sim's Breacher is at its weakest. The matrix had stage events off.

- Run `class_survival_sim --events` at weapon Lv 10 (minute 4.8), so the 5:00 shark lands in the minute. All 11 classes, mortal, 5 seeds; 90 s instead of 60, so the fight fits.
- Record downs by cause (`taken_by` now exists in the run log).
- The shark's chomp wind-up went from 0.45 to 0.55 s in the bosses pass, which may already help. This pass measures the shark *after* that change.
- If the shark is still the top early killer, its knobs are `shark_chomp_wind`, the chomp damage and the new `chomp_miss_range`. Tune toward "a class at its median Lv 10 survives the shark 4/5 of the time".

### 4c. Calibration
The scenario's average zombie hp runs above the logs' medians (Lv 5: 36-48 vs 25.5). Fix that in `scenario_jump` before the re-runs in §1-§3, so the before/after numbers come from the same, better-matched conditions. Re-run the baseline rows once with the fix, so "before" is comparable.

---

## 5. Bosses: items, the Angel, and the bench

### 5a. Boss-item strength (**Q2: run-defining**, see Decisions)
At today's defaults, the boss items are modest spikes, not run-defining ones (3 classes x 2 seeds, items from 10:00):

| Config | Survived | DPS | Clear |
|---|---|---|---|
| none | 4/6 | 11,684 | 1.32 |
| Coil | 5/6 | 10,393 | 1.29 |
| Maw | 4/6 | 13,825 | 1.32 |
| Brood | 5/6 | 13,136 | 1.36 |
| Disc | 5/6 | 13,146 | 1.43 |
| Crown | 5/6 | 11,582 | 1.44 |
| Drowned Jaws (from 5:00) | 6/6 vs 5/6 | +32% | 0.90 vs 0.73 |

If the goal is RoR2-strength items, the plan is:
- Target: each final-boss item adds at least +25% dps **or** +0.25 clear ratio on its own, in the same sim.
- Knobs, in order: `maw_volley_damage` (60), `coil_damage` (55) and `coil_arrive_level` (5), `crown_damage` (45), `disc_drain` (30).
- The Coil shows *no* dps gain. Before raising numbers, check why: a Lv 5 Coil arriving at minute 10 may simply be weaker than the weapons already running. Try `coil_arrive_level` 5 -> 10 first.
- Re-run with 5 seeds, not 2. Six runs per setting is too noisy to tune on.

Decided: run-defining, so all five items get tuned to the target, not just the Coil.

### 5b. The Angel and the regrab cooldown (**Q3: yes**, see Decisions)
`final_regrab_time` went from a const 2.5 s to a 7 s setting, which brought the serpents' fury down. It applies to the Angel too, the boss everything else is tuned *to*. Its fury damage in the re-run went from 338 to 434 a minute: seed noise or the cooldown.
- Decided: give the Angel its own `angel_regrab_time` (default 2.5, the old value) so the target stays put, then re-run the Angel's bench at 10 seeds to settle whether 434 was noise.

### 5c. The bench's contact bias
The bench's Hunter bot chases the boss's body, so body contact dominates the numbers, and the fury fix (`serpent_fury_contact` 0.24) was tuned against that. Real players may feel less fury pressure than the table shows.
- Add a `--kite` mode to `boss_pressure_bench`: the bot keeps `boss_stalk_range * 0.5` from the boss's head and dodges telegraphed lanes. Re-run all five bosses.
- If fury drops well under the Angel in kite mode, raise the signature-move cadence in fury (not contact damage) to bring it back.
- The Gulper's phase-2 gap is 1.53x (target 1.5x). Re-check at 10 seeds before touching it; nudge `gulper_suck_every` 6 -> 5.5 only if it holds.

### 5d. Co-op gaps
- The boss items' zombie moves (Maw pull/relocate, Brood hold/slow) run only on the owner's machine, like the Whirlpool Charm; hits do sync. **Q4: later.** They stay a known gap alongside the Whirlpool Charm for a future net pass.
- With `boss_item_every_player` off, a second local player who opens the chest before the first commits still gets a copy. Fix: claim the chest on open, not on commit.

### 5e. Polish (small, from the reports)
- Gulper's Maw glyph is busy; Crown lashes are short streaks that are easy to miss.
- The King doesn't lift its snout in a chomp (its rig has no root pitch). Leave it unless the user notices.
- SurvivorBot's swap/keep branches are dead code since the Coil stopped being a weapon. Remove them.
- The team review listed a few new visual consts (fade rates, colours, the hagfish lunge timing, the Maw's spit speed). Turn the hagfish lunge timing and the Maw's spit speed into settings, since they affect gameplay; leave the colours and fades.

---

## Phases and hand-offs

| Phase | Work | Probes / tools | Hand-off to user |
|---|---|---|---|
| A | §0 close-out (team session), §4c calibration, then start §4a and §4b in the background | full suite vs baseline, `class_survival_sim` smoke | (none) |
| B | §1 Skirmisher pull settings + new defaults | `milestones_probe`, Skirmisher matrix rows | Build: play the Skirmisher past Lv 15 |
| C | §2 Haze merge (option A) + `open_cloud` fix + weapon_bench `--spread` | `milestones_probe`, weapon_bench, Alchemist rows | Build: Alchemist run |
| D | §3 offence-floor retunes (after the A calibration baseline) | matrix rows for the four classes | Build: Brawler and Breacher runs |
| E | Read §4a/§4b; Glider/Scorcher decision; shark tuning if needed | the two passes' reports | Report, then a build if anything changed |
| F | §5a-§5c boss items to run-defining, `angel_regrab_time`, kite bench | `boss_pressure_bench --kite`, `boss_items_probe`, whole-run sims at 5 seeds | Build: fight the bosses, pick up their items |
| G | §5d chest race fix + §5e polish (online item sync deferred) | `unnatural_net.sh`, `boss_items_probe` | Build: co-op boss chest |
| H | Full matrix re-run on the final tree; update `analysis_class_survival.md` | the §5 matrix, `survival_report.py` | Updated report |

Phases B-D can run as three teammates in parallel: they own different attack files and different settings rows. §4's sim runs go first because they run in the background for over an hour.

## Decisions (user, 2026-10-31)
- **Q1. Purple Haze merge: option A.** A merged cloud keeps the summed damage of the clouds it swallowed, capped by `haze_merge_damage_cap`. `MERGE_MAX` and `PATH_STEP` still become settings.
- **Q2. Boss items: run-defining.** Tune toward the §5a target (each item adds at least +25% dps or +0.25 clear ratio on its own), Coil first.
- **Q3. The Angel gets its own regrab time.** `angel_regrab_time` defaults to 2.5 s (the old value); `final_regrab_time` 7 s stays for the serpents.
- **Q4. Boss items' zombie moves online: later.** They stay owner-only, like the Whirlpool Charm, until a net pass. The `boss_item_every_player` chest race (§5d) is still fixed in this plan.
- **Q5. Calibrate first.** §4c's zombie-hp fix and a fresh baseline come before any §3 value goes in; the §3 values are re-checked against the calibrated numbers before applying.
