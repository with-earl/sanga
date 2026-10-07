class_name DialogueBox
extends Control
## Bottom-of-screen dialogue box that plays one or more lines, in a soft 90s anime window with the
## speaker's name on a little plate on its top edge.
##
## Each line types itself out. A tap while it types shows the rest at once; once it is all there a
## small ▼ bobs in the corner, and a tap moves to the next line. A tap after the last line closes
## the box. Characters can stand beside the box, one on each side, with whoever is speaking shown
## at full brightness and the other slightly dimmed.

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
## Which way each portrait looks in its picture. Portraits not listed here look to the left. A
## portrait is mirrored when needed so that people on the left of the box always face right and
## people on the right always face left: everyone in a conversation faces each other.
## A whole character is named ("gloria"), or one picture of them ("batista_2") when that picture
## looks the other way from their usual one.
const PORTRAITS_FACING_RIGHT := ["father_eli", "ben", "gloria", "gwen", "peter", "batista_2"]
## Single pictures that look to the left although their character's usual picture looks right.
const PORTRAITS_FACING_LEFT := ["gloria_2", "gwen_2"]
## How far a portrait stands in from the side of the box, so the characters are a little in from
## its edges.
const PORTRAIT_INSET := 40.0
## The box spans the screen with this margin on the sides and bottom, but never grows wider than
## the 1280 x 720 stage, so lines stay easy to read on very wide phones.
const BOX_MARGIN := 24.0
const BOX_HEIGHT := 196.0
const MAX_BOX_WIDTH := 1232.0
## The text starts at the top left of the box, this far in from its edge. The top leaves room for
## the name plate that sits across the box's top edge.
const TEXT_PADDING := 32.0
const TEXT_PADDING_TOP := 34.0
const TEXT_PADDING_BOTTOM := 18.0
## The name plate starts this far in from the box's left edge, and about half of it rises above
## the box.
const PLATE_INSET := 22.0
const PLATE_RISE := 0.55
const PLATE_PADDING := Vector2(18.0, 4.0)
## How fast a line types itself out, in letters per second. Unhurried, like a 90s visual novel.
const LETTERS_PER_SECOND := 42.0
## The ▼ in the bottom right corner when a line is all there, bobbing gently.
const NEXT_CURSOR_SIZE := Vector2i(18, 14)
const NEXT_CURSOR_MARGIN := Vector2(26.0, 20.0)
const NEXT_CURSOR_BOB := 4.0
const NEXT_CURSOR_BOB_SECONDS := 0.5
const RETRO_TEXT_SHADER := preload("res://shaders/retro_text.gdshader")
const LISTENER_BRIGHTNESS := 0.55
const PORTRAIT_FADE_SECONDS := 0.15
## When two people stand together on the right (such as Ben and Gwen), the first stands in front
## and nearer the middle, overlapping the one behind by this much of their own width.
const COMPANION_OVERLAP := 0.4
## Choices: soft windows stacked above the box, fading in one after another.
const CHOICE_WIDTH := 720.0
const CHOICE_GAP := 14.0
const CHOICE_FADE_SECONDS := 0.22
const CHOICE_STAGGER_SECONDS := 0.07
## The gameplay text colours: golden ochre with a brown outline.
const CHOICE_TEXT := Color(0.851, 0.643, 0.255, 1.0)
const CHOICE_OUTLINE := Color(0.29, 0.165, 0.071, 1.0)

@onready var _speaker: Label = %SpeakerLabel
@onready var _text: Label = %TextLabel
@onready var _panel: PanelContainer = %Panel
@onready var _portrait_left: TextureRect = %PortraitLeft
@onready var _portrait_right: TextureRect = %PortraitRight

var _pending_lines: Array = []
var _left_name := ""
var _right_name := ""
## A second person standing on the right, behind the first, for a conversation with two people.
var _portrait_companion := TextureRect.new()
var _companion_name := ""
var _portrait_tween: Tween
## Looks up the picture for a character by name. The box uses it to bring in whoever speaks next
## on the right, when a conversation has more than one person speaking there.
var portrait_source := Callable()
var _plate := PanelContainer.new()
var _next_cursor := TextureRect.new()
var _next_tween: Tween
var _typing_tween: Tween
## When true, tapping past the last line leaves the box open, for more lines or a choice to follow.
var _keep_open := false
var _choosing := false
var _choices := VBoxContainer.new()
## Extra room kept free at each edge for a phone's notch or rounded corners (left, top, right,
## bottom), set by the location.
var _insets := Vector4.ZERO


func _ready() -> void:
	hide()
	_portrait_companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_companion.visible = false
	add_child(_portrait_companion)
	# Behind the first person on the right.
	move_child(_portrait_companion, _portrait_right.get_index())
	_fit_panel()
	resized.connect(_fit_panel)
	var box_style := StyleBoxEmpty.new()
	box_style.content_margin_top = TEXT_PADDING_TOP
	box_style.content_margin_bottom = TEXT_PADDING_BOTTOM
	box_style.content_margin_left = TEXT_PADDING
	box_style.content_margin_right = TEXT_PADDING
	_panel.add_theme_stylebox_override("panel", box_style)
	SoftWindow.behind(_panel)
	_panel.gui_input.connect(_on_panel_gui_input)
	_build_plate()
	_build_next_cursor()
	_choices.add_theme_constant_override("separation", int(CHOICE_GAP))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.visible = false
	add_child(_choices)


## Keeps the box clear of a phone's notch and rounded corners. See ScreenFit.safe_insets.
func keep_clear(insets: Vector4) -> void:
	_insets = insets
	_fit_panel()


## Places the box along the bottom of the screen, within the stage's width and clear of the notch.
func _fit_panel() -> void:
	var side := maxf(BOX_MARGIN + maxf(_insets.x, _insets.z), (size.x - MAX_BOX_WIDTH) / 2.0)
	_panel.offset_left = side
	_panel.offset_right = -side
	_panel.offset_bottom = -(BOX_MARGIN + _insets.w)
	_panel.offset_top = _panel.offset_bottom - BOX_HEIGHT
	_place_plate()


## The name plate: the speaker's name on a small warm-brown window across the box's top edge.
func _build_plate() -> void:
	var plate_style := StyleBoxEmpty.new()
	plate_style.content_margin_left = PLATE_PADDING.x
	plate_style.content_margin_right = PLATE_PADDING.x
	plate_style.content_margin_top = PLATE_PADDING.y
	plate_style.content_margin_bottom = PLATE_PADDING.y
	_plate.add_theme_stylebox_override("panel", plate_style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SoftWindow.behind(_plate, SoftWindow.Look.PLATE)
	_speaker.reparent(_plate, false)
	# A child of the box itself rather than of the panel, which would lay it out like its text.
	add_child(_plate)
	_plate.resized.connect(_place_plate)
	_panel.item_rect_changed.connect(_place_plate)


func _place_plate() -> void:
	_plate.reset_size()
	_plate.position = _panel.position + Vector2(PLATE_INSET, -_plate.size.y * PLATE_RISE)
	if _next_cursor.visible:
		_show_next_cursor(true)


## Where the ▼ rests, in the bottom right corner of the panel.
func _next_cursor_rest() -> Vector2:
	return _panel.position + _panel.size - NEXT_CURSOR_MARGIN - Vector2(NEXT_CURSOR_SIZE)


## The ▼ that bobs in the box's bottom right corner once a line is all there.
func _build_next_cursor() -> void:
	var w := float(NEXT_CURSOR_SIZE.x)
	var h := float(NEXT_CURSOR_SIZE.y)
	_next_cursor.texture = SoftShapes.triangle(NEXT_CURSOR_SIZE, PackedVector2Array([Vector2(2, 2), Vector2(w - 2, 2), Vector2(w / 2.0, h - 2)]), CHOICE_TEXT, CHOICE_OUTLINE, 1.5)
	_next_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_next_cursor.visible = false
	add_child(_next_cursor)
	_next_cursor.size = Vector2(NEXT_CURSOR_SIZE)


func _show_next_cursor(on: bool) -> void:
	if _next_tween != null and _next_tween.is_valid():
		_next_tween.kill()
	_next_cursor.visible = on
	if not on:
		return
	var rest := _next_cursor_rest()
	_next_cursor.position = rest
	_next_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_next_tween.tween_property(_next_cursor, "position:y", rest.y + NEXT_CURSOR_BOB, NEXT_CURSOR_BOB_SECONDS)
	_next_tween.tween_property(_next_cursor, "position:y", rest.y, NEXT_CURSOR_BOB_SECONDS)


## Sets who stands beside the box before it opens: a name and a picture for each side. Pass an
## empty name or no picture to leave a side empty. A companion stands on the right too, behind the
## right character, for a conversation with two people there, such as Ben and Gwen.
func set_cast(left_name: String, left_picture: Texture2D, right_name: String, right_picture: Texture2D, companion_name := "", companion_picture: Texture2D = null) -> void:
	_left_name = left_name
	_right_name = right_name
	_companion_name = companion_name if companion_picture != null else ""
	_place_portrait(_portrait_left, left_picture, true, left_name)
	var front_width := _place_portrait(_portrait_right, right_picture, false, right_name)
	_place_portrait(_portrait_companion, companion_picture, false, companion_name)
	if companion_picture != null and front_width > 0.0:
		# The companion keeps the corner; the right character steps in front of them.
		_portrait_right.position.x = _portrait_companion.position.x - front_width * (1.0 - COMPANION_OVERLAP)


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
		_stop_typing()
		hide()
		dismissed.emit()


## Shows the options above the box and waits for one to be tapped. Returns its index.
func choose(options: Array) -> int:
	_clear_choices()
	_choosing = true
	_finish_typing()
	_show_next_cursor(false)
	for index in options.size():
		_choices.add_child(_make_choice_button(str(options[index]), index))
	_choices.size = Vector2(CHOICE_WIDTH, 0.0)
	_choices.reset_size()
	var box_top := size.y + _panel.offset_top
	_choices.position = Vector2((size.x - CHOICE_WIDTH) / 2.0, box_top - _choices.get_combined_minimum_size().y - 40.0)
	_choices.modulate.a = 0.0
	_choices.visible = true
	# Choices can be offered with no line on screen: then only the choices show.
	if not visible:
		_panel.visible = false
		_plate.visible = false
		_portrait_left.visible = false
		_portrait_right.visible = false
		_portrait_companion.visible = false
		show()
	create_tween().tween_property(_choices, "modulate:a", 1.0, CHOICE_FADE_SECONDS)
	# Each choice fades in a moment after the one above it.
	var buttons := _choices.get_children()
	for index in buttons.size():
		var button := buttons[index] as Button
		button.modulate.a = 0.0
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) \
			.tween_property(button, "modulate:a", 1.0, CHOICE_FADE_SECONDS).set_delay(index * CHOICE_STAGGER_SECONDS)
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
	button.custom_minimum_size = Vector2(CHOICE_WIDTH, UiSkin.BUTTON_HEIGHT)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiSkin.style_button(button, _text.get_theme_font_size("font_size"))
	button.pressed.connect(func() -> void:
		if _choosing:
			_choosing = false
			Settings.vibrate(Settings.HAPTIC_LIGHT)
			choice_made.emit(index))
	return button


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
	_plate.visible = who != ""
	_type_out(text)
	if offscreen:
		_highlight("")
		return
	_bring_in_speaker(who)
	_highlight(who)


## If someone other than the left character and the current right character speaks, they replace
## the right character, for example Ben answering after Gwen.
func _bring_in_speaker(who: String) -> void:
	if who == "" or who == _left_name or who == _right_name or who == _companion_name or not portrait_source.is_valid():
		return
	var picture := portrait_source.call(who) as Texture2D
	if picture == null:
		return
	_right_name = who
	_place_portrait(_portrait_right, picture, false, who)


## The speaker is shown at full brightness, everyone else slightly dimmed.
func _highlight(who: String) -> void:
	_portrait_left.modulate.v = 1.0 if who == _left_name else LISTENER_BRIGHTNESS
	_portrait_right.modulate.v = 1.0 if who == _right_name else LISTENER_BRIGHTNESS
	_portrait_companion.modulate.v = 1.0 if who == _companion_name else LISTENER_BRIGHTNESS


## Shows the top part of a portrait standing on the bottom edge of the screen, at the left or right
## corner and underneath the box. Returns how wide it is drawn, or 0 if there is no picture.
func _place_portrait(portrait: TextureRect, picture: Texture2D, on_left: bool, _who := "") -> float:
	portrait.visible = picture != null
	if picture == null:
		return 0.0
	portrait.flip_h = faces_right(picture) != on_left
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
	var x := _panel.offset_left + PORTRAIT_INSET if on_left else size.x + _panel.offset_right - PORTRAIT_INSET - drawn.x
	portrait.position = Vector2(x, size.y - drawn.y)
	portrait.size = drawn
	return drawn.x


## True when the person in this portrait looks to the right in the picture itself.
static func faces_right(picture: Texture2D) -> bool:
	var base := picture.resource_path.get_file().get_basename()
	if base in PORTRAITS_FACING_LEFT:
		return false
	if base in PORTRAITS_FACING_RIGHT:
		return true
	# Otherwise "gloria_1" looks the way Gloria usually does.
	var parts := base.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		base = parts[0]
	return base in PORTRAITS_FACING_RIGHT


func _fade_portraits_in() -> void:
	if _portrait_tween != null and _portrait_tween.is_valid():
		_portrait_tween.kill()
	_portrait_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for portrait in [_portrait_left, _portrait_right, _portrait_companion]:
		portrait.modulate.a = 0.0
		_portrait_tween.tween_property(portrait, "modulate:a", 1.0, PORTRAIT_FADE_SECONDS)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


## Types the line out letter by letter, then shows the ▼.
func _type_out(text: String) -> void:
	_stop_typing()
	_show_next_cursor(false)
	_text.text = text
	_text.visible_characters = 0
	var letters := _text.get_total_character_count()
	_typing_tween = create_tween()
	_typing_tween.tween_property(_text, "visible_characters", letters, letters / LETTERS_PER_SECOND)
	_typing_tween.tween_callback(_finish_typing)


func _is_typing() -> bool:
	return _typing_tween != null and _typing_tween.is_valid() and _typing_tween.is_running()


## Shows the whole line at once, for a tap while it is still typing.
func _finish_typing() -> void:
	_stop_typing()
	_text.visible_characters = -1
	_show_next_cursor(not _choosing)


func _stop_typing() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	_typing_tween = null


## Moves to the next line, the same as tapping the box. A tap while a line is still typing shows
## the rest of it first.
func advance() -> void:
	if _choosing:
		return
	if _is_typing():
		_finish_typing()
		return
	if has_more_lines():
		_show_next_line(_speaker.text)
	elif _keep_open:
		_keep_open = false
		lines_finished.emit()
	else:
		lines_finished.emit()
		close()
