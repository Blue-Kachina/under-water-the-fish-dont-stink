"""The conditions real runs are in when the main weapon reaches Lv 5/10/15/20.

planning_bosses_and_survival.md §5a: the medians over the run logs (from
milestones.py) of the minute, the team's level, the director's target, the
zombies out, difficulty and average zombie hp, per weapon level. These are
what tests/class_survival_sim.gd's CONDITIONS hold; after more play, refresh
them with this and paste the printed line over it.

    uv run python tools/medians.py [--logs DIR] [--since 2026-10-23] [--json OUT]
"""
import argparse
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from milestones import DEFAULT_LOGS, LEVELS, rows  # noqa: E402

KEYS = ["minute", "player_level", "target", "alive", "difficulty", "avg_hp"]


def medians(folder, since):
    by_level = {level: [] for level in LEVELS}
    for row in rows(folder, since):
        if row["target"] is None:
            continue
        by_level[row["level"]].append(row)
    out = {}
    for level, found in by_level.items():
        if not found:
            continue
        entry = {"runs": len(found), "minute_min": min(r["minute"] for r in found),
                 "minute_max": max(r["minute"] for r in found)}
        for key in KEYS:
            values = [r[key] for r in found if r[key] is not None]
            entry[key] = round(statistics.median(values), 2) if values else None
        out[level] = entry
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--logs", default=DEFAULT_LOGS, help="the run log folder (user://run_logs)")
    parser.add_argument("--since", default="2026-10-23", help="only runs from this date on ('' for all)")
    parser.add_argument("--json", default="", help="also write the table here")
    args = parser.parse_args(argv)
    table = medians(args.logs, args.since)
    print("| Main weapon | Runs | Minute (median, range) | Player level | Director target | Alive | Difficulty | Avg zombie hp |")
    print("|---|---|---|---|---|---|---|---|")
    for level, e in table.items():
        print(f"| Lv {level} | {e['runs']} | {e['minute']} ({e['minute_min']}-{e['minute_max']}) | {e['player_level']} | "
              f"{e['target']} | {e['alive']} | {e['difficulty']} | {e['avg_hp']} |")
    pairs = ", ".join(f"{level}: [{e['minute']}, {int(e['player_level'])}, {int(round(e['target']))}]"
                      for level, e in table.items())
    print("\nclass_survival_sim CONDITIONS: const CONDITIONS := {" + pairs + "}")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump(table, handle, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
