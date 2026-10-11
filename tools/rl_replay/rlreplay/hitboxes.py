"""Rocket League's six hitbox presets (RocketSim's values, in uu).

`offset` is the hitbox centre relative to the car's centre of mass, in the car's
own frame: (forward, right, up). Replays record the centre of mass.
"""

HITBOXES = {
    "octane": {"length": 120.507, "width": 86.6994, "height": 38.6591, "offset": [13.8757, 0.0, 20.755]},
    "dominus": {"length": 130.427, "width": 85.7799, "height": 33.8, "offset": [9.0, 0.0, 15.75]},
    "plank": {"length": 131.32, "width": 87.1704, "height": 31.8944, "offset": [9.00857, 0.0, 12.0942]},
    "breakout": {"length": 133.992, "width": 83.0197, "height": 32.8, "offset": [12.5, 0.0, 11.75]},
    "hybrid": {"length": 129.519, "width": 84.6879, "height": 36.6591, "offset": [13.8757, 0.0, 20.755]},
    "merc": {"length": 123.22, "width": 79.2103, "height": 44.1591, "offset": [11.3757, 0.0, 21.505]},
}


def family_for(name: str | None) -> tuple[str, bool]:
    """Our family key for subtr-actor's `car_hitbox_family` name, and whether it was known.
    Unknown or missing families fall back to Octane, the most common."""
    key = (name or "").strip().lower()
    if key in HITBOXES:
        return key, True
    return "octane", False
