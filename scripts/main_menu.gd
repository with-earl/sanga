extends Control
## Main screen: Continue (when there is a save), New Game and Quit. Continue and New Game open the
## list of saves over everything (see SaveSlots), and opening a save shows its start screen (see
## StartScreen). The Quit question and short messages swap in for the buttons, in the same spot.
## Anything that would lose progress asks first and says so.

const ROW_SIZE := Vector2(300, 52)
## Where the lists sit, in the screen's own terms: their centre line is the logo's (the logo is part
## of the main screen's picture, centred about 258 px from the right edge), and their top is just
## under it (344 px from the top of a 720 px screen).
const MENU_CENTER_FROM_RIGHT := -258.0
const MENU_TOP_FROM_BOTTOM := -376.0
## The least room kept between a list and the screen's right and bottom edges.
const MENU_EDGE_MARGIN := Vector2(40.0, 24.0)

@onready var _menu: Control = $Buttons
@onready var _quit_confirm: Control = %QuitConfirm
@onready var _save_panel: VBoxContainer = %SavePanel
@onready var _continue_button: Button = %ContinueButton
@onready var _new_button: Button = %NewButton
@onready var _quit_button: Button = %QuitButton
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton
## The gear at the top left, opening the sound, music and vibration settings.
@onready var _settings: GameMenu = $Settings

## What the Android back button does while the save panel is showing.
var _back_action := Callable()
## A save's start screen, and the list of saves, while they are open.
var _start_screen: StartScreen
var _slots: SaveSlots


func _ready() -> void:
	_continue_button.visible = GameState.latest_slot() >= 0
	_continue_button.pressed.connect(_open_slots.bind(SaveSlots.Mode.LOAD))
	_new_button.pressed.connect(_open_slots.bind(SaveSlots.Mode.NEW))
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
	elif _start_screen != null:
		_start_screen.back()
	elif _slots != null:
		_slots.back()
	elif _save_panel.visible:
		_back_action.call()
	else:
		_show_quit_confirm(not _quit_confirm.visible)


## Sets up one of the right-hand lists as plain words, with no box behind them: every line is
## centred, and the list is kept centred on the logo's axis, just under the logo, whatever its
## width and however many lines it has. The words stay readable on the busy picture through their
## thick dark outline and soft shadow (see the theme).
func _put_on_window(panel: VBoxContainer) -> void:
	for child in panel.get_children():
		if child is Button:
			(child as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif child is Label:
			(child as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hug := func() -> void:
		var size := panel.get_combined_minimum_size()
		# A wide list (a long save line) slides left, and a tall one up, to stay on the screen.
		var centre := minf(MENU_CENTER_FROM_RIGHT, -MENU_EDGE_MARGIN.x - size.x / 2.0)
		var top := minf(MENU_TOP_FROM_BOTTOM, -MENU_EDGE_MARGIN.y - size.y)
		panel.offset_left = centre - size.x / 2.0
		panel.offset_right = centre + size.x / 2.0
		panel.offset_top = top
		panel.offset_bottom = top + size.y
	panel.minimum_size_changed.connect(hug)
	hug.call()


## The question takes the place of the three menu buttons, in the same spot.
func _show_quit_confirm(asking: bool) -> void:
	_quit_confirm.visible = asking
	_menu.visible = not asking


## Continue and New Game both open the list of saves (see SaveSlots). Continue's list opens the
## slot that is chosen; New Game's starts a new game in it.
func _open_slots(mode: SaveSlots.Mode) -> void:
	_slots = SaveSlots.new()
	add_child(_slots)
	_slots.open(mode)
	_slots.picked.connect(_slot_picked.bind(mode))
	_slots.closed.connect(_slots_closed)


func _slot_picked(slot: int, mode: SaveSlots.Mode) -> void:
	if mode == SaveSlots.Mode.LOAD:
		_open_save(slot)
	else:
		# The first run of a save always begins at the market.
		GameState.new_game(slot)
		StoryDirector.begin_with("tokhang")


func _slots_closed() -> void:
	_slots = null
	_continue_button.visible = GameState.latest_slot() >= 0


func _show_main() -> void:
	_save_panel.visible = false
	_quit_confirm.visible = false
	_menu.visible = true


## Opening a save shows its start screen (see StartScreen): continue the run in progress, or begin
## a new run at one of the three stories. The save list stays underneath, to come back to.
func _open_save(slot: int) -> void:
	if not GameState.load_slot(slot):
		_show_message("That save can’t be opened")
		return
	_start_screen = StartScreen.new()
	add_child(_start_screen)
	_start_screen.open(slot, SaveSlots.describe(slot))
	_start_screen.closed.connect(func() -> void: _start_screen = null)


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
	# Centred, like the main buttons, so every list on its window reads the same way.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_panel.add_child(label)


func _add_row(text: String, enabled: bool, action: Callable) -> void:
	var row := Button.new()
	row.theme_type_variation = &"TextButton"
	row.text = text
	row.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not enabled
	row.custom_minimum_size = ROW_SIZE
	row.pressed.connect(action)
	_save_panel.add_child(row)


