class_name DevTools
extends Control
## Development only: the "Developer Tools" window, opened by the terminal icon next to the
## settings gear, on the main screen and in every place. It lists the start of each story, the
## stories that react to what came before them in a run, and two run endings, so testers can reach
## any part without playing from the start (see DevJump). Runs started here are never saved.
##
## It follows Apple's own design: a black, rounded sheet with a title at the
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
## Run endings to jump to: a name, where the run began, and the outcomes it reached. The first is
## the usual first run; the second earns the true ending, so its epilogue plays.
const ENDINGS := [
	["First Run Ending", "main", ["tokhang_peter", "kumpisal_kulas", "padala_police"]],
	["True Ending", "kumpisal", ["kumpisal_sinamahan", "padala_pinalaya", "tokhang_safe"]],
]
## The Alaala (memories) a save holds open new choices. These rows give or take them all at once,
## to test those choices without dying first.
const MEMORIES_TITLE := "Memories"
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
	# The same note as the game's windows, in the sheet's own crisp grey letters.
	var hint := UiSkin.add_close_hint(self, SECONDARY, Color.TRANSPARENT)
	hint.add_to_group(&"crisp_text")
	hint.material = null
	hint.add_theme_font_override("font", MONO)
	hint.add_theme_font_size_override("font_size", SMALL_SIZE)


## The top bar: the title. There is no close button: tapping outside closes the sheet.
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
	bar.add_child(row)
	return bar


## One section per group of jump points, then the endings, in a scrolling area, with the footnote under the
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
	for ending in ENDINGS:
		endings.append([str(ending[0]), _show_ending.bind(str(ending[1]), ending[2])])
	_add_section(sections, ENDINGS_TITLE, endings)
	_add_section(sections, MEMORIES_TITLE, [
		["Remember All Memories", _set_all_memories.bind(true)],
		["Forget All Memories", _set_all_memories.bind(false)],
	])
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


func _set_all_memories(remember: bool) -> void:
	GameState.alaala = []
	if remember:
		for item in Alaala.all():
			GameState.alaala.append(str(item.get("id", "")))
	GameState.save_current(true)
	close()


func _jump(point: Dictionary) -> void:
	visible = false
	DevJump.jump(point)


## Ends an unsaved run as if it had begun at `timeline` and reached `outcomes`, so the run's
## closing (the true ending's epilogue, when earned, and the recap) plays as it does in the game.
func _show_ending(timeline: String, outcomes: Array) -> void:
	visible = false
	GameState.start_unsaved_game()
	GameState.timeline = timeline
	GameState.run_outcomes = outcomes.duplicate()
	StoryDirector.end_run("", "", "")
