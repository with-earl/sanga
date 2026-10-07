extends Control
## Main screen. Quit, loading a save, and deleting a save all happen in place: the three menu
## buttons are swapped for a short list or a question with Yes and No, in the same spot.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const ROW_SIZE := Vector2(300, 52)
## The main buttons, the save list and the quit question each sit on a soft window, hugging their
## contents above the bottom right corner.
const MENU_WINDOW_MARGIN := Vector2(40.0, 26.0)

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
