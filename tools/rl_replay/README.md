# Rocket League replay converter

Turns a Rocket League `.replay` into the game's playback format, `*.rlreplay.json` (schema v1),
using [subtr-actor](https://github.com/rlrml/subtr-actor) (MIT) to parse it.

```
cd tools/rl_replay
uv run convert.py PATH/TO/GAME.replay                 # writes GAME.rlreplay.json next to it
uv run convert.py GAME.replay -o OUT.rlreplay.json --anonymize
uv run make_fixture.py                                # regenerate tests/fixtures/replay_fixture.rlreplay.json
uv run python -m unittest discover tests              # converter tests (no real replay needed)
```

The first run creates `.venv` and installs `subtr-actor-py` (pinned in `pyproject.toml`). If no wheel
fits your Python, uv builds it from source, which needs a Rust toolchain and takes about a minute.

**You don't normally run this by hand.** The game converts a `.replay` itself when you pick one in
Replays mode (the replay bar's "Replay..."), drop it on the window, or start the game with
`-- --replay=PATH`. It runs this tool through `uv` and keeps the result in
`user://replays/`, so each replay converts once. Rocket League saves replays in
`Documents/My Games/Rocket League/TAGame/Demos`.

## Soundtracks from a broadcast
`broadcast_audio.py` gives a replay the sound of the broadcast it was shown in: casters, crowd and
game audio, cut to the replay's timeline. A broadcast is longer than its replay (it shows Rocket
League's goal replays, which the converter cuts out, plus camera cuts and reactions), but between those
it runs in real time. So the replay splits into blocks, each running from a kickoff countdown to the end
of the pause after the next goal, and each block needs one offset into the video.

```
uvx yt-dlp -f "bv*[height<=480]" -o video.%(ext)s URL     # a small copy is enough to align with
uvx yt-dlp -f bestaudio -o audio.%(ext)s URL
uv run convert.py GAME.replay                              # GAME.rlreplay.json
uv run broadcast_audio.py align GAME.rlreplay.json video.mp4    # GAME.sync.json, and a report
uv run broadcast_audio.py stitch GAME.rlreplay.json audio.webm  # GAME.ogg
```

`align` matches the scoreboard clock's once-a-second ticks to the replay's `seconds_remaining`
(frame-accurate), and uses each goal's explosion (the frame's brightness jumping) to settle which
second. Its report gives each block's goal explosion relative to the replay's goal; anything
much over ±0.1 s is marked `CHECK THIS BLOCK`. `--clock X Y W H` (fractions of the frame) says
where the clock is on screen; the default fits the 2018 RLCS broadcast. If a block comes out wrong,
edit its `offset` in the `.sync.json` and run `stitch` again.

Put `GAME.ogg` (or `.mp3`/`.wav`) next to the replay with the same name (`7.replay`, `7.ogg`) and the game
plays it with the replay. Another can be picked with **Audio...** on the replay's controls, or dropped on
the window. Broadcast audio isn't ours: keep it in `private_content`, like the replays.

## Files
- `convert.py`: the command line.
- `rlreplay/extract.py`: the only module that calls subtr-actor, so a change in its API is fixed in one place.
- `rlreplay/clean.py`: subtr-actor's data → the v1 document (see its docstring for every rule).
- `rlreplay/hitboxes.py`: RocketSim's six hitbox presets.
- `rlreplay/schema.py`: checks a document's shape (the converter refuses to write an invalid one).
- `broadcast_audio.py`: soundtracks from a broadcast (above).
- `make_fixture.py`: a deterministic synthetic replay in subtr-actor's shape, run through the real converter.
- `samples/`: put replays here if you like. It's gitignored: **replays contain player names; never commit them.**

## The format (v1)
Columnar JSON in Rocket League's own units and axes (uu, +X left, +Y toward orange, +Z up). The game
converts it once, on load (`scripts/rl/rl_space.gd`, `scripts/replay/replay_data.gd`). Per frame (about
30 a second):
- `frames`: `time` (s from 0), `game_state` (0 live, 1 countdown, 2 after a goal), `seconds_remaining`,
  `kickoff_countdown`.
- `ball` and each of `cars[i]`: `present`, `pos`, `vel`, `rot` (quaternion xyzw), `ang_vel` (rad/s),
  `teleport`, `time_offset` (s; when the sample really happened, relative to its frame).
- Cars also have `boost` (0–100), `throttle` and `steer` (−1..1), `flags` (1 boost, 2 jump, 4 double jump,
  8 dodge, 16 powerslide, 32 supersonic, 64 demolished) and `dodge_torque`.
- `players`: name, team, body id, hitbox family and size, and the hitbox's offset from the centre of mass
  (replays record the centre of mass).
- `events` (`kickoff`, `goal`, `touch`, `demo`, `boost_pickup`), `segments`, `boost_pads`.

What the converter fixes up, so the game doesn't have to:
- Replay angular velocities are stored ×100. The scale is detected from the ball, whose spin is capped
  at 6 rad/s.
- Boost is RL's raw byte (0–255, 85 at kickoff).
- The replicated game state is an index into each replay's own name table (28 in one replay, 82 in
  another), so states are inferred from the kickoff countdown timer.
- Goal replays are cut out of recordings, leaving multi-second gaps. These are closed up and marked as
  teleports.
- subtr-actor reports only the team for ball touches. The toucher is that team's car nearest the ball.
- A car's first frames can come before its team is known. Teams come from the end-of-match roster, or
  else a majority vote over the frames.
- **Smooth motion.** About a quarter to a half of a car's frames have no network update. subtr-actor
  fills them by coasting the last state on at its velocity, so the car snaps when the real state
  arrives. Those fillers are rebuilt through the genuine samples either side, on the same curve the
  game draws. Genuine states also come from whichever physics tick (1/120 s) last replicated each
  body, up to about 3 ticks either side of the frame's time. Each sample's real time is fitted from
  its motion (`time_offset`). Played back as recorded, both made everything jitter.
- Players who join mid-match (replacing someone who left) get their own track, absent before they
  join. Their car may be missing from the roster, in which case it falls back to Octane's hitbox.
