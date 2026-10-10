shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// Air bubble: the water behind shows through bent outwards (air in water acts as
// a diverging lens), a bright silvery rim where light reflects off at grazing
// angles (total internal reflection), a faint thin-film shimmer, and a slow wobble.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.8, 0.95, 1.0);
uniform float refraction = 0.06;
uniform float rim_power = 2.2;
uniform float rim_strength = 1.4;
uniform float wobble = 0.035;
// Set by the ball: direction of travel and how much to stretch along it.
uniform vec3 stretch_dir = vec3(0.0, 1.0, 0.0);
uniform float stretch = 0.0;

void vertex() {
	vec3 p = VERTEX;
	float w = sin(TIME * 3.1 + p.y * 4.0) * sin(TIME * 2.3 + p.x * 3.5) + 0.5 * sin(TIME * 4.7 + p.z * 5.0);
	p += NORMAL * w * wobble;
	// Stretch along travel and pinch across it, keeping the volume about the same.
	vec3 dir = normalize((inverse(MODEL_MATRIX) * vec4(stretch_dir, 0.0)).xyz);
	float along = dot(p, dir);
	p += dir * along * stretch - (p - dir * along) * stretch * 0.5;
	VERTEX = p;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);

	// Sample outwards from the centre so the view behind is shrunk. Screen y runs down.
	vec2 bend = vec2(NORMAL.x, -NORMAL.y) * refraction * (1.0 - facing * 0.5);
	vec3 behind = textureLod(screen_texture, SCREEN_UV + bend, 1.0).rgb;

	vec3 film = 0.5 + 0.5 * cos(6.28318 * (rim * 1.3 + TIME * 0.05 + vec3(0.0, 0.33, 0.67)));
	vec3 rim_color = mix(tint, film, 0.35) * rim * rim_strength;

	ALBEDO = vec3(0.0);
	EMISSION = behind * mix(1.05, 0.6, rim) * tint + rim_color;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = 1.0;
}
