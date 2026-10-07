class_name Location
extends Control
## Base script for every playable location.
##
## Interactive ArtSlot children are wired automatically. A slot whose asset_id is a key in
## `exits` moves the player to that location. Tapping a character plays their conversation, or a
## placeholder line until it is written.

## Key in SceneRouter.SCENES, saved so LOAD returns the player here.
@export var location_key := ""
## Where the back button goes. An empty value opens the game menu instead.
@export var back_to := ""
@export var back_label := "Menu"
## The place name shown beside the menu icon. Empty uses the background's name, for example
## "Church Nave".
@export var location_title := ""
## What the player is working toward here, shown top right. One line per objective.
@export var objectives: PackedStringArray = []
## Fill this to make the objectives an ordered route. It lists, in the same order as `objectives`,
## who or what completes each one: a character or object name such as "Gloria" or
## "Confessional Booth", or names joined with "|" such as "Gwen|Ben" when all of them are needed.
## The panel shows the finished objectives struck through, then the current one. A finished
## objective only counts once its dialogue has closed. Tapping something that belongs to a later
## objective makes the left character say they must do the current one first.
@export var objective_targets: PackedStringArray = []
## Maps an interactive slot's asset_id to the location key it leads to.
@export var exits: Dictionary = {}
## A character who is always on the left of the dialogue box here, for example "Father Eli".
## Leave empty for none. Their picture is assets/portraits/<name in lowercase, spaces as _>_1.png.
@export var left_character := ""
## What each character says when tapped. A key is a character name, or names joined with "|" for
## one conversation shared by several characters, such as "Gwen|Ben". A value is a list of lines,
## each {"speaker": name, "text": words}. Everyone in the key leaves the scene while it plays.
@export var conversations: Dictionary = {}

## While a dialogue is open the scene dims and blurs, the characters in the conversation vanish,
## the objectives and menu button hide, and nothing in the scene can be tapped.
const BACKDROP_SHADER := preload("res://shaders/dialogue_backdrop.gdshader")
## Above the screen vignette (layer 10) and below the HUD and dialogue box (layer 20).
const BACKDROP_LAYER := 15
const FOCUS_IN_SECONDS := 0.2
const FOCUS_OUT_SECONDS := 0.25
## Characters vanish instantly when tapped, and fade back in when the dialogue closes.
const CHARACTER_FADE_IN_SECONDS := 0.2
## Character outlines fade out with the rest, and back when the dialogue closes.
const OUTLINE_FADE_SECONDS := 0.2
## The objective is struck through this long after the dialogue closes, once the panel is back.
const OBJECTIVE_STRIKE_DELAY := 0.3
## When the player has not tapped anything for a while, a soft glint appears at one fixed spot on
## each thing the current objective needs, and slowly brightens and fades, over and over, until
## the next tap. Like the hint shine in God of War: calm, easy to miss at first, never in the way.
const HINT_IDLE_SECONDS := 8.0
## One slow breath of the glint: fade in, glow, fade out.
const HINT_PULSE_SECONDS := 3.4
const HINT_GLINT_SIZE := 48
## The glint grows a little as it brightens, and turns very slightly.
const HINT_GROW := 0.25
const HINT_TURN := 0.18
## Where on the art the glint sits: the visible pixel nearest this point of the slot (0 to 1).
const HINT_SPOT := Vector2(0.5, 0.68)
## Above the scene and its vignette (layer 10), below the dialogue backdrop (layer 15).
const SPARKLE_LAYER := 12
## A soft dark fade along the top of the screen, behind the place name and objectives, so they
## read clearly over bright art. It hides with them during a dialogue.
const TOP_SHADE_HEIGHT := 150.0
const TOP_SHADE_ALPHA := 0.42

@onready var _dialogue: DialogueBox = $Hud/DialogueBox
@onready var _back_button: Button = get_node_or_null("Hud/BackButton")
@onready var _game_menu: GameMenu = $GameMenu
@onready var _objectives_panel: ObjectivesPanel = $Hud/ObjectivesPanel

var _backdrop_layer := CanvasLayer.new()
var _backdrop_overlay := ColorRect.new()
var _backdrop_material := ShaderMaterial.new()
var _focus_tween: Tween
var _focus_amount := 0.0
## The characters who are in the conversation now, and so are hidden from the scene.
var _hidden_characters: Array[ArtSlot] = []
var _character_tween: Tween
## Index of the current objective on an ordered route.
var _step := 0
## Who took part in the conversation just played, to be counted when the dialogue closes.
var _talked_names: Array[String] = []
## When true the objectives, back button and menu button stay hidden even between dialogues, for
## scenes that play a whole sequence of dialogues in a row.
var hud_locked := false
var _idle_seconds := 0.0
var _sparkle_layer := CanvasLayer.new()
var _glint_texture: ImageTexture
## The glint shown on each hinted slot, and where on the slot it sits.
var _glints := {}
var _glint_spots := {}
var _hint_seconds := 0.0
## Takes back the last step of the story. Only shown when there is a step to take back.
var _top_shade := TextureRect.new()


func _ready() -> void:
	_fit_stage()
	GameState.set_location(location_key)
	_step = int(GameState.get_flag(_step_flag(), 0))
	_show_objectives(false)
	var background := get_node_or_null("Background") as ArtSlot
	var title := location_title
	if title == "" and background != null:
		title = background.display_name
	_game_menu.set_location_title(title)
	for node in find_children("*", "ArtSlot", true, false):
		var slot := node as ArtSlot
		if slot.interactive:
			slot.interacted.connect(_on_slot_interacted)
	if _back_button != null:
		_back_button.text = back_label
		_back_button.pressed.connect(_go_back)
	_build_top_shade()
	_build_backdrop()
	_dialogue.portrait_source = _portrait_for
	_dialogue.opened.connect(_focus_on_dialogue.bind(true))
	_dialogue.dismissed.connect(_focus_on_dialogue.bind(false))
	_dialogue.dismissed.connect(_count_conversation)
	get_viewport().size_changed.connect(_fit_stage)


## Shows the place at its 16:9 shape, enlarged to fill the screen's width. On a phone wider than
## 16:9 a thin strip at the top and bottom is cut off; on a taller screen, such as a tablet, dark
## bars show above and below. Nothing is ever stretched, and every prop and character keeps its
## place on the art.
func _fit_stage() -> void:
	var half := ScreenFit.DESIGN_SIZE / 2.0
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -half.x
	offset_top = -half.y
	offset_right = half.x
	offset_bottom = half.y
	pivot_offset = half
	scale = Vector2.ONE * ScreenFit.width_scale(get_viewport().get_visible_rect().size)


func _build_top_shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.06, 0.03, 0.05, TOP_SHADE_ALPHA))
	gradient.set_color(1, Color(0.06, 0.03, 0.05, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	_top_shade.name = "TopShade"
	_top_shade.texture = texture
	_top_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_top_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_shade.offset_bottom = TOP_SHADE_HEIGHT
	$Hud.add_child(_top_shade)
	$Hud.move_child(_top_shade, 0)


func _build_backdrop() -> void:
	_backdrop_layer.layer = BACKDROP_LAYER
	_backdrop_layer.visible = false
	_backdrop_material.shader = BACKDROP_SHADER
	_set_backdrop_amount(0.0)
	_backdrop_overlay.material = _backdrop_material
	_backdrop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# During a dialogue, a tap anywhere on the scene moves it on, not only a tap on the box.
	_backdrop_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dialogue.visible:
			_dialogue.advance())
	_backdrop_layer.add_child(_backdrop_overlay)
	add_child(_backdrop_layer)


## Fades the dim and blur in or out, the character outlines out or back in, and the objectives
## and menu button away or back. The characters in the conversation vanish in the same moment.
func _focus_on_dialogue(focused: bool) -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	var seconds := FOCUS_IN_SECONDS if focused else FOCUS_OUT_SECONDS
	_backdrop_layer.visible = true
	# The overlay sits above the scene and catches every tap, so characters and objects behind it
	# cannot be pressed during a dialogue. The dialogue box is above it.
	_backdrop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if focused else Control.MOUSE_FILTER_IGNORE
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_method(_set_backdrop_amount, _focus_amount, 1.0 if focused else 0.0, seconds)
	for node in find_children("*", "OutlineGroup", true, false):
		var group := node as OutlineGroup
		_focus_tween.tween_property(group, "outline_opacity", 0.0 if focused else 1.0, OUTLINE_FADE_SECONDS)
	var show_hud := not focused and not hud_locked
	var hud_alpha := 1.0 if show_hud else 0.0
	var icon := _game_menu.get_icon()
	icon.visible = true
	icon.mouse_filter = Control.MOUSE_FILTER_STOP if show_hud else Control.MOUSE_FILTER_IGNORE
	_focus_tween.tween_property(_objectives_panel, "modulate:a", hud_alpha, seconds)
	_focus_tween.tween_property(_top_shade, "modulate:a", hud_alpha, seconds)
	_focus_tween.tween_property(icon, "modulate:a", hud_alpha, seconds)
	if _back_button != null:
		_back_button.mouse_filter = Control.MOUSE_FILTER_STOP if show_hud else Control.MOUSE_FILTER_IGNORE
		_focus_tween.tween_property(_back_button, "modulate:a", hud_alpha, seconds)
	if not focused:
		_restore_characters()
		_focus_tween.chain().tween_callback(func() -> void: _backdrop_layer.visible = false)


## Hides the characters in the conversation instantly.
func _hide_characters(slots: Array[ArtSlot]) -> void:
	if _character_tween != null and _character_tween.is_valid():
		_character_tween.kill()
	_restore_characters(true)
	for slot in slots:
		slot.modulate.a = 0.0
	_hidden_characters = slots


## Brings the hidden characters back, with a short fade or at once.
func _restore_characters(immediately := false) -> void:
	for slot in _hidden_characters:
		if not is_instance_valid(slot):
			continue
		if immediately:
			slot.modulate.a = 1.0
		else:
			if _character_tween == null or not _character_tween.is_valid():
				_character_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_character_tween.tween_property(slot, "modulate:a", 1.0, CHARACTER_FADE_IN_SECONDS)
	_hidden_characters = []


func _set_backdrop_amount(value: float) -> void:
	_focus_amount = value
	_backdrop_material.set_shader_parameter("amount", value)


## The picture shown beside the dialogue box for a character, or null if there is none yet.
func _portrait_for(character: String) -> Texture2D:
	if character == "":
		return null
	var key := character.to_lower().replace(" ", "_")
	var path := "res://assets/portraits/%s_1.png" % key
	if not ResourceLoader.exists(path):
		path = "res://assets/portraits/%s.png" % key
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Replaces the objectives on screen, for example after the player completes one.
func set_objectives(lines: PackedStringArray) -> void:
	objectives = lines
	_objectives_panel.set_objectives(lines)


func _is_route() -> bool:
	return not objective_targets.is_empty()


func _step_flag() -> String:
	return "objective_step:%s" % location_key


func _talked_flag(step: int) -> String:
	return "objective_talked:%s:%d" % [location_key, step]


## Shows every objective, or on an ordered route the finished ones struck through followed by the
## current one. With `animate`, the objective that was just finished draws its line in.
func _show_objectives(animate: bool) -> void:
	if not _is_route():
		_objectives_panel.set_objectives(objectives)
		return
	var shown := mini(_step + 1, objectives.size())
	var lines := PackedStringArray()
	for index in shown:
		lines.append(objectives[index])
	_objectives_panel.set_objectives(lines, mini(_step, objectives.size()), animate, OBJECTIVE_STRIKE_DELAY)


## The names that complete a step, for example ["Gwen", "Ben"].
func _names_for_step(step: int) -> PackedStringArray:
	return objective_targets[step].split("|") if step < objective_targets.size() else PackedStringArray()


## "Gwen and Ben" for the names that complete a step.
func _phrase_for_step(step: int) -> String:
	return " and ".join(_names_for_step(step))


## True when `name` belongs to a later objective than the current one, so it is a shortcut.
func _is_shortcut(item_name: String) -> bool:
	if not _is_route():
		return false
	for step in range(_step + 1, objective_targets.size()):
		if item_name in _names_for_step(step):
			return true
	return false


## Called when a dialogue closes. If it was a conversation the current objective needs, count it,
## and move on once everyone that objective needs has been talked to.
func _count_conversation() -> void:
	var names := _talked_names.duplicate()
	_talked_names.clear()
	if names.is_empty() or not _is_route() or _step >= objective_targets.size():
		return
	var talked: Array = GameState.get_flag(_talked_flag(_step), [])
	for name_ in names:
		if name_ in _names_for_step(_step) and name_ not in talked:
			talked.append(name_)
	GameState.set_flag(_talked_flag(_step), talked)
	for needed in _names_for_step(_step):
		if needed not in talked:
			GameState.save_current()
			return
	_advance_step()


func _advance_step() -> void:
	Settings.vibrate(Settings.HAPTIC_MEDIUM)
	_step += 1
	GameState.set_flag(_step_flag(), _step)
	GameState.checkpoint()
	GameState.save_current(true)
	_show_objectives(true)


func _process(delta: float) -> void:
	if not _can_hint():
		_idle_seconds = 0.0
	else:
		_idle_seconds += delta
	if _idle_seconds >= HINT_IDLE_SECONDS:
		_hint_seconds += delta
		_show_glints(_hint_slots())
	else:
		_hint_seconds = 0.0
		_hide_glints()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_idle_seconds = 0.0


## Hints wait while anything else has the player's attention.
func _can_hint() -> bool:
	return not (_dialogue.visible or _game_menu.is_open() or hud_locked or Cutscene.visible or StoryCard.visible)


## The names of what the current objective needs, for the idle hint. Scenes without an ordered
## route say what to hint at themselves.
func _hint_names() -> PackedStringArray:
	if _is_route() and _step < objective_targets.size():
		return _names_for_step(_step)
	return PackedStringArray()


func _hint_slots() -> Array[ArtSlot]:
	var names := _hint_names()
	var found: Array[ArtSlot] = []
	for node in find_children("*", "ArtSlot", true, false):
		var slot := node as ArtSlot
		if slot.interactive and slot.is_visible_in_tree() and slot.display_name in names:
			found.append(slot)
	return found


## Keeps one glint on each hinted slot, at its fixed spot, breathing slowly in and out.
func _show_glints(slots: Array[ArtSlot]) -> void:
	if _glint_texture == null:
		_glint_texture = SoftShapes.glint(HINT_GLINT_SIZE)
		_sparkle_layer.layer = SPARKLE_LAYER
		add_child(_sparkle_layer)
	for slot in _glints.keys():
		if slot not in slots:
			(_glints[slot] as Node).queue_free()
			_glints.erase(slot)
	# Starts dark, so the first glint fades in rather than popping up.
	var breath := 0.5 - 0.5 * cos(TAU * _hint_seconds / HINT_PULSE_SECONDS)
	breath = breath * breath * (3.0 - 2.0 * breath)
	for slot in slots:
		if not _glints.has(slot):
			var glint := TextureRect.new()
			glint.texture = _glint_texture
			glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glint.size = Vector2(HINT_GLINT_SIZE, HINT_GLINT_SIZE)
			glint.pivot_offset = glint.size / 2.0
			glint.material = ArtSlot.retro_material()
			_sparkle_layer.add_child(glint)
			_glints[slot] = glint
		var shown := _glints[slot] as TextureRect
		# Follows the slot, which the stage may have enlarged to fit the screen.
		shown.position = slot.get_global_transform() * _glint_spot(slot) - shown.pivot_offset
		shown.modulate.a = breath
		shown.scale = Vector2.ONE * (1.0 - HINT_GROW + HINT_GROW * breath)
		shown.rotation = HINT_TURN * sin(TAU * _hint_seconds / (HINT_PULSE_SECONDS * 2.0))


func _hide_glints() -> void:
	for glint in _glints.values():
		(glint as Node).queue_free()
	_glints.clear()


## The fixed spot on a slot where its glint sits: the visible pixel of its art nearest HINT_SPOT,
## so it always lands on the thing itself. Worked out once per slot.
func _glint_spot(slot: ArtSlot) -> Vector2:
	if _glint_spots.has(slot):
		return _glint_spots[slot]
	var target := slot.size * HINT_SPOT
	var best := target
	var best_distance := INF
	var step := maxf(minf(slot.size.x, slot.size.y) / 24.0, 2.0)
	var y := 0.0
	while y < slot.size.y:
		var x := 0.0
		while x < slot.size.x:
			var point := Vector2(x, y)
			var distance := point.distance_squared_to(target)
			if distance < best_distance and slot._has_point(point):
				best = point
				best_distance = distance
			x += step
		y += step
	_glint_spots[slot] = best
	return best


## Android back button.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


## Closes the game menu if it is open. Otherwise goes to the previous location, or opens the
## game menu where there is none.
func _go_back() -> void:
	if _game_menu.is_open():
		_game_menu.close()
	elif back_to == "":
		_game_menu.open()
	else:
		SceneRouter.go_to(back_to)


## The key of the conversation a character takes part in, or "" if they have none.
func _conversation_key_for(character: String) -> String:
	for key in conversations:
		if character in str(key).split("|"):
			return str(key)
	return ""


## The character slots in this scene with the given names.
func _slots_named(names: PackedStringArray) -> Array[ArtSlot]:
	var found: Array[ArtSlot] = []
	for node in find_children("*", "ArtSlot", true, false):
		var slot := node as ArtSlot
		if slot.category == "characters" and slot.display_name in names:
			found.append(slot)
	return found


## The slot as a one-item list if it is a character, or an empty list for a prop.
func _only_if_character(slot: ArtSlot) -> Array[ArtSlot]:
	var list: Array[ArtSlot] = []
	if slot.category == "characters":
		list.append(slot)
	return list


func _on_slot_interacted(slot: ArtSlot) -> void:
	if _dialogue.visible:
		return
	# An exit always opens. The scene it leads to decides what happens there.
	if exits.has(slot.asset_id):
		SceneRouter.go_to(exits[slot.asset_id])
		return
	if _is_shortcut(slot.display_name):
		_say_must_do_first(slot)
		return
	var key := _conversation_key_for(slot.display_name)
	if key != "":
		_play_conversation(slot, key)
		return
	# No conversation written yet. Only a character vanishes; a prop, such as keys, stays.
	_hide_characters(_only_if_character(slot))
	_open_dialogue(slot, [{"speaker": slot.display_name, "text": "No dialogue yet."}])


## Plays a character's written conversation. Everyone in it leaves the scene while it plays.
func _play_conversation(slot: ArtSlot, key: String) -> void:
	var participants := key.split("|")
	if _is_route():
		for name_ in participants:
			if name_ in _names_for_step(_step):
				_talked_names.append(name_)
	_hide_characters(_slots_named(participants))
	_open_dialogue(slot, conversations[key])


## The left character explains that the current objective comes first. They have not gone over
## to whoever was tapped, so that character stays where they are and nobody stands on the right.
func _say_must_do_first(slot: ArtSlot) -> void:
	_talked_names.clear()
	_say_alone("I must talk to %s first." % _phrase_for_step(_step), slot)


## A line from the scene's own character with nobody else beside the box, for moments when they
## talk to themselves, such as an early tap on someone they have not gone to yet.
func _say_alone(text: String, slot: ArtSlot = null) -> void:
	var speaker := left_character
	if speaker == "" and slot != null:
		speaker = slot.display_name
	_dialogue.set_cast(left_character, _portrait_for(left_character), "", null)
	_dialogue.say_lines(speaker, [{"speaker": speaker, "text": text}])


## Opens the dialogue with the scene's own character, if there is one, on the left and the first
## person who is not them speaking on the right. When a second person also speaks, such as Gwen
## after Ben, they stand on the right too from the start, so both are there for the whole talk.
func _open_dialogue(slot: ArtSlot, lines: Array) -> void:
	var others := _right_speakers(lines)
	var right_name := slot.display_name if slot.category == "characters" else ""
	if not others.is_empty():
		right_name = others[0]
	var companion := others[1] if others.size() > 1 else ""
	var first_speaker := str((lines[0] as Dictionary).get("speaker", slot.display_name))
	_dialogue.set_cast(left_character, _portrait_for(left_character), right_name, _portrait_for(right_name), companion, _portrait_for(companion) if companion != "" else null)
	_dialogue.say_lines(first_speaker, lines)


## Everyone who speaks in these lines apart from the scene's own character and voices from out of
## sight, in the order they first speak.
func _right_speakers(lines: Array) -> Array[String]:
	var found: Array[String] = []
	for line in lines:
		var data := line as Dictionary
		var who := str(data.get("speaker", ""))
		if who != "" and who != left_character and not data.get("offscreen", false) and who not in found:
			found.append(who)
	return found


## Plays lines with the scene's own character on the left and whoever else speaks on the right,
## and waits until they have been read. Voices from out of sight (lines marked "offscreen") do not
## take a place on the right. With `keep_open` the box stays up for what follows.
func _converse(lines: Array, keep_open: bool) -> void:
	if lines.is_empty():
		return
	var right := ""
	for line in lines:
		var data := line as Dictionary
		var who := str(data.get("speaker", ""))
		if who != left_character and not data.get("offscreen", false):
			right = who
			break
	if not _dialogue.visible:
		_dialogue.set_cast(left_character, _portrait_for(left_character), right, _portrait_for(right))
	_dialogue.say_lines(str((lines[0] as Dictionary).get("speaker", "")), lines, keep_open)
	await _dialogue.lines_finished
	if not keep_open:
		# Let the scene come back before anything else happens.
		await get_tree().create_timer(FOCUS_OUT_SECONDS).timeout
