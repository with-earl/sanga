class_name DevTools
extends Control
## Development only: the "Developer tools" window, opened by the terminal icon next to the
## settings gear, on the main screen and in every place. It lists points of the game to jump to
## without playing from the start (see DevJump), and the screens a timeline ends on. Runs started
## here are never saved.
##
## It looks like a computer terminal (a black screen, green monospaced text, a prompt and a
## blinking cursor) instead of the game's warm storybook windows, so no one takes it for part of
## the story. Tapping outside the window closes it.

## While the game is still being made, the tools show in every build, the web playtest build
## included, so coaches and testers can reach any part. Set this to false before release, and
## they show only in debug builds again.
const SHOW_IN_ALL_BUILDS := true
const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const PANEL_WIDTH := 600.0
## The list grows with its rows, and scrolls once it would get taller than this.
const LIST_HEIGHT := 360.0
const PADDING := 24.0
const ROW_HEIGHT := 44.0
const ROW_GAP := 4.0
const FONT_SIZE := 20
const SMALL_SIZE := 16
## A terminal's monospaced letters (DejaVu Sans Mono, a free font; licence in assets/fonts).
const MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")
const MONO_BOLD := preload("res://assets/fonts/DejaVuSansMono-Bold.ttf")
const SCREEN := Color(0.035, 0.045, 0.04, 0.97)
const TITLE_BAR := Color(0.1, 0.12, 0.11, 1)
const GREEN := Color(0.42, 0.96, 0.55, 1)
const DIM_GREEN := Color(0.3, 0.62, 0.4, 1)
const WHITE := Color(0.85, 0.9, 0.86, 1)
const DIM := Color(0.0, 0.0, 0.0, 0.6)
## The note every tester sees first, written as a comment line in the terminal.
const DISCLAIMER := "# Continuous improvement in progress."
const CURSOR_BLINK_SECONDS := 0.55

var _path := Label.new()
var _note := Label.new()
var _command := Label.new()
var _list := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _cursor := Label.new()
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
	_start_cursor_blink()


## The window's top strip: three dots, the window's name and a close button, like a terminal app.
func _build_title_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var style := _flat(TITLE_BAR, Color(GREEN, 0.55))
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 16
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for dot_color in [Color(0.93, 0.36, 0.33), Color(0.95, 0.75, 0.3), Color(0.38, 0.8, 0.42)]:
		var dot := Panel.new()
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = dot_color
		dot_style.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
	var title := _text("Developer tools", SMALL_SIZE, WHITE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)
	var close_button := Button.new()
	_style_button(close_button, "[x]", WHITE)
	close_button.custom_minimum_size = Vector2(52, 36)
	close_button.add_theme_font_size_override("font_size", SMALL_SIZE + 2)
	close_button.pressed.connect(close)
	row.add_child(close_button)
	bar.add_child(row)
	return bar


## The black screen: the disclaimer, a short help line, the command being "run", its list of
## results and a prompt with a blinking cursor. A faint pattern of scan lines lies over it.
func _build_screen() -> PanelContainer:
	var screen := PanelContainer.new()
	var style := _flat(SCREEN, Color(GREEN, 0.55))
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.set_content_margin_all(PADDING)
	screen.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(_text(DISCLAIMER, SMALL_SIZE, DIM_GREEN))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_text_style(_note, SMALL_SIZE, DIM_GREEN)
	column.add_child(_note)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)
	_set_text_style(_command, FONT_SIZE, WHITE, true)
	column.add_child(_command)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_list)
	column.add_child(_scroll)
	var prompt := HBoxContainer.new()
	prompt.add_theme_constant_override("separation", 0)
	_set_text_style(_path, FONT_SIZE, GREEN, true)
	prompt.add_child(_path)
	_set_text_style(_cursor, FONT_SIZE, GREEN, true)
	_cursor.text = "█"
	prompt.add_child(_cursor)
	column.add_child(prompt)
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
	COLOR = vec4(0.0, 0.0, 0.0, 0.16 * step(0.5, fract(FRAGCOORD.y / 3.0)));
}"""
	return shader


func _start_cursor_blink() -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(_cursor, "modulate:a", 0.0, 0.0).set_delay(CURSOR_BLINK_SECONDS)
	blink.tween_property(_cursor, "modulate:a", 1.0, 0.0).set_delay(CURSOR_BLINK_SECONDS)


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
	_open_list("~", "ls", "# Jump to any part of the game. Runs started here are not saved.")
	for index in DevJump.GROUPS.size():
		_add_row(_folder_name(str(DevJump.GROUPS[index]["title"])) + "/", _show_group.bind(index))
	_add_row("endings/", _show_endings)


## The points of one timeline. A tap opens the point straight away.
func _show_group(index: int) -> void:
	var group: Dictionary = DevJump.GROUPS[index]
	var folder := _folder_name(str(group["title"]))
	_open_list("~/" + folder, "ls", "# " + str(group["title"]) + ". Tap a point to start there.")
	_add_row("../", _show_menu, true)
	for point in group["points"]:
		_add_row(str(point["label"]), _jump.bind(point))


## Main, then Alternate 1 to 5: one for each way a timeline can end.
func _show_endings() -> void:
	_open_list("~/endings", "ls", "# Tap one to see the screen a timeline ends on.")
	_add_row("../", _show_menu, true)
	var endings := TimelineMap.endings()
	for index in endings.size():
		_add_row(TimelineMap.ending_name(index), _show_ending.bind(endings[index]))


## "Main timeline" becomes "main_timeline", like a folder name in a terminal.
func _folder_name(title: String) -> String:
	return title.to_lower().replace(" ", "_")


func _open_list(path: String, command: String, note: String) -> void:
	_command.text = "dev@sanga:%s$ %s" % [path, command]
	_path.text = "dev@sanga:%s$ " % path
	_note.text = note
	_scroll.scroll_vertical = 0
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_scroll.custom_minimum_size.y = 0.0


## One result line. It lights up in green, with dark text, while held, like a selected line.
func _add_row(text: String, action: Callable, dimmed := false) -> void:
	var row := Button.new()
	_style_button(row, "  " + text, DIM_GREEN if dimmed else GREEN)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = ROW_HEIGHT
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var lit := _flat(GREEN, GREEN)
	lit.set_corner_radius_all(2)
	for state in ["hover", "pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(state, lit)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		row.add_theme_color_override(state, SCREEN)
	row.pressed.connect(action)
	_list.add_child(row)
	var rows := _list.get_child_count()
	_scroll.custom_minimum_size.y = minf(rows * ROW_HEIGHT + (rows - 1) * ROW_GAP, LIST_HEIGHT)


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
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
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
