shader_type spatial;
// A lifelike fish eye (FishModel._real_eye): a glossy ball looking along its
// -Z, with a big dark pupil, a metallic iris ring (fine fibres, a darker
// limbal edge) and a dark rim where it sits in the head. A wet cornea's sharp
// highlight comes from the light, not painted on. On a unit sphere (0.5 m
// radius), sized by its node's scale.

uniform vec4 iris : source_color = vec4(0.75, 0.6, 0.25, 1.0);
uniform vec4 iris_inner : source_color = vec4(0.35, 0.25, 0.08, 1.0);  // round the pupil
uniform vec4 rim_color : source_color = vec4(0.08, 0.07, 0.06, 1.0);  // round the iris, sunk in the head
uniform float pupil = 0.42;  // its radius, of the visible disc's
uniform float iris_size = 0.82;  // the iris's radius, of the visible disc's
uniform float pupil_stretch = 1.0;  // 1 round; more stretches it side to side (sharks, rays)
uniform float sheen = 0.45;  // how metallic the iris is

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

float eye_hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	// How far from the eye's centre, 0 there to 1 at the side of the ball.
	vec2 face = dir.xy;
	float r = length(vec2(face.x / pupil_stretch, face.y));
	float around = atan(face.y, face.x);
	float aa = fwidth(r) * 1.5;
	float back = 1.0 - smoothstep(-0.2, 0.0, -dir.z);  // the half facing away
	float fibre = eye_hash(floor(around * 40.0)) * 0.5 + eye_hash(floor(around * 97.0)) * 0.5;
	vec3 iris_color = mix(iris_inner.rgb, iris.rgb, smoothstep(pupil, iris_size, length(face)));
	iris_color *= 0.75 + 0.45 * fibre;
	iris_color *= 1.0 - 0.55 * smoothstep(iris_size * 0.85, iris_size, length(face));
	vec3 color = mix(iris_color, rim_color.rgb, smoothstep(iris_size - aa, iris_size + aa, length(face)));
	float in_pupil = 1.0 - smoothstep(pupil - aa, pupil + aa, r);
	color = mix(color, vec3(0.005), in_pupil);
	color = mix(color, rim_color.rgb, back);
	float on_iris = (1.0 - in_pupil) * (1.0 - smoothstep(iris_size - aa, iris_size + aa, length(face))) * (1.0 - back);
	ALBEDO = color;
	METALLIC = sheen * on_iris;
	ROUGHNESS = 0.04;
	SPECULAR = 0.8;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
