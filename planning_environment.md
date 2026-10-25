# Unnatural: the environment and look pass

Planned 2026-10-25 from your brief: make Unnatural's world more appealing. The game should
look finished, but release-build work isn't part of this pass.

## Status
Planned 2026-10-25. Phases 1–8 are being built in order. Each phase ends with probes and a
debug build.

## Decisions (interview, 2026-10-25)
| # | Question | Answer |
|---|---|---|
| E1 | "Production ready" | Make the game look good. No release-build, store or robustness work |
| E2 | Uneven seabed, ramps up to raised surfaces | **Parked** |
| E3 | Flora mood | **A lush, living reef** under the blood moon |
| E4 | Shrines: how to find them | **Compass and minimap only.** No beam; a faint glow up close, hidden by the murk further out |
| E5 | Compass | **Both:** a compass ring on the minimap's rim, and a heading strip across the top of the screen |
| E6 | Ruins | **Scattered rubble, plus 3–5 small ruin clusters.** Each shrine is its own small temple |
| E7 | Chests in reach | **All of them count down.** Jump opens the closest. Once it's looted, the next unlocked one still in reach opens |
| E8 | Basic-geometry effects | **Audit everything** in Unnatural and redo it with FxKit |
| E9 | Sound list | **Revise planning_audio.md** in place |
| E10 | Process | Plan doc, then build it all |

## House rules
- Every number goes in the panel with a wide range, and 0 switches it off.
- Every model is one seamless, smooth-shaded mesh with PBR materials, held to
  `3D_Character_Art_Quality_Standards.md`. Nothing should look like stacked primitives.
- The seabed is built from the seabed seed, so every co-op machine lays out the same world.
- Performance: the horde is GPU-bound. Every new piece of scenery is a chunked
  MultiMesh (see "Chunked scatter") that's culled beyond the murk, and its triangle counts are measured on
  `horde_bench` and `split_bench`.

---

## Phase 1. Chests count down together (E7)
Today `_open_chests` keeps one `holding` chest per fish. Only the last chest the loop finds
fills, and a second one only starts after the first unlocks.
- While a fish holds still, every chest within `chest_reach` that it can afford fills at the
  same time. Each chest already keeps its own progress per fish, and the HUD already draws a
  ring per chest.
- The fish counts as "opening" (`is_picking`: untouchable and unseen) while any of those chests
  is still filling.
- Jump opens the closest unlocked chest (`open_unlocked`, unchanged).
- **Chain:** when the cards from a chest are closed (picked, skipped or cancelled), the next
  unlocked chest still in reach opens straight away (`chest_chain_open`, on by default).
  Cancelling with B doesn't chain: you backed out.
- Probe: `chest_multi_probe`. Two and three chests in reach fill together; Jump opens the
  closest; the next opens after the pick; B stops the chain.

## Phase 2. A compass (E5)
North is world −Z everywhere, on both the ring and the strip.
- **Ring on the minimap:** a bezel just outside the minimap's rim with a tick every 15°, longer
  ones every 45°, and N, E, S, W. N is the coral accent. The ring turns with
  `minimap_heading_up`. The marks already pinned to the rim (bosses, whirlpool) stay.
- **Strip across the top:** a heading strip centred under the XP bar, `compass_width` of the
  view wide (0.42) and showing `compass_fov` degrees (150). It has the same ticks and letters,
  plus markers:
  - discovered shrines: a diamond in their colour, pulsing while a Tide runs;
  - bosses: a skull;
  - the whirlpool: a spiral;
  - teammates: an arrow in their colour, or a cross while they're down;
  - your chests within `chest_ping_range`: a box.

  Markers past the strip's edge stick to its end as a half-icon. Each marker shows its
  distance in metres under it. The clock, kills and boss bar move down to make room.
- Settings, in a new **UNNATURAL > Compass** group: `compass_ring`, `compass_strip`,
  `compass_width`, `compass_fov`, `compass_opacity`.
- Probe: `compass_probe`. It checks the heading maths, the edge pinning, and which markers
  show. Screenshots: `compass_shots`.

## Phase 3. A Greek kit and the shrines (E4, E6)
### 3.1 `GreekKit` (scripts/unnatural/scenery/greek_kit.gd)
These are procedural mesh builders, each cached once per run:
- **Column drum:** a lathe with 20 Doric flutes (sharp arrises, soft hollows). It can be
  built whole or broken with a jagged top. Also a **capital** (an echinus and an abacus, Doric
  or Ionic with volutes) and a **base** (a torus and a plinth).
- **Fallen column:** 3–4 drums lying offset along a line, as one merged mesh.
- **Blocks:** stylobate steps, architrave and frieze blocks with a triglyph pattern, a
  pediment shard. Each block gets bevels and chipped corners from noise displacement.
- **Amphora and krater:** lathed pots with handles (bent tubes). Some are broken.
- **Statues:** a draped figure in a chiton, lofted from cross-sections with the folds
  displaced along the body. Like most real ancient statues, they're weathered and broken:
  arms missing, and some heads missing. The attribute each holds is modelled separately. Also
  a colossal head lying on its side, and a colossal foot.

  **Limitation (per the standards doc):** procedural statues can carry a silhouette, folds
  and weathering, but not a sculpted face or hands. That's why they're fragments, and why the
  faces are worn smooth. If they fall short in the shots, the proper fix is sculpted assets
  (Blender/ZBrush, glTF). I'll flag that rather than lower the bar.
- **Marble shader** (`shaders/marble.gdshader`):
  - weathered white-grey marble with veining and pitting;
  - green-brown algae creeping over upward-facing surfaces;
  - pink coralline crust at the base;
  - darker grime in the hollows, taken from the mesh's baked vertex AO.

### 3.2 Shrines become temples
Each shrine is a small round **tholos**, sized so its Jump reach still covers it:
- a 3-step round platform, a ring of 6 columns (some broken, one fallen) and a broken
  architrave ring;
- a statue on a plinth in the middle, and a bronze brazier in front of it that burns in the
  shrine's colour.

| Shrine | Statue | Attribute |
|---|---|---|
| Tide | Poseidon | a trident |
| Chance | Tyche | a cornucopia and a wheel |
| Deep | Hades | a bident, with a dog at its feet as a simple sculpted form |
| Pearls | Aphrodite | standing in a scallop shell, a pearl in her hand |

- **Visibility (E4):** the beam goes, and so does the fog-free glow. The brazier's flame and
  light obey the fog, and the light reaches 7 m. From about 40 m in murk a shrine is a dim
  shape, the way ruins are. A spent shrine's brazier goes cold.
- **Discovery:** a shrine joins the minimap and the compass once any player has come within
  `shrine_reveal_range` m (60). It stays shown for the rest of the stage, for the whole team.
  At 0 shrines always show, as they do today.
- The Tide's ring becomes a ring of carved stone on the sand that lights up, instead of a
  torus.
- Probe: `shrine_probe` gets reveal checks. Screenshots: `scenery_shots --what=shrines`.

## Phase 4. Ruins and rubble (E6)
- **Rubble everywhere:** drums, capitals, block chunks, potsherds and amphorae, half-sunk in
  the sand at random angles, scattered thinly (`ruin_rubble`, 220). Each kind is one
  chunked MultiMesh (see "Chunked scatter").
- **3–5 clusters** (`ruin_clusters`, 4), each a temple footprint 14–24 m across:
  - a stylobate platform, a colonnade on 1–2 sides with columns standing, broken and fallen,
    and a stretch of architrave across the standing ones;
  - a statue or colossal fragment;
  - rubble thickening towards it;
  - the reef growing over all of it (Phase 5).
  
  Clusters keep clear of the start, of each other, and of the shrines (shrines are placed
  after the seabed and avoid `seabed.cluster_spots`).
- **No collision**, matching today's rocks and kelp. Solid scenery belongs with the parked
  terrain (E2).
- Probe: `scenery_probe`. It checks that the same seed gives the same layout, the cluster
  spacing, and the instance counts. Screenshots: `scenery_shots --what=ruins`.

## Phase 5. A lush reef (E3)
These replace today's sphere rocks and box kelp:
- **Sand:** a sand shader with wave ripples (normal-mapped), a little shell grit and colour
  patches.
- **Rocks:** lofted, noise-displaced boulders and flat slabs in 3 shapes. Encrusting coralline
  and algae on their tops come from the same rule as the marble.
- **Kelp:** a real giant kelp. One stipe carries fronds (tapered, rippled membranes) on small
  float bladders, swaying with its height (`kelp.gdshader`, extended). It grows in forests
  of clumps.
- **Sea grass** meadows: dense, short blades with a shared sway.
- **Corals:**
  - staghorn: branching tubes grown by an L-system;
  - brain and boulder coral: a displaced dome with a meandering groove shader;
  - table coral: a flat plate on a stalk;
  - fan coral (gorgonian): a lattice membrane that uses `fin_membrane`'s idea;
  - tube and barrel sponges.
  
  Colours: purple, orange, yellow, pink and teal, at full saturation. They sit inside the red
  murk, so the reef shows where it's lit.
- **Anemones:** a tuft of tentacles swaying, some with glowing tips (a little emission, fog on).
- **Small life:** starfish, urchins and clam shells, very small and scattered.
- Placement:
  - reef patches (noise-driven) cluster corals, anemones and sponges together, with open sand
    and sea-grass meadows between them;
  - kelp forests in a few bands;
  - the ruins are overgrown;
  - the edge keeps its outcrops (now real rocks) and its kelp wall.
- Settings, in a new **UNNATURAL > Seabed** group (replacing Arena's rocks and kelp): `reef_density`, `kelp_forests`,
  `seagrass`, `corals`, `anemones`, `small_life`, `scenery_draw_distance` (0 = follow the
  murk), `scenery_fade`.

### Chunked scatter (shared by Phases 4–5)
The arena is cut into 32 m tiles. Each tile has one MultiMeshInstance3D per mesh kind, with a
`visibility_range_end` from the murk's density (`scenery_draw_distance`) and a fade margin.
Godot's mesh LODs then work, because each tile's bounds are small. LOD meshes come from
`SchoolLook.detail_meshes`'s cut logic.

Bench: `horde_bench` and `split_bench` report frame time before and after. The target is
under 1.5 ms extra GPU at 1 player, and the 3-player split view still above 100 fps.

## Phase 6. Effects audit (E8)
Every Unnatural visual that's still a plain sphere, torus, cylinder or box, by priority:

| Effect | Today | Becomes |
|---|---|---|
| **Hazard clouds** (`BurstCloud`): Burning elite fire, Cinder Lionfish fire, Electric elite shock, Sour Sea Hare haze, Bloated burst, Lamprey blood cloud, hagfish slime | one tinted sphere | a style per cause: **fire** is licking flames on the sand (Greek Fire's patch look) plus embers; **shock** is a crackling cage of jagged arcs that flickers faster while armed, then a white flash; **haze, slime, blood and bloated** are billowing soft puffs (FxKit soft billboards). Every one gets a faint ground ring at its true radius, so the danger edge reads |
| **Tsunami Heart wave** | an open cylinder | a curling wave lofted across its width (a cross-section that curls over), a foam crest, spray off its ends, and a fresnel water shader |
| **The whirlpool** (the way out) | stacked torus rings | a funnel lofted from the seabed to the surface with a spiral streak shader, foam bands, and debris and bubbles circling in |
| **Whirlpool Charm's vortex** | torus | the same funnel, small and low |
| **Drops** (heart, magnet, hourglass, lightning) | boxes, cones, a torus | a modelled token for each: a faceted glass heart, a horseshoe magnet, a brass and glass hourglass with flowing sand, and a lightning-bolt crystal. The halo and beam stay |
| **Treasure chests** | 3 boxes | a proper chest: a barrel lid lofted, plank grooves and wear in a wood shader, iron or gold bands, studs and a lock plate. The cursed one has bone trim, the boss one steel |
| **Boss spit bolts** (Leviathan, Gulper, Lamprey, Fallen Angel) | spheres | a glowing globule (FxKit rim shell) with a tapered ribbon tail and a wobble |
| **Worn items** (25 `make_worn` builders) | stacked primitives | rebuilt with a small `WornKit` (lathe, loft, tube along a curve, shared shell, metal, glass and organic materials). Each item keeps its idea (barnacles, shell, seahorse, trident...), but as one smooth mesh |

Already fine, and left alone: everything that went through FxKit in the Arsenal FX pass, the
Explosion, kill pops, telegraphs, the blood moon, and eyes.

Checks: `fx_tour` gains the new hazards, the wave, the whirlpool and the drops. `fx_bench`
and `torpedo_bench --build` must not get slower.

## Phase 7. The sound list (E9)
`planning_audio.md` §3 is revised in place. It covers everything added since 2026-10-18:
- the 4 new classes' weapons (Cavitation Punch, Purple Haze, Jellyfish Halo as a starting
  weapon, Remora Buddy);
- 11 mobility skills, gait sounds (a bell pulse, a whale fluke), the 24 items added since;
- shrines (each kind's use, a Tide's waves, a Chance win or loss), elite modifiers, swarm
  events (SURVIVE), the Lightning drop;
- rerolls, skips and banishes, unlocking a chest, the 4 final bosses and the Fallen Angel, the
  new zombie behaviours (school, drift sting, punch, whale calf, sea-hare cloud);
- the whirlpool, the compass reveal, and the new scenery's ambience (kelp creak, reef crackle).

Each row is marked **hooked** (it plays now if the file exists), **id only** (in the catalog,
not hooked yet) or **new** (this pass adds the id). New ids go into `SoundCatalog`, so
**Write recording sheet** lists them. Hooking the easy ones is part of this phase.

## Phase 8. Checks and build
- The probe suite, the new probes, and screenshots of every new piece of scenery
  (`scenery_shots`, `compass_shots`, `fx_tour`), checked by eye against the standards doc.
- `INVENTORY.md` gets no changes unless numbers move. `setting_docs` is regenerated.
- A debug build in `builds/windows`.

## Open items (for you to close)
- E2 terrain stays parked. When it comes back, the ruin clusters' platforms are natural
  plateaus with steps as ramps.
- If the procedural statues aren't good enough at gameplay distance, they need sculpted assets.
