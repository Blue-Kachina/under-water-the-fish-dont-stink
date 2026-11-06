shader_type spatial;
// The living room seen through the Aquarium arena's glass (planning_marco_polo.md
// §12), out of focus: soft warm and cool blobs (a lamp, a sofa, a window, a
// bookshelf) on a dim wall, all blurred. It ignores the tank's fog and fades to
// `murk` by itself, so the room shows faintly through the water.

render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 wall : source_color = vec3(0.22, 0.18, 0.14);
uniform vec3 murk : source_color = vec3(0.06, 0.13, 0.06);
uniform float murk_amount = 0.6;
uniform float seed = 0.0;

float blob(vec2 uv, vec2 at, vec2 size) {
	vec2 d = (uv - at) / size;
	return exp(-dot(d, d) * 2.0);
}

void fragment() {
	vec2 uv = UV;
	vec3 colour = wall * (0.7 + 0.3 * uv.y);
	// A floor lamp's glow, a window's daylight, a sofa, a shelf of books.
	colour += vec3(1.0, 0.72, 0.4) * blob(uv, vec2(0.18 + seed * 0.3, 0.35), vec2(0.08, 0.12)) * 1.4;
	colour += vec3(0.55, 0.7, 0.9) * blob(uv, vec2(0.72 - seed * 0.2, 0.4), vec2(0.18, 0.22)) * 0.9;
	colour = mix(colour, vec3(0.35, 0.12, 0.1), blob(uv, vec2(0.45, 0.82), vec2(0.3, 0.1)) * 0.8);
	colour = mix(colour, vec3(0.2, 0.25, 0.32), blob(uv, vec2(0.9, 0.6), vec2(0.06, 0.3)) * 0.7);
	colour = mix(colour, vec3(0.1, 0.08, 0.06), smoothstep(0.88, 1.0, uv.y));  // the skirting and floor
	ALBEDO = mix(colour, murk, murk_amount);
}
