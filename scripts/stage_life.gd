class_name StageLife
extends Node
## Gives a place the 2.5D staging from docs/STORY_BIBLE.md, section 12, without new art:
##
## - The camera drifts very slowly, in and out and a little to the side. The people, and things
##   drawn out of focus in front, move a touch more than the room behind them, so the room has
##   depth, like a camera with layers.
## - The people standing in the place breathe: each rises and settles very slightly, on their own
##   rhythm, so nobody looks like a cut-out.
## - The light lives (see shaders/stage_light.gdshader): candles and lamps flicker, dust floats in
##   the sun, steam drifts from the bathroom, and cloud shadows pass over.
##
## Everything is kept small on purpose: the player should feel it more than see it.

const LIGHT_SHADER := preload("res://shaders/stage_light.gdshader")
## How far the camera drifts: sideways and up and down in pixels, and in and out as a share of
## the size. One slow cycle takes this many seconds; the two directions are out of step, so the
## path never repeats exactly.
const DRIFT_PIXELS := Vector2(6.0, 3.0)
const DRIFT_ZOOM := 0.012
## Every layer is shown this much larger all the time, so the drift never shows an empty edge.
const OVERSCAN := 0.014
const DRIFT_SECONDS := Vector2(29.0, 23.0)
const ZOOM_SECONDS := 37.0
## How much more than the room the people and the near, blurred things move.
const CHARACTER_DEPTH := 1.35
const FOREGROUND_DEPTH := 1.9
## One breath: how much taller a person gets (a share of their height), and how long it takes.
## Each person's breath is a little faster or slower than the others'.
const BREATH_RISE := 0.007
const BREATH_SECONDS := 4.2
const BREATH_SPREAD := 0.7
## The light of each place. Positions are shares of the place's width and height, read off the
## background art: flames are [x, y, size, strength]; areas are [x, y, width, height].
const LIGHTS := {
	"church_nave": {
		"flames": [[0.234, 0.63, 0.03, 0.32], [0.716, 0.63, 0.03, 0.32], [0.778, 0.1, 0.045, 0.16], [0.613, 0.225, 0.035, 0.14]],
		"motes": 1.0, "motes_area": [0.0, 0.15, 0.6, 0.65], "clouds": 0.05,
	},
	"confessional": {"motes": 0.8, "motes_area": [0.5, 0.0, 0.5, 1.0], "clouds": 0.1},
	"apartment_room": {
		"steam": 0.3, "steam_area": [0.86, 0.15, 0.13, 0.65],
		"motes": 0.5, "motes_area": [0.2, 0.3, 0.4, 0.4], "clouds": 0.07,
	},
	"public_market": {"motes": 0.8, "motes_area": [0.0, 0.0, 0.5, 1.0], "clouds": 0.06},
}

var _place: Control
## Each moving layer, with where it rests and how strongly it moves.
var _layers: Array = []
var _time := 0.0


## Brings `place` to life: call once the place is set up.
static func add_to(place: Control, location_key: String) -> StageLife:
	var life := StageLife.new()
	life.name = "StageLife"
	life._place = place
	place.add_child(life)
	life._build(location_key)
	return life


func _build(location_key: String) -> void:
	var center := ScreenFit.DESIGN_SIZE / 2.0
	# Every part of the room moves: the background, the things in it, the doors and hotspots. The
	# menu does not, and neither does the HUD (it is on its own layer).
	for child in _place.get_children():
		if not child is Control or child is GameMenu:
			continue
		var layer := child as Control
		var depth := CHARACTER_DEPTH if layer.name == "Characters" else 1.0
		_add_layer(layer, depth, center - layer.position)
		# Things drawn out of focus sit in front of everything, so they move the most.
		for node in layer.find_children("*", "ArtSlot", true, false):
			var slot := node as ArtSlot
			if slot.depth_blur > 0.0:
				# It already moves with its layer; this is only the extra on top.
				_add_layer(slot, FOREGROUND_DEPTH - depth, slot.size / 2.0, false)
	for node in _place.find_children("*", "ArtSlot", true, false):
		var slot := node as ArtSlot
		if slot.category == "characters":
			slot.pivot_offset = Vector2(slot.size.x / 2.0, slot.size.y)
			breathe(slot)
	_add_light(location_key)


func _add_layer(layer: Control, depth: float, pivot: Vector2, overscan := true) -> void:
	layer.pivot_offset = pivot
	_layers.append({"node": layer, "rest": layer.position, "depth": depth, "base": 1.0 + (OVERSCAN if overscan else 0.0)})


## Rises and settles around its pivot (set it at the feet first), forever, starting at a random
## point of the breath. Used for the people in a place and the portraits by the dialogue box.
static func breathe(person: Control) -> void:
	var seconds := BREATH_SECONDS + randf_range(-BREATH_SPREAD, BREATH_SPREAD)
	var breath := person.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(person, "scale", Vector2(1.0 - BREATH_RISE * 0.3, 1.0 + BREATH_RISE), seconds / 2.0)
	breath.tween_property(person, "scale", Vector2.ONE, seconds / 2.0)
	breath.custom_step(randf() * seconds)


func _add_light(location_key: String) -> void:
	var settings: Dictionary = LIGHTS.get(location_key, {})
	if settings.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = LIGHT_SHADER
	var flames: Array = settings.get("flames", [])
	var packed: Array[Vector4] = []
	for flame in flames:
		packed.append(Vector4(flame[0], flame[1], flame[2], flame[3]))
	while packed.size() < 4:
		packed.append(Vector4.ZERO)
	material.set_shader_parameter("flames", packed)
	material.set_shader_parameter("flame_count", flames.size())
	for amount in ["motes", "steam", "clouds"]:
		material.set_shader_parameter(amount, float(settings.get(amount, 0.0)))
	for area in ["motes_area", "steam_area"]:
		var rect: Array = settings.get(area, [0.0, 0.0, 0.0, 0.0])
		material.set_shader_parameter(area, Vector4(rect[0], rect[1], rect[2], rect[3]))
	var light := ColorRect.new()
	light.name = "StageLight"
	light.material = material
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_place.add_child(light)
	# Above the room, its things and its people; below the menu, which comes after them.
	var characters := _place.get_node_or_null("Characters")
	if characters != null:
		_place.move_child(light, characters.get_index() + 1)


func _process(delta: float) -> void:
	_time += delta
	var sway := Vector2(sin(TAU * _time / DRIFT_SECONDS.x), sin(TAU * _time / DRIFT_SECONDS.y))
	var zoom := 0.5 - 0.5 * cos(TAU * _time / ZOOM_SECONDS)
	for layer in _layers:
		var node: Control = layer["node"]
		var depth: float = layer["depth"]
		node.position = (layer["rest"] as Vector2) + sway * DRIFT_PIXELS * depth
		node.scale = Vector2.ONE * (float(layer["base"]) + DRIFT_ZOOM * depth * zoom)
