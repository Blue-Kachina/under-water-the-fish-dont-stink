# B4-gulper log

1. Read the kit (attack_exaggerate.gd), gulper rig/jaw/mother/suction_attack, hunter_bite signals.
2. Wired AttackExaggerate into gulper_rig.gd. Beats come from HunterBite signals: opened -> press, released -> release(charge), landed -> contact(share), aborted -> abort; hold(bite.charge()) each frame while held. The rig's own clock (follow lag, gape ease) runs on tick()'s hit-stop-aware dt. Camera punch goes to ChompKit.view_camera(fish).punch (local fish only).
3. Channels (preset EXAGGERATE in the rig; snap_omega 30 / zeta 0.7 so the girth rebound is smooth): jaw (pouch gape, pinches 0.55 on the press, 2.3 on the hold, 0.5 on the release), body (girth: puff 1.14, deflate 0.7 on the hold, rebound 1.3 on the gulp; length inversely by ^-0.3), throat (gulp bulge x2.4 on release, rings out).
4. Shader gape is driven as base + (jaw-1)*1.1, clamped to [-0.22, 4]; the shut ease is now 24/s (was 6) so the snap reads. Tap mode keeps the old landing balloon. Eyes and lure ride the body scale. The gulp lump (shader lump.z) is multiplied by (throat + strength*0.6).
5. Decision: shader file not touched; everything done through existing uniforms and the mesh node scale.
6. Probe tests/b4_gulper_probe.tscn: 22 checks, 0 failed (pinch 0.02 from 0.15, puff 1.18, sail gape 2.70 vs 1.25 before, deflate 0.70, rebound 1.34, hit-stop 3 ticks, camera margin 2.3, lump 1.62 vs 0.50 plain, master 0 exactly rest). Run twice for flaky lump placement: made it retry across schools.
7. Strip logs/new_hunters/b4_shots/gulper_strip.png reviewed (rest/press/hold/release/settle): sail and deflate are obvious, the clamp is clear, settle returns.
8. Finding: a transient parse error from another worker's fish_controller.gd (_angle_shown) appeared once mid-run; unrelated.
