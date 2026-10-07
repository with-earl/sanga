extends Control
## "Ang Nangyari": what happened in the run just finished, written into the old open book. It lists
## the stories in the order they were played, the player's own choices in their own words, how each
## story ended, and any memory gained on the way.
##
## It only tells what this run did. Nothing here mentions the other choices, how many endings there
## are, or what else could have happened, so the player is left to find those by playing again. The
## last line says only that this was not the only way it could have gone.
##
## When the writing is longer than two pages, a tap turns to the next spread. After the last one, a
## tap goes on: to the card that puts the three stories in time order (the main timeline), or to
## the timeline chart (any other timeline).

const BOOK_PICTURE := preload("res://assets/ui/book_spread.png")
## Where the words go on the two pages, in the picture's own pixels (the same as the memory book).
const LEFT_PAGE := Rect2(78, 70, 380, 510)
const RIGHT_PAGE := Rect2(582, 70, 380, 510)
const BOOK_SCALE := 0.9
## Room kept free at the bottom of the screen for the "Tap anywhere to continue" note.
const NOTE_ROOM := 84.0
const BACKGROUND := Color(0.05, 0.03, 0.04, 1)
## Pen ink on paper, and the same ink faded for the quieter lines.
const INK := Color(0.2, 0.12, 0.07, 1.0)
const FADED_INK := Color(0.2, 0.12, 0.07, 0.6)
const TITLE := "Ang Nangyari"
const TITLE_SIZE := 34
const STORY_SIZE := 26
const TEXT_SIZE := 21
const SMALL_SIZE := 19
## Space between entries, and the extra space above each story's name.
const GAP := 10.0
const STORY_GAP := 14.0
## The book's last line. It admits there were other ways, without saying how many or which.
const CLOSING_LINE := "Ito ang nangyari. Hindi ito ang tanging maaaring mangyari."
const PAGE_TURN_SECONDS := 0.35
const OPEN_SECONDS := 0.6
const HINT_DELAY_SECONDS := 0.8

## A memory's line sits this close under its name, and the two always stay on the same page.
const UNDER_NAME_GAP := 2.0

## Each page's lines, as [text, size, colour, gap above, centred].
var _pages: Array = []
var _spread := 0
var _book := TextureRect.new()
var _left := VBoxContainer.new()
var _right := VBoxContainer.new()
var _hint: TapHint
var _waiting := false
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dark := ColorRect.new()
	dark.color = BACKGROUND
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	_font = get_theme_default_font()
	_book.texture = BOOK_PICTURE
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.size = BOOK_PICTURE.get_size()
	_book.scale = Vector2.ONE * BOOK_SCALE
	var room := Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y - NOTE_ROOM)
	_book.position = (room - BOOK_PICTURE.get_size() * BOOK_SCALE) / 2.0
	add_child(_book)
	for pair in [[_left, LEFT_PAGE], [_right, RIGHT_PAGE]]:
		var column: VBoxContainer = pair[0]
		column.position = (pair[1] as Rect2).position
		column.size = (pair[1] as Rect2).size
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_book.add_child(column)
	_hint = TapHint.make(self, StoryCard.SKIP_HINT)
	_pages = paginate(lines_for(StoryDirector.last_run_log), LEFT_PAGE.size.x, LEFT_PAGE.size.y)
	_show_spread()
	_book.modulate.a = 0.0
	_open.call_deferred()


## The lines the book writes for a run log (see GameState.run_log), in order, closing line last.
static func lines_for(run_log: Array) -> Array:
	var lines: Array = [[TITLE, TITLE_SIZE, INK, 0.0, false]]
	for entry in run_log:
		var moment: Dictionary = entry
		if moment.has("story"):
			lines.append([str(moment["story"]), STORY_SIZE, INK, STORY_GAP, false])
		elif moment.has("choice"):
			lines.append(["“%s”" % str(moment["choice"]), TEXT_SIZE, INK, GAP, false])
		elif moment.has("ending"):
			# The ending's own words say what happened; its card title is only a short name.
			var line := str(moment.get("line", ""))
			lines.append([line if line != "" else str(moment["ending"]), TEXT_SIZE, FADED_INK, GAP, false])
		elif moment.has("alaala"):
			var item := Alaala.info(str(moment["alaala"]))
			if not item.is_empty():
				lines.append(["%s%s" % [Alaala.MARK, item.get("name", "")], TEXT_SIZE, INK, GAP, false])
				lines.append([str(item.get("memory", "")), SMALL_SIZE, FADED_INK, UNDER_NAME_GAP, false])
	lines.append([CLOSING_LINE, TEXT_SIZE, INK, STORY_GAP * 2.0, true])
	return lines


## Splits the lines into pages `height` tall, measuring how many rows each wraps to at `width`.
## A memory's line that would start a new page takes its name along with it.
func paginate(lines: Array, width: float, height: float) -> Array:
	var pages: Array = [[]]
	var used := 0.0
	for line in lines:
		var page: Array = pages[-1]
		var gap: float = line[3] if not page.is_empty() else 0.0
		if not page.is_empty() and used + gap + _tall(line, width) > height:
			var carried: Array = []
			if float(line[3]) == UNDER_NAME_GAP and page.size() > 1:
				carried.append(page.pop_back())
			pages.append(carried)
			page = pages[-1]
			used = 0.0
			for kept in carried:
				used += _tall(kept, width)
			gap = 0.0 if carried.is_empty() else float(line[3])
		page.append(line)
		used += gap + _tall(line, width)
	return pages


func _tall(line: Array, width: float) -> float:
	return _font.get_multiline_string_size(str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, width, int(line[1])).y


func _show_spread() -> void:
	for pair in [[_left, _spread * 2], [_right, _spread * 2 + 1]]:
		var column: VBoxContainer = pair[0]
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
		if int(pair[1]) < _pages.size():
			for line in _pages[int(pair[1])]:
				column.add_child(_ink(line, column.get_child_count() == 0))


## One line of handwriting: dark ink, no outline, none of the retro blur.
func _ink(line: Array, first: bool) -> Label:
	var label := Label.new()
	label.add_to_group(&"crisp_text")
	label.text = str(line[0])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if line[4] else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", line[2])
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_font_size_override("font_size", int(line[1]))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The gap above sits inside the label as empty room, so a page's lines need no spacers.
	var gap: float = 0.0 if first else float(line[3])
	label.custom_minimum_size.y = gap + _tall(line, LEFT_PAGE.size.x)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _open() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_book, "modulate:a", 1.0, OPEN_SECONDS)
	await tween.finished
	await get_tree().create_timer(HINT_DELAY_SECONDS).timeout
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.6)
	_waiting = true


func _gui_input(event: InputEvent) -> void:
	if _waiting and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_waiting = false
		if (_spread + 1) * 2 < _pages.size():
			await _turn_page()
			_waiting = true
		else:
			_continue()


func _turn_page() -> void:
	var out := create_tween().set_trans(Tween.TRANS_SINE)
	out.tween_property(_left, "modulate:a", 0.0, PAGE_TURN_SECONDS / 2.0)
	out.parallel().tween_property(_right, "modulate:a", 0.0, PAGE_TURN_SECONDS / 2.0)
	await out.finished
	_spread += 1
	_show_spread()
	var back := create_tween().set_trans(Tween.TRANS_SINE)
	back.tween_property(_left, "modulate:a", 1.0, PAGE_TURN_SECONDS / 2.0)
	back.parallel().tween_property(_right, "modulate:a", 1.0, PAGE_TURN_SECONDS / 2.0)
	await back.finished


## The main timeline goes on to the card that puts the stories in time order; any other timeline
## goes on to the chart of the realities this save has made.
func _continue() -> void:
	create_tween().tween_property(_hint, "modulate:a", 0.0, 0.3)
	if StoryDirector.last_timeline == "main":
		StoryCard.show_time_order()
	else:
		StoryCard.fade_to_scene("timeline_reveal")
