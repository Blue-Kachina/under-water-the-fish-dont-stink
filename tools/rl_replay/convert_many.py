"""Convert every .replay under a folder, in one process, skipping ones already done.

    uv run convert_many.py IN_DIR OUT_DIR [--limit N]

Writes OUT_DIR/<replay name>.rlreplay.json, anonymized (names become "Blue 1" and so on),
and prints one line per replay. A replay that fails is reported and skipped. For mining
physics segments in bulk (tools/rocketsim_compare/replay_segments.py); the game converts
single replays itself.
"""

import argparse
import sys
import time
from pathlib import Path

from convert import convert
from rlreplay import clean


def main() -> int:
    sys.stdout.reconfigure(errors="replace")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--limit", type=int, default=0, help="stop after converting this many")
    args = parser.parse_args()
    args.target.mkdir(parents=True, exist_ok=True)
    replays = sorted(args.source.rglob("*.replay"))
    done = failed = 0
    start = time.time()
    for path in replays:
        out = args.target / (path.name.removesuffix(".replay") + ".rlreplay.json")
        if out.exists():
            continue
        try:
            doc = convert(path, out, anonymize=True)
            done += 1
            print(f"ok   {path.name}: {doc['source']['map']}, {doc['match']['duration']:.0f} s", flush=True)
        except (clean.ConversionError, Exception) as error:  # one bad replay mustn't stop the batch
            failed += 1
            print(f"fail {path.name}: {str(error).splitlines()[0][:160]}", flush=True)
        if args.limit and done >= args.limit:
            break
    print(f"converted {done}, failed {failed}, {time.time() - start:.0f} s", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
