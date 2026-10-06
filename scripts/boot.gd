extends Control
## Startup screen. Shows the still image while every asset loads, naming the stage in progress,
## then opens the main screen. The first time the game is opened on a device, a content warning
## comes first and waits for the player to continue.
##
## In the web build, "Tap to start" comes after loading. Browsers, iPhone Safari above all, keep a
## page silent until the player touches it, so this first tap is what lets the music be heard.

const WARNING_TITLE := "Content Warning"
## Kept general on purpose: it names the kinds of content, not who does what, so it gives nothing
## of the story away.
const WARNING_TEXT := "SANGA is a work of fiction. It contains violence, death, abuse, and other mature themes.\n\nSome scenes may be distressing. Please play with care."
const WARNING_FADE_SECONDS := 0.4
const WARNING_WIDTH := 760.0
const WARNING_TITLE_COLOR := Color(0.98, 0.93, 0.86)
const WARNING_TEXT_COLOR := Color(0.86, 0.84, 0.8)
const TAP_TO_START_TEXT := "Tap to start"

@onready var _status: Label = %StatusLabel

var _started := false


func _ready() -> void:
	AssetPreloader.start()
	_status.text = AssetPreloader.current_label


func _process(delta: float) -> void:
	if AssetPreloader.poll(delta):
		set_process(false)
		if OS.has_feature("web"):
			_wait_for_first_tap()
		else:
			_continue()
		return
	_status.text = AssetPreloader.current_label


func _continue() -> void:
	if Settings.content_warning_seen:
		SceneRouter.go_to("main_menu")
	else:
		_show_content_warning()


## Web only. Waits for a tap anywhere, which also unlocks the browser's audio.
func _wait_for_first_tap() -> void:
	_status.text = TAP_TO_START_TEXT
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(catcher)
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		var tapped := (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
		if tapped and not _started:
			_started = true
			catcher.queue_free()
			Sfx.click()
			_continue())


func _show_content_warning() -> void:
	_status.hide()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.modulate.a = 0.0
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(WARNING_WIDTH, 0)
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"Headline"
	title.text = WARNING_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", WARNING_TITLE_COLOR)
	column.add_child(title)
	var body := Label.new()
	body.theme_type_variation = &"Body"
	body.text = WARNING_TEXT
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", WARNING_TEXT_COLOR)
	column.add_child(body)
	var button := Button.new()
	button.text = "Continue"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(300, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(button)
	create_tween().tween_property(shade, "modulate:a", 1.0, WARNING_FADE_SECONDS)
	button.pressed.connect(func() -> void:
		button.disabled = true
		Settings.content_warning_seen = true
		Settings.save()
		SceneRouter.go_to("main_menu"), CONNECT_ONE_SHOT)
