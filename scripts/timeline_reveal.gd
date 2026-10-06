extends Control
## Closes a run on an alternate timeline. The timeline diagram starts zoomed far in on the run's
## first card, and a glowing green line travels the path this run took, card to card, with the
## view following it. Then the view pulls back to show every reality this save has made.
##
## Only finished realities are drawn: a timeline or branch the player has not finished never
## appears, so the diagram never gives away what else is possible. The layout follows the
## timelines chart (story/timelines.json). A tap afterwards returns to the main screen.

const COLUMN_WIDTH := 250.0
const ROW_HEIGHT := 112.0
const CARD_SIZE := Vector2(200, 86)
const SECTION_TITLE_GAP := 80.0
const TITLE_SIZE := 17
const LINE_SIZE := 13
const SECTION_SIZE := 20
const CARD_PADDING := 10.0

const BACKGROUND := Color(0, 0, 0, 1)
const CARD_FILL := Color(0.06, 0.06, 0.06, 0.92)
const PAST_LINE := Color(1, 1, 1, 0.32)
const GLOW_CORE := Color(0.62, 1.0, 0.66, 1)
const GLOW_INNER := Color(0.3, 0.95, 0.42, 0.35)
const GLOW_OUTER := Color(0.2, 0.9, 0.35, 0.14)
const TEXT := Color(1, 1, 1, 1)
const LINE_TEXT := Color(0.8, 0.8, 0.8, 1)
## The chart's legend colours, by kind of card.
const KIND_COLORS := {
	"story": Color(0.78, 0.78, 0.78, 1),
	"lives": Color(0.5, 0.85, 0.5, 1),
	"suffers": Color(0.93, 0.78, 0.38, 1),
	"dies": Color(0.93, 0.45, 0.45, 1),
	"someone_dies": Color(0.7, 0.6, 0.98, 1),
}

const START_ZOOM := 3.4
const OPENING_HOLD_SECONDS := 0.9
## How fast the glowing line travels, in diagram units per second.
const TRAVEL_SPEED := 300.0
const ARRIVAL_HOLD_SECONDS := 0.8
const ZOOM_OUT_SECONDS := 2.2
const FIT_MARGIN := 70.0
const HINT_DELAY_SECONDS := 0.6

var _diagram := Control.new()
var _hint := Label.new()
var _nodes: Dictionary = {}
var _sections: Dictionary = {}
## Card id to its centre, in diagram units, for the cards being shown.
var _centers: Dictionary = {}
var _shown_sections: Array = []
## Every edge of every finished reality, as point lists.
var _past_edges: Array = []
## This run's route as one point list, and how far along it the glow has travelled.
var _route := PackedVector2Array()
var _route_length := 0.0
var _travelled := 0.0
var _reached: Array = []
var _new_path: Array = []
var _card_styles: Dictionary = {}
var _font: Font
var _waiting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = BACKGROUND
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_font = get_theme_default_font()
	_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diagram.draw.connect(_draw_diagram)
	# Text and card boxes get the soft retro look of the rest of the game.
	var retro := ShaderMaterial.new()
	retro.shader = DialogueBox.RETRO_TEXT_SHADER
	retro.set_shader_parameter("alpha_boost", 1.0)
	_diagram.material = retro
	add_child(_diagram)
	_hint.theme_type_variation = &"HudHeading"
	_hint.text = StoryCard.SKIP_HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -70.0
	_hint.offset_bottom = -30.0
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_build()
	_play.call_deferred()


func _build() -> void:
	var map := TimelineMap.data()
	_nodes = map.get("nodes", {})
	_sections = map.get("sections", {})
	for kind in KIND_COLORS:
		_card_styles[kind] = SoftShapes.box_style(CARD_FILL, KIND_COLORS[kind], 2, 8)
	var realities := TimelineMap.realities_with(GameState.realities)
	for reality in realities:
		var path: Array = reality.get("path", [])
		for id in path:
			if not _centers.has(id):
				_centers[id] = _center_of(id)
				var section := str(_nodes[id].get("section", ""))
				if section not in _shown_sections:
					_shown_sections.append(section)
		for index in range(path.size() - 1):
			_past_edges.append(_edge(path[index], path[index + 1]))
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


func _center_of(id: String) -> Vector2:
	var card: Dictionary = _nodes[id]
	var section: Dictionary = _sections.get(card.get("section", ""), {})
	var row := float(section.get("row", 0.0)) + float(card.get("row", 0.0))
	return Vector2(float(card.get("col", 0.0)) * COLUMN_WIDTH, row * ROW_HEIGHT + SECTION_TITLE_GAP)


## From the right edge of one card to the left edge of the next, with a right-angled bend halfway,
## as in the chart.
func _edge(from_id: String, to_id: String) -> PackedVector2Array:
	var start: Vector2 = _centers.get(from_id, _center_of(from_id)) + Vector2(CARD_SIZE.x / 2.0, 0)
	var end: Vector2 = _centers.get(to_id, _center_of(to_id)) - Vector2(CARD_SIZE.x / 2.0, 0)
	var bend := (start.x + end.x) / 2.0
	return PackedVector2Array([start, Vector2(bend, start.y), Vector2(bend, end.y), end])


func _play() -> void:
	if _route.is_empty():
		_view_all(0.0)
		await _finish()
		return
	_look_at(_route[0], START_ZOOM)
	_reached = [_new_path[0]]
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
			_reached.append(id)
	_diagram.queue_redraw()


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
	var fit := minf((size.x - FIT_MARGIN * 2.0) / bounds.size.x, (size.y - FIT_MARGIN * 2.0) / bounds.size.y)
	var zoom := minf(fit, 1.0)
	var target_position := size / 2.0 - bounds.get_center() * zoom
	if seconds <= 0.0:
		_diagram.scale = Vector2(zoom, zoom)
		_diagram.position = target_position
		_diagram.queue_redraw()
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_diagram, "scale", Vector2(zoom, zoom), seconds)
	tween.tween_property(_diagram, "position", target_position, seconds)


func _section_title_position(section: String) -> Vector2:
	var row := float(_sections.get(section, {}).get("row", 0.0))
	return Vector2(-CARD_SIZE.x / 2.0, row * ROW_HEIGHT + 14.0)


func _draw_diagram() -> void:
	for section in _shown_sections:
		_diagram.draw_string(_font, _section_title_position(section), str(_sections[section].get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_SIZE, TEXT)
	for edge in _past_edges:
		_diagram.draw_polyline(edge, PAST_LINE, 2.0, true)
	_draw_glow()
	for id in _centers:
		_draw_card(id)


## The green line, as far as it has travelled: a wide soft glow under a bright core.
func _draw_glow() -> void:
	if _route.is_empty() or _travelled <= 0.0:
		return
	var points := PackedVector2Array([_route[0]])
	var left := _travelled
	for index in range(1, _route.size()):
		var piece := _route[index - 1].distance_to(_route[index])
		if left <= piece:
			points.append(_route[index - 1].lerp(_route[index], left / maxf(piece, 0.001)))
			break
		points.append(_route[index])
		left -= piece
	_diagram.draw_polyline(points, GLOW_OUTER, 16.0, true)
	_diagram.draw_polyline(points, GLOW_INNER, 8.0, true)
	_diagram.draw_polyline(points, GLOW_CORE, 2.5, true)
	_diagram.draw_circle(points[points.size() - 1], 5.0, GLOW_CORE)


func _draw_card(id: String) -> void:
	var card: Dictionary = _nodes[id]
	var kind := str(card.get("kind", "story"))
	var rect := Rect2(_centers[id] - CARD_SIZE / 2.0, CARD_SIZE)
	if id in _reached:
		# Cards on this run's path glow green once the line reaches them.
		_diagram.draw_rect(rect.grow(5.0), GLOW_OUTER, true)
		_diagram.draw_rect(rect.grow(2.0), GLOW_INNER, true)
	_diagram.draw_style_box(_card_styles.get(kind, _card_styles["story"]), rect)
	var title_color: Color = TEXT if kind == "story" else KIND_COLORS.get(kind, TEXT)
	var inner_width := CARD_SIZE.x - CARD_PADDING * 2.0
	var title_y := rect.position.y + CARD_PADDING + TITLE_SIZE
	_diagram.draw_string(_font, Vector2(rect.position.x + CARD_PADDING, title_y), str(card.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, inner_width, TITLE_SIZE, title_color)
	_diagram.draw_multiline_string(_font, Vector2(rect.position.x + CARD_PADDING, title_y + LINE_SIZE + 8.0), str(card.get("line", "")), HORIZONTAL_ALIGNMENT_CENTER, inner_width, LINE_SIZE, 3, LINE_TEXT)
