class_name TitleOrnament
extends Control
## The thin golden ornament under a title card's title: a fine ochre line that fades out at both
## ends, with a small diamond in the middle, like the title cards of a 90s anime episode.

const WIDTH := 320.0
const DIAMOND := 6.0
const LINE_COLOR := Color(0.851, 0.643, 0.255, 0.9)
const SEGMENTS := 24


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, DIAMOND * 2.0 + 2.0)


## An ornament centred horizontally in `parent`, its middle `y` below the parent's centre.
static func make(parent: Control, y: float) -> TitleOrnament:
	var ornament := TitleOrnament.new()
	parent.add_child(ornament)
	ornament.set_anchors_preset(Control.PRESET_CENTER)
	ornament.offset_left = -WIDTH / 2.0
	ornament.offset_right = WIDTH / 2.0
	ornament.offset_top = y - DIAMOND - 1.0
	ornament.offset_bottom = y + DIAMOND + 1.0
	return ornament


func _draw() -> void:
	var middle := size / 2.0
	# Each half of the line fades from full at the diamond to nothing at its end.
	for side in [-1.0, 1.0]:
		for index in SEGMENTS:
			var from := DIAMOND + 4.0 + (middle.x - DIAMOND - 4.0) * index / SEGMENTS
			var to := DIAMOND + 4.0 + (middle.x - DIAMOND - 4.0) * (index + 1) / SEGMENTS
			var fade := 1.0 - float(index) / SEGMENTS
			draw_line(middle + Vector2(from * side, 0), middle + Vector2(to * side, 0), Color(LINE_COLOR, LINE_COLOR.a * fade), 1.5, true)
	var diamond := PackedVector2Array([middle + Vector2(0, -DIAMOND), middle + Vector2(DIAMOND, 0),
		middle + Vector2(0, DIAMOND), middle + Vector2(-DIAMOND, 0)])
	draw_colored_polygon(diamond, LINE_COLOR)
