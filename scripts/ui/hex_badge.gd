class_name HexBadge
## The Hex Badge icon set (UI Redesign Handoff, Icons A): each powerup's white
## line glyph in a dark hexagon rimmed in its rarity's colour (a weapon's in a
## diamond, a tome's in a square: Shape); the same glyphs
## go in the powerup cards' medallions, and the mode picker's tiles have their
## own. Glyphs are SVG path data on a 24-unit grid, stroke only, parsed once
## into polylines (parse()).
##
## A new powerup needs a glyph drawn on the same 24-unit grid with the same
## stroke, under the id it has in Powerup.INFO.

## Glyph id -> SVG path data (24×24, stroke only).
const GLYPHS := {
	"greek_fire": "M12 3c1.5 3 5 5 5 9.5a5 5 0 0 1-10 0c0-2 1-3.5 2.5-4.5 0 2 1 3 2.5 3 0-3-1-5 0-8zM3 21h4M10 21h4M17 21h4",
	"chain_lightning": "M13 2 5 13h6l-1 9 8-12h-6l1-8z",
	"torpedo": "M8 9h7a3 3 0 0 1 0 6H8a3 3 0 0 1 0-6zM8 9 5 6M8 15l-3 3M5 12H2M20 12h2",
	"bow_grow_bow": "M12 12 4 7v10zM12 12l8-5v10zM10.5 10.5h3v3h-3z",
	"barnacle_plating": "M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6zM8.2 10a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0M13.2 11a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0M10.7 15a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0",
	"hermit_shell": "M3 19h18M5 19c0-7 4-12 10-12a5 5 0 0 1 0 10h-3a2.5 2.5 0 0 1 0-5h1",
	"fizzy_soda": "M7 8h10l-1.2 13H8.2zM6 8h12M14 8l2-5h3M10 13a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M12.5 16.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M9.9 18a0.6 0.6 0 1 0 1.2 0a0.6 0.6 0 1 0 -1.2 0",
	"speedy_seahorse": "M15 3c2 0 3 1.5 3 3l-4 1c-1.5 1-1.5 3 0 4.5S15 15 13 17c-1.5 1.5-1 3.5 1 3.5M15 3c-2.5 0-4 1.5-4 4M2 9h5M3 13h4M4 17h3",
	"remora_buddy": "M3 10c3-4 9-4 12 0-3 4-9 4-12 0zM15 10l4-3v6zM9 18c1.5-1.8 4-1.8 5.5 0-1.5 1.8-4 1.8-5.5 0zM14.5 18l2-1.5v3z",
	"kelp_wrap": "M8 21c3-4-3-6 0-9s-3-5 0-9M15 21c3-4-3-6 0-9s-3-5 0-9",
	"sea_salt": "M12 3l4 6-4 12-4-12zM3 10l3 2M21 10l-3 2",
	"coral_knuckles": "M12 21v-8M12 13l-4-5M12 13l4-5M8 8V4M16 8V4",
	"divers_goggles": "M3 9h18v6H3zM8 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0M13 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
	"lucky_sand_dollar": "M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0M12 6l1.5 4.5H18l-3.5 2.5 1.5 4.5-4-3-4 3 1.5-4.5L6 10.5h4.5z",
	"lamprey": "M3 15c4-8 12-8 18 0M3 15l3-1M18 8l3 2",
	"clam_shield": "M3 14a9 7 0 0 1 18 0zM3 14c0 4 4 6 9 6s9-2 9-6M12 7v7",
	"momentum_fin": "M3 8h13M5 12h16M3 16h11",
	"treasure_map": "M4 5l5 2 6-2 5 2v12l-5-2-6 2-5-2zM9 7v12M15 5v12",
	"bubble_wrap": "M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0M8 9.5a4.5 4.5 0 0 1 3-3M18 4a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0 -3 0",
	"pufferfish_spines": "M7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1",
	"jellyfish_halo": "M6 12a6 6 0 0 1 12 0zM8.5 12v3c0 1.5-1 2.5 0 4M12 12v7M15.5 12v3c0 1.5 1 2.5 0 4M3 7.5c2-3.5 5.5-5 9-5s7 1.5 9 5",
	"electric_eel": "M2 15c2.5-4 4.5-4 7 0s4.5 4 7 0c1-1.6 2.5-2 4-1.5M20 3l-2.5 3.5h3L18 10",
	"depth_charges": "M6 13a6 6 0 1 0 12 0a6 6 0 1 0 -12 0M12 4v3M12 19v2M4 13H2.5M21.5 13H20M6.3 7.3 5 6M17.7 7.3 19 6",
	"anglerfish_lure": "M3 21C3 12 8 5 15 5c2.5 0 4 1.5 4 3.5V10M16.5 12.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0",
	"tsunami_heart": "M12 20.5s-8-4.8-8-10.5a4.3 4.3 0 0 1 8-2.2 4.3 4.3 0 0 1 8 2.2c0 5.7-8 10.5-8 10.5zM7.5 12c1.5-1.2 3-1.2 4.5 0s3 1.2 4.5 0",
	"drowned_fin": "M4 18c4.5 0 7-3 8-8l2.5-6c1 5 2.5 10 6 14zM2 21.5h20",
	"leviathans_coil": "M2 15a3.3 3.3 0 0 1 6.6 0 3.3 3.3 0 0 0 6.6 0 3.3 3.3 0 0 1 6.6 0V10l-2-2",
	"blood_moon_shard": "M15 3.5a8.5 8.5 0 1 0 5.5 14 7 7 0 0 1-5.5-14zM10 9l2 3-1.5 3",
	"glass_coral": "M12 21v-8M12 13 8 9V4.5M12 13l4.5-5V4M8 9 5 7.5M16.5 8 19.5 7M8 21h8",
	"sirens_song": "M9 17.5V5.5l11-2v12M9 9.5l11-2M4 17.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0M15 15.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0",
	"abyssal_hunger": "M3 8c4-3 14-3 18 0M3 16c4 3 14 3 18 0M5 8.7l1.5 3 1.5-3.4M10.5 7.5 12 11l1.5-3.5M16 7.7l1.5 3.4 1.5-3M5 15.3l1.5-3 1.5 3.4M10.5 16.5 12 13l1.5 3.5M16 16.3l1.5-3.4 1.5 3",
	"sunken_idol": "M8 3h8v4l2 2v12H6V9l2-2zM9.5 12h1.5M13 12h1.5M10 16h4M6 9h12",
	"sticky_anemone": "M5 20h14M8 20c0-4-2-6-3-9M12 20V9M16 20c0-4 2-6 3-9M10 20c0-3-1-5-1-8M14 20c0-3 1-5 1-8M11 6a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
	"ink_sac": "M12 3c3 4 6 7 6 11a6 6 0 0 1-12 0c0-4 3-7 6-11zM9 15a3 3 0 0 0 3 3",
	"sonar_pinger": "M5 19l5-5M10 14a6 6 0 0 0-5-9M14 4a8 8 0 0 1 6 6M14 8a4 4 0 0 1 2 2M8 21h6",
	"cold_seep": "M12 2v20M3.5 7l17 10M3.5 17l17-10M9 4l3 2 3-2M9 20l3-2 3 2",
	"whirlpool_charm": "M12 12a1.5 1.5 0 1 1 1.5 1.5c-2.5 0-4-2-4-4a4.5 4.5 0 0 1 9 0c0 4-3 7-7 7a8 8 0 0 1-8-8",
	"krakens_grasp": "M6 21c0-6 2-10 6-12s4-6 1-6c-2 0-3 2-2 3M10 21c0-4 2-7 5-8M14 21c0-2 1-4 4-5",
	"ghost_swordfish": "M2 12h6M8 12c2-3 7-4 11-1l3 1-3 1c-4 3-9 2-11-1zM12 8l1-3M12 16l1 3M16 12a0.6 0.6 0 1 0 1.2 0a0.6 0.6 0 1 0 -1.2 0",
	"ammonite_spiral": "M12 12a1.5 1.5 0 1 0 1.5-1.5M13.5 10.5a3.5 3.5 0 1 1-4 4M9.5 14.5a6 6 0 1 1 9-6M18.5 8.5a8.5 8.5 0 0 1-1 11",
	"riptide": "M3 8c3-2 6-2 9 0s6 2 9 0M3 13c3-2 6-2 9 0s6 2 9 0M3 18c3-2 6-2 9 0M16 18l3-2v4z",
	"reef_guardian": "M5 18h14M6 18V9l3 3 3-6 3 6 3-3v9M12 14v1",
	"bioluminescence": "M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
	"poseidons_trident": "M12 22V7M7 3v5a5 5 0 0 0 10 0V3M12 3v4M5 5l2-2 2 2M15 5l2-2 2 2M10 3l2-2 2 2",
	"megalodon_tooth": "M5 4h14l-2 6-5 11-5-11zM8 8h8M9 12h6",
	"moon_pearl": "M7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0M10 10a2 2 0 0 1 2-2M4 4l3 3M20 4l-3 3M12 2v2",
	"abyssal_engine": "M7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0M12 3v4M12 17v4M3 12h4M17 12h4M5.5 5.5l3 3M15.5 15.5l3 3M10 12h4",
	# The fish's own attacks, as weapons (Weapons.glyph).
	"attack_bite": "M3 9c3-4 15-4 18 0M3 15c3 4 15 4 18 0M6 9.5l1.5 2.5 1.5-2.7M10.5 8.7 12 11.5l1.5-2.8M15 9.3l1.5 2.7 1.5-2.5M6 14.5l1.5-2.5 1.5 2.7M10.5 15.3 12 12.5l1.5 2.8M15 14.7l1.5-2.7 1.5 2.5",
	"attack_sting": "M9.5 12a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0M12 9.5C11 7 13 5 12 2.5M12 14.5c1 2.5-1 4.5 0 7M9.5 12C7 13 5 11 2.5 12M14.5 12c2.5-1 4.5 1 7 0M10 10 6.5 6.5M14 14l3.5 3.5M14 10l3.5-3.5M10 14l-3.5 3.5",
	"attack_lash": "M3 20c3-1 5-4 6-8M9 12l3 2 2-5 3 3 4-8",
	"attack_thrust": "M4 20 16 8M13 5l6-1-1 6zM6 14l4 4",
	"attack_bubbles": "M4 15a4 4 0 1 0 8 0a4 4 0 1 0-8 0M13 8a3 3 0 1 0 6 0a3 3 0 1 0-6 0M15 17.5a2 2 0 1 0 4 0a2 2 0 1 0-4 0M6 13.5a1.5 1.5 0 0 1 1.5-1.5",
	"attack_spines": "M8 8h8v8H8zM12 3v5M12 16v5M3 12h5M16 12h5M5 5l3 3M16 16l3 3M5 19l3-3M16 8l3-3",
	# The tomes (Tomes.glyph): a book, its emblem on the cover.
	"tome_teeth": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M9.5 8l1.75 4 1.75-4 1.75 4 1.75-4",
	"tome_tides": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M9.5 9c1-1 2-1 3 0s2 1 3 0M9.5 12.5c1-1 2-1 3 0s2 1 3 0",
	"tome_reef": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M13 15V8.5M13 11.5l-2.5-2.5M13 10.5l2.5-2.5",
	"tome_schools": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M9.5 8.5h2.5M14 8.5h2M11.5 12.5h3",
	"tome_currents": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M9.5 10.5h6M13.5 8.5l2 2-2 2",
	"tome_kill": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M10.5 10.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0M13 6.5v1.5M13 13v1.5M9 10.5h1.5M15.5 10.5H17",
	"tome_fins": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M10 14c2-.5 3.5-3 4-7 1 3 2 5.5 2 7z",
	"tome_ram": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M10 7.5l3 3-3 3M13 7.5l3 3-3 3",
	"tome_shell": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M13 6.5l3.5 1.5v2.5c0 2-1.5 3.5-3.5 4.5-2-1-3.5-2.5-3.5-4.5V8z",
	"tome_pearls": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M10.5 10.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0M12 9.6a1.2 1.2 0 0 1 1-.6",
	"tome_fortune": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M13 6.5l1.1 2.3 2.4.3-1.8 1.7.5 2.4-2.2-1.2-2.2 1.2.5-2.4-1.8-1.7 2.4-.3z",
	"tome_ages": "M6 20V5a2 2 0 0 1 2-2h10v15H8a2 2 0 0 0-2 2a2 2 0 0 0 2 2h10M10 6.5h6M10 14.5h6M10.5 6.5c0 3 5 2.5 5 4s-5 1-5 4M15.5 6.5c0 3-5 2.5-5 4s5 1 5 4",
	# The mode picker's tiles.
	"mode_unnatural": "M12 3a8 8 0 1 0 0 16a8 8 0 1 0 0-16zM8.5 15.5v4M12 17v4.5M15.5 15.5v3M9 9.5a1 1 0 1 0 2 0a1 1 0 1 0-2 0M13 9.5a1 1 0 1 0 2 0a1 1 0 1 0-2 0",
	"mode_1v1": "M4 12c1.8-2.8 5.2-2.8 7 0-1.8 2.8-5.2 2.8-7 0zM4 12l-2.5-2v4zM13 12c1.8-2.8 5.2-2.8 7 0-1.8 2.8-5.2 2.8-7 0zM20 12l2.5-2v4zM12 5v2.5M12 16.5V19",
	"mode_hunt": "M6 12a6 6 0 1 0 12 0a6 6 0 1 0-12 0M12 2.5v5M12 16.5v5M2.5 12h5M16.5 12h5M11 12a1 1 0 1 0 2 0a1 1 0 1 0-2 0",
	"mode_nature": "M3 10.5c3-4.5 9-4.5 12 0-3 4.5-9 4.5-12 0zM15 10.5l5-3.5v7zM6 10a.9.9 0 1 0 1.8 0a.9.9 0 1 0-1.8 0M2 19c2-1.5 4-1.5 6 0s4 1.5 6 0 4-1.5 6 0",
	"mode_free_play": "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 8.2l3.6 2.6-1.4 4.2H9.8l-1.4-4.2zM12 8.2V3M15.6 10.8l4.9-1.6M14.2 15l3 4.2M9.8 15l-3 4.2M8.4 10.8l-4.9-1.6",
	"mode_free_swim": "M2 8c2-1.5 4-1.5 6 0s4 1.5 6 0 4-1.5 6 0M2 13c2-1.5 4-1.5 6 0s4 1.5 6 0 4-1.5 6 0M2 18c2-1.5 4-1.5 6 0s4 1.5 6 0 4-1.5 6 0",
	"mode_obstacle_course": "M5 21V3.5l10 3.8-10 3.8M13 16a4 4 0 1 0 8 0a4 4 0 1 0-8 0",
	"mode_test_tank": "M4 12a8 8 0 1 0 16 0a8 8 0 1 0-16 0M8 12a4 4 0 1 0 8 0a4 4 0 1 0-8 0M11 12a1 1 0 1 0 2 0a1 1 0 1 0-2 0",
	"mode_replays": "M3.5 12a8.5 8.5 0 1 0 2.5-6M3 3.5V8h4.5M10 8.5l5.5 3.5-5.5 3.5z",
}

## A badge's outline, by what it holds (Card Type Variations, E): a weapon's
## a diamond, a tome's a square, an item's (a powerup) a hexagon. The same
## shape on its level-up card, its HUD slot and the scoreboard.
enum Shape { HEX, DIAMOND, SQUARE, CIRCLE }

## The hexagon's corners in a 100-unit box.
const HEX := [Vector2(50, 4), Vector2(90, 27), Vector2(90, 73), Vector2(50, 96), Vector2(10, 73), Vector2(10, 27)]
## The diamond's, likewise.
const DIAMOND := [Vector2(50, 2), Vector2(98, 50), Vector2(50, 98), Vector2(2, 50)]
## The square's side and corner radius in the same box.
const SQUARE_SIDE := 78.0
const SQUARE_RADIUS := 12.0
## A glyph's size against the badge's width (a diamond's smaller: less room inside).
const GLYPH_SHARE := 0.47
const DIAMOND_GLYPH_SHARE := 0.42
const CURVE_STEPS := 10

## Glyph id -> {"lines": Array[PackedVector2Array], "joints": PackedVector2Array}
static var _parsed := {}


## Whether there's a glyph for `id`.
static func has_glyph(id: String) -> bool:
	return GLYPHS.has(id)


## A badge `size` px wide centred on `centre`: its `shape` filled with `fill`,
## its rim in `rim`, and glyph `id` in white. `hud`: the HUD's heavier strokes.
static func draw_badge(canvas: CanvasItem, centre: Vector2, size: float, id: String, rim: Color, hud := false,
		fill := UITheme.BADGE_FILL, shape := Shape.HEX) -> void:
	draw_shape(canvas, shape, centre, size, fill, rim, (7.0 if hud else 6.0) / 100.0 * size)
	draw_glyph(canvas, id, centre, size * glyph_share(shape), UITheme.INK, 2.0 if hud else 1.8)


## The shape for what powerup or weapon `id` is: a diamond for a weapon, a
## hexagon for an item. (Tomes aren't powerups: Shape.SQUARE.)
static func shape_of(id: String) -> Shape:
	return Shape.DIAMOND if Powerup.is_weapon(id) else Shape.HEX


static func glyph_share(shape: Shape) -> float:
	return DIAMOND_GLYPH_SHARE if shape == Shape.DIAMOND else GLYPH_SHARE


## The hexagon alone, `size` px wide, its rim `rim_width` px.
static func draw_hex(canvas: CanvasItem, centre: Vector2, size: float, fill: Color, rim: Color, rim_width: float) -> void:
	draw_shape(canvas, Shape.HEX, centre, size, fill, rim, rim_width)


## `shape` alone, `size` px wide (its 100-unit box), its rim `rim_width` px.
static func draw_shape(canvas: CanvasItem, shape: Shape, centre: Vector2, size: float, fill: Color, rim: Color, rim_width: float) -> void:
	var points := outline(shape, centre, size)
	canvas.draw_colored_polygon(points, fill)
	if rim_width <= 0.0:
		return
	var ring := points.duplicate()
	ring.append(points[0])
	canvas.draw_polyline(ring, rim, rim_width, true)
	if shape == Shape.HEX or shape == Shape.DIAMOND:
		for corner in points:
			canvas.draw_circle(corner, rim_width * 0.5, rim, true, -1.0, true)


## `shape`'s outline, `size` px wide (its 100-unit box) around `centre`.
static func outline(shape: Shape, centre: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match shape:
		Shape.HEX, Shape.DIAMOND:
			for corner: Vector2 in (HEX if shape == Shape.HEX else DIAMOND):
				points.append(centre + (corner - Vector2(50, 50)) * size / 100.0)
		Shape.SQUARE:
			var half := SQUARE_SIDE * 0.5 * size / 100.0
			points = rounded_rect(Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0), SQUARE_RADIUS * size / 100.0)
		Shape.CIRCLE:
			for n in 32:
				points.append(centre + Vector2.from_angle(TAU * n / 32.0) * size * 0.46)
	return points


## A rounded rectangle's outline (clockwise from its top-left corner's arc).
static func rounded_rect(rect: Rect2, radius: float, steps := 6) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(r, r), PI],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5],
		[rect.end - Vector2(r, r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
	]
	var points := PackedVector2Array()
	for corner: Array in corners:
		var at: Vector2 = corner[0]
		var start: float = corner[1]
		for step in steps + 1:
			points.append(at + Vector2.from_angle(start + PI * 0.5 * step / steps) * r)
	return points


## Glyph `id` drawn `px` wide centred on `centre`, its stroke `stroke` units
## (of 24) wide, with round caps and joins.
static func draw_glyph(canvas: CanvasItem, id: String, centre: Vector2, px: float, color: Color, stroke := 1.8) -> void:
	if not GLYPHS.has(id):
		return
	var shape := parse(id)
	var unit := px / 24.0
	var width := maxf(stroke * unit, 1.0)
	var origin := centre - Vector2(12.0, 12.0) * unit
	for line: PackedVector2Array in shape.lines:
		var placed := PackedVector2Array()
		placed.resize(line.size())
		for i in line.size():
			placed[i] = origin + line[i] * unit
		if placed.size() >= 2:
			canvas.draw_polyline(placed, color, width, true)
	for joint: Vector2 in shape.joints:
		canvas.draw_circle(origin + joint * unit, width * 0.5, color, true, -1.0, true)


## The stack count chip on a badge's bottom-right ("×3"), `size` the badge's width.
static func draw_stack_chip(canvas: CanvasItem, centre: Vector2, size: float, count: int, s: float) -> void:
	var text := "×%d" % count
	var px := roundi(14.0 * s)
	var font := UITheme.condensed(700)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 10.0 * s
	var height := 18.0 * s
	var rect := Rect2(centre + Vector2(size * 0.5 - width + 4.0 * s, size * 0.5 - height + 2.0 * s), Vector2(width, height))
	UITheme.draw_box(canvas, rect, UITheme.INK, height * 0.5)
	UITheme.draw_text(canvas, rect, text, font, px, UITheme.GROUND)


## Glyph `id` as polylines (in 24-unit space) plus the points that get a round
## cap or join. Parsed once.
static func parse(id: String) -> Dictionary:
	if _parsed.has(id):
		return _parsed[id]
	var result := parse_path(GLYPHS.get(id, ""))
	_parsed[id] = result
	return result


## SVG path data (M L H V C S Q A Z, absolute and relative, with implicit
## repeats) -> {"lines": Array[PackedVector2Array], "joints": PackedVector2Array}.
static func parse_path(data: String) -> Dictionary:
	var tokens := _tokens(data)
	var lines: Array[PackedVector2Array] = []
	var joints := PackedVector2Array()
	var current := PackedVector2Array()
	var at := Vector2.ZERO
	var start := Vector2.ZERO
	var last_control := Vector2.ZERO
	var last_command := ""
	var command := ""
	var i := 0
	while i < tokens.size():
		var token: String = tokens[i]
		if _is_command(token):
			command = token
			i += 1
			if command == "Z" or command == "z":
				if current.size() > 0:
					current.append(start)
					lines.append(current)
					joints.append(start)
				current = PackedVector2Array()
				at = start
				last_command = command
				continue
		elif command == "M":
			command = "L"  # extra pairs after a move are lines
		elif command == "m":
			command = "l"
		var relative := command == command.to_lower()
		var base := at if relative else Vector2.ZERO
		match command.to_upper():
			"M":
				if current.size() > 1:
					lines.append(current)
				at = base + Vector2(_num(tokens, i), _num(tokens, i + 1))
				i += 2
				start = at
				current = PackedVector2Array([at])
				joints.append(at)
			"L":
				at = base + Vector2(_num(tokens, i), _num(tokens, i + 1))
				i += 2
				current.append(at)
				joints.append(at)
			"H":
				at = Vector2((at.x if relative else 0.0) + _num(tokens, i), at.y)
				i += 1
				current.append(at)
				joints.append(at)
			"V":
				at = Vector2(at.x, (at.y if relative else 0.0) + _num(tokens, i))
				i += 1
				current.append(at)
				joints.append(at)
			"C", "S":
				var c1: Vector2
				if command.to_upper() == "C":
					c1 = base + Vector2(_num(tokens, i), _num(tokens, i + 1))
					i += 2
				else:
					c1 = at * 2.0 - last_control if last_command.to_upper() in ["C", "S"] else at
				var c2 := base + Vector2(_num(tokens, i), _num(tokens, i + 1))
				var to := base + Vector2(_num(tokens, i + 2), _num(tokens, i + 3))
				i += 4
				for step in range(1, CURVE_STEPS + 1):
					var t := float(step) / CURVE_STEPS
					current.append(at.bezier_interpolate(c1, c2, to, t))
				last_control = c2
				at = to
				joints.append(at)
			"Q":
				var control := base + Vector2(_num(tokens, i), _num(tokens, i + 1))
				var to := base + Vector2(_num(tokens, i + 2), _num(tokens, i + 3))
				i += 4
				for step in range(1, CURVE_STEPS + 1):
					var t := float(step) / CURVE_STEPS
					current.append(at.lerp(control, t).lerp(control.lerp(to, t), t))
				at = to
				joints.append(at)
			"A":
				var radii := Vector2(absf(_num(tokens, i)), absf(_num(tokens, i + 1)))
				var rotation := deg_to_rad(_num(tokens, i + 2))
				var large := _num(tokens, i + 3) != 0.0
				var sweep := _num(tokens, i + 4) != 0.0
				var to := base + Vector2(_num(tokens, i + 5), _num(tokens, i + 6))
				i += 7
				for point in _arc(at, to, radii, rotation, large, sweep):
					current.append(point)
				at = to
				joints.append(at)
			_:
				i += 1  # an unknown command's numbers: skip
		last_command = command
	if current.size() > 1:
		lines.append(current)
	return {"lines": lines, "joints": joints}


## The arc from `from` to `to` (SVG's endpoint form) as points, `from` left out.
static func _arc(from: Vector2, to: Vector2, radii: Vector2, rotation: float, large: bool, sweep: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	if radii.x < 0.0001 or radii.y < 0.0001 or from.is_equal_approx(to):
		points.append(to)
		return points
	var cos_r := cos(rotation)
	var sin_r := sin(rotation)
	var half := (from - to) * 0.5
	var p := Vector2(cos_r * half.x + sin_r * half.y, -sin_r * half.x + cos_r * half.y)
	var rx := radii.x
	var ry := radii.y
	var fit := (p.x * p.x) / (rx * rx) + (p.y * p.y) / (ry * ry)
	if fit > 1.0:
		rx *= sqrt(fit)
		ry *= sqrt(fit)
	var top := rx * rx * ry * ry - rx * rx * p.y * p.y - ry * ry * p.x * p.x
	var under := rx * rx * p.y * p.y + ry * ry * p.x * p.x
	var factor := sqrt(maxf(top / under, 0.0)) if under > 0.0 else 0.0
	if large == sweep:
		factor = -factor
	var c := Vector2(factor * rx * p.y / ry, -factor * ry * p.x / rx)
	var middle := (from + to) * 0.5
	var centre := Vector2(cos_r * c.x - sin_r * c.y, sin_r * c.x + cos_r * c.y) + middle
	var start_angle := Vector2(1, 0).angle_to(Vector2((p.x - c.x) / rx, (p.y - c.y) / ry))
	var delta := Vector2((p.x - c.x) / rx, (p.y - c.y) / ry).angle_to(Vector2((-p.x - c.x) / rx, (-p.y - c.y) / ry))
	if not sweep and delta > 0.0:
		delta -= TAU
	elif sweep and delta < 0.0:
		delta += TAU
	var steps := maxi(ceili(absf(delta) / deg_to_rad(12.0)), 2)
	for step in range(1, steps + 1):
		var angle := start_angle + delta * step / steps
		var local := Vector2(rx * cos(angle), ry * sin(angle))
		points.append(centre + Vector2(cos_r * local.x - sin_r * local.y, sin_r * local.x + cos_r * local.y))
	points[points.size() - 1] = to
	return points


static func _is_command(token: String) -> bool:
	return token.length() == 1 and "MmLlHhVvCcSsQqAaZz".contains(token)


static func _num(tokens: PackedStringArray, at: int) -> float:
	return tokens[at].to_float() if at < tokens.size() else 0.0


static var _number_regex: RegEx


## Commands and numbers ("-10", ".5", "1.5") in path data.
static func _tokens(data: String) -> PackedStringArray:
	if _number_regex == null:
		_number_regex = RegEx.create_from_string("[MmLlHhVvCcSsQqAaZz]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
	var found := PackedStringArray()
	for match_result in _number_regex.search_all(data):
		found.append(match_result.get_string())
	return found
