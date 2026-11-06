# Titan art log

The user's review sheet for the adult whales (planning_marco_whales.md §6a step 5): each
species' shots, its numbers against titan_specs.md, the faults found on the shots and what was
done about them, and any compromise left. Newest round last.

**Where the shots are:** `private_content/titan_shots/<species>/r<N>/` (git-ignored; a
`.gdignore` keeps Godot from importing them). Each round is the full QA set from
`tests/model_shots.tscn -- --fish=titan --species=N [--skin=N] --qa --out=DIR`:
- `*_qa_<light>_<view>.png`: 6 angles (front three-quarter, head-on, side, top, back three-quarter,
  below) under 3 lights (`studio`, `water` = the arenas' blue-green with fog and a sun from above,
  `rim` = low warm light from behind);
- `*_qa_close_{head,flipper,flukes,eye}.png`: close-ups;
- `*_qa_gameplay_{chase,mid,far}.png`: the chase cam behind (1.25 lengths), across the arena
  (4 lengths, LOD1) and far (8 lengths, LOD2), in the water light;
- `*_qa_compare.png`: beside the approved assets (the koi above, the humpback calf below, both
  scaled to the adult's length);
- `*_qa_fluke_{down,up}.png`: the flukes at full beat, to check the stock stays on the body.

**The numbers:** `Godot_console.exe --headless --path . --script res://tools/model_measure.gd --
--species=<key>` (or `all`). It reads the meshes back and prints each target from
titan_specs.md beside the measurement. Pass: all within ±10 %.

---

## 1. Humpback (`humpback`): Wave 2, 2026-11-05

**Status:** done by my checks after 3 fix rounds (r1 → r4); waiting on the coordinator's second
look.

**Final shots:** `private_content/titan_shots/humpback/r4/` (skin 0 `atlantic` as
`titan_humpback_qa_*`, skin 1 `southern` as `titan_humpback_skin1_qa_*`, skin 2 `pacific` as
`titan_humpback_skin2_qa_*`). Best single looks: `titan_humpback_qa_water_front.png`,
`titan_humpback_qa_studio_side.png`, `titan_humpback_skin1_qa_studio_below.png`,
`titan_humpback_qa_close_flukes.png`.

**Numbers (r4, model_measure, L = 6.23 m at the Titan hitbox): PASS, 23 of 23 within ±10 %.**

| key | target | measured |
|---|---|---|
| eye_at / eye_up | 0.23 / 0.35 | 0.230 / 0.345 |
| pec_at / pec_len / pec_chord | 0.28 / 0.30 / 0.065 | 0.280 / 0.299 / 0.068 |
| fluke_span / fluke_sweep | 0.32 / 0.07 | 0.320 / 0.070 |
| dorsal_at / dorsal_h | 0.64 / 0.025 | 0.633 / 0.026 |
| max_w / max_d / max_d_at | 0.21 / 0.24 / 0.36 | 0.210 / 0.241 / 0.370 |
| stock_at | 0.70 | 0.647 |
| w / d at 0.1, 0.3, 0.5, 0.7, 0.9 | 0.10/0.07, 0.20/0.23, 0.19/0.22, 0.11/0.15, 0.03/0.07 | all within 3 % |

Natural size: 1.31 m wide, 1.50 m deep, fluke span 1.99 m (the class hitbox is 1.9 × 2.4 ×
6.7 m, so the body sits inside it; flippers reach past it, as fins may).

Triangles: LOD0 50,464 (body 33.6k, flippers, flukes, dorsal, eyes), LOD1 10,768, LOD2 2,704.
LODs swap at 2.5 and 6 hitbox lengths (16.75 m and 40 m at scale 1).

**Faults found and fixed**

| Round | Fault (on the shots) | Fix |
|---|---|---|
| r1 | Scars read as rows of dotted dashes ("stitching") all over the flanks | Bigger, rarer cells; 2–3 long thin curved scratches per rake, broken up by noise; rarer cookie-cutter ovals |
| r1 | Barnacle clumps on the mid-flanks looked like a skin disease | Barnacles only on the chin, along the lower jaw and a few by the navel; tighter clumps |
| r1 | Belly splashes too big and blotchy (camouflage) on the Atlantic skin | Smaller, fewer splashes (`belly_mottle` 0.55 → 0.35, higher frequency) |
| r1 | Flipper tubercles a saw blade (sharp valleys between knobs) | Rounded bumps with rounded scallops between (cosine profile), smaller (0.22 → 0.16 → 0.12 of the chord), 9 of them |
| r1 | Pleats wavy like wood grain | Nearly straight, slow wander; closer together toward the chin |
| r1 | Nose a sharp wedge | Blunter tip (wider and deeper first station, longer closing) |
| r1 | Tail stock tapering to a spike into the flukes | Stock kept deeper to the notch |
| r2 | Rake scars fat wavy ribbons with per-pixel speckle | Thin anti-aliased lines, smooth noise breaks |
| r2 | Flipper root's end cap visible on the flank | Root loft runs on into the body and closes there; root sunk deeper (`pec_sink` 0.35 → 0.6) |
| r3 | Fluke serrations a regular pie crust | Irregular: 13 scallops, each its own depth, wandering spacing, shallower |

**Checked and fine:** silhouette from 6 angles (whale, not calf: longer and leaner, small head,
long keeled stock; see `_qa_compare`); no faceting on the body or fins at LOD0; flukes and dorsal
meet the body without gaps, also at full beat (`_qa_fluke_down`); reads under all 3 lights (the
tubercles carry the head in the rim light); at gameplay distance the white flippers and the dark
body carry it even at LOD2 (`_qa_gameplay_far`); 3 skins differ clearly (dark Atlantic, white-bellied
Southern, grey Pacific with black-topped flippers); fluke underside pattern differs per skin.

**Open / compromises (for the coordinator's look and the user):**
1. **Flipper root from below.** Seen from below and in front, the flipper's rounded root still
   reads as set onto the flank rather than growing out of it (`_qa_studio_below`). A real fillet
   (a lofted collar blending flipper into body) would fix it; not done in 3 rounds. Logged.
2. **Tubercles** cover the whole top of the rostrum as a field of knobs. Real humpbacks have them in
   rough rows (midline and the edges of the rostrum). It reads strongly as "humpback" at every
   distance, so it's kept; rows would be more accurate.
3. **Fluke underside scratches** are regular wavy lines (`_qa_close_flukes`); they read as
   contour lines up close. Minor.
4. **Eyes** are true to size (about 1 % of L across) and read as a small dark pit in a socket with a
   lid and fold. Intended ("old and poor-sighted"); they vanish past LOD0.
5. **Triangle budget.** LOD0 is 50k triangles, over tests/skins_probe's 40k cap (it counts every
   mesh, all LODs). Asked the coordinator to have skins_probe count LOD0 only (meta `lod`) and give
   Titans their own cap; not reduced, as the body needs its slices for the silhouette at chase-cam
   distance.
6. ~~Wave 3 (motion) will touch this~~: done, see the motion entry below.

**Lead's second-look faults, round r6 (2026-11-06, after the blue).** Shots are in
`private_content/titan_shots/humpback/r6` (all 3 skins). model_measure still passes 23 of 23
(stock_at 0.672).
- **Hump, knuckles and dorsal.** The hump is now 0.01 L, wider. There are 5 knuckles at 0.006 L
  (they were 4 at 0.0028). The dorsal is more upright on a longer base (0.605 to 0.655), with
  dorsal_h 0.022 and the fin and hump together measuring 0.024. From the side it now reads as a
  small fin on a hump, with the knuckles bumping down the stock.
- **Head depth.** The throat and chest are deeper at 0.2 L (top 0.075, bottom 0.12, was 0.065 and
  0.1), so the front half is bulkier. The 0.6 slice is a little wider (0.162) to keep stock_at in
  range.
- **Fluke ID pattern.** Crisp-edged shapes, antialiased by slope, at a finer scale, with ragged
  streaky edges and small black flecks in the white. The underside mask is sharper. Each skin
  reads as its own ID pattern (`_qa_close_flukes`, `_skin1_qa_close_flukes`).
- Still open: the flipper-root fillet, and tubercles in rows. The fluke's dark trailing margin is
  still a soft gradient.

## 2. Orca (`orca`): Wave 4, 2026-11-05

**Status:** done, 3 rounds. Shots: `private_content/titan_shots/orca/r1`..`r3`; r3 is current and
covers all 3 skins (`titan_orca_qa_*`, `titan_orca_skin1_qa_*`, `titan_orca_skin2_qa_*`).
model_measure passes 23 of 23 on the first build, with every key within 3.2 %. Natural size:
width 1.07 m and depth 1.31 m on L 6.23 m. Triangles: LOD0 50.5k, LOD1 10.8k, LOD2 2.7k (the same
loft budget as the humpback).

**New in the pipeline for it:**
- A fan dorsal (`dorsal_tip`, `dorsal_round`): every column reaches for the tip, so both edges run
  straight, as a male orca's tall triangle does. `dorsal_curl` is now a look value.
- Orca paint is now settings, not hard-coded:
  - eye patch: place, size and tilt;
  - the white band's edge: chin, between the flippers, the flank lobe's peak and where it is;
  - saddle: place, size and colour;
  - a grey cape for type B.
  The white edges are crisp and antialiased by their own slope (fwidth), not soft blobs.
- Flukes: `fluke_plain` gives one clean white field inside a dark margin, and `fluke_under` gives
  a white underside under black flippers.

**Rounds:**
| round | seen | fix |
|---|---|---|
| 1 | Reads as an orca at once. Faults: the eye patch was too tall and round; the flippers were pointed leaves, not paddles; the fluke underside was black (it took the flippers' black `fin_under`); symmetric cookie-cutter rings on top of the back read like bolts; the saddle was a pale heart-shaped blur from above. | eye patch 0.055 × 0.014 L, tilted; flipper chord kept broad to the tip; `fluke_under` added; resident scars 0; saddle darker, with a crisper ragged edge. |
| 2 | All three skins fine. The flank lobe's back edge was a vertical cut. | The lobe rises over 0.11 L and tapers back over 0.16 L. |
| 3 | Fine. | none |

**Skins:**
- `resident`: crisp patches, dark saddle, no scars.
- `biggs`: a pointed fin tip (`dorsal_round` 0.015), a broader, paler saddle, the eye patch smaller
  and further back, and rake scars.
- `antarctic_b`: a dark cape over slate flanks, the white tinted yellow by diatoms (`patch`), a
  large eye patch, cookie-cutter scars.

**Open:**
1. Scars are painted the same on both sides (they're placed by `s`, which is unsigned), as on the
   humpback. They're too sparse to notice.
2. Biggs' pointed fin tip and the resident's rounded one differ only up close.
3. From the lead's second look (accepted, no re-work):
   - the flipper outline is a little spoon-shaped (a rounder paddle with a bent leading edge
     would be better);
   - the trunk is slightly slim in the front half;
   - the white chin line is thin in the water front view.

## 3. Beluga (`beluga`): Wave 4, 2026-11-06

**Status:** done, 3 rounds. Shots: `private_content/titan_shots/beluga/r1`..`r3`; r3 is current and
covers all 3 skins. model_measure passes 23 of 23. Natural size: 1.38 x 1.52 m on L 6.23 m. LOD0
50.0k triangles.

**New for it:**
- The melon's place and length are look values (`melon_a`, `melon_len`).
- `scar_color` lets scars show grey on a white hide.
- There's no dorsal fin. The ridge is a long, low hump (dorsal_at 0.60, dorsal_h 0.008, as measured).

**Rounds:**
| round | seen | fix |
|---|---|---|
| 1 | Reads as a beluga (white, matte, the neck creases, the smile). The head was a pointed cone with a small bulge, not a melon over a beak, and there was no neck crease in the silhouette. | melon 0.05 at 0.055 L, shorter nose caps, neck 0.022. |
| 2 | Bulbous melon and a clear neck. The dip behind the melon was a little too deep (hammer-headed). | neck 0.016, melon_len 0.045. |
| 3 | Fine on all skins. | none |

**Skins:**
- `white`;
- `cream` (yellowish hide, grey-brown fin edges);
- `scarred` (grey scratch scars all over).

**Open:**
1. The beak under the melon is very short (a blunt face rather than a distinct beak).
2. The flippers' upturned tips are slight.
3. The spec's darker, scuffed dorsal ridge on `scarred` isn't painted; only scars mark that skin.
4. From the lead's second look (accepted, no re-work):
   - the body is a long, evenly thick tube (a belly bulge behind the flippers and a narrower
     stock would read more beluga);
   - the mouth line is faint.
   Belly shape fixed in r4 (`private_content/titan_shots/beluga/r4`): a belly bulge at 0.4 to
   0.5 L and a narrower stock at 0.8. Still 23 of 23.

## 4. Sperm whale (`sperm`): Wave 4, 2026-11-06

**Status:** done, 3 rounds. Shots: `private_content/titan_shots/sperm/r1`..`r3`; r3 is current and
covers all 3 skins. model_measure passes 24 of 24, including jaw_len 0.22. Natural size: 1.07 x
1.22 m on L 6.23 m. LOD0 51.6k triangles.

**New for it:**
- `_jaw`: a separate narrow lower jaw. It's a lofted rod tucked `jaw_sink` into the head's underside
  all along, rounded at the tip and slimming into the head at the hinge. It's in the fin shader as
  part 3, white along its top.
- The box head: square superellipse (n_head 4.0 / 2.6), very short top and side nose caps (a flat
  front), and the underside closing over 0.12 L (`box`) so the box overhangs the jaw.
- Prune skin: wrinkle 1.0 now paints wandering furrows mostly along the body, broken up and crossed
  by short creases. Before, it was fbm contour lines, which read as a map.

**Rounds:**
| round | seen | fix |
|---|---|---|
| 1 | Strong silhouette: box head, hump, knuckles. Faults: the jaw floated below the head as a white plank; the wrinkles read as contour lines or circuitry; a painted triangle at the head's lower front corner (the mouth line meeting the flat front). | The jaw follows the head's underside; lips white only on top; furrow wrinkles; no painted mouth line (the jaw is the mouth). |
| 2 | Jaw tucked in. A step where the jaw ends at the hinge; the furrows too straight and even. | The jaw slims to a quarter at the hinge; the furrows wander more. |
| 3 | Fine. | none |

**Skins:**
- `grey`;
- `scarred_bull` (heavy rake scars and pale blotches);
- `brown` (brown hide, paler belly).

**Open:**
1. The furrows are still more regular than a real sperm whale's corrugated skin; they read as
   stripes from the side.
2. `scarred_bull` has pale blotches (`mottle`), not real scarring: there are no sucker rings or
   scar-whitened head.
3. With the jaw tucked in, its white lips hardly show from the side.

## 5. Blue whale (`blue`): Wave 4, 2026-11-06

**Status:** done, 3 rounds. Shots: `private_content/titan_shots/blue/r1`..`r3`; r3 is current and
covers all 3 skins. model_measure passes 23 of 23. Natural size: 0.88 x 0.95 m on L 6.23 m (the
slenderest). LOD0 50.5k triangles.

**Rounds:**
| round | seen | fix |
|---|---|---|
| 0 (measure) | dorsal_h -52 % (the root's inset ate a fin this small); max_d_at 0.34. | dorsal_h 0.02 in the look (it measures 0.0123); deepest slice moved to 0.4. |
| 1 | Reads as a blue: long, slender, flat head, tiny dorsal far back, fine pleats. The mottling was big camouflage blotches rather than a dapple. | Mottle reworked for every species that uses it: many small flecks gathered into looser clouds. |
| 2 | Dappled. The `sulphur` belly was a saturated olive yellow; the mouth line was heavy. | Sulphur belly a faint grey-yellow; mouth line 0.0011 L. |
| 3 | Fine on all skins. | none |

**Skins:**
- `mottled` (light blue-grey, strong dapple);
- `dark` (darker slate blue, a softer dapple);
- `sulphur` (a faint yellowish film on the belly).

**Open:**
1. The blowhole pair and splashguard read as a small ringed oval up close.
- Lead's second look: the mottles were hard-edged, camouflage-like blotches. In r4
  (`private_content/titan_shots/blue/r4`) every scale is soft-edged and there's a second, finer
  dapple, faded out with distance.
- Lead's notes on the sperm whale (logged, no re-work): the jaw is almost invisible from the side,
  and the furrows are a bit regular.
2. The head's U shape from above isn't checked on its own shot (the top view crops the snout).

**LOD ranges when scaled:** A confirmed (via the lead, 2026-11-06) that they call the
`titan_lod_rescale` meta in the grow tween, after `_become_titan` and at the tween's end, so the
LOD swap distances follow the whale's visual scale.

## Motion (all Titans): Wave 3, 2026-11-05

**Status:** built and judged on the humpback. Shots are in `private_content/titan_shots/humpback/motion1`
(round 1) and `motion2` (round 2, current). Each folder has `_swim_sheet_side.png` (2 beats from
the side, 16 frames, left to right and top to bottom) and `_swim_sheet_turn.png` (the same while
turning left, seen from behind and above). QA re-shot after the motion in `r5`: no regressions, and
model_measure still passes 23 of 23.
Run: `model_shots.tscn -- --fish=titan --species=N --swim --out=<dir>` (it prints fluke range, head,
surge, bank and each power_stroke).

**How it works** (`FishModel._titan_swim`, the Titan branch in `fish_bend.gdshaderinc`):
- The swim still drives the beat: it writes tail.rotation.x each frame, and the Titan motion reads
  that and replaces it with the flukes' own angle. With no swim writing, the last beat holds.
- **Power and recovery:** the beat is followed at `fluke_snap` (1/s) going down and
  `fluke_snap / fluke_power_ratio` coming back up, so the down-stroke is fast and the recovery slow.
- **Wave:** a chain of up to 3 arcs (`bend_segments`) from 0.48 L to the fluke root. Each joint
  takes the shaped beat `bend_lag` s after the one in front (a delay line, so the beat keeps its
  size down the body). The bend share grows toward the tail (1 : 4 : 9).
- **Head counter:** the head (0.12 to 0.48 L) arcs the other way, `head_counter` times the body's
  pitch.
- **Surge:** each power stroke kicks the whole body forward by about `body_surge` of L, and it
  springs back.
- **Flipper trim:** the flippers pitch against the body's pitch and bank into turns, inside one down
  (`flipper_trim`). **Bank:** the body rolls into turns (`turn_bank`).
- **power_stroke(strength, at)** fires once per down-stroke at peak fluke speed. strength is the
  peak over `power_stroke_speed`, clamped to 0..1; `at` is the tail pivot's global transform.

**Rounds:**
| round | seen | fix |
|---|---|---|
| 1 | Beat barely visible (flukes about ±0.3 rad). The springs in series (stiffness 1/bend_lag) cut the beat by about half by the flukes and lagged it by about half a beat, so the wave shrank toward the tail (real whales: it grows). The power/recovery follower ran at 2/bend_lag, so it was coupled to the wave speed. Power strokes read strength 0.48. | Replaced the springs with a delay line (`_wave`, 10 ms samples) and decoupled the follower (`fluke_snap`, new). bend_lag 0.09 -> 0.12. |
| 2 | Flukes -0.53..+0.62 rad (down-stroke larger), a visible wave through the stock, tail tip about 0.2 L peak to peak. Power strokes at 0.92 strength, one per 1.4 s beat. Bank 0.07 rad at 0.5 rad/s turn. Fine. | none |

**Open:**
1. The head counter (about 0.09 rad) and surge (about 4.5 cm on a 6.2 m whale) are subtle on 300 px
   frames. They're there, and they're settings (`head_counter`, `body_surge`) if play shows they
   should read more.
2. Not yet seen in a match with A's real swim driving it (the shots drive tail.rotation.x with
   a 0.5 rad sine).
