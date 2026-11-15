// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// Material pass (planning_abyssal_look.md, phase 7): the extra terms the reef, ruins, kelp and sand wear in the Ocean modes.
// Fluorescence `albedo * flu * dot(light, (.1,.5,.5))` (coral re-emits the blue-green light that reaches it), kelp
// translucency with a warm tint, thin-film iridescence and a sparkle band, rock strata / detail / rim light, sand cover and the
// per-run biome tint. Everything is a global set from WaterLook every frame; all zero (any non-Ocean arena) changes nothing.
// Needs scenery.gdshaderinc and water_caustics.gdshaderinc (water_surface_y, water_kd, water_sun_dir) included first.

global uniform vec4 water_mat_kelp;   // translucency, iridescence, veins, sparkle peak
global uniform vec4 water_mat_kelp2;  // warm tint rgb, sparkle fraction of blades
global uniform vec4 water_mat_coral;  // fluorescence strength, flu min, flu max, tip highlight
global uniform vec4 water_mat_rock;   // strata, detail map, algae multiplier, rim light
global uniform vec4 water_mat_sand;   // encrusting cover
global uniform vec4 water_biome;      // tint rgb, strength
global uniform sampler2D water_rock_detail : repeat_enable, filter_linear_mipmap;

// The sunlight (plus a little sky) left at a point's depth, per colour: what the colours can still light.
vec3 wm_light(vec3 wp) {
	float depth = max(water_surface_y - wp.y, 0.0);
	return exp(-water_kd * depth) * 0.85 + vec3(0.04, 0.09, 0.12);
}

// Fluorescence: the part of the light that is green or blue gets re-emitted in the albedo's colour.
vec3 wm_fluor(vec3 albedo, vec3 wp, float flu) {
	if (water_mat_coral.x <= 0.0) {
		return vec3(0.0);
	}
	return albedo * flu * water_mat_coral.x * dot(wm_light(wp), vec3(0.1, 0.5, 0.5));
}

// Per-copy fluorescence within the palette range.
float wm_flu_of(float r) {
	return mix(water_mat_coral.y, water_mat_coral.z, fract(r * 7.31));
}

// Triplanar detail map: x height, y slope, z mottle, w cracks (two scales blended so it never reads as tiling).
vec4 wm_detail(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	vec4 a = texture(water_rock_detail, p.zy * 0.21) * w.x + texture(water_rock_detail, p.xz * 0.21) * w.y + texture(water_rock_detail, p.xy * 0.21) * w.z;
	vec4 b = texture(water_rock_detail, p.zy * 0.067 + 0.31) * w.x + texture(water_rock_detail, p.xz * 0.067 + 0.31) * w.y + texture(water_rock_detail, p.xy * 0.067 + 0.31) * w.z;
	return mix(a, b, 0.45);
}

// Strata: horizontal beds of tint with dark seams, an olive/brown mix and red encrustation. Returns colour; `amount` is how much to
// take over the stone's own colour. `up` (n.y) puts algae on the faces that look up.
vec3 wm_strata(vec3 color, vec3 p, vec3 n, vec4 det, float variant) {
	float s = water_mat_rock.x;
	if (s <= 0.0) {
		return color;
	}
	float wob = (det.x - 0.5) * 1.6 + (det.z - 0.5) * 0.8;
	float bed = p.y * 1.7 + wob + variant * 5.0;
	float bands = 0.5 + 0.5 * sin(bed * 3.0) * 0.6 + 0.5 * sin(bed * 7.3 + 1.7) * 0.4;
	vec3 olive = vec3(0.52, 0.5, 0.36);
	vec3 brown = vec3(0.5, 0.38, 0.28);
	vec3 bedc = mix(brown, olive, smoothstep(0.3, 0.7, det.z)) * (0.8 + 0.4 * bands);
	vec3 c = mix(color, color * bedc * 1.7, 0.55 * s);
	c *= 1.0 - det.w * 0.45 * s;  // dark seams (thin cracks)
	float red = smoothstep(0.62, 0.8, det.z + (1.0 - det.x) * 0.25) * smoothstep(0.1, -0.4, n.y);
	c = mix(c, vec3(0.45, 0.2, 0.16), red * 0.45 * s);
	return c;
}

// Algae on up faces (abyssal-garden's smoothstep(-.1,.6,n.y)), as a mix amount, scaled by the algae multiplier.
float wm_algae(vec3 n, vec4 det) {
	return smoothstep(-0.1, 0.6, n.y) * smoothstep(0.35, 0.65, det.z + det.x * 0.3) * clamp(water_mat_rock.z * 0.45, 0.0, 1.0);
}

// The biome tint: a run's regional colour cast over sand and rock.
vec3 wm_biome(vec3 color, float k) {
	return mix(color, color * water_biome.rgb, clamp(water_biome.w * k, 0.0, 1.0));
}
