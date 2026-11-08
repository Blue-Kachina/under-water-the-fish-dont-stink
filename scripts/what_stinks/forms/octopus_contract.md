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
- **Axes.** Model space: **-Z is the direction of travel** (head, eyes and arms ahead; the mantle trails behind along +Z and lifts a
  little, +Y up, +X is the octopus's right when looking along -Z... that is, to the viewer's right when it swims away from them).
  The origin is the head centre (where the arms meet the head). Rest extents (design units, times `octo.unit` for metres): mantle tip
  at z = +0.64 (`OctopusModel.MANTLE_END`), arm tips about z = -0.35 to -0.4; the crown spans about 1.1 x 1.1 of `length_m` across X and Y.
- **Cost.** 118 bones; body (mantle, head, 8 arms) 8.0k vertices / 14.8k triangles, webs 1.6k / 2.6k, suckers full detail 28.8k / 45k (near) or
  low detail 11k / 16k (far); one is visible at a time. One `ShaderMaterial` per part kind (skin, web, sucker, eye), same shader.
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
      MeshInstance3D "EyeL", "EyeR"   slit-pupil eyes (octo.eyes[0] = left, [1] = right), + "LidL"/"LidR" rims
      Node3D "Siphon"                 octo.siphon, mesh child "SiphonMesh"; local +Z is the exhaust direction (back and a little down: about (0, -0.21, 0.98))
        Marker3D "SiphonMouth"        octo.siphon_mouth, at the funnel exit
    BoneAttachment3D "ArmTip0".."7"   child Marker3D "Tip": octo.arm_tips[arm], the last bone's far end
```

## Bones (indices are public)

| Name | Index | Notes |
|---|---|---|
| `root` | 0 | model origin |
| `head` | 1 | child of root; carries the eyes, siphon and all 8 arm chains. Scaling it scales the arms' bases (cascades). |
| `mantle_0` .. `mantle_3` | 2..5 | child chain from root (NOT the head), along +Z at z = 0.10, 0.22, 0.34, 0.46 design units. Bone local +Z points to the mantle tip (identity basis). |
| `arm{a}_{s}` | `6 + a*14 + s` | a = 0..7, s = 0..13. Arm a's bone 0 is a child of `head`, each next bone a child of the previous. |

`octo.head_bone`, `octo.mantle_bones: PackedInt32Array` (4), `octo.arm_bones: Array` (8 arrays of 14 ints, **arm_bones[arm][segment]**),
`octo.root_bone`.

### Arm numbering (`arm` 0..7)

Ring around the head, looking along the travel direction (-Z, from behind the octopus), counter-clockwise from the octopus's right
(+X): `octo.arm_angle(arm)` is the ring angle in radians (22.5, 67.5, ... 337.5 degrees): arm 0 upper right, 1 high right of the top, 2 high left, 3 upper left,
4 lower left, 5 bottom left, 6 bottom right, 7 lower right. Neighbours are arm +-1 mod 8 (the web joins each neighbouring pair). Left side = arms 2-5,
right side = arms 0, 1, 6, 7 (`octo.arm_side(arm)` returns +1 right / -1 left). `octo.arm_radial(arm) -> Vector3` is the unit outward direction in model space (XY plane).
Front pair for gait/targeting: arms 1 and 2 (top), rear pair 5 and 6 (bottom).

### Arm bone frames (local axes, for pose chains)

- **-Z** points along the arm toward its tip (so the next bone is at local (0, 0, -segment_length)).
- **+Y** is the oral (sucker) side normal; rolls with the arm. **+X** is the lateral binormal.
- Bend angles are rotations of the bone relative to its REST orientation, in its own local axes: `pitch` about X (positive curls the arm
  **toward its sucker side**, +Y, the natural curl-in), `yaw` about Y (positive bends toward local -X), `twist` about Z (positive rolls the sucker side
  toward +X). Applied as `rest * Q(Y, yaw) * Q(X, pitch) * Q(Z, twist)`. Bends accumulate down the chain, so a curl of c rad per segment over 14 segments is a total 14c rad.
- A segment's length is `octo.arm_segment_length(arm, seg)` (about 0.033-0.048 of `length_m` for the long arms), the whole arm `octo.arm_length(arm)`.
  Radius at the base 0.04 design units tapering to 0.003.

## Pose setters (call every frame from the rig; idempotent; cheap: only bones that change are written)

```gdscript
octo.set_arm_pose(arm: int, bends: PackedVector3Array)       # per-segment Vector3(pitch, yaw, twist), size <= 14, missing = 0. THE per-arm chain setter.
octo.set_arm_bend(arm: int, seg: int, pitch: float, yaw: float, twist := 0.0)   # single segment
octo.clear_arm_pose(arm := -1)                                # back to rest (-1 = all arms)
octo.set_mantle_pulse(p: float)                               # -1 inflated (+14% radius) .. 0 rest .. +1 fully contracted (-24% radius, bulge profile along the mantle). Also drives shader `mantle_pulse`.
octo.set_mantle_bend(yaw: float, pitch: float)                # total bend of the mantle (spread over the 4 bones, rad); yaw about Y, pitch about X, mantle trails the head
octo.set_mantle_pose(bends: PackedVector3Array)               # per mantle bone (4), same Vector3(pitch, yaw, twist) convention (bone local +Z to the tip)
octo.set_head_basis(b: Basis)                                 # the head's rotation relative to the root (look/roll); carries arms, eyes, siphon
octo.set_siphon_aim(yaw: float, pitch: float)                 # rotates the `siphon` node (vectored jet); 0,0 = exhaust straight back (+Z, a little down)
octo.reset_pose()                                             # everything back to rest, uniforms to defaults
```

Rest pose: the arms form a loose flaring crown ahead of the head, curling at the tips; the mantle trails behind and lifts about 6 percent of its length.

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
octo.mouth_local() -> Vector3                        # the beak: the point arms meet, at the head front (for bite/engulf origin), model space
octo.mantle_tip_local() -> Vector3                   # current mantle end, model space
octo.length_m: float ; octo.unit: float ; octo.arms_count = 8 ; octo.segments = 14
```

`arm_tips[arm]` (Marker3D) follows the last bone automatically (use for attaching spark FX / aura nodes). For per-frame maths prefer
`arm_tip_local`, which does not wait on the BoneAttachment's update.

## Shader uniforms (all four materials share the shader; set through the model's setters, or `octo.set_param(name, value)` which sets it on every material)

| Uniform | Range | Meaning |
|---|---|---|
| `mantle_pulse` | -1..1 | mirrors `set_mantle_pulse`: flushes the mantle veins and brightens the rim on a contraction |
| `stroke` | 0..1 | swim-stroke energy: raises vein emission, speeds the flow. The rig feeds it from the stride envelope (peak 1 at the jet) |
| `vein_travel` | 0..1.2 (out of range = off) | position of a bright pulse running along the body from the mantle tip (0) to the arm tips (1). Rig: sweep it 0 to 1.1 over ~0.35 s per jet |
| `vein_travel_gain` | 0..3 | strength of that pulse (default 1.4) |
| `charge` | 0..1 | Tendril Lash charge: veins widen, shift white-hot, suckers light, eyes flare, vein flicker speeds up |
| `glow` | 0..3 | master emission multiplier (default 1) |
| `arm_glow_a` | vec4 | per-arm glow add (arms 0-3 in x,y,z,w), 0..2 |
| `arm_glow_b` | vec4 | arms 4-7 in x,y,z,w |
| `sucker_glow` | 0..3 | extra sucker emission (default 0.15; press crown pushes it up) |
| `eye_glow` | 0..3 | iris emission (default 0.35) |
| `chroma_shift` | -1..1 | chromatophore tint push: -1 pulls toward copper/orange, +1 toward violet (mood / damage) |
| `flash` | 0..1 | hit / lock flash toward white-hot |
| `hurt` | 0..1 | pale desaturation + dim (taking damage) |

Convenience wrappers: `set_charge(c)`, `set_stroke(s)`, `set_vein_travel(t)`, `set_glow(g)`, `set_arm_glow(arm, g)` (array under the hood), `set_flash(f)`,
`set_chroma_shift(x)`, `set_sucker_glow(g)`, `set_eye_glow(g)`. Without any driver the model still idles alive: veins breathe on a slow built-in pulse
(the shader's `TIME`), chromatophores drift, so a rig only adds energy on top.

## LOD / perf

- Suckers (a skinned mesh, not a MultiMesh: instances cannot follow bones without a per-frame CPU matrix update): two meshes with
  `visibility_range` windows scaled by `length_m` (full detail to `octo.sucker_hi_range_lengths` = 3 body lengths, cheap to `octo.sucker_range_lengths` = 7, then
  none; 0.5 length dither fade). Set the two properties (0 = no limit / no hi detail) at runtime.
- A rig should not call the setters on arms the camera cannot see (per-view culling); `octo.set_detail(bool)` hides suckers+webs entirely for far bots.
- Gameplay-distance reading: at 2 to 4 body lengths the arms, mantle veins, eyes and sucker rows read; below 1 length the cups and eyelids hold up (see `tests/octopus_model_shots.tscn`).
- Skinning is GPU; per frame CPU cost is only the bones written (up to 118). `set_arm_pose` skips a bone whose delta is unchanged.

## Not in this model (by design)

Gait, jet physics, crawl planting, whip attack: C2/C3. The model only exposes joints and poses them as told. `idle_pose(t)` (a lazy
arm sway + gentle mantle breath) is provided as a baseline and as an example of a driver; it is what the model shot tool uses.
