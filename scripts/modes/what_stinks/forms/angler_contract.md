# Lantern Angler model contract (D1)

Form id `lantern_angler`. File: `scripts/what_stinks/forms/angler_model.gd` (`class_name AnglerModel`, `extends Node3D`),
skin `shaders/angler_skin.gdshader`, fins `shaders/angler_fin.gdshader` (shared pose channels in `shaders/angler_pose.gdshaderinc`).
D2 (rig/gait) and D3 (lure attack) code against this API.

## Space and scale
- Built at a real length: `AnglerModel.build(length_m)` (the hitbox length of the form, 7 m on the sheet). Every dimension inside is
  `k = length_m / 7.5` times the 7.5 m design (`DESIGN_LENGTH`; it was 6 before the 2026-11-08 refine). A size change means `build()` again (like KingRig).
- **Rest space** (what `rest` means below): head's snout at z 0, tail tip at z = length, +x the fish's right, +y up. The body is one
  mesh bent by a `SpineRig` (`rig`) exactly like the bosses: the mesh node is `top_level`, at the world origin, and the shader writes
  world positions. The fish faces its own -Z, so a controller pose is head = front of the hitbox, tailward = the fish's +Z.
- Proportions at `k` = 1 (design m): globe head about 3 m long, 3.4 m wide, 3.9 m tall (unchanged by the refine); lower jaw sticks
  0.35 m past the snout; behind the gill a real fish body tapers to a narrow peduncle (0.4 wide, 0.55 tall) at z 6.0 (`BODY_END` 6.25
  closes the loft); the caudal fan runs from z 5.95 to 7.5; spiny first dorsal z 1.95-3.35, soft dorsal 4.25-5.9, anal 4.5-5.9;
  illicium 2.9 m long arcing over the mouth; pectorals behind the gill at z 2.6-3.0 (hinge `PECT_ROOT` (1.5, -0.25, 2.8)).

## Posing (D2 calls these every frame, in this order)
1. `rig.head_up`, `rig.head_back` (the fish's up and tailward), then `rig.follow_trail(head, trail, back)` or
   `rig.follow_chain(points)`. Or for a still / preview pose: `pose_straight(bend := 0.0)` which lays the spine along the node's own
   global transform (head at the node's origin, tailward = node +Z) with an optional sideways bend (rad, total, eased toward the tail).
2. `update(delta, accel_world := Vector3.ZERO)` (once per frame, after the spine moved): `rig.apply()`, steps the stalk spring chain
   (pass the head's world acceleration; zero is fine, an idle sway is built in), places eyes, the esca, its light and halo.
   `pose_straight()` calls `update` itself.

## Public API
| Member | Meaning |
|---|---|
| `jaw_open: float` (setter) | 0 shut, 1 fully open (52 deg drop), 0..2.4 for exaggeration (clamped to `MAX_JAW_ANGLE` 2.1 rad). Negative = clamped shut tight (-0.1: bites past shut). Turns the lower jaw, its teeth and tongue about the skull's hinge in the shader (`spine_hinge`), so the skin follows without seams. |
| `esca_intensity: float` (setter) | 0 dark to 1 normal glow, up to 4 for a flare. Drives the bulb's emission, the halo size/alpha and the point light's energy. D3 flickers it. |
| `esca_color: Color` | Default cool cyan. |
| `eye_glint: float` (0..2) | Brightness of the cold eye glint (flare on the press). |
| `tail_bend: float` (rad) | Extra tail snap: everything behind `TAIL_FROM` (design z 3.9, the body behind the head) and its fins turn about the vertical, eased in. +x side positive. For lunge bursts; the spine's own bend comes from the rig. |
| `set_pectoral(flap: float, sweep := 0.0)` | Pectoral fin scull: flap in rad (+ raises tips), sweep in rad (fins fan back). Both fins, shader-driven (hinged at their roots). `flap_l`/`flap_r` for asymmetric (roll). |
| `light_enabled: bool` | Wanted state of the esca point light. The light really exists only while `AnglerModel.lights_in_use < AnglerModel.light_cap` (static; the murk/light cap sets `light_cap`); otherwise the **emissive halo** is the fallback (and the halo stays on top of the light anyway, smaller). `has_light() -> bool` tells which. |
| `static light_cap: int` | Default 6 across all anglers. Raise/lower from the murk system. `lights_in_use` is the live count. |
| `esca_world() -> Vector3` | Where the bulb is now (world): for the lure field, the HUD cue, FX. |
| `esca_rest() -> Vector3` / `mouth_rest() -> Vector3` | Rest-space points (esca at rest; the mouth centre where prey are taken: between the jaws about 1.0 m behind the snout). `mouth_world(open := jaw_open)` includes the jaw's turn. |
| `stalk_nodes: Array[Node3D]` | 6 nodes (base to esca) following the spring chain in world space, for attaching FX (the lure's cone is aimed from `stalk_nodes[5]`). Do not reparent. |
| `stalk_stiffness`, `stalk_damping`, `stalk_sway` | Spring chain tuning (exports). Base joint is pinned to the forehead; stiffness grows toward the base. |
| `kick_stalk(impulse_world: Vector3)` | One-off flick of the esca (lunge, lure press). |
| `eyes: Array[MeshInstance3D]` | Left, right; glow via `eye_glint`. |
| `skin: ShaderMaterial`, `teeth_skin: ShaderMaterial`, `fin_skin: ShaderMaterial` | Body, translucent teeth and fin materials (all on `rig.materials`). `skin` and `fin_skin` uniforms for D2/D3: `warn` (0..1 tint when charging), `flash`, `dissolve`. |
| `rig: SpineRig` | The spine. `rig.instances` has the body, teeth and fin nodes (`body_node`, `teeth_node`, `fin_node`). |
| `mesh_stats() -> Dictionary` | `{vertices, triangles, teeth, fin_vertices}` for budget probes (vertices = body + teeth + fins). |
| `rest_aabb() -> AABB` | Rest-space bounds of all three meshes (snout or jaw tip to the caudal fan's tip): use it, not the body mesh's AABB, for the creature's length. |

## Fins and bones
There are no skeleton bones: the creature is spine-bent meshes like the bosses (see SpineRig). The "tail/fin bones" are
shader channels: `tail_bend`, `set_pectoral`, the fin `flutter` uniform (every fin ripples along its normal out to the tips, a wave
running across it; amplitude from `fin_flutter: float` 0..2, default 0.6) and the spine itself. D2's gait therefore only writes:
spine (rig), `tail_bend`, pectoral, `fin_flutter`.

The fins are their own mesh (`fin_node`, third draw call, alpha-blended, no shadow) of plain membranes (UV u along the root, v out
to the tips; UV2.x the fin id: 10 spiny dorsal, 11 soft dorsal, 12 anal, 13 caudal, 14 pectorals). `angler_fin.gdshader` paints
everything else: rays as jointed ridges (bump), a translucent web (alpha + backlight + edge sheen) torn back between the rays to a
ragged, chewed edge with holes and splits, and each ray running on past the web as a hair-like filament, some fraying into a
second wandering strand; a few photophores on the rays. Per-fin ray counts and web reach are in `fin_spec()`.

## HunterJaw hookup (D4 / D2 writes `angler_jaw.gd`)
`HunterJaw.mouth_local()` = `mouth_rest()` converted to the visual's space; `pose(open)` -> `jaw_open = open * gape_mult` where the
exaggeration kit can push `gape_mult` past 1. Teeth are part of the same hinge so nothing else needs moving.

## Looks (for reviewers)
Reference `private_content/lit_angler_fish.png`: dark teal skin with ridged brow, pale wrinkle highlights, glassy needle teeth upward
from a heavy underslung jaw, ragged pectoral/tail fins with hair-like tufts, small cold eyes, cyan esca on a long curved stalk,
cyan photophores along the flank.

## Budget
Target < 40k vertices total body + teeth + fins, 3 draw calls (+ 2 eyes, bulb halo quad). One optional OmniLight3D (range 9 k).

## As built (D1 final notes)
- `jaw_open` 0 is NOT fully shut: the jaw hangs `JAW_REST` 0.1 rad open so the teeth show (menacing at rest). 1.0 = 0.1 + 0.9 rad (about 57 deg), 2.0 = 1.9 rad
  (109 deg), cap `MAX_JAW_ANGLE` 2.1 rad. Negative down to -0.12 closes it tight.
- Vertices about 26k body + teeth (probe prints it), 66k tris before the loft trim; 54 teeth; 2 draw calls + 2 eyes + halo quad.
- `tail_bend` starts at z 3.9 (design) and `rad` is the angle at the tail's tip (0.7 about 40 deg). Pectoral flap/sweep per side via `set_pectoral_sides`.
- Teeth are merged into the one teeth mesh (a second draw call, alpha-blended, hinged by the same shader) instead of MultiMesh instances: instancing cannot ride the
  shader hinge and the spine bend.
- Tools: `tests/angler_shots.tscn` (turntable, jaw 0.5/1/1.6/2.2, esca flare, stalk whip, fins, tail snap; `--out=DIR --set=turn,close,open,stalk,fins,game`),
  `tests/angler_model_probe.tscn` (82 checks, headless).
- Refine 2026-11-08 (planning_hunter_refine.md, worker A): longer body (design 7.5 m, sheet 7 m), fins moved to their own mesh and
  `angler_fin.gdshader`, gnarlier skin (creased wrinkle lines along the face and round the body, warty knobs with pale tips, dark
  creases, matte rather than glossy, denser photophores), thinner glassier needle teeth, a gill-cover rim, geometric warts and skin
  folds breaking the outline, 16 head tufts. About 34k vertices (body + teeth + fins), 67k triangles.
- Not done / for D2-D4: HunterJaw wrapper (`angler_jaw.gd`), the form file and registration, gameplay tuning of stalk stiffness, a sound for the esca, the lure field.
