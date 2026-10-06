class_name GameMenu
extends CanvasLayer
## The in-game menu: the gear at the top left, with the place name beside it, opens a modal with
## the sound and music volumes (in quarter steps), a vibration switch, and a way back to the main
## menu. Tapping outside the modal closes it.
## The modal looks like the dialogue box: the same black box with a gray and silver border,
## white text with a black outline, and buttons styled like the dialogue choices.

const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const PANEL_PADDING := 24.0
## Disabled stepper buttons (at 0% or 100%) fade back.
const DISABLED_ALPHA := 0.35

## On the main screen the gear opens only the settings: no way back to the main menu, no story
## skip, and no place name.
@export var main_screen := false

@onready var _modal: Control = %Modal
@onready var _dim: ColorRect = %Dim
@onready var _main_view: Control = %MainView
@onready var _confirm_view: Control = %ConfirmView
@onready var _menu_icon: Button = %MenuIcon
@onready var _close_button: IconButton = %CloseButton
@onready var _sound_down: IconButton = %SoundDown
@onready var _sound_up: IconButton = %SoundUp
@onready var _sound_value: Label = %SoundValue
@onready var _music_down: IconButton = %MusicDown
@onready var _music_up: IconButton = %MusicUp
@onready var _music_value: Label = %MusicValue
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
var _panel_style := StyleBoxTexture.new()
var _panel_size := Vector2i.ZERO


func _ready() -> void:
	_apply_dialog_look()
	_modal.visible = false
	_menu_icon.pressed.connect(open)
	_close_button.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)
	_sound_down.pressed.connect(_step_sound.bind(-1))
	_sound_up.pressed.connect(_step_sound.bind(1))
	_music_down.pressed.connect(_step_music.bind(-1))
	_music_up.pressed.connect(_step_music.bind(1))
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


func _apply_dialog_look() -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel_style.set_content_margin(side, PANEL_PADDING)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The same soft retro look as the dialogue box, keeping its exact opacity.
	var retro := ShaderMaterial.new()
	retro.shader = DialogueBox.RETRO_TEXT_SHADER
	retro.set_shader_parameter("alpha_boost", 1.0)
	_panel.material = retro
	_vibration_toggle.material = retro
	_panel.resized.connect(_redraw_panel)
	var headings := [$Modal/Center/Panel/MainView/Header/Title, $Modal/Center/Panel/ConfirmView/Question]
	for node in _modal.find_children("*", "Label", true, false):
		var label := node as Label
		UiSkin.style_label(label, UiSkin.HEADING_SIZE if label in headings else UiSkin.TEXT_SIZE)
	for button in [_main_menu_button, _dev_skip_button, _yes_button, _no_button]:
		UiSkin.style_button(button)
	for stepper in [_sound_down, _sound_up, _music_down, _music_up]:
		UiSkin.style_icon(stepper)
		UiSkin.box_only(stepper)
	# The close button: a plain white cross with a black outline, like the text.
	UiSkin.style_icon(_close_button)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


## Redraws the box background whenever the panel changes size, for example between the menu and
## the question.
func _redraw_panel() -> void:
	var wanted := Vector2i(_panel.size.round())
	if wanted == _panel_size or wanted.x <= 0 or wanted.y <= 0:
		return
	_panel_size = wanted
	_panel_style.texture = DialogueBox.box_texture(wanted)


## Shows where the player is, beside the gear, for example "Church Nave".
func set_location_title(text: String) -> void:
	_location_title.text = text


## The gear icon, so a scene can hide it while a dialogue is open.
func get_icon() -> Button:
	return _menu_icon


func is_open() -> bool:
	return _modal.visible


func open() -> void:
	_sync_from_settings()
	_show_confirm(false)
	_modal.visible = true
	_fade(1.0, OPEN_SECONDS)


func close() -> void:
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
	_show_volume(Settings.sound_volume, _sound_value, _sound_down, _sound_up)
	_show_volume(Settings.music_volume, _music_value, _music_down, _music_up)
	_vibration_toggle.set_on_quietly(Settings.vibration)


func _step_sound(direction: int) -> void:
	Settings.set_sound_volume(Settings.sound_volume + direction * Settings.VOLUME_STEP)
	Settings.save()
	Settings.vibrate(Settings.HAPTIC_LIGHT)
	_show_volume(Settings.sound_volume, _sound_value, _sound_down, _sound_up)


func _step_music(direction: int) -> void:
	Settings.set_music_volume(Settings.music_volume + direction * Settings.VOLUME_STEP)
	Settings.save()
	Settings.vibrate(Settings.HAPTIC_LIGHT)
	_show_volume(Settings.music_volume, _music_value, _music_down, _music_up)


## Shows a volume as a percentage, with the minus or plus faded out at either end.
func _show_volume(value: float, label: Label, down: Button, up: Button) -> void:
	label.text = "%d%%" % roundi(value * 100.0)
	down.disabled = value <= 0.0
	up.disabled = value >= 1.0
	down.modulate.a = DISABLED_ALPHA if down.disabled else 1.0
	up.modulate.a = DISABLED_ALPHA if up.disabled else 1.0


func _fade(alpha: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_modal, "modulate:a", alpha, seconds)
	await _tween.finished
