# Under Water The Fish Don't Stink

A swimming game with Rocket League-style movement. See
[`fish_movement_game_development_plan.md`](fish_movement_game_development_plan.md) for the design.

The current build is a **movement playground**: an underwater arena with hoops, obstacles,
speed readouts and a live tuning panel for dialling in how the fish handles.

Two environments, picked from the tuning panel's *Environment* dropdown (remembered per PC):

- **Obstacle Course**: walled arena with a timed 10-hoop course, tunnel, pillars, ramps and an arch.
- **Ocean**: endless open water with no walls, floor or obstacles. Floating specks surround you
  wherever you go, and the water is lighter above and darker below so you can tell up from down.
  Environments are listed in `ENVIRONMENTS` in `scripts/main.gd`.

## Running it

Open the project in Godot 4.7 (or from Rider) and press **Play** (F5). An Xbox controller is
recommended; keyboard works for quick checks.

| Action | Xbox | Keyboard |
|---|---|---|
| Swim forward | RT | W |
| Reverse / brake | LT | S |
| Pitch / yaw | Left stick | Arrows (A/D also yaw) |
| Boost | B | Shift |
| Jump; press again within 1.25 s to double jump, or with the stick pushed to dodge | A | Space |
| Air roll (stick yaws → rolls) | X (hold) | C (hold) |
| Powerslide (drift sideways, turn harder) | Y (hold) | Ctrl (hold) |
| Roll left / right | LB / RB | Q / E |
| Look around | Right stick | I J K L |
| Reset fish and course | Start | R |
| Show / hide tuning panel | View | F1 / Tab |

The table shows the **Default** controller profile. Pick another in the tuning panel's
*Controller profile* dropdown; the choice is remembered on that PC only. Sticks, triggers and
keyboard keys are the same in every profile. Profiles live in `PROFILES` in `scripts/controls.gd`.

| Profile | A | B | X | Y | LB | RB |
|---|---|---|---|---|---|---|
| Default | Jump | Boost | Air roll | Powerslide | Roll left | Roll right |
| Personal | Jump | Roll right | Roll left | — | Powerslide | Boost |

**Swim strokes:** sweep the left stick side to side (or up and down) in a steady rhythm for extra
speed on top of throttle. Steady timing gives full-strength strokes; mashing gives nothing. The HUD
shows your stroke count and timing.

Stick forward pitches the nose **down**, as in Rocket League (`invert_pitch` in the panel flips it).

## Making a standalone build

Needs the Godot 4.7.2 export templates (Editor → Manage Export Templates). Then either use
Project → Export → "Windows Desktop", or from the command line:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Windows Desktop" builds/windows/FishPlayground.exe
```

Builds go to `builds/` (ignored by git). Tuning saved inside a build goes to
`%APPDATA%\Godot\app_userdata\Under Water The Fish Don't Stink\tuning.cfg`; the panel's
**Copy** button puts the values on the clipboard so you can paste them into the project's `tuning.cfg`.

## Tuning

The panel lists every `@export_range` float and `@export` bool on the fish
(`scripts/fish_controller.gd`) and camera (`scripts/follow_camera.gd`). Add a new exported
value to either script and it shows up automatically. **Save** writes `res://tuning.cfg`, which
is loaded on startup, so committed tuning is shared through git.

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
