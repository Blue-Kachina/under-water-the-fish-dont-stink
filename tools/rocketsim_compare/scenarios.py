"""Scripted scenarios run identically in RocketSim and in the game.

Everything here is in Rocket League units and axes: uu (1 uu = 1 cm), uu/s,
rad/s; +X left (seen from blue), +Y toward orange, +Z up. Ticks are 120 Hz.

A scenario's `controls` is a list of (from_tick, {control: value}) segments;
each segment holds until the next one, and unlisted controls are 0 / False.
Stick values are kept to -1, 0 or 1 on one axis at a time: the game reads the
stick through Input.get_vector, which normalises diagonals, while RL's pitch and
yaw are independent.

`arena` is "void" (RocketSim's THE_VOID / the game's Ocean: no floor or walls)
or "soccar" (needs RocketSim's collision meshes, so it's skipped without them).
"""

TICK_RATE = 120
HIGH = 1000.0  # start height for airborne scenarios (uu)


def s(ticks: int) -> int:
    """Seconds -> ticks."""
    return round(ticks * TICK_RATE)


def car(pos=(0.0, 0.0, HIGH), vel=(0.0, 0.0, 0.0), ang_vel=(0.0, 0.0, 0.0), boost=100.0, can_flip=False):
    """A level car at `pos` (its centre of mass) facing +Y.
    can_flip: already jumped and in the air, so the next jump press is a double jump or dodge."""
    return {"pos": list(pos), "vel": list(vel), "ang_vel": list(ang_vel), "boost": boost, "can_flip": can_flip}


def scenario(name, duration, controls, arena="void", car_state=None, ball=None, notes=""):
    return {"name": name, "arena": arena, "ticks": s(duration), "notes": notes,
            "car": car_state if car_state is not None else car(),
            "ball": ball, "controls": [[tick, values] for tick, values in controls]}


JUMP_TAP = 3  # ticks the jump button is held for a dodge or double-jump press


def flip(name, stick, hold=None, after=None, vel=(0.0, 0.0, 0.0), duration=1.6, notes=""):
    """A dodge from can_flip: `stick` held through the jump press, then `after`
    (default: released). `hold` is held throughout (e.g. boost)."""
    hold = hold or {}
    controls = [(0, dict(hold)), (s(0.05), dict(hold, jump=True, **stick)), (s(0.05) + JUMP_TAP, dict(hold, **stick)),
                (s(0.15), dict(hold, **(after or {})))]
    return scenario(name, duration, controls, car_state=car(vel=vel, can_flip=True), notes=notes)


SCENARIOS = [
    # --- Free flight -------------------------------------------------------
    scenario("fall", 1.0, [(0, {})], notes="gravity only"),
    scenario("air_throttle", 2.0, [(0, {"throttle": 1.0})], notes="air throttle 66.7 uu/s^2"),
    scenario("air_reverse", 2.0, [(0, {"throttle": -1.0})]),
    scenario("air_boost", 2.0, [(0, {"boost": True})], notes="boost from rest"),
    scenario("air_boost_cap", 3.5, [(0, {"boost": True})], notes="boost into the 2300 uu/s cap"),
    scenario("air_boost_moving", 1.5, [(0, {"boost": True})],
             car_state=car(vel=(0.0, 1500.0, 0.0)), notes="boost from 1500 uu/s"),

    # --- Air control --------------------------------------------------------
    scenario("air_roll", 2.5, [(0, {"roll": 1.0}), (s(1.5), {})], notes="roll 1.5 s, then release"),
    scenario("air_pitch_up", 2.0, [(0, {"pitch": 1.0}), (s(1.0), {})]),
    scenario("air_pitch_down", 2.0, [(0, {"pitch": -1.0}), (s(1.0), {})]),
    scenario("air_yaw", 2.0, [(0, {"yaw": 1.0}), (s(1.0), {})]),
    scenario("air_roll_long", 3.0, [(0, {"roll": -1.0})], notes="roll into the 5.5 rad/s cap"),
    scenario("air_pitch_then_roll", 2.0, [(0, {"pitch": 1.0}), (s(0.5), {"roll": 1.0}), (s(1.2), {})]),
    scenario("spin_damping", 1.5, [(0, {})], car_state=car(ang_vel=(2.0, -1.5, 3.0)),
             notes="release with spin: damping only"),

    # --- Jumps and dodges (airborne, after a jump) ------------------------------
    scenario("double_jump", 1.0, [(0, {}), (s(0.05), {"jump": True}), (s(0.05) + JUMP_TAP, {})],
             car_state=car(can_flip=True)),
    flip("front_flip", {"pitch": -1.0}),
    flip("back_flip", {"pitch": 1.0}),
    flip("side_flip_right", {"yaw": 1.0}),
    flip("side_flip_left", {"yaw": -1.0}),
    flip("roll_flip_right", {"roll": 1.0}, notes="dodge direction from roll"),
    flip("front_flip_held", {"pitch": -1.0}, after={"pitch": -1.0}, notes="stick held through the flip"),
    flip("flip_cancel", {"pitch": 1.0}, after={"pitch": -1.0},
         notes="back flip cancelled by pulling forward (half flip without the roll)"),
    flip("boosted_side_flip", {"yaw": 1.0}, hold={"boost": True}),
    flip("moving_front_flip", {"pitch": -1.0}, vel=(0.0, 1400.0, 0.0), notes="dodge at 1400 uu/s"),
    flip("moving_side_flip", {"yaw": 1.0}, vel=(0.0, 1400.0, 0.0), notes="side dodge at 1400 uu/s"),
    flip("moving_back_flip", {"pitch": 1.0}, vel=(0.0, 1400.0, 0.0), notes="back dodge at 1400 uu/s"),

    # --- Ball ------------------------------------------------------------------
    scenario("ball_flight", 2.0, [(0, {})], car_state=car(pos=(3000.0, 0.0, HIGH)),
             ball={"pos": [0.0, 0.0, HIGH], "vel": [800.0, 1200.0, 600.0], "ang_vel": [1.0, 2.0, 0.5]},
             notes="ball gravity + drag, car far away"),
    scenario("ball_hit_centre", 1.0, [(0, {"boost": True})],
             car_state=car(pos=(0.0, -600.0, HIGH), vel=(0.0, 1400.0, 0.0)),
             ball={"pos": [0.0, 0.0, HIGH + 20.755], "vel": [0.0, 0.0, 0.0], "ang_vel": [0.0, 0.0, 0.0]},
             notes="boosting car hits a ball level with its hitbox centre"),
    scenario("ball_hit_kickoff", 1.0, [(0, {"boost": True})],
             car_state=car(pos=(0.0, -600.0, HIGH), vel=(0.0, 1400.0, 0.0)),
             ball={"pos": [0.0, 0.0, HIGH + 20.755], "vel": [0.0, 0.0, 0.0], "ang_vel": [0.0, 0.0, 0.0],
                   "kickoff_float": True},
             notes="as ball_hit_centre, but the ball floats until touched (RL's kickoff rule)"),
    scenario("ball_hit_offset", 1.0, [(0, {})],
             car_state=car(pos=(-40.0, -500.0, HIGH), vel=(0.0, 1800.0, 0.0)),
             ball={"pos": [0.0, 0.0, HIGH + 60.0], "vel": [0.0, 0.0, 0.0], "ang_vel": [0.0, 0.0, 0.0]},
             notes="glancing hit: ball high and to one side"),

    # --- Ground (needs RocketSim's soccar collision meshes) ----------------------
    scenario("ground_throttle", 3.0, [(0, {"throttle": 1.0})], arena="soccar",
             car_state=car(pos=(0.0, -4000.0, 17.0))),
    scenario("ground_boost", 3.0, [(0, {"boost": True})], arena="soccar",
             car_state=car(pos=(0.0, -4000.0, 17.0))),
    scenario("ground_brake", 1.5, [(0, {"throttle": -1.0})], arena="soccar",
             car_state=car(pos=(0.0, -3000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    scenario("ground_coast", 2.0, [(0, {})], arena="soccar",
             car_state=car(pos=(0.0, -3000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    scenario("ground_turn", 2.0, [(0, {"throttle": 1.0, "steer": 1.0, "yaw": 1.0})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    scenario("ground_powerslide", 1.5, [(0, {"throttle": 1.0, "steer": 1.0, "yaw": 1.0, "handbrake": True})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    scenario("ground_turn_slow", 2.0, [(0, {"throttle": 0.4, "steer": 1.0, "yaw": 1.0})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 500.0, 0.0))),
    scenario("ground_turn_half", 2.0, [(0, {"throttle": 1.0, "steer": 0.5, "yaw": 0.5})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    scenario("ground_turn_boost", 1.5, [(0, {"boost": True, "steer": 1.0, "yaw": 1.0})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    scenario("ground_powerslide_slow", 1.5, [(0, {"throttle": 1.0, "steer": 1.0, "yaw": 1.0, "handbrake": True})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 700.0, 0.0))),
    scenario("ground_powerslide_release", 2.0, [(0, {"throttle": 1.0, "steer": 1.0, "yaw": 1.0, "handbrake": True}),
                                                (s(0.5), {"throttle": 1.0, "steer": 1.0, "yaw": 1.0})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 1400.0, 0.0)), notes="powerslide 0.5 s, then a normal turn"),
    scenario("ground_handbrake_straight", 1.5, [(0, {"throttle": 1.0, "handbrake": True})], arena="soccar",
             car_state=car(pos=(0.0, -2000.0, 17.0), vel=(0.0, 1400.0, 0.0))),
    # --- Driving up the back wall, beside the goal ---------------------------------
    scenario("wall_drive", 3.0, [(0, {"throttle": 1.0})], arena="soccar",
             car_state=car(pos=(2000.0, 3000.0, 17.0), vel=(0.0, 1400.0, 0.0)), notes="throttle up the back wall"),
    scenario("wall_drive_boost", 3.0, [(0, {"boost": True})], arena="soccar",
             car_state=car(pos=(2000.0, 3000.0, 17.0), vel=(0.0, 1400.0, 0.0)), notes="boost up the back wall"),
    scenario("wall_drive_turn", 3.0, [(0, {"throttle": 1.0}), (s(1.5), {"throttle": 1.0, "steer": 1.0, "yaw": 1.0})], arena="soccar",
             car_state=car(pos=(2000.0, 3000.0, 17.0), vel=(0.0, 1400.0, 0.0)), notes="up the wall, then steer along it"),
    scenario("wall_slow_fall", 3.0, [(0, {})], arena="soccar",
             car_state=car(pos=(2000.0, 4300.0, 17.0), vel=(0.0, 900.0, 0.0)), notes="coasting up the wall until it falls off"),
    # --- Ball against the arena (car parked far away) -----------------------------
    *[scenario(name, duration, [(0, {})], arena="soccar", car_state=car(pos=(-3000.0, 4000.0, 17.0)),
               ball={"pos": list(pos), "vel": list(vel), "ang_vel": list(spin)}, notes=notes)
      for name, duration, pos, vel, spin, notes in [
          ("ball_bounce_floor", 3.0, (0, -1000, 1200), (0, 0, 0), (0, 0, 0), "dropped onto the floor"),
          ("ball_bounce_moving", 3.0, (0, -2000, 800), (0, 1500, 0), (0, 0, 0), "dropped while moving: bounce friction"),
          ("ball_bounce_spin", 3.0, (0, -2000, 800), (0, 1000, 0), (-8.0, 0, 0), "backspin into the floor"),
          ("ball_slide_to_roll", 2.5, (0, -2000, 93.15), (0, 1500, 0), (0, 0, 0), "sliding along the floor, no spin"),
          ("ball_side_wall", 2.0, (2500, 0, 600), (2500, 300, 300), (0, 0, 0), "thrown at the side wall"),
          ("ball_side_wall_spin", 2.0, (2500, 0, 600), (2500, 0, 300), (0, 0, 6.0), "side wall with sidespin"),
          ("ball_back_wall", 2.0, (2000, 3000, 900), (0, 2500, 200), (0, 0, 0), "thrown at the back wall beside the goal"),
          ("ball_ramp", 3.0, (0, 0, 93.15), (1500, 0, 0), (0, -16.4, 0), "rolling up the side wall ramp"),
          ("ball_ceiling", 2.0, (0, 0, 1400), (300, 0, 1500), (0, 0, 0), "thrown up into the ceiling"),
          ("ball_corner", 2.0, (2500, 3500, 600), (1500, 1500, 0), (0, 0, 0), "into a 45 degree corner"),
          ("ball_into_goal", 3.0, (0, 4000, 93.15), (0, 2000, 0), (21.9, 0, 0), "rolling into the net"),
      ]],
    scenario("jump_tap", 1.5, [(0, {}), (s(0.1), {"jump": True}), (s(0.1) + JUMP_TAP, {})], arena="soccar",
             car_state=car(pos=(0.0, 0.0, 17.0))),
    scenario("jump_full", 2.0, [(0, {}), (s(0.1), {"jump": True}), (s(0.4), {})], arena="soccar",
             car_state=car(pos=(0.0, 0.0, 17.0))),
]
