shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// The Lantern Angler's fins (AnglerModel's fin mesh): plain membrane strips and fans whose look is all in here. A membrane's UV is
// (u across it along the root, v out from the root to the tips); rays run along v at evenly spaced u. Per fin (UV2.x):
//   10 spiny dorsal (few tall spines, webbed only low down), 11 soft dorsal, 12 anal, 13 caudal fan, 14 pectorals (flap and sweep).
// The rays are ridges (bump + paler, jointed), the web between them is translucent (alpha + backlight), torn back between the rays
// to a ragged edge with holes, and each ray runs on past the web as a fraying hair-like filament. The fins ripple along their
// normal (`flutter`.x is the amplitude at the tips, set by AnglerModel.fin_flutter), then turn with the tail snap and the
// pectoral hinges (angler_pose) and bend with the spine.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"
#include "res://shaders/angler_pose.gdshaderinc"

uniform vec4 web_color : source_color = vec4(0.1, 0.16, 0.18, 1.0);
uniform vec4 ray_color : source_color = vec4(0.26, 0.36, 0.38, 1.0);
uniform vec4 hair_color : source_color = vec4(0.4, 0.5, 0.5, 1.0);
uniform vec4 photo_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float web_alpha = 0.72;
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;

varying float part;
varying vec3 rest;

// Per fin: rays across it, how far up the rays the web reaches (of v), how deep it tears between them, ray width (of a gap).
vec4 fin_spec(float id) {
	if (id < 10.5) {
		return vec4(5.0, 0.5, 0.5, 0.3);
	} else if (id < 11.5) {
		return vec4(12.0, 0.8, 0.3, 0.22);
	} else if (id < 12.5) {
		return vec4(10.0, 0.78, 0.3, 0.22);
	} else if (id < 13.5) {
		return vec4(15.0, 0.82, 0.28, 0.2);
	}
	return vec4(11.0, 0.8, 0.3, 0.22);
}

void vertex() {
	part = UV2.x;
	rest = VERTEX;
	float v = UV.y;
	float u = UV.x;
	// A ripple out to the tips, running across the fin (a slow sway plus a quicker flutter).
	float a = u * 7.0 + v * 2.2 - TIME * flutter.z + part * 1.3;
	float wave = sin(a) + 0.35 * sin(2.3 * a + 1.7 + u * 5.0);
	VERTEX += NORMAL * flutter.x * 2.0 * pow(v, 1.4) * wave;
	if (part > 13.5) {
		angler_pectoral(VERTEX, NORMAL);
	}
	angler_tail(VERTEX, NORMAL);
	spine_bend(VERTEX, NORMAL, 0.0);
}

float aa_band(float d, float w) {
	float aa = fwidth(d) * 1.2 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

vec3 bump(vec3 n, vec3 pos, float h, float strength) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - grad * strength);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 p = rest / k;
	if (dissolve > 0.0 && skin_noise(p * 3.0 + 5.0) < dissolve) {
		discard;
	}
	vec4 spec = fin_spec(part);
	float u = UV.x;
	float v = UV.y;
	float x = u * spec.x;  // rays at whole numbers
	float i0 = floor(x);
	float t = x - i0;
	// Each ray's length (of v) and the web's reach up it; the leading spines stand tallest.
	float lead = part < 10.5 ? 1.0 - 0.1 * i0 : 1.0;
	float len0 = mix(0.74, 1.0, skin_hash(vec3(i0, part, 3.0))) * lead;
	float len1 = mix(0.74, 1.0, skin_hash(vec3(i0 + 1.0, part, 3.0))) * (part < 10.5 ? 1.0 - 0.1 * (i0 + 1.0) : 1.0);
	float near = t < 0.5 ? i0 : i0 + 1.0;
	float near_len = t < 0.5 ? len0 : len1;
	float to_ray = min(t, 1.0 - t);  // in gaps
	// The web: up to `spec.y` of the shorter neighbour, scalloped and torn deeper between the rays, its edge chewed.
	float gap_tear = spec.z * mix(0.35, 1.0, skin_hash(vec3(i0, part, 11.0)));
	float scallop = pow(sin(t * PI), 0.8);
	float chew = (skin_noise(vec3(u * spec.x * 3.0, v * 9.0, part)) - 0.5) * 0.12 + (skin_noise(vec3(u * 60.0, 2.0, part)) - 0.5) * 0.05;
	float web_top = spec.y * mix(len0, len1, smoothstep(0.0, 1.0, t)) * (1.0 - gap_tear * scallop) + chew;
	float web = 1.0 - smoothstep(web_top - 0.015, web_top + 0.015, v);
	// Holes and splits in the web.
	float hole = smoothstep(0.7, 0.76, skin_noise(vec3(x * 0.9, v * 5.0, part * 3.0))) * smoothstep(0.2, 0.4, v);
	float split = aa_band(t - 0.5 + 0.08 * sin(v * 11.0 + i0), 0.025) * step(0.72, skin_hash(vec3(i0, part, 17.0))) * smoothstep(web_top * 0.4, web_top * 0.7, v);
	web *= 1.0 - max(hole, split);
	// The rays: thick at the root, thinning to a hair that runs on past the web; a few fray into a second, wandering strand.
	float along = v / max(near_len, 0.05);
	float rw = spec.w * mix(1.0, 0.45, v) * sqrt(max(1.0 - along, 0.0)) + 0.01;
	float ray = aa_band(to_ray, rw * 0.5) * step(along, 1.0);
	float past = max(v - web_top, 0.0);
	float lean = (skin_hash(vec3(near, part, 23.0)) - 0.5) * 2.4 * past + 0.12 * sin(v * 17.0 + near * 3.7) * past * 3.0;
	float frayed = step(0.45, skin_hash(vec3(near, part, 29.0)));
	float strand = aa_band((x - near) - lean, 0.035 * (1.0 - along * 0.5)) * step(along, 0.92) * frayed * smoothstep(0.02, 0.06, past);
	// Lines thinner than a pixel fade instead of breaking into dots.
	float px = max(fwidth(x), 1e-4);
	ray *= clamp(rw / px, 0.25, 1.0);
	strand *= clamp(0.07 / px, 0.0, 1.0);
	float hair = max(ray * step(web_top, v), strand);
	float coverage = max(web, max(ray, strand));
	if (coverage < 0.02) {
		discard;
	}

	// The web: dark, faintly striated along the rays, mottled, paler toward the torn edge.
	float stria_at = x * 4.0 + skin_noise(vec3(x, v * 6.0, part)) * 0.5;
	float stria = (0.5 + 0.5 * sin(stria_at * TAU)) * (1.0 - smoothstep(0.15, 0.4, fwidth(stria_at)));
	float mottle = skin_fbm(vec3(u * spec.x * 0.8, v * 4.0, part));
	vec3 color = web_color.rgb * mix(0.7, 1.45, mottle) * mix(0.96, 1.04, stria);
	float near_edge = smoothstep(web_top - 0.12, web_top, v) * web;
	color = mix(color, hair_color.rgb * 0.6, near_edge * 0.7);
	// Sheen: the membrane catches light edge-on, a wet rim.
	float sheen = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	float alpha = web * mix(web_alpha, 0.95, smoothstep(0.18, 0.0, v)) * mix(0.85, 1.0, mottle);
	// The rays: jointed, pale on the ridge.
	float joint = aa_band(fract(v * 10.0 + skin_hash(vec3(near, part, 5.0))) - 0.5, 0.08);
	vec3 ray_c = ray_color.rgb * mix(1.0, 0.75, joint) * mix(0.8, 1.15, skin_noise(vec3(near, v * 20.0, part)));
	color = mix(color, ray_c, ray);
	color = mix(color, hair_color.rgb * mix(0.7, 1.0, along), hair);
	alpha = max(alpha, ray * 0.95);
	alpha = max(alpha, strand * 0.8);
	// A few photophores along the rays.
	float dot_at = mix(0.35, 0.7, skin_hash(vec3(near, part, 31.0)));
	float ph = (1.0 - smoothstep(0.012, 0.022, length(vec2((x - near) / spec.x * 4.0, v - dot_at)))) * step(0.6, skin_hash(vec3(near, part, 37.0)));
	vec3 emit = photo_color.rgb * ph * (0.8 + 0.4 * sin(TIME * 1.3 + near * 2.0));
	color = mix(color, photo_color.rgb * 0.4, ph * 0.6);
	emit += hair_color.rgb * hair * 0.04 + vec3(0.1, 0.2, 0.22) * sheen * web * 0.5 + web_color.rgb * web * 0.25;

	float height = ray * (1.0 - to_ray / max(rw * 0.5, 0.001)) * 0.8 + stria * 0.03 * web;
	NORMAL = bump(NORMAL, VERTEX, height * 0.03 * k, 1.0);
	color = mix(color, vec3(1.0, 0.3, 0.2), warn * 0.18);
	emit += vec3(1.0, 0.4, 0.3) * warn * 0.25 + vec3(flash);

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
	ROUGHNESS = mix(0.5, 0.35, ray);
	SPECULAR = 0.5;
	EMISSION = emit;
	BACKLIGHT = color * 1.2 + vec3(0.03, 0.07, 0.08);
}
