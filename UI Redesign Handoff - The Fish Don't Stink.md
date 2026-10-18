# UI Redesign Handoff — The Fish Don't Stink

Oct 17, 2026 · @Matt

## Summary

Four picks from the [design canvas](https://claude.ai/artifact/Y8xRGKJ1gmJSTrcMoh9ZJL) are approved to build in Godot. The other eight options on the canvas are reference only.

| Area | Picked option | Canvas artboard |
| --- | --- | --- |
| Home screen | Reef Console, with a pop-up mode picker when Play is pressed | Home A · Reef Console + Home A · Play → Mode Picker |
| Settings menu | Detail Pane | Settings C · Detail Pane |
| Powerup cards | Gem Frame | Cards A · Gem Frame |
| Powerup icons | Hex Badges | Icons A · Hex Badges |

The canvas is a clickable prototype for the home flow: press Play on Home A to open the mode picker, and the close button returns. Every screen is drawn at 1280×720 and should scale to the game's resolution.

## Visual system

All four screens share one dark-water theme. Build it once as a Godot `Theme` resource and reuse it in every menu.

| Token | Hex | Use |
| --- | --- | --- |
| Ground | #061826 | Screen background |
| Deep | #04111C | Rails, inputs, the darkest panels |
| Panel | #0B2536 | Rows and cards on the ground |
| Ink | #E8F4F8 | Main text |
| Ink soft | #CFE3EA | Body text on cards |
| Muted | #8FB3C2 | Hints and secondary labels |
| Aqua (accent) | #37E2D5 | Focus rings, selected states, section labels |
| Coral | #FF8A5B | Player chip, warnings, changed values |
| Dim overlay | #020A12 at 72% | Behind pop-ups and the card picker |

**Rarity colours** (rims, ribbons, pips). These are the existing `Rarity.COLORS`, lifted slightly for contrast on navy:

| Tier | Hex |
| --- | --- |
| Common | #9EA3A8 |
| Uncommon | #4DCC59 |
| Rare | #408CFF |
| Epic | #AD52F2 |
| Legendary | #FFC233 |
| Boss | #73BFE6 |
| Cursed | #E8323C |

**Type**: [Fredoka](https://fonts.google.com/specimen/Fredoka) 600–700 for titles and big buttons; [Barlow](https://fonts.google.com/specimen/Barlow) 400–600 for body; Barlow Condensed 600 in caps with wide letter-spacing (0.2–0.3em) for small labels such as RARE or TUNING LAB. All three are OFL and can ship in the game.

**Shape**: corner radius 12–14 px on rows and buttons, 20–24 px on cards and pop-ups. Focused items get a 2 px aqua border plus an aqua fill at 12%. Interactive rows are at least 48 px tall.

**Controller hints** sit bottom-right on every screen: round face-button badges (A green, B red, X blue, Y yellow) and outlined LB/RB pills, each followed by a verb.

## Home screen: Reef Console + mode picker

The game launches to Home A. Pressing Play opens a pop-up mode picker over it, laid out like the Mode Wall option.

**Home A layout** (1280×720 reference)

- Left column (72 px in, 460 px wide): a small UNDER WATER label, then a two-line "The Fish / Don't Stink" title in Fredoka 54 px.
- Menu under the title, top to bottom: **Play** (76 px tall, outlined in aqua, with the last mode played as a subtitle, e.g. "Unnatural · last played"), Choose mode, Co-op, Replays, Settings, Quit (52 px rows, Quit in muted text).
- Right half: the player's current fish, live in 3D, with ‹ › buttons and LB/RB to change it. Under it: the fish's name and its stat bias in coral caps (e.g. "HYBRID BODY · LUCK +").
- Top right: a player chip with the name from `UISettings.player_name`.
- Background: slanted, faint light shafts, a seabed silhouette along the bottom, a few bubbles. Keep the light shafts gentle so they don't fight with the 3D fish.

**Mode picker pop-up**

1. Opens over Home A with the dim overlay; the home menu stays visible but faded underneath.
2. A panel of 1120×616 px with a 24 px radius, titled "PLAY / Choose a mode", with a round close button top right.
3. A 4×2 grid: the last-played mode is the large 2×2 tile (focused when the picker opens, with a LAST PLAYED badge, a one-line pitch and Solo / Split-screen / Online chips). Next to it, four single tiles: 1v1, Hunt, Nature, Free Play, each with a line icon and one line of text.
4. A MORE row for the less-used modes: Free Swim, Obstacle Course, Test Tank.
5. Hints: A Play, X Mode rules (opens the existing match card text), B Back.

The featured tile follows the last mode played. Each mode's colours and pitch line come from one table so this tile can show any mode.

"Choose mode" on the home menu opens the same picker. Picking a mode starts it straight away; the match card becomes the X Mode rules view rather than a separate step.

## Settings: Detail Pane

Settings is three columns: sections, the options in the chosen section, and a detail pane explaining the focused option. It replaces both the GAME block of the tuning panel and the panel's per-section sliders.

| Column | Width | Holds |
| --- | --- | --- |
| Sections | 220 px | Game, Display, Controls, Camera, Fish, Ball, Nature, Unnatural, Powerups. The current one gets a panel fill and a 3 px aqua bar on its right edge. |
| Options | 520 px | Section title (Fredoka 34 px) plus the group name (e.g. "Fish · Swim Strokes"), then 56 px rows: label on the left, value on the right in Barlow Condensed caps (aqua when on or changed, muted when off). The focused row gets a 2 px aqua border. |
| Detail | the rest | A preview area (240 px tall) for a looping clip or still, a caps group label, a plain-language title, a 2–3 sentence description, the control itself (On/Off buttons, a slider with its value, or a list of choices), then "Default: … · Used by …". |

- **Sections map to what exists today**: Game = player name, fish, goal replays; Display = fullscreen, stats panel, controller overlay; Controls = the controller profile; Camera / Fish / Ball / Nature / Unnatural / Powerups = the tuning panel's sections. The `@export_group` names become the group headings in the options list.
- **Descriptions** come from the doc comments on each export where one exists. Options with no comment show only their name until one is written.
- **Hints**: Y resets the focused option to its default; B goes back a column, then closes. LB/RB jump between sections.
- Locked sections (e.g. online, `set_sections_locked`) show their rows greyed out and the lock note in the detail pane.
- Wide ranges stay. Sliders keep the existing export ranges so tuning is as flexible as it is now.

## Powerup cards: Gem Frame

Chest offers show up to three Gem Frame cards on the dim overlay, under a gold CHEST OPENED label and a "Pick a powerup" title.

**One card, top to bottom**

1. **Frame**: 290×410 px, radius 20, #0B1F2E fill, 2 px rim in the rarity colour. The focused card grows to 320×450 with a 3 px rim, a 6 px rarity glow at 12–14% and a drop shadow; unfocused cards sit at 86% opacity.
2. **Ribbon**: a rarity-colour tab hanging from the top edge, the tier in Barlow Condensed caps on dark text.
3. **Medallion**: a 132 px hexagon, rarity tint fill, 3 px rarity rim, the powerup's glyph (from the icon set) at 60 px in the rarity colour.
4. **Name**: Fredoka 26 px, centred.
5. **Stack line**: "NEW" or "STACK 2 → 3" in rarity-colour caps.
6. **Description**: the `Powerup.INFO` blurb, Barlow 16 px.
7. **Pips**: five 22×6 px bars along the bottom. Held stacks are filled in the rarity colour, the stack this pick adds is white, and the rest are dark.

**Picking**: ◀ ▶ moves focus, A takes it. The existing `ARM_TIME` (0.4 s) delay before input counts stays.

**Cursed and Boss**: same frame in their tier colours. Cursed cards could also split the blurb into the boon and a red "Curse: …" strip, as on Cards C. That's optional, but it reads more clearly.

## Powerup icons: Hex Badges

Each powerup gets a white line glyph inside a dark hexagon with a rim in its rarity colour. The same glyphs also go in the card medallions.

**Badge spec**

- Hexagon points (100-unit box): 50,4 90,27 90,73 50,96 10,73 10,27. Fill #0D2B3D (HUD: #061826 at 88%), rim in the rarity colour, 6 units wide (7 in the HUD), round joins.
- Glyph: 24×24 viewBox, stroke #E8F4F8, width 1.8 (2.0 at HUD size), round caps and joins, no fill. Drawn at about 47% of the badge width.
- Sizes: 72 px in menus and lists, 56 px in the HUD.
- **HUD (held powerups)**: a row of 56 px badges, 10 px apart, top-left of each player's view, in the order they were picked up (`Powerups.list()`). Once a powerup has 2 or more stacks, a small white chip at the bottom-right shows "×3" in dark Barlow Condensed 14 px. The chip is hidden at one stack.
- In split-screen the row stays in each player's own view.

**Glyph path data** (SVG `d`, 24×24, stroke only). Save each one as an SVG file and import it into Godot, or draw it with `draw_polyline` from the parsed path:

```csv
id,d
greek_fire,M12 3c1.5 3 5 5 5 9.5a5 5 0 0 1-10 0c0-2 1-3.5 2.5-4.5 0 2 1 3 2.5 3 0-3-1-5 0-8zM3 21h4M10 21h4M17 21h4
chain_lightning,M13 2 5 13h6l-1 9 8-12h-6l1-8z
torpedo,M8 9h7a3 3 0 0 1 0 6H8a3 3 0 0 1 0-6zM8 9 5 6M8 15l-3 3M5 12H2M20 12h2
bow_grow_bow,M12 12 4 7v10zM12 12l8-5v10zM10.5 10.5h3v3h-3z
barnacle_plating,M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6zM8.2 10a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0M13.2 11a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0M10.7 15a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0
hermit_shell,M3 19h18M5 19c0-7 4-12 10-12a5 5 0 0 1 0 10h-3a2.5 2.5 0 0 1 0-5h1
fizzy_soda,M7 8h10l-1.2 13H8.2zM6 8h12M14 8l2-5h3M10 13a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M12.5 16.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M9.9 18a0.6 0.6 0 1 0 1.2 0a0.6 0.6 0 1 0 -1.2 0
speedy_seahorse,M15 3c2 0 3 1.5 3 3l-4 1c-1.5 1-1.5 3 0 4.5S15 15 13 17c-1.5 1.5-1 3.5 1 3.5M15 3c-2.5 0-4 1.5-4 4M2 9h5M3 13h4M4 17h3
remora_buddy,M3 10c3-4 9-4 12 0-3 4-9 4-12 0zM15 10l4-3v6zM9 18c1.5-1.8 4-1.8 5.5 0-1.5 1.8-4 1.8-5.5 0zM14.5 18l2-1.5v3z
bubble_wrap,M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0M8 9.5a4.5 4.5 0 0 1 3-3M18 4a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0 -3 0
pufferfish_spines,M7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1
jellyfish_halo,M6 12a6 6 0 0 1 12 0zM8.5 12v3c0 1.5-1 2.5 0 4M12 12v7M15.5 12v3c0 1.5 1 2.5 0 4M3 7.5c2-3.5 5.5-5 9-5s7 1.5 9 5
electric_eel,M2 15c2.5-4 4.5-4 7 0s4.5 4 7 0c1-1.6 2.5-2 4-1.5M20 3l-2.5 3.5h3L18 10
depth_charges,M6 13a6 6 0 1 0 12 0a6 6 0 1 0 -12 0M12 4v3M12 19v2M4 13H2.5M21.5 13H20M6.3 7.3 5 6M17.7 7.3 19 6
anglerfish_lure,M3 21C3 12 8 5 15 5c2.5 0 4 1.5 4 3.5V10M16.5 12.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0
tsunami_heart,M12 20.5s-8-4.8-8-10.5a4.3 4.3 0 0 1 8-2.2 4.3 4.3 0 0 1 8 2.2c0 5.7-8 10.5-8 10.5zM7.5 12c1.5-1.2 3-1.2 4.5 0s3 1.2 4.5 0
drowned_fin,M4 18c4.5 0 7-3 8-8l2.5-6c1 5 2.5 10 6 14zM2 21.5h20
leviathans_coil,M2 15a3.3 3.3 0 0 1 6.6 0 3.3 3.3 0 0 0 6.6 0 3.3 3.3 0 0 1 6.6 0V10l-2-2
blood_moon_shard,M15 3.5a8.5 8.5 0 1 0 5.5 14 7 7 0 0 1-5.5-14zM10 9l2 3-1.5 3
glass_coral,M12 21v-8M12 13 8 9V4.5M12 13l4.5-5V4M8 9 5 7.5M16.5 8 19.5 7M8 21h8
sirens_song,M9 17.5V5.5l11-2v12M9 9.5l11-2M4 17.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0M15 15.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0
abyssal_hunger,M3 8c4-3 14-3 18 0M3 16c4 3 14 3 18 0M5 8.7l1.5 3 1.5-3.4M10.5 7.5 12 11l1.5-3.5M16 7.7l1.5 3.4 1.5-3M5 15.3l1.5-3 1.5 3.4M10.5 16.5 12 13l1.5 3.5M16 16.3l1.5-3.4 1.5 3
sunken_idol,M8 3h8v4l2 2v12H6V9l2-2zM9.5 12h1.5M13 12h1.5M10 16h4M6 9h12
```

The ids match the keys in `Powerup.INFO`. A new powerup needs a glyph drawn on the same 24-unit grid with the same stroke so the set stays consistent.

## Where it lands in the code

The game has no home screen today: `main.gd` boots straight into the last mode played (`_saved_mode`), and the pause menu holds Settings, Co-op and Exit.

| Picked design | Today | Change |
| --- | --- | --- |
| Home A | None; `main.gd` `_ready` starts `_saved_mode()` | New home scene shown at launch, before `set_mode`. Play / Choose mode open the picker; Co-op opens `coop_menu.gd`; Settings opens the new settings screen; Quit calls `get_tree().quit()`. |
| Mode picker | `debug_panel.gd` mode dropdown + `match_card.gd` (`_match_card_text`) | New pop-up that calls `main.set_mode(mode)`. Tile pitch lines live in one table beside `MODES`; X shows the match card text. |
| Settings C | `debug_panel.gd` (GAME section + one foldable per `_targets` entry), opened from `pause_menu.gd` | New three-column screen driven by the same `_targets` and `UISettings` keys, keeping save/load in `user://playground.cfg` and `set_sections_locked`. The pause menu's Settings and the home screen both open it. |
| Cards A | `level_up_cards.gd` (`CARD_SIZE` 250×330, `_draw_card`, `_draw_powerup`) | Redraw to the Gem Frame spec at 290×410 (focused 320×450); keep `open()`, the `picked` signal and the input handling. |
| Icons A (HUD) | `unnatural_hud.gd` `_draw_powerups` draws a colour box with the two-letter `Powerup.tag` | Swap the tag box for the hex badge plus glyph and the ×N chip. The stats panel list (around line 323) can show the 24 px badge before each name. |

All on-screen words keep the game's terms: batteries / Battered, Fish Fry, team colours.

## Open items

- [ ] Decide whether picking a mode starts it straight away or still shows its match card first (see the comment on the home section).
- [ ] Redraw the roughest glyphs: speedy\_seahorse, leviathans\_coil, sunken\_idol.
- [ ] Write a one-line pitch for Free Swim, Obstacle Course and Test Tank in case they get featured.
- [ ] Write descriptions for the tuning options that have no doc comment (they show in the settings detail pane).
- [ ] Pick or record preview clips for the settings detail pane, or drop the preview area for options without one.
- [ ] Settings has no Audio section because the game has no audio settings yet; add one when it does.
- [ ] No powerup is Epic yet, so Epic purple only appears in the colour key.
