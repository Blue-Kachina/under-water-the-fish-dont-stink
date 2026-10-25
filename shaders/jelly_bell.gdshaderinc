// A jellyfish's bell (JellyModel): glassy see-through jelly, firmer and brighter
// at grazing angles (a fresnel rim that glows faintly), painted from its rest
// shape. UV.x runs once round the bell, UV.y from the apex (0) to the rim (1).
// The outer surface (exumbrella) and the inner one (subumbrella, `inner`, seen
// from both sides) share it: radial stripes, the moon jelly's radial canals and
// ring canal, the inner surface's rings of swimming muscle, stinging-cell
// speckles. It pulses with the swim (jelly_pulse.gdshaderinc).
//
// Team tint: `albedo` is the bell's main colour; every colour here shifts by
// how far albedo is from the skin's own (`own`), so a tinted jelly reads as the
// team colour while its stripes and canals stay.

#include "res://shaders/jelly_pulse.gdshaderinc"
#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 own : source_color = vec4(1.0);  // the skin's own main colour
uniform vec4 centre_color : source_color = vec4(1.0);  // at the apex
uniform vec4 edge_color : source_color = vec4(1.0);  // toward the rim
uniform vec4 rim_color : source_color = vec4(1.0);  // the margin
uniform vec4 glow_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float base_alpha = 0.2;
uniform float rim_alpha = 0.5;  // the margin, and grazing angles
uniform float glow = 0.3;
uniform float stripes = 0.0;  // radial stripes round the bell, 0 for none
uniform vec4 stripe_color : source_color = vec4(0.4, 0.1, 0.5, 1.0);
uniform float stripe_width = 0.2;  // of the gap between stripes
uniform float stripe_alpha = 0.5;
uniform float canals = 0.0;  // radial canals round the bell, 0 for none
uniform vec4 canal_color : source_color = vec4(1.0);
uniform float canal_alpha = 0.3;
uniform float spots = 0.0;  // stinging-cell speckles
uniform vec4 spot_color : source_color = vec4(1.0);
uniform float rim_band = 0.0;  // a solid band round the margin, of UV.y
uniform float muscle = 0.0;  // the inner surface's rings of muscle
uniform bool inner = false;

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	NORMAL = jelly_pulse_normal(VERTEX, NORMAL);
	VERTEX = jelly_pulse(VERTEX);
}

// 1 on a line `width` wide (in `d`'s units) at d = 0, antialiased.
float line(float d, float width) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(width, width + aa, abs(d));
}

void fragment() {
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	float t = UV.y;
	float around = UV.x;
	vec3 shift = albedo.rgb - own.rgb;
	vec3 color = mix(centre_color.rgb, edge_color.rgb, smoothstep(0.05, 1.0, t)) + shift;
	float alpha = base_alpha * mix(0.75, 1.15, t);
	// Fine, uneven jelly.
	float grain = skin_fbm(rest * 45.0);
	color *= 0.92 + 0.16 * grain;
	alpha *= 0.85 + 0.3 * grain;
	if (stripes > 0.0) {
		// Wider toward the rim, fading out before the apex where they meet.
		float s = around * stripes;
		float d = abs(fract(s) - 0.5) * 2.0;  // 0 mid-stripe
		float width = stripe_width * mix(0.55, 1.0, t) * (0.85 + 0.3 * skin_noise(vec3(s * 3.0, t * 9.0, 0.0)));
		float aa = fwidth(s) * 2.0;
		float stripe = 1.0 - smoothstep(width - aa, width + aa, d);
		stripe *= smoothstep(0.1, 0.32, t);
		color = mix(color, stripe_color.rgb + shift * 0.35, stripe * stripe_alpha);
		alpha = mix(alpha, max(alpha, 0.85), stripe * stripe_alpha);
	}
	if (canals > 0.0) {
		// Radial canals from the stomach out to a ring canal by the margin;
		// every other one branches as it goes.
		float s = around * canals;
		float near = s - floor(s + 0.5);  // to the nearest canal, in gaps
		float width = 0.012 / max(t, 0.05);
		float canal = line(near, width) * smoothstep(0.22, 0.3, t);
		float odd = mod(floor(s + 0.5), 2.0);
		float wiggle = 0.06 * sin(t * 40.0 + floor(s + 0.5) * 2.3);
		float branch = line(abs(near) - (t - 0.5) * 0.5 - wiggle, width * 0.8) * step(0.5, t) * odd;
		float ring = line(t - 0.935, 0.006);
		float all_canals = max(max(canal, branch * 0.8), ring) * step(t, 0.95);
		color = mix(color, canal_color.rgb + shift * 0.3, all_canals * 0.8);
		alpha = mix(alpha, canal_alpha, all_canals);
	}
	if (spots > 0.0) {
		float speck = smoothstep(0.78, 0.86, skin_noise(rest * 110.0)) * smoothstep(0.15, 0.4, t);
		color = mix(color, spot_color.rgb, speck * spots);
		alpha = mix(alpha, max(alpha, 0.6), speck * spots);
	}
	if (inner && muscle > 0.0) {
		float rings = 0.5 + 0.5 * sin(t * 90.0);
		float band = smoothstep(0.5, 0.65, t) * (1.0 - smoothstep(0.9, 0.97, t));
		color = mix(color, color * 1.25 + 0.05, rings * band * muscle);
		alpha += rings * band * muscle * 0.08;
	}
	float margin = smoothstep(0.8, 1.0, t);
	color = mix(color, rim_color.rgb + shift * 0.5, margin * 0.55);
	alpha = mix(alpha, rim_alpha, margin * 0.5);
	if (rim_band > 0.0) {
		float band = smoothstep(1.0 - rim_band - fwidth(t), 1.0 - rim_band, t);
		color = mix(color, rim_color.rgb + shift * 0.3, band);
		alpha = mix(alpha, 0.9, band);
	}
	float facing = clamp(abs(dot(n, VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	color = clamp(color, vec3(0.0), vec3(1.0));
	ALBEDO = color;
	ALPHA = clamp(alpha + fresnel * rim_alpha * (inner ? 0.5 : 0.9), 0.0, 0.96);
	EMISSION = (glow_color.rgb + shift * 0.4) * (glow * fresnel + 0.02) + color * 0.04;
	ROUGHNESS = 0.07;
	SPECULAR = 0.75;
	BACKLIGHT = color * 0.4;
	NORMAL = n;
}
