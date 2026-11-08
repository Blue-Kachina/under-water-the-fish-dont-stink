# B5-king log
1. Read plan, kit (attack_exaggerate.gd), king_rig.gd (A2's edits present, not mine), coil_attack, king jaw/form. King_rig is off-limits, so the exaggeration is a Driver Node added by king_of_herrings.dress() as a child of KingRig (processes after it): it post-bends rig.rig.points (extra curl, tail stretch, whip lag), re-poses riders, scales eyes/lampreys, drives the jaw hinge multiplier through king_jaw.gd.
2. Finding: spine shader normalises the frame vectors, so tail thinning (volume) is not possible without a shader change; tail only stretches.
3. Finding: hunter_bite_fx already does a camera punch and controls hit-stop on landed; the kit's camera_punch is forwarded additively.
4. Built forms/king_exaggerate.gd (driver), king_jaw.gd gape x kit jaw scale, coil_attack.gd: press floor 0.4 (setting coil_press_floor) and a coil unwind over strike+shake (was 0.11 s drop).
5. Strip (top/iso: rest, press, hold, release, settle) reviewed: straight -> curved -> tight coil -> long whipped tail -> straight. Tail thinning impossible (shader normalises frames).
6. Pop: plain game already moves the tail tip ~3-5 m/frame at release (0.07 s strike); ours up to ~2x that with stretch. Lag gain trimmed to 0.45.
