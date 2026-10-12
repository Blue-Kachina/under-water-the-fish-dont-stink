class_name XRayOutline
## Outlines of targets (the ball, the next hoop) shown through whatever hides
## them. Each is a material's next pass, drawing only the hidden parts.

const SHADER := preload("res://shaders/xray_outline.gdshader")


## A next-pass material that outlines its mesh in `color` where it's hidden.
static func material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("color", color)
	return material
