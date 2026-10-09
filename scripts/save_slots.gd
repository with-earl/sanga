class_name SaveSlots
extends Control
## The screen that lists the save slots of the game mode in use (Story Mode or Shift Mode, each with
## its own three).
##
## A compact, left-aligned list with one row for each slot. Each row has a small 4:3 picture of the
## place the save stopped in, and beside it the slot's name, where the story is up to and when it
## was saved, and how far the player has come. Tapping a row selects it. In the empty space at the
## right, two buttons act on the selected slot, bottom-aligned with Back: "Load" for a save or "New
## game" for an empty slot, and Delete. Loading and deleting each ask first, in a small window with
## a Cancel choice, so it closes only by its own buttons (no tapping outside).
##
## An empty slot looks like a void: grey, faint and flat, with no picture. It can be selected, to
## start a new game in it.

## Emitted with the slot the player confirmed: a save to open, or an empty slot to start a new game in
## (the main screen tells them apart with GameState.has_slot).
signal picked(slot: int)
## Emitted when the player goes back.
signal closed

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## A row is one rounded plate: a 4:3 picture on its left, then the words.
const ROW_SIZE := Vector2(560, 108)
const THUMB_INSET := 8.0
const THUMB_SIZE := Vector2(122, 92)
const TEXT_LEFT := 146.0
const ROW_GAP := 10.0
const LEFT := 90.0
const TOP := 150.0
const TITLE_TOP := 96.0
const TITLE_SIZE := 30
const NAME_SIZE := 24
const LINE_SIZE := 18
const SMALL_SIZE := 15
const RADIUS := 12
## Back, Load and Delete are all this tall, so their bottoms line up exactly. The two actions sit in
## the empty space at the right of the list.
const BUTTON_HEIGHT := 52.0
const BUTTON_GAP := 8.0
## The two actions are the main screen's buttons in size and place: 300 x 52, centred on the logo's
## line, 258 px in from the right edge.
const ACTION_WIDTH := 300.0
const ACTION_CENTER_X := 1280.0 - 258.0
const DIM := Color(0.035, 0.02, 0.03, 0.9)
const PLATE := Color(0.09, 0.05, 0.065, 0.82)
const PLATE_SELECTED := Color(0.17, 0.1, 0.12, 0.92)
const LINE := Color(1.0, 0.953, 0.839, 0.3)
const SELECTED_LINE := Color(0.851, 0.643, 0.255, 0.95)
## An empty slot: a faint grey plate that barely shows, like a gap in the list.
const VOID_PLATE := Color(0.55, 0.55, 0.58, 0.1)
const VOID_LINE := Color(0.75, 0.75, 0.78, 0.2)
const VOID_TEXT := Color(0.72, 0.72, 0.75, 0.5)
const FADE_SECONDS := 0.2
const BACK := "‹  Back"
const LOAD := "Load"
const NEW_GAME := "New game"
const DELETE := "Delete"
const EMPTY := "Empty slot"
const FALLBACK_PICTURE := "res://assets/backgrounds/main_screen.png"

## The question being asked (load, replace or delete), while it shows.
var _confirm: Control
## The slot that is selected, or -1 for none, and each row's parts so a selection can light it up.
var _selected := -1
var _rows: Array = []
var _load_button: Button
var _delete_button: Button


## Opens the list for the game mode in use (GameState.mode), with the most recent save selected.
func open() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_selected = GameState.latest_slot()
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)


## Steps back one level: closes the question if it is open, otherwise the list.
func back() -> void:
	if _confirm != null:
		_close_confirm()
		return
	closed.emit()
	queue_free()


## "Oct 4, 7:23 PM" from a saved time such as "2026-10-04T19:23:13", with the year added when it
## is not this year. Empty when the time cannot be read.
static func format_time(saved_at: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(saved_at)
	if unix <= 0:
		return ""
	var when := Time.get_datetime_dict_from_unix_time(int(unix))
	var hour: int = when["hour"] % 12
	if hour == 0:
		hour = 12
	var meridiem := "AM" if when["hour"] < 12 else "PM"
	var year := ""
	if when["year"] != Time.get_date_dict_from_system()["year"]:
		year = ", %d" % when["year"]
	return "%s %d%s, %d:%02d %s" % [MONTHS[when["month"] - 1], when["day"], year, hour, when["minute"], meridiem]


## "Slot 1 · Kumpisal · Oct 4, 7:23 PM" for a slot, "Slot 2 · Empty" for an empty one: the short
## name of a save, for the start screen's top line.
static func describe(slot: int) -> String:
	var info := GameState.slot_summary(slot)
	if not info["exists"]:
		return "Slot %d · Empty" % (slot + 1)
	return "Slot %d · %s · %s" % [slot + 1, where(info), format_time(info["saved_at"])]


## Where a save's story is up to: the story being played, or a line about the run between runs.
static func where(info: Dictionary) -> String:
	var stories: Array = StoryDirector.TIMELINES.get(info["timeline"], [])
	if str(info["timeline"]) != "" and int(info["chapter"]) < stories.size():
		return StoryDirector.story_title(stories[int(info["chapter"])])
	if GameState.mode == GameState.MODE_SHIFT:
		return "Ready for a new run"
	return "New story" if int(info["runs_finished"]) == 0 else "Story complete"


func _build() -> void:
	_rows.clear()
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = "Story Mode" if GameState.mode == GameState.MODE_STORY else "Shift Mode  ·  %s" % StoryDirector.story_title(GameState.shift_story)
	UiSkin.style_label(title, TITLE_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The whole group (title, rows, buttons) is centred up and down on the screen.
	var list_bottom := TOP + GameState.SLOT_COUNT * (ROW_SIZE.y + ROW_GAP) + 16.0 + BUTTON_HEIGHT
	var shift := (ScreenFit.DESIGN_SIZE.y - (list_bottom - TITLE_TOP)) / 2.0 - TITLE_TOP
	title.position = Vector2(LEFT, TITLE_TOP + shift)
	add_child(title)
	for slot in GameState.SLOT_COUNT:
		_add_row(slot, Vector2(LEFT, TOP + shift + slot * (ROW_SIZE.y + ROW_GAP)))
	# Back, Load and Delete share one bottom edge, a little under the list.
	var bottom := list_bottom + shift
	var back_button := _button(BACK, Vector2(150, BUTTON_HEIGHT))
	back_button.position = Vector2(LEFT - 14.0, bottom - BUTTON_HEIGHT)
	back_button.pressed.connect(back)
	add_child(back_button)
	var action_left := ACTION_CENTER_X - ACTION_WIDTH / 2.0
	_delete_button = _button(DELETE, Vector2(ACTION_WIDTH, BUTTON_HEIGHT))
	_delete_button.position = Vector2(action_left, bottom - BUTTON_HEIGHT)
	_delete_button.pressed.connect(_ask_delete)
	add_child(_delete_button)
	_load_button = _button(LOAD, Vector2(ACTION_WIDTH, BUTTON_HEIGHT))
	_load_button.position = Vector2(action_left, bottom - 2.0 * BUTTON_HEIGHT - BUTTON_GAP)
	_load_button.pressed.connect(_ask_load)
	add_child(_load_button)
	_refresh()


## A plain text button of the menu's look, a little smaller than the main screen's.
func _button(words: String, size: Vector2) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"TextButton"
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_disabled_color", Color(UiSkin.BUTTON_TEXT, 0.3))
	button.custom_minimum_size = size
	button.size = size
	return button


## One slot's row: the whole plate is the button, and tapping it selects the slot.
func _add_row(slot: int, at: Vector2) -> void:
	var info := GameState.slot_summary(slot)
	var filled: bool = info["exists"]
	var row := Button.new()
	row.flat = true
	row.focus_mode = Control.FOCUS_NONE
	row.position = at
	row.size = ROW_SIZE
	row.custom_minimum_size = ROW_SIZE
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		row.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	row.disabled = false
	var plate := Panel.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plate)
	row.add_child(_thumbnail(info, filled))
	row.add_child(_words(slot, info, filled))
	UiSkin.add_press_bounce(row)
	row.pressed.connect(_select.bind(slot))
	add_child(row)
	_rows.append({"slot": slot, "filled": filled, "plate": plate})


## Selects a slot and lights it up.
func _select(slot: int) -> void:
	_selected = slot
	_refresh()


## Shows which row is selected, and turns the two buttons on only when they can act on it.
func _refresh() -> void:
	for row in _rows:
		var plate: Panel = row["plate"]
		var filled: bool = row["filled"]
		var chosen: bool = int(row["slot"]) == _selected
		var style := _rounded(VOID_PLATE, 1, VOID_LINE)
		if filled and chosen:
			style = _rounded(PLATE_SELECTED, 2, SELECTED_LINE)
		elif filled:
			style = _rounded(PLATE, 1, LINE)
		elif chosen:
			# An empty slot that is picked: still a void, but with a gold edge.
			style = _rounded(VOID_PLATE, 2, SELECTED_LINE)
		plate.add_theme_stylebox_override("panel", style)
	var has_selection := _selected >= 0
	var selected_filled := has_selection and GameState.has_slot(_selected)
	_load_button.disabled = not has_selection
	_load_button.text = LOAD if selected_filled else NEW_GAME
	_delete_button.disabled = not selected_filled


## A small 4:3 picture of the place the save stopped in, cropped to fill and rounded; a flat grey
## void for an empty slot.
func _thumbnail(info: Dictionary, filled: bool) -> Control:
	var frame := Panel.new()
	var fill := Color(0.05, 0.03, 0.04, 0.9) if filled else Color(0.6, 0.6, 0.63, 0.08)
	frame.add_theme_stylebox_override("panel", _rounded(fill, 0, LINE))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.position = Vector2(THUMB_INSET, THUMB_INSET)
	frame.size = THUMB_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if filled:
		var path := "res://assets/backgrounds/%s.png" % str(info["location"])
		var picture := TextureRect.new()
		picture.texture = load(path if ResourceLoader.exists(path) else FALLBACK_PICTURE) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(picture)
	return frame


## The words beside the picture: the slot's name, where it is up to and when, and how far it has
## come. An empty slot has only a grey name and "Empty slot".
func _words(slot: int, info: Dictionary, filled: bool) -> Control:
	var column := VBoxContainer.new()
	column.position = Vector2(TEXT_LEFT, 0)
	column.size = Vector2(ROW_SIZE.x - TEXT_LEFT - 10.0, ROW_SIZE.y)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not filled:
		column.add_child(_void_label("Slot %d" % (slot + 1), NAME_SIZE))
		column.add_child(_void_label(EMPTY, LINE_SIZE))
		return column
	column.add_child(_label("Slot %d" % (slot + 1), NAME_SIZE, true))
	var stories: Array = StoryDirector.TIMELINES.get(info["timeline"], [])
	var place := where(info)
	if str(info["timeline"]) != "" and stories.size() > 0:
		place += " · %d of %d" % [int(info["chapter"]) + 1, stories.size()]
	column.add_child(_label("%s · %s" % [place, format_time(info["saved_at"])], LINE_SIZE, false))
	var runs := int(info["runs_finished"])
	var memories := int(info.get("alaala", 0))
	column.add_child(_label("%d %s · %d %s · %s" % [
		runs, "run" if runs == 1 else "runs", memories, "memory" if memories == 1 else "memories", _played(float(info["play_seconds"]))
	], SMALL_SIZE, false, 0.8))
	return column


func _played(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %d min" % [minutes / 60, minutes % 60]


## Cream words with a dark outline; a name is golden ochre.
func _label(words: String, font_size: int, is_name: bool, alpha := 1.0) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	if is_name:
		UiSkin.style_label(label, font_size)
	else:
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(UiSkin.BUTTON_TEXT, alpha))
		label.add_theme_color_override("font_outline_color", UiSkin.BUTTON_OUTLINE)
		label.add_theme_constant_override("outline_size", 4)
	return label


## Faint grey words with no outline, for an empty slot.
func _void_label(words: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", VOID_TEXT)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _rounded(fill: Color, border_width: int, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(RADIUS)
	box.set_border_width_all(border_width)
	box.border_color = border
	box.anti_aliasing = true
	return box


## Load (or New game) was pressed. A save asks first; an empty slot just starts.
func _ask_load() -> void:
	if _selected < 0:
		return
	var slot := _selected
	if GameState.has_slot(slot):
		_ask("Load Slot %d?" % (slot + 1), "Continue where this save left off.", "Load", func() -> void: picked.emit(slot))
	else:
		picked.emit(slot)


func _ask_delete() -> void:
	if _selected < 0 or not GameState.has_slot(_selected):
		return
	var slot := _selected
	_ask("Delete Slot %d?" % (slot + 1), "This can’t be undone.", "Delete", _delete.bind(slot))


func _delete(slot: int) -> void:
	GameState.delete_slot(slot)
	_close_confirm()
	_selected = -1
	for child in get_children():
		child.queue_free()
	_build.call_deferred()


## A small window with a question and two plain choices. It has a Cancel choice, so tapping outside
## does nothing: it closes only from its own buttons (and the back button).
func _ask(question: String, note: String, yes_text: String, yes: Callable) -> void:
	_close_confirm()
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var outside := ColorRect.new()
	outside.color = Color(0, 0, 0, 0.5)
	outside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(outside)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	panel.custom_minimum_size = Vector2(420, 0)
	var asking := _label(question, 30, false)
	asking.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(asking)
	var detail := _label(note, LINE_SIZE, false, 0.85)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(detail)
	for choice in [[yes_text, yes], ["Cancel", _close_confirm]]:
		var button := Button.new()
		button.theme_type_variation = &"TextButton"
		button.text = str(choice[0])
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(300, 52)
		button.pressed.connect(choice[1])
		panel.add_child(button)
	_confirm.add_child(panel)
	SoftWindow.behind(panel, SoftWindow.Look.WINDOW, Vector2(40, 24))
	add_child(_confirm)
	panel.reset_size()
	panel.position = (ScreenFit.DESIGN_SIZE - panel.get_combined_minimum_size()) / 2.0


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
