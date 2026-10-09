extends Control
## Main screen: Story Mode, Shift Mode and Quit. Each mode has its own three save slots, listed over
## everything when the mode is chosen (see SaveSlots): an empty slot starts a new game, a save is
## opened. Story Mode is the one fixed run, from the market. Shift Mode, which stays locked until
## Story Mode has been finished, opens a save's start screen (see StartScreen) to begin a run at any
## of the three stories. The Quit question and short messages swap in for the buttons, in the same
## spot. Anything that would lose progress asks first and says so.

const ROW_SIZE := Vector2(300, 52)
## The padlock shown before "Shift Mode" while it is locked.
const LOCK_ICON := "res://assets/ui/lock.png"
## What tapping the locked Shift Mode says, as a note at the bottom centre that fades by itself.
const UNLOCK_NOTE := "Finish Story Mode to unlock Shift Mode"
const TOAST_FADE_IN := 0.2
const TOAST_HOLD := 2.2
const TOAST_FADE_OUT := 0.5
## Room kept between the toast and the bottom edge of the screen.
const TOAST_BOTTOM_GAP := 44.0
## Where the lists sit, in the screen's own terms: their centre line is the logo's (the logo is part
## of the main screen's picture, centred about 258 px from the right edge), and their top is just
## under it (344 px from the top of a 720 px screen).
const MENU_CENTER_FROM_RIGHT := -258.0
const MENU_TOP_FROM_BOTTOM := -296.0
## The least room kept between a list and the screen's right and bottom edges.
const MENU_EDGE_MARGIN := Vector2(40.0, 24.0)

@onready var _menu: Control = $Buttons
@onready var _quit_confirm: Control = %QuitConfirm
@onready var _save_panel: VBoxContainer = %SavePanel
@onready var _story_button: Button = %StoryButton
@onready var _shift_button: Button = %ShiftButton
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
## The bottom-centre note and its fade (see _toast).
var _toast_label: Control
var _toast_tween: Tween


func _ready() -> void:
	_story_button.pressed.connect(_open_slots.bind(GameState.MODE_STORY))
	_shift_button.pressed.connect(_shift_pressed)
	_refresh_shift_lock()
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


## Shift Mode shows a lock icon before its name, dimmed, until Story Mode has been finished; tapping
## it then says what to do.
func _refresh_shift_lock() -> void:
	var open := GameState.story_finished()
	_shift_button.text = "Shift Mode"
	_shift_button.modulate.a = 1.0
	var old := _shift_button.get_node_or_null("Lock")
	if old != null:
		old.queue_free()
	if open:
		return
	# The padlock sits just before the centred words, so the whole line stays centred on the logo's axis.
	var icon := TextureRect.new()
	icon.name = "Lock"
	icon.texture = load(LOCK_ICON) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(34, 34)
	var font := _shift_button.get_theme_font("font", "Button")
	var font_size := _shift_button.get_theme_font_size("font_size", "Button")
	var text_width := font.get_string_size(_shift_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	icon.position = Vector2((ROW_SIZE.x - text_width) / 2.0 - icon.size.x - 14.0, (ROW_SIZE.y - icon.size.y) / 2.0)
	_shift_button.add_child(icon)


func _shift_pressed() -> void:
	if GameState.story_finished():
		_open_slots(GameState.MODE_SHIFT)
	else:
		_toast(UNLOCK_NOTE)


## A short note at the bottom centre of the screen, on a small rounded plate with a padlock: it rises
## and fades in, stays a moment and fades out by itself.
func _toast(words: String) -> void:
	if _toast_label != null:
		_toast_label.queue_free()
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.05, 0.065, 0.9)
	style.set_corner_radius_all(18)
	style.set_border_width_all(2)
	style.border_color = Color(0.851, 0.643, 0.255, 0.9)
	style.content_margin_left = 22
	style.content_margin_right = 26
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.anti_aliasing = true
	plate.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(LOCK_ICON) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = words
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", UiSkin.BUTTON_TEXT)
	label.add_theme_color_override("font_outline_color", UiSkin.BUTTON_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	plate.modulate.a = 0.0
	add_child(plate)
	_toast_label = plate
	# Centred along the bottom, a little above the edge.
	plate.reset_size()
	var rest := Vector2((ScreenFit.DESIGN_SIZE.x - plate.size.x) / 2.0, ScreenFit.DESIGN_SIZE.y - plate.size.y - TOAST_BOTTOM_GAP)
	plate.position = rest + Vector2(0, 14)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(plate, "modulate:a", 1.0, TOAST_FADE_IN)
	_toast_tween.tween_property(plate, "position", rest, TOAST_FADE_IN)
	_toast_tween.chain().tween_interval(TOAST_HOLD)
	_toast_tween.chain().tween_property(plate, "modulate:a", 0.0, TOAST_FADE_OUT)


## The question takes the place of the three menu buttons, in the same spot.
func _show_quit_confirm(asking: bool) -> void:
	_quit_confirm.visible = asking
	_menu.visible = not asking


## A mode was chosen: list that mode's three save slots (see SaveSlots). Tapping an empty slot starts
## a new game in it; a save opens.
func _open_slots(game_mode: String) -> void:
	GameState.mode = game_mode
	# The list covers the screen, so the main words step aside rather than show through it.
	_menu.visible = false
	_slots = SaveSlots.new()
	add_child(_slots)
	_slots.open()
	_slots.picked.connect(_slot_picked)
	_slots.closed.connect(_slots_closed)


func _slot_picked(slot: int) -> void:
	if GameState.has_slot(slot):
		_open_save(slot)
		return
	GameState.new_game(slot)
	if GameState.mode == GameState.MODE_STORY:
		# The story always begins at the market.
		StoryDirector.begin_with("tokhang")
	else:
		_show_start_screen(slot)


func _slots_closed() -> void:
	_slots = null
	_menu.visible = true
	_refresh_shift_lock()


func _show_main() -> void:
	_save_panel.visible = false
	_quit_confirm.visible = false
	_menu.visible = true


## Opening a save. In Story Mode the run in progress carries on, or the finished story says so. In
## Shift Mode the save's start screen opens (see StartScreen): continue the run in progress, or begin
## a new run at one of the three stories. The save list stays underneath, to come back to.
func _open_save(slot: int) -> void:
	if not GameState.load_slot(slot):
		_close_slots()
		_show_message("That save can’t be opened")
		return
	if GameState.mode == GameState.MODE_SHIFT:
		_show_start_screen(slot)
	elif GameState.is_run_in_progress():
		StoryDirector.resume()
	elif GameState.runs_finished > 0:
		_close_slots()
		_refresh_shift_lock()
		_show_message("Story complete. Shift Mode is open.")
	else:
		StoryDirector.begin_with("tokhang")


func _show_start_screen(slot: int) -> void:
	_start_screen = StartScreen.new()
	add_child(_start_screen)
	_start_screen.open(slot, SaveSlots.describe(slot))
	_start_screen.closed.connect(func() -> void: _start_screen = null)


## Takes the save list away, for a message that has to show on the main screen itself.
func _close_slots() -> void:
	if _slots != null:
		_slots.queue_free()
		_slots = null


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


