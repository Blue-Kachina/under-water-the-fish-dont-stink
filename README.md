# Under Water The Fish Don't Stink

A swimming game with Rocket League-style movement. See
[`fish_movement_game_development_plan.md`](fish_movement_game_development_plan.md) for the design.

The current build is a **movement playground**: an underwater arena with hoops, obstacles,
speed readouts and a live tuning panel for dialling in how the fish handles.

Pick a mode from the settings panel's *Mode* dropdown (remembered per PC, apart from Replays):

- **Free Play**: the Aquarium Arena with a ball, on your own.
- **1v1**: the Aquarium Arena against a bot.
- **Free Swim (Ocean)**: endless open water with no walls, floor or obstacles. Floating specks
  surround you wherever you go, and the water is lighter above and darker below so you can tell
  up from down.
- **Nature**: the Ocean, with no boost and the **Extra Swishy** swim style (see below). The boost
  button holds the direction lock instead (*Boost Button Locks*). It starts on a
  card; after **Play**, a calm fish waits ahead and ball cam locks onto it. Ram it nose first at 10 m/s
  or more (*Nature Batter Speed*) to batter it, and a new one turns up 30-50 m away.

  **Schools.** Harmless fish (`School`) swim around you in schools, together and mostly in unison:
  three schools of fifty by default. Ram through one at speed to batter as many as you can; each
  costs you a little speed. A school tightens into a bait ball and swerves when you rush it, and
  bursts apart for a moment when one of its fish is battered.

  **Points** (`NatureScore`, Unreal Tournament style):
  - battered fish close together chain into multis: Double Dip, Triple Fry, Fish Supper, Feeding
    Frenzy, Monster Catch, with a draining bar under the counts for the time left;
  - a run of them without slowing down is a spree: Spring Roll, Riptide, Apex Predator, Unstoppable,
    Poseidon.

  **Pearls.** Battered fish sometimes leave a glowing pearl, more often deeper into a multi. Swim
  over or near one and it's drawn in; for now they're only counted.

  **Ball cam (Y).** A tap looks at whatever is nearest ahead, the lone fish or a school. Hold it to
  open the **school wheel**: a slice for each school, placed the way it lies from you, with its
  fish and distance. Pick one with the right stick (IJKL) and let go. Arrows at the screen's edge
  point to schools off screen.

  **Tuning.** Everything is in the panel's **NATURE** section (schools, formation, reactions,
  battered fish, multis, pearls, targeting, performance) and changes live. Schools are drawn as baked
  meshes, one per tail pose, with full models only for the few fish nearest the camera, so
  hundreds of fish stay cheap. Nature has its own tuning (`presets/nature.cfg`); leaving Nature
  puts your tuning from before back, and the changes you made in Nature are there again next time
  (until you close the game).

  **Co-op** (`going_coop.md`), 2 to 4 players hunting the same schools, with a shared count of
  fish battered and pearls, and each player's own points, multis and sprees:
  - **Split-screen** (`LocalCoop`): during a Nature run, press **Back/View** on another controller
    to join, with your own fish, camera, HUD and school wheel. **D-pad left/right** changes a joined
    player's fish, and holding **Back/View** for a second leaves. The first player keeps the
    keyboard and their own controller, and their tuning applies to everyone. Two players ramming
    the same fish at once both get the credit. Co-op fish swim through each other.
  - **Online** (`NetSession`, `CoopSession`): pause menu → **Co-op online**. **Host** on a port, or
    **Join** an address (LAN, or a port-forwarded host). The host's world is everyone's: its
    schools, lone fish, pearls and counts. Only the host tunes; a guest's fish and Nature tuning are
    the host's and locked while they play, and come back when they leave. Your own fish has no
    added lag; everyone else's is shown a tenth of a second behind, smoothly. A guest can't
    restart the run (R just puts their own fish back); the host can, for everyone. The pause
    menu doesn't pause an online game. Steam is switched off for now (`NetSession.STEAM_ENABLED`):
    under Steam's test App ID it takes the controller over. When it's on, **Host on Steam** / **Invite friends** show up once the
    [GodotSteam](https://godotsteam.com) addon (`addons/godotsteam`) finds Steam running: a friends-only
    lobby over Steam's relays, no addresses or ports (test App ID 480 until the game has its own;
    `--no-steam` keeps Steam out of a run). Steam's invite overlay only appears when Steam launched
    the game, so the menu also shows the lobby's number with **Copy**: a friend pastes it into
    **Lobby** and presses **Join** (or, with the game already running, uses **Join Game** in your
    friends list).
    Command line: `-- --host` or `-- --join=ADDRESS`, `--port=N`, and for testing a bad
    connection `--lag=MS --jitter=MS --loss=0.05` (also in the Co-op menu).
  - Tests: `tests/coop_local_probe`, `tests/school_sync_probe`, and `tests/coop_net.sh` (a host, a
    laggy guest and a late joiner, each its own Godot). `tests/split_shots` (needs a window) shows
    1-4 player split-screen and its frame times.
- **Hunt**: a 1v1 in the Ocean on Nature's tuning against a hostile fish (`HunterBot`, Basic
  difficulty) that swims with exactly your mechanics and is out to batter you. Getting
  **Battered** is a goal here: ram the other fish nose first at *Nature Batter
  Speed* or faster. Rammed by each other at once, the faster fish scores (the same speed: both are
  battered, a **Fish Fry**, and nobody scores). After each one, a replay (unless *Goal replays* is
  off), shot arcade style: the fish show their stride tails, bow waves and bubbles as they were, the
  vignette closes in with the attacker's flow, and the impact hits with a hit-stop, flash, punch-in
  and shake. Then a kickoff with both fish back on their lanes. 5 minutes on
  the clock; level on goals at 0:00, the most **points** wins (close call +25, dodge +50, every 4
  perfect strides in a row +10, battered +100), and level on those too, overtime's next
  batter wins. The arena reaches 90 m out from the centre: near its edge the water
  darkens, and past it you're pushed back in. Hold D-pad up / B for the scoreboard (fish battered
  are its BATTERED FISH column). `tests/battery_replay_shots` (needs a window) renders a battery replay.
- **Obstacle Course**: walled arena with a timed 10-hoop course, tunnel, pillars, ramps and an arch.
- **Replays**: watch Rocket League replays in the Aquarium Arena. Pick one with **Replay...** in the
  replay bar, or drop a `.replay` / `.rlreplay.json` on the window from any mode. **Close** goes back
  to the mode you came from.

Modes and the environment each is played in are listed in `MODES` and `MODE_ENVIRONMENTS` in
`scripts/main.gd`.

## Running it

Open the project in Godot 4.7 (or from Rider) and press **Play** (F5). An Xbox controller is
recommended; keyboard works for quick checks.

| Action | Xbox | Keyboard |
|---|---|---|
| Swim forward | RT | W |
| Reverse / brake | LT | S |
| Pitch / yaw | Left stick | Arrows (A/D also yaw) |
| Boost | RB | Shift |
| Jump; press again within 1.25 s to double jump, or with the stick pushed to dodge | A | Space |
| Powerslide / Air roll (see below) | LB (hold) | Ctrl / C (hold) |
| Ball cam | Y | Y |
| Roll left / right | X / B | Q / E |
| Look around | Right stick | I J K L |
| Pause (Resume, reset, Settings); B or Start again resumes | Start | Esc / F1 |
| Reset fish and course (1v1: restart kickoff; Hunt: restart match) | Pause menu | R |

The settings panel opens from the pause menu's **Settings**, so it's only reachable with the game
paused.

The controller buttons are the **Personal** profile (`Controls.DEFAULT_PROFILE`), remembered per
PC. Sticks, triggers and keyboard keys are the same in every profile. Profiles live in `PROFILES`
in `scripts/controls.gd`; the panel's *Controller profile* picker is hidden for now.

*Powerslide / Air roll* is one button doing both jobs, as RL's shared bind: on a surface it
powerslides and the stick steers; off it (in the air or water) the stick's left/right rolls the
fish instead of turning it (free air roll).

**Swim strokes:** sweep the left stick side to side (or up and down) in a steady rhythm. The first
two beats set the tempo; every on-tempo beat after that adds a small speed boost. An off-tempo
beat breaks the rhythm, and mashing gives nothing. Sweeps also steer, so the fish wiggles as it
swims; a lower *Steer Response* makes that gentler.

**Extra Swishy** (Nature, or *Swim Style* in the panel's Swim Strokes): while you hold throttle,
each sweep of the left stick to the opposite side is a stride, like a skater pushing off alternate blades. Any direction works
(left/right, up/down, diagonal), as long as each sweep goes back the other way through the middle;
circling the stick does nothing. A stride's push builds to a peak (*Stride Peak Time*), then fades.
Strides drive the tail: push right and it sweeps across to the left, arriving at the far side at the
peak, ready for the push back the other way (*Stride Tail Swing*); it relaxes to the middle as a
stride fades. The fish's tail is also the timing cue: it lights up from its root to its tip like a progress bar
as the stride builds, reaching the tip (and turning gold) at the peak, then dims as the stride fades.
Sweeping back right at the peak builds **flow**, which multiplies every stride's push. Too early and the stride hadn't
built up; too late and it had already faded. Each stride pushes a little sideways away from the
sweep, so alternate strides weave forward. Steering follows a smoothed stick (*Stride Steer
Smoothing*), so alternating sweeps mostly cancel out while a held direction still turns. Without
throttle the stick just steers, directly, as in the other modes (*Stride Needs Throttle*).
`tests/swishy_probe` measures the timings. The bottom of the screen shows how the last stride was
timed (EARLY / PERFECT / LATE) and the flow.

Strides get visibly more powerful as flow builds: the tail grows (*Stride Tail Growth*, Battletoads
style) and swells on each stride, and while a stride pushes, the tail pours a tight stream of tiny bubbles like a
boost trail, denser as the stride builds and with flow, coloured by its timing: pale, blue, gold for a
perfect one (*Stride Bubbles*). It stops once you're out of stride. The camera closes in a little
with flow and a vignette darkens the screen's edges, warming to gold near full flow, with speed
streaks when you're fast; a perfect stride punches the view in (camera *Arcade Zoom* / *Arcade
Punch*; `scripts/arcade_fx.gd`).

**Bow wave** (on in Nature, *Bow Wave* in the panel): speed pushes a mostly clear, torpedo-tip
shell of water out ahead of the fish, from *Bow Start Speed* to full size at *Bow Full Speed*. It
counts as the fish's front for battered fish, so a fast fish has a bigger target area, but it doesn't
push anything. `tests/stride_shots` (needs a window) renders the tail cue and the bow wave on
every fish.

**Boost works at any time**, including mid-dodge, and always pushes the way the fish is facing.
A flip cancel hands control straight back (throttle, boost, camera) while the spin winds down.

**Direction lock** (keyboard F): keeps the nose pointed where it faced
when pressed. No turning, but rolling still works.

**Roll and dodge timing match Rocket League:** air roll, dodge flips and flip cancels use
RocketSim's constants at the same 120 Hz tick rate. A full roll from rest takes 1.242 s (149 ticks).
Flips complete in the time they do in RL when you hold the flip direction: 1.333 s for front/back
flips (0.65 s of flip torque, 0.3 s pitch lock, then held pitch) and 1.150 s for side flips (as if
holding air roll). Pull the stick against a front/back flip during its first 0.65 s to cancel it,
for half flips. RL's flip Z-damp is in too: early in a flip most vertical speed is removed, so
dodges stay flat. `tests/roll_timing_probe` checks all of this against a reference simulation.
Toggles in the panel: *RL Roll Timing*, *RL Dodge Timing*, *Complete Flips*, *RL Flip Z Damp*.

Stick forward pitches the nose **down**, as in Rocket League (`invert_pitch` in the panel flips it).

## Making a standalone build

Needs the Godot 4.7.2 export templates (Editor → Manage Export Templates). Then either use
Project → Export → "Windows Desktop", or from the command line:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Windows Desktop" builds/windows/FishPlayground.exe
```

Builds go to `builds/` (ignored by git).

## Tuning

The panel lists every `@export_range` float and `@export` bool on the fish
(`scripts/fish_controller.gd`) and camera (`scripts/follow_camera.gd`). Add a new exported
value to either script and it shows up automatically.

Tuning is saved as **presets**: **Save...** asks where to save one (Save As), **Load...** opens one,
**Default** goes back to the defaults (Rocket League's) and **Copy** puts the values on the clipboard.
Both pickers open in the presets folder,
`%APPDATA%\Godot\app_userdata\Under Water The Fish Don't Stink\presets`, where the shipped
presets in `presets/` (such as **Water**, the original underwater tuning) are copied on startup.
A preset only needs to list what it changes: loading one applies the defaults first. The preset
last saved or loaded is loaded again at startup.

Rotation defaults match community measurements of Rocket League's aerial physics, so it should
feel familiar before you start changing things.

For numbers instead of feel, run the scripted probe:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/movement_probe.tscn
```

## Project structure

```
scenes/          main.tscn (playground), fish.tscn (placeholder fish)
scripts/         GDScript gameplay code
  controls.gd        input bindings (autoload "Controls")
  fish_controller.gd swimming physics
  follow_camera.gd   chase camera
  arena.gd, hoop.gd  procedurally built arena and hoop course
  hud.gd, debug_panel.gd
shaders/         grid.gdshader (world-space grid for speed perception)
tests/           movement_probe (headless scripted input test)
addons/under-water-the-fish-dont-stinkExt/   GDExtension plugin (C++ output lands in bin/)
native/under-water-the-fish-dont-stinkExt/   C++ source + godot-cpp submodule (pinned to 10.0.0-stable)
cmake/           godot-cpp setup and addon download helpers
```

## Building the native (C++) extension

Gameplay is GDScript; the C++ extension is only scaffolding for later (e.g. a RocketSim spike).

1. Configure: `cmake -B cmake-build-debug -S .`
2. Build: `cmake --build cmake-build-debug`

The compiled library is copied to `addons/under-water-the-fish-dont-stinkExt/bin/` after each build.

> **Note:** godot-cpp's binding generator fails if the project path contains an apostrophe.
