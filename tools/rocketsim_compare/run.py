"""RocketSim parity harness: run the same scripted inputs through RocketSim and
through the game's physics (headless Godot), then diff the two.

    uv run run.py                      # all runnable scenarios
    uv run run.py air_roll front_flip  # just these
    uv run run.py --godot PATH         # Godot console exe (default: $GODOT or the known install)

Writes out/scenarios.json, out/rocketsim.json, out/game.json and out/report.txt.
Everything is compared in Rocket League units and axes (see scenarios.py).

"Soccar" scenarios need RocketSim's collision meshes (dumped from the game,
not redistributable): put them in ./collision_meshes or point
RS_COLLISION_MESHES at them. Without them those scenarios are skipped.
"""

import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path

import numpy as np
import RocketSim as rs

from scenarios import SCENARIOS, TICK_RATE

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = HERE / "out"
DEFAULT_GODOT = r"C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
UU_PER_M = 100.0
CHECKPOINTS = (0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0)


# --- RocketSim ------------------------------------------------------------------

def vec(v) -> list:
    return [v.x, v.y, v.z]


def controls_at(scenario: dict, tick: int) -> dict:
    current = {}
    for start, values in scenario["controls"]:
        if start <= tick:
            current = values
    return current


def meshes_available() -> bool:
    path = Path(os.getenv("RS_COLLISION_MESHES", HERE / "collision_meshes"))
    return (path / "soccar").is_dir()


def run_rocketsim(scenario: dict) -> list[dict]:
    mode = rs.GameMode.THE_VOID if scenario["arena"] == "void" else rs.GameMode.SOCCAR
    arena = rs.Arena(mode, tick_rate=TICK_RATE)
    car = arena.add_car(0, car_config(scenario))

    spec = scenario["car"]
    state = car.get_state()  # level, facing +Y
    state.pos = rs.Vec(*spec["pos"])
    state.vel = rs.Vec(*spec["vel"])
    state.ang_vel = rs.Vec(*spec["ang_vel"])
    state.boost = spec["boost"]
    if spec.get("yaw") is not None:
        state.rot_mat = rs.Angle(spec["yaw"], 0.0, 0.0).as_rot_mat()
    if spec.get("rot"):  # any orientation (replay segments)
        rot = spec["rot"]
        state.rot_mat = rs.RotMat(rs.Vec(*rot["fwd"]), rs.Vec(*rot["right"]), rs.Vec(*rot["up"]))
    if spec["can_flip"]:
        state.is_on_ground = False
        state.has_jumped = True
        state.is_jumping = False
        state.jump_time = 0.2
        state.air_time = 0.2
        state.air_time_since_jump = 0.0
    car.set_state(state)

    ball = arena.ball.get_state()
    if scenario["ball"]:
        ball.pos = rs.Vec(*scenario["ball"]["pos"])
        ball.vel = rs.Vec(*scenario["ball"]["vel"])
        ball.ang_vel = rs.Vec(*scenario["ball"]["ang_vel"])
        if not any(scenario["ball"]["vel"]) and not scenario["ball"].get("kickoff_float", False):
            # RocketSim's ball floats until first touched (RL's kickoff rule). The game only does
            # that after a kickoff respawn, so wake it unless the scenario is testing the float.
            ball.vel = rs.Vec(0.0, 0.0, -0.01)
    else:
        ball.pos = rs.Vec(30000.0, 30000.0, 30000.0)  # out of the way (the void has no bounds)
        ball.vel = rs.Vec(0.0, 0.0, 0.0)
        arena.set_car_ball_collision(False)
    arena.ball.set_state(ball)

    ticks = []
    for tick in range(scenario["ticks"] + 1):
        st = car.get_state()
        b = arena.ball.get_state()
        ticks.append({
            "com": vec(st.pos), "vel": vec(st.vel), "ang_vel": vec(st.ang_vel),
            "fwd": vec(st.rot_mat.forward), "right": vec(st.rot_mat.right), "up": vec(st.rot_mat.up),
            "boost": st.boost, "flipping": st.is_flipping, "on_ground": st.is_on_ground,
            "ball_pos": vec(b.pos), "ball_vel": vec(b.vel), "ball_ang_vel": vec(b.ang_vel),
        })
        if tick == scenario["ticks"]:
            break
        c = controls_at(scenario, tick)
        car.set_controls(rs.CarControls(
            throttle=c.get("throttle", 0.0), steer=c.get("steer", 0.0), pitch=c.get("pitch", 0.0),
            yaw=c.get("yaw", 0.0), roll=c.get("roll", 0.0), jump=c.get("jump", False),
            boost=c.get("boost", False), handbrake=c.get("handbrake", False)))
        arena.step(1)
    return ticks


# --- Geometry --------------------------------------------------------------------

def car_config(scenario: dict):
    """The scenario's car (RocketSim's preset for its hitbox; Octane unless it says)."""
    return getattr(rs.CarConfig, scenario.get("hitbox", "octane").upper())


def car_offset(scenario: dict) -> np.ndarray:
    cfg = rs.Arena(rs.GameMode.THE_VOID).add_car(0, car_config(scenario)).get_config()
    return np.array(vec(cfg.hitbox_pos_offset))  # (forward, right, up) from the centre of mass


def hitbox_centre(tick: dict, offset: np.ndarray) -> np.ndarray:
    return (np.array(tick["com"]) + offset[0] * np.array(tick["fwd"])
            + offset[1] * np.array(tick["right"]) + offset[2] * np.array(tick["up"]))


def game_start(scenario: dict, first: dict, offset: np.ndarray) -> dict:
    """Where the game puts the fish: its centre on RL's hitbox centre, same orientation, and
    its centre of mass moving like RL's (a body's velocity is its centre of mass's)."""
    return {"centre": hitbox_centre(first, offset).tolist(), "com_vel": first["vel"],
            "ang_vel": first["ang_vel"], "fwd": first["fwd"], "right": first["right"], "up": first["up"],
            "boost": scenario["car"]["boost"], "can_flip": scenario["car"]["can_flip"]}


def rot_error_deg(a: dict, b: dict) -> float:
    ma = np.array([a["fwd"], a["right"], a["up"]])
    mb = np.array([b["fwd"], b["right"], b["up"]])
    cos = (np.trace(ma @ mb.T) - 1.0) / 2.0
    return math.degrees(math.acos(max(-1.0, min(1.0, cos))))


# --- Comparison --------------------------------------------------------------------

def compare(scenario: dict, ref: list[dict], game: list[dict], offset: np.ndarray) -> dict:
    n = min(len(ref), len(game))
    com0 = np.array(ref[0]["com"])
    game_com0 = np.array(game[0]["com"])
    rows = []
    for i in range(n):
        r, g = ref[i], game[i]
        moved_ref = np.array(r["com"]) - com0
        moved_game = np.array(g["com"]) - game_com0
        row = {
            "t": i / TICK_RATE,
            "path": np.linalg.norm(moved_game - moved_ref) / UU_PER_M,
            "hitbox": np.linalg.norm(np.array(g["centre"]) - hitbox_centre(r, offset)) / UU_PER_M,
            "vel": np.linalg.norm(np.array(g["vel"]) - np.array(r["vel"])) / UU_PER_M,
            "rot": rot_error_deg(r, g),
            "ang_vel": float(np.linalg.norm(np.array(g["ang_vel"]) - np.array(r["ang_vel"]))),
            "boost": abs(g["boost"] - r["boost"]),
            "ref_speed": np.linalg.norm(r["vel"]) / UU_PER_M,
            "game_speed": np.linalg.norm(g["vel"]) / UU_PER_M,
        }
        if scenario["ball"]:
            row["ball"] = np.linalg.norm(np.array(g["ball_pos"]) - np.array(r["ball_pos"])) / UU_PER_M
            row["ball_vel"] = np.linalg.norm(np.array(g["ball_vel"]) - np.array(r["ball_vel"])) / UU_PER_M
            row["ref_ball_speed"] = np.linalg.norm(r["ball_vel"]) / UU_PER_M
            row["game_ball_speed"] = np.linalg.norm(g["ball_vel"]) / UU_PER_M
        rows.append(row)
    keys = [k for k in rows[0] if k not in ("t",)]
    worst = {k: max(rows, key=lambda row: row[k]) for k in keys}
    return {"rows": rows, "worst": {k: (worst[k][k], worst[k]["t"]) for k in keys}, "final": rows[-1]}


def report(results: dict, skipped: list[str]) -> str:
    lines = ["RocketSim parity report (game vs RocketSim, same inputs; errors in m, m/s, deg, rad/s)", ""]
    header = f"{'scenario':<22}{'path':>8}{'hitbox':>8}{'vel':>8}{'rot':>8}{'w':>7}{'boost':>7}{'ball':>8}{'ballv':>8}   worst at"
    lines += ["Worst error over the run:", header, "-" * len(header)]
    for name, res in results.items():
        w = res["worst"]
        ball = f"{w['ball'][0]:8.2f}{w['ball_vel'][0]:8.2f}" if "ball" in w else f"{'':8}{'':8}"
        when = f"path {w['path'][1]:.2f}s, rot {w['rot'][1]:.2f}s"
        lines.append(f"{name:<22}{w['path'][0]:8.2f}{w['hitbox'][0]:8.2f}{w['vel'][0]:8.2f}{w['rot'][0]:8.1f}"
                     f"{w['ang_vel'][0]:7.2f}{w['boost'][0]:7.1f}{ball}   {when}")
    lines += ["", "Columns: path = centre-of-mass displacement difference (pure dynamics);",
              "hitbox = visible hitbox-centre difference (also includes where each body's centre of mass is:",
              "RL's is 0.14 m behind and 0.21 m below the hitbox centre, the fish's wherever Godot puts it);",
              "vel = velocity difference; rot = orientation difference; w = angular velocity difference.", ""]
    lines.append("Checkpoints (game | RocketSim speed, and errors):")
    for name, res in results.items():
        lines.append(f"  {name}")
        for cp in CHECKPOINTS:
            i = round(cp * TICK_RATE)
            if i >= len(res["rows"]):
                break
            r = res["rows"][i]
            ball = (f"  ball {r['game_ball_speed']:6.2f}|{r['ref_ball_speed']:6.2f} m/s err {r['ball']:.2f} m"
                    if "ball" in r else "")
            lines.append(f"    t={cp:4.2f}s speed {r['game_speed']:6.2f}|{r['ref_speed']:6.2f}  path {r['path']:5.2f}"
                         f"  rot {r['rot']:6.1f}  w {r['ang_vel']:5.2f}  boost {r['boost']:5.1f}{ball}")
    if skipped:
        lines += ["", "Skipped (need RocketSim collision meshes): " + ", ".join(skipped)]
    return "\n".join(lines)


# --- Real Rocket League (replay segments, replay_segments.py) -------------------------

def state_at(ticks: list[dict], t: float) -> dict:
    """A simulation's state at time `t` (s): centre of mass and velocity interpolated
    between ticks, orientation from the nearer tick."""
    f = min(max(t * TICK_RATE, 0.0), len(ticks) - 1.0)
    k0 = int(math.floor(f))
    k1 = min(k0 + 1, len(ticks) - 1)
    w = f - k0
    a, b = ticks[k0], ticks[k1]
    near = b if w >= 0.5 else a
    return {"com": ((1 - w) * np.array(a["com"]) + w * np.array(b["com"])).tolist(),
            "vel": ((1 - w) * np.array(a["vel"]) + w * np.array(b["vel"])).tolist(),
            "fwd": near["fwd"], "right": near["right"], "up": near["up"]}


def against_truth(scenario: dict, ticks: list[dict]) -> list[dict]:
    """A simulation's error against the replay's recorded samples: centre of mass (m),
    velocity (m/s), orientation (deg), at each sample time."""
    rows = []
    for sample in scenario["truth"]:
        sim = state_at(ticks, sample["t"])
        rows.append({"t": sample["t"],
                     "pos": float(np.linalg.norm(np.array(sim["com"]) - np.array(sample["com"])) / UU_PER_M),
                     "vel": float(np.linalg.norm(np.array(sim["vel"]) - np.array(sample["vel"])) / UU_PER_M),
                     "rot": rot_error_deg(sim, sample)})
    return rows


def error_at(rows: list[dict], t: float, key: str) -> float | None:
    """`key` at the last sample no later than `t`, or None if the segment is shorter."""
    best = None
    for row in rows:
        if row["t"] <= t + 1e-6:
            best = row[key]
    return best if rows and rows[-1]["t"] >= t - 0.05 else None


def truth_report(scenarios: list[dict], reference: dict, game: dict, label: str) -> tuple[str, dict]:
    """Medians and spreads, per kind of segment, of RocketSim's and the game's errors against
    the replays; and the segments where the game is furthest off."""
    rows = {}
    for sc in scenarios:
        rows[sc["name"]] = {"rs": against_truth(sc, reference[sc["name"]]), "game": against_truth(sc, game[sc["name"]])}
    lines = [f"Real Rocket League (replays) vs RocketSim and the game{(' — ' + label) if label else ''}",
             "Errors against the replay's own recorded states: centre of mass (m), velocity (m/s), orientation (deg).",
             "p50 / p75 / p90 over segments; 'at' = time since the segment's start.", ""]
    summary = {}
    for kind in sorted({sc["kind"] for sc in scenarios}):
        group = [sc for sc in scenarios if sc["kind"] == kind]
        lines.append(f"{kind}: {len(group)} segments")
        for at in (0.25, 0.5, 1.0):
            for key, unit in (("pos", "m"), ("vel", "m/s"), ("rot", "deg")):
                cols = []
                for who in ("rs", "game"):
                    values = [v for v in (error_at(rows[sc["name"]][who], at, key) for sc in group) if v is not None]
                    if not values:
                        cols = []
                        break
                    p = np.percentile(values, [50, 75, 90])
                    summary[f"{kind}/{who}/{key}@{at}"] = float(p[0])
                    cols.append(f"{p[0]:7.3f} {p[1]:7.3f} {p[2]:7.3f}")
                if cols:
                    lines.append(f"  at {at:4.2f}s {key:>3} ({unit:>3})  RocketSim {cols[0]}   game {cols[1]}")
        lines.append("")
    summary["segments"] = {}
    for sc in scenarios:  # each segment's end state, for splitting results afterwards
        end = sc["truth"][-1]["com"] if sc["truth"] else sc["car"]["pos"]
        wall = "side" if abs(end[0]) > 3900.0 else ("back" if abs(end[1]) > 4900.0 else "")
        summary["segments"][sc["name"]] = {
            "kind": sc["kind"], "wall": wall, "speed": sc["source"]["start_speed"],
            "rs": error_at(rows[sc["name"]]["rs"], 1.0, "pos"), "game": error_at(rows[sc["name"]]["game"], 1.0, "pos"),
            "rs_max": max((r["pos"] for r in rows[sc["name"]]["rs"]), default=0.0),
            "game_max": max((r["pos"] for r in rows[sc["name"]]["game"]), default=0.0)}
    worst = sorted(scenarios, key=lambda sc: -max((r["pos"] for r in rows[sc["name"]]["game"]), default=0.0))[:12]
    lines.append("Segments where the game is furthest from the replay (worst centre-of-mass error, m):")
    for sc in worst:
        g = max((r["pos"] for r in rows[sc["name"]]["game"]), default=0.0)
        r = max((x["pos"] for x in rows[sc["name"]]["rs"]), default=0.0)
        lines.append(f"  {sc['name']:<34} game {g:6.2f}  RocketSim {r:6.2f}   {sc['notes']}")
    return "\n".join(lines), summary


def run_game(args, quiet: bool, timeout: int = 900) -> dict:
    """Runs out/scenarios.json through the game (headless) and returns its per-tick states."""
    game_out = OUT / "game.json"
    game_out.unlink(missing_ok=True)
    cmd = [args.godot, "--headless", "--path", str(REPO), "res://tests/physics_parity_probe.tscn",
           "--", str(OUT / "scenarios.json"), str(game_out)]
    if not quiet:
        print("running the game:", " ".join(cmd[1:4]), "...")
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if not game_out.exists():
        print(proc.stdout[-4000:], proc.stderr[-4000:])
        sys.exit("the game didn't write its results")
    return json.loads(game_out.read_text())["scenarios"]


def run_replays(args, meshes: bool) -> None:
    if not meshes:
        sys.exit("replay segments are on RL's arena: they need RocketSim's collision meshes")
    scenarios = json.loads(args.replays.read_text())["scenarios"]
    if args.names:
        scenarios = [sc for sc in scenarios if sc["name"] in args.names or sc["kind"] in args.names]
    if args.steady:  # inputs that never change: no error from when between samples they changed
        scenarios = [sc for sc in scenarios if len(sc["controls"]) == 1]
    if args.sample:
        rng = np.random.default_rng(args.seed)
        picked = []
        for kind in sorted({sc["kind"] for sc in scenarios}):
            group = [sc for sc in scenarios if sc["kind"] == kind]
            idx = rng.choice(len(group), size=min(args.sample, len(group)), replace=False)
            picked += [group[i] for i in sorted(idx)]
        scenarios = picked
    overrides = {k: parse_setting(v) for k, v in (item.split("=", 1) for item in args.set)}
    OUT.mkdir(exist_ok=True)
    reference = {}
    for sc in scenarios:
        sc["settings"] = overrides
        reference[sc["name"]] = run_rocketsim(sc)
        sc["start"] = game_start(sc, reference[sc["name"]][0], car_offset(sc))
    (OUT / "rocketsim.json").write_text(json.dumps(reference))
    (OUT / "scenarios.json").write_text(json.dumps({"tick_rate": TICK_RATE, "scenarios": scenarios}))
    print(f"{len(scenarios)} replay segments; running the game ...", flush=True)
    game = run_game(args, quiet=True, timeout=3600)
    text, summary = truth_report(scenarios, reference, game, args.label)
    name = "replay_report" + (f"_{args.label}" if args.label else "")
    (OUT / f"{name}.txt").write_text(text, encoding="utf-8")
    (OUT / f"{name}.json").write_text(json.dumps(summary, indent=1))
    print(text)


def parse_setting(text: str):
    """A --set value: true/false for a switch, otherwise a number."""
    if text.lower() in ("true", "false"):
        return text.lower() == "true"
    return float(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*")
    parser.add_argument("--godot", default=os.getenv("GODOT", DEFAULT_GODOT))
    parser.add_argument("--set", action="append", default=[], metavar="NAME=VALUE",
                        help="override a FishController setting for the game run (repeatable), for tuning")
    parser.add_argument("--quiet", action="store_true", help="print only the worst-error table")
    parser.add_argument("--replays", type=Path, metavar="SEGMENTS.json",
                        help="run real-RL replay segments (replay_segments.py) instead, scored against the replays")
    parser.add_argument("--sample", type=int, default=0, help="with --replays: at most this many segments of each kind")
    parser.add_argument("--seed", type=int, default=1, help="with --sample: which random sample")
    parser.add_argument("--label", default="", help="with --replays: a name for this run in the report")
    parser.add_argument("--steady", action="store_true", help="with --replays: only segments whose inputs never change")
    args = parser.parse_args()

    meshes = meshes_available()
    if meshes:
        rs.init(str(Path(os.getenv("RS_COLLISION_MESHES", HERE / "collision_meshes"))))
    if args.replays:
        run_replays(args, meshes)
        return
    chosen = [sc for sc in SCENARIOS if not args.names or sc["name"] in args.names]
    skipped = [sc["name"] for sc in chosen if sc["arena"] == "soccar" and not meshes]
    runnable = [sc for sc in chosen if sc["name"] not in skipped]

    OUT.mkdir(exist_ok=True)
    reference = {}
    overrides = {k: parse_setting(v) for k, v in (item.split("=", 1) for item in args.set)}
    for sc in runnable:
        sc["settings"] = overrides
        reference[sc["name"]] = run_rocketsim(sc)
        sc["start"] = game_start(sc, reference[sc["name"]][0], car_offset(sc))
    (OUT / "rocketsim.json").write_text(json.dumps(reference))
    (OUT / "scenarios.json").write_text(json.dumps({"tick_rate": TICK_RATE, "scenarios": runnable}, indent=1))

    game = run_game(args, quiet=args.quiet)

    results = {sc["name"]: compare(sc, reference[sc["name"]], game[sc["name"]], car_offset(sc)) for sc in runnable}
    text = report(results, skipped)
    (OUT / "report.txt").write_text(text, encoding="utf-8")
    print(text.split("Columns:")[0] if args.quiet else text)


if __name__ == "__main__":
    main()
