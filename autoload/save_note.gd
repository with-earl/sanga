extends CanvasLayer
## A quiet "Progress saved" note at the top centre of the screen after each automatic save the player
## should know about. It fades in, stays a moment, and fades out.

const FADE_IN_SECONDS := 0.25
const HOLD_SECONDS := 1.4
const FADE_OUT_SECONDS := 0.5

var _label := Label.new()
var _tween: Tween


func _ready() -> void:
	layer = 60
	_label.text = "Progress saved"
	_label.theme_type_variation = &"HudBody"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -200.0
	_label.offset_top = 24.0
	_label.offset_right = 200.0
	_label.offset_bottom = 58.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)
	GameState.saved.connect(_on_saved)


func _on_saved(noticed: bool) -> void:
	if not noticed:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_label, "modulate:a", 1.0, FADE_IN_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_OUT_SECONDS)
