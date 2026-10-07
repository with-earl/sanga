class_name GameMenu
extends CanvasLayer
## The in-game menu: the gear at the top left, then the developer tools' terminal icon while the
## game is being made, then the place name. In a place, the top right holds two more icons in the
## same style: the book opens the memories (Alaala), the clipboard opens the objectives. The gear opens a modal with
## on and off switches for sound, music and vibration, and a way back to the main menu. Tapping
## outside the modal closes it.
## The modal looks like the dialogue box: the same black box with a gray and silver border,
## golden ochre text with a brown outline, and buttons styled like the dialogue choices.

const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const PANEL_PADDING := 34.0
## The place name fades in this long after a place opens, over this many seconds.
const TITLE_FADE_DELAY := 0.35
const TITLE_FADE_SECONDS := 0.9
## Room between the place name and the edge of its plate.
const TITLE_PLATE_MARGIN := Vector2(18.0, 5.0)
## The developer tools icon sits right after the gear, the same size and style.
const TERMINAL_PICTURE := preload("res://assets/ui/terminal.png")
const ICON_SIZE := 80.0
## Room between the last icon and the place name's plate.
const TITLE_GAP := 22.0
## The terminal is a little wider than it is tall, so it is drawn a touch larger than the gear to
## look the same size.
const TERMINAL_PICTURE_SIZE := 72.0
## The icons at the top right of a place, mirroring the gear's distance from the edge.
const BOOK_PICTURE := preload("res://assets/ui/book.png")
const CLIPBOARD_PICTURE := preload("res://assets/ui/clipboard.png")
## Drawn so each covers about as much of the screen as the gear (64): the book is wide and short,
## the clipboard tall and solid, so they get slightly different sizes to look the same.
const BOOK_PICTURE_SIZE := 66.0
const CLIPBOARD_PICTURE_SIZE := 58.0
const EDGE_MARGIN := Vector2(12.0, 4.0)
## When the objectives change, the clipboard swells for a moment, so the player knows to look.
const NUDGE_SCALE := 1.18
const NUDGE_SECONDS := 0.35

## On the main screen the gear opens only the settings: no way back to the main menu, no story
## skip, and no place name.
@export var main_screen := false

@onready var _modal: Control = %Modal
@onready var _dim: ColorRect = %Dim
@onready var _main_view: Control = %MainView
@onready var _confirm_view: Control = %ConfirmView
@onready var _menu_icon: Button = %MenuIcon
@onready var _close_button: IconButton = %CloseButton
@onready var _sound_toggle: ToggleSwitch = %SoundToggle
@onready var _music_toggle: ToggleSwitch = %MusicToggle
@onready var _vibration_toggle: ToggleSwitch = %VibrationToggle
@onready var _main_menu_button: Button = %MainMenuButton
## Development only: finishes the current story, for testing the story order before every story
## is built. Only shown in debug builds.
@onready var _dev_skip_button: Button = %DevSkipButton
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton
@onready var _panel: PanelContainer = $Modal/Center/Panel
@onready var _location_title: Label = %LocationTitle

var _tween: Tween
var _panel_style := StyleBoxEmpty.new()
var _dev_tools: DevTools
var _journal: JournalModal
var _right_icons := HBoxContainer.new()
var _clipboard_icon: IconButton
## The objectives this place shows, kept up to date by the place (see set_objectives).
var _objectives := PackedStringArray()
var _struck_count := 0
var _terminal_icon: IconButton


func _ready() -> void:
	_apply_dialog_look()
	_modal.visible = false
	_menu_icon.pressed.connect(open)
	_close_button.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)
	_sound_toggle.toggled.connect(_switch_volume.bind(Settings.set_sound_volume))
	_music_toggle.toggled.connect(_switch_volume.bind(Settings.set_music_volume))
	$Modal/Center/Panel/MainView/VibrationRow.visible = Settings.can_vibrate()
	_vibration_toggle.toggled.connect(func(on: bool) -> void:
		Settings.set_vibration(on)
		Settings.vibrate(Settings.HAPTIC_MEDIUM))
	_main_menu_button.pressed.connect(_show_confirm.bind(true))
	_dev_skip_button.visible = OS.is_debug_build()
	_dev_skip_button.pressed.connect(func() -> void:
		close()
		StoryDirector.finish_story())
	_no_button.pressed.connect(_show_confirm.bind(false))
	_yes_button.pressed.connect(SceneRouter.go_to.bind("main_menu"))
	if main_screen:
		$Modal/Center/Panel/MainView/Header/Title.text = "Settings"
		$Modal/Center/Panel/MainView/Gap.visible = false
		_main_menu_button.visible = false
		_dev_skip_button.visible = false
		_location_title.visible = false
	if DevTools.enabled():
		_add_dev_tools()
	if not main_screen:
		_add_journal()


## The book and the clipboard at the top right, and the window they open.
func _add_journal() -> void:
	_right_icons.name = "RightIcons"
	_right_icons.add_theme_constant_override("separation", 0)
	_right_icons.add_child(_make_icon("BookIcon", BOOK_PICTURE, BOOK_PICTURE_SIZE, _open_memories))
	_clipboard_icon = _make_icon("ClipboardIcon", CLIPBOARD_PICTURE, CLIPBOARD_PICTURE_SIZE, _open_objectives)
	_right_icons.add_child(_clipboard_icon)
	add_child(_right_icons)
	_right_icons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_right_icons.position += Vector2(-EDGE_MARGIN.x, EDGE_MARGIN.y)
	_journal = JournalModal.new()
	_journal.name = "Journal"
	add_child(_journal)


func _make_icon(icon_name: String, picture: Texture2D, picture_size: float, action: Callable) -> IconButton:
	var icon := IconButton.new()
	icon.name = icon_name
	icon.theme_type_variation = &"TextButton"
	icon.focus_mode = Control.FOCUS_NONE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.plain = true
	icon.picture = picture
	icon.picture_size = picture_size
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.pivot_offset = Vector2(ICON_SIZE, ICON_SIZE) / 2.0
	icon.pressed.connect(action)
	return icon


## The place's objectives, for the clipboard window. With `animate` (an objective was just done
## or a new one appeared), the clipboard swells for a moment.
func set_objectives(lines: PackedStringArray, struck_count: int, animate: bool) -> void:
	_objectives = lines
	_struck_count = struck_count
	if animate and _clipboard_icon != null and not lines.is_empty():
		var nudge := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		nudge.tween_property(_clipboard_icon, "scale", Vector2.ONE * NUDGE_SCALE, NUDGE_SECONDS)
		nudge.tween_property(_clipboard_icon, "scale", Vector2.ONE, NUDGE_SECONDS)


## The icons that hide while a dialogue is open: the gear (with the terminal and place name on it)
## and the icons at the top right.
func get_hud_icons() -> Array[Control]:
	var icons: Array[Control] = [_menu_icon]
	if _right_icons.get_parent() != null:
		icons.append(_right_icons)
	return icons


func _open_memories() -> void:
	if _hud_out_of_reach():
		return
	close()
	_journal.open_memories()


func _open_objectives() -> void:
	if _hud_out_of_reach():
		return
	close()
	_journal.open_objectives(_objectives, _struck_count)


## True while the place has put the icons away, for example during a dialogue.
func _hud_out_of_reach() -> bool:
	return _menu_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE or _menu_icon.modulate.a < 0.5


## The terminal icon beside the gear, and the developer tools window it opens.
func _add_dev_tools() -> void:
	_terminal_icon = IconButton.new()
	_terminal_icon.name = "DevToolsIcon"
	_terminal_icon.theme_type_variation = &"TextButton"
	_terminal_icon.focus_mode = Control.FOCUS_NONE
	_terminal_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_terminal_icon.plain = true
	_terminal_icon.picture = TERMINAL_PICTURE
	_terminal_icon.picture_size = TERMINAL_PICTURE_SIZE
	_terminal_icon.position = Vector2(ICON_SIZE, 0.0)
	_terminal_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_terminal_icon.pressed.connect(_open_dev_tools)
	# A child of the gear, so it moves, fades and hides with it during dialogues.
	_menu_icon.add_child(_terminal_icon)
	_location_title.position.x = ICON_SIZE * 2.0 + TITLE_GAP
	_dev_tools = DevTools.new()
	_dev_tools.name = "DevTools"
	add_child(_dev_tools)


## Opens the developer tools, unless the place has put the icons out of reach (during a dialogue,
## for example, where the gear stops taking taps).
func _open_dev_tools() -> void:
	if _hud_out_of_reach():
		return
	close()
	_dev_tools.open()


func _apply_dialog_look() -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel_style.set_content_margin(side, PANEL_PADDING)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	# The same soft 90s window as the dialogue box.
	SoftWindow.behind(_panel)
	# The switches get the soft retro look too, keeping their exact opacity.
	var retro := ShaderMaterial.new()
	retro.shader = DialogueBox.RETRO_TEXT_SHADER
	retro.set_shader_parameter("alpha_boost", 1.0)
	for toggle in [_sound_toggle, _music_toggle, _vibration_toggle]:
		toggle.material = retro
	var headings := [$Modal/Center/Panel/MainView/Header/Title, $Modal/Center/Panel/ConfirmView/Question]
	for node in _modal.find_children("*", "Label", true, false):
		var label := node as Label
		UiSkin.style_label(label, UiSkin.HEADING_SIZE if label in headings else UiSkin.TEXT_SIZE)
	for button in [_main_menu_button, _dev_skip_button, _yes_button, _no_button]:
		UiSkin.style_button(button)
	# The place name sits on a small warm plate beside the menu icon.
	SoftWindow.behind(_location_title, SoftWindow.Look.PLATE, TITLE_PLATE_MARGIN)
	# The close button: a plain golden ochre cross with a brown outline, like the text.
	UiSkin.style_icon(_close_button)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


## Shows the place name beside the menu icon. It fades in gently each time a place opens, like a
## location caption in an anime episode.
func set_location_title(text: String) -> void:
	_location_title.text = text
	# The plate behind it hugs the words.
	_location_title.reset_size()
	_location_title.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) \
		.tween_property(_location_title, "modulate:a", 1.0, TITLE_FADE_SECONDS).set_delay(TITLE_FADE_DELAY)


## The gear icon, so a scene can hide it while a dialogue is open.
func get_icon() -> Button:
	return _menu_icon


func is_open() -> bool:
	return _modal.visible or (_dev_tools != null and _dev_tools.is_open()) or (_journal != null and _journal.is_open())


func open() -> void:
	_sync_from_settings()
	_show_confirm(false)
	_modal.visible = true
	_fade(1.0, OPEN_SECONDS)


func close() -> void:
	if _dev_tools != null:
		_dev_tools.close()
	if _journal != null:
		_journal.close()
	if not _modal.visible:
		return
	await _fade(0.0, CLOSE_SECONDS)
	_modal.visible = false


## Taps on the dimmed area outside the panel close the menu.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


## Progress is saved after every objective, so the question needs no reminder about saving.
func _show_confirm(asking: bool) -> void:
	_confirm_view.visible = asking
	_main_view.visible = not asking


func _sync_from_settings() -> void:
	_sound_toggle.set_on_quietly(Settings.sound_volume > 0.0)
	_music_toggle.set_on_quietly(Settings.music_volume > 0.0)
	_vibration_toggle.set_on_quietly(Settings.vibration)


## Sound and music are simply on or off: on plays at the default volume, off is silent.
func _switch_volume(on: bool, set_volume: Callable) -> void:
	set_volume.call(Settings.DEFAULT_VOLUME if on else 0.0)
	Settings.save()
	Settings.vibrate(Settings.HAPTIC_LIGHT)


func _fade(alpha: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_modal, "modulate:a", alpha, seconds)
	await _tween.finished
