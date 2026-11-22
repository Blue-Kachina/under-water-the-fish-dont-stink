# Race: Phase 0 audit, contract and file ownership

Written 2026-11-21 by the Phase 0 agent, for planning_race.md. User decisions in force: D1 title **Fin-ish Line** (id `race`),
D2 8 racers (card 2-12), D3 size cap ~2x Skirmisher length (scale body and hitbox, keep bump weight), D4 weighted bumps with no
damage, D5 mobility skills ON with a race cooldown (card toggle), D6 start surge, D7 bot-only rubber band (Easy on, Hard off),
D8 30 s finish clock, D9 script-authored track (`canyon_reef_track.gd`).

## File ownership (4 workers, one owner per file)

| Worker | Owns |
|---|---|
| **W1 core mode** | `scripts/modes/race/race_match.gd` (RaceMatch, descriptor, card, setup rows, countdown/laps/positions/rescue/finish clock/results), `race_hud.gd`, `race_camera` bits (CameraClaim use), `race_sounds.gd`, the **one line** in `scripts/core/mode_registry.gd` `scripts()`, `INVENTORY.md` (Race column), `scripts/ui/setting_docs.gd` regen, `tests/race_lap_probe`, `tests/race_rules_probe`, `tests/race_roster_probe`, the `mode_boundary_probe` list (add `scripts/modes/race`). Also owns `race_settings.gd`, `race_handling.gd`, `race_roster.gd` after this contract (others ask W1 to change them; additive changes are fine). |
| **W2 terrain + track** | native `native/under-water-the-fish-dont-stinkExt/src/terrain_field.{h,cpp}` (`channel` records), `scripts/terrain/terrain.gd` and `terrain_layout.gd` seam edits (inject a layout, keep core free of "race"), `race_layout.gd` (RaceLayout: builds the configure() dictionary), `tracks/canyon_reef_track.gd`, `tracks/greybox_track.gd` (data only), `race_track.gd` bugs, soft ceiling, `race_track_probe`, `tools/race_track_shots` (top-down map + feature shots), cues / bubble streams / slipstream visuals (`bubble_stream.gd`, `race_cues.gd`, `slipstream_fx.gd`). |
| **W3 bots** | `race_bot.gd` (RaceBot drives FishController through `controls`, like WanderBot/HunterBot), `race_bot_brain` helpers, `tests/race_sim`, `tests/race_roster_bench`, support for `race_lap_probe` (a bot lapping). BotDifficulty tiers come from `RaceSettings.noise_for / rubber_for`. |
| **W4 split-screen + online** | `race_net.gd` (RaceNet extends ModeNet), `attach_player` / `detach_player` bodies **inside race_match.gd** are W1's, but W4 supplies `RaceNet` and the per-view HUD hooks (agree the seam with W1 by message), `tests/race_split_probe`, `tests/race_net_probe` + `race_net_peer`. |

Shared, do not edit without telling the owner: `scripts/fish_controller.gd`, `scripts/core/*`, `scripts/main.gd`.
Existing uncommitted edits in `debug_panel.gd`, `kits/school*.gd`, `modes/nature/*`, `modes/what_stinks/*`, `ui/setting_docs.gd` belong to others: do not revert them. The user does all git.

## The contract files (built, parse and pass `tests/race_contract_probe`)

In `scripts/modes/race/`:
- `race_track.gd` `RaceTrack`: `build(data) -> RaceTrack`, `sample(d) -> Fix`, `nearest(p, hint_d := -1, window := 40) -> Fix` (Fix has `d pos forward right up width height tag lateral vertical distance`, `inside(margin)`), `racing_line(d)`, `line_offset(d)`, `delta(from, to)`, `grid_slots(n)` (Array of `{xform, d, lateral}`), `streams_at(d)`, `checkpoints` (Array of `{d pos forward right up width height tag}`), `checkpoint_before(d)`, `progress(lap, d)`, `lap_length`, `streams`. Data shape in its header.
- `tracks/greybox_track.gd` `GreyboxTrack.data()`: 723 m stadium loop, 29 checkpoints, 2 streams. Canyon Reef must return the same dictionary shape.
- `race_settings.gd` `RaceSettings` (Resource, `shared()`, panel key `race`): all names below.
- `race_handling.gd` `RaceHandling`: `of(entry) -> row`, `modifiers(row) -> {turn, rl_turn, drag}`; row keys `turn_scale coast weight stream_grip slip_gain skill_cooldown`.
- `race_roster.gd` `RaceRoster`: `entries()`, `of_family(f)`, `find(key)`, `entry_of(fish, form)`, `cap_scale(len, cap)`, `dress(fish, entry, cap)`.

Modifier names (FishModifiers sets pushed on `fish.modifiers`, popped on leaving): `race.shared` (`RaceSettings.shared_modifiers(fish.stroke_max_speed)`: top_speed, accel, stride), `race.handling` (`RaceHandling.modifiers(row)`), `race.size` (`RaceRoster.MODS_SIZE`, pushed by `dress`). W1 defines `RaceMatch.MODS_SHARED = "race.shared"` and `MODS_HANDLING = "race.handling"`.

RaceSettings names: `laps field_size bot_difficulty track slipstream skills bumps countdown finish_clock ghost_time race_top_speed race_accel race_stride_gain start_surge start_window race_size_cap bump_strength stream_push stream_max_gain slip_gain slip_delay slip_length slip_angle slip_fade race_oob_time wrong_way_banner race_wrong_way_time stuck_time stuck_speed rescue_cooldown rescue_fade ceiling_margin ceiling_push skill_cooldown_scale rubber_easy/normal/hard rubber_gap bot_lookahead bot_lookahead_min bot_noise_easy/normal/hard`. Wide ranges, defaults from the plan; `stroke_cap()`, `shared_modifiers()`, `rubber_for()`, `noise_for()` helpers.

## Phase 0 findings

### (a) Race top speed and lap length (measured, headless, Nature preset, Ocean)
`tests/race_phase0_probe.tscn` (my probe; edit `CAPS` to rerun). Nature: `max_speed 12` (but throttle alone settles at **9.1 m/s**: accel 8 / drag 0.85), `stroke_max_speed 40`.
**The plan's assumption of "12-14 m/s" is not what Nature does.** A perfect stride chain (flip the stick every stroke peak) holds **~31-33 m/s** (swim_metrics fixture: 32.5 after 4 s); sloppy timing gives 20-23, mashing 9. So "top speed" has to be a race setting, not an inherited number.
- The stroke cap is `stroke_max_speed * top_speed_scale`. A perfect chain settles at about **1.5 x cap + 0.5** m/s. Measured (18 s runs, mean after 8 s): cap 8 -> 12.4, 10 -> 15.2, 12 -> 18.1, 14 -> 21.0, 16 -> 23.8, 20 -> 29.3, 24 or 40 -> 31.7 (cap no longer binding above ~21).
- `RaceSettings.race_top_speed` is that settled chain speed (default **20 m/s**, i.e. stroke cap 13, `top_speed` modifier 0.325). Throttle-only cruise stays 9.1 m/s, so strides are worth +11 m/s.
- Turn radius at full stick, no throttle (Nature, M3 water turning): about 3.6 m at 12.5 m/s, 4.5 m at 14 m/s, 6.8 m at 18 m/s, 9 m at 21 m/s, 16 m at 36 m/s. At race speed 20 the tightest bend centreline radius should be **at least 12-15 m** (speed is scrubbed 40-60% in a full-stick turn: 14.7 m/s lost at 18 m/s).
- **Proposed lap length: 720 m** (the Grey Box is 723 m). A perfect chain at 20 m/s laps in 36 s; real laps (bends scrub, streams add) land around 40-45 s at an average of 16-18 m/s. Fits the plan's footprint (a 723 m loop is a 230 m circle; with a crossover it fits 300 x 300 m). If the user prefers a slower pace, drop `race_top_speed` to 16 (cap 10.3) and keep the same track.

### (b) Body lengths before/after a 2x Skirmisher cap
Skirmisher hitbox length **1.205 m**, so the cap is **2.41 m** (`race_size_cap` default 2.4). All 11 pickable fish classes are 1.21-1.34 m: **never capped**. Hunter forms (`HunterForms` sheet `length_m`) and Titans scale down:

| Entry | Length | Body scale after cap |
|---|---|---|
| Fish classes (46 skins) | 1.21-1.34 m | 1.000 |
| Beluga form (Titan species 2) | 2.2 m | 1.000 |
| Orca | 3.6 m | 0.669 |
| Humpback / Titan class default | 6.7 m | 0.360 |
| Sperm Whale | 7.7 m | 0.313 |
| Blue Whale | 12 m | 0.201 |
| Ember Octopus / Drowned Shark / Lantern Angler | 6-7 m | 0.40-0.34 |
| Gulper Mother 9 / Fallen Angel 10 / Lamprey Queen 14 / King of Herrings 16 | | 0.27 / 0.24 / 0.17 / 0.15 |
| Whale Fall | 12 m | 0.201 (form `ready()` is false: not on the roster) |

Roster counts: **68 entries = 46 fish + 7 hunters + 15 titans** (`RaceRoster.entries()`). A capped King is 2.4 m on a 16 m model's art: eyes, jaws and rigs scale with the model, but check the scaled-down look and that hunter rigs (`HunterForms.dress`) read `fish.body_scale` (risk, below). Scale is a `body` modifier, so hitbox, belly and wheels scale with it.
Note: "adult whales" and "Titans" in the plan are the same bodies in code (FishClass.TITAN, `titan_model.gd`, no class_name: load by path, as `FishModel.TITAN_MODEL`). The Hunter forms Humpback..Blue wear that class too, so the roster lists them once, under TITAN, with 3 skins each. Family ids: `fish`, `hunter`, `titan`.

### (c) How each family is driven
Every family is already **one FishController** with `fish.set_look(class, species, skin)` and `fish.modifiers`:
- **Fish classes and skins**: `FishModel.build(class, species)`. No adapter.
- **Titans (adult whales)**: `set_look(TITAN, species, skin)`, `body_scale`, `hitbox_scale`, multi-segment swim with `power_stroke`. Marco (`MarcoPoloMatch._become_titan`, `_whale_values`) pushes `WHALE_MODS` {turn, accel, drag, top_speed, boost, speed}. Race pushes only the shared set + handling instead. **Marco writes `body_scale`/`hitbox_scale` directly** (its grow tween owns them); Race uses the `body` modifier `race.size` instead since nothing else grows them. No adapter.
- **Hunter forms** (`HunterForms.sheet(key)`): `class` is MONSTER (own bodies via descriptor `models` provider `HunterFormModel.build`, registered by What Stinks, so it is available whenever the registry lists it) or TITAN. `HunterSize.apply` pushes `HunterSize.MODS` with the form's `speed/accel/turn` and `body`: **Race must not use it** (that breaks "same speed"); it uses `RaceRoster.dress` which pushes only `body` and then runs `HunterForms.dress` (visual rig only: SharkRig, WhaleJaw, KingRig...; "safe to call twice"). Bites, attacks and the HunterBite node are not needed and not attached. **Needs a probe check**: `dress` hooks read `sheet` and `fish.body_scale`; confirm each of the 7 hunter rigs behaves at the cap scale (`race_roster_probe`).
- Mobility skills (D5): `Traversal` (scripts/kits/traversal.gd) + `CourseSkill` (modes/course/course_skill.gd): `Traversal.new(null, fish, effects_node)`, `update(delta)` per physics tick, `fish.speed_scale = twist.speed_factor()`. Hunter forms and Titans have no class twist of their own; `RaceRoster` marks `skill_class` = SKIRMISHER for them (their Dash). That is a design call for W1/W3 to confirm. CourseSkill's HUD button is `UnnaturalHud.SkillButton`. Cooldowns live in `TraversalSettings` (`dash_cooldown`, `fin_cooldown`, ...): race multiplies by `skill_cooldown_scale * row.skill_cooldown`, which needs a hook in `Traversal` (`_cool_for`) or a `cooldown_scale` field (W1 asks the owner of kits/traversal.gd; a one-line additive field).
- Conclusion: **no family needs a new mover.** The only adapter is `RaceRoster.dress` (look + cap + hunter rig). Nothing in core/kits needs to name a mode.

### (d) Mode patterns to copy (all paths under `scripts/`)
- **Descriptor**: `GameMode.descriptor()` keys documented at the top of `core/game_mode.gd`; examples `modes/marco/marco_polo_match.gd:225` (arena, role_rows, join, net), `modes/what_stinks/what_stinks_match.gd` descriptor (models, setup, card_choices), `modes/nature/nature_run.gd:179` (`split_screen: true`). Registry: one line in `core/mode_registry.gd` `scripts()`. Other modes use their **title as id** ("Marco Polo", "What Stinks?"); the user wants id `race`: W1 decides whether the id is `race` with title "Fin-ish Line" (descriptor has separate `id` and `title`, so both work).
- **Match card**: `card_text` Callable, `card_choices(card, host)` appending `{title, options, index, changed}` (What Stinks), or `card_fill(host, MatchCard)` (Marco). `MatchCard` is `scripts/match_card.gd`. Laps, field, bots, slipstream and skills toggles go here from `RaceSettings.shared()`.
- **Join-time character screen / per-role saves**: `ui/mode_setups.gd` (`ModeSetups`, rows via `row()`, roles, pools) and `ui/mode_setup.gd` (`ModeSetup`), `role_characters.gd` (`RoleCharacters`: `character(role)`, `species(role, class)`, `form(role)`, `store*`; saved in `user://playground.cfg` section `roles`). The cleanest fit is What Stinks' `"setup"` script (static `rows`, `current_role`, `use_role`, `apply_form`, `settle_form`, `change_form`) with the whole roster as one pool (`setup.pool` entries `{name, line, character, form, slot, species, preview_species}`), role `"racer"`. RoleCharacters stores class+species or a form string only: the Titan skin and the roster key need `RoleCharacters.store_form("racer", entry.key)` (use the `form` string slot for `RaceRoster` keys) or a `ModeData` value.
- **ModeHud**: `core/mode_hud.gd` hooks (`attach`, `detach`, `live`, `update_slots`, `countdown_text`, `update_board`, `shows_plate`, `restart_hint`, `has_board`...). Each mode HUD: `WhatStinksModeHud`, `NatureHud`, `MarcoPoloHud`. Install with `slot.hud.set_mode_hud(...)` per slot (split-screen: one per view).
- **CameraClaim**: `core/camera_claim.gd` (`follow(subject, Snap)`, `pose_override` Callable for a custom pose, `body_follow`, `ball_cam`, `wheel`). Marco: `_claim := CameraClaim.new()`; Nature per slot: `camera.claim(focus, true, true)` / `camera.release()`. For the race chase cam use `pose_override`.
- **ModeNet**: `core/mode_net.gd` (`hook(mode)`, `unhook`, `tick(delta)`, `world()`/`apply_world(state)`, `puppet_added/removed`, `puppet_parent`, `is_host`, `coop: CoopSession`); examples `modes/nature/nature_net.gd`, `modes/marco/marco_polo_net.gd`, `modes/what_stinks/what_stinks_net.gd`. Descriptor `net` + `net_key`.
- **attach_player**: `GameMode.attach_player(slot: PlayerSlot)` / `detach_player` (Nature `nature_run.gd:218`): per slot camera (`slot.camera`), `slot.hud`, `slot.fish`, `slot.input`, `slot.mode_data(mode_id)`. Descriptor `split_screen: true`; main `_start_registered` drops split-screen when `one_screen`.
- **Bots**: `FishInput` (`fish_input.gd`: forward, reverse, stick, jump, boost, direction_lock) set as `fish.controls`; `WanderBot` (`kits/wander_bot.gd`, `_physics_process` + `_steer_to`), `FishBot`, `HunterBot`, `MarcoPoloBot`, `WhatStinksBot`; `BotDifficulty.basic()` (reaction_time, timing_error, perfect_chance, aim_error). A stride chain through `controls`: flip `stick.x` every `fish.stride_peak_time` with `forward = 1` (the probe does this: `tests/race_phase0_probe.gd` `_chain`).
- **Settings**: Resource with `static shared()`, `@export_group`, saved with presets `[<key>]` (descriptor `settings`, `settings_key`, `settings_after`). `tuning_preset: "res://presets/nature.cfg"` applies Nature's tuning on entering the mode. Registered `net_descriptors`, `environments` ({name: script}) merged into the host.
- The index (jcodemunch) did not list `scripts/modes/**` or several `core/` files (stale); I read them straight from disk.

### (e) Native terrain: C++ rebuild feasibility
- `TerrainField` is a **godot-cpp GDExtension** (`native/under-water-the-fish-dont-stinkExt/src/terrain_field.{h,cpp}`, ~1160 lines + header), registered in `register_types.cpp`. Params are one `Dictionary` read in `TerrainField::configure()` (`terrain_field.cpp:182`); features are **flat `std::vector<float>` records** (`mesas` 10 floats, `arches` 7, `tunnels` 7, `cavities` 6, `clearings` 3) taken from `PackedFloat32Array` entries of that dictionary (`to_vec(d.get("tunnels", ...))`). A `channel` record fits the same mold: add `std::vector<float> channels` (`ax ay az bx by bz width height`, 8) to `Params`, `to_vec(d.get("channels"))` in `configure`, and fold `max(rock_fill, -channel)` in the density loop in `generate()` (the tunnels loop is the pattern: a capsule SDF; make it elliptical).
- The generator is built around an **arena** (edge ring, `relief_inner/outer`, plateaus, `spawn`, floor); for a track W2 feeds it via a new `RaceLayout` producing the same `params` dictionary (ring off, `cull_radius` large, `origin/size` to the track bounds, `spawn` on the start line). `Terrain.prepare` currently calls `TerrainLayout.roll(...)` directly (`scripts/terrain/terrain.gd:41`): needs a small seam (an optional pre-made layout/params) that keeps core free of "race".
- **Build works here**: `cmake-build-debug` exists (Ninja, MSVC 14.38 BuildTools, Debug, terrain source has per-file /O2). I ran the build: `ninja: no work to do`. Exact command (PowerShell):
  `cd D:\Dev\GameDev\under-water-the-fish-dont-stink; cmd /c 'call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul && cmake --build cmake-build-debug'`
  (a stray `'vswhere.exe' is not recognized` line is harmless). The DLL is copied to `addons/under-water-the-fish-dont-stinkExt/bin/windows/under-water-the-fish-dont-stinkExt.windows.template_debug.x86_64.dll` (current build 2026-11-15). I did not time a real rebuild (only the no-op); expect one file plus a link. **Windows locks the DLL while a Godot editor/game has it loaded**: close the editor and any running probes before rebuilding. Only ONE agent should rebuild at a time (W2). Re-run `--import` afterwards. `.godot` caches the extension list; the .gdextension is `addons/under-water-the-fish-dont-stinkExt/bin/under-water-the-fish-dont-stinkExt.gdextension`.
- Fallback if the native work slips: the existing `tunnels` records (capsules, `r`) can carve a channel as a chain of capsules (circular cross-section, no ellipse) with no C++ change; the walls would come from the layout's mesas. Not recommended as the end state (round channels, no roof control), but it unblocks track probes early.
- Cost per plan: 349 x 61 x 349 cells ~0.65 s (PROGRESS.md). A 300 x 70 x 300 track at 1 m is similar.

### (f) Running headless probes
Godot console: `C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.
- After adding `class_name` scripts: `Godot_console.exe --headless --path . --import` first (class cache; it also prints parse errors).
- Run: `timeout 300 "$G" --headless --path . res://tests/<name>.tscn 2>&1 | tail -40` (a script error hangs a probe: always `timeout`). Pass flags after `--`.
- Probes are `.tscn` + `.gd` pairs in `tests/` (`extends Node`, `main.tscn` instance, `main.set_environment("Ocean")`, `load_mode_preset(main.NATURE_PRESET)`, `fish.controls = FishInput.new()`; see `tests/swim_metrics_probe.gd`). New probes also get a `.uid` file when imported: leave them.
- Warnings are errors: type variables you infer from a Variant. `--check-only` false-flags autoloads. `posmod` is integer-only: use `fposmod` for floats (it bit RaceTrack once).
- No bare `python` (use `uv run python`); never kill python.exe (MCP servers); no `git mv`; refresh the class cache after new class_names; window probes need 1080p. `mode_boundary_probe --strict` must stay green (core/kits never name a mode).
- My probes: `tests/race_phase0_probe` (speed + lengths), `tests/race_contract_probe` (track closes, nearest monotonic, 68 roster entries, handling rows; prints `race_contract_probe: ok`). Both end with benign leak warnings at exit.

## Open items for the user
- Race top speed 20 m/s (stroke cap 13) and lap 720 m are proposals from measurement; the plan's 12-14 m/s does not match Nature (cruise 9, perfect chain 32). Confirm or pick 16.
- Hunter forms and Titans have no mobility skill (no class twist): the contract gives them the Skirmisher's Dash. Confirm.
- RaceHandling numbers are first guesses; the balance bot sim reports them (not retuned, per play-test-before-tuning).
