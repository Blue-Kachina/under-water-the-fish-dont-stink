shader_type spatial;
// The Marco! scan's wake ripples (MarcoScan): one thin expanding ring per spot along a
// hider's path, camera-facing quads from a MultiMesh. The instance scale is the ring's
// radius; COLOR.r is its strength and COLOR.a what's left of its fade. Rings shed along
// a path pile up into a V-shaped wake and cross each other (additive: interference).
// Fog off so the murk doesn't swallow them; marco_ripple_walls.gdshader is the
// through-walls pass.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/marco_ripple.gdshaderinc"
