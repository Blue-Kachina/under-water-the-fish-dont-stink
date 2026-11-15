#[compute]
#version 450
// Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md
// The water look's grade pass (planning_abyssal_look.md, phase 1), run per camera on the
// linear HDR picture just before tonemapping: a vignette worked out against this view's own
// shape, a luminance S-curve applied by ratio (so hue is kept), and highlights that lose colour.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
	vec2 size;
	float vignette;
	float vignette_start;
	float curve;
	float desat;
	float desat_start;
	float exposure;
} p;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) {
		return;
	}
	vec4 src = imageLoad(color_image, px);
	vec3 col = src.rgb * p.exposure;  // depth exposure (phase 2)

	// Vignette: 0 at the centre, 1 at the corners, whatever the view's shape.
	vec2 aspect = vec2(p.size.x / p.size.y, 1.0);
	vec2 q = ((vec2(px) + 0.5) / p.size - 0.5) * aspect;
	float r = length(q) / (0.5 * length(aspect));
	col *= 1.0 - p.vignette * smoothstep(p.vignette_start, 1.0, r);

	// S-curve on luminance, by ratio, below white (HDR above is left alone).
	float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
	if (l > 1e-4 && l < 1.0) {
		float s = mix(l, l * l * (3.0 - 2.0 * l), p.curve);
		col *= s / l;
		l = s;
	}

	// Highlights desaturate toward their own luminance.
	col = mix(col, vec3(l), p.desat * smoothstep(p.desat_start, p.desat_start + 1.0, l));

	imageStore(color_image, px, vec4(col, src.a));
}
