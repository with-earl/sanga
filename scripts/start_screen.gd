class_name StartScreen
extends Control
## The screen a save opens on. A Story Mode save shows only the Continue card, centred. A Shift Mode
## save shows carry on, or begin a new run somewhere else:
##
## On the left, one card to continue the run in progress. A thin line divides it from the three
## story cards on the right, under "Select your starting point": Tokhang, Kumpisal and Padala, each
## with its place and who the player is there. The cards are upright, 3:4,
## like the covers of three small books.
##
## The first run of a save always begins at the market, so until it is finished the other two
## stories stay closed, and say when they open. Beginning a new run while one is in progress asks
## first, because that run's progress is lost.

## Emitted when the player goes back to the main screen.
signal closed

## The size of every card (3:4), the room between the story cards, and the room on each side of
## the line between Continue and the stories.
const CARD_SIZE := Vector2(216, 288)
const CARD_GAP := 22.0
const DIVIDER_SPACE := 36.0
const CARD_RADIUS := 14
## Where the cards' top edge sits, and the heading above them.
const CARDS_TOP := 236.0
const HEADING_GAP := 46.0
const DIM := Color(0.035, 0.02, 0.03, 0.94)
const LINE := Color(1.0, 0.953, 0.839, 0.32)
const BORDER := Color(1.0, 0.953, 0.839, 0.7)
const SHADE := Color(0.05, 0.025, 0.035, 0.92)
const CLOSED_SHADE := Color(0.03, 0.02, 0.03, 0.8)
const TITLE_SIZE := 34
const SMALL_SIZE := 17
const HEADING_SIZE := 24
const FADE_SECONDS := 0.25
## Each story's card: the picture on it, and who the player is and where. No time is shown.
const STORIES := [
	{"story": "tokhang", "image": "res://assets/backgrounds/public_market.png",
		"who": "Peter · ang palengke"},
	{"story": "kumpisal", "image": "res://assets/backgrounds/church_nave.png",
		"who": "Eli · ang simbahan"},
	{"story": "padala", "image": "res://assets/backgrounds/apartment_room.png",
		"who": "Mercy · ang kwarto"},
]
const CONTINUE_TITLE := "Continue"
const NO_RUN := "No run in progress"
const STORY_DONE := "Story complete"
const HEADING := "Select your starting point"
const LOCKED := "Opens after run 1"
const BACK := "‹  Back"
const CONFIRM_TITLE := "Start a new run?"
const CONFIRM_NOTE := "Your current progress in Slot %d will be lost."

var _slot := 0
## The question asked before a new run replaces the one in progress, while it shows.
var _confirm: Control


## Opens the screen for the save in `slot` (already loaded). `description` names the save, for
## example "Slot 1 · Kumpisal · Oct 4, 7:23 PM".
func open(slot: int, description: String) -> void:
	var shift := GameState.mode == GameState.MODE_SHIFT
	_slot = slot
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_add_top_bar(description)
	if not shift:
		# Story Mode: one card, in the middle.
		add_child(_continue_card(Vector2((ScreenFit.DESIGN_SIZE.x - CARD_SIZE.x) / 2.0, CARDS_TOP)))
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
		return
	var total := CARD_SIZE.x * 4.0 + CARD_GAP * 2.0 + DIVIDER_SPACE * 2.0
	var left := (ScreenFit.DESIGN_SIZE.x - total) / 2.0
	add_child(_continue_card(Vector2(left, CARDS_TOP)))
	var line := ColorRect.new()
	line.color = LINE
	line.position = Vector2(left + CARD_SIZE.x + DIVIDER_SPACE, CARDS_TOP - HEADING_GAP)
	line.size = Vector2(1, CARD_SIZE.y + HEADING_GAP)
	add_child(line)
	var stories_left := left + CARD_SIZE.x + DIVIDER_SPACE * 2.0 + 1.0
	var heading := _text(HEADING, HEADING_SIZE, true)
	heading.position = Vector2(stories_left, CARDS_TOP - HEADING_GAP)
	add_child(heading)
	for index in STORIES.size():
		var at := Vector2(stories_left + index * (CARD_SIZE.x + CARD_GAP), CARDS_TOP)
		add_child(_story_card(STORIES[index], at))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)


## Steps back one level: closes the question if it is open, otherwise the screen.
func back() -> void:
	if _confirm != null:
		_close_confirm()
	else:
		closed.emit()
		queue_free()


func _add_top_bar(description: String) -> void:
	var back_button := Button.new()
	back_button.theme_type_variation = &"TextButton"
	back_button.text = BACK
	back_button.focus_mode = Control.FOCUS_NONE
	# Beside the gear and terminal icons that sit at the top left, not under them.
	back_button.position = Vector2(180, 26)
	back_button.pressed.connect(back)
	add_child(back_button)
	var title := _text(description, SMALL_SIZE + 3, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(ScreenFit.DESIGN_SIZE.x, 30)
	add_child(title)


## The Continue card shows the place the run stopped in, or says there is nothing to continue.
func _continue_card(at: Vector2) -> Button:
	var in_progress := GameState.is_run_in_progress()
	var image := "res://assets/backgrounds/main_screen.png"
	var detail := NO_RUN
	if GameState.mode == GameState.MODE_STORY and not in_progress and GameState.runs_finished > 0:
		detail = STORY_DONE
	if in_progress:
		var place := "res://assets/backgrounds/%s.png" % GameState.location
		if ResourceLoader.exists(place):
			image = place
		var stories: Array = StoryDirector.TIMELINES.get(GameState.timeline, [])
		detail = "%s · %d of %d" % [StoryDirector.story_title(StoryDirector.current_story()), GameState.chapter + 1, stories.size()]
	var card := _card(at, image, CONTINUE_TITLE, "", detail, in_progress)
	if in_progress:
		card.pressed.connect(func() -> void: StoryDirector.resume())
	return card


func _story_card(info: Dictionary, at: Vector2) -> Button:
	var story := str(info["story"])
	# The first run always begins at the market.
	var open_now := story == "tokhang" or GameState.has_finished_first_run()
	var bottom := str(info["who"]) if open_now else LOCKED
	var card := _card(at, str(info["image"]), StoryDirector.story_title(story), "", bottom, open_now)
	card.pressed.connect(_pick.bind(story))
	return card


## One upright card: the picture, cropped to fill it, darkening towards the bottom, a small line at
## the top, the title and a line under it, and a thin cream border. A closed card is dimmed.
func _card(at: Vector2, image: String, title: String, top_line: String, bottom_line: String, enabled: bool) -> Button:
	var card := Button.new()
	# Its own look, not the game's default button window.
	card.theme_type_variation = &"StartCard"
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.position = at
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	card.disabled = not enabled
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		card.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", _rounded(Color.WHITE, 0))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mask)
	var picture := TextureRect.new()
	picture.texture = load(image) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(picture)
	var fade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(SHADE, 0.0))
	gradient.set_color(1, SHADE)
	gradient.add_point(0.45, Color(SHADE, 0.15))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	fade.texture = texture
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(fade)
	if not enabled:
		var shade := ColorRect.new()
		shade.color = CLOSED_SHADE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.add_child(shade)
	if top_line != "":
		var top := _text(top_line, SMALL_SIZE, false)
		top.position = Vector2(16, 14)
		mask.add_child(top)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fixed to the bottom of the card, so a line that wraps grows upwards and never past the edge.
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words.offset_left = 16
	words.offset_right = -16
	words.offset_top = 14
	words.offset_bottom = -16
	words.alignment = BoxContainer.ALIGNMENT_END
	var name_label := Label.new()
	name_label.text = title
	UiSkin.style_label(name_label, TITLE_SIZE)
	words.add_child(name_label)
	var line := _text(bottom_line, SMALL_SIZE, false)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CARD_SIZE.x - 32
	words.add_child(line)
	mask.add_child(words)
	var border := Panel.new()
	border.add_theme_stylebox_override("panel", _rounded(Color(0, 0, 0, 0), 2))
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.modulate.a = 1.0 if enabled else 0.4
	card.add_child(border)
	if enabled:
		UiSkin.add_press_bounce(card)
	return card


func _rounded(fill: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(CARD_RADIUS)
	box.set_border_width_all(border_width)
	box.border_color = BORDER
	box.anti_aliasing = true
	return box


## Cream text with a dark outline, like the main screen's buttons; a heading is the golden ochre.
func _text(words: String, font_size: int, heading: bool) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		UiSkin.style_label(label, font_size)
	else:
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", UiSkin.BUTTON_TEXT)
		label.add_theme_color_override("font_outline_color", UiSkin.BUTTON_OUTLINE)
		label.add_theme_constant_override("outline_size", 4)
	return label


## A story card was picked: begin there, asking first if that ends a run in progress.
func _pick(story: String) -> void:
	if not GameState.is_run_in_progress():
		StoryDirector.begin_with(story)
		return
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	panel.custom_minimum_size = Vector2(420, 0)
	var question := _text(CONFIRM_TITLE, HEADING_SIZE, false)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(question)
	var note := _text(CONFIRM_NOTE % (_slot + 1), SMALL_SIZE + 2, false)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = 0.85
	panel.add_child(note)
	for row in [["Start Over", func() -> void: StoryDirector.begin_with(story)], ["Cancel", _close_confirm]]:
		var button := Button.new()
		button.theme_type_variation = &"TextButton"
		button.text = str(row[0])
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(300, 52)
		button.pressed.connect(row[1])
		panel.add_child(button)
	_confirm.add_child(panel)
	SoftWindow.behind(panel, SoftWindow.Look.WINDOW, Vector2(40, 24))
	panel.reset_size()
	panel.position = (ScreenFit.DESIGN_SIZE - panel.get_combined_minimum_size()) / 2.0
	add_child(_confirm)


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
