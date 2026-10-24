shader_type spatial;
// The Rotten Sardine's body (ZombieLooks.sardine): a slim lofted fish (UV.x
// nose 0 to tail 1, UV.y round from the top). A dark blue-green back over
// bright silver flanks and a white belly, with a row of dark spots along the
// upper flank and a faint gold stripe. The Horde's rot overlay goes over it.

#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.12, 0.3, 0.36, 1.0);  // the back
uniform vec4 flank : source_color = vec4(0.86, 0.89, 0.92, 1.0);
uniform vec4 belly : source_color = vec4(0.95, 0.96, 0.97, 1.0);
uniform vec4 spot_color : source_color = vec4(0.06, 0.1, 0.14, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.75, 0.65, 0.35, 1.0);

varying float up;

void vertex() {
	up = cos(UV.y * TAU);  // 1 the top, -1 the belly
	fish_bend(VERTEX, NORMAL);
}

void fragment() {
	float back = smoothstep(0.15, 0.55, up);
	float under = smoothstep(-0.2, -0.75, up);
	vec3 color = mix(flank.rgb, albedo.rgb, back);
	color = mix(color, belly.rgb, under);
	// Round spots along the upper flank, from behind the gill to mid body.
	float along = UV.x;
	vec2 offset = vec2((fract(along * 22.0) - 0.5) * 0.9, (up - 0.2) / 0.11);
	float spot = smoothstep(0.42, 0.28, length(offset)) * smoothstep(0.2, 0.24, along) * smoothstep(0.64, 0.58, along);
	color = mix(color, spot_color.rgb, spot * 0.85);
	float stripe = exp(-pow((up - 0.05) / 0.04, 2.0)) * smoothstep(0.15, 0.3, along) * smoothstep(0.9, 0.7, along);
	color = mix(color, stripe_color.rgb, stripe * 0.35);
	// The gill cover's edge.
	float gill = exp(-pow((along - 0.2) / 0.012, 2.0)) * smoothstep(0.7, 0.2, abs(up));
	color *= 1.0 - gill * 0.35;
	// The silver catches the light at a glance, a sheen that reads even in dim water.
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float silver = 1.0 - back;
	ALBEDO = color + vec3(0.25, 0.3, 0.33) * glance * silver;
	METALLIC = 0.35 * silver;
	ROUGHNESS = mix(0.35, 0.18, silver);
	SPECULAR = 0.7;
}
