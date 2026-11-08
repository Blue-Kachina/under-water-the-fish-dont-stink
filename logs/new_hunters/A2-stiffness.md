# A2-stiffness log
1. Read plan; flex sources: shader spine_wave amplitude (king_rig/lamprey_rig _swim_look) and the trail-following bend (SpineRig.follow_trail, shared, untouched).
2. Added body_stiffness (0 = old body, 1 = rigid; default 0.4 = 0.6 of the old flex) read tolerantly via WhatStinksSettings.get("body_stiffness") (fallback 0.4 until registered); `stiffness_override` var for probes.
3. Wave amplitude x (1 - stiffness). Wave wavelength, tail ramp (w) and fin flutter untouched, so the head/tail stride look stays.
4. _stiffen(): after follow_trail, blend each spine point toward the straight line from the head along the fish's tail direction (ramped in over the first 35% of the body), ease the direction/offsets in time (damping 30/s down to 8/s), resample by arc length along the blended curve (tail runs on straight past its end). Early version re-spaced cumulatively and jittered (1.3 m/frame spikes); resampling fixed it.
5. tests/stiffness_probe.gd: tight boosted circle, stiffness 0/0.4/1: tail bend 13.8/8.4/3.9 m (king), 12.2/7.6/3.5 (lamprey), jitter equal to old, segment error <= 3 mm. king_probe 81/0, lamprey_form_probe 86/0.
6. Not done: visual strip/model_shots comparison (numeric only); stiffened default feel needs play-test.
