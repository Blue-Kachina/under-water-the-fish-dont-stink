# Ember Octopus model contract (`OctopusModel`, C1)

Public API other workers (C2 rig, C3 whip attack, C4 integration) code against. The model is `scripts/what_stinks/forms/octopus_model.gd`
(`class_name OctopusModel extends Node3D`), the skin is `shaders/octopus_skin.gdshader`. Everything here is implemented and probed
by `tests/octopus_model_probe.tscn`.

## Build

```gdscript
var octo: OctopusModel = OctopusModel.build(length_m)   # length_m = rest-pose extent along Z (mantle tip to arm tips), default 1.0
add_child(octo)
```

- **Units.** Metres. `length_m` is the model's rest-pose extent along Z, mantle tip to the furthest arm tip (about 1.0 body length,
  the form sheet's `length_m`). All geometry, bones and the skeleton are built at that size (do not scale the node to size it; scaling
  the whole node uniformly is fine for the exaggeration kit). `octo.unit` = metres per design unit (0.9 design units of mantle = 0.9 x unit).
  The hitbox length to match is `octo.length_m`.
- **Axes (changed 2026-11-08, planning_hunter_refine.md).** Model space: **-Z is the direction of travel and the MANTLE LEADS** (as a
  real octopus jets): the mantle tip is the front (-Z), the head and eyes behind it, and the **arms trail behind along +Z** in a flat,
  swept-back delta (the webs between their bases make the wing). +Y up, +X is the octopus's right when looking along -Z (to the viewer's
  right when it swims away from them). The origin is the head centre (the arms root just behind it). Rest extents (design units, times
  `octo.unit` for metres; `unit` = length_m / 1.494): mantle tip at z = -0.56 (`OctopusModel.MANTLE_END`), crown pole z = +0.145
  (`CROWN_END`), arm bases on a flat ellipse round the crown at z = +0.072 (x = cos(angle) x 0.058, y = sin(angle) x 0.036), arm tips
  at z = +0.68 .. +0.93. At rest the delta spans about 0.58 x 0.29 of `length_m` across X and Y (wide and flat). Each arm's fan angle in
  the delta is `OctopusModel.ARM_FAN` (degrees toward +X: 56, 20, -20, -56, -40, -7, 7, 40 for arms 0..7; dorsal 0-3 and ventral 4-7
  interleave), sweeping back 20-32% toward the axis by the tip.
- **Cost.** 118 bones; body (mantle, head, 8 arms) 8.5k vertices / 15.8k triangles, webs 2.2k / 3.6k, suckers full detail 43k / 68k (near) or
  low detail 17k / 24k (far; the arms are longer than before); one is visible at a time. One `ShaderMaterial` per part kind (skin, web, sucker, eye), same shader.
- **Gotcha for anyone adding skinned meshes to it:** a `MeshInstance3D` made in code needs `skeleton = NodePath("..")` and a skin, or it
  renders in the bind pose and ignores every pose setter.

## Node structure

```
OctopusModel (Node3D)                 meta "hunter_octopus" = true
  Skeleton3D                          octo.skeleton
    MeshInstance3D "Body"             mantle + head + 8 arms (one mesh, skinned)
    MeshInstance3D "Web"              membranes between adjacent arm bases (skinned, double sided)
    MeshInstance3D "Suckers"          every sucker, full detail (16 sides), skinned; visible within `octo.sucker_hi_range_lengths` (3) body lengths
    MeshInstance3D "SuckersLo"        the same suckers at 7 sides, between that and `octo.sucker_range_lengths` (7) body lengths; fields `sucker_mesh`, `sucker_mesh_lo`
    BoneAttachment3D "HeadAttach"     follows `head`
      MeshInstance3D "EyeL", "EyeR"   small slit-pupil eyes (octo.eyes[0] = left, [1] = right), + "LidL"/"LidR" rims swelling into a heavy brow
      Node3D "Siphon"                 octo.siphon, mesh child "SiphonMesh"; under the head, local +Z is the exhaust direction (back between the
                                      ventral arms and a little down: about (0, -0.21, 0.98)); its mouth at about (0, -0.10, +0.06) design units
        Marker3D "SiphonMouth"        octo.siphon_mouth, at the funnel exit
    BoneAttachment3D "ArmTip0".."7"   child Marker3D "Tip": octo.arm_tips[arm], the last bone's far end
```

## Bones (indices are public)

| Name | Index | Notes |
|---|---|---|
| `root` | 0 | model origin |
| `head` | 1 | child of root; carries the eyes, siphon and all 8 arm chains. Scaling it scales the arms' bases (cascades). |
| `mantle_0` .. `mantle_3` | 2..5 | child chain from root (NOT the head), AHEAD along -Z at z = -0.10, -0.22, -0.34, -0.46 design units. Identity basis (bone axes = model axes): the mantle tip is toward the bones' local -Z. |
| `arm{a}_{s}` | `6 + a*14 + s` | a = 0..7, s = 0..13. Arm a's bone 0 is a child of `head`, each next bone a child of the previous. |

`octo.head_bone`, `octo.mantle_bones: PackedInt32Array` (4), `octo.arm_bones: Array` (8 arrays of 14 ints, **arm_bones[arm][segment]**),
`octo.root_bone`.

### Arm numbering (`arm` 0..7)

Ring around the head, looking along the travel direction (-Z, from behind the octopus), counter-clockwise from the octopus's right
(+X): `octo.arm_angle(arm)` is the ring angle in radians (22.5, 67.5, ... 337.5 degrees): arm 0 upper right, 1 high right of the top, 2 high left, 3 upper left,
4 lower left, 5 bottom left, 6 bottom right, 7 lower right. Neighbours are arm +-1 mod 8 (the web joins each neighbouring pair). Left side = arms 2-5,
right side = arms 0, 1, 6, 7 (`octo.arm_side(arm)` returns +1 right / -1 left). `octo.arm_radial(arm) -> Vector3` is the unit outward direction in model space (XY plane).
In the delta the dorsal (upper) layer is arms 0-3, the ventral (lower) layer arms 4-7; inner arms 1, 2 (dorsal) and 5, 6 (ventral) run
near the centre line, 0, 3, 4, 7 are the delta's outer edges. Sucker sides: the outer arms' face the delta's centre line (sideways, a
touch down), the inner arms' face mostly down, so the tips curl in the wing's plane and the two layers never cross.

### Arm bone frames (local axes, for pose chains)

- **-Z** points along the arm toward its tip (so the next bone is at local (0, 0, -segment_length)).
- **+Y** is the oral (sucker) side normal; rolls with the arm. **+X** is the lateral binormal.
- Bend angles are rotations of the bone relative to its REST orientation, in its own local axes: `pitch` about X (positive curls the arm
  **toward its sucker side**, +Y, the natural curl-in), `yaw` about Y (positive bends toward local -X), `twist` about Z (positive rolls the sucker side
  toward +X). Applied as `rest * Q(Y, yaw) * Q(X, pitch) * Q(Z, twist)`. Bends accumulate down the chain, so a curl of c rad per segment over 14 segments is a total 14c rad.
- A segment's length is `octo.arm_segment_length(arm, seg)` (about 0.036-0.044 of `length_m`), the whole arm `octo.arm_length(arm)`
  (0.86 design units, 0.5-0.61 of `length_m`). Radius about 0.055 design units at the base (a root flare) tapering to 0.005.
- **Roots.** Each arm's tube carries on 4 rings back into the head (on the head bone), and its first segment's skin leans on the head bone
  (75% at the base, fading out over 1.3 segments); the web's first rows lean on the head the same way, so bent arms stay on the body. The
  web runs 14 dense rows (a third of the arm) down at the middle of each gap and 25 along the arms themselves.

## Pose setters (call every frame from the rig; idempotent; cheap: only bones that change are written)

```gdscript
octo.set_arm_pose(arm: int, bends: PackedVector3Array)       # per-segment Vector3(pitch, yaw, twist), size <= 14, missing = 0. THE per-arm chain setter.
octo.set_arm_bend(arm: int, seg: int, pitch: float, yaw: float, twist := 0.0)   # single segment
octo.clear_arm_pose(arm := -1)                                # back to rest (-1 = all arms)
octo.set_mantle_pulse(p: float)                               # -1 inflated (+14% radius) .. 0 rest .. +1 fully contracted (-24% radius, bulge profile along the mantle). Also drives shader `mantle_pulse`.
octo.set_mantle_bend(yaw: float, pitch: float)                # total bend of the mantle (spread over the 4 bones, rad); yaw about Y, pitch about X; the mantle LEADS, so + yaw swings its tip to -X
octo.set_mantle_pose(bends: PackedVector3Array)               # per mantle bone (4), same Vector3(pitch, yaw, twist) convention (bone axes = model axes, tip toward -Z)
octo.set_head_basis(b: Basis)                                 # the head's rotation relative to the root (look/roll); carries arms, eyes, siphon
octo.set_siphon_aim(yaw: float, pitch: float)                 # rotates the `siphon` node (vectored jet); 0,0 = exhaust straight back (+Z between the ventral arms, a little down)
octo.reset_pose()                                             # everything back to rest, uniforms to defaults
```

Rest pose: the mantle ahead (its tip lifting about 2 percent), the arms trailing behind in a flat swept-back delta, the outer arms' tips
curling in toward the centre line, the inner arms' a little down.

### Read-back (for lagged solvers, crawl foot plants, whip curves; all in the octopus's own model space unless noted)

```gdscript
octo.arm_rest_joints(arm) -> PackedVector3Array      # 15 points: bone origins 0..13 then the tip; REST pose, cached (no skeleton query)
octo.arm_joints(arm) -> PackedVector3Array           # same 15 points in the CURRENT pose (reads the skeleton)
octo.arm_tip_local(arm) -> Vector3                   # current tip position, model space
octo.arm_tip_global(arm) -> Vector3                  # world space (octo.global_transform * local)
octo.arm_bone_transform(arm, seg) -> Transform3D     # current bone transform, model space (basis columns = the arm frame above)
octo.arm_segment_length(arm, seg) -> float
octo.arm_length(arm) -> float
octo.arm_angle(arm) -> float ; octo.arm_side(arm) -> int ; octo.arm_radial(arm) -> Vector3
octo.siphon_exhaust_dir() -> Vector3                 # model space unit vector the jet leaves along (current aim); thrust = -this
octo.siphon_mouth_local() -> Vector3                 # model space
octo.mouth_local() -> Vector3                        # the beak: where the arms meet, BEHIND the head between the delta's two layers, head * (0, -0.004, +0.11) design units (bite/grab origin), model space
octo.mantle_tip_local() -> Vector3                   # current mantle end, model space
octo.length_m: float ; octo.unit: float ; octo.arms_count = 8 ; octo.segments = 14
```

`arm_tips[arm]` (Marker3D) follows the last bone automatically (use for attaching spark FX / aura nodes). For per-frame maths prefer
`arm_tip_local`, which does not wait on the BoneAttachment's update.

## Shader uniforms (all four materials share the shader; set through the model's setters, or `octo.set_param(name, value)` which sets it on every material)

| Uniform | Range | Meaning |
|---|---|---|
| `mantle_pulse` | -1..1 | mirrors `set_mantle_pulse`: a contraction brightens the mantle's gold core and its sparks |
| `stroke` | 0..1 | swim-stroke energy: brightens the ember sparks, the gold core and the faint threads. The rig feeds it from the stride envelope (peak 1 at the jet) |
| `vein_travel` | 0..1.2 (out of range = off) | position of a bright pulse (sparks, threads, sucker rims) running along the body from the mantle tip (0) to the arm tips (1). Rig: sweep it 0 to 1.1 over ~0.35 s per jet |
| `vein_travel_gain` | 0..3 | strength of that pulse (default 1.4) |
| `charge` | 0..1 | attack charge: the sparks grow and shift white-gold, the threads light, sucker rims glow, the eyes flare |
| `glow` | 0..3 | master emission multiplier (default 1) |
| `arm_glow_a` | vec4 | per-arm glow add (arms 0-3 in x,y,z,w), 0..2 |
| `arm_glow_b` | vec4 | arms 4-7 in x,y,z,w |
| `sucker_glow` | 0..3 | extra sucker (rim) emission (default 0.15) |
| `eye_glow` | 0..3 | the dark iris's faint ember glint (default 0.35) |
| `chroma_shift` | -1..1 | chromatophore tint push: -1 toward the warm wine (`copper`), +1 toward maroon-violet (mood / damage) |
| `flash` | 0..1 | hit / lock flash toward white-hot |
| `hurt` | 0..1 | pale desaturation + dim (taking damage) |

The look (2026-11-08, `private_content/giant_glowing_octopus.png`): deep wine / maroon-violet wet skin with folds and papillae (fine ones in the
normal, coarse ones pushed into the silhouette in `vertex()` by `displace` design units; the model sets `unit_m`), the glow as fine twinkling
ember photophores under the skin (two voronoi layers: `speck_scale`, `speck_energy`) with a warm gold core through the middle of the mantle
(`core_gold`, `core_energy`), faint glowing threads (`vein_*`, mostly lit by a stroke or the charge), pale-rimmed suckers, a small dark eye.

Convenience wrappers: `set_charge(c)`, `set_stroke(s)`, `set_vein_travel(t)`, `set_glow(g)`, `set_arm_glow(arm, g)` (array under the hood), `set_flash(f)`,
`set_chroma_shift(x)`, `set_sucker_glow(g)`, `set_eye_glow(g)`. Without any driver the model still idles alive: the sparks twinkle and the core breathes on
the shader's `TIME`, chromatophores drift, so a rig only adds energy on top.

## LOD / perf

- Suckers (a skinned mesh, not a MultiMesh: instances cannot follow bones without a per-frame CPU matrix update): two meshes with
  `visibility_range` windows scaled by `length_m` (full detail to `octo.sucker_hi_range_lengths` = 3 body lengths, cheap to `octo.sucker_range_lengths` = 7, then
  none; 0.5 length dither fade). Set the two properties (0 = no limit / no hi detail) at runtime.
- A rig should not call the setters on arms the camera cannot see (per-view culling); `octo.set_detail(bool)` hides suckers+webs entirely for far bots.
- Gameplay-distance reading: at 2 to 4 body lengths the arms, mantle veins, eyes and sucker rows read; below 1 length the cups and eyelids hold up (see `tests/octopus_model_shots.tscn`).
- Skinning is GPU; per frame CPU cost is only the bones written (up to 118). `set_arm_pose` skips a bone whose delta is unchanged.

## Not in this model (by design)

Gait, jet physics, crawl planting, attacks: the rig (octopus_rig.gd) and the attack. The model only exposes joints and poses them as told.
`idle_pose(t)` (a lazy arm sway + gentle mantle breath) is provided as a baseline and as an example of a driver; it is what the model shot
tool uses.

## The rig's hooks for an attack (octopus_rig.gd, `OctopusRig`)

- `rig.gait_joints(arm) -> PackedVector3Array`: the gait's own 15 model-space joints for that arm now (use as `gait_provider`: what a
  driven arm reels back to). With the new axes these trail behind (+Z); reel an arm back by interpolating each segment's DIRECTION
  (slerp), not the joint positions: a straight position lerp from an arm reaching ahead to the trailing pose folds through the base and
  stretches segments past `WhipAttack.Solver.KMAX`.
- `rig.lash`: an attack object; its `blend_pose(model)` runs after the gait every frame, so it overrides the arms it drives (returns
  them). `busy()` / `driven_arms()` / `arm_weight(arm)` are the attack's own (the rig does not read them).
- `rig.override_dirs[arm]` (14 unit directions, model frame) + `rig.override_w[arm]` (0..1): the gait's springs follow these instead.
- `rig.charge`, `rig.glow_extra`: shader drive. `WhipAttack.Solver` (joints -> bends + stretch) reads the rest bones, so it works on the
  new rest unchanged (round trip exact, arms swung ahead, sideways and up).
- The swim: settings `octopus_jet_narrow` (the delta narrowing on a power stroke), `octopus_jet_respread` (re-spread on the recovery),
  `octopus_jet_wave` (a wave down the arms after each jet), `octopus_bank` (turns and rolls bank the delta), on top of the C2 ones.
