"""broadcast_audio.py on synthetic data: the replay's blocks, the clock's ticks, and stitching.

    uv run python -m unittest discover tests
"""

import argparse
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import broadcast_audio as ba  # noqa: E402
import make_fixture  # noqa: E402


class Blocks(unittest.TestCase):
    def test_fixture_blocks(self):
        blocks = ba.replay_blocks(make_fixture.build_document())
        # countdown, live, goal, countdown, live (to the end, no goal)
        self.assertEqual([(b["start"], b["end"], b["goal"]) for b in blocks],
                         [(0.0, 10.0, 8.0), (10.0, blocks[1]["end"], None)])
        self.assertTrue(all(b["live"][0] < t <= b["live"][1] for b in blocks for t in b["ticks"]))


class Ticks(unittest.TestCase):
    def test_lone_changes_are_ticks_and_cuts_are_not(self):
        w, h = ba.CLOCK_SIZE
        frames = np.zeros((300, h, w), np.uint8)
        frames[30:] = 200  # a tick at frame 30 (1 s)
        frames[60:, :, :w // 2] = 0  # another at 2 s
        for i in range(150, 160):  # a transition: changes on many frames running
            frames[i:] = 255 * (i % 2)
        ticks = ba.video_ticks(frames)
        self.assertEqual(list(np.round(ticks, 3)), [1.0, 2.0])


class Stitch(unittest.TestCase):
    def test_pieces_land_at_replay_time(self):
        rate = ba.SAMPLE_RATE
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            # The "broadcast": 30 s, beeps at 5 s, 15 s (in the gap between blocks) and 19 s.
            source = np.zeros(30 * rate, np.float32)
            for at in (5.0, 15.0, 19.0):
                i = int(at * rate)
                source[i:i + rate // 10] = 0.5 * np.sin(np.arange(rate // 10) * 2 * np.pi * 1000 / rate)
            (tmp / "src.f32").write_bytes(source.tobytes())
            subprocess.run([ba.ffmpeg(), "-loglevel", "error", "-f", "f32le", "-ar", str(rate), "-ac", "1",
                            "-i", str(tmp / "src.f32"), str(tmp / "src.wav")], check=True)
            # A replay of two blocks: [0, 8) shown at video 3 s, [8, 12) at video 17 s, with a gap
            # between them (the broadcast's goal replay).
            replay = tmp / "game.rlreplay.json"
            replay.write_text(json.dumps({"match": {"duration": 12.0}}))
            (tmp / "game.sync.json").write_text(json.dumps({"blocks": [
                {"start": 0.0, "end": 8.0, "offset": 3.0}, {"start": 8.0, "end": 12.0, "offset": 9.0}]}))
            ba.stitch(argparse.Namespace(replay=str(replay), source=str(tmp / "src.wav"), sync=None, out=None))
            out = subprocess.run([ba.ffmpeg(), "-loglevel", "error", "-i", str(tmp / "game.ogg"), "-ac", "1",
                                  "-ar", str(rate), "-f", "f32le", "-"], capture_output=True, check=True).stdout
            out = np.frombuffer(out, np.float32)
            self.assertAlmostEqual(len(out) / rate, 12.0, delta=0.05)
            # Video 5 s is replay 2 s; video 19 s is replay 10 s; the 15 s beep is cut out.
            loud = np.where(np.abs(out) > 0.1)[0] / rate
            starts = loud[np.r_[True, np.diff(loud) > 0.05]]  # the first loud sample of each beep
            self.assertEqual(len(starts), 2)
            self.assertAlmostEqual(starts[0], 2.0, delta=0.01)
            self.assertAlmostEqual(starts[1], 10.0, delta=0.01)


if __name__ == "__main__":
    unittest.main()
