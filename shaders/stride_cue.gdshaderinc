// Extra Swishy's stride cue (FishModel.set_stride_cue), shared by every shader a
// tail is drawn with: the tail lights up from its root (along 0) toward its tip
// (along 1) as a stride builds, like a progress bar. It reaches the tip at the
// stride's peak, the moment to sweep back, and turns gold there. Per mesh
// (instance uniforms), so a fin material shared with other fins lights only
// the tail's.

instance uniform float stride_fill = 0.0;  // lit from the root up to here, 0..1
instance uniform float stride_glow = 0.0;  // brightness, 0 = off
instance uniform float stride_sweet = 0.0;  // 0 building (blue) to 1 at the peak (gold)

vec3 stride_cue(float along) {
	if (stride_glow <= 0.0) {
		return vec3(0.0);
	}
	float edge = 0.05;
	float lit = 1.0 - smoothstep(stride_fill - edge, stride_fill, along);
	// A brighter band at the leading edge, so the fill's progress reads at a glance.
	float front = lit * smoothstep(stride_fill - edge * 4.0, stride_fill - edge, along);
	vec3 color = mix(vec3(0.1, 0.65, 1.0), vec3(1.0, 0.82, 0.3), stride_sweet);
	return color * stride_glow * lit * (1.3 + 1.5 * front + 0.6 * stride_sweet);
}
