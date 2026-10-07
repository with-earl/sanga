class_name JournalModal
extends Control
## A window for reading, opened from the icons at the top right of a place: the objectives (the
## clipboard) or the memories (the book). It looks like the settings window: the same soft 90s
## window, a heading with a close cross, and golden ochre text with a brown outline. Tapping
## outside it closes it.

const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const PADDING := 34.0
const WIDTH := 640.0
const DIM := Color(0.0, 0.0, 0.0, 0.45)
## Finished objectives stay listed, struck through and faded, so the player sees how far they are.
const FINISHED_ALPHA := 0.55
const NOTHING_YET := "Wala pang layunin."
const OBJECTIVES_TITLE := "Objectives"
const MEMORIES_TITLE := "Alaala"
## A memory the save does not hold yet keeps its place, unnamed, so the player knows there is more.
const UNKNOWN_NAME := "???"
const UNKNOWN_MEMORY := "Hindi mo pa ito naaalala."
const MEMORY_GAP := 18

var _title := Label.new()
var _count := Label.new()
var _list := VBoxContainer.new()
var _tween: Tween


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var padding := StyleBoxEmpty.new()
	padding.set_content_margin_all(PADDING)
	panel.add_theme_stylebox_override("panel", padding)
	panel.custom_minimum_size.x = WIDTH
	SoftWindow.behind(panel)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	UiSkin.style_label(_title, UiSkin.HEADING_SIZE)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	UiSkin.style_label(_count, UiSkin.TEXT_SIZE - 4)
	_count.modulate.a = 0.75
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_count)
	var close_button := IconButton.new()
	close_button.icon_kind = IconButton.Icon.CLOSE
	close_button.plain = true
	close_button.icon_scale = 0.5
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.theme_type_variation = &"TextButton"
	UiSkin.style_icon(close_button)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.pressed.connect(close)
	header.add_child(close_button)
	column.add_child(header)
	_list.add_theme_constant_override("separation", 10)
	column.add_child(_list)


## Lists the objectives, the first `struck_count` of them struck through.
func open_objectives(lines: PackedStringArray, struck_count: int) -> void:
	_start(OBJECTIVES_TITLE, "")
	if lines.is_empty():
		_list.add_child(_line(NOTHING_YET, UiSkin.TEXT_SIZE))
	for index in lines.size():
		var item := ObjectiveItem.new()
		UiSkin.style_label(item, UiSkin.TEXT_SIZE)
		item.text = lines[index]
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if index < struck_count:
			item.strike_amount = 1.0
			item.modulate.a = FINISHED_ALPHA
		_list.add_child(item)
	_show()


## Lists every memory: the ones this save holds by name with their line, the rest unnamed.
func open_memories() -> void:
	var all := Alaala.all()
	var held := 0
	for item in all:
		if Alaala.has(str(item.get("id", ""))):
			held += 1
	_start(MEMORIES_TITLE, "%d / %d" % [held, all.size()])
	_list.add_theme_constant_override("separation", MEMORY_GAP)
	for item in all:
		var known := Alaala.has(str(item.get("id", "")))
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		var name_label := _line(str(item.get("name", "")) if known else UNKNOWN_NAME, UiSkin.TEXT_SIZE)
		entry.add_child(name_label)
		var memory := _line(str(item.get("memory", "")) if known else UNKNOWN_MEMORY, UiSkin.TEXT_SIZE - 4)
		memory.modulate.a = 0.8 if known else 0.5
		entry.add_child(memory)
		if not known:
			name_label.modulate.a = 0.5
		_list.add_child(entry)
	_show()


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	await _fade(0.0, CLOSE_SECONDS)
	visible = false


func _start(title: String, count: String) -> void:
	_title.text = title
	_count.text = count
	_list.add_theme_constant_override("separation", 10)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func _show() -> void:
	visible = true
	_fade(1.0, OPEN_SECONDS)


func _line(text: String, font_size: int) -> Label:
	var label := Label.new()
	UiSkin.style_label(label, font_size)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _fade(alpha: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", alpha, seconds)
	await _tween.finished
