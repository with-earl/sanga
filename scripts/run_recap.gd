extends Control
## "Ang Nangyari": what happened in the run just finished, written into the old open book. It lists
## the stories in the order they were played, the player's own choices in their own words, the
## moments those choices came back later in the run (marked ↳), how each story ended, and any
## memory gained on the way.
##
## It only tells what this run did. Nothing here mentions the other choices, how many endings there
## are, or what else could have happened, so the player is left to find those by playing again. The
## last line says only that this was not the only way it could have gone.
##
## When the writing is longer than two pages, a tap turns to the next spread. After the last one,
## "Ayusin ayon sa oras": the ink fades and the run is written again in true time order (Kumpisal
## the past, Padala the present, Tokhang the future), and red threads draw themselves from each cause
## to its effect (see TimeThreads). A last tap goes on: to the main screen (the main timeline) or
## to the timeline chart (any other timeline).

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
## The time-order pages: their title, and the red thread that joins a cause to its effect.
const TIME_TITLE := "Ayon sa Oras"
const THREAD_COLOR := Color(0.62, 0.09, 0.1, 0.85)
const THREAD_WIDTH := 3.0
const KNOT_RADIUS := 5.0
## Threads run down the page margins (or the gutter between the pages), each in its own lane so
## none lie on top of another, turning neat rounded corners. How long each takes to draw.
const LANE_START := 16.0
const LANE_GAP := 9.0
const CORNER := 10.0
const THREAD_SECONDS := 0.8
const THREAD_PAUSE_SECONDS := 0.25
const REORDER_SECONDS := 0.45
## After any ending but the true one, the voice from the confessional speaks once more.
const TRUE_ENDING := "padala_walang_namatay"
const VOICE_PICTURE := "res://assets/cutscenes/prologue_booth.png"

## Each page's lines, as [text, size, colour, gap above, centred].
var _pages: Array = []
var _spread := 0
var _book := TextureRect.new()
var _left := VBoxContainer.new()
var _right := VBoxContainer.new()
var _hint: TapHint
var _waiting := false
var _font: Font
## True once the pages show the run in time order, with its threads.
var _in_time := false
var _threads: Array = []
var _thread_layer := Node2D.new()


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
	_book.add_child(_thread_layer)
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
		elif moment.has("echo"):
			# An earlier choice coming back, quoted as a reply under the story it reached.
			lines.append(["↳ %s: %s" % [moment.get("speaker", ""), moment["echo"]], SMALL_SIZE, FADED_INK, UNDER_NAME_GAP + 4.0, false])
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


## The time-order pages: each story of the run under its place in time, keeping only the moments
## a thread joins and each story's ending, so cause and effect stand out. Each line also carries the
## run-log position of its moment, so its thread can find it.
static func lines_in_time(run_log: Array, threads: Array) -> Array:
	var linked := {}
	for pair in threads:
		linked[pair[0]] = true
		linked[pair[1]] = true
	var lines: Array = [[TIME_TITLE, TITLE_SIZE, INK, 0.0, false, -1]]
	for section in TimeThreads.sections(run_log):
		var story := str(section["story"])
		var when: int = TimeThreads.STORY_TIME.get(story, 0)
		lines.append(["%s · %s" % [story, TimeThreads.TIME_WORDS[when]], STORY_SIZE, INK, STORY_GAP, false, -1])
		for index in section["moments"]:
			var moment: Dictionary = run_log[index]
			if moment.has("ending"):
				var words := str(moment.get("line", ""))
				lines.append([words if words != "" else str(moment["ending"]), TEXT_SIZE, FADED_INK, GAP, false, index])
			elif linked.has(index) and moment.has("choice"):
				lines.append(["“%s”" % str(moment["choice"]), TEXT_SIZE, INK, GAP, false, index])
			elif linked.has(index) and moment.has("echo"):
				lines.append(["↳ %s: %s" % [moment.get("speaker", ""), moment["echo"]], SMALL_SIZE, FADED_INK, UNDER_NAME_GAP + 4.0, false, index])
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
				var label := _ink(line, column.get_child_count() == 0)
				label.set_meta(&"line", line)
				column.add_child(label)


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
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_hint, "modulate:a", 1.0, 0.6)
	_waiting = true


func _gui_input(event: InputEvent) -> void:
	if _waiting and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_waiting = false
		if (_spread + 1) * 2 < _pages.size():
			await _turn_page()
			_waiting = true
		elif not _in_time:
			await _put_in_time_order()
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
	_clear_threads()
	var back := create_tween().set_trans(Tween.TRANS_SINE)
	back.tween_property(_left, "modulate:a", 1.0, PAGE_TURN_SECONDS / 2.0)
	back.parallel().tween_property(_right, "modulate:a", 1.0, PAGE_TURN_SECONDS / 2.0)
	await back.finished
	if _in_time:
		await _draw_threads()


## The ink fades, the run is written again in time order, and the threads draw themselves.
func _put_in_time_order() -> void:
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_hint, "modulate:a", 0.0, 0.3)
	var out := create_tween().set_trans(Tween.TRANS_SINE).set_parallel(true)
	out.tween_property(_left, "modulate:a", 0.0, REORDER_SECONDS)
	out.tween_property(_right, "modulate:a", 0.0, REORDER_SECONDS)
	await out.finished
	var run_log: Array = StoryDirector.last_run_log
	_threads = TimeThreads.threads(run_log)
	_pages = paginate(lines_in_time(run_log, _threads), LEFT_PAGE.size.x, LEFT_PAGE.size.y)
	_spread = 0
	_in_time = true
	_show_spread()
	var back := create_tween().set_trans(Tween.TRANS_SINE).set_parallel(true)
	back.tween_property(_left, "modulate:a", 1.0, REORDER_SECONDS)
	back.tween_property(_right, "modulate:a", 1.0, REORDER_SECONDS)
	await back.finished
	await _draw_threads()
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_hint, "modulate:a", 1.0, 0.6)


func _clear_threads() -> void:
	for child in _thread_layer.get_children():
		child.queue_free()


## Draws, one after another, each thread whose two ends are on this spread: from the cause, along
## a lane in the margin (or, from the left page to the right, in the gutter), into its effect, with
## a small knot at each end.
func _draw_threads() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ends := {}
	for column in [_left, _right]:
		for label in (column as VBoxContainer).get_children():
			var line: Array = label.get_meta(&"line", [])
			if line.size() > 5 and int(line[5]) >= 0:
				ends[int(line[5])] = _anchor(label as Label, line, column as Control)
	var lanes := {"left": 0, "right": 0, "gutter": 0}
	for pair in _threads:
		if not (ends.has(pair[0]) and ends.has(pair[1])):
			continue
		var cause: Dictionary = ends[pair[0]]
		var effect: Dictionary = ends[pair[1]]
		var points: Array
		if cause["column"] == effect["column"]:
			# Down the margin beside the page's writing.
			var side := "left" if cause["column"] == _left else "right"
			var lane: float = cause["margin"].x - (lanes[side] + 1) * LANE_GAP
			lanes[side] += 1
			points = _route(cause["margin"], effect["margin"], lane)
		else:
			# From the end of the cause's words, down the gutter, into the effect's margin.
			var lane: float = LEFT_PAGE.end.x + LANE_START + lanes["gutter"] * LANE_GAP
			lanes["gutter"] += 1
			points = _route(cause["after"], effect["margin"], lane)
		await _draw_thread(points)
		await get_tree().create_timer(THREAD_PAUSE_SECONDS).timeout


## Where a thread can meet a line, at the height of its first row: in the margin just before it,
## and just past the end of its words.
func _anchor(label: Label, line: Array, column: Control) -> Dictionary:
	var top := column.position.y + label.position.y + label.size.y - _tall(line, LEFT_PAGE.size.x)
	var width := minf(_font.get_string_size(str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1])).x, LEFT_PAGE.size.x)
	var y := top + _font.get_height(int(line[1])) * 0.55
	return {"column": column, "margin": Vector2(column.position.x - LANE_START * 0.5, y), "after": Vector2(column.position.x + width + 8.0, y)}


## A path from `a` across to the lane at `lane_x`, along it, and across to `b`, with rounded corners.
func _route(a: Vector2, b: Vector2, lane_x: float) -> Array:
	var down := signf(b.y - a.y) if b.y != a.y else 1.0
	var r := minf(CORNER, absf(b.y - a.y) / 2.0)
	var out: Array = [a]
	out.append_array(_corner(Vector2(lane_x, a.y), signf(lane_x - a.x), down, r))
	out.append_array(_corner(Vector2(lane_x, b.y), down, signf(b.x - lane_x), r, true))
	out.append(b)
	return out


## Points rounding a right-angle corner at `at`: coming in going `first` (sideways, or down when
## `vertical_first`), leaving going `second`.
func _corner(at: Vector2, first: float, second: float, r: float, vertical_first := false) -> Array:
	var points: Array = []
	for i in 7:
		var t := i / 6.0
		var p := Vector2.ZERO
		if vertical_first:
			# Coming down (or up) the lane, turning out sideways.
			var start := at - Vector2(0, first * r)
			var finish := at + Vector2(second * r, 0)
			p = start.lerp(at, t).lerp(at.lerp(finish, t), t)
		else:
			var start := at - Vector2(first * r, 0)
			var finish := at + Vector2(0, second * r)
			p = start.lerp(at, t).lerp(at.lerp(finish, t), t)
		points.append(p)
	return points


func _draw_thread(curve: Array) -> void:
	_thread_layer.add_child(_knot(curve[0]))
	var thread := Line2D.new()
	thread.width = THREAD_WIDTH
	thread.default_color = THREAD_COLOR
	thread.joint_mode = Line2D.LINE_JOINT_ROUND
	thread.begin_cap_mode = Line2D.LINE_CAP_ROUND
	thread.end_cap_mode = Line2D.LINE_CAP_ROUND
	thread.antialiased = true
	_thread_layer.add_child(thread)
	var grow := func(amount: float) -> void:
		var shown := maxi(int(amount * (curve.size() - 1)) + 1, 2)
		thread.points = PackedVector2Array(curve.slice(0, shown))
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(grow, 0.0, 1.0, THREAD_SECONDS)
	await tween.finished
	_thread_layer.add_child(_knot(curve[-1]))


func _knot(at: Vector2) -> Polygon2D:
	var knot := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 12:
		points.append(at + Vector2.from_angle(TAU * i / 12.0) * KNOT_RADIUS)
	knot.polygon = points
	knot.color = THREAD_COLOR
	return knot


## The main timeline goes back to the main screen (the book has just shown its time order); any
## other timeline goes on to the chart of the realities this save has made.
func _continue() -> void:
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_hint, "modulate:a", 0.0, 0.3)
	if TRUE_ENDING not in StoryDirector.last_reality.get("needs", []):
		# The voice from the confessional, over black: the confession is not over yet.
		await Cutscene.play([{"image": VOICE_PICTURE, "lines": [StoryDirector.more_to_tell()]}])
		Cutscene.hand_over()
	if StoryDirector.last_timeline == "main":
		StoryCard.fade_to_scene("main_menu")
	else:
		StoryCard.fade_to_scene("timeline_reveal")
