"""Make a replay's soundtrack from a broadcast of the same game.

A broadcast is longer than its replay: it shows Rocket League's own goal replays (cut out of the
.replay, see rlreplay/clean.py), plus camera cuts and reactions. Between those, though, it runs in
real time, as does each stretch of the replay from a kickoff countdown to the end of the pause after
the next goal (a "block"). So each block needs one number: where it starts in the video.

    uv run broadcast_audio.py align GAME.rlreplay.json VIDEO.mp4        # writes GAME.sync.json
    uv run broadcast_audio.py stitch GAME.rlreplay.json VIDEO.mp4       # writes GAME.ogg

`align` finds the offsets from the scoreboard clock. During live play it changes once a second, at
the moments the replay's `seconds_remaining` changes, so matching the two gives each block's offset to
a frame or so. That only fixes it modulo whole seconds; the goal explosion (the frame's brightness
jumping at the goal's time) settles which second. `--clock` is where the clock is on screen, as
fractions of the frame (x, y, width, height); the default fits the 2018 RLCS broadcast.

`stitch` cuts each block's stretch out of the video's audio (or any audio file with the video's
timing) and joins them, so the result's second 0 is the replay's second 0, as long as the replay.
Put it next to the replay with the same name (7.replay, 7.ogg) and the game plays it with the replay.

Broadcast audio is someone else's work: it stays in private_content, like the replays.
"""

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import imageio_ffmpeg
import numpy as np

FPS = 30.0  # the video is resampled to this, so frame i is at i / FPS
CLOCK_SIZE = (80, 30)  # the clock crop is scaled to this, so thresholds don't depend on resolution
DEFAULT_CLOCK = (0.453, 0.008, 0.094, 0.063)  # RLCS 2018: "4:38" at the top centre
TICK_PIXELS = 15  # pixels (of the scaled crop) that must change for a clock tick
TICK_TOLERANCE = 0.06  # s
GOAL_TOLERANCE = 0.15  # s; the explosion shows within this of the goal's time
GOAL_BONUS = 8.0  # worth this many ticks
SAMPLE_RATE = 48000
FADE = 0.015  # s, at each join, so the cuts don't click


def ffmpeg() -> str:
    return imageio_ffmpeg.get_ffmpeg_exe()


def read_frames(video: Path, vf: str, size: tuple[int, int]) -> np.ndarray:
    """The video's frames at FPS through filter `vf`, as gray (n, h, w) uint8."""
    cmd = [ffmpeg(), "-hide_banner", "-loglevel", "error", "-i", str(video),
           "-vf", f"fps={FPS},{vf},scale={size[0]}:{size[1]},format=gray", "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, size[1], size[0])


def replay_blocks(doc: dict) -> list[dict]:
    """Each run of countdown, live play and post-goal pause, with its clock ticks and goal."""
    t = np.array(doc["frames"]["time"])
    remaining = np.array(doc["frames"]["seconds_remaining"])
    blocks, block = [], None
    for seg in doc["segments"]:
        if block is None or seg["type"] == "countdown" and block.get("live"):
            block = {"start": seg["start"], "goal": None}
            blocks.append(block)
        block["end"] = seg["end"]
        if seg["type"] == "live":
            block["live"] = (seg["start"], seg["end"])
        elif seg["type"] == "post_goal":
            block["goal"] = seg["start"]
    for block in blocks:
        lo, hi = block.get("live", (block["start"], block["start"]))
        i = np.where((t > lo) & (t <= hi))[0]
        i = i[remaining[i] != remaining[i - 1]]
        block["ticks"] = t[i]
    return blocks


def video_ticks(clock: np.ndarray) -> np.ndarray:
    """Times the clock changed on its own: one frame differs, its neighbours don't (a scene cut
    or transition changes it for several frames running)."""
    changed = (np.abs(np.diff(clock.astype(np.int16), axis=0)) > 50).sum(axis=(1, 2)) > TICK_PIXELS
    lone = changed & ~np.r_[False, changed[:-1]] & ~np.r_[changed[1:], False]
    return (np.where(lone)[0] + 1) / FPS


def explosion_at(jumps: np.ndarray, at: float) -> float:
    """Where, near `at`, the frame brightens most (a goal explosion fills the screen)."""
    lo, hi = max(int((at - 1.5) * FPS), 0), min(int((at + 1.5) * FPS), len(jumps))
    if hi <= lo:
        return float("nan")
    return (lo + int(np.argmax(jumps[lo:hi])) + 1) / FPS


def place(block: dict, vticks: np.ndarray, jumps: np.ndarray, lo: float, hi: float) -> tuple[float, float]:
    """The offset in [lo, hi] that lines up the most clock ticks (and the goal explosion)."""
    rt = block["ticks"]
    best, best_score = lo, -1.0
    for o in np.arange(lo, hi, 1.0 / FPS):
        shifted = rt + o
        j = np.clip(np.searchsorted(vticks, shifted), 1, len(vticks) - 1)
        near = np.minimum(np.abs(vticks[j] - shifted), np.abs(vticks[j - 1] - shifted))
        score = float((near < TICK_TOLERANCE).sum())
        if score > best_score - GOAL_BONUS and block["goal"] is not None:
            if abs(explosion_at(jumps, block["goal"] + o) - (block["goal"] + o)) < GOAL_TOLERANCE:
                score += GOAL_BONUS
        if score > best_score:
            best, best_score = o, score
    # Refine to the median of the matched ticks.
    shifted = rt + best
    j = np.clip(np.searchsorted(vticks, shifted), 1, len(vticks) - 1)
    nearest = np.where(np.abs(vticks[j] - shifted) < np.abs(vticks[j - 1] - shifted), vticks[j], vticks[j - 1])
    residual = nearest - shifted
    matched = np.abs(residual) < TICK_TOLERANCE
    if matched.any():
        best += float(np.median(residual[matched]))
    return best, best_score


def align(args: argparse.Namespace) -> None:
    doc = json.loads(Path(args.replay).read_text())
    blocks = replay_blocks(doc)
    x, y, w, h = args.clock
    print(f"reading {args.video}...", file=sys.stderr)
    clock = read_frames(args.video, f"crop=iw*{w}:ih*{h}:iw*{x}:ih*{y}", CLOCK_SIZE)
    small = read_frames(args.video, "null", (64, 36))
    duration = len(small) / FPS
    vticks = video_ticks(clock)
    jumps = np.diff(small.astype(np.float32).mean(axis=(1, 2)))

    # Biggest blocks first (the most ticks, so the surest), each kept between its placed neighbours:
    # the video shows the blocks in order and never overlaps them.
    offsets: list[float | None] = [None] * len(blocks)
    for k in sorted(range(len(blocks)), key=lambda k: -len(blocks[k]["ticks"])):
        lo = -blocks[k]["start"] - 60.0  # the video may start part way into the first block
        hi = duration - blocks[k]["start"]
        for i in range(k - 1, -1, -1):
            if offsets[i] is not None:
                lo = max(lo, blocks[i]["end"] + offsets[i] - blocks[k]["start"])
                break
        for i in range(k + 1, len(blocks)):
            if offsets[i] is not None:
                hi = min(hi, blocks[i]["start"] + offsets[i] - blocks[k]["end"])
                break
        offsets[k], _ = place(blocks[k], vticks, jumps, lo, max(hi, lo + 1.0 / FPS))

    out = {"replay": Path(args.replay).name, "video": Path(args.video).name, "blocks": []}
    print(" block  replay (s)         video (s)          offset   ticks   goal explosion")
    for k, (block, o) in enumerate(zip(blocks, offsets)):
        shifted = block["ticks"] + o
        j = np.clip(np.searchsorted(vticks, shifted), 1, len(vticks) - 1)
        near = np.minimum(np.abs(vticks[j] - shifted), np.abs(vticks[j - 1] - shifted))
        goal = "-"
        if block["goal"] is not None:
            lag = explosion_at(jumps, block["goal"] + o) - (block["goal"] + o)
            goal = f"{lag:+.2f} s" + ("" if abs(lag) < GOAL_TOLERANCE else "  CHECK THIS BLOCK")
        print(f" {k:5d}  {block['start']:7.2f}-{block['end']:7.2f}   {block['start'] + o:7.2f}-{block['end'] + o:7.2f}"
              f"   {o:7.3f}   {(near < TICK_TOLERANCE).sum():3d}/{len(block['ticks']):<3d}  {goal}")
        out["blocks"].append({"start": round(block["start"], 4), "end": round(block["end"], 4), "offset": round(o, 3)})
    target = Path(args.out) if args.out else sync_path(args.replay)
    target.write_text(json.dumps(out, indent=1) + "\n")
    print(f"wrote {target}")


def sync_path(replay: str) -> Path:
    return Path(replay.removesuffix(".rlreplay.json").removesuffix(".replay") + ".sync.json")


def stitch(args: argparse.Namespace) -> None:
    doc = json.loads(Path(args.replay).read_text())
    sync = json.loads(Path(args.sync or sync_path(args.replay)).read_text())
    duration = doc["match"]["duration"]
    cmd = [ffmpeg(), "-hide_banner", "-loglevel", "error", "-i", str(args.source),
           "-vn", "-ac", "2", "-ar", str(SAMPLE_RATE), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    source = np.frombuffer(raw, np.float32).reshape(-1, 2)

    out = np.zeros((int(round(duration * SAMPLE_RATE)), 2), np.float32)
    fade = int(FADE * SAMPLE_RATE)
    for block in sync["blocks"]:
        a, b = int(round(block["start"] * SAMPLE_RATE)), min(int(round(block["end"] * SAMPLE_RATE)), len(out))
        src = int(round((block["start"] + block["offset"]) * SAMPLE_RATE))
        piece = np.zeros((b - a, 2), np.float32)
        lo, hi = max(src, 0), min(src + b - a, len(source))
        if hi > lo:
            piece[lo - src:hi - src] = source[lo:hi]  # silence where the video doesn't reach
        ramp = np.linspace(0.0, 1.0, min(fade, len(piece)), dtype=np.float32)[:, None]
        piece[:len(ramp)] *= ramp
        piece[len(piece) - len(ramp):] *= ramp[::-1]
        out[a:b] = piece

    target = Path(args.out) if args.out else Path(str(sync_path(args.replay)).removesuffix(".sync.json") + ".ogg")
    with tempfile.TemporaryDirectory() as tmp:
        pcm = Path(tmp) / "soundtrack.f32"
        out.tofile(pcm)
        subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SAMPLE_RATE),
                        "-ac", "2", "-i", str(pcm), "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
    print(f"wrote {target} ({duration:.1f} s, {len(sync['blocks'])} pieces)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    a = sub.add_parser("align", help="find where each block of the replay is in the video")
    a.add_argument("replay", help="the converted .rlreplay.json")
    a.add_argument("video")
    a.add_argument("--clock", type=float, nargs=4, default=DEFAULT_CLOCK, metavar=("X", "Y", "W", "H"),
                   help="the scoreboard clock, as fractions of the frame")
    a.add_argument("-o", "--out", help="default: next to the replay, NAME.sync.json")
    s = sub.add_parser("stitch", help="cut the blocks out of the video's audio and join them")
    s.add_argument("replay", help="the converted .rlreplay.json")
    s.add_argument("source", help="the video, or audio with the video's timing")
    s.add_argument("--sync", help="default: NAME.sync.json next to the replay")
    s.add_argument("-o", "--out", help="default: next to the replay, NAME.ogg")
    args = parser.parse_args()
    align(args) if args.command == "align" else stitch(args)


if __name__ == "__main__":
    main()
