@tool
class_name OutlineGroup
extends CanvasGroup
## Draws a black outline around the sides and top of everything inside it as one shape.
##
## Put one character in it for a single outline, or several (for example Gwen and Ben) to get one
## outline around all of them together. Children keep their own position and look.

const SHADER := preload("res://shaders/outline.gdshader")

## Outline thickness in screen pixels.
@export_range(0.0, 12.0, 0.1) var outline_width := 1.4:
	set(value):
		outline_width = value
		_apply()
## 1 shows the outline and 0 hides it, for example while a dialogue is open.
@export_range(0.0, 1.0, 0.01) var outline_opacity := 1.0:
	set(value):
		outline_opacity = value
		_apply()

var _material: ShaderMaterial


func _ready() -> void:
	_apply()


func _apply() -> void:
	# The group's picture is padded, so the outline has room to draw outside the characters.
	var margin := ceilf(outline_width) + 3.0
	fit_margin = margin
	clear_margin = margin
	# Each group has its own material, so each outline can fade on its own.
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		material = _material
	_material.set_shader_parameter("outline_width", outline_width)
	_material.set_shader_parameter("outline_opacity", outline_opacity)
