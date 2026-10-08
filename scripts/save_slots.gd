class_name SaveSlots
extends Control
## The screen that lists a game's save slots, for Continue and for New Game.
##
## A left-aligned list with one row for each slot. Each row has a 4:3 picture of the place the save
## stopped in, and beside it the slot's name, where the story is up to and when it was saved, and
## how far the player has come (runs finished, memories, time played). An empty slot shows a dim
## placeholder. In the Continue list an empty slot cannot be chosen; in the New Game list it can,
## and a slot that already holds a save asks before it is replaced. A small "Delete" on a filled
## row asks first as well.
##
## The questions are small windows with the note "Tap outside to close" right under them.

## What choosing a slot does: open it (Continue), or start a new game in it (New Game).
enum Mode { LOAD, NEW }

## Emitted with the slot the player chose (an empty one, or one they agreed to replace, for New Game).
signal picked(slot: int)
## Emitted when the player goes back, or when the last save is deleted.
signal closed

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## A row is one rounded plate: a 4:3 picture on its left, then the words.
const ROW_SIZE := Vector2(800, 146)
const THUMB_INSET := 7.0
const THUMB_SIZE := Vector2(176, 132)
const TEXT_LEFT := 210.0
const ROW_GAP := 12.0
const LEFT := 92.0
const TOP := 140.0
const TITLE_TOP := 78.0
const TITLE_SIZE := 38
const NAME_SIZE := 32
const LINE_SIZE := 22
const SMALL_SIZE := 19
const RADIUS := 14
const DIM := Color(0.035, 0.02, 0.03, 0.9)
const PLATE := Color(0.09, 0.05, 0.065, 0.82)
const PLATE_EMPTY := Color(0.09, 0.05, 0.065, 0.45)
const LINE := Color(1.0, 0.953, 0.839, 0.3)
const FADE_SECONDS := 0.2
const CONTINUE_TITLE := "Choose a save"
const NEW_TITLE := "Save progress to which slot?"
const BACK := "‹  Back"
const DELETE := "Delete"
const EMPTY := "Empty slot"
const EMPTY_NEW := "Start here"
const FALLBACK_PICTURE := "res://assets/backgrounds/main_screen.png"

var _mode := Mode.LOAD
## The question being asked (replace or delete), while it shows.
var _confirm: Control


## Opens the list in `mode`.
func open(mode: Mode) -> void:
	_mode = mode
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	return "New story" if int(info["runs_finished"]) == 0 else "Ready for a new run"


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = CONTINUE_TITLE if _mode == Mode.LOAD else NEW_TITLE
	UiSkin.style_label(title, TITLE_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(LEFT, TITLE_TOP)
	add_child(title)
	for slot in GameState.SLOT_COUNT:
		_add_row(slot, Vector2(LEFT, TOP + slot * (ROW_SIZE.y + ROW_GAP)))
	var back_button := Button.new()
	back_button.theme_type_variation = &"TextButton"
	back_button.text = BACK
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.position = Vector2(LEFT - 16.0, TOP + GameState.SLOT_COUNT * (ROW_SIZE.y + ROW_GAP) + 4.0)
	back_button.pressed.connect(back)
	add_child(back_button)


## One slot's row: the whole plate is the button, with a small Delete on its right for a filled slot.
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
	# In the Continue list only a filled slot can be opened.
	var usable := filled or _mode == Mode.NEW
	row.disabled = not usable
	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", _rounded(PLATE if filled or usable else PLATE_EMPTY, 1, LINE))
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plate)
	row.add_child(_thumbnail(info, filled))
	row.add_child(_words(slot, info, filled))
	if usable:
		UiSkin.add_press_bounce(row)
	row.pressed.connect(_choose.bind(slot, filled))
	add_child(row)
	if filled:
		var delete := Button.new()
		delete.theme_type_variation = &"TextButton"
		delete.text = DELETE
		delete.focus_mode = Control.FOCUS_NONE
		delete.add_theme_font_size_override("font_size", LINE_SIZE)
		delete.position = at + Vector2(ROW_SIZE.x - 130.0, ROW_SIZE.y - 54.0)
		delete.custom_minimum_size = Vector2(120, 44)
		delete.pressed.connect(_ask_delete.bind(slot))
		add_child(delete)


## The 4:3 picture of the place the save stopped in, cropped to fill and rounded; a dim empty frame
## for an empty slot.
func _thumbnail(info: Dictionary, filled: bool) -> Control:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _rounded(Color(0.05, 0.03, 0.04, 0.9), 0, LINE))
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


## The words beside the picture: the slot's name, where it is up to and when, and how far it has come.
func _words(slot: int, info: Dictionary, filled: bool) -> Control:
	var column := VBoxContainer.new()
	column.position = Vector2(TEXT_LEFT, 0)
	column.size = Vector2(ROW_SIZE.x - TEXT_LEFT - 150.0, ROW_SIZE.y)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label("Slot %d" % (slot + 1), NAME_SIZE, true)
	column.add_child(name_label)
	if not filled:
		column.add_child(_label(EMPTY_NEW if _mode == Mode.NEW else EMPTY, LINE_SIZE, false, 0.7))
		return column
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


func _rounded(fill: Color, border_width: int, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(RADIUS)
	box.set_border_width_all(border_width)
	box.border_color = border
	box.anti_aliasing = true
	return box


## A row was tapped. For New Game, a filled slot asks before it is replaced.
func _choose(slot: int, filled: bool) -> void:
	if _mode == Mode.NEW and filled:
		_ask("Replace Slot %d?" % (slot + 1), "The save already in this slot will be lost.", "Replace", func() -> void: picked.emit(slot))
	else:
		picked.emit(slot)


func _ask_delete(slot: int) -> void:
	_ask("Delete Slot %d?" % (slot + 1), "This can’t be undone.", "Delete", _delete.bind(slot))


func _delete(slot: int) -> void:
	GameState.delete_slot(slot)
	# The list is built again, so the slot shows as empty; with no saves left there is nothing to continue.
	_close_confirm()
	for child in get_children():
		child.queue_free()
	if _mode == Mode.LOAD and GameState.latest_slot() < 0:
		closed.emit()
		queue_free()
		return
	_build.call_deferred()


## A small window with a question and two plain choices, and the note under it that tapping outside
## closes it.
func _ask(question: String, note: String, yes_text: String, yes: Callable) -> void:
	_close_confirm()
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var outside := ColorRect.new()
	outside.color = Color(0, 0, 0, 0.5)
	outside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outside.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_confirm())
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
	var window := SoftWindow.behind(panel, SoftWindow.Look.WINDOW, Vector2(40, 24))
	add_child(_confirm)
	panel.reset_size()
	panel.position = (ScreenFit.DESIGN_SIZE - panel.get_combined_minimum_size()) / 2.0
	# The note sits right under the window the player is looking at.
	UiSkin.add_close_hint(_confirm, Color(1.0, 0.953, 0.839, 0.85), Color(0.165, 0.086, 0.031, 1), window)


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
