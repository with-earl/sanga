class_name UiSkin
extends RefCounted
## The game's one button and text look, taken from the dialogue box: black boxes with a light gray
## border, and golden ochre text with a brown outline. Every box is drawn from a picture, so the retro
## text shader softens it like the text.

## Sizes chosen to read comfortably on a phone held sideways, where the 720-unit-high screen is
## only about 7 cm tall.
const TEXT_SIZE := 24
const HEADING_SIZE := 28
const OUTLINE_SIZE := 6
## At least this tall, so every button is easy to tap with a thumb (about 9 mm on a phone).
const BUTTON_HEIGHT := 64.0
## Room between a button's edge and its text.
const BUTTON_PADDING := Vector2(40.0, 10.0)
## The ▶ cursor beside a pressed button.
const CURSOR_SIZE := Vector2i(14, 18)
const CURSOR_INSET := 16.0
const CURSOR_FADE_SECONDS := 0.1
## Every button, on every screen, uses these two colours: warm cream text with a near-black brown
## outline. That pairing has the strongest contrast against both the black button boxes and the busy
## picture and video behind the main screen. Change them here and all buttons follow.
const BUTTON_TEXT := Color(1.0, 0.953, 0.839, 1)
const BUTTON_OUTLINE := Color(0.165, 0.086, 0.031, 1)
## Pressed text and icons dim a little, so a tap is felt.
const PRESSED_TEXT := Color(0.74, 0.70, 0.62, 1)


## Gives a button the shared look: a soft 90s window with cream text and a dark outline.
static func style_button(button: Button, font_size := TEXT_SIZE) -> void:
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, BUTTON_HEIGHT)
	box_only(button)
	button.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, BUTTON_TEXT)
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, PRESSED_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(BUTTON_TEXT, 0.4))
	button.add_theme_color_override("font_outline_color", BUTTON_OUTLINE)
	button.add_theme_constant_override("outline_size", OUTLINE_SIZE)


## Only the window and the cursor, for buttons that draw their own content, such as an icon. Safe
## to call more than once on the same button.
static func box_only(button: Button) -> void:
	if button.has_meta(&"soft_window"):
		return
	button.set_meta(&"soft_window", true)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = BUTTON_PADDING.x
	empty.content_margin_right = BUTTON_PADDING.x
	empty.content_margin_top = BUTTON_PADDING.y
	empty.content_margin_bottom = BUTTON_PADDING.y
	for state in ["normal", "hover", "focus", "disabled", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, empty)
	SoftWindow.behind_button(button)
	_add_cursor(button)


## A small ▶ at the left of the button while it is held down (or the mouse is over it), the way
## 90s game menus pointed at the option about to be picked.
static func _add_cursor(button: Button) -> void:
	var cursor := TextureRect.new()
	var w := float(CURSOR_SIZE.x)
	var h := float(CURSOR_SIZE.y)
	cursor.texture = SoftShapes.triangle(CURSOR_SIZE, PackedVector2Array([Vector2(2, 2), Vector2(w - 2, h / 2.0), Vector2(2, h - 2)]), DialogueBox.CHOICE_TEXT, DialogueBox.CHOICE_OUTLINE, 1.5)
	cursor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.modulate.a = 0.0
	button.add_child(cursor, false, Node.INTERNAL_MODE_BACK)
	cursor.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	cursor.offset_left = CURSOR_INSET
	cursor.offset_right = CURSOR_INSET + w
	cursor.offset_top = -h / 2.0
	cursor.offset_bottom = h / 2.0
	var show_cursor := func(on: bool) -> void:
		cursor.create_tween().tween_property(cursor, "modulate:a", 1.0 if on else 0.0, CURSOR_FADE_SECONDS)
	button.button_down.connect(show_cursor.bind(true))
	button.button_up.connect(show_cursor.bind(false))
	button.mouse_entered.connect(show_cursor.bind(true))
	button.mouse_exited.connect(show_cursor.bind(false))


## Gives a label the dialogue text look: golden ochre with a brown outline.
static func style_label(label: Label, font_size := TEXT_SIZE) -> void:
	label.add_theme_color_override("font_color", DialogueBox.CHOICE_TEXT)
	label.add_theme_color_override("font_outline_color", DialogueBox.CHOICE_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_font_size_override("font_size", font_size)


## Every window closes by tapping outside it. This note at the bottom centre of the screen says so.
const CLOSE_HINT := "Tap outside to close"
const CLOSE_HINT_SIZE := 22
const CLOSE_HINT_BOTTOM := 28.0


## Adds the "Tap outside to close" note to a full-screen window, at the bottom centre.
static func add_close_hint(window: Control, color := Color(1.0, 0.953, 0.839, 0.85), outline := Color(0.165, 0.086, 0.031, 1)) -> Label:
	var hint := Label.new()
	hint.text = CLOSE_HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", CLOSE_HINT_SIZE)
	hint.add_theme_color_override("font_color", color)
	hint.add_theme_color_override("font_outline_color", outline)
	hint.add_theme_constant_override("outline_size", OUTLINE_SIZE if outline.a > 0.0 else 0)
	window.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	hint.position.y -= CLOSE_HINT_BOTTOM
	return hint


## A plain icon in the same cream with a dark outline as the button text.
static func style_icon(icon: IconButton) -> void:
	icon.plain = true
	icon.plain_fill = BUTTON_TEXT
	icon.plain_outline = BUTTON_OUTLINE


## True for a button that still has the theme's default look, so it should get this one. Text
## buttons (the main screen's "TextButton" style) keep their own text-only look.
static func wants_default_look(button: Button) -> bool:
	if button is IconButton or button is BackLink or button is ToggleSwitch:
		return false
	if button.theme_type_variation != &"":
		return false
	return not button.has_theme_stylebox_override("normal")
