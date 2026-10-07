class_name ObjectivesPanel
extends Control
## Top-right objective list on a small soft window: a heading, a thin line, then one right-aligned
## line per objective. The window fits its text. Finished objectives have a line struck through
## them and fade back, so the current one stands out.

const STRIKE_SECONDS := 0.35
const NEW_ITEM_FADE_SECONDS := 0.3
## A new objective glows a little brighter as it appears, then settles, so the eye finds it.
const NEW_ITEM_GLOW := 1.45
const NEW_ITEM_GLOW_SECONDS := 1.2
## Finished objectives settle at this opacity once struck through.
const FINISHED_ALPHA := 0.6
## Room between the text and the edge of its window.
const WINDOW_MARGIN := Vector2(18.0, 12.0)

@onready var _list: VBoxContainer = %List
@onready var _box: VBoxContainer = $Box

var _shown_count := 0
var _struck_count := 0


## Shows the given objectives. The first `struck_count` of them are finished and struck through.
## With `animate`, the ones that have just been finished draw their line in, and a new line fades
## in, starting after `delay` seconds.
func _ready() -> void:
	# The box hugs its text at the top right, and a soft window sits behind it.
	_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.offset_top = WINDOW_MARGIN.y
	SoftWindow.behind(_box, SoftWindow.Look.WINDOW, WINDOW_MARGIN)
	_box.resized.connect(_fit_box)


## Keeps the box's right edge in place as its text changes width.
func _fit_box() -> void:
	_box.position.x = size.x - _box.size.x


func set_objectives(lines: PackedStringArray, struck_count := 0, animate := false, delay := 0.0) -> void:
	for child in _list.get_children():
		child.queue_free()
	visible = not lines.is_empty()
	for index in lines.size():
		var item := ObjectiveItem.new()
		item.theme_type_variation = &"HudBody"
		item.text = lines[index]
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# One line each, so the window can hug the widest objective.
		item.autowrap_mode = TextServer.AUTOWRAP_OFF
		item.size_flags_horizontal = Control.SIZE_FILL
		_list.add_child(item)
		var finished := index < struck_count
		var just_finished := finished and index >= _struck_count
		var is_new := index >= _shown_count
		if animate and just_finished:
			item.strike_amount = 0.0
			Sfx.strike(delay)
			var strike := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			strike.tween_property(item, "strike_amount", 1.0, STRIKE_SECONDS).set_delay(delay)
			strike.tween_property(item, "modulate:a", FINISHED_ALPHA, NEW_ITEM_FADE_SECONDS)
		elif finished:
			item.strike_amount = 1.0
			item.modulate.a = FINISHED_ALPHA
		if animate and is_new:
			item.modulate = Color(NEW_ITEM_GLOW, NEW_ITEM_GLOW, NEW_ITEM_GLOW, 0.0)
			var appear := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			appear.tween_property(item, "modulate:a", 1.0, NEW_ITEM_FADE_SECONDS) \
				.set_delay(delay + STRIKE_SECONDS)
			appear.tween_property(item, "modulate", Color.WHITE, NEW_ITEM_GLOW_SECONDS)
	_shown_count = lines.size()
	_struck_count = struck_count
