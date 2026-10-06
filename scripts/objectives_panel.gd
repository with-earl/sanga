class_name ObjectivesPanel
extends Control
## Top-right objective list: a heading, a thin line, then one right-aligned line per objective.
## Finished objectives have a line struck through them.

const STRIKE_SECONDS := 0.35
const NEW_ITEM_FADE_SECONDS := 0.3

@onready var _list: VBoxContainer = %List

var _shown_count := 0
var _struck_count := 0


## Shows the given objectives. The first `struck_count` of them are finished and struck through.
## With `animate`, the ones that have just been finished draw their line in, and a new line fades
## in, starting after `delay` seconds.
func set_objectives(lines: PackedStringArray, struck_count := 0, animate := false, delay := 0.0) -> void:
	for child in _list.get_children():
		child.queue_free()
	visible = not lines.is_empty()
	for index in lines.size():
		var item := ObjectiveItem.new()
		item.theme_type_variation = &"HudBody"
		item.text = lines[index]
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.size_flags_horizontal = Control.SIZE_FILL
		_list.add_child(item)
		var finished := index < struck_count
		var just_finished := finished and index >= _struck_count
		var is_new := index >= _shown_count
		if animate and just_finished:
			item.strike_amount = 0.0
			create_tween().tween_property(item, "strike_amount", 1.0, STRIKE_SECONDS) \
				.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		elif finished:
			item.strike_amount = 1.0
		if animate and is_new:
			item.modulate.a = 0.0
			create_tween().tween_property(item, "modulate:a", 1.0, NEW_ITEM_FADE_SECONDS) \
				.set_delay(delay + STRIKE_SECONDS)
	_shown_count = lines.size()
	_struck_count = struck_count
