shader_type spatial;
// The Marco! scan's ghosts, depth-tested. Fog off so the murk doesn't swallow
// them; marco_ghost_walls.gdshader is the through-walls pass.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/marco_ghost.gdshaderinc"
