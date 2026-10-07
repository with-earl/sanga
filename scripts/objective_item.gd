class_name ObjectiveItem
extends Label
## One line in the objectives list. When finished it gets a line struck through its text, which
## can be drawn in from left to right.

const LINE_COLOR := Color(0.851, 0.643, 0.255, 1.0)
const LINE_OUTLINE := Color(0.29, 0.165, 0.071, 1.0)
const LINE_WIDTH := 2.0
const LINE_OUTLINE_WIDTH := 4.0

## 0 shows no line and 1 shows the whole line.
var strike_amount := 0.0:
	set(value):
		strike_amount = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	if strike_amount <= 0.0:
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	# Where the text starts depends on how it is aligned.
	var start_x := 0.0
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT:
			start_x = size.x - text_width
		HORIZONTAL_ALIGNMENT_CENTER:
			start_x = (size.x - text_width) / 2.0
	var y := size.y * 0.54
	var end_x := start_x + text_width * strike_amount
	draw_line(Vector2(start_x - 2.0, y), Vector2(end_x + 2.0, y), LINE_OUTLINE, LINE_OUTLINE_WIDTH, true)
	draw_line(Vector2(start_x - 1.0, y), Vector2(end_x + 1.0, y), LINE_COLOR, LINE_WIDTH, true)
