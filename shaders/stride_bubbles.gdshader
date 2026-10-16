shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
// A stride's puff of tiny bubbles (StrideBubbles): faint, with a soft rim in
// the timing's colour (per bubble, from the MultiMesh's colours; alpha fades it).

varying vec4 tone;

void vertex() {
	tone = COLOR;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 1.8);
	ALBEDO = mix(tone.rgb * 1.4, vec3(1.0), rim * 0.3);  // bright enough to tell the colours apart
	ALPHA = tone.a * (0.3 + 0.6 * rim);
}
