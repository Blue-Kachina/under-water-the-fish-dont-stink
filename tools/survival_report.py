"""The class survival report (planning_bosses_and_survival.md §5d).

Reads the class survival sim's CSVs and JSONs (tests/class_survival_sim.gd,
in user://run_logs/survival/), weapon_bench's table (--bench) and the real
run logs (milestones.py), and writes analysis_class_survival.md:

- one table per weapon level with every class (survival, time to down, dps,
  kills a minute, clear ratio, hp lost a second), sorted by survival then
  clear ratio;
- each class's weapon sheet across the levels, and the classes' base stats;
- flags: survival or clear ratio more than 1 sigma under the median at a
  level; dps scaling Lv 5 -> 20 far off the others'; out-offences but dies,
  or survives but can't clear;
- the cross-checks: the sheet's and the sim's dps against weapon_bench's, and
  the sim's flags against the classes that went down early in real runs.

Hand-written conclusions go between the <!-- notes --> and <!-- /notes -->
markers in the output; they are kept when the report is written again.

    uv run python tools/survival_report.py [--dir DIR] [--runs matrix_*] [--bench weapon_bench_matrix] [--out analysis_class_survival.md]
"""
import argparse
import csv
import datetime
import glob
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from milestones import DEFAULT_LOGS, normalise, run_logs  # noqa: E402

DEFAULT_DIR = os.path.join(DEFAULT_LOGS, "survival")
LEVELS = (5, 10, 15, 20)
# FishAttack.INFO: the attack's title -> its hit source (weapon_bench's rows).
SOURCES = {
    "Anemone Sting": "sting", "Ghost Bite": "bite", "Shock Lash": "lash", "Bill Thrust": "thrust",
    "Bubble Volley": "bubbles", "Spine Burst": "spines", "Greek Fire Trail": "greek_fire",
    "Jellyfish Halo": "jellyfish_halo", "Purple Haze": "purple_haze", "Remora Buddy": "remora_buddy",
    "Cavitation Punch": "punch", "Leviathan's Coil": "leviathans_coil",
}
NUMERIC = ["seed", "weapon_level", "at_min", "player_level", "target", "target_end", "time_to_down", "seconds", "max_hp",
           "hp_lost_per_s", "lowest_hp_share", "taken", "taken_contact", "taken_lunge", "taken_hazard", "taken_ranged",
           "taken_boss", "taken_other", "battered", "battery_damage", "contact_share", "damage", "dps", "kills",
           "kills_per_min", "avg_zombie_hp", "ttk", "overkill_share", "hits", "hits_per_s", "damage_per_hit", "avg_alive",
           "max_alive", "fill", "spawn_rate", "clear_ratio", "spawned", "level_end", "cards_passed", "forced_picks", "real_s"]
NOTES_START = "<!-- notes -->"
NOTES_END = "<!-- /notes -->"


def load_runs(folder, pattern):
    rows, sheets, bases, conditions = [], {}, {}, {}
    for path in sorted(glob.glob(os.path.join(folder, pattern + ".csv"))):
        with open(path, encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                for key in NUMERIC:
                    if key in row and row[key] not in ("", None):
                        row[key] = float(row[key])
                row["survived"] = row["survived"] == "true"
                rows.append(row)
        json_path = path[:-4] + ".json"
        if os.path.exists(json_path):
            with open(json_path, encoding="utf-8") as handle:
                data = json.load(handle)
            sheets.update(data.get("sheets", {}))
            bases.update(data.get("bases", {}))
            conditions.update(data.get("conditions", {}))
    return rows, sheets, bases, conditions


def load_bench(folder, name):
    path = os.path.join(folder, name + ".csv")
    table = {}
    if name and os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                table[(row["source"], int(row["level"]))] = float(row["dps"])
    return table


def median(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def stdev(values):
    values = [v for v in values if v is not None]
    return statistics.pstdev(values) if len(values) > 1 else 0.0


def fmt(value, digits=1, pct=False):
    if value is None:
        return "-"
    if pct:
        return f"{value * 100:.0f}%"
    return f"{value:,.{digits}f}"


def cell_stats(rows):
    """Per (class, level): the mortal and god passes' summaries."""
    cells = {}
    for row in rows:
        cells.setdefault((row["fish"], int(row["weapon_level"])), []).append(row)
    out = {}
    for key, found in cells.items():
        mortal = [r for r in found if r["pass"] == "mortal"]
        god = [r for r in found if r["pass"] == "god"]
        downs = [r["time_to_down"] for r in mortal if not r["survived"]]
        out[key] = {
            "attack": found[0]["attack"],
            "mortal_runs": len(mortal), "god_runs": len(god),
            "survival": sum(1 for r in mortal if r["survived"]) / len(mortal) if mortal else None,
            "time_to_down": median(downs),
            "hp_lost_per_s": median([r["hp_lost_per_s"] for r in mortal]),
            "hp_lost_share_per_min": median([r["hp_lost_per_s"] * 60 / max(r["max_hp"], 1) for r in mortal]),
            "lowest_hp": median([r["lowest_hp_share"] for r in mortal]),
            "contact_share": median([r["contact_share"] for r in mortal]),
            "taken": {k: median([r["taken_" + k] for r in mortal]) for k in
                      ("contact", "lunge", "hazard", "ranged", "boss", "other")},
            "dps": median([r["dps"] for r in god]),
            "mortal_dps": median([r["dps"] for r in mortal]),
            "kills_per_min": median([r["kills_per_min"] for r in god]),
            "clear_ratio": median([r["clear_ratio"] for r in god]),
            "fill": median([r["fill"] for r in god]),
            "ttk": median([r["ttk"] for r in god]),
            "overkill": median([r["overkill_share"] for r in god]),
            "hits_per_s": median([r["hits_per_s"] for r in god]),
            "damage_per_hit": median([r["damage_per_hit"] for r in god]),
            "avg_zombie_hp": median([r["avg_zombie_hp"] for r in god]),
            "battery_share": median([r["battery_damage"] / r["damage"] if r["damage"] > 0 else 0.0 for r in god]),
            "max_hp": median([r["max_hp"] for r in mortal]),
            "real_speed": median([r["seconds"] / r["real_s"] for r in found if r["real_s"] > 0]),
        }
    return out


def flags(stats, classes):
    """{class: [flag text]} and the per-level spreads used."""
    out = {c: [] for c in classes}
    for level in LEVELS:
        here = {c: stats[(c, level)] for c in classes if (c, level) in stats}
        if len(here) < 3:
            continue
        for key, label, worse_low in (("survival", "survival", True), ("clear_ratio", "clear ratio", True),
                                      ("hp_lost_share_per_min", "hp lost a minute (share of max)", False)):
            values = [s[key] for s in here.values() if s[key] is not None]
            if len(values) < 3:
                continue
            mid, sigma = median(values), stdev(values)
            if sigma <= 1e-9:
                continue
            for c, s in here.items():
                v = s[key]
                if v is None:
                    continue
                if worse_low and v < mid - sigma:
                    out[c].append(f"Lv {level}: {label} {fmt(v, 2)} is more than 1 sigma under the median {fmt(mid, 2)} (sigma {fmt(sigma, 2)})")
                if not worse_low and v > mid + sigma:
                    out[c].append(f"Lv {level}: {label} {fmt(v, 3)} is more than 1 sigma over the median {fmt(mid, 3)} (sigma {fmt(sigma, 3)})")
        dps_mid = median([s["dps"] for s in here.values()])
        surv_mid = median([s["survival"] for s in here.values()])
        clear_vals = [s["clear_ratio"] for s in here.values()]
        clear_mid, clear_sigma = median(clear_vals), stdev(clear_vals)
        hp_mid = median([s["hp_lost_share_per_min"] for s in here.values()])
        for c, s in here.items():
            if s["dps"] and dps_mid and s["dps"] > dps_mid and (
                    (s["survival"] is not None and surv_mid is not None and s["survival"] < surv_mid)
                    or (s["hp_lost_share_per_min"] or 0) > (hp_mid or 0) * 1.5):
                out[c].append(f"Lv {level}: out-offences (dps {fmt(s['dps'], 0)} vs median {fmt(dps_mid, 0)}) but takes the most "
                              f"(survival {fmt(s['survival'], pct=True)}, hp lost {fmt(s['hp_lost_share_per_min'], 3)} of max a minute): a defence problem")
            if (s["survival"] or 0) >= (surv_mid or 0) and s["clear_ratio"] is not None and clear_sigma > 0 \
                    and s["clear_ratio"] < clear_mid - clear_sigma:
                out[c].append(f"Lv {level}: survives but can't clear (clear ratio {fmt(s['clear_ratio'], 2)} vs median "
                              f"{fmt(clear_mid, 2)}): an offence problem")
    scaling = {}
    for c in classes:
        lo, hi = stats.get((c, 5)), stats.get((c, 20))
        if lo and hi and lo["dps"] and hi["dps"]:
            scaling[c] = hi["dps"] / lo["dps"]
    if len(scaling) >= 3:
        mid, sigma = median(list(scaling.values())), stdev(list(scaling.values()))
        for c, ratio in scaling.items():
            if ratio < mid / 1.5 or ratio > mid * 1.5:
                out[c].append(f"dps scales x{ratio:.0f} from Lv 5 to 20, against the median x{mid:.0f} "
                              f"({'much slower' if ratio < mid else 'much faster'})")
    return out, scaling


def real_runs(folder, since):
    """Per class from the real logs: runs, downs, downs before 10 min, median minutes."""
    out = {}
    for _name, log in run_logs(folder, since):
        ending = log.get("ending") or {}
        players = ending.get("players") or [{}]
        fish = normalise(players[0].get("fish"))
        entry = out.setdefault(fish, {"runs": 0, "downs": 0, "early": 0, "minutes": [], "causes": {}})
        entry["runs"] += 1
        minutes = float(log.get("minutes") or 0.0)
        entry["minutes"].append(minutes)
        if ending.get("outcome") == "down":
            entry["downs"] += 1
            if minutes < 10.0:
                entry["early"] += 1
            cause = ending.get("cause") or "?"
            entry["causes"][cause] = entry["causes"].get(cause, 0) + 1
    return out


def write(args):
    rows, sheets, bases, conditions = load_runs(args.dir, args.runs)
    if not rows:
        print(f"no runs found in {args.dir} matching {args.runs}.csv")
        return 1
    bench = load_bench(args.dir, args.bench)
    stats = cell_stats(rows)
    classes = sorted({r["fish"] for r in rows})
    flagged, scaling = flags(stats, classes)
    real = real_runs(args.logs, args.since)

    notes = "\n_Conclusions and proposed retunes: none written yet._\n"
    if os.path.exists(args.out):
        with open(args.out, encoding="utf-8") as handle:
            old = handle.read()
        if NOTES_START in old and NOTES_END in old:
            notes = old.split(NOTES_START, 1)[1].split(NOTES_END, 1)[0]

    lines = []
    add = lines.append
    passes = sorted({r["pass"] for r in rows})
    seeds = len({r["seed"] for r in rows})
    add("# Class survival analysis: main weapon only")
    add("")
    add(f"Generated by `uv run python tools/survival_report.py` on {datetime.date.today().isoformat()} from "
        f"{len(rows)} one-minute runs ({len(classes)} classes x {len({int(r['weapon_level']) for r in rows})} weapon levels x "
        f"{'/'.join(passes)} x {seeds} seeds) of `tests/class_survival_sim.tscn` "
        f"(planning_bosses_and_survival.md §5). Hand-written sections sit between the notes markers and survive a rewrite.")
    add("")
    add("**What it measures.** Each run jumps an Unnatural run to the minute real runs reach the main weapon's level, "
        "puts the team at that level (max hp and the class's signature stat per level, no cards), gives the class's own "
        "attack at that level (facets spread over common upgrades, milestones on), holds the director's pressure so it "
        "wants the real runs' median target out, and fills the horde at once. A SurvivorBot (MAIN_ONLY: never takes a "
        "card, pearl or chest) then plays one minute. Stage events and bosses are off; the director's breathers stay on. "
        "The mortal pass measures survival; the god pass (can't go down) measures a full minute of offence.")
    add("")
    add("**This is the floor each class stands on, not overall class strength.** Nobody plays main-weapon-only.")
    add("")
    add("## Conditions (real runs' medians, `tools/medians.py`)")
    add("")
    add("| Main weapon | Minute | Team level | Director target (start of the minute) |")
    add("|---|---|---|---|")
    for level in LEVELS:
        c = conditions.get(str(level)) or conditions.get(level)
        if c:
            add(f"| Lv {level} | {c[0]} | {c[1]} | {c[2]} |")
    add("")
    add("Columns below: **survival** = share of mortal runs alive at the minute's end; **down at** = median seconds to a "
        "down (downs only); **hp lost/s** and **% max/min** = mortal pass, hp lost a second and as a share of max hp a "
        "minute; **lowest** = median lowest hp share; **contact** = share of frames with a zombie touching; **dps**, "
        "**kills/min**, **clear** and **fill** = god pass medians. **Clear ratio** = kills a minute / the most the "
        "director can send a minute at that time (a pack of swarm_size() every spawn_interval): above 1 keeps up, below "
        "1 gets swarmed. **ttk** = average zombie hp / dps.")
    add("")
    for level in LEVELS:
        here = [(c, stats[(c, level)]) for c in classes if (c, level) in stats]
        if not here:
            continue
        here.sort(key=lambda cs: (-(cs[1]["survival"] or 0), -(cs[1]["clear_ratio"] or 0)))
        add(f"## Main weapon Lv {level}")
        add("")
        add("| Class | Attack | Survival | Down at | hp lost/s | % max/min | Lowest | Contact | dps | kills/min | Clear | Fill | ttk (s) | Overkill | Battery share |")
        add("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for c, s in here:
            add(f"| {c.title()} | {s['attack']} | {fmt(s['survival'], pct=True)} | {fmt(s['time_to_down'], 0)} | "
                f"{fmt(s['hp_lost_per_s'], 2)} | {fmt(s['hp_lost_share_per_min'], 3)} | {fmt(s['lowest_hp'], pct=True)} | "
                f"{fmt(s['contact_share'], pct=True)} | {fmt(s['dps'], 0)} | {fmt(s['kills_per_min'], 0)} | "
                f"{fmt(s['clear_ratio'], 2)} | {fmt(s['fill'], 2)} | {fmt(s['ttk'], 3)} | {fmt(s['overkill'], pct=True)} | "
                f"{fmt(s['battery_share'], pct=True)} |")
        add("")
        add("Damage taken in the mortal pass by source (median hp a run): " + "; ".join(
            f"{c.title()} " + ", ".join(f"{k} {fmt(v, 0)}" for k, v in s["taken"].items() if v) for c, s in here
            if any(s["taken"].values())) + ".")
        add("")

    add("## Flags")
    add("")
    any_flag = False
    for c in classes:
        if flagged[c]:
            any_flag = True
            add(f"- **{c.title()}**")
            for text in flagged[c]:
                add(f"  - {text}")
    if not any_flag:
        add("- none")
    add("")
    add("DPS scaling Lv 5 -> 20 (god pass medians): " + ", ".join(f"{c.title()} x{r:.0f}" for c, r in sorted(scaling.items(), key=lambda cr: -cr[1])) + ".")
    add("")

    add("## Weapon sheets (the attack's own numbers at each level)")
    add("")
    add("From each class's attack after the jump: damage (base), per hit (with the Damage facet and the class's Damage stat), "
        "cooldown, attack speed, Size, Quantity (extra projectiles), reach, milestones, the facets the upgrades put on, "
        "and a theoretical single-target dps (per hit x hits a second x crits; fired attacks only, the steady ones work on "
        "their own timers). **Sim dps** is the god pass's median, **bench** weapon_bench's Test Tank dps for the attack's "
        "source at that level (no class stats: Lv 1 team, Hunter).")
    add("")
    for c in classes:
        add(f"### {c.title()}")
        add("")
        add("| Lv | Attack | Damage | Per hit | Cooldown | Atk speed | Size | Qty | Reach | Milestones | Theory dps | Sim dps | Bench dps | Facets |")
        add("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for level in LEVELS:
            sheet = sheets.get(f"{c}:{level}")
            if not sheet:
                continue
            source = SOURCES.get(sheet["attack"], "")
            bench_dps = bench.get((source, level))
            sim = stats.get((c, level), {}).get("dps")
            facets = ", ".join(f"{k} {v:g}" for k, v in sorted(sheet.get("facets", {}).items()))
            add(f"| {level} | {sheet['attack']} | {fmt(sheet['damage'], 1)} | {fmt(sheet['damage_per_hit'], 1)} | "
                f"{fmt(sheet['cooldown'], 2)} | {fmt(sheet['attack_speed'], 2)} | {fmt(sheet['size'], 2)} | {sheet['quantity']} | "
                f"{fmt(sheet['reach'], 1) if sheet['reach'] >= 0 else '-'} | {sheet['milestones']} | "
                f"{fmt(sheet['single_dps'], 0) if sheet['single_dps'] >= 0 else 'steady'} | {fmt(sim, 0)} | {fmt(bench_dps, 0)} | {facets} |")
        add("")

    add("## Class base stats")
    add("")
    add("| Class | Max hp Lv 1 | Armour (team Lv 8) | Regen | Top speed | Batter speed | Hitbox (l x w x h) | Taken factor | Extra i-frames | Signature (per level) |")
    add("|---|---|---|---|---|---|---|---|---|---|")
    for c in classes:
        b = bases.get(c)
        if not b:
            continue
        add(f"| {c.title()} | {b['max_hp_lv1']:g} | {b['armour']:g} | {b['regen']:g} | {b['max_speed']:g} | {b['batter_speed']:g} | "
            f"{' x '.join(f'{v:g}' for v in b['hitbox'])} | {b['taken_factor']:g} | {b['iframe_bonus']:g} | "
            f"{b['signature']} +{b['signature_per_level']:g} |")
    add("")
    add("Armour and regen are at the class's first scenario (weapon Lv 5, team Lv 8: the signature stat grows them "
        "per level). Top speed is the fish's own max_speed before stats, the same for every class. Max hp at a level is "
        "base_hp + hp_per_level per level for every class.")
    add("")

    add("## Cross-check: weapon_bench")
    add("")
    if bench:
        add("The sim's god-pass dps over weapon_bench's for the same source and level. The bench has no class stats (a Lv 1 "
            "Hunter in the Test Tank, immortal dummies crowding in) and the sim has the class's signature stat at the team's "
            "level and a real horde, so the ratio isn't 1; what matters is that it's similar across classes. A class far off "
            "the others' ratio is reading its weapon differently in a real horde (reach, aim, targets).")
        add("")
        add("| Class | Source | " + " | ".join(f"Lv {l}" for l in LEVELS) + " |")
        add("|---|---|" + "---|" * len(LEVELS))
        for c in classes:
            sheet = sheets.get(f"{c}:5") or {}
            source = SOURCES.get(sheet.get("attack", ""), "")
            cells = []
            for level in LEVELS:
                sim = stats.get((c, level), {}).get("dps")
                b = bench.get((source, level))
                cells.append(f"{sim / b:.1f}x" if sim and b else "-")
            add(f"| {c.title()} | {source} | " + " | ".join(cells) + " |")
    else:
        add(f"_No weapon_bench table found (`{args.bench}.csv` in {args.dir}); run weapon_bench with `--out {args.bench}`._")
    add("")

    add("## Cross-check: real runs")
    add("")
    add(f"From the run logs in user://run_logs since {args.since or 'the start'} (legacy RL-hitbox names mapped to classes). "
        "**Early downs** = runs that ended down before minute 10.")
    add("")
    add("| Class | Real runs | Downs | Early downs | Median minutes | Most common causes | Sim flags |")
    add("|---|---|---|---|---|---|---|")
    for c in sorted(set(classes) | set(real)):
        r = real.get(c, {"runs": 0, "downs": 0, "early": 0, "minutes": [], "causes": {}})
        causes = ", ".join(f"{k} ({v})" for k, v in sorted(r["causes"].items(), key=lambda kv: -kv[1])[:3])
        add(f"| {c.title()} | {r['runs']} | {r['downs']} | {r['early']} | {fmt(median(r['minutes']), 1)} | {causes or '-'} | "
            f"{len(flagged.get(c, []))} |")
    add("")

    add("## Known confounds")
    add("")
    add("- SurvivorBot's skill isn't equal across movement styles: Glider and Breacher may be helped or hurt by the bot rather "
        "than their kit. A stand-still control pass (aim only) would isolate the weapon; it was left out of this first run.")
    add("- \"Main weapon only\" is not how anyone plays: these are the floor each class stands on, not overall strength.")
    add("- The bot is safer than a human (balance pass 1): survival is relative between classes, not absolute.")
    add("- The weapon's upgrades are spread evenly over its facets at the common step; real runs pick rarer upgrades and "
        "choose facets, so real weapons at the same level are usually stronger.")
    add("- The director's pressure is held at the real runs' median target for the minute (it rises with the minute's "
        "baseline); breathers (relief) stay on, so a class that gets hurt gets short pauses in the packs.")
    add("- No stage events or bosses: real downs are often to bosses and swarm events, which this doesn't test.")
    add("- Drops (hearts, magnets, hourglasses) still fall and the bot can touch them on its way.")
    add("")
    add("## Conclusions and proposed retunes")
    add("")
    add(NOTES_START + notes + NOTES_END)
    add("")
    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
    print(f"wrote {args.out}: {len(rows)} runs, {sum(len(v) for v in flagged.values())} flags")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dir", default=DEFAULT_DIR, help="the sim's output folder (user://run_logs/survival)")
    parser.add_argument("--runs", default="matrix_*", help="the CSVs to read (a glob, without .csv)")
    parser.add_argument("--bench", default="weapon_bench_matrix", help="weapon_bench's --out table in --dir ('' for none)")
    parser.add_argument("--logs", default=DEFAULT_LOGS, help="the real run logs (user://run_logs)")
    parser.add_argument("--since", default="2026-10-23", help="real runs from this date on ('' for all)")
    parser.add_argument("--out", default="analysis_class_survival.md", help="the report to write")
    return write(parser.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
