class_name UiSkin
extends RefCounted
## The game's one button and text look, taken from the dialogue box: black boxes with a light gray
## border, and white text with a black outline. Every box is drawn from a picture, so the retro
## text shader softens it like the text.

const TEXT_SIZE := 19
const HEADING_SIZE := 22
const OUTLINE_SIZE := 6
const BUTTON_HEIGHT := 48.0
## Pressed text and icons dim a little, so a tap is felt.
const PRESSED_TEXT := Color(0.78, 0.78, 0.78, 1)


## Gives a button the dialogue-choice look: a black box with a gray border and white text.
static func style_button(button: Button, font_size := TEXT_SIZE) -> void:
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, BUTTON_HEIGHT)
	box_only(button)
	button.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, DialogueBox.CHOICE_TEXT)
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, PRESSED_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	button.add_theme_color_override("font_outline_color", DialogueBox.CHOICE_OUTLINE)
	button.add_theme_constant_override("outline_size", OUTLINE_SIZE)


## Only the box, for buttons that draw their own content, such as an icon.
static func box_only(button: Button) -> void:
	var normal := DialogueBox.choice_style(DialogueBox.CHOICE_FILL)
	var pressed := DialogueBox.choice_style(DialogueBox.CHOICE_FILL_PRESSED)
	for state in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, pressed)


## Gives a label the dialogue text look: white with a black outline.
static func style_label(label: Label, font_size := TEXT_SIZE) -> void:
	label.add_theme_color_override("font_color", DialogueBox.CHOICE_TEXT)
	label.add_theme_color_override("font_outline_color", DialogueBox.CHOICE_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_font_size_override("font_size", font_size)


## A plain icon in the same white with a black outline.
static func style_icon(icon: IconButton) -> void:
	icon.plain = true
	icon.plain_fill = DialogueBox.CHOICE_TEXT
	icon.plain_outline = DialogueBox.CHOICE_OUTLINE


## True for a button that still has the theme's default look, so it should get this one. Text
## buttons (the main screen's "TextButton" style) keep their own text-only look.
static func wants_default_look(button: Button) -> bool:
	if button is IconButton or button is BackLink or button is ToggleSwitch:
		return false
	if button.theme_type_variation != &"":
		return false
	return not button.has_theme_stylebox_override("normal")
