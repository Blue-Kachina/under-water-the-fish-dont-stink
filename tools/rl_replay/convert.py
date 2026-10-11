"""Convert a Rocket League .replay into the game's playback format.

    uv run convert.py IN.replay [-o OUT.rlreplay.json] [--anonymize]

The output defaults to IN with .rlreplay.json in place of .replay.
"""

import argparse
import json
import sys
from pathlib import Path

from rlreplay import clean, extract, schema


def convert(source: Path, target: Path, anonymize: bool = False) -> dict:
    raw = extract.read_replay(str(source))
    doc = clean.build_document(raw, extract.parser_name(), anonymize)
    errors = schema.validate(doc)
    if errors:
        raise clean.ConversionError("the converted document is invalid:\n  " + "\n  ".join(errors))
    target.write_text(json.dumps(doc, separators=(",", ":")), encoding="utf-8")
    return doc


def main() -> int:
    sys.stdout.reconfigure(errors="replace")  # player names can be any script; Windows consoles often can't show them
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("replay", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument("--anonymize", action="store_true", help='replace player names with "Blue 1" and so on')
    args = parser.parse_args()
    target = args.output or args.replay.with_name(args.replay.name.removesuffix(".replay") + ".rlreplay.json")
    try:
        doc = convert(args.replay, target, args.anonymize)
    except clean.ConversionError as error:
        print(f"convert: {error}", file=sys.stderr)
        return 1
    match = doc["match"]
    print(f"{target}: {match['num_frames']} frames, {match['duration']:.1f} s, "
          f"{len(doc['players'])} players, score {match['score'][0]}-{match['score'][1]}, "
          f"{target.stat().st_size / 1e6:.1f} MB")
    for player in doc["players"]:
        note = "" if player["hitbox_family_known"] else " (unknown car: using Octane's hitbox)"
        print(f"  {['Blue', 'Orange'][player['team']]:<7}{player['name']:<24}{player['hitbox_family']}{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
