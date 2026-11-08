# Hunter form sheets (What Stinks?)

The form sheet is to the Hunter what `titan_specs.md` is to a Titan: what the form is, how big, fast and
slow, how its bite is shaped, and where the camera sits. Every number is the default of a setting
(flexible-tuning), at `hunter_size` 1; `HunterSize` (the panel's "Hunter Size" group) multiplies on top.

## How a form is registered

`scripts/what_stinks/hunter_forms.gd` (`HunterForms`) is the registry: eleven keys, one file each in
`scripts/what_stinks/forms/<key>.gd`. **A form worker edits only its own file.** The registry, the
settings and the match card never change when a form is finished.

A form file is a `RefCounted` with three static functions:

| Function | What |
|---|---|
| `ready() -> bool` | `true` once the form plays end to end. The match card lists only ready forms, and a pick that is not ready plays as the Drowned Shark. |
| `sheet() -> Dictionary` | The sheet below. Missing keys take `HunterForms.DEFAULTS` (the shark's numbers). |
| `dress(fish, sheet)` | Optional extras after the fish wears the form's class/species and size is applied: a model swap, a rig fed from the fish's velocity and turn, extra nodes. Runs every round, so it must be safe to run twice on one model. If it swaps the model, the bite refreshes its model afterwards (`HunterBite.refresh_model`). |

`HunterForms.sheet(key)` returns the sheet with every key filled in plus `key` and `ready`.

## The sheet's keys

| Key | Meaning |
|---|---|
| `name` | The card's name for it. |
| `class`, `species` | The `FishCharacter` class and species it wears. Titans: `TITAN`, species 0-4 (humpback, orca, beluga, sperm, blue). The shark and bosses: `MONSTER`. The hitbox is per class, not per species: a form with another body shape needs its own hidden class (or a per-species hitbox in `FishCharacter.hitbox_size`). |
| `length_m` | Its length at size 1 (m). Body scale = this over the class's hitbox length. |
| `speed`, `accel`, `turn` | Multipliers on the tuned swimming at size 1 (as the Titans' `whale_*`). |
| `bite_reach_m` | The bite's reach from the mouth at size 1 (m). |
| `bite_radius_m` | The bite's half width at the far end at size 1 (m). |
| `bite_wind`, `bite_every` | The wind-up (s) and the cooldown between bites (s). |
| `capacity` | Fish one bite takes at size 1 (x size^`bite_capacity_exp`). |
| `cam` | `Vector2(distance, height)` factors on the camera, on top of the size framing (`HunterSize.frame`). A 40 m oarfish is framed differently from a 7 m whale: raise `x` to pull back. |
| `cam_settle` | Optional. A multiplier on the follow camera's Settle rate (default 1): under 1 and the view follows the nose slower, so a form whose stride sweeps are big does not wobble it (the Fallen Angel's is 0.65). |
| `attack` | The attack style (`HunterAttack.STYLES`): `chomp` (default), `engulf`, `lock`, `suction`, `coil`, `drill`. |
| `open_s` | Seconds from the press to fully open jaws (default 0.12). A release before the jaws are open from at least `tap_open_min` open strikes at once (tap). |
| `charge_s` | Seconds of hold to a full charge (default 1.2). There is no max hold. |

## What `hunter_size` moves (one dial, `size_mult` 0.25-30; a fish's own `size_mult` meta multiplies on top)

Model and hitbox x s; bite reach and radius x s^`bite_reach_exp`; capacity x s^`bite_capacity_exp`; top speed,
boost push x s^`speed_exp`; thrust x s^`accel_exp`; turn x s^-`turn_exp`; camera distance and height in
proportion (`cam_frame`); the schools' alarm radius x s^`alarm_exp` (all schools take the biggest Hunter's).
`sight_exp` (murk sight) has no consumer until the Hunter's murk view is built. The match card has a Size pick
(0.5x to 10x); the panel takes any value. It applies from each round's start.

## Checklist before `ready()` returns true

1. `tests/hunter_forms_probe.tscn` passes with the form ready (it runs every ready form at 0.5x, 1x, 3x, and through a real match).
2. Looked at: `--shots=DIR` framing and jaw shots (needs a window). The model reads right close up and at the size's extremes.
3. Camera `cam` chosen by eye, hitbox matches the model's length (the probe checks the model is 0.7-1.5x the hitbox length), swim reads from the controller's speed and turn (not boss AI), eyes and murk look, stand-in sounds.

## The forms

| Key | Name | Class / species | State | Signature (attack style: press opens, hold charges, release shuts; tap = old snap) |
|---|---|---|---|---|
| `drowned_shark` | Drowned Shark | MONSTER / 0 | **ready** | **Chomp** (`attack: chomp`): held jaws open wider and reach further, release is the chomp |
| `humpback` | Humpback | TITAN / 0 | **ready** | **Engulf** (`engulf`): hinged baleen mouth, fish that swim in are held, release eats them |
| `orca` | Orca | TITAN / 1 | **ready** (first-guess sheet) | Engulf, toothed mouth |
| `beluga` | Beluga | TITAN / 2 | **ready** (first-guess sheet) | Engulf, toothed mouth |
| `sperm` | Sperm Whale | TITAN / 3 | **ready** (first-guess sheet) | Engulf, toothed mouth |
| `blue` | Blue Whale | TITAN / 4 | **ready** (first-guess sheet) | Engulf, baleen mouth |
| `king_of_herrings` | King of Herrings | MONSTER (own box needed) | **ready** | **Coil** (`coil`): the hold tightens the body, release whips the head through a sector |
| `gulper_mother` | Gulper Mother | MONSTER | **ready** | **Suction** (`suction`): the hold pulls fish and prey toward the mouth, release snaps a sphere |
| `whale_fall` | Whale Fall | MONSTER | **disabled** (`ready()` false) | Hagfish knot / lash: not built (out of scope, behind its flag) |
| `lamprey_queen` | Lamprey Queen | MONSTER | **ready** | **Drill** (`drill`): the hold winds the body back, release is a corkscrew dash through a tube |
| `fallen_angel` | Fallen Angel | MONSTER | **ready** | **Lock** (`lock`): the press needs a fish in reach, the hold locks it (pace match, auto-face, orbit), release lashes the line through it |
| `ember_octopus` | Ember Octopus | MONSTER | **ready** (new 2026-11-08, first-guess sheet) | **Whip** (`whip`): the hold coils and locks up to 8 arms onto fish ahead, release lashes them, nearest first |
| `lantern_angler` | Lantern Angler | MONSTER (generic box, thinner than the globe) | **ready** (new 2026-11-08, first-guess sheet) | **Lure** (`lure`): the hold lights the esca and draws bots and prey in (resistable, a dash breaks it), release snaps the jaws |

Every number below is a first guess for play-testing. Each style is a file in `scripts/what_stinks/attacks/`
(`HunterAttack.STYLES` maps the sheet's `attack` key), the shared hold, charge and cost machinery is
`HunterBite`, and the beats (sound, rumble, hit-stop, sparks) are `HunterBiteFx`. The whole design is
`two-stage-attack.md`; the style numbers are panel settings (groups Bite, Engulf, Lock, Suction, Coil, Drill).

The five bosses use `BossMesh`/`SpineRig` (one mesh bent by a shader from the spine), which a controller cannot
drive without a `SpineRig` fed from the fish's velocity and turn: the long pole. Phase 0's fallback is the same
hidden-class approach with a model node wrapping the BossMesh, built in `dress`.

## Drowned Shark (`forms/drowned_shark.gd`)

**Bite, two-stage (Chomp).** `attacks/chomp_attack.gd`, the default style. The press opens the jaws (`open_s` 0.12), the hold charges (full at `charge_s` 1.2 s, no max hold) and widens the catch: reach x`hold_reach_mult` 1.5, capacity x`hold_capacity_mult` 2.5 at full charge; holding costs swim speed, turn, school alarm and cooldown (Bite group). The release slams shut. A tap is the old instant snap (`bite_mode` tap restores it everywhere). The shark pull-back (spec 4a) is not built. Probe: `two_stage_bite_probe`.

## Humpback (`forms/humpback.gd`)

TITAN / species 0, 6.7 m. Model, swim (from the controller's speed and turn), hitbox and eyes are the Titan's own; `dress` does nothing.
Signature, **Tail Slap**, as a shape of the Bite: reach 2.2 m, half width 2.6 m at the far end (about a 100 degree cone, wider
than the Shark's 3.5 / 1.6), capacity 6 (Shark 4), wind-up 0.95 s, cooldown 2.4 s; speed x1.15, accel x0.6, turn x0.5 (slower than
the Shark's 1.3 / 0.7 / 0.55). Camera `cam` (1.2, 1.1): further back and a little higher. All first-guess defaults, not tuned.
Probe: `hunter_forms_probe` passes 386/386 with it ready (reach/radius/capacity follow size; camera 2.5 body lengths at every size).
Not done: a real tail-slap animation (the bite still opens the jaw), stand-in audio ids, a screenshot review of the wide cone.

**Bite, two-stage (Engulf).** All five whales share one style (`attacks/engulf_attack.gd`) and one hinged `WhaleJaw` on the Titan model (opens to `whale_gape_deg` 80, with tongue, roof and throat, baleen for Humpback and Blue, teeth for Orca, Beluga and Sperm; Marco Polo whales stay jawless). The press opens the mouth; school fish inside the mouth box (`engulf_box_len` 1.5 x `engulf_box_width` 0.6 reaches) are held by `School.hold` and ride there; the release eats them (Clean Sweep) or, in Upset Stomach, spits a prey player. A full mouth (`engulf_max_mult` 2 x capacity) stays open and strains. Sheet numbers (size 1, first guesses): Humpback reach 2.2, capacity 6; Orca 3.6 m long, reach 1.2, capacity 4; Beluga 2.2 m, reach 0.75, capacity 3; Sperm 7.7 m, reach 2.5, capacity 5; Blue 12 m, reach 4.0, capacity 9 (all `bite_wind` is the tap's old value). Orca, Beluga, Sperm and Blue are `ready()` since 2026-11-07 (the earlier "stub" status is out of date); their looks and numbers are unreviewed in play. Probe: `whale_engulf_probe` (133), `school_hold_probe`. Not done: guests do not see held fish riding in the mouth; the jaw is a thin belly patch with no upper-jaw lift; the throat swell has not been seen in play.

## King of Herrings (`forms/king_of_herrings.gd`, `king_rig.gd`, `king_jaw.gd`): ready

- **Body.** Hidden `MONSTER` class (the shark's box), the shark model hidden, `KingRig` child of the visual: BloodLeviathan's mesh (one spine-bent mesh, oarfish skin, crest, oars, jaw, milky eyes, lampreys) rebuilt at the hitbox's length (`GIRTH_OVER_LENGTH` 0.095, stockier than the boss) and laid along the trail the head leaves (`SpineRig.follow_trail`), so it bends through turns. Length 16 m at size 1 (the boss is ~109 m). Rebuilt when the size changes; the trail clears on a teleport.
- **Swim.** The shader's wave amplitude follows speed and turn rate (`_swim_look`); the bend is the trail's. Bite pose: the visual's lift/saw moves the head and twists the spine.
- **Bite: Coil sweep.** reach 5.5 m, radius 4.5 m (39 degrees half angle, the shark's is 25), capacity 7, wind-up 1.0 s, 2.8 s between bites. Jaw = the skin's hinge (`KingJaw` for `HunterBite`), `warn` pulse during the wind-up.
- **Camera.** `cam` (0.8, 1.35): closer (a slim body is a small share of the screen) and higher. By eye only through a free-camera shot, not play-tested.
- **Sound ids (stand-ins, sheet keys).** `sound_chomp` boss/chomp (played at the mouth when the bite lands, by `KingRig`), `sound_arrive` boss/leviathan_arrive, `sound_miss` boss/chomp_miss, `sound_grab` boss/grab (last three have no consumer yet).
- **Eyes/murk.** Pale milky eyes with a faint glow so they read in the murk; the Hunter murk view itself is not built.
- **Known.** The hitbox is the MONSTER box scaled to 16 m (5.3 m wide, 7.4 m tall), much fatter than the 2.6 m body: a per-form box is the fix. The shared `hunter_forms_probe` measures model extent from placed mesh boxes and does not call `HunterForms.dress`, so it cannot see this body; `tests/king_probe.tscn` does (81 checks).
- **Bite, two-stage (Coil).** `attacks/coil_attack.gd`. Press starts the coil, the hold tightens it (the rig curls through `coil_curl_deg` 300 and cocks the head aside), release whips the head round a pivot `coil_pivot` 0.45 reaches behind the mouth. The catch is a flat sector from the pivot, `coil_arc_min` 45 degrees at no charge to `coil_arc_max` 160 at full, `coil_thick` 0.5 reaches thick; contact is the head crossing the middle. Capacity x`coil_capacity_mult` 1.5 with the charge, reach unchanged. The earlier wind-up / snap description above is the tap path. Probe: `coil_whip_probe` (53). Not seen visually (no windowed shots).


## Gulper Mother (`gulper_mother`): ready

Registered file `forms/gulper_mother.gd` (the registry loads it by key; the brief called it `gulper.gd`). Extra files, all in `forms/`: `gulper_model.gd` (the look), `gulper_rig.gd` (the body's driver), `gulper_jaw.gd` (the mouth for `HunterBite`). Probe: `tests/gulper_form_probe.tscn` (79 checks; `--shots=DIR` needs a window), plus `hunter_forms_probe` picks it up automatically (386/386).

| Part | What |
|---|---|
| Class / box | `MONSTER`, species 0: the shark's hidden box (1.2 m long at scale 1). `dress` hides the shark's parts on the model and adds the Gulper's rig on it. |
| Sheet (size 1) | 9.0 m long, speed 1.15, accel 0.6, turn 0.5 (slower and heavier than the shark's 7 m, 1.3, 0.7, 0.55). Camera `Vector2(1.15, 1.1)`: a bit further back and higher for the pouch. |
| Swallow (the bite's shape) | Reach 6.0 m, far half width 4.0 m (radius over reach 0.67, about 34 degrees; the frustum is a quarter of that at the mouth, about 1 m, as wide as the pouch), capacity 8, wind-up 1.0 s, rest 2.5 s. Against the shark's chomp (3.5 m, 1.6 m, 4, 0.75 s, 2.0 s): deeper, wider, takes twice the fish, opens slower. The tell is the pouch gaping and the suction streaks. |
| Look | `GulperBoss._build_look` (BossMesh, boss_gulper.gdshader, black eyes, glowing lure) rebuilt at the boss's own girth unit 1 (the skin shader has metres in it, so the mesh is built at boss scale and `GulperRig` scales its node down to the box: 0.97 of the box's length). Model length is 0.97x the hitbox at every size. |
| Swim | `GulperRig._process` reads the fish: yaw and pitch rates give each of 48 spine segments a lag (the body trails a turn: tail 0.5-0.8 of the body length off the axis in a hard turn), speed sets the undulation's amplitude (`wave_idle` to `wave_swim`). Works on puppets too (it measures the fish's motion, not its inputs). Tuning: `follow_rate`, `wave_idle`, `wave_swim`, `wave_full_speed`, `gape_idle` (exports on the rig). |
| Mouth | `GulperJaw` (a `HunterJaw`): `mouth_local()` is the pouch's opening, `pose(open)` hands the bite's open to the rig, which gapes the skin shader (0.15 to 1.25) and turns the suction streaks on above 0.3. |
| Eyes, murk | Beady black eyes from the boss. No murk view for Hunters yet (`sight_exp` has no consumer). The lure is a pink point light (range 0.3 x body length) that glows in the dark. |
| Audio | None yet; stand-ins to use when the forms get sounds: the boss's `gulper` gulp/suck ids. |
| Not built | The "pull": the cone does not drag school fish or prey toward the mouth during the wind-up (needs a `School` pull call, or a push on prey players; both in shared files). Swallowed fish do not show as lumps in the belly (the shader's `lump`/`fullness` are left at rest). Hit area and bite use the shark's box, not a form-shaped one. |

**Bite, two-stage (Suction).** `attacks/suction_attack.gd` + `School.pull`. While the button is held, school fish in the cone (`suck_cone` 35 degrees) are drawn to the mouth and prey players are pushed (`suck_prey_push`); reach and pull rise with the charge (`suck_reach_mult` 2.5 at full, never under `suck_reach_min` 0.4 of reach). The release catches a sphere of `gulper_mouth_r` 0.7 bite radii at the mouth (tap mode keeps the old frustum). `GulperRig` drives the skin's fullness and slides a belly lump after the snap (`suck_lump_s`, `suck_lump_size`). The "Not built" row above is now built except per-fish lumps (one lump sized by the count) and a rising-pitch loop. Probe: `gulper_suction_probe` (40). Open: the pull may be weak against a fleeing school.

## Lamprey Queen (`forms/lamprey_queen.gd`, `lamprey_rig.gd`, `lamprey_jaw.gd`): ready

Registered file is `forms/lamprey_queen.gd` (the registry loads it by key; the brief called it `lamprey.gd`). Probe: `tests/lamprey_form_probe.tscn` (86 checks, `--shots=DIR` needs a window), and `hunter_forms_probe` picks it up automatically (467/467).

- **Body.** Hidden `MONSTER` class (the shark's box), the shark's parts hidden, `LampreyRig` child of the visual: `LampreyBoss._build_look` (one spine-bent mesh, boss_lamprey skin, 7 gill holes a side, oral disc of hooked teeth round a rasping tongue, fins, yellow eyes, nine brood clamped on) rebuilt at the hitbox's length (`RADIUS_OVER_LENGTH` 0.06, stockier than the boss) and laid along the trail the head leaves (`SpineRig.follow_trail`). 14 m at size 1 (the boss is ~88 m). Rebuilt when the size changes.
- **Swim.** The skin's wave amplitude follows speed and turn rate; the bend is the trail's.
- **Bite: Corkscrew latch.** reach 3.2 m, radius 1.0 m (about 17 degrees, the shark's is 25), capacity 1 (one target; x size^1.5 at larger sizes), wind-up 0.8 s, 3.0 s between bites. The disc flares through the wind-up (`LampreyJaw` hands `open` to the skin's `disc`), `warn` pulses; when the bite lands the disc clamps and she rolls round her length at `lamprey_spin` (the boss's setting) for `latch_s` (sheet, 1.1 s), then rights herself.
- **Camera.** `cam` (0.9, 1.3): further back and higher so the trailing body shows. Probe: 2.1 body lengths at every size. By eye through a free-camera shot only.
- **Sound ids (stand-ins).** `sound_chomp` boss/grab (played at the mouth when the bite lands), `sound_arrive` boss/leviathan_arrive, `sound_miss` boss/chomp_miss (the last two have no consumer yet).
- **Eyes/murk.** Small yellow eyes behind the disc with a faint glow; the Hunter murk view is not built.
- **Known.** The hitbox is the MONSTER box scaled to 14 m (4.7 m wide), fatter than the 1.7 m body; a per-form box is the fix. The latch is a visual roll only: it does not pin the prey or drain it (the bite still takes the fish as any bite). `hunter_forms_probe` does not call `dress`, so `lamprey_form_probe` is the check for the body.
- **Bite, two-stage (Drill).** `attacks/drill_attack.gd`. The hold winds the body back and speeds the rasp; a release at charge 0.2 or more (`drill_min_charge`) is a corkscrew dash at `drill_dash` 2 x top speed x charge for `drill_time` 0.6 s, taking what the disc passes through (tube `drill_radius_mult` 1.5 bite radii) up to capacity x`drill_capacity_mult` 6 x charge. At full charge the first prey player met latches her (`drill_latch`): the dash ends and she rolls on it. A tap is the old latch roll. The body ram is held off during the dash (`suppresses_ram`). Probe: `drill_probe` (38). Not seen visually.

## Whale Fall (`whale_fall`): disabled

Registered file `forms/whale_fall.gd` (the registry loads it by key; the brief called it `whalefall.gd`). Extra files, all in `forms/`: `whalefall_model.gd` (the look), `whalefall_rig.gd` (the body's driver), `whalefall_jaw.gd` (the mouth for `HunterBite`). Probe: `tests/whalefall_probe.tscn` (88 checks; `--shots=DIR` needs a window), plus `hunter_forms_probe` picks the form up when it is ready.

| Part | What |
|---|---|
| Class / box | `MONSTER`, species 0: the shark's hidden box. `dress` hides the shark's parts on the model and adds the rig on it (once per model: a second `dress` only refreshes the sheet). |
| Sheet (size 1) | 12.0 m long, speed 0.9, accel 0.5, turn 0.45 (a heavy drifter; the shark is 7 m, 1.3, 0.7, 0.55). Camera `Vector2(1.25, 1.15)`. |
| Hagfish knot (the bite's shape) | Reach 4.5 m, far half width 3.6 m (about 39 degrees), capacity 6, wind-up 0.9 s, rest 2.6 s. Against the shark's chomp (3.5 m, 1.6 m, 4, 0.75 s, 2.0 s): short and wide, takes more, slower to open. The tell is the hagfish rearing back and glowing. |
| Look | `WhaleFallBoss._build_look` (BossMesh, boss_whale.gdshader: torn chest, flank wound, eye sockets, blowhole; hagfish from `WhaleFallBoss._hagfish_mesh`, boss_hagfish.gdshader) rebuilt at the boss's girth unit 1 (45 units long) and scaled to 0.97 of the box's length. The model is 0.99x the hitbox's length at every size. Six hagfish (`ropes`, 0-6) come out of the eye sockets, chest, flank wound and blowhole. |
| Swim | The carcass is rigid (as the boss's): it rocks and leans into turns (`rock_idle`, `rock_swim`, `lean`). The hagfish stream back with speed and lag the turn (`stream`, `sway`), read from the fish's motion (works on puppets). All exports on the rig. |
| Bite | `WhaleFallJaw` (a `HunterJaw`): `pose(open)` only hands the open on. Wind-up: hagfish rear back, glow (`warn`). As the jaws shut they lash into the cone (`lash_time`), tie a knot that slides down their length (`knot_time`), and a slime cloud is let go at 0.7 of the reach (`cloud_life`), with the stand-in `boss/leviathan_spit` sound. About 5 of the 6 heads end in the cone. |
| Scatter hook | The rig emits `slimed(at, radius, life)` and sets meta `hunter_cloud` on the model (the rig: `cloud_at`, `cloud_radius`, `cloud_left`). The cloud is only visual so far: making schools and prey flee it needs the mode to read this (a shared change). |
| Eyes, murk | The sockets are the hagfish's holes; a dull green `Gloom` light from the chest (range half the body's length). No murk view for Hunters yet (`sight_exp` has no consumer). |
| Audio | Stand-ins in the sheet: `sound_slime` boss/leviathan_spit (played at the cloud), `sound_grab` boss/grab and `sound_arrive` boss/leviathan_arrive (no consumer yet). |
| Not built | Prey held and reeled in by a hagfish (the boss's grab); the cloud does not yet scatter fish or slow prey; the hitbox is the shark's box, not carcass-shaped; no look at the shots (free-camera framing, the carcass's roll onto its side) by eye. |

**Status 2026-11-07.** Disabled (`ready()` false, the boss skipped by `UnnaturalRun.DISABLED_BOSSES`). Its two-stage lash (two-stage-attack.md 4g) was explicitly out of scope and is **not built**; it plays as the default chomp style if forced ready (`whalefall_probe` still fails 7 checks for the disabled form).

## Fallen Angel (`fallen_angel`): ready

Registered file `forms/fallen_angel.gd` (the registry loads it by key; the brief called it `angel.gd`). Extra files in `forms/`: `angel_model.gd` (the look), `angel_rig.gd` (the body's driver), `angel_jaw.gd` (the crown as the bite's mouth). Probe: `tests/angel_form_probe.tscn` (88 checks; `--shots=DIR` needs a window), and `hunter_forms_probe` picks it up automatically (629/629 with it ready).

| Part | What |
|---|---|
| Class / box | `MONSTER`, species 0: the shark's hidden box. `dress` hides the shark's parts on the model and adds the angel's rig on it (once; a second `dress` is a no-op). |
| Sheet (size 1) | 10.0 m long, speed 1.2, accel 0.65, turn 0.7 (light and agile). Camera `Vector2(1.1, 1.15)`: a little back and higher. |
| Lock-on (the bite's shape) | Reach 6.5 m, far half width 1.3 m (radius over reach 0.2, about 11 degrees), capacity 2, wind-up 1.2 s, rest 2.2 s. Against the shark's chomp (3.5 m, 1.6 m, 4, 0.75 s, 2.0 s): longer, much thinner, half the fish, slower to open. It is aim, not sweep. |
| Look | `FallenAngelBoss`'s own glass body, orange organs, horns, wings and six crown tentacles (the boss's static mesh helpers and shaders, built at the boss's 40 m unit and scaled to the box: 0.97x the hitbox's length). Glass and organs are one spine-bent mesh each. |
| Swim | `AngelRig._process` reads the fish: yaw and pitch rates make each of 48 spine segments lag (the body trails a turn), speed sets the wave's amplitude and the wingbeat (0.8 to 2.4 beats a second, `beat_idle`/`beat_swim`). Works on puppets (it measures the fish's motion). |
| Crown and tell | `AngelJaw` (a `HunterJaw`): `pose(open)` hands the bite's open to the rig, which opens the six tentacles out of the top of the head, flushes them orange, warms the organs and the crown light, and draws a lock-on ring (a torus) on the cone's far end, closing from 1.6x to 1x its width. When the bite lands the tentacles lash forward for `lash_time` (0.45 s). The ring is the cone's honest edge, not the target. |
| Mouth | The crown's base, a little ahead of the hood, so the cone starts at the front of the body. |
| Eyes, murk | No eyes (the boss has none): the orange head and gut glow through the glass and an orange point light (range 0.6 x length) rides the crown. No murk view for Hunters yet. |
| Audio | Sheet keys `sound_chomp` boss/chomp, `sound_lock` boss/angel_lock (not an existing id), `sound_miss` boss/chomp_miss: stand-ins, no consumer yet. |
| Not built | "A fish it has watched": the bite does not track or reward a watched target (a watch-time bonus would need the bite or the field to read a lock state, both shared files). The shapes carry the idea: a narrow cone you have to hold on a fish. The hit area is the shark's box (wider and taller than the glass body). Wings and ring were looked at in free-camera shots only; the Hunter murk look is not built. |

**Bite, two-stage (Lock).** `attacks/lock_attack.gd`. The press only opens when a prey fish is inside `angel_lock_range` 2 reaches and `angel_lock_cone` 40 degrees (else a short denied beat). The hold locks the nearest fish: it matches the school's pace (`angel_close_speed` 14 to reach the stand-off `angel_standoff` 0.7 reaches), auto-faces it (`angel_face_rate`), and the stick orbits (`angel_orbit_speed`). A ring and line sit on the target with an "xN" preview of the count. The release lashes a line through the target (`angel_lash_speed` 40): fish taken = capacity x `angel_count_mult` 3 x the facing share (how squarely the Angel faces the mass of the target's school, with `angel_charge_weight` 0.3 of the share from the charge), at least the target; the camera's lock-on bite on the same school multiplies on top. It breaks if the target leaves `angel_break_range` 3.5 (cooldown `angel_break_cooldown`). The "Lock-on" bite shape row above is the tap path. Probe: `angel_lock_probe` (71). Needs a windowed look at the ring, line and label.

## Ember Octopus (`ember_octopus`): ready

`forms/ember_octopus.gd` (sheet, dress), `octopus_rig.gd` (gait), `octopus_model.gd` + `shaders/octopus_skin.gdshader` (body; `octopus_contract.md` is its API), `attacks/whip_attack.gd` (Tendril Lash) + `forms/octopus_whip_fx.gd`.

- Sheet: class MONSTER, 6 m, speed 1.15, accel 0.45, turn 0.6, reach 3.4 m, radius 2.6 m, wind 0.85 s, every 2.4 s, capacity 5, camera (1.05, 1.2), attack `whip`.
- Gait: jet pulse (arms bundle forward on the power stroke, flare on recovery; thrust and off-centre torque applied in the fish's physics tick), cruise scull, dash jet (x1.8, arms bundled), crawl within `octopus_crawl_range` body lengths of a floor (sucker feet plant and step), air-roll aware (stick x is roll when air roll is held). A frozen body (card preview, countdown) runs the jet clock on the frame.
- Attack, Tendril Lash: press flares the arms into a crown and locks up to `whip_arms` prey (nearest first inside `whip_cone` degrees and `whip_range` reaches, one arm each); hold coils tighter with the charge (reach x`whip_charge_reach`, fish per arm x`whip_charge_capacity`); release whips the arms out on homing curves 30-60 ms apart and each arm is judged as it arrives; the octopus is pushed back `whip_recoil` m/s per arm that lands (a miss a share of it, capped by `whip_recoil_cap`). A lash with nothing locked still whips `whip_whiff_arms` front arms. Arms reel back onto the gait pose with no pop.
- Online: no lock list is sent; puppets and guests run the same lock and timeline from the synced bite beats, the host judges every arm.
- Attack exaggeration: the mantle squashes and pops, arms stretch up to `whip_stretch`, hit-stop and camera punch from `hunter_exaggeration`.
- Probe: `octopus_match_probe` (registry, settings, docs, sounds, a player match with jets and a lash, a bot match, a puppet's bite).

## Lantern Angler (`lantern_angler`): ready

`forms/lantern_angler.gd` (sheet, dress), `lantern_rig.gd` (gait), `angler_model.gd` + `shaders/angler_skin.gdshader` (body; `angler_contract.md`), `attacks/lure_attack.gd` + `lure_field.gd` (the Lure).

- Sheet: class MONSTER, 6 m, speed 1.1, accel 0.55, turn 0.5, reach 3.2 m, radius 2.2 m, wind 0.9 s, every 2.6 s, capacity 5, cam (1.0, 1.2), attack `lure`.
- Gait: stiff body, slow pectoral scull, tail snap on bursts of acceleration, spring-chain lure stalk; settings `angler_*` (Lantern Angler group).
- Attack, the Lure: press flares the esca and gapes the jaw and starts the attraction field; hold ramps a resistable drift on prey in the light cone (bots also steer toward it; a dash breaks it; HUD captivated vignette); release snaps shut. Settings `lure_*`.
- Online: puppets run the same lure from synced bite beats; each machine moves the prey it owns.
- Probe: `angler_match_probe` (registry, settings, docs, sounds, a player match with a held lure pulling prey, resist and dash, a bot match, a puppet's bite).

## Attack exaggeration (`attack_exaggerate.gd`, the Exaggeration / Shark / Whales / King and Lamprey bodies / Preview setting groups)

Every ready form's bite is drawn bold (Battletoads style): the press squashes a part (anticipation), the hold swells it past rest, the release snaps it, and a landing freezes the rig for a few frames and punches the camera. `AttackExaggerate` is the shared driver: per-channel scale curves (jaw, limb, throat, head, tail, eyes), smear, hit-stop and a camera-margin helper. Each form keeps its own preset (its rig's `EXAGGERATE` table, or a sheet key `exaggerate` Dictionary merged into the kit's params, e.g. `{"channels": {"jaw": {"hold_peak": 2.6}}}`). The sheet key `exaggeration` (float, default 1) is the form's own multiplier. All effective values are the preset x `hunter_exaggeration` x the form's `exaggeration`; 0 is exactly the old look.

Shared settings: `hunter_exaggeration` 1 (0-4), `hunter_hit_stop_frames` 2.5 (0-12), `hunter_camera_punch` 0.5 (0-5), `hunter_exaggerate_squash` 1 (0-3), `hunter_exaggerate_smear` 0.05 (0-0.5), `hunter_exaggerate_max_scale` 3.5 (1-8). The follow camera pads its collision margin with the rig's `camera_margin(radius)` (not wired yet, see below).

| Form | What departs from rest (at hunter_exaggeration 1) | Form settings |
| --- | --- | --- |
| Drowned Shark | jaw 2.2x hold / 0.7x snap, head 1.8x hold / 2.4x snap, teeth 1.9x / 2.5x, eyes 1.8x / 2.3x; snap_omega 32, snap_time 0.09 | `shark_jaw_gape`, `shark_head_thrust`, `shark_body_stretch`, `shark_teeth_gain`, `shark_eye_flare` |
| Whales (humpback, orca, beluga, sperm, blue) | jaw gape up to 2.2x, soft-limited at `whale_gape_max_deg` 135; head/tail body pulse; throat balloon; baleen/teeth pop; shut-jaw rebound; 3-tick hit-stop | `whale_gape_max_deg`, `whale_rebound_deg`, `whale_body_pulse`, `whale_throat_balloon`, `whale_tooth_pop` |
| King of Herrings | coil +166 deg curl with lift, gape 2.2x, eyes 1.7x, tail 1.5x stretch with smear and whip lag, 3-frame hit-stop, camera punch; the coil unwinds over strike + shake | `king_whip_stretch`, `king_coil_tighten`, `king_whip_lag`, `coil_press_floor` |
| Lamprey Queen | disc 1 to 2.1x lip at hold, 2.6x at the release snap; body 0.72 on hold, 1.86 peak on release (cap 1.9); teeth 0 to 14 rad/s on hold, plus 14 rad/s through the dash | `lamprey_disc_flare`, `lamprey_teeth_spin`, `lamprey_telescope_max`, `lamprey_dash_stretch/flare/spin`, `lamprey_lunge_impulse` |
| Gulper Mother | jaw pouch gape pinch -0.22, hold sail about 2.7 (x2.3 jaw), release clamp; body girth 1.14 puff, 0.7 deflate, 1.3 rebound; gulp bulge x2.4 ringing plus 0.6 x strength | shared only |
| Fallen Angel | jaw/crown hold 1.9 / squash 0.6 / release 1.5 (the lash on contact up to 2.4x); limb/wings 1.5 / 0.7 / 1.85; throat/ring+glow 1.15 / 0.82 / 2.3; head/body lunge 1.08 / 0.86 / 1.28; tail unchanged; hit-stop 3 ticks, camera punch 0.7 | shared only |

Other tuning from this pass: `body_stiffness` 0.4 (0 old floppy, 1 rigid bar; King and Lamprey bodies), `lamprey_lunge_impulse` 0.55 (the corkscrew dash's speed as a multiple of the old lunge). The card's Hunter preview (`hunter_preview.gd`) swims every form on a real fish, so each form's dress hook also runs on a frozen fish with `controls` null and must be safe there; `preview_throttle` 0.75, `preview_speed` 1, `preview_wander` 1.

Known gaps: the kit is not hooked into `hunter_bite_fx.gd` (each rig drives its own kit from HunterBite signals); `what_stinks_cam.gd` does not yet use `camera_margin()` or the kit's `camera_punch` (so a landing may punch twice only if both are wired later); the double punch is tuned by `hunter_camera_punch`.
