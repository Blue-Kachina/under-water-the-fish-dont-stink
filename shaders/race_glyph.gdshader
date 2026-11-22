// A wall arrow for the race track (planning_race.md section 6): three chevrons that point the way round the next bend and
// drift in that direction, glowing and additive, so they read at a distance through the murk. The quad's X axis is the
// direction of the turn; `flip` mirrors it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 glyph_color : source_color = vec3(1.0, 0.7, 0.2);
uniform float strength = 2.2;
uniform float flip = 1.0;
uniform float speed = 0.5;

void fragment() {
	float t = (UV.x - 0.5) * flip;     // along the arrow: + is the way to go
	float h = (0.5 - UV.y) * 2.0;      // across it, -1..1
	float band = fract((t + 0.55 * abs(h)) * 2.2 - TIME * speed);
	float chevron = smoothstep(0.0, 0.08, band) * (1.0 - smoothstep(0.34, 0.42, band));
	float edge = (1.0 - smoothstep(0.7, 0.95, abs(h))) * (1.0 - smoothstep(0.38, 0.5, abs(t)));
	ALBEDO = glyph_color * strength;
	ALPHA = chevron * edge;
}
