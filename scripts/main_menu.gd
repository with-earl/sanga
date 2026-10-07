extends Control
## Main screen. Quit, loading a save, and deleting a save all happen in place: the three menu
## buttons are swapped for a short list or a question with Yes and No, in the same spot.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const ROW_SIZE := Vector2(300, 52)
## Development only: the "Developer tools" window on the left, for opening any point of the game
## without playing from the start (see DevJump), or the screen a timeline ends on. Runs started
## there are never saved. While the game is still being made it shows in every build, the web
## playtest build included, so coaches and testers can reach any part. It starts folded into one
## clearly labelled button, in cool blue rather than the game's warm colours, with a note that
## this is a development preview, so no one takes it for a bug. Set this to false before release,
## and it shows only in debug builds again.
const SHOW_DEV_MENU_IN_ALL_BUILDS := true
const DEV_PANEL_LEFT := 40.0
const DEV_PANEL_TOP := 96.0
const DEV_PANEL_WIDTH := 420.0
const DEV_PANEL_BOTTOM := 70.0
const DEV_PANEL_PADDING := 20.0
const DEV_ROW_HEIGHT := 48.0
const DEV_FONT_SIZE := 21
const DEV_NOTE_SIZE := 17
const DEV_TEXT := Color(0.86, 0.98, 0.94, 1)
const DEV_ACCENT := Color(0.45, 0.9, 0.78, 1)
const DEV_OUTLINE := Color(0.03, 0.07, 0.09, 1)
const DEV_BUTTON_SIZE := Vector2(330, 52)
## The line at the bottom left saying this is a build still being made.
const PREVIEW_NOTE := "DEVELOPMENT PREVIEW  ·  work in progress, not the final game"
## The main buttons, the save list and the quit question each sit on a soft window, hugging their
## contents above the bottom right corner.
const MENU_WINDOW_MARGIN := Vector2(26.0, 18.0)

@onready var _menu: Control = $Buttons
@onready var _quit_confirm: Control = %QuitConfirm
@onready var _save_panel: VBoxContainer = %SavePanel
@onready var _continue_button: Button = %ContinueButton
@onready var _new_button: Button = %NewButton
@onready var _load_button: Button = %LoadButton
@onready var _quit_button: Button = %QuitButton
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton
## The gear at the top left, opening the sound, music and vibration settings.
@onready var _settings: GameMenu = $Settings

## What the Android back button does while the save panel is showing.
var _back_action := Callable()
var _dev_panel := PanelContainer.new()
var _dev_title := Label.new()
var _dev_list := VBoxContainer.new()
var _dev_scroll := ScrollContainer.new()
var _dev_note := Label.new()
var _dev_open_button := Button.new()


func _ready() -> void:
	_continue_button.visible = GameState.latest_slot() >= 0
	_continue_button.pressed.connect(_on_continue)
	_new_button.pressed.connect(_show_new_game_slots)
	_load_button.pressed.connect(_show_slots.bind(false))
	_quit_button.pressed.connect(_show_quit_confirm.bind(true))
	# A web page cannot close itself, so the browser build has no Quit.
	_quit_button.visible = not OS.has_feature("web")
	_yes_button.pressed.connect(get_tree().quit)
	_no_button.pressed.connect(_show_quit_confirm.bind(false))
	for panel in [_menu, _quit_confirm, _save_panel]:
		_put_on_window(panel)
	if SHOW_DEV_MENU_IN_ALL_BUILDS or OS.is_debug_build():
		_build_dev_panel()
		_show_dev_menu()
		_show_dev_panel(false)


## Android back button steps back one level. From the main buttons it asks before leaving.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _settings.is_open():
		_settings.close()
	elif _save_panel.visible:
		_back_action.call()
	else:
		_show_quit_confirm(not _quit_confirm.visible)


## Gives one of the right-hand lists a soft window that grows and shrinks with what is in it,
## with its buttons centred on it.
func _put_on_window(panel: VBoxContainer) -> void:
	SoftWindow.behind(panel, SoftWindow.Look.WINDOW, MENU_WINDOW_MARGIN)
	for child in panel.get_children():
		if child is Button:
			(child as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif child is Label:
			(child as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hug := func() -> void:
		panel.offset_top = panel.offset_bottom - panel.get_combined_minimum_size().y
	panel.minimum_size_changed.connect(hug)
	hug.call()


## The question takes the place of the three menu buttons, in the same spot.
func _show_quit_confirm(asking: bool) -> void:
	_quit_confirm.visible = asking
	_menu.visible = not asking


func _show_main() -> void:
	_save_panel.visible = false
	_quit_confirm.visible = false
	_menu.visible = true


## Development only. The folded button, the "Developer tools" window it opens (a title, a short
## note saying what it is for, and a scrolling list of rows), and the preview note at the bottom.
func _build_dev_panel() -> void:
	_style_dev_button(_dev_open_button, "DEV  ·  Developer tools  ›", DEV_ACCENT)
	_dev_open_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dev_open_button.position = Vector2(DEV_PANEL_LEFT, DEV_PANEL_TOP)
	_dev_open_button.size = DEV_BUTTON_SIZE
	_dev_open_button.add_theme_stylebox_override("normal", _dev_box(Color(0.1, 0.17, 0.22, 0.94), DEV_ACCENT))
	_dev_open_button.add_theme_stylebox_override("hover", _dev_box(Color(0.14, 0.24, 0.3, 0.96), DEV_ACCENT))
	_dev_open_button.add_theme_stylebox_override("pressed", _dev_box(Color(0.18, 0.3, 0.36, 0.96), DEV_ACCENT))
	_dev_open_button.pressed.connect(_show_dev_panel.bind(true))
	add_child(_dev_open_button)

	var style := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, DEV_PANEL_PADDING)
	_dev_panel.add_theme_stylebox_override("panel", style)
	SoftWindow.behind(_dev_panel, SoftWindow.Look.DEV)
	_dev_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_dev_panel.offset_left = DEV_PANEL_LEFT
	_dev_panel.offset_top = DEV_PANEL_TOP
	_dev_panel.offset_right = DEV_PANEL_LEFT + DEV_PANEL_WIDTH
	_dev_panel.offset_bottom = -DEV_PANEL_BOTTOM
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	var badge := Label.new()
	badge.text = "DEV"
	_style_dev_text(badge, DEV_NOTE_SIZE, DEV_OUTLINE)
	badge.add_theme_constant_override("outline_size", 0)
	var badge_back := StyleBoxFlat.new()
	badge_back.bg_color = DEV_ACCENT
	badge_back.set_corner_radius_all(6)
	badge_back.set_content_margin_all(4)
	badge_back.content_margin_left = 10
	badge_back.content_margin_right = 10
	badge.add_theme_stylebox_override("normal", badge_back)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	header.add_theme_constant_override("separation", 12)
	_style_dev_text(_dev_title, UiSkin.HEADING_SIZE, DEV_TEXT)
	_dev_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_dev_title)
	var close := Button.new()
	_style_dev_button(close, "Hide ✕", DEV_ACCENT)
	close.add_theme_font_size_override("font_size", DEV_NOTE_SIZE + 2)
	close.pressed.connect(_show_dev_panel.bind(false))
	header.add_child(close)
	column.add_child(header)
	_dev_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_dev_text(_dev_note, DEV_NOTE_SIZE, DEV_TEXT.darkened(0.12))
	column.add_child(_dev_note)
	var rule := ColorRect.new()
	rule.color = Color(DEV_ACCENT, 0.4)
	rule.custom_minimum_size.y = 2
	column.add_child(rule)
	_dev_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dev_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dev_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_list.add_theme_constant_override("separation", 6)
	_dev_scroll.add_child(_dev_list)
	column.add_child(_dev_scroll)
	_dev_panel.add_child(column)
	add_child(_dev_panel)

	var preview := Label.new()
	preview.text = PREVIEW_NOTE
	_style_dev_text(preview, DEV_NOTE_SIZE, DEV_TEXT)
	var preview_box := _dev_box(Color(0.07, 0.12, 0.16, 0.85), Color(DEV_ACCENT, 0.6))
	preview_box.content_margin_left = 14
	preview_box.content_margin_right = 14
	preview.add_theme_stylebox_override("normal", preview_box)
	add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	preview.position += Vector2(DEV_PANEL_LEFT, -16)


## Shows the developer tools window, or folds it back into its button.
func _show_dev_panel(open: bool) -> void:
	_dev_panel.visible = open
	_dev_open_button.visible = not open
	if open:
		_show_dev_menu()


## A developer button: text only, in the developer colours, kept out of the game's own button look.
func _style_dev_button(button: Button, text: String, color: Color) -> void:
	button.theme_type_variation = &"TextButton"
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_style_dev_text(button, DEV_FONT_SIZE, color)


## A rounded slate box with a thin mint edge, the developer tools' own look.
func _dev_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(6)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box


func _style_dev_text(control: Control, font_size: int, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, color)
	control.add_theme_color_override("font_outline_color", DEV_OUTLINE)
	control.add_theme_constant_override("outline_size", 4)
	control.add_theme_font_size_override("font_size", font_size)


## The first level: one row for each timeline, and one for the endings.
func _show_dev_menu() -> void:
	_open_dev_list("Developer tools", "Skip straight to any part of the game for testing while it is being made. These shortcuts are not part of the finished game, and nothing played from here is saved.")
	for index in DevJump.GROUPS.size():
		_add_dev_row(str(DevJump.GROUPS[index]["title"]) + "  ›", _show_dev_group.bind(index))
	_add_dev_row("Endings  ›", _show_dev_endings)


## The points of one timeline. A tap opens the point straight away.
func _show_dev_group(index: int) -> void:
	var group: Dictionary = DevJump.GROUPS[index]
	_open_dev_list(str(group["title"]), "Tap a point to start there. Nothing played from here is saved.")
	_add_dev_row("‹  Back", _show_dev_menu)
	for point in group["points"]:
		_add_dev_row(str(point["label"]), DevJump.jump.bind(point))


## Main, then Alternate 1 to 5: one for each way a timeline can end.
func _show_dev_endings() -> void:
	_open_dev_list("Endings", "Tap one to see the screen a timeline ends on.")
	_add_dev_row("‹  Back", _show_dev_menu)
	var endings := TimelineMap.endings()
	for index in endings.size():
		_add_dev_row(TimelineMap.ending_name(index), _show_dev_ending.bind(endings[index]))


func _open_dev_list(title: String, note: String) -> void:
	_dev_title.text = title
	_dev_note.text = note
	_dev_scroll.scroll_vertical = 0
	for child in _dev_list.get_children():
		_dev_list.remove_child(child)
		child.queue_free()


func _add_dev_row(text: String, action: Callable) -> void:
	var row := Button.new()
	_style_dev_button(row, text, DEV_TEXT)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = DEV_ROW_HEIGHT
	row.add_theme_stylebox_override("normal", _dev_box(Color(1, 1, 1, 0.04), Color(DEV_ACCENT, 0.18)))
	row.add_theme_stylebox_override("hover", _dev_box(Color(DEV_ACCENT, 0.14), Color(DEV_ACCENT, 0.5)))
	row.add_theme_stylebox_override("pressed", _dev_box(Color(DEV_ACCENT, 0.24), DEV_ACCENT))
	row.add_theme_color_override("font_pressed_color", DEV_ACCENT)
	row.add_theme_color_override("font_hover_color", DEV_ACCENT)
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.pressed.connect(action)
	_dev_list.add_child(row)


## Development only. Ends an unsaved run as if it had reached this reality, so the timeline's
## closing screen plays exactly as it does in the game.
func _show_dev_ending(reality: Dictionary) -> void:
	GameState.start_unsaved_game()
	GameState.timeline = str(reality.get("timeline", ""))
	GameState.run_outcomes = (reality.get("needs", []) as Array).duplicate()
	StoryDirector.end_run("", "", "")


## Continue picks up the save played most recently.
func _on_continue() -> void:
	var slot := GameState.latest_slot()
	if slot >= 0 and GameState.load_slot(slot):
		_enter_save()


## Goes into the loaded save: back into the story in progress, or, between runs, to the choice of
## where the next run begins.
func _enter_save() -> void:
	if not StoryDirector.resume():
		_show_story_choice()


## Between runs the player chooses which story to begin with.
func _show_story_choice() -> void:
	_open_panel("Where does it begin?")
	for story in StoryDirector.STORY_ORDER:
		_add_row(StoryDirector.story_title(story), true, _ask_story.bind(story))
	_add_row("Back", true, _show_main)
	_back_action = _show_main


func _ask_story(story: String) -> void:
	_open_panel("Begin with %s?" % StoryDirector.story_title(story))
	_add_row("Yes", true, StoryDirector.begin_with.bind(story))
	_add_row("No", true, _show_story_choice)
	_back_action = _show_story_choice


## New Game asks where to save progress. Picking a slot that already has a save asks first.
func _show_new_game_slots() -> void:
	_open_panel("Save progress to which slot?")
	for slot in GameState.SLOT_COUNT:
		_add_row(_describe(slot), true, _pick_new_game_slot.bind(slot))
	_add_row("Back", true, _show_main)
	_back_action = _show_main


func _pick_new_game_slot(slot: int) -> void:
	if GameState.has_slot(slot):
		_open_panel("Overwrite Slot %d?" % (slot + 1))
		_add_row("Yes", true, _start_new_game.bind(slot))
		_add_row("No", true, _show_new_game_slots)
		_back_action = _show_new_game_slots
	else:
		_start_new_game(slot)


## The first run of a save always begins with Tokhang.
func _start_new_game(slot: int) -> void:
	GameState.new_game(slot)
	StoryDirector.begin_with("tokhang")


## The list of saves. In delete mode, picking a save asks to delete it instead of loading it.
func _show_slots(delete_mode: bool) -> void:
	var any_saves := false
	for slot in GameState.SLOT_COUNT:
		any_saves = any_saves or GameState.has_slot(slot)
	if not any_saves:
		_show_message("No saved games yet")
		return
	_open_panel("Delete which save?" if delete_mode else "Load which save?")
	for slot in GameState.SLOT_COUNT:
		var filled := GameState.has_slot(slot)
		_add_row(_describe(slot), filled, _ask.bind(slot, delete_mode))
	if delete_mode:
		_add_row("Back", true, _show_slots.bind(false))
	else:
		_add_row("Delete", true, _show_slots.bind(true))
		_add_row("Back", true, _show_main)
	_back_action = _show_slots.bind(false) if delete_mode else _show_main


## Asks before loading or deleting a save: "Load Slot 1?" with Yes and No.
func _ask(slot: int, delete_mode: bool) -> void:
	_open_panel("%s Slot %d?" % ["Delete" if delete_mode else "Load", slot + 1])
	_add_row("Yes", true, _delete_slot.bind(slot) if delete_mode else _load_slot.bind(slot))
	_add_row("No", true, _show_slots.bind(delete_mode))
	_back_action = _show_slots.bind(delete_mode)


func _load_slot(slot: int) -> void:
	if GameState.load_slot(slot):
		_enter_save()
	else:
		_show_message("That save can’t be loaded")


func _delete_slot(slot: int) -> void:
	GameState.delete_slot(slot)
	_show_slots(true)


func _show_message(text: String) -> void:
	_open_panel(text)
	_add_row("Back", true, _show_main)
	_back_action = _show_main


func _open_panel(prompt: String) -> void:
	_menu.visible = false
	_quit_confirm.visible = false
	_save_panel.visible = true
	for child in _save_panel.get_children():
		_save_panel.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.theme_type_variation = &"MenuPrompt"
	label.text = prompt
	label.custom_minimum_size = ROW_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_panel.add_child(label)


func _add_row(text: String, enabled: bool, action: Callable) -> void:
	var row := Button.new()
	row.theme_type_variation = &"TextButton"
	row.text = text
	row.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not enabled
	row.custom_minimum_size = ROW_SIZE
	row.pressed.connect(action)
	_save_panel.add_child(row)


## "Slot 1 · Kumpisal · Oct 4, 7:23 PM", "Slot 2 · New story · ...", or "Slot 3 · Empty".
func _describe(slot: int) -> String:
	var title := "Slot %d" % (slot + 1)
	var info := GameState.slot_summary(slot)
	if not info["exists"]:
		return "%s · Empty" % title
	var where := "New story"
	if str(info["timeline"]) != "":
		var stories: Array = StoryDirector.TIMELINES.get(info["timeline"], [])
		if int(info["chapter"]) < stories.size():
			where = StoryDirector.story_title(stories[int(info["chapter"])])
	return "%s · %s · %s" % [title, where, _format_time(info["saved_at"])]


## Turns "2026-10-04T19:23:13" into "Oct 4, 7:23 PM", adding the year when it is not this year.
func _format_time(saved_at: String) -> String:
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
