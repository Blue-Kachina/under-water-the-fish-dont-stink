"""A small, deterministic replay for tests, needing no real .replay file.

    uv run make_fixture.py [-o OUT.rlreplay.json]

Builds raw data in subtr-actor's shape (see rlreplay/extract.py), quirks included (angular
velocity x100, boost as RL's raw byte, "Empty" frames, a cut-out goal replay, arbitrary state
codes), and runs it through the real converter. The default output is the game's test fixture,
tests/fixtures/replay_fixture.rlreplay.json.

The story, at 30 fps: a 3 s kickoff countdown; Blue's Octane drives from the back kickoff spot
and hits the ball at 5 s; the ball rolls into Orange's goal at about 7.9 s. Orange's Dominus
jumps, double jumps, is demolished at 6 s and respawns 0.7 s later. After the goal, a 4 s gap
(the goal replay, cut out), then a 1 s countdown and 1 s of play.
"""

import argparse
import json
import math
from pathlib import Path

from rlreplay import clean, schema

FPS = 30
START_TIME = 5.0  # replay clocks don't start at 0
COUNTDOWN, LIVE, POST_GOAL = 28, 31, 47  # each replay has its own codes
BALL_RADIUS = 92.75
BLUE_ID = {"Epic": "fixture-blue"}
ORANGE_ID = {"Steam": "fixture-orange"}
DEFAULT_OUT = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "replay_fixture.rlreplay.json"

TOUCH_FRAME = 150
DEMO_FRAME, RESPAWN_FRAME = 180, 201
JUMP_FRAME, DOUBLE_JUMP_FRAME = 105, 125
BALL_SPEED = 1800.0
CAR_SPEED = 2200.0


def yaw_quat(yaw: float) -> dict:
    return {"x": 0.0, "y": 0.0, "z": math.sin(yaw / 2.0), "w": math.cos(yaw / 2.0)}


def body(location, rotation, velocity=None, spin=None) -> dict:
    vec = lambda v: {"x": v[0], "y": v[1], "z": v[2]}
    return {"sleeping": velocity is None, "location": vec(location), "rotation": rotation,
            "linear_velocity": vec(velocity) if velocity is not None else None,
            "angular_velocity": vec([c * 100.0 for c in spin]) if spin is not None else None}


def car_frame(name, team0, rigid, boost_byte, throttle=128, steer=128, **flags) -> dict:
    data = {"rigid_body": rigid, "boost_amount": boost_byte, "is_team_0": team0, "player_name": name,
            "input": {"throttle": throttle, "steer": steer, "dodge_torque": [0.0, 0.0, 0.0]}, "team": None,
            "camera": {"pitch": 128, "yaw": 128}}
    for key in ("boost_active", "jump_active", "double_jump_active", "dodge_active", "powerslide_active"):
        data[key] = flags.get(key, False)
    return {"Data": data}


def build_raw() -> dict:
    meta_frames, ball_frames, blue_frames, orange_frames = [], [], [], []
    time = START_TIME
    goal_frame = None
    phases = ([("countdown", 90), ("live", 150), ("post_goal", 60)]  # first kickoff and goal
              + [("gap", 0), ("countdown", 30), ("live", 30)])  # after the cut-out goal replay
    frame = 0
    seconds = 300
    for phase, length in phases:
        if phase == "gap":
            time += 4.0
            continue
        for k in range(length):
            t_live = (frame - 90) / FPS  # seconds since the first kickoff
            state = {"countdown": COUNTDOWN, "live": LIVE, "post_goal": POST_GOAL}[phase]
            remaining = 0 if phase != "countdown" or k < 6 else 3 - int((k - 6) / (length - 6) * 3)
            meta_frames.append({"time": time, "seconds_remaining": seconds, "replicated_game_state_name": state,
                                "replicated_game_state_time_remaining": remaining})
            second_half = frame >= 300  # the second kickoff: everyone back at the spots

            # Ball: still at the kickoff spot, then rolling toward Orange's goal (+Y) after the touch.
            if second_half or frame < TOUCH_FRAME:
                ball_frames.append({"Data": {"rigid_body": body([0.0, 0.0, BALL_RADIUS], yaw_quat(0.0))}})
            elif goal_frame is None or frame < goal_frame + 3:
                s = (frame - TOUCH_FRAME) / FPS
                y = BALL_SPEED * s
                roll = 6.0 * s
                rot = {"x": math.sin(-roll / 2.0), "y": 0.0, "z": 0.0, "w": math.cos(-roll / 2.0)}
                ball_frames.append({"Data": {"rigid_body": body([0.0, y, BALL_RADIUS], rot, [0.0, BALL_SPEED, 0.0],
                                                                [-6.0, 0.0, 0.0])}})
                if goal_frame is None and y > 5215.5:
                    goal_frame = frame
            else:
                ball_frames.append("Empty")

            # Blue: waits at the back kickoff spot, then drives at the ball and follows it in.
            facing = yaw_quat(math.pi / 2.0)
            if second_half or frame < 90:
                blue_frames.append(car_frame("Fixture Blue", True, body([0.0, -4608.0, 17.0], facing), 85))
            else:
                # Full speed to the ball (its nose meets it at the touch), then on behind it at its speed.
                speed = CAR_SPEED if frame < TOUCH_FRAME else BALL_SPEED
                touch_y = -4608.0 + CAR_SPEED * (TOUCH_FRAME - 90) / FPS
                y = -4608.0 + CAR_SPEED * t_live if frame < TOUCH_FRAME else touch_y + BALL_SPEED * (frame - TOUCH_FRAME) / FPS
                y = min(y, 5000.0)
                moving = y < 5000.0
                blue_frames.append(car_frame("Fixture Blue", True,
                                             body([0.0, y, 17.0], facing, [0.0, speed if moving else 0.0, 0.0],
                                                  [0.0, 0.0, 0.0]),
                                             max(85 - 2 * (frame - 90), 0), throttle=255 if moving else 128,
                                             boost_active=moving and frame < 120))

            # Orange: jumps, double jumps, then is demolished and respawns at a demo spawn.
            facing = yaw_quat(-math.pi / 2.0)
            if frame >= 90 and not second_half and DEMO_FRAME <= frame < RESPAWN_FRAME:
                orange_frames.append("Empty")
            elif frame >= RESPAWN_FRAME and not second_half:
                orange_frames.append(car_frame("Fixture Orange", False, body([2304.0, 4608.0, 36.0], facing), 85))
            elif frame >= JUMP_FRAME and not second_half:
                s = (frame - JUMP_FRAME) / FPS
                z = max(17.0 + 600.0 * s - 325.0 * s * s, 17.0)
                if frame >= DOUBLE_JUMP_FRAME:
                    s2 = (frame - DOUBLE_JUMP_FRAME) / FPS
                    z = max(17.0 + 600.0 * (DOUBLE_JUMP_FRAME - JUMP_FRAME) / FPS
                            - 325.0 * ((DOUBLE_JUMP_FRAME - JUMP_FRAME) / FPS) ** 2 + 300.0 * s2 - 325.0 * s2 * s2, 17.0)
                orange_frames.append(car_frame("Fixture Orange", False,
                                               body([0.0, 4608.0, z], facing, [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]), 85,
                                               jump_active=JUMP_FRAME <= frame < JUMP_FRAME + 6,
                                               double_jump_active=DOUBLE_JUMP_FRAME <= frame < DOUBLE_JUMP_FRAME + 3))
            else:
                orange_frames.append(car_frame("Fixture Orange", False, body([0.0, 4608.0, 17.0], facing), 85))

            time += 1.0 / FPS
            frame += 1
            if frame % FPS == 0 and phase == "live":
                seconds -= 1

    header = [["TeamSize", 1], ["Id", "FIXTURE"], ["MapName", "stadium_p"], ["MatchType", "Offline"],
              ["RecordFPS", float(FPS)], ["BuildVersion", "fixture"], ["Date", "2026-10-11 00-00-00"]]
    return {
        "frame_data": {
            "metadata_frames": meta_frames,
            "ball_data": {"frames": ball_frames},
            "players": [[BLUE_ID, {"frames": blue_frames}], [ORANGE_ID, {"frames": orange_frames}]],
        },
        "meta": {
            "all_headers": header,
            "team_zero": [{"remote_id": BLUE_ID, "name": "Fixture Blue", "car_body_id": 23,
                           "car_hitbox_family": "Octane"}],
            "team_one": [{"remote_id": ORANGE_ID, "name": "Fixture Orange", "car_body_id": 403,
                          "car_hitbox_family": "Dominus"}],
        },
        "goal_events": [{"frame": goal_frame, "player": BLUE_ID, "scoring_team_is_team_0": True,
                         "team_zero_score": 1, "team_one_score": 0}],
        "demolish_infos": [{"frame": DEMO_FRAME, "attacker": BLUE_ID, "victim": ORANGE_ID}],
        "touch_events": [{"frame": TOUCH_FRAME, "player": None, "team_is_team_0": True}],
        "boost_pads": [{"pad_id": "Pad_0", "position": {"x": 3584.0, "y": 0.0, "z": 73.0}, "size": "Big"},
                       {"pad_id": "Pad_1", "position": {"x": 0.0, "y": -4240.0, "z": 70.0}, "size": "Small"}],
        "boost_pad_events": [{"frame": 100, "pad_id": "Pad_1", "player": BLUE_ID, "kind": {"PickedUp": {"sequence": 1}}}],
    }


def build_document(anonymize: bool = False) -> dict:
    return clean.build_document(build_raw(), "fixture", anonymize)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    doc = build_document()
    errors = schema.validate(doc)
    if errors:
        raise SystemExit("fixture is invalid:\n  " + "\n  ".join(errors))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(doc, separators=(",", ":")), encoding="utf-8")
    print(f"{args.output}: {doc['match']['num_frames']} frames, {doc['match']['duration']:.2f} s")


if __name__ == "__main__":
    main()
