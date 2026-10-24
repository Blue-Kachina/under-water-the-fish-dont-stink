shader_type spatial;
render_mode cull_disabled;
// A Whale Fall's giant hagfish (WhaleFallBoss): painted from its rest shape
// (BossMesh's channels), bent along its rope (spine_bend.gdshaderinc).
// - Body: pinkish grey, darker and more purple along the back, finely wrinkled
//   round its length, slick with slime; a row of pale slime pores low on each
//   flank; two faint pale eyespots under the skin of its blind head.
// - Barbels (FILAMENT): paler, pinker. Teeth (BONE): yellow keratin combs.
//   The tail's fold (FIN): thin, translucent-looking.
// flash, warn (its lunge winding up), rage and dissolve (dying) from the boss.

#include "res://shaders/fish_skin.gdshaderinc"
#include "res://shaders/spine_bend.gdshaderinc"

uniform vec4 skin : source_color = vec4(0.62, 0.45, 0.45, 1.0);
uniform vec4 back : source_color = vec4(0.36, 0.25, 0.3, 1.0);
uniform vec4 bone : source_color = vec4(0.88, 0.74, 0.38, 1.0);
uniform float radius = 1.2;
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
	if (dissolve > 0.0 && skin_noise(rest * 1.1 + 7.0) < dissolve) {
		discard;
	}
	vec3 color;
	float rough = 0.2;
	float up = ring.y;
	if (part < 0.5) {
		color = mix(skin.rgb, back.rgb, smoothstep(0.1, 0.9, up));
		color *= mix(0.88, 1.08, skin_fbm(rest * 0.9));
		// Fine wrinkles round its length, wandering.
		float wr = band(fract(rest.z / (radius * 0.12) + skin_noise(rest * 1.5) * 1.2) - 0.5, 0.18);
		color = mix(color, color * 0.85, wr * 0.35);
		// Slime pores: a row of pale dots low on each flank.
		float zz = rest.z / (radius * 0.7);
		float pore = (1.0 - smoothstep(0.06, 0.12, length(vec2(fract(zz) - 0.5, (up + 0.45) * 3.0) * vec2(1.0, 0.8))));
		pore *= smoothstep(0.08, 0.15, along) * (1.0 - smoothstep(0.85, 0.95, along)) * step(0.3, abs(ring.x));
		color = mix(color, vec3(0.92, 0.9, 0.82), pore * 0.85);
		// Two faint eyespots under the skin of its blind head.
		float spot = 1.0 - smoothstep(radius * 0.12, radius * 0.22, length(vec2(rest.z - radius * 0.9, rest.y - radius * 0.55)));
		color = mix(color, vec3(0.85, 0.72, 0.7), spot * step(0.2, abs(ring.x)) * 0.6);
		// The mouth: a dark slit across the front of its head, underneath.
		float mouth = (1.0 - smoothstep(radius * 0.2, radius * 0.45, rest.z)) * smoothstep(-0.2, -0.6, up);
		color = mix(color, vec3(0.2, 0.04, 0.05), mouth);
		// Slime: a glossy wet sheen.
		float graze = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		color += vec3(0.08, 0.09, 0.06) * graze;
		rough = mix(0.08, 0.25, skin_noise(rest * 0.8));
	} else if (part < 1.5) {
		color = skin.rgb * mix(0.65, 0.95, UV.y);
		rough = 0.25;
	} else if (part < 2.5) {
		color = mix(bone.rgb * 0.6, bone.rgb, UV.x);
		rough = 0.3;
	} else {
		color = mix(skin.rgb * 1.15, vec3(0.85, 0.55, 0.55), UV.x * 0.6);
		rough = 0.25;
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	SPECULAR = 0.7;
	EMISSION = vec3(1.0, 0.4, 0.35) * flash * 0.7 + vec3(1.0, 0.06, 0.04) * warn * 2.2 + vec3(0.5, 0.05, 0.08) * rage * 0.3;
}
