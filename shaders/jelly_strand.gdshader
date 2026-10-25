shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// A jellyfish's oral arms and tentacles (JellyModel). UV.y runs from a strand's
// root (0) to its tip (1), UV.x is a random seed per strand (or per arm), UV2.x
// how far out across an arm's frill a point is (0 on its core, 1 at the frilly
// edge). They sway in slow travelling waves that grow toward their tips, and
// the arms' frills flutter.
//
// Following the swim: the tail pivot's swing (`swing`: pitch, yaw, set each
// frame by JellyModel.Sway) bends a strand from its root, none at the root and
// all of it at the tip, so it trails round in a smooth curve. The oral arms hang
// on the tail pivot (`on_tail`): their root stays put under the bell and only
// the bend carries the swing. Rim tentacles hang off the model and bend about
// their own roots (their length in UV2.y; else `pivot`); they also ride the
// bell's pulse (`pulsing`).
//
// Drawn first of the jelly's parts and writing depth, so the see-through bell
// layers cleanly over them from any side (render_priority, JellyModel).

#include "res://shaders/jelly_pulse.gdshaderinc"
#include "res://shaders/stride_cue.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);  // the bell's main colour (team tint)
uniform vec4 own : source_color = vec4(1.0);  // the skin's own main colour
uniform float tint_share = 0.5;  // how much of a team tint these take
uniform vec4 root_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0);  // the frill's edge
uniform vec4 alt_color : source_color = vec4(1.0);  // some strands are this colour
uniform float alt_share = 0.0;
uniform vec4 band_color : source_color = vec4(1.0);
uniform float bands = 0.0;  // dashes along the strand, 0 for none
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow = 0.2;
uniform float core_alpha = 0.7;
uniform float edge_alpha = 0.9;
uniform float edge_fade = 0.0;  // the frill thins to see-through at its very edge
uniform bool on_tail = false;
uniform bool pulsing = false;
uniform vec3 pivot = vec3(0.0);  // model space: what strands without their own root bend about
uniform vec2 swing = vec2(0.0);  // the tail pivot's (pitch, yaw), rad
uniform float swing_share = 1.0;
uniform float bend_from = 0.0;  // along the strand where the bend starts
uniform float sway = 0.03;  // m at the tip
uniform float sway_waves = 1.3;  // waves along a strand
uniform float tempo = 0.6;  // against the swim phase
uniform float ripple = 0.006;  // the frill's flutter at its edge, m
uniform float ripple_waves = 18.0;  // along an arm

// As Godot's Basis.from_euler(Vector3(pitch, yaw, 0)): yaw about Y after pitch about X.
mat3 turn(float pitch, float yaw) {
	float cp = cos(pitch);
	float sp = sin(pitch);
	float cy = cos(yaw);
	float sy = sin(yaw);
	mat3 ry = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cp, sp), vec3(0.0, -sp, cp));
	return ry * rx;
}

void vertex() {
	float s = UV.y;
	float seed = UV.x;
	float across = UV2.x;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	// A rim tentacle (its length in UV2.y) bends about its own root.
	vec3 root = UV2.y > 0.0 ? vec3(v.xy, v.z - UV2.y * s) : pivot;
	// The frill flutters out of its plane, more toward its edge.
	v += n * ripple * (1.0 + effort) * across * across * sin(phase * tempo * 2.3 - s * ripple_waves + across * 2.0 + seed * 9.0);
	// Slow waves travel down each strand, growing toward the tip.
	float wave = phase * tempo - s * sway_waves * TAU + seed * TAU;
	float reach = sway * (0.7 + 0.6 * effort) * pow(s, 1.6);
	v.x += sin(wave) * reach;
	v.y += cos(wave * 0.83 + seed * 4.0) * reach * 0.7;
	if (pulsing) {
		v = jelly_pulse(v);
		root = jelly_pulse(root);
	}
	float k = smoothstep(bend_from, 1.0, s);
	mat3 bend = turn(swing.x * swing_share * k, swing.y * swing_share * k);
	if (on_tail) {
		// The pivot turns the whole arm; undo that, leaving the bend.
		mat3 undo = transpose(turn(swing.x, swing.y));
		v = undo * (bend * v);
		n = undo * (bend * n);
	} else {
		v = root + bend * (v - root);
		n = bend * n;
	}
	VERTEX = v;
	NORMAL = n;
}

void fragment() {
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	float s = UV.y;
	float across = UV2.x;
	vec3 shift = (albedo.rgb - own.rgb) * tint_share;
	vec3 color = mix(root_color.rgb, edge_color.rgb, smoothstep(0.15, 1.0, across));
	color = mix(color, alt_color.rgb, step(1.0 - alt_share, fract(UV.x * 7.31)));
	if (bands > 0.0) {
		float b = s * bands;
		float dash = smoothstep(0.35, 0.45, abs(fract(b) - 0.5)) * (1.0 - across);
		color = mix(color, band_color.rgb, dash * 0.7);
	}
	color = clamp(color + shift, vec3(0.0), vec3(1.0));
	float facing = clamp(abs(dot(n, VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.5);
	ALBEDO = color;
	float alpha = mix(core_alpha, edge_alpha, across) * mix(1.0, 0.75, s * s);
	alpha *= 1.0 - edge_fade * smoothstep(0.6, 1.0, across);
	ALPHA = clamp(alpha + fresnel * 0.25 * (1.0 - 0.5 * edge_fade * across), 0.0, 1.0);
	ROUGHNESS = 0.4;
	SPECULAR = 0.35;
	BACKLIGHT = color * 0.6;
	vec3 cue = stride_cue(s);
	EMISSION = (glow_color.rgb + shift) * glow * fresnel + cue * 1.5;
	ALPHA = max(ALPHA, min(length(cue), 1.0));
	NORMAL = n;
}
