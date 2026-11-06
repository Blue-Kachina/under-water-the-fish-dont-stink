shader_type spatial;
// The Marco! scan's ghosts through walls: the depth test off, drawn at
// `strength` (MarcoPoloSettings.ghost_through_walls).
render_mode blend_add, unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/marco_ghost.gdshaderinc"
