shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

// Marco Polo's self view (HiderLooks): once a hider is less than fully visible
// to the seekers, a dashed outline round their body keeps them in their own
// sight, like a sketch about to be drawn. A copy of the body drawn with this,
// pushed out a little: only its rim (where the surface turns away from the
// view) draws, in dashes that march along the body and wobble like a pencil.
// It bends with the body (fish_bend.gdshaderinc). Fog off, so the murk never
// hides it.

#include "res://shaders/fish_bend.gdshaderinc"

uniform vec4 color : source_color = vec4(0.94, 0.97, 1.0, 1.0);
uniform float strength = 0.0;    // 0..1, the outline's opacity
uniform float width = 0.28;      // how much of the rim it covers (0..1)
uniform float dashes = 12.0;     // per metre along the body
uniform float gap = 0.42;        // share of each dash left blank
uniform float march = 0.6;       // dashes per second
uniform float inflate = 0.015;   // m out along the normal
uniform float wobble = 0.006;    // m of pencil wobble

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	float shake = sin(VERTEX.z * 31.0 + TIME * 9.0) * sin(VERTEX.y * 23.0 - TIME * 6.0);
	vec3 v = VERTEX + NORMAL * (inflate + wobble * shake);
	vec3 n = NORMAL;
	fish_bend(v, n);
	VERTEX = v;
	NORMAL = n;
}

void fragment() {
	float edge = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float line = smoothstep(1.0 - width, 1.0 - width * 0.55, edge);
	// Along the body, and round its nose and tail: dashes run whichever way the rim does.
	float along = (rest.z + abs(rest.y) + abs(rest.x)) * dashes - TIME * march;
	if (line < 0.05 || fract(along) < gap) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(color.a * line * strength, 0.0, 1.0);
}
