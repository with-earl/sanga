class_name DevTools
extends Control
## Development only: the "Developer Tools" window, opened by the terminal icon next to the
## settings gear, on the main screen and in every place. It lists the start of each story on each
## timeline, and the screens a timeline ends on, so testers can reach any part without playing
## from the start (see DevJump). Runs started here are never saved.
##
## It follows Apple's own design: a black, rounded sheet with a title and a "Done" button at the
## top, grouped lists of rows on rounded dark cards with thin dividers and a grey chevron, small
## grey section titles, and a grey footnote. Everything is black, white and greys, in terminal
## letters, so no one takes it for part of the story. Tapping outside the sheet closes it.

## While the game is still being made, the tools show in every build, the web playtest build
## included, so coaches and testers can reach any part. Set this to false before release, and
## they show only in debug builds again.
const SHOW_IN_ALL_BUILDS := true
const OPEN_SECONDS := 0.2
const CLOSE_SECONDS := 0.15
const SHEET_WIDTH := 620.0
## The sheet never gets taller than this; the lists scroll inside it.
const LIST_HEIGHT := 440.0
const SHEET_RADIUS := 18
const CARD_RADIUS := 12
const SIDE := 20.0
const ROW_HEIGHT := 50.0
const ROW_INSET := 18
const TITLE_SIZE := 22
const ROW_SIZE := 19
const SMALL_SIZE := 15
## Terminal letters (DejaVu Sans Mono, a free font; licence in assets/fonts).
const MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")
const MONO_BOLD := preload("res://assets/fonts/DejaVuSansMono-Bold.ttf")
## Apple's dark-mode greys: the sheet, the cards, a held row, the dividers and the quieter text.
const SHEET := Color(0.0, 0.0, 0.0, 0.97)
const CARD := Color(0.11, 0.11, 0.118, 1)
const CARD_HELD := Color(0.227, 0.227, 0.235, 1)
const DIVIDER := Color(0.22, 0.22, 0.227, 1)
const LABEL := Color(1, 1, 1, 1)
const SECONDARY := Color(0.557, 0.557, 0.576, 1)
const DIM := Color(0.0, 0.0, 0.0, 0.5)
const TITLE := "Developer Tools"
const ENDINGS_TITLE := "Endings"
## The footnote under the lists.
const FOOTNOTE := "This build is still in development, so some parts may use placeholder art or text."

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
	var sheet := PanelContainer.new()
	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = SHEET
	sheet_style.border_color = DIVIDER
	sheet_style.set_border_width_all(1)
	sheet_style.set_corner_radius_all(SHEET_RADIUS)
	sheet_style.anti_aliasing = true
	sheet.add_theme_stylebox_override("panel", sheet_style)
	sheet.custom_minimum_size.x = SHEET_WIDTH
	center.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	sheet.add_child(column)
	column.add_child(_build_bar())
	column.add_child(_divider(0))
	column.add_child(_build_lists())


## The top bar: the title at the left and "Done" at the right, as on an Apple sheet.
func _build_bar() -> MarginContainer:
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_left", int(SIDE))
	bar.add_theme_constant_override("margin_right", int(SIDE) - 8)
	bar.add_theme_constant_override("margin_top", 10)
	bar.add_theme_constant_override("margin_bottom", 10)
	var row := HBoxContainer.new()
	var title := _text(TITLE, TITLE_SIZE, LABEL, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var done := Button.new()
	_plain_button(done)
	done.text = "Done"
	done.add_theme_font_override("font", MONO_BOLD)
	done.add_theme_font_size_override("font_size", ROW_SIZE)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		done.add_theme_color_override(state, LABEL)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		done.add_theme_color_override(state, SECONDARY)
	done.custom_minimum_size = Vector2(72, 44)
	done.pressed.connect(close)
	row.add_child(done)
	bar.add_child(row)
	return bar


## One section per timeline, then the endings, in a scrolling area, with the footnote under the
## first section.
func _build_lists() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = LIST_HEIGHT
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, int(SIDE))
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", int(SIDE))
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 0)
	for index in DevJump.GROUPS.size():
		var group: Dictionary = DevJump.GROUPS[index]
		var rows: Array = []
		for point in group["points"]:
			rows.append([str(point["label"]), _jump.bind(point)])
		_add_section(sections, str(group["title"]), rows)
		# The footnote sits under the first list, as on Apple's settings screens, so it is read
		# without scrolling.
		if index == 0:
			sections.add_child(_footnote())
	var endings: Array = []
	var realities := TimelineMap.endings()
	for index in realities.size():
		var name := "Main Ending" if index == 0 else "Alternate Ending %d" % index
		endings.append([name, _show_ending.bind(realities[index])])
	_add_section(sections, ENDINGS_TITLE, endings)
	margin.add_child(sections)
	scroll.add_child(margin)
	return scroll


## The grey footnote, indented like the rows above it.
func _footnote() -> MarginContainer:
	var footnote := _text(FOOTNOTE, SMALL_SIZE, SECONDARY)
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", ROW_INSET)
	holder.add_theme_constant_override("margin_right", ROW_INSET)
	holder.add_theme_constant_override("margin_top", 8)
	holder.add_child(footnote)
	return holder


## A small grey section title, then its rows on one rounded card, with thin dividers between rows.
func _add_section(parent: VBoxContainer, title: String, rows: Array) -> void:
	var heading := MarginContainer.new()
	heading.add_theme_constant_override("margin_left", ROW_INSET)
	heading.add_theme_constant_override("margin_top", 20)
	heading.add_theme_constant_override("margin_bottom", 8)
	heading.add_child(_text(title, SMALL_SIZE, SECONDARY))
	parent.add_child(heading)
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CARD
	card_style.set_corner_radius_all(CARD_RADIUS)
	card_style.anti_aliasing = true
	card.add_theme_stylebox_override("panel", card_style)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	for index in rows.size():
		if index > 0:
			list.add_child(_divider(ROW_INSET))
		var row: Button = _row(str(rows[index][0]), index == 0, index == rows.size() - 1)
		row.pressed.connect(rows[index][1])
		list.add_child(row)
	card.add_child(list)
	parent.add_child(card)


## One row: its name at the left and a grey chevron at the right. While held it turns a lighter
## grey, the way an Apple list row does.
func _row(text: String, first: bool, last: bool) -> Button:
	var row := Button.new()
	_plain_button(row)
	row.custom_minimum_size.y = ROW_HEIGHT
	var held := StyleBoxFlat.new()
	held.bg_color = CARD_HELD
	held.anti_aliasing = true
	if first:
		held.corner_radius_top_left = CARD_RADIUS
		held.corner_radius_top_right = CARD_RADIUS
	if last:
		held.corner_radius_bottom_left = CARD_RADIUS
		held.corner_radius_bottom_right = CARD_RADIUS
	for state in ["pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(state, held)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = ROW_INSET
	line.offset_right = -ROW_INSET
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := _text(text, ROW_SIZE, LABEL)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name)
	var chevron := _text("›", ROW_SIZE + 4, SECONDARY)
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(chevron)
	row.add_child(line)
	return row


## A thin divider line, indented from the left like Apple's list dividers.
func _divider(inset: int) -> MarginContainer:
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", inset)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = DIVIDER
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


## A text-free, see-through button, kept out of the game's own button look and blur.
func _plain_button(button: Button) -> void:
	button.add_to_group(&"crisp_text")
	# A variation keeps the game's own button look (warm window, cursor) off this button.
	button.theme_type_variation = &"TextButton"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_constant_override("outline_size", 0)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


## Terminal letters: monospaced, crisp (no retro blur) and with no outline.
func _text(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.add_to_group(&"crisp_text")
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MONO_BOLD if bold else MONO)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	return label


func is_open() -> bool:
	return visible


func open() -> void:
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
