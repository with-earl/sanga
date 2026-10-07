class_name DialogueBox
extends Control
## Bottom-of-screen dialogue box that plays one or more lines.
##
## Each line shows in full at once. A tap moves to the next line, and a tap after the last line
## closes the box. Characters can stand beside the box, one on each side, with whoever is speaking
## shown at full brightness and the other slightly dimmed.

signal opened
signal dismissed
## Emitted when the last line has been tapped through, whether or not the box then closes.
signal lines_finished
signal choice_made(index: int)

## Portraits are drawn at this fraction of their picture size, and only the top part is shown.
const PORTRAIT_SCALE := 1.1625
const PORTRAIT_KEEP := 0.6
## The pictures are not all drawn at the same size: measured from the top of the hair to the chin,
## Father Eli's head is 118 px tall in his picture but Mercy's is 142 px. These factors scale each
## picture so heads come out the same size as Father Eli's, so everyone looks equally close to the
## camera. A picture that is not listed is drawn at the plain scale (1.0). Ben is left alone on
## purpose: he is a child, and his picture is already smaller.
const PORTRAIT_SIZE_FACTORS := {
	"father_eli": 1.0,
	"mercy_1": 0.83,
	"gloria_1": 0.93,
	"gloria_2": 0.93,
	"batista_1": 0.96,
	"batista_2": 0.96,
	"gwen_1": 0.89,
	"gwen_2": 0.89,
	"kulas_1": 0.96,
	"peter_1": 1.0,
}
## Space between a portrait and the side of the screen. Wider than the dialogue box's own margin,
## so the characters stand a little in from the edges.
const PORTRAIT_MARGIN := 64.0
## The box spans the whole screen. Its text starts at the top left, this far in from the edge.
const TEXT_PADDING := 28.0
## The box: black at 40% opacity with a gray and silver gradient border.
const BOX_FILL := Color(0.0, 0.0, 0.0, 0.4)
const BORDER_GRAY := Color(0.52, 0.52, 0.52, 1.0)
const BORDER_SILVER := Color(0.92, 0.92, 0.92, 1.0)
## How many times the gray to silver gradient repeats around the border: 2 reads as
## gray, silver, gray, silver and then back to gray where it started.
const BORDER_REPEATS := 2
const BORDER_WIDTH := 5
const TEXT_PADDING_VERTICAL := 18.0
const RETRO_TEXT_SHADER := preload("res://shaders/retro_text.gdshader")
const LISTENER_BRIGHTNESS := 0.55
const PORTRAIT_FADE_SECONDS := 0.15
## Choices: stacked above the box, in the box's own colours.
const CHOICE_WIDTH := 720.0
const CHOICE_GAP := 12.0
const CHOICE_FILL := Color(0.0, 0.0, 0.0, 0.72)
const CHOICE_FILL_PRESSED := Color(0.24, 0.24, 0.24, 0.85)
const CHOICE_BORDER := Color(0.87, 0.87, 0.87, 1.0)
const CHOICE_TEXT := Color(0.851, 0.643, 0.255, 1.0)
const CHOICE_OUTLINE := Color(0.29, 0.165, 0.071, 1.0)
const CHOICE_FADE_SECONDS := 0.2
## The Continue button is at least this tall, for an easy tap.

@onready var _speaker: Label = %SpeakerLabel
@onready var _text: Label = %TextLabel
@onready var _panel: PanelContainer = %Panel
@onready var _portrait_left: TextureRect = %PortraitLeft
@onready var _portrait_right: TextureRect = %PortraitRight

var _pending_lines: Array = []
var _left_name := ""
var _right_name := ""
var _portrait_tween: Tween
## Looks up the picture for a character by name. The box uses it to bring in whoever speaks next
## on the right, when a conversation has more than one person speaking there.
var portrait_source := Callable()
var _box_style := StyleBoxTexture.new()
var _box_size := Vector2i.ZERO
## When true, tapping past the last line leaves the box open, for more lines or a choice to follow.
var _keep_open := false
var _choosing := false
var _choices := VBoxContainer.new()


func _ready() -> void:
	hide()
	# The box background is drawn from a picture made at the box's exact size (see _build_box),
	# so the soft retro look affects it by about a pixel. It keeps its exact opacity.
	_box_style.content_margin_top = TEXT_PADDING_VERTICAL
	_box_style.content_margin_bottom = TEXT_PADDING_VERTICAL
	_box_style.content_margin_left = TEXT_PADDING
	_box_style.content_margin_right = TEXT_PADDING
	_panel.add_theme_stylebox_override("panel", _box_style)
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var retro := ShaderMaterial.new()
	retro.shader = RETRO_TEXT_SHADER
	retro.set_shader_parameter("alpha_boost", 1.0)
	_panel.material = retro
	_panel.gui_input.connect(_on_panel_gui_input)
	_choices.add_theme_constant_override("separation", int(CHOICE_GAP))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.visible = false
	add_child(_choices)


## Sets who stands beside the box before it opens: a name and a picture for each side. Pass an
## empty name or no picture to leave a side empty.
func set_cast(left_name: String, left_picture: Texture2D, right_name: String, right_picture: Texture2D) -> void:
	_left_name = left_name
	_right_name = right_name
	_build_box()
	_place_portrait(_portrait_left, left_picture, true)
	_place_portrait(_portrait_right, right_picture, false)


## Draws the box background at its exact size: black at 40% with a gray and silver gradient
## border that runs around the box and repeats twice. Made only when the size changes.
func _build_box() -> void:
	var wanted := Vector2i(roundi(size.x + _panel.offset_right - _panel.offset_left), roundi(_panel.offset_bottom - _panel.offset_top))
	if wanted == _box_size or wanted.x <= 0 or wanted.y <= 0:
		return
	_box_size = wanted
	_box_style.texture = box_texture(wanted)


## The box background at an exact size: black at 40% with a gray and silver gradient border
## that runs around the box and repeats twice. Other panels use it to look like the dialogue box.
static func box_texture(box_size: Vector2i) -> ImageTexture:
	var width := box_size.x
	var height := box_size.y
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(BOX_FILL)
	var perimeter := float(2 * (width + height))
	for y in height:
		var on_edge_row := y < BORDER_WIDTH or y >= height - BORDER_WIDTH
		for x in width:
			if not on_edge_row and x >= BORDER_WIDTH and x < width - BORDER_WIDTH:
				continue
			# How far round the box this pixel is, clockwise from the top left corner.
			var along: float
			if y < BORDER_WIDTH:
				along = x
			elif y >= height - BORDER_WIDTH:
				along = width + height + (width - 1 - x)
			elif x >= width - BORDER_WIDTH:
				along = width + y
			else:
				along = 2 * width + height + (height - 1 - y)
			var wave := 0.5 - 0.5 * cos(TAU * BORDER_REPEATS * along / perimeter)
			image.set_pixel(x, y, BORDER_GRAY.lerp(BORDER_SILVER, wave))
	return ImageTexture.create_from_image(image)


## Plays a single line.
func say(speaker: String, text: String) -> void:
	say_lines(speaker, [text])


## Plays several lines in a row, one per tap. A line is a string spoken by `speaker`, or a
## dictionary {"speaker": ..., "text": ...} for a line spoken by someone else. With `keep_open`,
## the box stays open after the last line, so more lines or a choice can follow; await
## `lines_finished` to know when the player has read them.
func say_lines(speaker: String, lines: Array, keep_open := false) -> void:
	if lines.is_empty():
		return
	_keep_open = keep_open
	_pending_lines = lines.duplicate()
	var was_open := visible
	_show_next_line(speaker)
	show()
	if not was_open:
		_fade_portraits_in()
		opened.emit()


## True while there is at least one more line after the one on screen.
func has_more_lines() -> bool:
	return not _pending_lines.is_empty()


func close() -> void:
	if visible:
		_pending_lines.clear()
		_keep_open = false
		_clear_choices()
		hide()
		dismissed.emit()


## Shows the options above the box and waits for one to be tapped. Returns its index.
func choose(options: Array) -> int:
	_clear_choices()
	_choosing = true
	for index in options.size():
		_choices.add_child(_make_choice_button(str(options[index]), index))
	_choices.size = Vector2(CHOICE_WIDTH, 0.0)
	_choices.reset_size()
	var box_top := size.y + _panel.offset_top
	_choices.position = Vector2((size.x - CHOICE_WIDTH) / 2.0, box_top - _choices.get_combined_minimum_size().y - 28.0)
	_choices.modulate.a = 0.0
	_choices.visible = true
	# Choices can be offered with no line on screen: then only the choices show.
	if not visible:
		_panel.visible = false
		_portrait_left.visible = false
		_portrait_right.visible = false
		show()
	create_tween().tween_property(_choices, "modulate:a", 1.0, CHOICE_FADE_SECONDS)
	var picked: int = await choice_made
	_clear_choices()
	if not _panel.visible:
		_panel.visible = true
		hide()
	return picked


func _make_choice_button(text: String, index: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(CHOICE_WIDTH, 56.0)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, choice_style(CHOICE_FILL))
	button.add_theme_stylebox_override("pressed", choice_style(CHOICE_FILL_PRESSED))
	button.add_theme_stylebox_override("hover_pressed", choice_style(CHOICE_FILL_PRESSED))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, UiSkin.BUTTON_TEXT)
	button.add_theme_color_override("font_outline_color", UiSkin.BUTTON_OUTLINE)
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_font_size_override("font_size", _text.get_theme_font_size("font_size"))
	button.pressed.connect(func() -> void:
		if _choosing:
			_choosing = false
			Settings.vibrate(Settings.HAPTIC_LIGHT)
			choice_made.emit(index))
	return button


## The look of a choice button, also used by buttons on panels styled like the dialogue box.
## It is drawn from a picture, so the retro text shader softens it like the text.
static func choice_style(fill: Color) -> StyleBoxTexture:
	var style := SoftShapes.box_style(fill, CHOICE_BORDER, 3)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _clear_choices() -> void:
	_choosing = false
	_choices.visible = false
	for child in _choices.get_children():
		child.queue_free()


func _show_next_line(default_speaker: String) -> void:
	var line: Variant = _pending_lines.pop_front()
	var who := default_speaker
	var text := ""
	# A voice from out of sight, such as someone in the next room: nobody on screen speaks.
	var offscreen := false
	if line is Dictionary:
		who = str(line.get("speaker", default_speaker))
		text = str(line.get("text", ""))
		offscreen = bool(line.get("offscreen", false))
	else:
		text = str(line)
	_speaker.text = who
	_text.text = text
	if offscreen:
		_highlight("")
		return
	_bring_in_speaker(who)
	_highlight(who)


## If someone other than the left character and the current right character speaks, they replace
## the right character, for example Ben answering after Gwen.
func _bring_in_speaker(who: String) -> void:
	if who == "" or who == _left_name or who == _right_name or not portrait_source.is_valid():
		return
	var picture := portrait_source.call(who) as Texture2D
	if picture == null:
		return
	_right_name = who
	_place_portrait(_portrait_right, picture, false)


## The speaker is shown at full brightness, the other side slightly dimmed.
func _highlight(who: String) -> void:
	_portrait_left.modulate.v = 1.0 if who == _left_name else LISTENER_BRIGHTNESS
	_portrait_right.modulate.v = 1.0 if who == _right_name else LISTENER_BRIGHTNESS


## Shows the top part of a portrait standing on the bottom edge of the screen, at the left or right
## corner and underneath the box. Returns how wide it is drawn, or 0 if there is no picture.
func _place_portrait(portrait: TextureRect, picture: Texture2D, on_left: bool) -> float:
	portrait.visible = picture != null
	if picture == null:
		return 0.0
	var full := picture.get_size()
	var shown := AtlasTexture.new()
	shown.atlas = picture
	shown.region = Rect2(0.0, 0.0, full.x, full.y * PORTRAIT_KEEP)
	portrait.texture = shown
	# The same smooth, soft look as the characters in the scene.
	portrait.material = ArtSlot.character_material()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var factor: float = PORTRAIT_SIZE_FACTORS.get(picture.resource_path.get_file().get_basename(), 1.0)
	var drawn := shown.region.size * PORTRAIT_SCALE * factor
	var x := PORTRAIT_MARGIN if on_left else size.x - PORTRAIT_MARGIN - drawn.x
	portrait.position = Vector2(x, size.y - drawn.y)
	portrait.size = drawn
	return drawn.x


func _fade_portraits_in() -> void:
	if _portrait_tween != null and _portrait_tween.is_valid():
		_portrait_tween.kill()
	_portrait_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for portrait in [_portrait_left, _portrait_right]:
		portrait.modulate.a = 0.0
		_portrait_tween.tween_property(portrait, "modulate:a", 1.0, PORTRAIT_FADE_SECONDS)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


## Moves to the next line, the same as tapping the box.
func advance() -> void:
	if _choosing:
		return
	if has_more_lines():
		_show_next_line(_speaker.text)
	elif _keep_open:
		_keep_open = false
		lines_finished.emit()
	else:
		lines_finished.emit()
		close()
