# What Stinks? bot report (2026-11-07)

**Numbers only. Nothing was tuned from them** (the play-test comes first). Every setting is at its default except where the Method section says otherwise. Written by the Phase 7 worker (`what_stinks.md` Phase 7, `two-stage-attack.md` Phase 6); the tool is `tests/what_stinks_sim.gd`.

## Method
- 5 fish, **all bots** (the player's fish too): one Hunter bot (`WhatStinksBot`), four prey bots (`WhatStinksPreyBot`). The Hunter changes each round (every fish takes a turn), always in the form being measured.
- Hunter size **1.0x** as the task asked. The match's own default is 0.5x (`HunterSize.MATCH_SIZE`), so these are not the numbers a default match would give (see open item 9).
- 10 ready forms (Whale Fall is off). Per form, 2 variants (Clean Sweep, Upset Stomach) and 2 bite modes (hold, the default; tap, the old snap): 40 cells of **4 rounds** each, 160 rounds. Round clock 180 s, hide time 12 s, 14 schools, everything else default.
- "Bite" is one landing (a miss counts as 0 fish). **Fish per bite** is every fish a landing took, counting a drill dash or an engulf's whole mouthful but not the body rams, over the landings. **Fish per min** counts all fish taken (rams included) over the live round time. **Took something** is the share of landings that took at least one fish or prey. In Upset Stomach a prey a bite catches is spat out, not eaten, so only school fish count there.
- A win is the Hunter's: every prey eaten before the clock (Clean Sweep), or the belly filled before the clock (Upset Stomach). Round length is the live time to the round's end (180 s means the clock ran out).
- With 4 rounds a cell's win rate moves in steps of 25%, so treat any single cell as a hint. Earlier passes were thrown away: they ran before a bot bug was fixed (see the next section); the numbers below are the pass on the final bots.
- Reproduce: `Godot_console.exe --headless --fixed-fps 120 --path . res://tests/what_stinks_sim.tscn -- --forms=all --variants=sweep,stomach --modes=hold,tap --rounds=4 --out=rows.jsonl` (about 40 minutes split over five processes with `--forms=a,b`; add `--size=0.5` for the default size).

## A bot bug the sim found (fixed, not tuning)
The first sim pass showed the hold-mode Hunter bots landing at charge 0.00 on every bite (the whales took 0.0 fish per bite). The bite reads the button a tick after the bot sets it, so the bot saw "not open yet", let the button go, and every bite was a one-tick tap. `WhatStinksBot` now keeps a press down for up to two ticks until the jaws open (hold mode only). All the numbers below are after that fix; `what_stinks_bots_probe` checks that the bot lets go at a real charge. Any earlier hold-mode bot figure came from taps.

## Headline numbers
- **Clean Sweep: the Hunter bot won 0 of 80 rounds** (40 hold, 40 tap), in every form. It took 59 fish per round on average in hold mode (37 in tap) but only 0 to 1.5 of the 4 prey per round (see the tables).
- **Upset Stomach: the Hunter bot won 30 of 40 hold rounds and 22 of 40 tap rounds.** Hold: Humpback 100% in 74 s, Blue 100% in 36 s, King 100% in 40 s, Gulper 100% in 36 s, Fallen Angel 100% in 28 s, Drowned Shark 100% in 85 s, Lamprey 75% in 138 s, Sperm 50% in 117 s, Orca 25% in 163 s, **Beluga 0%**.
- Fish per bite, hold (Clean Sweep / Upset Stomach): Blue 5.4 / 5.4, Humpback 4.0 / 4.3, Fallen Angel 3.9 / 2.9, King 2.3 / 2.9, Gulper 2.8 / 2.7, Lamprey 2.3 / 2.6, Sperm 2.2 / 2.0, Orca 1.4 / 2.0, Drowned Shark 1.0 / 1.3, **Beluga 0.7 / 0.5**.
- Hold against tap: for most forms the fish per bite is about the same (shark 0.99 / 1.03, Humpback 3.98 / 4.27, King 2.32 / 2.46) and hold takes more fish per minute because the bot opens at 1.6 reaches against 0.8 for a tap (more bites per minute). The two that gain from the hold itself are **Lamprey Queen (2.33 against 0.42 fish per bite) and Fallen Angel (3.86 against 0.68)**; Blue, King and Gulper take more per bite in tap in Upset Stomach (Blue 12.0 against 5.4).
- **Fallen Angel, hold, Clean Sweep: 45 fish per round come from body rams** (tap: 0.2). Its 53 fish per minute is mostly that plus its lash.
- The bots' echo work: the Hunter bot Clicks about every cooldown (53 to 58 times per Clean Sweep round, 26 to 39 in Upset Stomach), sniffs about 4.5 s per Clean Sweep round (one school's worth: `hunter_bot_sniff_s` 4 per school) and never in Upset Stomach; a prey bot relocates 0.2 times per Clean Sweep round (about one in five rounds) and never in Upset Stomach (it baits).

## Results

### Clean Sweep, hold mode (the default)

| Form | Rounds | Hunter wins | Round (s) | Bites/min | Fish per bite | Bites that took something | Fish per min | Rams per round | Prey eaten per round |
|---|---|---|---|---|---|---|---|---|---|
| Drowned Shark | 4 | 0% | 180 | 10.9 | 0.99 | 44% | 11.8 | 2.8 | 0.75 |
| Humpback | 4 | 0% | 180 | 3.7 | 3.98 | 82% | 15.3 | 2.2 | 0.00 |
| Orca | 4 | 0% | 180 | 2.5 | 1.40 | 67% | 4.2 | 2.2 | 0.00 |
| Beluga | 4 | 0% | 180 | 2.8 | 0.70 | 52% | 2.0 | 0.2 | 0.50 |
| Sperm Whale | 4 | 0% | 180 | 4.3 | 2.23 | 77% | 9.9 | 0.8 | 0.50 |
| Blue Whale | 4 | 0% | 180 | 6.0 | 5.43 | 93% | 33.2 | 1.8 | 0.50 |
| King of Herrings | 4 | 0% | 180 | 10.4 | 2.32 | 74% | 24.6 | 1.2 | 1.25 |
| Gulper Mother | 4 | 0% | 180 | 11.0 | 2.78 | 46% | 31.7 | 3.2 | 0.50 |
| Lamprey Queen | 4 | 0% | 180 | 4.2 | 2.33 | 22% | 11.8 | 5.8 | 0.75 |
| Fallen Angel | 4 | 0% | 180 | 9.9 | 3.86 | 97% | 53.2 | 45.0 | 1.25 |

### Upset Stomach, hold mode

| Form | Rounds | Hunter wins | Round (s) | Bites/min | Fish per bite | Bites that took something | Fish per min | Spat per round | Hurls |
|---|---|---|---|---|---|---|---|---|---|
| Drowned Shark | 4 | 100% | 85 | 10.6 | 1.33 | 50% | 15.7 | 0.25 | 0 |
| Humpback | 4 | 100% | 74 | 4.3 | 4.33 | 76% | 18.7 | 0.25 | 0 |
| Orca | 4 | 25% | 163 | 2.9 | 2.03 | 84% | 6.9 | 0.00 | 0 |
| Beluga | 4 | 0% | 180 | 2.5 | 0.53 | 43% | 1.3 | 0.00 | 0 |
| Sperm Whale | 4 | 50% | 117 | 3.3 | 2.00 | 46% | 7.6 | 0.00 | 0 |
| Blue Whale | 4 | 100% | 36 | 5.9 | 5.43 | 86% | 34.2 | 0.25 | 0 |
| King of Herrings | 4 | 100% | 40 | 9.1 | 2.92 | 71% | 26.5 | 0.00 | 0 |
| Gulper Mother | 4 | 100% | 36 | 10.9 | 2.69 | 50% | 29.4 | 0.50 | 0 |
| Lamprey Queen | 4 | 75% | 138 | 3.3 | 2.57 | 30% | 8.9 | 0.00 | 0 |
| Fallen Angel | 4 | 100% | 28 | 9.1 | 2.94 | 100% | 40.0 | 1.25 | 0 |

### Clean Sweep, tap mode

| Form | Rounds | Hunter wins | Round (s) | Bites/min | Fish per bite | Bites that took something | Fish per min | Rams per round | Prey eaten per round |
|---|---|---|---|---|---|---|---|---|---|
| Drowned Shark | 4 | 0% | 180 | 5.8 | 1.03 | 65% | 6.3 | 1.2 | 0.50 |
| Humpback | 4 | 0% | 180 | 1.8 | 4.27 | 100% | 8.5 | 2.0 | 0.25 |
| Orca | 4 | 0% | 180 | 1.5 | 1.06 | 89% | 1.8 | 0.5 | 0.25 |
| Beluga | 4 | 0% | 180 | 1.3 | 0.50 | 50% | 1.7 | 3.0 | 0.00 |
| Sperm Whale | 4 | 0% | 180 | 2.4 | 1.83 | 79% | 5.8 | 4.2 | 0.25 |
| Blue Whale | 4 | 0% | 180 | 4.7 | 7.59 | 100% | 37.3 | 5.8 | 1.50 |
| King of Herrings | 4 | 0% | 180 | 10.1 | 2.46 | 82% | 25.4 | 1.8 | 0.75 |
| Gulper Mother | 4 | 0% | 180 | 7.2 | 3.31 | 83% | 24.0 | 0.8 | 0.50 |
| Lamprey Queen | 4 | 0% | 180 | 10.0 | 0.42 | 42% | 4.8 | 2.0 | 0.50 |
| Fallen Angel | 4 | 0% | 180 | 13.1 | 0.68 | 46% | 9.0 | 0.2 | 0.50 |

### Upset Stomach, tap mode

| Form | Rounds | Hunter wins | Round (s) | Bites/min | Fish per bite | Bites that took something | Fish per min | Spat per round | Hurls |
|---|---|---|---|---|---|---|---|---|---|
| Drowned Shark | 4 | 25% | 176 | 5.5 | 1.20 | 68% | 6.7 | 0.00 | 0 |
| Humpback | 4 | 100% | 94 | 2.7 | 4.47 | 100% | 12.7 | 0.00 | 0 |
| Orca | 4 | 0% | 180 | 2.2 | 0.88 | 69% | 2.8 | 0.25 | 0 |
| Beluga | 4 | 0% | 180 | 1.6 | 0.53 | 53% | 1.0 | 0.00 | 0 |
| Sperm Whale | 4 | 25% | 176 | 2.0 | 1.83 | 70% | 4.7 | 0.00 | 0 |
| Blue Whale | 4 | 100% | 46 | 3.3 | 12.00 | 100% | 39.5 | 0.75 | 0 |
| King of Herrings | 4 | 100% | 35 | 7.7 | 4.11 | 89% | 31.5 | 0.25 | 0 |
| Gulper Mother | 4 | 100% | 28 | 7.9 | 4.27 | 80% | 33.7 | 0.00 | 0 |
| Lamprey Queen | 4 | 0% | 180 | 9.5 | 0.39 | 41% | 4.0 | 1.00 | 0 |
| Fallen Angel | 4 | 100% | 111 | 14.3 | 0.68 | 46% | 12.8 | 1.25 | 0 |

### Hold against tap, Clean Sweep

| Form | Fish per bite hold / tap | Fish per min hold / tap | Bites per min hold / tap | Hunter wins hold / tap | Round (s) hold / tap |
|---|---|---|---|---|---|
| Drowned Shark | 0.99 / 1.03 | 11.8 / 6.3 | 10.9 / 5.8 | 0% / 0% | 180 / 180 |
| Humpback | 3.98 / 4.27 | 15.3 / 8.5 | 3.7 / 1.8 | 0% / 0% | 180 / 180 |
| Orca | 1.40 / 1.06 | 4.2 / 1.8 | 2.5 / 1.5 | 0% / 0% | 180 / 180 |
| Beluga | 0.70 / 0.50 | 2.0 / 1.7 | 2.8 / 1.3 | 0% / 0% | 180 / 180 |
| Sperm Whale | 2.23 / 1.83 | 9.9 / 5.8 | 4.3 / 2.4 | 0% / 0% | 180 / 180 |
| Blue Whale | 5.43 / 7.59 | 33.2 / 37.3 | 6.0 / 4.7 | 0% / 0% | 180 / 180 |
| King of Herrings | 2.32 / 2.46 | 24.6 / 25.4 | 10.4 / 10.1 | 0% / 0% | 180 / 180 |
| Gulper Mother | 2.78 / 3.31 | 31.7 / 24.0 | 11.0 / 7.2 | 0% / 0% | 180 / 180 |
| Lamprey Queen | 2.33 / 0.42 | 11.8 / 4.8 | 4.2 / 10.0 | 0% / 0% | 180 / 180 |
| Fallen Angel | 3.86 / 0.68 | 53.2 / 9.0 | 9.9 / 13.1 | 0% / 0% | 180 / 180 |

### Hold against tap, Upset Stomach

| Form | Fish per bite hold / tap | Fish per min hold / tap | Bites per min hold / tap | Hunter wins hold / tap | Round (s) hold / tap |
|---|---|---|---|---|---|
| Drowned Shark | 1.33 / 1.20 | 15.7 / 6.7 | 10.6 / 5.5 | 100% / 25% | 85 / 176 |
| Humpback | 4.33 / 4.47 | 18.7 / 12.7 | 4.3 / 2.7 | 100% / 100% | 74 / 94 |
| Orca | 2.03 / 0.88 | 6.9 / 2.8 | 2.9 / 2.2 | 25% / 0% | 163 / 180 |
| Beluga | 0.53 / 0.53 | 1.3 / 1.0 | 2.5 / 1.6 | 0% / 0% | 180 / 180 |
| Sperm Whale | 2.00 / 1.83 | 7.6 / 4.7 | 3.3 / 2.0 | 50% / 25% | 117 / 176 |
| Blue Whale | 5.43 / 12.00 | 34.2 / 39.5 | 5.9 / 3.3 | 100% / 100% | 36 / 46 |
| King of Herrings | 2.92 / 4.11 | 26.5 / 31.5 | 9.1 / 7.7 | 100% / 100% | 40 / 35 |
| Gulper Mother | 2.69 / 4.27 | 29.4 / 33.7 | 10.9 / 7.9 | 100% / 100% | 36 / 28 |
| Lamprey Queen | 2.57 / 0.39 | 8.9 / 4.0 | 3.3 / 9.5 | 75% / 0% | 138 / 180 |
| Fallen Angel | 2.94 / 0.68 | 40.0 / 12.8 | 9.1 / 14.3 | 100% / 100% | 28 / 111 |

### The bots' echo work

| Variant | Mode | Hunter bot clicks per round | Sniff seconds per round | Prey relocations per round |
|---|---|---|---|---|
| sweep | hold | 52.8 | 4.3 | 0.20 |
| sweep | tap | 57.6 | 4.6 | 0.17 |
| stomach | hold | 25.8 | 0.0 | 0.00 |
| stomach | tap | 39.2 | 0.0 | 0.00 |


## Open items for the play-test (none acted on)
1. **Clean Sweep may be too hard for the Hunter, or the bot is too weak.** 0 of 80 bot rounds won, with up to 1.5 of 4 prey found per round. Play it to see whether people find hidden prey inside 180 s. Possible knobs, not touched: `round_time`, `school_count` and sizes, `echo_range` and `click_gain`, the bots' `hunter_bot_read_exposure`, `prey_bot_exposure` and `prey_bot_patience`.
2. **Upset Stomach looks easy for most forms**: bot Hunters filled the belly in 28 to 85 s with six of the ten forms in hold mode (round clock 180 s; belly 100, decay 0.5/s, 4 per fish). Beluga never did, Orca 1 of 4, Lamprey 3 of 4. Whether the belly numbers or the weaker forms need a look is a play-test question.
3. **Beluga is the weakest form in all four cells** (0.5 to 0.7 fish per bite, 1 to 2 fish per minute), Orca next; Blue is the strongest per bite (5.4 hold, 7.6 to 12 tap). Their sheets are first guesses (Phase 2 of the two-stage plan).
4. **Hold against tap per form**: Lamprey and Angel get a lot more from the hold; King, Gulper and Blue take more per bite from a tap in Upset Stomach. The hold's higher bite rate with the bots is how they were told to open (`hunter_bot_open_gap` 1.6), not a measure of the hold.
5. **Fallen Angel rams**: 45 fish per Clean Sweep round in hold mode. Possibly the orbit around its locked target keeps it above `ram_speed`, so the body ram eats about as much as the lash (not checked). Check by feel; the drill suppresses the ram while it dashes, the lock does not.
6. **Prey bots take a while to find cover**: from a far spawn (up to about 100 m) a small fish needed about 13 to 20 s to reach a school (watched in one run), longer than the 12 s hide time, so one or two prey are still in the open when the Hunter is freed. The bot rushes (full throttle, boost beyond 15 m) but is speed-limited by its class.
7. **Relocation is rare** (0.2 per Clean Sweep round): the prey bot leaves only after a read of at least 0.45 for 2.5 s while joined, and a joined fish is rarely read that long.
8. **Upset Stomach, prey**: 0 to 1.25 prey were spat per round; no Hunter hurled in any of the 80 rounds.
9. **Size**: all of this is at 1.0x. Run it again with `--size=0.5` for the numbers a default match gives (not done).
10. **Not covered**: people's play (these are bots against bots), online, Whale Fall (disabled), 4 or more Hunters. The engulf bot has no Upset Stomach gate on its release (a prey inside the mouth is spat when it lets go), only on the press.
11. **Sample size**: 4 rounds per cell, so win rates move in 25-point steps and a single cell is a hint. Read the tables for ranking, not for exact values.

## Appendix: every round's end, length (s) and fish taken, per cell
- drowned_shark sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [46, 25, 41, 29]
- drowned_shark sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [18, 22, 20, 16]
- drowned_shark stomach hold: {'full': 4} lengths [4.2, 102.6, 130.3, 103.2] fish [15, 26, 25, 23]
- drowned_shark stomach tap: {'full': 1, 'hungry': 3} lengths [180.0, 162.8, 180.0, 180.0] fish [12, 27, 14, 26]
- humpback sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [63, 37, 25, 59]
- humpback sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [23, 5, 27, 47]
- humpback stomach hold: {'full': 4} lengths [75.9, 31.3, 168.9, 18.7] fish [24, 24, 25, 19]
- humpback stomach tap: {'full': 4} lengths [116.4, 62.7, 155.4, 43.0] fish [23, 17, 24, 16]
- orca sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [5, 15, 16, 15]
- orca sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [3, 7, 8, 3]
- orca stomach hold: {'full': 1, 'hungry': 3} lengths [180.0, 110.1, 180.0, 180.0] fish [8, 22, 23, 22]
- orca stomach tap: {'hungry': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [14, 11, 5, 3]
- beluga sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [2, 6, 4, 12]
- beluga sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [1, 3, 5, 11]
- beluga stomach hold: {'hungry': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [7, 1, 5, 3]
- beluga stomach tap: {'hungry': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [3, 1, 2, 6]
- sperm sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [28, 26, 40, 25]
- sperm sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [24, 5, 10, 31]
- sperm stomach hold: {'full': 2, 'hungry': 2} lengths [180.0, 180.0, 5.4, 103.2] fish [0, 17, 15, 27]
- sperm stomach tap: {'full': 1, 'hungry': 3} lengths [180.0, 180.0, 162.3, 180.0] fish [3, 13, 27, 12]
- blue sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [102, 102, 100, 94]
- blue sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [113, 116, 123, 96]
- blue stomach hold: {'full': 4} lengths [85.0, 42.3, 6.9, 7.7] fish [23, 28, 16, 14]
- blue stomach tap: {'full': 4} lengths [22.0, 24.8, 122.6, 13.0] fish [28, 17, 51, 24]
- king_of_herrings sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [65, 75, 92, 63]
- king_of_herrings sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [89, 78, 58, 80]
- king_of_herrings stomach hold: {'full': 4} lengths [32.0, 92.2, 15.0, 19.4] fish [18, 20, 14, 18]
- king_of_herrings stomach tap: {'full': 4} lengths [20.1, 50.4, 40.8, 29.4] fish [16, 21, 19, 18]
- gulper_mother sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [132, 96, 64, 88]
- gulper_mother sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [90, 73, 57, 68]
- gulper_mother stomach hold: {'full': 4} lengths [40.7, 48.4, 41.7, 12.1] fish [18, 20, 16, 16]
- gulper_mother stomach tap: {'full': 4} lengths [4.5, 43.6, 33.1, 32.6] fish [16, 18, 15, 15]
- lamprey_queen sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [44, 31, 23, 44]
- lamprey_queen sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [16, 20, 9, 13]
- lamprey_queen stomach hold: {'full': 3, 'hungry': 1} lengths [114.9, 169.7, 180.0, 88.3] fish [21, 24, 18, 19]
- lamprey_queen stomach tap: {'hungry': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [18, 7, 14, 9]
- fallen_angel sweep hold: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [171, 139, 157, 172]
- fallen_angel sweep tap: {'clock': 4} lengths [180.0, 180.0, 180.0, 180.0] fish [26, 33, 30, 19]
- fallen_angel stomach hold: {'full': 4} lengths [10.2, 33.3, 28.7, 40.3] fish [15, 18, 20, 22]
- fallen_angel stomach tap: {'full': 4} lengths [80.1, 157.1, 146.8, 60.4] fish [23, 25, 28, 19]
