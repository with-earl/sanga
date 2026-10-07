extends CanvasLayer
## Story title card, then an optional montage, then the story's first scene.
##
## The screen goes black and the story's name appears. If the story has a montage, the title
## fades out into the first picture. Every picture is zoomed in and pans across the screen, the
## direction alternating (right to left, then left to right, and so on), and fades out to black at
## the end. When the last picture has faded out, the story's first scene opens and the black
## fades away.
##
## A few seconds into the montage, "Tap anywhere to continue" fades in and skipping becomes
## possible: two quick taps close together skip the rest of the montage and go straight to the
## scene. Two taps far apart, or too slow, do not. Taps before the hint appears do nothing.

const FADE_TO_BLACK_SECONDS := 0.35
const TITLE_FADE_IN_SECONDS := 0.6
const TITLE_HOLD_SECONDS := 1.6
const FADE_OUT_SECONDS := 0.5
## The title leaves a little ahead of the black, so the last thing to fade is the scene itself.
const TITLE_FADE_OUT_SECONDS := 0.25
## How long an ending card stays up before the main screen.
const ENDING_HOLD_SECONDS := 3.5
## The main timeline's closing screen: the three titles, then when each one happens.
const TIME_ORDER := [["Tokhang", "Future"], ["Kumpisal", "Past"], ["Padala", "Present"]]
const TIME_ORDER_COLUMN_WIDTH := 350.0
const TIME_ORDER_STEP_SECONDS := 0.7
const TIME_ORDER_PAUSE_SECONDS := 1.0
const TIME_ORDER_RISE := 12.0
const TIME_WORD_COLOR := Color(1.0, 0.953, 0.839, 0.62)

## How long the title takes to fade out into the first montage picture.
const TITLE_REVEAL_SECONDS := 0.6

## Time on screen for each montage picture, including its fades.
const MONTAGE_SECONDS := 3.0
const MONTAGE_FADE_SECONDS := 0.5
## The picture is drawn this much larger than the screen, so there is room to pan.
const MONTAGE_ZOOM := 1.1
const SCREEN_SIZE := Vector2(1280, 720)

const SKIP_HINT := "Tap anywhere to continue"
## Under the title: the ornament, then the ending card's one-line summary, in soft cream.
const ORNAMENT_BELOW_TITLE := 50.0
const ENDING_LINE_TOP := 76.0
const ENDING_LINE_SIZE := 26
## The hint, and skipping, only start this long after the montage begins...
const SKIP_HINT_DELAY_SECONDS := 2.0
## ...and the hint fades in over this long.
const SKIP_HINT_FADE_IN_SECONDS := 0.6
## Two taps count as a double tap only when they come within this time...
const DOUBLE_TAP_SECONDS := 0.4
## ...and land within this distance of each other, in screen pixels.
const DOUBLE_TAP_DISTANCE := 90.0
const SKIP_FADE_SECONDS := 0.3

## Montage pictures by story title. A story without an entry goes straight to its scene.
const MONTAGES := {
	"Kumpisal": [
		"res://assets/montage/kumpisal_1.png",
		"res://assets/montage/kumpisal_2.png",
		"res://assets/montage/kumpisal_3.png",
	],
}

var _stage := Control.new()
var _picture := TextureRect.new()
var _black := ColorRect.new()
var _title := Label.new()
var _hint: TapHint
var _ending_line := Label.new()
var _time_order := HBoxContainer.new()
var _waiting_for_tap := false
signal _tapped
var _running := false
var _montage_active := false
var _skip_enabled := false
var _skip_requested := false
var _last_tap_time := -100.0
var _last_tap_position := Vector2.ZERO
var _pan_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	layer = 100
	visible = false

	# The montage sits under the black, and clips the zoomed picture to the screen.
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.visible = false
	add_child(_stage)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Same soft film look as the other art. It needs smooth sampling.
	_picture.material = ArtSlot.retro_material()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_stage.add_child(_picture)
	var vignette := ColorRect.new()
	vignette.material = SceneVignette.make_material()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(vignette)

	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Absorbs taps, so nothing underneath can be pressed while the card is up.
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)
	_title.theme_type_variation = &"StoryTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.add_child(_title)
	# A fine golden ornament under the title, fading with it.
	TitleOrnament.make(_title, ORNAMENT_BELOW_TITLE)
	# The ending card's one-line summary, under the title.
	_ending_line.theme_type_variation = &"HudBody"
	_ending_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ending_line.anchor_top = 0.5
	_ending_line.anchor_bottom = 0.5
	_ending_line.offset_left = -400.0
	_ending_line.offset_right = 400.0
	_ending_line.offset_top = ENDING_LINE_TOP
	_ending_line.offset_bottom = ENDING_LINE_TOP + 44.0
	_ending_line.add_theme_color_override("font_color", UiSkin.BUTTON_TEXT)
	_ending_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	_ending_line.add_theme_font_size_override("font_size", ENDING_LINE_SIZE)
	_ending_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_line.modulate.a = 0.0
	_black.add_child(_ending_line)
	_black.gui_input.connect(_on_card_input)
	_build_time_order()

	# The hint sits above the black, so it stays readable between pictures.
	var hint_holder := Control.new()
	hint_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_holder)
	_hint = TapHint.make(hint_holder, SKIP_HINT)


## Shows the card with the story's title, plays its montage if it has one, opens the scene behind
## the black, then fades the card away.
## `lead_in` is an optional list of picture paths played first, for example the cutscene that ends
## the previous story, before this story's title appears.
func start(title: String, scene_key: String, lead_in: Array = []) -> void:
	if _running:
		return
	_running = true
	MusicDirector.play_for_key(scene_key)
	_title.text = title
	_title.modulate.a = 0.0
	_black.modulate.a = 0.0
	visible = true
	await _fade(_black, 1.0, FADE_TO_BLACK_SECONDS)
	if not lead_in.is_empty():
		await _play_montage(lead_in)
	await _fade(_title, 1.0, TITLE_FADE_IN_SECONDS)
	await get_tree().create_timer(TITLE_HOLD_SECONDS).timeout
	var pictures: Array = MONTAGES.get(title, [])
	if not pictures.is_empty():
		await _play_montage(pictures)
	SceneRouter.go_to(scene_key)
	# Let the new scene draw once under the black before the black fades away.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_out_card()
	visible = false
	_running = false


## Plays each picture in turn. The black card does all the fading: it lifts to reveal a picture
## and comes back down at the end of it, so the next picture always starts from black. A double
## tap ends the montage early.
func _play_montage(paths: Array) -> void:
	# Each picture covers the whole screen, whatever the phone's shape, with room to pan.
	var screen := get_viewport().get_visible_rect().size
	var zoomed := SCREEN_SIZE * maxf(screen.x / SCREEN_SIZE.x, screen.y / SCREEN_SIZE.y) * MONTAGE_ZOOM
	var overflow := zoomed.x - screen.x
	_picture.size = zoomed
	_stage.visible = true
	_skip_requested = false
	_skip_enabled = false
	_last_tap_time = -100.0
	_montage_active = true
	_reveal_skip_hint_later()
	for index in paths.size():
		var texture := load(paths[index]) as Texture2D
		if texture == null:
			push_error("Missing montage picture: %s" % paths[index])
			continue
		_picture.texture = texture
		# Even pictures pan right to left (the picture slides left), odd ones left to right.
		var leftward := index % 2 == 0
		var from_x := 0.0 if leftward else -overflow
		var to_x := -overflow if leftward else 0.0
		_picture.position = Vector2(from_x, -(zoomed.y - screen.y) / 2.0)

		var reveal_seconds := MONTAGE_FADE_SECONDS
		if index == 0:
			# The title screen fades out into the first picture.
			reveal_seconds = TITLE_REVEAL_SECONDS
			create_tween().tween_property(_title, "modulate:a", 0.0, TITLE_FADE_OUT_SECONDS)
		_fade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_fade_tween.tween_property(_black, "modulate:a", 0.0, reveal_seconds)
		_fade_tween.tween_interval(MONTAGE_SECONDS - reveal_seconds - MONTAGE_FADE_SECONDS)
		_fade_tween.tween_property(_black, "modulate:a", 1.0, MONTAGE_FADE_SECONDS)

		# A steady, even pan for the whole time the picture is on screen.
		_pan_tween = create_tween()
		_pan_tween.tween_property(_picture, "position:x", to_x, MONTAGE_SECONDS)
		await _wait_or_skip(MONTAGE_SECONDS)
		if _skip_requested:
			break
	_montage_active = false
	_skip_enabled = false
	for tween in [_pan_tween, _fade_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_title.modulate.a = 0.0
	_fade_hint(0.0, 0.4)
	if _skip_requested:
		# Straight to black, then on to the scene.
		await _fade(_black, 1.0, SKIP_FADE_SECONDS)
	_stage.visible = false


## Waits for the time to pass, or until a double tap asks to skip.
func _wait_or_skip(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


## Counts a tap during the montage. Two taps skip it only if they are quick and close together.
func _on_card_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if _waiting_for_tap and tap != null and tap.pressed and tap.button_index == MOUSE_BUTTON_LEFT:
		_waiting_for_tap = false
		_tapped.emit()
		return
	if not _skip_enabled or tap == null or not tap.pressed or tap.button_index != MOUSE_BUTTON_LEFT:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var is_quick := now - _last_tap_time <= DOUBLE_TAP_SECONDS
	var is_close := tap.position.distance_to(_last_tap_position) <= DOUBLE_TAP_DISTANCE
	if is_quick and is_close:
		_skip_requested = true
		return
	# Otherwise this tap becomes the first tap of a possible double tap.
	_last_tap_time = now
	_last_tap_position = tap.position


## After a few seconds the hint fades in, and skipping turns on at the same moment.
func _reveal_skip_hint_later() -> void:
	await get_tree().create_timer(SKIP_HINT_DELAY_SECONDS).timeout
	if not _montage_active:
		return
	_skip_enabled = true
	_last_tap_time = -100.0
	_fade_hint(1.0, SKIP_HINT_FADE_IN_SECONDS, Tween.EASE_OUT)


## Fading in uses an ease-out curve, so the hint shows up promptly and then settles gently.
func _fade_hint(alpha: float, seconds: float, easing := Tween.EASE_IN_OUT) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(easing)
	tween.tween_property(_hint, "modulate:a", alpha, seconds)


## The card that closes a run: any closing pictures, then the ending's title and one line on
## black, held for a moment, then the main screen. With no title it simply says "The End".
## With `next_scene` there is no card: after the pictures that scene opens behind the black.
func show_ending(title: String, line: String, lead_in: Array = [], next_scene := "") -> void:
	if _running:
		return
	if next_scene != "":
		await fade_to_scene(next_scene, lead_in)
		return
	_running = true
	MusicDirector.play_main()
	_title.text = title if title != "" else "The End"
	_title.modulate.a = 0.0
	_ending_line.text = line
	_ending_line.modulate.a = 0.0
	_black.modulate.a = 0.0
	visible = true
	await _fade(_black, 1.0, FADE_TO_BLACK_SECONDS)
	if not lead_in.is_empty():
		await _play_montage(lead_in)
	await _fade(_title, 1.0, TITLE_FADE_IN_SECONDS)
	if line != "":
		await _fade(_ending_line, 1.0, TITLE_FADE_IN_SECONDS)
	await get_tree().create_timer(ENDING_HOLD_SECONDS).timeout
	SceneRouter.go_to("main_menu")
	await get_tree().process_frame
	await get_tree().process_frame
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "modulate:a", 0.0, TITLE_FADE_OUT_SECONDS)
	tween.tween_property(_ending_line, "modulate:a", 0.0, TITLE_FADE_OUT_SECONDS)
	tween.tween_property(_black, "modulate:a", 0.0, FADE_OUT_SECONDS * 2.0)
	await tween.finished
	visible = false
	_running = false


## The main timeline's last screen. "Tokhang", "Kumpisal" and "Padala" appear one by one from
## left to right; then, one by one, when each happens: Future, Past and Present. A tap goes back
## to the main screen.
func show_time_order(lead_in: Array = []) -> void:
	if _running:
		return
	_running = true
	MusicDirector.play_main()
	_title.modulate.a = 0.0
	_black.modulate.a = 0.0
	visible = true
	await _fade(_black, 1.0, FADE_TO_BLACK_SECONDS)
	if not lead_in.is_empty():
		await _play_montage(lead_in)
	_time_order.visible = true
	for column in _time_order.get_children():
		for label in column.get_children():
			(label as Control).modulate.a = 0.0
	for column in _time_order.get_children():
		await _fade(column.get_child(0), 1.0, TIME_ORDER_STEP_SECONDS)
	await get_tree().create_timer(TIME_ORDER_PAUSE_SECONDS).timeout
	for column in _time_order.get_children():
		var word := column.get_child(1) as Control
		var rest_y := word.position.y
		word.position.y = rest_y + TIME_ORDER_RISE
		var rise := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rise.tween_property(word, "modulate:a", 1.0, TIME_ORDER_STEP_SECONDS)
		rise.tween_property(word, "position:y", rest_y, TIME_ORDER_STEP_SECONDS)
		await rise.finished
	_hint.text = SKIP_HINT
	_fade_hint(1.0, SKIP_HINT_FADE_IN_SECONDS, Tween.EASE_OUT)
	_waiting_for_tap = true
	await _tapped
	_fade_hint(0.0, 0.3)
	var out := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	out.tween_property(_time_order, "modulate:a", 0.0, FADE_OUT_SECONDS)
	await out.finished
	_time_order.visible = false
	_time_order.modulate.a = 1.0
	SceneRouter.go_to("main_menu")
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(_black, 0.0, FADE_OUT_SECONDS * 2.0)
	visible = false
	_running = false


## Fades to black, plays any pictures, then opens `scene_key` and fades the black away.
func fade_to_scene(scene_key: String, lead_in: Array = []) -> void:
	if _running:
		return
	_running = true
	_title.modulate.a = 0.0
	_black.modulate.a = 0.0
	visible = true
	await _fade(_black, 1.0, FADE_TO_BLACK_SECONDS)
	if not lead_in.is_empty():
		await _play_montage(lead_in)
	SceneRouter.go_to(scene_key)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(_black, 0.0, FADE_OUT_SECONDS)
	visible = false
	_running = false


func _build_time_order() -> void:
	_time_order.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_time_order.grow_vertical = Control.GROW_DIRECTION_BOTH
	_time_order.alignment = BoxContainer.ALIGNMENT_CENTER
	_time_order.add_theme_constant_override("separation", 0)
	_time_order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_order.visible = false
	for pair in TIME_ORDER:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = TIME_ORDER_COLUMN_WIDTH
		column.add_theme_constant_override("separation", 14)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var story := Label.new()
		story.theme_type_variation = &"StoryTitle"
		story.text = pair[0]
		story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(story)
		var when := Label.new()
		when.theme_type_variation = &"HudHeading"
		when.text = pair[1]
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		when.add_theme_color_override("font_color", TIME_WORD_COLOR)
		when.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		column.add_child(when)
		_time_order.add_child(column)
	_black.add_child(_time_order)
	_time_order.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## True while the card's black screen fully covers everything.
func is_screen_covered() -> bool:
	return visible and _black.modulate.a >= 0.99


func _fade_out_card() -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "modulate:a", 0.0, TITLE_FADE_OUT_SECONDS)
	tween.tween_property(_black, "modulate:a", 0.0, FADE_OUT_SECONDS)
	await tween.finished


## Eased, so the fade starts and ends gently instead of at a constant rate.
func _fade(item: CanvasItem, alpha: float, seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item, "modulate:a", alpha, seconds)
	await tween.finished
