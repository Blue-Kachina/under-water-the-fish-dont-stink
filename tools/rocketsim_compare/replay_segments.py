"""Mine real Rocket League physics segments from converted replays, as harness scenarios.

    uv run replay_segments.py [DIR ...] [--per-replay N] [--out out/replay_scenarios.json]

DIR defaults to private_content/replays/converted/own (made by tools/rl_replay/convert_many.py).
Each segment is one car, alone (no car or ball nearby, no touches, no boost pickups, no jumps
or dodges, no teleports, live play), as a run.py scenario: the replay's first state as the start, its
recorded throttle / steer / boost / powerslide as the controls (held between samples), and
every later recorded sample as `truth`. `uv run run.py --replays out/replay_scenarios.json`
then runs RocketSim and the game from that start and scores both against the replay.

Kinds:
- floor_drive: a second on the flat floor, away from the walls. The control group: RocketSim
  and the game agree here, so what's left is the replay's own error (quantised states, inputs
  sampled at 30 Hz).
- wall_climb: from the flat floor up the ramp onto a side or back wall, kept only if the car
  ends up flush on a standard Soccar wall (so non-standard arenas drop out).

Replays record each car's centre of mass, in RL units and axes, like everything here.
"""

import argparse
import json
import math
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
DEFAULT_DIR = REPO / "private_content" / "replays" / "converted" / "own"
TICK_RATE = 120

FLOOR_Z = 17.0  # a car's centre of mass resting on the floor (uu)
SIDE_WALL_X = 4096.0
BACK_WALL_Y = 5120.0
GOAL_HALF_WIDTH = 893.0
FLAG_BOOST, FLAG_JUMP, FLAG_DOUBLE_JUMP, FLAG_DODGE, FLAG_POWERSLIDE, FLAG_DEMOLISHED = 1, 2, 4, 8, 16, 64
AIRBORNE_FLAGS = FLAG_JUMP | FLAG_DOUBLE_JUMP | FLAG_DODGE | FLAG_DEMOLISHED
CLEAR_OF_CARS = 500.0  # uu between centres
CLEAR_OF_BALL = 450.0


def quat_axes(q) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Forward, right and up of a car with rotation `q` (x, y, z, w), as rl_space.gd reads it."""
    x, y, z, w = q
    m = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    return m[:, 0], m[:, 1], m[:, 2]


class Track:
    """One car's samples from a replay, as numpy arrays indexed by frame."""

    def __init__(self, doc: dict, car: dict):
        n = len(doc["frames"]["time"])
        self.present = np.array(car["present"], dtype=bool)
        self.pos = np.array(car["pos"], dtype=float).reshape(n, 3)
        self.vel = np.array(car["vel"], dtype=float).reshape(n, 3)
        self.rot = np.array(car["rot"], dtype=float).reshape(n, 4)
        self.ang_vel = np.array(car["ang_vel"], dtype=float).reshape(n, 3)
        self.teleport = np.array(car["teleport"], dtype=bool)
        self.flags = np.array(car["flags"], dtype=int)
        self.throttle = np.array(car["throttle"], dtype=float)
        self.steer = np.array(car["steer"], dtype=float)
        self.boost = np.array(car["boost"], dtype=float)
        self.time = np.array(doc["frames"]["time"], dtype=float) + np.array(car.get("time_offset", [0.0] * n), dtype=float)
        self.up_z = np.array([quat_axes(q)[2][2] for q in self.rot])
        # A fresh sample: the state changed since the frame before (replays repeat a car's
        # last state on frames where it wasn't updated).
        self.fresh = np.ones(n, dtype=bool)
        self.fresh[1:] = np.any(self.pos[1:] != self.pos[:-1], axis=1) | np.any(self.vel[1:] != self.vel[:-1], axis=1)
        self.player = car["player"]


def load(path: Path) -> tuple[dict, list[Track]] | None:
    doc = json.loads(path.read_text(encoding="utf-8"))
    return doc, [Track(doc, car) for car in doc["cars"]]


def clear_window(doc: dict, tracks: list[Track], me: Track, a: int, b: int, ball_pos: np.ndarray,
                 touches: list[float]) -> bool:
    """Whether frames a..b are clean for `me`: live play, present, no teleport or airborne flags,
    nobody else near, the ball well away, and no touch by this car."""
    live = np.array(doc["frames"]["game_state"][a:b + 1]) == 0
    if not live.all() or not me.present[a:b + 1].all() or me.teleport[a + 1:b + 1].any():
        return False
    if (me.flags[a:b + 1] & AIRBORNE_FLAGS).any():
        return False
    for other in tracks:
        if other is me:
            continue
        seen = other.present[a:b + 1]
        if seen.any() and (np.linalg.norm(other.pos[a:b + 1][seen] - me.pos[a:b + 1][seen], axis=1) < CLEAR_OF_CARS).any():
            return False
    ball_seen = np.array(doc["ball"]["present"][a:b + 1], dtype=bool)
    if ball_seen.any() and (np.linalg.norm(ball_pos[a:b + 1][ball_seen] - me.pos[a:b + 1][ball_seen], axis=1) < CLEAR_OF_BALL).any():
        return False
    t0, t1 = me.time[a], me.time[b]
    return not any(t0 - 0.1 <= t <= t1 for t in touches)  # touches: ball touches and boost pickups


def on_floor(track: Track, i: int) -> bool:
    return abs(track.pos[i][2] - FLOOR_Z) < 4.0 and track.up_z[i] > 0.98


def on_standard_wall(track: Track, i: int) -> bool:
    """Flush on a standard Soccar side wall or back wall (not in a goal, a corner or the ceiling)."""
    x, y, z = track.pos[i]
    _, _, up = quat_axes(track.rot[i])
    if z < 300.0 or z > 1700.0:
        return False
    side = SIDE_WALL_X - FLOOR_Z - 25.0 < abs(x) < SIDE_WALL_X and abs(y) < 3700.0 and up[0] * -math.copysign(1, x) > 0.95
    back = BACK_WALL_Y - FLOOR_Z - 25.0 < abs(y) < BACK_WALL_Y and GOAL_HALF_WIDTH + 250.0 < abs(x) < 2800.0 \
        and up[1] * -math.copysign(1, y) > 0.95
    return side or back


def scenario(doc: dict, path: Path, me: Track, kind: str, a: int, b: int) -> dict:
    player = doc["players"][me.player]
    fwd, right, up = quat_axes(me.rot[a])
    t0 = me.time[a]
    ticks = int(round((me.time[b] - t0) * TICK_RATE))
    controls = []
    for i in range(a, b + 1):
        tick = int(round((me.time[i] - t0) * TICK_RATE))
        values = {"throttle": round(float(me.throttle[i]), 4), "steer": round(float(me.steer[i]), 4),
                  "boost": bool(me.flags[i] & FLAG_BOOST), "handbrake": bool(me.flags[i] & FLAG_POWERSLIDE)}
        if not controls or controls[-1][1] != values:
            controls.append([max(tick, 0), values])
    controls[0][0] = 0
    truth = []
    for i in range(a + 1, b + 1):
        if me.fresh[i]:
            f, r, u = quat_axes(me.rot[i])
            truth.append({"t": round(float(me.time[i] - t0), 5), "com": me.pos[i].tolist(), "vel": me.vel[i].tolist(),
                          "fwd": f.tolist(), "right": r.tolist(), "up": u.tolist()})
    speed = float(np.linalg.norm(me.vel[a]))
    return {
        "name": f"rp_{kind}_{doc['source']['replay_id'][:8].lower()}_{me.player}_{a}",
        "arena": "soccar", "ticks": ticks, "hitbox": player["hitbox_family"], "ball": None,
        "notes": f"{kind} from {path.name} player {me.player} frame {a} ({speed:.0f} uu/s, {doc['source']['map']})",
        "car": {"pos": me.pos[a].tolist(), "vel": me.vel[a].tolist(), "ang_vel": me.ang_vel[a].tolist(),
                "boost": float(me.boost[a]), "can_flip": False, "yaw": None,
                "rot": {"fwd": fwd.tolist(), "right": right.tolist(), "up": up.tolist()}},
        "controls": controls, "truth": truth, "kind": kind,
        "source": {"replay": path.name, "player": me.player, "frame": a, "map": doc["source"]["map"],
                   "build": doc["source"].get("build_version", ""), "start_speed": round(speed, 1)},
    }


def frames_at(track: Track, start: int, seconds: float) -> int:
    """The last frame at most `seconds` after frame `start`."""
    end = start
    while end + 1 < len(track.time) and track.time[end + 1] - track.time[start] <= seconds:
        end += 1
    return end


def mine(path: Path, per_replay: int) -> list[dict]:
    loaded = load(path)
    doc, tracks = loaded
    n = len(doc["frames"]["time"])
    ball_pos = np.array(doc["ball"]["pos"], dtype=float).reshape(n, 3)
    found = []
    for me in tracks:
        # Ball touches, and boost pad pickups: RL and RocketSim have pads, the game doesn't (yet),
        # so a segment crossing one would score the missing pad, not the physics.
        touches = [e["time"] for e in doc["events"]
                   if e["type"] in ("touch", "boost_pickup") and e.get("player") == me.player]
        climbs = floors = 0
        i = 1
        while i < n - 1:
            # wall_climb: the car's up tips past 70 degrees while it leaves the floor for a wall.
            if climbs < per_replay and me.present[i] and me.up_z[i] < 0.35 <= me.up_z[i - 1]:
                last_floor = i
                while last_floor > 0 and not on_floor(me, last_floor):
                    last_floor -= 1
                if i - last_floor <= 12 and on_floor(me, last_floor):  # straight off the floor (<= 0.4 s)
                    a = last_floor
                    while a > 0 and me.time[last_floor] - me.time[a - 1] <= 0.25 and on_floor(me, a - 1):
                        a -= 1
                    b = frames_at(me, i, 0.6)
                    settled = frames_at(me, i, 0.35)
                    if (me.time[last_floor] - me.time[a] >= 0.15 and np.linalg.norm(me.vel[a]) > 400.0
                            and on_standard_wall(me, settled) and clear_window(doc, tracks, me, a, b, ball_pos, touches)):
                        found.append(scenario(doc, path, me, "wall_climb", a, b))
                        climbs += 1
                        i = b
                        continue
            # floor_drive: a second on the flat floor, away from the walls.
            if floors < per_replay and on_floor(me, i) and np.linalg.norm(me.vel[i]) > 400.0:
                b = frames_at(me, i, 1.0)
                if (me.time[b] - me.time[i] > 0.9 and all(on_floor(me, k) for k in range(i, b + 1))
                        and np.all(np.abs(me.pos[i:b + 1, 0]) < 3500.0) and np.all(np.abs(me.pos[i:b + 1, 1]) < 4500.0)
                        and clear_window(doc, tracks, me, i, b, ball_pos, touches)):
                    found.append(scenario(doc, path, me, "floor_drive", i, b))
                    floors += 1
                    i = b + 30
                    continue
            i += 1
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dirs", nargs="*", type=Path, default=[DEFAULT_DIR])
    parser.add_argument("--per-replay", type=int, default=2, help="at most this many of each kind per car per replay")
    parser.add_argument("--out", type=Path, default=HERE / "out" / "replay_scenarios.json")
    args = parser.parse_args()
    scenarios = []
    files = sorted(f for d in args.dirs for f in d.glob("*.rlreplay.json"))
    for k, path in enumerate(files):
        try:
            scenarios += mine(path, args.per_replay)
        except (KeyError, ValueError) as error:
            print(f"skip {path.name}: {error}")
        if (k + 1) % 25 == 0:
            print(f"{k + 1}/{len(files)} replays, {len(scenarios)} segments", flush=True)
    args.out.parent.mkdir(exist_ok=True)
    args.out.write_text(json.dumps({"tick_rate": TICK_RATE, "scenarios": scenarios}))
    kinds = {}
    for sc in scenarios:
        kinds[sc["kind"]] = kinds.get(sc["kind"], 0) + 1
    print(f"{len(scenarios)} segments from {len(files)} replays: {kinds} -> {args.out}")


if __name__ == "__main__":
    main()
