shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// One of the Fallen Angel's six crown tentacles (FallenAngelBoss): a tube built
// straight along +z, rest_length long, drawn `length` long and curled in an even
// arc toward its +y by `curl` (rad, root to tip; negative curls the other way),
// writhing a little. Translucent like the body: pale and glassy at its edges
// with an orange core showing through, the core flushing over the whole of it
// with `flush` as it feeds, its blunt tip paler.

uniform float rest_length = 16.0;
uniform float length = 16.0;
uniform float curl = 0.0;
uniform float flush = 0.0;
uniform float flash = 0.0;
uniform vec4 pale : source_color = vec4(0.94, 0.93, 0.9, 1.0);
uniform vec4 orange : source_color = vec4(1.0, 0.48, 0.12, 1.0);

varying float along;

void vertex() {
	float s = length / max(rest_length, 0.001);
	along = clamp(VERTEX.z / max(rest_length, 0.001), 0.0, 1.0);
	float z = VERTEX.z * s;
	float a = curl * along + 0.12 * sin(TIME * 3.0 + along * 7.0) * along;
	vec3 c;
	if (abs(a) < 0.0005) {
		c = vec3(0.0, 0.0, z);
	} else {
		float r = z / a;
		c = vec3(0.0, r * (1.0 - cos(a)), r * sin(a));
	}
	vec3 y_dir = vec3(0.0, cos(a), -sin(a));
	vec3 z_dir = vec3(0.0, sin(a), cos(a));
	float thick = mix(1.0, sqrt(max(s, 0.05)), 0.5);
	VERTEX = c + vec3(VERTEX.x * thick, 0.0, 0.0) + y_dir * VERTEX.y * thick;
	NORMAL = normalize(vec3(NORMAL.x, 0.0, 0.0) + y_dir * NORMAL.y + z_dir * NORMAL.z);
}

void fragment() {
	float face = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float glance = pow(1.0 - face, 2.0);
	// The core: orange through the middle (face on), more of it as it flushes.
	float core = smoothstep(0.35, 0.9, face) * mix(0.45, 1.0, flush) * (1.0 - smoothstep(0.8, 0.95, along) * 0.6);
	vec3 color = mix(pale.rgb, orange.rgb, clamp(core + flush * 0.35 * along, 0.0, 1.0));
	// Faint rings along it.
	color *= 0.93 + 0.07 * sin(along * 110.0);
	ALBEDO = color;
	ALPHA = clamp(0.5 + glance * 0.4 + core * 0.3, 0.0, 0.95);
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	EMISSION = orange.rgb * (core * 0.4 + flush * 0.2) + pale.rgb * glance * 0.15 + vec3(1.0, 0.4, 0.3) * flash * 0.6;
}
