shader_type spatial;
render_mode cull_disabled;
// The Lamprey Queen (LampreyBoss): a giant sea lamprey. Painted from its rest
// shape (BossMesh's channels), bent along its swim path (spine_bend.gdshaderinc).
// - Body: a sea lamprey's olive-brown back marbled darker, fading to a yellowish
//   belly, slick with slime (a wet sheen). Seven gill holes each side behind the
//   eye, raw red inside, glowing as she breathes (`breath`, brighter while she
//   spits). Old scars where her brood fed.
// - The oral disc (INSIDE): pinkish-red rasping flesh, darker toward the throat.
// - Teeth (BONE): yellowed, browner at the base. Fins: thin brown membrane.
// flash, warn, rage and dissolve come from the boss.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform vec4 back_color : source_color = vec4(0.27, 0.24, 0.15, 1.0);
uniform vec4 marble : source_color = vec4(0.1, 0.09, 0.06, 1.0);
uniform vec4 belly : source_color = vec4(0.62, 0.55, 0.36, 1.0);
uniform vec4 disc_color : source_color = vec4(0.62, 0.2, 0.18, 1.0);
uniform vec4 bone : source_color = vec4(0.86, 0.74, 0.44, 1.0);
uniform vec4 gill_glow : source_color = vec4(1.0, 0.22, 0.08, 1.0);
uniform float gill_z = 9.0;  // m, the first gill hole
uniform float gill_step = 2.0;  // m between them
uniform float gill_size = 0.6;  // m, a hole's radius
uniform float gill_up = 0.15;  // round the body (cos: 1 top) the row sits at
uniform float radius = 3.7;  // m, the body's radius
uniform float breath = 0.0;  // 0..1, how wide the gills glow now
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
	spine_bend(VERTEX, NORMAL, UV2.y);
}

float band(float d, float w) {
	float aa = fwidth(d) * 1.5 + 1e-4;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (dissolve > 0.0 && skin_noise(rest * 0.7 + 3.0) < dissolve) {
		discard;
	}
	vec3 color;
	float rough = 0.25;
	float glow = 0.0;
	vec3 glow_color = gill_glow.rgb;
	float s = sign(rest.x + 1e-5);
	float up = ring.y;
	if (part < 0.5) {
		// Olive-brown back marbled darker, a yellowish belly.
		float m = skin_fbm(vec3(rest.z * 0.18, rest.y * 0.35, rest.x * 0.35));
		float veins = band(m - 0.5, 0.035) + band(skin_fbm(vec3(rest.z * 0.4, rest.y * 0.7, s * 2.0)) - 0.52, 0.02);
		color = mix(back_color.rgb, back_color.rgb * 0.65, smoothstep(0.35, 0.65, m));
		color = mix(color, marble.rgb, clamp(veins, 0.0, 1.0) * 0.7 * smoothstep(-0.3, 0.3, up));
		color = mix(color, belly.rgb * mix(0.85, 1.0, m), smoothstep(-0.15, -0.65, up));
		color *= mix(0.9, 1.05, skin_noise(rest * 2.4));
		// Slime: a wet, oily sheen in the light.
		float graze = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
		color += vec3(0.06, 0.07, 0.04) * graze;
		rough = mix(0.12, 0.28, skin_noise(rest * 0.6));
		// Seven gill holes each side, raw inside, glowing as she breathes.
		float zg = (rest.z - gill_z) / gill_step;
		float k = clamp(round(zg), 0.0, 6.0);
		vec2 hole = vec2((zg - k) * gill_step, (up - gill_up) * radius);
		hole += (vec2(skin_noise(rest * 2.0), skin_noise(rest * 2.0 + 9.0)) - 0.5) * gill_size * 0.35;
		float d = length(hole * vec2(1.7, 0.75));
		float side_ok = smoothstep(0.15, 0.4, abs(ring.x));
		float pit = (1.0 - smoothstep(gill_size * 0.55, gill_size * 0.75, d)) * side_ok;
		float lip = band(d - gill_size * 0.82, gill_size * 0.12) * side_ok;
		color = mix(color, color * 1.25 + 0.04, lip * 0.6);
		color = mix(color, vec3(0.25, 0.02, 0.02), pit);
		glow += pit * (0.08 + breath * 1.1 + rage * 0.4);
		// Old scars where her brood fed: pale rings.
		vec2 cell = vec2(rest.z, atan(rest.x, rest.y) * radius) / 3.0;
		vec2 id = floor(cell);
		vec2 f = fract(cell) - 0.5;
		float scar = step(0.88, skin_hash(vec3(id, 7.0))) * band(length(f) - 0.16, 0.025) * smoothstep(0.12, 0.25, along);
		color = mix(color, vec3(0.7, 0.6, 0.45), scar * 0.8);
	} else if (part < 1.5) {
		// Thin brown fin membrane, rays faintly paler.
		float ray = band(fract(UV.x * 60.0) - 0.5, 0.1);
		color = mix(back_color.rgb * 0.8, back_color.rgb * 1.2, ray * 0.4) * mix(0.8, 1.05, UV.y);
		rough = 0.35;
	} else if (part < 2.5) {
		// Teeth: yellowed, browner at the root.
		color = mix(bone.rgb * 0.55, bone.rgb, smoothstep(0.0, 0.7, UV.x));
		rough = 0.3;
	} else {
		// The oral disc: rasping red flesh, darker toward the throat.
		float depth = UV.x;
		color = mix(disc_color.rgb, disc_color.rgb * 0.25, smoothstep(0.3, 1.0, depth));
		color *= mix(0.75, 1.1, skin_fbm(rest * 3.0));
		float ridge = band(fract(depth * 9.0) - 0.5, 0.08);
		color = mix(color, color * 1.4, ridge * 0.5);
		rough = 0.18;
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	SPECULAR = 0.7;
	EMISSION = glow_color * glow + vec3(1.0, 0.4, 0.3) * flash * 0.8 + vec3(1.0, 0.05, 0.02) * warn * 2.5;
}
