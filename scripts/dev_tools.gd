class_name DevTools
extends Control
## Development only: the "Developer tools" window, opened by the terminal icon next to the
## settings gear, on the main screen and in every place. It lists points of the game to jump to
## without playing from the start (see DevJump), and the screens a timeline ends on. Runs started
## here are never saved.
##
## It looks like a plain black and white computer terminal (monospaced letters on a black screen)
## instead of the game's warm storybook windows, so no one takes it for part of the story, while
## the words stay everyday words: a heading, a short note and a list of places to tap. Tapping
## outside the window closes it.

## While the game is still being made, the tools show in every build, the web playtest build
## included, so coaches and testers can reach any part. Set this to false before release, and
## they show only in debug builds again.
const SHOW_IN_ALL_BUILDS := true
const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const PANEL_WIDTH := 600.0
## The list grows with its rows, and scrolls once it would get taller than this.
const LIST_HEIGHT := 360.0
const PADDING := 28.0
const ROW_HEIGHT := 48.0
const ROW_GAP := 6.0
const FONT_SIZE := 20
const SMALL_SIZE := 16
## A terminal's monospaced letters (DejaVu Sans Mono, a free font; licence in assets/fonts).
const MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")
const MONO_BOLD := preload("res://assets/fonts/DejaVuSansMono-Bold.ttf")
const SCREEN := Color(0.02, 0.02, 0.02, 0.97)
const TITLE_BAR := Color(0.1, 0.1, 0.1, 1)
const WHITE := Color(0.95, 0.95, 0.95, 1)
const GREY := Color(0.62, 0.62, 0.62, 1)
const EDGE := Color(1, 1, 1, 0.75)
const DIM := Color(0.0, 0.0, 0.0, 0.6)
## The note every tester sees first.
const DISCLAIMER := "Continuous improvement in progress."

var _heading := Label.new()
var _note := Label.new()
var _list := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _tween: Tween


## True when the developer tools should be offered at all.
static func enabled() -> bool:
	return SHOW_IN_ALL_BUILDS or OS.is_debug_build()


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var window := VBoxContainer.new()
	window.custom_minimum_size.x = PANEL_WIDTH
	window.add_theme_constant_override("separation", 0)
	center.add_child(window)
	window.add_child(_build_title_bar())
	window.add_child(_build_screen())


## The window's top strip: its name and a Close button.
func _build_title_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var style := _flat(TITLE_BAR, EDGE)
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_bottom = 1
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING - 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	var title := _text("Developer tools", SMALL_SIZE + 2, WHITE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var close_button := Button.new()
	_style_button(close_button, "Close  ✕", WHITE)
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(close)
	row.add_child(close_button)
	bar.add_child(row)
	return bar


## The black screen: the disclaimer, a heading, a short note and the list. A faint pattern of
## scan lines lies over it, like an old monitor.
func _build_screen() -> PanelContainer:
	var screen := PanelContainer.new()
	var style := _flat(SCREEN, EDGE)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.border_width_top = 0
	style.set_content_margin_all(PADDING)
	screen.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.add_child(_text(DISCLAIMER, SMALL_SIZE, GREY))
	var rule := ColorRect.new()
	rule.color = Color(WHITE, 0.25)
	rule.custom_minimum_size.y = 1
	column.add_child(rule)
	_set_text_style(_heading, FONT_SIZE + 2, WHITE, true)
	column.add_child(_heading)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_text_style(_note, SMALL_SIZE, GREY)
	column.add_child(_note)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_list)
	column.add_child(_scroll)
	screen.add_child(column)
	var lines := ColorRect.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines_material := ShaderMaterial.new()
	lines_material.shader = _scanline_shader()
	lines.material = lines_material
	screen.add_child(lines)
	return screen


func _scanline_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, 0.12 * step(0.5, fract(FRAGCOORD.y / 3.0)));
}"""
	return shader


func is_open() -> bool:
	return visible


func open() -> void:
	_show_menu()
	visible = true
	_fade(1.0, OPEN_SECONDS)


func close() -> void:
	if not visible:
		return
	await _fade(0.0, CLOSE_SECONDS)
	visible = false


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _fade(alpha: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", alpha, seconds)
	await _tween.finished


## The first level: one row for each timeline, and one for the endings.
func _show_menu() -> void:
	_open_list("Jump to", "Start from any part of the game. Runs started here are not saved.")
	for index in DevJump.GROUPS.size():
		_add_row(str(DevJump.GROUPS[index]["title"]), _show_group.bind(index), true)
	_add_row("Endings", _show_endings, true)


## The points of one timeline. A tap opens the point straight away.
func _show_group(index: int) -> void:
	var group: Dictionary = DevJump.GROUPS[index]
	_open_list(str(group["title"]), "Tap a point to start there.")
	_add_back_row()
	for point in group["points"]:
		_add_row(str(point["label"]), _jump.bind(point))


## Main, then Alternate 1 to 5: one for each way a timeline can end.
func _show_endings() -> void:
	_open_list("Endings", "Tap one to see the screen a timeline ends on.")
	_add_back_row()
	var endings := TimelineMap.endings()
	for index in endings.size():
		_add_row(TimelineMap.ending_name(index), _show_ending.bind(endings[index]))


func _open_list(heading: String, note: String) -> void:
	_heading.text = heading
	_note.text = note
	_scroll.scroll_vertical = 0
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_scroll.custom_minimum_size.y = 0.0


func _add_back_row() -> void:
	var row := _add_row("‹  Back", _show_menu)
	row.add_theme_color_override("font_color", GREY)


## One line of the list, in a thin white frame. `opens_more` adds a › for a line that leads to
## another list. While held it turns white with black letters, like a selected line.
func _add_row(text: String, action: Callable, opens_more := false) -> Button:
	var row := Button.new()
	_style_button(row, text + ("  ›" if opens_more else ""), WHITE)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = ROW_HEIGHT
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var frame := _flat(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.3))
	_pad_row(frame)
	row.add_theme_stylebox_override("normal", frame)
	var lit := _flat(WHITE, WHITE)
	_pad_row(lit)
	for state in ["hover", "pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(state, lit)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		row.add_theme_color_override(state, SCREEN)
	row.pressed.connect(action)
	_list.add_child(row)
	var rows := _list.get_child_count()
	_scroll.custom_minimum_size.y = minf(rows * ROW_HEIGHT + (rows - 1) * ROW_GAP, LIST_HEIGHT)
	return row


func _pad_row(style: StyleBoxFlat) -> void:
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16


## A text-only button in the terminal's letters, kept out of the game's own button look and blur.
func _style_button(button: Button, text: String, color: Color) -> void:
	button.add_to_group(&"crisp_text")
	# A variation keeps the game's own button look (warm window, cursor) off this button.
	button.theme_type_variation = &"TextButton"
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 6
		empty.content_margin_right = 6
		button.add_theme_stylebox_override(state, empty)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, color)
	button.add_theme_font_override("font", MONO)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_constant_override("outline_size", 0)


func _text(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	_set_text_style(label, font_size, color, bold)
	return label


## Terminal letters: monospaced, crisp (no retro blur) and with no outline.
func _set_text_style(label: Label, font_size: int, color: Color, bold := false) -> void:
	label.add_to_group(&"crisp_text")
	label.add_theme_font_override("font", MONO_BOLD if bold else MONO)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)


func _flat(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _jump(point: Dictionary) -> void:
	visible = false
	DevJump.jump(point)


## Ends an unsaved run as if it had reached this reality, so the timeline's closing screen plays
## exactly as it does in the game.
func _show_ending(reality: Dictionary) -> void:
	visible = false
	GameState.start_unsaved_game()
	GameState.timeline = str(reality.get("timeline", ""))
	GameState.run_outcomes = (reality.get("needs", []) as Array).duplicate()
	StoryDirector.end_run("", "", "")
