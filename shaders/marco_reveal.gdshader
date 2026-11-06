shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Marco Polo's reveal (planning_marco_polo.md §3): how a hider looks in a
// seeker's view, built up from the inside out as its exposure rises. One shader
// for every part of the reveal copy (HiderLooks), picked by `kind`:
//   0 the body: swells out from the spine's centreline by `grow` (the profile
//     texture gives each slice's middle), raw red with W-shaped myomeres;
//   1 a fin membrane (UV.x along its root, UV.y out to its edge): bone rays
//     first, a vessel beside each, then the membrane creeping out from the rays;
//   2 a thin part (whiskers, a bill, spines): dithered muscle;
//   3 bones (FishAnatomy; COLOR.r the bone's kind, COLOR.g how far along it):
//     the spine grows first, then the ribs out to their tips, then the skull
//     and the rest;
//   4 vessels (COLOR.g their distance from the heart): grow out from the heart,
//     with the pulse running along them;
//   5 the heart (beaten by its node's scale).
// The skin layer is the real model under this copy: the copy dithers away by
// `skin`. Everything is dithered, never blended, so it all stays opaque.
// Jellies' bells pulse and rays' wings bend as their own shaders do (their
// uniforms are copied from the real materials each frame).

#include "res://shaders/fish_bend.gdshaderinc"
#include "res://shaders/jelly_pulse.gdshaderinc"

// Per hider (its reveal materials), set by HiderLooks: (bones, cardio, grow, skin), each 0..1 through
// its band, and (beat 0..1, seconds since the beat, see-through m, -).
uniform vec4 layers = vec4(0.0);
uniform vec4 pulse = vec4(0.0);

uniform int kind = 0;
uniform bool jelly = false;
uniform bool ray_wing = false;
// The body's slices along z (FishAnatomy): r half width, g half height, b middle height.
uniform sampler2D profile : filter_linear, repeat_disable;
uniform vec2 profile_z = vec2(-0.5, 0.5);  // nose and tail z the texture spans
// A fin membrane's (fin_membrane.gdshader).
uniform float rays = 12.0;
uniform float flutter = 0.0;
uniform float waves = 1.2;
uniform float tempo = 1.0;
// A ray's wings (ray_skin.gdshader, keep in step).
uniform float hinge = 0.16;
uniform float span = 0.54;
uniform float rest_flap = 0.25;
uniform float flap_left = 0.0;
uniform float flap_right = 0.0;
uniform float sweep_left = 0.0;
uniform float sweep_right = 0.0;
uniform float ripple = 0.015;
uniform float ripple_bias = 0.0;
uniform float wave = 7.0;
uniform float wave_from = -0.5;
uniform float wave_to = 0.3;
// The look.
uniform vec4 bone_color : source_color = vec4(0.92, 0.9, 0.82, 1.0);
uniform float bone_glow = 0.18;
uniform vec4 muscle_color : source_color = vec4(0.62, 0.09, 0.08, 1.0);
uniform vec4 septum_color : source_color = vec4(0.93, 0.74, 0.7, 1.0);
uniform vec4 membrane_color : source_color = vec4(0.86, 0.42, 0.4, 1.0);
uniform vec4 vessel_color : source_color = vec4(0.9, 0.04, 0.06, 1.0);
uniform float vessel_glow = 0.7;
uniform float myomeres = 16.0;  // blocks nose to tail
uniform float core = 0.12;  // how thick the body is (of its full size) as it starts to grow

varying vec3 rest;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float dither(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	return (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}

vec3 slice_at(float z) {
	float t = clamp((z - profile_z.x) / max(profile_z.y - profile_z.x, 1e-4), 0.0, 1.0);
	return texture(profile, vec2(t, 0.5)).rgb;
}

void ray_bend(inout vec3 v, inout vec3 n) {
	float side = sign(v.x);
	float reach = max(span - hinge, 0.001);
	float outward = clamp((abs(v.x) - hinge) / reach, 0.0, 1.0);
	float up = rest_flap + (side > 0.0 ? flap_right : flap_left);
	float back = side > 0.0 ? sweep_right : sweep_left;
	float a = wave * v.z - phase;
	float swell = ripple * (1.0 + ripple_bias * side) * mix(0.5, 1.5, smoothstep(wave_from, wave_to, v.z));
	float lift = up * reach * outward * outward * 0.5 + swell * outward * outward * sin(a);
	float lift_x = side * (up * outward + swell * 2.0 * outward / reach * sin(a));
	float lift_z = swell * outward * outward * wave * cos(a);
	float shift = back * reach * outward * outward * 0.5;
	float shift_x = side * back * outward;
	v.y += lift;
	v.z += shift;
	n = vec3(n.x - lift_x * n.y, n.y, n.z - lift_z * n.y);
	n = normalize(vec3(n.x - shift_x * n.z, n.y, n.z));
}

void vertex() {
	rest = VERTEX;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (kind == 0) {
		// Pulled toward the spine's centreline, swelling out as it grows.
		vec3 s = slice_at(v.z);
		vec3 centre = vec3(0.0, s.b, v.z);
		v = mix(centre, v, core + (1.0 - core) * layers.z);
		v += n * 0.003 * step(0.001, layers.w);  // just over the real skin while that washes in
	} else if (kind == 1) {
		float a = TAU * waves * UV.y + UV.x * 2.5 - phase * tempo;
		v += n * flutter * (1.0 + 1.5 * effort) * UV.y * UV.y * sin(a);
	}
	if (jelly) {
		vec3 at = v;
		v = jelly_pulse(at);
		n = jelly_pulse_normal(at, n);
	}
	if (ray_wing && kind != 1) {
		ray_bend(v, n);
	}
	fish_bend(v, n);
	VERTEX = v;
	NORMAL = n;
	// The heart and vessels show through the muscle: drawn a little nearer the
	// eye. (Writing POSITION anywhere means writing it everywhere.)
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (kind >= 4) {
		view.xyz += normalize(-view.xyz) * pulse.z;
	}
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float d = dither(FRAGCOORD.xy);
	float bones = layers.x;
	float cardio = layers.y;
	float grow = layers.z;
	float skin = layers.w;
	vec3 color = bone_color.rgb;
	float glow = 0.0;
	float rough = 0.55;
	if (kind == 0) {
		if (d >= min(grow * 5.0, 1.0) * (1.0 - skin)) {
			discard;
		}
		vec3 s = slice_at(rest.z);
		float t = clamp((rest.z - profile_z.x) / max(profile_z.y - profile_z.x, 1e-4), 0.0, 1.0);
		float dy = (rest.y - s.b) / max(s.g, 1e-3);
		// W-shaped blocks: forward-pointing chevrons above and below the
		// lateral line, the septa between them pale.
		float w = abs(abs(dy) - 0.5);
		float m = t * myomeres - w * 1.4 + abs(dy) * 0.35;
		float line = abs(fract(m) - 0.5);
		float fw = fwidth(m);
		float septum = 1.0 - smoothstep(0.035, 0.07 + fw, 0.5 - line);
		float lateral = 1.0 - smoothstep(0.03, 0.07, abs(dy));
		color = muscle_color.rgb * (0.75 + 0.35 * smoothstep(0.0, 0.5, 0.5 - line));
		color = mix(color, septum_color.rgb, max(septum * 0.75, lateral * 0.45));
		rough = 0.32;
		glow = 0.06;
	} else if (kind == 1) {
		if (d >= 1.0 - skin) {
			discard;
		}
		float across = UV.x * max(rays, 1.0);
		float r = abs(fract(across + 0.5) - 0.5);  // 0 on a ray
		float fw = fwidth(across);
		float fin_bones = clamp((bones - 0.55) / 0.45, 0.0, 1.0);
		bool bone = r < 0.035 + fw * 0.6 && UV.y < fin_bones * 1.02 && d < 0.5 + 0.5 * bones;
		bool membrane = r < grow * 0.56 && d < min(grow * 3.0, 1.0);
		bool vessel = abs(r - 0.14) < 0.025 + fw && UV.y < cardio * 1.05;
		if (bone) {
			color = bone_color.rgb;
			glow = bone_glow;
		} else if (vessel && !membrane) {
			color = vessel_color.rgb;
			glow = vessel_glow * (0.5 + 1.5 * exp(-pow((UV.y - pulse.y * 1.5) * 5.0, 2.0)));
		} else if (membrane) {
			color = membrane_color.rgb;
			glow = 0.05;
		} else {
			discard;
		}
	} else if (kind == 2) {
		if (d >= min(grow * 3.0, 1.0) * (1.0 - skin)) {
			discard;
		}
		color = muscle_color.rgb;
		rough = 0.35;
	} else if (kind == 3) {
		float k = COLOR.r;
		float reach = k < 0.2 ? bones * 2.5 : (k < 0.5 ? (bones - 0.22) * 2.4 : (bones - 0.55) * 2.6);
		// The skull's shell is porous (half its pixels), so it reads as bone, not a helmet.
		float solid = (0.45 + 0.55 * bones) * (k > 0.5 ? 0.5 : 1.0);
		if (COLOR.g > reach || d >= solid) {
			discard;
		}
		color = bone_color.rgb * (k > 0.5 ? 0.8 : 1.0);
		glow = bone_glow;
		rough = 0.7;
	} else if (kind == 4) {
		if (COLOR.g > cardio * 1.12) {
			discard;
		}
		color = vessel_color.rgb;
		float front = pulse.y * 1.6;
		glow = vessel_glow * min(cardio * 4.0, 1.0) * (0.45 + 1.8 * exp(-pow((COLOR.g - front) * 7.0, 2.0)));
		rough = 0.3;
	} else {
		if (d >= min(cardio * 4.0, 1.0)) {
			discard;
		}
		color = vessel_color.rgb * 0.85;
		glow = vessel_glow * (0.6 + 1.6 * pulse.x);
		rough = 0.3;
	}
	ALBEDO = color;
	EMISSION = color * glow;
	ROUGHNESS = rough;
}
