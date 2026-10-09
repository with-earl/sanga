extends CanvasLayer
## Plays a cutscene: a list of steps, each a full-screen picture with optional dialogue, or a card
## on black. Tapping anywhere moves the dialogue on, and skips a picture's hold after a moment.
##
## A step is a dictionary:
##   {"image": path, "lines": [{"speaker": ..., "text": ...}]}   a picture with dialogue
##   {"image": path, "hold": seconds}                             a picture on its own
##   {"image": path, "gunshot": true, ...}                        with a flash, shake and buzz
##   {"image": path, "caption": "Flashback", ...}                 with a small caption
##   {"image": path, "sound": "engine_ride", ...}                 with a sound from assets/sounds: a looping
##                                                                one ("engine_ride") fades out when the step ends
##   {"image": path, "zoom": true, ...}                           with a slow push-in (pictures hold still otherwise)
##   {"card": "Peter", "line": "Namatay si Peter."}                     a title card on black
##   {"image": path, "choose": ["Run", "Ride Jeep"]}              a picture with a choice;
##                                                                the answer is in `last_choice`
## A choice's options can also be {"text": ..., "needs": alaala, "flag": "run_x", "then": [steps]}:
## an option that needs an Alaala shows only when the save holds it (marked ✦), its flag is set
## when it is picked, and its "then" steps play right after. Any step can have "needs" or
## "needs_not" (see Alaala) to play only with, or only without, a memory.
##
## `play` leaves the screen black at the end. Call `release` to fade back to the scene, or
## `hand_over` when a title card from the StoryCard follows.

const FADE_SECONDS := 0.4
const ZOOM_FROM := 1.0
const ZOOM_TO := 1.06
const DEFAULT_HOLD := 2.5
## A hold can be tapped away once it has been up this long.
const MIN_HOLD_BEFORE_TAP := 0.6
const CARD_HOLD := 3.0
## Sounds a step can play (see "sound" above), and the ones that loop until the step ends.
const SOUND_FOLDER := "res://assets/sounds/"
const LOOPING_SOUNDS := ["engine_ride"]
const SOUND_FADE_IN := 0.8
const SOUND_FADE_OUT := 0.45
const SOUND_QUIET_DB := -40.0
const SHAKE_PIXELS := 14.0
const VIBRATE_MS := 220
const SCREEN_SIZE := Vector2(1280, 720)

var _black := ColorRect.new()
var _picture := TextureRect.new()
var _flash := ColorRect.new()
var _caption := Label.new()
var _card_title := Label.new()
var _card_line := Label.new()
var _tap_catcher := Control.new()
var _dialogue: DialogueBox
var _tapped := false
var _playing := false
## The option picked in the last choice step, counted from 0, or -1.
var last_choice := -1


func _ready() -> void:
	layer = 90
	visible = false
	var base := ColorRect.new()
	base.color = Color.BLACK
	_fill(base)
	add_child(base)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.size = SCREEN_SIZE
	_picture.pivot_offset = SCREEN_SIZE / 2.0
	_picture.material = ArtSlot.retro_material()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	var vignette := ColorRect.new()
	vignette.material = SceneVignette.make_material()
	_fill(vignette)
	add_child(vignette)
	_caption.theme_type_variation = &"HudHeading"
	_caption.position = Vector2(40, 32)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	add_child(_caption)
	_flash.color = Color(1, 1, 1, 1)
	_flash.modulate.a = 0.0
	_fill(_flash)
	add_child(_flash)
	_black.color = Color.BLACK
	_fill(_black)
	add_child(_black)
	_card_title.theme_type_variation = &"StoryTitle"
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fill(_card_title)
	_card_title.modulate.a = 0.0
	add_child(_card_title)
	# The same golden ornament as the story title cards, fading with the title.
	TitleOrnament.make(_card_title, StoryCard.ORNAMENT_BELOW_TITLE)
	_card_line.theme_type_variation = &"HudBody"
	_card_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_line.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	_card_line.offset_top = StoryCard.ENDING_LINE_TOP
	_card_line.offset_bottom = StoryCard.ENDING_LINE_TOP + 44.0
	_card_line.add_theme_color_override("font_color", UiSkin.BUTTON_TEXT)
	_card_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	_card_line.add_theme_font_size_override("font_size", StoryCard.ENDING_LINE_SIZE)
	_card_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_line.modulate.a = 0.0
	add_child(_card_line)
	# Catches every tap, so the scene underneath cannot be touched while a cutscene plays.
	_fill(_tap_catcher)
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap_catcher.gui_input.connect(_on_tap)
	add_child(_tap_catcher)
	_dialogue = (load("res://scenes/components/dialogue_box.tscn") as PackedScene).instantiate()
	_fill(_dialogue)
	add_child(_dialogue)


func is_playing() -> bool:
	return _playing


## Plays the steps in order and returns when they are done, leaving the screen black.
func play(steps: Array) -> void:
	_playing = true
	visible = true
	_black.modulate.a = 0.0
	await _tween_alpha(_black, 1.0, FADE_SECONDS)
	var queue: Array = steps.duplicate()
	while not queue.is_empty():
		var data := queue.pop_front() as Dictionary
		if not Alaala.allows(data):
			continue
		if data.has("card"):
			if not data.get("alaala", false):
				GameState.log_moment({"ending": str(data["card"]), "line": str(data.get("line", ""))})
			await _play_card(str(data["card"]), str(data.get("line", "")))
		elif data.has("image"):
			var next_steps: Array = await _play_picture(data)
			queue = next_steps + queue
	_playing = false


## Fades from the black end of a cutscene back to the scene underneath.
func release() -> void:
	await _tween_alpha(_black, 0.0, FADE_SECONDS)
	visible = false


## Stays black until the StoryCard's own black screen has taken over, then steps aside.
func hand_over() -> void:
	while not (StoryCard.visible and StoryCard.is_screen_covered()):
		await get_tree().process_frame
	visible = false


## Plays one picture step. Returns the steps a picked choice asks to play next, if any.
func _play_picture(data: Dictionary) -> Array:
	var texture := load(str(data["image"])) as Texture2D
	if texture == null:
		push_error("Missing cutscene picture: %s" % data["image"])
		return []
	_picture.texture = texture
	# The picture fills the screen's width at its own shape, whatever the phone's shape.
	var area := ScreenFit.width_rect(texture.get_size(), get_viewport().get_visible_rect().size)
	_picture.size = area.size
	_picture.pivot_offset = area.size / 2.0
	_picture.scale = Vector2.ONE * ZOOM_FROM
	_picture.position = area.position
	var lines: Array = Alaala.prepare_lines(data.get("lines", []))
	var next_steps: Array = []
	var hold: float = float(data.get("hold", DEFAULT_HOLD))
	var sound: Variant = _start_sound(str(data.get("sound", "")))
	var zoom: Tween = null
	if data.get("zoom", false):
		zoom = create_tween()
		zoom.tween_property(_picture, "scale", Vector2.ONE * ZOOM_TO, maxf(hold, 4.0) + 6.0)
	if data.has("caption"):
		_caption.text = str(data["caption"])
		_tween_alpha(_caption, 1.0, FADE_SECONDS)
	await _tween_alpha(_black, 0.0, FADE_SECONDS)
	if data.get("gunshot", false):
		_gunshot()
	if not lines.is_empty():
		_dialogue.set_cast("", null, "", null)
		_dialogue.say_lines(str((lines[0] as Dictionary).get("speaker", "")), lines)
		await _dialogue.lines_finished
	elif data.has("choose"):
		await _hold(MIN_HOLD_BEFORE_TAP)
		_dialogue.set_cast("", null, "", null)
		var options := Alaala.prepare_options(data["choose"])
		var labels: Array = []
		for option in options:
			labels.append(option["label"])
		var picked: Dictionary = options[await _dialogue.choose(labels)]
		# Counted in the full list, so callers can match it to their own list of outcomes.
		last_choice = int(picked["index"])
		Alaala.apply_option(picked)
		next_steps = picked.get("then", [])
	else:
		await _hold(hold)
	if data.has("caption"):
		_tween_alpha(_caption, 0.0, FADE_SECONDS)
	await _tween_alpha(_black, 1.0, FADE_SECONDS)
	if zoom != null:
		zoom.kill()
	_stop_sound(sound)
	return next_steps


## Starts the step's sound on the Sound bus (so the Sound switch silences it) and returns its player, or
## null for no sound. A looping sound fades in, and is faded out by `_stop_sound` when the step ends.
func _start_sound(sound_name: String) -> Variant:
	if sound_name == "":
		return null
	var stream := load(SOUND_FOLDER + sound_name + ".wav") as AudioStreamWAV
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.bus = Settings.SOUND_BUS
	var level := Sfx.VOLUME_DB + 4.0
	if sound_name in LOOPING_SOUNDS:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.volume_db = SOUND_QUIET_DB
		create_tween().tween_property(player, "volume_db", level, SOUND_FADE_IN)
	else:
		player.volume_db = level
	player.stream = stream
	add_child(player)
	player.play()
	if sound_name not in LOOPING_SOUNDS:
		player.finished.connect(player.queue_free)
	return player


## Fades a step's looping sound out and removes it; a sound that plays once is left to finish.
func _stop_sound(player: Variant) -> void:
	if not is_instance_valid(player) or not player.playing:
		return
	if (player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		return
	var fade := create_tween()
	fade.tween_property(player, "volume_db", SOUND_QUIET_DB, SOUND_FADE_OUT)
	fade.tween_callback(player.queue_free)


func _play_card(title: String, line: String) -> void:
	_card_title.text = title
	_card_line.text = line
	await _tween_alpha(_card_title, 1.0, FADE_SECONDS * 1.5)
	if line != "":
		await _tween_alpha(_card_line, 1.0, FADE_SECONDS * 1.5)
	await _hold(CARD_HOLD)
	var out := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	out.tween_property(_card_title, "modulate:a", 0.0, FADE_SECONDS)
	out.tween_property(_card_line, "modulate:a", 0.0, FADE_SECONDS)
	await out.finished


## A white flash, a quick shake of the picture, and a short vibration on phones.
func _gunshot() -> void:
	_flash.modulate.a = 0.9
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	var shake := create_tween()
	for i in 6:
		var reach := SHAKE_PIXELS * (1.0 - float(i) / 6.0)
		shake.tween_property(_picture, "position", Vector2(randf_range(-reach, reach), randf_range(-reach, reach)), 0.04)
	shake.tween_property(_picture, "position", Vector2.ZERO, 0.05)
	Settings.vibrate(VIBRATE_MS)


## Waits `seconds`, or less if the player taps after a short moment.
func _hold(seconds: float) -> void:
	_tapped = false
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if _tapped and elapsed >= MIN_HOLD_BEFORE_TAP:
			break
		_tapped = false


func _on_tap(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _dialogue.visible:
		_dialogue.advance()
	else:
		_tapped = true


func _tween_alpha(item: CanvasItem, alpha: float, seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item, "modulate:a", alpha, seconds)
	await tween.finished


func _fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
