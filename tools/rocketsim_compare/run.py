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
CHECKPOINTS = (0.25, 0.5, 1.0, 1.5, 2.0, 3.0)


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
    car = arena.add_car(0, rs.CarConfig.OCTANE)

    spec = scenario["car"]
    state = car.get_state()  # level, facing +Y
    state.pos = rs.Vec(*spec["pos"])
    state.vel = rs.Vec(*spec["vel"])
    state.ang_vel = rs.Vec(*spec["ang_vel"])
    state.boost = spec["boost"]
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

def octane_offset() -> np.ndarray:
    cfg = rs.Arena(rs.GameMode.THE_VOID).add_car(0, rs.CarConfig.OCTANE).get_config()
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*")
    parser.add_argument("--godot", default=os.getenv("GODOT", DEFAULT_GODOT))
    parser.add_argument("--set", action="append", default=[], metavar="NAME=VALUE",
                        help="override a FishController setting for the game run (repeatable), for tuning")
    parser.add_argument("--quiet", action="store_true", help="print only the worst-error table")
    args = parser.parse_args()

    meshes = meshes_available()
    if meshes:
        rs.init(str(Path(os.getenv("RS_COLLISION_MESHES", HERE / "collision_meshes"))))
    chosen = [sc for sc in SCENARIOS if not args.names or sc["name"] in args.names]
    skipped = [sc["name"] for sc in chosen if sc["arena"] == "soccar" and not meshes]
    runnable = [sc for sc in chosen if sc["name"] not in skipped]

    OUT.mkdir(exist_ok=True)
    offset = octane_offset()
    reference = {}
    overrides = {k: float(v) for k, v in (item.split("=", 1) for item in args.set)}
    for sc in runnable:
        sc["settings"] = overrides
        reference[sc["name"]] = run_rocketsim(sc)
        sc["start"] = game_start(sc, reference[sc["name"]][0], offset)
    (OUT / "rocketsim.json").write_text(json.dumps(reference))
    (OUT / "scenarios.json").write_text(json.dumps({"tick_rate": TICK_RATE, "scenarios": runnable}, indent=1))

    game_out = OUT / "game.json"
    game_out.unlink(missing_ok=True)
    cmd = [args.godot, "--headless", "--path", str(REPO), "res://tests/physics_parity_probe.tscn",
           "--", str(OUT / "scenarios.json"), str(game_out)]
    if not args.quiet:
        print("running the game:", " ".join(cmd[1:4]), "...")
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    if not game_out.exists():
        print(proc.stdout[-4000:], proc.stderr[-4000:])
        sys.exit("the game didn't write its results")
    game = json.loads(game_out.read_text())["scenarios"]

    results = {sc["name"]: compare(sc, reference[sc["name"]], game[sc["name"]], offset) for sc in runnable}
    text = report(results, skipped)
    (OUT / "report.txt").write_text(text, encoding="utf-8")
    print(text.split("Columns:")[0] if args.quiet else text)


if __name__ == "__main__":
    main()
