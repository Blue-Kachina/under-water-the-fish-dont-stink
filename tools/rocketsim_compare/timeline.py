"""Side-by-side timeline of one scenario from the last run.py run: height, speed,
how upright the car is, and surface contact, RocketSim vs the game.

    uv run timeline.py wall_letgo [step_seconds]
"""
import json
import sys
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent / "out"
name = sys.argv[1]
step = float(sys.argv[2]) if len(sys.argv) > 2 else 0.25
ref = json.loads((OUT / "rocketsim.json").read_text())[name]
game = json.loads((OUT / "game.json").read_text())["scenarios"][name]
fmt = lambda v: "(" + ",".join(f"{x:5.2f}" for x in v) + ")"
every = max(1, round(step * 120))
print(f"{name}: (z height uu, speed uu/s, up.z, contact)")
print("   t  |  RS z    speed  up.z  fwd             ground | game z  speed  up.z  fwd             wheels")
for i in range(0, min(len(ref), len(game)), every):
    r, g = ref[i], game[i]
    print(f"{i / 120:5.2f} | {r['com'][2]:6.0f} {np.linalg.norm(r['vel']):6.0f} {r["up"][2]:5.2f} {fmt(r["fwd"])} {str(r["on_ground"]):5} "
          f"| {g['com'][2]:6.0f} {np.linalg.norm(g['vel']):6.0f} {g["up"][2]:5.2f} {fmt(g["fwd"])} {g.get("wheels", "?")}")
