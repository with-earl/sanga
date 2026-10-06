class_name ToggleSwitch
extends Button
## An on and off switch in the dialogue box's black and white: a rounded track with a round knob
## that slides across when tapped. On is a white track with a black knob on the right; off is a
## dark track with a white knob on the left. Drawn from pictures, so the retro text shader softens
## it like the text.

const TRACK_SIZE := Vector2i(52, 30)
const KNOB_INSET := 3
const BORDER := 2
const SLIDE_SECONDS := 0.15
const ON_TRACK := Color(0.92, 0.92, 0.92, 1)
const OFF_TRACK := Color(0, 0, 0, 0.55)
const EDGE := Color(0.87, 0.87, 0.87, 1)
const ON_KNOB := Color(0, 0, 0, 1)
const OFF_KNOB := Color(1, 1, 1, 1)

## 0 when off, 1 when on, in between while sliding.
var _amount := 1.0
var _slide: Tween
var _on_track: StyleBoxTexture
var _off_track: StyleBoxTexture
var _knob: ImageTexture


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(TRACK_SIZE.x + 16, TRACK_SIZE.y + 14)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var radius := TRACK_SIZE.y / 2
	_on_track = SoftShapes.box_style(ON_TRACK, EDGE, BORDER, radius)
	_off_track = SoftShapes.box_style(OFF_TRACK, EDGE, BORDER, radius)
	var knob_diameter := TRACK_SIZE.y - KNOB_INSET * 2
	_knob = SoftShapes.strokes(Vector2i(knob_diameter, knob_diameter), [PackedVector2Array([Vector2(knob_diameter, knob_diameter) / 2.0, Vector2(knob_diameter, knob_diameter) / 2.0])], Color.WHITE, knob_diameter - 1.0, Color.WHITE, 0.0)
	_amount = 1.0 if button_pressed else 0.0
	toggled.connect(_on_toggled)


## Sets the switch without sliding or telling anyone, for example when the menu opens.
func set_on_quietly(on: bool) -> void:
	set_pressed_no_signal(on)
	_amount = 1.0 if on else 0.0
	queue_redraw()


func _on_toggled(on: bool) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_slide.tween_method(_set_amount, _amount, 1.0 if on else 0.0, SLIDE_SECONDS)


func _set_amount(value: float) -> void:
	_amount = value
	queue_redraw()


func _draw() -> void:
	var track := Rect2((size - Vector2(TRACK_SIZE)) / 2.0, Vector2(TRACK_SIZE))
	# The track turns white once the knob is past the middle.
	draw_style_box(_on_track if _amount >= 0.5 else _off_track, track)
	var knob_size := Vector2(_knob.get_size())
	var travel := track.size.x - knob_size.x - KNOB_INSET * 2
	var knob_position := track.position + Vector2(KNOB_INSET + travel * _amount, KNOB_INSET)
	draw_texture(_knob, knob_position, OFF_KNOB.lerp(ON_KNOB, _amount))
