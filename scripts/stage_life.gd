class_name StageLife
extends Node
## Gives a place its living light (see shaders/stage_light.gdshader): candles and lamps glow,
## dust floats in the sun, steam drifts from the bathroom, and cloud shadows pass over.
##
## Only the light moves. The room, its things and its people stay perfectly still, and so do the
## portraits: drifting cameras and breathing people were tried, and at the size of a phone screen
## they only read as everything trembling.

const LIGHT_SHADER := preload("res://shaders/stage_light.gdshader")
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


## Brings `place` to life: call once the place is set up.
static func add_to(place: Control, location_key: String) -> StageLife:
	var life := StageLife.new()
	life.name = "StageLife"
	life._place = place
	place.add_child(life)
	life._add_light(location_key)
	return life


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
