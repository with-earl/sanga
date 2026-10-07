class_name Confessional
extends Location
## The confessional. It has no characters in it. What happens depends on the Kumpisal route:
##
## - Before "Go to confessional booth" is the objective, Father Eli, alone on the left of the
##   dialogue box, says nobody is here yet, straight away. One tap closes it.
## - When it is the objective, the confessions play one after another, each with a caption. Then
##   the ending cutscene plays, and the next story starts by itself, or the run ends.
##
## Who confesses and how it ends depend on the timeline, and come from story/kumpisal.json.

## Where the church nave keeps its route progress. "Go to confessional booth" is its last step.
@export var nave_step_flag := "objective_step:church_nave"

## Each confession's title ("Gwen's Confession") shows at the top of the screen while the
## confession itself already plays, so nothing holds the dialogue up.
const CAPTION_FADE_SECONDS := 0.4
const CAPTION_HOLD_SECONDS := 2.2
const CAPTION_TOP := 92.0
const CAPTION_HEIGHT := 64.0
const CAPTION_SIZE := 42
const TOO_EARLY_LINE := "No one is here yet. I should go back to the Church Nave."

var _caption_layer := CanvasLayer.new()
var _caption_label := Label.new()
var _caption_tween: Tween
var _variant: Dictionary = {}


func _ready() -> void:
	_variant = KumpisalStory.load_variant()
	super._ready()
	# Nobody is in the booth in this scene.
	var characters := get_node_or_null("Characters")
	if characters != null:
		characters.hide()
	_build_caption()
	_begin.call_deferred()


func _begin() -> void:
	var step := int(GameState.get_flag(nave_step_flag, 0))
	if step != _booth_step() or _variant.get("confessions", []).is_empty():
		_say_alone(TOO_EARLY_LINE)
		return
	await _play_confessions()


func _play_confessions() -> void:
	# The menu and buttons stay out of the way for the whole sequence.
	hud_locked = true
	_objectives_panel.modulate.a = 0.0
	_game_menu.get_icon().modulate.a = 0.0
	_game_menu.get_icon().mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _back_button != null:
		_back_button.modulate.a = 0.0
		_back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_undo()
	for confession in _variant.get("confessions", []):
		_show_caption(str(confession.get("title", "")))
		var who := str(confession.get("who", ""))
		var lines: Array = confession.get("lines", [])
		if lines.is_empty():
			continue
		_dialogue.set_cast(left_character, _portrait_for(left_character), who, _portrait_for(who))
		_dialogue.say_lines(str((lines[0] as Dictionary).get("speaker", who)), lines)
		await _dialogue.dismissed
	GameState.set_flag(nave_step_flag, _booth_step() + 1)
	await Cutscene.play(_variant.get("ending", []))
	var run_ending := str(_variant.get("end_run", ""))
	if run_ending != "":
		StoryDirector.end_run(run_ending, "", "")
	else:
		StoryDirector.finish_story([], "kumpisal_" + KumpisalStory.variant_name())


## The step of the nave's route that is "Go to confessional booth": always the last one.
func _booth_step() -> int:
	return maxi(_variant.get("targets", []).size() - 1, 0)


func _build_caption() -> void:
	# Above the dialogue box (layer 20), so it reads over the portraits.
	_caption_layer.layer = 22
	_caption_label.theme_type_variation = &"StoryTitle"
	_caption_label.add_theme_font_size_override("font_size", CAPTION_SIZE)
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_caption_label.offset_top = CAPTION_TOP
	_caption_label.offset_bottom = CAPTION_TOP + CAPTION_HEIGHT
	_caption_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.05, 0.85))
	_caption_label.add_theme_constant_override("outline_size", 10)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label.modulate.a = 0.0
	_caption_layer.add_child(_caption_label)
	add_child(_caption_layer)


## Shows a caption such as "Gwen's Confession" at the top of the screen for a moment, without
## waiting for it: the confession starts at the same time.
func _show_caption(text: String) -> void:
	if text == "":
		return
	_caption_label.text = text
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_caption_tween.tween_property(_caption_label, "modulate:a", 1.0, CAPTION_FADE_SECONDS)
	_caption_tween.tween_interval(CAPTION_HOLD_SECONDS)
	_caption_tween.tween_property(_caption_label, "modulate:a", 0.0, CAPTION_FADE_SECONDS)
