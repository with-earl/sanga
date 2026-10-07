class_name DevTools
extends Control
## Development only: the "Developer tools" window, opened by the terminal icon next to the
## settings gear, on the main screen and in every place. It lists points of the game to jump to
## without playing from the start (see DevJump), and the screens a timeline ends on. Runs started
## here are never saved.
##
## It uses its own cool slate blue with a mint line instead of the game's warm colours, so no one
## takes it for part of the story. Tapping outside the window closes it.

## While the game is still being made, the tools show in every build, the web playtest build
## included, so coaches and testers can reach any part. Set this to false before release, and
## they show only in debug builds again.
const SHOW_IN_ALL_BUILDS := true
const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const PANEL_WIDTH := 560.0
## The list grows with its rows, and scrolls once it would get taller than this.
const LIST_HEIGHT := 380.0
const PADDING := 28.0
const ROW_HEIGHT := 50.0
const ROW_GAP := 8.0
const FONT_SIZE := 21
const NOTE_SIZE := 17
const TEXT := Color(0.86, 0.98, 0.94, 1)
const ACCENT := Color(0.45, 0.9, 0.78, 1)
const OUTLINE := Color(0.03, 0.07, 0.09, 1)
const DIM := Color(0.0, 0.0, 0.0, 0.55)

var _title := Label.new()
var _note := Label.new()
var _list := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _tween: Tween


## True when the developer tools should be offered at all.
static func enabled() -> bool:
	return SHOW_IN_ALL_BUILDS or OS.is_debug_build()


## A rounded slate box with a thin mint edge, the developer tools' own look.
static func box(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## Developer text: pale mint with a dark outline, never the game's golden ochre.
static func style_text(control: Control, font_size: int, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, color)
	control.add_theme_color_override("font_outline_color", OUTLINE)
	control.add_theme_constant_override("outline_size", 4)
	control.add_theme_font_size_override("font_size", font_size)


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
	var panel := PanelContainer.new()
	var padding := StyleBoxEmpty.new()
	padding.set_content_margin_all(PADDING)
	panel.add_theme_stylebox_override("panel", padding)
	panel.custom_minimum_size.x = PANEL_WIDTH
	SoftWindow.behind(panel, SoftWindow.Look.DEV)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_build_header())
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_text(_note, NOTE_SIZE, TEXT.darkened(0.12))
	column.add_child(_note)
	var rule := ColorRect.new()
	rule.color = Color(ACCENT, 0.35)
	rule.custom_minimum_size.y = 2
	column.add_child(rule)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_list)
	column.add_child(_scroll)


## The DEV badge, the title and a close cross, on one line.
func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var badge := Label.new()
	badge.text = "DEV"
	style_text(badge, NOTE_SIZE, OUTLINE)
	badge.add_theme_constant_override("outline_size", 0)
	var badge_back := StyleBoxFlat.new()
	badge_back.bg_color = ACCENT
	badge_back.set_corner_radius_all(6)
	badge_back.content_margin_left = 10
	badge_back.content_margin_right = 10
	badge_back.content_margin_top = 2
	badge_back.content_margin_bottom = 2
	badge.add_theme_stylebox_override("normal", badge_back)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	style_text(_title, UiSkin.HEADING_SIZE, TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	var close_button := IconButton.new()
	close_button.icon_kind = IconButton.Icon.CLOSE
	close_button.plain = true
	close_button.icon_scale = 0.5
	close_button.plain_fill = TEXT
	close_button.plain_outline = OUTLINE
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.theme_type_variation = &"TextButton"
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.pressed.connect(close)
	header.add_child(close_button)
	return header


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
	_open_list("Developer tools", "Jump to any part of the game. Runs started here are not saved.")
	for index in DevJump.GROUPS.size():
		_add_row(str(DevJump.GROUPS[index]["title"]) + "  ›", _show_group.bind(index))
	_add_row("Endings  ›", _show_endings)


## The points of one timeline. A tap opens the point straight away.
func _show_group(index: int) -> void:
	var group: Dictionary = DevJump.GROUPS[index]
	_open_list(str(group["title"]), "Tap a point to start there.")
	_add_row("‹  Back", _show_menu)
	for point in group["points"]:
		_add_row(str(point["label"]), _jump.bind(point))


## Main, then Alternate 1 to 5: one for each way a timeline can end.
func _show_endings() -> void:
	_open_list("Endings", "Tap one to see the screen a timeline ends on.")
	_add_row("‹  Back", _show_menu)
	var endings := TimelineMap.endings()
	for index in endings.size():
		_add_row(TimelineMap.ending_name(index), _show_ending.bind(endings[index]))


func _open_list(title: String, note: String) -> void:
	_title.text = title
	_note.text = note
	_scroll.scroll_vertical = 0
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_scroll.custom_minimum_size.y = 0.0


func _add_row(text: String, action: Callable) -> void:
	var row := Button.new()
	# A variation keeps the game's own button look (warm window, cursor) off this row.
	row.theme_type_variation = &"TextButton"
	row.text = text
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = ROW_HEIGHT
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	style_text(row, FONT_SIZE, TEXT)
	row.add_theme_color_override("font_pressed_color", ACCENT)
	row.add_theme_color_override("font_hover_color", ACCENT)
	row.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.05), Color(ACCENT, 0.2)))
	row.add_theme_stylebox_override("hover", box(Color(ACCENT, 0.14), Color(ACCENT, 0.5)))
	row.add_theme_stylebox_override("pressed", box(Color(ACCENT, 0.24), ACCENT))
	row.add_theme_stylebox_override("hover_pressed", box(Color(ACCENT, 0.24), ACCENT))
	row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	row.pressed.connect(action)
	_list.add_child(row)
	var rows := _list.get_child_count()
	_scroll.custom_minimum_size.y = minf(rows * ROW_HEIGHT + (rows - 1) * ROW_GAP, LIST_HEIGHT)


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
