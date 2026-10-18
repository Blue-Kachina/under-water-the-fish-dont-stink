# Sound profiles

Each folder here is one sound profile. It shows up in **Settings > Audio > Sound profile**
under the name in its `profile.cfg`, or under the folder name if it has none. The full
design is in `planning_audio.md`.

## Making one

1. Make a folder, e.g. `audio/profiles/acappella/`.
2. Name each file after its event id. `ball/hit` is `acappella/ball/hit.wav` (or `.ogg`
   or `.mp3`). Every event is listed in **Settings > Audio > Sound Board**, and in the
   recording sheet (**Settings > Audio > Write recording sheet** writes
   `audio/sound_sheet.csv`).
3. Pick the profile in Settings. After saving a file, press **Reload sounds** to hear it.

Anything your profile doesn't have stays silent. To hear where the gaps are, turn on
**Beep for missing sounds**.

## File names

| Name | Means |
|---|---|
| `ball/hit.wav` | the sound for `ball/hit` |
| `ball/hit-1.wav`, `ball/hit-2.wav` | variations, picked at random, never the same twice in a row |
| `ball/hit@1.wav` … `ball/hit@3.wav` | soft to hard, for events marked *layers* |
| `ball/hit@2-3.wav` | layer 2, variation 3 |
| `nature/pearl_n00.wav` … `_n11` | the notes of a *pitched* event, in semitones above the root. Without them, the plain file is pitch-shifted up the scale |

- **3D events** (marked 3D on the sheet) are placed in the world. Record them in mono.
- **Loops** (ids ending `_loop`) must loop cleanly from end to start.
- Trim the silence at the start. The sound plays the moment the thing happens.
- Record dry. The game adds the underwater muffle and reverb (a profile can turn this
  off).

## profile.cfg (optional)

```ini
[profile]
name="A Cappella"
author="Matthew"
description="Every sound is a voice."
root_note="D"               ; the note plain pitched files are recorded at
scale="major_pentatonic"    ; major, minor, major_pentatonic, minor_pentatonic, blues, dorian, chromatic, whole_tone
underwater_filter=true      ; false = play exactly as recorded

[mix]
"ball/hit"={ "volume_db": -2.0, "pitch_jitter": 0.05 }
"unnatural/zombie_die"={ "voices": 6 }
```
