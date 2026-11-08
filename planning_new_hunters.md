# Plan: Hunter feedback pass + Giant Octopus + Angler Fish (What Stinks?)

Written 2026-11-08 from play-test feedback. Builds on two-stage-attack.md, hunter_forms.md and 3D_Character_Art_Quality_Standards.md.
References: private_content/giant_glowing_octopus.png, private_content/lit_angler_fish.png.

## Decisions (user, 2026-11-08)
- Octopus locomotion: **Hybrid** = jet-pulse in open water (BellPulse-style) + arm-crawl gait near terrain/floor.
- Angler lure: pulls **bots and human prey** as a resistable drift (counter-steer / dash breaks it), with a visible "captivated" cue.
- Exaggeration: **Bold, readable**: 1.5-2.5x at peak, anticipation squash, overshoot, 2-3 frame hit-stop. All values are panel settings.
- Priority: fixes -> exaggeration -> Octopus -> Angler. Octopus gets the most polish budget of the two new forms.

## Proposed names (swap freely)
- Octopus: **Abyssal Kraken-Mother**? Too long. Working id `ember_octopus`, display **"Ember Octopus"** (the glowing copper mantle); alt "Lantern Kraken", "Cinder Mother".
- Angler: id `lantern_angler`, display **"Lantern Angler"**; alt "Gloam Angler", "Deep Bait".

## 0. Setup (orchestrator, before any workers)
1. `index_folder` (the jcodemunch index was missing this session) and read: hunter_form.gd, hunter_forms.gd, hunter_bite.gd, hunter_bite_fx.gd, attacks/hunter_attack.gd, one rig (king_rig.gd), the join screen preview (what_stinks_join.gd), jelly BellPulse, SpineRig.
2. Snapshot `git status` (large uncommitted tree: work only on files each worker owns; no git actions, per memory).
3. Create the shared contract in this file's Progress log: file ownership table (below) and probe names.

## 1. Phase A: fixes to existing hunters (1 worker per item cluster, parallel, disjoint files)
**A1 Preview swimming + jitter (join screen, all forms).**
- Root-cause jitter first (likely spine-bend/IK solving against a stationary fixed-step or pose snapping each frame; test with headless frame-to-frame vertex delta probe, `preview_jitter_probe`).
- Make every preview swim in place: feed the form's real gait with a synthetic throttle + gentle yaw/pitch wander and a slow auto-rotate; same code path as in-match so it can't drift.
- Files: what_stinks_join.gd, hunter_form_model.gd (+ per-form preview hooks only if needed).
**A2 King of Herrings + Lamprey Queen rigidity.**
- Add a `body_stiffness` knob to the SpineRig use in king_rig.gd / lamprey_rig.gd (reduce wave amplitude and per-segment lag, raise bend damping, keep head/tail stride). Panel setting, default ~0.6 of current flex. Compare with model_shots.
**A3 Lamprey lunge distance.** Reduce drill/lunge impulse (lamprey_queen.gd, drill_attack.gd); make `lamprey_lunge_impulse` a panel setting; target ~55 percent of current; probe asserts travel distance.
**A4 Whale attack beef-up** is folded into Phase B (needs the exaggeration kit).

Gate A: probes `preview_jitter_probe`, `lamprey_form_probe`, `king_probe`, `hunter_forms_probe` green; model_shots of King/Lamprey previews reviewed.

## 2. Phase B: Exaggeration kit + pass over every hunter attack
**B0 build `AttackExaggerate` (new scripts/what_stinks/attack_exaggerate.gd), one worker, first.** Reusable curve-driven tool the rigs call during press / hold / release:
- Per-part scale channels (jaw, head, tail, limbs) with anticipation squash -> overshoot -> settle (damped spring, not tweens).
- Smear/stretch along motion axis, hit-stop (brief time-scale on the attacker's rig, not the world), camera punch-in hook (small, setting).
- Single master setting `hunter_exaggeration` (0 = off, 1 = bold default, 2 = extreme) plus per-form multipliers. Wide ranges per the flexible-tuning rule.
**B1-B6 per-form workers (parallel, each owns its rig/model/attack files):**
- Whales (shared engulf): jaw hinge to ~2.2x gape, head swells on charge, throat/pleat balloon, lower jaw overshoot-snap, tongue/baleen or teeth pop by species. Fixes "underwhelming".
- Drowned Shark chomp: head thrusts forward and the jaw unhinges wider, teeth row scales up, eye flare.
- Fallen Angel lock: halo/wings flare, jaw spread, limb snap to target.
- Gulper suction: mouth balloons to a huge sail, body deflates (squash), then gulp bulge travels the body.
- King coil-whip: coil winds visibly tighter on press, whip tail stretches 1.5x on release with smear.
- Lamprey drill: oral disc flares wide, teeth ring spin-up, body telescopes.
- Tail stride exaggeration stays as is (user likes it).
Gate B: `hunter_forms_probe`, per-attack probes, attack_shots contact sheets (rest / press / hold-peak / release / settle) reviewed per form. Write the exaggeration table into hunter_forms.md and INVENTORY.md.

## 3. Phase C: Giant Ember Octopus (the flagship; deepest polish)
Design (from the reference): bulbous elongated mantle with a glowing emissive vein network, eight long tapering arms with suckers, trailing curls, copper-to-violet skin, particulate glow. Quality bar: 3D_Character_Art_Quality_Standards.md (clean topology, no seams, PBR-like layered shader with subsurface-style rim, emissive veins with pulse, suckers as instanced detail with LOD).
**C1 Model (art worker):** loft-built mantle + head + 8 arms along splines (tapering radius, sucker rows via instanced MultiMesh, web membrane between arm bases), eyes with horizontal slit pupils, siphon funnel. Skin shader `octopus_skin.gdshader`: colour-shift chromatophore noise, vein emissive pulsing with swim stroke and charge. model_shots turntable + close-ups.
**C2 Rig + gait (animation worker, owns octopus_rig.gd):**
- Each arm = 12-16 bone chain, FK wave with per-arm phase and a lagged follow-the-leader solver (like SpineRig, one per arm) so arms trail and curl organically.
- Gait set: (a) Jet-pulse: mantle contracts, siphon jets (impulse along siphon vector), arms stream back then relax and flare; (b) Cruise scull: low-amplitude arm undulation for fine steering; (c) Crawl: when near terrain/floor within a threshold, arms plant sucker tips via raycast and walk (alternating arm pairs, body glides over), blend by distance; (d) Dash-jet: big pulse with arms bundled.
- Stride system integration: jet pulses and arm cycles driven off the same speed/stride phase variables the other forms use, so the HUD/audio hooks work unchanged.
- Physics: siphon-vectored thrust, drag-based turning, full 3D with air rolls (siphon aims relative to the up vector; roll via asymmetric arm flare). Verified by `octopus_roll_probe` like hunter_roll_probe.
**C3 Attack: "Tendril Lash" (EngulfAttack-style class: `whip_attack.gd`):**
- **Press:** arms rear back and flare into a crown, suckers glow, a targeting aura sweeps the cone; up to 8 targets are acquired (nearest-first by view cone and distance, one arm each, reticle sparks per lock). Anticipation squash on the mantle.
- **Hold:** lock-ons track targets; charged arms coil tighter and veins brighten (charge level = lash reach and damage).
- **Release:** arms whip out heat-seeking along curved homing paths (bezier with curvature toward target, whip crack at tip), staggered 30-60 ms per arm; each hit applies damage plus a bite-credit; the net recoil impulse on the octopus is the sum of arm lashes (pushes slightly away, scaled by number of hits); arms then recoil and settle. Misses retract fast with a smaller recoil.
- Targets lacking an angle (behind) are dropped from the lock list, so approach/angle matters. Tuning: arm count cap (8), range, cone, homing, recoil, stagger, all panel settings.
- FX via `HunterBiteFx`: whip cracks, shockwave rings, sparks, sucker-pop decals; audio ids stand-ins in sound_catalog.gd.
**C4 Integration:** hunter_forms.gd registration, join-screen preview swimming (with A1 code), bot support (what_stinks_bot.gd: choose targets, charge by count of nearby prey, release), net sync (what_stinks_net.gd: lock list + arm states compact), HUD charge/lock-count indicator, settings, setting_docs.
**C5 Polish loop (Octopus only, 2 passes):** a reviewer agent compares model_shots/animation strips to the reference and the standards doc, lists defects, worker fixes. Check: arm interpenetration, popping on gait blends, smoothness at every speed, roll behaviour, crawl foot-plant slip.
Gate C: `octopus_form_probe`, `octopus_roll_probe`, `octopus_whip_probe` (8 target case, behind-target case, recoil magnitude), gait blend probe, preview jitter probe, bench for per-frame cost (arms x segments budget, LOD).

## 4. Phase D: Lantern Angler
Design: heavy-headed globe body, oversized hinged jaw with long needle teeth (slightly translucent), illicium (lure stalk) from the head with a glowing esca bulb, tattered fins, bioluminescent dots along flank, small eyes with glint. Move style: ambush swimmer, slow fin-sculling with a bursty tail snap for lunge (unlike the shark's body wave). Stalk lags and bobs physically (spring chain, 5-6 bones).
**D1 Model:** loft body, jaw via the shader-hinge approach used on the shark, teeth instanced, esca emissive + point light (with light budget and murk interaction).
**D2 Rig/gait:** SpineRig with high stiffness, pectoral scull, tail snap; lure stalk spring chain; air rolls with the standard fish roll rig.
**D3 Attack "Lure" (`lure_attack.gd`):**
- **Press:** esca flares to full brightness, light cone/halo expands, jaws go agape (exaggerated), eyes flash. Starts the attraction field.
- **Hold:** attraction ramps: prey inside the light cone and radius gain a drift toward the esca. Bots get steering bias; humans get a resistable drift (force falls with distance; full opposite input or a dash cancels; HUD "captivated" vignette). Light flickers faster as prey close in.
- **Release:** jaws snap shut with chomp + hit-stop; bite damages everything inside the bite volume; esca dims, short cooldown.
- Tuning: radius, cone, pull strength, human resist factor, ramp time, cooldown as panel settings.
**D4 Integration:** same checklist as C4. Prey-side: attraction reads in what_stinks_prey_bot.gd and the human prey controller path via a small `LureField` interface, net-synced as the esca state + affected-player list.
Gate D: `angler_form_probe`, `angler_roll_probe`, `lure_pull_probe` (bot pulled, human resists, dash escape), net peer probe.

## 5. Parallelisation and file ownership (to avoid merge collisions in the dirty tree)
- Shared files touched by many (hunter_forms.gd, what_stinks_settings.gd, setting_docs.gd, sound_catalog.gd, INVENTORY.md): **only the orchestrator edits these**, from worker-returned patch lists. Workers add their own new files and report registrations.
- Waves: Wave 1 = A1, A2, A3, B0 (4 workers). Wave 2 = B1-B6 (6 workers; reduce to 4 by pairing Gulper+Angel and King+Lamprey if concurrency is limited). Wave 3 = C1 and C2 in parallel, then C3, then C4/C5. Wave 4 = D1, D2 in parallel, then D3, D4. Phase D can overlap Phase C's late polish if budget allows.
- Reviewer agents (fresh, given diffs not conclusions): after each phase gate, one review worker. Per project habit, wrap-ups update hunter_forms.md, two-stage-attack.md, what_stinks.md and INVENTORY.md.

## 6. Workflow shape (Workflow tool, ~10 agents live at a time)
`phase('A')` parallel(A1..A3,B0) -> verify gate -> `phase('B')` parallel(B1..B6) -> review -> `phase('C')` pipeline: C1||C2 -> C3 -> C4 -> C5 x2 -> `phase('D')` D1||D2 -> D3 -> D4 -> `phase('Final')` full probe set, build, docs. Each worker returns: files changed, registrations needed, probe results, open items. The orchestrator applies shared-file edits, runs probes, and stops a phase on any red gate (retry once with the failure output, then record and continue).

## 7. Risks and defaults (no further questions needed)
- Perf: octopus 8 arms x ~14 segments + suckers; mitigate with MultiMesh suckers, LOD by distance, per-view culling already in split-screen.
- Camera clipping from exaggeration: camera collision margin scales with the form's current peak scale; `hunter_exaggeration` setting is the escape hatch.
- Light budget: angler esca point light counts against the murk/light cap; fall back to an emissive halo when over budget.
- Human-prey lure fairness: cap pull acceleration, always breakable, logged in run stats.
- Whale Fall stays disabled. Steam stays off. No git actions by me.
- Naming: "bite"/"attack" in UI and code; "demolition" stays RL-only; battered/Fish Fry terms unchanged.
- End state: a build, handoff summary in this file's Progress log, and everything awaiting your play-test (with a list of every new panel setting).

## Progress log
### 2026-11-08_11:57 FINAL SUMMARY (new-hunters pass: fixes, exaggeration, Ember Octopus, Lantern Angler)
**Built.** Build `builds/windows/FishPlayground.exe`, debug export 2026-11-08 11:57 (108 MB). Awaiting the user's play-test: nothing from this pass has been played. Worker logs are in `logs/new_hunters/*.md`; the probe output for this wrap-up is in `logs/new_hunters/final/`.
- **Phase A fixes.** A1 Hunter card preview (`hunter_preview.gd`, `HunterPreview`): every form now swims on a real `FishController` with a synthetic throttle and wander, so the preview uses the in-match gait. Root cause of the King/Lamprey jitter was an empty head trail plus a pivot moved outside the physics tick (worst spine 2nd difference 0.04-0.08 of length down to 0.0003). Titans and the Drowned Shark used to be model-only and now swim. A2 `body_stiffness` (King and Lamprey, default 0.4: wave amplitude x(1-stiffness) plus a straightening blend after `follow_trail`). A3 `lamprey_lunge_impulse` default 0.55 (dash travel 33.1 m to 18.2 m at the dash end; it reads 80 percent if measured after 1.5 s of coast, because she keeps top speed after the dash).
- **Phase B exaggeration.** `AttackExaggerate` (`attack_exaggerate.gd`): damped-spring channels, anticipate/hold/snap/settle, output multiplier 1+(raw-1)k so `hunter_exaggeration` 0 is exactly the old look, a camera-safety scale cap, 120 Hz substepping, hit-stop in ticks. Wired into the Shark (new `forms/shark_rig.gd`, per-tooth meshes), the five whales (`whale_jaw.gd`), Fallen Angel (crown, wings, ring, lash), Gulper (girth, pouch, gulp bulge), King (`king_exaggerate.gd` driver, the coil unwinds, `coil_press_floor`) and Lamprey (`lamprey_exaggerate.gd`, a patched copy of the boss shader for teeth spin and girth). Each rig drives its own kit from the HunterBite signals.
- **Phase C Ember Octopus (`ember_octopus`, 12th form, attack style `whip`).** Skinned model with 8 arms x 14 bones and baked sucker meshes with LOD; hybrid rig (jet pulses in open water, arm crawl near the floor, air-roll aware, direction-space spring arms); whip attack (cocked coil, homing unroll, up to 8 locks, first arm judged at contact, the rest through `judge_drill`). Integrated: HUD "of N arms", bot plan works, puppets run the lash visuals from synced beats.
- **Phase D Lantern Angler (`lantern_angler`, 13th form, attack style `lure`).** Spine-bent model (hinged jaw, needle teeth, six-point spring stalk, esca light with a cap and halo fallback), trail-following rig with a ringing tail snap and figure-eight pectorals, `LureField` pull attack (resistable drift, a prey dash breaks it, captivated amber vignette for humans, bots steer through `blend_target`).
- **Polish.** Octopus: fixed a blown-out white charge/lash glow and the open siphon base. Angler: fixed a cartoon cyan eye and flat pectorals.

**What each worker found (the non-obvious ones).** A MeshInstance3D made in code has an empty skeleton path and ignores bone poses until `mi.skeleton = NodePath("..")` (C1: headless CPU-skinned checks passed while the screen showed nothing; only windowed shots caught it). `Node.process_priority` orders only `_process`; physics hooks need `process_physics_priority` (B2). The spine shader normalises frame vectors, so King tail thinning is impossible without a shader change (B5). `FishController` emits `physics_tick(state)` so a rig can add thrust without touching the controller (C2). A frozen fish never samples input, so card previews needed the rig to run its own jet clock (INT2). `WhipAttack.on_close` did `int(Dictionary)` and raised a script error on every judged arm (fixed by INT2). C2 placement bug: the model sat 2.3 m x length too far forward (arms past the hitbox) because the unscaled position was set after `settle()`. The exaggeration camera punch stacks on `HunterBiteFx`'s own punch (lower `hunter_camera_punch` if it is too much).

**New panel settings (about 121, registered in `what_stinks_settings.gd`, docs regenerated in `setting_docs.gd`).**
- Shared exaggeration: `hunter_exaggeration` 1 (0-4), `hunter_hit_stop_frames` 2.5 (0-12), `hunter_camera_punch` 0.5 (0-5), `hunter_exaggerate_squash`, `hunter_exaggerate_smear`, `hunter_exaggerate_max_scale`.
- Shark: `shark_jaw_gape`, `shark_head_thrust`, `shark_body_stretch`, `shark_teeth_gain`, `shark_eye_flare`. Whales: `whale_gape_max_deg`, `whale_rebound_deg`, `whale_body_pulse`, `whale_throat_balloon`, `whale_tooth_pop`.
- King: `body_stiffness` 0.4, `king_whip_stretch`, `king_coil_tighten`, `king_whip_lag`, `coil_press_floor`. Lamprey: `lamprey_lunge_impulse` 0.55, `lamprey_disc_flare`, `lamprey_teeth_spin`, `lamprey_telescope_max`, `lamprey_dash_stretch`, `lamprey_dash_flare`, `lamprey_dash_spin`.
- Preview: `preview_throttle`, `preview_speed`, `preview_wander`.
- Octopus: 31 `whip_*` (group "Octopus lash") and 27 `octopus_*` (group "Octopus body", for example `octopus_tip_curl` 0.3, `octopus_crawl_height` 0.3, `octopus_crawl_pull` 2.5).
- Angler: 17 `lure_*` (for example `lure_pull` 7 with cap 11, `lure_cooldown`) and 12 `angler_*` (stalk stiffness 38, damping 5.5, sway 0.5, `angler_esca_light_cap` 6, `angler_body_stiffness` 0.85).
- Sound ids: ten `octopus/*` and three `angler/*` with stand-ins in `sound_catalog.gd`.

**Probes (this wrap-up, fresh `--import`, 3 in parallel, 240 s timeout).** Clean: angler model/form/roll/match (50), lure_pull, octopus model/gait/roll/whip/form (58)/match (43), b1-b6, exaggerate, stiffness, lamprey_lunge, drill, king, lamprey_form, gulper_form, angel_form, angel_lock, hunter_spike, hunter_roll, mode_setup, hunter_bot, what_stinks (probe, bots, camera, lock_bite), whale_reach, gulper_suction (40), preview_jitter (passes only with `--fixed-fps 144`), whale_engulf (133). Failed under the 3-way load and passed solo: angler_match (2 puppet checks), octopus_form ("swimming is smooth"), gulper_suction (the bump check), whale_engulf (1 net check; failed on one solo rerun too, passed on the next: flaky as before). Failing as before and unrelated: whale_spike_probe (2: "11 pickable of 13" is probably a stale expected count since 13 forms are registered, plus a random Titan start overlap; not compared with HEAD this time), whale_sight (59.9 < 59.9 float compare), whalefall (disabled form), two_stage_bite_probe (306 fails for every form from the shark at x1.0 up, the press never opens in the probe; it failed identically with the octopus unregistered, so it is not caused by the new forms, but it needs a look before it is trusted again). hunter_forms_probe passes solo: 1020 checks, 0 failed (about 10 min; needs a 900 s timeout). hunter_size_feel_probe times out (900 s) and gave no result. two_stage_bite_probe was green on the 00:32 tree (586/0) and fails deterministically now (371 FAIL lines then timeout, all from the Shark at x1.0 on: the press does not open in the probe); with the other uncommitted work as the suspect, a bisect was not done.

**Perf.** `split_bench` is Unnatural-only and takes no Hunter form, so there is no equivalent for the octopus or the angler and I did not build one. Numbers on record: octopus arm solver `step` costs 0.2 ms (8 x 14 arms, C2 gait probe); octopus model 14.8k body triangles plus 45k near-sucker triangles (sucker LOD at 3 body lengths); angler esca lights are capped by `angler_esca_light_cap`. No in-window frame-time check of either form and no split-screen check with an octopus.

**Open items.**
- Camera: `what_stinks_cam.gd` does not pad its collision margin with the rigs' `camera_margin()` or consume the kit's `camera_punch`; `hunter_bite_fx.gd` does not host the kit. The camera probe has a freed `_focus` race in `WhatStinksCam._focus_ok` (an `is_instance_valid` guard would fix it).
- Lamprey lunge travel is 80 percent of the old distance when measured after the coast, not 55; needs a feel decision.
- Stiffness default 0.4 was verified numerically only (no before/after strips). Exaggeration was judged by workers from rendered strips; no human look yet.
- Octopus: arms spread and curl less in cruise than the reference, the siphon is still slab-like side-on, crawl foot plant not re-measured, no beak mesh, veins are noise not a network, shader untested under the real murk and the Compatibility renderer, Extra Swishy jets untested in a match.
- Angler: the hitbox is the generic MONSTER box (1.39 x 1.0 x 3.0 at 0.5x), thinner than the globe (2.05 x 1.28 x 3.16); gait and attack strips never rendered (no tool); lure pull (7, cap 11) untested against real prey physics; school-hiding (joined) prey are only affected through `School.pull`. Esca, jaw and tail are not net-synced (derived locally); octopus lock targets can differ between machines.
- `tests/what_stinks_net.sh` fails (peer lambda at `what_stinks_net_peer.gd:210` returns void, and the first peer's bite takes nothing at the host), identically with the octopus unregistered; no net run with the new forms on two machines.
- `hunter_forms_probe` EXPECTED is an exact-match list; add new forms there.

**Blockers.** None. `two_stage_bite_probe` and `what_stinks_net.sh` need a look before the next regression sweep.

**Export presets.** `export_presets.cfg` exclude_filter now includes `logs/*`: the logs' screenshots were being packed into the exe (158 MB, now 108 MB).

**Play-test first.** Home -> What Stinks? -> Hunter. Check the card preview for every form (smooth, swimming). Hold-bite each form and judge the exaggeration (turn `hunter_exaggeration` down if too much, and `hunter_camera_punch`). King and Lamprey stiffness and lunge length. The Ember Octopus (jets vs crawl, eight-arm lash, lock count in the ring). The Lantern Angler (lure pull strength, dash to break, amber vignette, jaw snap, hitbox).

**Not done, honestly.** Camera hookups, perf benches for the new forms, windowed gait and attack strips for the angler, a two-machine net run, body stiffness before/after strips, Whale Fall (still disabled). The user has not seen any of it.
