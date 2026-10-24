shader_type canvas_item;
// Unnatural's hurt feedback (UnnaturalHud, the Playability pass P3): the view's
// edges flush red when you're hit (`hurt`, 1 fading to 0) and, while you're low
// on hp, beat with your heart (`beat`, a lub-dub 0..1) over a faint standing
// red (`low`, 0..1: how low). Ragged at the edge like blood in the water.

uniform float hurt = 0.0;
uniform float beat = 0.0;
uniform float low = 0.0;
uniform float aspect = 1.7778;
uniform vec4 red : source_color = vec4(0.75, 0.0, 0.04, 1.0);

void fragment() {
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(c) / length(vec2(aspect, 1.0) * 0.5);  // 0 centre, 1 corner
	float angle = atan(c.y, c.x);
	float ragged = 0.04 * sin(angle * 7.0 + TIME * 0.7) + 0.03 * sin(angle * 13.0 - TIME * 1.1);
	float strength = clamp(hurt + beat * 0.7 + low * 0.25, 0.0, 1.5);
	float inner = mix(0.95, 0.45, clamp(strength, 0.0, 1.0)) + ragged;
	float edge = smoothstep(inner, inner + 0.45, r);
	COLOR = vec4(red.rgb * (0.8 + 0.4 * hurt), clamp(edge * 0.85 * strength, 0.0, 0.9));
}
