# Titan spec sheets (adult whales)

The targets the five Titan models are built and measured against (planning_marco_whales.md §6, §6a
step 1). Written before any mesh. `tools/model_measure.gd` reads the built meshes back and prints
each number below next to its target. **Pass: every measured ratio within ±10 % of its target.**

Class key `titan`. Species keys, in order: `humpback`, `orca`, `beluga`, `sperm`, `blue`. Skins
(variants within a species, index 0 the default) are listed per species below.

## How the numbers are defined (what model_measure reads)

All lengths are fractions of **L, the standard length**: snout tip to the fluke notch, which is
how whale morphometrics are taken. In the model, L is the `Body` mesh's length along Z (the body
mesh ends at the notch; the flukes are separate meshes behind it). "Along" is the distance back
from the snout tip, also over L (0 snout, 1 notch).

| Key | What it is | How it's measured |
|---|---|---|
| `eye_at` | eye centre, along | the `Eye` nodes' position |
| `eye_up` | eye height in its slice, 0 belly to 1 back | eye y against the Body slice's bottom/top at that z |
| `pec_at` | flipper root (insertion), along | the flipper pivot's position |
| `pec_len` | flipper length, root to tip | farthest flipper vertex from its pivot |
| `pec_chord` | flipper's widest chord | widest flipper cross-section (vertices binned along its span) |
| `fluke_span` | fluke tip to tip | X extent of the `Fluke` meshes |
| `fluke_sweep` | how far the fluke tips trail the notch | fluke tips' Z behind the body's end |
| `dorsal_at` | dorsal fin (or hump / ridge) peak, along | highest `Dorsal` vertex (body relief for the beluga/sperm) |
| `dorsal_h` | its height above the back | that peak above the Body's top without it |
| `max_w`, `max_d` | the body's full width / depth at its biggest | Body vertices binned along Z |
| `max_d_at` | where the body is deepest, along | as above |
| `w10`…`w90`, `d10`…`d90` | full width and depth at the 5 stations (along 0.1, 0.3, 0.5, 0.7, 0.9) | Body vertices in a thin bin at each station |
| `stock_at` | where the tail stock starts: first slice past 0.55 where width / depth < 0.75 (laterally compressed) | from the binned slices |
| `jaw_len` | sperm whale only: lower jaw length | Z extent of the `Jaw` mesh |

Things that can't be read back as a single number (the head's outline, pleats, patches, tubercles,
barnacles) are checked on the shots (§6a step 3) against the ranked features below.

The hitbox is A's (contract 2). The model is built from the hitbox's **length only**: width and
depth follow the species' anatomy, so the ratios hold whatever the hitbox's width and height.
model_measure prints each species' natural width and depth so A can size the hitbox to match.

## Sources

Ratios are from the standard whale morphometrics where they exist, rounded:
- Woodward, Winn & Fish 2006, *Morphological specializations of baleen whales associated with
  hydrodynamic performance and ecological niche*, J. Morphology 267 (blue, humpback flipper and
  fluke spans as proportions of body length).
- Clark & Odell 1999, *Allometric relationships and sexual dimorphism in captive killer whales*,
  J. Mammalogy 80 (male orca flipper and dorsal fin).
- Sperm whale head share at 25–36 % of length (larger in mature males); fluke span about 5 m on
  16 m (National Museum of Nature and Science, Tokyo, pictorial book; Sea Watch Foundation).
- Beluga and blue whale fact sheets (Sea Watch Foundation; SeaWorld): beluga's small paddle
  flippers and overhanging melon, the blue's flippers at about 12–15 % and its tiny dorsal more
  than two-thirds of the way back.

Cross-sections are read off standard side and top-view plates of each species (adult). Where a
figure is a judgement (the station widths), that's said; they're still the targets.

---

## 1. Humpback (hero) — `humpback`

Adult about 13–15 m. Bulky and knobbly, with the longest flippers of any whale.

**Proportions (over L)**

| Key | Target | Note |
|---|---|---|
| eye_at | 0.23 | just above and behind the mouth's corner |
| eye_up | 0.35 | low on the head |
| pec_at | 0.28 | |
| pec_len | 0.30 | about a third of the body (Woodward 2006: 0.29–0.33) |
| pec_chord | 0.065 | narrow: length about 4.5× its chord |
| fluke_span | 0.32 | Woodward 2006: about a third |
| fluke_sweep | 0.07 | swept tips |
| dorsal_at | 0.64 | small fin on a hump, two-thirds back |
| dorsal_h | 0.025 | (hump and fin together) |
| max_w / max_d | 0.21 / 0.24 | |
| max_d_at | 0.36 | just behind the flippers |
| stock_at | 0.70 | |

**Stations (full width / full depth, over L) and section shape**

| Along | W | D | Shape |
|---|---|---|---|
| 0.1 | 0.10 | 0.07 | rostrum: flat, broad, gently rounded top, tubercles |
| 0.3 | 0.20 | 0.23 | throat: deep belly with pleats, rounded oval |
| 0.5 | 0.19 | 0.22 | round oval, belly flatter |
| 0.7 | 0.11 | 0.15 | narrowing, back and belly keels starting |
| 0.9 | 0.03 | 0.07 | tail stock: tall and thin, keeled top and bottom (diamond) |

**Colour map**
- Back and flanks black to slate (`23262b`–`3a3e45`). Belly white to mottled grey, varies by
  skin; the edge is ragged, not a clean line.
- Throat pleats (about 20 to 35 visible grooves) from chin to navel (along 0.5), paler in the
  grooves.
- Flippers: white undersides and leading edge, top white or black by skin; tubercles along the
  leading edge.
- Fluke underside: a black-and-white pattern unique per skin (the ID pattern), serrated trailing
  edge. Top of the flukes black.
- Barnacle clusters (acorn barnacles, pale cream-grey bumps in tight clumps) on the chin, the
  flipper leading edges, the fluke tips and the throat. White rake and cookie-cutter scars on
  the flanks.

**Recognisable features, ranked**
1. Very long, narrow, white flippers with scalloped leading edges (tubercles).
2. Knobbly head: tubercles in rows on the rostrum and the lower jaw.
3. Ventral throat pleats to the navel.
4. Small dorsal fin on a hump two-thirds back; the knuckles behind it.
5. Flukes with a serrated trailing edge and a black-and-white underside.
6. Barnacle clusters and scars.

**Skins:** `atlantic` (0, black with a mostly black belly and fluke underside, white flippers),
`southern` (1, white belly running up the flanks, mostly white fluke underside),
`pacific` (2, grey-mottled belly, mixed fluke underside, black-topped flippers).

---

## 2. Orca — `orca`

Adult male about 8–9 m. Sleek and powerful, crisp black and white.

**Proportions (over L)**

| Key | Target | Note |
|---|---|---|
| eye_at | 0.13 | just above the mouth's corner, in front of the eye patch |
| eye_up | 0.40 | |
| pec_at | 0.18 | |
| pec_len | 0.18 | male: big rounded paddles (Clark & Odell 1999) |
| pec_chord | 0.10 | broad: length about 1.8× its chord |
| fluke_span | 0.25 | |
| fluke_sweep | 0.05 | |
| dorsal_at | 0.45 | mid-back |
| dorsal_h | 0.20 | male: a straight, tall triangle, up to 1.8 m |
| max_w / max_d | 0.17 / 0.21 | |
| max_d_at | 0.40 | |
| stock_at | 0.66 | |

**Stations**

| Along | W | D | Shape |
|---|---|---|---|
| 0.1 | 0.10 | 0.10 | short blunt rounded head, no beak |
| 0.3 | 0.17 | 0.20 | round, deep |
| 0.5 | 0.16 | 0.19 | round, deep |
| 0.7 | 0.09 | 0.14 | oval, laterally compressed |
| 0.9 | 0.03 | 0.07 | tail stock, keeled |

**Colour map**
- Glossy black back, flanks and flippers (`121316`).
- White: the oval eye patch above and behind the eye (crisp edge), the chin and throat, a belly
  band that narrows between the flippers then widens, and a lobe sweeping up the flank behind the
  dorsal fin. Fluke underside white with a black edge.
- Grey saddle patch behind the dorsal fin (soft edge), by skin.
- Skin is smooth and glossy: a clearcoat look, few blemishes.

**Recognisable features, ranked**
1. Tall, straight dorsal fin (male).
2. White eye patch and white chin/belly with crisp edges.
3. Grey saddle patch.
4. Large rounded paddle flippers.
5. Glossy skin.

**Skins:** `resident` (0, standard eye patch, clear grey saddle), `biggs` (1, transient: more
pointed fin tip, uniform grey saddle, eye patch further back), `antarctic_b` (2, a grey cape
over the back, yellowish diatom tint on the white, large eye patch).

---

## 3. Beluga — `beluga`

Adult about 4–5 m. Stout, white, a soft forehead and a supple neck.

**Proportions (over L)**

| Key | Target | Note |
|---|---|---|
| eye_at | 0.11 | |
| eye_up | 0.42 | |
| pec_at | 0.18 | |
| pec_len | 0.12 | small, broad paddles that curl up at the tips with age |
| pec_chord | 0.065 | |
| fluke_span | 0.22 | deeply notched, rounded trailing edge |
| fluke_sweep | 0.05 | |
| dorsal_at | 0.60 | the dorsal ridge's highest point (no fin) |
| dorsal_h | 0.008 | a low ridge |
| max_w / max_d | 0.22 / 0.24 | |
| max_d_at | 0.45 | |
| stock_at | 0.74 | |

**Stations**

| Along | W | D | Shape |
|---|---|---|---|
| 0.1 | 0.13 | 0.14 | melon: a rounded bulb overhanging a short beak |
| 0.3 | 0.21 | 0.22 | round, the neck crease just in front (about 0.2) |
| 0.5 | 0.22 | 0.24 | round, a little wider low down |
| 0.7 | 0.13 | 0.16 | oval |
| 0.9 | 0.035 | 0.07 | tail stock |

**Colour map**
- White all over (`e8ecea`), creamy or yellowish by skin; a soft subsurface look, matte.
- Fluke and flipper edges a little darker (grey-brown in the yellow skin).
- Fine wrinkles and creases on the neck; faint scratch scars on the back.
- The dorsal ridge sometimes darker (scuffed).

**Recognisable features, ranked**
1. White skin.
2. Rounded melon overhanging a short beak (mobile: it swells with the call).
3. No dorsal fin, a low ridge instead.
4. A visible neck crease (the head turns).
5. Small upturned paddle flippers.

**Skins:** `white` (0, adult white), `cream` (1, pre-moult yellowish), `scarred` (2, white with
grey scratch scars and a darker ridge).

---

## 4. Sperm whale — `sperm`

Adult male about 15–16 m. The box head, wrinkled skin.

**Proportions (over L)**

| Key | Target | Note |
|---|---|---|
| eye_at | 0.30 | behind the mouth's corner, low |
| eye_up | 0.30 | |
| pec_at | 0.34 | |
| pec_len | 0.10 | short, broad paddles |
| pec_chord | 0.05 | |
| fluke_span | 0.30 | broad triangles (about 5 m on 16 m) |
| fluke_sweep | 0.06 | |
| dorsal_at | 0.64 | the hump |
| dorsal_h | 0.02 | |
| max_w / max_d | 0.17 / 0.20 | |
| max_d_at | 0.30 | |
| stock_at | 0.70 | |
| jaw_len | 0.22 | narrow underslung jaw |

The head (snout to the end of the box, about where the eye sits) is about a third of the body: a
male's 35 %, judged on the shots.

**Stations**

| Along | W | D | Shape |
|---|---|---|---|
| 0.1 | 0.12 | 0.17 | the box: flat-fronted, squared top, sides nearly flat |
| 0.3 | 0.17 | 0.19 | the head's end: still boxy above, the jaw under it |
| 0.5 | 0.17 | 0.19 | round, belly rounded |
| 0.7 | 0.10 | 0.13 | narrowing, the knuckles along the back |
| 0.9 | 0.03 | 0.06 | tail stock, a ventral keel |

**Colour map**
- Dark slate grey to brownish (`3a3c3f`), lighter on the belly; white lips and inside the mouth's
  edge; sometimes white patches on the belly.
- Deep wrinkles over the body behind the head (the "prune" skin), smoother on the head itself.
- Circular sucker scars (squid) and long scratches on the head, by skin.
- Single S-shaped blowhole at the front left of the head.

**Recognisable features, ranked**
1. The huge squared box head, a third of the body.
2. The narrow underslung lower jaw, with white lips.
3. Deeply wrinkled skin behind the head.
4. A low hump two-thirds back, then a row of knuckles down to the flukes.
5. Broad triangular flukes.
6. The blowhole at the front left.

**Skins:** `grey` (0, dark slate), `scarred_bull` (1, a scar-whitened head with sucker rings),
`brown` (2, brownish, paler belly).

---

## 5. Blue whale — `blue`

Adult about 24–27 m. Long and slender, mottled blue-grey.

**Proportions (over L)**

| Key | Target | Note |
|---|---|---|
| eye_at | 0.22 | just behind the mouth's corner |
| eye_up | 0.35 | |
| pec_at | 0.28 | |
| pec_len | 0.12 | slender (fact sheets: 12–15 %; Woodward 2006) |
| pec_chord | 0.035 | |
| fluke_span | 0.25 | |
| fluke_sweep | 0.06 | |
| dorsal_at | 0.77 | tiny, far back (more than two-thirds) |
| dorsal_h | 0.012 | |
| max_w / max_d | 0.14 / 0.15 | |
| max_d_at | 0.40 | |
| stock_at | 0.74 | |

**Stations**

| Along | W | D | Shape |
|---|---|---|---|
| 0.1 | 0.09 | 0.05 | broad, flat U-shaped head, a median ridge |
| 0.3 | 0.14 | 0.15 | round, pleated throat |
| 0.5 | 0.13 | 0.14 | round |
| 0.7 | 0.08 | 0.10 | oval |
| 0.9 | 0.025 | 0.05 | tail stock |

**Colour map**
- Mottled blue-grey (`4a5a6c` with `9aacbc` mottles), lighter on the flanks, the mottling large
  and irregular.
- Paler belly; throat pleats to the navel (along 0.5), many and fine.
- Flipper undersides and tips paler.
- The splashguard: a raised ridge in front of the paired blowholes.

**Recognisable features, ranked**
1. Long, slender body; the head a broad flat U from above.
2. Mottled blue-grey skin.
3. Tiny dorsal fin far back.
4. The splashguard at the blowholes.
5. Long throat pleats.

**Skins:** `mottled` (0, light blue-grey, strong mottles), `dark` (1, darker slate blue),
`sulphur` (2, a yellowish diatom film on the belly: the "sulphur bottom").

---

## Shared to all five (the adult look, not a calf)

- **Not a scaled-up calf.** Longer and leaner, smaller head (except the sperm whale), a long
  keeled tail stock, flukes a quarter to a third of L.
- **Eyes.** Small (eye diameter about 1 % of L or less), sunk into the skin with a skin fold, a
  lid and a wet highlight. They read as old and poor-sighted.
- **LODs.** 3 levels: full (LOD0), about half the slices and points round (LOD1), about a
  quarter (LOD2). Fins get fewer columns too. Targets are checked by model_measure on LOD0; the
  triangle counts per LOD go in the art log.
