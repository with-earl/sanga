class_name IconButton
extends Button
## A button with a simple drawn icon, so no image files are needed. The icon is drawn into a
## small picture rather than as vector lines, so the retro text shader softens it like the text.
##
## With `plain` on, there is no button box at all: just the icon, drawn in the text style (cream
## with a dark outline) and getting the same soft look as the text. Taps still use the whole
## button area, so it stays easy to hit.

enum Icon { MENU, CLOSE, MINUS, PLUS }

const INK := Color(0.29, 0.184, 0.153, 1.0)
const STROKE := 4.0
## The text style, used by a plain icon.
const PLAIN_FILL := Color(0.965, 0.906, 0.796, 1.0)
const PLAIN_OUTLINE := Color(0.2, 0.12, 0.1, 1.0)
const PLAIN_STROKE := 5.0
const PLAIN_OUTLINE_WIDTH := 2.5

@export var icon_kind := Icon.MENU:
	set(value):
		icon_kind = value
		queue_redraw()
@export var plain := false:
	set(value):
		plain = value
		queue_redraw()
## Draws the icon larger or smaller than usual, strokes included, without changing the tap area.
@export var icon_scale := 1.0:
	set(value):
		icon_scale = value
		queue_redraw()
## The colours of a plain icon. The defaults match the cream HUD text.
@export var plain_fill := PLAIN_FILL:
	set(value):
		plain_fill = value
		queue_redraw()
@export var plain_outline := PLAIN_OUTLINE:
	set(value):
		plain_outline = value
		queue_redraw()

## A picture to show instead of a drawn icon, for example the gear on the menu button. It is
## drawn this many pixels across, centred, and keeps its shape.
@export var picture: Texture2D:
	set(value):
		picture = value
		queue_redraw()
@export var picture_size := 30.0:
	set(value):
		picture_size = value
		queue_redraw()

var _picture: ImageTexture
var _picture_key := ""


func _draw() -> void:
	if picture != null:
		var drawn := picture.get_size() * (picture_size / maxf(picture.get_width(), picture.get_height()))
		draw_texture_rect(picture, Rect2((size - drawn) / 2.0, drawn), false)
		return
	var center := size / 2.0
	var scale_up := (1.3 if plain else 1.0) * icon_scale
	var segments: Array[PackedVector2Array] = []
	match icon_kind:
		Icon.MENU:
			for offset_y in [-9.0, 0.0, 9.0]:
				segments.append(PackedVector2Array([center + Vector2(-13.0, offset_y) * scale_up, center + Vector2(13.0, offset_y) * scale_up]))
		Icon.CLOSE:
			segments.append(PackedVector2Array([center + Vector2(-9.0, -9.0) * scale_up, center + Vector2(9.0, 9.0) * scale_up]))
			segments.append(PackedVector2Array([center + Vector2(9.0, -9.0) * scale_up, center + Vector2(-9.0, 9.0) * scale_up]))
		Icon.MINUS:
			segments.append(PackedVector2Array([center + Vector2(-9.0, 0.0) * scale_up, center + Vector2(9.0, 0.0) * scale_up]))
		Icon.PLUS:
			segments.append(PackedVector2Array([center + Vector2(-9.0, 0.0) * scale_up, center + Vector2(9.0, 0.0) * scale_up]))
			segments.append(PackedVector2Array([center + Vector2(0.0, -9.0) * scale_up, center + Vector2(0.0, 9.0) * scale_up]))
	# A plain icon gets a dark outline underneath, like the text. The outline never gets thinner
	# than the HUD text's outline.
	var stroke := (PLAIN_STROKE if plain else STROKE) * icon_scale
	var outline := maxf(PLAIN_OUTLINE_WIDTH * icon_scale, 2.0) if plain else 0.0
	var fill := plain_fill if plain else INK
	var picture_size := Vector2i(size.ceil())
	var key := "%s|%s|%s|%s|%s|%s|%s" % [picture_size, icon_kind, plain, icon_scale, fill, plain_outline, outline]
	if key != _picture_key:
		_picture_key = key
		_picture = SoftShapes.strokes(picture_size, segments, fill, stroke, plain_outline, outline)
	draw_texture(_picture, Vector2.ZERO)
