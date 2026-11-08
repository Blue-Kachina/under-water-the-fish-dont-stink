# B0-exaggerate-kit log

1. Read plan (planning_new_hunters.md phase B), hunter_bite_fx.gd (existing punch/hit-stop pattern: ChompKit view camera `punch`, local hit-stop on hunter controls).
2. Built scripts/what_stinks/attack_exaggerate.gd (class AttackExaggerate, RefCounted, pure maths). Damped-spring channels jaw/head/tail/limb/throat, phases IDLE/ANTICIPATE/HOLD/SNAP/SETTLE, substepped at 120 Hz (stable at 0.5 s steps).
3. Decision: multiplier applied at OUTPUT (1+(raw-1)*k) so live setting changes are smooth; master 0 is exactly 1.0. Clamped by min_scale/max_scale (camera safety).
4. Decision: hit-stop is frame-counted in tick() with a ~5% time scale and is separate from release(): rigs call contact() on HunterBite.landed. Camera punch is a signal (no camera ownership).
5. Finding: Basis has no subtraction in GDScript; built the axis-stretch matrix from columns.
6. Finding: import run shows parse errors in other workers' files (stiff/raw/n/head/dir identifiers); not mine.
7. tests/exaggerate_probe.tscn: 31 checks, 0 failures. Snap is deliberately fast (0.25/tick at 120 Hz for jaw 2.0 -> 0.8); ring-out max 0.0245/tick, overshoot 1.05.
8. Not done: no rig wiring (per-form workers B1-B6), no settings registered (shared files).
