shader_type spatial;
// A lionfish's spines, fin rays and fleshy tentacles (LionfishModel): thin
// tapered tubes, banded along their length, rippling with the fin they hold up
// (lionfish_fin.gdshaderinc).

#include "res://shaders/lionfish_fin.gdshaderinc"

uniform float roughness = 0.4;

void vertex() {
	fin_rest = VERTEX;
	fin_at = UV2;
	fin_vertex(VERTEX, NORMAL, UV2);
}

void fragment() {
	float b = fin_band();
	vec3 color = mix(pale.rgb, fin_band_color(), b);
	// A faint gloss down each spine, darker toward its root in the body.
	color *= mix(0.8, 1.0, smoothstep(0.0, 0.02, fin_at.x));
	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = 0.55;
	BACKLIGHT = color * 0.35;
}
