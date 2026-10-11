"""The converter's cleaning rules, checked on the synthetic fixture (no real replay needed).

    uv run python -m unittest discover tests
"""

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import make_fixture  # noqa: E402
from rlreplay import clean, schema  # noqa: E402


class FixtureDocument(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = make_fixture.build_document()
        cls.n = cls.doc["match"]["num_frames"]

    def frame(self, track: dict, key: str, i: int, width: int) -> list:
        return track[key][width * i:width * i + width]

    def test_valid(self):
        self.assertEqual(schema.validate(self.doc), [])

    def test_round_trips_through_json(self):
        self.assertEqual(json.loads(json.dumps(self.doc)), self.doc)

    def test_times_start_at_zero_and_the_cut_is_closed(self):
        times = self.doc["frames"]["time"]
        self.assertEqual(times[0], 0.0)
        self.assertEqual(self.doc["match"]["gaps_closed"], 1)
        # The 4 s cut after frame 299 becomes one frame step.
        self.assertAlmostEqual(times[300] - times[299], 1.0 / 30.0, places=3)
        self.assertAlmostEqual(self.doc["match"]["duration"], 359 / 30.0, places=2)

    def test_game_states_from_the_countdown_timer(self):
        kinds = [s["type"] for s in self.doc["segments"]]
        self.assertEqual(kinds, ["countdown", "live", "post_goal", "countdown", "live"])
        self.assertEqual(self.doc["source"]["game_state_codes"], {"countdown": 28, "live": 31})

    def test_spin_in_rad_per_s(self):
        self.assertEqual(self.doc["source"]["ang_vel_scale_detected"], 0.01)
        w = self.frame(self.doc["ball"], "ang_vel", 200, 3)
        self.assertAlmostEqual(w[0], -6.0, places=3)

    def test_boost_as_percent(self):
        blue = self.doc["cars"][0]
        self.assertAlmostEqual(blue["boost"][0], 33.3, places=1)  # raw 85 of 255

    def test_players_and_hitboxes(self):
        blue, orange = self.doc["players"]
        self.assertEqual((blue["name"], blue["team"], blue["hitbox_family"]), ("Fixture Blue", 0, "octane"))
        self.assertEqual((orange["team"], orange["hitbox_family"]), (1, "dominus"))
        self.assertEqual(orange["hitbox"]["offset"], [9.0, 0.0, 15.75])

    def test_anonymize(self):
        doc = make_fixture.build_document(anonymize=True)
        self.assertEqual([p["name"] for p in doc["players"]], ["Blue 1", "Orange 1"])

    def test_events(self):
        events = self.doc["events"]
        goal = next(e for e in events if e["type"] == "goal")
        self.assertEqual((goal["team"], goal["player"]), (0, 0))
        self.assertEqual(self.doc["match"]["score"], [1, 0])
        touch = next(e for e in events if e["type"] == "touch")
        self.assertEqual(touch["player"], 0)  # worked out: subtr-actor gave only the team
        demo = next(e for e in events if e["type"] == "demo")
        self.assertEqual((demo["attacker"], demo["victim"]), (0, 1))
        self.assertEqual([e["frame"] for e in events if e["type"] == "kickoff"], [90, 330])
        for event in events:
            self.assertAlmostEqual(event["time"], self.doc["frames"]["time"][event["frame"]], places=3)

    def test_presence_and_teleports(self):
        ball, blue, orange = self.doc["ball"], self.doc["cars"][0], self.doc["cars"][1]
        demo, respawn = make_fixture.DEMO_FRAME, make_fixture.RESPAWN_FRAME
        self.assertEqual(orange["present"][demo - 1], 1)
        self.assertEqual(orange["present"][demo], 0)
        self.assertTrue(orange["flags"][demo] & clean.FLAG_DEMOLISHED)
        self.assertEqual(orange["teleport"][respawn], 1)
        self.assertEqual(sum(orange["teleport"]), 3)  # first sample, respawn, second kickoff
        self.assertEqual(sum(blue["teleport"]), 2)  # first sample, second kickoff
        self.assertEqual(ball["present"][250], 0)  # gone after the goal
        self.assertEqual(ball["teleport"][300], 1)

    def test_flags(self):
        orange = self.doc["cars"][1]
        self.assertTrue(orange["flags"][make_fixture.JUMP_FRAME] & clean.FLAG_JUMP)
        self.assertTrue(orange["flags"][make_fixture.DOUBLE_JUMP_FRAME] & clean.FLAG_DOUBLE_JUMP)
        blue = self.doc["cars"][0]
        self.assertTrue(blue["flags"][100] & clean.FLAG_BOOST)
        self.assertTrue(blue["flags"][100] & clean.FLAG_SUPERSONIC)  # 2200 uu/s
        self.assertEqual(blue["throttle"][100], 1.0)

    def test_checked_in_fixture_is_current(self):
        """tests/fixtures/replay_fixture.rlreplay.json must be regenerated after changing the
        converter or the fixture: uv run make_fixture.py"""
        on_disk = json.loads(make_fixture.DEFAULT_OUT.read_text(encoding="utf-8"))
        self.assertEqual(on_disk, json.loads(json.dumps(self.doc)))


class Retiming(unittest.TestCase):
    ACCEL = 1000.0  # uu/s^2, about a boosting car's

    def accelerating_ball(self, raw: dict, ticks_off: dict, filler_every: int = 0) -> dict:
        """The fixture's rolling ball, speeding up (as real motion always varies), sampled
        `ticks_off[i]` physics ticks away from frame i's time. With `filler_every`, every
        such frame is instead the parser's filler: the last state coasted on at its velocity.
        Returns the true position (y) at each frame's time."""
        true_y = {}
        last = None
        for i, frame in enumerate(raw["frame_data"]["ball_data"]["frames"]):
            body = clean._rigid_body(frame)
            if not (body and body.get("linear_velocity") and 160 <= i < 230):
                continue
            s = (i - make_fixture.TOUCH_FRAME) / make_fixture.FPS
            true_y[i] = make_fixture.BALL_SPEED * s + 0.5 * self.ACCEL * s * s
            if filler_every and i % filler_every == 0 and last is not None:
                body["linear_velocity"] = dict(last["linear_velocity"])
                body["angular_velocity"] = dict(last["angular_velocity"])
                body["location"]["y"] = last["location"]["y"] + last["linear_velocity"]["y"] / make_fixture.FPS
            else:
                s += ticks_off.get(i, 0) * clean.TICK
                body["location"]["y"] = make_fixture.BALL_SPEED * s + 0.5 * self.ACCEL * s * s
                body["linear_velocity"]["y"] = make_fixture.BALL_SPEED + self.ACCEL * s
            last = body
        return true_y

    def test_recovers_tick_offsets(self):
        """Samples taken a tick or so off their frames' times (as replays record them) get
        their timing back. What shows on screen is the time between neighbouring samples, so
        that's what's checked (a slow drift of all offsets together is invisible)."""
        import random
        raw = make_fixture.build_raw()
        rng = random.Random(3)
        ticks = {i: rng.randint(-1, 1) for i in range(160, 230)}
        self.accelerating_ball(raw, ticks)
        offsets = clean.build_document(raw, "fixture")["ball"]["time_offset"]
        planted = {i: k * clean.TICK for i, k in ticks.items()}
        pairs = [i for i in planted if i - 1 in planted]
        before = max(abs(planted[i] - planted[i - 1]) for i in pairs)
        after = max(abs((offsets[i] - offsets[i - 1]) - (planted[i] - planted[i - 1])) for i in pairs)
        self.assertGreater(before, 0.015)
        self.assertLess(after, 0.002, f"worst step timing error {after * 1000:.1f} ms (was {before * 1000:.1f} ms)")

    def test_rebuilds_filler(self):
        """Every other frame coasted on at the last velocity (the parser's filler): rebuilt
        onto the true path, where coasting was well off it."""
        raw = make_fixture.build_raw()
        true_y = self.accelerating_ball(raw, {}, filler_every=2)
        frames = raw["frame_data"]["ball_data"]["frames"]
        coasted = max(abs(clean._rigid_body(frames[i])["location"]["y"] - true_y[i])
                      for i in true_y if i % 2 == 0 and i > 160)
        ball = clean.build_document(raw, "fixture")["ball"]
        worst = 0.0
        for i in true_y:
            if i % 2 == 0 and 162 <= i < 228:
                s = (i - make_fixture.TOUCH_FRAME) / make_fixture.FPS + ball["time_offset"][i]
                expected = make_fixture.BALL_SPEED * s + 0.5 * self.ACCEL * s * s
                worst = max(worst, abs(ball["pos"][3 * i + 1] - expected))
        self.assertGreater(coasted, 0.5)
        self.assertLess(worst, 0.05, f"rebuilt filler off the path by {worst:.2f} uu (coasting: {coasted:.2f} uu)")

    def test_steady_motion_needs_no_offsets(self):
        doc = make_fixture.build_document()
        self.assertLess(max(abs(o) for o in doc["ball"]["time_offset"]), 0.0005)


class Rejections(unittest.TestCase):
    def test_unknown_spin_units(self):
        raw = make_fixture.build_raw()
        for frame in raw["frame_data"]["ball_data"]["frames"]:
            body = clean._rigid_body(frame)
            if body and body.get("angular_velocity"):
                body["angular_velocity"] = {k: v * 1000 for k, v in body["angular_velocity"].items()}
        with self.assertRaises(clean.ConversionError):
            clean.build_document(raw, "fixture")

    def test_schema_catches_short_columns(self):
        doc = make_fixture.build_document()
        doc["cars"][0]["pos"].pop()
        self.assertTrue(any("cars[0].pos" in e for e in schema.validate(doc)))


if __name__ == "__main__":
    unittest.main()
