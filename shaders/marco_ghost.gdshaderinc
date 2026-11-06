// Shared by marco_ghost.gdshader and marco_ghost_walls.gdshader (MarcoScan's
// ghosts): one soft glowing point per cell a fish moved through as the scan
// passed, camera-facing quads from a MultiMesh. COLOR.r is the cell's heat
// (how much movement, 0..1), COLOR.a what's left of its fade.

uniform vec4 cold : source_color = vec4(0.2, 0.75, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.6, 1.0, 0.85, 1.0);
uniform float point_size = 0.3;
uniform float strength = 1.0;

varying float heat;
varying float life;

void vertex() {
	heat = COLOR.r;
	life = COLOR.a;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= point_size * (0.7 + 0.6 * heat);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float soft = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = mix(cold.rgb, hot.rgb, heat);
	ALPHA = clamp(soft * soft * life * life * (0.02 + 0.16 * heat) * strength, 0.0, 1.0);
}
