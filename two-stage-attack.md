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
