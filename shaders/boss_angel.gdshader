shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// The Fallen Angel (FallenAngelBoss): a giant zombie sea angel. Its body is
// glass-clear (the orange organs show through: boss_angel_organ), built head up
// at z 0 and bent along its upright spine (spine_bend.gdshaderinc); its wings
// (is_wing) are plain nodes beating at its shoulders, not bent.
// - The glass: milky blue-white, clearer face on and bright at the edges (a
//   Fresnel rim that also glows faintly, so the shape reads in the dark), with
//   fine muscle bands running down the body and a wet sheen.
// - The light inside: the orange head and gut scatter a warm glow into the
//   glass round them.
// - The rot: grey-green necrotic patches, more opaque, eating into it; the
//   wings' edges torn into holes.
// - The tail's tip and the horns: orange.
// flash, warn, rage and dissolve come from the boss.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform float height = 40.0;
uniform bool is_wing = false;
uniform vec4 glass : source_color = vec4(0.8, 0.88, 0.95, 1.0);
uniform vec4 rim_glow : source_color = vec4(0.62, 0.8, 1.0, 1.0);
uniform vec4 inner_glow : source_color = vec4(1.0, 0.5, 0.18, 1.0);
uniform vec4 rot_color : source_color = vec4(0.4, 0.44, 0.34, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.42, 0.1, 1.0);
uniform float rot_amount = 0.4;
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;
uniform float rage = 0.0;

varying vec3 rest;
varying vec2 ring;
varying float part;
varying float along;

void vertex() {
	rest = VERTEX;
	ring = COLOR.rg * 2.0 - 1.0;
	part = UV2.x;
	along = COLOR.b;
	if (!is_wing) {
		spine_bend(VERTEX, NORMAL, UV2.y);
	}
}

float band(float d, float w) {
	float aa = fwidth(d) * 1.5 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	vec3 p = rest / max(height, 1.0) * 40.0;
	if (dissolve > 0.0 && skin_noise(p * 0.7 + 3.0) < dissolve) {
		discard;
	}
	float rot = smoothstep(0.58, 0.78, skin_fbm(p * 0.2 + vec3(1.7, 0.0, 4.2))) * rot_amount;
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 color = glass.rgb;
	float alpha;
	float warm = 0.0;
	if (is_wing) {
		// A thin paddle: veins fanning from the root, torn and rotting at the edge.
		float edge = UV.y;
		vec2 at = vec2(UV.x * 5.0, edge * 3.0);
		float tear = skin_fbm(vec3(at, 2.0 + COLOR.a * 0.0));
		if (edge > 0.55 && tear < (edge - 0.55) * 1.6) {
			discard;
		}
		if (skin_fbm(vec3(at * 2.2, 7.0)) > 0.78 && edge > 0.3) {
			discard;  // holes rotted through
		}
		float vein = band(fract(UV.x * 9.0 + edge * 0.6) - 0.5, 0.05) * (1.0 - edge * 0.6);
		color = mix(color, vec3(0.95, 0.97, 1.0), vein * 0.4);
		rot = max(rot, smoothstep(0.55, 1.0, edge) * 0.5 * smoothstep(0.35, 0.65, tear + 0.2));
		alpha = 0.42 + glance * 0.45 + vein * 0.2;
	} else {
		// Fine muscle bands down the body, and the milky jelly thicker toward the edges.
		float bands = band(fract(atan(ring.x, ring.y) / TAU * 30.0 + skin_noise(p * 0.25) * 0.6) - 0.5, 0.12);
		bands *= smoothstep(0.18, 0.3, along) * (1.0 - smoothstep(0.85, 0.98, along));
		color = mix(color, vec3(0.96, 0.98, 1.0), bands * 0.35);
		alpha = 0.24 + glance * 0.6 + bands * 0.06;
		// The orange insides light the glass round them: the head's in the hood,
		// the gut's down the front of the body.
		float front = ring.y * 0.5 + 0.5;
		warm = exp(-pow((along - 0.1) / 0.07, 2.0)) * 0.9 + exp(-pow((along - 0.36) / 0.15, 2.0)) * 0.55 * front;
		color = mix(color, mix(color, inner_glow.rgb, 0.55), clamp(warm, 0.0, 1.0));
	}
	color = mix(color, rot_color.rgb * mix(0.7, 1.1, skin_noise(p * 1.3)), rot);
	alpha = max(alpha, rot * 0.85);
	float tip = is_wing ? 0.0 : smoothstep(0.88, 0.97, along);
	if (part > 4.5 && part < 5.5) {
		tip = 0.25 + 0.5 * UV.x;  // the horns, oranger toward their points
	}
	color = mix(color, tip_color.rgb, tip);
	alpha = mix(alpha, 0.9, tip);
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 0.95);
	ROUGHNESS = mix(0.05, 0.45, rot);
	SPECULAR = 0.9;
	EMISSION = rim_glow.rgb * glance * 0.22 * (1.0 - rot) + inner_glow.rgb * warm * 0.18 + tip_color.rgb * tip * 0.4
			+ vec3(1.0, 0.4, 0.3) * flash * 0.8 + vec3(1.0, 0.05, 0.02) * (warn * 2.0 + rage * 0.3) * (0.3 + glance);
}
