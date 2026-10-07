class_name TapHint
extends PanelContainer
## "Tap anywhere to continue": cream words on a small soft plate at the bottom of the screen, so
## they read over bright pictures as well as black. Once shown, it breathes very gently.

const FONT_SIZE := 22
const PADDING := Vector2(26.0, 8.0)
## How far up from the bottom of the screen it sits.
const BOTTOM := 44.0
const BREATH_SECONDS := 2.4
const BREATH_LOW := 0.62

var _label := Label.new()
var _breath: Tween
## The words shown.
var text: String:
	get:
		return _label.text
	set(value):
		_label.text = value


## A hint with this text, anchored at the bottom centre of `parent`, starting invisible. Fade it
## in by tweening its modulate:a; it breathes on its own while visible.
static func make(parent: Control, text: String) -> TapHint:
	var hint := TapHint.new()
	hint.text = text
	parent.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_top -= BOTTOM
	hint.offset_bottom -= BOTTOM
	return hint


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var style := StyleBoxEmpty.new()
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	add_theme_stylebox_override("panel", style)
	SoftWindow.behind(self, SoftWindow.Look.PLATE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", UiSkin.BUTTON_TEXT)
	_label.add_theme_color_override("font_outline_color", UiSkin.BUTTON_OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _ready() -> void:
	# The words breathe softly between dim and full, inside whatever fade the hint is given.
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_label, "modulate:a", BREATH_LOW, BREATH_SECONDS / 2.0)
	_breath.tween_property(_label, "modulate:a", 1.0, BREATH_SECONDS / 2.0)
