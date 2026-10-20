shader_type spatial;
render_mode cull_back;
// A mantis shrimp's stalked compound eye (MantisModel): the stalk (vertex colour
// red 0) in the body's `albedo` (set_body_color() tints it), the eye (red 1) an
// oval of two glossy hemispheres split by a dark midband of six ommatidia rows,
// with fine facets and the three pseudopupils of a trinocular eye: dark spots
// where the ommatidia look at the viewer, the hemispheres' tilted toward the
// midband. The eye swivels on its stalk on its own (`phase`, `seed`), as they
// do. The mesh's origin is the stalk's root.

#include "res://shaders/fish_skin.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.23, 0.6, 0.24, 1.0);
uniform vec4 eye_color : source_color = vec4(0.3, 0.7, 0.35, 1.0);
uniform vec4 eye_color2 : source_color = vec4(0.25, 0.55, 0.4, 1.0);
uniform vec4 band_color : source_color = vec4(0.06, 0.08, 0.06, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.5, 0.75, 0.9, 1.0);
uniform vec3 centre = vec3(0.0, 0.1, 0.0);  // the eye's middle, from the root
uniform vec3 radii = vec3(0.03, 0.04, 0.03);
uniform float band = 0.12;  // half the midband's height, of the eye's
uniform float seed = 0.0;
uniform float swivel = 0.35;  // rad
uniform float phase = 0.0;
uniform float effort = 0.0;

varying vec3 local;
varying float is_eye;
varying vec3 up_view;

vec3 turn(vec3 v, float yaw, float pitch) {
	float cy = cos(yaw);
	float sy = sin(yaw);
	v = vec3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy);
	float cp = cos(pitch);
	float sp = sin(pitch);
	return vec3(v.x, v.y * cp - v.z * sp, v.y * sp + v.z * cp);
}

void vertex() {
	local = (VERTEX - centre) / radii;
	is_eye = COLOR.r;
	float yaw = swivel * (0.7 * sin(phase * 0.23 + seed) + 0.3 * sin(phase * 0.61 + seed * 2.3));
	float pitch = swivel * 0.45 * sin(phase * 0.37 + seed * 1.7);
	VERTEX = turn(VERTEX, yaw, pitch);
	NORMAL = turn(NORMAL, yaw, pitch);
	up_view = normalize((MODELVIEW_MATRIX * vec4(turn(vec3(0.0, 1.0, 0.0), yaw, pitch), 0.0)).xyz);
}

void fragment() {
	if (is_eye < 0.5) {
		vec3 col = albedo.rgb * (0.85 + 0.25 * skin_fbm(local * 6.0));
		ALBEDO = col;
		ROUGHNESS = 0.3;
		CLEARCOAT = 0.6;
	} else {
		vec3 d = normalize(local);
		float y = d.y;
		float aa = fwidth(y) + 1e-4;
		vec3 col = mix(eye_color2.rgb, eye_color.rgb, smoothstep(-0.1, 0.1, y));
		col *= mix(0.75, 1.1, smoothstep(-0.9, 0.6, y));
		// Facets: a fine hexagonal-ish grain.
		vec2 g = vec2(atan(d.x, d.z) * 18.0, y * 22.0);
		g.x += 0.5 * mod(floor(g.y), 2.0);
		vec2 f = fract(g) - 0.5;
		col *= 0.88 + 0.12 * smoothstep(0.5, 0.2, length(f));
		// The midband: six rows, dark with pale stripes.
		float in_band = 1.0 - smoothstep(band - aa, band + aa, abs(y));
		float rows = fract((y + band) / (2.0 * band) * 6.0);
		vec3 band_col = mix(band_color.rgb, stripe_color.rgb, smoothstep(0.35, 0.5, abs(rows - 0.5)) * 0.35);
		col = mix(col, band_col, in_band);
		// Pseudopupils: where the ommatidia face the viewer, the hemispheres'
		// looking in toward the midband.
		float hemi = in_band > 0.5 ? 0.0 : sign(y);
		vec3 n = normalize(NORMAL - up_view * hemi * 0.45);
		float pupil = smoothstep(0.93, 0.985, dot(n, VIEW));
		col = mix(col, col * 0.15, pupil * 0.8);
		ALBEDO = col;
		ROUGHNESS = 0.12;
		SPECULAR = 0.7;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.05;
	}
}
