class_name BackLink
extends Button
## A "back" link: a left chevron and the name of the place it leads to, drawn exactly like the
## objectives text (golden ochre with a brown outline, same size), with no button shape around it.

const CHEVRON_WIDTH := 6.0
const CHEVRON_HEIGHT := 12.0
const CHEVRON_STROKE := 2.4
const GAP := 7.0
## Text and chevron dim slightly while pressed.
const PRESSED_DIM := 0.75

var _fill := Color.WHITE
var _outline := Color.BLACK
var _outline_size := 4


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fill = get_theme_color("font_color", &"HudBody")
	_outline = get_theme_color("font_outline_color", &"HudBody")
	_outline_size = get_theme_constant("outline_size", &"HudBody")
	# The HUD text has no font of its own: it uses the theme's default font.
	add_theme_font_override("font", get_theme_default_font())
	add_theme_font_size_override("font_size", get_theme_font_size("font_size", &"HudBody"))
	add_theme_constant_override("outline_size", _outline_size)
	add_theme_color_override("font_outline_color", _outline)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(color_name, _fill)
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(color_name, _dimmed(_fill))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = _outline_size / 2.0 + CHEVRON_WIDTH + GAP
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var left := _outline_size / 2.0
	var middle := size.y / 2.0
	var points := PackedVector2Array([
		Vector2(left + CHEVRON_WIDTH, middle - CHEVRON_HEIGHT / 2.0),
		Vector2(left, middle),
		Vector2(left + CHEVRON_WIDTH, middle + CHEVRON_HEIGHT / 2.0),
	])
	var fill := _dimmed(_fill) if is_pressed() else _fill
	draw_polyline(points, _outline, CHEVRON_STROKE + _outline_size, true)
	draw_polyline(points, fill, CHEVRON_STROKE, true)


func _dimmed(color: Color) -> Color:
	return Color(color.r * PRESSED_DIM, color.g * PRESSED_DIM, color.b * PRESSED_DIM, color.a)
