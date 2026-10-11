"""Checks a v1 document's shape: the same rules the game's loader (ReplayData) relies on."""

from .clean import FORMAT, VERSION

EVENT_TYPES = {"kickoff", "goal", "demo", "touch", "boost_pickup"}
SEGMENT_TYPES = {"live", "countdown", "post_goal"}
CAR_COLUMNS = {"present": 1, "pos": 3, "vel": 3, "rot": 4, "ang_vel": 3, "teleport": 1,
               "boost": 1, "throttle": 1, "steer": 1, "flags": 1, "dodge_torque": 3, "time_offset": 1}
BALL_COLUMNS = {"present": 1, "pos": 3, "vel": 3, "rot": 4, "ang_vel": 3, "teleport": 1, "time_offset": 1}


def validate(doc: dict) -> list[str]:
    """Every problem found, or an empty list."""
    errors = []
    if doc.get("format") != FORMAT:
        errors.append(f"format is {doc.get('format')!r}, expected {FORMAT!r}")
    if doc.get("version") != VERSION:
        errors.append(f"version is {doc.get('version')!r}, expected {VERSION}")
    for key in ("units", "source", "match", "players", "frames", "ball", "cars", "events", "segments"):
        if key not in doc:
            errors.append(f"missing {key!r}")
    if errors:
        return errors

    times = doc["frames"].get("time", [])
    n = len(times)
    if n < 2:
        errors.append("fewer than 2 frames")
    if doc["match"].get("num_frames") != n:
        errors.append(f"match.num_frames {doc['match'].get('num_frames')} != {n} frames")
    if any(b < a for a, b in zip(times, times[1:])):
        errors.append("frame times go backwards")
    for key in ("game_state", "seconds_remaining", "kickoff_countdown"):
        if len(doc["frames"].get(key, [])) != n:
            errors.append(f"frames.{key} has {len(doc['frames'].get(key, []))} entries, expected {n}")

    errors += _columns("ball", doc["ball"], BALL_COLUMNS, n)
    players = doc["players"]
    for i, player in enumerate(players):
        if player.get("index") != i:
            errors.append(f"players[{i}].index is {player.get('index')}")
        if player.get("team") not in (0, 1):
            errors.append(f"players[{i}].team is {player.get('team')!r}")
        hitbox = player.get("hitbox", {})
        if not all(k in hitbox for k in ("length", "width", "height", "offset")):
            errors.append(f"players[{i}].hitbox is incomplete")
    if len(doc["cars"]) != len(players):
        errors.append(f"{len(doc['cars'])} car tracks for {len(players)} players")
    for i, car in enumerate(doc["cars"]):
        if car.get("player") != i:
            errors.append(f"cars[{i}].player is {car.get('player')}")
        errors += _columns(f"cars[{i}]", car, CAR_COLUMNS, n)

    for i, event in enumerate(doc["events"]):
        if event.get("type") not in EVENT_TYPES:
            errors.append(f"events[{i}] has unknown type {event.get('type')!r}")
        if not 0 <= event.get("frame", -1) < n:
            errors.append(f"events[{i}].frame {event.get('frame')} is out of range")
    for i, segment in enumerate(doc["segments"]):
        if segment.get("type") not in SEGMENT_TYPES:
            errors.append(f"segments[{i}] has unknown type {segment.get('type')!r}")
    return errors


def _columns(name: str, track: dict, columns: dict, n: int) -> list[str]:
    errors = []
    for key, width in columns.items():
        values = track.get(key)
        if values is None:
            errors.append(f"{name}.{key} is missing")
        elif len(values) != n * width:
            errors.append(f"{name}.{key} has {len(values)} values, expected {n * width}")
    return errors
