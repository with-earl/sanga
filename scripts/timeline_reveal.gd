extends Control
## Closes a run on an alternate timeline. The timeline diagram starts zoomed far in on the run's
## first card, and a glowing green line travels the path this run took, card to card, with the
## view following it. Then the view pulls back to show every reality this save has made.
##
## Only what the player has finished is shown: a timeline, branch or ending they have not reached
## never appears, and the cards are packed together with no gaps where others would go, so the
## diagram never gives away how much else is possible. The layout follows the
## timelines chart (story/timelines.json). A tap afterwards returns to the main screen.
##
## The diagram is built from nodes, not drawn into a picture: each card is a Panel with a flat
## rounded border and Labels, and each connection is a Line2D, so text, borders and lines all stay
## sharp at every zoom, including the close-up at the start. Nothing blurs this screen: it has no
## retro text shader and no screen vignette.

## Sized to stay readable on a phone even when the whole diagram is in view.
const COLUMN_WIDTH := 280.0
const ROW_HEIGHT := 132.0
const CARD_SIZE := Vector2(224, 104)
const SECTION_TITLE_GAP := 80.0
## Rows of space between one shown timeline and the next.
const SECTION_GAP_ROWS := 0.6
const TITLE_SIZE := 21
const LINE_SIZE := 16
const SECTION_SIZE := 26
const CARD_PADDING := 12.0
const CARD_BORDER := 2
const CARD_RADIUS := 12
const LINE_GAP := 4
## Text is laid out this many times larger than it appears and then scaled down, so it is already
## sharp in the close-up at START_ZOOM, and smoothed (with mipmaps) when the view pulls back.
const TEXT_DETAIL := 3.4

## A deep plum night sky, darker toward the bottom, in the colours of the game's windows.
const BACKGROUND_TOP := Color(0.14, 0.08, 0.12, 1)
const BACKGROUND_BOTTOM := Color(0.03, 0.02, 0.035, 1)
const CARD_FILL := Color(0.17, 0.1, 0.14, 0.95)
const PAST_LINE := Color(1, 1, 1, 0.32)
const PAST_LINE_WIDTH := 2.0
const GLOW_CORE := Color(0.62, 1.0, 0.66, 1)
const GLOW_INNER := Color(0.3, 0.95, 0.42, 0.35)
const GLOW_OUTER := Color(0.2, 0.9, 0.35, 0.14)
## The glowing line: a wide soft band, a narrower one, and a bright core, widest first.
const GLOW_LAYERS := [[GLOW_OUTER, 16.0], [GLOW_INNER, 8.0], [GLOW_CORE, 2.5]]
const GLOW_HEAD_RADIUS := 5.0
## A card on this run's path glows green around its border once the line reaches it.
const CARD_GLOW := Color(0.3, 0.95, 0.42, 0.45)
const CARD_GLOW_SIZE := 7
const TEXT := Color(1.0, 0.953, 0.839, 1)
const LINE_TEXT := Color(0.86, 0.82, 0.76, 1)
## Timeline names are golden ochre, like the game's headings.
const SECTION_TEXT := Color(0.851, 0.643, 0.255, 1)
## The chart's legend colours, by kind of card.
const KIND_COLORS := {
	"story": Color(0.78, 0.78, 0.78, 1),
	"lives": Color(0.5, 0.85, 0.5, 1),
	"suffers": Color(0.93, 0.78, 0.38, 1),
	"dies": Color(0.93, 0.45, 0.45, 1),
	"someone_dies": Color(0.7, 0.6, 0.98, 1),
}
const BODY_WEIGHT := 400.0
const TITLE_WEIGHT := 600.0
## OpenType tag of the font's weight axis ("wght").
const WEIGHT_AXIS := 2003265652

const START_ZOOM := 3.4
const OPENING_HOLD_SECONDS := 0.9
## How fast the glowing line travels, in diagram units per second.
const TRAVEL_SPEED := 300.0
const ARRIVAL_HOLD_SECONDS := 0.8
const ZOOM_OUT_SECONDS := 2.2
const FIT_MARGIN := 44.0
## Room kept free under the diagram for the "Tap anywhere to continue" note.
const HINT_ROOM := 84.0
## When everything fits with room to spare, the pulled-back view may stay this much larger, so a
## save with only one or two endings still reads comfortably.
const MAX_FIT_ZOOM := 1.5
const HINT_DELAY_SECONDS := 0.6

## A Node2D, not a Control: a Control is only drawn while its own rectangle is on screen, and the
## diagram's origin leaves the screen while the view is zoomed in on the route.
var _diagram := Node2D.new()
var _edge_layer := Node2D.new()
var _glow_layer := Node2D.new()
var _card_layer := Node2D.new()
var _glow_lines: Array[Line2D] = []
var _glow_head := Polygon2D.new()
var _hint: TapHint
var _nodes: Dictionary = {}
var _sections: Dictionary = {}
## Card id to its centre, in diagram units, for the cards being shown.
var _centers: Dictionary = {}
## Card id to its Panel, for the cards being shown.
var _cards: Dictionary = {}
## Connections already drawn, so a connection several realities share is drawn once.
var _drawn_edges: Dictionary = {}
## For each shown timeline, the rows its reached cards use, packed together from 0, by the row the
## chart gives them. A branch not reached leaves no gap.
var _packed_rows: Dictionary = {}
var _shown_sections: Array = []
## Where each shown timeline starts, in rows. Shown timelines are stacked with no gap for the ones
## not finished yet.
var _section_rows: Dictionary = {}
## This run's route as one point list, and how far along it the glow has travelled.
var _route := PackedVector2Array()
var _route_length := 0.0
var _travelled := 0.0
var _reached: Array = []
var _new_path: Array = []
var _body_font: Font
var _title_font: Font
var _waiting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, BACKGROUND_TOP)
	gradient.set_color(1, BACKGROUND_BOTTOM)
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = gradient
	sky_texture.fill_from = Vector2(0, 0)
	sky_texture.fill_to = Vector2(0, 1)
	sky_texture.width = 4
	sky_texture.height = 128
	sky.texture = sky_texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	_make_fonts()
	_diagram.add_child(_edge_layer)
	_diagram.add_child(_glow_layer)
	_diagram.add_child(_card_layer)
	add_child(_diagram)
	_build_glow()
	_hint = TapHint.make(self, StoryCard.SKIP_HINT)
	_build()
	_play.call_deferred()


## The game font at a regular and a semi-bold weight. A copy with mipmaps, so the large text
## stays smooth when it is scaled down, without changing the rest of the game's text.
func _make_fonts() -> void:
	var base: Font = get_theme_default_font()
	if base is FontVariation:
		base = (base as FontVariation).base_font
	if base is FontFile:
		var smooth := (base as FontFile).duplicate() as FontFile
		smooth.generate_mipmaps = true
		base = smooth
	_card_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_body_font = _weighted(base, BODY_WEIGHT)
	_title_font = _weighted(base, TITLE_WEIGHT)


func _weighted(base: Font, weight: float) -> Font:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {WEIGHT_AXIS: weight}
	return font


func _build() -> void:
	var map := TimelineMap.data()
	_nodes = map.get("nodes", {})
	_sections = map.get("sections", {})
	var realities := TimelineMap.realities_with(GameState.realities)
	for reality in realities:
		for id in reality.get("path", []):
			var section := str(_nodes[id].get("section", ""))
			if section not in _shown_sections:
				_shown_sections.append(section)
	_pack_rows(realities)
	_stack_sections()
	for reality in realities:
		var path: Array = reality.get("path", [])
		for id in path:
			if not _centers.has(id):
				_centers[id] = _center_of(id)
		for index in range(path.size() - 1):
			_add_edge(path[index], path[index + 1], PAST_LINE)
	for section in _shown_sections:
		_add_section_title(section)
	for id in _centers:
		_add_card(id)
	_new_path = StoryDirector.last_reality.get("path", [])
	if TimelineMap.key_of(StoryDirector.last_reality) not in GameState.realities:
		_new_path = []
	for index in range(_new_path.size() - 1):
		var edge := _edge(_new_path[index], _new_path[index + 1])
		if _route.is_empty():
			_route.append_array(edge)
		else:
			_route.append_array(edge.slice(1))
	for index in range(1, _route.size()):
		_route_length += _route[index - 1].distance_to(_route[index])


## Places the shown timelines one under another, in the chart's order, each as tall as its cards.
func _stack_sections() -> void:
	_shown_sections.sort_custom(func(a: String, b: String) -> bool:
		return float(_sections.get(a, {}).get("row", 0.0)) < float(_sections.get(b, {}).get("row", 0.0)))
	var next_row := 0.0
	for section in _shown_sections:
		_section_rows[section] = next_row
		var last_row := float((_packed_rows.get(section, {}) as Dictionary).size() - 1)
		next_row += maxf(last_row, 0.0) + 1.0 + SECTION_GAP_ROWS


## A timeline's first row: where it is stacked, or its place in the chart if it is not shown.
func _section_row(section: String) -> float:
	return float(_section_rows.get(section, _sections.get(section, {}).get("row", 0.0)))


## Gives the rows the reached cards of each timeline use new numbers, 0, 1, 2 and on, in the
## chart's order, so the rows of branches not reached do not leave gaps.
func _pack_rows(realities: Array) -> void:
	var used: Dictionary = {}
	for reality in realities:
		for id in reality.get("path", []):
			var section := str(_nodes[id].get("section", ""))
			if not used.has(section):
				used[section] = {}
			used[section][float(_nodes[id].get("row", 0.0))] = true
	for section in used:
		var rows: Array = (used[section] as Dictionary).keys()
		rows.sort()
		var packed := {}
		for index in rows.size():
			packed[rows[index]] = float(index)
		_packed_rows[section] = packed


func _center_of(id: String) -> Vector2:
	var card: Dictionary = _nodes[id]
	var section := str(card.get("section", ""))
	var chart_row := float(card.get("row", 0.0))
	var row := _section_row(section) + float((_packed_rows.get(section, {}) as Dictionary).get(chart_row, chart_row))
	return Vector2(float(card.get("col", 0.0)) * COLUMN_WIDTH, row * ROW_HEIGHT + SECTION_TITLE_GAP)


## From the right edge of one card to the left edge of the next, with a right-angled bend halfway,
## as in the chart.
func _edge(from_id: String, to_id: String) -> PackedVector2Array:
	var start: Vector2 = _centers.get(from_id, _center_of(from_id)) + Vector2(CARD_SIZE.x / 2.0, 0)
	var end: Vector2 = _centers.get(to_id, _center_of(to_id)) - Vector2(CARD_SIZE.x / 2.0, 0)
	var bend := (start.x + end.x) / 2.0
	return PackedVector2Array([start, Vector2(bend, start.y), Vector2(bend, end.y), end])


## A connection between two cards, drawn once even when several realities share it.
func _add_edge(from_id: String, to_id: String, color: Color) -> void:
	var key := from_id + ">" + to_id
	if _drawn_edges.has(key):
		return
	_drawn_edges[key] = true
	_add_line(_edge_layer, _edge(from_id, to_id), color, PAST_LINE_WIDTH)


func _add_line(layer: Node2D, points: PackedVector2Array, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.default_color = color
	line.width = width
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	layer.add_child(line)
	return line


## The green line and the dot at its head. Their points are set as the line travels.
func _build_glow() -> void:
	for layer in GLOW_LAYERS:
		_glow_lines.append(_add_line(_glow_layer, PackedVector2Array(), layer[0], layer[1]))
	var dot := PackedVector2Array()
	for step in 24:
		dot.append(Vector2.from_angle(TAU * step / 24.0) * GLOW_HEAD_RADIUS)
	_glow_head.polygon = dot
	_glow_head.color = GLOW_CORE
	_glow_head.antialiased = true
	_glow_head.visible = false
	_glow_layer.add_child(_glow_head)


func _add_section_title(section: String) -> void:
	var title := _label(str(_sections[section].get("title", "")), _title_font, SECTION_SIZE, SECTION_TEXT)
	title.position = _section_title_position(section) - Vector2(0, _title_font.get_ascent(SECTION_SIZE))
	_card_layer.add_child(title)


## A card: a rounded box in the colour of its kind, its title, and a short line under it.
func _add_card(id: String) -> void:
	var card: Dictionary = _nodes[id]
	var kind := str(card.get("kind", "story"))
	if not KIND_COLORS.has(kind):
		kind = "story"
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = CARD_SIZE
	panel.position = (_centers[id] as Vector2) - CARD_SIZE / 2.0
	panel.add_theme_stylebox_override("panel", _card_style(kind, false))
	var inner_width := CARD_SIZE.x - CARD_PADDING * 2.0
	var title_color: Color = TEXT if kind == "story" else KIND_COLORS[kind]
	var title := _label(str(card.get("title", "")), _title_font, TITLE_SIZE, title_color, inner_width)
	title.position = Vector2(CARD_PADDING, CARD_PADDING)
	var line := _label(str(card.get("line", "")), _body_font, LINE_SIZE, LINE_TEXT, inner_width)
	line.position = title.position + Vector2(0, _title_font.get_height(TITLE_SIZE) + LINE_GAP)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.max_lines_visible = 3
	for label in [title, line]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
	panel.set_meta("kind", kind)
	_card_layer.add_child(panel)
	_cards[id] = panel


## A label that looks `font_size` big, laid out TEXT_DETAIL times larger and scaled down. With a
## `width`, it is that wide (in diagram units) for centring and wrapping.
func _label(text: String, font: Font, font_size: int, color: Color, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.scale = Vector2.ONE / TEXT_DETAIL
	if width > 0.0:
		label.custom_minimum_size.x = width * TEXT_DETAIL
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", roundi(font_size * TEXT_DETAIL))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _card_style(kind: String, glowing: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_FILL
	style.border_color = KIND_COLORS[kind]
	style.set_border_width_all(CARD_BORDER)
	style.set_corner_radius_all(CARD_RADIUS)
	style.anti_aliasing = true
	if glowing:
		style.shadow_color = CARD_GLOW
		style.shadow_size = CARD_GLOW_SIZE
	return style


func _play() -> void:
	if _route.is_empty():
		_view_all(0.0)
		await _finish()
		return
	_look_at(_route[0], START_ZOOM)
	_light_card(_new_path[0])
	await get_tree().create_timer(OPENING_HOLD_SECONDS).timeout
	var travel := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_method(_set_travelled, 0.0, _route_length, _route_length / TRAVEL_SPEED)
	await travel.finished
	await get_tree().create_timer(ARRIVAL_HOLD_SECONDS).timeout
	_view_all(ZOOM_OUT_SECONDS)
	await get_tree().create_timer(ZOOM_OUT_SECONDS).timeout
	await _finish()


func _finish() -> void:
	await get_tree().create_timer(HINT_DELAY_SECONDS).timeout
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.6)
	_waiting = true


func _gui_input(event: InputEvent) -> void:
	if _waiting and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_waiting = false
		StoryCard.fade_to_scene("main_menu")


func _set_travelled(value: float) -> void:
	_travelled = value
	var head := _point_along(value)
	_look_at(head, START_ZOOM)
	# A card lights up once the line reaches its left edge.
	for id in _new_path:
		if id not in _reached and head.x >= (_centers[id] as Vector2).x - CARD_SIZE.x / 2.0 - 1.0 and absf(head.y - (_centers[id] as Vector2).y) < 1.0:
			_light_card(id)
	_update_glow()


func _light_card(id: String) -> void:
	_reached.append(id)
	var panel: Panel = _cards[id]
	panel.add_theme_stylebox_override("panel", _card_style(str(panel.get_meta("kind")), true))


## Shows the green line as far as it has travelled, with the dot at its head.
func _update_glow() -> void:
	var points := PackedVector2Array([_route[0]])
	var left := _travelled
	for index in range(1, _route.size()):
		var piece := _route[index - 1].distance_to(_route[index])
		if left <= piece:
			points.append(_route[index - 1].lerp(_route[index], left / maxf(piece, 0.001)))
			break
		points.append(_route[index])
		left -= piece
	for line in _glow_lines:
		line.points = points
	_glow_head.position = points[points.size() - 1]
	_glow_head.visible = _travelled > 0.0


func _point_along(distance: float) -> Vector2:
	var left := distance
	for index in range(1, _route.size()):
		var piece := _route[index - 1].distance_to(_route[index])
		if left <= piece:
			return _route[index - 1].lerp(_route[index], left / maxf(piece, 0.001))
		left -= piece
	return _route[_route.size() - 1]


## Centres the view on `point` at `zoom`.
func _look_at(point: Vector2, zoom: float) -> void:
	_diagram.scale = Vector2(zoom, zoom)
	_diagram.position = size / 2.0 - point * zoom


## Pulls back until every shown card and section title fits on screen.
func _view_all(seconds: float) -> void:
	var bounds := Rect2()
	var first := true
	for id in _centers:
		var card := Rect2(_centers[id] - CARD_SIZE / 2.0, CARD_SIZE)
		bounds = card if first else bounds.merge(card)
		first = false
	for section in _shown_sections:
		bounds = bounds.expand(_section_title_position(section) + Vector2(0, -SECTION_SIZE))
	var room := Vector2(size.x, size.y - HINT_ROOM)
	var fit := minf((room.x - FIT_MARGIN * 2.0) / bounds.size.x, (room.y - FIT_MARGIN * 2.0) / bounds.size.y)
	var zoom := minf(fit, MAX_FIT_ZOOM)
	var target_position := room / 2.0 - bounds.get_center() * zoom
	if seconds <= 0.0:
		_diagram.scale = Vector2(zoom, zoom)
		_diagram.position = target_position
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_diagram, "scale", Vector2(zoom, zoom), seconds)
	tween.tween_property(_diagram, "position", target_position, seconds)


## Where a timeline's title sits: its baseline, at the left edge of the first column of cards.
func _section_title_position(section: String) -> Vector2:
	var row := _section_row(section)
	return Vector2(-CARD_SIZE.x / 2.0, row * ROW_HEIGHT + 14.0)
