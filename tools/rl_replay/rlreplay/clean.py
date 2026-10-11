"""Turns subtr-actor's frame data (see extract.read_replay) into the v1 playback document.

Everything stays in Rocket League's units and axes (uu, +X left, +Y toward orange, +Z up);
the game converts once, on load. What's done here so the game's loader stays simple:

- Times start at 0. Gaps longer than GAP_SECONDS (where goal replays were cut out of the
  recording) are closed up to one frame, and marked as teleports.
- Game state per frame, inferred from the countdown timer, because the replicated state is
  an index into each replay's own name table (28 in one replay, 82 in another).
- Angular velocities rescaled to rad/s: replays store them x100 (sometimes x10 or x1), found
  from the ball, whose spin is capped at 6 rad/s.
- Teleport flags wherever playback mustn't interpolate: a car or ball appearing, a closed
  gap, a kickoff reset, or a jump faster than anything can move.
- Who touched the ball: subtr-actor reports only the team, so the toucher is that team's
  car nearest the ball.
- Smooth motion (see _refine): the parser's filler for frames with no update (a car coasted on
  at its last velocity) is rebuilt through the genuine samples, and each sample gets the time
  it really happened (time_offset), since states come from physics ticks a little before or
  after their frame's time. Played back as recorded, both make everything jerk.
"""

import math

from .hitboxes import HITBOXES, family_for

FORMAT = "uwfds.rlreplay"
VERSION = 1
CONVERTER = "tools/rl_replay 1.2.0"

GAP_SECONDS = 0.5
TICK = 1.0 / 120.0  # RL's physics step
MAX_TIME_OFFSET = 3 * TICK  # a sample is never further than this from its frame's time
# More than driving, boosting or falling can do (uu/s^2; RL's throttle gives 1600, boost about
# 1000, gravity 650): a faster change of velocity is a hit, bounce, landing or jump.
MAX_STEADY_ACCEL = 3500.0
MAX_FILL_FRAMES = 8  # rebuild filler across at most this many frames between genuine samples
CAR_TELEPORT_SPEED = 4600.0  # uu/s; cars top out at 2300
BALL_TELEPORT_SPEED = 9000.0  # the ball tops out at 6000
SUPERSONIC_SPEED = 2200.0
BALL_MAX_SPIN = 6.0  # rad/s
FLAG_BOOST, FLAG_JUMP, FLAG_DOUBLE_JUMP, FLAG_DODGE = 1, 2, 4, 8
FLAG_POWERSLIDE, FLAG_SUPERSONIC, FLAG_DEMOLISHED = 16, 32, 64
GAME_LIVE, GAME_COUNTDOWN, GAME_POST_GOAL = 0, 1, 2
STATE_NAMES = {GAME_LIVE: "live", GAME_COUNTDOWN: "countdown", GAME_POST_GOAL: "post_goal"}


class ConversionError(Exception):
    pass


def build_document(raw: dict, parser: str, anonymize: bool = False, boost_scale: float = 100.0 / 255.0) -> dict:
    """`boost_scale` turns the parser's boost amounts into 0-100. subtr-actor gives RL's raw
    byte (0-255, 85 at kickoff); the maximum alone can't tell, as a short replay may never
    see a full tank."""
    frame_data = raw["frame_data"]
    meta_frames = frame_data["metadata_frames"]
    n = len(meta_frames)
    if n < 2:
        raise ConversionError("the replay has fewer than 2 frames")
    headers = dict((pair[0], pair[1]) for pair in raw["meta"].get("all_headers", []))

    times, gap_after = _playback_times(meta_frames)
    states, state_codes = _game_states(meta_frames)
    spin_scale = _spin_scale(frame_data["ball_data"]["frames"])
    players, tracks = _players(raw, anonymize)

    # A kickoff reset teleports everything: the first frame of each countdown.
    resets = {i for i in range(1, n) if states[i] == GAME_COUNTDOWN and states[i - 1] != GAME_COUNTDOWN}
    jumps = resets | gap_after

    ball = _track([_rigid_body(f) for f in frame_data["ball_data"]["frames"]], times, spin_scale,
                  BALL_TELEPORT_SPEED, jumps)
    cars = []
    for index, frames in enumerate(tracks):
        car = _track([_rigid_body(f) for f in frames], times, spin_scale, CAR_TELEPORT_SPEED, jumps)
        car["player"] = index
        cars.append(car)
    for car, frames in zip(cars, tracks):
        car.update(_car_controls(frames, car, boost_scale))
    for track in [ball] + cars:
        track["time_offset"] = _refine(track, times)

    events = _events(raw, players, times, states, ball, cars)
    for event in events:
        if event["type"] == "demo" and event.get("victim") is not None:
            cars[event["victim"]]["flags"][event["frame"]] |= FLAG_DEMOLISHED

    score = [sum(1 for e in events if e["type"] == "goal" and e["team"] == t) for t in (0, 1)]
    return {
        "format": FORMAT,
        "version": VERSION,
        "units": {"length": "uu", "time": "s", "angle": "rad", "axes": "rl_lh_zup", "quat": "xyzw"},
        "source": {
            "replay_id": headers.get("Id", ""),
            "map": headers.get("MapName", ""),
            "match_type": headers.get("MatchType", ""),
            "team_size": headers.get("TeamSize", 0),
            "build_version": headers.get("BuildVersion", ""),
            "date": headers.get("Date", ""),
            "converter": CONVERTER,
            "parser": parser,
            "ang_vel_scale_detected": spin_scale,
            "boost_scale": boost_scale,
            "game_state_codes": state_codes,
        },
        "match": {
            "record_fps": headers.get("RecordFPS", 30.0),
            "num_frames": n,
            "duration": times[-1],
            "score": score,
            "source_start_time": meta_frames[0]["time"],
            "gaps_closed": len(gap_after),
        },
        "players": players,
        "frames": {
            "time": [_r(t, 4) for t in times],
            "game_state": states,
            "seconds_remaining": [int(m.get("seconds_remaining") or 0) for m in meta_frames],
            "kickoff_countdown": [int(m.get("replicated_game_state_time_remaining") or 0) for m in meta_frames],
        },
        "ball": ball,
        "cars": cars,
        "events": events,
        "segments": _segments(states, times),
        "boost_pads": [{"id": p["pad_id"], "pos": _vec(p["position"], 1), "big": p.get("size") == "Big"}
                       for p in raw.get("boost_pads", [])],
    }


def _playback_times(meta_frames: list) -> tuple[list[float], set[int]]:
    """Times from 0, with gaps closed up. Returns the times and the frames just after a gap."""
    times = [0.0]
    gap_after = set()
    nominal = 1.0 / 30.0
    for i in range(1, len(meta_frames)):
        dt = meta_frames[i]["time"] - meta_frames[i - 1]["time"]
        if dt > GAP_SECONDS:
            gap_after.add(i)
            dt = nominal
        times.append(times[-1] + max(dt, 0.0))
    return times, gap_after


def _game_states(meta_frames: list) -> tuple[list[int], dict]:
    """Live, countdown or post-goal for every frame. The countdown's code is the state seen
    while the 3-2-1 timer runs; live is whatever follows a countdown; anything else is the
    pause after a goal (or the end of the match)."""
    codes = [m.get("replicated_game_state_name") for m in meta_frames]
    timed = [codes[i] for i, m in enumerate(meta_frames) if (m.get("replicated_game_state_time_remaining") or 0) > 0]
    if not timed:
        # No kickoff countdown recorded at all: treat everything as live play.
        return [GAME_LIVE] * len(codes), {"countdown": None, "live": None}
    countdown = max(set(timed), key=timed.count)
    live = None
    for i in range(1, len(codes)):
        if codes[i - 1] == countdown and codes[i] != countdown:
            live = codes[i]
            break
    states = []
    for code in codes:
        if code == countdown:
            states.append(GAME_COUNTDOWN)
        elif code == live:
            states.append(GAME_LIVE)
        else:
            states.append(GAME_POST_GOAL)
    return states, {"countdown": countdown, "live": live}


def _spin_scale(ball_frames: list) -> float:
    """The factor that turns the replay's angular velocities into rad/s. The ball's spin is
    capped at 6 rad/s and reaches it often, so its near-maximum identifies the scale."""
    spins = []
    for frame in ball_frames:
        body = _rigid_body(frame)
        if body and body.get("angular_velocity"):
            w = body["angular_velocity"]
            spins.append(math.sqrt(w["x"] ** 2 + w["y"] ** 2 + w["z"] ** 2))
    if not spins:
        raise ConversionError("the ball never has an angular velocity, so its units can't be checked")
    spins.sort()
    top = spins[min(len(spins) - 1, int(len(spins) * 0.999))]
    for scale in (1.0, 0.1, 0.01):
        if 3.0 <= top * scale <= BALL_MAX_SPIN * 1.2:
            return scale
    raise ConversionError(f"the ball's top spin is {top:.3f} in replay units, which matches no known scale "
                          "(expected about 6, 60 or 600)")


def _players(raw: dict, anonymize: bool) -> tuple[list[dict], list[list]]:
    """One entry per player track, with team, car and hitbox, plus each track's frames."""
    meta = raw["meta"]
    roster = [(0, p) for p in meta.get("team_zero", [])] + [(1, p) for p in meta.get("team_one", [])]
    players, tracks = [], []
    counts = [0, 0]
    for index, (player_id, data) in enumerate(raw["frame_data"]["players"]):
        frames = data["frames"]
        first = next((f["Data"] for f in frames if isinstance(f, dict)), {})
        entry = next(((t, p) for t, p in roster if p.get("remote_id") == player_id), None)
        if entry is None:
            entry = next(((t, p) for t, p in roster if p.get("name") == first.get("player_name")), None)
        known = entry[1] if entry else {}
        # The end-of-match roster knows each player's team. Otherwise go by the frames,
        # by majority: a car's first frames can come before its team is replicated.
        if entry:
            team = entry[0]
        else:
            votes = [f["Data"].get("is_team_0") for f in frames if isinstance(f, dict) and "Data" in f]
            team = 0 if votes.count(True) >= votes.count(False) else 1
        family, recognised = family_for(known.get("car_hitbox_family"))
        counts[team] += 1
        name = known.get("name") or first.get("player_name") or f"Player {index + 1}"
        if anonymize:
            name = f"{['Blue', 'Orange'][team]} {counts[team]}"
        players.append({
            "index": index,
            "name": name,
            "team": team,
            "body_id": known.get("car_body_id", 0),
            "hitbox_family": family,
            "hitbox_family_known": recognised,
            "hitbox": HITBOXES[family],
        })
        tracks.append(frames)
    return players, tracks


def _rigid_body(frame) -> dict | None:
    if not isinstance(frame, dict) or "Data" not in frame:
        return None
    return frame["Data"].get("rigid_body")


def _track(bodies: list, times: list, spin_scale: float, teleport_speed: float, jumps: set) -> dict:
    """Columnar rigid-body arrays. Absent frames repeat the last known state (or zeros) with
    present = 0; sleeping bodies, which send no velocities, get zero velocities."""
    present, pos, vel, rot, ang_vel, teleport, fresh = [], [], [], [], [], [], []
    last = None
    last_present = -1
    last_body = None
    for i, body in enumerate(bodies):
        if body is None or body.get("location") is None:
            present.append(0)
            teleport.append(0)
            fresh.append(False)
            last_body = None
            p = last["pos"] if last else [0.0, 0.0, 0.0]
            q = last["rot"] if last else [0.0, 0.0, 0.0, 1.0]
            pos.extend(p)
            rot.extend(q)
            vel.extend([0.0, 0.0, 0.0])
            ang_vel.extend([0.0, 0.0, 0.0])
            continue
        p = _vec(body["location"], 2)
        q = _quat(body["rotation"])
        v = _vec(body["linear_velocity"], 2) if body.get("linear_velocity") else [0.0, 0.0, 0.0]
        w = ([_r(c * spin_scale, 4) for c in _vec(body["angular_velocity"], 6)]
             if body.get("angular_velocity") else [0.0, 0.0, 0.0])
        jump = last_present < 0 or last_present != i - 1 or i in jumps
        if not jump:
            dt = max(times[i] - times[last_present], 1e-6)
            jump = math.dist(p, last["pos"]) / dt > teleport_speed
        present.append(1)
        teleport.append(1 if jump else 0)
        # A genuine state, or the parser's filler for a frame with no update for this body
        # (the last state coasted on at its velocity, or held): the same velocity and spin
        # to the last bit. A body at rest is genuinely still.
        moving = body.get("linear_velocity") is not None
        fresh.append(jump or not moving or last_body is None
                     or body.get("linear_velocity") != last_body.get("linear_velocity")
                     or body.get("angular_velocity") != last_body.get("angular_velocity"))
        pos.extend(p)
        vel.extend(v)
        rot.extend(q)
        ang_vel.extend(w)
        last = {"pos": p, "rot": q}
        last_present = i
        last_body = body
    return {"present": present, "pos": pos, "vel": vel, "rot": rot, "ang_vel": ang_vel, "teleport": teleport,
            "_fresh": fresh}


def _refine(track: dict, times: list) -> list[float]:
    """Makes the track smooth to play back: returns each sample's time offset from its frame's
    time (s), and rebuilds the parser's filler samples. Removes the track's "_fresh" marks.

    Two things in the recording make playback jerk:
    - Filler. Frames with no network update for a body (half of all car frames in some
      replays) get the last state coasted on at its velocity. The real state then arrives
      somewhere else, since the car was turning or speeding up. Fillers are rebuilt on the
      same curve playback uses, through the genuine samples either side.
    - Timing. A genuine state comes from whichever physics tick last replicated it, up to a few
      ticks (1/120 s) either side of its frame's time, differently for each body. Between two
      genuine samples, the time that really passed is about dp . v / |v|^2 (v the mean of the
      two velocities; exact under constant acceleration). Fitting every sample's offset to
      those in the least-squares sense, plus a gentle pull of each toward 0 so they can't
      drift, is a tridiagonal system. Steps that say nothing reliable are left out: slow, a
      sudden change of velocity (a hit, bounce, landing or jump), or implying more than a few
      ticks of error."""
    n = len(times)
    present, teleport, pos, vel = track["present"], track["teleport"], track["pos"], track["vel"]
    rot, ang_vel = track["rot"], track["ang_vel"]
    fresh = track.pop("_fresh")
    genuine = [i for i in range(n) if fresh[i]]

    def joined(a: int, b: int) -> bool:
        """Whether genuine samples a < b are one stretch of motion: present throughout, no
        teleport, not too far apart."""
        return b - a <= MAX_FILL_FRAMES and all(present[i] and not teleport[i] for i in range(a + 1, b + 1))

    # Timing, over the genuine samples only.
    m = len(genuine)
    weight = [0.0] * m  # for the step from genuine[k-1] to genuine[k]
    target = [0.0] * m
    for k in range(1, m):
        a, b = genuine[k - 1], genuine[k]
        if not joined(a, b):
            continue
        v = [(vel[3 * a + c] + vel[3 * b + c]) / 2.0 for c in range(3)]
        speed2 = v[0] ** 2 + v[1] ** 2 + v[2] ** 2
        if speed2 < 300.0 ** 2:
            continue
        gap = times[b] - times[a]
        if math.dist(vel[3 * a:3 * a + 3], vel[3 * b:3 * b + 3]) > MAX_STEADY_ACCEL * gap:
            continue
        dp = [pos[3 * b + c] - pos[3 * a + c] for c in range(3)]
        error = (dp[0] * v[0] + dp[1] * v[1] + dp[2] * v[2]) / speed2 - gap
        if abs(error) > 4.0 * TICK:
            continue
        weight[k] = min(1.0, speed2 / 800.0 ** 2)
        target[k] = error
    solved = _solve_offsets(weight, target, pull=0.05)
    offset = [0.0] * n
    for k, i in enumerate(genuine):
        offset[i] = max(-MAX_TIME_OFFSET, min(MAX_TIME_OFFSET, solved[k]))

    # Fillers between two genuine samples: spread evenly in time between them, on the curve.
    for k in range(1, m):
        a, b = genuine[k - 1], genuine[k]
        if b - a < 2 or not joined(a, b):
            continue
        ta, tb = times[a] + offset[a], times[b] + offset[b]
        dt = tb - ta
        if dt <= 0.0:
            continue
        p0, p1 = pos[3 * a:3 * a + 3], pos[3 * b:3 * b + 3]
        v0, v1 = vel[3 * a:3 * a + 3], vel[3 * b:3 * b + 3]
        w0, w1 = ang_vel[3 * a:3 * a + 3], ang_vel[3 * b:3 * b + 3]
        q0, q1 = rot[4 * a:4 * a + 4], rot[4 * b:4 * b + 4]
        for i in range(a + 1, b):
            f = (i - a) / (b - a)
            offset[i] = ta + f * dt - times[i]
            pos[3 * i:3 * i + 3] = [_r(x, 2) for x in _hermite(p0, v0, p1, v1, dt, f)]
            vel[3 * i:3 * i + 3] = [_r(x0 + (x1 - x0) * f, 2) for x0, x1 in zip(v0, v1)]
            ang_vel[3 * i:3 * i + 3] = [_r(x0 + (x1 - x0) * f, 4) for x0, x1 in zip(w0, w1)]
            rot[4 * i:4 * i + 4] = [_r(x, 5) for x in _slerp(q0, q1, f)]

    # Keep each body's samples in order.
    last = -math.inf
    for i in range(n):
        offset[i] = max(offset[i], last + 1e-4 - times[i])
        last = times[i] + offset[i]
    return [_r(o, 5) for o in offset]


def _solve_offsets(weight: list, target: list, pull: float) -> list[float]:
    """Minimises sum w_k (o_k - o_{k-1} - target_k)^2 + pull * sum o_k^2 (tridiagonal normal
    equations, Thomas algorithm)."""
    m = len(weight)
    if m == 0:
        return []
    lower, diag, upper, rhs = [0.0] * m, [0.0] * m, [0.0] * m, [0.0] * m
    for j in range(m):
        w_in = weight[j]
        w_out = weight[j + 1] if j + 1 < m else 0.0
        diag[j] = pull + w_in + w_out
        lower[j] = -w_in
        upper[j] = -w_out
        rhs[j] = w_in * target[j] - (w_out * target[j + 1] if j + 1 < m else 0.0)
    for j in range(1, m):
        f = lower[j] / diag[j - 1]
        diag[j] -= f * upper[j - 1]
        rhs[j] -= f * rhs[j - 1]
    out = [0.0] * m
    out[m - 1] = rhs[m - 1] / diag[m - 1]
    for j in range(m - 2, -1, -1):
        out[j] = (rhs[j] - upper[j] * out[j + 1]) / diag[j]
    return out


def _hermite(p0: list, v0: list, p1: list, v1: list, dt: float, f: float) -> list[float]:
    """The cubic through p0 and p1 with velocities v0 and v1, dt apart, at fraction f (the same
    curve the game's playback draws)."""
    b = [p0[c] + v0[c] * dt / 3.0 for c in range(3)]
    e = [p1[c] - v1[c] * dt / 3.0 for c in range(3)]
    u = 1.0 - f
    return [u ** 3 * p0[c] + 3 * u * u * f * b[c] + 3 * u * f * f * e[c] + f ** 3 * p1[c] for c in range(3)]


def _slerp(q0: list, q1: list, f: float) -> list[float]:
    d = sum(a * b for a, b in zip(q0, q1))
    if d < 0.0:
        q1, d = [-x for x in q1], -d
    if d > 0.9995:
        q = [a + (b - a) * f for a, b in zip(q0, q1)]
    else:
        theta = math.acos(d)
        s0, s1 = math.sin((1 - f) * theta) / math.sin(theta), math.sin(f * theta) / math.sin(theta)
        q = [s0 * a + s1 * b for a, b in zip(q0, q1)]
    length = math.sqrt(sum(x * x for x in q)) or 1.0
    return [x / length for x in q]


def _car_controls(frames: list, track: dict, boost_scale: float) -> dict:
    """Boost (0-100), throttle, steer, the action flags and the last dodge direction, per frame."""
    boost, throttle, steer, flags, dodge = [], [], [], [], []
    last_boost = 33.3
    for i, frame in enumerate(frames):
        data = frame["Data"] if isinstance(frame, dict) and "Data" in frame else None
        if data is None:
            boost.append(_r(last_boost, 1))
            throttle.append(0.0)
            steer.append(0.0)
            flags.append(0)
            dodge.extend([0.0, 0.0, 0.0])
            continue
        if data.get("boost_amount") is not None:
            last_boost = data["boost_amount"] * boost_scale
        controls = data.get("input") or {}
        bits = 0
        for key, bit in (("boost_active", FLAG_BOOST), ("jump_active", FLAG_JUMP),
                         ("double_jump_active", FLAG_DOUBLE_JUMP), ("dodge_active", FLAG_DODGE),
                         ("powerslide_active", FLAG_POWERSLIDE)):
            if data.get(key):
                bits |= bit
        v = track["vel"][3 * i:3 * i + 3]
        if math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) >= SUPERSONIC_SPEED:
            bits |= FLAG_SUPERSONIC
        boost.append(_r(last_boost, 1))
        throttle.append(_byte_axis(controls.get("throttle")))
        steer.append(_byte_axis(controls.get("steer")))
        flags.append(bits)
        torque = controls.get("dodge_torque") or [0.0, 0.0, 0.0]
        dodge.extend(_r(c, 3) for c in torque)
    return {"boost": boost, "throttle": throttle, "steer": steer, "flags": flags, "dodge_torque": dodge}


def _byte_axis(value) -> float:
    """RL's replicated throttle and steer bytes: 0 = -1, 128 = 0 (also when never sent), 255 = +1."""
    if value is None:
        return 0.0
    return _r(max(-1.0, min(1.0, (value - 128) / 127.0)), 3)


def _events(raw: dict, players: list, times: list, states: list, ball: dict, cars: list) -> list[dict]:
    n = len(times)
    by_id = {}
    for (player_id, _), player in zip(raw["frame_data"]["players"], players):
        by_id[_key(player_id)] = player["index"]

    def frame_of(event) -> int:
        return max(0, min(n - 1, int(event.get("frame", 0))))

    events = []
    for i in range(1, n):
        if states[i] == GAME_LIVE and states[i - 1] == GAME_COUNTDOWN:
            events.append({"type": "kickoff", "frame": i})
    for goal in raw.get("goal_events", []):
        events.append({"type": "goal", "frame": frame_of(goal), "team": 0 if goal.get("scoring_team_is_team_0") else 1,
                       "player": by_id.get(_key(goal.get("player"))),
                       "score": [goal.get("team_zero_score", 0), goal.get("team_one_score", 0)]})
    for demo in raw.get("demolish_infos", []):
        events.append({"type": "demo", "frame": frame_of(demo), "attacker": by_id.get(_key(demo.get("attacker"))),
                       "victim": by_id.get(_key(demo.get("victim")))})
    for touch in raw.get("touch_events", []):
        i = frame_of(touch)
        team = 0 if touch.get("team_is_team_0") else 1
        player = by_id.get(_key(touch.get("player"))) if touch.get("player") else None
        if player is None:
            player = _nearest_car(i, team, players, ball, cars)
        if player is None and states[i] != GAME_LIVE:
            continue  # phantom touches recorded during goal resets, with every car gone
        events.append({"type": "touch", "frame": i, "team": team, "player": player})
    for pickup in raw.get("boost_pad_events", []):
        if "PickedUp" not in (pickup.get("kind") or {}):
            continue
        events.append({"type": "boost_pickup", "frame": frame_of(pickup), "pad": pickup.get("pad_id"),
                       "player": by_id.get(_key(pickup.get("player")))})
    for event in events:
        event["time"] = _r(times[event["frame"]], 4)
    events.sort(key=lambda e: (e["frame"], e["type"]))
    return events


def _nearest_car(i: int, team: int, players: list, ball: dict, cars: list) -> int | None:
    # The touch can land on a frame the ball is missing from (it's just gone into a goal):
    # look a couple of frames back.
    for i in range(i, max(i - 3, -1), -1):
        if ball["present"][i]:
            break
    else:
        return None
    b = ball["pos"][3 * i:3 * i + 3]
    best, best_distance = None, math.inf
    for car, player in zip(cars, players):
        if player["team"] != team or not car["present"][i]:
            continue
        distance = math.dist(car["pos"][3 * i:3 * i + 3], b)
        if distance < best_distance:
            best, best_distance = player["index"], distance
    return best


def _segments(states: list, times: list) -> list[dict]:
    segments = []
    start = 0
    for i in range(1, len(states) + 1):
        if i == len(states) or states[i] != states[start]:
            segments.append({"type": STATE_NAMES[states[start]], "start": _r(times[start], 4),
                             "end": _r(times[min(i, len(states) - 1)], 4)})
            start = i
    return segments


def _key(player_id) -> str:
    """A hashable key for subtr-actor's player ids ({"Epic": "..."} and the like)."""
    if player_id is None:
        return ""
    if isinstance(player_id, dict):
        return repr(sorted((k, repr(v)) for k, v in player_id.items()))
    return repr(player_id)


def _vec(v, digits: int) -> list[float]:
    if isinstance(v, (list, tuple)):
        return [_r(c, digits) for c in v]
    return [_r(v["x"], digits), _r(v["y"], digits), _r(v["z"], digits)]


def _quat(q) -> list[float]:
    x, y, z, w = q["x"], q["y"], q["z"], q["w"]
    length = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    return [_r(x / length, 5), _r(y / length, 5), _r(z / length, 5), _r(w / length, 5)]


def _r(value: float, digits: int) -> float:
    rounded = round(float(value), digits)
    return 0.0 if rounded == 0 else rounded  # no "-0.0" in the file
