# Plan: "Nature" mode + "Extra Swishy" swim style

## Context
We want a new mode, **Nature**, built to make players *swim like a fish*. That was the original intent behind the rhythm strokes. In Nature:
- boost is off;
- the fish uses a new swim style, **Extra Swishy**, where alternating stick sweeps act like a skater's strides (or tail beats);
- a well-timed alternation compounds speed;
- a visual cue shows when to alternate.

The player gets a "begin" prompt, then is placed in open ocean near a non-hostile target fish. Ball cam locks onto that fish, and hitting it fast enough demolishes it.

The existing **Original** style stays exactly as it is for all other modes, since swim strokes are never removed. Extra Swishy is expected to need several feel-tuning loops, so every number goes through `@export` values. Those values show in the tuning panel and are saved in presets automatically.

Decisions already made:
- **Physics base:** the Water preset.
- **Cue:** both on the fish and on the HUD.
- **After a demo:** a new target spawns nearby.
- **Stride input:** physics-based. Any sweep direction counts, diagonals included; it should feel like cutting through water.

## Existing pieces to reuse
- `FishController` (`scripts/fish_controller.gd`):
  - stroke detection in `_detect_strokes` / `_register_stroke`;
  - `_apply_strokes` and `_apply_water`;
  - boost in `_update_boost`;
  - `demolish()` / `revive()`;
  - the `stroked` signal;
  - `is_option_active` (hides tuning options that don't apply).
- `main.gd`:
  - `MODES`, `MODE_ENVIRONMENTS`, `set_mode` / `_apply_mode`;
  - the match card (`_show_match_card`, `_match_card_text`, `play_match`);
  - `_sit_out` / `_come_back`, which currently assume AquariumArena and need generalising.
- `scripts/ocean.gd`: an open-water environment with no collision, endless specks and a sky gradient.
- `Match1v1` (`scripts/match_1v1.gd`):
  - the template for spawning a second fish (`_ready` 132–144);
  - `copy_tuning`;
  - `_check_demolition` / `_touching` (demo logic);
  - the respawn timers.
- `FishBot._celebrate()` (`scripts/fish_bot.gd`): a non-hostile wander pattern, and `_drive` has the steering math. Bots drive fish through a `FishInput`.
- `follow_camera.gd`:
  - `_focus()` returns `ball` (typed `Node3D`); a fish works as a target.
  - `_sweep` already ignores the `fish` group.
- `Explosion.spawn`, the HUD `_on_demolished` banner, the `xray_outline` shader (target visible through things), and `presets/water.cfg`.

## Design

### 1. Swim style switch (FishController)
- Add `enum SwimStyle { ORIGINAL, EXTRA_SWISHY }` and `@export var swim_style := SwimStyle.ORIGINAL`.
- Add `@export var boost_enabled := true`. When it is false, `_update_boost` forces `is_boosting = false`, and the HUD hides the gauge.
- `_detect_strokes` and `_apply_strokes` branch on the style. With ORIGINAL, the code path is unchanged.
- Put the Extra Swishy logic in a new `scripts/swishy_swim.gd` (a RefCounted owned by the controller) so `fish_controller.gd` doesn't grow. The controller calls `_swishy.sample(stick, delta)` and `_swishy.apply(state, forward, basis)`.
- Use `is_option_active` to show only the active style's tuning group, plus a new `@export_group("Extra Swishy")`.

### 2. Extra Swishy model (physics-based strides)
**What counts as a stride.**
- The stick is treated as the tail's bend direction in the fish's local plane: x = yaw sweep, y = pitch sweep, any angle.
- A stride starts when the stick leaves the deadzone in a direction roughly opposite the previous stride's extreme (`dot(dir, prev_dir) < -stride_reversal`, about -0.5).
- So left↔right, up↔down and diagonal↔opposite diagonal all count. Circling the stick does not.

**Thrust comes from the sweep itself.**
- Over a stride, the tail sweeps through the water.
- Thrust ∝ stick sweep speed × current stride power. Snappy, full sweeps cut harder than slow drifts, and a tiny wiggle gives almost nothing.
- **Direction:** mostly along the fish's forward axis, plus a small component opposite the sweep (`stride_side_angle`, about 10–15°).
- Because strides alternate, the side pushes cancel and you weave forward like a skater. This also gives the natural S-path.

**Power envelope per stride.**
- Each stride has a power curve P(t): it rises to a peak at `stride_peak_time` (about 0.35 s), then decays over `stride_fade_time`.
- Thrust is applied **continuously along this envelope** as force, not as an instant velocity jump. That gives the "push through the water" feel.

**Timing and compounding.**
- When the next opposite stride starts, its gain multiplier is `timing = P(t_since_prev) / P_peak`:
  - too early means the previous stride hadn't reached full strength;
  - too late means it has already faded in proportion to the time since the peak.
- A running `flow` value (0..`flow_max`) compounds: `flow = lerp(flow, flow + timing*flow_gain, …)`. A good stride raises it; a poor one bleeds it (`flow_loss`).
- Stride strength = `stride_force * (1 + flow) * timing`.
- `flow` also decays when you stop swimming.
- **Mashing:** a sweep that reverses before `stride_min_time` gives near-zero timing, so it gives nothing, consistent with Original.

**Exposed state.** These feed the cue and the probes:
- `stride_power` (the current envelope value 0..1);
- `stride_phase` (time since the stride started, divided by the peak time);
- `flow`;
- `last_timing`;
- a `strode(timing, flow)` signal.

**Water.** Nature loads a new `presets/nature.cfg`, derived from `presets/water.cfg`:
- drag lets speed bleed off between strides;
- the speed cap is high enough that a long, well-timed chain feels fast;
- `swim_style = EXTRA_SWISHY`, `boost_enabled = false`;
- buoyancy is close to neutral for open water.

### 3. Timing cue (on the fish + HUD)
- **On the fish:**
  - `fish_model.gd` bends the tail to follow the stick and the stride envelope;
  - the fin/tail glow and scale swell with `stride_power`;
  - there is a brief bright "sweet" flash while P is within about 90% of peak, which is the moment to alternate;
  - the hooks are the existing `_process` tail yaw/pitch (around fish_controller 1867), plus a skin shader parameter.
- **On the HUD:** `hud.gd` adds a small arc meter near the bottom centre:
  - the fill shows `stride_power` rising and falling;
  - a highlighted band marks the sweet spot;
  - a pip shows the last stride's timing (early, perfect or late);
  - a `flow` bar or multiplier is shown next to it.
- The boost gauge is hidden when `boost_enabled` is false.
- The existing "IN THE RHYTHM xN" banner switches to a flow-based message in Extra Swishy.

### 4. Nature mode flow (main.gd)
- Add `NATURE := "Nature"` to `MODES` and `MODE_ENVIRONMENTS[NATURE] = "Ocean"`. It is a card mode (prompt to begin).
- Generalise `_sit_out` / `_come_back` so they only touch the AquariumArena ball when the environment is an AquariumArena.
- Add `_match_card_text` for Nature, e.g. "Swim like a fish. Sweep the stick back and forth, and alternate at each stroke's peak. Ram the fish to demo it."
- `play_match` dispatches by mode: it creates a new `NatureRun` node instead of `Match1v1`.
- When entering Nature, apply `presets/nature.cfg` to the player fish.
- When leaving, restore the previous tuning. Snapshot it with `copy_tuning` into a stash, or reload the active preset.

### 5. NatureRun (`scripts/nature_run.gd`, new)
- **Setup:** places the player at the ocean spawn, facing the target. It spawns the target fish (the same `FISH_SCENE` setup as `Match1v1._ready`), about 25–35 m ahead with a random offset, on team 1 with a neutral colour.
- **Target AI:** a new `scripts/wander_bot.gd` writes a `FishInput`:
  - it wanders through random waypoints within a radius around its home, using steering from `FishBot._drive`;
  - it is calm and slow, never chases the player;
  - optionally it makes a gentle dodge or flee turn when the player gets close fast. Off by default, as a tunable.
- **Ball cam:** set `_camera.ball = target`, with the HUD hint label reading "fish cam". Add `xray_outline` to the target so it stays readable in fog.
- **Demo:** move `_check_demolition` / `_touching` into a shared static helper (`scripts/demolition.gd`), so that `Match1v1` and `NatureRun` both call it. NatureRun passes `nature_demo_speed` (an export, defaulting to roughly the supersonic speed of 22 m/s and tuned with Extra Swishy), so a demo requires a good stride chain.
- **On a demo:**
  - `Explosion.spawn`, `victim.demolish()`, and the HUD banner "DEMOLITION! 27 m/s";
  - a demo counter ticks up;
  - after about 1.5 s a new target `revive`s 30–50 m away in a random direction, and the camera re-targets.
- **Ending:** `end()` frees the target and returns control.

### 6. Ocean dressing (minimal now, more later)
- Keep `ocean.gd` as is for v1. The specks, fog and sky are enough to "feel" speed.
- Optionally add a soft leash so the target never wanders more than about 150 m from the player.
- Seabed, kelp and light shafts are a later pass. They are noted here, not part of this plan.

## Files
- **Modify:**
  - `scripts/fish_controller.gd`: style enum, `boost_enabled`, delegation, option gating;
  - `scripts/fish_model.gd`: tail and glow cue;
  - `scripts/hud.gd`: stride meter, hide gauge, labels;
  - `scripts/main.gd`: mode, card, dispatch, generalised sit-out, preset swap;
  - `scripts/match_1v1.gd`: use the shared demo helper;
  - `scripts/follow_camera.gd`: only if the hint or label needs a "fish" focus;
  - `README.md`: a modes section;
  - `tests/modes_probe.gd`: the new mode.
- **New:** `scripts/swishy_swim.gd`, `scripts/nature_run.gd`, `scripts/wander_bot.gd`, `scripts/demolition.gd`, `presets/nature.cfg`, `tests/swishy_probe.gd/.tscn`, `tests/nature_probe.gd/.tscn`.

## Verification
Run headless probes with `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/<probe>.tscn`.

**`swishy_probe`** drives `fish.controls` with scripted sweeps and prints PASS/FAIL:
- left/right strides at the peak interval build `flow` and speed above a single stride;
- too-early strides (half the peak time) and too-late strides (peak + 2× fade) both give clearly less speed than on-peak strides, and early mashing gives about 0;
- diagonal and up/down alternation also propel the fish, and circling the stick does not;
- the net path is mostly straight (side pushes cancel);
- boost input does nothing while `boost_enabled` is false;
- Original style still matches the `momentum_probe` numbers (regression).

**`nature_probe`:**
- `set_mode(NATURE)` shows the card, and the fish sits out;
- `play_match` spawns the target, sets the camera focus to the target, and turns boost off;
- ramming the target above the demo speed demos it, and a new target appears;
- a slow bump does not demo it;
- leaving Nature restores the previous tuning and Original style.

**Other checks:**
- Re-run all existing probes (they should all still pass), especially `modes_probe`, `match_probe` (shared demo helper) and `momentum_probe`.
- Build, then hand off for manual feel testing. Expect several tuning loops on `stride_peak_time`, `stride_fade_time`, `flow_gain`, `stride_side_angle`, drag and the demo speed. All are live in the tuning panel.
