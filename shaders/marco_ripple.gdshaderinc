// Shared by marco_ripple.gdshader and marco_ripple_walls.gdshader.
uniform vec4 cold : source_color = vec4(0.35, 0.62, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float strength = 1.0;
uniform float glow = 1.0;
uniform float width = 0.09;

varying float power;
varying float life;

void vertex() {
	power = COLOR.r;
	life = COLOR.a;
	float radius = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= radius * 2.0;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	// A thin bright ring at the rim, soft on its inside (the wave's trailing swell).
	float rim = smoothstep(1.0 - width * 2.0, 1.0 - width, d) * (1.0 - smoothstep(1.0 - width, 1.0, d));
	float swell = smoothstep(0.55, 1.0, d) * (1.0 - smoothstep(1.0 - width, 1.0, d)) * 0.25;
	float a = (rim + swell) * life * life * power * strength * glow;
	ALBEDO = mix(cold.rgb, hot.rgb, clamp(power * life, 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 1.0);
}
