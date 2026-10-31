"""When the main weapon reached Lv 5, 10, 15 and 20 in each real run log.

planning_bosses_and_survival.md §5a. For every run_*.json in the run log
folder: the first time player 0's "attack Lv N" pick crossed each level, and
the minute sample at that time (zombies out, the director's target, stage,
difficulty, average zombie hp, dps), plus how the run ended. Legacy RL-hitbox
class names (DOMINUS, MERC, OCTANE...) are mapped onto the current classes.

    uv run python tools/milestones.py [--logs DIR] [--since 2026-10-23] [--csv OUT]

Prints a tab-separated table; --csv also writes it. medians.py builds on it.
"""
import argparse
import csv
import glob
import json
import os
import re
import sys

LEVELS = (5, 10, 15, 20)
DEFAULT_LOGS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata",
                            "Under Water The Fish Don't Stink", "run_logs")
# FishCharacter's aliases (scripts/fish_character.gd): old names -> classes.
ALIASES = {
    "OCTANE": "SKIRMISHER", "DOMINUS": "HUNTER", "PLANK": "GLIDER", "BREAKOUT": "LANCER", "HYBRID": "CHARMER",
    "MERC": "BULWARK", "LIONFISH": "SCORCHER", "MOON_JELLY": "DRIFTER", "MANTIS": "BRAWLER",
    "WHALE_SHARK": "BREACHER", "SEA_HARE": "ALCHEMIST",
}
FIELDS = ["run", "fish", "level", "minute", "player_level", "alive", "target", "stage", "difficulty", "avg_hp", "dps",
          "outcome", "minutes", "cause"]


def normalise(fish):
    fish = (fish or "?").upper()
    return ALIASES.get(fish, fish)


def run_logs(folder, since=""):
    """Each run log's (name, parsed json), oldest first, from `since` (a date prefix) on."""
    for path in sorted(glob.glob(os.path.join(folder, "run_*.json"))):
        name = os.path.basename(path)[4:-5]
        if since and name < since:
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                yield name, json.load(handle)
        except (OSError, ValueError):
            continue


def milestones(log):
    """{level: seconds} when player 0's main weapon first reached each of LEVELS."""
    hit = {}
    for pick in log.get("picks", []):
        match = re.match(r"attack Lv (\d+)", pick.get("card", ""))
        if not match or pick.get("player", 0) != 0:
            continue
        for level in LEVELS:
            if int(match.group(1)) >= level and level not in hit:
                hit[level] = pick["t"]
    return hit


def sample_at(log, seconds):
    """The last minute sample taken by `seconds` (+30 s: the sample nearest it), or {}."""
    found = {}
    for sample in log.get("samples", []):
        if sample["t"] * 60 <= seconds + 30:
            found = sample
    return found


def rows(folder, since=""):
    for name, log in run_logs(folder, since):
        ending = log.get("ending", {}) or {}
        players = ending.get("players") or [{}]
        fish = normalise(players[0].get("fish"))
        for level, seconds in sorted(milestones(log).items()):
            sample = sample_at(log, seconds)
            yield {
                "run": name, "fish": fish, "level": level, "minute": round(seconds / 60, 2),
                "player_level": sample.get("level"), "alive": sample.get("alive"), "target": sample.get("target"),
                "stage": sample.get("stage"), "difficulty": sample.get("difficulty"), "avg_hp": sample.get("avg_hp"),
                "dps": sample.get("dps"), "outcome": ending.get("outcome", "?"), "minutes": log.get("minutes"),
                "cause": ending.get("cause", ""),
            }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--logs", default=DEFAULT_LOGS, help="the run log folder (user://run_logs)")
    parser.add_argument("--since", default="", help="only runs from this date on, e.g. 2026-10-23")
    parser.add_argument("--csv", default="", help="also write the table here")
    args = parser.parse_args(argv)
    table = list(rows(args.logs, args.since))
    print("\t".join(FIELDS))
    for row in table:
        print("\t".join("" if row[f] is None else str(row[f]) for f in FIELDS))
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, FIELDS)
            writer.writeheader()
            writer.writerows(table)
    return 0


if __name__ == "__main__":
    sys.exit(main())
