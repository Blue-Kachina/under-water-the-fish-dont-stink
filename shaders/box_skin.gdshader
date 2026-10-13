shader_type spatial;
// A boxfish's skin (FishModel._build_boxfish): `albedo` (the colour
// set_body_color() tints) armoured in faint hexagonal plates, most with a black
// spot in the middle, a little paler underneath. Painted from the resting shape
// onto its three faces' planes and blended round the rounded edges.

uniform vec4 albedo : source_color = vec4(1.0, 0.8, 0.06, 1.0);
uniform vec4 plate_color : source_color = vec4(1.0, 0.95, 0.65, 1.0);
uniform vec4 spot_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float plate_size = 0.07;  // m across

varying vec3 rest;
varying vec3 rest_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// x: 1 on a plate's edge; y: 1 inside its spot.
vec2 plates(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = floor((p - gv) / h + 0.5);  // whole numbers, so every pixel of a plate hashes alike
	vec2 q = abs(gv);
	float inside = 0.5 - max(dot(q, normalize(r)), q.x);  // 0 at the edge
	float aa = length(fwidth(p));
	float edge = 1.0 - smoothstep(0.015, 0.04 + aa, inside);
	float chance = hash(id);
	float radius = mix(0.13, 0.22, fract(chance * 13.7));
	float spot = (1.0 - smoothstep(radius - aa, radius + aa, length(gv))) * step(chance, 0.75);
	return vec2(edge, spot);
}

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
}

void fragment() {
	vec3 weight = pow(abs(normalize(rest_normal)), vec3(10.0));  // sharp, so spots on the edges blend less
	weight /= weight.x + weight.y + weight.z;
	vec2 marks = plates(rest.zy / plate_size) * weight.x + plates(rest.xz / plate_size) * weight.y
			+ plates(rest.xy / plate_size) * weight.z;
	vec3 color = mix(albedo.rgb, plate_color.rgb, 0.25 * smoothstep(-0.2, -0.8, rest_normal.y));
	color = mix(color, plate_color.rgb, marks.x * 0.35);
	color = mix(color, spot_color.rgb, marks.y);
	ALBEDO = color;
	ROUGHNESS = 0.4;
	SPECULAR = 0.6;
}
