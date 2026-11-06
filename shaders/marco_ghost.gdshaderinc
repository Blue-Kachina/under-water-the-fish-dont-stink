// Shared by marco_ghost.gdshader and marco_ghost_walls.gdshader (MarcoScan's
// ghosts): one soft glowing point per cell a fish moved through as the scan
// passed, camera-facing quads from a MultiMesh. COLOR.r is the cell's heat
// (how much movement, 0..1), COLOR.g how much of a streak's head it is (0 the
// old tail .. 1 the newest cell), COLOR.a what's left of its fade.
// The streak has its own colour (amber to white-hot), not the pulse's mint.

uniform vec4 cold : source_color = vec4(0.35, 0.62, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float point_size = 0.3;
uniform float strength = 1.0;
uniform float glow = 2.5;

varying float heat;
varying float head;
varying float life;

void vertex() {
	heat = COLOR.r;
	head = COLOR.g;
	life = COLOR.a;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= point_size * (0.7 + 0.6 * heat + 0.5 * head);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float soft = 1.0 - smoothstep(0.0, 1.0, d);
	float lit = clamp(heat * 0.6 + head, 0.0, 1.0);
	ALBEDO = mix(cold.rgb, hot.rgb, lit);
	ALPHA = clamp(soft * soft * sqrt(life) * (0.05 + 0.4 * heat + 0.3 * head) * strength * glow, 0.0, 1.0);
}
