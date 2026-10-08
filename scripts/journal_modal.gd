class_name JournalModal
extends Control
## The windows opened from the icons at the top right of a place. Each looks like its icon, opened
## up: the memories (Alaala) are written across the two pages of an old open book, and the
## objectives are a checklist on the paper of a clipboard. The words are dark ink, like handwriting
## on paper. Tapping outside closes the window; a note at the bottom of the screen says so.

const OPEN_SECONDS := 0.15
const CLOSE_SECONDS := 0.12
const DIM := Color(0.0, 0.0, 0.0, 0.5)
const BOOK_PICTURE := preload("res://assets/ui/book_spread.png")
const CLIPBOARD_PICTURE := preload("res://assets/ui/clipboard_board.png")
## Where the words go on each picture, in its own pixels: the two pages, and the clipboard's paper.
const LEFT_PAGE := Rect2(78, 70, 380, 510)
const RIGHT_PAGE := Rect2(582, 70, 380, 510)
const PAPER := Rect2(126, 124, 440, 520)
## The paper's ruled lines are this far apart (see draw_props.py), and each line of writing sits
## on one of them.
const RULE_GAP := 46.0
## The book and clipboard are drawn a little smaller, so they fit above the note at the bottom.
const BOOK_SCALE := 0.9
const CLIPBOARD_SCALE := 0.86
## Room kept free at the bottom of the screen for the "Tap outside to close" note under the book.
const NOTE_ROOM := 64.0
## Pen ink on paper, and the same ink faded for what is done or not yet known.
const INK := Color(0.2, 0.12, 0.07, 1.0)
const FADED_INK := Color(0.2, 0.12, 0.07, 0.45)
const TITLE_SIZE := 34
const TEXT_SIZE := 24
const SMALL_SIZE := 20
## The checkbox before each objective, drawn a little larger than the words so it reads as a box.
const BOX_SIZE := 36
const NOTHING_YET := "Wala pang layunin."
const OBJECTIVES_TITLE := "Objectives"
const MEMORIES_TITLE := "Alaala"
## Shown in the book before the player remembers anything.
const NOTHING_REMEMBERED := "Wala ka pang naaalala."
## How many memories are written on the left page; the rest go on the right.
const LEFT_PAGE_MEMORIES := 2

var _holder := Control.new()
## The "Tap outside to close" note, kept right under whatever is open.
var _hint: Label
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
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_hint = UiSkin.add_close_hint(self)


## The objectives as a checklist on the clipboard, finished ones ticked and struck through.
func open_objectives(lines: PackedStringArray, struck_count: int) -> void:
	var board := _start(CLIPBOARD_PICTURE, CLIPBOARD_SCALE)
	var paper := _area(board, PAPER)
	paper.add_theme_constant_override("separation", 0)
	var title := _ink(OBJECTIVES_TITLE, TITLE_SIZE, INK)
	_sit_on_rule(title)
	paper.add_child(title)
	if lines.is_empty():
		var nothing := _ink(NOTHING_YET, TEXT_SIZE, FADED_INK)
		_sit_on_rule(nothing)
		paper.add_child(nothing)
	for index in lines.size():
		var done := index < struck_count
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var box := _ink("☑" if done else "☐", BOX_SIZE, FADED_INK if done else INK)
		_sit_on_rule(box)
		row.add_child(box)
		var item := ObjectiveItem.new()
		_style_ink(item, TEXT_SIZE, FADED_INK if done else INK)
		item.text = lines[index]
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sit_on_rule(item)
		item.line_color = FADED_INK
		item.line_outline = Color.TRANSPARENT
		item.strike_amount = 1.0 if done else 0.0
		row.add_child(item)
		paper.add_child(row)
	_show()


## The memories this save holds, across the two pages of the open book, each by name with its
## line. Memories not reached yet are never mentioned, not even as a count, so nothing gives away
## how many there are.
func open_memories() -> void:
	var book := _start(BOOK_PICTURE, BOOK_SCALE)
	var left := _area(book, LEFT_PAGE)
	var right := _area(book, RIGHT_PAGE)
	left.add_child(_ink(MEMORIES_TITLE, TITLE_SIZE, INK))
	var held: Array = []
	for item in Alaala.all():
		if Alaala.has(str(item.get("id", ""))):
			held.append(item)
	if held.is_empty():
		left.add_child(_ink(NOTHING_REMEMBERED, SMALL_SIZE, FADED_INK))
	for index in held.size():
		var item: Dictionary = held[index]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		entry.add_child(_ink(str(item.get("name", "")), TEXT_SIZE, INK))
		var memory := _ink(str(item.get("memory", "")), SMALL_SIZE, INK)
		memory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(memory)
		# Where the memory matters, faintly, so it can be followed without being spelled out.
		if str(item.get("hint", "")) != "":
			var hint := _ink("↳ " + str(item["hint"]), SMALL_SIZE, FADED_INK)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entry.add_child(hint)
		(left if index < LEFT_PAGE_MEMORIES else right).add_child(entry)
	_show()


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	await _fade(0.0, CLOSE_SECONDS)
	visible = false


## Clears the window and lays down the picture it is written on, centred on the screen.
func _start(picture: Texture2D, scale_by: float) -> TextureRect:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()
	var screen := get_viewport_rect().size
	var shown := TextureRect.new()
	shown.texture = picture
	shown.mouse_filter = Control.MOUSE_FILTER_STOP
	shown.size = picture.get_size()
	shown.scale = Vector2.ONE * scale_by
	var room := Vector2(screen.x, screen.y - NOTE_ROOM)
	shown.position = (room - picture.get_size() * scale_by) / 2.0
	_holder.add_child(shown)
	UiSkin.keep_hint_below(_hint, shown)
	return shown


## A column for words over part of the picture.
func _area(picture: TextureRect, rect: Rect2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.position = rect.position
	column.size = rect.size
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(column)
	return column


## Makes a line of writing exactly one ruled line tall, resting on the line below it.
func _sit_on_rule(label: Label) -> void:
	label.custom_minimum_size.y = RULE_GAP
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


func _ink(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	_style_ink(label, font_size, color)
	label.text = text
	return label


## Dark ink on paper: no outline, and none of the retro blur the HUD text has.
func _style_ink(label: Label, font_size: int, color: Color) -> void:
	label.add_to_group(&"crisp_text")
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show() -> void:
	visible = true
	_fade(1.0, OPEN_SECONDS)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _fade(alpha: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", alpha, seconds)
	await _tween.finished
