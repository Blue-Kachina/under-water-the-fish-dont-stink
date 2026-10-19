# Refining Weaponry

Planning pass 2026-10-19. Goal: (a) tables of every fish / weapon / tome so we can propose edits, and (b) decisions and work items for a batch of cleanup and feature changes. No code has been changed yet. Figures come from a code read, not play-testing.

Abbreviations: `us` = `scripts/unnatural/unnatural_settings.gd`, `ps` = `scripts/unnatural/powerups/powerup_settings.gd`, `run` = `scripts/unnatural/unnatural_run.gd`.

---

# PART 1 — Reference tables (editable)

## 1.0 Rules that apply everywhere
- Level-up: every player gets +1 step of their fish's signature stat (× `signature_steps`, us:417). Max HP +10/level (base 100). The team shares one level; XP to next = ceil(5 × L^1.9).
- Cards: 3 per level. Kind weights: upgrade weapon 40 / upgrade tome 30 / new weapon 15 / new tome 15 (new only while a slot is free). Fallbacks: pearl purse, 30% team heal.
- Slots: weapons 2 (the fish's own attack takes one), tomes 2. Weapon max Lv 20, tome max Lv 99.
- Rarity weights 60/25/10/4/1 (Common→Legendary); BOSS and CURSED never roll on cards. Tome multipliers ×1/1.5/2/3/5.
- Weapon upgrade card: facets raised 1/1/2/2/3 by rarity; facet step ×1/1.5/1.5/2/2.5.
- Milestones at weapon Lv 5/10/15/20.
- Damage pipeline (`run:774`): × (1+Damage) → crit (×(1.5+crit_damage)) → knockback → on_hit hooks (proc coefficient).

## 1.1 Playable fish
All six share base stats (HP 100, regen 0, i-frames 0.7 s). They differ in hitbox, starting weapon, signature stat and traversal twist.

| Fish | Starting weapon | Signature stat (auto +1 step each level-up) | Step | Twist (passive) |
|---|---|---|---|---|
| Clownfish | Anemone Sting | area | +10% | Nimble: turn ×1.4 |
| Shark | Ghost Bite | damage | +10% | Frenzy: +4%/kill swim speed, max +50%, 3 s hold |
| String Ray | Shock Lash | attack_speed | +8% | Glide: keeps 30% of drag while coasting |
| Swordfish | Bill Thrust | projectile_speed | +10% | Dash: dodge +14 m/s, 0.3 s untouchable |
| Butterfly Koi | Bubble Volley | luck | +0.1 | Leap: jump leaps +12 m/s, splashdown 30 dmg / 7 m, 2.5 s cd |
| Boxfish | Spine Burst | armour | +1 | Armoured: 0.7× damage taken, 0.88× speed |

### Stat steps (per card at Common)
| Stat | Step | Stat | Step |
|---|---|---|---|
| max_hp | +10 | projectile_speed | +10% |
| regen | +0.4/s | crit_chance | +5% |
| armour | +1 | crit_damage | +20% |
| damage | +10% | swim_speed | +5% |
| attack_speed | +8% | stride_power | +6% |
| area | +10% | battery_damage | +15% |
| projectile_count | +1 | knockback | +15% |
| duration | +10% | pickup_range | +15% |
| xp_gain | +8% | pearl_chance | +15% |
| luck | +0.1 | | |

## 1.2 Weapons

### Fish attacks (one per fish; occupies a weapon slot)
Common facets: damage +20%, rate +12%, knock +30% (where listed), size +12%.

| Weapon | Fish | Ability | Base output | Scalable properties (facets) | Stat gates |
|---|---|---|---|---|---|
| Ghost Bite | Shark | Spectral jaws on an ellipsoid ahead; nearest zombie in 110° | 26 dmg / 0.9 s, reach 8 m (~29 dps/target) | damage, rate, size (jaw), knock | — |
| Anemone Sting | Clownfish | Pulse around fish, only if a zombie is in range | 9 dmg / 0.9 s, radius 6.5 m (~10 dps/target) | damage, rate, size (pulse), knock | — |
| Shock Lash | String Ray | Tail whips nearest in 14 m, arcs to others (70% dmg) | 47 dmg / 0.8 s, 1 arc (~100 dps) | damage, rate, size (reach), arcs (+1) | projectile_count |
| Bill Thrust | Swordfish | Spear at nearest in 60°, pierces 6 | 34 dmg / 1.0 s, 45 m/s | damage, rate, spears (+1), speed (+15%) | projectile_count, projectile_speed |
| Bubble Volley | Koi | 4 homing bubbles, pop splash 2 m | 9 dmg ×4 / 1.2 s (~30 dps) | damage, rate, bubbles (+1), speed | projectile_count, projectile_speed |
| Spine Burst | Boxfish | Ring/sphere of 18 spines when a zombie is within 12 m | 32 dmg ×18 / 1.4 s, pierce 2 | damage, rate, spine rings (+1), range | projectile_count (+4 spines), projectile_speed |

Milestones (Lv 5 / 10 / 15 / 20):
- Sting: echo pulse / slow 60% / pull-in / third pulse
- Bite: echo jaws behind / sides / above+below / re-snap after 0.3 s
- Lash: 2nd zombie struck / arcs jump ×2 far / +2 arcs / 3rd zombie struck
- Thrust: pierce +1 / burst at end of flight / +2 spears / pierce all
- Bubbles: pop ×1.6 / big bubble ends volley / double bubbles / three big bubbles
- Spines: range ×1.4 / second ring 0.25 s later / pierce +2 / third full ring

### Powerup weapons (cards)
| Weapon | Tier | Ability | Base output | Scalable facets | Stat/tome scaling |
|---|---|---|---|---|---|
| Greek Fire Trail | Uncommon | Swimming >2 m/s drops burning patches | 40 dps per patch, r 1.6 m, life 2 s, max 60 | burn +25%, life +0.4 s, radius +10%, density +12%, patches +5 | Damage, Duration |
| Jellyfish Halo | Uncommon | Jellies orbit and sting | 2 jellies, 35/tick @0.25 s (140 dps each), r 3.2 m | count +1, damage +25%, radius +12%, spin +15%, rate +15% | Damage |
| Depth Charges | Rare | Mine drops behind; arms, blows on proximity | 46 dmg, blast 5 m, every 4 s, max 12 | damage +30%, blast +15%, rate +15%, mines +3, arm +30% | Damage, Duration |
| Remora Buddy | Common | Remoras nip nearest zombie in turn | 55 dmg / 1.5 s per remora (~37 dps), reach 7 m | count +1, damage +25%, rate +15%, reach +15% | Damage |
| Leviathan's Coil | BOSS | Chain trails fish, hurts on touch | 6 segs, 55/tick @0.25 s (220 dps/seg), arrives at Lv 5 | count +3, damage +25%, size +15%, rate +15% | Damage |

Milestones (Lv 5 / 10 / 15 / 20):
- Greek Fire: burnt-out zombie leaves patch / 3-wide trail / flare every 3 s / patches creep to zombies
- Halo: ghost trail stings 50% / swings wide every 4 s / second counter-ring 75% / stings jump 4 m
- Depth Charges: pull-in before blast / every 4th is a cluster bomb / mines drift to zombies / blast repeats 0.4 s later
- Remora: latch (3 bites @50%) / kill splits a temp remora / nips tear 2.5 m / kills heal 1%
- Coil: slow 50% / head snap 5× / tail shock ring 3× / coil ×2 length

### Items (chests only; not weapons)
| Item | Tier | Effect / scaling per stack |
|---|---|---|
| Chain Lightning | Uncommon | 15%+8% chance, 3+1 jumps, 22 dmg, 8 m |
| Torpedo Launcher | Rare | 8%+5% chance, 1 per 2 stacks, 40 dmg, blast 3 m +0.6 |
| Bow Grow Bow | Common | bow scale +0.5; from 3 stacks bow batters at 50% |
| Barnacle Plating | Common | +2 armour |
| Hermit Shell | Common | +15 max HP |
| Fizzy Soda | Common | +8% attack speed |
| Speedy Seahorse | Common | +6% swim speed |
| Bubble Wrap | Common | free hit after 8 s untouched, −1 s/stack (floor 2 s) |
| Pufferfish Spines | Uncommon | reflect 0.5+0.25; burst 25+15, r 4 m |
| Electric Eel | Uncommon | battery → ring 30+20, r 5+1 |
| Anglerfish Lure | Rare | decoy every 10 s×0.9^n; bursts 80+50, r 6 |
| Tsunami Heart | Legendary | battery → wave 60+40, width 6+2 |
| Drowned Fin | BOSS | boost dash 45 m/s; 90+45 per zombie passed |
| Blood Moon Shard | CURSED | +1.0 damage, +0.5 damage taken |
| Glass Coral | CURSED | +1.0 damage, max HP ×0.5^n |
| Siren's Song | CURSED | +1.0 XP, +50% zombies |
| Abyssal Hunger | CURSED | kill heals 3% max HP; lose 2%/s |
| Sunken Idol | CURSED | +1 chest pick; stage events cost a random item stack |

## 1.3 Tomes
Multi-stat tomes give each stat 0.7 of a step. Amounts shown at Common.

| Tome | Stats | Per card | What it actually scales |
|---|---|---|---|
| Teeth | damage | +10% | every hit |
| Tides | attack_speed | +8% | **fish attack only** (powerup weapons ignore it) |
| the Reef | area | +10% | **fish attack only** |
| Schools | projectile_count | +1 | Lash/Thrust/Bubbles/Spines only; offered only if the attack uses it |
| Currents | projectile_speed, knockback | +7%, +10.5% | Thrust/Bubbles/Spines speed; all knockback |
| the Kill | crit_chance, crit_damage | +3.5%, +14% | every hit |
| Fins | swim_speed, stride_power | +3.5%, +4.2% | movement |
| the Ram | battery_damage | +15% | ramming damage |
| the Shell | max_hp, armour, regen | +7, +0.7, +0.28/s | survivability |
| Pearls | xp_gain, pearl_chance, pickup_range | +5.6%, +10.5%, +10.5% | economy |
| Fortune | luck | +0.1 | card/chest rarity, chest drops |
| Ages | duration | +10% | Greek Fire + Depth Charge only; **does nothing for Anglerfish Lure** despite being listed (bug, being fixed — see 2.14) |

**Decided:** Tides (attack_speed) and the Reef (area) must also affect powerup weapons (see 2.14). Anglerfish Lure must read Tome of Ages.

---

# PART 2 — Decisions & work items

## 2.1 Ambient loops keep playing during card picks
Cause: `sfx.gd:507-508` `_process_mode_for` makes the `Ambience` bus PAUSABLE, so `get_tree().paused` freezes `amb/*` loops during level-up/chest cards (`_hold_for_cards`, `unnatural_run.gd:1881`).
- Add `"Ambience"` to the always-run list.
- `stage/blood_moon_loop` sits on `World`; give it an always-run override (or move it to `amb/`).
- Gameplay loops (moan, heartbeat, magnet) stay pausable.
- To decide: should beds also continue under the pause menu? The same fix covers it; separating card-pause from menu-pause would need an extra flag.
- Update `tests/audio_probe.gd` loop checks and add a note to `planning_audio.md` §4.3/4.4.

## 2.2 Cancel out of a chest opening
Today the chest is opened, paid, consumed and its cards rolled before the UI shows (`open_chest`, `run:1815`); `LevelUpCards` has no cancel input.
- Design: **commit on pick, not on open.** Reserve the chest and roll, show the cards, and only `open_for` / charge / stats / `chest_opened` when `pick()` succeeds.
- Cancel = B/Esc on a chest offer only (not level-ups); hint added to `_hints`. Check Esc ordering vs `pause_menu.gd`.
- Cache the rolled cards per chest+fish so cancel/reopen can't reroll (exploit at price 0); keep deterministic for online/replay.
- Cancel only before the first pick (Sunken Idol extra picks and `_offer_swap` can't cancel).
- Refund uses the stored price (price grows with time/paid_chests).
- Online: propagate cancel (`chest_claimed`, `apply_chest_opened`, `unnatural_net.gd`); defer the open sound/flash to commit.
- Bots (`survivor_bot.gd`) never cancel. Update `tests/unnatural_net_peer.gd`.

## 2.3 Remoras visibly attack
Today damage is instant from the player (`remora_buddy.gd on_tick`) and the worn capsules are static.
- Per-remora state using the existing worn child nodes. On each turn: detach / tween from flank to the target (`horde.enemy_position`), land → `run.hit` + `PowerupFx.flash`, tween back and re-attach.
- Latch milestone (Lv 5): remora stays on target with tail wiggle and bite pulses.
- Reuse `FxKit` (ribbons/glow/rim), `PowerupFx`, and `anglerfish_lure.gd` as the example of a powerup owning nodes.
- Keep hit timing deterministic (damage on arrival, short travel); handle `take_off()/wear()` rebuilds, `on_removed()` cleanup, render layers/split-screen, `PowerupFx` MAX 40.
- Bench with `weapon_bench`; probes assert nips/tears counts.

## 2.4 Bosses need far more health
Current: Drowned Shark `shark_hp` 2500 (us:368), Blood Leviathan `leviathan_hp` 9000 (us:387), each × `crowd` (run:1195/1198).
- Raise both substantially; keep as panel settings with wide ranges.
- Starting point to tune with `run_sim`/`weapon_bench` (not yet measured): Shark ~3-4×, Leviathan ~3×; or scale by team DPS / player count. Decide after a sim pass.
- Check the HUD health bar, Hourglass (bosses ignore it), and chest/Coil-drop pacing still make sense.

## 2.4b Ramming (battering) feels weak; speed should matter, and speed should protect
Current (`run:822-834`, us:221-225): a battery needs speed ≥ `nature_batter_speed` (× Bow Grow Bow share). Damage = `battery_damage` 40 × (speed / batter speed)^`battery_speed_power` (default **1.0**) × (1 + Battery Damage stat). So damage already scales linearly with speed, but 40 base at roughly batter speed is tiny next to weapons (e.g. Spine Burst 32×18, Coil 220 dps/seg), and the power of 1.0 makes the speed reward gentle. Also `battery_iframes` 0.3 s and big zombies (size ≥ 1.5) absorb a share of your speed.
- Make ramming scale harder with speed: raise `battery_speed_power` (try 1.5-2.0) and/or raise `battery_damage`; consider a cap so extreme speeds can't one-shot bosses. Tune with `run_sim`/`weapon_bench` against weapon DPS so a fast ram is competitive with a mid-level weapon.
- Add impact feel: hit-stop, bigger knockback scaled by speed, shockwave ring/bubble burst and a heavier sound at high speed (FxKit + audio hooks), damage number scaled by hit.
- **Speed protection:** new damage reduction while swimming fast, e.g. `armour_from_speed`: linear ramp from 0 at batter speed up to a cap (suggest -30% damage taken at max speed; panel settings with wide ranges). Also consider brief i-frames scaling with speed (extends `battery_iframes`).
- **Item to grant it** (new chest item, proposed name **Torpedo Hide** / **Remora Slipstream** / **Dolphin Skin**; pick a name): more stacks = more speed-based damage reduction and +battery damage at speed; could also lower the batter-speed threshold. Candidate pairings: Tome of the Ram (battery_damage), Fins (swim_speed), Bow Grow Bow. Boxfish (Armoured, 0.88× speed) is the awkward fit; Swordfish Dash and String Ray Glide pair well.
- **On hold:** speed protection (item vs tome, numbers) — user is pondering it. Ramming damage/feel changes above can proceed independently.

## 2.5 Remove Rocket League / RL mentions from player-visible text
Keep: replay feature text (`replay_controls.gd`).
- `debug_panel.gd:56` (Fish detail text mentions RL cars), `:60` (Default tuning "Rocket League's").
- `setting_docs.gd` (~83 hits, generated by `tools/gen_setting_docs.gd` from `##` comments): reword the `##` doc comments in `fish_controller.gd`, `follow_camera.gd`, `ball_settings.gd`, then regenerate.
- Fish names: `display_name()` "Clownfish (Octane)" → drop car names (`fish_character.gd:15-65`); `home_screen.gd:281` caption "OCTANE body".
- Option titles derived from `rl_*` property names ("RL Roll Timing"): rename titles (prefer a title mapping over renaming properties, to avoid breaking presets).
- `presets/water.cfg` description "~2x RL speeds". README may keep history but trim the pitch.
- Code identifiers/comments untouched.

## 2.6 Mode naming: "Fish Sticks"
- New tile **Fish Sticks** (the Rocket League-style modes) containing **1v1** and **Free Play** sub-modes. Needs a sub-mode step between the picker and `start_mode()`.
- Safest: keep ids `ONE_V_ONE`/`FREE_PLAY` and the saved `[playground] mode` values; change the display/tile layer only. Touch points: `main.gd` `MODES`, `MODE_ENVIRONMENTS`, `MODE_TILES`, `_match_card_text`; `mode_picker.gd` `PRIMARY/MORE`; `hex_badge.gd` icon; `home_screen.gd:_play_note`.
- Picker then shows: Unnatural, Fish Sticks, Hunt, Nature, plus More (Obstacle Course, Test Tank).

## 2.7 Hide Replays behind a Konami code
- Remove the Replays button from home (`home_screen.gd:101`); keep the `--replay=` and file-drop paths.
- Listener in `home_screen.gd:_input` (ignored while settings/co-op/picker open). Sequence: Up Up Down Down Left Right Left Right B A B A SELECT START (B=`ui_cancel`, A=`ui_accept`; SELECT/START via raw `JOY_BUTTON_BACK`/`JOY_BUTTON_START`).
- Variations allowed: ending at A without SELECT/START; ending on A or START; keyboard equivalents (arrows, Esc/Enter, plus chosen keys for SELECT/START); rolling buffer so mistakes just restart; tolerate repeat events from `MenuNav`.
- Left/Right currently cycle the fish: let them still act while the buffer reads in parallel.
- On success: reveal Replays and play a sound. **Decided:** the unlock is saved once used (new `UISettings` key, e.g. `replays_unlocked`).

## 2.8 Deprecate and hide "Free Swim"
- Drop `FREE_SWIM` from `MORE` in `mode_picker.gd:18` only; keep the constant/`MODES`/`MODE_ENVIRONMENTS` so the ~20 probes using `set_mode(FREE_SWIM)` as "go to Ocean" still run.
- Remap a saved mode of Free Swim and the legacy `environment == "Ocean"` migration (`main.gd:266-268`) to Free Play / Unnatural.
- Update `audio_hooks4_probe.gd:50-52` if it asserts the Free Swim bed; fix comment mentions.

## 2.9 Settings clean-up + "Show Debug Tweaks"
Findings: no whole section is only RL options; the RL toggles live inside Fish (Rotation, Steering, Surface, Jump & Dodge), Ball (`rl_hit_impulse`, `kickoff_float`) and Camera (`roll_with_surface`). No shipped code or preset changes them from default, but a user preset can. Defaults are not all "enabled" (`rl_pushback_holds`, `complete_flips`, camera follow flags default false).
- Hide the enabled-by-default `rl_*` toggles from the UI and keep them at their defaults; options gated on them via `is_option_active` stay hidden. **Decided:** no testers use presets, so old-preset compatibility is not a concern: rename/remove properties and force defaults freely, and drop preset handling that only existed for compatibility. (This also lets 2.5 rename `rl_*` properties directly instead of mapping titles.)
- Standard (always visible): Game (name, fish, goal replays), Display (fullscreen), Controls (profile, rebinds), Audio (profile, music, volumes), Camera > Follow basics, Controller deadzone/sensitivity.
- Gated behind **Show Debug Tweaks** (default off): tuning presets, Stats panel, controller overlay, Sound Board/sound tools, and the rest of Camera, Fish, Ball, Nature, Unnatural, Powerups (~600 options).
- Toggle: new action `ui_debug_toggle` = `JOY_BUTTON_BACK` (SELECT) + a keyboard key (F2 candidate), registered in `controls.gd` next to the other `ui_*` actions; handled in `debug_panel.gd:_input` (SELECT is free there; only `local_coop.gd` uses it, during runs). Show a footer hint. Persist as a `UISettings` var + `KEYS` entry (`ui_settings.gd`), default false, plus `_default()` in `debug_panel.gd`.
- Apply the gate in `_refresh_visibility()` (and hide whole tabs via `_prune_tabs`).
- Not yet read: `debug_panel.gd` preset load/save (~1474-1530) and `fish_controller.gd` 870-900. Confirm before implementing.

## 2.10 Forgotten / deferred weapons and items (from `planning_unnatural.md`, `brainstorm_playability.md`)
- **Leviathan's Coil has no acquisition path** (only reachable in Test Tank); the Blood Leviathan ends the run instead of dropping it. `_offer_swap` is built but unreachable in play. Fix was P5 (`planning_unnatural.md` ~777). No direction yet on how to obtain it; since the run no longer ends at the boss (see 2.12), one natural option is a BOSS chest dropped by the Blood Leviathan (like the Shark's Drowned Fin). **Open — needs a decision.**
- **Equipment tier (§7c):** one slot, on-demand button (long-press Y or stick click undecided), long cooldown, equipment chest. Ideas: Ink Bomb, Whale Call, Bubble Net, Tide Turner, Sunken Bell. Drowned Fin is the first-Equipment candidate (D20). Phase 9, not started.
- **Evolutions (D24):** Greek Fire + Ages → Sea of Flame; Halo + Reef → Man o' War; Depth Charges + Schools → Minefield; Remora + Teeth → Lamprey Pack. No `evolves_with`/`evolved_id` field exists.
- **§7b unbuilt item ideas:**
  - Common: Kelp Wrap, Sea Salt, Coral Knuckles, Diver's Goggles, Lucky Sand Dollar, Sticky Anemone, Ink Sac
  - Uncommon: Lamprey, Sonar Pinger, Cold Seep, Treasure Map, Momentum Fin, Clam Shield, Whirlpool Charm
  - Rare: Kraken's Grasp, Ghost Swordfish, Ammonite Spiral, Riptide, Reef Guardian, Bioluminescence
  - Legendary: Poseidon's Trident, Megalodon Tooth, Moon Pearl, Abyssal Engine
  - Also: Ink Cloud, Whirlpool, Sonar Ping, Barnacle Armour (thorns), Pressure Wave, Jellyfish Familiar, team items (Cleaner Wrasse, Pilot Fish)
- **P4 limiters not built:** stacking curves, cooldown floor, area soft cap, weapon-card frequency decay, rerolls/skips/banishes.
- **P5/P6:** shrines, elite modifiers, hermit-crab shop, 3rd/4th slots, per-fish passives and unlocks, difficulty tiers, picker slow-mo.
- **Facet drafts vs build:** planned bleed (Bite), slow-on-hit (Sting), homing turn rate (Bubbles) became milestones; Greek Fire "spacing" became "density".
- **Known balance:** Halo builds lose; Greek Fire is 2-3× the others at Lv 15-20; online, the Remora heal and Anglerfish decoy only apply on the host's / dropper's machine.

## 2.11 Roadmap: a playable character for every weapon
Today 6 of 11 weapons have a fish (the 6 attacks). The 5 powerup weapons are card-only. Proposal: one fish per weapon as its starting weapon, each with a signature stat and a twist, mirroring `FishAttack.FOR_FAMILY` / `StatBlock.SIGNATURE` / `Traversal`.

| New fish (placeholder species) | Starting weapon | Signature stat (proposed) | Twist (proposed) |
|---|---|---|---|
| Lionfish / Dragonet | Greek Fire Trail | duration | Wake: stronger trail while boosting |
| Moon Jelly / Man o' War | Jellyfish Halo | area | Drift: hovers, slow but wide turn |
| Mantis / Pistol Shrimp | Depth Charges | knockback | Mine layer: drops a mine on dodge |
| Manta / Whale Shark (remora host) | Remora Buddy | pearl_chance or luck | Escort: remoras guard when idle |
| Eel / Sea Serpent | Leviathan's Coil | max_hp or regen | Slither: wide turn, longer tail |

Species are placeholders to rename.

Per-fish work (repeat pattern): `FishCharacter` entry + hitbox mapping and model (model_shots tool, koi-style loft + skins); `FishAttack.FOR_FAMILY` / `StatBlock.SIGNATURE` / `Traversal.NAMES` entries; starting-weapon wiring (powerup weapons must be seedable as the slot-1 weapon and level through the same facets/milestones); card-pool exclusion so a fish never gets its own weapon as a new-weapon card; home-screen fish picker entry; sounds; `run_sim` balance pass.

Phases: (A) allow powerup weapons as the starting weapon + data tables; (B) fish with simple models; (C) models + traversal twists one by one; (D) unlock/meta (ties to P6). The Coil fish is gated until the Coil has an acquisition path (2.10).

## 2.12 Beating the final boss no longer ends the run: the whirlpool exit
Today the Blood Leviathan's death ends the run (`run:1292-1296`).
- **Decided:** after the level's final boss dies, play continues for as long as the player wants: keep battering/frying fish and collecting loot (pearls, chests, pickups, XP/levels keep working).
- A **whirlpool** spawns where the boss died.
- Within **15 m** of it, a prompt appears: press Jump/interact to enter. (Co-op: decide whether one player entering ends it for everyone, or each player enters separately and the run completes when all alive players have — **open**.)
- **Only entering the whirlpool counts as a successful completion** (victory screen, run log, unlocks). Dying afterwards is still a loss; to decide whether a run that beat the boss but died counts as partial credit in the stats.
- Implementation notes: replace the run-end call at the Leviathan death with spawning a `Whirlpool` node; add a proximity check + prompt in `unnatural_hud.gd`; stop the director's escalation or cap it so lingering is viable (decide: does difficulty keep rising, the boss's chests drop, spawns thin out?); online peers need whirlpool spawn/enter messages in `unnatural_net.gd`; sound/FX with FxKit; bots (`survivor_bot.gd`) should enter after some linger time so `run_sim` still terminates.
- Ties into 2.10: Coil acquisition (a Leviathan boss chest is now viable).

## 2.13 Detailed post-game stat breakdown
- **Decided:** on both win and loss, the end screen shows how much damage each source dealt, per player: each fish attack, each powerup weapon, each damaging item (Chain Lightning, Torpedo, Eel, Lure, Tsunami Heart, Drowned Fin, Pufferfish reflect, etc.), batteries/ramming, Bow Grow Bow's bow wave, traversal twists (Koi splashdown), and anything else.
- Source: `run.hit(... id ...)` already takes a source id (`[id]` list, proc chain). Accumulate per-fish `damage_by_source[id] += dealt` there (after the pipeline, post-crit), plus kills per source and hits count; show raw damage, share %, and maybe DPS over time alive.
- Reuse the existing `RunLog` (run logs from the playability pass) — extend it so logs and the end screen share the data; add to `run_sim` output so balance passes can read per-weapon contribution.
- Online/co-op: host owns damage truth; sync totals to peers at run end (puppet weapons aren't simulated locally).
- Decide: overkill damage counted or clipped to remaining HP; whether to show boss damage separately.

## 2.14 Anglerfish Lure + Tome of Ages; Tides and the Reef affect all weapons
- **Lure:** `anglerfish_lure.gd` must call `duration_scale()` (decoy life 5 s; consider the drop interval left alone). Add a test in the existing probes. `DURATION_USERS` already lists it.
- **Tides (attack_speed):** apply to every powerup weapon's timing: Greek Fire patch drop rate, Halo tick rate/spin, Depth Charge drop interval, Remora nip interval, Coil tick rate, and item cooldowns that are timers (Lure drop, Drowned Fin cooldown; chance-based items stay unaffected). Hook once in the shared powerup tick/interval helper (like `duration_scale`) rather than per file; keep per-weapon facet `rate` multiplicative with it.
- **the Reef (area):** apply to every powerup weapon's size/radius: patch radius, jelly radius + orbit, mine blast + trigger radius, remora reach, Coil segment size, item AoE radii (Eel ring, Torpedo blast, Tsunami width, Pufferfish burst, Lure burst).
- Consequences to re-bench: Greek Fire is already 2-3× others at Lv 15-20 and Tides/Reef will stack onto it; rebalance with `weapon_bench`/`run_sim`. Update the tome table in 1.3 and the "Stat/tome scaling" column in 1.2 once built.
- Add an area soft cap (P4 limiter) if the combination gets out of hand.

## 2.15 Character details button (fish picker)
The user only just learned each fish has a traversal twist (passive); nothing in the UI says so. They will playtest each and expect to tweak them afterwards.
- **Decided:** the fish picker (home screen, `home_screen.gd`) gets a **Details** button (and a gamepad shortcut, Y) opening a panel for the highlighted fish: starting weapon + what it does, signature stat and step per level, twist name + description + numbers (cooldown, speed, damage), base stats (HP, i-frames, speed multiplier).
- Single source of truth: build the text from `FishAttack.FOR_FAMILY`, `StatBlock.SIGNATURE`/steps and `Traversal` data/settings, not hand-typed copy, so later twist tweaks show up automatically.
- Twist numbers stay panel settings (see "flexible tuning"), so the user can tweak them under Show Debug Tweaks (2.9).
- Also show the twist name on the picker caption so it is discoverable without opening Details.

## Implementation log (2026-10-19, in progress)
See the end of this file; entries are appended as pieces land.

## Verification (when implemented)
- Probes: audio loop probe with the tree paused; chest cancel probe (refund, no reroll, online peer); remora visual + nip-count probe; Konami buffer probe with variants; settings gating probe (default off, SELECT toggles, persists).
- Bench/sim: `weapon_bench` and `run_sim` for boss HP and new fish; `split_bench` for remora visuals in split-screen.
- Manual: build handoff; user tests the home menu (Fish Sticks, no Free Swim, no Replays button, Konami reveals it), Settings (SELECT), ambient during cards, chest cancel.
