# Planning: Sound Effects (and swappable Sound Profiles)

Status: **phase 0 (foundation) built 2026-10-18** (10:24 build). **Phase 1 (core feel) built
2026-10-18** (12:21 build): menus, your fish, the ball, goals and a 1v1's flow now ask for
their sounds (Â§4 lists what's in and what's left). Before this, the only audio was
`ReplayAudio`, which plays a soundtrack beside a replay.

**Phases 2, 3 and 4 built 2026-10-18** (Battered, Nature and Hunt; Unnatural; space and
ambience). Every event in the catalog is now asked for by the game, bar the few listed under
"Left for later" in §4.2–4.4. Phase 5 (music) is still open. All of it is silent until a
profile has the files: the sheet (Settings > Audio > Write recording sheet) lists what to record.

Goal: every meaningful moment in the game gets a sound. The sounds come from a **Sound
Profile**, which is a folder of files with fixed names. You can make as many profiles as you
like ("A Cappella", "Synth", "Foley", ...), switch between them in Settings, and swap
them at runtime while you work on them.

---

## 1. How Sound Profiles work

### 1.1 Folder layout

**`None` is the starting profile.** It's built in, not a folder: it plays nothing and has
no fallback. It's selected by default (and on first launch), so the game stays quiet while
sounds are being hooked up and recorded. You switch to a real profile in Settings when you
want to hear one. `None` will likely be retired once a real profile is finished.

```
audio/profiles/
  README.md           <- the naming rules, for whoever records
  acappella/
    profile.cfg
    ui/select.wav
    fish/stroke-1.wav
    fish/stroke-2.wav
    ball/hit@1-1.wav
    ...
  synth/
    profile.cfg
    ui/select.wav
    ...
  synth/
    ...
```

Every profile uses the same relative paths. The **event id** is the path without the
extension and suffixes: `ball/hit`, `fish/boost_loop`, `unnatural/zombie_die_tank`.

### 1.2 File-name rules (the whole contract)

| Pattern | Meaning | Example |
|---|---|---|
| `name.wav` / `name.ogg` | one sound for the event | `ui/select.wav` |
| `name-1`, `name-2`, ... | **variations**: picked at random, never the same one twice in a row | `fish/stroke-1.wav` … `fish/stroke-4.wav` |
| `name@1`, `name@2`, `name@3` | **intensity layers**, soft to hard. The game picks one from how hard the hit was | `ball/hit@1.wav` (tap), `ball/hit@3.wav` (smash) |
| `name@2-3` | layer 2, variation 3 | `ball/hit@2-3.wav` |
| `name_loop` | a looping sound. The game starts it, stops it, and moves its volume/pitch | `fish/boost_loop.ogg` |
| `name_n00` … `name_n11` | **optional per-note files** for pitched events (semitones above the root) | `nature/pearl_n00.wav` … `nature/pearl_n07.wav` |

You don't have to use any of these. A single `ball/hit.wav` works. Variations and layers
are there for when you want to record more takes.

For pitched events (XP pickups, pearl streaks, combo counters) the game climbs a scale.
If the profile has `_nNN` files it uses those, so a choir can sing real notes. If not, it
pitch-shifts the plain file. The scale itself (major, minor pentatonic, ...) is set in
`profile.cfg`, so an a cappella profile and a synth profile can each be in their own key.

### 1.3 `profile.cfg` (optional, per profile)

```ini
[profile]
name="A Cappella"
author="Matthew"
description="Every sound is a voice."
underwater_filter=true      ; false = play exactly as recorded (you baked the effect in)
root_note="D"               ; for pitched events
scale="major_pentatonic"    ; major, minor, major_pentatonic, minor_pentatonic, chromatic, ...

[mix]                       ; per-event trims, so you can mix without touching code
"ball/hit" = { "volume_db": -2.0, "pitch_jitter": 0.05 }
"fish/boost_loop" = { "volume_db": -6.0 }
"unnatural/zombie_die" = { "max_voices": 6 }
```

### 1.4 Formats

- **Short one-shots:** `.wav`, 16-bit 48 kHz. Mono for anything that happens *in the world*,
  since 3D placement pans it. Stereo is fine for UI and stingers.
- **Loops and anything long (ambience, music):** `.ogg`. Godot loops OGG cleanly when the
  game sets `loop = true`.
- Trim silence at the start. The game plays the file the moment the event happens, so any
  lead-in shows up as latency.

### 1.5 Missing sounds

**A sound the active profile doesn't have stays silent.** Placeholder beeps never mix
in with your recordings. A profile with five sounds plays those five and nothing else.

For finding gaps, the debug panel has a **Beep for missing sounds** toggle (off by
default). While it's on, a missing sound plays its built-in placeholder beep,
so you can hear where the gaps are while playing. The Sound Board shows the same gaps
without playing anything.

---

## 2. Engine design

### 2.1 Pieces

| Piece | What it does |
|---|---|
| `scripts/audio/sound_catalog.gd` | **The single list of every event id.** Each entry gives the bus, 2D/3D, default volume, pitch jitter, max simultaneous voices, cooldown, whether it's pitched or looped, and a one-line description for your recording sheet. |
| `scripts/audio/sound_profile.gd` | Scans a profile folder, groups files into events (variations/layers/notes), reads `profile.cfg`, and loads the streams. |
| `scripts/audio/sfx.gd` (autoload `Sfx`) | The API. Pools of `AudioStreamPlayer` and `AudioStreamPlayer3D`, voice limiting, loops, and profile switching. |
| `scripts/audio/sfx_hooks/*.gd` | Small listeners that connect to the **signals the game already emits** and call `Sfx`. Gameplay code stays mostly unaware of sound. |
| (in `Sfx`) | The mixer buses (§2.3), made in code at startup. |

### 2.2 API

```gdscript
Sfx.play(&"ui/select")                                  # 2D
Sfx.play_at(&"ball/hit", ball.global_position, 0.8)    # 3D, intensity 0..1 picks the @layer
Sfx.play_pitched(&"unnatural/xp", streak_step)         # climbs the profile's scale
var h := Sfx.start_loop(&"fish/boost_loop", fish)      # follows the node
Sfx.set_loop(h, volume_01, pitch)                      # e.g. boost loop pitch follows speed
Sfx.stop_loop(h, 0.15)                                 # fade-out seconds
Sfx.set_profile("acappella")
Sfx.reload()                                           # hot reload from disk
```

### 2.3 Buses

```
Master
 ├─ Music
 ├─ UI
 ├─ Voice         (announcer-type stingers: "FISH FRY!", stage warnings)
 └─ World
     ├─ Fish / Ball / Combat   (gameplay one-shots)
     └─ Ambience
```

**Underwater feel:** the `World` bus gets a gentle low-pass and a reverb. These are bus
effects, so every profile gets them for free. Your raw recordings stay dry, and a choir
sounds like it's underwater without you having to process it.
- A profile can turn this off (`underwater_filter=false` in `profile.cfg`) if you'd
  rather bake the effect in yourself.
- **Murk** tightens the low-pass as visibility drops.
- **Surface breach:** when the camera goes above the water line, the filter opens up.

Settings gets a volume slider for Master / Music / SFX (World+UI) / Voice, a **Sound
profile** picker (starts on `None`), and a separate **Music** picker that defaults to
"Same as sound profile". With that, Synth effects can play with A Cappella music.

**Voice bus (optional callouts):** big moments (Fish Fry, stage warnings, boss arrivals,
level up) can have a spoken/sung callout in `voice/` (`voice/fish_fry`,
`voice/ring_warn`, ...) on top of their regular sound. A profile without `voice/` files
just has no callouts. They have their own slider, so players can turn them off.

### 2.4 Where profiles live, and hot reload

- **All profiles live in the repo** at `audio/profiles/<name>/`, versioned with git.
- **Hot reload while you work:** when the game runs from the project (the editor or
  `Godot_console.exe` on the project folder), `Sfx` reads the raw files straight from the
  folder with `AudioStreamWAV.load_from_file` / `AudioStreamOggVorbis.load_from_file`.
  That's the same runtime loading `ReplayAudio` already uses. Save a WAV from your DAW,
  press **Reload Sounds** in the debug panel, and you hear it at once.
- **Exported builds** pick up profile changes on the next export. Phase 0 verifies how
  the files get into the .pck: either the imported resources, loaded with `load()`, or
  the raw files through an export include filter.

### 2.5 Voice limiting (matters a lot for Unnatural)

Hundreds of zombies can die in one second. Each catalog entry has:
- `max_voices`: oldest/quietest voice is stolen past this.
- `cooldown`: minimum gap between starts of the same event.
- **Aggregation**: for mass events (zombie deaths, XP pickups) the hook counts events per
  frame and plays **one** sound with intensity scaled by the count, so 40 kills read as
  one big "crunch" (`@3`) rather than 40 overlapping copies.

### 2.6 Split-screen and online co-op

- **Split-screen:** Godot mixes 3D sound for every camera, so a sound near both players
  would play twice. Instead there's one shared mix: `Sfx` plays each world sound once, as
  loud as it is for whichever player is closest (decided, A3).
- **Online co-op:** hooks listen to signals that fire on *both* host and guest (e.g.
  `pearl_taken`, `zombie_killed`, `boss_arrived`), so guests hear the same events without
  any new network messages. Where a signal is host-only, the hook uses the replicated
  counterpart (`*_confirmed` / `apply_*`).

### 2.7 Tools for you

- **Sound Board** (Settings > Audio > Sound Board tab): every event in the catalog,
  grouped by category. Press A on a row to hear it. Each row says **HAVE** (in this
  profile), **BORROWED** (uses another event's sound, e.g. a per-arena horn using the
  generic one) or **MISSING** (plays its placeholder beep when auditioned). The detail
  pane shows what the event is for, how it plays, its file name and the profile's files.
- **Recording sheet:** Settings > Audio > **Write recording sheet** writes
  `audio/sound_sheet.csv`: every event id, its file name, priority, 2D/3D,
  loop/pitched/layers, the description, and a column per profile showing what's done.
  This is your checklist when you sit down to record.
- **Placeholder beeps:** built in (the **Beeps** profile) and synthesised in memory, so
  there are no placeholder files in the repo. Each event gets its own pitch. Pitched
  events beep on A, so you can hear the scale they climb.
- **Probe** `tests/audio_probe.gd`: catalog ids, file-name parsing, None/Beeps, a
  throwaway profile in `user://sfx_probe` (variations, layers, notes, trims, scale,
  borrowed sounds, voice limits, cooldowns, loops, hot reload), buses and volumes, and
  Settings > Audio with its Sound Board.

---

## 3. The sound list

Priority: **P1** = the game feels dead without it. **P2** = adds a lot. **P3** = polish.
"3D" = positioned in the world. "Loop" = sustained. "Pitched" = climbs a scale.
Hook = the existing signal or function it hangs off.

### 3.1 UI and menus (`ui/`)

| Event id | When | P | Notes | Hook |
|---|---|---|---|---|
| `ui/move` | focus moves between buttons/cards | P1 | very short, quiet; fires a lot | `MenuNav` |
| `ui/select` | confirm / press | P1 | | `MenuNav` |
| `ui/back` | back / cancel | P1 | | `MenuNav` |
| `ui/denied` | can't do that (locked, not enough pearls) | P2 | | |
| `ui/toggle_on`, `ui/toggle_off` | settings toggles | P3 | | settings |
| `ui/slider` | slider step | P3 | pitched by value is fun | settings |
| `ui/mode_picker_open`, `ui/mode_picker_close` | mode pop-up | P2 | whoosh / bubble | `ModePicker` |
| `ui/mode_chosen` | mode picked | P2 | | `HomeScreen.mode_chosen` |
| `ui/character_change` | cycling fish on home screen | P2 | could be per family (6 families) | `HomeScreen.character_changed` |
| `ui/pause`, `ui/unpause` | pause menu | P2 | | `pause_menu` |
| `ui/match_card` | match card appears | P2 | | `main._show_match_card` |
| `ui/player_join`, `ui/player_leave` | co-op slot joins/leaves | P2 | | `local_coop._join/_leave`, `NetSession.peer_*` |
| `ui/connect_fail` | online connection fails | P3 | | `NetSession.connection_failed` |

### 3.2 Your fish (`fish/`)

| Event id | When | P | Notes | Hook |
|---|---|---|---|---|
| `fish/stroke` | each swim stroke | P1 | **intensity = stroke quality.** The swim strokes are rhythmic, so this is the most musical sound in the game | `stroked(quality)` |
| `fish/stride` | Extra Swishy stride | P1 | pitched by `flow`, intensity by `timing`. A rising run while you hold good flow | `strode(timing, flow)` |
| `fish/stroke_miss` | badly timed stroke | P3 | soft "flub" | `stroked` with low quality |
| `fish/jump` | first jump | P1 | 3D | `jumped` |
| `fish/double_jump` | second jump | P1 | | `double_jumped` |
| `fish/dodge` | dodge/flip | P1 | swoosh | `dodged` |
| `fish/boost_start` | boost pressed | P1 | | `_update_boost` |
| `fish/boost_loop` | while boosting | P1 | loop, pitch follows speed | `_update_boost` |
| `fish/boost_stop` | boost released | P2 | tail | |
| `fish/boost_empty` | tried to boost with none left | P3 | | |
| `fish/supersonic` | crossing `SUPERSONIC_SPEED` | P2 | a "whoomp" + optional `fish/supersonic_loop` | speed check |
| `fish/land` | touching floor/wall after air | P2 | intensity = impact speed | `_detect_surface` |
| `fish/scrape_loop` | sliding along a wall/floor | P3 | loop | tyres/surface |
| `fish/breach`, `fish/splash` | leaving / re-entering the water surface | P2 | big one: also flips the World filter | `ocean`/surface |
| `fish/bow_wave_loop` | the bow wave in front of you at speed | P3 | loop, louder with Bow Grow Bow | `_update_bow_view` |
| `fish/bump` | bumping another fish (not a battery) | P2 | | contact |
| `fish/reset` | reset / respawn | P2 | | `request_reset` |
| `fish/teleport` | teleported | P2 | | `fish_teleported` / `_announce_teleport` |

### 3.3 Ball and arena (`ball/`, `arena/`)

| Event id | When | P | Notes |
|---|---|---|---|
| `ball/hit` | fish hits ball | P1 | **layers @1–@3 by impact speed.** The most-heard sound in Free Play / 1v1 |
| `ball/bounce` | ball off floor/wall/ceiling | P1 | intensity by speed |
| `arena/hoop_rim` | clipping a hoop's rim (obstacle course) | P2 | `hoop.gd` (not hooked yet) |
| `arena/hoop_through` | swimming through the next hoop (obstacle course) | P2 | `arena.gd`. Renamed from `ball/hoop_*` in phase 1: it's the fish that goes through |
| `ball/reset` | ball re-spawns | P2 | |
| `arena/bubble_column_loop` | each bubble column | P2 | 3D loop, `bubble_column.gd` |
| `arena/goal_net` | ball hits the back of the net | P1 | |

### 3.4 Matches: Free Play, 1v1, Hunt (`match/`)

| Event id | When | P | Notes |
|---|---|---|---|
| `match/countdown` | 3-2-1 | P1 | pitched: three steps |
| `match/go` | kickoff | P1 | |
| `match/goal_horn` | goal scored | P1 | the big moment. One horn for both teams. An arena can override it with `match/goal_horn_<arena>` (e.g. `_aquarium`), which falls back to the generic horn, so new arenas can get their own later |
| `match/goal_replay_in`, `match/goal_replay_out` | goal replay starts/ends | P2 | |
| `match/clock_tick` | last 10 seconds | P2 | pitched, climbing |
| `match/time_up` | buzzer | P1 | `_time_up` |
| `match/overtime` | overtime starts | P2 | |
| `match/win`, `match/lose`, `match/draw` | result | P1 | `_finish_match` |
| `hunt/target_spotted` | Hunt: quarry seen | P2 | |
| `hunt/caught`, `hunt/escaped` | Hunt result beats | P2 | |

### 3.5 Battered (`battered/`)

Battered sounds are our crunchiest, most satisfying hits. Never "demo".

| Event id | When | P | Notes |
|---|---|---|---|
| `battered/battery` | you batter something | P1 | intensity by `batter_speed` |
| `battered/battered` | you get battered | P1 | different colour from dealing one |
| `battered/fish_fry` | a double (Fish Fry) | P1 | voice-ish stinger on the `Voice` bus |
| `battered/fish_fry_more` | triple and up | P2 | pitched: climbs with the count |
| `battered/out` | victim knocked out / respawning | P2 | |

### 3.6 Nature (`nature/`)

| Event id | When | P | Notes | Hook |
|---|---|---|---|---|
| `nature/school_loop` | a school nearby | P2 | 3D loop, fluttery; one per *nearby* school only | `school.gd` |
| `nature/school_scatter` | school startled | P2 | | |
| `nature/target_lock` | target wheel locks a target | P1 | | `target_wheel.gd`, `set_focus` |
| `nature/target_cycle` | cycling targets on the wheel | P2 | quiet tick | |
| `nature/battery` | batter a school fish | P1 | | `_batter_school_fish` |
| `nature/pearl_drop` | pearl appears | P2 | | `drop_pearl` |
| `nature/pearl` | pearl collected | P1 | **pitched, climbs a scale on a streak** | `_on_pearl_collected` |
| `nature/style` | style points awarded | P2 | intensity by size | `style_points.gd` |
| `nature/target_respawn` | new target placed | P3 | | `_respawn_target` |

### 3.7 Unnatural (`unnatural/`)

**Your attacks:** one fire sound and one hit sound per kind (`FishAttack.Kind`):

| Event id | P |
|---|---|
| `unnatural/attack_own_fire`, `_hit` | P1 |
| `unnatural/sting_fire`, `_hit` (Anemone Sting) | P1 |
| `unnatural/bite_fire`, `_hit` (Ghost Bite) | P1 |
| `unnatural/lash_fire`, `_hit` (Shock Lash) | P1 |
| `unnatural/thrust_fire`, `_hit` (Bill Thrust) | P1 |
| `unnatural/bubbles_fire`, `_hit` (Bubble Volley) | P1 |
| `unnatural/spines_fire`, `_hit` (Spine Burst) | P1 |

**Zombies** (per `EnemyKind.Behaviour`: chase, swarm, tank, lunge, glide). A profile only
*needs* the generic one; per-behaviour files override it if present.

| Event id | When | P | Notes |
|---|---|---|---|
| `unnatural/zombie_spawn` | rising from the seabed | P3 | heavily rate-limited |
| `unnatural/zombie_moan_loop` | ambient horde moan | P2 | **one** loop whose volume follows how many are near. Not per zombie |
| `unnatural/zombie_hit` | a zombie takes damage | P1 | aggregated per frame |
| `unnatural/zombie_die` (+ `_chase`/`_swarm`/`_tank`/`_lunge`/`_glide`) | kill | P1 | aggregated; layers by kill count this frame |
| `unnatural/lunge_telegraph` | lunger winds up | P1 | gameplay-critical warning: you should hear it coming |
| `unnatural/lunge` | lunger strikes | P2 | |

**You and your team:**

| Event id | When | P | Hook |
|---|---|---|---|
| `unnatural/hurt` | you take damage | P1 | `player_hurt` |
| `unnatural/low_hp_loop` | heartbeat under ~25% HP | P2 | |
| `unnatural/downed` | you go down | P1 | `player_down` |
| `unnatural/revive_loop` | being revived (co-op) | P2 | |
| `unnatural/revived` | back up | P1 | `player_revived` |
| `unnatural/xp` | XP orb collected | P1 | **pitched, climbs on a streak** | `xp_claimed` |
| `unnatural/level_up` | level up | P1 | `leveled_up` |
| `unnatural/cards_offered` | level-up cards fan out | P1 | `cards_offered` |
| `unnatural/card_reveal_common` … `_legendary`, `_boss`, `_cursed` | a card's rarity shows | P2 | a rising rarity ladder; cursed should feel *wrong* |
| `unnatural/card_picked` | card chosen | P1 | `card_picked` |
| `unnatural/pickup_heart`, `_magnet`, `_hourglass` | `Pickup.Kind` | P1 | `pickup_taken` |
| `unnatural/magnet_pull_loop` | magnet hoovering up XP | P3 | |
| `unnatural/chest_buried` | chest appears | P2 | `chest_buried` |
| `unnatural/chest_open` | open it | P1 | `chest_opened` |
| `unnatural/powerup_lost` | Sunken Idol takes one | P2 | `powerup_lost` |
| `unnatural/pearl` | pearl currency | P2 | shares the Nature pearl scale |

**Powerups:** the passive stat ones (Barnacle Plating, Hermit Shell, Fizzy Soda, Speedy
Seahorse) only need the card-pick sound. The active ones each get their own:

| Powerup | Event ids | P |
|---|---|---|
| Greek Fire Trail | `pw/greek_fire_loop` (burning patch, 3D), `pw/greek_fire_burn` | P2 |
| Chain Lightning | `pw/chain_zap` (pitched up per jump) | P1 |
| Torpedo Launcher | `pw/torpedo_launch`, `pw/torpedo_loop`, uses `fx/explosion` | P1 |
| Bow Grow Bow | louder `fish/bow_wave_loop` | P3 |
| Remora Buddy | `pw/remora_nip` | P2 |
| Bubble Wrap | `pw/bubble_wrap_ready`, `pw/bubble_wrap_pop` | P1 |
| Pufferfish Spines | `pw/puffer_spines` | P2 |
| Jellyfish Halo | `pw/jelly_halo_loop`, `pw/jelly_sting` | P2 |
| Electric Eel | `pw/eel_shock_ring` | P1 |
| Depth Charges | `pw/depth_charge_drop`, `pw/depth_charge_arm`, `fx/explosion` | P1 |
| Anglerfish Lure | `pw/lure_drop`, `pw/lure_loop`, `pw/lure_burst` | P2 |
| Tsunami Heart | `pw/tsunami_wave` | P1 |
| Drowned Fin | `pw/drowned_fin_charge_loop`, `pw/drowned_fin_dash` | P1 |
| Leviathan's Coil | `pw/coil_loop`, `pw/coil_hit` | P2 |
| Cursed (all five) | `pw/cursed_take` (pick-up), plus Siren's Song could tint the zombie moan | P2 |

**Stage events** (`StageTimeline.EVENTS`): each has a **warning** (it's coming) and a
**start**.

| Event id | P |
|---|---|
| `stage/ring_warn`, `stage/ring` (THE RING CLOSES) | P1 |
| `stage/miniboss_warn` (THE DROWNED SHARK RISES) | P1 |
| `stage/boss_warn` (THE BLOOD LEVIATHAN WAKES; added in phase 3) | P1 |
| `stage/stampede_warn`, `stage/stampede` | P1 |
| `stage/tide_warn`, `stage/tide` | P1 |
| `stage/blood_moon` (rises), `stage/blood_moon_loop` | P2 |
| `stage/complete` | P1 |
| `stage/run_over` | P1 |

**Bosses:**

| Event id | When | P |
|---|---|---|
| `boss/shark_arrive` | Drowned Shark arrives | P1 |
| `boss/shark_telegraph` | before a charge (`Mode.TELEGRAPH`) | P1 (gameplay warning) |
| `boss/shark_charge` | the charge | P1 |
| `boss/leviathan_arrive` | Blood Leviathan arrives | P1 |
| `boss/leviathan_phase` | `phase_changed` (circle → spit → fury) | P1 |
| `boss/leviathan_spit` | a spit attack | P2 |
| `boss/enraged` | `enraged_now` | P1 |
| `boss/hit` | boss takes damage | P1 |
| `boss/defeated` | `boss_defeated` | P1 |

### 3.8 Shared FX (`fx/`)

| Event id | When | P |
|---|---|---|
| `fx/explosion` | `explosion.gd` (torpedoes, depth charges, lure) | P1 |
| `fx/burst_cloud` | `burst_cloud.gd` | P2 |
| `fx/shock` / `fx/ring` / `fx/flash` / `fx/spikes` / `fx/pop` | `PowerupFx.Shape` generic fallbacks | P3 |

### 3.9 Ambience (`amb/`)

| Event id | Where | P |
|---|---|---|
| `amb/arena_loop` | the obstacle course | P2 |
| `amb/aquarium_loop` | the aquarium arena (Free Play, 1v1) | P2 |
| `amb/ocean_loop` | open water (Nature, Free Swim, Hunt) | P2 |
| `amb/seabed_loop` | Unnatural seabed (and the Test Tank's) | P2 |
| `amb/murk_loop` | crossfades in as the water thickens | P3 |
| `amb/surface_loop` | above the waterline | P3 |

### 3.10 Music (optional, `music/`)

Out of scope for the first pass, but the profile system is ready for it: `music/menu`,
`music/match`, `music/nature`, `music/unnatural`, `music/boss`, `music/victory`. These
play on the Music bus and crossfade by mode. Music files sit in a profile's `music/`
folder, but the separate **Music** picker (§2.3) chooses which profile's music plays.

**Count:** about 60 P1 events, 60 P2 and 25 P3. A usable first profile is roughly the P1
list.

---

## 4. Build phases

| Phase | What | Done when |
|---|---|---|
| **0. Foundation** | Buses, `SoundCatalog`, `SoundProfile`, `Sfx` autoload with the built-in silent **`None` profile selected by default**, Settings (volumes + sound profile picker + music picker), debug "Beep for missing sounds", Sound Board + Reload, recording sheet, built-in Beeps profile, `audio_probe.gd` | **Built 2026-10-18**: audio_probe passes (66 checks), ui/modes/pause/controls probes pass. Build 10:24 |
| **1. Core feel** | UI, fish movement (strokes, stride, jump, dodge, boost), ball, goals, match flow | **Built 2026-10-18** (12:05 build): `audio_hooks_probe` passes. See Â§4.1 |
| **2. Battered, Nature, Hunt** | §3.5, §3.6, Hunt rows | **Built 2026-10-18**: `audio_hooks2_probe` passes. See §4.2 |
| **3. Unnatural** | attacks, zombies (with aggregation), pickups, cards, powerups, stage events, bosses | **Built 2026-10-18**: `audio_hooks3_probe` passes; `split_bench` (3 players, 2000 zombies) with and without the hooks is the same within noise (about 21 ms either way). See §4.3 |
| **4. Space** | underwater bus filter, surface breach, murk, ambience loops, bubble columns, split-screen listener (A3) | **Built 2026-10-18**: `audio_hooks4_probe` passes. See §4.4 |
| **5. Music** (if wanted) | | |

### 4.1 Phase 1: how it's hooked up

`Sfx` makes an `SfxHooks` node (`scripts/audio/sfx_hooks/`), which watches every node entering
the tree and adds a sound node to it: `FishSounds` on each fish, `BallSounds` on the ball,
`ArenaSounds` on the aquarium (the goal net and horn, in Free Play too), `MatchSounds` on a
1v1. It also sweeps the tree once when it starts: the game's startup scene is readied together
with the autoloads, so its fish, ball and arena never pass through `node_added` (the 12:05
build missed them; fixed in the 12:21 build). Menus are hooked up there too. Gameplay code only gained a few signals:
`FishController.stroke_beat` (every stroke the rhythm hears, missed ones too; `stroked` still
only fires on tempo), `FishController.respawning` (R in Free Play, or back from a battery
mid-play) and `Ball.respawned`. `Sfx.requested` reports every sound asked for (probes).

**UI sounds are settled once a frame.** One press can move focus, press a button and open a
menu, and only the most specific sound plays: a menu's own sound (mode picked, pause, toggle)
beats `ui/select`, which beats `ui/back`, which beats `ui/move`. Focus landing, a back press
or the mode picker closing within 150 ms of another UI sound stays quiet. A button can set
meta `sfx` to its own id, or `""` for none (the Sound Board's rows play their event instead).

**Hooked in phase 1:** all of `ui/` except `ui/denied`; `fish/` stroke, stride, stroke_miss,
jump, double_jump, dodge, boost_start/loop/stop/empty, supersonic, land, reset; `ball/hit`,
`ball/bounce`, `ball/reset`; `arena/goal_net`, `arena/hoop_through`; `match/` countdown, go,
goal_horn(_aquarium), goal_replay_in/out, clock_tick, time_up, overtime, win, lose (draw
can't happen in a 1v1, but is hooked).

**Left for later:** `ui/denied` (nothing in the menus refuses a press yet), `fish/teleport`
and `fish/bump` (with Battered, phase 2), `arena/hoop_rim`, `fish/scrape_loop`,
`fish/bow_wave_loop`, `fish/breach`/`fish/splash` and bubble columns (phase 4), Hunt's
match sounds (phase 2). An online guest's copy of another player's fish (a puppet) makes
no sound yet. In split-screen every view hears world sounds, so a sound near both players
plays twice until phase 4's shared mix (A3).

From phase 1 on, you can record in parallel: each phase's events appear on the Sound
Board and in the sheet as they're hooked up.

### 4.2 Phase 2: Battered, Nature, Hunt

`SfxHooks` adds: `BatteredSounds` to every `Match1v1` and `HuntMatch` (`battered`, with a null
attacker for a Fish Fry), `MatchSounds` now also to a Hunt (the countdown, last ten seconds,
buzzer, replays and result read off the same state), `NatureSounds` to every `NatureRun`,
`WheelSounds` to every `TargetWheel`, and `FishSounds` hears two fish touching.

- **Battered:** `battered/battery` (you land one: 3D at the victim, harder by speed) or
  `battered/battered` (you take one), then `battered/out` 0.35 s later. A Fish Fry is
  `battered/fish_fry` plus `voice/fish_fry`, and both fish go out.
- **Nature:** `nature/battery` (school fish and the lone fish, harder by speed),
  `nature/pearl_drop`, `nature/pearl` (pitched: each pearl within 2 s of the last climbs a
  step), `nature/style` for multis and sprees (bigger awards are harder), the multi's Fish Fry
  (a double is `battered/fish_fry` + `voice/fish_fry`; a triple and up is
  `battered/fish_fry_more`, climbing with the count), `nature/target_respawn` when the lone
  fish turns up, `nature/school_loop` on the nearest three schools within 70 m (swelling as you
  near, faster when they're scared) and `nature/school_scatter` when one startles.
- **Target wheel:** `nature/target_cycle` as the stick moves to another slice,
  `nature/target_lock` when it closes on one.
- **Hunt:** the hunter locking on (`hunt/target_spotted`: `StylePoints.is_threatened(0)` is
  new), batter you (`hunt/caught`) and your close calls and dodges (`hunt/escaped`). The
  descriptions in the catalog changed to say so.
- **Fish bumps:** `fish/bump` for two fish touching that didn't batter each other (judged one
  physics step later, so a battery's own sound isn't doubled).

**Left for later:** `fish/teleport` (nothing moves a fish mid-play; kickoffs and resets have
their own sounds, so it stays in the catalog marked reserved). Online, an opponent's puppet
fish still makes no sound of its own, but every event above comes off a signal that fires on
both machines.

### 4.3 Phase 3: Unnatural

`SfxHooks` adds `UnnaturalSounds` to every `UnnaturalRun` (which covers the Test Tank) and
`BossSounds` to every `Boss`, and watches every `FishAttack`. The gameplay code gained a few
signals: `UnnaturalRun.zombie_hit` (hit(), the one door every hit goes through, and a guest's
claimed hits) and `pearl_collected`, `Horde.lunge_stage`, and `FishAttack.fired`. The powerups
play their own sounds (`Sfx.play_at(...)` next to their effect), because each has several
moments of its own; `Sfx.loop_for(id, node)` gives a loop that lasts as long as a node does.

- **Gathered per frame:** zombie deaths (by behaviour, `unnatural/zombie_die_<chase|swarm|tank|lunge|glide>`),
  hits, boss hits and spawns make one sound each per frame, at their middle, harder (the @
  layers) the more there were: 40 kills in a frame are one crunch.
- **Your hits by source:** an attack's `<kind>_hit`; a battery is `battered/battery`; a
  powerup's own (`pw/greek_fire_burn`, `pw/remora_nip`, `pw/jelly_sting`, `pw/coil_hit`;
  Chain Lightning's `pw/chain_zap` climbs a step per jump); a boss's body is `boss/hit`;
  anything else (a blast, a ring) is `unnatural/zombie_hit`. Every attack falls back to
  `unnatural/attack_own_fire` / `attack_own_hit`, so one recording covers all of them until you
  want each its own.
- **XP:** there are no orbs (kills pay XP straight to the team), so `unnatural/xp` is a
  pitched sound once a frame a kill of yours lands, climbing while kills keep coming (1 s window).
- **You and your team:** hurt, downed, revived, level-up (`voice/level_up` too), cards fanning
  out then the rarest card's reveal 0.3 s later, the card picked (and `pw/cursed_take` for a
  cursed one), the three pickups, pearls (pitched streak), chests buried and opened, a powerup
  lost.
- **Loops (looked after five times a second):** `unnatural/zombie_moan_loop` (volume with the
  zombies within 35 m), `unnatural/low_hp_loop` (under a quarter of your hp, faster as it
  drops), `unnatural/revive_loop`, `unnatural/magnet_pull_loop` (2 s after the magnet).
- **Beds:** `amb/seabed_loop`, `stage/blood_moon_loop` and `stage/blood_moon` when the run starts.
- **Stage:** each event's `stage/<event>_warn` and `stage/<event>` (and `voice/<event>_warn`
  where there is one) off `stage_warned` / `stage_event`; `stage/boss_warn` is new. Boss
  arrivals (`boss/shark_arrive`, `boss/leviathan_arrive`, `voice/boss_arrive`), rage,
  defeat, the stage complete, a run over. A boss's moves are `BossSounds`: the Shark's
  wind-up and charge (read off its mode), the Leviathan's phases and spit.
- **Powerups** (in the powerup scripts): torpedoes launch, run (a loop that swells with how many
  are flying) and blast (`fx/explosion`); depth charges drop, arm and blast; the lure drops
  (with a glowing loop), bursts; the Tsunami Heart's wave; the Eel's ring; the Puffer's spines;
  the Drowned Fin's dash (with a loop while it lasts, standing in for the charge); Bubble Wrap
  ready and pop; Greek Fire patches, the Jellyfish Halo and Leviathan's Coil loop. A burst
  cloud is `fx/burst_cloud`.

**Left for later:** the generic `fx/shock`, `fx/ring`, `fx/flash`, `fx/spikes` and `fx/pop`
(the powerups have their own sounds, so these stay unplayed), and Traversal's leap burst. A
puppet's powerups (an online guest's copy of another player) make no sound; the player on
their own machine hears them.

### 4.4 Phase 4: Space

- **Beds:** `BedSounds` on each environment: `amb/arena_loop` (the obstacle course),
  `amb/aquarium_loop` (Free Play, 1v1), `amb/ocean_loop` (Free Swim, Nature, Hunt). An
  Unnatural run has its own seabed, so the Ocean's bed gives way to it. A replay has none (it
  has its own soundtrack).
- **Murk:** the Ocean's fog density above the scene's clear water (0.012) swells
  `amb/murk_loop` and closes the World bus's low-pass from 4200 Hz toward 1500 Hz (0.072 is the
  thickest). Unnatural's murk and an arena's edge both do it.
- **The surface:** `Sfx.water_surface` (INF where a place has none). A fish crossing it up
  breaches (`fish/breach`) and down splashes (`fish/splash`, harder by vertical speed); a
  camera above it opens the low-pass to 18 kHz and fades `amb/surface_loop` in. **Nothing in
  the game reaches the surface yet** (Unnatural sets it to the blood moon's water line, which
  sits above the arena's ceiling), so this waits for a place with a real waterline.
- **Bubble columns:** `arena/bubble_column_loop` on each, for as long as it stands.
- **Scraping and the bow wave:** `fish/scrape_loop` (sliding along a surface faster than
  3 m/s, louder and higher with speed) and `fish/bow_wave_loop` (volume with the bow wave's
  size, so louder with Bow Grow Bow), both following the fish. `arena/hoop_rim` for clipping a hoop.
- **Split-screen (A3):** only the first player has ears, so `Sfx.heard_at()` moves a world sound
  in along its line to the nearest player's distance: as loud as it is for whoever is nearest.
  `SfxHooks` keeps `Sfx.ears` (the local fish when there's more than one).
- **Underwater filter (A4):** the World bus's low-pass and reverb were already there from phase
  0; a profile with `underwater_filter=false` switches them off.

**Left for later:** `ui/denied` (nothing in the menus refuses a press), `fish/teleport`.

**Tools:** `tests/audio_hooks2_probe`, `audio_hooks3_probe` and `audio_hooks4_probe`; `split_bench`
takes `--no-sfx-hooks` to compare frame times.

---

## 5. Decisions

All answered 2026-10-18.

| # | Question | Decision |
|---|---|---|
| **A0** | Starting profile | The built-in silent **`None`**, selected by default. The Sound Board can still audition any profile while it's selected. Likely retired once a real profile is finished |
| **A1** | File-name rules | `-N` variations / `@N` layers / `_nNN` notes (§1.2), all optional |
| **A2** | Music | Part of a profile's folder, chosen by a separate **Music** picker that defaults to "same as sound profile" |
| **A3** | Split-screen | One shared mix, each sound as loud as it is for the nearest player |
| **A4** | Underwater filter | On for every profile; a profile can opt out |
| **A5** | Goals | A single horn, with an optional per-arena override |
| **A6** | Mix | Per profile (`[mix]` in `profile.cfg`) |
| **A7** | Profile per player in split-screen | No, one per machine |
| **A8** | Shipped profiles | Whatever you finish. The built-in Beeps stay as the placeholder/gap-finder |
| **A9** | Missing sounds | Silent. A debug toggle, **Beep for missing sounds**, plays the placeholder instead |
| **A10** | Where profiles live | In the repo (`audio/profiles/`), hot-reloaded when running from the project |
| **A11** | Announcer | An optional `voice/` callout layer on its own bus and slider |
