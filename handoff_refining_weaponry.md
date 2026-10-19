# Handoff: refining_weaponry.md implementation (2026-10-19)

Read `refining_weaponry.md` first (the plan, tables and decisions; §2.x numbers below refer to it). User handles all git; never commit. Workflow: change, headless probes, build, hand off for manual testing. Godot console: `C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. After adding a `class_name`, run `--headless --path . --import` once; run probes with `timeout`. Build: `--export-debug "Windows Desktop" D:/Dev/GameDev/under-water-the-fish-dont-stink/builds/windows/FishPlayground.exe` (absolute path).

## Built this session (build 2026-10-19 ~18:21, awaiting the user's manual test)
| Plan § | What | Where |
|---|---|---|
| 2.1 | Ambience bus (and `stage/blood_moon_loop`) keep playing while paused | `scripts/audio/sfx.gd` (`_process_mode_for`, `ALWAYS_LOOPS`) |
| 2.2 | Chest cancel (B / Backspace on a chest's cards before the first pick): refund, chest shut again, same cards on reopen (no reroll), online messages | `unnatural_run.gd` (`can_cancel`, `cancel_offer`, `_chest_offer`, `_chest_rolls`, `_commit_chest`), `treasure_chest.gd` (`reshut_for`), `level_up_cards.gd`, `unnatural_hud.gd`, `unnatural_net.gd` |
| 2.3 | Remoras visibly dart to their zombie and back (damage still instant) | `powerups/remora_buddy.gd` (`_lunge`) |
| 2.4 | Boss HP: shark 2500 to 9000, leviathan 9000 to 27000 (untuned) | `unnatural_settings.gd` |
| 2.4b | Ramming: `battery_damage` 40 to 60, `battery_speed_power` 1.0 to 1.5, knockback scales with speed. **Speed protection NOT done (user pondering).** | `unnatural_settings.gd`, `unnatural_run.gd` `_batter_zombies` |
| 2.5 (partly) | Fish names without car names, home caption, panel texts, `water.cfg` description | `fish_character.gd`, `home_screen.gd`, `debug_panel.gd` |
| 2.6 | Fish Sticks tile; choosing it asks 1v1 or Free Play. Mode ids unchanged; tiles titled "Fish Sticks: 1v1/Free Play". Obstacle Course promoted into the main wall to fill the grid | `ui/mode_picker.gd`, `main.gd` (`MODE_TILES`) |
| 2.7 | Konami code (short form to full original) reveals Replays; saved in `UISettings.replays_unlocked`. B/A of a nearly-finished code are swallowed | `ui/konami_code.gd`, `ui/home_screen.gd` |
| 2.8 | Free Swim removed from the picker; saved Free Swim/Ocean modes map to Free Play (constant and probes' use kept) | `mode_picker.gd`, `main.gd` |
| 2.9 | Show Debug Tweaks (SELECT or F2 in Settings, off by default, saved). Hidden always: the always-on RL switches (`HIDDEN`). Everyday: Game name/fish/goal replays, fullscreen, audio profile+volumes, Controls, Camera, Fish's Controller group. Empty sections/tabs hide | `debug_panel.gd` (`HIDDEN`, `EVERYDAY`, `_refresh_visibility`, `_toggle_debug_tweaks`), `ui_settings.gd` |
| 2.12 | Whirlpool exit: Leviathan's death opens a whirlpool, Jump within 15 m (`whirlpool_range`) wins; co-op: any player entering ends it for all; bots enter after 15 s | `whirlpool.gd`, `unnatural_run.gd`, `unnatural_hud.gd`, `unnatural_net.gd`, `survivor_bot.gd` |
| 2.13 | End-screen DAMAGE block per source (top 10, share bars) in the stats panel; data was already in `stats.by_source` | `unnatural_hud.gd` (`_add_damage_lines`) |
| 2.14 | Lure uses Ages (life), Tides (interval) and Reef (blast). Tides (rate) and Reef (area) now apply to all powerup weapons and timed/area items via `Powerup.rate_scale()/area_scale()` | `powerups/*.gd` |
| 2.15 | Fish Details panel on the home screen (button, Y or I), built from live tables; caption shows signature stat and twist | `unnatural/fish_details.gd`, `home_screen.gd` |

Probes updated/added: `stage_probe` (whirlpool), `ui_probe` (Fish Sticks, debug gating), `drops_probe` (chest stays while the second player chooses), `audio_probe`, `powerup_batch_probe` (remora lunges, Lure tomes), new `konami_probe`, new `chest_cancel_probe`. All passed when last run, along with modes, run_log, slots, levels, milestones, hunt, coop_local, unnatural_coop, pearl_currency, boss_cursed, murk, combat, and `tests/unnatural_net.sh`. `unnatural_combat_probe` flaked once (death test) then passed. A `run_sim` check (`--out refine_check`, user://run_logs/sim) was still running in the background; its result is unread.

## Not done / open
- **Speed protection** (2.4b): user is pondering; wait for direction.
- **2.5 remainder:** ~26 RL mentions in `ui/setting_docs.gd` (generated from `##` comments in `fish_controller.gd`, `follow_camera.gd`, `ball_settings.gd` via `tools/gen_setting_docs.gd`); only visible in debug-tweaks detail panes. README untouched.
- **2.9 refinement:** Camera is fully "everyday" (plan said basics only); `rl_pushback_holds` and `complete_flips` (default false) stay visible under debug.
- **2.10/2.11:** Leviathan's Coil acquisition (a Leviathan boss chest is now viable; user hasn't decided); equipment, evolutions, unbuilt items; a playable character per weapon (roadmap only).
- **Whirlpool open questions:** lingering difficulty (director keeps escalating), partial credit if the player dies after the boss, late-joiner doesn't receive an existing whirlpool (not in `world()`), no whirlpool sound, whirlpool visuals are plain torus rings.
- **Damage breakdown:** overkill counted as dealt; no per-source hits/kills; not yet in `RunLog`/`run_sim` output; online guests' totals are host-claimed hits only.
- **Balance:** boss HP, ram numbers and Tides/Reef on Greek Fire need `run_sim`/`weapon_bench` passes.
- **Chest cancel:** visuals show the lid popping open before it reappears; battering back through the same chest reopens it at once.
- Update `planning_audio.md` 4.3/4.4 notes about ambience under pause (not done).
- Update the table notes in refining_weaponry.md 1.2/1.3 for Tides/Reef/Ages (not done).

## Manual test checklist for the user
Home: no Replays button; Konami (up up down down left right left right B A) reveals it and it stays; Play shows Fish Sticks (then 1v1 / Free Play), no Free Swim; Y/I or the Details button on a fish. Settings: only everyday options until SELECT/F2. Unnatural: ambience through card picks; B on a chest's cards; remoras darting; ramming feel; beat the Leviathan (needs a very strong build; use Test Tank or panel to lower `leviathan_hp`) and use the whirlpool; end-screen damage list; Lure with Tome of Ages.
