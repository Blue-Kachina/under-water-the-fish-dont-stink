"""Side-by-side ground handling of one scenario from the last run.py run:
speed, yaw rate, heading and slip angle (between the nose and the direction of
travel), RocketSim vs the game. For turns and powerslides.

    uv run turnline.py ground_powerslide [step_seconds]
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent / "out"
name = sys.argv[1]
step = float(sys.argv[2]) if len(sys.argv) > 2 else 0.1
ref = json.loads((OUT / "rocketsim.json").read_text())[name]
game = json.loads((OUT / "game.json").read_text())["scenarios"][name]
every = max(1, round(step * 120))


def row(s):
    vel = np.array(s["vel"])
    fwd = np.array(s["fwd"])
    up = np.array(s["up"])
    speed = np.linalg.norm(vel)
    heading = math.degrees(math.atan2(fwd[1], fwd[0]))
    yaw_rate = float(np.dot(s["ang_vel"], up))
    flat = vel - up * np.dot(vel, up)
    slip = 0.0
    if np.linalg.norm(flat) > 50:
        # + = travelling to the nose's right
        slip = math.degrees(math.atan2(-np.dot(np.cross(fwd, flat), up), np.dot(fwd, flat)))
    return f"{speed:6.0f} {yaw_rate:6.2f} {heading:7.1f} {slip:6.1f}"


print(f"{name}: speed uu/s, yaw rate rad/s (about up), heading deg, slip deg")
print("   t  |  RS speed  yaw  heading  slip | game speed  yaw  heading  slip")
for i in range(0, min(len(ref), len(game)), every):
    print(f"{i / 120:5.2f} | {row(ref[i])} | {row(game[i])}")
