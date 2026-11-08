# A3-lamprey-lunge log
1. Found the lunge: DrillAttack._start sets dash speed = top speed x drill_dash x charge, held for drill_time. No lamprey_lunge_impulse existed.
2. Added DrillAttack.lunge_impulse(settings): multiplier on dash speed, default 0.55; reads panel setting lamprey_lunge_impulse, falls back to a meta of the same name, then the default (so it works before registration). The speed cap lift (_raised) now follows the real speed.
3. Probe tests/lamprey_lunge_probe.gd: measured at the dash end. Old 33.1 m, new 18.2 m (55%), 0 -> 0 m, 1.5 -> 49.7 m. All pass.
4. Finding: if measured after 1.5 s of coast it reads 80%, because velocity stays at top speed after the dash and the old 2x was clamped back to 1x. Decision: lunge = dash travel; coast is normal swim momentum, left alone (no velocity bleed added).
5. Blocker/note: tests/drill_probe.gd (not mine) asserts attack.speed == base * drill_dash and the cap lifted by drill_dash; those two checks will now fail (speed is x0.55). Edit needed: multiply by DrillAttack.lunge_impulse(settings).
