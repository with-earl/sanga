extends Control
## Main screen. Quit, loading a save, and deleting a save all happen in place: the three menu
## buttons are swapped for a short list or a question with Yes and No, in the same spot.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const ROW_SIZE := Vector2(300, 52)
## Development only: the menu on the left, for quick testing without a save slot. "Stories" starts
## a story's timeline; "Endings" shows the screen a timeline ends on (Main, Alternate 1, ...). It
## only appears in debug builds.

@onready var _menu: Control = $Buttons
@onready var _quit_confirm: Control = %QuitConfirm
@onready var _save_panel: VBoxContainer = %SavePanel
@onready var _dev_stories: Control = %DevStories
@onready var _dev_confirm: Control = %DevConfirm
@onready var _dev_question: Label = %DevQuestion
@onready var _dev_yes: Button = %DevYes
@onready var _dev_no: Button = %DevNo
@onready var _continue_button: Button = %ContinueButton
@onready var _new_button: Button = %NewButton
@onready var _load_button: Button = %LoadButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton
## The gear at the top left, opening the sound, music and vibration settings.
@onready var _settings: GameMenu = $Settings

## What the Android back button does while the save panel is showing.
var _back_action := Callable()
## What Yes does in the development question on the left, and what No goes back to.
var _dev_yes_action := Callable()
var _dev_no_action := Callable()


func _ready() -> void:
	_continue_button.visible = GameState.latest_slot() >= 0
	_continue_button.pressed.connect(_on_continue)
	_new_button.pressed.connect(_show_new_game_slots)
	_load_button.pressed.connect(_show_slots.bind(false))
	_settings_button.pressed.connect(_settings.open)
	_quit_button.pressed.connect(_show_quit_confirm.bind(true))
	# A web page cannot close itself, so the browser build has no Quit.
	_quit_button.visible = not OS.has_feature("web")
	_yes_button.pressed.connect(get_tree().quit)
	_no_button.pressed.connect(_show_quit_confirm.bind(false))
	_dev_stories.visible = OS.is_debug_build()
	_show_dev_menu()
	_dev_yes.pressed.connect(func() -> void: _dev_yes_action.call())
	_dev_no.pressed.connect(func() -> void: _dev_no_action.call())


## Android back button steps back one level. From the main buttons it asks before leaving.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _settings.is_open():
		_settings.close()
	elif _dev_confirm.visible:
		_dev_no_action.call()
	elif _save_panel.visible:
		_back_action.call()
	else:
		_show_quit_confirm(not _quit_confirm.visible)


## The question takes the place of the three menu buttons, in the same spot.
func _show_quit_confirm(asking: bool) -> void:
	_quit_confirm.visible = asking
	_menu.visible = not asking


func _show_main() -> void:
	_save_panel.visible = false
	_quit_confirm.visible = false
	_menu.visible = true


## Development only. The two choices on the left: Stories and Endings.
func _show_dev_menu() -> void:
	_open_dev_list()
	_add_dev_row("Stories", _show_dev_stories)
	_add_dev_row("Endings", _show_dev_endings)


func _show_dev_stories() -> void:
	_open_dev_list()
	for story in StoryDirector.STORY_ORDER:
		var title := StoryDirector.story_title(story)
		_add_dev_row(title, _ask_dev("Start with %s?" % title, _start_dev_story.bind(story), _show_dev_stories))
	_add_dev_row("Back", _show_dev_menu)


## Main, then Alternate 1 to 5: one for each way a timeline can end.
func _show_dev_endings() -> void:
	_open_dev_list()
	var endings := TimelineMap.endings()
	for index in endings.size():
		var ending_name := TimelineMap.ending_name(index)
		_add_dev_row(ending_name, _ask_dev("Show the %s ending?" % ending_name, _show_dev_ending.bind(endings[index]), _show_dev_endings))
	_add_dev_row("Back", _show_dev_menu)


func _open_dev_list() -> void:
	_dev_confirm.visible = false
	_dev_stories.visible = OS.is_debug_build()
	for child in _dev_stories.get_children():
		_dev_stories.remove_child(child)
		child.queue_free()


func _add_dev_row(text: String, action: Callable) -> void:
	var row := Button.new()
	row.theme_type_variation = &"TextButton"
	row.text = text
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = ROW_SIZE
	row.pressed.connect(action)
	_dev_stories.add_child(row)


## A question in place of the list, on the left. Yes does `yes`; No goes back with `no`.
func _ask_dev(question: String, yes: Callable, no: Callable) -> Callable:
	return func() -> void:
		_dev_question.text = question
		_dev_yes_action = yes
		_dev_no_action = no
		_dev_stories.visible = false
		_dev_confirm.visible = true


## Development only. Starts unsaved so test runs never fill the save slots.
func _start_dev_story(story: String) -> void:
	_show_dev_menu()
	GameState.start_unsaved_game()
	StoryDirector.begin_with(story)


## Development only. Ends an unsaved run as if it had reached this reality, so the timeline's
## closing screen plays exactly as it does in the game.
func _show_dev_ending(reality: Dictionary) -> void:
	_show_dev_menu()
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
