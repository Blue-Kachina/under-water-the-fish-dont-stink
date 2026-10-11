"""Yaw rate, speed and slip angle over time, RocketSim | game, for ground scenarios
in the last run (out/). For tuning steering and powerslide.

    uv run inspect_ground.py ground_turn ground_powerslide
"""

import json
import math
import sys
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent / "out"
TIMES = (0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1.0, 1.25, 1.49, 1.99)


def info(t: dict) -> tuple[float, float, float]:
    w = np.array(t["ang_vel"])
    fwd = np.array(t["fwd"])
    v = np.array(t["vel"])
    speed = math.hypot(v[0], v[1]) / 100.0
    cross = fwd[0] * v[1] - fwd[1] * v[0]
    slip = math.degrees(math.atan2(cross, fwd[0] * v[0] + fwd[1] * v[1])) if speed > 0.3 else 0.0
    return float(w @ np.array(t["up"])), speed, slip


def main() -> None:
    ref = json.loads((OUT / "rocketsim.json").read_text())
    game = json.loads((OUT / "game.json").read_text())["scenarios"]
    for name in sys.argv[1:]:
        r, g = ref[name], game[name]
        print(f"== {name}  (yaw rad/s, speed m/s, slip deg: RocketSim | game)")
        for t in TIMES:
            i = round(t * 120)
            if i >= len(r):
                break
            a, b = info(r[i]), info(g[i])
            print(f"  t={t:4.2f} yaw {a[0]:6.2f}|{b[0]:6.2f}  speed {a[1]:6.2f}|{b[1]:6.2f}  slip {a[2]:7.1f}|{b[2]:7.1f}")


if __name__ == "__main__":
    main()
