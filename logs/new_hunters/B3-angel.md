# B3-angel log
1. Read plan, rig/jaw/form/lock_attack, AttackExaggerate. Angel has no hinged jaw: channel mapping chosen = jaw -> crown (reach/splay/root radius), limb -> wings (span + flare angle), throat -> halo ring + organ glow + crown light, head -> whole-body z lunge stretch pivoted at the tail. tail channel unused (stride exaggeration stays).
2. Second kit instance (ex_lash) released on HunterBite.landed so the tentacle lash snaps out at contact (press->release lands ~0.1 s later, the main kit has settled by then).
3. Beats come from HunterBite signals (opened, released, aborted, landed); hold(charge) every frame while holding.
4. Built: angel_rig.gd wired (kits, signals, wings flare/span, crown reach+splay, ring/glow burst, body lunge about the tail, lash via ex_lash, camera_margin()). Tuned after strips: wings release 1.85, body 1.28, lash cap 2.4x.
5. b3_angel_probe: 23 checks pass headless; strips reviewed (crown starburst and lash obvious; wings are small/pale so the crown+body carry the read). Release snap is one-frame by design (step ~0.4-0.8), threshold 1.2.
6. Open: camera should use rig.camera_margin(); settings hunter_* not registered yet (rig falls back to defaults).
