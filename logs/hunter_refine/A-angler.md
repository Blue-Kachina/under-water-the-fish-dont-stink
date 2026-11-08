# Worker A: Lantern Angler realism pass (2026-11-08)

Plan: planning_hunter_refine.md, row A. I did not touch any octopus, whip or grapple files.

## What changed
- `scripts/what_stinks/forms/angler_model.gd`
  - **Longer body.** `DESIGN_LENGTH` 6 -> 7.5 (k = length / 7.5). In design metres the head is unchanged. Behind the gill there is now
    a real fish body: the SKULL_TOP/BOTTOM/WIDTH curves taper to a narrow, laterally flattened peduncle at z 6.0, and the loft closes at
    `BODY_END` 6.25. The caudal fan runs from 5.95 to 7.5. The belly under the jaw's back end is a little deeper so the jaw no longer
    hangs below it as a pod. Loft is 260 x 80 (was 210 x 64), the cross-section eases toward an oval down the body.
  - Geometric breakup: a gill-cover rim, loose skin folds round the body, warty knobs in the outline, 16 head and mane tufts (the old
    fin-edge tube tufts are gone; the shader draws filaments now).
  - **Fins are their own mesh** (`fin_node`, third draw call, alpha-blended, no shadow). Plain membranes: spiny first dorsal (z 1.95-3.35,
    tall raked spines), soft dorsal (4.25-5.9), anal (4.5-5.9), caudal fan, and two pectoral fans behind the gill. Ids are `FIN_*` consts.
  - Thinner needle teeth (radius about 0.65x).
  - New consts `TAIL_FROM` 3.9 and `PECT_ROOT` (1.5, -0.25, 2.8). `_skins()` now covers body, teeth and fins (pose channels).
    `_body_skins()` covers the two skin copies (jaw hinge, esca, stalk).
  - New API: `fin_skin`, `fin_node`, `rest_aabb()` (bounds of all three meshes), `mesh_stats()["fin_vertices"]`.
- `shaders/angler_fin.gdshader` (new). Everything about the fins is drawn here:
  - jointed rays as bump ridges that taper to a point;
  - a translucent web (alpha, backlight, edge sheen) torn back between the rays to a chewed, ragged edge, with holes and splits;
  - rays that carry on past the web as hair-like filaments, some fraying into a second, wandering strand;
  - a few photophores on the rays.
  - Each fin ripples along its normal out to the tips, driven by `fin_flutter` through the existing `flutter` uniform. Per-fin ray counts are in `fin_spec()`.
  - Lines thinner than a pixel fade out instead of breaking into dots.
- `shaders/angler_pose.gdshaderinc` (new): the tail snap and pectoral hinge, shared by the skin and fin shaders. They were in
  angler_skin before.
- `shaders/angler_skin.gdshader`:
  - The old fin branch is gone. Wrinkles are now lines along the face (parallel to the lips and brow) and round the body, over a
    coarse fold network. Crests are pale and creases dark.
  - Warty knobs at two scales with pale tips.
  - The skin is matte: clearcoat is 0.1 and off on the warts. The first try made the warts glossy bubbles.
  - Photophores are denser, smaller and scattered all over, plus the lateral row. Teeth are more transparent (alpha 0.85 to 0.15).
- `scripts/what_stinks/forms/lantern_angler.gd`: **sheet `length_m` 6.0 -> 7.0** (the head is about 7 % smaller than before; it would
  have been 20 % smaller at 6 m). The comment is updated. `lantern_rig.gd` and the jaw wrapper needed no change: the mouth offset comes from
  `mouth_rest()` and the hitbox length.
- `tests/angler_shots.gd`: builds at 7 m, frames for it, new `side_profile` shot (compare to angler_fish_side_profile.png) and
  `fins_caudal`, `fins_dorsal`, `fins_pectoral` close-ups.
- Probe updates. Each one is needed because of the new shape:
  - `angler_model_probe`: k = length / DESIGN_LENGTH. 3 rig instances (fins). 6 mesh nodes after a rebuild. Length checks use `rest_aabb()`
    because the caudal fan is in the fin mesh. The jaw section builds at DESIGN_LENGTH so its hinge maths stays at k 1.
  - `angler_form_probe`: the model-length check uses `rest_aabb()`.
- Docs: `angler_contract.md` (space/scale, proportions, fins section, API rows, budget, refine note), angler rows of `INVENTORY.md`
  and `hunter_forms.md` (7 m, fin shader).

## Shots (logs/hunter_refine/angler/)
- Before: the scratchpad `before_angler/` set (globe with comb fins).
- Final set: `after/`. Best ones to compare:
  - `after/side_profile.png` against the side-profile reference: big head, real tapering body, fanned caudal, spiny dorsal, photophores;
  - `after/turn_2.png`, `after/open_16_side.png` (gnarly open jaw);
  - `after/fins_caudal.png`, `after/fins_pectoral.png` (membranes with torn web and filaments);
  - `after/close_head_closed.png` (wrinkle lines and warts).
- Iterations: `v1/` (first long body; fins were dark combs and the warts looked like glossy bubbles), `v2/` (thicker, fewer rays; matte
  skin), `v3/` (tapered rays, web sheen, face wrinkle lines, thinner teeth), then `after/`.

## Probes (solo runs, all green)
| Probe | Result |
|---|---|
| angler_model_probe | 82 checks, 0 failed (34,349 verts body + teeth + fins, 66.8k tris, 54 teeth) |
| angler_form_probe | 85 / 0 failed |
| angler_roll_probe | 52 / 0 failed |
| angler_match_probe | 50, all passed |
| lure_pull_probe | 66 / 0 failed |
| hunter_forms_probe (for the sheet change) | 1020 / 0 failed |

## Open issues
- Between the spiny dorsal's spines, faint dotted strands still show in close-ups (`after/fins_dorsal.png`). You can't see them at game distance.
- The lower jaw's back end still shows as a separate rounded lobe under the cheek in pure side view. This was there before the pass
  and is less obvious now.
- From the top (`after/tail_snap_top.png`) the pectorals lie close to the body and read small. They might want `angler_pectoral_deg` or a
  longer fan after a play-test.
- `lantern_rig.gd` still scales its burst threshold and still-speed by `length / 6.0`. At 7 m both are about 8 % higher. I left them alone;
  they are gait tuning, not shape.
- The gait has not been re-tuned for the longer body (body stiffness 0.85, tail sway). It may want a softer tail half now that there
  is one. Play-test first.

## Handoff state (2026-11-08)
- Done: everything above. No edit is half-finished; all touched files parse (the last probe runs and the `after/` shot set came after
  the final shader edit, except the subpixel-line fade in `angler_fin.gdshader`, which was followed by a full `after/` shot run
  with 0 errors).
- Half-done: nothing.
- Untried:
  - gait re-tune for the longer body (`lantern_rig.gd` `_stiffen`, `angler_body_stiffness`, `angler_sway_deg`);
  - the `length / 6.0` thresholds in `lantern_rig.gd`;
  - bigger pectorals (`angler_model.gd` `_build_fins`, pectoral `l`);
  - removing the dotted strands between dorsal spines (`angler_fin.gdshader` `fragment`, the `strand` term);
  - pelvic fins.
- Last results: the probes in the table above (solo runs, all green). Shots are in `logs/hunter_refine/angler/after/`, and the probe logs
  are in `logs/hunter_refine/angler/*.log`.
- Next steps:
  1. Orchestrator runs the regression suite (hunter_forms, mode_setup, preview_jitter `--fixed-fps 144`) and builds.
  2. User play-tests the angler at 7 m.
  3. Then tune the gait or pectorals from the feedback.
