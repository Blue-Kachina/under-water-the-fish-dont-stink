# Plan: Ember Octopus + Lantern Angler refinements (What Stinks?)

Written 2026-11-08 from the user's first look at the two new hunters (planning_new_hunters.md built them the same day).

## References (private_content/)
- `octopus_swim_style.mp4` (4.3 s; contact sheets of it were reviewed): the octopus swims **mantle first**. The arms trail behind in a
  streamlined bundle, gently undulating, tips curling. The jet is a subtle mantle squeeze, not a crown opening and closing.
- `octopus_formation.png`: arms spread flat and swept back from a broad webbed centre, like a **stealth bomber / delta wing**.
  => Movement from the video, shape from the photo: swept-back flat delta while swimming, mantle leading.
- `giant_glowing_octopus.png`: the look. Deep wine/maroon-violet wet skin, wrinkles and papillae, glow as fine sparkling
  embers/photophores under the skin with a warm gold core in the mantle (not big lava-lamp vein blobs), pale-rimmed suckers, a small
  dark slit-pupil eye under a heavy brow. Realistic and menacing, not cartoony.
- `angler_fish_side_profile.png`: the angler's **longer body**: big head but a real fish body tapering to a fanned tail; dorsal spines,
  pectoral fan, many photophore dots.
- `lit_angler_fish.png`: the look. Gnarly, wrinkled, rough pale-highlighted skin, ragged hair-like fin filaments, glassy needle teeth.

## User decisions (2026-11-08)
1. Octopus swim: mantle-first like the video, arms trailing in the photo's delta shape. No open/close crown pulsing.
2. New octopus attack, replacing the Tendril Lash ("whip" style):
   - **Press:** one tentacle shoots out and attaches to the nearest fish in reach (school fish or prey player).
   - **Hold:** the octopus is towed behind the grabbed fish (it does NOT slow or impede the fish). While held, more free tentacles
     grab more fish that are close enough (the school). Grabbing stops when out of tentacles (8) or on release.
   - **Release:** every attached tentacle reels in and all held fish are eaten at once (beak snap). (User pick: eat on release.)
   - Prey players CAN be grabbed; a **dash (or hard counter-steer) tears the tentacle off** (user pick, like the lure's resist).
3. Fix tentacles looking detached from the body.
4. Octopus model more realistic and menacing (giant_glowing_octopus.png).
5. Angler: longer body (side profile), realistic yet gnarly (lit_angler_fish.png), fins as shader membranes (rays, translucency,
   ragged edges, flutter) instead of flat basic geometry.

## Work split (workers own disjoint files)
| Worker | Owns |
|---|---|
| A angler | angler_model.gd, shaders/angler_skin.gdshader (+ new angler fin shader), lantern_rig.gd/angler_jaw if the shape change needs it, lantern_angler.gd sheet, angler_* tests, angler_contract.md |
| B octopus body | octopus_model.gd, shaders/octopus_skin.gdshader, octopus_rig.gd, ember_octopus.gd, octopus_model/gait/roll/form tests + shots, octopus_contract.md |
| C grapple attack | new attacks/grapple_attack.gd (style "grapple"), HunterAttack.STYLES, octopus_whip_fx.gd (or a new grapple fx), prey-side break-free, bot plan, net sync, HUD cue, settings + setting_docs for the attack, new grapple probe |
| Orchestrator | regression suite, INVENTORY.md / hunter_forms.md tables, build |

### Contract between B and C
- Bone layout is unchanged: 8 arms x 14 bones, same indices, `arm_bones[arm][seg]`, `set_arm_pose`, `arm_joints`, `arm_rest_joints`,
  `arm_tip_global`, `arm_length`, `mouth_local`, `WhipAttack.Solver` (joints -> bends) keeps working.
- Model space after B: **-Z is still the travel direction, but the mantle now leads** (mantle tip at -Z) and the arms rest trailing
  behind along +Z in a flat, swept-back delta. `mouth_local()` stays the beak at the arms' junction (now on the underside/behind the head).
- The rig exposes the gait's own arm joints (`gait_provider`-style `Callable(arm) -> PackedVector3Array`) and keeps `blend_pose()`
  support: a driven arm (attack) overrides the gait for that arm with a weight. C must not edit octopus_rig.gd; hooks it needs go in
  C's log and the orchestrator (or B) adds them.
- Towing is done by C on the hunter's FishController (velocity/position steering each physics tick), not inside the rig.

## Gates
- A: angler_model_probe, angler_form_probe, angler_roll_probe, angler_match_probe, lure_pull_probe green; angler_shots reviewed vs references.
- B: octopus_model_probe, octopus_gait_probe, octopus_roll_probe, octopus_form_probe green (updated for the new axes); shots + gait sheets reviewed.
- C: new grapple_probe (press grabs nearest, hold grabs more up to 8, tow does not slow the fish, release eats all, dash breaks free,
  bot uses it); octopus_match_probe green.
- All: hunter_forms_probe, mode_setup_probe, preview_jitter_probe (`--fixed-fps 144`); then build.

## Progress log
- 2026-11-08: plan written, workers A/B/C started.
- 2026-11-08: stopped early for a handoff to another login (token budget). Workers were told to finish their current edit and write
  their state to `logs/hunter_refine/A-angler.md`, `B-octopus-body.md`, `C-grapple.md`.

## HANDOFF (read this first in a new session)
**State at shutdown (2026-11-08 ~14:00):** A (angler) finished, all probes green, log `logs/hunter_refine/A-angler.md`.
B and C were force-stopped BEFORE writing their logs (B-octopus-body.md / C-grapple.md do not exist). Their work is on disk only,
state unknown and possibly mid-edit:
- B touched: octopus_model.gd, octopus_rig.gd, ember_octopus.gd, octopus_contract.md, shaders/octopus_skin.gdshader, tests
  octopus_form_probe / octopus_gait_probe / octopus_gait_shots / octopus_model_probe / octopus_model_shots (`git diff` these; they
  were committed at bdf53fb, so the diff is exactly B's work). Shots it made: logs/hunter_refine/octopus/.
- C added: scripts/what_stinks/attacks/grapple_attack.gd, scripts/what_stinks/forms/octopus_grapple_fx.gd, tests/grapple_probe.gd/.tscn;
  shots in logs/hunter_refine/grapple/. Check `git diff` of hunter_attack.gd (STYLES), what_stinks_settings.gd, setting_docs.gd,
  what_stinks_prey_bot.gd, what_stinks_net.gd, what_stinks_hud.gd, sound_catalog.gd for its registrations (those files also carry
  earlier uncommitted work, so compare against the plan, not just the diff).
- First step: `--headless --path . --import` to find parse errors, then review B's diff and shots, then C's.

1. Read the three worker logs above. Each says what is done, half-done and next. Code may be mid-rework; run
   `Godot_console.exe --headless --path . --import` first (prints parse errors; new class_names need it).
2. Resume each worker's next steps (they are independent; B and C share the contract above). Reference frames from the video were in
   a temp scratchpad that will not survive: regenerate with OpenCV via `uv run --no-project --with opencv-python-headless python -I <script>`
   (read frames every ~0.17 s from private_content/octopus_swim_style.mp4, tile into contact sheets). "Before" shots can be regenerated
   from `git stash`-free means: `git archive HEAD` into a temp dir (see memory probe-running-tips) and run the shot tools there.
3. Orchestrator steps still to do after the workers: set `ATTACK := "grapple"` in `scripts/what_stinks/forms/ember_octopus.gd` (once
   GrappleAttack is registered in HunterAttack.STYLES), add any rig hooks C's log asks for in octopus_rig.gd, update INVENTORY.md and
   hunter_forms.md (octopus attack + any sheet changes, angler sheet), run gates (above) + hunter_forms_probe (900 s timeout),
   mode_setup_probe, preview_jitter_probe (`--fixed-fps 144`), then build: `--export-debug "Windows Desktop"
   D:/Dev/GameDev/under-water-the-fish-dont-stink/builds/windows/FishPlayground.exe` (absolute path). Hand off for the user's play-test;
   no git actions (the user does all git).

## Progress log, session 2 (2026-11-08)
- `--import` clean. B's body and C's grapple were both on disk and working: octopus_model/gait/roll/form probes and grapple_probe (62) green.
- Set `ATTACK := "grapple"` in ember_octopus.gd; ported `octopus_match_probe` to GrappleAttack (also fixed its net section: wait for the bot's bite to end before `net_open`); added the 33 missing `grapple_*` lines to setting_docs.gd (the probe caught them missing).
- Gates green: angler_model/form/roll/lure_pull, mode_setup, preview_jitter (144 fps), hunter_forms_probe (1020). angler_match_probe failed its puppet-bite checks once and passed on rerun (flake).
- hunter_forms.md and INVENTORY.md updated. Still to do: final regression of changed files, build, and the user's play-test (B/C screenshots not yet reviewed by eye).

## Strides pass (2026-11-08, after the user's first play-test: "huge improvement")
User asks: octopus pulse on the player's input once striding (free beat before), Battletoads exaggeration on strides, speed tightens the trailing arms; angler tail on the player's rhythm with stride exaggeration.
- Built: octopus_rig.gd `_stride_shape` (stride = jet on its own clock), `_step_pop` (mantle pop spring), `octopus_speed_tuck` in `_solve_arms`; octopus_model.gd `set_mantle_pop`; lantern_rig.gd `_gait_stride` / `_on_strode` (tail follows `tail_swing`, ring spring, flick, flow swell); `tail_grow` uniform in angler_pose.gdshaderinc + AnglerModel.tail_grow; 5 settings + docs; tests/stride_forms_probe (26 checks).
- Interpretation to confirm on play-test: "the expansion part of the pulse" = the mantle swelling (inflate) now lands on the stride input, the squeeze/thrust on the stride's peak.
- Puppets (online) do not run strides (swishy is not sampled for them), so other machines' hunters keep the free beat/sway.
