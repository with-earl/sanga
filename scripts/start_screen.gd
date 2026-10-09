class_name StartScreen
extends Control
## Shift Mode's first screen: a carousel of the three stories, "Select a starting point".
##
## The story in the middle is in front and full size; the other two sit behind it on either side,
## smaller and dimmed, partly hidden. Swipe sideways, or tap a side card, to bring another to the
## middle; tap the middle card to choose it (the main screen then lists that story's three save
## slots). A small round button in the corner of the middle card flips it over to a short summary of
## the story that gives nothing away; tapping the button, or the card, flips it back.

## Emitted with "tokhang", "kumpisal" or "padala" when the middle card is chosen.
signal picked(story: String)
## Emitted when the player goes back to the main screen.
signal closed

## The middle card's size (3:4), the smaller size of the cards behind it, and how far to each side
## they sit from the centre line.
const CARD_SIZE := Vector2(264, 352)
const SIDE_SCALE := 0.8
const SIDE_OFFSET := 184.0
const SIDE_ALPHA := 0.55
const CARD_TOP := 150.0
const CARD_RADIUS := 14
const DIM := Color(0.035, 0.02, 0.03, 0.94)
const BORDER := Color(1.0, 0.953, 0.839, 0.7)
const SHADE := Color(0.05, 0.025, 0.035, 0.92)
const BACK_FILL := Color(0.09, 0.05, 0.065, 0.97)
const GOLD := Color(0.851, 0.643, 0.255, 0.95)
const TITLE_SIZE := 34
const SMALL_SIZE := 17
const SUMMARY_SIZE := 17
const HEADING_SIZE := 26
const FADE_SECONDS := 0.25
const SLIDE_SECONDS := 0.28
const FLIP_SECONDS := 0.16
## A sideways drag shorter than this is a tap.
const SWIPE_PIXELS := 56.0
const HEADING := "Select a starting point"
const BACK := "‹  Back"
## Each story's card: the picture on it, who the player is and where, and a summary for the back of the
## card. The summaries set the scene and never say what happens.
const STORIES := [
	{"story": "tokhang", "image": "res://assets/backgrounds/public_market.png", "who": "Peter · ang palengke",
		"summary": "A delivery rider has one errand left before his son's birthday: a toy from the market. The street is busier than it should be, and everyone seems to be watching someone."},
	{"story": "kumpisal", "image": "res://assets/backgrounds/church_nave.png", "who": "Eli · ang simbahan",
		"summary": "A parish priest hears confessions until the church closes. One voice behind the grille keeps him there longer than he meant to stay."},
	{"story": "padala", "image": "res://assets/backgrounds/apartment_room.png", "who": "Mercy · ang kwarto",
		"summary": "A girl waits in a locked room for a call. A package, a phone and a stranger's promise will decide how the night goes, and who she can trust."},
]

## Which story is in the middle, and each card's parts.
var _index := 0
var _cards: Array = []
var _heading: Label
var _dots: Array = []
## While a drag that began on a card is moving, and whether it already moved the carousel (so the tap
## that ends it does not also choose or flip anything).
var _press_x := -1.0
var _swiped := false
var _busy := false


## Opens the carousel with the first story in the middle.
func open() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_add_top_bar()
	for index in STORIES.size():
		_cards.append(_make_card(STORIES[index], index))
	_heading = _text(HEADING, HEADING_SIZE, true)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.position = Vector2(0, CARD_TOP + CARD_SIZE.y + 38.0)
	_heading.size = Vector2(ScreenFit.DESIGN_SIZE.x, 36)
	add_child(_heading)
	for index in STORIES.size():
		var dot := ColorRect.new()
		dot.size = Vector2(10, 10)
		dot.position = Vector2(ScreenFit.DESIGN_SIZE.x / 2.0 + (index - 1) * 24.0 - 5.0, CARD_TOP + CARD_SIZE.y + 92.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)
	_arrange(false)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)


## Steps back one level.
func back() -> void:
	closed.emit()
	queue_free()


## The raw sideways drag: it moves the carousel, and marks itself so the tap it ends is ignored.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var press := event as InputEventMouseButton
		if press.pressed:
			_press_x = press.position.x
			_swiped = false
		else:
			if _press_x >= 0.0 and not _busy:
				var moved := press.position.x - _press_x
				if absf(moved) >= SWIPE_PIXELS:
					_swiped = true
					_move(-1 if moved > 0.0 else 1)
			_press_x = -1.0


func _add_top_bar() -> void:
	var back_button := Button.new()
	back_button.theme_type_variation = &"TextButton"
	back_button.text = BACK
	back_button.focus_mode = Control.FOCUS_NONE
	# Beside the gear and terminal icons that sit at the top left, not under them.
	back_button.position = Vector2(180, 26)
	back_button.pressed.connect(back)
	add_child(back_button)
	var title := _text("Shift Mode", SMALL_SIZE + 5, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 36)
	title.size = Vector2(ScreenFit.DESIGN_SIZE.x, 36)
	add_child(title)


## One carousel card: a holder (so the whole card can flip), with the front (a button), the back
## (the summary) and the round button that turns it.
func _make_card(info: Dictionary, index: int) -> Dictionary:
	var holder := Control.new()
	holder.size = CARD_SIZE
	holder.pivot_offset = CARD_SIZE / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var story := str(info["story"])
	var front := _front(info)
	front.pressed.connect(_card_pressed.bind(index))
	holder.add_child(front)
	var back_face := _back(info)
	back_face.visible = false
	holder.add_child(back_face)
	var flip := Button.new()
	flip.focus_mode = Control.FOCUS_NONE
	flip.size = Vector2(46, 46)
	flip.position = Vector2(CARD_SIZE.x - 46.0 - 10.0, 10.0)
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		flip.add_theme_stylebox_override(style, _circle(style == "pressed" or style == "hover_pressed"))
	flip.text = "i"
	flip.add_theme_font_size_override("font_size", 28)
	flip.add_theme_color_override("font_color", UiSkin.BUTTON_TEXT)
	flip.add_theme_color_override("font_hover_color", UiSkin.BUTTON_TEXT)
	flip.add_theme_color_override("font_pressed_color", GOLD)
	flip.pressed.connect(_flip_pressed.bind(index))
	holder.add_child(flip)
	add_child(holder)
	return {"story": story, "holder": holder, "front": front, "back": back_face, "flip": flip, "flipped": false}


## The face of a card: the picture cropped to fill it, darkening towards the bottom, the title and
## who the player is, and a thin cream border.
func _front(info: Dictionary) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"StartCard"
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		card.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", _rounded(Color.WHITE, 0))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mask)
	var picture := TextureRect.new()
	picture.texture = load(str(info["image"])) as Texture2D
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
	name_label.text = StoryDirector.story_title(str(info["story"]))
	UiSkin.style_label(name_label, TITLE_SIZE)
	words.add_child(name_label)
	var line := _text(str(info["who"]), SMALL_SIZE, false)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CARD_SIZE.x - 32
	words.add_child(line)
	mask.add_child(words)
	var border := Panel.new()
	border.add_theme_stylebox_override("panel", _rounded(Color(0, 0, 0, 0), 2))
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(border)
	return card


## The back of a card: the story's name, who and where, a thin gold line and its short summary.
func _back(info: Dictionary) -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	var plate := _rounded(BACK_FILL, 2)
	plate.border_color = GOLD
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		card.add_theme_stylebox_override(style, plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20
	column.offset_right = -20
	column.offset_top = 22
	column.offset_bottom = -20
	var name_label := Label.new()
	name_label.text = StoryDirector.story_title(str(info["story"]))
	UiSkin.style_label(name_label, TITLE_SIZE - 2)
	column.add_child(name_label)
	var who := _text(str(info["who"]), SMALL_SIZE, false)
	who.modulate.a = 0.8
	column.add_child(who)
	var rule := ColorRect.new()
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var summary := _text(str(info["summary"]), SUMMARY_SIZE, false)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = CARD_SIZE.x - 40
	column.add_child(summary)
	card.add_child(column)
	card.pressed.connect(func() -> void: _flip(_index))
	return card


## Brings card `index` to the middle, or (when the drag was a swipe) does nothing.
func _card_pressed(index: int) -> void:
	if _swiped or _busy:
		_swiped = false
		return
	if index == _index:
		picked.emit(str(_cards[index]["story"]))
	else:
		_go_to(index)


func _flip_pressed(index: int) -> void:
	if _swiped or _busy:
		_swiped = false
		return
	if index != _index:
		_go_to(index)
		return
	_flip(index)


## Turns the middle card over to its other face and back, squeezing it flat for a moment.
func _flip(index: int) -> void:
	if _busy:
		return
	_busy = true
	var card: Dictionary = _cards[index]
	var holder: Control = card["holder"]
	var tween := create_tween()
	tween.tween_property(holder, "scale:x", 0.0, FLIP_SECONDS)
	tween.tween_callback(func() -> void:
		card["flipped"] = not card["flipped"]
		(card["front"] as Control).visible = not card["flipped"]
		(card["back"] as Control).visible = card["flipped"])
	tween.tween_property(holder, "scale:x", 1.0, FLIP_SECONDS)
	tween.finished.connect(func() -> void: _busy = false)


func _move(step: int) -> void:
	var target := clampi(_index + step, 0, STORIES.size() - 1)
	if target != _index:
		_go_to(target)


func _go_to(index: int) -> void:
	# The card that leaves the middle turns back to its face.
	var leaving: Dictionary = _cards[_index]
	if leaving["flipped"]:
		leaving["flipped"] = false
		(leaving["front"] as Control).visible = true
		(leaving["back"] as Control).visible = false
	_index = index
	_arrange(true)


## Puts every card where it belongs for the middle one: full size in front, the others smaller, dimmed
## and tucked behind it; the round button shows on the middle card only.
func _arrange(animated: bool) -> void:
	var centre_x := ScreenFit.DESIGN_SIZE.x / 2.0
	for index in _cards.size():
		var holder: Control = _cards[index]["holder"]
		var offset := index - _index
		var scale_to := 1.0 if offset == 0 else SIDE_SCALE
		var centre := Vector2(centre_x + offset * SIDE_OFFSET, CARD_TOP + CARD_SIZE.y / 2.0)
		var position_to := centre - CARD_SIZE / 2.0
		var alpha := 1.0 if offset == 0 else SIDE_ALPHA
		holder.z_index = 10 - absi(offset)
		(_cards[index]["flip"] as Control).visible = offset == 0
		if animated:
			var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(holder, "position", position_to, SLIDE_SECONDS)
			tween.tween_property(holder, "scale", Vector2.ONE * scale_to, SLIDE_SECONDS)
			tween.tween_property(holder, "modulate:a", alpha, SLIDE_SECONDS)
		else:
			holder.position = position_to
			holder.scale = Vector2.ONE * scale_to
			holder.modulate.a = alpha
	for index in _dots.size():
		(_dots[index] as ColorRect).color = GOLD if index == _index else Color(1.0, 0.953, 0.839, 0.3)


func _circle(pressed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.03, 0.04, 0.82) if not pressed else Color(0.2, 0.12, 0.08, 0.92)
	box.set_corner_radius_all(23)
	box.set_border_width_all(2)
	box.border_color = BORDER
	box.anti_aliasing = true
	return box


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
