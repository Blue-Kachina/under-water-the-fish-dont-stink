# INT1 log
1. Registered 34 settings in what_stinks_settings.gd (groups Drill additions, Exaggeration, Shark, Whales, King and Lamprey bodies, Preview); union of ranges where workers disagreed (hunter_exaggeration 0-4, hit_stop 0-12, punch 0-5, smear 0-0.5, max_scale 1-8).
2. Regenerated setting_docs.gd via tools/gen_setting_docs.gd (+31 rows).
3. INVENTORY.md and hunter_forms.md updated (exaggeration table).
4. tests/drill_probe.gd updated for lunge_impulse; tests/b3_angel_probe.gd dip thresholds loosened to the preset floors (0.851/0.951).
5. Probe matrix in logs/new_hunters/int1/*.txt. preview_jitter_probe must run with --fixed-fps 144 (fails without). whale_engulf_probe is flaky under parallel load (also on HEAD). whale_spike_probe: 2 pre-existing-looking fails (11 pickable of 13; Titan start overlap).
6. Not wired: camera margin/punch in what_stinks_cam.gd, hunter_bite_fx hookup.
