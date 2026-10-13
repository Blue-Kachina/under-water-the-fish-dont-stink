"""Measure a floor ramp of RocketSim's Soccar arena (RL's own collision mesh) with the ball.

    uv run ramp_fit.py end 2000     # the back wall's ramp, along +y at x = 2000 uu
    uv run ramp_fit.py side 0       # the side wall's ramp, along +x at y = 0

With gravity off, the ball is thrown at the ramp from many heights and angles; the ball's centre on
the tick before it first touches lies one ball radius (plus the mesh's collision margin) off the
surface. Then fits, for each facet count, the profile the game builds (aquarium_arena.gd: flat facets
with their corners on a quarter circle between the floor and the wall) and prints the wall's
position, the ramp's radius and the rms misfit. Needs the collision meshes (see README).
"""
import math
import sys

import numpy as np
import RocketSim as rs

import run  # noqa: F401  (initialises RocketSim with the collision meshes)

BALL_REACH = 93.15  # RocketSim's BALL_REST_Z: ball radius plus the mesh's collision margin
THROW_SPEED = 60.0  # uu/s: slow, so the tick before contact is within half a uu of the surface


def contacts(kind: str, at: float) -> np.ndarray:
    arena = rs.Arena(rs.GameMode.SOCCAR, tick_rate=120)
    mutators = arena.get_mutator_config()
    mutators.gravity = rs.Vec(0, 0, 0)
    arena.set_mutator_config(mutators)
    wall = 5120.0 if kind == "end" else 4096.0
    points = []
    for degrees in (0, 15, 30, 45, 60, 75, 90):  # below horizontal, toward the wall
        d = np.array([math.cos(math.radians(degrees)), -math.sin(math.radians(degrees))])
        for k in range(70):
            z0 = BALL_REACH + 0.5 + k * 4.0 + 200.0 * d[1] * -1.0
            u0 = wall - 320.0 + (k * 4.0 if degrees == 90 else 0.0)
            state = arena.ball.get_state()
            state.pos = rs.Vec(at, u0, z0) if kind == "end" else rs.Vec(u0, at, z0)
            velocity = (0.0, THROW_SPEED * d[0], THROW_SPEED * d[1]) if kind == "end" else (THROW_SPEED * d[0], 0.0, THROW_SPEED * d[1])
            state.vel = rs.Vec(*velocity)
            state.ang_vel = rs.Vec(0, 0, 0)
            arena.ball.set_state(state)
            previous = None
            for _ in range(2400):
                b = arena.ball.get_state()
                u = b.pos.y if kind == "end" else b.pos.x
                vu = b.vel.y if kind == "end" else b.vel.x
                p, v = np.array([u, b.pos.z]), np.array([vu, b.vel.z])
                if previous is not None and np.linalg.norm(v - previous[1]) > 0.5:
                    points.append(previous[0])
                    break
                previous = (p, v)
                arena.step(1)
    return np.array(points)


def profile(wall: float, radius: float, facets: int) -> np.ndarray:
    a = np.linspace(0.0, math.pi / 2.0, facets + 1)
    ramp = np.stack([wall - radius + radius * np.sin(a), radius - radius * np.cos(a)], 1)
    return np.vstack([[wall - radius - 2000.0, 0.0], ramp, [wall, 3000.0]])


def distance(points: np.ndarray, polyline: np.ndarray) -> np.ndarray:
    best = np.full(len(points), np.inf)
    for a, b in zip(polyline[:-1], polyline[1:]):
        ab = b - a
        t = np.clip(((points - a) @ ab) / (ab @ ab), 0.0, 1.0)
        best = np.minimum(best, np.linalg.norm(points - (a + t[:, None] * ab), axis=1))
    return best


def main() -> None:
    kind, at = sys.argv[1], float(sys.argv[2])
    wall_guess = 5120.0 if kind == "end" else 4096.0
    points = contacts(kind, at)
    # Only contacts with the ramp itself, not the flat floor or the wall above it.
    on_ramp = points[(points[:, 1] > BALL_REACH + 1.0) & (points[:, 0] < wall_guess - BALL_REACH - 1.0)]
    print(f"{len(points)} contacts, {len(on_ramp)} on the ramp")
    for facets in (4, 6, 8, 10, 12, 16):
        best = (math.inf, 0.0, 0.0)
        for wall in np.arange(wall_guess - 10.0, wall_guess + 10.01, 0.25):
            for radius in np.arange(100.0, 400.0, 0.5):
                miss = distance(on_ramp, profile(wall, radius, facets)) - BALL_REACH
                rms = float(np.sqrt(np.mean(miss ** 2)))
                if rms < best[0]:
                    best = (rms, wall, radius)
        print(f"{facets:2d} facets: wall at {best[1]:7.2f} uu, radius {best[2]:6.1f} uu, rms {best[0]:.2f} uu")


if __name__ == "__main__":
    main()
