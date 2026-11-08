# Plan: Two-stage attacks (What Stinks? Hunters)

## Context
Every Hunter form attacks with one press today: `HunterBite` sees the button go down and plays a whole
`ChompKit.Bite`. With `bite_snap` on (the default) the jaws are already wide and slam shut on the same
press, so there is no wind-up at all.

The change: **press opens, release closes.** The attack becomes a held move. For the shark, the press
opens the jaws and the release shuts them. You can hold them open while you plough through a school, and
a longer, better-timed hold can take more fish. Every form gets its own version of the same two beats:

| Form | Press (open) | Held | Release (close) |
|---|---|---|---|
| Drowned Shark | Jaws gape, head lifts | Jaws held wide, trembling; the charge builds reach and capacity | Lunge and slam shut |
| Whales (Humpback, Orca, Beluga, Sperm, Blue) | A huge Battletoads-style mouth drops open | Anything that swims into the mouth is held in it, no way out | The mouth slams shut and swallows all of it |
| Fallen Angel | Only near a fish ahead: the buccal cones open and it fully locks onto the nearest fish | It matches the target's pace and keeps facing it; the stick orbits it | The cones lash out. How squarely it faces the target's school at release sets how many fish go |
| Gulper Mother | The pouch balloons open | Suction pulls fish toward the mouth | The pouch snaps shut on what's in it |
| King of Herrings | The body starts to coil, head drawn back | The coil tightens | The whip-sweep, wider the longer it was coiled |
| Lamprey Queen | The disc flares and the teeth spin up | The rasp speeds up | A corkscrew dash that drills through what it hits |
| Ember Octopus | The eight arms start to coil, mantle glows | Charge builds, arms lock onto fish ahead (up to 8) | The arms unroll and lash onto their locks, nearest first |
| Lantern Angler | The esca flares, eyes flash | Light draws bots and prey in (resistable drift, a dash breaks it) | The jaws snap on what was drawn in |
| Whale Fall (disabled) | The hagfish rear back | More hagfish rear as you hold (1 to 6) | They lash out, one fish per hagfish, and a slime cloud the size of the charge |

The rule above everything else: **every beat must be seen, felt and heard on the same tick.** The press
answers on the frame it lands, the hold has a living loop, and the release has a hard contact frame.
See section 3.

## 1. Where things stand (checked 2026-11-07)

- `scripts/what_stinks/hunter_bite.gd` (`HunterBite`): `_physics_process` detects a press edge
  (`_pressed()` reads `fish.jump_held` etc.) and calls `try_bite()`, which calls `_begin()`. With `snap` it
  does `bite.strike_now()`; without it, `bite.start(bite_wind)`. `chomped(mouth, reach, radius, capacity)`
  fires on the contact tick (`_land`), which also starts the cooldown and punches the camera. It drives the
  jaw (`HunterJaw.pose(open)`, `set_overshoot(over)`) and the head's lift and saw from the Bite every tick.
  There is no notion of a release.
- `scripts/unnatural/chomp_kit.gd` `ChompKit.Bite`: the phases are `IDLE, ANTICIPATE, GAPE, HOLD, STRIKE,
  SHAKE, RECOVER`, each with a timed length. HOLD always times out into STRIKE. `cue(name)` fires on each
  beat and on `contact`. It is shared with the Unnatural bosses (Drowned Shark, Blood Leviathan) and the
  Drowned Jaws item, **so they must not change behaviour.**
- `WhatStinksMatch._on_chomp` judges the bite: the plain frustum (`HunterBite.in_frustum`) or the lock-on
  bite (`_locked_bite`: facing, closeness and speed give a share of `capacity x lock_bite_mult`). Both go
  through `_judge_bite` and then `WhatStinksField.eat_at(point, capacity, inside, extra, only)`.
- Online (`scripts/net/what_stinks_net.gd`): `bite_started` is sent as `_ws_bite_started`, so puppets call
  `bite.net_start()` (pose only). A guest's own landing goes as `local_bite(mouth, forward)` and the host
  judges it in `judge_net_bite`. There is no message for a release.
- Bot (`what_stinks_bot.gd`): presses `jump` for one tick when a fish is within `hunter_bot_bite_share` of
  the reach.
- Form rigs hook the bite by polling `_bite.bites` (Angel) or connecting `chomped` (King, Lamprey, Gulper,
  Whale Fall). They read `bite.bite.winding()` and `open` for their tells. Sounds are stand-ins
  (`Sfx.play_at`). There is no What Stinks rumble. `ChompKit.rumble_near` needs an `UnnaturalRun`;
  `Input.start_joy_vibration` is what it uses underneath.
- Whales: `TitanModel` has **no moving mouth**. The mouth is a line painted by the skin shader
  (`mouth_s`, `mouth_a`, ...). Only the sperm whale has a separate lower-jaw mesh, and it is static. The
  Humpback's "Tail Slap" bite still has no animation.
- The Angel: `AngelRig` already opens the crown from `open`, flushes it orange, and draws a lock-on ring
  on the cone's end. `hunter_forms.md` lists "a fish it has watched" as not built.
- The Gulper: the "pull" (suction dragging fish in) is listed as not built.
- `Sfx.start_loop / set_loop(volume, pitch) / stop_loop` exist, so the held beat can have a loop whose
  pitch rises with the charge.
- HUD: `WhatStinksHud._draw_bite_ring(at, bite)` exists and becomes the charge meter.

## 2. The core: a held bite

### 2a. `ChompKit.Bite` gets an open-ended hold (opt-in, bosses unchanged)
- A new flag `held_open := false`. While it's true, HOLD doesn't time out. It loops the tremble and adds a
  slow "strain" on top as the charge rises.
- New calls:
  - `open_now(open_s, bite_reach)`: the opening beat. It's a short GAPE (and a short ANTICIPATE if the form
    wants a pull-back), then HOLD with `held_open = true`.
  - `release()`: straight to STRIKE from wherever it is. Released during the GAPE, it strikes from that
    partial open, which is what a tap does.
  - `charge` (0 to 1): seconds in HOLD over the form's `charge_s`. It's exposed for the pose, the HUD and
    the judge.
- Nothing calls these from the bosses, so `start()`, `strike_now()` and the timed HOLD stay as they are.
  The Unnatural boss probes have to keep passing.

### 2b. `HunterBite` becomes press/hold/release
- An edge on press calls `try_open()` (idle, off cooldown, in play, and the form's own gate passes: the
  Angel's proximity). An edge on release calls `try_close()`.
- **The Hunter has no jump or dodge in this mode** (D9). The bite stays on `jump`, and the Hunter's fish
  ignores jump/dodge while it is a Hunter (a flag on the controller, set and cleared with the role), so a
  press is only ever the bite.
- **Tap = snap.** Released before the jaws are fully open, it strikes at once from the partial open, so a
  quick tap still feels like today's snap chomp (D1).
- **No max hold** (D2). The jaws stay open as long as the button is held. The charge stops at 1, but
  the hold goes on. Only the costs below balance it.
- **The cost of holding** (all settings, wide ranges): swim speed x `hold_speed_mult`, turn x
  `hold_turn_mult` (an open mouth is drag), the schools' alarm radius x `hold_alarm_mult` (a gaping mouth is
  a tell), and a cooldown that grows with the hold (`bite_every + hold_cooldown_per_s x held`, capped at
  `hold_cooldown_max`). With no max hold these costs have to bite, so they are the first things to look at
  in play-testing.
- **What holding buys** depends on the form's style (2c). The default (the shark's, D3) is more capacity
  and more reach: `capacity x lerp(1, hold_capacity_mult, charge)` and `reach x lerp(1, hold_reach_mult,
  charge)`. The release lunge is fixed (the snap's).
- Signals: `opened` (replaces `started`, which is kept as an alias for one release), `charged` (charge hit
  1), `released(charge)`, and `chomped(...)` as now, with the charge added.
- `bite_snap` is replaced by a `bite_mode` setting: `hold` (the default) or `tap` (today's snap), so
  you can A/B it.

### 2c. Attack styles: one hook per form, not one class per form
Each form sheet gets `attack` (the style key) and its numbers. A small `HunterAttack` strategy object
(RefCounted, one file per style in `scripts/what_stinks/attacks/`) owns the style's rules:

| Hook | Called | Default (Chomp) |
|---|---|---|
| `can_open(bite) -> bool` | On press | Always |
| `on_open(bite)` | Press accepted | Nothing |
| `on_hold(bite, delta)` | Each tick held | Nothing |
| `catch_rule(bite) -> Dictionary` | Release contact: `{point, capacity, inside, only, extra_taken}` for `_judge_bite` | Frustum, capacity x charge |
| `on_close(bite, taken)` | After judging | Nothing |
| `bot_plan(bot, bite) -> {press, hold}` | The bot's press and release logic per style | Press close, release at once |

The styles are `chomp` (Shark, the default), `engulf` (whales), `lock` (Angel), `suction` (Gulper),
`coil` (King), `drill` (Lamprey) and `lash` (Whale Fall). `WhatStinksMatch._on_chomp` asks the style for
its catch rule instead of building the frustum itself. The lock-on bite (`_locked_bite`) still applies on
top for styles that use the frustum (D8).

### 2d. Online
- New messages: `_ws_bite_open(hunter_id)` and `_ws_bite_close(hunter_id, charge)`.
  `_ws_bite_started` is renamed to `_ws_bite_open`. Puppets call `bite.net_open()` / `bite.net_close(charge)`,
  and both are pose only.
- A guest's own release goes as today's `local_bite(mouth, forward)` plus the charge and the style's extra
  (the Angel's target id). The host clamps the charge to what it saw: the time between the open and close
  messages, plus slack.
- The engulf and suction styles collect fish over time. **The host runs that on the Hunter it sees**, the
  puppet with its mouth open from `_ws_bite_open`, and owns the list. Guests see the held fish as a pose:
  the school's fish drawn into the mouth from `eat_taken` order. The host sends the list on close.

### 2e. Bot
`WhatStinksBot` presses and holds per `bot_plan`. The chomp style opens at `hunter_bot_open_gap` and
releases when a fish is in the frustum and the charge is at least `hunter_bot_charge` (or at once if the fish
is escaping). Engulf: open on a school ahead, release when the mouth is full or the school has passed. Lock:
open only in range, release when the alignment is past `hunter_bot_lock_align`. The Upset Stomach rule
(don't bite readable prey) still gates the release.

## 3. Feel: seen, felt and heard together

### 3a. One node does it: `HunterBiteFx`
This is a child of `HunterBite`. It connects to `ChompKit.Bite.cue` and the new signals, so **every
effect fires off the same cue that moves the pose**, on the same tick, on puppets too. Nothing times its
own effect. Rigs keep their looks but drop their own `chomped` sound hooks, which move here. Each form's
sheet names its sound ids and effect strengths.

| Beat | See | Feel (Hunter's pad, its own view) | Hear |
|---|---|---|---|
| **Press** (same frame) | The jaw starts moving this tick (the GAPE eases out fast, 0.08-0.15 s, so it reads as instant). Head lift, POSE_WIDE smear, the overshoot fling | A short tick (`rumble_open`) | `open`: a creak or whoosh at the mouth |
| **Held** | Tremble, plus strain that grows with the charge. Bubbles stream from the mouth. The form's tell (crown glow, pouch, coil). The HUD ring fills | A low rumble that rises with the charge | A `hold` loop (growl, suction, rasp) whose pitch and volume rise with the charge |
| **Full charge** | A rim flash on the mouth and the HUD ring snaps to gold | One crisp pulse | `charged`: a click or ping |
| **Full mouth** (engulf only: `engulf_max` reached) | The tremble doubles, the pleats strain, the ring flashes red | A stutter | `strain` |
| **Release** | STRIKE: ease-in slam, POSE_LUNGE, the lunge push. The strike is short (`chomp_strike`) so contact lands 2-5 frames after the release | | `strike`: a swoosh |
| **Contact (caught)** | POSE_IMPACT squash, a camera punch scaled by charge and fish taken, a **local hit-stop** on the Hunter (60-120 ms, never the global time scale), blood, bubbles and tooth sparks (`ChompKit.Fx`), the callout | A hard pulse scaled by the fish taken | `chomp` / `gulp` / `lash`, layered with a pitched "crunch" per fish (`play_pitched`, rising through the chain) |
| **Contact (miss)** | Clack, small punch, a bubble puff | A short light pulse | `miss` |

- **Prey get it too.** A prey player caught by any attack (or held inside a whale's mouth) gets their own
  view's punch, rumble and vignette (`ChompKit.impact`'s pieces, re-used without the `UnnaturalRun`
  argument). A prey player within the reach while the jaws are open hears the hold loop louder and gets a
  slow heartbeat rumble. That's the "it's about to close" warning.
- **Rumble.** A small `WhatStinksRumble` (pad of the fish's own view, split-screen aware) on
  `Input.start_joy_vibration`. Bots get none.
- **Sounds.** New ids go into the sound profile list (audio plan). The stand-ins come from the existing
  `boss/*` ids until the user records them. The list is in section 6.
- **Sync check.** A probe records the tick of each pose beat and its cue, sound and rumble call, and fails
  if any lands more than one tick apart (section 7).

## 4. Per form

### 4a. Drowned Shark: chomp
- Press: the GAPE (a short ANTICIPATE first if `shark_pullback` is on), the jaw flung wide, the head lifted.
- Held: jaws wide, the tremble, the charge. The bite's frustum is drawn faintly on the HUD only while held
  (a setting), so the player can line up a school.
- Release: lunge plus slam. Capacity (`hold_capacity_mult`, default 2.5) and reach (`hold_reach_mult`,
  default 1.5) grow with the charge, so a held bite through a school takes a mouthful. The preview cone
  grows with the reach, so the player can see it.

### 4b. Whales: engulf, the Battletoads mouth
- **A real mouth for the Titans.** `TitanModel` gets a hinged lower jaw for every species, built from the
  painted mouth line (`mouth_s`, `mouth_a`, `mouth_arch`). The lower jaw is a separate mesh that hinges at
  the mouth's corner (the sperm whale's existing jaw mesh becomes its version). There's a dark-pink inside
  (a tongue and roof; baleen plates for humpback and blue, teeth for orca and sperm) and ventral pleats that
  balloon as fish go in (humpbacks do this: lunge feeding). It gets a `WhaleJaw` (`HunterJaw`) in meta
  `hunter_jaw`.
- **Exaggerated.** The jaw drops to `whale_gape_deg` (default 80, real whales open to about 90), and the
  head's smear goes far past the shark's: the head stretches tall (POSE_WIDE x `whale_smear`). The upper
  jaw lifts too. It should look comically huge, like Battletoads.
- Press: the jaw drops over 0.15 s with a big overshoot fling, and a whoosh of water rushes in (bubble
  streaks into the mouth).
- **Held: the mouth takes what comes in.** Each tick, the host checks the **mouth volume** (a short wide
  box or cone in front of the jaws, sized by the gape) for school fish and prey players. Each one that
  enters is **held**: it is removed from its school's boids (a new `School.hold(i)` that stops the fish and
  hides it from its school's alarm), drawn into the mouth and rides there. The pleats swell per fish, and
  every fish in plays a small `engulf` pop and a little rumble tick. The mouth has a limit (`engulf_max`, x
  size). When it's full it **stays open but takes no more**: fish bump off the lips and the full-mouth
  strain cue plays until the player releases.
- Release: the mouth slams shut, and **everything held is eaten** in one `_judge_bite` (one callout, one
  chain). Water is pushed out of the sides (a spray FX) and a deep `gulp` plays. The pleats squeeze back
  down over 0.6 s.
- **A prey player in the mouth is doomed** (D4). Their controls lock and they ride in the mouth. Their view
  is pulled to the jaw, with a vignette and a dark-pink tint and a heartbeat rumble, until it closes and
  they are eaten. Upset Stomach: a prey player held when the mouth closes is spat as today, with the queasy
  cost (the whale can't filter them out once they're in).
- Capacity: there's no capacity roll. Engulf takes what's in the mouth, up to `engulf_max`. The charge is
  just "how long you held". The cost of holding (drag, slower turn, alarm) is what balances it.

### 4c. Fallen Angel: lock
- **The gate.** The press only takes when a fish (school fish or prey player) is within `angel_lock_range`
  (default 2x reach) and inside `angel_lock_cone` of the nose. Otherwise it's a "denied" beat: the crown
  flickers, the `denied` sound plays (the audio plan's unbuilt `denied` id) and there's no cooldown.
- Press: the **buccal cones** (the six crown tentacles) splay open, and **the target is the nearest fish at
  that moment**. Its id (a school id and index, or a prey player) is kept for the whole hold.
- **Held: full lock-on**, like the gif (D5). The angel **matches the target's speed** and holds a stand-off
  distance (`angel_standoff`, a share of the reach). Its body **pivots to keep facing the target** the whole
  time, until release. The player doesn't steer the nose. **The stick orbits the angel round the target**
  (`angel_orbit_speed`), choosing which side it strikes from. The lock-on ring (already in `AngelRig`) moves
  off the cone's end and onto **the target**, tightening as the charge builds. A thin glowing line runs
  from the crown to the target.
- **The angle decides the count** (D6, a facing share). At release the count is `capacity x
  angel_count_mult x share`, at least 1 (the target). `share` is how squarely the angel faces **the mass of
  the target's school**: the dot of the nose with the line to the school's middle, mapped like the lock-on
  bite's `facing`, plus the charge. So orbiting round to where the school lies behind the target pays, and
  striking from the side with the school behind you takes the target alone. The fish taken are the
  target and then the nearest of its school. While held, **the count it would take shows by the ring**
  ("x5"), and the fish are highlighted, so the player can see the angle working.
- Stacking: if the camera's lock-on is on the same school, the lock-on bite's bonus multiplies on top (D8).
- **Breaking.** If the target gets further than `angel_break_range` or is eaten by someone else, the lock
  snaps: a `lock_lost` sound, the ring bursts, and the crown closes empty with a small cooldown.
- Release: the cones lash at the target (the existing `lash`, aimed at it) and on into the school, with a
  hit-stop. A pitched crunch plays for each fish taken, in order of distance, each delayed by its distance,
  so it reads as the lash travelling.

### 4d. Gulper Mother: suction
- Press: the pouch balloons open (the existing gape 0.15 to 1.25) and the suction streaks start.
- Held: **the pull** (listed as not built). School fish in the suction cone are drawn toward the mouth (a
  new `School.pull(point, dir, cone, strength)`, a force on the boids), and prey players get an
  `apply_push` toward the mouth (they can swim against it). The strength rises with the charge. A `suck`
  loop plays, rising in pitch.
- Release: the pouch snaps shut on everything within `gulper_mouth_r` of the mouth, and the belly lumps
  show (`lump`/`fullness` in the shader, listed as not built).

### 4e. King of Herrings: coil
- Press: the head draws back and the body starts to coil (SpineRig bend toward a loop, the boss's coil
  pose).
- Held: the coil tightens with the charge, the skin's `warn` pulses, and a creaking `coil` loop plays.
- Release: the whip. The head sweeps through an arc whose width is `lerp(coil_arc_min, coil_arc_max,
  charge)`. The catch is the arc (a wide flat sector), not the frustum. Contact is when the head crosses
  the middle of the arc.

### 4f. Lamprey Queen: drill
- Press: the oral disc flares and the teeth and tongue start to rasp (the disc's spin rate follows the
  charge).
- Held: the rasp gets faster and the body coils back slightly. A grinding loop plays.
- Release: a **corkscrew dash** forward (`drill_dash` speed x charge for `drill_time`), rolling at
  `lamprey_spin`. Each fish the disc passes through is taken, up to `capacity x charge`. That's a drill
  through a school, not one latch. At a full charge the first prey player hit is latched (today's latch
  roll) and the dash ends.

### 4g. Whale Fall: lash (the form is disabled; built last, behind its flag)
- Held: the hagfish rear back one by one as the charge rises (1 to 6) and glow.
- Release: each reared hagfish lashes into the cone and takes one fish (the nearest left). The slime cloud's
  size follows the charge.

### 4h. Ember Octopus: whip (style key `whip`, `attacks/whip_attack.gd`; added 2026-11-08 by the new-hunters pass)
- Press: all eight arms start to coil (cocked spiral, tighter with charge); the mantle glows. Held: the charge builds
  and the arms lock onto the nearest fish ahead (up to 8 locks; the HUD ring shows "N" and "of N arms").
- Release: the arms unroll base to tip toward their locks with a travelling crack wave; the first (nearest) arm is
  judged on the bite's contact tick (a real hit or miss, the STRIKE phase waits until it lands), later arms are
  judged as they arrive through `match.judge_drill` (host only, same precedent as the Lamprey drill). Retract reels
  the arms back onto the gait pose (`OctopusRig.gait_joints`) with no pop.
- Net: puppets and guests run the same lash visuals from the synced bite beats; the host judges every arm. No lock
  list is sent, so visual lock targets can differ slightly between machines.
- Settings: 31 `whip_*` (group "Octopus lash"). Probe: `octopus_whip_probe` 74, `octopus_match_probe` 43.

### 4i. Lantern Angler: lure (style key `lure`, `attacks/lure_attack.gd`, `lure_field.gd`; added 2026-11-08)
- Press: the esca flares (spike), the eyes flash, the stalk kicks and a `LureField` source is registered at the
  esca. Held: the field ramps; bots and prey players inside its cone are pulled toward the light as a
  resistable drift (capped acceleration; thrusting away resists, a prey dash breaks it, then a short immunity). Human
  prey get an amber "captivated" vignette; bots steer through `LureField.blend_target`. The jaw gapes with the hold
  (`LureAttack.gape_mult`).
- Release: the field ends, the esca drops dark, the jaws snap on what was drawn in (the plain bite judge), and
  `lure_cooldown` relights it over the cooldown.
- Net: no extra messages; puppets run `on_open/on_close` from the synced beats, each machine pushes only the prey
  it owns. Esca, jaw and tail are derived locally.
- Settings: 17 `lure_*` and 12 `angler_*` (group "Lantern Angler"). Probes: `lure_pull_probe` 66,
  `angler_match_probe` 50.

## 5. Settings (flexible tuning: panel settings, wide ranges)
In `WhatStinksSettings`, "Bite" group: `bite_mode` (hold, tap), `hold_speed_mult`,
`hold_turn_mult`, `hold_alarm_mult`, `hold_cooldown_per_s`, `hold_cooldown_max`, `hold_capacity_mult`,
`hold_reach_mult`, `tap_open_min` (how
open a tap strikes from), `bite_frustum_preview`, the rumble strengths (`rumble_open`, `rumble_hold`,
`rumble_contact`), `hitstop_ms`.

Per form, in the sheet (and a panel group per style): `charge_s`, `open_s`; engulf `whale_gape_deg`,
`whale_smear`, `engulf_max`, `engulf_box`; lock `angel_lock_range` (2x reach), `angel_lock_cone`,
`angel_standoff`, `angel_orbit_speed`, `angel_break_range`, `angel_count_mult`; suction `suck_strength`, `suck_cone`, `gulper_mouth_r`; coil `coil_arc_min`,
`coil_arc_max`; drill `drill_dash`, `drill_time`. All the numbers are first guesses for play-testing.

## 6. Sound ids (stand-ins until recorded)

| Id | When | Stand-in |
|---|---|---|
| `hunter/jaw_open` | Shark press | `boss/chomp` (first 0.1 s, pitched up) |
| `hunter/jaw_hold` (loop) | Shark held | a growl / `boss/leviathan_arrive` low |
| `hunter/charged` | Full charge (all forms) | a UI click |
| `hunter/strain` | A whale's mouth is full | `boss/chomp_miss` pitched |
| `hunter/chomp`, `hunter/crunch` | Contact / per fish | `boss/chomp`, `boss/chomp_thud` |
| `hunter/miss` | Empty close | `boss/chomp_miss` |
| `whale/gape_open`, `whale/engulf` (per fish), `whale/gulp`, `whale/spray` | Engulf beats | `gulper` gulp/suck ids |
| `angel/cones_open`, `angel/lock` (loop), `angel/lock_lost`, `angel/lash`, `angel/denied` | Lock beats | `boss/angel_*` if any, else `boss/grab` |
| `gulper/suck` (loop), `gulper/snap` | Suction | the boss's `gulper` ids |
| `king/coil` (loop), `king/whip` | Coil | `boss/leviathan_*` |
| `lamprey/rasp` (loop), `lamprey/drill` | Drill | `boss/grab` |
| `octopus/*` (10 ids) | Whip beats, jets, arm cracks | stand-ins in `sound_catalog.gd` FALLBACKS |
| `angler/flare`, `angler/hum` (loop), `angler/snap` | Lure beats | stand-ins in `sound_catalog.gd` FALLBACKS |

## 7. Probes (headless) and tools
- `tests/two_stage_bite_probe.tscn`: for each ready form at 0.5x, 1x and 3x, a press opens (jaw over 0.9
  within `open_s` + 1 tick), a hold keeps it open indefinitely (30 s checked), the charge reaches 1 at
  `charge_s`, the shark's reach and capacity grow with it, a release lands within the strike's length, a
  tap strikes from a partial open, the cooldown grows with the hold up to its cap, the Hunter's jump
  press doesn't jump or dodge, and `bite_mode = tap` behaves as today's snap.
- **Sync check** (same probe): for each beat, the tick of the pose change, the cue, the `HunterBiteFx`
  sound call and the rumble call are recorded, and must all match within 1 tick. Sound and rumble are
  stubbed to record calls.
- Engulf: fish entering the mouth box are held and eaten on release. At `engulf_max` the mouth stays open
  and takes no more. A held prey player's controls are locked and they are eaten on release.
- Lock: denied out of range or behind, the target is the nearest at the press, the angel matches the
  target's speed and keeps facing it, the stick orbits it, the count from the school's side vs the far
  side (expect more with the school ahead), and the lock breaks past `angel_break_range`.
- Net: `what_stinks_net` probe with a host and a guest. The guest's held bite opens and closes on the host's
  puppet, and the host judges the release with the clamped charge.
- Existing probes must still pass: `hunter_forms_probe`, the per-form probes (`angel_form_probe`,
  `gulper_form_probe`, `king_probe`, `lamprey_form_probe`, `whalefall_probe`), `what_stinks_probe`,
  `what_stinks_lock_bite_probe`, and the Unnatural boss chomp probes (ChompKit unchanged for them).
- `--shots=DIR` (needs a window) for the whale mouth wide open per species, side and front. Look at them
  before calling the whales done.

## 8. Phases
0. **Core.** The `ChompKit.Bite` open-ended hold, `HunterBite` press/hold/release, tap = snap, no max
   hold, hold costs, no jump/dodge for Hunters, `bite_mode`, the shark's chomp style, the `HunterAttack` hooks with the default style, the
   bot press/hold/release, the net open and close messages. Probe: core and net.
1. **Feel.** `HunterBiteFx` (all beats from the cues), `WhatStinksRumble`, local hit-stop, the prey-side
   warning and impact, the HUD ring as the charge meter (fill, gold at full, red at strain), the sound ids
   with stand-ins. Probe: sync check.
2. **Whales.** The Titan hinged jaw, inside, pleats (`WhaleJaw`), the exaggerated gape, the engulf style
   with `School.hold`, held prey locked in, net. Shots review. Humpback first, then the other four species' mouths
   (their forms are still stubs, so their `ready()` stays as it is).
3. **Fallen Angel.** The gate, the full lock (pace match, auto-face, the stick orbits), the ring on the
   target, the facing-share count and its preview, breaking, the lash.
4. **Gulper, King, Lamprey.** Suction with `School.pull` and belly lumps, the coil-whip arc, the drill dash.
5. **Whale Fall** lash (behind its disabled flag).
6. **Bots and a short sim pass.** Per-style bot plans. A short `run_sim` of each form at 1x: fish per
   bite and per minute, hold vs tap. **Report the numbers as open items; no tuning pass on my own call.**
   Then update `hunter_forms.md` (the Signature column and each form's Bite section), what_stinks.md's
   summary, then build and hand off for play-testing.

## 9. Decisions (user, 2026-11-07)
- **D1. Tap:** strikes at once from the partial open, like today's snap.
- **D2. Max hold:** none. The jaws stay open as long as the button is held, and only the hold costs
  balance it.
- **D3. What the shark's hold buys:** more capacity and more reach (the lunge is unchanged).
- **D4. Prey in a whale's mouth:** doomed once inside (controls locked, eaten on close).
- **D5. Angel lock:** full lock-on. It matches the target's speed and pivots to keep facing it until the
  release. The stick orbits it round the target.
- **D6. Angel count:** a facing share. How squarely it faces the target's school at release (plus the
  charge) scales the count, and it always takes at least the target.
- **D7. Orca and sperm whale:** engulf like the rest (teeth instead of baleen inside).
- **D8. The lock-on bite** still applies and stacks with the held bite.
- **D9. Button:** the bite stays on `jump`. Hunters have no jump or dodge in this mode.
- **Whale mouth full:** stays open but takes no more until release.
- **Angel gate:** a fish within about 2x the bite reach, in a cone ahead of the nose.

## 10. Risks
- **Shared ChompKit.** Kept opt-in (`held_open`), with the boss probes as the guard.
- **Engulf and the schools.** Holding fish out of the boids (`School.hold`) touches `school.gd`, which is
  shared with Nature. It has to be an extra state that Nature never sets.
- **Online engulf** is host-owned. A guest Hunter sees its own mouth fill only as fast as the host's list
  arrives. An acceptable first cut; flag it if it feels laggy.
- **The Titan jaw** changes `TitanModel`, which Marco Polo uses too. The jaw stays shut (invisible
  change) unless something opens it. The Marco Polo whale probes and shots guard it.

## Progress log

### 2026-11-07 Phase 0 (Core) built
**Built.**
- `ChompKit.Bite` (opt-in, bosses unchanged): `held_open`, `open_now(open_s, reach, charge_for, pull_s)`, `release()`, `charge`/`charge_s` and a `charged` signal. HOLD loops while `held_open`, tremble plus strain with the charge; `start()`/`strike_now()`/timed HOLD untouched.
- `HunterBite` rewritten as press/hold/release: `try_open()` / `try_close()`, `opened` (+ `started` alias), `charged`, `released(charge)`, `aborted`; `chomped` keeps its 4 args (the form rigs and probes connect it) and the charge is `strike_charge()`, valid inside the signal. `try_bite()` stays as a one-call bite (tap mode's press, old probes). Tap = release before fully open strikes from at least `tap_open_min` open. No max hold. Hold costs: speed and turn scales x `hold_speed_mult`/`hold_turn_mult` while open (given back on close, abort or `release_fish()`), alarm x `hold_alarm_mult` (`WhatStinksMatch.refresh_alarm()`), cooldown `bite_every + hold_cooldown_per_s x held`, capped at max(`hold_cooldown_max`, `bite_every`). The chomp style's charge scales reach and capacity.
- Hunters ignore jump/dodge: `FishController.ignore_jump`, set by `HunterBite.setup`, cleared by `release_fish()` (called from `WhatStinksMatch._drop_bite`, which now runs first in `_become_hunter`).
- `scripts/what_stinks/attacks/`: `HunterAttack` (the hooks of 2c plus `reach_mult_at`/`capacity_mult_at`, `net_catch_rule`, `net_extra`; `make(key)` falls back to the chomp for styles not built) and `ChompAttack`. `WhatStinksMatch._on_chomp` asks `catch_rule()` and `_judge_rule()` judges it; the lock-on bite still goes on top of frustum rules. Form sheets get `attack`, `open_s` (0.12), `charge_s` (1.2) defaults in `HunterForms.DEFAULTS`.
- Bot: `WhatStinksBot` publishes the nearest fish's state and asks `bot_plan`; the chomp style opens at `hunter_bot_open_gap` x reach, releases when a fish is in the frustum and charge >= `hunter_bot_charge`, or the fish is getting away, or it gave up; a stinker in the frustum holds the release back.
- Net: `_ws_bite_started` -> `_ws_bite_open`; new `_ws_bite_close(hunter_id, charge)` (host/guests -> others), guest -> host `_ws_bite_start` (kept) and `_ws_bite_stop(pid, charge)`; `_ws_bite_land` now carries `charge` and the style's `extra` dict. The host caps a guest's charge to what its puppet saw plus 0.3 s of slack (`HunterBite.net_clamp`), and `judge_net_bite` uses no more than that cap. Puppets run `net_open()` / `net_close(charge)` (negative: call off), pose only. `WhatStinksMatch` signals: `bite_started` (open), new `bite_closed(hunter, charge)`, `local_bite(mouth, forward, charge, extra)`.
- Settings (Bite group): `bite_mode` (HOLD/TAP, replaces `bite_snap`), `tap_open_min`, `hold_speed_mult`, `hold_turn_mult`, `hold_alarm_mult`, `hold_cooldown_per_s`, `hold_cooldown_max`, `hold_capacity_mult`, `hold_reach_mult`, `bite_frustum_preview`, `rumble_open`, `rumble_hold`, `rumble_contact`, `hitstop_ms` (the last four and the preview are defined for Phase 1, nothing reads them yet); Bots group `hunter_bot_open_gap`, `hunter_bot_charge`. `setting_docs.gd` regenerated; INVENTORY.md bite line updated.
- `HunterBite.snap` stays as a field (true: a one-press bite is the snap, false: the old `bite_wind` chomp) for `try_bite()` and what_stinks_probe's comparison; it is no longer a setting.

**Probes.** New `tests/two_stage_bite_probe` (core, bot plans, puppet net calls, ChompKit hold, a real match: held bite eats more than a tap, alarm follows the jaws; `-- --match-only` skips the ~4 min per-form sweep). `tests/what_stinks_net_peer` now holds the button 0.6 s and checks the host saw one open and one close with a sane charge. Existing probes: `hunter_forms`, `hunter_spike`, `angel_form`, `gulper_form`, `king`, `lamprey_form`, `whalefall` set `bite_mode = TAP` in `_ready` (they press the button for a few ticks and expect a full snap chomp). `what_stinks_probe` had a duplicated "snap chomp vs wind-up" block that did not parse (already so at HEAD); the duplicate was removed.

**Decisions.** `chomped` keeps its 4-arg signature (charge via `strike_charge()`) to avoid breaking every rig. Shark pull-back (`shark_pullback`, 4a) not added: `open_now` takes `pull_s` but `HunterBite` passes 0. `extra` in `catch_rule` is a list of extra candidate fish for `_judge_bite` (unused by the chomp). A puppet emits `opened`/`released` too, so the host's alarm and later Phase 1 FX work on it.

**Open items.** Hold-cost and bite-number defaults are first guesses for play-testing (alarm x1.5, speed x0.8, turn x0.7, +0.5 s cooldown per second held to 6 s, capacity x2.5, reach x1.5). The match check "a held bite ate more than a tap" depends on how thick the pinned school is at the mouth (3 vs 4 fish once). The Whale Fall probe's 7 failures are the disabled form, not this change.

### 2026-11-07 Phase 0 (Core) review
**Verdict.** Core matches the spec (2a-2e): the `ChompKit.Bite` hold is opt-in, `start()`/`strike_now()` and the timed HOLD are untouched, tap strikes from at least `tap_open_min`, no max hold, hold costs given back on close/abort/`release_fish()`, the net charge is capped host-side, and puppets are pose only.
**Defects fixed.**
- Sniff vs open bite drift (`what_stinks_echo.gd`): sniff saved the absolute speed scales and restored them, so sniffing on, opening the jaws (x`hold_speed_mult`), then letting go of sniff before the jaws closed left the Hunter permanently faster once the bite divided its cost back. Sniff now multiplies and divides by its factor (clamped at 0.01 both ways). `echo_probe` has a new check for it (92 pass).
- `WhatStinksMatch._drop_bite` now calls `refresh_alarm()`, so a Hunter dropped with its jaws open stops widening the schools' alarm at once.
- `two_stage_bite_probe` match check compared how many fish two different schools gave up (flaky, and a held bite scares fish off by design: alarm x`hold_alarm_mult`, it ate 1 vs 4 in reruns). It now checks the judged capacity and reach (10 / 5.25 m held vs 4 / 3.5 m tap) and that the catch stays within capacity.
**Probes re-run, all clean.** what_stinks_probe 62, hunter_forms, hunter_spike, angel_form, gulper_form, king, lamprey_form, hunter_bot, hunt, what_stinks_lock_bite, stomach (66; its WhatStinksCam freed-focus errors come from the probe freeing fish, the cam is untouched), modes, ui, console, marco_polo, nature, nature_schools, nature_battered_fish, school, school_eat, chomp_lunge, final_boss, boss_items, boss_cursed, echo (92), two_stage_bite match-only (42), what_stinks_net.sh (host + 2 guests, all passed). Not re-run: the full two_stage_bite per-form sweep (~4 min; the builder's run was clean) and boss_moves/whalefall (builder: pre-existing failures).
**Open items.** The shark's hold currently scares schools more than it buys (alarm x1.5 against capacity x2.5 and reach x1.5): first thing to read in play-testing.

### 2026-11-07 Phase 1 (Feel) built
**Built.**
- `scripts/what_stinks/hunter_bite_fx.gd` (`HunterBiteFx`, child of `HunterBite`, made in `setup()`): driven only by `ChompKit.Bite.cue`, `Bite.charged` and the new `HunterBite.landed(taken)` (the contact tick, after the match judged it; -1 when unknown: a puppet's, or a guest's own bite). Press (`gape`): open sound, pad tick, bubbles. Hold (`hold`): `Sfx.start_loop` whose volume and pitch follow the charge each tick, a rising rumble, bubble puffs. `charged`: click, pulse, tooth sparks. `strike`: swoosh, loop stops. Landing: `chomp` + a `crunch` per fish (first on the contact tick, the rest staggered 50 ms, pitched up the chain), camera punch scaled by charge and fish taken (moved here from `HunterBite._land`), a hard pulse, local hit-stop (`hitstop_ms` of the Hunter's own `controls_locked`, never the time scale; skipped on a miss), blood/bubbles/teeth via `ChompKit.Fx`; a miss gets clack, small punch, bubble puff. `strain()` (for the Phase 2 engulf) plays the strain cue and a red ring flash. Sounds: the form sheet's `sound_<beat>` wins (so `sound_chomp`/`sound_miss` still work), else the style's table (`HunterBiteFx.SOUNDS`).
- Prey: `prey_caught(prey, from)` (called from `WhatStinksMatch._judge_bite`, `apply_net_spit`, `apply_net_bite`): camera punch + pulse + red flush on the prey's own view (`WhatStinksHud.flash`, HUD joins group `what_stinks_huds`). Warning: a local, non-bot prey within `prey_warn_range` x reach of an open mouth makes the hold louder and feels a heartbeat that quickens with the charge. Match sets `fx.prey_source = live_prey`.
- `scripts/what_stinks/what_stinks_rumble.gd` (`WhatStinksRumble.pulse`): own pad via `fish.input_source`; none for puppets or bots (`fish.controls != null`); `record` mode logs calls for probes. `ChompKit.view_camera(fish)` added (public wrapper; Bite and bosses untouched).
- HUD: `_draw_bite_ring` is the charge meter while held (fills with the charge, gold at full, flashes red while straining; the number is the capacity a release takes now); `ring_share`/`ring_color`; red edge flush.
- Sounds: 23 `hunter/ whale/ angel/ gulper/ king/ lamprey/` catalog rows (section 6) with stand-ins in `SoundCatalog.FALLBACKS` (mostly `boss/*`; `hunter/jaw_open` borrows `boss/shark_jaw_open`, `hunter/strike` `boss/shark_snap`, `hunter/charged` `ui/select`), plus new Sound Board categories. King and Lamprey rigs dropped their `chomped` sound hooks.
- Settings (Bite group): `bite_fx_mult`, `prey_warn_range`, `prey_warn_rumble`, `prey_impact` (with `rumble_*`, `hitstop_ms` from Phase 0, now read). `setting_docs.gd` regenerated; INVENTORY.md bite line updated.

**Probes.** `two_stage_bite_probe` gained `_feel()` and a match check: for press, hold, charged, strike and contact, on a catch and on a miss, the pose tick, `ChompKit` cue, `HunterBiteFx` sound (stubbed) and rumble (recorded) are within 1 tick (the log shows pose sampled 1 tick after the cue; cue, sound and rumble are the same tick); `landed` fires on the contact tick; crunch on it; hit-stop on, then off, time scale untouched; no hit-stop on a miss; bots/puppets feel nothing; every sound id is catalogued with a stand-in; prey impact; a near prey feels the heartbeat, a far one does not. `--match-only`: 67 checks, 0 failed.

**Decisions.** `landed` is a new signal rather than judging in the cue, because catch vs miss is only known after `_on_chomp`. `bite_frustum_preview` is still unread (not in Phase 1's list; 4a). The hold loop's stand-in is a one-shot sound.

**Open items.** Feel numbers (rumble strengths, hit-stop 80 ms, prey warning range) are first guesses for play-testing. Bot Hunters also get the hit-stop. Real rumble and audio need a window and a pad; only recorded calls were checked headless.

### 2026-11-07 Phase 1 (Feel) review
**Verdict.** Feel matches spec section 3: `HunterBiteFx` listens only to `Bite.cue`, `Bite.charged` and `HunterBite.landed`; rumble is the player's own pad (none for bots or puppets); hit-stop is the Hunter's own `controls_locked`, never the time scale; the HUD ring is the charge meter; the section 6 ids are catalogued with stand-ins; the shared `ChompKit` change is only the public `view_camera` wrapper (bosses, Nature and Marco Polo unchanged). Tap (release before full open) and tap mode play the strike and landing feel without the open/hold loop; abort, cancel and `_exit_tree` stop the loop.
**Defect fixed.** The hit-stop timer unlocked the Hunter unconditionally. A Hunter whose controls the match locked inside its 80 ms (another Hunter ate the last prey so the round ended, or it hurled) was freed again for the rest of the round-over. `HunterBiteFx.may_unlock` (a Callable, set by `WhatStinksMatch` to "phase is LIVE and not hurled") now gates the unlock; unset it always unlocks. New probe checks cover it.
**Probe flake fixed.** `two_stage_bite_probe` `_feel()` started inside the previous stage's (tap chomp) hit-stop about 1 run in 4, so the first bite never began (7 failures); it now waits the hit-stop out first. 69 checks, 0 failed on 3 reruns.
**Re-run, all clean.** two_stage_bite match-only (69), what_stinks_probe (62), hunter_forms (536), hunter_spike, what_stinks_lock_bite, echo (92), hunter_bot, stomach (66), chomp_lunge, final_boss, boss_items, boss_cursed, modes, ui, console, marco_polo, nature, nature_schools, nature_battered_fish, school, school_eat, audio, audio_hooks, angel_form (88), gulper_form, king (81), lamprey_form, what_stinks_net.sh (host and 2 guests). Not run: the per-form two_stage_bite sweep, whalefall and boss_moves (known failures).
**Open items.** Unchanged from the build entry (feel numbers are first guesses; bots also get the hit-stop; a guest's own bite plays the catch feel on a miss because `taken` is unknown there; real rumble and audio need a window and a pad).

### 2026-11-07 Phase 2 (Whales) built
**Built.** `WhaleJaw : HunterJaw` (`scripts/what_stinks/whale_jaw.gd`) on the Titan model (`titan_model.gd` `hunter_jaw()`, `titan_skin.gdshader`, `titan_fin.gdshader`): hinged lower jaw for all five species via the shark technique (belly patch discarded from the body skin, a copy rotated about the hinge in the vertex shader; the sperm whale's rod jaw swings through the fin shader), inside of the mouth (tongue floor, roof, throat fan, pleats, baleen on Humpback/Blue, teeth on Orca/Beluga/Sperm), exaggerated gape (`whale_gape_deg` 80, fling past wide) and smear (`whale_smear`), throat swell with `fullness`. Marco Polo whales get no jaw (no `hunter_jaw` meta, `jaw_cut` 0). `EngulfAttack` (`attacks/engulf_attack.gd`, style `"engulf"`): press opens, fish and prey inside the mouth box are held and ride in it, release eats them in one bite (Clean Sweep) or spits prey (Upset Stomach); `engulf_max_mult` caps the mouth, a full mouth stays open and strains. `School.hold/release_hold/nudge/is_held/held_count/held_indices` (state Nature never sets). New HunterAttack hooks `on_tick/on_landed/on_cancel/ring_count`, `HunterBite.world`, HUD ring shows held count, `HunterBiteFx.engulf/spray`. Net: the host runs engulf on the puppet Hunter (host-owned held list); a guest's release is judged by `judge_net_bite` through `net_catch_rule`; an unreported bite lets go after 1.5 s. Settings group Engulf (10 values, docs regenerated). Orca, Beluga, Sperm, Blue sheets given first-guess numbers and `ready()` flipped to true.
**Files.** school.gd, titan_model.gd, titan_skin/fin.gdshader, what_stinks/whale_jaw.gd, attacks/engulf_attack.gd, attacks/hunter_attack.gd, hunter_bite.gd, hunter_bite_fx.gd, what_stinks_match.gd, what_stinks_hud.gd, what_stinks_settings.gd, forms/{humpback,orca,beluga,sperm,blue}.gd, setting_docs.gd, INVENTORY.md; tests school_hold_probe, whale_engulf_probe (127 checks), whale_jaw_shots (windowed screenshot tool).
**Probes.** school_hold 0 failed; whale_engulf 127/0; hunter_forms 852/0; hunter_spike 75/0; what_stinks 62/0; two_stage_bite match-only 69/0; lock_bite 20/0; stomach 66/0 (flaked once with a freed-object error in WhatStinksCam._focus_ok, clean on rerun); marco_polo pass; chomp_lunge pass; nature, nature_schools, nature_battered_fish, school, school_eat, school_join (104), school_sync pass. Not clean: whale_spike_probe (2 FAIL: "11 pickable of 13", Titan start overlaps a solid) and whale_sight_probe (59.9 < 59.9 float compare), both in Marco Polo whale checks untouched by this phase (treated as pre-existing, not bisected). final_boss_probe leaks 2 ObjectDB instances at exit.
**Shots.** Looked at sperm/orca/humpback/blue; all five open to about 80 degrees with inside, throat and baleen/teeth.
**Open items.** Jaw is a thin belly patch (reads as a ribbon from the front); no upper-jaw lift; sperm roof strip reads bright pink; guests see held fish only when eaten; prey owned by a guest cannot be locked on the host (eaten at close only if still in the box); held fish bump only by nudge; throat swell shader bulge not seen in play; all numbers are first guesses; online path not run through what_stinks_net.sh.

### 2026-11-07 Phase 2 (Whales) review
**Verdict.** Whales matches spec 4b and D4/D7: press opens a hinged jaw, fish and prey in the mouth box are held and ride there (School.hold keeps them out of the school's boids and alarm middle), release eats everything held in one judged bite, Upset Stomach spits prey, a full mouth stays open and bumps fish away, `engulf_max_mult` caps it. Shared code is behaviour-identical when nothing is held: `School._held` is empty everywhere but a whale's mouth (the shader uniforms default to no-ops, so Marco Polo whales are untouched, and the probes show Nature schools identical). Cancel, abort, `_exit_tree`, battered/locked Hunter and a non-LIVE release all let held fish and prey go; a puppet's held fish let go 1.5 s after an unreported bite. Net: the host runs a guest's engulf on its puppet and judges the report through `net_catch_rule`.
**Defects found.** None in the game code. The new probe was thin on non-1x sizes and its net section depended on a school the earlier sections had thinned.
**Probe changes.** `whale_engulf_probe` gained section E (Hunter size 0.5 and 2.0: held fish ride within the box, the release eats them, nothing is left held) and `_fullest()` so sections D and E use the school with the most fish left (the net section failed about 1 run in 3 on a depleted school). 133 checks, 0 failed on 3 runs.
**Re-run, all clean.** whale_engulf 133, school_hold, what_stinks 62, hunter_forms 852, hunter_spike 75, lock_bite 20, stomach, marco_polo, chomp_lunge, nature, nature_schools, nature_battered_fish, school, school_eat, school_sync, school_join (104), modes, ui, console, final_boss, boss_items, boss_cursed, echo 92, hunter_bot, king 81, angel_form 88, gulper_form 79, lamprey_form 86, whale_reach, what_stinks_net.sh (host and 2 guests, all passed; shark only, the whale net path is covered by the probe's section D).
**Pre-existing, confirmed on a clean `git archive HEAD` copy.** whale_spike_probe (11 pickable of 13; Titan start overlaps a solid) and whale_sight_probe (59.9 < 59.9 m float compare) fail identically at HEAD; they are Marco Polo whale checks.
**Open items.** As the build entry (looks and numbers need play-testing; guests do not see held fish riding; guest-owned prey cannot be locked on the host). `setting_docs.gd` is generated and also carries comment-derived text for other groups (for example `click_button` now reads like `click_ring`); harmless, not changed here.

### 2026-11-07 Phase 4 (Gulper suction) built
**Built.** `SuctionAttack` (`attacks/suction_attack.gd`, style key `suction`, registered in `HunterAttack.STYLES`; the Gulper sheet says `"attack": "suction"`). Held, a cone ahead of the mouth draws school fish in through a new `School.pull(source, point, dir, cone_deg, speed, reach, mouth)` (an extra state, `_pulls`, that Nature never sets: it lapses 0.15 s after the last call, `end_pull`/`is_pulled` too; in `_move_fish` a pulled fish's wanted velocity is blended toward the mouth by how close it is, easing in at the lips) and shoves non-puppet prey players with `apply_push` (they can swim against it). Reach and speed rise with the charge (`suck_reach_min`/`suck_charge_min` up to full). The release catches everything within `gulper_mouth_r` bite radii of the mouth (a sphere; tap mode keeps the frustum snap, so `gulper_form_probe` is unchanged). The belly: `fullness` rises while fish crowd the mouth and the boss skin's `fullness` follows; after the snap a `lump` slides down `belly_span` for `suck_lump_s` seconds, sized by how much was taken. Bot: opens in pull range, snaps shut when the mouth is crowded, the crowd stops growing, the school has passed or after 6 s.
**Net.** No new messages. The pull is a pure function of the open mouth, so every machine runs it for the Hunter it sees (a puppet's `net_open` already drives `on_hold`), a prey player is pushed on its own machine, and the host judges a guest's release from the mouth the guest reports (`net_catch_rule`, a sphere). The lump on a guest/puppet uses the crowd count when no judged result arrives.
**Settings** (new "Suction" group in WhatStinksSettings): `suck_strength` 16, `suck_prey_push` 12, `suck_cone` 35, `suck_reach_mult` 2.5, `suck_reach_min` 0.4, `suck_charge_min` 0.35, `gulper_mouth_r` 0.7 (x bite radius), `suck_lump_s` 3, `suck_lump_size` 0.5. `setting_docs.gd` not regenerated (integration reviewer).
**Files.** `scripts/what_stinks/attacks/suction_attack.gd` (new), `scripts/school.gd` (pull), `scripts/what_stinks/attacks/hunter_attack.gd` (STYLES line), `scripts/what_stinks/what_stinks_settings.gd`, `scripts/what_stinks/forms/gulper_mother.gd`, `scripts/what_stinks/forms/gulper_rig.gd`, `tests/gulper_suction_probe.gd/.tscn`.
**Probes.** New `gulper_suction_probe` 40 checks, clean twice (numbers, school pulled to the mouth, charge, belly/lump in the shader, suction stops on release and on abort, prey shoved and eaten at the lips, a player behind unaffected, tap = frustum, net rule, bot). Guards clean: gulper_form 79, school, school_eat, school_hold, nature_schools, two_stage_bite `--match-only` 69, what_stinks 62.
**Open items.** The probe freezes the school (`school_speed` 0) for the pull check: against a school swimming and fleeing at normal speed the first unfrozen run pulled only 2 fish into the snap sphere, so the pull may be too weak against fleeing schools (a play-test question, not tuned). Sounds use the existing `gulper/suck`/`gulper/snap` rows, no rising-pitch change was added. No per-fish gulp cue or belly lump per fish (one lump, sized by the count). The King/Lamprey rigs of other tracks were mid-edit (a `_coil` parse error) while I ran; not mine. Not run: net script (no new messages), full per-form two_stage_bite sweep.

### 2026-11-07 Phase 3 (Fallen Angel lock) built
**Built.** `LockAttack` (`attacks/lock_attack.gd`, style `"lock"`, registered in `HunterAttack.STYLES`; the Angel's sheet has `attack: "lock"`): the gate (nearest school fish or prey within `angel_lock_range` x reach and `angel_lock_cone` of the nose, else a denied beat: crown flicker, `denied` sound, no cooldown), the nearest fish at the press kept as the target for the whole hold, matches the target's velocity and holds `angel_standoff` x reach, turns to face it (`angel_face_rate`), the stick orbits (`angel_orbit_speed`; a bot swings to the far side of the school), the ring moves onto the target with a line from the crown and the count the release would take ("x5", mates highlighted) in `AngelRig`, the count = capacity x `angel_count_mult` x facing share of the target's school (+ `angel_charge_weight` of the charge), at least 1, multiplied by the camera lock-on's bonus when on the same school (D8, `WhatStinksMatch.lock_stack_mult`), breaking (`angel_break_range`, target eaten: `lock_lost` sound, ring burst, `angel_break_cooldown`), the lash takes the target and its nearest schoolmates with a pitched crunch per fish delayed by distance (`angel_lash_speed`, `crunch_delay`), net (`net_extra` reports the school and index, the host builds the rule in `net_catch_rule`, falling back to the cone), bot plan. Settings: Angel group in `WhatStinksSettings` (`angel_*`, `hunter_bot_lock_align`); `HunterBiteFx.denied()/lost()`.
**Files.** attacks/lock_attack.gd, attacks/hunter_attack.gd, forms/angel_rig.gd, forms/fallen_angel.gd, hunter_bite.gd, hunter_bite_fx.gd, what_stinks_match.gd, what_stinks_settings.gd, tests/angel_lock_probe.gd/.tscn. `setting_docs.gd` not regenerated (the integration reviewer does it).
**Probes.** `angel_lock_probe` 59 checks, 0 failed (3 runs). The earlier worker's probe was flaky: its school picks were random and its net/bot section placed the Angel with the target level with its own mouth (outside the cone); it now picks the school with the most room and places the target ahead of the mouth. Guards: angel_form 88, what_stinks_lock_bite 20, what_stinks 62 clean. Other tracks' scripts were mid-edit at times (transient parse errors in unrelated files).
**Open items.** All numbers are first guesses for play-testing. `hunter_forms.md` Angel section and INVENTORY.md not updated for the lock (no stat table row changed). Real look of the ring/line needs a windowed review.

### 2026-11-07 Review of Gulper suction (independent reviewer)
**Read** `suction_attack.gd`, the `School.pull`/`_pulled` diff, the rig and sheet changes against section 4d. No defect found in the game code: the pull is a pure function of the open mouth (every machine runs it, `_pulls` lapses 0.15 s after the last call and on abort/close), Nature never calls it, tap mode keeps the frustum, the sphere radius scales with `bite.radius()` so non-1x sizes follow, and a guest's release is judged by the host through `net_catch_rule` from the reported mouth.
**Fixed (probe only).** `gulper_suction_probe` failed 3 runs in 4 on the prey check: the reach grows with the charge, and the probe placed the prey at 0.6 of the full reach straight after the pouch opened, outside the early reach; it also judged by the gap to the mouth while the Gulper itself drifts, and put the "behind" prey inside the Gulper's own body (physics bumps). Now it waits for full charge, judges the prey's own velocity toward the mouth, and puts the control prey beside the mouth. The `snap: they are gone from the school` check got a 3 frame wait (the school hears of eaten fish a tick later). Six clean runs after the change except one 1.04 m/s bump, which the loosened bound covers.
**Probes.** gulper_suction 40/0 (repeated), gulper_form 79/0, school_hold 0 failed, school pass, nature_schools pass, two_stage_bite --match-only 69/0, school_eat re-run after the other tracks' parse errors cleared (see below). Not run: per-form sweep, net script. A transient `DrillAttack` parse error from the King/Lamprey track appeared throughout (not this track).
**Open.** Prey push strength is uneven in the probe (0.96 to 4.25 m/s in over 0.25 s), depends on the Gulper's drift; play-test question, not tuned. The builder's open item (pull weak against a fleeing school) stands.

### 2026-11-07 Phase 3 (Fallen Angel lock) review
**Verdict.** Lock matches spec 4c and D5/D6/D8: the gate (denied beat, no cooldown), the nearest fish at the press kept for the hold, pace match, stand-off, auto-face, stick orbit (sign checked: stick right moves the Angel to its right of the target), breaking, the facing-share count with the camera lock-on stacking through `lock_stack_mult`, the distance-delayed crunches, the net report and the bot. `try_open` calls `can_open` and `on_open` in one go, so the gate's pick is never stale; a tap (release inside the opening) and tap mode (`try_bite`, no gate, plain frustum) both work. Shared code is only the `HunterAttack.STYLES` line and the additive hooks, so bosses, Nature and Marco Polo are untouched.
**Defects.** None in the game code. I tried moving the facing share from the mouth to the body (the mouth passes a near school's middle and the line flips) and reverted it: with the 0.7 x reach stand-off and small schools the body-based line is almost always "ahead", which kills the angle-decides-the-count mechanic. The mouth-based share is what makes orbiting matter.
**Probe changes.** `angel_lock_probe` section G (71 checks, 0 failed on 4 runs): the lock at Hunter size 0.5 (the match default) and 2.0, a quick tap in hold mode, and tap mode. Section D now uses an outer fish as the target; the bot's "lets go" check compares against the share itself (it flaked about 1 run in 3 when the target sat near a small school's middle, where the mouth-based line flips).
**Re-run, clean.** angel_form 88, what_stinks_lock_bite 20, what_stinks 62, two_stage_bite match-only 69, hunter_forms 852 (this closes the builder's open item).
**Open items.** `angel_close_speed` is not scaled with Hunter size, so a 2x Angel takes about 2 s to close to its stand-off (0.5x is fine); a target near a small school's middle reads a low share because of the mouth-based flip. Both left as play-test questions. Ring, line and "xN" still need a windowed look; hunter_forms.md Angel section not updated; `setting_docs.gd` is the integration reviewer's.

### 2026-11-07 Phase 4 (King coil-whip and Lamprey drill) built
**Built.**
- `CoilAttack` (`attacks/coil_attack.gd`, style `"coil"`, King): the catch is a flat sector (`in_sector`) from a pivot `coil_pivot` x reach behind the mouth, `coil_arc_min` to `coil_arc_max` degrees wide with the charge, a reach beyond the mouth long, `coil_thick` x reach thick; `frustum: false` (the camera lock-on bite does not stack). The charge lifts capacity (`coil_capacity_mult`), not reach. `sweep_at()` is the head's yaw round the pivot (cocked aside while held, growing with the charge; through zero at the contact tick; on to the far side; home) and `coil_target()` the coil tightness; `KingRig` swings the head round the pivot by that, curls the spine behind the neck through `coil_curl_deg` x the eased coil, and the skin's `warn` burns brighter with the charge. A guest's landing is judged on the host as the same sector from its mouth, heading and capped charge (`net_catch_rule`). Bot: opens at `hunter_bot_open_gap`, lets go when a fish is in the sector the coil has now and the charge is up (or it is getting away).
- `DrillAttack` (`attacks/drill_attack.gd`, style `"drill"`, extends `ChompAttack` for the bot plan, Queen): capacity x lerp(1, `drill_capacity_mult`, charge); reach unchanged. On the release (STRIKE t == 0) a hold of at least `drill_min_charge` starts a dash: `drill_dash` x her top speed x the charge for `drill_time`, the fish's `top_speed_scale` lifted for it (given back on end/cancel; never for a puppet). Each tick the tube the disc swept (`drill_radius_mult` x bite radius) is judged through the new `WhatStinksMatch.judge_drill` (an ordinary `_judge_bite` whose cooldown is restored; one `chew_delay` is added when the dash ends) until the budget (capacity x charge, shared with the contact cone via `on_close`) or the time runs out. At full charge a prey player taken (at the contact or on the run) latches her: the dash ends and `LampreyRig` rolls on it (`consume_latch`). `LampreyRig` winds the body back against the roll (`_wind`, `WIND_BACK`) and speeds the rasp (`breath`) with the charge, rolls at `lamprey_spin` through the dash, and no longer latches on a landing while a dash is on (a tap, under `drill_min_charge`, still plays the old latch roll). The host runs the dash's eating on a guest's puppet along its synced position (as the engulf does); the guest's own landing report judges the plain cone, and the budget is shared so nothing is eaten twice.
- Shared, additive: `HunterAttack` gets `suppresses_ram()` (false; the drill returns true while dashing, so the body ram does not add to its count; `WhatStinksMatch._ram_step` asks it) and two `STYLES` rows; `WhatStinksMatch.judge_drill`; `HunterBiteFx.drilled()` (crunch pitched up the run's count, a pad tick, blood); `WhatStinksSettings` groups Coil (6 values) and Drill (6 values). Sheets: King `"attack": "coil"`, Lamprey `"attack": "drill"`. INVENTORY.md bite section updated. `setting_docs.gd` NOT regenerated (the integration reviewer does that).

**Probes.** New `tests/coil_whip_probe` (53 checks: numbers, sector geometry at both charges, press/hold/release poses, the sweep crossing zero on the contact tick, the rig's coil/chord/head swing/warn, tap, tap mode, bot, a real match with a held and a tap release and a prey player 65 degrees off the nose (missed by a tap and by a no-charge net landing, eaten by a full hold and by a full-charge net landing)) and `tests/drill_probe` (38 checks: numbers, tap = plain bite and latch roll, wind-back, the dash's speed/time/distance/roll/top speed given back, `drill_dash` 0, a real match: a dash through a school takes up to the budget, a tap does not dash, prey at half charge (drilled, no latch, runs its time) and at full charge (drilled, dash ends, latch roll), the host's dash on a puppet). Both 0 failed on 3-4 runs. Existing, clean: king_probe 81, lamprey_form_probe 86, what_stinks_probe 62, two_stage_bite match-only 69, hunter_forms 852, hunter_spike 75, hunter_bot, chomp_lunge, final_boss, boss_items, boss_cursed (leaks at exit only).

**Decisions.** The drill's school take is judged per tick on the owning machine (the host, or the host's view of a guest) rather than all at the contact tick, so fish go as the disc reaches them; the plain cone at the contact is the first of the same budget. The coil's catch is judged at the contact tick over the whole sector (the head's sweep is the pose of that, not a moving hit test). Lamprey sheet capacity stays 1 (the tap/old latch); the drill lifts it by `drill_capacity_mult`.

**Open items.** All numbers are first guesses for play-testing (arc 45-160 degrees, capacity x1.5, coil 300 degrees; dash x2 her top speed for 0.6 s, capacity x6, tube x1.5). The dash's speed (55 m/s at size 1) may feel too fast for the arena; a guest's own Queen sees fish vanish as the host's puppet reaches them (one round trip late). The body ram is held off during the dash, so the Queen takes fewer fish while dashing through a thick school than the ram alone did before (capacity x charge is the new limit). The rig's coil curl and the sweep were checked as numbers only, not seen: no `--shots` run for the King mid-coil or the Queen mid-drill (needs a window).

### 2026-11-07 Review of King coil-whip and Lamprey drill (independent reviewer)
**Checked.** Read `coil_attack.gd`, `drill_attack.gd`, `judge_drill`, the `suppresses_ram` hook and the call order in `HunterBite` (on_tick before `bite.update`, so the STRIKE t == 0 start fires on the release tick; `_land` sets the cooldown before `chomped`, so the drill's `_end` chew delay lands after it). Tried to refute: the top-speed lift is given back on `on_cancel` (`release_fish`, `abort`) and survives a freed fish; a puppet never lifts its top speed or sets its velocity; `_end` twice is harmless; tap mode and a hold under `drill_min_charge` never dash; the sector scales with size through `bite_reach`; a guest's landing is judged flat to the puppet's up. No shared-code behaviour change found (`suppresses_ram` is false for every other style; `judge_drill` restores the cooldown).
**Defect found (probe only).** `coil_whip_probe` section C "held: the same place is inside the arc" failed about 1 run in 3. The test prey is placed once, then drifts in the current (up to about 3 m up in the strike's time), past the sector's thickness (`coil_thick` x reach = 2.75 m). Not a game defect. The probe now pins that prey 55 degrees off the nose each physics tick until the landing (and the placement leaves margin for the lunge swinging the pivot on). 8 clean runs after.
**Probes (this review).** coil_whip_probe 53/0 (8 runs), drill_probe 38/0 (4 runs), king_probe 81/0, lamprey_form_probe 86/0, what_stinks_probe 62/0, two_stage_bite match-only 69/0, hunter_spike 75/0, hunter_bot all passed, chomp_lunge ALL PASS, final_boss ALL PASS, what_stinks_net.sh (host + 2 guests) all passed. Not run: hunter_forms, the per-form two_stage_bite sweep, windowed shots.
**Open items.** Still unseen: the King mid-coil and the Queen mid-drill (needs a window). The coil's `coil_thick` (0.5 x reach) is tight vertically; worth feeling in play-testing. `setting_docs.gd` is still for the integration reviewer. `tests/what_stinks_net.sh` needs the Godot console path as its first argument on this machine.

### 2026-11-07 Phase 6 (bots) built
**Built.** The per-style `bot_plan`s already existed from phases 0 to 4 (chomp: open at `hunter_bot_open_gap` x reach, release at a frustum fish and `hunter_bot_charge` or when it is getting away; engulf and suction: open on a school ahead, release when the mouth is full, the catch has dried up or the school has passed; lock: open only through the gate, release at `hunter_bot_lock_align`; coil: release when the target is in the arc the coil has now; drill: the chomp's plan, the charge threshold 0.5 is above `drill_min_charge` 0.2 so it dashes). This phase found and fixed what stopped them working and closed the Upset Stomach gaps:
- **Bug: the Hunter bot never held a bite.** `HunterBite` reads `fish.jump_held` a tick after the bot sets it, so the bot saw "not holding" on the tick after its press, let the button go, and every hold-mode bite was a one-tick tap at charge 0.00 (the sim showed the whales taking 0.0 fish per bite). `WhatStinksBot` now keeps a press down for up to `PRESS_TICKS` (2) until the jaws open (hold mode only; tap mode as before). This is why earlier probes (which test `bot_plan` or the plan's return value) passed.
- `LockAttack.bot_plan` no longer opens on a prey it reads as a stinker (Upset Stomach); `WhatStinksBot.reads_as_stinker()` is the public face of `_is_stinker`. Engulf has no release gate for Upset Stomach (a prey in the mouth can't be let off); it keeps the press gate.
- `tests/what_stinks_bots_probe` (27 checks) includes: the bot's real bites are let go at a charge of at least `hunter_bot_charge`; the Angel's bot won't lock a readable prey in Upset Stomach and does lock an unreadable one.
**Files.** scripts/what_stinks/what_stinks_bot.gd, attacks/lock_attack.gd, tests/what_stinks_bots_probe.gd/.tscn. See `what_stinks.md` for the rest of Phase 7 (prey bot, echo use, sim, report) and `what_stinks_report.md` for the per-form numbers (fish per bite and per minute, hold against tap, win rates and round times, both variants), listed there as open items for the play-test, not tuned.
**Probes.** what_stinks_bots_probe 27/0 (several runs), what_stinks 62, stomach 66, two_stage_bite match-only 69, angel_lock 71, angel_form 88, gulper_form, king 81, lamprey_form 86, hunter_forms 852, hunter_spike, echo 92, lock_bite 20, school_hold, school_eat, school_join, school_sync, chomp_lunge, final_boss, nature, nature_schools, nature_battered_fish, modes, ui, console, what_stinks_net.sh (host and 2 guests) all clean. When several probe groups ran at once next to the sim, gulper_suction (2 checks), whale_engulf (net 1.5 s), coil_whip (net arc), drill (disc took 0), school_probe and marco_polo (seeker holds depth) each failed once and passed on a quiet rerun (marco_polo and school_probe are known flakes); nothing was fixed for them. Not run: whalefall and boss_moves (known failures).
**Open items.** Whole sim numbers are in `what_stinks_report.md`. The drill and coil plans are the chomp's with the style's own geometry; the drill bot does not aim its dash. All bot numbers are first guesses for the play-test.

### 2026-11-08 Wrap-up: docs, full probe set, build (00:32)
**Docs.** `hunter_forms.md`: new sheet keys (`attack`, `open_s`, `charge_s`), the forms table with each form's attack style and the true state (ten forms ready, Whale Fall disabled), and a "Bite, two-stage" section per form (Shark chomp, whales engulf, King coil, Gulper suction, Lamprey drill, Angel lock; Whale Fall noted as not built). `INVENTORY.md` section 8: Lock and Suction bullets, Whale Fall disabled, match size locked at 0.5x; synced date bumped. `what_stinks.md`: Progress section and a FINAL SUMMARY entry.
**Full probe set (fresh `--import`, no errors; sequential, quiet machine).** Clean: what_stinks 62, what_stinks_bots 27, what_stinks_lock_bite 20, what_stinks_camera, hunter_spike 75, angel_form 88, gulper_form 79, king 81, lamprey_form 86, echo 92, stomach 66, angel_lock 71, coil_whip 53, drill 38, hunter_forms 852, hunter_bot, hunt, school_eat, school_hold, school_sync, school_join 104, nature, nature_schools, nature_score, nature_battered_fish, modes, ui, console, marco_scan, marco_watch, whale_reach, chomp_lunge, final_boss, boss_items, boss_cursed, audio, audio_hooks 1-4, and the net scripts marco_polo_net, coop_net, unnatural_net. Failed once, passed on rerun (flakes): whale_engulf (stomach section, 3 checks; 2 clean reruns), school_probe (1; rerun clean), marco_polo (seeker holds depth, 1; rerun clean), what_stinks_net.sh (host and guests "b is eaten here too"; 2 clean reruns, the known moving-school flake), gulper_suction (see below).
**Failures I caused and fixed (both in probes, no game code).** (1) `two_stage_bite_probe` full per-form sweep: 108 failures. Its reach x`hold_reach_mult` and capacity x`hold_capacity_mult` checks are the chomp style's, but they ran for every form, and nine forms now use other styles. Gated by the form's `attack`; the others check a charged bite is at least the plain one and landed at full charge. Sweep now 586 checks, 0 failed (it was 640 with the old, wrong checks). (2) `gulper_suction_probe` prey section failed about 3 runs in 4 ("0.00 m/s in"): since the Phase 7 prey bots, the probe's prey had joined a school (frozen, controls locked) by the time section D ran. The probe now turns `bots_join` off, stops the prey bots and calls `join.leave` on each prey first. 5 of 6 clean runs after; the sixth failed only the old bump flake ("a player beside the mouth is not (2.41 m/s; the Gulper drifts and can bump it)").
**Pre-existing / not ours.** whalefall_probe 7 fail (Whale Fall disabled: "reports ready", on the card, its bite and rig). boss_moves_probe 1 fail ("in fury, a player in front of its mouth is sucked in"), fails the same on HEAD. whale_spike_probe 2 fail ("11 pickable of 13", Titan start overlaps a solid) and whale_sight_probe 1 fail (59.9 < 59.9 float compare): identical on a clean HEAD copy (checked by the Whales reviewer). stomach_probe prints WhatStinksCam freed-focus errors (probe frees fish the camera holds), exits 0.
**Build.** `builds/windows/FishPlayground.exe` exported 2026-11-08 00:32 (debug export), after the probes above.
**Not run / not verified.** Whale Fall lash (out of scope). Windowed visuals for the Angel ring and line, the King coil, the Queen's drill, the Gulper lumps and the whale jaws (headless only). Real rumble and audio. A real two-machine run of the whale net path (whale_engulf_probe section D covers it in one process; what_stinks_net.sh uses the shark).
**Play-test first (all numbers are first guesses; nothing tuned).** Hold balance (alarm x1.5 scares schools off: a held shark bite ate 1 fish where a tap ate 3 to 4 in the match probe); Gulper pull strength against a fleeing school; Angel lock feel (ring, "xN", `angel_close_speed` at larger sizes); King coil arc and `coil_thick`; Lamprey dash speed (55 m/s at size 1) and the body ram being held off during it; whale looks (thin ribbon jaw, pink sperm roof, throat swell) and Orca/Beluga/Sperm/Blue numbers; bot sim: Clean Sweep 0 of 80 bot Hunter wins, Beluga weakest, Upset Stomach easy for most forms (what_stinks_report.md, at 1x not the 0.5x default).

### 2026-11-08_11:57 New-hunters pass: two more styles and the exaggeration layer
Two styles were added after the six above: **whip** (Ember Octopus, section 4h) and **lure** (Lantern Angler, section 4i); `HunterAttack.STYLES` and `HunterBiteFx.SOUNDS` have rows for both, sound stand-ins are in `sound_catalog.gd`. Every existing style now also drives an `AttackExaggerate` kit from the HunterBite signals (opened, released, landed, aborted): bolder anticipation, overshoot and a short hit-stop, scaled by `hunter_exaggeration` (0 = the old look). The Lamprey dash is now `lamprey_lunge_impulse` 0.55 of the old speed. Probes: whip 74, octopus_match 43, lure_pull 66, angler_match 50, b1-b6 exaggeration probes, drill 38 (checks multiply by `DrillAttack.lunge_impulse`). Known: `two_stage_bite_probe` fails (306, the press never opens for the forms from the shark at x1.0 up) with or without the new forms; it was green at 00:32 (586/0), so something changed in its setup or the bite path in between and it needs a look. Details and open items: `planning_new_hunters.md` Progress log.
